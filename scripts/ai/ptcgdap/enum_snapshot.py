from __future__ import annotations

import ast
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Mapping

from .source_lock import load_json_strict, resolve_locked_artifact


@dataclass(frozen=True)
class EnumSnapshotIssue:
    code: str
    detail: str
    expected: Any = None
    actual: Any = None


@dataclass
class EnumSnapshotReport:
    enum_count: int = 0
    issues: list[EnumSnapshotIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.issues

    def add(self, code: str, detail: str, expected: Any = None, actual: Any = None) -> None:
        self.issues.append(EnumSnapshotIssue(code, detail, expected, actual))

    def to_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "enum_count": self.enum_count,
            "issues": [asdict(issue) for issue in self.issues],
        }


def extract_int_enums(api_path: str | Path) -> dict[str, dict[str, int]]:
    path = Path(api_path)
    tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    result: dict[str, dict[str, int]] = {}
    for node in tree.body:
        if not isinstance(node, ast.ClassDef):
            continue
        if not any(isinstance(base, ast.Name) and base.id == "IntEnum" for base in node.bases):
            continue
        values: dict[str, int] = {}
        for statement in node.body:
            if not isinstance(statement, (ast.Assign, ast.AnnAssign)):
                continue
            targets = statement.targets if isinstance(statement, ast.Assign) else [statement.target]
            value = statement.value
            if isinstance(value, ast.Tuple) and len(value.elts) == 1:
                value = value.elts[0]
            named_targets = [target.id for target in targets if isinstance(target, ast.Name)]
            if not named_targets:
                raise ValueError(f"unsupported IntEnum assignment target in {node.name}")
            if not isinstance(value, ast.Constant) or isinstance(value.value, bool) or not isinstance(value.value, int):
                raise ValueError(
                    f"unsupported non-literal IntEnum value in {node.name}: {named_targets}"
                )
            for target in targets:
                if isinstance(target, ast.Name):
                    values[target.id] = value.value
        result[node.name] = values
    return result


def extract_cpp_enum(path: str | Path, enum_name: str) -> dict[str, int]:
    text = Path(path).read_text(encoding="utf-8-sig")
    match = re.search(
        rf"enum\s+class\s+{re.escape(enum_name)}\b[^{{]*{{(?P<body>.*?)}}\s*;",
        text,
        flags=re.DOTALL,
    )
    if match is None:
        raise ValueError(f"C++ enum not found: {enum_name}")
    body = re.sub(r"//[^\r\n]*", "", match.group("body"))
    result: dict[str, int] = {}
    current = -1
    for raw_member in body.split(","):
        member = raw_member.strip()
        if not member:
            continue
        name, separator, raw_value = member.partition("=")
        name = name.strip()
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) is None:
            raise ValueError(f"unsupported C++ enum member: {member!r}")
        current = int(raw_value.strip(), 0) if separator else current + 1
        result[name] = current
    return result


