from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
	sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.competitive_strategy_platform import CspContractOwner
from scripts.ai.ptcgdap.source_lock import load_json_strict


IONO_UID = "CSV3C_123"
JUDGE_UID = "CSV10C_206"
SUPPORTER_UIDS = {IONO_UID, JUDGE_UID}


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest().upper()


def _zone_counts(frame: dict[str, Any]) -> dict[int, dict[str, int]]:
    rows: dict[int, dict[str, int]] = {}
    for value in frame["public_state"]["zone_counts"]:
        rows[int(value["seat"])] = {
            "deck_count": int(value["deck_count"]),
            "hand_count": int(value["hand_count"]),
            "prize_count": int(value["prize_count"]),
        }
    return rows


def _candidate_participant(
    envelope: dict[str, Any],
    package_id: str,
    package_version: str,
    archive_sha256: str,
) -> tuple[int, int] | None:
    participants = envelope["participants"]
    seats = envelope["seat_assignment"]
    matches = [
        index
        for index, participant in enumerate(participants)
        if participant.get("participant_kind") == "strategy_release"
        and participant.get("package_id") == package_id
        and participant.get("release_version") == package_version
        and participant.get("archive_sha256") == archive_sha256
    ]
    if len(matches) != 1:
        return None
    participant_index = matches[0]
    return participant_index, int(seats[participant_index])


def _stage(uid: str, turn_number: int, own_prizes: int, opponent_prizes: int) -> str:
    if uid == IONO_UID:
        if own_prizes >= 3 and opponent_prizes <= 3:
            return "late_prize_lock_shape"
        if turn_number <= 6:
            return "early_mid"
        return "other"
    if opponent_prizes <= 3:
        return "late_hold_shape"
    if turn_number <= 6 and opponent_prizes >= 4:
        return "early_mid_disruption_shape"
    return "other"


def _supporter_events(
    replay_name: str,
    frames: list[dict[str, Any]],
    candidate_seat: int,
) -> list[dict[str, Any]]:
    previous_discard: set[tuple[int, str]] = set()
    events: list[dict[str, Any]] = []
    for frame in frames:
        current_discard = {
            (int(card["card_serial"]), str(card["card_uid"]))
            for card in frame["public_state"]["public_cards"]
            if int(card["seat"]) == candidate_seat
            and card["zone"] == "discard"
            and card["card_uid"] in SUPPORTER_UIDS
        }
        entered = sorted(current_discard - previous_discard)
        previous_discard = current_discard
        if not entered:
            continue
        counts = _zone_counts(frame)
        if set(counts) != {0, 1}:
            for serial, uid in entered:
                events.append({
                    "replay": replay_name,
                    "card_serial": serial,
                    "card_uid": uid,
                    "effect_confirmed": False,
                    "reason": "zone_counts_invalid",
                })
            continue
        opponent_seat = 1 - candidate_seat
        for serial, uid in entered:
            if uid == IONO_UID:
                confirmed = all(
                    counts[seat]["hand_count"] == counts[seat]["prize_count"]
                    for seat in (0, 1)
                )
            else:
                confirmed = all(counts[seat]["hand_count"] == 4 for seat in (0, 1))
            own_prizes = counts[candidate_seat]["prize_count"]
            opponent_prizes = counts[opponent_seat]["prize_count"]
            events.append({
                "replay": replay_name,
                "ordinal": int(frame["ordinal"]),
                "turn_number": int(frame["turn_number"]),
                "candidate_seat": candidate_seat,
                "card_serial": serial,
                "card_uid": uid,
                "supporter": "iono" if uid == IONO_UID else "judge",
                "own_prizes": own_prizes,
                "opponent_prizes": opponent_prizes,
                "stage": _stage(uid, int(frame["turn_number"]), own_prizes, opponent_prizes),
                "effect_confirmed": confirmed,
                "reason": "" if confirmed else "public_effect_signature_mismatch",
            })
    return events


