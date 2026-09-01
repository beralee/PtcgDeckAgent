from __future__ import annotations

import copy
import hashlib
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Protocol, Sequence

from .cabt_tree_hash import jcs_canonical_json_bytes
from .a3_entity_relation import SemanticActionBinder, SemanticEntityRelation
from .a3_operation_contract import (
    A3OperationContractError,
    comparable_operation_projection,
)
from .a3_match_plan import A3MatchPlan, A3MatchPlanError
DIFF_TAXONOMY = frozenset(
    {
        "oracle_provenance_diff", "lifecycle_diff", "observation_visibility_diff",
        "contract_shape_diff", "option_field_presence_diff", "option_generation_diff",
        "option_order_diff", "cardinality_diff", "legality_diff", "entity_lineage_diff",
        "zone_order_diff", "evolution_stack_diff", "binding_or_execution_diff",
        "random_schedule_diff", "random_outcome_diff", "damage_diff",
        "damage_counter_diff", "status_lifetime_diff", "continuous_or_replacement_diff",
        "once_per_turn_flag_diff", "log_diff", "ko_resolution_diff",
        "prize_resolution_diff", "promotion_diff", "terminal_diff",
        "harness_or_canonicalization_diff",
    }
)


class A3DifferentialError(RuntimeError):
    pass


class OracleRightsDecision(Protocol):
    """Public boundary accepted by the optional official-oracle adapter.

    The rights authority is supplied by the private validation workspace.  The
    public differential runtime depends only on this immutable decision shape,
    never on the private Control/Bot service package.
    """

    accepted: bool
    mode: Any
    operation: str
    claims: Mapping[str, bool]


def _hash(value: Any) -> str:
    def json_value(current: Any) -> Any:
        if isinstance(current, tuple):
            return [json_value(item) for item in current]
        if isinstance(current, Mapping):
            return {str(key): json_value(item) for key, item in current.items()}
        if isinstance(current, list):
            return [json_value(item) for item in current]
        return current

    return hashlib.sha256(jcs_canonical_json_bytes(json_value(value))).hexdigest().upper()


def parity_observation_projection(
    raw_observation: Mapping[str, Any] | None,
) -> Mapping[str, Any] | None:
    """Return callback semantics with an opaque Search token presence marker."""
    if raw_observation is None:
        return None
    if type(raw_observation) is not dict:
        raise A3DifferentialError("parity_raw_observation_invalid")
    projected = copy.deepcopy(raw_observation)
    if "search_begin_input" in projected:
        token = projected["search_begin_input"]
        projected["search_begin_input"] = {
            "presence": token is not None,
            "type": "opaque_ascii" if token is not None else "null",
        }
    return projected


def parity_observation_hash(raw_observation: Mapping[str, Any] | None) -> str:
    """Hash callback semantics without persisting the opaque Search token value."""
    return _hash(parity_observation_projection(raw_observation))


def semantic_transition_witness(value: Any) -> dict[str, Any]:
    if type(value) is not dict:
        raise A3DifferentialError("parity_transition_witness_invalid")
    accepted = value.get("accepted")
    indexes = value.get("indexes")
    selection_count = value.get("selection_count")
    if (
        accepted is not True
        or type(indexes) is not list
        or any(type(index) is not int or index < 0 for index in indexes)
        or len(indexes) != len(set(indexes))
        or type(selection_count) is not int
        or selection_count != len(indexes)
    ):
        raise A3DifferentialError("parity_transition_witness_invalid")
    return {
        "accepted": True,
        "indexes": list(indexes),
        "selection_count": selection_count,
    }


def _select_descriptor(value: Mapping[str, Any] | None) -> Mapping[str, Any] | None:
    if value is None:
        return None
    result = copy.deepcopy(dict(value))
    result.pop("option", None)
    return result


def validate_checkpoint_selection(checkpoint: "Checkpoint", indexes: Any) -> list[int]:
    select = checkpoint.select
    if (
        checkpoint.kind != "SELECTION"
        or type(select) is not dict
        or type(select.get("minCount")) is not int
        or type(select.get("maxCount")) is not int
        or select["minCount"] < 0
        or select["maxCount"] < select["minCount"]
        or select["maxCount"] > len(checkpoint.ordered_options)
        or type(indexes) is not list
        or any(type(index) is not int for index in indexes)
        or len(indexes) != len(set(indexes))
        or not select["minCount"] <= len(indexes) <= select["maxCount"]
        or any(index < 0 or index >= len(checkpoint.ordered_options) for index in indexes)
    ):
        raise A3DifferentialError("parity_indexes_invalid")
    return list(indexes)


