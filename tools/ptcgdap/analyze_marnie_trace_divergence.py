from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path


R54_RULE_PREFIXES = (
    "search.arven-empty",
    "search.secret-box",
    "tm-evolution-target",
    "search.artazon-munkidori-late",
    "search.artazon-reject",
    "main.reject-late",
    "main.bench-munkidori-late",
    "night-stretcher.",
    "attach.exact-two",
    "main.spikemuth-backup",
)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _selected_descriptions(decision: dict[str, object]) -> list[dict[str, object]]:
    policy = decision["policy"]
    frame = decision["frame"]
    options = frame["options"]
    return [
        {
            "index": index,
            "kind": options[index].get("kind"),
            "card_uid": options[index].get("card_uid"),
            "source_uid": options[index].get("source_uid"),
            "target_uid": options[index].get("target_uid"),
        }
        for index in policy.get("reported_indexes", [])
    ]


def _selected_r54_rules(decision: dict[str, object]) -> list[str]:
    policy = decision["policy"]
    selected = set(policy.get("reported_indexes", []))
    scorecards = policy.get("base_result", {}).get("scorecards", [])
    return [
        str(match.get("rule_id"))
        for scorecard in scorecards
        if scorecard.get("index") in selected
        for match in scorecard.get("matched_rules", [])
        if str(match.get("rule_id", "")).startswith(R54_RULE_PREFIXES)
    ]


def compare(base: dict[str, object], candidate: dict[str, object]) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    candidate_games = {
        (game["seed"], game["candidate_seat"]): game
        for game in candidate["per_game"]
    }
    for base_game in base["per_game"]:
        candidate_game = candidate_games.get(
            (base_game["seed"], base_game["candidate_seat"])
        )
        if candidate_game is None:
            continue
        base_decisions = base_game["candidate_developer_decisions"]
        candidate_decisions = candidate_game["candidate_developer_decisions"]
        first = next(
            (
                (index, base_decision, candidate_decision)
                for index, (base_decision, candidate_decision) in enumerate(
                    zip(base_decisions, candidate_decisions)
                )
                if base_decision["policy"].get("reported_indexes")
                != candidate_decision["policy"].get("reported_indexes")
            ),
            None,
        )
        if first is None:
            continue
        decision_index, base_decision, candidate_decision = first
        frame = candidate_decision["frame"]
        rows.append(
            {
                "game": candidate_game["game"],
                "seed": candidate_game["seed"],
                "candidate_seat": candidate_game["candidate_seat"],
                "base_outcome": base_game["candidate_outcome"],
                "candidate_outcome": candidate_game["candidate_outcome"],
                "decision_index": decision_index,
                "turn_number": frame["public_state"]["turn_number"],
                "prompt_kind": frame["prompt_kind"],
                "same_public_observation": (
                    frame["source"]["public_observation_hash"]
                    == base_decision["frame"]["source"]["public_observation_hash"]
                ),
                "base_selected": _selected_descriptions(base_decision),
                "candidate_selected": _selected_descriptions(candidate_decision),
                "candidate_selected_r54_rules": _selected_r54_rules(candidate_decision),
            }
        )
    selected_counts = Counter(
        rule for row in rows for rule in row["candidate_selected_r54_rules"]
    )
    flip_loss_counts = Counter(
        rule
        for row in rows
        if row["base_outcome"] == "win" and row["candidate_outcome"] == "loss"
        for rule in row["candidate_selected_r54_rules"]
    )
    return {
        "base_wins": base["candidate_wins"],
        "candidate_wins": candidate["candidate_wins"],
        "first_divergence_count": len(rows),
        "first_divergences": rows,
        "selected_r54_rule_counts": dict(selected_counts.most_common()),
        "flip_to_loss_r54_rule_counts": dict(flip_loss_counts.most_common()),
    }


