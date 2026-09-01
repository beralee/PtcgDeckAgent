from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "evidence/ptcgdap/ucis/ucis_performance_qualification_v1.json"


class UcisPerformanceQualificationTests(unittest.TestCase):
    def test_runtime_hot_path_is_preloaded_bounded_and_has_no_forbidden_io(self) -> None:
        report = json.loads(EVIDENCE.read_text(encoding="utf-8"))
        self.assertEqual(report["document_type"], "ptcgdap_ucis_performance_qualification_v1")
        self.assertEqual(report["qualification"]["status"], "passed")
        self.assertTrue(report["build_cost"]["qualified"])
        self.assertTrue(report["per_window_runtime_cost"]["qualified"])
        self.assertGreaterEqual(report["build_cost"]["iterations"], 5)
        self.assertGreaterEqual(report["per_window_runtime_cost"]["iterations"], 100)
        audit = report["runtime_operation_audit"]
        self.assertTrue(audit["qualified"])
        self.assertEqual(audit["disk_schema_or_contract_reads"], 0)
        self.assertEqual(audit["subprocess_or_external_forge_calls"], 0)
        self.assertEqual(audit["full_catalog_scans"], 0)
        self.assertTrue(audit["preloaded_registry_lookup"])
        self.assertTrue(audit["current_state_legality_query"])
        self.assertTrue(audit["sparse_public_projection_only"])

    def test_receipt_and_source_identities_are_exact(self) -> None:
        report = json.loads(EVIDENCE.read_text(encoding="utf-8"))
        expected = report.pop("evidence_sha256")
        canonical = json.dumps(
            report, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        self.assertEqual(expected, hashlib.sha256(canonical).hexdigest().upper())
        identities = report["source_identities"]
        self.assertEqual(
            identities["measurement_owner"],
            hashlib.sha256(
                (ROOT / "scripts/ai/ptcgdap/ucis_performance.py").read_bytes()
            ).hexdigest().upper(),
        )
        self.assertEqual(
            identities["runtime_owner"],
            hashlib.sha256((ROOT / "scripts/ai/ptcgdap/ucis.py").read_bytes()).hexdigest().upper(),
        )


if __name__ == "__main__":
    unittest.main()
