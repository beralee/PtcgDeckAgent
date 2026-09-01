from __future__ import annotations

import copy
import hashlib
import json
import math
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Mapping

from .source_lock import (
    canonical_json_bytes,
    load_json_bytes_strict,
    resolve_locked_artifact,
)


_PUBLIC_REPLAY_OBSERVATION_SELECTOR = re.compile(r"^/steps/[0-9]+/[01]/observation$")
PUBLIC_CLASSIFICATIONS = {
    "public_agent_observation",
    "synthetic_forward_compat_observation",
}
PRIVATE_CLASSIFICATIONS = {"private_replay_negative_control"}
RAW_OBSERVATION_FIELDS = {"select", "logs", "current", "search_begin_input"}
MAX_FIXTURE_CATALOG_BYTES = 1024 * 1024
MAX_FIXTURE_FILE_BYTES = 8 * 1024 * 1024
MAX_SOURCE_JSON_BYTES = 64 * 1024 * 1024
MAX_JSON_DEPTH = 128
MAX_JSON_NODES = 1_000_000
_FORBIDDEN_PUBLIC_KEYS = {
    "action",
    "configuration",
    "deckorder",
    "hiddenhand",
    "lookingcount",
    "privaterngstate",
    "randomseed",
    "rewards",
    "rngstate",
    "seed",
    "selected",
    "specification",
    "statuses",
    "steps",
    "token",
    "visualize",
}


class FixtureContractError(ValueError):
    pass


@dataclass(frozen=True)
class FixtureIssue:
    code: str
    fixture_id: str
    detail: str
    expected: Any = None
    actual: Any = None


@dataclass
class FixtureCatalogReport:
    public_fixture_count: int = 0
    private_fixture_count: int = 0
    issues: list[FixtureIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.issues

    def add(
        self,
        code: str,
        fixture_id: str,
        detail: str,
        expected: Any = None,
        actual: Any = None,
    ) -> None:
        self.issues.append(FixtureIssue(code, fixture_id, detail, expected, actual))

    def to_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "public_fixture_count": self.public_fixture_count,
            "private_fixture_count": self.private_fixture_count,
            "issues": [
                asdict(issue)
                for issue in sorted(self.issues, key=lambda item: (item.fixture_id, item.code))
            ],
        }


def _validate_json_tree_limits(value: Any) -> None:
    stack: list[tuple[Any, int]] = [(value, 0)]
    node_count = 0
    while stack:
        current, depth = stack.pop()
        node_count += 1
        if node_count > MAX_JSON_NODES:
            raise FixtureContractError(
                f"JSON tree exceeds the {MAX_JSON_NODES}-node fixture limit"
            )
        if depth > MAX_JSON_DEPTH:
            raise FixtureContractError(
                f"JSON tree exceeds the {MAX_JSON_DEPTH}-level fixture limit"
            )
        if isinstance(current, dict):
            if any(not isinstance(key, str) for key in current):
                raise FixtureContractError("JSON object keys must be strings")
            stack.extend((child, depth + 1) for child in current.values())
        elif isinstance(current, list):
            stack.extend((child, depth + 1) for child in current)
        elif current is None or isinstance(current, (str, bool)) or type(current) is int:
            continue
        elif isinstance(current, float) and math.isfinite(current):
            continue
        else:
            raise FixtureContractError("fixture tree contains a non-JSON or non-finite value")


def _load_json_bounded(
    path: Path,
    *,
    max_bytes: int,
    label: str,
) -> tuple[Any, bytes]:
    size = path.stat().st_size
    if size > max_bytes:
        raise FixtureContractError(f"{label} exceeds the {max_bytes}-byte limit")
    with path.open("rb") as stream:
        data = stream.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise FixtureContractError(f"{label} exceeds the {max_bytes}-byte limit")
    value = load_json_bytes_strict(data)
    _validate_json_tree_limits(value)
    return value, data


def canonical_sha256(value: Any) -> str:
    _validate_json_tree_limits(value)
    try:
        return hashlib.sha256(canonical_json_bytes(value)).hexdigest().upper()
    except (ValueError, TypeError, RuntimeError, RecursionError) as exc:
        raise FixtureContractError("fixture tree cannot be canonicalized safely") from exc


