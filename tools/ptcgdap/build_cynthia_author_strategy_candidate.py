from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_gholdengo_author_strategy_candidate import (
    WEIGHTS,
    _predicate,
    _rule,
    _scenario,
    build_deck_csv,
    build_policy_ir,
)


SOURCE_DECK_ID = 800018543
SOURCE_DECK_PATH = Path(f"data/bundled_user/decks/{SOURCE_DECK_ID}.json")
PACKAGE_ID = "ptcgdap.cynthia-garchomp-800018543.windows-local"
PACKAGE_VERSION = "0.1.0"
CARD_ID_DOMAIN = "godot_local_card_uid_v1"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def build_deck_manifest(root: Path = ROOT) -> dict[str, object]:
    source_path = root / SOURCE_DECK_PATH
    source_bytes = source_path.read_bytes()
    source = load_json_strict(source_path)
    if source.get("id") != SOURCE_DECK_ID or source.get("total_cards") != 60:
        raise ValueError("source_deck_drift")

    source_rows = source.get("cards")
    if type(source_rows) is not list:
        raise ValueError("invalid_source_cards")
    sorted_rows = sorted(
        source_rows,
        key=lambda row: f"{row['set_code']}_{row['card_index']}".encode("ascii"),
    )
    entries: list[dict[str, object]] = []
    for row in sorted_rows:
        uid = f"{row['set_code']}_{row['card_index']}"
        card_path = root / "data/bundled_user/cards" / f"{uid}.json"
        card_bytes = card_path.read_bytes()
        card = load_json_strict(card_path)
        if (
            card.get("set_code") != row.get("set_code")
            or card.get("card_index") != row.get("card_index")
            or card.get("effect_id") != row.get("effect_id")
            or type(row.get("count")) is not int
        ):
            raise ValueError(f"source_card_drift:{uid}")
        entries.append(
            {
                "local_card_uid": uid,
                "set_code": row["set_code"],
                "card_index": row["card_index"],
                "count": row["count"],
                "card_type": card["card_type"],
                "stage": card.get("stage", ""),
                "effect_id": row["effect_id"],
                "source_raw_sha256": _sha(card_bytes),
                "source_canonical_sha256": _sha(canonical_json_v1_bytes(card)),
            }
        )

    manifest: dict[str, object] = {
        "document_type": "deck_manifest_windows_local_v1",
        "schema_version": 1,
        "deck_id": "cynthia-garchomp.800018543",
        "card_id_domain": CARD_ID_DOMAIN,
        "card_count": 60,
        "unique_card_count": len(entries),
        "deck_csv_sha256": "0" * 64,
        "cabt_exportable": False,
        "platform_scope": ["windows"],
        "source_deck_id": SOURCE_DECK_ID,
        "source_deck_raw_sha256": _sha(source_bytes),
        "source_deck_canonical_sha256": _sha(canonical_json_v1_bytes(source)),
        "cards": entries,
    }
    manifest["deck_csv_sha256"] = _sha(build_deck_csv(manifest))
    return manifest


