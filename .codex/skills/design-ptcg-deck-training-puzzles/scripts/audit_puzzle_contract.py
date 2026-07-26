#!/usr/bin/env python3
"""Static admission audit for authored PTCG deck-training puzzle contracts."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


MIN_HAND = 5
MIN_HAND_CATEGORIES = 3
DEFAULT_BENCH_CAPACITY = 5
MIN_BAITS = 2
MIN_ACTIONS = 5
MIN_DECISIONS = 3
MIN_PLAUSIBLE_OPENINGS = 3
MIN_WINNING_ROUTE_STEPS = 3
MIN_COMEBACK_STEPS = 3
MIN_DRAW_TRACE = 2
MIN_FILTERING_CHECKPOINTS_BEFORE_FINISHER = 2


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def card_uid(entry: dict[str, Any]) -> str:
    set_code = str(entry.get("set_code", "")).strip()
    index = str(entry.get("card_index", "")).strip()
    return f"{set_code}_{index}" if set_code and index else ""


def load_deck_cards(
    project_root: Path, deck_id: int
) -> tuple[set[str], dict[str, str], dict[str, int]]:
    deck_path = project_root / "data" / "bundled_user" / "decks" / f"{deck_id}.json"
    deck = load_json(deck_path)
    uids: set[str] = set()
    categories: dict[str, str] = {}
    counts: dict[str, int] = {}
    for raw in deck.get("cards", []):
        if not isinstance(raw, dict):
            continue
        uid = card_uid(raw)
        if not uid:
            continue
        uids.add(uid)
        categories[uid] = str(raw.get("card_type", "")).strip()
        counts[uid] = counts.get(uid, 0) + int(raw.get("count", 0))
    return uids, categories, counts


def normalize_category(value: str) -> str:
    normalized = value.strip().lower().replace("_", " ")
    if "energy" in normalized or "能量" in normalized:
        return "Energy"
    aliases = {
        "pokemon": "Pokemon",
        "pokémon": "Pokemon",
        "宝可梦": "Pokemon",
        "supporter": "Supporter",
        "支援者": "Supporter",
        "item": "Item",
        "物品": "Item",
        "tool": "Tool",
        "宝可梦道具": "Tool",
        "stadium": "Stadium",
        "竞技场": "Stadium",
    }
    return aliases.get(normalized, value.strip())


def scenario_fingerprint(scenario: dict[str, Any]) -> str:
    payload = {
        "player": scenario.get("player", {}),
        "opponent": scenario.get("opponent", {}),
        "goal": scenario.get("goal", {}),
    }
    return json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def audit_scenario(scenario: dict[str, Any], project_root: Path | None = None) -> list[str]:
    sid = str(scenario.get("id", "<missing-id>"))
    errors: list[str] = []
    design = scenario.get("design_contract")
    if not isinstance(design, dict):
        return [f"{sid}: missing design_contract"]

    hand = list((scenario.get("player") or {}).get("hand", []))
    key_cards = list(design.get("key_cards", []))
    key_card_roles = (
        design.get("key_card_roles")
        if isinstance(design.get("key_card_roles"), dict)
        else {}
    )
    decoys = list(design.get("initial_hand_decoys", []))
    checkpoints = list(design.get("draw_checkpoints", []))
    baits = list(design.get("bait_lines", []))
    math_rows = list(design.get("damage_math", []))
    energy_rows = list(design.get("energy_math", []))
    witness = design.get("witness") if isinstance(design.get("witness"), dict) else {}
    exemptions = list(design.get("board_exemptions", []))
    exemption_reasons = (
        design.get("board_exemption_reasons")
        if isinstance(design.get("board_exemption_reasons"), dict)
        else {}
    )
    board_capacity = (
        design.get("board_capacity")
        if isinstance(design.get("board_capacity"), dict)
        else {}
    )
    random_hand = (
        design.get("random_hand_profile")
        if isinstance(design.get("random_hand_profile"), dict)
        else {}
    )
    combo = design.get("combo_contract") if isinstance(design.get("combo_contract"), dict) else {}
    winning_route = (
        design.get("winning_draw_route")
        if isinstance(design.get("winning_draw_route"), dict)
        else {}
    )
    luck = design.get("luck_contract") if isinstance(design.get("luck_contract"), dict) else {}
    climax = (
        design.get("climax_contract")
        if isinstance(design.get("climax_contract"), dict)
        else {}
    )
    board_history = (
        design.get("board_history")
        if isinstance(design.get("board_history"), dict)
        else {}
    )
    board_roles = (
        design.get("board_roles")
        if isinstance(design.get("board_roles"), dict)
        else {}
    )

    if len(hand) < MIN_HAND:
        errors.append(f"{sid}: initial hand has {len(hand)} cards; require >= {MIN_HAND}")
    if not str(design.get("deck_identity", "")).strip():
        errors.append(f"{sid}: deck_identity is required")
    if not bool(design.get("solution_key_inventory_complete", False)):
        errors.append(f"{sid}: solution_key_inventory_complete must be true")
    if not key_cards:
        errors.append(f"{sid}: key_cards must enumerate the hidden solution cards")
    elif len(key_cards) != len(set(str(key) for key in key_cards)):
        errors.append(f"{sid}: key_cards must be a distinct complete manifest")
    for key in key_cards:
        if key in hand:
            errors.append(f"{sid}: key card {key} is already in the initial hand")
        if not str(key_card_roles.get(str(key), "")).strip():
            errors.append(f"{sid}: key card {key} has no declared key_card_roles entry")
    if len(set(str(decoy) for decoy in decoys)) < 2:
        errors.append(f"{sid}: require at least 2 declared initial-hand decoys")
    if any(decoy not in hand for decoy in decoys):
        errors.append(f"{sid}: every initial_hand_decoy must occur in player.hand")
    awkward_cards = list(random_hand.get("awkward_cards", []))
    redundant_cards = list(random_hand.get("redundant_cards", []))
    if not awkward_cards:
        errors.append(f"{sid}: random_hand_profile must declare at least 1 awkward card")
    if not redundant_cards:
        errors.append(f"{sid}: random_hand_profile must declare at least 1 redundant card")
    declared_hand_cards = awkward_cards + redundant_cards
    if any(uid not in hand for uid in declared_hand_cards):
        errors.append(f"{sid}: random_hand_profile cards must occur in player.hand")
    functional_categories = {
        str(category).strip()
        for category in random_hand.get("functional_categories", [])
        if str(category).strip()
    }
    if len(functional_categories) < MIN_HAND_CATEGORIES:
        errors.append(
            f"{sid}: random_hand_profile must declare >= {MIN_HAND_CATEGORIES} functional categories"
        )
    plausible_openings = {
        str(opening).strip()
        for opening in random_hand.get("plausible_openings", [])
        if str(opening).strip()
    }
    if len(plausible_openings) < MIN_PLAUSIBLE_OPENINGS:
        errors.append(
            f"{sid}: random-looking hand must declare >= {MIN_PLAUSIBLE_OPENINGS} plausible openings"
        )
    combo_required = {"prerequisites", "ordered_steps", "payoff", "reordered_failure"}
    if any(not combo.get(field) for field in combo_required):
        errors.append(f"{sid}: combo_contract is missing identity/order/payoff/failure evidence")
    elif len(combo.get("ordered_steps", [])) < MIN_WINNING_ROUTE_STEPS:
        errors.append(
            f"{sid}: combo_contract must contain >= {MIN_WINNING_ROUTE_STEPS} ordered steps"
        )
    if not checkpoints:
        errors.append(f"{sid}: require at least 1 ordered draw checkpoint")
    checkpoint_required = {
        "order",
        "source",
        "acquisition_kind",
        "reveals",
        "must_precede",
        "reason",
    }
    allowed_acquisition_kinds = {
        "ability_draw",
        "natural_draw",
        "prize_pickup",
        "effect_reveal",
        "search",
        "recovery",
        "topdeck_placement",
    }
    hidden_acquisition_kinds = {
        "ability_draw",
        "natural_draw",
        "prize_pickup",
        "effect_reveal",
    }
    reveal_acquisition: dict[str, list[str]] = {}
    checkpoint_orders: list[int] = []
    for index, checkpoint in enumerate(checkpoints):
        if not isinstance(checkpoint, dict) or any(
            field not in checkpoint or checkpoint.get(field) in ("", [], None)
            for field in checkpoint_required
        ):
            errors.append(f"{sid}: draw_checkpoints[{index}] is incomplete")
            continue
        try:
            checkpoint_orders.append(int(checkpoint["order"]))
        except (TypeError, ValueError):
            errors.append(f"{sid}: draw_checkpoints[{index}].order must be an integer")
        acquisition_kind = str(checkpoint["acquisition_kind"]).strip()
        if acquisition_kind not in allowed_acquisition_kinds:
            errors.append(
                f"{sid}: draw_checkpoints[{index}] has unknown acquisition_kind "
                f"{acquisition_kind!r}"
            )
        for uid in checkpoint.get("reveals", []):
            reveal_uid = str(uid)
            reveal_acquisition.setdefault(reveal_uid, []).append(acquisition_kind)
    if checkpoint_orders and (
        len(checkpoint_orders) != len(set(checkpoint_orders))
        or checkpoint_orders != sorted(checkpoint_orders)
    ):
        errors.append(f"{sid}: draw checkpoint order values must be unique and increasing")
    revealed = {
        str(uid)
        for checkpoint in checkpoints
        if isinstance(checkpoint, dict)
        for uid in checkpoint.get("reveals", [])
    }
    for key in key_cards:
        if key not in revealed:
            errors.append(f"{sid}: key card {key} has no declared acquisition checkpoint")
    hidden_checkpoint_orders = [
        int(checkpoint["order"])
        for checkpoint in checkpoints
        if isinstance(checkpoint, dict)
        and str(checkpoint.get("acquisition_kind", "")).strip()
        in hidden_acquisition_kinds
        and str(checkpoint.get("order", "")).lstrip("-").isdigit()
    ]
    searched_key_orders = [
        int(checkpoint["order"])
        for checkpoint in checkpoints
        if isinstance(checkpoint, dict)
        and str(checkpoint.get("acquisition_kind", "")).strip() in {"search", "recovery"}
        and any(str(uid) in key_cards for uid in checkpoint.get("reveals", []))
        and str(checkpoint.get("order", "")).lstrip("-").isdigit()
    ]
    if searched_key_orders and (
        not hidden_checkpoint_orders
        or min(hidden_checkpoint_orders) > min(searched_key_orders)
    ):
        errors.append(
            f"{sid}: key-card acquisition graph must be rooted in a hidden "
            "draw/reveal before search or recovery"
        )
    route_required = {
        "opening",
        "sequence",
        "draw_trace",
        "hidden_reveal",
        "order_sensitive_pair",
        "exact_reason",
    }
    if any(not winning_route.get(field) for field in route_required):
        errors.append(f"{sid}: winning_draw_route is incomplete")
    elif len(winning_route.get("sequence", [])) < MIN_WINNING_ROUTE_STEPS:
        errors.append(
            f"{sid}: winning draw route must contain >= {MIN_WINNING_ROUTE_STEPS} steps"
        )
    draw_trace = winning_route.get("draw_trace", [])
    if not isinstance(draw_trace, list) or len(draw_trace) < MIN_DRAW_TRACE:
        errors.append(
            f"{sid}: winning draw route must record >= {MIN_DRAW_TRACE} actual "
            "draw/reveal results"
        )
    hidden_reveals_raw = winning_route.get("hidden_reveal", [])
    hidden_reveals = (
        [str(uid) for uid in hidden_reveals_raw]
        if isinstance(hidden_reveals_raw, list)
        else [str(hidden_reveals_raw)]
    )
    for hidden_uid in hidden_reveals:
        if hidden_uid not in key_cards:
            errors.append(
                f"{sid}: hidden reveal {hidden_uid} must be declared as a solution key card"
            )
        if hidden_uid not in revealed:
            errors.append(
                f"{sid}: hidden reveal {hidden_uid} has no declared acquisition checkpoint"
            )
        if hidden_uid in hand:
            errors.append(
                f"{sid}: hidden reveal {hidden_uid} is already visible in the initial hand"
            )
        if not any(
            kind in hidden_acquisition_kinds
            for kind in reveal_acquisition.get(hidden_uid, [])
        ):
            errors.append(
                f"{sid}: hidden reveal {hidden_uid} must come from a draw/reveal/prize "
                "checkpoint, not search or recovery"
            )
    if len(baits) < MIN_BAITS:
        errors.append(f"{sid}: require at least {MIN_BAITS} lure lines")
    bait_ids: list[str] = []
    bait_openings: list[str] = []
    bait_failures: list[str] = []
    bait_probe_ids: list[str] = []
    for index, bait in enumerate(baits):
        required = {
            "id",
            "opening",
            "looks_good_because",
            "gained_information",
            "draw_trace",
            "consumed_resource",
            "fails_because",
            "failed_equation",
            "negative_probe_id",
        }
        if not isinstance(bait, dict) or any(not str(bait.get(field, "")).strip() for field in required):
            errors.append(f"{sid}: bait_lines[{index}] is missing its lure/failure contract")
            continue
        if not isinstance(bait.get("draw_trace"), list) or not bait.get("draw_trace"):
            errors.append(
                f"{sid}: bait_lines[{index}] must record the actual cards/information "
                "reached from the shared hidden state"
            )
        bait_ids.append(str(bait["id"]).strip())
        bait_openings.append(str(bait["opening"]).strip())
        bait_failures.append(
            f"{str(bait['fails_because']).strip()} :: "
            f"{str(bait['failed_equation']).strip()}"
        )
        bait_probe_ids.append(str(bait["negative_probe_id"]).strip())
    for label, values in (
        ("ids", bait_ids),
        ("openings", bait_openings),
        ("failure equations", bait_failures),
        ("negative probe ids", bait_probe_ids),
    ):
        if len(values) != len(set(values)):
            errors.append(f"{sid}: lure {label} must be distinct")
    winning_opening = str(winning_route.get("opening", "")).strip()
    if winning_opening and winning_opening in bait_openings:
        errors.append(f"{sid}: winning opening must be distinct from every lure opening")

    if not math_rows:
        errors.append(f"{sid}: require exact damage_math rows")
    for index, row in enumerate(math_rows):
        if not isinstance(row, dict):
            errors.append(f"{sid}: damage_math[{index}] must be an object")
            continue
        printed = int(row.get("printed_hp", 0))
        modifiers = int(row.get("hp_modifiers", 0))
        existing = int(row.get("existing_damage", 0))
        planned = int(row.get("planned_counter_damage", 0))
        remaining = printed + modifiers - existing - planned
        if remaining != int(row.get("remaining_hp", -1)):
            errors.append(f"{sid}: damage_math[{index}] remaining_hp equation is inconsistent")
        if int(row.get("final_damage", 0)) < remaining:
            errors.append(f"{sid}: damage_math[{index}] does not reach the knockout")
        expected_overkill = int(row.get("final_damage", 0)) - remaining
        if printed <= 0:
            errors.append(f"{sid}: damage_math[{index}] printed_hp must be positive")
        is_state_based_counter_ko = (
            remaining == 0
            and int(row.get("final_damage", 0)) == 0
            and bool(str(row.get("payment", "")).strip())
        )
        if existing < 0 or planned < 0 or remaining < 0 or (
            remaining == 0 and not is_state_based_counter_ko
        ):
            errors.append(
                f"{sid}: damage_math[{index}] must describe a live target with "
                "non-negative authored damage"
            )
        if "overkill" not in row:
            errors.append(f"{sid}: damage_math[{index}] must declare overkill")
        elif int(row.get("overkill", -1)) != expected_overkill:
            errors.append(f"{sid}: damage_math[{index}] overkill equation is inconsistent")
    if not energy_rows:
        errors.append(f"{sid}: require exact energy_math rows")
    for index, row in enumerate(energy_rows):
        required = {
            "checkpoint",
            "starting_attached",
            "acquired",
            "spent_or_discarded",
            "attack_requirement",
            "remaining_for_next_turn",
        }
        if not isinstance(row, dict) or any(field not in row for field in required):
            errors.append(f"{sid}: energy_math[{index}] is incomplete")
            continue
        remaining = int(row["starting_attached"]) + int(row["acquired"]) - int(
            row["spent_or_discarded"]
        )
        if remaining != int(row["remaining_for_next_turn"]):
            errors.append(f"{sid}: energy_math[{index}] resource equation is inconsistent")
        if remaining < 0:
            errors.append(f"{sid}: energy_math[{index}] spends more Energy than is available")
        if int(row["starting_attached"]) + int(row["acquired"]) < int(
            row["attack_requirement"]
        ):
            errors.append(f"{sid}: energy_math[{index}] cannot pay the declared attack cost")

    if not bool(luck.get("deterministic", False)):
        errors.append(f"{sid}: luck_contract must be deterministic")
    if not bool(luck.get("same_state_for_all_routes", False)):
        errors.append(f"{sid}: winning and lure routes must use the same frozen hidden state")
    if not str(luck.get("kind", "")).strip():
        errors.append(f"{sid}: luck_contract must declare its deterministic kind")
    if "shuffle_points" not in luck or not isinstance(luck.get("shuffle_points"), list):
        errors.append(f"{sid}: luck_contract must declare shuffle_points, including an empty list")
    reveal_sequence = [str(uid) for uid in luck.get("reveal_sequence", [])]
    if not reveal_sequence:
        errors.append(f"{sid}: luck_contract must declare a reveal_sequence")
    missing_from_luck = sorted(set(str(uid) for uid in key_cards) - set(reveal_sequence))
    if missing_from_luck:
        errors.append(
            f"{sid}: luck_contract.reveal_sequence omits key cards: "
            f"{', '.join(missing_from_luck)}"
        )

    climax_required = {
        "apparent_dead_end",
        "comeback_chain",
        "finisher",
        "finisher_card",
        "finisher_checkpoint_order",
        "filtering_checkpoints_before_finisher",
        "finisher_was_hidden",
        "exact_payoff",
    }
    if any(not climax.get(field) for field in climax_required):
        errors.append(f"{sid}: climax_contract is incomplete")
    elif len(climax.get("comeback_chain", [])) < MIN_COMEBACK_STEPS:
        errors.append(
            f"{sid}: climax comeback_chain must contain >= {MIN_COMEBACK_STEPS} conversions"
        )
    finisher_card = str(climax.get("finisher_card", "")).strip()
    if finisher_card and finisher_card not in [str(uid) for uid in key_cards]:
        errors.append(f"{sid}: climax finisher_card must be in the complete key-card manifest")
    if finisher_card and finisher_card in [str(uid) for uid in hand]:
        errors.append(f"{sid}: climax finisher_card must not be visible in the initial hand")
    try:
        finisher_order = int(climax.get("finisher_checkpoint_order", 0))
    except (TypeError, ValueError):
        finisher_order = 0
    if finisher_order <= 0 or finisher_order not in checkpoint_orders:
        errors.append(
            f"{sid}: climax finisher_checkpoint_order must reference an authored draw checkpoint"
        )
    try:
        filter_count = int(climax.get("filtering_checkpoints_before_finisher", 0))
    except (TypeError, ValueError):
        filter_count = 0
    if filter_count < MIN_FILTERING_CHECKPOINTS_BEFORE_FINISHER:
        errors.append(
            f"{sid}: climax requires >= {MIN_FILTERING_CHECKPOINTS_BEFORE_FINISHER} "
            "filtering checkpoints before the hidden finisher"
        )
    if not bool(climax.get("finisher_was_hidden", False)):
        errors.append(f"{sid}: climax finisher must be authored as hidden information")
    if finisher_order > 0:
        finisher_reveals = {
            str(uid)
            for checkpoint in checkpoints
            if isinstance(checkpoint, dict)
            and str(checkpoint.get("order", "")).lstrip("-").isdigit()
            and int(checkpoint["order"]) == finisher_order
            for uid in checkpoint.get("reveals", [])
        }
        if finisher_card and finisher_card not in finisher_reveals:
            errors.append(
                f"{sid}: climax finisher_card is not revealed by finisher_checkpoint_order"
            )
        earlier_filter_count = sum(
            1
            for checkpoint in checkpoints
            if isinstance(checkpoint, dict)
            and str(checkpoint.get("order", "")).lstrip("-").isdigit()
            and int(checkpoint["order"]) < finisher_order
        )
        if earlier_filter_count < filter_count:
            errors.append(
                f"{sid}: declared filtering checkpoints exceed the checkpoints before "
                "the finisher"
            )

    board_history_required = {
        "elapsed_turns",
        "energy_origins",
        "damage_origins",
        "prize_history",
    }
    if any(
        field not in board_history or board_history.get(field) in ("", [], None, 0)
        for field in board_history_required
    ):
        errors.append(
            f"{sid}: board_history must explain elapsed turns, Energy, damage, and prizes"
        )

    if int(witness.get("player_turns", 0)) != 2:
        errors.append(f"{sid}: witness must encode exactly 2 player turns")
    if int(witness.get("minimum_meaningful_actions", 0)) < MIN_ACTIONS:
        errors.append(f"{sid}: shortest witness must require >= {MIN_ACTIONS} meaningful actions")
    if int(witness.get("irreversible_decisions", 0)) < MIN_DECISIONS:
        errors.append(f"{sid}: require >= {MIN_DECISIONS} irreversible decisions")
    if not bool(witness.get("one_turn_shortcut_refuted", False)):
        errors.append(f"{sid}: one-turn shortcut must be explicitly refuted")
    if len(scenario.get("validation_operations", [])) < 8:
        errors.append(f"{sid}: require at least 8 authored validation operations/events")

    player_bench = list((scenario.get("player") or {}).get("bench", []))
    opponent_bench = list((scenario.get("opponent") or {}).get("bench", []))
    required_board_roles = [
        "player.active",
        *(f"player.bench.{index}" for index in range(len(player_bench))),
        "opponent.active",
        *(f"opponent.bench.{index}" for index in range(len(opponent_bench))),
    ]
    for role_key in required_board_roles:
        role = str(board_roles.get(role_key, "")).strip()
        if not role:
            errors.append(f"{sid}: board_roles.{role_key} is required")
        elif role.lower() in {"filler", "decoration", "decorative", "占位", "填充"}:
            errors.append(f"{sid}: board_roles.{role_key} may not be decorative filler")
    for side_key, bench in (
        ("player_bench", player_bench),
        ("opponent_bench", opponent_bench),
    ):
        try:
            capacity = int(board_capacity.get(side_key, DEFAULT_BENCH_CAPACITY))
        except (TypeError, ValueError):
            capacity = 0
        if capacity <= 0:
            errors.append(f"{sid}: board_capacity.{side_key} must be a positive integer")
            continue
        if len(bench) > capacity:
            errors.append(
                f"{sid}: {side_key} has {len(bench)} slots, above declared capacity {capacity}"
            )
        if len(bench) < capacity and side_key not in exemptions:
            errors.append(
                f"{sid}: {side_key} has {len(bench)}/{capacity} occupied slots; "
                "fill it or declare an exemption"
            )
        if side_key in exemptions and not str(exemption_reasons.get(side_key, "")).strip():
            errors.append(f"{sid}: {side_key} exemption requires an exact reason")

    if project_root is not None:
        deck_uids, categories, counts = load_deck_cards(
            project_root, int(scenario.get("player_deck_id", 0))
        )
        unknown = sorted({str(uid) for uid in key_cards + hand if str(uid) not in deck_uids})
        if unknown:
            errors.append(f"{sid}: cards absent from frozen player deck: {', '.join(unknown)}")
        for uid, amount in Counter(str(card) for card in hand).items():
            if amount > counts.get(uid, 0):
                errors.append(
                    f"{sid}: initial hand contains {amount}x {uid}, above frozen-list count "
                    f"{counts.get(uid, 0)}"
                )
        hand_categories = {
            normalize_category(categories.get(str(uid), "")) for uid in hand
        }
        hand_categories.discard("")
        if len(hand_categories) < MIN_HAND_CATEGORIES:
            errors.append(
                f"{sid}: initial hand has {len(hand_categories)} card categories; "
                f"require >= {MIN_HAND_CATEGORIES}"
            )
        declared_categories = {
            normalize_category(str(category))
            for category in random_hand.get("functional_categories", [])
            if str(category).strip()
        }
        unsupported_categories = sorted(declared_categories - hand_categories)
        if unsupported_categories:
            errors.append(
                f"{sid}: random_hand_profile declares categories absent from hand: "
                f"{', '.join(unsupported_categories)}"
            )
    return errors


def audit_catalog(
    catalog: dict[str, Any],
    project_root: Path | None,
    deck_key: str,
    scenario_id: str = "",
) -> list[str]:
    scenarios = [
        item
        for item in catalog.get("scenarios", [])
        if isinstance(item, dict)
        and (not deck_key or str(item.get("deck_key", "")) == deck_key)
        and (not scenario_id or str(item.get("id", "")) == scenario_id)
    ]
    if not scenarios:
        return ["no matching scenarios"]
    errors: list[str] = []
    fingerprints = Counter(scenario_fingerprint(scenario) for scenario in scenarios)
    duplicates = {fingerprint for fingerprint, count in fingerprints.items() if count > 1}
    for scenario in scenarios:
        errors.extend(audit_scenario(scenario, project_root))
        if scenario_fingerprint(scenario) in duplicates:
            errors.append(f"{scenario.get('id', '<missing-id>')}: board fingerprint is duplicated")
    return errors


def valid_fixture() -> dict[str, Any]:
    return {
        "id": "fixture",
        "player": {
            "hand": ["P", "S", "I", "D1", "D2"],
            "bench": [{}, {}, {}, {}, {}],
        },
        "opponent": {"bench": [{}, {}, {}, {}, {}]},
        "validation_operations": list(range(8)),
        "design_contract": {
            "deck_identity": "fixture draw engine converts hidden information into exact damage",
            "solution_key_inventory_complete": True,
            "key_cards": ["K1", "K2"],
            "key_card_roles": {"K1": "hidden bridge", "K2": "searched payoff"},
            "initial_hand_decoys": ["D1", "D2"],
            "random_hand_profile": {
                "functional_categories": ["Pokemon", "Supporter", "Item"],
                "awkward_cards": ["D1"],
                "redundant_cards": ["D2"],
                "plausible_openings": ["draw", "supporter", "search"],
            },
            "combo_contract": {
                "prerequisites": ["engine"],
                "ordered_steps": ["draw", "search", "attack"],
                "payoff": "exact knockout",
                "reordered_failure": "supporter quota is consumed",
            },
            "draw_checkpoints": [
                {
                    "order": 1,
                    "source": "ability",
                    "acquisition_kind": "ability_draw",
                    "reveals": ["K1"],
                    "must_precede": "supporter",
                    "reason": "preserve quota",
                },
                {
                    "order": 2,
                    "source": "filter",
                    "acquisition_kind": "effect_reveal",
                    "reveals": ["F1"],
                    "must_precede": "search",
                    "reason": "confirm the second information checkpoint",
                },
                {
                    "order": 3,
                    "source": "search",
                    "acquisition_kind": "search",
                    "reveals": ["K2"],
                    "must_precede": "attack",
                    "reason": "complete payment",
                },
            ],
            "winning_draw_route": {
                "opening": "draw",
                "sequence": ["draw", "search", "attack"],
                "draw_trace": ["K1", "F1", "K2"],
                "hidden_reveal": "K1",
                "order_sensitive_pair": ["draw", "search"],
                "exact_reason": "preserves the only search",
            },
            "bait_lines": [
                {
                    "id": "a",
                    "opening": "S",
                    "looks_good_because": "draw",
                    "gained_information": "seven cards",
                    "draw_trace": ["D3", "D4", "D5"],
                    "consumed_resource": "supporter quota",
                    "fails_because": "quota",
                    "failed_equation": "zero supporters remain",
                    "negative_probe_id": "a_probe",
                },
                {
                    "id": "b",
                    "opening": "I",
                    "looks_good_because": "search",
                    "gained_information": "deck contents",
                    "draw_trace": ["P2"],
                    "consumed_resource": "topdeck order",
                    "fails_because": "shuffle",
                    "failed_equation": "one key card is lost",
                    "negative_probe_id": "b_probe",
                },
            ],
            "damage_math": [
                {
                    "printed_hp": 240,
                    "hp_modifiers": 0,
                    "existing_damage": 40,
                    "planned_counter_damage": 0,
                    "remaining_hp": 200,
                    "final_damage": 200,
                    "overkill": 0,
                }
            ],
            "energy_math": [
                {
                    "checkpoint": "attack",
                    "starting_attached": 1,
                    "acquired": 2,
                    "spent_or_discarded": 2,
                    "attack_requirement": 1,
                    "remaining_for_next_turn": 1,
                }
            ],
            "luck_contract": {
                "kind": "ordered_hidden_topdeck",
                "deterministic": True,
                "same_state_for_all_routes": True,
                "shuffle_points": ["search"],
                "reveal_sequence": ["K1", "K2"],
            },
            "climax_contract": {
                "apparent_dead_end": "behind on prizes",
                "comeback_chain": ["draw", "recover", "gust"],
                "finisher": "gust",
                "finisher_card": "K2",
                "finisher_checkpoint_order": 3,
                "filtering_checkpoints_before_finisher": 2,
                "finisher_was_hidden": True,
                "exact_payoff": "take four prizes",
            },
            "board_history": {
                "elapsed_turns": 5,
                "energy_origins": ["three legal attachments and one acceleration"],
                "damage_origins": ["opponent's previous 200-damage attack"],
                "prize_history": ["both players have taken two Prizes"],
            },
            "board_exemptions": [],
            "board_exemption_reasons": {},
            "board_capacity": {"player_bench": 5, "opponent_bench": 5},
            "board_roles": {
                "player.active": "draw engine and attacker",
                "player.bench.0": "second attacker",
                "player.bench.1": "recovery engine",
                "player.bench.2": "pivot",
                "player.bench.3": "gust liability",
                "player.bench.4": "future lane",
                "opponent.active": "first exact target",
                "opponent.bench.0": "second exact target",
                "opponent.bench.1": "ability engine",
                "opponent.bench.2": "pivot",
                "opponent.bench.3": "gust bait",
                "opponent.bench.4": "future attacker",
            },
            "witness": {
                "player_turns": 2,
                "minimum_meaningful_actions": 7,
                "irreversible_decisions": 3,
                "one_turn_shortcut_refuted": True,
            },
        },
    }


def run_self_test() -> int:
    if audit_scenario(valid_fixture()):
        print("self-test failed: valid fixture was rejected")
        return 1
    bad = valid_fixture()
    bad["player"]["hand"].append("K1")
    bad["design_contract"]["bait_lines"] = []
    errors = audit_scenario(bad)
    if not any("already in the initial hand" in error for error in errors):
        print("self-test failed: key-card-in-hand defect was missed")
        return 1
    if not any("lure lines" in error for error in errors):
        print("self-test failed: lure-line defect was missed")
        return 1
    bad_hidden = valid_fixture()
    bad_hidden["design_contract"]["winning_draw_route"]["hidden_reveal"] = "NOT_A_KEY"
    errors = audit_scenario(bad_hidden)
    if not any("must be declared as a solution key card" in error for error in errors):
        print("self-test failed: non-key hidden reveal defect was missed")
        return 1
    duplicate_lure = valid_fixture()
    duplicate_lure["design_contract"]["bait_lines"][1]["opening"] = "S"
    errors = audit_scenario(duplicate_lure)
    if not any("lure openings must be distinct" in error for error in errors):
        print("self-test failed: duplicate lure opening defect was missed")
        return 1
    incomplete_inventory = valid_fixture()
    incomplete_inventory["design_contract"]["solution_key_inventory_complete"] = False
    incomplete_inventory["design_contract"]["key_card_roles"].pop("K2")
    errors = audit_scenario(incomplete_inventory)
    if not any("solution_key_inventory_complete" in error for error in errors):
        print("self-test failed: incomplete key inventory assertion was missed")
        return 1
    if not any("key_card_roles" in error for error in errors):
        print("self-test failed: missing key-card role was missed")
        return 1
    incomplete_lure = valid_fixture()
    incomplete_lure["design_contract"]["bait_lines"][0].pop("failed_equation")
    errors = audit_scenario(incomplete_lure)
    if not any("lure/failure contract" in error for error in errors):
        print("self-test failed: incomplete lure equation was missed")
        return 1
    underfilled_board = valid_fixture()
    underfilled_board["player"]["bench"].pop()
    errors = audit_scenario(underfilled_board)
    if not any("fill it or declare an exemption" in error for error in errors):
        print("self-test failed: underfilled Bench was missed")
        return 1
    searched_hidden_reveal = valid_fixture()
    searched_hidden_reveal["design_contract"]["draw_checkpoints"][0][
        "acquisition_kind"
    ] = "search"
    errors = audit_scenario(searched_hidden_reveal)
    if not any("must come from a draw/reveal/prize checkpoint" in error for error in errors):
        print("self-test failed: searched hidden reveal was missed")
        return 1
    bad_overkill = valid_fixture()
    bad_overkill["design_contract"]["damage_math"][0]["overkill"] = 99
    errors = audit_scenario(bad_overkill)
    if not any("overkill equation is inconsistent" in error for error in errors):
        print("self-test failed: inconsistent overkill was missed")
        return 1
    missing_board_role = valid_fixture()
    missing_board_role["design_contract"]["board_roles"].pop("player.bench.4")
    errors = audit_scenario(missing_board_role)
    if not any("board_roles.player.bench.4 is required" in error for error in errors):
        print("self-test failed: missing board role was missed")
        return 1
    search_before_draw = valid_fixture()
    search_before_draw["design_contract"]["draw_checkpoints"][0][
        "acquisition_kind"
    ] = "search"
    search_before_draw["design_contract"]["draw_checkpoints"][2][
        "acquisition_kind"
    ] = "ability_draw"
    errors = audit_scenario(search_before_draw)
    if not any("must be rooted in a hidden draw/reveal" in error for error in errors):
        print("self-test failed: search-before-hidden-draw defect was missed")
        return 1
    duplicate_keys = valid_fixture()
    duplicate_keys["design_contract"]["key_cards"].append("K1")
    errors = audit_scenario(duplicate_keys)
    if not any("distinct complete manifest" in error for error in errors):
        print("self-test failed: duplicate key-card manifest entry was missed")
        return 1
    missing_random_role = valid_fixture()
    missing_random_role["design_contract"]["random_hand_profile"]["awkward_cards"] = []
    errors = audit_scenario(missing_random_role)
    if not any("at least 1 awkward card" in error for error in errors):
        print("self-test failed: missing awkward hand card was missed")
        return 1
    shared_opening = valid_fixture()
    shared_opening["design_contract"]["winning_draw_route"]["opening"] = "S"
    errors = audit_scenario(shared_opening)
    if not any("winning opening must be distinct" in error for error in errors):
        print("self-test failed: shared winning/lure opening was missed")
        return 1
    incomplete_luck = valid_fixture()
    incomplete_luck["design_contract"]["luck_contract"]["reveal_sequence"] = ["K1"]
    errors = audit_scenario(incomplete_luck)
    if not any("reveal_sequence omits key cards" in error for error in errors):
        print("self-test failed: incomplete luck reveal sequence was missed")
        return 1
    missing_winning_trace = valid_fixture()
    missing_winning_trace["design_contract"]["winning_draw_route"]["draw_trace"] = []
    errors = audit_scenario(missing_winning_trace)
    if not any("actual draw/reveal results" in error for error in errors):
        print("self-test failed: missing winning draw trace was missed")
        return 1
    missing_lure_trace = valid_fixture()
    missing_lure_trace["design_contract"]["bait_lines"][0]["draw_trace"] = []
    errors = audit_scenario(missing_lure_trace)
    if not any("actual cards/information" in error for error in errors):
        print("self-test failed: missing lure draw trace was missed")
        return 1
    visible_finisher = valid_fixture()
    visible_finisher["player"]["hand"].append("K2")
    errors = audit_scenario(visible_finisher)
    if not any("finisher_card must not be visible" in error for error in errors):
        print("self-test failed: visible climax finisher was missed")
        return 1
    premature_finisher = valid_fixture()
    premature_finisher["design_contract"]["climax_contract"][
        "finisher_checkpoint_order"
    ] = 2
    errors = audit_scenario(premature_finisher)
    if not any("finisher_card is not revealed" in error for error in errors):
        print("self-test failed: premature climax finisher was missed")
        return 1
    missing_board_history = valid_fixture()
    missing_board_history["design_contract"]["board_history"]["damage_origins"] = []
    errors = audit_scenario(missing_board_history)
    if not any("board_history must explain" in error for error in errors):
        print("self-test failed: missing board-history evidence was missed")
        return 1
    print("self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path)
    parser.add_argument("--scenario-file", type=Path)
    parser.add_argument("--deck-key", default="")
    parser.add_argument("--scenario-id", default="")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    if args.project_root is None or args.scenario_file is None:
        parser.error("--project-root and --scenario-file are required unless --self-test is used")
    project_root = args.project_root.resolve()
    scenario_file = args.scenario_file
    if not scenario_file.is_absolute():
        scenario_file = project_root / scenario_file
    errors = audit_catalog(
        load_json(scenario_file),
        project_root,
        args.deck_key,
        args.scenario_id,
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("puzzle contract audit passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