@dataclass(frozen=True, slots=True)
class Checkpoint:
    source_lane: str
    kind: str
    transition_ordinal: int
    callback_ordinal: int
    acting_seat: int | None
    raw_actor_observation: Mapping[str, Any] | None
    raw_observation_hash: str
    window_handle: str | None
    window_generation: int | None
    select: Mapping[str, Any] | None
    ordered_options: tuple[Mapping[str, Any], ...]
    option_fingerprints: tuple[str, ...]
    incremental_logs: tuple[Mapping[str, Any], ...]
    public_snapshot: Mapping[str, Any]
    random_event_cursor: int
    diagnostic_capability_mask: tuple[str, ...]

    @classmethod
    def parse(cls, value: Any) -> "Checkpoint":
        if type(value) is not dict:
            raise A3DifferentialError("parity_checkpoint_invalid")
        source_lane = value.get("source_lane")
        kind = value.get("kind")
        seat = value.get("acting_seat")
        options = value.get("ordered_options")
        fingerprints = value.get("option_fingerprints")
        transition = value.get("transition_ordinal")
        callback = value.get("callback_ordinal")
        raw_hash = value.get("raw_observation_hash")
        logs = value.get("incremental_logs")
        snapshot = value.get("public_snapshot")
        random_cursor = value.get("random_event_cursor")
        diagnostics = value.get("diagnostic_capability_mask")
        raw_observation = value.get("raw_actor_observation")
        if (
            source_lane not in ("official_native", "godot_private", "test_fixture")
            or kind not in ("INITIAL_DECK", "SELECTION", "TERMINAL")
            or (seat is not None and (type(seat) is not int or seat not in (0, 1)))
            or type(transition) is not int or transition < 0
            or type(callback) is not int or callback < 0
            or type(raw_hash) is not str or len(raw_hash) != 64
            or raw_hash != raw_hash.upper()
            or type(options) is not list
            or type(fingerprints) is not list
            or len(options) != len(fingerprints)
            or any(type(option) is not dict for option in options)
            or any(type(item) is not str or len(item) != 64 for item in fingerprints)
            or type(logs) is not list or any(type(item) is not dict for item in logs)
            or type(snapshot) is not dict
            or type(random_cursor) is not int or random_cursor < 0
            or type(diagnostics) is not list
            or any(type(item) is not str or not item for item in diagnostics)
            or len(diagnostics) != len(set(diagnostics))
        ):
            raise A3DifferentialError("parity_checkpoint_invalid")
        if raw_hash != parity_observation_hash(raw_observation):
            raise A3DifferentialError("parity_raw_observation_hash_invalid")
        if tuple(_hash(option) for option in options) != tuple(fingerprints):
            raise A3DifferentialError("parity_option_fingerprint_invalid")
        if kind == "SELECTION" and (
            type(value.get("window_handle")) is not str
            or not value["window_handle"]
            or type(value.get("window_generation")) is not int
            or value["window_generation"] < 1
            or type(value.get("select")) is not dict
        ):
            raise A3DifferentialError("parity_checkpoint_invalid")
        if kind == "SELECTION":
            select = value["select"]
            wire_options = select.get("option")
            if (
                type(select.get("type")) is not int
                or type(select.get("context")) is not int
                or type(select.get("minCount")) is not int
                or type(select.get("maxCount")) is not int
                or select["minCount"] < 0
                or select["maxCount"] < select["minCount"]
                or select["maxCount"] > len(options)
                or (wire_options is not None and wire_options != options)
            ):
                raise A3DifferentialError("parity_checkpoint_invalid")
        if kind != "SELECTION" and (
            value.get("window_handle") is not None
            or value.get("window_generation") is not None
            or value.get("select") is not None
            or options
        ):
            raise A3DifferentialError("parity_checkpoint_invalid")
        if kind == "TERMINAL" and seat is not None:
            raise A3DifferentialError("parity_checkpoint_invalid")
        return cls(
            source_lane,
            kind,
            transition,
            callback,
            seat,
            copy.deepcopy(raw_observation),
            raw_hash,
            value.get("window_handle"),
            value.get("window_generation"),
            copy.deepcopy(value.get("select")),
            tuple(copy.deepcopy(options)),
            tuple(fingerprints),
            tuple(copy.deepcopy(logs)),
            copy.deepcopy(snapshot),
            random_cursor,
            tuple(diagnostics),
        )


