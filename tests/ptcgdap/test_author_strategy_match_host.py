from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.author_strategy_match_host import (
    AuthorStrategyExactDeckGate,
    AuthorStrategyMatchError,
    AuthorStrategyMatchHandleBuilder,
    AuthorStrategyShadowPrompt,
    PtcgDAPAuthorMatchHost,
)
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.source_lock import load_json_strict
from tests.ptcgdap.test_public_base_policy import policy_owners
from tools.ptcgdap.build_as_wp4_author_strategy_fixture import build_fixture_bytes


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
VECTORS = ROOT / "contracts/ptcgdap/author_strategy_match_host_conformance_vectors.json"


def handle():
    package = AuthorStrategyPackageLoader().load_bytes(FIXTURE.read_bytes())
    return AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)


def prompt(case: dict[str, object]):
    context, window, _, _ = policy_owners()
    return AuthorStrategyShadowPrompt.create(
        context,
        window,
        prompt_id=case["prompt_id"],
        prompt_generation=case["prompt_generation"],
        mandatory_indexes=copy.deepcopy(case["mandatory_indexes"]),
        terminal_indexes=copy.deepcopy(case["terminal_indexes"]),
        base_hard_tiers=copy.deepcopy(case["base_hard_tiers"]),
        base_vetoed_indexes=copy.deepcopy(case["base_vetoed_indexes"]),
    )


class AuthorStrategyMatchHostTests(unittest.TestCase):
    def test_fixture_is_deterministic_exact_mapped_and_never_execution_trusted(self) -> None:
        self.assertEqual(FIXTURE.read_bytes(), build_fixture_bytes())
        value = handle()
        self.assertTrue(value.validate_integrity())
        pins = value.to_public_dict()
        self.assertEqual("test.fixture.mapped-shadow", pins["package_id"])
        self.assertEqual(60, pins["local_deck_card_count"])
        self.assertEqual(9, pins["local_deck_unique_printing_count"])
        self.assertFalse(pins["execution_trusted"])
        self.assertTrue(pins["development_shadow_ready"])
        self.assertFalse(pins["live_authority"])
        self.assertEqual("gdscript_public_base_policy_v1", pins["backend_id"])
        self.assertIsNone(pins["weights_sha256"])
        local = value.local_deck_snapshot()
        local[0]["count"] = 999
        self.assertEqual(28, value.local_deck_snapshot()[0]["count"])
        object.__setattr__(value, "_pins_json", b"{}")
        self.assertFalse(value.validate_integrity())
        with self.assertRaises(AuthorStrategyMatchError):
            value.to_public_dict()

    def test_marnie_official_deck_remains_rejected_by_exact_gate(self) -> None:
        official = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json")
        counts: dict[int, int] = {}
        for card_id in official["ordered_card_ids"]:
            counts[card_id] = counts.get(card_id, 0) + 1
        rows = [{"official_card_id": card_id, "count": count} for card_id, count in sorted(counts.items())]
        with self.assertRaises(AuthorStrategyMatchError) as captured:
            AuthorStrategyExactDeckGate.map_official_rows(rows, root=ROOT)
        self.assertEqual("package_deck_unmapped", captured.exception.code)

    def test_shared_prompt_vectors_produce_exact_indexes_and_public_audit(self) -> None:
        vectors = load_json_strict(VECTORS)
        for case in vectors["shadow_cases"]:
            with self.subTest(case=case["id"]):
                match_handle = handle()
                host = PtcgDAPAuthorMatchHost.create(match_handle, case["match_id"])
                self.assertTrue(host.is_author_owner_ready())
                self.assertEqual({"ok": True, "error_code": ""}, host.open_current_prompt(prompt(case)))
                result = host.request_current_selection()
                self.assertTrue(result.validate_integrity())
                self.assertEqual(case["expected_selected_indexes"], result.indexes)
                self.assertEqual(case["expected_audit"], result.to_public_dict())
                serialized = json.dumps(result.to_public_dict(), sort_keys=True)
                for forbidden in ("PRIVATE", "GameState", "BattleScene", "callback", "ticket", "command", "object_ref"):
                    self.assertNotIn(forbidden, serialized)

    def test_handle_and_prompt_are_one_match_one_use_and_fail_closed(self) -> None:
        case = load_json_strict(VECTORS)["shadow_cases"][0]
        match_handle = handle()
        host = PtcgDAPAuthorMatchHost.create(match_handle, "one-use-match")
        with self.assertRaises(AuthorStrategyMatchError) as reused:
            PtcgDAPAuthorMatchHost.create(match_handle, "other-match")
        self.assertEqual("package_handle_already_claimed", reused.exception.code)
        source = prompt(case)
        host.open_current_prompt(source)
        first = host.request_current_selection()
        with self.assertRaises(AuthorStrategyMatchError) as repeated:
            host.request_current_selection()
        self.assertEqual("prompt_not_open", repeated.exception.code)
        with self.assertRaises(AuthorStrategyMatchError) as replayed:
            host.open_current_prompt(source)
        self.assertEqual("prompt_already_consumed", replayed.exception.code)
        audit = first.to_public_dict()
        audit["selected_indexes"] = [999]
        self.assertEqual(case["expected_selected_indexes"], first.indexes)

    def test_cross_window_context_and_malformed_base_authority_are_rejected(self) -> None:
        case = load_json_strict(VECTORS)["shadow_cases"][0]
        context, window, _, _ = policy_owners()
        other_context, _, _, _ = policy_owners()
        with self.assertRaises(AuthorStrategyMatchError) as cross:
            AuthorStrategyShadowPrompt.create(
                other_context,
                window,
                prompt_id="cross-window",
                prompt_generation=1,
                mandatory_indexes=[],
                terminal_indexes=[],
                base_hard_tiers=case["base_hard_tiers"],
                base_vetoed_indexes=[],
            )
        self.assertEqual("invalid_current_window_owner", cross.exception.code)
        bad_tiers = copy.deepcopy(case["base_hard_tiers"])
        bad_tiers[0]["index"] = True
        with self.assertRaises(AuthorStrategyMatchError) as malformed:
            AuthorStrategyShadowPrompt.create(
                context,
                window,
                prompt_id="bad-authority",
                prompt_generation=1,
                mandatory_indexes=[],
                terminal_indexes=[],
                base_hard_tiers=bad_tiers,
                base_vetoed_indexes=[],
            )
        self.assertEqual("invalid_prompt_authority", malformed.exception.code)


if __name__ == "__main__":
    unittest.main()
