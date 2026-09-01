from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_private_cloud_implementation_is_absent_from_public_tree() -> None:
    forbidden = (
        ROOT / "services" / "ptcgdap_replay",
        ROOT / "deploy" / "alipay-cloudrun",
        ROOT / "deploy" / "godot-v18-ladder",
        ROOT / "deploy" / "ptcgdap-platform",
        ROOT / ".ptcgdap-local",
    )
    assert all(not path.exists() for path in forbidden)


def test_public_python_does_not_import_private_service_modules() -> None:
    roots = (ROOT / "scripts", ROOT / "tools", ROOT / "tests")
    violations: list[str] = []
    for source_root in roots:
        if not source_root.exists():
            continue
        for path in source_root.rglob("*.py"):
            if path.resolve() == Path(__file__).resolve():
                continue
            text = path.read_text(encoding="utf-8")
            if "services.ptcgdap_replay" in text:
                violations.append(path.relative_to(ROOT).as_posix())
    assert violations == []
