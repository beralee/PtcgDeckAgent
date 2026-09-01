from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


NATIVE_DOMAIN = "ptcgdap_native_replay_witness_canonical_json_v2"
DEVELOPER_DOMAIN = "ptcgdap_developer_decision_record_canonical_json_v1"
FORBIDDEN_KEYS = {
    "deck_order",
    "opponent_hand",
    "opponent_hidden_hand",
    "opponent_deck",
    "opponent_prizes",
    "face_down_prizes",
    "private_rng",
    "rng_state",
    "search_begin_input",
    "object_ref",
    "callback",
    "binding",
    "ticket",
    "command",
}
ITERATION_CAPABILITIES = (
    "native_event_integrity",
    "replay_state_frames",
    "structured_battle_events",
    "decision_windows",
    "host_acceptance",
    "terminal_status",
)


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def _record_hash(domain: str, value: object) -> str:
    payload = (
        b"PTCGDAP_REPLAY_DIAGNOSTIC\0"
        + domain.encode("utf-8")
        + b"\0"
        + _canonical(value)
    )
    return hashlib.sha256(payload).hexdigest().upper()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _load_json_lines(path: Path) -> tuple[list[str], list[dict[str, Any]] | None]:
    try:
        lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
    except (OSError, UnicodeDecodeError):
        return [], None
    values: list[dict[str, Any]] = []
    try:
        for line in lines:
            value = json.loads(line)
            if not isinstance(value, dict):
                return lines, None
            values.append(value)
    except json.JSONDecodeError:
        return lines, None
    return lines, values


def _capability(state: str, reason: str) -> dict[str, str]:
    return {"state": state, "reason": reason}


def _is_public_safe(value: object) -> bool:
    stack = [value]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            for raw_key, child in current.items():
                if not isinstance(raw_key, str):
                    return False
                key = raw_key.lower()
                if (
                    key in FORBIDDEN_KEYS
                    or "opponent_hidden" in key
                    or "private_rng" in key
                    or "face_down_prize" in key
                ):
                    return False
                stack.append(child)
        elif isinstance(current, list):
            stack.extend(current)
        elif not isinstance(current, (str, int, float, bool, type(None))):
            return False
    return True


def _legacy_report(match_dir: Path) -> dict[str, Any]:
    lines, events = _load_json_lines(match_dir / "detail.jsonl")
    if events is None:
        return _rejected("legacy_detail_invalid")
    capabilities = {
        "legacy_playback": _capability("available", "legacy_detail_jsonl"),
        "native_event_integrity": _capability("unavailable", "v2_manifest_absent"),
        "replay_state_frames": _capability("partial", "legacy_events_not_integrity_bound"),
        "structured_battle_events": _capability("partial", "legacy_events_not_integrity_bound"),
        "decision_windows": _capability("unavailable", "legacy_recording_has_no_decision_trace"),
        "host_acceptance": _capability("unavailable", "legacy_recording_has_no_decision_trace"),
        "terminal_status": _capability("partial", "legacy_result_only"),
    }
    missing = list(ITERATION_CAPABILITIES)
    return {
        "accepted": True,
        "format": "legacy_v1",
        "complete": (match_dir / "match.json").is_file(),
        "integrity_status": "unavailable",
        "error_codes": [],
        "match_dir": str(match_dir.resolve()),
        "record_count": len(lines),
        "last_valid_record_index": -1,
        "capabilities": capabilities,
        "capability_gaps": sorted(
            key for key, value in capabilities.items() if value["state"] != "available"
        ),
        "decision_summary": _empty_decision_summary(),
        "self_iteration_ready": False,
        "self_iteration_missing": missing,
        "official_alignment_gaps": [
            "v2_hash_chain",
            "decision_windows",
            "host_acceptance",
            "exact_terminal_status_rewards_faults",
        ],
        "missing_fields_inferred": False,
        "execution_authority_granted": False,
    }


