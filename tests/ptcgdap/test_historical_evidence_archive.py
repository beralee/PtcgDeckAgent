from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT / "tests/ptcgdap/history"


def test_completed_work_package_audits_are_archived_outside_current_gate() -> None:
    archived = sorted(ARCHIVE.glob("history_*.py"))
    assert len(archived) == 82
    assert not list(ARCHIVE.glob("test_*.py"))
    assert all(path.read_bytes() for path in archived)


def test_current_gate_keeps_runtime_and_repository_boundary_owners() -> None:
    required = (
        ROOT / "tests/ptcgdap/test_private_cloud_boundary.py",
        ROOT / "tests/ptcgdap/test_device_manifest_v1.py",
        ROOT / "tests/ptcgdap/test_local_policy_executor_v1.py",
        ROOT / "tests/ptcgdap/test_policy_executor_conformance_v1.py",
    )
    assert all(path.is_file() for path in required)
