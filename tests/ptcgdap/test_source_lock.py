from __future__ import annotations

import hashlib
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    main,
    verify_source_lock,
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class SourceLockVerifierTests(unittest.TestCase):
    def _make_lock(self, root: Path, *, payload: bytes = b"official\r\n") -> Path:
        bundle = root / "bundle"
        bundle.mkdir()
        payload_path = bundle / "payload.bin"
        payload_path.write_bytes(payload)
        candidate_path = root / "candidate.csv"
        candidate_path.write_bytes(b"1\n2\n")
        local_candidate_path = root / "local_candidate.json"
        local_candidate_path.write_bytes(b'{"cards":[1,2]}\n')

        competition_manifest = {
            "file_count": 1,
            "total_bytes": len(payload),
            "files": [
                {
                    "name": "payload.bin",
                    "size": len(payload),
                    "sha256": _sha256(payload),
                }
            ],
        }
        manifest_bytes = (
            json.dumps(competition_manifest, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        manifest_path = bundle / "competition_files.sha256.json"
        manifest_path.write_bytes(manifest_bytes)

        lock = {
            "schema_version": 2,
            "lock_id": "ptcgdap-test-source-lock",
            "hash_modes": {
                "raw_bytes": "SHA-256 over the exact file byte stream",
                "canonical_json_v1": "SHA-256 over duplicate-key-rejected UTF-8 JSON serialized with Unicode object keys sorted by Python code-point order, no insignificant whitespace or ASCII escaping; values are limited to object/list/string/integer/boolean/null (no floats), with no Unicode normalization",
            },
            "auxiliary_hash_policy": "captured_raw_sha256_and_git_blob_lf_sha256_are_diagnostic_only",
            "roots": {
                "fixture": {
                    "captured_path": str(root),
                }
            },
            "official_bundle": {
                "root_id": "fixture",
                "relative_path": "bundle",
                "manifest": manifest_path.name,
                "manifest_sha256": _sha256(manifest_bytes),
                "file_count": 1,
                "total_bytes": len(payload),
                "extra_file_policy": "reject_unlocked_extras_except_reported_pycache_diagnostics",
            },
            "artifacts": [
                {
                    "id": "payload",
                    "root_id": "fixture",
                    "relative_path": "bundle/payload.bin",
                    "hash_mode": "raw_bytes",
                    "sha256": _sha256(payload),
                },
                {
                    "id": "candidate",
                    "root_id": "fixture",
                    "relative_path": "candidate.csv",
                    "hash_mode": "raw_bytes",
                    "sha256": _sha256(candidate_path.read_bytes()),
                    "role": "proposed_vertical_slice_official_deck",
                },
                {
                    "id": "local_candidate",
                    "root_id": "fixture",
                    "relative_path": "local_candidate.json",
                    "hash_mode": "raw_bytes",
                    "sha256": _sha256(local_candidate_path.read_bytes()),
                    "role": "proposed_vertical_slice_local_deck",
                },
            ],
            "candidate_first_vertical_slice": {
                "official_deck_artifact_id": "candidate",
                "local_deck_artifact_id": "local_candidate",
            },
        }
        lock_path = root / "SOURCE_LOCK.json"
        lock_path.write_text(json.dumps(lock), encoding="utf-8")
        return lock_path

    def test_verifies_manifest_entries_and_nested_locked_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = self._make_lock(Path(directory))

            report = verify_source_lock(lock_path)

            self.assertTrue(report.ok, report.to_dict())
            self.assertEqual(report.verified_bundle_entry_count, 1)
            self.assertEqual(report.verified_locked_artifact_count, 3)
            self.assertEqual(report.verified_bundle_bytes, len(b"official\r\n"))

    def test_report_is_bound_to_lock_manifest_and_each_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            expected_lock_hash = _sha256(
                json.dumps(
                    lock,
                    ensure_ascii=False,
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                ).encode("utf-8")
            )
            expected_manifest_hash = lock["official_bundle"]["manifest_sha256"]

            report = verify_source_lock(lock_path)
            payload = report.to_dict()

            self.assertTrue(report.ok, payload)
            self.assertEqual(payload["report_schema_version"], 1)
            self.assertEqual(payload["lock_id"], "ptcgdap-test-source-lock")
            self.assertEqual(payload["source_lock_canonical_sha256"], expected_lock_hash)
            self.assertEqual(payload["verified_manifest_sha256"], expected_manifest_hash)
            self.assertEqual(
                {
                    (item["artifact_id"], item["status"], item["actual_sha256"])
                    for item in payload["artifact_results"]
                },
                {
                    (artifact["id"], "verified", artifact["sha256"])
                    for artifact in lock["artifacts"]
                },
            )
            digest_scope = {
                key: payload[key]
                for key in (
                    "report_schema_version",
                    "verifier_version",
                    "ok",
                    "lock_id",
                    "source_lock_canonical_sha256",
                    "schema_version",
                    "verified_manifest_sha256",
                    "verified_bundle_entry_count",
                    "verified_bundle_bytes",
                    "verified_locked_artifact_count",
                    "artifact_results",
                )
            }
            digest_scope["issue_identities"] = []
            self.assertEqual(
                payload["authoritative_result_sha256"],
                _sha256(canonical_json_v1_bytes(digest_scope)),
            )
            (root / "candidate.csv").write_bytes(b"drift\n")
            drifted_digest = verify_source_lock(lock_path).to_dict()[
                "authoritative_result_sha256"
            ]
            self.assertNotEqual(drifted_digest, payload["authoritative_result_sha256"])

    def test_json_cli_emits_the_bound_report(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = self._make_lock(Path(directory))
            expected_lock_hash = verify_source_lock(lock_path).source_lock_canonical_sha256
            output = io.StringIO()

            with redirect_stdout(output):
                exit_code = main(
                    [
                        "--lock",
                        str(lock_path),
                        "--expect-lock-sha256",
                        str(expected_lock_hash),
                        "--format",
                        "json",
                    ]
                )

            payload = json.loads(output.getvalue())
            self.assertEqual(exit_code, 0)
            self.assertEqual(payload["report_schema_version"], 1)
            self.assertEqual(payload["verifier_version"], "ptcgdap-source-lock-verifier-v1")
            self.assertEqual(payload["lock_id"], "ptcgdap-test-source-lock")
            self.assertEqual(len(payload["artifact_results"]), 3)

    def test_cli_expected_lock_hash_is_a_real_trust_anchor_and_text_prints_digest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = self._make_lock(Path(directory))
            output = io.StringIO()
            with redirect_stdout(output):
                exit_code = main(
                    [
                        "--lock",
                        str(lock_path),
                        "--expect-lock-sha256",
                        "0" * 64,
                    ]
                )

            self.assertEqual(exit_code, 1)
            self.assertIn("authoritative result:", output.getvalue())
            self.assertIn("expected_source_lock_sha256_mismatch", output.getvalue())

    def test_hashes_raw_bytes_and_detects_line_ending_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            (root / "bundle" / "payload.bin").write_bytes(b"official\n")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("sha256_mismatch", {issue.code for issue in report.issues})

    def test_rejects_manifest_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            manifest_path = root / "bundle" / "competition_files.sha256.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"][0]["name"] = "../candidate.csv"
            manifest_bytes = json.dumps(manifest).encode("utf-8")
            manifest_path.write_bytes(manifest_bytes)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["official_bundle"]["manifest_sha256"] = _sha256(manifest_bytes)
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("unsafe_manifest_path", {issue.code for issue in report.issues})

    def test_root_override_replaces_captured_machine_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["roots"]["fixture"]["captured_path"] = "Z:\\not-present"
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path, root_overrides={"fixture": root})

            self.assertTrue(report.ok, report.to_dict())

    def test_untrusted_manifest_is_not_used_to_resolve_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            manifest_path = root / "bundle" / "competition_files.sha256.json"
            manifest_path.write_bytes(manifest_path.read_bytes() + b" ")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertEqual(report.verified_bundle_entry_count, 0)
            self.assertIn("manifest_sha256_mismatch", {issue.code for issue in report.issues})

    def test_duplicate_json_keys_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = Path(directory) / "SOURCE_LOCK.json"
            lock_path.write_text('{"schema_version":2,"schema_version":2}', encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("source_lock_parse_error", {issue.code for issue in report.issues})

    def test_utf8_bom_is_rejected_by_the_strict_json_loader(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            lock_path = Path(directory) / "SOURCE_LOCK.json"
            lock_path.write_bytes(b"\xef\xbb\xbf{}")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("source_lock_parse_error", {issue.code for issue in report.issues})

    def test_nonstandard_nan_json_constant_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["invalid_number"] = float("nan")
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("source_lock_parse_error", {issue.code for issue in report.issues})

    def test_manifest_names_cannot_collide_after_casefold(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            manifest_path = root / "bundle" / "competition_files.sha256.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            second = dict(manifest["files"][0])
            second["name"] = second["name"].upper()
            manifest["files"].append(second)
            manifest["file_count"] = 2
            manifest["total_bytes"] *= 2
            manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
            manifest_path.write_bytes(manifest_bytes)
            lock["official_bundle"]["manifest_sha256"] = _sha256(manifest_bytes)
            lock["official_bundle"]["file_count"] = 2
            lock["official_bundle"]["total_bytes"] *= 2
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("casefold_manifest_name_collision", {issue.code for issue in report.issues})

    def test_unknown_schema_version_requires_review(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["schema_version"] = 99
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("unsupported_schema_version", {issue.code for issue in report.issues})

    def test_canonical_json_artifact_is_portable_across_line_endings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            portable_path = root / "portable.json"
            portable_path.write_bytes(b'{\r\n  "b": 2,\r\n  "a": 1\r\n}\r\n')
            canonical = json.dumps(
                {"a": 1, "b": 2}, separators=(",", ":"), sort_keys=True
            ).encode("utf-8")
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["artifacts"].append(
                {
                    "id": "portable_json",
                    "root_id": "fixture",
                    "relative_path": "portable.json",
                    "hash_mode": "canonical_json_v1",
                    "sha256": _sha256(canonical),
                }
            )
            lock_path.write_text(json.dumps(lock), encoding="utf-8")
            portable_path.write_bytes(b'{"a":1,"b":2}\n')

            report = verify_source_lock(lock_path)

            self.assertTrue(report.ok, report.to_dict())

    def test_canonical_json_v1_rejects_floating_point_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            portable_path = root / "portable.json"
            portable_path.write_text('{"value":1.5}', encoding="utf-8")
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["artifacts"].append(
                {
                    "id": "portable_json",
                    "root_id": "fixture",
                    "relative_path": "portable.json",
                    "hash_mode": "canonical_json_v1",
                    "sha256": _sha256(b'{"value":1.5}'),
                }
            )
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("artifact_read_error", {issue.code for issue in report.issues})

    def test_canonical_json_v1_rejects_unsafe_integers_noncharacters_and_host_subtypes(self) -> None:
        class StringSubtype(str):
            pass

        class IntegerSubtype(int):
            pass

        invalid_values = (
            {"value": 2**53},
            {"value": -(2**53)},
            {"value": "\ufdd0"},
            {"\U0001ffff": "value"},
            {"value": StringSubtype("host-string")},
            {"value": IntegerSubtype(7)},
        )
        for value in invalid_values:
            with self.subTest(value=repr(value)):
                with self.assertRaises(ValueError):
                    canonical_json_v1_bytes(value)

        cyclic: list[object] = []
        cyclic.append(cyclic)
        with self.assertRaises(ValueError):
            canonical_json_v1_bytes(cyclic)

        self.assertEqual(
            canonical_json_v1_bytes({"min": -(2**53) + 1, "max": 2**53 - 1}),
            b'{"max":9007199254740991,"min":-9007199254740991}',
        )

    def test_invalid_manifest_size_is_reported_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            manifest_path = root / "bundle" / "competition_files.sha256.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"][0]["size"] = "eleven"
            manifest_bytes = json.dumps(manifest).encode("utf-8")
            manifest_path.write_bytes(manifest_bytes)
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
            lock["official_bundle"]["manifest_sha256"] = _sha256(manifest_bytes)
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("invalid_bundle_entry_size", {issue.code for issue in report.issues})

    def test_bundle_and_manifest_metadata_require_non_boolean_integers(self) -> None:
        cases = (
            ("bundle", "file_count", 1.0, "invalid_bundle_file_count"),
            ("bundle", "total_bytes", True, "invalid_bundle_total_bytes"),
            ("manifest", "file_count", 1.0, "invalid_manifest_file_count"),
            ("manifest", "total_bytes", True, "invalid_manifest_total_bytes"),
        )
        for target, field, value, expected_code in cases:
            with self.subTest(target=target, field=field), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                lock_path = self._make_lock(root)
                lock = json.loads(lock_path.read_text(encoding="utf-8"))
                if target == "bundle":
                    lock["official_bundle"][field] = value
                else:
                    manifest_path = root / "bundle" / "competition_files.sha256.json"
                    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                    manifest[field] = value
                    manifest_bytes = json.dumps(manifest).encode("utf-8")
                    manifest_path.write_bytes(manifest_bytes)
                    lock["official_bundle"]["manifest_sha256"] = _sha256(manifest_bytes)
                lock_path.write_text(json.dumps(lock), encoding="utf-8")

                report = verify_source_lock(lock_path)

                self.assertFalse(report.ok)
                self.assertIn(expected_code, {issue.code for issue in report.issues})

    def test_lock_id_extra_policy_and_candidate_refs_are_required(self) -> None:
        cases = (
            ("missing_lock_id", "invalid_lock_id"),
            ("missing_hash_modes", "invalid_hash_mode_contract"),
            ("missing_auxiliary_policy", "invalid_auxiliary_hash_policy"),
            ("unknown_extra_policy", "unsupported_extra_file_policy"),
            ("missing_candidate_ref", "invalid_candidate_artifact_ref"),
            ("unknown_candidate_ref", "unresolved_candidate_artifact_ref"),
            ("duplicate_candidate_ref", "duplicate_candidate_artifact_ref"),
            ("swapped_candidate_refs", "candidate_artifact_role_mismatch"),
        )
        for mutation, expected_code in cases:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                lock_path = self._make_lock(root)
                lock = json.loads(lock_path.read_text(encoding="utf-8"))
                if mutation == "missing_lock_id":
                    del lock["lock_id"]
                elif mutation == "missing_hash_modes":
                    del lock["hash_modes"]
                elif mutation == "missing_auxiliary_policy":
                    del lock["auxiliary_hash_policy"]
                elif mutation == "unknown_extra_policy":
                    lock["official_bundle"]["extra_file_policy"] = "silently_ignore"
                elif mutation == "missing_candidate_ref":
                    del lock["candidate_first_vertical_slice"]["local_deck_artifact_id"]
                elif mutation == "unknown_candidate_ref":
                    lock["candidate_first_vertical_slice"]["local_deck_artifact_id"] = "missing"
                elif mutation == "swapped_candidate_refs":
                    lock["candidate_first_vertical_slice"]["official_deck_artifact_id"] = "local_candidate"
                    lock["candidate_first_vertical_slice"]["local_deck_artifact_id"] = "candidate"
                else:
                    lock["candidate_first_vertical_slice"]["local_deck_artifact_id"] = "candidate"
                lock_path.write_text(json.dumps(lock), encoding="utf-8")

                report = verify_source_lock(lock_path)

                self.assertFalse(report.ok)
                self.assertIn(expected_code, {issue.code for issue in report.issues})

    def test_manifest_is_not_extra_and_only_pycache_is_a_host_diagnostic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            baseline_digest = verify_source_lock(lock_path).to_dict()[
                "authoritative_result_sha256"
            ]
            cache_dir = root / "bundle" / "sample" / "__pycache__"
            cache_dir.mkdir(parents=True)
            cache_path = cache_dir / "module.cpython-311.pyc"
            cache_path.write_bytes(b"host cache")
            cache_only_report = verify_source_lock(lock_path)
            self.assertTrue(cache_only_report.ok, cache_only_report.to_dict())
            self.assertEqual(
                cache_only_report.to_dict()["authoritative_result_sha256"],
                baseline_digest,
            )
            note_path = root / "bundle" / "local-note.txt"
            note_path.write_text("diagnostic", encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok, report.to_dict())
            self.assertEqual(
                report.host_diagnostic_files,
                ["sample/__pycache__/module.cpython-311.pyc"],
            )
            self.assertEqual(report.extra_bundle_files, ["local-note.txt"])
            self.assertNotIn("competition_files.sha256.json", report.extra_bundle_files)
            self.assertIn("unlocked_bundle_file", {issue.code for issue in report.issues})
            self.assertNotEqual(report.to_dict()["authoritative_result_sha256"], baseline_digest)

    def test_every_unlocked_non_cache_file_fails_verification(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            (root / "bundle" / "rogue.py").write_text("print('unexpected')\n", encoding="utf-8")

            report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("unlocked_bundle_file", {issue.code for issue in report.issues})

    def test_root_resolution_and_recursive_json_fail_as_reports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock_path = self._make_lock(root)
            with mock.patch(
                "scripts.ai.ptcgdap.source_lock._resolve_roots",
                side_effect=RecursionError("synthetic recursion"),
            ):
                report = verify_source_lock(lock_path)

            self.assertFalse(report.ok)
            self.assertIn("root_resolution_error", {issue.code for issue in report.issues})

            with mock.patch(
                "scripts.ai.ptcgdap.source_lock.load_json_strict",
                side_effect=RecursionError("synthetic recursive JSON"),
            ):
                recursive_report = verify_source_lock(lock_path)
            self.assertFalse(recursive_report.ok)
            self.assertIn(
                "source_lock_parse_error",
                {issue.code for issue in recursive_report.issues},
            )

    def test_duplicate_cli_root_override_is_rejected(self) -> None:
        stderr = io.StringIO()
        with redirect_stderr(stderr), self.assertRaises(SystemExit) as raised:
            main(
                [
                    "--lock",
                    "unused.json",
                    "--root",
                    "fixture=C:\\one",
                    "--root",
                    "fixture=C:\\two",
                ]
            )

        self.assertEqual(raised.exception.code, 2)
        self.assertIn("duplicate --root override", stderr.getvalue())

    def test_cli_report_serialization_failure_is_stable_and_fails_closed(self) -> None:
        report = mock.Mock(
            ok=True,
            lock_id="synthetic-lock",
            source_lock_canonical_sha256="A" * 64,
            verified_manifest_sha256="B" * 64,
            verified_bundle_entry_count=1,
            verified_locked_artifact_count=1,
            extra_bundle_files=[],
            host_diagnostic_files=[],
        )
        report.to_dict.side_effect = ValueError("synthetic serialization failure")
        stdout = io.StringIO()

        with mock.patch(
            "scripts.ai.ptcgdap.source_lock.verify_source_lock",
            return_value=report,
        ), redirect_stdout(stdout):
            exit_code = main(["--lock", "unused.json"])

        self.assertEqual(exit_code, 1)
        self.assertIn("FAIL", stdout.getvalue())
        self.assertIn("authoritative result: unavailable", stdout.getvalue())
        self.assertIn("report_serialization_error", stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