def _verify_native(
    match_dir: Path,
    manifest: dict[str, Any],
) -> tuple[list[str], int, str | None, list[dict[str, Any]]]:
    errors: list[str] = []
    detail_lines, events = _load_json_lines(match_dir / "detail.jsonl")
    _, witnesses = _load_json_lines(match_dir / "detail.chain.jsonl")
    if events is None or witnesses is None:
        return ["record_json_invalid"], -1, None, []
    complete = manifest.get("complete") is True
    expected_count = manifest.get("record_count")
    if complete and (
        type(expected_count) is not int
        or len(detail_lines) != expected_count
        or len(witnesses) != expected_count
    ):
        errors.append("record_count_mismatch")
    match_id = manifest.get("match_id")
    previous: str | None = None
    last_valid = -1
    for index, (line, event, witness) in enumerate(
        zip(detail_lines, events, witnesses, strict=False)
    ):
        if (
            witness.get("document_type") != "native_replay_record_witness_v2"
            or witness.get("schema_version") != 2
            or witness.get("match_id") != match_id
            or witness.get("record_index") != index
            or witness.get("previous_record_sha256") != previous
        ):
            errors.append("native_witness_binding_invalid")
            break
        if witness.get("detail_line_sha256") != _sha(line.encode("utf-8")):
            errors.append("detail_line_hash_mismatch")
            break
        if witness.get("event_index") != event.get("event_index"):
            errors.append("native_witness_binding_invalid")
            break
        if event.get("match_id") != match_id:
            errors.append("cross_match_event")
            break
        body = dict(witness)
        stored = body.pop("record_sha256", None)
        try:
            computed = _record_hash(NATIVE_DOMAIN, body)
        except (TypeError, ValueError):
            computed = ""
        if stored != computed or not computed:
            errors.append("native_witness_hash_mismatch")
            break
        previous = stored
        last_valid = index
    if complete:
        if previous != manifest.get("chain_root_sha256"):
            errors.append("chain_root_mismatch")
        try:
            detail_sha = _sha((match_dir / "detail.jsonl").read_bytes())
        except OSError:
            detail_sha = ""
        if detail_sha != manifest.get("detail_file_sha256"):
            errors.append("detail_file_hash_mismatch")
    return errors, last_valid, previous, events


