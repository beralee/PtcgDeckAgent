from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.author_strategy_developer import (
    simulate_public_window,
    validate_development_package,
)
from tools.ptcgdap.build_cynthia_author_strategy_candidate import (
    PACKAGE_ID,
    SOURCE_DECK_ID,
    build_adapter,
    build_deck_manifest,
    build_scenarios,
)
from tools.ptcgdap.build_gholdengo_author_strategy_candidate import build_deck_csv


ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = ROOT / "artifacts/ptcgdap/cynthia_garchomp_strategy_iteration/author_strategy_candidate_v1"
CANDIDATE_PACKAGE = CANDIDATE_ROOT / "build/cynthia-garchomp-800018543-v0.1.0-dev.ptcgai"
BUILTIN_PACKAGE = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-cynthia-garchomp-development-candidate.ptcgai"
CYNTHIA_POLICY_MANIFEST = ROOT / "data/ptcgdap/cynthia_garchomp_windows_policy_package_v1.json"
CYNTHIA_POLICY = ROOT / "scripts/ai/ptcgdap/runtime/local/CynthiaAuthorStrategyDevelopmentPolicy.gd"
CYNTHIA_OWNER = ROOT / "scripts/ai/ptcgdap/host/godot/CynthiaAuthorStrategyDevelopmentBattleOwner.gd"
CYNTHIA_MANIFEST_VERIFIER = ROOT / "scripts/ai/ptcgdap/runtime/local/CynthiaPolicyPackageManifest.gd"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class CynthiaAuthorStrategyCandidateTests(unittest.TestCase):
    def test_exact_deck_manifest_pins_all_local_printings(self) -> None:
        manifest = build_deck_manifest(ROOT)
        csv_bytes = build_deck_csv(manifest)
        self.assertEqual(SOURCE_DECK_ID, manifest["source_deck_id"])
        self.assertEqual("godot_local_card_uid_v1", manifest["card_id_domain"])
        self.assertEqual(60, manifest["card_count"])
        self.assertEqual(26, manifest["unique_card_count"])
        self.assertEqual(60, sum(row["count"] for row in manifest["cards"]))
        uids = [row["local_card_uid"] for row in manifest["cards"]]
        self.assertEqual(sorted(uids, key=str.encode), uids)
        self.assertEqual(sha(csv_bytes), manifest["deck_csv_sha256"])
        self.assertIn("CSV10C_113", uids)
        self.assertIn("CSV10C_005", uids)
        for row in manifest["cards"]:
            card_path = ROOT / "data/bundled_user/cards" / f"{row['local_card_uid']}.json"
            card = load_json_strict(card_path)
            self.assertEqual(sha(card_path.read_bytes()), row["source_raw_sha256"])
            self.assertEqual(sha(canonical_json_v1_bytes(card)), row["source_canonical_sha256"])

    def test_adapter_is_public_only_and_uses_exact_deck_uids(self) -> None:
        manifest = build_deck_manifest(ROOT)
        adapter = build_adapter()
        allowed = {row["local_card_uid"] for row in manifest["cards"]}
        self.assertEqual(PACKAGE_ID, adapter["adapter_id"])
        self.assertEqual(12, len(adapter["rules"]))
        for rule in adapter["rules"]:
            self.assertEqual("macro_proposal", rule["operator"])
            for key in ("option_card_id", "acting_hand_card_id", "acting_active_card_id"):
                value = rule["predicate"][key]
                if value is not None:
                    self.assertIn(value, allowed)

    def test_package_preflight_and_all_public_scenarios_pass(self) -> None:
        validated = validate_development_package(CANDIDATE_PACKAGE)
        self.assertEqual("valid", validated["status"])
        self.assertTrue(validated["policy_preflight"]["accepted"])
        self.assertEqual([], validated["policy_preflight"]["invalid_local_card_uids"])
        scenarios = build_scenarios(ROOT)
        self.assertEqual(6, len(scenarios))
        for name in sorted(scenarios):
            scenario_path = CANDIDATE_ROOT / "scenarios" / name
            with self.subTest(scenario=name):
                self.assertEqual([1], scenarios[name]["expected_selected_indexes"])
                simulated = simulate_public_window(CANDIDATE_PACKAGE, scenario_path)
                self.assertEqual("passed", simulated["status"], json.dumps(simulated, ensure_ascii=False))
                self.assertFalse(simulated["adjudication"]["deterministic_fallback_used"])

    def test_exact_builtin_development_execution_binding_is_hash_pinned_and_non_production(self) -> None:
        self.assertEqual(CANDIDATE_PACKAGE.read_bytes(), BUILTIN_PACKAGE.read_bytes())
        manifest = load_json_strict(CYNTHIA_POLICY_MANIFEST)
        validated = validate_development_package(BUILTIN_PACKAGE)
        self.assertEqual("development_exact_fixture_only", manifest["authority_scope"])
        self.assertEqual(PACKAGE_ID, manifest["author_package"]["package_id"])
        self.assertEqual(validated["archive_sha256"], manifest["author_package"]["archive_sha256"])
        self.assertEqual(sha(CYNTHIA_POLICY.read_bytes()), manifest["executor"]["host_adapter_sha256"])
        self.assertEqual(sha(CYNTHIA_OWNER.read_bytes()), manifest["executor"]["match_owner_sha256"])
        verifier = CYNTHIA_MANIFEST_VERIFIER.read_text(encoding="utf-8")
        self.assertIn(manifest["executor"]["host_adapter_sha256"], verifier)
        self.assertIn(manifest["executor"]["match_owner_sha256"], verifier)
        self.assertFalse(validated["execution_trusted"])
        self.assertFalse(validated["production_ready"])
        self.assertFalse(validated["cabt_exportable"])
        policy = CYNTHIA_POLICY.read_text(encoding="utf-8")
        for forbidden in ("GameState", "BattleScene", "CardInstance", "HTTPClient", "OS.execute"):
            self.assertNotIn(forbidden, policy)


if __name__ == "__main__":
    unittest.main()
