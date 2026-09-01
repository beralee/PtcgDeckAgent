from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


SOURCE_DECK_ID = 575479
SOURCE_DECK_PATH = Path("data/bundled_user/decks/575479.json")
SOURCE_DECK_RAW_SHA256 = "52EEDC29650D902A356E7B7775B72C6956D52DFE3D2D06C5FEDC66F7C04625C0"
SOURCE_DECK_CANONICAL_SHA256 = "A5DDA6FF8F1C640FCFDF71436F7C7F0006FF139CEEEA4BDF16EAB41BD522818C"
PACKAGE_ID = "ptcgdap.gholdengo-palkia-575479.windows-local"
PACKAGE_VERSION = "0.1.2"
CARD_ID_DOMAIN = "godot_local_card_uid_v1"
EXPECTED_CARD_ROWS = (
    ("CS5.5C_060", 1, "2f68195255c863293be4fad262bf23d2"),
    ("CS5DC_138", 2, "4f53ab6bf158fd1a8869ae037f4a0d6d"),
    ("CS5aC_105", 1, "d8e81bf574a9d7a0f42ff33e15b0522c"),
    ("CS5aC_113", 1, "66b2f1d77328b6578b1bf0d58d98f66b"),
    ("CS5bC_051", 1, "720fd5ca597f96db0f5f00d3ac16febb"),
    ("CS5bC_052", 1, "04653d073ffc3ca2202746e4f9aebabd"),
    ("CS5bC_111", 1, "5a80f8eb94c6fcc27c475c10a63cf856"),
    ("CS6.5C_020", 1, "09445b8c32fd4abef4230ebcdc964096"),
    ("CS6bC_123", 1, "8f655fea1f90164bfbccb7a95c223e17"),
    ("CSNC_003", 1, "63cf95979c653e65cbd502a4c0d3fbdd"),
    ("CSV1C_109", 1, "c9c948169525fbb3dce70c477ec7a90a"),
    ("CSV1C_111", 1, "a47d5a8ed00e14a2146fc511745d23b5"),
    ("CSV1C_112", 2, "a337ed34a45e63c6d21d98c3d8e0cb6e"),
    ("CSV1C_113", 1, "7c0b20e121c9d0e0d2d8a43524f7494e"),
    ("CSV3C_115", 4, "ff7e5670880217816bcf5d34388624cd"),
    ("CSV3C_123", 1, "af514f82d182aeae5327b2c360df703d"),
    ("CSV4C_063", 3, "8bcc42363d38245b8b408cfaafa1ba30"),
    ("CSV4C_089", 4, "07f01f4f21033a1bbc058e4af555420a"),
    ("CSV6C_115", 3, "e366f56ecd3f805a28294109a1a37453"),
    ("CSV6C_125", 1, "73d5f46ecf3a6d71b23ce7bc1a28d4f4"),
    ("CSV7C_177", 3, "f866dfee26cd6b0dbbb52b74438d0a59"),
    ("CSV7C_180", 1, "4ec261453212280d0eb03ed8254ca97f"),
    ("CSV7C_191", 3, "1b5fc2ed2bce98ef93457881c05354e2"),
    ("CSV7C_202", 2, "59e1e1faa3ceb8c3ae801979a499532e"),
    ("CSVE1C_MET", 4, "4557c01497b81767fdaa0004089ecfb3"),
    ("CSVE1C_WAT", 6, "0cf075ae61b8a0b4e9151e5146c3aa26"),
    ("CSVH1C_034", 1, "8538726d6cdfad2fa3ca5f4b462c12c5"),
    ("CSVH1C_043", 4, "1af63a7e2cb7a79215474ad8db8fd8fd"),
    ("CSVH1C_051", 1, "0a9bdf265647461dd5c6c827ffc19e61"),
    ("CSVH1aC_023", 2, "8e1fa2c9018db938084c94c7c970d419"),
    ("SVP_105", 1, "46e0b7c128aeca65657bf19f3ae8fb91"),
)
WEIGHTS = bytes.fromhex(
    "505443474441502D574549474854532D563100000000000000803E000080BE0000003F000000BF0000803F000080BF0000003E"
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def build_deck_csv(manifest: dict[str, object]) -> bytes:
    cards = manifest.get("cards")
    if type(cards) is not list:
        raise ValueError("invalid_deck_cards")
    lines = ["local_card_uid,count"]
    for row in cards:
        if type(row) is not dict:
            raise ValueError("invalid_deck_row")
        lines.append(f"{row['local_card_uid']},{row['count']}")
    return ("\n".join(lines) + "\n").encode("ascii")


def build_deck_manifest(root: Path = ROOT) -> dict[str, object]:
    source_path = Path(root) / SOURCE_DECK_PATH
    source_bytes = source_path.read_bytes()
    source = load_json_strict(source_path)
    actual_rows = tuple(
        sorted(
            (
                (f"{row['set_code']}_{row['card_index']}", row["count"], row["effect_id"])
                for row in source.get("cards", [])
            ),
            key=lambda row: row[0].encode("ascii"),
        )
    )
    if (
        _sha(source_bytes) != SOURCE_DECK_RAW_SHA256
        or _sha(canonical_json_v1_bytes(source)) != SOURCE_DECK_CANONICAL_SHA256
        or source.get("id") != SOURCE_DECK_ID
        or source.get("total_cards") != 60
        or actual_rows != EXPECTED_CARD_ROWS
    ):
        raise ValueError("source_deck_drift")

    entries: list[dict[str, object]] = []
    for uid, count, effect_id in EXPECTED_CARD_ROWS:
        set_code, card_index = uid.rsplit("_", 1)
        card_path = Path(root) / "data/bundled_user/cards" / f"{uid}.json"
        card_bytes = card_path.read_bytes()
        card = load_json_strict(card_path)
        if (
            card.get("set_code") != set_code
            or card.get("card_index") != card_index
            or card.get("effect_id") != effect_id
            or type(card.get("card_type")) is not str
            or type(card.get("stage", "")) is not str
        ):
            raise ValueError(f"source_card_drift:{uid}")
        entries.append(
            {
                "local_card_uid": uid,
                "set_code": set_code,
                "card_index": card_index,
                "count": count,
                "card_type": card["card_type"],
                "stage": card.get("stage", ""),
                "effect_id": effect_id,
                "source_raw_sha256": _sha(card_bytes),
                "source_canonical_sha256": _sha(canonical_json_v1_bytes(card)),
            }
        )
    manifest: dict[str, object] = {
        "document_type": "deck_manifest_windows_local_v1",
        "schema_version": 1,
        "deck_id": "gholdengo-palkia.575479",
        "card_id_domain": CARD_ID_DOMAIN,
        "card_count": 60,
        "unique_card_count": len(entries),
        "deck_csv_sha256": "0" * 64,
        "cabt_exportable": False,
        "platform_scope": ["windows"],
        "source_deck_id": SOURCE_DECK_ID,
        "source_deck_raw_sha256": SOURCE_DECK_RAW_SHA256,
        "source_deck_canonical_sha256": SOURCE_DECK_CANONICAL_SHA256,
        "cards": entries,
    }
    manifest["deck_csv_sha256"] = _sha(build_deck_csv(manifest))
    return manifest


def _predicate(
    *,
    select_type_raw: int | None = None,
    select_context_raw: int | None = None,
    option_type_raw: int | None = None,
    option_card_id: str | None = None,
    acting_hand_card_id: str | None = None,
    acting_active_card_id: str | None = None,
) -> dict[str, object]:
    return {
        "select_type_raw": select_type_raw,
        "select_context_raw": select_context_raw,
        "option_type_raw": option_type_raw,
        "option_card_id": option_card_id,
        "option_player_index": None,
        "acting_hand_card_id": acting_hand_card_id,
        "acting_active_card_id": acting_active_card_id,
    }


def _rule(rule_id: str, stage: str, priority: int, predicate: dict[str, object]) -> dict[str, object]:
    return {
        "rule_id": rule_id,
        "operator": "macro_proposal",
        "reason_code": "public_macro_proposal",
        "goal_stage": stage,
        "priority": priority,
        "predicate": predicate,
    }


def build_adapter() -> dict[str, object]:
    rules = [
        _rule("gholdengo.setup.active.csv4c", "deploy", 0, _predicate(select_type_raw=1, select_context_raw=1, option_type_raw=3, option_card_id="CSV4C_063")),
        _rule("gholdengo.poffin.play", "acquire", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV7C_177", acting_hand_card_id="CSV7C_177")),
        _rule("gholdengo.poffin.target.csv4c", "deploy", 0, _predicate(select_type_raw=1, select_context_raw=5, option_type_raw=3, option_card_id="CSV4C_063")),
        _rule("gholdengo.evolve.csv4c", "deploy", 0, _predicate(option_type_raw=3, option_card_id="CSV4C_063", acting_hand_card_id="CSV4C_089")),
        _rule("gholdengo.palkia-vstar.evolve", "deploy", 2, _predicate(option_type_raw=3, option_card_id="CSNC_003", acting_hand_card_id="CS5bC_051")),
        _rule("gholdengo.superior-energy-retrieval.play", "recover", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV3C_115", acting_hand_card_id="CSV3C_115")),
        _rule("gholdengo.energy-retrieval.play", "recover", 1, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSVH1C_034", acting_hand_card_id="CSVH1C_034")),
        _rule("gholdengo.make-it-rain.attack", "execute", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=13, acting_active_card_id="CSV4C_089")),
        _rule("gholdengo.subspace-swell.attack", "execute", 1, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=13, acting_active_card_id="CS5bC_051")),
    ]
    return {"adapter_id": PACKAGE_ID, "adapter_version": 1, "rules": rules, "schema_version": 1}


def build_policy_ir(adapter: dict[str, object]) -> dict[str, object]:
    rule_ids = [rule["rule_id"] for rule in adapter["rules"]]  # type: ignore[index]
    nodes = [
        ("n00", "legality_guard", "base", {"frontier": "current_window"}),
        ("n10", "mandatory_terminal_guard", "base", {"mandatory_precedence": True, "terminal_precedence": True}),
        ("n20", "macro_proposal", "adapter", {"macro_ids": rule_ids}),
        ("n30", "hard_tier_filter", "base", {"same_tier_only": True}),
        ("n40", "base_veto", "base", {"enabled": True}),
        ("n50", "deterministic_fallback", "base", {"strategy": "same_window_first_min"}),
        ("n60", "emit_decision", "base", {}),
    ]
    return {
        "entry_node_id": "n00",
        "graph_id": PACKAGE_ID,
        "nodes": [
            {
                "config": config,
                "next_node_ids": [] if index + 1 == len(nodes) else [nodes[index + 1][0]],
                "node_id": node_id,
                "operator": operator,
                "owner": owner,
            }
            for index, (node_id, operator, owner, config) in enumerate(nodes)
        ],
        "profile_id": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
        "required_capabilities": ["public_context", "current_window", "deterministic_fallback", "strategic_trace_v2"],
        "schema_version": 1,
    }


def _scenario(
    root: Path,
    *,
    scenario_id: str,
    select_type: int,
    select_context: int,
    option_zero_type: int,
    option_one_type: int,
    option_zero_uid: str | None,
    option_one_uid: str | None,
    acting_hand_uid: str | None = None,
    acting_active_uid: str | None = None,
    option_zero_attack_id: int | None = None,
    option_one_attack_id: int | None = None,
) -> dict[str, object]:
    vectors = load_json_strict(root / "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json")
    raw = copy.deepcopy(vectors["base_observations"]["regular"])
    def raw_option(option_type: int, index: int, attack_id: int | None) -> dict[str, object]:
        if option_type == 13:
            if type(attack_id) is not int or attack_id < 1:
                raise ValueError("attack scenario requires a positive attack identity")
            return {"type": option_type, "attackId": attack_id}
        if option_type in {12, 14}:
            return {"type": option_type}
        if option_type == 7:
            return {"type": option_type, "index": index}
        return {"type": option_type, "area": 2, "index": index, "playerIndex": 0}

    raw["select"].update(
        {
            "type": select_type,
            "context": select_context,
            "minCount": 1,
            "maxCount": 1,
            "option": [
                raw_option(option_zero_type, 0, option_zero_attack_id),
                raw_option(option_one_type, 1, option_one_attack_id),
            ],
        }
    )
    return {
        "document_type": "author_strategy_developer_scenario_v1",
        "schema_version": 1,
        "scenario_id": scenario_id,
        "raw_observation": raw,
        "prompt": {
            "prompt_id": scenario_id,
            "prompt_generation": 1,
            "mandatory_indexes": [],
            "terminal_indexes": [],
            "base_hard_tiers": [{"index": 0, "tier": [0]}, {"index": 1, "tier": [0]}],
            "base_vetoed_indexes": [],
        },
        "local_uid_bindings": {
            "options": [
                {"index": 0, "local_card_uid": option_zero_uid},
                {"index": 1, "local_card_uid": option_one_uid},
            ],
            # The local-UID public context is an exact positional projection:
            # every public hand/active card in the fixture must be bound even
            # when the rule does not predicate on that zone.
            "acting_hand": [{"serial": 30, "local_card_uid": acting_hand_uid or "CSV1C_111"}],
            "acting_active": [{"serial": 10, "local_card_uid": acting_active_uid or "CSV4C_063"}],
        },
        "expected_selected_indexes": [1],
    }


def build_workspace_payloads(root: Path = ROOT) -> dict[str, bytes]:
    root = Path(root)
    deck_manifest = build_deck_manifest(root)
    deck_csv = build_deck_csv(deck_manifest)
    deck_manifest_bytes = _json_bytes(deck_manifest)
    adapter = build_adapter()
    policy_ir = build_policy_ir(adapter)
    package_manifest = {
        "author": {"author_id": "ptcgdap.strategy-lab", "display_name": "PtcgDAP Strategy Lab"},
        "compatibility": {
            "base_executor_sha256": "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389",
            "cabt_contract_sha256": "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294",
            "card_catalog_sha256": "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4",
            "minimum_game_api": "ptcgdap-author-host-v1",
            "required_capabilities": [],
        },
        "deck": {
            "deck_path": "deck/deck.csv",
            "display_name": "赛富豪 起源帕路奇亚 575479",
            "manifest_path": "deck/deck_manifest.json",
        },
        "document_type": "strategy_package_v1",
        "package_id": PACKAGE_ID,
        "package_version": PACKAGE_VERSION,
        "policy": {
            "adapter_path": "policy/adapter.json",
            "config_path": "policy/config.json",
            "entry_kind": "restricted_policy_ir_v1",
            "ir_path": "policy/policy_ir.json",
            "weights_path": "policy/weights.bin",
        },
        "presentation": {"banner_path": None, "icon_path": None},
        "schema_version": 1,
        "strategy": {
            "display_name": "赛富豪/起源帕路奇亚 Windows 本地候选 v1",
            "summary": "Exact local-UID 575479 public-window ordering hints; benchmarked rules candidate, test signed and never player-ready.",
        },
    }
    config = {
        "config_profile_id": "ptcgdap-author-policy-config-v1",
        "document_type": "author_policy_config_v1",
        "schema_version": 1,
        "values": {
            "cabt_exportable": False,
            "card_id_domain": CARD_ID_DOMAIN,
            "deck_manifest_sha256": _sha(deck_manifest_bytes),
            "platform_scope": "windows",
            "source_deck_id": SOURCE_DECK_ID,
        },
    }
    scenarios = {
        "setup-active-gimmighoul.json": _scenario(
            root,
            scenario_id="gholdengo-setup-active",
            select_type=1,
            select_context=1,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSNC_003",
            option_one_uid="CSV4C_063",
        ),
        "poffin-play.json": _scenario(
            root,
            scenario_id="gholdengo-poffin-play",
            select_type=0,
            select_context=0,
            option_zero_type=14,
            option_one_type=7,
            option_zero_uid=None,
            option_one_uid="CSV7C_177",
            acting_hand_uid="CSV7C_177",
        ),
        "evolve-gholdengo.json": _scenario(
            root,
            scenario_id="gholdengo-evolve",
            select_type=1,
            select_context=19,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSNC_003",
            option_one_uid="CSV4C_063",
            acting_hand_uid="CSV4C_089",
        ),
        "superior-energy-retrieval-play.json": _scenario(
            root,
            scenario_id="gholdengo-ser-play",
            select_type=0,
            select_context=0,
            option_zero_type=14,
            option_one_type=7,
            option_zero_uid=None,
            option_one_uid="CSV3C_115",
            acting_hand_uid="CSV3C_115",
        ),
        "make-it-rain-attack.json": _scenario(
            root,
            scenario_id="gholdengo-make-it-rain",
            select_type=0,
            select_context=0,
            option_zero_type=14,
            option_one_type=13,
            option_zero_uid=None,
            option_one_uid=None,
            acting_active_uid="CSV4C_089",
            option_one_attack_id=1,
        ),
    }
    payloads = {
        "package/strategy_package.json": _json_bytes(package_manifest),
        "package/README.md": (
            "# Gholdengo / Origin Forme Palkia 575479 author-strategy candidate\n\n"
            "Windows-only public-window ordering hints for development simulation. "
            "The archive is test-fixture signed, execution_trusted=false, cabt_exportable=false, "
            "and grants no player or match authority.\n"
        ).encode("utf-8"),
        "package/LICENSE": b"Development test fixture only. No production grant.\n",
        "package/deck/deck_manifest.json": deck_manifest_bytes,
        "package/deck/deck.csv": deck_csv,
        "package/policy/adapter.json": _json_bytes(adapter),
        "package/policy/policy_ir.json": _json_bytes(policy_ir),
        "package/policy/config.json": _json_bytes(config),
        "package/policy/weights.bin": WEIGHTS,
    }
    for name, scenario in scenarios.items():
        payloads[f"scenarios/{name}"] = _json_bytes(scenario)
    return payloads


def write_workspace(output: Path, *, root: Path = ROOT) -> dict[str, object]:
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError("output_exists")
    output.parent.mkdir(parents=True, exist_ok=True)
    payloads = build_workspace_payloads(root)
    for relative_path, payload in payloads.items():
        target = output / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
    (output / "build").mkdir()
    return {
        "status": "created",
        "package_id": PACKAGE_ID,
        "package_version": PACKAGE_VERSION,
        "source_deck_id": SOURCE_DECK_ID,
        "file_count": len(payloads),
        "workspace": str(output.resolve()),
        "claims": {
            "engine_execution": False,
            "production_authority": False,
            "cabt_export": False,
            "android": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the exact 575479 Gholdengo/Palkia author-strategy development workspace")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        report = write_workspace(args.output)
        if args.report is not None:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_bytes(_json_bytes(report))
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        return 0
    except (OSError, KeyError, TypeError, ValueError) as exc:
        print(json.dumps({"status": "failed", "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
