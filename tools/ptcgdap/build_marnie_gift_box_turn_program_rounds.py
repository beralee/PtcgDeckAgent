from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes  # noqa: E402
from scripts.ai.ptcgdap.turn_program_generator import TurnProgramGenerator  # noqa: E402
from tools.ptcgdap.build_author_strategy_package import (  # noqa: E402
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
)
from tools.ptcgdap.build_marnie_gift_box_r54 import TEST_FIXTURE_PRIVATE_KEY  # noqa: E402
from tools.ptcgdap.build_marnie_gift_box_r55 import build_payloads as build_r55_payloads  # noqa: E402


OUTPUT_ROOT = ROOT / "data/ptcgdap/author_strategy_packages"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _model(version: int, **weights: int) -> dict[str, object]:
    model = TurnProgramGenerator.default_value_model()
    model["model_version"] = version
    model["feature_weights_milli"].update(weights)
    return model


ACTION_SEMANTICS = {
    "draw": ["CSV1C_121"],
    "disruption": ["CSV3C_123"],
    "search": [
        "CSV1C_109", "CSV1C_112", "CSV1C_123", "CSV8C_176",
        "CSV8C_183", "CSVH1C_035",
    ],
    "conversion": ["CSV6C_114", "CSVH1aC_023"],
    "evolution": ["CSVH1C_045"],
    "bench": ["CSV7C_177"],
    "supporter": ["CSV1C_121", "CSV1C_123", "CSV3C_123", "CSVH1aC_023"],
}


# Each round changes one bounded public value/gate hypothesis.  The builder is
# deterministic; benchmark retention is recorded separately and never mutates
# an earlier archive.
CONFIGS: dict[str, dict[str, object]] = {
    "arch": {
        "package_version": "5.16.0",
        "label": "architecture",
        "sources": ["turn_transaction", "turn_route"],
        "effects": [
            "ability", "bench", "conversion", "damage_transfer", "disruption",
            "draw", "energy", "evolution", "handoff", "search",
        ],
        "uncertainty": 400,
        "margin": 1,
        "model": _model(1),
    },
    "01": {
        "package_version": "5.17.0", "label": "admit-safe-base-evolution",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": ["evolution", "damage_transfer"], "uncertainty": 400, "margin": 1,
        "model": _model(2),
    },
    "02": {
        "package_version": "5.18.0", "label": "admit-safe-energy-and-ability",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": ["evolution", "damage_transfer", "energy", "ability"],
        "uncertainty": 400, "margin": 1, "model": _model(3),
    },
    "03": {
        "package_version": "5.19.0", "label": "admit-safe-stadium-search",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": ["evolution", "damage_transfer", "energy", "ability", "search"],
        "uncertainty": 400, "margin": 1, "model": _model(4),
        "action_semantics": True,
    },
    "04": {
        "package_version": "5.20.0", "label": "raise-core-continuity",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": ["evolution", "damage_transfer", "energy", "ability", "search"],
        "uncertainty": 400, "margin": 1,
        "model": _model(5, board_development_milli=1300, next_turn_continuity_milli=1800),
        "action_semantics": True,
    },
    "05": {
        "package_version": "5.21.0", "label": "raise-damage-transfer",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": ["evolution", "damage_transfer", "energy", "ability", "search"],
        "uncertainty": 400, "margin": 1,
        "model": _model(6, attack_pressure_milli=1500, next_turn_continuity_milli=1800),
        "action_semantics": True,
    },
    "06": {
        "package_version": "5.22.0", "label": "raise-disruption",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": [
            "evolution", "damage_transfer", "energy", "ability", "search",
            "draw", "disruption",
        ],
        "uncertainty": 400, "margin": 1,
        "model": _model(7, disruption_milli=1300, hand_quality_milli=900),
        "action_semantics": True,
    },
    "07": {
        "package_version": "5.23.0", "label": "strict-uncertainty",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": [
            "evolution", "damage_transfer", "energy", "ability", "search",
            "draw", "disruption",
        ],
        "uncertainty": 320, "margin": 1,
        "model": _model(8, board_development_milli=1300, next_turn_continuity_milli=1800),
        "action_semantics": True,
    },
    "08": {
        "package_version": "5.24.0", "label": "public-supporter-outcome-guards",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": [
            "evolution", "damage_transfer", "energy", "ability", "search",
            "draw", "disruption",
        ],
        "uncertainty": 400, "margin": 1,
        "model": _model(9, disruption_milli=1300, hand_quality_milli=900),
        "action_semantics": True,
        "guards": {"draw_max": 4, "disruption_max": 4, "disruption_min": 5},
    },
    "09": {
        "package_version": "5.25.0", "label": "preserve-resources-less",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": [
            "evolution", "damage_transfer", "energy", "ability", "search",
            "draw", "disruption", "bench",
        ],
        "uncertainty": 400, "margin": 1,
        "model": _model(10, resource_preservation_milli=450, board_development_milli=1400),
        "action_semantics": True,
        "guards": {"draw_max": 3, "disruption_max": 4, "disruption_min": 6},
    },
    "10": {
        "package_version": "5.26.0", "label": "balanced-transactional-commit",
        "sources": ["turn_transaction", "turn_route", "base_action"],
        "effects": [
            "evolution", "damage_transfer", "energy", "ability", "search",
            "draw", "disruption",
        ],
        "uncertainty": 380, "margin": 50000,
        "model": _model(
            11,
            board_development_milli=1300,
            attack_pressure_milli=1400,
            next_turn_continuity_milli=1800,
            hand_quality_milli=800,
            disruption_milli=1100,
            resource_preservation_milli=550,
            risk_milli=-2300,
            unresolved_debt_milli=-1700,
        ),
        "action_semantics": True,
        "guards": {"draw_max": 3, "disruption_max": 4, "disruption_min": 5},
    },
}


