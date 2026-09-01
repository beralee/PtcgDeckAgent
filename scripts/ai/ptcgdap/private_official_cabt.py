from __future__ import annotations

import copy
import ctypes
import importlib
import json
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

from scripts.ai.ptcgdap.a3_differential import (
    A3DifferentialError,
    Checkpoint,
    _hash,
    parity_observation_hash,
    validate_checkpoint_selection,
)


class PrivateOfficialCabtError(RuntimeError):
    pass


class OfficialCabtCheckpointBuilder:
    """Convert one official callback without normalizing its wire frontier."""

    def __init__(self, source_identity_sha256: str) -> None:
        if (
            type(source_identity_sha256) is not str
            or len(source_identity_sha256) != 64
            or any(character not in "0123456789ABCDEF" for character in source_identity_sha256)
        ):
            raise PrivateOfficialCabtError("official_bridge_source_identity_invalid")
        self.source_identity_sha256 = source_identity_sha256
        self.transition_ordinal = 0
        self.callback_ordinal = 0
        self.window_generation = 0
        self.current: Checkpoint | None = None

    def advance_transition(self) -> None:
        self.transition_ordinal += 1

    def build(self, observation: Mapping[str, Any], *, select_player: int) -> Checkpoint:
        if type(observation) is not dict:
            raise PrivateOfficialCabtError("official_bridge_observation_invalid")
        raw = copy.deepcopy(observation)
        token = raw.get("search_begin_input")
        if token is not None and (type(token) is not str or not token.isascii()):
            raise PrivateOfficialCabtError("official_bridge_search_token_invalid")
        logs = raw.get("logs")
        current = raw.get("current")
        select = raw.get("select")
        if type(logs) is not list or any(type(item) is not dict for item in logs):
            raise PrivateOfficialCabtError("official_bridge_logs_invalid")
        if type(current) is not dict or type(current.get("result")) is not int:
            raise PrivateOfficialCabtError("official_bridge_current_invalid")
        terminal = current["result"] in (0, 1)
        if terminal:
            # The locked native runtime can retain the just-consumed SelectData
            # object in the terminal callback.  It is preserved byte-for-byte
            # in raw_actor_observation, but it is not a live action frontier:
            # terminal checkpoints expose no handle, options, or commit path.
            acting_seat: int | None = None
            options: list[dict[str, Any]] = []
            window_handle = None
            generation = None
        else:
            if select_player not in (0, 1) or current.get("yourIndex") != select_player:
                raise PrivateOfficialCabtError("official_bridge_acting_seat_invalid")
            if type(select) is not dict or type(select.get("option")) is not list:
                raise PrivateOfficialCabtError("official_bridge_selection_invalid")
            if any(type(option) is not dict for option in select["option"]):
                raise PrivateOfficialCabtError("official_bridge_selection_invalid")
            acting_seat = select_player
            options = copy.deepcopy(select["option"])
            self.window_generation += 1
            generation = self.window_generation
            window_handle = _hash({
                "source_identity_sha256": self.source_identity_sha256,
                "transition_ordinal": self.transition_ordinal,
                "callback_ordinal": self.callback_ordinal,
                "acting_seat": acting_seat,
                "window_generation": generation,
                "raw_observation_hash": parity_observation_hash(raw),
                "option_fingerprints": [_hash(option) for option in options],
            })
        public_snapshot = {
            "lifecycle": "terminal" if terminal else "selection",
            "current": copy.deepcopy(current),
            "select": copy.deepcopy(select),
            "ordered_options": copy.deepcopy(options),
            "incremental_logs": copy.deepcopy(logs),
            "result": current["result"],
        }
        value = {
            "source_lane": "official_native",
            "kind": "TERMINAL" if terminal else "SELECTION",
            "transition_ordinal": self.transition_ordinal,
            "callback_ordinal": self.callback_ordinal,
            "acting_seat": acting_seat,
            "raw_actor_observation": raw,
            "raw_observation_hash": parity_observation_hash(raw),
            "window_handle": window_handle,
            "window_generation": generation,
            "select": None if terminal else copy.deepcopy(select),
            "ordered_options": options,
            "option_fingerprints": [_hash(option) for option in options],
            "incremental_logs": copy.deepcopy(logs),
            "public_snapshot": public_snapshot,
            "random_event_cursor": 0,
            "diagnostic_capability_mask": [
                "official_private_state_unavailable",
                "official_rng_cursor_unavailable",
                "search_token_value_private",
            ],
        }
        try:
            checkpoint = Checkpoint.parse(value)
        except A3DifferentialError as error:
            raise PrivateOfficialCabtError(str(error)) from error
        self.callback_ordinal += 1
        self.current = checkpoint
        return checkpoint


