from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from .cabt_time_search_v2 import load_time_profile
from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def build_a1_scope(repository_root: str | Path) -> dict[str, Any]:
    root = Path(repository_root).resolve()
    contracts = root / "contracts" / "ptcgdap"
    census = load_json_strict(contracts / "cabt_interface_census_v2.json")
    prompt = load_json_strict(contracts / "cabt_prompt_coverage_matrix_v2.json")
    lifecycle = load_json_strict(contracts / "cabt_lifecycle_coverage_matrix_v2.json")
    time_profile = load_time_profile(contracts, "godot_headless_development")
    all_prompt_green = all(
        row.get("support_status") == "aligned"
        and set(row.get("four_statuses", {}).values()) == {"green"}
        for row in prompt["rows"]
    )
    all_lifecycle_green = all(
        row.get("support_status") == "aligned"
        and set(row.get("statuses", {}).values()) == {"green"}
        for row in lifecycle["rows"]
    )
    report: dict[str, Any] = {
        "document_type": "ptcgdap_a1_scope_report_v2",
        "schema_version": 2,
        "contract_generation": census["contract_generation"],
        "source_lock_id": census["source_lock_id"],
        "source_hashes": census["sources"],
        "contract_hashes": {
            name: _sha(contracts / name)
            for name in (
                "cabt_interface_census_v2.json",
                "cabt_prompt_coverage_matrix_v2.json",
                "cabt_lifecycle_coverage_matrix_v2.json",
                "cabt_time_profile_v2.json",
                "cabt_search_capability_v2.json",
                "cabt_fault_taxonomy_v2.json",
            )
        },
        "contexts_raw": list(range(49)),
        "option_types_raw": list(range(17)),
        "select_types_raw": list(range(11)),
        "lifecycle_rows": [row["lifecycle_id"] for row in lifecycle["rows"]],
        "four_statuses": {
            "prompt_all_green": all_prompt_green,
            "lifecycle_all_green": all_lifecycle_green,
        },
        "levels": {
            "A1.0_Source_Schema": "pass",
            "A1.2_Window": "pass" if all_prompt_green else "pending",
            "A1.3_Lifecycle": "pass" if all_lifecycle_green else "pending",
            "A1.4_Logs": "pass" if all_prompt_green and all_lifecycle_green else "pending",
            "A1.T": "pass_godot_profile_not_official_clock",
            "A1.S": "pass_search_none",
        },
        "search_capability": "none",
        "time_profile": {
            "profile_id": time_profile.profile_id,
            "profile_hash": time_profile.profile_hash,
            "time_authority": time_profile.time_authority,
        },
        "core_selection_interface_aligned": all_prompt_green and all_lifecycle_green,
        "full_official_api_aligned": False,
        "unsupported": ["Search=official_native", "official_native_clock_execution"],
        "known_differences": census["actual_wire_differences"],
        "claim": "A1 core selection interface pass for contexts 0..48; Search=none; Godot development time profile",
        "evidence": [
            "tests/ptcgdap/test_cabt_window_v2.py",
            "tests/ptcgdap/test_cabt_match_lifecycle_v2.py",
            "tests/ptcgdap/test_cabt_time_search_v2.py",
            "tests/ptcgdap/godot/test_cabt_decision_port_v2.gd",
            "tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd",
            "tests/test_game_state_machine.gd",
        ],
    }
    report["scope_sha256"] = hashlib.sha256(jcs_canonical_json_bytes(report)).hexdigest().upper()
    return report


__all__ = ["build_a1_scope"]
