from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_gholdengo_author_strategy_candidate import (
    PACKAGE_ID,
    SOURCE_DECK_ID,
    build_deck_csv,
    build_deck_manifest,
    build_workspace_payloads,
    write_workspace,
)
from tools.ptcgdap.author_strategy_developer import (
    simulate_public_window,
    validate_development_package,
)


ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = ROOT / "artifacts/ptcgdap/gholdengo_strategy_iteration/author_strategy_candidate_v1_2"
CANDIDATE_PACKAGE = CANDIDATE_ROOT / "build/gholdengo-palkia-575479-v0.1.2-dev.ptcgai"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class GholdengoAuthorStrategyCandidateTests(unittest.TestCase):
    def test_validate_preflights_the_same_host_compiler_and_scenarios_simulate(self) -> None:
        validated = validate_development_package(CANDIDATE_PACKAGE)
        self.assertEqual("valid", validated["status"])
        self.assertEqual(
            {
                "accepted": True,
                "owning_layer": "PtcgDAPAuthorMatchHost.create",
                "stage": "compile_policy",
                "error_code": "",
                "invalid_local_card_uids": [],
            },
            validated["policy_preflight"],
        )
        for scenario in sorted((CANDIDATE_ROOT / "scenarios").glob("*.json")):
            with self.subTest(scenario=scenario.name):
                simulated = simulate_public_window(CANDIDATE_PACKAGE, scenario)
                self.assertEqual("passed", simulated["status"], simulated)

    def test_exact_575479_manifest_pins_all_local_printings(self) -> None:
        manifest = build_deck_manifest(ROOT)
        csv_bytes = build_deck_csv(manifest)
        self.assertEqual(SOURCE_DECK_ID, manifest["source_deck_id"])
        self.assertEqual("godot_local_card_uid_v1", manifest["card_id_domain"])
        self.assertEqual(["windows"], manifest["platform_scope"])
        self.assertFalse(manifest["cabt_exportable"])
        self.assertEqual(60, manifest["card_count"])
        self.assertEqual(31, manifest["unique_card_count"])
        self.assertEqual(60, sum(row["count"] for row in manifest["cards"]))
        uids = [row["local_card_uid"] for row in manifest["cards"]]
        self.assertEqual(sorted(uids, key=str.encode), uids)
        self.assertIn("CSV4C_089", uids)
        self.assertIn("CS5bC_051", uids)
        self.assertEqual(sha(csv_bytes), manifest["deck_csv_sha256"])
        self.assertNotIn("official_card_id", json.dumps(manifest, sort_keys=True))
        for row in manifest["cards"]:
            card_path = ROOT / "data/bundled_user/cards" / f"{row['local_card_uid']}.json"
            card = load_json_strict(card_path)
            self.assertEqual(sha(card_path.read_bytes()), row["source_raw_sha256"])
            self.assertEqual(sha(canonical_json_v1_bytes(card)), row["source_canonical_sha256"])

    def test_policy_only_declares_public_safe_ordering_hints(self) -> None:
        payloads = build_workspace_payloads(ROOT)
        manifest = json.loads(payloads["package/strategy_package.json"])
        deck = json.loads(payloads["package/deck/deck_manifest.json"])
        adapter = json.loads(payloads["package/policy/adapter.json"])
        ir = json.loads(payloads["package/policy/policy_ir.json"])
        config = json.loads(payloads["package/policy/config.json"])
        allowed = {row["local_card_uid"] for row in deck["cards"]}
        self.assertEqual(PACKAGE_ID, manifest["package_id"])
        self.assertEqual(PACKAGE_ID, adapter["adapter_id"])
        self.assertEqual(SOURCE_DECK_ID, config["values"]["source_deck_id"])
        self.assertEqual(sha(payloads["package/deck/deck_manifest.json"]), config["values"]["deck_manifest_sha256"])
        macro_ids = ir["nodes"][2]["config"]["macro_ids"]
        self.assertEqual([rule["rule_id"] for rule in adapter["rules"]], macro_ids)
        self.assertFalse(any(rule["predicate"]["option_type_raw"] in {8, 10} for rule in adapter["rules"]))
        self.assertNotIn("SVP_105", json.dumps(adapter, sort_keys=True))
        for rule in adapter["rules"]:
            self.assertEqual("macro_proposal", rule["operator"])
            for key in ("option_card_id", "acting_hand_card_id", "acting_active_card_id"):
                value = rule["predicate"][key]
                if value is not None:
                    self.assertIn(value, allowed)

    def test_workspace_is_deterministic_and_scenarios_pin_expected_indexes(self) -> None:
        first = build_workspace_payloads(ROOT)
        second = build_workspace_payloads(ROOT)
        self.assertEqual(first, second)
        scenario_paths = sorted(path for path in first if path.startswith("scenarios/"))
        self.assertGreaterEqual(len(scenario_paths), 4)
        for path in scenario_paths:
            scenario = json.loads(first[path])
            self.assertEqual([1], scenario["expected_selected_indexes"], path)
            self.assertNotIn("context_hash", json.dumps(scenario, sort_keys=True))
            self.assertNotIn("window_id", json.dumps(scenario, sort_keys=True))
        attack = json.loads(first["scenarios/make-it-rain-attack.json"])
        self.assertEqual({"type": 13, "attackId": 1}, attack["raw_observation"]["select"]["option"][1])
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "gholdengo"
            report = write_workspace(output, root=ROOT)
            self.assertEqual("created", report["status"])
            self.assertEqual(len(first), report["file_count"])
            for relative_path, expected in first.items():
                self.assertEqual(expected, (output / relative_path).read_bytes())


if __name__ == "__main__":
    unittest.main()
