from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.author_strategy_match_host import (
    AuthorStrategyMatchHandleBuilder,
    PtcgDAPAuthorMatchHost,
)
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageError, AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_package import TEST_FIXTURE_KEY_ID, build_package_bytes
from tools.ptcgdap.build_author_strategy_release_candidate import (
    TEST_FIXTURE_PRIVATE_KEY,
    build_candidate_bytes,
    build_candidate_payloads,
)
from tools.ptcgdap.build_author_strategy_windows_local_deck_contract import (
    ARTIFACT_PATHS,
    CARD_ID_DOMAIN,
    PROFILE_ID,
    build_contract_documents,
    build_marnie_deck_csv,
    build_marnie_deck_manifest,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DECK = ROOT / "data/bundled_user/decks/800018501.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AuthorStrategyWindowsLocalDeckTests(unittest.TestCase):
    def test_extension_contract_is_strict_windows_only_and_reproducible(self) -> None:
        documents = build_contract_documents()
        Draft202012Validator.check_schema(documents["schema"])
        profile = documents["profile"]
        self.assertEqual(PROFILE_ID, profile["profile_id"])
        self.assertEqual(["windows"], profile["supported_platforms"])
        self.assertEqual(CARD_ID_DOMAIN, profile["card_id_domain"])
        self.assertFalse(profile["cabt_exportable"])
        bundle = documents["bundle"]
        self.assertEqual(
            {"schema", "profile", "vectors"},
            {entry["id"] for entry in bundle["artifacts"]},
        )
        for entry in bundle["artifacts"]:
            path = ROOT / entry["path"]
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))))
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_author_strategy_windows_local_deck_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_marnie_180_source_becomes_exact_60_card_local_uid_manifest(self) -> None:
        manifest = build_marnie_deck_manifest(ROOT)
        csv_bytes = build_marnie_deck_csv(manifest)
        self.assertEqual("deck_manifest_windows_local_v1", manifest["document_type"])
        self.assertEqual(CARD_ID_DOMAIN, manifest["card_id_domain"])
        self.assertEqual(["windows"], manifest["platform_scope"])
        self.assertFalse(manifest["cabt_exportable"])
        self.assertEqual(800018501, manifest["source_deck_id"])
        self.assertEqual(60, manifest["card_count"])
        self.assertEqual(28, manifest["unique_card_count"])
        self.assertEqual(sha(SOURCE_DECK.read_bytes()), manifest["source_deck_raw_sha256"])
        self.assertEqual(sha(csv_bytes), manifest["deck_csv_sha256"])
        self.assertEqual(60, sum(entry["count"] for entry in manifest["cards"]))
        uids = [entry["local_card_uid"] for entry in manifest["cards"]]
        self.assertEqual(sorted(uids, key=str.encode), uids)
        self.assertEqual(28, len(set(uids)))
        self.assertIn("CSV10C_148", uids)
        self.assertIn("CSVE1C_DAR", uids)
        self.assertNotIn("official_card_id", json.dumps(manifest, sort_keys=True))
        self.assertEqual("local_card_uid,count", csv_bytes.decode("ascii").splitlines()[0])
        for entry in manifest["cards"]:
            source = ROOT / "data/bundled_user/cards" / f"{entry['local_card_uid']}.json"
            card = load_json_strict(source)
            self.assertEqual(sha(source.read_bytes()), entry["source_raw_sha256"])
            self.assertEqual(sha(canonical_json_v1_bytes(card)), entry["source_canonical_sha256"])
            self.assertEqual(entry["local_card_uid"], f"{card['set_code']}_{card['card_index']}")
            self.assertEqual(card["effect_id"], entry["effect_id"])

    def test_test_signed_candidate_loads_and_materializes_all_28_local_printings(self) -> None:
        candidate = build_candidate_bytes()
        package = AuthorStrategyPackageLoader().load_bytes(candidate, expected_archive_sha256=sha(candidate))
        self.assertEqual("ptcgdap.marnie.windows-local", package.package_id)
        self.assertFalse(package.execution_trusted)
        handle = AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)
        pins = handle.to_public_dict()
        self.assertEqual(CARD_ID_DOMAIN, pins["deck_card_id_domain"])
        self.assertEqual(["windows"], pins["deck_platform_scope"])
        self.assertFalse(pins["cabt_exportable"])
        self.assertEqual(60, pins["local_deck_card_count"])
        self.assertEqual(28, pins["local_deck_unique_printing_count"])
        local = handle.local_deck_snapshot()
        self.assertTrue(all("local_card_uid" in row for row in local))
        self.assertTrue(all("official_card_id" not in row for row in local))
        self.assertEqual(
            [entry["local_card_uid"] for entry in build_marnie_deck_manifest(ROOT)["cards"]],
            [entry["local_card_uid"] for entry in local],
        )
        host = PtcgDAPAuthorMatchHost.create(handle, "marnie-local-domain-shadow")
        self.assertTrue(host.is_author_owner_ready())
        self.assertFalse(pins["execution_trusted"])
        self.assertFalse(pins["live_authority"])

    def test_candidate_policy_uses_only_exact_game_local_card_uids(self) -> None:
        payloads = build_candidate_payloads()
        deck_manifest = json.loads(payloads["deck/deck_manifest.json"])
        adapter = json.loads(payloads["policy/adapter.json"])
        config = json.loads(payloads["policy/config.json"])
        allowed_uids = {entry["local_card_uid"] for entry in deck_manifest["cards"]}

        self.assertEqual(CARD_ID_DOMAIN, config["values"]["card_id_domain"])
        self.assertEqual(sha(payloads["deck/deck_manifest.json"]), config["values"]["deck_manifest_sha256"])
        self.assertEqual("ptcgdap.marnie.windows-local", adapter["adapter_id"])
        self.assertNotIn("test.fixture", json.dumps(adapter, sort_keys=True))
        self.assertNotIn("official_card_id", json.dumps(adapter, sort_keys=True))
        self.assertGreaterEqual(len(adapter["rules"]), 6)

        referenced_uids: set[str] = set()
        for rule in adapter["rules"]:
            predicate = rule["predicate"]
            for field in ("option_card_id", "acting_hand_card_id", "acting_active_card_id"):
                value = predicate[field]
                if value is not None:
                    self.assertIs(type(value), str)
                    self.assertIn(value, allowed_uids)
                    referenced_uids.add(value)
        self.assertTrue(
            {"CSV10C_146", "CSV10C_147", "CSV10C_148", "CSV7C_177", "CSV10C_216", "CSV8C_183", "CSVE1C_DAR"}
            <= referenced_uids
        )

    def test_local_manifest_fails_closed_on_scope_export_uid_and_source_drift(self) -> None:
        loader = AuthorStrategyPackageLoader()
        base = build_candidate_payloads()
        cases: list[tuple[str, object, str]] = [
            ("android_scope", ["android"], "package_deck_unmapped"),
            ("cabt_exportable", True, "package_deck_unmapped"),
            ("uid_path", "../CSV10C_146", "package_deck_unmapped"),
            ("source_hash", "0" * 64, "package_deck_unmapped"),
            ("official_numeric_card_id", 1086, "package_policy_unsupported"),
            ("unknown_local_card_uid", "CSV999C_999", "package_policy_unsupported"),
            ("config_domain", "official_cabt_card_id", "package_policy_unsupported"),
        ]
        for case_id, replacement, expected_code in cases:
            with self.subTest(case=case_id):
                payloads = copy.deepcopy(base)
                deck = json.loads(payloads["deck/deck_manifest.json"])
                if case_id == "android_scope":
                    deck["platform_scope"] = replacement
                elif case_id == "cabt_exportable":
                    deck["cabt_exportable"] = replacement
                elif case_id == "uid_path":
                    deck["cards"][0]["local_card_uid"] = replacement
                elif case_id == "source_hash":
                    deck["cards"][0]["source_canonical_sha256"] = replacement
                elif case_id in {"official_numeric_card_id", "unknown_local_card_uid"}:
                    adapter = json.loads(payloads["policy/adapter.json"])
                    adapter["rules"][0]["predicate"]["acting_hand_card_id"] = replacement
                    payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
                else:
                    config = json.loads(payloads["policy/config.json"])
                    config["values"]["card_id_domain"] = replacement
                    payloads["policy/config.json"] = canonical_json_v1_bytes(config)
                if case_id in {"android_scope", "cabt_exportable", "uid_path", "source_hash"}:
                    payloads["deck/deck_manifest.json"] = canonical_json_v1_bytes(deck)
                archive = build_package_bytes(payloads, TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID)
                with self.assertRaises(AuthorStrategyPackageError) as captured:
                    loader.load_bytes(archive)
                self.assertEqual(expected_code, captured.exception.code)

    def test_competitive_v2_adapter_is_a_loadable_data_only_package(self) -> None:
        payloads = build_candidate_payloads()
        deck = json.loads(payloads["deck/deck_manifest.json"])
        allowed = {entry["local_card_uid"] for entry in deck["cards"]}
        dark_energy = "CSVE1C_DAR"
        grimmsnarl = "CSV10C_148"
        self.assertTrue({dark_energy, grimmsnarl} <= allowed)
        payloads["policy/adapter.json"] = canonical_json_v1_bytes(
            {
                "schema_version": 2,
                "adapter_id": "ptcgdap.marnie.competitive-v2",
                "adapter_version": 2,
                "goals": [
                    {
                        "goal_id": "ready-two-attackers",
                        "stage": "fund",
                        "priority": 100,
                        "requirements": [
                            {
                                "card_uid": grimmsnarl,
                                "ready_target_count": 2,
                                "energy_required": 2,
                            }
                        ],
                    }
                ],
                "count_rules": [
                    {
                        "rule_id": "punk-up.exact-energy-debt",
                        "priority": 0,
                        "goal_id": "ready-two-attackers",
                        "mode": "goal_energy_debt",
                        "fixed_count": None,
                        "fact": None,
                        "divisor": None,
                        "when": [
                            {
                                "fact": "prompt_kind",
                                "op": "eq",
                                "value": "search",
                                "card_uid": None,
                            }
                        ],
                    }
                ],
                "rules": [
                    {
                        "rule_id": "punk-up.dark-energy",
                        "goal_id": "ready-two-attackers",
                        "goal_stage": "fund",
                        "channel": "interaction",
                        "horizon": 0,
                        "confidence_milli": 1000,
                        "base_score": 1000,
                        "when": [
                            {
                                "fact": "option.card_uid",
                                "op": "eq",
                                "value": dark_energy,
                                "card_uid": None,
                            }
                        ],
                        "score_terms": [],
                    }
                ],
            }
        )
        archive = build_package_bytes(
            payloads,
            TEST_FIXTURE_PRIVATE_KEY,
            key_id=TEST_FIXTURE_KEY_ID,
        )

        package = AuthorStrategyPackageLoader().load_bytes(archive)

        self.assertEqual("ptcgdap.marnie.windows-local", package.package_id)
        self.assertEqual(2, json.loads(package.payload_bytes("policy/adapter.json"))["schema_version"])

    def test_competitive_v2_adapter_rejects_private_or_unknown_facts(self) -> None:
        payloads = build_candidate_payloads()
        adapter = {
            "schema_version": 2,
            "adapter_id": "ptcgdap.marnie.competitive-v2",
            "adapter_version": 2,
            "goals": [
                {
                    "goal_id": "ready-attacker",
                    "stage": "ready",
                    "priority": 1,
                    "requirements": [
                        {
                            "card_uid": "CSV10C_148",
                            "ready_target_count": 1,
                            "energy_required": 2,
                        }
                    ],
                }
            ],
            "count_rules": [],
            "rules": [
                {
                    "rule_id": "reject-hidden",
                    "goal_id": "ready-attacker",
                    "goal_stage": "ready",
                    "channel": "uncertainty",
                    "horizon": 0,
                    "confidence_milli": 1000,
                    "base_score": 1,
                    "when": [
                        {
                            "fact": "opponent.deck_order",
                            "op": "eq",
                            "value": 1,
                            "card_uid": None,
                        }
                    ],
                    "score_terms": [],
                }
            ],
        }
        payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
        archive = build_package_bytes(
            payloads,
            TEST_FIXTURE_PRIVATE_KEY,
            key_id=TEST_FIXTURE_KEY_ID,
        )

        with self.assertRaises(AuthorStrategyPackageError) as captured:
            AuthorStrategyPackageLoader().load_bytes(archive)

        self.assertEqual("package_policy_unsupported", captured.exception.code)


if __name__ == "__main__":
    unittest.main()
