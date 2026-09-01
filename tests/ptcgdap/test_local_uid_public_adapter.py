from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.author_strategy_match_host import (
    AuthorStrategyMatchError,
    AuthorStrategyMatchHandleBuilder,
    AuthorStrategyShadowPrompt,
    PtcgDAPAuthorMatchHost,
)
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.public_deck_adapter import (
    EXPECTED_LOCAL_BUNDLE_SHA256,
    PublicDeckAdapterCompiler,
    PublicDeckAdapterProposer,
    is_valid_local_card_uid,
)
from tests.ptcgdap.test_public_base_policy import policy_owners


ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
LOCAL_DOMAIN = "godot_local_card_uid_v1"
LOCAL_CONTEXT_VECTORS = ROOT / "contracts/ptcgdap/local_uid_public_context_conformance_vectors.json"


def local_handle():
    package = AuthorStrategyPackageLoader().load_path(CANDIDATE)
    return AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)


def local_context(context, *, option_uid: str | None = "CSV10C_146") -> dict[str, object]:
    public = context.to_public_dict()
    options = public["select_semantics"]["options"]
    hand = public["public_state"]["acting_player"]["hand"]
    active = public["public_state"]["acting_player"]["active"]
    return {
        "schema_version": 1,
        "card_id_domain": LOCAL_DOMAIN,
        "source": {
            "context_hash": public["context_hash"],
            "window_id": public["source"]["window_id"],
        },
        "options": [
            {"index": item["index"], "local_card_uid": option_uid if item["index"] == 0 else None}
            for item in options
        ],
        "acting_hand": [
            {"serial": item["serial"], "local_card_uid": "CSV7C_177"}
            for item in hand
        ],
        "acting_active": [
            {"serial": item["serial"], "local_card_uid": "CSV10C_148"}
            for item in active
        ],
    }


def matching_document() -> dict[str, object]:
    document = local_handle()._policy_documents()[1]
    document["rules"] = [copy.deepcopy(document["rules"][0])]
    rule = document["rules"][0]
    rule["predicate"] = {
        "select_type_raw": 9,
        "select_context_raw": 41,
        "option_type_raw": 1,
        "option_card_id": "CSV10C_146",
        "option_player_index": None,
        "acting_hand_card_id": "CSV7C_177",
        "acting_active_card_id": "CSV10C_148",
    }
    return document