def _safe_fixture_path(root: Path, relative: Any) -> tuple[Path | None, str | None]:
    if not isinstance(relative, str) or not relative or "\\" in relative:
        return None, "fixture path must be a non-empty '/'-separated string"
    pure = PurePosixPath(relative)
    if pure.is_absolute() or any(part == ".." for part in pure.parts):
        return None, "fixture path must remain below the fixture root"
    try:
        resolved_root = root.resolve()
        candidate = resolved_root.joinpath(*pure.parts).resolve(strict=False)
        candidate.relative_to(resolved_root)
    except (OSError, RuntimeError, RecursionError):
        return None, "fixture path could not be resolved safely"
    except ValueError:
        return None, "resolved fixture path escapes the fixture root"
    return candidate, None


def _is_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _validate_public_observation(
    fixture_id: str,
    payload: Any,
    report: FixtureCatalogReport,
) -> None:
    if not isinstance(payload, dict) or not RAW_OBSERVATION_FIELDS.issubset(payload):
        report.add(
            "not_raw_agent_observation",
            fixture_id,
            "public fixtures must be a raw callback object with select/logs/current/search_begin_input",
        )
        return
    selection = payload["select"]
    if selection is not None and not isinstance(selection, dict):
        report.add("invalid_select_shape", fixture_id, "select must be an object or null")
    elif isinstance(selection, dict):
        for field_name in ("type", "context", "minCount", "maxCount"):
            if not _is_integer(selection.get(field_name)):
                report.add(
                    "invalid_select_integer",
                    fixture_id,
                    f"select.{field_name} must be a non-boolean integer",
                )
        options = selection.get("option")
        if not isinstance(options, list):
            report.add("invalid_option_list", fixture_id, "select.option must be an array")
        else:
            for option_index, option in enumerate(options):
                if not isinstance(option, dict):
                    report.add("invalid_option_shape", fixture_id, f"select.option[{option_index}] must be an object")
                elif not _is_integer(option.get("type")):
                    report.add(
                        "invalid_option_type",
                        fixture_id,
                        f"select.option[{option_index}].type must be a non-boolean integer",
                    )
        if selection.get("deck") is not None and not isinstance(selection.get("deck"), list):
            report.add("invalid_select_deck", fixture_id, "select.deck must be an array or null")
    if not isinstance(payload["logs"], list):
        report.add("invalid_logs_shape", fixture_id, "logs must be an array")
    if payload["current"] is not None and not isinstance(payload["current"], dict):
        report.add("invalid_current_shape", fixture_id, "current must be an object or null")
    if payload["search_begin_input"] is not None:
        report.add(
            "unredacted_search_token",
            fixture_id,
            "persisted public fixtures must replace the ephemeral Search capability with null",
        )
    _reject_private_fields(fixture_id, payload, report, "")

    current = payload.get("current")
    if not isinstance(current, dict):
        return
    players = current.get("players")
    your_index = current.get("yourIndex")
    if not isinstance(players, list):
        report.add("invalid_players_shape", fixture_id, "current.players must be an array")
        return
    if len(players) != 2:
        report.add("invalid_players_shape", fixture_id, "current.players must contain exactly two seats")
    if not _is_integer(your_index) or your_index not in range(len(players)):
        report.add("invalid_your_index", fixture_id, "current.yourIndex must identify one current.players seat")
    for player_index, player in enumerate(players):
        if not isinstance(player, dict):
            report.add("invalid_player_shape", fixture_id, f"current.players[{player_index}] must be an object")
            continue
        if "deck" in player:
            report.add(
                "private_deck_order",
                fixture_id,
                f"current.players[{player_index}].deck is private; authorized deck search belongs only in select.deck",
            )
        prize = player.get("prize")
        if not isinstance(prize, list):
            report.add("invalid_prize_shape", fixture_id, f"current.players[{player_index}].prize must be an array")
        elif any(card is not None for card in prize):
            report.add("private_prize_identity", fixture_id, f"current.players[{player_index}].prize reveals identity")
        hand = player.get("hand")
        if _is_integer(your_index) and your_index in range(len(players)) and player_index != your_index and hand is not None:
            report.add("opponent_hand_identity", fixture_id, f"current.players[{player_index}].hand must be null")
    if isinstance(selection, dict) and isinstance(selection.get("deck"), list):
        for card_index, card in enumerate(selection["deck"]):
            if not isinstance(card, dict):
                report.add("invalid_select_deck_card", fixture_id, f"select.deck[{card_index}] must be a Card object")
                continue
            if not _is_integer(your_index) or card.get("playerIndex") != your_index:
                report.add(
                    "unauthorized_select_deck_identity",
                    fixture_id,
                    f"select.deck[{card_index}] must belong to current.yourIndex",
                )
            for field_name in ("id", "serial", "playerIndex"):
                if not _is_integer(card.get(field_name)):
                    report.add(
                        "invalid_select_deck_card",
                        fixture_id,
                        f"select.deck[{card_index}].{field_name} must be a non-boolean integer",
                    )
    for log_index, log in enumerate(payload["logs"] if isinstance(payload["logs"], list) else []):
        if not isinstance(log, dict):
            report.add("invalid_log_shape", fixture_id, f"logs[{log_index}] must be an object")
            continue
        if not _is_integer(log.get("type")):
            report.add("invalid_log_type", fixture_id, f"logs[{log_index}].type must be a non-boolean integer")
            continue
        if log.get("type") in {5, 7}:
            leaked_identity = sorted({"cardId", "serial"}.intersection(log))
            if leaked_identity:
                report.add(
                    "reverse_log_identity",
                    fixture_id,
                    f"logs[{log_index}] is a hidden-identity reverse log",
                    actual=leaked_identity,
                )