class PrivateOfficialCabtRuntime:
    """Thin, process-local caller for a user-supplied official cg package."""

    def __init__(self, private_bundle_root: str | Path, source_identity_sha256: str) -> None:
        root = Path(private_bundle_root).resolve()
        package_root = root / "sample_submission" / "sample_submission"
        if package_root.is_symlink() or not (package_root / "cg" / "cg.dll").is_file():
            raise PrivateOfficialCabtError("official_bridge_private_package_missing")
        sys.path.insert(0, str(package_root))
        try:
            self.sim = importlib.import_module("cg.sim")
        except Exception as error:
            raise PrivateOfficialCabtError("official_bridge_private_package_load_failed") from error
        self.builder = OfficialCabtCheckpointBuilder(source_identity_sha256)
        self.started = False
        self.disposed = False
        self.pending: Checkpoint | None = None
        self.terminal: Mapping[str, Any] | None = None

    @staticmethod
    def _deck(value: Any) -> list[int]:
        if (
            type(value) is not list
            or len(value) != 60
            or any(type(card_id) is not int or card_id <= 0 for card_id in value)
        ):
            raise PrivateOfficialCabtError("official_bridge_deck_invalid")
        return list(value)

    def _get_battle_data(self) -> tuple[dict[str, Any], int]:
        serial = self.sim.lib.GetBattleData(self.sim.Battle.battle_ptr)
        try:
            observation = json.loads(serial.json.decode("utf-8"))
            token = ctypes.string_at(serial.data, serial.count).decode("ascii")
        except (AttributeError, UnicodeError, ValueError, json.JSONDecodeError) as error:
            raise PrivateOfficialCabtError("official_bridge_native_observation_invalid") from error
        observation["search_begin_input"] = token
        return observation, int(serial.selectPlayer)

    def start(self, match_spec: Mapping[str, Any]) -> Checkpoint:
        if self.started or type(match_spec) is not dict or set(match_spec) != {"deck0", "deck1"}:
            raise PrivateOfficialCabtError("official_bridge_start_invalid")
        deck0 = self._deck(match_spec["deck0"])
        deck1 = self._deck(match_spec["deck1"])
        cards = deck0 + deck1
        argument = (ctypes.c_int * len(cards))(*cards)
        start_data = self.sim.lib.BattleStart(argument)
        self.sim.Battle.battle_ptr = start_data.battlePtr
        if not start_data.battlePtr:
            raise PrivateOfficialCabtError(
                f"official_bridge_battle_start_error_{int(start_data.errorPlayer)}_{int(start_data.errorType)}"
            )
        self.started = True
        observation, seat = self._get_battle_data()
        checkpoint = self.builder.build(observation, select_player=seat)
        self._capture_terminal(checkpoint)
        return checkpoint

    def commit(self, window_handle: str, indexes: Sequence[int]) -> Mapping[str, Any]:
        current = self.builder.current
        if (
            not self.started
            or self.disposed
            or self.pending is not None
            or current is None
            or current.kind != "SELECTION"
            or window_handle != current.window_handle
        ):
            raise PrivateOfficialCabtError("official_bridge_commit_invalid")
        try:
            validated_indexes = validate_checkpoint_selection(current, indexes)
        except A3DifferentialError as error:
            raise PrivateOfficialCabtError("official_bridge_commit_invalid") from error
        argument = (ctypes.c_int * len(validated_indexes))(*validated_indexes)
        error = int(self.sim.lib.Select(
            self.sim.Battle.battle_ptr, argument, len(validated_indexes)
        ))
        if error != 0:
            raise PrivateOfficialCabtError(f"official_bridge_select_error_{error}")
        self.builder.advance_transition()
        observation, seat = self._get_battle_data()
        self.pending = self.builder.build(observation, select_player=seat)
        self._capture_terminal(self.pending)
        return {
            "accepted": True,
            "indexes": validated_indexes,
            "selection_count": len(validated_indexes),
        }

    def next_checkpoint(self) -> Checkpoint:
        if self.pending is None:
            raise PrivateOfficialCabtError("official_bridge_next_checkpoint_invalid")
        value = self.pending
        self.pending = None
        return value

    def semantic_snapshot(self, view: str, capability: str) -> Mapping[str, Any]:
        if view != "actor_public" or capability != "R0" or self.builder.current is None:
            raise PrivateOfficialCabtError("official_bridge_snapshot_capability_unsupported")
        return copy.deepcopy(self.builder.current.public_snapshot)

    def random_events_since(self, cursor: int) -> list[Mapping[str, Any]]:
        if cursor != 0:
            raise PrivateOfficialCabtError("official_bridge_rng_capability_unsupported")
        return []

    def terminal_result(self) -> Mapping[str, Any] | None:
        return copy.deepcopy(self.terminal)

    def _capture_terminal(self, checkpoint: Checkpoint) -> None:
        if checkpoint.kind == "TERMINAL":
            self.terminal = copy.deepcopy(checkpoint.public_snapshot)

    def dispose(self) -> None:
        if self.disposed:
            return
        if self.started and self.sim.Battle.battle_ptr:
            self.sim.lib.BattleFinish(self.sim.Battle.battle_ptr)
            self.sim.Battle.battle_ptr = None
        self.pending = None
        self.disposed = True


__all__ = [
    "OfficialCabtCheckpointBuilder", "PrivateOfficialCabtError",
    "PrivateOfficialCabtRuntime",
]