def verify_enum_snapshot(
    snapshot_path: str | Path,
    source_lock_path: str | Path,
    *,
    root_overrides: Mapping[str, str | Path] | None = None,
) -> EnumSnapshotReport:
    report = EnumSnapshotReport()
    try:
        snapshot = load_json_strict(Path(snapshot_path))
        source_lock = load_json_strict(Path(source_lock_path))
        if not isinstance(snapshot, dict) or not isinstance(source_lock, dict):
            raise ValueError("snapshot and source lock roots must be objects")
        if type(snapshot.get("schema_version")) is not int or snapshot.get("schema_version") != 1:
            raise ValueError(f"unsupported enum snapshot schema: {snapshot.get('schema_version')!r}")
        artifact_id = snapshot.get("source_artifact_id")
        if not isinstance(artifact_id, str):
            raise ValueError("source_artifact_id must be a string")
        if snapshot.get("source_lock_id") != source_lock.get("lock_id"):
            raise ValueError("enum snapshot source_lock_id does not match SOURCE_LOCK")
        api_path, artifact = resolve_locked_artifact(
            source_lock,
            artifact_id,
            root_overrides=root_overrides,
        )
        actual_source_hash = str(artifact.get("sha256")).upper()
        locked_source_hash = artifact.get("sha256")
        snapshot_source_hash = snapshot.get("source_sha256")
        if actual_source_hash != str(snapshot_source_hash).upper():
            report.add("snapshot_source_hash_mismatch", "snapshot points at a different source", snapshot_source_hash, actual_source_hash)
            return report
        actual_enums = extract_int_enums(api_path)
        expected_enums = snapshot.get("enums")
        if not isinstance(expected_enums, dict):
            raise ValueError("enum snapshot enums must be an object")
        if actual_enums != expected_enums:
            report.add("enum_snapshot_mismatch", "AST enum literals differ from the checked snapshot", expected_enums, actual_enums)
        engine_artifact_id = snapshot.get("engine_source_artifact_id")
        if not isinstance(engine_artifact_id, str):
            raise ValueError("engine_source_artifact_id must be a string")
        engine_path, engine_artifact = resolve_locked_artifact(
            source_lock,
            engine_artifact_id,
            root_overrides=root_overrides,
        )
        if snapshot.get("engine_source_sha256") != engine_artifact.get("sha256"):
            report.add(
                "engine_source_hash_mismatch",
                "engine-only enum source differs from SOURCE_LOCK",
                snapshot.get("engine_source_sha256"),
                engine_artifact.get("sha256"),
            )
        cpp_area = extract_cpp_enum(engine_path, "AreaType")
        actual_engine_values = {
            str(cpp_area[name]): name
            for name in ("Playing", "DeckBottom")
        }
        engine_source_values = snapshot.get("engine_source_values")
        if not isinstance(engine_source_values, dict):
            raise ValueError("engine_source_values must be an object")
        if engine_source_values.get("AreaType") != actual_engine_values:
            report.add(
                "engine_enum_snapshot_mismatch",
                "locked engine-only AreaType literals differ",
                engine_source_values.get("AreaType"),
                actual_engine_values,
            )
        locked_engine_metadata = snapshot.get("locked_engine_only_observations")
        if not isinstance(locked_engine_metadata, dict):
            raise ValueError("locked_engine_only_observations must be an object")
        locked_engine = locked_engine_metadata.get("AreaType")
        expected_engine_labels = {
            str(cpp_area["Playing"]): "PLAYING_INTERNAL",
            str(cpp_area["DeckBottom"]): "DECK_BOTTOM_INTERNAL",
        }
        if locked_engine != expected_engine_labels:
            report.add(
                "engine_authority_metadata_mismatch",
                "engine-only labels must exactly match the reviewed C++ values",
                expected_engine_labels,
                locked_engine,
            )
        official_area_values = set(actual_enums.get("AreaType", {}).values())
        engine_only_values = {int(value) for value in actual_engine_values}
        if official_area_values.intersection(engine_only_values):
            report.add(
                "engine_enum_authority_overlap",
                "engine-only AreaType values must not overlap official SDK ordinals",
                None,
                sorted(official_area_values.intersection(engine_only_values)),
            )
        if snapshot.get("unknown_value_policy") != "preserve_raw_integer_fail_closed_contract_only":
            report.add("unknown_value_policy_mismatch", "unknown enum policy declaration changed")
        if snapshot.get("authority_states") != ["official_known", "locked_engine_only", "unknown_future"]:
            report.add("authority_states_mismatch", "enum authority states changed")
        append_only = snapshot.get("append_only_warning")
        if not isinstance(append_only, dict) or append_only.get("SelectContext") is not True or append_only.get("LogType") is not True:
            report.add("append_only_warning_mismatch", "SelectContext and LogType must remain append-only warnings")
        report.enum_count = len(actual_enums)
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, SyntaxError, json.JSONDecodeError) as exc:
        report.add("enum_snapshot_error", str(exc))
    return report
