from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest


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
        self.assertEqual(scope["total_cards"], 797)
        self.assertEqual(scope["total_effects"], 730)
        self.assertEqual(scope["declared_usable"], 729)
        self.assertEqual(scope["explicit_unsupported"], 1)
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

    def test_receipt_contracts_and_source_owners_are_exact(self) -> None:
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
        contracts = report["contract_identities"]
        self.assertEqual(
            contracts["bundle_raw_sha256"], _sha(ROOT / "contracts/ptcgdap/ucis_bundle_v1.json")
        )
        self.assertEqual(
            contracts["catalog_raw_sha256"],
            _sha(ROOT / "contracts/ptcgdap/ucis_card_catalog_v1.json"),
        )

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
