from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.ucis_qualification import audit_qualification_inputs
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "evidence/ptcgdap/ucis/ucis_catalog_qualification_v1.json"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class UcisCatalogQualificationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.report = json.loads(EVIDENCE.read_text(encoding="utf-8"))

    def test_catalog_scope_is_closed_without_legacy_or_silent_fallback(self) -> None:
        report = self.report
        self.assertEqual(report["document_type"], "ptcgdap_ucis_catalog_qualification_v1")
        self.assertEqual(report["qualification_status"], "passed")
        self.assertEqual(report["failure_reasons"], [])
        scope = report["scope"]
        # Scan the actual source files independently of generated manifests,
        # so an omitted newly bundled printing cannot shrink the denominator.
        source_cards = {}
        for path in (ROOT / "data/bundled_user/cards").glob("*.json"):
            card = json.loads(path.read_text(encoding="utf-8-sig"))
            uid = f"{card['set_code']}_{card['card_index']}"
            self.assertNotIn(uid, source_cards, "Duplicate source printing")
            source_cards[uid] = (path, card)
        self.assertTrue(source_cards)
        source_effects = {card["effect_id"] for _, card in source_cards.values()}
        self.assertEqual(scope["total_cards"], len(source_cards))
        self.assertEqual(scope["total_effects"], len(source_effects))
        catalog = json.loads((ROOT / "contracts/ptcgdap/ucis_card_catalog_v1.json").read_bytes())
        self.assertEqual({row["card_uid"] for row in catalog["cards"]}, set(source_cards))
        self.assertEqual(len(catalog["cards"]), len(source_cards))
        self.assertEqual({row["effect_id"] for row in catalog["effects"]}, source_effects)
        self.assertEqual(len(catalog["effects"]), len(source_effects))
        for row in catalog["cards"]:
            path, card = source_cards[row["card_uid"]]
            self.assertEqual(row["effect_id"], card["effect_id"])
            self.assertEqual(row["source_path"], path.relative_to(ROOT).as_posix())
            self.assertEqual(row["source_sha256"], _sha(path))
        statuses = Counter(row["status"] for row in catalog["effects"])
        self.assertLessEqual(set(statuses), {"compiled", "automatic", "unsupported"})
        self.assertEqual(scope["compiled"], statuses["compiled"])
        self.assertEqual(scope["automatic"], statuses["automatic"])
        self.assertEqual(scope["declared_usable"], statuses["compiled"] + statuses["automatic"])
        self.assertEqual(scope["explicit_unsupported"], statuses["unsupported"])
        for field in (
            "unregistered",
            "silent_fallback",
            "legacy_author_visible",
            "custom_prompt_builder",
        ):
            self.assertEqual(scope[field], 0)
        self.assertEqual(scope["legacy_callsites_ucis_owned"], scope["legacy_callsites_total"])
        for metric in report["coverage"].values():
            self.assertEqual(metric["numerator"], metric["denominator"])

    def test_live_operation_and_performance_scopes_remain_independent_and_pass(self) -> None:
        live = self.report["representative_live_operation_scope"]
        self.assertEqual(
            live["claim"], "corresponding_card_whole_battle_input_index_contract"
        )
        self.assertEqual(live["qualification_status"], "passed")
        self.assertEqual(len(live["operation_families"]), 9)
        performance = self.report["performance_scope"]
        self.assertEqual(performance["qualification_status"], "passed")
        self.assertTrue(performance["runtime_operation_audit"]["qualified"])
        self.assertEqual(
            performance["runtime_operation_audit"]["subprocess_or_external_forge_calls"], 0
        )

    def test_historical_receipt_integrity_and_current_applicability(self) -> None:
        report = dict(self.report)
        expected = report.pop("evidence_sha256")
        canonical = json.dumps(
            report, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        self.assertEqual(expected, hashlib.sha256(canonical).hexdigest().upper())
        identities = report["source_identities"]
        paths = {
            "qualification_generator": "tools/ptcgdap/build_ucis_catalog_qualification.py",
            "contract_generator": "scripts/ai/ptcgdap/ucis_contract.py",
            "catalog_compiler": "scripts/ai/ptcgdap/ucis_catalog.py",
            "python_compiler": "scripts/ai/ptcgdap/ucis.py",
            "godot_compiler": "scripts/engine/ucis/UcisInteractionCompiler.gd",
        }
        for key, relative in paths.items():
            self.assertEqual(identities[key], _sha(ROOT / relative), key)
        current_contracts = {
            key: _sha(ROOT / "contracts/ptcgdap" / filename)
            for key, filename in {
                "bundle_raw_sha256": "ucis_bundle_v1.json",
                "catalog_raw_sha256": "ucis_card_catalog_v1.json",
                "runtime_attestation_raw_sha256": "ucis_runtime_attestation_v1.json",
                "coverage_raw_sha256": "ucis_coverage_ledger_v1.json",
                "legacy_inventory_raw_sha256": "ucis_legacy_inventory_v1.json",
            }.items()
        }
        registry = json.loads((ROOT / "contracts/ptcgdap/ucis_registry_v1.json").read_bytes())
        current_contracts["registry_canonical_sha256"] = hashlib.sha256(canonical_json_v1_bytes(registry)).hexdigest().upper()
        audit = audit_qualification_inputs(self.report, {key: _sha(ROOT / path) for key, path in paths.items()}, current_contracts)
        self.assertEqual(audit["status"], "applicable")
        self.assertTrue(audit["current_inputs_qualified"])
        self.assertEqual(audit["unverified_identities"], [])
        self.assertEqual(audit["changed_identities"], [])

    def test_stale_contract_and_source_inputs_require_requalification(self) -> None:
        for group in ("source_identities", "contract_identities"):
            source = dict(self.report["source_identities"])
            contracts = dict(self.report["contract_identities"])
            changed = source if group == "source_identities" else contracts
            key = next(iter(changed))
            changed[key] = "0" * 64 if changed[key] != "0" * 64 else "F" * 64
            audit = audit_qualification_inputs(self.report, source, contracts)
            self.assertEqual(audit["status"], "requires_requalification")
            self.assertFalse(audit["current_inputs_qualified"])
            self.assertEqual(audit["changed_identities"], [f"{group}.{key}"])
            self.assertEqual(audit["unverified_identities"], [])

    def test_exact_historical_inputs_retain_the_recorded_scope(self) -> None:
        audit = audit_qualification_inputs(self.report, self.report["source_identities"], self.report["contract_identities"])
        self.assertTrue(audit["current_inputs_qualified"])

    def test_missing_inputs_and_tampered_history_fail_closed(self) -> None:
        audit = audit_qualification_inputs(self.report, {}, {})
        self.assertFalse(audit["current_inputs_qualified"])
        self.assertTrue(audit["unverified_identities"])
        self.report["qualification_status"] = "tampered"
        with self.assertRaisesRegex(ValueError, "evidence_hash_invalid"):
            audit_qualification_inputs(self.report, {}, {})

    def test_public_receipt_contains_no_private_locator_or_official_numeric_mapping(self) -> None:
        text = EVIDENCE.read_text(encoding="utf-8").lower()
        for forbidden in (
            "private_oracle_root",
            "program files",
            "appdata",
            "official_card_id_mapping",
            "d:\\\\",
            "c:\\\\",
        ):
            self.assertNotIn(forbidden, text)


if __name__ == "__main__":
    unittest.main()
