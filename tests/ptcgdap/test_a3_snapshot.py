from __future__ import annotations

from pathlib import Path
import unittest

from scripts.ai.ptcgdap.a3_snapshot import A3SnapshotCanonicalizer, A3SnapshotError


ROOT = Path(__file__).resolve().parents[2]


class A3SnapshotTests(unittest.TestCase):
    def test_missing_null_zero_and_ordered_arrays_remain_distinct(self) -> None:
        owner = A3SnapshotCanonicalizer.load_default(ROOT)
        snapshot = owner.canonicalize({
            "lifecycle": None,
            "damage": 0,
            "incremental_logs": [{"ordinal": 2}, {"ordinal": 1}],
        })
        self.assertEqual(snapshot["fields"]["lifecycle"]["presence"], "null")
        self.assertEqual(snapshot["fields"]["damage"]["value"], 0)
        self.assertEqual(snapshot["fields"]["status"]["presence"], "missing")
        self.assertEqual(snapshot["fields"]["incremental_logs"]["value"], [{"ordinal": 2}, {"ordinal": 1}])

    def test_diagnostic_values_are_hash_only_and_unavailable_is_explicit(self) -> None:
        owner = A3SnapshotCanonicalizer.load_default(ROOT)
        snapshot = owner.canonicalize(
            {},
            trusted_diagnostic_snapshot={"entity_serial": {"secret": 99}},
            unavailable_diagnostics=("rng_cursor",),
        )
        serial = snapshot["diagnostics"]["entity_serial"]
        self.assertEqual(serial["classification"], "diagnostic-only")
        self.assertNotIn("value", serial)
        self.assertEqual(len(serial["private_value_sha256"]), 64)
        self.assertEqual(snapshot["diagnostics"]["rng_cursor"]["classification"], "unavailable")

    def test_unknown_public_or_private_fields_fail_closed(self) -> None:
        owner = A3SnapshotCanonicalizer.load_default(ROOT)
        with self.assertRaisesRegex(A3SnapshotError, "unknown_field"):
            owner.canonicalize({"opponent_hidden_hand": [1]})
        with self.assertRaisesRegex(A3SnapshotError, "unknown_field"):
            owner.canonicalize({}, trusted_diagnostic_snapshot={"credential": "x"})


if __name__ == "__main__":
    unittest.main()
