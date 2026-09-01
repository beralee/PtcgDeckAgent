from __future__ import annotations

import base64
from collections import Counter
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_p5_wp3_parent_snapshot import is_p5_wp3_path, p5_wp4_parent_bytes

ROOT = Path(__file__).resolve().parents[2]
P5_WP1_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
P5_WP2_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
_P5_WP2_SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot"
_P5_WP2_MANIFEST = load_json_strict(_P5_WP2_SNAPSHOT_ROOT / "manifest.json")
P5_WP2_PARENT_BYTES = {
    entry["original_path"]: base64.b64decode(
        "".join((_P5_WP2_SNAPSHOT_ROOT / entry["snapshot_path"]).read_text(encoding="ascii").splitlines()),
        validate=True,
    )
    for entry in _P5_WP2_MANIFEST["files"]
}
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p3_wp7/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
EXPECTED_MANIFEST_RAW = "1AAE7C75DA7C19D379EBFA6ED4FDD13970A9820F63748F42ABFA7DDDA2430258"
EXPECTED_MANIFEST_CANONICAL = "AB687451FEFC1C6A44F2DA028D050458428E7FAEC0F93148633B877055F84363"
EXPECTED_PARENT_MANIFEST_RAW = "8BBBE90A68D21C575C3457F1AECC0547A2C1894E6DA2F9D434C141147D87A7CB"
EXPECTED_PARENT_MANIFEST_CANONICAL = "5B20B9D5CC9D8B4167251FFFB9B170DD0FEE8836A28548C28A105C8DA5187EE0"
EXPECTED_PARENT_DIGEST = "8E8D6BC920C55505855A11082F6975D870C09E14972249C9EE45B28D6C0A86E4"
EXPECTED_COUNTS = {"untracked": 558, "deleted": 28, "modified": 1}
P3_WP7_PATHS = {
    "contracts/ptcgdap/shadow_engine_command_applier.schema.json",
    "contracts/ptcgdap/shadow_engine_command_applier_profile.json",
    "contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json",
    "contracts/ptcgdap/shadow_engine_command_applier_bundle.json",
    "scripts/ai/ptcgdap/shadow_engine_command_applier.py",
    "scripts/engine/decision/ShadowEngineCommandApplier.gd",
    "tools/ptcgdap/build_shadow_engine_command_applier_contract.py",
    "tests/ptcgdap/test_shadow_engine_command_applier_contract_builder.py",
    "tests/ptcgdap/test_shadow_engine_command_applier.py",
    "tests/ptcgdap/test_shadow_engine_command_applier_properties.py",
    "tests/ptcgdap/test_p3_wp7_boundaries.py",
    "tests/ptcgdap/test_p3_wp7_parent_snapshot.py",
    "tests/ptcgdap/godot/test_shadow_engine_command_applier.gd",
}
P3_WP8_PATHS = {
    "contracts/ptcgdap/shadow_whole_match_harness.schema.json",
    "contracts/ptcgdap/shadow_whole_match_harness_profile.json",
    "contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json",
    "contracts/ptcgdap/shadow_whole_match_harness_bundle.json",
    "scripts/ai/ptcgdap/shadow_whole_match_harness.py",
    "scripts/engine/decision/ShadowWholeMatchHarness.gd",
    "tools/ptcgdap/build_shadow_whole_match_harness_contract.py",
    "tests/ptcgdap/test_shadow_whole_match_harness_contract_builder.py",
    "tests/ptcgdap/test_shadow_whole_match_harness.py",
    "tests/ptcgdap/test_shadow_whole_match_harness_properties.py",
    "tests/ptcgdap/test_p3_wp8_boundaries.py",
    "tests/ptcgdap/test_p3_wp8_parent_snapshot.py",
    "tests/ptcgdap/godot/test_shadow_whole_match_harness.gd",
}
P4_WP1_PATHS = {
    "contracts/ptcgdap/strategic_context_v18.schema.json",
    "contracts/ptcgdap/strategic_context_v18_profile.json",
    "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json",
    "contracts/ptcgdap/strategic_context_v18_bundle.json",
    "scripts/ai/ptcgdap/strategic_context_v18.py",
    "scripts/ai/ptcgdap/public/StrategicContextV18.gd",
    "tools/ptcgdap/build_strategic_context_v18_contract.py",
    "tests/ptcgdap/test_strategic_context_v18_contract_builder.py",
    "tests/ptcgdap/test_strategic_context_v18.py",
    "tests/ptcgdap/test_strategic_context_v18_properties.py",
    "tests/ptcgdap/test_p4_wp1_boundaries.py",
    "tests/ptcgdap/test_p4_wp1_parent_snapshot.py",
    "tests/ptcgdap/godot/test_strategic_context_v18.gd",
}
P4_WP2_PATHS = {
    "contracts/ptcgdap/strategic_trace_v2.schema.json",
    "contracts/ptcgdap/strategic_trace_v2_profile.json",
    "contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json",
    "contracts/ptcgdap/strategic_trace_v2_bundle.json",
    "scripts/ai/ptcgdap/strategic_trace_v2.py",
    "scripts/ai/ptcgdap/public/StrategicTraceV2.gd",
    "tools/ptcgdap/build_strategic_trace_v2_contract.py",
    "tests/ptcgdap/test_strategic_trace_v2_contract_builder.py",
    "tests/ptcgdap/test_strategic_trace_v2.py",
    "tests/ptcgdap/test_strategic_trace_v2_properties.py",
    "tests/ptcgdap/test_p4_wp2_boundaries.py",
    "tests/ptcgdap/test_p4_wp2_parent_snapshot.py",
    "tests/ptcgdap/godot/test_strategic_trace_v2.gd",
}
P4_WP3_PATHS = {
    "contracts/ptcgdap/restricted_base_graph_executor.schema.json",
    "contracts/ptcgdap/restricted_base_graph_executor_profile.json",
    "contracts/ptcgdap/restricted_base_graph_executor_conformance_vectors.json",
    "contracts/ptcgdap/restricted_base_graph_executor_bundle.json",
    "scripts/ai/ptcgdap/restricted_base_graph_executor.py",
    "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
    "tools/ptcgdap/build_restricted_base_graph_executor_contract.py",
    "tests/ptcgdap/test_restricted_base_graph_executor_contract_builder.py",
    "tests/ptcgdap/test_restricted_base_graph_executor.py",
    "tests/ptcgdap/test_restricted_base_graph_executor_properties.py",
    "tests/ptcgdap/test_p4_wp3_boundaries.py",
    "tests/ptcgdap/test_p4_wp3_parent_snapshot.py",
    "tests/ptcgdap/godot/test_restricted_base_graph_executor.gd",
}
P4_WP4_PATHS = {
    "contracts/ptcgdap/public_deck_adapter.schema.json",
    "contracts/ptcgdap/public_deck_adapter_profile.json",
    "contracts/ptcgdap/public_deck_adapter_conformance_vectors.json",
    "contracts/ptcgdap/public_deck_adapter_bundle.json",
    "scripts/ai/ptcgdap/public_deck_adapter.py",
    "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd",
    "tools/ptcgdap/build_public_deck_adapter_contract.py",
    "tests/ptcgdap/test_public_deck_adapter_contract_builder.py",
    "tests/ptcgdap/test_public_deck_adapter.py",
    "tests/ptcgdap/test_public_deck_adapter_properties.py",
    "tests/ptcgdap/test_p4_wp4_boundaries.py",
    "tests/ptcgdap/test_p4_wp4_parent_snapshot.py",
    "tests/ptcgdap/godot/test_public_deck_adapter.gd",
}
P4_WP5_PATHS = {
    "contracts/ptcgdap/public_base_policy.schema.json",
    "contracts/ptcgdap/public_base_policy_profile.json",
    "contracts/ptcgdap/public_base_policy_conformance_vectors.json",
    "contracts/ptcgdap/public_base_policy_bundle.json",
    "scripts/ai/ptcgdap/public_base_policy.py",
    "scripts/ai/ptcgdap/public/PublicBasePolicy.gd",
    "tools/ptcgdap/build_public_base_policy_contract.py",
    "tests/ptcgdap/test_public_base_policy_contract_builder.py",
    "tests/ptcgdap/test_public_base_policy.py",
    "tests/ptcgdap/test_public_base_policy_properties.py",
    "tests/ptcgdap/test_p4_wp5_boundaries.py",
    "tests/ptcgdap/test_p4_wp5_parent_snapshot.py",
    "tests/ptcgdap/godot/test_public_base_policy.gd",
}
P4_WP6_PATHS = {
    "contracts/ptcgdap/public_policy_budget.schema.json",
    "contracts/ptcgdap/public_policy_budget_profile.json",
    "contracts/ptcgdap/public_policy_budget_conformance_vectors.json",
    "contracts/ptcgdap/public_policy_budget_bundle.json",
    "scripts/ai/ptcgdap/public_policy_budget.py",
    "scripts/ai/ptcgdap/public/PublicPolicyBudget.gd",
    "tools/ptcgdap/build_public_policy_budget_contract.py",
    "tests/ptcgdap/test_public_policy_budget_contract_builder.py",
    "tests/ptcgdap/test_public_policy_budget.py",
    "tests/ptcgdap/test_public_policy_budget_properties.py",
    "tests/ptcgdap/test_p4_wp6_boundaries.py",
    "tests/ptcgdap/test_p4_wp6_parent_snapshot.py",
    "tests/ptcgdap/godot/test_public_policy_budget.gd",
}
P4_WP5_PARENT_BYTES = {
    "tests/ptcgdap/test_p1_wp3_boundaries.py": base64.b64decode(
        "".join((ROOT / "artifacts/ptcgdap/p4_wp5/parent_snapshot/tests__ptcgdap__test_p1_wp3_boundaries.py.base64").read_text(encoding="ascii").split()),
        validate=True,
    ),
    "scripts/ai/ptcgdap/strategic_trace_v2.py": base64.b64decode(
        "".join((ROOT / "artifacts/ptcgdap/p4_wp5/parent_snapshot/scripts__ai__ptcgdap__strategic_trace_v2.py.base64").read_text(encoding="ascii").split()),
        validate=True,
    ),
    "scripts/ai/ptcgdap/public/StrategicTraceV2.gd": base64.b64decode(
        "".join((ROOT / "artifacts/ptcgdap/p4_wp5/parent_snapshot/scripts__ai__ptcgdap__public__StrategicTraceV2.gd.base64").read_text(encoding="ascii").split()),
        validate=True,
    ),
    "tests/ptcgdap/test_strategic_trace_v2_properties.py": base64.b64decode(
        "".join((ROOT / "artifacts/ptcgdap/p4_wp5/parent_snapshot/tests__ptcgdap__test_strategic_trace_v2_properties.py.base64").read_text(encoding="ascii").split()),
        validate=True,
    ),
}
P4_WP1_PARENT_BYTES = {
    "tests/ptcgdap/test_p1_wp3_boundaries.py": base64.b64decode(
        (ROOT / "artifacts/ptcgdap/p4_wp1/parent_snapshot/tests__ptcgdap__test_p1_wp3_boundaries.py.base64")
        .read_text(encoding="ascii").strip(),
        validate=True,
    ),
    "tests/ptcgdap/test_p2_wp3_boundaries.py": base64.b64decode(
        (ROOT / "artifacts/ptcgdap/p4_wp1/parent_snapshot/tests__ptcgdap__test_p2_wp3_boundaries.py.base64")
        .read_text(encoding="ascii").strip(),
        validate=True,
    ),
}

