from __future__ import annotations

import io
from pathlib import Path
import unittest
import warnings
import zipfile

from tools.ptcgdap.inspect_author_strategy_export import inspect_zip_inventory


ROOT = Path(__file__).resolve().parents[2]

REQUIRED_LOCAL_UID_EXPORT_PATHS = [
    "contracts/ptcgdap/local_uid_public_context.schema.json",
    "contracts/ptcgdap/local_uid_public_context_profile.json",
    "contracts/ptcgdap/local_uid_public_context_conformance_vectors.json",
    "contracts/ptcgdap/local_uid_public_context_bundle.json",
    "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd",
    "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd",
    "scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd",
    "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd",
    "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd",
]


def archive_bytes(paths: list[str]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in paths:
            archive.writestr(path, path.encode("ascii"))
    return output.getvalue()


class AuthorStrategyExportInspectionTests(unittest.TestCase):
    def test_complete_export_inventory_is_accepted(self) -> None:
        required = [
            "contracts/ptcgdap/author_strategy_package_profile.json",
            "contracts/ptcgdap/author_strategy_match_host_profile.json",
            "contracts/ptcgdap/author_strategy_live_seam_profile.json",
            "contracts/ptcgdap/author_strategy_release_profile.json",
            "data/ptcgdap/author_strategy_release_trust_store.json",
            "data/ptcgdap/author_strategy_release_approvals.json",
            "data/ptcgdap/author_strategy_device_acceptance_profile.json",
            "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
            "scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd",
            "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
            *REQUIRED_LOCAL_UID_EXPORT_PATHS,
        ]
        report = inspect_zip_inventory(archive_bytes(required), required_paths=required)
        self.assertTrue(report["accepted"])
        self.assertEqual([], report["missing_paths"])
        self.assertEqual(19, report["required_path_count"])
        self.assertEqual(19, report["present_required_path_count"])

    def test_missing_contract_package_or_runtime_fails_closed(self) -> None:
        required = ["contract.json", "builtin.ptcgai", "runtime.gd"]
        report = inspect_zip_inventory(archive_bytes(required[:2]), required_paths=required)
        self.assertFalse(report["accepted"])
        self.assertEqual("export_inventory_missing", report["error_code"])
        self.assertEqual(["runtime.gd"], report["missing_paths"])

    def test_android_assets_prefix_and_compiled_gdscript_are_accepted(self) -> None:
        required = ["contracts/ptcgdap/release.json", "scripts/ai/runtime.gd"]
        value = archive_bytes([
            "assets/contracts/ptcgdap/release.json",
            "assets/scripts/ai/runtime.gdc",
        ])
        report = inspect_zip_inventory(value, required_paths=required, path_prefix="assets/")
        self.assertTrue(report["accepted"], report)
        self.assertEqual(2, report["present_required_path_count"])

    def test_duplicate_or_unsafe_archive_paths_are_rejected(self) -> None:
        output = io.BytesIO()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("safe.json", b"a")
                archive.writestr("safe.json", b"b")
        report = inspect_zip_inventory(output.getvalue(), required_paths=["safe.json"])
        self.assertFalse(report["accepted"])
        self.assertEqual("export_inventory_archive_invalid", report["error_code"])
        unsafe = inspect_zip_inventory(archive_bytes(["../escape"]), required_paths=[])
        self.assertFalse(unsafe["accepted"])
        self.assertEqual("export_inventory_archive_invalid", unsafe["error_code"])


if __name__ == "__main__":
    unittest.main()