class EngineAdapter(Protocol):
    adapter_id: str
    def start(self, match_spec: Mapping[str, Any]) -> Checkpoint: ...
    def next_checkpoint(self) -> Checkpoint: ...
    def commit(self, window_handle: str, indexes: list[int]) -> Mapping[str, Any]: ...
    def semantic_snapshot(self, view: str, capability: str) -> Mapping[str, Any]: ...
    def random_events_since(self, cursor: int) -> tuple[Mapping[str, Any], ...]: ...
    def terminal_result(self) -> Mapping[str, Any] | None: ...
    def dispose(self) -> None: ...


class JsonLineEngineAdapter:
    """Executable transport for an engine-owned JSON-line bridge.

    The bridge is event-driven: callers cannot ask to observe an arbitrary seat.
    Every response carries the next engine-published acting-seat checkpoint.
    """

    def __init__(
        self,
        adapter_id: str,
        command: Sequence[str],
        *,
        expected_source_lane: str,
        cwd: str | Path | None = None,
    ) -> None:
        if (
            not adapter_id
            or not command
            or expected_source_lane not in ("official_native", "godot_private")
        ):
            raise A3DifferentialError("parity_adapter_configuration_invalid")
        self.adapter_id = adapter_id
        self._expected_source_lane = expected_source_lane
        self._command = tuple(command)
        self._cwd = None if cwd is None else str(cwd)
        self._process: subprocess.Popen[str] | None = None
        self._state = "CREATED"
        self._current_window_handle: str | None = None
        self._current_checkpoint: Checkpoint | None = None

    def _ensure_process(self) -> None:
        if self._process is None:
            self._process = subprocess.Popen(
                self._command,
                cwd=self._cwd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
            )

    def _rpc(self, method: str, payload: Mapping[str, Any] | None = None) -> Any:
        self._ensure_process()
        assert self._process is not None and self._process.stdin is not None and self._process.stdout is not None
        request = {"method": method, "payload": dict(payload or {})}
        self._process.stdin.write(json.dumps(request, ensure_ascii=False, separators=(",", ":")) + "\n")
        self._process.stdin.flush()
        line = self._process.stdout.readline()
        if not line:
            raise A3DifferentialError("parity_adapter_process_terminated")
        response = json.loads(line)
        if type(response) is not dict or not response.get("ok", False):
            raise A3DifferentialError(str(response.get("error_code", "parity_adapter_error")))
        return response.get("result")

    def start(self, match_spec: Mapping[str, Any]) -> Checkpoint:
        if self._state != "CREATED":
            raise A3DifferentialError("parity_adapter_state_invalid")
        checkpoint = Checkpoint.parse(self._rpc("start", match_spec))
        self._verify_source_lane(checkpoint)
        self._state = "TERMINAL" if checkpoint.kind == "TERMINAL" else "WAITING_SELECTION"
        self._current_window_handle = checkpoint.window_handle
        self._current_checkpoint = checkpoint
        return checkpoint

    def next_checkpoint(self) -> Checkpoint:
        if self._state != "COMMITTED":
            raise A3DifferentialError("parity_adapter_state_invalid")
        checkpoint = Checkpoint.parse(self._rpc("next_checkpoint"))
        self._verify_source_lane(checkpoint)
        self._state = "TERMINAL" if checkpoint.kind == "TERMINAL" else "WAITING_SELECTION"
        self._current_window_handle = checkpoint.window_handle
        self._current_checkpoint = checkpoint
        return checkpoint

    def _verify_source_lane(self, checkpoint: Checkpoint) -> None:
        if checkpoint.source_lane != self._expected_source_lane:
            raise A3DifferentialError("parity_checkpoint_source_lane_invalid")

    def commit(self, window_handle: str, indexes: list[int]) -> Mapping[str, Any]:
        if (
            self._state != "WAITING_SELECTION"
            or window_handle != self._current_window_handle
            or self._current_checkpoint is None
        ):
            raise A3DifferentialError("parity_adapter_state_invalid")
        validated_indexes = validate_checkpoint_selection(self._current_checkpoint, indexes)
        result = self._rpc("commit", {"window_handle": window_handle, "indexes": validated_indexes})
        result = semantic_transition_witness(result)
        self._state = "COMMITTED"
        self._current_window_handle = None
        self._current_checkpoint = None
        return result

    def semantic_snapshot(self, view: str, capability: str) -> Mapping[str, Any]:
        result = self._rpc("semantic_snapshot", {"view": view, "capability": capability})
        if type(result) is not dict:
            raise A3DifferentialError("parity_snapshot_invalid")
        return result

    def random_events_since(self, cursor: int) -> tuple[Mapping[str, Any], ...]:
        result = self._rpc("random_events_since", {"cursor": cursor})
        if type(result) is not list or any(type(event) is not dict for event in result):
            raise A3DifferentialError("parity_random_events_invalid")
        return tuple(result)

    def terminal_result(self) -> Mapping[str, Any] | None:
        result = self._rpc("terminal_result")
        if result is not None and type(result) is not dict:
            raise A3DifferentialError("parity_terminal_invalid")
        return result

    def dispose(self) -> None:
        if self._state == "DISPOSED":
            return
        if self._process is not None:
            process = self._process
            try:
                self._rpc("dispose")
            finally:
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=5)
                for stream in (process.stdin, process.stdout, process.stderr):
                    if stream is not None:
                        stream.close()
                self._process = None
        self._state = "DISPOSED"