def _verify_developer_trace(
    match_dir: Path,
    native_manifest: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    manifest_path = match_dir / "developer_decision_trace_manifest.json"
    if not manifest_path.is_file():
        return (
            {"accepted": True, "present": False, "state": "unavailable"},
            [],
            [],
        )
    link = native_manifest.get("developer_decision_trace")
    if not isinstance(link, dict) or link.get("path") != manifest_path.name:
        return _developer_error("developer_trace_link_invalid"), [], []
    try:
        manifest_sha = _sha(manifest_path.read_bytes())
    except OSError:
        return _developer_error("developer_trace_manifest_unreadable"), [], []
    if manifest_sha != link.get("sha256"):
        return _developer_error("developer_trace_manifest_hash_mismatch"), [], []
    manifest = _load_json(manifest_path)
    if (
        manifest.get("document_type") != "developer_decision_trace_manifest_v1"
        or manifest.get("schema_version") != 1
        or manifest.get("native_match_id") != match_dir.name
    ):
        return _developer_error("developer_trace_manifest_invalid"), [], []
    _, envelopes = _load_json_lines(match_dir / "developer_decisions.jsonl")
    if envelopes is None:
        return _developer_error("developer_trace_record_invalid"), [], []
    if len(envelopes) != manifest.get("record_count"):
        return _developer_error("developer_trace_record_count_mismatch"), [], []
    previous: str | None = None
    decisions: list[dict[str, Any]] = []
    steps: list[dict[str, Any]] = []
    for index, envelope in enumerate(envelopes):
        payload = envelope.get("payload")
        if (
            envelope.get("document_type") != "developer_decision_trace_record_v1"
            or envelope.get("schema_version") != 1
            or envelope.get("native_match_id") != match_dir.name
            or envelope.get("record_index") != index
            or envelope.get("previous_record_sha256") != previous
            or not isinstance(payload, dict)
        ):
            return _developer_error("developer_trace_record_binding_invalid"), [], []
        if not _is_public_safe(payload):
            return _developer_error("developer_trace_privacy_invalid"), [], []
        body = dict(envelope)
        stored = body.pop("record_sha256", None)
        try:
            computed = _record_hash(DEVELOPER_DOMAIN, body)
        except (TypeError, ValueError):
            computed = ""
        if stored != computed or not computed:
            return _developer_error("developer_trace_record_hash_mismatch"), [], []
        previous = stored
        if payload.get("document_type") == "decision_window_record_v1":
            decisions.append(payload)
        elif payload.get("document_type") == "owner_step_witness_v1":
            steps.append(payload)
        else:
            return _developer_error("developer_trace_payload_type_invalid"), [], []
    if previous != manifest.get("chain_root_sha256"):
        return _developer_error("developer_trace_chain_root_mismatch"), [], []
    if len(decisions) != manifest.get("decision_count") or len(steps) != manifest.get(
        "owner_step_count"
    ):
        return _developer_error("developer_trace_type_count_mismatch"), [], []
    return (
        {
            "accepted": True,
            "present": True,
            "complete": manifest.get("complete") is True,
            "state": "available" if manifest.get("complete") is True else "partial",
            "error_code": "",
            "record_count": len(envelopes),
            "decision_count": len(decisions),
            "owner_step_count": len(steps),
            "chain_root_sha256": previous,
            "execution_authority_granted": False,
        },
        decisions,
        steps,
    )


def _developer_error(code: str) -> dict[str, Any]:
    return {
        "accepted": False,
        "present": True,
        "complete": False,
        "state": "invalid",
        "error_code": code,
        "execution_authority_granted": False,
    }


def _decision_summary(
    decisions: list[dict[str, Any]],
    steps: list[dict[str, Any]],
) -> dict[str, Any]:
    prompt_counts: Counter[str] = Counter()
    status_counts: Counter[str] = Counter()
    rule_counts: Counter[str] = Counter()
    policy_error_counts: Counter[str] = Counter()
    fallback_count = 0
    windows: list[dict[str, Any]] = []
    for decision in decisions:
        frame = decision.get("frame") if isinstance(decision.get("frame"), dict) else {}
        source = frame.get("source") if isinstance(frame.get("source"), dict) else {}
        policy = decision.get("policy") if isinstance(decision.get("policy"), dict) else {}
        host = decision.get("host") if isinstance(decision.get("host"), dict) else {}
        base = policy.get("base_result") if isinstance(policy.get("base_result"), dict) else {}
        prompt = str(frame.get("prompt_kind", "unknown"))
        status = str(host.get("status", "unknown"))
        prompt_counts[prompt] += 1
        status_counts[status] += 1
        if host.get("fallback_used") is True:
            fallback_count += 1
        error_code = str(host.get("error_code", ""))
        if error_code:
            policy_error_counts[error_code] += 1
        matched_rules = [
            str(value)
            for value in policy.get("matched_rule_ids", [])
            if isinstance(value, str)
        ]
        rule_counts.update(matched_rules)
        options: list[dict[str, Any]] = []
        for raw_option in frame.get("options", []):
            if not isinstance(raw_option, dict):
                continue
            options.append(
                {
                    key: raw_option.get(key)
                    for key in (
                        "index",
                        "kind",
                        "card_uid",
                        "source_uid",
                        "target_uid",
                        "attack_index",
                        "option_type_raw",
                        "option_card_uid",
                        "option_player_index",
                        "option_fingerprint",
                    )
                    if key in raw_option
                }
            )
        windows.append(
            {
                "decision_id": decision.get("decision_id"),
                "sequence": frame.get("sequence"),
                "prompt_kind": prompt,
                "public_observation_hash": source.get("public_observation_hash"),
                "window_id": source.get("window_id"),
                "option_count": len(options),
                "options": options,
                "select_semantics": frame.get("select_semantics", {}),
                "public_state": frame.get("public_state", {}),
                "reported_indexes": policy.get("reported_indexes", []),
                "accepted_indexes": host.get("accepted_indexes", []),
                "accepted_option_fingerprints": host.get(
                    "accepted_option_fingerprints", []
                ),
                "host_status": status,
                "fallback_used": host.get("fallback_used") is True,
                "error_code": error_code,
                "latency_usec": host.get("latency_usec"),
                "matched_rule_ids": matched_rules,
                "base_reason_code": base.get("reason_code"),
                "base_fallback_branch": base.get("fallback_branch"),
                "base_execution_hash": base.get("execution_hash"),
                "base_node_audit": base.get("node_audit", []),
            }
        )
    engine_commits = sum(
        int(step.get("engine_commit_delta", 0))
        for step in steps
        if type(step.get("engine_commit_delta", 0)) is int
    )
    engine_rejections = sum(
        int(step.get("engine_rejection_delta", 0))
        for step in steps
        if type(step.get("engine_rejection_delta", 0)) is int
    )
    problems: list[str] = []
    if fallback_count:
        problems.append("same_window_fallback_observed")
    if policy_error_counts:
        problems.append("policy_error_observed")
    if engine_rejections:
        problems.append("engine_rejection_observed")
    return {
        "decision_count": len(decisions),
        "owner_step_count": len(steps),
        "prompt_counts": dict(sorted(prompt_counts.items())),
        "host_status_counts": dict(sorted(status_counts.items())),
        "matched_rule_counts": dict(sorted(rule_counts.items())),
        "policy_error_counts": dict(sorted(policy_error_counts.items())),
        "fallback_count": fallback_count,
        "engine_commit_count": engine_commits,
        "engine_rejection_count": engine_rejections,
        "problem_signals": problems,
        "windows": windows,
        "steps": [
            {
                "step_index": step.get("step_index"),
                "status": step.get("status"),
                "decision_ids": step.get("decision_ids", []),
                "engine_commit_delta": step.get("engine_commit_delta", 0),
                "engine_rejection_delta": step.get("engine_rejection_delta", 0),
                "native_event_count_before_step": step.get(
                    "native_event_count_before_step", -1
                ),
                "native_event_count_after_step": step.get(
                    "native_event_count_after_step", -1
                ),
            }
            for step in steps
        ],
    }


def _empty_decision_summary() -> dict[str, Any]:
    return _decision_summary([], [])


def audit_match_dir(match_dir: Path | str) -> dict[str, Any]:
    path = Path(match_dir)
    if not path.is_dir():
        return _rejected("match_dir_missing")
    manifest_path = path / "native_replay_manifest.json"
    if not manifest_path.is_file():
        return _legacy_report(path)
    manifest = _load_json(manifest_path)
    if (
        manifest.get("document_type") != "native_replay_manifest_v2"
        or manifest.get("schema_version") != 2
        or manifest.get("match_id") != path.name
    ):
        return _rejected("native_manifest_invalid")
    native_errors, last_valid, chain_root, _events = _verify_native(path, manifest)
    developer, decisions, steps = _verify_developer_trace(path, manifest)
    errors = list(native_errors)
    if developer.get("accepted") is False:
        errors.append(str(developer.get("error_code", "developer_decision_trace_invalid")))
    complete = manifest.get("complete") is True
    report_errors = list(errors)
    if not complete and not native_errors:
        report_errors.append("recording_incomplete")
    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict):
        capabilities = {}
    if developer.get("accepted") is False:
        capabilities = dict(capabilities)
        capabilities["decision_windows"] = _capability(
            "partial", "developer_decision_trace_invalid"
        )
        capabilities["host_acceptance"] = _capability(
            "partial", "developer_decision_trace_invalid"
        )
    missing: list[str] = []
    for capability_name in ITERATION_CAPABILITIES:
        capability = capabilities.get(capability_name)
        if not isinstance(capability, dict) or capability.get("state") != "available":
            missing.append(capability_name)
    decision_summary = _decision_summary(decisions, steps)
    if decision_summary["decision_count"] == 0 and "decision_windows" not in missing:
        missing.append("decision_windows")
    if decision_summary["owner_step_count"] == 0 and "host_acceptance" not in missing:
        missing.append("host_acceptance")
    terminal = manifest.get("terminal") if isinstance(manifest.get("terminal"), dict) else {}
    if terminal.get("document_type") != "replay_terminal_v1":
        missing.append("terminal_result")
    accepted = not errors
    self_iteration_ready = accepted and complete and not missing
    official_gaps = [
        key
        for key, value in capabilities.items()
        if isinstance(value, dict) and value.get("state") != "available"
    ]
    return {
        "accepted": accepted,
        "format": "native_replay_v2",
        "complete": complete and accepted,
        "integrity_status": "invalid" if errors else "verified" if complete else "partial",
        "error_codes": report_errors,
        "match_dir": str(path.resolve()),
        "match_id": manifest.get("match_id"),
        "record_count": manifest.get("record_count", 0),
        "last_valid_record_index": last_valid,
        "chain_root_sha256": chain_root,
        "capabilities": capabilities,
        "capability_gaps": sorted(official_gaps),
        "developer_decision_trace": developer,
        "decision_summary": decision_summary,
        "terminal": terminal,
        "self_iteration_ready": self_iteration_ready,
        "self_iteration_missing": sorted(set(missing)),
        "official_alignment_gaps": sorted(official_gaps),
        "missing_fields_inferred": False,
        "execution_authority_granted": False,
    }


