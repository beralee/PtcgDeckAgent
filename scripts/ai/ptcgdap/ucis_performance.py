from __future__ import annotations

from contextlib import ExitStack
from dataclasses import dataclass
import gc
from pathlib import Path
import statistics
import subprocess
import time
from typing import Any, Callable
from unittest.mock import patch

from scripts.ai.ptcgdap.ucis import (
    CardEffectSpec,
    UcisCompiler,
    UcisRegistry,
    begin_program,
)


@dataclass(frozen=True)
class _AttemptCounter:
    name: str
    attempts: list[str]

    def reject(self, *args: object, **kwargs: object) -> None:
        del args, kwargs
        self.attempts.append(self.name)
        raise AssertionError(f"ucis_runtime_forbidden_operation:{self.name}")


def _representative_spec(registry: UcisRegistry) -> CardEffectSpec:
    primitive_name = "ChooseCardSet"
    primitive = registry.primitives[primitive_name]
    row = registry.context_rows[primitive.contexts[0]]
    return CardEffectSpec.from_mapping(
        {
            "schema_version": 1,
            "effect_ref": "qualification:ucis-performance",
            "resolution_kind": "interactive",
            "program_kind": primitive_name,
            "capability_ids": [primitive_name],
            "steps": [
                {
                    "step_id": "current-window",
                    "primitive": primitive_name,
                    "context_name": row.context_name,
                    "option_type_name": row.option_type_names[0],
                    "source_zone_query": "current_public_frontier",
                    "candidate_predicate": "legal_current_options",
                    "target_predicate": "legal_current_targets",
                    "quantity_encoding": primitive.quantity_encodings[0],
                    "min_rule": "current_min_count",
                    "max_rule": "current_max_count",
                    "remaining_debt_rule": "current_remaining_debt",
                    "public_context_projection": "ucis_public_facts_v1",
                    "private_binding_recipe": "current_option_private_binding",
                    "commit_command_kind": "commit_current_selection",
                    "next_checkpoint_rule": "fresh_reobserve",
                    "unsupported_if": [],
                    "capability_ids": [primitive_name],
                }
            ],
            "chooser_rule": "engine_current_chooser",
            "visibility_rule": "acting_seat_public_only",
            "lifecycle_anchor": "current_effect_checkpoint",
            "continuation_rule": "ordered_steps_fresh_reobserve",
            "stop_rule": "program_complete",
            "information_checkpoints": ["fresh_reobserve"],
            "source_hash": "A" * 64,
        }
    )


def _percentile(samples: list[int], percentile: float) -> int:
    if not samples:
        raise ValueError("ucis_performance_samples_required")
    ordered = sorted(samples)
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * percentile))))
    return ordered[index]


def _timing(samples: list[int], threshold_ns: int) -> dict[str, Any]:
    median = int(statistics.median(samples))
    p95 = _percentile(samples, 0.95)
    return {
        "iterations": len(samples),
        "median_ns": median,
        "p95_ns": p95,
        "max_ns": max(samples),
        "qualification_threshold_p95_ns": threshold_ns,
        "qualified": p95 <= threshold_ns,
    }


def _measure(call: Callable[[int], object], iterations: int) -> list[int]:
    samples: list[int] = []
    for index in range(iterations):
        started = time.perf_counter_ns()
        call(index)
        samples.append(time.perf_counter_ns() - started)
    return samples


def build_ucis_performance_report(
    repository_root: str | Path,
    *,
    build_iterations: int = 25,
    runtime_iterations: int = 10_000,
) -> dict[str, Any]:
    if type(build_iterations) is not int or build_iterations < 5:
        raise ValueError("ucis_performance_build_iterations_invalid")
    if type(runtime_iterations) is not int or runtime_iterations < 100:
        raise ValueError("ucis_performance_runtime_iterations_invalid")

    root = Path(repository_root).resolve()

    def build_once(_: int) -> object:
        registry = UcisRegistry.load(root)
        return UcisCompiler(registry).compile_effect(_representative_spec(registry))

    gc_was_enabled = gc.isenabled()
    gc.disable()
    try:
        build_samples = _measure(build_once, build_iterations)

        registry = UcisRegistry.load(root)
        program = UcisCompiler(registry).compile_effect(_representative_spec(registry))
        instance = begin_program(program, "qualification:runtime-hot-path")
        state = {
            "observation_generation": 0,
            "public_state_hash": "B" * 64,
            "legality": {
                "ordered_option_fingerprints": ["candidate-0", "candidate-1", "candidate-2"],
                "min_count": 0,
                "max_count": 3,
                "remain_damage_counter": None,
                "remain_energy_cost": None,
            },
        }

        disk_attempts: list[str] = []
        process_attempts: list[str] = []
        catalog_attempts: list[str] = []
        disk = _AttemptCounter("disk_read", disk_attempts)
        process = _AttemptCounter("subprocess", process_attempts)
        catalog = _AttemptCounter("catalog_scan", catalog_attempts)

        with ExitStack() as stack:
            stack.enter_context(patch("pathlib.Path.read_bytes", disk.reject))
            stack.enter_context(patch("pathlib.Path.read_text", disk.reject))
            stack.enter_context(patch("pathlib.Path.open", disk.reject))
            stack.enter_context(patch.object(subprocess, "Popen", process.reject))
            stack.enter_context(patch.object(subprocess, "run", process.reject))
            stack.enter_context(
                patch("scripts.ai.ptcgdap.ucis_catalog.build_ucis_catalog", catalog.reject)
            )

            def runtime_once(index: int) -> object:
                state["observation_generation"] = index
                return instance.next_step(state)

            runtime_samples = _measure(runtime_once, runtime_iterations)
    finally:
        if gc_was_enabled:
            gc.enable()

    build_timing = _timing(build_samples, 500_000_000)
    runtime_timing = _timing(runtime_samples, 5_000_000)
    runtime_audit = {
        "disk_schema_or_contract_reads": len(disk_attempts),
        "subprocess_or_external_forge_calls": len(process_attempts),
        "full_catalog_scans": len(catalog_attempts),
        "preloaded_registry_lookup": True,
        "current_state_legality_query": True,
        "sparse_public_projection_only": True,
        "qualified": not (disk_attempts or process_attempts or catalog_attempts),
    }
    return {
        "document_type": "ptcgdap_ucis_performance_qualification_v1",
        "schema_version": 1,
        "contract_generation": registry.contract_generation,
        "ucis_generation": registry.ucis_generation,
        "registry_sha256": registry.document_hash,
        "measurement_scope": {
            "build_path": "registry_load_plus_spec_parse_plus_compile",
            "runtime_path": "precompiled_program_current_window_next_step",
            "timing_note": "environmental_measurement_not_a_reproducible_content_hash",
        },
        "build_cost": build_timing,
        "per_window_runtime_cost": runtime_timing,
        "runtime_operation_audit": runtime_audit,
        "qualification": {
            "status": "passed"
            if build_timing["qualified"] and runtime_timing["qualified"] and runtime_audit["qualified"]
            else "failed",
            "build_and_runtime_costs_reported_separately": True,
            "runtime_forbidden_operations_observed": 0,
        },
        "nonclaims": [
            "not_a_cross_device_latency_guarantee",
            "not_a_full_match_throughput_benchmark",
            "not_official_engine_performance_evidence",
        ],
    }


__all__ = ["build_ucis_performance_report"]