class OfficialCabtEngineAdapter(JsonLineEngineAdapter):
    def __init__(
        self,
        command: Sequence[str],
        rights: OracleRightsDecision,
        *,
        cwd: str | Path | None = None,
    ) -> None:
        mode = getattr(rights.mode, "value", rights.mode)
        claims = rights.claims if isinstance(rights.claims, Mapping) else {}
        private_read = (
            mode == "user_supplied_private"
            and rights.operation == "local_private_oracle"
            and claims.get("read_private_bundle") is True
            and claims.get("cache_private_bundle") is False
            and claims.get("upload_private_bundle") is False
        )
        explicit = mode == "explicit_authorized"
        if not rights.accepted or not (explicit or private_read):
            raise A3DifferentialError("authority_official_oracle_unavailable")
        super().__init__(
            "official-cabt-native", command,
            expected_source_lane="official_native", cwd=cwd,
        )


class GodotHeadlessEngineAdapter(JsonLineEngineAdapter):
    def __init__(self, command: Sequence[str], *, cwd: str | Path | None = None) -> None:
        super().__init__(
            "godot-headless-decision-owner-v2", command,
            expected_source_lane="godot_private", cwd=cwd,
        )


class TranscriptEngineAdapter:
    """Deterministic development adapter for harness qualification only."""

    def __init__(self, adapter_id: str, checkpoints: Sequence[Mapping[str, Any]]) -> None:
        self.adapter_id = adapter_id
        self._checkpoints = tuple(Checkpoint.parse(value) for value in checkpoints)
        self._cursor = -1
        self._commits: list[tuple[str, tuple[int, ...]]] = []
        self._disposed = False

    def start(self, _match_spec: Mapping[str, Any]) -> Checkpoint:
        if self._cursor != -1:
            raise A3DifferentialError("parity_adapter_state_invalid")
        self._cursor = 0
        return self._checkpoints[0]

    def next_checkpoint(self) -> Checkpoint:
        self._cursor += 1
        return self._checkpoints[self._cursor]

    def commit(self, window_handle: str, indexes: list[int]) -> Mapping[str, Any]:
        current = self._checkpoints[self._cursor]
        if current.kind != "SELECTION" or current.window_handle != window_handle:
            raise A3DifferentialError("binding_or_execution_diff")
        validated_indexes = validate_checkpoint_selection(current, indexes)
        self._commits.append((window_handle, tuple(validated_indexes)))
        return {
            "accepted": True,
            "indexes": validated_indexes,
            "selection_count": len(validated_indexes),
        }

    def semantic_snapshot(self, _view: str, _capability: str) -> Mapping[str, Any]:
        return self._checkpoints[self._cursor].public_snapshot

    def random_events_since(self, _cursor: int) -> tuple[Mapping[str, Any], ...]: return ()
    def terminal_result(self) -> Mapping[str, Any] | None:
        return self._checkpoints[self._cursor].public_snapshot if self._checkpoints[self._cursor].kind == "TERMINAL" else None
    def dispose(self) -> None: self._disposed = True


@dataclass(frozen=True, slots=True)
class FirstDivergence:
    classification: str
    phase: str
    transition_ordinal: int
    left_hash: str
    right_hash: str
    path: str