def audit(
    report_path: Path,
    replay_root: Path,
    package_id: str,
    package_version: str,
    archive_sha256: str,
) -> dict[str, Any]:
    report = load_json_strict(report_path)
    owner = CspContractOwner.load_trusted(ROOT)
    mismatches: list[str] = []
    expected_games: list[dict[str, Any]] = []
    policy_calls = 0
    policy_successes = 0
    classic_fallbacks = 0
    same_window_fallbacks = 0
    invalid_outputs = 0
    policy_errors = 0
    engine_rejections = 0
    candidate_wins = 0
    candidate_losses = 0
    matchup_wins: list[int] = []

    if report.get("is_clean") is not True:
        mismatches.append("report_not_clean")
    if report.get("candidate_package_id") != package_id:
        mismatches.append("report_package_id_mismatch")
    if report.get("candidate_package_version") != package_version:
        mismatches.append("report_package_version_mismatch")
    if report.get("candidate_archive_sha256") != archive_sha256:
        mismatches.append("report_archive_sha256_mismatch")

    for result in report.get("results", []):
        if result.get("is_clean") is not True:
            mismatches.append(f"matchup_not_clean:{result.get('opponent_deck_id')}")
        wins = int(result.get("candidate_wins", 0))
        games = int(result.get("games", 0))
        matchup_wins.append(wins)
        candidate_wins += wins
        candidate_losses += games - wins - int(result.get("draws", 0))
        totals = result.get("candidate_audit_totals", {})
        policy_calls += int(totals.get("policy_calls", 0))
        policy_successes += int(totals.get("policy_successes", 0))
        classic_fallbacks += int(totals.get("classic_fallbacks", 0))
        same_window_fallbacks += int(totals.get("same_window_fallbacks", 0))
        invalid_outputs += int(totals.get("invalid_outputs", 0))
        policy_errors += int(totals.get("policy_errors", 0))
        engine_rejections += int(totals.get("engine_rejections", 0))
        for game in result.get("per_game", []):
            expected_games.append(game)
            if game.get("terminal") is not True or game.get("failure") != "":
                mismatches.append(
                    f"game_not_terminal_clean:{result.get('opponent_deck_id')}:{game.get('game')}"
                )

    if policy_calls != policy_successes:
        mismatches.append("policy_call_success_mismatch")
    if any((classic_fallbacks, same_window_fallbacks, invalid_outputs, policy_errors, engine_rejections)):
        mismatches.append("policy_audit_not_clean")

    files = sorted(replay_root.glob("*.json"))
    if len(files) != len(expected_games):
        mismatches.append(f"replay_file_count:{len(files)}:{len(expected_games)}")
    files_by_name = {path.name: path for path in files}
    validated_files = 0
    validated_frames = 0
    events: list[dict[str, Any]] = []

    for game in expected_games:
        public_replay = game.get("public_replay", {})
        replay_name = Path(str(public_replay.get("path", ""))).name
        path = files_by_name.get(replay_name)
        if path is None:
            mismatches.append(f"replay_missing:{replay_name}")
            continue
        raw = path.read_bytes()
        if _sha256(raw) != public_replay.get("artifact_sha256"):
            mismatches.append(f"artifact_sha256:{replay_name}")
        artifact = load_json_strict(path)
        envelope = artifact.get("match_envelope")
        manifest = artifact.get("manifest")
        frames = artifact.get("frames")
        try:
            envelope_result = owner.validate_document(envelope)
            replay_result = owner.validate_replay(manifest, frames)
        except Exception as error:  # exact contract error is preserved in evidence
            mismatches.append(f"contract_validation:{replay_name}:{type(error).__name__}:{error}")
            continue
        if envelope_result.canonical_sha256 != manifest.get("match_envelope_sha256"):
            mismatches.append(f"manifest_envelope_sha256:{replay_name}")
        if envelope_result.canonical_sha256 != public_replay.get("match_envelope_sha256"):
            mismatches.append(f"report_envelope_sha256:{replay_name}")
        if replay_result.frame_count != int(public_replay.get("frame_count", -1)):
            mismatches.append(f"frame_count:{replay_name}")
        if replay_result.frame_chain_root_sha256 != public_replay.get("frame_chain_root_sha256"):
            mismatches.append(f"frame_chain_root:{replay_name}")
        participant = _candidate_participant(
            envelope, package_id, package_version, archive_sha256
        )
        if participant is None:
            mismatches.append(f"participant_identity:{replay_name}")
            continue
        _, candidate_seat = participant
        if candidate_seat != int(game.get("candidate_seat", -1)):
            mismatches.append(f"candidate_seat:{replay_name}")
        events.extend(_supporter_events(replay_name, frames, candidate_seat))
        validated_files += 1
        validated_frames += replay_result.frame_count

    confirmed = [event for event in events if event.get("effect_confirmed") is True]
    unclassified = [event for event in events if event.get("effect_confirmed") is not True]
    if unclassified:
        mismatches.append(f"unclassified_supporter_events:{len(unclassified)}")
    iono_events = [event for event in confirmed if event.get("supporter") == "iono"]
    judge_events = [event for event in confirmed if event.get("supporter") == "judge"]

    stage_counts: dict[str, int] = {}
    for event in confirmed:
        key = f"{event['supporter']}:{event['stage']}"
        stage_counts[key] = stage_counts.get(key, 0) + 1

    return {
        "document_type": "ogerpon_supporter_benchmark_audit_v1",
        "schema_version": 1,
        "status": "passed" if not mismatches else "failed",
        "report_path": report_path.as_posix(),
        "report_sha256": _sha256(report_path.read_bytes()),
        "replay_root": replay_root.as_posix(),
        "candidate": {
            "package_id": package_id,
            "package_version": package_version,
            "archive_sha256": archive_sha256,
        },
        "games": len(expected_games),
        "candidate_wins": candidate_wins,
        "candidate_losses": candidate_losses,
        "matchup_wins": matchup_wins,
        "policy_audit": {
            "policy_calls": policy_calls,
            "policy_successes": policy_successes,
            "classic_fallbacks": classic_fallbacks,
            "same_window_fallbacks": same_window_fallbacks,
            "invalid_outputs": invalid_outputs,
            "policy_errors": policy_errors,
            "engine_rejections": engine_rejections,
        },
        "replay_validation": {
            "expected_files": len(expected_games),
            "validated_files": validated_files,
            "validated_frames": validated_frames,
            "mismatch_count": len(mismatches),
            "mismatches": mismatches,
        },
        "effect_confirmed_supporter_plays": {
            "judge": len(judge_events),
            "iono": len(iono_events),
            "total": len(confirmed),
            "unclassified": len(unclassified),
            "stage_counts": dict(sorted(stage_counts.items())),
        },
        "supporter_events": confirmed,
        "unclassified_supporter_events": unclassified,
        "claims": {
            "public_replay_only": True,
            "card_serial_first_enters_candidate_discard": True,
            "public_effect_signature_required": True,
            "engine_rule_parity": False,
            "production_authority": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--replay-root", required=True, type=Path)
    parser.add_argument("--package-id", required=True)
    parser.add_argument("--package-version", required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report_path = args.report.resolve()
    replay_root = args.replay_root.resolve()
    archive_sha256 = args.archive_sha256.upper()
    result = audit(
        report_path,
        replay_root,
        args.package_id,
        args.package_version,
        archive_sha256,
    )
    rendered = json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    if args.output is not None:
        output = args.output.resolve()
        if output.exists():
            raise SystemExit(f"output_exists:{output}")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