def _reject_private_fields(
    fixture_id: str,
    value: Any,
    report: FixtureCatalogReport,
    pointer: str,
) -> None:
    stack: list[tuple[Any, str]] = [(value, pointer)]
    while stack:
        current, current_pointer = stack.pop()
        if isinstance(current, dict):
            for key, child in current.items():
                child_pointer = f"{current_pointer}/{key}"
                normalized = re.sub(r"[^a-z0-9]", "", key.lower())
                if normalized == "name":
                    report.add("visualizer_card_name", fixture_id, f"visualizer-only card name at {child_pointer}")
                elif normalized == "deck" and not (
                    current_pointer == "/select" and key == "deck"
                ):
                    report.add("private_deck_order", fixture_id, f"deck identity list is forbidden at {child_pointer}")
                elif normalized == "searchbegininput" and not (
                    current_pointer == "" and key == "search_begin_input"
                ):
                    report.add("nested_search_capability", fixture_id, f"Search capability is only legal at the callback root: {child_pointer}")
                elif normalized in _FORBIDDEN_PUBLIC_KEYS:
                    report.add("private_replay_container_field", fixture_id, f"private/replay field is forbidden at {child_pointer}")
                stack.append((child, child_pointer))
        elif isinstance(current, list):
            stack.extend(
                (child, f"{current_pointer}/{index}")
                for index, child in enumerate(current)
            )