def output_path(round_id: str) -> Path:
    config = CONFIGS[round_id]
    label = "arch" if round_id == "arch" else f"round{round_id}"
    return OUTPUT_ROOT / (
        f"marnies-gift-box-turn-program-{label}-{config['package_version']}.ptcgai"
    )


def build_payloads(round_id: str) -> dict[str, bytes]:
    config = CONFIGS[round_id]
    payloads = build_r55_payloads()
    manifest = json.loads(payloads["strategy_package.json"])
    policy_config = json.loads(payloads["policy/config.json"])
    manifest["package_version"] = config["package_version"]
    manifest["strategy"]["summary"] = (
        f"Turn Program {config['label']}：公开状态推演、资源冲突与不确定性门禁，"
        "每个新窗口重新生成、证明并绑定当前合法动作；R55 保持可回滚。"
    )
    values = policy_config["values"]
    model = config["model"]
    weights = model["feature_weights_milli"]
    values.update(
        {
            "turn_program_profile_id": "ptcgdap-turn-program-package-v1",
            "turn_program_mode": "canary",
            "turn_program_model_version": model["model_version"],
            "turn_program_weight_prize_gain_milli": weights["prize_gain_milli"],
            "turn_program_weight_board_development_milli": weights["board_development_milli"],
            "turn_program_weight_attack_pressure_milli": weights["attack_pressure_milli"],
            "turn_program_weight_next_turn_continuity_milli": weights["next_turn_continuity_milli"],
            "turn_program_weight_hand_quality_milli": weights["hand_quality_milli"],
            "turn_program_weight_disruption_milli": weights["disruption_milli"],
            "turn_program_weight_resource_preservation_milli": weights["resource_preservation_milli"],
            "turn_program_weight_risk_milli": weights["risk_milli"],
            "turn_program_weight_unresolved_debt_milli": weights["unresolved_debt_milli"],
            "turn_program_allowed_sources": ",".join(config["sources"]),
            "turn_program_allowed_effects": ",".join(config["effects"]),
            "turn_program_max_uncertainty_milli": config["uncertainty"],
            "turn_program_minimum_utility_margin": config["margin"],
        }
    )
    if config.get("action_semantics", False):
        values.update(
            {
                "turn_program_semantics_profile_id": "ptcgdap-turn-program-action-semantics-v1",
                "turn_program_semantic_draw_uids": ",".join(ACTION_SEMANTICS["draw"]),
                "turn_program_semantic_disruption_uids": ",".join(ACTION_SEMANTICS["disruption"]),
                "turn_program_semantic_search_uids": ",".join(ACTION_SEMANTICS["search"]),
                "turn_program_semantic_conversion_uids": ",".join(ACTION_SEMANTICS["conversion"]),
                "turn_program_semantic_evolution_uids": ",".join(ACTION_SEMANTICS["evolution"]),
                "turn_program_semantic_bench_uids": ",".join(ACTION_SEMANTICS["bench"]),
                "turn_program_semantic_supporter_uids": ",".join(ACTION_SEMANTICS["supporter"]),
            }
        )
    if config.get("guards"):
        guards = config["guards"]
        values.update(
            {
                "turn_program_semantic_guard_profile_id": "ptcgdap-turn-program-public-guard-v1",
                "turn_program_semantic_guard_draw_max_own_hand": guards["draw_max"],
                "turn_program_semantic_guard_disruption_max_own_hand": guards["disruption_max"],
                "turn_program_semantic_guard_disruption_min_opponent_hand": guards["disruption_min"],
            }
        )
    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["policy/config.json"] = canonical_json_v1_bytes(policy_config)
    readme = payloads["README.md"].decode("utf-8").rstrip()
    payloads["README.md"] = (
        readme
        + f"\n\n## Turn Program {round_id}\n\n"
        + f"Hypothesis: {config['label']}. The canary only rebinds a fresh, "
        + "Base-proven current semantic step and fails closed on uncertainty, "
        + "resource conflict, mandatory/terminal ownership, or insufficient utility.\n"
    ).encode("utf-8")
    return payloads


def build_bytes(round_id: str) -> bytes:
    return build_package_bytes(
        build_payloads(round_id), TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--round", choices=CONFIGS, required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")
    args = parser.parse_args()
    archive = build_bytes(args.round)
    path = output_path(args.round)
    if args.write:
        path.write_bytes(archive)
    elif not path.is_file() or path.read_bytes() != archive:
        raise SystemExit(f"Turn Program package drift: {path.name}")
    handle = AuthorStrategyPackageLoader().load_bytes(archive)
    adapter = json.loads(handle.payload_bytes("policy/adapter.json"))
    print(f"round={args.round}")
    print(f"archive_path={path.as_posix()}")
    print(f"archive_bytes={len(archive)}")
    print(f"archive_sha256={_sha(archive)}")
    print(f"package_version={handle.package_version}")
    print(f"adapter_version={adapter['adapter_version']}")
    print(f"adapter_rule_count={len(adapter['rules'])}")
    print("execution_trusted=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