def sha(value: bytes) -> str: return hashlib.sha256(value).hexdigest().upper()

def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw: raise AssertionError(raw)
    path=PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix()!=raw: raise AssertionError(raw)
    return raw

def decode(entry: dict[str, object]) -> bytes:
    name=safe_path(entry["snapshot_path"])
    if "/" in name: raise AssertionError(name)
    encoded_file=(SNAPSHOT_ROOT/name).read_bytes()
    if not encoded_file.endswith(b"\n") or encoded_file.count(b"\n")!=1 or b"\r" in encoded_file: raise AssertionError(name)
    encoded=encoded_file[:-1]; value=base64.b64decode(encoded.decode("ascii"),validate=True)
    if base64.b64encode(value)!=encoded: raise AssertionError(name)
    if len(encoded_file)!=entry["snapshot_file_bytes"] or sha(encoded_file)!=entry["snapshot_file_raw_sha256"]: raise AssertionError(name)
    if len(value)!=entry["bytes"] or sha(value)!=entry["raw_sha256"]: raise AssertionError(name)
    return value

def p3_wp7_parent_bytes(path: str) -> bytes:
    manifest=load_json_strict(MANIFEST_PATH)
    matches=[entry for entry in manifest["files"] if entry["original_path"]==path]
    if len(matches)!=1: raise AssertionError(path)
    return decode(matches[0])