class LocalUidPublicAdapterTests(unittest.TestCase):
    def test_local_compiler_accepts_the_deck_contract_without_a_set_suffix_convention(self) -> None:
        self.assertTrue(is_valid_local_card_uid("SVP_105"))
        for invalid in ("SVP-105", "SVP_10_5", "SVP_10-5", "PRIVATE_105"):
            with self.subTest(invalid=invalid):
                self.assertFalse(is_valid_local_card_uid(invalid))
        handle = local_handle()
        allowed = {item["local_card_uid"] for item in handle.local_deck_snapshot()}
        allowed.add("SVP_105")
        outcome = PublicDeckAdapterCompiler.compile_local_uid(
            matching_document(),
            allowed_card_uids=allowed,
            deck_manifest_sha256=handle.to_public_dict()["deck_manifest_sha256"],
        )
        self.assertTrue(outcome.accepted, outcome.error_code)

    def test_local_contract_tamper_fails_before_adapter_compilation(self) -> None:
        vectors = json.loads(LOCAL_CONTEXT_VECTORS.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as temporary:
            contract_root = Path(temporary) / "ptcgdap"
            shutil.copytree(ROOT / "contracts/ptcgdap", contract_root)
            profile_path = contract_root / "local_uid_public_context_profile.json"
            profile = json.loads(profile_path.read_text(encoding="utf-8"))
            profile["scope"]["player_live_authority"] = True
            profile_path.write_text(json.dumps(profile), encoding="utf-8")
            rejected = PublicDeckAdapterCompiler.compile_local_uid(
                matching_document(),
                allowed_card_uids=set(vectors["deck_binding"]["allowed_card_uids"]),
                deck_manifest_sha256=vectors["deck_binding"]["deck_manifest_sha256"],
                contract_root=contract_root,
            )
            self.assertFalse(rejected.accepted)
            self.assertEqual("local_uid_contract_error", rejected.error_code)

    def test_shared_local_uid_public_context_vectors_match_exact_hash_and_rejections(self) -> None:
        context, _window, _ir, _official_adapter = policy_owners()
        vectors = json.loads(LOCAL_CONTEXT_VECTORS.read_text(encoding="utf-8"))
        compiled = PublicDeckAdapterCompiler.compile_local_uid(
            matching_document(),
            allowed_card_uids=set(vectors["deck_binding"]["allowed_card_uids"]),
            deck_manifest_sha256=vectors["deck_binding"]["deck_manifest_sha256"],
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        bound = PublicDeckAdapterCompiler.bind_local_context(
            compiled.adapter,
            context,
            vectors["accepted_case"]["value"],
        )
        self.assertTrue(bound.accepted, bound.error_code)
        self.assertEqual(vectors["accepted_case"]["expected_local_context_hash"], bound.adapter.local_context_hash)
        for case in vectors["rejected_cases"]:
            with self.subTest(case=case["id"]):
                rejected = PublicDeckAdapterCompiler.bind_local_context(compiled.adapter, context, case["value"])
                self.assertFalse(rejected.accepted)
                self.assertEqual(case["expected_error_code"], rejected.error_code)

    def test_local_compiler_binds_manifest_uid_set_and_public_context(self) -> None:
        context, _window, _ir, _official_adapter = policy_owners()
        handle = local_handle()
        allowed = {item["local_card_uid"] for item in handle.local_deck_snapshot()}
        pins = handle.to_public_dict()

        self.assertFalse(PublicDeckAdapterCompiler.compile(matching_document()).accepted)
        compiled = PublicDeckAdapterCompiler.compile_local_uid(
            matching_document(),
            allowed_card_uids=allowed,
            deck_manifest_sha256=pins["deck_manifest_sha256"],
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        self.assertEqual(LOCAL_DOMAIN, compiled.adapter.card_id_domain)
        self.assertFalse(compiled.adapter.local_context_bound)

        bound = PublicDeckAdapterCompiler.bind_local_context(
            compiled.adapter,
            context,
            local_context(context),
        )
        self.assertTrue(bound.accepted, bound.error_code)
        self.assertTrue(bound.adapter.local_context_bound)
        proposal = PublicDeckAdapterProposer.propose(context, bound.adapter, "local-uid-match")
        self.assertTrue(proposal.accepted, proposal.error_code)
        self.assertEqual(
            [{"operator": "macro_proposal", "indexes": [0], "reason_code": "public_macro_proposal"}],
            proposal.result.adapter_proposals,
        )
        public = proposal.result.to_public_dict()
        self.assertEqual(LOCAL_DOMAIN, public["card_id_domain"])
        self.assertEqual(bound.adapter.local_context_hash, public["source"]["local_uid_public_context_hash"])

    def test_local_context_rejects_unknown_uid_serial_source_and_extra_fields(self) -> None:
        context, _window, _ir, _official_adapter = policy_owners()
        handle = local_handle()
        allowed = {item["local_card_uid"] for item in handle.local_deck_snapshot()}
        compiled = PublicDeckAdapterCompiler.compile_local_uid(
            matching_document(),
            allowed_card_uids=allowed,
            deck_manifest_sha256=handle.to_public_dict()["deck_manifest_sha256"],
        ).adapter
        self.assertIsNotNone(compiled)

        mutations = []
        unknown = local_context(context); unknown["options"][0]["local_card_uid"] = "CSV999C_999"; mutations.append(unknown)
        bad_serial = local_context(context); bad_serial["acting_hand"][0]["serial"] += 1; mutations.append(bad_serial)
        bad_source = local_context(context); bad_source["source"]["window_id"] = "A" * 64; mutations.append(bad_source)
        extra = local_context(context); extra["opponent_hand"] = [{"serial": 999, "local_card_uid": "CSV7C_177"}]; mutations.append(extra)
        private = local_context(context); private["acting_hand"][0]["local_card_uid"] = "PRIVATE_SENTINEL"; mutations.append(private)
        for value in mutations:
            with self.subTest(value=value):
                outcome = PublicDeckAdapterCompiler.bind_local_context(compiled, context, value)
                self.assertFalse(outcome.accepted)
                self.assertEqual("invalid_local_uid_public_context", outcome.error_code)

    def test_local_package_host_requires_bound_public_uid_view_and_remains_shadow_only(self) -> None:
        context, window, _ir, _official_adapter = policy_owners()
        tiers = [{"index": index, "tier": [0]} for index in range(window.option_count)]
        host = PtcgDAPAuthorMatchHost.create(local_handle(), "marnie-local-shadow")
        self.assertTrue(host.is_author_owner_ready())

        without_view = AuthorStrategyShadowPrompt.create(
            context, window, prompt_id="local-no-view", prompt_generation=1,
            mandatory_indexes=[], terminal_indexes=[], base_hard_tiers=tiers, base_vetoed_indexes=[],
        )
        with self.assertRaises(AuthorStrategyMatchError) as missing:
            host.open_current_prompt(without_view)
        self.assertEqual("invalid_local_uid_public_context", missing.exception.code)

        with_view = AuthorStrategyShadowPrompt.create(
            context, window, prompt_id="local-with-view", prompt_generation=2,
            mandatory_indexes=[], terminal_indexes=[], base_hard_tiers=tiers, base_vetoed_indexes=[],
            local_uid_public_context=local_context(context),
        )
        self.assertEqual({"ok": True, "error_code": ""}, host.open_current_prompt(with_view))
        result = host.request_current_selection()
        self.assertTrue(result.validate_integrity())
        audit = result.to_public_dict()
        self.assertEqual("shadow_selected", audit["status"])
        self.assertEqual(LOCAL_DOMAIN, audit["source"]["card_id_domain"])
        self.assertEqual(EXPECTED_LOCAL_BUNDLE_SHA256, audit["source"]["local_uid_contract_sha256"])
        self.assertEqual(64, len(audit["source"]["local_uid_public_context_hash"]))
        self.assertFalse(audit["execution_trusted"])
        self.assertFalse(audit["authoritative"])


if __name__ == "__main__":
    unittest.main()