def _rejected(code: str) -> dict[str, Any]:
    return {
        "accepted": False,
        "format": "unknown",
        "complete": False,
        "integrity_status": "invalid",
        "error_codes": [code],
        "capabilities": {},
        "capability_gaps": [],
        "decision_summary": _empty_decision_summary(),
        "self_iteration_ready": False,
        "self_iteration_missing": list(ITERATION_CAPABILITIES),
        "official_alignment_gaps": [],
        "missing_fields_inferred": False,
        "execution_authority_granted": False,
    }


def _human_summary(report: dict[str, Any]) -> str:
    summary = report.get("decision_summary", {})
    lines = [
        f"accepted={str(report.get('accepted', False)).lower()}",
        f"format={report.get('format', 'unknown')}",
        f"integrity={report.get('integrity_status', 'invalid')}",
        f"complete={str(report.get('complete', False)).lower()}",
        f"self_iteration_ready={str(report.get('self_iteration_ready', False)).lower()}",
        f"decisions={summary.get('decision_count', 0)}",
        f"owner_steps={summary.get('owner_step_count', 0)}",
        f"fallbacks={summary.get('fallback_count', 0)}",
        f"engine_rejections={summary.get('engine_rejection_count', 0)}",
    ]
    errors = report.get("error_codes", [])
    if errors:
        lines.append("errors=" + ",".join(str(value) for value in errors))
    missing = report.get("self_iteration_missing", [])
    if missing:
        lines.append("iteration_missing=" + ",".join(str(value) for value in missing))
    return "\n".join(lines)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify a local PTCG native replay and summarize strategy-decision evidence."
    )
    parser.add_argument("match_dir", type=Path, help="Path to one native match directory")
    parser.add_argument("--json", action="store_true", help="Print the complete machine-readable report")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    report = audit_match_dir(args.match_dir)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(_human_summary(report))
    return 0 if report.get("accepted") is True else 1


if __name__ == "__main__":
    sys.exit(main())
