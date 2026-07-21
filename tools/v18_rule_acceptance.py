#!/usr/bin/env python3
"""Aggregate and gate V18 rule-AI 100-game acceptance results."""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = 1
DEFAULT_GAMES = 100
DEFAULT_MIN_WIN_RATE = 0.50
ALLOWED_END_REASONS = frozenset({"normal_game_end", "deck_out"})
DEFAULT_V18_DECK_IDS = (
    18000230,
    18000625,
    800015734,
    800015934,
    800016834,
    800017047,
    800017097,
    800017407,
    800017631,
    800017643,
    800018105,
    800018359,
    800018497,
    800018498,
    800018499,
    800018500,
    800018501,
    800018502,
    800018509,
    800018539,
    800018543,
    800018880,
    800019125,
    800033475,
)
MODES = ("normal", "strong")


def _godot_user_dir() -> Path:
    if os.name == "nt" and os.environ.get("APPDATA"):
        return Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "PtcgDeckAgent"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / "PtcgDeckAgent"
    return Path.home() / ".local" / "share" / "godot" / "app_userdata" / "PtcgDeckAgent"


def _resolve_user_path(raw_path: str, godot_user_dir: Path) -> str:
    if raw_path.startswith("user://"):
        return str(godot_user_dir / raw_path.removeprefix("user://"))
    return raw_path


def expand_inputs(raw_paths: Iterable[str], godot_user_dir: Path | None = None) -> list[Path]:
    """Expand files, directories, globs, and Godot ``user://`` paths."""
    user_dir = godot_user_dir or _godot_user_dir()
    resolved: dict[str, Path] = {}
    for raw_path in raw_paths:
        expanded = os.path.expandvars(os.path.expanduser(_resolve_user_path(raw_path, user_dir)))
        matches = [Path(item) for item in glob.glob(expanded, recursive=True)]
        if not matches:
            matches = [Path(expanded)]
        for match in matches:
            candidates = sorted(match.rglob("*.json")) if match.is_dir() else [match]
            for candidate in candidates:
                try:
                    key = str(candidate.resolve())
                except OSError:
                    key = str(candidate.absolute())
                resolved[key] = candidate
    return [resolved[key] for key in sorted(resolved)]


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _reason_counts(value: Any) -> dict[str, int]:
    if not isinstance(value, Mapping):
        return {}
    return {str(reason): _as_int(count) for reason, count in value.items()}


def _detect_mode(entry: Mapping[str, Any], source: Path, mode_hint: str | None) -> str | None:
    if mode_hint in MODES:
        return mode_hint
    if "tracked_strong_fixed_opening" in entry:
        return "strong" if bool(entry["tracked_strong_fixed_opening"]) else "normal"
    if "deck_strong_fixed_opening" in entry:
        return "strong" if bool(entry["deck_strong_fixed_opening"]) else "normal"
    lowered_name = source.name.lower()
    if "strong" in lowered_name:
        return "strong"
    if "normal" in lowered_name:
        return "normal"
    return None


def _extract_entries(payload: Any) -> tuple[list[Mapping[str, Any]], list[str]]:
    if not isinstance(payload, Mapping):
        return [], ["JSON root must be an object"]
    errors: list[str] = []
    root_errors = payload.get("errors", [])
    if _as_int(payload.get("error_count"), 0) > 0 or (isinstance(root_errors, list) and root_errors):
        errors.append(f"runner reported errors: {root_errors!r}")
    results = payload.get("results")
    if isinstance(results, list):
        entries = [entry for entry in results if isinstance(entry, Mapping)]
        if len(entries) != len(results):
            errors.append("results contains non-object entries")
        return entries, errors
    if "deck_id" in payload and "games" in payload:
        return [payload], errors
    return [], errors + ["unsupported result schema: expected results[] or a single deck summary"]