def build_adapter() -> dict[str, object]:
    rules = [
        _rule("cynthia.setup.active.budew", "deploy", 0, _predicate(select_type_raw=1, select_context_raw=1, option_type_raw=3, option_card_id="CSV9.5C_004")),
        _rule("cynthia.poffin.play", "acquire", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV7C_177", acting_hand_card_id="CSV7C_177")),
        _rule("cynthia.arven.play", "acquire", 1, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV1C_123", acting_hand_card_id="CSV1C_123")),
        _rule("cynthia.poffin.target.gible", "deploy", 0, _predicate(select_type_raw=1, select_context_raw=5, option_type_raw=3, option_card_id="CSV10C_111")),
        _rule("cynthia.poffin.target.roselia", "deploy", 1, _predicate(select_type_raw=1, select_context_raw=5, option_type_raw=3, option_card_id="CSV10C_004")),
        _rule("cynthia.gabite.evolve", "deploy", 0, _predicate(option_type_raw=3, option_card_id="CSV10C_111", acting_hand_card_id="CSV10C_112")),
        _rule("cynthia.garchomp.evolve", "deploy", 0, _predicate(option_type_raw=3, option_card_id="CSV10C_112", acting_hand_card_id="CSV10C_113")),
        _rule("cynthia.roserade.evolve", "deploy", 1, _predicate(option_type_raw=3, option_card_id="CSV10C_004", acting_hand_card_id="CSV10C_005")),
        _rule("cynthia.tm-evolution.play", "deploy", 2, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV5C_119", acting_hand_card_id="CSV5C_119")),
        _rule("cynthia.power-weight.play", "fund", 1, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV10C_200", acting_hand_card_id="CSV10C_200")),
        _rule("cynthia.garchomp.attack", "execute", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=13, acting_active_card_id="CSV10C_113")),
        _rule("cynthia.night-stretcher.play", "recover", 0, _predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, option_card_id="CSV8C_183", acting_hand_card_id="CSV8C_183")),
    ]
    return {
        "adapter_id": PACKAGE_ID,
        "adapter_version": 1,
        "rules": rules,
        "schema_version": 1,
    }


def build_scenarios(root: Path) -> dict[str, dict[str, object]]:
    return {
        "setup-active-budew.json": _scenario(
            root,
            scenario_id="cynthia-setup-active-budew",
            select_type=1,
            select_context=1,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSV10C_138",
            option_one_uid="CSV9.5C_004",
            acting_hand_uid="CSV1C_123",
            acting_active_uid="CSV9.5C_004",
        ),
        "poffin-play.json": _scenario(
            root,
            scenario_id="cynthia-poffin-play",
            select_type=0,
            select_context=0,
            option_zero_type=14,
            option_one_type=7,
            option_zero_uid=None,
            option_one_uid="CSV7C_177",
            acting_hand_uid="CSV7C_177",
            acting_active_uid="CSV9.5C_004",
        ),
        "evolve-gabite.json": _scenario(
            root,
            scenario_id="cynthia-evolve-gabite",
            select_type=1,
            select_context=19,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSV10C_004",
            option_one_uid="CSV10C_111",
            acting_hand_uid="CSV10C_112",
            acting_active_uid="CSV9.5C_004",
        ),
        "evolve-garchomp.json": _scenario(
            root,
            scenario_id="cynthia-evolve-garchomp",
            select_type=1,
            select_context=19,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSV10C_004",
            option_one_uid="CSV10C_112",
            acting_hand_uid="CSV10C_113",
            acting_active_uid="CSV9.5C_004",
        ),
        "evolve-roserade.json": _scenario(
            root,
            scenario_id="cynthia-evolve-roserade",
            select_type=1,
            select_context=19,
            option_zero_type=3,
            option_one_type=3,
            option_zero_uid="CSV10C_111",
            option_one_uid="CSV10C_004",
            acting_hand_uid="CSV10C_005",
            acting_active_uid="CSV10C_113",
        ),
        "garchomp-attack.json": _scenario(
            root,
            scenario_id="cynthia-garchomp-attack",
            select_type=0,
            select_context=0,
            option_zero_type=14,
            option_one_type=13,
            option_zero_uid=None,
            option_one_uid=None,
            acting_hand_uid="CSV1C_123",
            acting_active_uid="CSV10C_113",
            option_one_attack_id=1,
        ),
    }


def write_workspace(workspace: Path, root: Path = ROOT) -> dict[str, object]:
    package = workspace / "package"
    scenarios_path = workspace / "scenarios"
    if not package.is_dir() or not scenarios_path.is_dir():
        raise ValueError("scaffold_workspace_required")

    deck_manifest = build_deck_manifest(root)
    deck_csv = build_deck_csv(deck_manifest)
    deck_manifest_bytes = _json_bytes(deck_manifest)
    adapter = build_adapter()
    policy_ir = build_policy_ir(adapter)
    policy_ir["graph_id"] = PACKAGE_ID
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
            "display_name": "18.0 竹兰烈咬陆鲨",
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
            "display_name": "竹兰烈咬陆鲨 Windows 本地候选 v1",
            "summary": "Exact local-UID 800018543 public-window ordering hints; benchmarked Godot rules candidate, test signed and never player-ready.",
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

    payloads = {
        "strategy_package.json": _json_bytes(package_manifest),
        "README.md": (
            "# Cynthia's Garchomp 800018543 author-strategy candidate\n\n"
            "Windows-only public-window ordering hints for development simulation. "
            "The archive is test-fixture signed, execution_trusted=false, "
            "cabt_exportable=false, and grants no player or match authority.\n"
        ).encode("utf-8"),
        "LICENSE": b"Development test fixture only. No production grant.\n",
        "deck/deck_manifest.json": deck_manifest_bytes,
        "deck/deck.csv": deck_csv,
        "policy/adapter.json": _json_bytes(adapter),
        "policy/policy_ir.json": _json_bytes(policy_ir),
        "policy/config.json": _json_bytes(config),
        "policy/weights.bin": WEIGHTS,
    }
    for relative, data in payloads.items():
        target = package / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    old_scenario = scenarios_path / "morgrem-evolve.json"
    if old_scenario.exists():
        old_scenario.unlink()
    scenarios = build_scenarios(root)
    for name, scenario in scenarios.items():
        (scenarios_path / name).write_bytes(_json_bytes(scenario))
    return {
        "status": "retargeted",
        "package_id": PACKAGE_ID,
        "package_version": PACKAGE_VERSION,
        "source_deck_id": SOURCE_DECK_ID,
        "card_count": deck_manifest["card_count"],
        "unique_card_count": deck_manifest["unique_card_count"],
        "rule_count": len(adapter["rules"]),
        "scenario_count": len(scenarios),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Retarget a developer scaffold to the exact Cynthia/Garchomp 800018543 local deck")
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        report = write_workspace(args.workspace.resolve())
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
