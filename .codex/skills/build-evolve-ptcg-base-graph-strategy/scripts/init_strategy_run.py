#!/usr/bin/env python3
"""Initialize an append-only Base Graph v1.8 strategic-agent run."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


BASE_GRAPH_VERSION = "1.8.0"
ARCHITECTURE = "clean_room_base_graph_v1_8_goal_state_strategic_agent_framework"
BENCH_ID = "meta_recent100_20260809_v7"
BASE_SOURCE_PATHS = (
    "strategy_graph/base_runtime.py",
    "strategy_graph/base_graph_v1.py",
    "strategy_graph/base_graph_v1_1.py",
    "strategy_graph/base_graph_v1_2.py",
    "strategy_graph/base_graph_v1_3.py",
    "strategy_graph/base_graph_v1_4.py",
    "strategy_graph/base_graph_v1_5.py",
    "strategy_graph/base_graph_v1_6.py",
    "strategy_graph/base_graph_v1_7.py",
    "strategy_graph/base_graph_v1_7_architecture_contract.json",
    "strategy_graph/base_graph_v1_8.py",
    "strategy_graph/base_graph_v1_8_architecture_contract.json",
)
REQUIRED_REPO_PATHS = (
    *BASE_SOURCE_PATHS,
    "tools/test_base_graph_v1_7_strategic_framework.py",
    "tools/test_base_graph_v1_8_goal_state_framework.py",
    "tools/assert_bench_v7.py",
    f"bench/{BENCH_ID}/bench.json",
)
INHERITED_CAPABILITIES = (
    "base_graph_v1_1_context_certificate",
    "base_graph_v1_1_all_option_scene_assessment",
    "base_graph_v1_1_mandatory_obligation_ledger",
    "base_graph_v1_1_attack_commit_barrier",
    "base_graph_v1_1_public_opponent_resolver",
    "base_graph_v1_1_matchup_extension_registry",
    "base_graph_v1_1_prize_turn_predictor",
    "base_graph_v1_1_prize_denial_solver",
    "base_graph_v1_1_transaction_replan_resolution",
)
V17_CAPABILITIES = (
    "base_graph_v1_7_strategic_context",
    "base_graph_v1_7_tactical_adapter",
    "base_graph_v1_7_goal_modifier",
    "base_graph_v1_7_legality_strategy_tactics_pipeline",
    "base_graph_v1_7_dynamic_win_condition",
    "base_graph_v1_7_future_simulation_hook",
    "base_graph_v1_7_public_matchup_activation",
    "base_graph_v1_7_result_authority_compatible",
)
V18_CAPABILITIES = (
    "base_graph_v1_8_typed_goal_state_machine",
    "base_graph_v1_8_macro_intent",
    "base_graph_v1_8_public_threat_clock",
    "base_graph_v1_8_two_turn_uncertainty_future",
    "base_graph_v1_8_proven_dominance_constraint",
    "base_graph_v1_8_persistent_plan_replan",
    "base_graph_v1_8_counterfactual_exam_boundary",
    "base_graph_v1_8_strategic_trace_v2",
    "base_graph_v1_8_v1_7_compatible",
)
OWNER_LAYERS = (
    "runtime_integration",
    "base_legality",
    "graph_transaction",
    "interaction",
    "strategic_context",
    "core_adapter",
    "matchup_adapter",
    "goal_modifier",
    "goal_state_machine",
    "macro_intent",
    "threat_clock",
    "dominance_constraint",
    "exam_contract",
    "tactical_scorer",
    "future_simulator",
    "matchup_activation",
    "learned_head",
    "irreducible",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inside(root: Path, raw: Path) -> Path:
    path = raw.resolve() if raw.is_absolute() else (root / raw).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"path must stay inside repository: {path}") from exc
    return path


def relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def read_deck(path: Path) -> list[int]:
    values: list[int] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        value = raw.strip()
        if not value:
            continue
        try:
            card_id = int(value)
        except ValueError as exc:
            raise ValueError(
                f"deck line {line_number} is not one integer card id: {value!r}"
            ) from exc
        if card_id <= 0:
            raise ValueError(f"deck line {line_number} has non-positive card id: {card_id}")
        values.append(card_id)
    if len(values) != 60:
        raise ValueError(f"fixed deck must contain exactly 60 card ids, found {len(values)}")
    return values


def json_text(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def optional_agent(root: Path, raw: Path | None) -> dict[str, Any] | None:
    if raw is None:
        return None
    path = inside(root, raw)
    result: dict[str, Any] = {"path": relative(root, path), "comparison_only": True}
    for name in ("main.py", "deck.csv"):
        artifact = path / name
        if artifact.is_file():
            result[f"{name.split('.')[0]}_sha256"] = sha256(artifact)
    return result


def load_machine_contract(root: Path) -> dict[str, Any]:
    path = root / "strategy_graph/base_graph_v1_8_architecture_contract.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("version") != BASE_GRAPH_VERSION:
        raise ValueError(
            "Base Graph machine contract version mismatch: "
            f"{payload.get('version')!r} != {BASE_GRAPH_VERSION!r}"
        )
    inherited = tuple(payload.get("inherited_capabilities") or ())
    if inherited != V17_CAPABILITIES:
        raise ValueError("Base Graph v1.8 inherited v1.7 capabilities do not match this skill")
    capabilities = tuple(payload.get("capabilities") or ())
    if capabilities != V18_CAPABILITIES:
        raise ValueError("Base Graph v1.8 capability contract does not match this skill")
    return payload


def build_documents(args: argparse.Namespace) -> tuple[Path, dict[str, str]]:
    root = args.repo_root.resolve()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.run_id):
        raise ValueError("run-id must contain only letters, digits, dot, underscore, and hyphen")
    missing = [value for value in REQUIRED_REPO_PATHS if not (root / value).is_file()]
    if missing:
        raise FileNotFoundError(f"repository is missing Base Graph v1.8 prerequisites: {missing}")
    machine_contract = load_machine_contract(root)

    seeds = (args.training_seed, args.discovery_seed, args.confirmation_seed)
    if len(set(seeds)) != 3 or any(value <= 0 for value in seeds):
        raise ValueError("training, discovery, and confirmation seeds must be distinct positive integers")

    deck_path = inside(root, args.deck_csv)
    candidate_path = inside(root, args.candidate_dir)
    deck = read_deck(deck_path)
    if args.artifacts_root is None:
        artifacts_root = root / "artifacts" / "architecture_runs"
    else:
        artifacts_root = (
            args.artifacts_root.resolve()
            if args.artifacts_root.is_absolute()
            else (root / args.artifacts_root).resolve()
        )
    run_dir = artifacts_root / args.run_id
    if run_dir.exists():
        raise FileExistsError(f"append-only run directory already exists: {run_dir}")

    base_hashes = {value: sha256(root / value) for value in BASE_SOURCE_PATHS}
    champion = optional_agent(root, args.champion_dir)
    architecture = {
        "schema_version": 2,
        "run_id": args.run_id,
        "mode": "clean_room_base_graph_v1_8",
        "architecture": ARCHITECTURE,
        "base_graph_version": BASE_GRAPH_VERSION,
        "runtime_class": "BaseGraphRuntimeV18",
        "controller_class": "BaseGraphV18",
        "deck": {
            "id": args.deck_id,
            "path": relative(root, deck_path),
            "sha256": sha256(deck_path),
            "card_count": len(deck),
            "identity_fixed": True,
        },
        "candidate": {"path": relative(root, candidate_path)},
        "comparison_champion": champion,
        "base_hashes": base_hashes,
        "machine_contract_sha256": base_hashes[
            "strategy_graph/base_graph_v1_8_architecture_contract.json"
        ],
        "action_pipeline": list(machine_contract["action_pipeline"]),
        "base_authority": list(machine_contract["base_authority"]),
        "adapter_authority": list(machine_contract["adapter_authority"]),
        "required_invariants": list(machine_contract["invariants"]),
        "required_capabilities": [
            *INHERITED_CAPABILITIES,
            *V17_CAPABILITIES,
            *V18_CAPABILITIES,
        ],
        "owner_layers": list(OWNER_LAYERS),
        "bench": {"id": BENCH_ID, "assertion_tool": "tools/assert_bench_v7.py"},
        "public_information_boundary": {
            "allowed": [
                "own private zones exposed to the acting player",
                "both public fields and discard piles",
                "revealed cards and public action history",
                "prize counts without prize identities",
                "complete legal option frontier",
            ],
            "forbidden": [
                "opponent hand identities",
                "either deck order",
                "prize identities",
                "engine-private state",
            ],
        },
        "adapter_contract": {
            "version": BASE_GRAPH_VERSION,
            "raw_observation_access": False,
            "hard_matchup_requires_unique": True,
            "ambiguous_requires_robust_coverage": True,
            "mandatory_filter_authority": False,
            "terminal_filter_authority": False,
            "hard_constraint_requires_public_dominance_proof": True,
        },
        "goal_state_contract": {
            "stages": [
                "acquire",
                "deploy",
                "fund",
                "ready",
                "execute",
                "maintain",
                "recover",
            ],
            "macro_root_must_be_currently_legal": True,
            "persistent_plan_reuses_constraints": False,
            "persistent_plan_reuses_scores": False,
        },
        "future_contract": {
            "horizon_turns": 2,
            "public_only": True,
            "requires_expected_worst_confidence": True,
            "may_create_legality": False,
        },
        "exam_contract": {
            "execution_action_order_required": False,
            "execution_final_public_state_exact": True,
            "execution_final_hand_exact": True,
            "counterfactual_outcome_is_separate_gate": True,
            "counterfactual_labels_are_runtime_inputs": False,
        },
        "strategic_trace": {
            "schema_version": 2,
            "required": True,
            "file": "strategic_trace.jsonl",
            "audit_file": "strategic_trace_audit.json",
        },
        "learned_contract": {
            "initial_mode": "disabled",
            "authority": "same_base_hard_tier_residual_only",
            "may_not_override": [
                "legal_mask",
                "strategic_mask",
                "resource_certificate",
                "mandatory_satisfier_filter",
                "terminal_proof",
                "base_hard_tier",
                "base_veto",
            ],
        },
        "promotion_authorized": False,
        "submission_authorized": False,
    }
    isolation = {
        "schema_version": 2,
        "run_id": args.run_id,
        "seed_families": {
            "training_oracle": args.training_seed,
            "discovery_200": args.discovery_seed,
            "confirmation_800": args.confirmation_seed,
        },
        "consumed": {"training_oracle": [], "discovery_200": [], "confirmation_800": []},
        "candidate_frozen": False,
        "candidate_main_sha256": None,
        "strategic_trace_sha256": None,
        "discovery_used_for_tuning": False,
        "candidate_changed_after_discovery": False,
        "rules": [
            "training evidence may influence the candidate",
            "discovery and confirmation evidence may not influence the frozen candidate",
            "any behavior change after discovery requires a new untouched discovery family",
            "paired engine seeds are mandatory",
            "owner routing and strategic traces from evaluation lanes may not compile live exceptions",
        ],
    }
    candidate_manifest = {
        "schema_version": 2,
        "run_id": args.run_id,
        "status": "scaffolded_unfrozen",
        "architecture": ARCHITECTURE,
        "base_graph_version": BASE_GRAPH_VERSION,
        "runtime_class": "BaseGraphRuntimeV18",
        "controller_class": "BaseGraphV18",
        "adapter_contract_version": BASE_GRAPH_VERSION,
        "adapters": [],
        "matchup_activation": {
            "hard_requires_unique": True,
            "ambiguous_requires_robust_coverage": True,
        },
        "owner_layers": list(OWNER_LAYERS),
        "base_final_veto": True,
        "strategic_trace_schema_version": 2,
        "strategic_trace_required": True,
        "tactical_cross_hard_tier": False,
        "future_simulation_legality_authority": False,
        "future_horizon_turns": 2,
        "future_requires_uncertainty": True,
        "hard_constraint_requires_public_dominance_proof": True,
        "persistent_plan_reuses_constraints": False,
        "persistent_plan_reuses_scores": False,
        "execution_exam_action_order_required": False,
        "counterfactual_exam_separate": True,
        "base_graph_v1_7_sha256": base_hashes["strategy_graph/base_graph_v1_7.py"],
        "base_graph_v1_7_contract_sha256": base_hashes[
            "strategy_graph/base_graph_v1_7_architecture_contract.json"
        ],
        "base_graph_v1_8_sha256": base_hashes["strategy_graph/base_graph_v1_8.py"],
        "base_graph_v1_8_contract_sha256": base_hashes[
            "strategy_graph/base_graph_v1_8_architecture_contract.json"
        ],
        "candidate_path": relative(root, candidate_path),
        "strategy_dependencies": [],
        "imports_r121_or_r122_policy": False,
        "imports_other_deck_policy": False,
        "deck_identity_fixed": True,
        "deck_sha256": sha256(deck_path),
        "main_sha256": None,
        "opponent_information": "public_only",
        "memorization_surface": [],
        "bc_mode": "disabled",
        "promotion_authorized": False,
        "submission_authorized": False,
    }
    index = {
        "schema_version": 2,
        "run_id": args.run_id,
        "required_artifacts": [
            "architecture_contract.json",
            "evaluation_isolation.json",
            "candidate_manifest.json",
            "iteration_ledger.jsonl",
            "owner_route_decisions.jsonl",
            "strategic_trace.jsonl",
            "strategic_trace_audit.json",
            "strategy_ceiling.json",
            "shared_loss_cases.json",
            "branch_labels.jsonl",
            "training_manifest.json",
            "candidate_contract_check.json",
            "discovery_200/",
            "confirmation_800/",
        ],
    }
    documents = {
        "architecture_contract.json": json_text(architecture),
        "evaluation_isolation.json": json_text(isolation),
        "candidate_manifest.json": json_text(candidate_manifest),
        "run_index.json": json_text(index),
        "iteration_ledger.jsonl": "",
        "owner_route_decisions.jsonl": "",
        "branch_labels.jsonl": "",
        "strategic_trace.jsonl": "",
    }
    return run_dir, documents


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--deck-id", required=True)
    parser.add_argument("--deck-csv", type=Path, required=True)
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--champion-dir", type=Path)
    parser.add_argument("--training-seed", type=int, required=True)
    parser.add_argument("--discovery-seed", type=int, required=True)
    parser.add_argument("--confirmation-seed", type=int, required=True)
    parser.add_argument("--artifacts-root", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    run_dir, documents = build_documents(args)
    if not args.dry_run:
        run_dir.mkdir(parents=True)
        for directory in (
            "tdd",
            "training_oracle",
            "discovery_200",
            "confirmation_800",
            "models",
            "owner_routing",
            "strategic_traces",
        ):
            (run_dir / directory).mkdir()
        for name, content in documents.items():
            (run_dir / name).write_text(content, encoding="utf-8", newline="\n")
    print(
        json_text({"run_dir": str(run_dir), "dry_run": args.dry_run, "files": sorted(documents)}),
        end="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