def load_records(
    paths_by_mode: Mapping[str | None, Sequence[Path]],
) -> tuple[list[dict[str, Any]], list[str]]:
    """Load sweep and single-summary schemas into a common record format."""
    records: list[dict[str, Any]] = []
    errors: list[str] = []
    for mode_hint, paths in paths_by_mode.items():
        for source in paths:
            try:
                payload = json.loads(source.read_text(encoding="utf-8-sig"))
            except (OSError, UnicodeError, json.JSONDecodeError) as exc:
                errors.append(f"{source}: cannot read JSON: {exc}")
                continue
            entries, payload_errors = _extract_entries(payload)
            errors.extend(f"{source}: {message}" for message in payload_errors)
            for entry in entries:
                mode = _detect_mode(entry, source, mode_hint)
                if mode is None:
                    errors.append(f"{source}: cannot determine normal/strong mode for deck {entry.get('deck_id')}")
                    continue
                details_value = entry.get("games_detail", entry.get("per_game", []))
                details = details_value if isinstance(details_value, list) else []
                reasons = _reason_counts(entry.get("failure_reason_counts", entry.get("failure_reasons", {})))
                records.append(
                    {
                        "deck_id": _as_int(entry.get("deck_id"), -1),
                        "deck_name": str(entry.get("deck_name", "")),
                        "mode": mode,
                        "games": _as_int(entry.get("games")),
                        "wins": _as_int(entry.get("wins")),
                        "losses": _as_int(entry.get("losses")),
                        "draws": _as_int(entry.get("draws")),
                        "reported_win_rate": entry.get("win_rate"),
                        "failure_reason_counts": reasons,
                        "games_detail": details,
                        "source": str(source.resolve()),
                    }
                )
    return records, errors


def _validate_record(record: Mapping[str, Any], games_required: int, min_win_rate: float) -> dict[str, Any]:
    failures: list[str] = []
    games = _as_int(record.get("games"))
    wins = _as_int(record.get("wins"))
    losses = _as_int(record.get("losses"))
    draws = _as_int(record.get("draws"))
    win_rate = float(wins) / games if games > 0 else 0.0
    reasons = _reason_counts(record.get("failure_reason_counts"))
    details = record.get("games_detail", [])
    detail_clean = True

    if games != games_required:
        failures.append(f"expected exactly {games_required} games, got {games}")
    if wins + losses + draws != games:
        failures.append(f"W/L/D total {wins + losses + draws} does not match games {games}")
    if win_rate < min_win_rate:
        failures.append(f"win rate {win_rate:.1%} is below {min_win_rate:.1%}")

    bad_reasons = sorted(reason for reason in reasons if reason not in ALLOWED_END_REASONS)
    if bad_reasons:
        failures.append(f"unclean end reasons: {', '.join(bad_reasons)}")
    if sum(reasons.values()) != games:
        failures.append(f"end-reason total {sum(reasons.values())} does not match games {games}")

    if details or games_required == DEFAULT_GAMES:
        if len(details) != games:
            failures.append(f"per-game detail count {len(details)} does not match games {games}")
            detail_clean = False
        detail_reasons: Counter[str] = Counter()
        dirty_flags = 0
        malformed_details = 0
        for detail in details:
            if not isinstance(detail, Mapping):
                malformed_details += 1
                detail_clean = False
                continue
            detail_reasons[str(detail.get("failure_reason", ""))] += 1
            if bool(detail.get("terminated_by_cap", False)) or bool(detail.get("stalled", False)):
                dirty_flags += 1
        if malformed_details:
            failures.append(f"per-game details contain {malformed_details} non-object entries")
        detail_bad = sorted(reason for reason in detail_reasons if reason not in ALLOWED_END_REASONS)
        if detail_bad:
            failures.append(f"per-game unclean end reasons: {', '.join(detail_bad)}")
            detail_clean = False
        if dirty_flags:
            failures.append(f"{dirty_flags} games are marked stalled or terminated by cap")
            detail_clean = False
        if dict(detail_reasons) != reasons:
            failures.append("per-game end reasons do not match summary counts")
            detail_clean = False

    reported_rate = record.get("reported_win_rate")
    try:
        if reported_rate is not None and abs(float(reported_rate) - win_rate) > 1e-9:
            failures.append(f"reported win rate {float(reported_rate):.3f} does not match W/G {win_rate:.3f}")
    except (TypeError, ValueError):
        failures.append("reported win rate is not numeric")

    return {
        "deck_id": _as_int(record.get("deck_id"), -1),
        "deck_name": str(record.get("deck_name", "")),
        "mode": str(record.get("mode", "")),
        "games": games,
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "win_rate": win_rate,
        "failure_reason_counts": reasons,
        "clean": not bad_reasons and sum(reasons.values()) == games and detail_clean,
        "source": str(record.get("source", "")),
        "passed": not failures,
        "failures": failures,
    }


