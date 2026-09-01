from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader  # noqa: E402
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes  # noqa: E402
from scripts.ai.ptcgdap.state_conditioned_transaction_value import (  # noqa: E402
    StateConditionedTransactionValueV2,
)
from tools.ptcgdap.build_author_strategy_package import (  # noqa: E402
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
)
from tools.ptcgdap.build_marnie_gift_box_r54 import TEST_FIXTURE_PRIVATE_KEY  # noqa: E402
from tools.ptcgdap.build_marnie_gift_box_turn_program_rounds import (  # noqa: E402
    build_payloads as build_turn_program_payloads,
)


PACKAGE_VERSION = "5.36.0"
MODEL_PATH = (
    ROOT
    / "artifacts/ptcgdap/training_runs/marnie_state_value_v2_20260901_r16/model.json"
)
MODEL_FILE_SHA256 = "DD0AEEE052DC89B52CE68CB18574E9CDB730894A7FD910D269B2A6AFB1BEF008"
OUTPUT_PATH = (
    ROOT
    / "data/ptcgdap/author_strategy_packages"
    / f"marnies-gift-box-state-value-v2-{PACKAGE_VERSION}.ptcgai"
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_model() -> dict[str, object]:
    raw = MODEL_PATH.read_bytes()
    if _sha(raw) != MODEL_FILE_SHA256:
        raise ValueError("state-conditioned model artifact drift")
    model = json.loads(raw)
    error = StateConditionedTransactionValueV2.model_error(model)
    if error:
        raise ValueError(error)
    return model


def build_payloads() -> dict[str, bytes]:
    payloads = build_turn_program_payloads("05")
    manifest = json.loads(payloads["strategy_package.json"])
    policy_config = json.loads(payloads["policy/config.json"])
    adapter = json.loads(payloads["policy/adapter.json"])
    model = _load_model()
    model_bytes = canonical_json_v1_bytes(model)
    fallback = model["fallback_value_model"]
    weights = fallback["feature_weights_milli"]

    manifest["package_version"] = PACKAGE_VERSION
    manifest["policy"]["weights_path"] = "policy/weights.bin"
    manifest["strategy"]["summary"] = (
        "完整公开局面条件化的事务价值 v2：局面、动作、局面×事务交互三头联合校准；"
        "v6 以人工 exam、同种子首事务分歧、真实执行胜局 canary、通用验证的分层门选择候选；Base Graph 继续独占合法性、"
        "终局、事务安全与最终否决，5.21/v1 权重可本地回滚。"
    )
    values = policy_config["values"]
    values.update(
        {
            "turn_program_model_version": model["model_version"],
            "turn_program_weight_prize_gain_milli": weights["prize_gain_milli"],
            "turn_program_weight_board_development_milli": weights[
                "board_development_milli"
            ],
            "turn_program_weight_attack_pressure_milli": weights[
                "attack_pressure_milli"
            ],
            "turn_program_weight_next_turn_continuity_milli": weights[
                "next_turn_continuity_milli"
            ],
            "turn_program_weight_hand_quality_milli": weights["hand_quality_milli"],
            "turn_program_weight_disruption_milli": weights["disruption_milli"],
            "turn_program_weight_resource_preservation_milli": weights[
                "resource_preservation_milli"
            ],
            "turn_program_weight_risk_milli": weights["risk_milli"],
            "turn_program_weight_unresolved_debt_milli": weights[
                "unresolved_debt_milli"
            ],
            "turn_program_allowed_effects": ",".join(
                [
                    "evolution",
                    "damage_transfer",
                    "energy",
                    "ability",
                    "search",
                    "draw",
                    "disruption",
                    "bench",
                ]
            ),
            "turn_program_semantic_guard_profile_id": (
                "ptcgdap-turn-program-public-guard-v1"
            ),
            "turn_program_semantic_guard_draw_max_own_hand": 4,
            "turn_program_semantic_guard_disruption_max_own_hand": 4,
            "turn_program_semantic_guard_disruption_min_opponent_hand": 5,
            "turn_program_conditioned_value_sha256": _sha(model_bytes),
        }
    )
    zero_active_rules = [
        rule
        for rule in adapter["rules"]
        if rule.get("rule_id") == "attack.reject-zero-active-damage"
    ]
    if len(zero_active_rules) != 1:
        raise ValueError("zero-active-damage rule drift")
    redundant_prompt_conditions = [
        condition
        for condition in zero_active_rules[0]["when"]
        if condition
        == {
            "fact": "prompt_kind",
            "op": "eq",
            "value": "main",
            "card_uid": None,
        }
    ]
    if len(redundant_prompt_conditions) != 1:
        raise ValueError("zero-active-damage prompt guard drift")
    # A kind=attack option is already confined to the current main-action
    # frontier. Removing the duplicate prompt guard keeps the signed adapter
    # within the established device package budget while preserving semantics.
    zero_active_rules[0]["when"].remove(redundant_prompt_conditions[0])
    zero_active_rules[0]["rule_id"] = "attack.zero-total-damage"
    zero_active_rules[0]["when"].append(
        {
            "fact": "damage.option.bench_damage",
            "op": "eq",
            "value": 0,
            "card_uid": None,
        }
    )
    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["policy/config.json"] = canonical_json_v1_bytes(policy_config)
    payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
    payloads["policy/weights.bin"] = model_bytes
    readme = payloads["README.md"].decode("utf-8").rstrip()
    payloads["README.md"] = (
        readme
        + "\n\n## State-conditioned transaction value v2\n\n"
        + "The signed package-local integer artifact in policy/weights.bin consumes only the fresh public frame and "
        + "Base-admitted semantic program. It contains no deck-number feature, network "
        + "dependency, Python runtime dependency, stale option index, or execution authority. "
        + "Any rejection fails closed before canary application; the embedded v1 fallback "
        + "weights remain the rollback leaf.\n"
    ).encode("utf-8")
    return payloads


def build_bytes() -> bytes:
    return build_package_bytes(
        build_payloads(), TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")
    args = parser.parse_args()
    archive = build_bytes()
    if args.write:
        OUTPUT_PATH.write_bytes(archive)
    elif not OUTPUT_PATH.is_file() or OUTPUT_PATH.read_bytes() != archive:
        raise SystemExit(f"state-conditioned package drift: {OUTPUT_PATH.name}")
    handle = AuthorStrategyPackageLoader().load_bytes(archive)
    print(f"archive_path={OUTPUT_PATH.as_posix()}")
    print(f"archive_sha256={_sha(archive)}")
    print(f"package_version={handle.package_version}")
    print(f"model_file_sha256={MODEL_FILE_SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