def development_summary(report: dict[str, object]) -> list[dict[str, object]]:
    tracked = {
        "grimmsnarl": "CSV10C_148",
        "froslass": "CSV7C_059",
        "munkidori": "CSV8C_094",
        "budew": "CSV9.5C_004",
    }
    summaries: list[dict[str, object]] = []
    for game in report["per_game"]:
        maxima = {name: 0 for name in tracked}
        earliest: dict[str, int | None] = {name: None for name in tracked}
        selected_attacks = 0
        selected_munkidori_abilities = 0
        last_state: dict[str, object] = {}
        for decision in game["candidate_developer_decisions"]:
            frame = decision["frame"]
            last_state = frame["public_state"]
            own = last_state["self"]
            board = [*own["active"], *own["bench"]]
            turn = last_state["turn_number"]
            for name, uid in tracked.items():
                count = sum(card.get("local_card_uid") == uid for card in board)
                maxima[name] = max(maxima[name], count)
                if count > 0 and earliest[name] is None:
                    earliest[name] = turn
            for index in decision["policy"].get("reported_indexes", []):
                option = frame["options"][index]
                if option.get("kind") in {"attack", "granted_attack"}:
                    selected_attacks += 1
                if (
                    option.get("kind") == "use_ability"
                    and option.get("source_uid") == "CSV8C_094"
                ):
                    selected_munkidori_abilities += 1
        summaries.append(
            {
                "game": game["game"],
                "seed": game["seed"],
                "candidate_seat": game["candidate_seat"],
                "outcome": game["candidate_outcome"],
                "win_reason": game["win_reason"],
                "steps": game["steps"],
                "maxima": maxima,
                "earliest_turn": earliest,
                "selected_attacks": selected_attacks,
                "selected_munkidori_abilities": selected_munkidori_abilities,
                "final_self_prizes": last_state.get("self", {}).get("prizes_remaining"),
                "final_opponent_prizes": last_state.get("opponent", {}).get("prizes_remaining"),
            }
        )
    return summaries


def decision_timeline(
    report: dict[str, object], game_number: int, compact: bool = False,
    turn_max: int | None = None,
) -> dict[str, object]:
    game = next(game for game in report["per_game"] if game["game"] == game_number)
    rows: list[dict[str, object]] = []
    for decision in game["candidate_developer_decisions"]:
        frame = decision["frame"]
        if turn_max is not None and frame["public_state"]["turn_number"] > turn_max:
            continue
        if compact and frame["prompt_kind"] not in {
            "main",
            "search",
            "effect_target",
            "evolve",
            "send_out",
        }:
            continue
        own = frame["public_state"]["self"]
        policy = decision["policy"]
        selected = set(policy.get("reported_indexes", []))
        scorecards = policy.get("base_result", {}).get("scorecards", [])
        rows.append(
            {
                "sequence": frame["sequence"],
                "turn_number": frame["public_state"]["turn_number"],
                "prompt_kind": frame["prompt_kind"],
                "hand": [card.get("local_card_uid") for card in own["hand"]],
                "active": [
                    [card.get("local_card_uid"), card.get("attached_energy_count")]
                    for card in own["active"]
                ],
                "bench": [
                    [card.get("local_card_uid"), card.get("attached_energy_count")]
                    for card in own["bench"]
                ],
                "selected": _selected_descriptions(decision),
                "selected_rules": [
                    match.get("rule_id")
                    for scorecard in scorecards
                    if scorecard.get("index") in selected
                    for match in scorecard.get("matched_rules", [])
                ],
            }
        )
    return {
        "game": game_number,
        "outcome": game["candidate_outcome"],
        "win_reason": game["win_reason"],
        "timeline": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--timeline", choices=("base", "candidate"))
    parser.add_argument("--game", type=int)
    parser.add_argument("--compact", action="store_true")
    parser.add_argument("--turn-max", type=int)
    args = parser.parse_args()
    base = _load(args.base)
    candidate = _load(args.candidate)
    if args.timeline:
        if args.game is None:
            parser.error("--timeline requires --game")
        result = decision_timeline(
            base if args.timeline == "base" else candidate,
            args.game,
            compact=args.compact,
            turn_max=args.turn_max,
        )
    elif args.development:
        result = {
            "base": development_summary(base),
            "candidate": development_summary(candidate),
        }
    else:
        result = compare(base, candidate)
    print(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