def evaluate_acceptance(
    records: Sequence[Mapping[str, Any]],
    expected_deck_ids: Sequence[int] = DEFAULT_V18_DECK_IDS,
    games_required: int = DEFAULT_GAMES,
    min_win_rate: float = DEFAULT_MIN_WIN_RATE,
    input_errors: Sequence[str] = (),
) -> dict[str, Any]:
    expected = tuple(dict.fromkeys(int(deck_id) for deck_id in expected_deck_ids))
    rows: list[dict[str, Any]] = []
    errors = list(input_errors)
    grouped: dict[tuple[int, str], list[Mapping[str, Any]]] = {}
    expected_set = set(expected)

    for record in records:
        deck_id = _as_int(record.get("deck_id"), -1)
        mode = str(record.get("mode", ""))
        if deck_id not in expected_set:
            errors.append(f"unexpected deck id {deck_id} in {record.get('source', '')}")
            continue
        if mode not in MODES:
            errors.append(f"invalid mode {mode!r} for deck {deck_id}")
            continue
        grouped.setdefault((deck_id, mode), []).append(record)

    for deck_id in expected:
        for mode in MODES:
            candidates = grouped.get((deck_id, mode), [])
            if not candidates:
                errors.append(f"missing {mode} result for deck {deck_id}")
                rows.append(
                    {
                        "deck_id": deck_id,
                        "deck_name": "",
                        "mode": mode,
                        "games": 0,
                        "wins": 0,
                        "losses": 0,
                        "draws": 0,
                        "win_rate": 0.0,
                        "failure_reason_counts": {},
                        "clean": False,
                        "source": "",
                        "passed": False,
                        "failures": ["missing result"],
                    }
                )
                continue
            if len(candidates) > 1:
                sources = ", ".join(str(item.get("source", "")) for item in candidates)
                errors.append(f"duplicate {mode} results for deck {deck_id}: {sources}")
                duplicate_row = _validate_record(candidates[0], games_required, min_win_rate)
                duplicate_row["passed"] = False
                duplicate_row["failures"].append("duplicate result")
                rows.append(duplicate_row)
                continue
            rows.append(_validate_record(candidates[0], games_required, min_win_rate))

    passed_rows = sum(1 for row in rows if row["passed"])
    overall_pass = not errors and passed_rows == len(expected) * len(MODES)
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "overall_pass": overall_pass,
        "config": {
            "expected_deck_ids": list(expected),
            "modes": list(MODES),
            "games_required": games_required,
            "min_win_rate": min_win_rate,
            "allowed_end_reasons": sorted(ALLOWED_END_REASONS),
        },
        "summary": {
            "expected_results": len(expected) * len(MODES),
            "passed_results": passed_rows,
            "failed_results": len(rows) - passed_rows,
            "error_count": len(errors),
        },
        "rows": rows,
        "errors": errors,
    }


def _short_source(source: str) -> str:
    return Path(source).name if source else "-"


