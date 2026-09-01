from __future__ import annotations

import base64
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    load_json_strict,
    sha256_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts" / "ptcgdap" / "p1_wp2" / "parent_contract_snapshot"


class ParentContractSnapshotTests(unittest.TestCase):
    def test_exact_parent_bytes_restore_the_p1_wp1_contract_hash(self) -> None:
        manifest = load_json_strict(SNAPSHOT_ROOT / "manifest.json")
        restored: dict[str, object] = {}

        for entry in manifest["files"]:
            encoded = (SNAPSHOT_ROOT / entry["snapshot_path"]).read_text(
                encoding="ascii"
            ).strip()
            exact_bytes = base64.b64decode(encoded, validate=True)
            self.assertEqual(sha256_bytes(exact_bytes), entry["raw_sha256"])
            tree = load_json_bytes_strict(exact_bytes)
            self.assertEqual(
                sha256_bytes(canonical_json_v1_bytes(tree)),
                entry["canonical_sha256"],
            )
            restored[entry["id"]] = tree

        bundle = restored["contract_bundle"]
        self.assertEqual(bundle["contract_id"], manifest["parent_contract_id"])
        self.assertEqual(
            sha256_bytes(canonical_json_v1_bytes(bundle)),
            manifest["parent_contract_canonical_sha256"],
        )
        self.assertEqual(
            {entry["id"]: entry["canonical_sha256"] for entry in bundle["artifacts"]},
            {
                "raw_envelope_schema": manifest["files"][1]["canonical_sha256"],
                "tree_hash_profile": manifest["files"][2]["canonical_sha256"],
                "enum_snapshot": manifest["files"][3]["canonical_sha256"],
                "option_sparse_shapes": manifest["files"][4]["canonical_sha256"],
            },
        )


if __name__ == "__main__":
    unittest.main()