def compare_checkpoints(
    left: Checkpoint,
    right: Checkpoint,
    *,
    phase: str,
    relation: SemanticEntityRelation | None = None,
) -> FirstDivergence | None:
    try:
        semantic_left = left.option_fingerprints if relation is None else relation.semantic_frontier("left", left.ordered_options)
        semantic_right = right.option_fingerprints if relation is None else relation.semantic_frontier("right", right.ordered_options)
        left_observation: Any = parity_observation_projection(left.raw_actor_observation)
        right_observation: Any = parity_observation_projection(right.raw_actor_observation)
        left_select: Any = _select_descriptor(left.select)
        right_select: Any = _select_descriptor(right.select)
        left_logs: Any = left.incremental_logs
        right_logs: Any = right.incremental_logs
        left_snapshot: Any = left.public_snapshot
        right_snapshot: Any = right.public_snapshot
        if relation is not None:
            left_observation = relation.semantic_tree("left", left_observation)
            right_observation = relation.semantic_tree("right", right_observation)
            left_select = relation.semantic_tree("left", left_select)
            right_select = relation.semantic_tree("right", right_select)
            left_logs = relation.semantic_tree("left", left_logs)
            right_logs = relation.semantic_tree("right", right_logs)
            left_snapshot = relation.semantic_tree("left", left_snapshot)
            right_snapshot = relation.semantic_tree("right", right_snapshot)
    except RuntimeError:
        return FirstDivergence(
            "entity_lineage_diff", phase,
            min(left.transition_ordinal, right.transition_ordinal),
            _hash(left.ordered_options), _hash(right.ordered_options),
            "/ordered_options/entity_relation",
        )
    pairs = (
        ("terminal_diff" if "TERMINAL" in (left.kind, right.kind) else "lifecycle_diff", "/kind", left.kind, right.kind),
        ("lifecycle_diff", "/acting_seat", left.acting_seat, right.acting_seat),
        ("observation_visibility_diff", "/raw_actor_observation", left_observation, right_observation),
        ("contract_shape_diff", "/select", left_select, right_select),
        ("option_generation_diff", "/ordered_options/count", len(left.ordered_options), len(right.ordered_options)),
        ("option_order_diff", "/semantic_option_fingerprints", semantic_left, semantic_right),
        ("random_schedule_diff", "/random_event_cursor", left.random_event_cursor, right.random_event_cursor),
        ("contract_shape_diff", "/diagnostic_capability_mask", left.diagnostic_capability_mask, right.diagnostic_capability_mask),
        ("log_diff", "/incremental_logs", left_logs, right_logs),
        ("damage_or_public_state_diff", "/public_snapshot", left_snapshot, right_snapshot),
    )
    for classification, path, left_value, right_value in pairs:
        if left_value != right_value:
            if classification == "damage_or_public_state_diff":
                classification = "damage_diff" if "damage" in json.dumps([left_value, right_value]) else "contract_shape_diff"
            return FirstDivergence(classification, phase, min(left.transition_ordinal, right.transition_ordinal), _hash(left_value), _hash(right_value), path)
    return None


def compare_operation_inputs(
    left: Checkpoint,
    right: Checkpoint,
    *,
    relation: SemanticEntityRelation,
    phase: str = "before_action",
) -> FirstDivergence | None:
    """Compare the exact current-window operation contract across ID domains."""
    try:
        left_value = relation.semantic_tree(
            "left", comparable_operation_projection(left)
        )
        right_value = relation.semantic_tree(
            "right", comparable_operation_projection(right)
        )
    except (RuntimeError, A3OperationContractError):
        return FirstDivergence(
            "entity_lineage_diff", phase,
            min(left.transition_ordinal, right.transition_ordinal),
            parity_observation_hash(left.raw_actor_observation),
            parity_observation_hash(right.raw_actor_observation),
            "/operation_input/entity_relation",
        )
    if left_value == right_value:
        return None
    left_header = left_value.get("select_header")
    right_header = right_value.get("select_header")
    path = "/operation_input/select_header" if left_header != right_header \
        else "/operation_input/ordered_semantic_options"
    classification = "contract_shape_diff" if left_header != right_header \
        else "option_order_diff"
    return FirstDivergence(
        classification, phase,
        min(left.transition_ordinal, right.transition_ordinal),
        _hash(left_value), _hash(right_value), path,
    )