def render_table(report: Mapping[str, Any]) -> str:
    headers = ("Deck", "Mode", "Games", "W-L-D", "Win%", "Clean", "Result", "Source")
    body: list[tuple[str, ...]] = []
    for row in report.get("rows", []):
        body.append(
            (
                str(row["deck_id"]),
                str(row["mode"]),
                str(row["games"]),
                f"{row['wins']}-{row['losses']}-{row['draws']}",
                f"{float(row['win_rate']):.1%}",
                "yes" if row["clean"] else "no",
                "PASS" if row["passed"] else "FAIL",
                _short_source(str(row["source"])),
            )
        )
    widths = [len(header) for header in headers]
    for values in body:
        for index, value in enumerate(values):
            widths[index] = max(widths[index], len(value))

    def line(values: Sequence[str]) -> str:
        return "  ".join(value.ljust(widths[index]) for index, value in enumerate(values)).rstrip()

    lines = [line(headers), line(tuple("-" * width for width in widths))]
    lines.extend(line(values) for values in body)
    summary = report["summary"]
    lines.append("")
    lines.append(
        "Overall: %s | passed %d/%d | errors %d"
        % (
            "PASS" if report["overall_pass"] else "FAIL",
            summary["passed_results"],
            summary["expected_results"],
            summary["error_count"],
        )
    )
    failed_rows = [row for row in report.get("rows", []) if not row["passed"]]
    if failed_rows:
        lines.append("Failures:")
        for row in failed_rows:
            lines.append(f"- {row['deck_id']} {row['mode']}: {'; '.join(row['failures'])}")
    if report.get("errors"):
        lines.append("Errors:")
        lines.extend(f"- {message}" for message in report["errors"])
    return "\n".join(lines)


def _parse_deck_ids(raw_value: str) -> list[int]:
    try:
        values = [int(item.strip()) for item in raw_value.split(",") if item.strip()]
    except ValueError as exc:
        raise argparse.ArgumentTypeError("deck ids must be comma-separated integers") from exc
    if not values:
        raise argparse.ArgumentTypeError("at least one deck id is required")
    return values


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="*", help="Auto-detected JSON files, directories, or globs")
    parser.add_argument("--normal", action="append", default=[], metavar="PATH", help="Force an input to normal mode")
    parser.add_argument("--strong", action="append", default=[], metavar="PATH", help="Force an input to strong mode")
    parser.add_argument(
        "--deck-ids",
        type=_parse_deck_ids,
        default=list(DEFAULT_V18_DECK_IDS),
        help="Expected comma-separated deck ids (defaults to all 24 V18 built-ins)",
    )
    parser.add_argument("--games", type=int, default=DEFAULT_GAMES, help="Required games per deck and mode")
    parser.add_argument("--min-win-rate", type=float, default=DEFAULT_MIN_WIN_RATE)
    parser.add_argument("--godot-user-dir", type=Path, default=_godot_user_dir())
    parser.add_argument("--json-output", type=Path, help="Write the machine-readable report to this file")
    parser.add_argument("--json-only", action="store_true", help="Print only machine-readable JSON")
    args = parser.parse_args(argv)
    if not (args.inputs or args.normal or args.strong):
        parser.error("provide at least one input path")
    if args.games <= 0:
        parser.error("--games must be positive")
    if not 0.0 <= args.min_win_rate <= 1.0:
        parser.error("--min-win-rate must be between 0 and 1")
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    paths_by_mode = {
        None: expand_inputs(args.inputs, args.godot_user_dir),
        "normal": expand_inputs(args.normal, args.godot_user_dir),
        "strong": expand_inputs(args.strong, args.godot_user_dir),
    }
    requested_paths = len(args.inputs) + len(args.normal) + len(args.strong)
    found_paths = sum(len(paths) for paths in paths_by_mode.values())
    input_errors: list[str] = []
    if requested_paths and not found_paths:
        input_errors.append("no JSON input files were found")
    records, load_errors = load_records(paths_by_mode)
    report = evaluate_acceptance(
        records,
        expected_deck_ids=args.deck_ids,
        games_required=args.games,
        min_win_rate=args.min_win_rate,
        input_errors=input_errors + load_errors,
    )
    machine_json = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(machine_json, encoding="utf-8")
    if args.json_only:
        sys.stdout.write(machine_json)
    else:
        print(render_table(report))
        if args.json_output:
            print(f"Machine report: {args.json_output}")
    return 0 if report["overall_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
