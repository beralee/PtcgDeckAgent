from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
)
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "GodotSerialRegistry.gd"
)
PROJECTOR_GODOT_RUNTIME = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "GodotObservationProjector.gd"
)
PROJECTOR_PROFILE = (
    ROOT / "contracts" / "ptcgdap" / "godot_observation_projector_profile.json"
)
IDENTITY_PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py"
IDENTITY_GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd"
D044_DEVELOPMENT_OWNER = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "PtcgDAPAuthorDevelopmentBattleOwner.gd"
)
D053_LOCAL_EXECUTOR_OWNER = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "PtcgDAPAuthorLocalExecutorBattleOwner.gd"
)
WORK_PACKAGE = ROOT / "artifacts" / "ptcgdap" / "p2_wp1" / "work_package.json"
CONTRACT_BUNDLE = ROOT / "contracts" / "ptcgdap" / "cabt_contract_bundle.json"
SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
P1_WP3_EVIDENCE = ROOT / "artifacts" / "ptcgdap" / "p1_wp3"
P1_WP3_MANIFEST = P1_WP3_EVIDENCE / "manifest.json"
ARCHITECTURE_DOCS = [
    ROOT / "docs" / "ptcgdap" / "03-target-architecture.md",
    ROOT / "docs" / "ptcgdap" / "04-migration-roadmap.md",
    ROOT / "docs" / "ptcgdap" / "05-validation-promotion-and-rollback.md",
    ROOT / "docs" / "ptcgdap" / "07-decisions-risks-and-open-questions.md",
]