def _json_pointer_get(value: Any, pointer: str) -> Any:
    if not isinstance(pointer, str):
        raise FixtureContractError("JSON Pointer must be a string")
    if pointer == "":
        return value
    if not pointer.startswith("/"):
        raise FixtureContractError(f"invalid JSON Pointer: {pointer!r}")
    current = value
    for raw_part in pointer[1:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            current = current[int(part)]
        elif isinstance(current, dict):
            current = current[part]
        else:
            raise FixtureContractError(f"pointer crosses a scalar: {pointer!r}")
    return current


def _json_pointer_set(value: Any, pointer: str, replacement: Any, operation: str) -> None:
    if not isinstance(pointer, str):
        raise FixtureContractError("mutation JSON Pointer must be a string")
    if not pointer.startswith("/") or pointer == "/":
        raise FixtureContractError(f"mutation pointer must target a child: {pointer!r}")
    parent_pointer, _, raw_leaf = pointer.rpartition("/")
    parent = _json_pointer_get(value, parent_pointer)
    leaf = raw_leaf.replace("~1", "/").replace("~0", "~")
    if isinstance(parent, list):
        index = int(leaf)
        if operation == "add" and index == len(parent):
            parent.append(copy.deepcopy(replacement))
        else:
            parent[index] = copy.deepcopy(replacement)
    elif isinstance(parent, dict):
        if operation == "replace" and leaf not in parent:
            raise FixtureContractError(f"replace target is missing: {pointer!r}")
        parent[leaf] = copy.deepcopy(replacement)
    else:
        raise FixtureContractError(f"mutation parent is not a container: {pointer!r}")


def _apply_sanitizer(payload: Any, sanitizer: str) -> Any:
    result = copy.deepcopy(payload)
    if sanitizer == "none":
        return result
    if sanitizer == "redact_search_begin_input_to_null_v1":
        if not isinstance(result, dict) or "search_begin_input" not in result:
            raise FixtureContractError("search token sanitizer requires a raw observation object")
        result["search_begin_input"] = None
        return result
    raise FixtureContractError(f"unknown fixture sanitizer: {sanitizer!r}")


def verify_fixture_catalog(
    manifest_path: str | Path,
    *,
    verify_sources: bool = False,
    root_overrides: Mapping[str, str | Path] | None = None,
    trusted_source_lock_path: str | Path | None = None,
    expected_source_lock_sha256: str | None = None,
) -> FixtureCatalogReport:
    report = FixtureCatalogReport()
    try:
        manifest_path = Path(manifest_path)
        manifest, _manifest_bytes = _load_json_bounded(
            manifest_path,
            max_bytes=MAX_FIXTURE_CATALOG_BYTES,
            label="fixture catalog",
        )
    except (
        OSError,
        ValueError,
        TypeError,
        RuntimeError,
        RecursionError,
        json.JSONDecodeError,
        FixtureContractError,
    ) as exc:
        report.add("fixture_manifest_error", "<manifest>", str(exc))
        return report
    if not isinstance(manifest, dict) or type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1:
        report.add("unsupported_fixture_manifest", "<manifest>", "schema_version must be 1")
        return report
    if not isinstance(manifest.get("catalog_id"), str) or not manifest.get("catalog_id"):
        report.add("invalid_catalog_id", "<manifest>", "catalog_id must be a non-empty string")
    if not isinstance(manifest.get("source_lock_id"), str) or not manifest.get("source_lock_id"):
        report.add("invalid_source_lock_id", "<manifest>", "source_lock_id must be a non-empty string")
    if re.fullmatch(r"[0-9A-F]{64}", str(manifest.get("source_lock_canonical_sha256"))) is None:
        report.add(
            "invalid_source_lock_hash",
            "<manifest>",
            "source_lock_canonical_sha256 must be an uppercase SHA-256",
        )
    if not isinstance(manifest.get("source_lock_locator_hint"), str):
        report.add(
            "invalid_source_lock_locator_hint",
            "<manifest>",
            "source_lock_locator_hint is non-authoritative metadata but must be a string",
        )
    expected_search_policy = (
        "Real search_begin_input values are never persisted. Persisted payloads always use null; "
        "provenance records only whether the source value was null or non-null."
    )
    if manifest.get("search_token_persistence_policy") != expected_search_policy:
        report.add(
            "invalid_search_token_policy",
            "<manifest>",
            "fixture catalog must declare the reviewed null-only Search-token persistence policy",
        )
    entries = manifest.get("fixtures")
    if not isinstance(entries, list):
        report.add("invalid_fixture_entries", "<manifest>", "fixtures must be an array")
        return report

    payloads: dict[str, Any] = {}
    entries_by_id: dict[str, Mapping[str, Any]] = {}
    seen_paths: set[str] = set()
    for index, entry in enumerate(entries):
        fixture_id = f"fixtures[{index}]"
        if not isinstance(entry, dict):
            report.add("invalid_fixture_entry", fixture_id, "fixture entry must be an object")
            continue
        raw_id = entry.get("id")
        if not isinstance(raw_id, str) or not raw_id:
            report.add("invalid_fixture_id", fixture_id, "fixture id must be non-empty")
            continue
        fixture_id = raw_id
        if fixture_id in entries_by_id:
            report.add("duplicate_fixture_id", fixture_id, "fixture ids must be unique")
            continue
        entries_by_id[fixture_id] = entry
        relative = entry.get("path")
        if isinstance(relative, str):
            if relative in seen_paths:
                report.add("duplicate_fixture_path", fixture_id, "fixture paths must be unique")
            seen_paths.add(relative)
        fixture_path, path_error = _safe_fixture_path(manifest_path.parent, relative)
        if path_error:
            report.add("unsafe_fixture_path", fixture_id, path_error)
            continue
        assert fixture_path is not None
        try:
            if not fixture_path.is_file():
                report.add("missing_fixture", fixture_id, "fixture file is missing")
                continue
            payload, fixture_bytes = _load_json_bounded(
                fixture_path,
                max_bytes=MAX_FIXTURE_FILE_BYTES,
                label="fixture",
            )
            actual_canonical_hash = canonical_sha256(payload)
        except (
            OSError,
            ValueError,
            TypeError,
            RuntimeError,
            RecursionError,
            json.JSONDecodeError,
            FixtureContractError,
        ) as exc:
            report.add("fixture_parse_error", fixture_id, str(exc))
            continue
        payloads[fixture_id] = payload
        expected_byte_hash = entry.get("byte_sha256")
        actual_byte_hash = hashlib.sha256(fixture_bytes).hexdigest().upper()
        if actual_byte_hash != str(expected_byte_hash).upper():
            report.add("fixture_byte_hash_mismatch", fixture_id, "fixture byte hash changed", expected_byte_hash, actual_byte_hash)
        expected_canonical_hash = entry.get("canonical_sha256")
        if actual_canonical_hash != str(expected_canonical_hash).upper():
            report.add(
                "fixture_canonical_hash_mismatch",
                fixture_id,
                "fixture canonical tree hash changed",
                expected_canonical_hash,
                actual_canonical_hash,
            )
        covers = entry.get("covers")
        provenance = entry.get("provenance")
        if not isinstance(covers, list) or not covers or not all(isinstance(item, str) for item in covers):
            report.add("incomplete_fixture_coverage", fixture_id, "covers must be a non-empty string array")
        if not isinstance(provenance, dict) or not all(
            isinstance(provenance.get(key), str) and provenance.get(key)
            for key in ("source_kind", "derivation", "sanitization")
        ):
            report.add("incomplete_fixture_provenance", fixture_id, "source_kind/derivation/sanitization are required")
        classification = entry.get("classification")
        callback_input = entry.get("runtime_agent_callback_input")
        policy_input = entry.get("runtime_policy_input")
        if policy_input is not False:
            report.add("raw_fixture_claims_policy_authority", fixture_id, "raw fixtures are Host inputs, never policy-core inputs")
        path_text = relative if isinstance(relative, str) else ""
        if isinstance(classification, str) and classification in PUBLIC_CLASSIFICATIONS:
            report.public_fixture_count += 1
            if callback_input is not True or not path_text.startswith("public/"):
                report.add("public_fixture_isolation", fixture_id, "public callback fixtures must be enabled and stored below public/")
            _validate_public_observation(fixture_id, payload, report)
        elif isinstance(classification, str) and classification in PRIVATE_CLASSIFICATIONS:
            report.private_fixture_count += 1
            if callback_input is not False or not path_text.startswith("private/"):
                report.add("private_fixture_isolation", fixture_id, "private fixtures must be disabled and stored below private/")
        else:
            report.add("unknown_fixture_classification", fixture_id, f"unsupported classification: {classification!r}")

    if verify_sources:
        try:
            if trusted_source_lock_path is None or expected_source_lock_sha256 is None:
                raise FixtureContractError(
                    "source verification requires a caller-owned lock path and expected canonical hash"
                )
            if re.fullmatch(r"[0-9A-F]{64}", expected_source_lock_sha256) is None:
                raise FixtureContractError("expected_source_lock_sha256 must be an uppercase SHA-256")
            source_lock_path = Path(trusted_source_lock_path)
            if not source_lock_path.is_absolute() or not source_lock_path.is_file():
                raise FixtureContractError("trusted source lock must be an existing absolute file")
            source_lock, _source_lock_bytes = _load_json_bounded(
                source_lock_path,
                max_bytes=MAX_FIXTURE_CATALOG_BYTES,
                label="trusted source lock",
            )
            if not isinstance(source_lock, dict):
                raise FixtureContractError("source lock root must be an object")
            actual_lock_hash = canonical_sha256(source_lock)
            if actual_lock_hash != expected_source_lock_sha256:
                raise FixtureContractError("caller trust anchor does not match the trusted SOURCE_LOCK")
            if manifest.get("source_lock_id") != source_lock.get("lock_id"):
                raise FixtureContractError("fixture catalog source_lock_id does not match SOURCE_LOCK")
            if manifest.get("source_lock_canonical_sha256") != actual_lock_hash:
                raise FixtureContractError("fixture catalog does not bind the canonical SOURCE_LOCK")
            source_cache: dict[str, tuple[Any, Mapping[str, Any]]] = {}
            for fixture_id, entry in entries_by_id.items():
                if fixture_id not in payloads:
                    continue
                provenance = entry.get("provenance")
                if not isinstance(provenance, dict):
                    continue
                derivation = provenance.get("derivation")
                classification = entry.get("classification")
                if (
                    classification == "public_agent_observation"
                    and derivation != "replay_observation_extract"
                ):
                    raise FixtureContractError(
                        f"public Agent observations require locked replay extraction provenance: {fixture_id}"
                    )
                if (
                    classification == "synthetic_forward_compat_observation"
                    and derivation != "declared_mutation"
                ):
                    raise FixtureContractError(
                        f"synthetic forward-compat fixtures require a declared patch table: {fixture_id}"
                    )
                if (
                    classification == "private_replay_negative_control"
                    and derivation != "synthetic_negative_control"
                ):
                    raise FixtureContractError(
                        f"private negative controls require isolated synthetic provenance: {fixture_id}"
                    )
                if derivation == "replay_observation_extract":
                    artifact_id = provenance.get("source_artifact_id")
                    selector = provenance.get("source_selector")
                    if not isinstance(artifact_id, str) or not isinstance(selector, str):
                        raise FixtureContractError(f"missing source artifact/selector: {fixture_id}")
                    if artifact_id not in source_cache:
                        source_path, source_artifact = resolve_locked_artifact(
                            source_lock,
                            artifact_id,
                            root_overrides=root_overrides,
                        )
                        if source_artifact.get("hash_mode", "raw_bytes") != "raw_bytes":
                            raise FixtureContractError(f"fixture replay source must use raw_bytes: {artifact_id}")
                        source_cache[artifact_id] = (
                            _load_json_bounded(
                                source_path,
                                max_bytes=MAX_SOURCE_JSON_BYTES,
                                label="locked replay source",
                            )[0],
                            source_artifact,
                        )
                    source_payload, source_artifact = source_cache[artifact_id]
                    if source_artifact.get("data_classification") != "private_replay_container":
                        raise FixtureContractError(f"replay source lacks private-container classification: {artifact_id}")
                    if source_artifact.get("runtime_policy_input") is not False:
                        raise FixtureContractError(f"replay source is not isolated from policy input: {artifact_id}")
                    if provenance.get("source_sha256") != source_artifact.get("sha256"):
                        raise FixtureContractError(f"fixture provenance source hash differs from source lock: {fixture_id}")
                    if _PUBLIC_REPLAY_OBSERVATION_SELECTOR.fullmatch(selector) is None:
                        raise FixtureContractError(
                            f"public replay extraction must target steps/<n>/<seat>/observation: {fixture_id}"
                        )
                    extracted = _json_pointer_get(source_payload, selector)
                    declared_presence = provenance.get("source_search_capability_presence")
                    actual_presence = (
                        "non_null"
                        if isinstance(extracted, dict) and extracted.get("search_begin_input") is not None
                        else "null"
                    )
                    if declared_presence != actual_presence:
                        raise FixtureContractError(f"Search capability presence provenance differs: {fixture_id}")
                    expected = _apply_sanitizer(extracted, provenance.get("sanitization", "none"))
                    if canonical_sha256(expected) != canonical_sha256(payloads[fixture_id]):
                        report.add("fixture_source_mismatch", fixture_id, "fixture no longer reproduces its source selector and sanitizer")
                elif derivation == "declared_mutation":
                    base_id = provenance.get("base_fixture_id")
                    mutations = provenance.get("mutations")
                    if not isinstance(base_id, str) or base_id not in payloads or not isinstance(mutations, list):
                        raise FixtureContractError(f"invalid mutation provenance: {fixture_id}")
                    base_hash = canonical_sha256(payloads[base_id])
                    if provenance.get("base_canonical_sha256") != base_hash:
                        raise FixtureContractError(f"base fixture hash differs from mutation provenance: {fixture_id}")
                    expected = copy.deepcopy(payloads[base_id])
                    for mutation in mutations:
                        if not isinstance(mutation, dict):
                            raise FixtureContractError(f"invalid mutation entry: {fixture_id}")
                        operation = mutation.get("op")
                        if operation not in {"add", "replace"}:
                            raise FixtureContractError(f"unsupported mutation op: {operation!r}")
                        _json_pointer_set(expected, mutation.get("path"), mutation.get("value"), operation)
                    if canonical_sha256(expected) != canonical_sha256(payloads[fixture_id]):
                        report.add("fixture_mutation_mismatch", fixture_id, "synthetic fixture differs from its declared patch table")
                elif derivation == "synthetic_negative_control":
                    continue
                elif derivation == "exact_copy" and provenance.get("source_kind") == "synthetic":
                    continue
                else:
                    report.add("unverifiable_fixture_provenance", fixture_id, f"unsupported derivation: {derivation!r}")
        except (
            OSError,
            ValueError,
            TypeError,
            KeyError,
            IndexError,
            AttributeError,
            RuntimeError,
            RecursionError,
            json.JSONDecodeError,
            FixtureContractError,
        ) as exc:
            report.add("fixture_source_verification_error", "<manifest>", str(exc))
    return report


def load_public_fixture(
    manifest_path: str | Path,
    fixture_id: str,
    *,
    expected_catalog_canonical_sha256: str,
) -> dict[str, Any]:
    try:
        manifest_path = Path(manifest_path)
    except (OSError, TypeError, ValueError, RuntimeError) as exc:
        raise FixtureContractError("fixture catalog path is invalid") from exc
    if not re.fullmatch(r"[0-9A-F]{64}", expected_catalog_canonical_sha256):
        raise FixtureContractError("expected_catalog_canonical_sha256 must be an uppercase SHA-256")
    try:
        catalog_tree, _catalog_bytes = _load_json_bounded(
            manifest_path,
            max_bytes=MAX_FIXTURE_CATALOG_BYTES,
            label="fixture catalog",
        )
        actual_catalog_sha256 = canonical_sha256(catalog_tree)
    except (
        OSError,
        ValueError,
        TypeError,
        RuntimeError,
        RecursionError,
        json.JSONDecodeError,
        FixtureContractError,
    ) as exc:
        raise FixtureContractError(f"fixture catalog cannot be hashed safely: {exc}") from exc
    if actual_catalog_sha256 != expected_catalog_canonical_sha256:
        raise FixtureContractError(
            "fixture catalog canonical hash drift: "
            f"expected {expected_catalog_canonical_sha256}, got {actual_catalog_sha256}"
        )
    report = verify_fixture_catalog(manifest_path)
    if not report.ok:
        raise FixtureContractError(json.dumps(report.to_dict(), ensure_ascii=False, sort_keys=True))
    manifest = catalog_tree
    assert isinstance(manifest, dict)
    matches = [entry for entry in manifest["fixtures"] if entry.get("id") == fixture_id]
    if len(matches) != 1:
        raise FixtureContractError(f"fixture must resolve exactly once: {fixture_id}")
    entry = matches[0]
    if entry.get("classification") not in PUBLIC_CLASSIFICATIONS or entry.get("runtime_agent_callback_input") is not True:
        raise FixtureContractError(f"fixture is not an Agent callback input: {fixture_id}")
    fixture_path, error = _safe_fixture_path(manifest_path.parent, entry.get("path"))
    if error or fixture_path is None:
        raise FixtureContractError(error or "invalid fixture path")
    try:
        if not fixture_path.is_file():
            raise FixtureContractError(f"fixture file is missing: {fixture_id}")
        payload, _fixture_bytes = _load_json_bounded(
            fixture_path,
            max_bytes=MAX_FIXTURE_FILE_BYTES,
            label="fixture",
        )
    except (
        OSError,
        ValueError,
        TypeError,
        RuntimeError,
        RecursionError,
        json.JSONDecodeError,
        FixtureContractError,
    ) as exc:
        raise FixtureContractError(f"fixture cannot be loaded safely: {fixture_id}") from exc
    if not isinstance(payload, dict):
        raise FixtureContractError(f"public fixture root must be an object: {fixture_id}")
    return payload