def status() -> list[tuple[str,str]]:
    output=subprocess.run(["git","status","--porcelain=v1","-z","--untracked-files=all"],cwd=ROOT,check=True,capture_output=True).stdout
    records=[]
    for record in output.split(b"\0"):
        if not record: continue
        code=record[:2].decode("ascii"); path=safe_path(record[3:].decode("utf-8").replace("\\","/"))
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path): continue
        if "R" in code or "C" in code: raise AssertionError("rename/copy outside algorithm")
        records.append((code,path))
    return records

class P3Wp7ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw=MANIFEST_PATH.read_bytes()
        if sha(raw)!=EXPECTED_MANIFEST_RAW: raise AssertionError("P3-WP7 snapshot raw drift")
        cls.manifest=load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest))!=EXPECTED_MANIFEST_CANONICAL: raise AssertionError("P3-WP7 snapshot canonical drift")
        cls.entries={safe_path(entry["original_path"]):entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_and_complete(self) -> None:
        self.assertEqual(self.manifest["file_count"],23); self.assertEqual(len(self.entries),23)
        parent=self.manifest["parent"]
        self.assertEqual(parent["manifest_raw_sha256"],EXPECTED_PARENT_MANIFEST_RAW)
        self.assertEqual(parent["manifest_canonical_sha256"],EXPECTED_PARENT_MANIFEST_CANONICAL)
        self.assertEqual(parent["worktree_snapshot_canonical_sha256"],EXPECTED_PARENT_DIGEST)
        self.assertEqual(parent["worktree_status_counts"],EXPECTED_COUNTS)
        self.assertEqual(set(self.manifest["rollback_scope"]["restore_exact_paths"]),set(self.entries))
        self.assertEqual(set(self.manifest["rollback_scope"]["delete_exact_paths"]),P3_WP7_PATHS)
        names=[entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names),len(set(names)))
        self.assertEqual({path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()},{"manifest.json",*names})
        for entry in self.entries.values(): decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p3-wp7-parent-") as temp:
            root=Path(temp)
            for path,entry in self.entries.items():
                destination=root/path; destination.parent.mkdir(parents=True,exist_ok=True); destination.write_bytes(decode(entry))
            self.assertEqual({path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()},set(self.entries))

    def test_virtual_rollback_reproduces_p3_wp6_candidate(self) -> None:
        parent_bytes={path:decode(entry) for path,entry in self.entries.items()}; records=[]; restored=set()
        for code,path in status():
            if path.startswith("artifacts/ptcgdap/p3_wp6/") or path.startswith("artifacts/ptcgdap/p3_wp7/") or path in P3_WP7_PATHS or path.startswith("artifacts/ptcgdap/p3_wp8/") or path in P3_WP8_PATHS or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS: continue
            if path in P4_WP1_PARENT_BYTES: data=P4_WP1_PARENT_BYTES[path]
            elif path in parent_bytes: data=parent_bytes[path]; restored.add(path)
            elif path in P5_WP2_PARENT_BYTES: data=P5_WP2_PARENT_BYTES[path]
            elif "D" in code: data=None
            else: data=p5_wp4_parent_bytes(path, (ROOT/path).read_bytes())
            records.append({"path":path,"status":code,"bytes":None if data is None else len(data),"sha256":None if data is None else sha(data)})
        self.assertEqual(restored,set(parent_bytes)); records.sort(key=lambda item:item["path"])
        counts=Counter("untracked" if item["status"]=="??" else "deleted" if "D" in item["status"] else "modified" for item in records)
        self.assertEqual(len(records),587); self.assertEqual(dict(counts),EXPECTED_COUNTS)
        self.assertEqual(sha(canonical_json_v1_bytes(records)),EXPECTED_PARENT_DIGEST)

if __name__ == "__main__": unittest.main()