P1_WP3_BUNDLE_RAW_SHA256 = (
    "F1E8269B7E4908660E5BE993F574D433B89FF5134FFE853110751E8BA9777920"
)
P1_WP3_BUNDLE_CANONICAL_SHA256 = (
    "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
)
P1_WP3_MANIFEST_RAW_SHA256 = (
    "CADED8CB12CF2314C872E25132C479CD47F412DD381D4D41389791BD306817EC"
)
P1_WP3_MANIFEST_CANONICAL_SHA256 = (
    "D166EA48A9DC2FE74C6ED3BC6655353EC806C5459C02623C10D4B5AE62DD2005"
)
SOURCE_LOCK_CANONICAL_SHA256 = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _gdscript_without_comments(source: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


class P2Wp1BoundaryTests(unittest.TestCase):
    def test_registry_is_a_host_private_side_table_with_only_identity_dependencies(self) -> None:
        source = REGISTRY.read_text(encoding="utf-8")
        code = _gdscript_without_comments(source)
        forbidden = {
            "AIOpponent",
            "BattleScene",
            "CardIdCatalog",
            "CardData",
            "DirAccess",
            "FileAccess",
            "GameState",
            "GameStateMachine",
            "GodotObservationProjector",
            "HTTPRequest",
            "HTTPClient",
            "ObjectDB",
            "OS.create_process",
            "OS.execute",
            "PacketPeerUDP",
            "RandomNumberGenerator",
            "StreamPeerTCP",
            "WebSocketPeer",
            ".card_data",
            ".get_name(",
            ".get_uid(",
            ".instance_id",
            "D:\\ai\\code\\ptcgabc",
        }
        for marker in forbidden:
            with self.subTest(marker=marker):
                self.assertNotIn(marker, code)

        self.assertIn("weakref(", code)
        self.assertIn("(raw_weak as WeakRef).get_ref()", code)
        self.assertIn("referenced == object", code)
        self.assertNotRegex(code, r"(?:preload|load)\(")
        self.assertNotIn("get_instance_id()", code)

    def test_registry_has_no_live_engine_headless_clone_replay_or_policy_consumer(self) -> None:
        markers = {
            "GodotSerialRegistry",
            "res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd",
        }
        consumers: list[str] = []
        candidate_paths = [
            *(
                path
                for path in (ROOT / "scripts").rglob("*")
                if path.is_file() and path.suffix in {".gd", ".py"}
            ),
            *(
                path
                for path in (ROOT / "scenes").rglob("*")
                if path.is_file() and path.suffix in {".gd", ".tscn"}
            ),
            ROOT / "project.godot",
        ]
        for path in candidate_paths:
            relative = path.relative_to(ROOT).as_posix()
            if relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                continue
            if path in {REGISTRY, PROJECTOR_GODOT_RUNTIME, IDENTITY_PYTHON_RUNTIME, IDENTITY_GODOT_RUNTIME}:
                continue
            source = path.read_text(encoding="utf-8", errors="strict")
            if any(marker in source for marker in markers):
                consumers.append(relative)
        self.assertEqual(
            consumers,
            [
                D044_DEVELOPMENT_OWNER.relative_to(ROOT).as_posix(),
                D053_LOCAL_EXECUTOR_OWNER.relative_to(ROOT).as_posix(),
            ],
            "Only the accepted D044 owner and its D053 versioned host may consume the private registry",
        )
        owner = D044_DEVELOPMENT_OWNER.read_text(encoding="utf-8")
        self.assertIn('OS.get_name() != "Windows"', owner)
        self.assertIn('"development_execution_only": true', owner)
        self.assertIn('"production_ready": false', owner)
        self.assertNotIn("host_pokemon_entity_serial", owner)
        self.assertNotIn("project.godot", owner)
        local_owner = D053_LOCAL_EXECUTOR_OWNER.read_text(encoding="utf-8")
        self.assertIn('extends "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"', local_owner)
        self.assertIn('OS.get_name() != "Windows"', local_owner)
        self.assertIn('audit["policy_engine_object_access"] = false', local_owner)
        self.assertNotIn("host_pokemon_entity_serial", local_owner)

    def test_host_entity_domain_is_absent_from_cabt_contract_and_pure_core(self) -> None:
        inspected = [
            *sorted((ROOT / "contracts" / "ptcgdap").glob("*.json")),
            *sorted((ROOT / "scripts" / "ai" / "ptcgdap" / "cabt").glob("*.gd")),
            *sorted((ROOT / "scripts" / "ai" / "ptcgdap").glob("*.py")),
        ]
        leaks: list[str] = []
        for path in inspected:
            if path in {IDENTITY_PYTHON_RUNTIME, IDENTITY_GODOT_RUNTIME}:
                continue
            if path == PROJECTOR_PROFILE:
                profile = load_json_strict(path)
                self.assertEqual(
                    profile["visibility"]["host_entity_serial"],
                    "never_public",
                )
                self.assertIn(
                    "host_pokemon_entity_serial",
                    profile["wire_root"]["public_forbidden"],
                )
                continue
            text = path.read_text(encoding="utf-8", errors="strict")
            if "host_pokemon_entity" in text or "host_entity_serial" in text:
                leaks.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(
            leaks,
            [],
            "Host-private entity continuity must not enter CABT wire/core contracts",
        )

    def test_authoritative_docs_separate_wire_top_card_from_private_entity(self) -> None:
        combined = "\n".join(path.read_text(encoding="utf-8") for path in ARCHITECTURE_DOCS)
        for marker in (
            "CABT `Pokemon.serial` 不是稳定的 Pokémon lineage ID",
            "`host_pokemon_entity` domain 的 `serial`（概念名 `host_pokemon_entity_serial`）",
            "同一 root 物理卡同时最多支撑一个 active Host entity",
            "P2-WP1 只完成 Godot serial registry 子门，不单独构成 C05 通过",
            "### D015 — 物理卡 serial 与 Host entity continuity 分域",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, combined)
        self.assertNotIn("两位玩家所有实体 serial 全局唯一且进化不漂移", combined)

    def test_p1_wp3_cabt_bundle_remains_byte_for_byte_unchanged(self) -> None:
        raw = CONTRACT_BUNDLE.read_bytes()
        parsed = load_json_strict(CONTRACT_BUNDLE)
        self.assertEqual(_sha256(raw), P1_WP3_BUNDLE_RAW_SHA256)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(parsed)),
            P1_WP3_BUNDLE_CANONICAL_SHA256,
        )

    def test_parent_source_lock_and_p1_evidence_chain_remain_exact(self) -> None:
        source_lock = load_json_strict(SOURCE_LOCK)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(source_lock)),
            SOURCE_LOCK_CANONICAL_SHA256,
        )
        manifest_raw = P1_WP3_MANIFEST.read_bytes()
        manifest = load_json_strict(P1_WP3_MANIFEST)
        self.assertEqual(_sha256(manifest_raw), P1_WP3_MANIFEST_RAW_SHA256)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(manifest)),
            P1_WP3_MANIFEST_CANONICAL_SHA256,
        )
        for record in manifest["evidence"]["evidence_file_hashes"]:
            path = P1_WP3_EVIDENCE / record["path"]
            self.assertTrue(path.is_file(), record["path"])
            self.assertEqual(_sha256(path.read_bytes()), record["raw_sha256"])
            expected_canonical = record.get("canonical_sha256")
            if expected_canonical is not None:
                self.assertEqual(
                    _sha256(canonical_json_v1_bytes(load_json_strict(path))),
                    expected_canonical,
                    record["path"],
                )

    def test_work_package_closes_scope_without_claiming_catalog_firewall_or_alignment(self) -> None:
        work_package = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
        self.assertEqual(work_package["work_package"], "P2-WP1")
        self.assertEqual(work_package["status"], "shadow")
        self.assertEqual(work_package["implementation_state"], "completed")
        self.assertIs(work_package["contracts_changed"], False)
        self.assertEqual(
            work_package["entry_evidence"]["parent_contract_canonical_sha256"],
            P1_WP3_BUNDLE_CANONICAL_SHA256,
        )
        self.assertEqual(
            work_package["files_allowed"]["implementation"],
            ["scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd"],
        )
        self.assertEqual(work_package["alignment_claim"]["A0"], "partial / not claimed")
        for level in ("A1", "A2", "A3", "A4", "A5"):
            self.assertEqual(work_package["alignment_claim"][level], "not evaluated")
        self.assertEqual(
            work_package["next_permitted_work"]["status"],
            "permitted_after_p2_wp1_exit",
        )


if __name__ == "__main__":
    unittest.main()