class LockstepDifferentialDriver:
    def __init__(
        self,
        left: EngineAdapter,
        right: EngineAdapter,
        *,
        entity_relation: SemanticEntityRelation | None = None,
    ) -> None:
        self.left = left
        self.right = right
        self.entity_relation = entity_relation
        self.history: list[dict[str, Any]] = []
        self.first_divergence: FirstDivergence | None = None
        self.comparison_surface = "full_checkpoint"
        self.match_plan_sha256: str | None = None

    def start(self, match_spec: Mapping[str, Any]) -> tuple[Checkpoint, Checkpoint]:
        if match_spec.get("document_type") == "ptcgdap_a3_sealed_match_plan_v2":
            try:
                plan = A3MatchPlan.parse(match_spec)
            except A3MatchPlanError as error:
                raise A3DifferentialError(str(error)) from error
            if (
                self.left.adapter_id != "godot-headless-decision-owner-v2"
                or self.right.adapter_id != "official-cabt-native"
                or self.entity_relation is None
                or self.entity_relation.relation_hash != plan.relation_sha256
            ):
                raise A3DifferentialError("parity_match_plan_adapter_binding_invalid")
            official = self.right.start(plan.official_projection())
            try:
                godot_spec = plan.godot_projection(official)
                resolved_anchor = plan.resolved_operation_anchor(official)
            except A3MatchPlanError as error:
                raise A3DifferentialError(str(error)) from error
            godot = self.left.start(godot_spec)
            self.comparison_surface = "current_window_operation"
            self.match_plan_sha256 = plan.plan_sha256
            godot = self._advance_to_operation_anchor(self.left, godot, resolved_anchor)
            official = self._advance_to_operation_anchor(self.right, official, resolved_anchor)
            return self._compare(godot, official, "operation_anchor")
        return self._compare(self.left.start(match_spec), self.right.start(match_spec), "before_action")

    def commit_exact(
        self,
        left: Checkpoint,
        right: Checkpoint,
        indexes: list[int],
        *,
        compare_next_operation: bool = True,
    ) -> tuple[Checkpoint, Checkpoint] | None:
        if self.first_divergence is not None:
            raise A3DifferentialError("parity_commit_after_divergence_forbidden")
        left_frontier: Any = left.option_fingerprints
        right_frontier: Any = right.option_fingerprints
        if self.comparison_surface == "current_window_operation":
            if self.entity_relation is None:
                raise A3DifferentialError("parity_entity_relation_required")
            self._bind_current_operation_entities(left, right)
            left_frontier = self.entity_relation.semantic_tree(
                "left", comparable_operation_projection(left)["ordered_semantic_options"]
            )
            right_frontier = self.entity_relation.semantic_tree(
                "right", comparable_operation_projection(right)["ordered_semantic_options"]
            )
        elif self.entity_relation is not None:
            left_frontier = self.entity_relation.semantic_frontier("left", left.ordered_options)
            right_frontier = self.entity_relation.semantic_frontier("right", right.ordered_options)
        if left.kind != "SELECTION" or right.kind != "SELECTION" or left_frontier != right_frontier:
            raise A3DifferentialError("parity_option_frontier_not_equal")
        validate_checkpoint_selection(left, indexes)
        validate_checkpoint_selection(right, indexes)
        try:
            left_witness = semantic_transition_witness(
                self.left.commit(left.window_handle or "", indexes)
            )
            right_witness = semantic_transition_witness(
                self.right.commit(right.window_handle or "", indexes)
            )
        except A3DifferentialError:
            self.first_divergence = FirstDivergence(
                "binding_or_execution_diff", "commit", left.transition_ordinal,
                _hash("invalid_transition_witness"), _hash("invalid_transition_witness"),
                "/transition_witness",
            )
            return None
        expected_witness = {
            "accepted": True, "indexes": list(indexes), "selection_count": len(indexes),
        }
        if left_witness != expected_witness or right_witness != expected_witness:
            self.first_divergence = FirstDivergence(
                "binding_or_execution_diff", "commit", left.transition_ordinal,
                _hash(left_witness), _hash(right_witness), "/transition_witness/selection",
            )
            return None
        if left_witness != right_witness:
            self.first_divergence = FirstDivergence(
                "binding_or_execution_diff", "commit", left.transition_ordinal,
                _hash(left_witness), _hash(right_witness), "/transition_witness",
            )
            return None
        next_left = self.left.next_checkpoint()
        next_right = self.right.next_checkpoint()
        if compare_next_operation:
            return self._compare(next_left, next_right, "after_commit")
        self.history.append({
            "phase": "post_commit_public_transition",
            "transition_ordinal": min(
                next_left.transition_ordinal, next_right.transition_ordinal
            ),
            "left_hash": parity_observation_hash(next_left.raw_actor_observation),
            "right_hash": parity_observation_hash(next_right.raw_actor_observation),
            "entity_bijection_hash": (
                None if self.entity_relation is None
                else self.entity_relation.relation_hash
            ),
            "aligned": None,
            "next_operation_compared": False,
        })
        return next_left, next_right

    def compare_current_operation(
        self,
        left: Checkpoint,
        right: Checkpoint,
        *,
        phase: str = "current_operation",
    ) -> tuple[Checkpoint, Checkpoint]:
        if self.comparison_surface != "current_window_operation":
            raise A3DifferentialError("parity_operation_comparison_surface_required")
        return self._compare(left, right, phase)

    def commit_semantic(
        self,
        left: Checkpoint,
        right: Checkpoint,
        intent: Mapping[str, Any],
    ) -> tuple[Checkpoint, Checkpoint] | None:
        if self.entity_relation is None:
            raise A3DifferentialError("parity_entity_relation_required")
        left_indexes = SemanticActionBinder.resolve(
            intent, side="left", options=left.ordered_options, relation=self.entity_relation,
        )
        right_indexes = SemanticActionBinder.resolve(
            intent, side="right", options=right.ordered_options, relation=self.entity_relation,
        )
        if left_indexes != right_indexes:
            self.first_divergence = FirstDivergence(
                "option_order_diff", "semantic_bind", left.transition_ordinal,
                _hash(left_indexes), _hash(right_indexes), "/semantic_intent/indexes",
            )
            return None
        return self.commit_exact(left, right, left_indexes)

    def _compare(self, left: Checkpoint, right: Checkpoint, phase: str) -> tuple[Checkpoint, Checkpoint]:
        if self.comparison_surface == "current_window_operation":
            if left.kind != right.kind:
                divergence = FirstDivergence(
                    "lifecycle_diff", phase,
                    min(left.transition_ordinal, right.transition_ordinal),
                    _hash(left.kind), _hash(right.kind), "/kind",
                )
            elif left.kind == "SELECTION":
                self._bind_current_operation_entities(left, right)
                assert self.entity_relation is not None
                divergence = compare_operation_inputs(
                    left, right, phase=phase, relation=self.entity_relation,
                )
            else:
                divergence = None
        else:
            divergence = compare_checkpoints(left, right, phase=phase, relation=self.entity_relation)
        self.history.append({
            "phase": phase,
            "transition_ordinal": min(left.transition_ordinal, right.transition_ordinal),
            "left_hash": _hash(left.public_snapshot),
            "right_hash": _hash(right.public_snapshot),
            "entity_bijection_hash": None if self.entity_relation is None else self.entity_relation.relation_hash,
            "aligned": divergence is None,
        })
        if divergence is not None and self.first_divergence is None:
            self.first_divergence = divergence
        return left, right

    @staticmethod
    def _advance_to_operation_anchor(
        adapter: EngineAdapter,
        checkpoint: Checkpoint,
        anchor: Mapping[str, Any],
    ) -> Checkpoint:
        if set(anchor) != {
            "lifecycle_id", "select_type", "select_context", "acting_seat",
            "occurrence_ordinal", "candidate_count", "starting_player_choice_index",
        } or anchor.get("lifecycle_id") != "setup_active_after_starting_player_yes":
            raise A3DifferentialError("parity_match_plan_anchor_invalid")
        matching_occurrence = 0
        starting_player_choice_count = 0
        for _ in range(512):
            if (
                checkpoint.kind == "SELECTION"
                and checkpoint.select is not None
                and checkpoint.select.get("type") == anchor.get("select_type")
                and checkpoint.select.get("context") == anchor.get("select_context")
                and checkpoint.acting_seat == anchor.get("acting_seat")
            ):
                matching_occurrence += 1
                if matching_occurrence == anchor.get("occurrence_ordinal"):
                    if (
                        starting_player_choice_count != 1
                        or len(checkpoint.ordered_options) != anchor.get("candidate_count")
                    ):
                        raise A3DifferentialError("parity_match_plan_anchor_invalid")
                    return checkpoint
            if checkpoint.kind != "SELECTION" or checkpoint.select is None:
                raise A3DifferentialError("parity_match_plan_anchor_unreachable")
            context = checkpoint.select.get("context")
            indexes: list[int]
            if context in (41, 42):
                indexes = [next((
                    index for index, option in enumerate(checkpoint.ordered_options)
                    if option.get("type", option.get("option_type_raw")) == 1
                ), -1)]
                if context == 41:
                    starting_player_choice_count += 1
                    if indexes != [anchor.get("starting_player_choice_index")]:
                        raise A3DifferentialError("parity_match_plan_anchor_invalid")
            elif context == 38:
                indexes = [next((
                    index for index, option in enumerate(checkpoint.ordered_options)
                    if option.get("number", option.get("option_number")) == 0
                ), -1)]
            else:
                indexes = list(range(checkpoint.select["minCount"]))
            if any(index < 0 for index in indexes):
                raise A3DifferentialError("parity_match_plan_anchor_unreachable")
            adapter.commit(checkpoint.window_handle or "", indexes)
            checkpoint = adapter.next_checkpoint()
        raise A3DifferentialError("parity_match_plan_anchor_unreachable")

    def _bind_current_operation_entities(self, left: Checkpoint, right: Checkpoint) -> None:
        if self.entity_relation is None:
            raise A3DifferentialError("parity_entity_relation_required")
        try:
            left_options = comparable_operation_projection(left)["ordered_semantic_options"]
            right_options = comparable_operation_projection(right)["ordered_semantic_options"]
            if len(left_options) != len(right_options):
                return
            pairs: list[tuple[str | int, int, int, int, str]] = []

            def visit(left_value: Any, right_value: Any, path: str) -> tuple[Any, Any]:
                if type(left_value) is dict and type(right_value) is dict:
                    if set(left_value) != set(right_value):
                        return left_value, right_value
                    if set(("cardId", "serial")).issubset(left_value):
                        left_id = left_value["cardId"]
                        right_id = right_value["cardId"]
                        left_semantic = self.entity_relation.semantic_card_id("left", left_id)
                        right_semantic = self.entity_relation.semantic_card_id("right", right_id)
                        if left_semantic != right_semantic:
                            return left_value, right_value
                        pairs.append((left_id, int(right_id), int(left_value["serial"]), int(right_value["serial"]), path))
                        return ({"cardId": left_semantic}, {"cardId": right_semantic})
                    left_result: dict[str, Any] = {}
                    right_result: dict[str, Any] = {}
                    for key in left_value:
                        left_result[key], right_result[key] = visit(
                            left_value[key], right_value[key], f"{path}/{key}"
                        )
                    return left_result, right_result
                if type(left_value) is list and type(right_value) is list and len(left_value) == len(right_value):
                    left_result, right_result = [], []
                    for index, (left_item, right_item) in enumerate(zip(left_value, right_value, strict=True)):
                        next_left, next_right = visit(left_item, right_item, f"{path}/{index}")
                        left_result.append(next_left)
                        right_result.append(next_right)
                    return left_result, right_result
                return left_value, right_value

            left_skeleton, right_skeleton = visit(left_options, right_options, "/options")
            if left_skeleton != right_skeleton:
                return
            window_evidence_hash = _hash({
                "match_plan_sha256": self.match_plan_sha256,
                "left_header": comparable_operation_projection(left)["select_header"],
                "right_header": comparable_operation_projection(right)["select_header"],
                "semantic_skeleton": left_skeleton,
            })
            for left_id, right_id, left_serial, right_serial, path in pairs:
                semantic = self.entity_relation.semantic_card_id("left", left_id)
                if type(semantic) is not str:
                    raise A3DifferentialError("parity_current_window_entity_invalid")
                self.entity_relation.bind_current_window_entity(
                    semantic_card_id=semantic, left_card_id=left_id,
                    official_card_id=right_id, left_serial=left_serial,
                    right_serial=right_serial,
                    window_evidence_hash=_hash({
                        "window": window_evidence_hash, "path": path,
                    }),
                )
        except (RuntimeError, A3OperationContractError, ValueError, TypeError) as error:
            raise A3DifferentialError("parity_current_window_entity_invalid") from error

    def public_report(self, scope: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "document_type": "ptcgdap_a3_differential_report_v2",
            "scope_sha256": scope.get("scope_sha256"),
            "status": "aligned" if self.first_divergence is None else "unexplained_difference",
            # A single run is evidence input, never promotion authority.  Only
            # A3QualificationOwner may aggregate the exact 25-configuration
            # ledger, self-reruns, scenario/mutation coverage and review receipt.
            "a3_promoted": False,
            "promotion_authority": "qualification_owner_only",
            "comparison_surface": self.comparison_surface,
            "match_plan_sha256": self.match_plan_sha256,
            "maximum_claim": scope.get("oracle_provenance", {}).get("maximum_claim", "development-only"),
            "transitions": copy.deepcopy(self.history),
            "first_divergence": None if self.first_divergence is None else {
                "classification": self.first_divergence.classification,
                "phase": self.first_divergence.phase,
                "transition_ordinal": self.first_divergence.transition_ordinal,
                "left_hash": self.first_divergence.left_hash,
                "right_hash": self.first_divergence.right_hash,
                "path": self.first_divergence.path,
            },
        }


__all__ = [
    "A3DifferentialError", "Checkpoint", "DIFF_TAXONOMY", "EngineAdapter",
    "FirstDivergence", "GodotHeadlessEngineAdapter", "JsonLineEngineAdapter",
    "LockstepDifferentialDriver", "OfficialCabtEngineAdapter", "TranscriptEngineAdapter",
    "SemanticActionBinder", "SemanticEntityRelation", "compare_checkpoints",
    "compare_operation_inputs",
    "parity_observation_hash", "semantic_transition_witness",
    "parity_observation_projection",
    "validate_checkpoint_selection",
]
