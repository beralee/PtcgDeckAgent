from __future__ import annotations

import copy
import gc
import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads(
    (ROOT / "contracts/ptcgdap/godot_option_binding_conformance_vectors.json").read_text(encoding="utf-8")
)


class HostRef:
    pass


def materialize(value, refs):
    if isinstance(value, str) and value.startswith(("card:", "command:", "object:")):
        return refs.setdefault(value, HostRef())
    if isinstance(value, list):
        return [materialize(item, refs) for item in value]
    if isinstance(value, dict):
        return {key: materialize(item, refs) for key, item in value.items()}
    return value


def build_window(spec):
    result = CabtSelectionWindow.build(
        copy.deepcopy(spec["select"]),
        public_observation_hash=spec["public_observation_hash"],
        public_hash_authority=spec["public_hash_authority"],
        chooser_player_index=spec["chooser_player_index"],
    )
    if not result.accepted or not result.validate_integrity():
        raise AssertionError(result.to_public_dict())
    return result.window


def context():
    fixture = copy.deepcopy(VECTORS["fixture"])
    refs = {}
    source = materialize(fixture["source"], refs)
    window = build_window(fixture["window"])
    commands = materialize(fixture["private_commands"], refs)
    private_refs = materialize(fixture["private_object_refs"], refs)
    port = EngineDecisionPort(fixture["match_generation"])
    published = port.publish(
        source,
        fixture["decision_generation"],
        fixture["chooser_player_index"],
    )
    if not published.accepted:
        raise AssertionError(published.error_code)
    return fixture, refs, source, window, commands, private_refs, port, published.snapshot


def apply_bind_fault(fault, fixture, source, window, commands, private_refs):
    callback_hash = fixture["callback_binding_hash"]
    current_source = source
    if fault in {"window_option_reorder", "window_payload_change", "window_chooser_change"}:
        spec = copy.deepcopy(fixture["window"])
        if fault == "window_option_reorder":
            spec["select"]["option"][0], spec["select"]["option"][1] = (
                spec["select"]["option"][1],
                spec["select"]["option"][0],
            )
        elif fault == "window_payload_change":
            spec["select"]["option"][1]["index"] += 1
        else:
            spec["chooser_player_index"] = 1
        window = build_window(spec)
    elif fault == "callback_lowercase":
        callback_hash = callback_hash.lower()
    elif fault == "command_count":
        commands = commands[:-1]
    elif fault == "command_primitive":
        commands = list(commands)
        commands[0] = 17
    elif fault == "reference_count":
        private_refs = private_refs[:-1]
    elif fault == "reference_primitive":
        private_refs = copy.copy(private_refs)
        private_refs[0] = [17]
    elif fault == "source_mutation":
        current_source = dict(source)
        current_source["turn_action_count"] += 1
    elif fault == "null_window":
        window = None
    elif fault != "none":
        raise AssertionError(fault)
    return current_source, window, callback_hash, commands, private_refs


class GodotOptionBindingTests(unittest.TestCase):
    def test_shared_bind_vectors(self) -> None:
        for case in VECTORS["bind_cases"]:
            with self.subTest(case=case["id"]):
                fixture, refs, source, window, commands, private_refs, port, snapshot = context()
                current_source, current_window, callback_hash, current_commands, current_refs = apply_bind_fault(
                    case["fault"], fixture, source, window, commands, private_refs
                )
                owner = GodotOptionBinding()
                result = owner.bind(
                    port=port,
                    snapshot=snapshot,
                    current_source=current_source,
                    window=current_window,
                    callback_binding_hash=callback_hash,
                    private_commands=current_commands,
                    private_object_refs=current_refs,
                )
                expected = case["expected"]
                self.assertEqual(result.accepted, expected["accepted"])
                self.assertEqual(result.error_code, expected["error_code"])
                self.assertEqual(result.to_public_dict(), expected)
                self.assertTrue(result.validate_integrity(owner))
                if result.accepted:
                    self.assertIs(result.binding, owner.current_binding())
                    self.assertTrue(result.binding.validate_integrity(owner))
                    self.assertEqual(result.binding.to_audit_dict(), expected["audit"])
                    serialized = json.dumps(result.to_public_dict())
                    for forbidden in (
                        "callback_binding_hash", "private_engine_command", "private_object_refs",
                        "command:", "object:", "card:", "_pending_choice", "_dialog_data",
                    ):
                        self.assertNotIn(forbidden, serialized)
                else:
                    self.assertIsNone(result.binding)

    def test_shared_resolve_vectors(self) -> None:
        for case in VECTORS["resolve_cases"]:
            with self.subTest(case=case["id"]):
                fixture, refs, source, window, commands, private_refs, port, snapshot = context()
                owner = GodotOptionBinding()
                bound = owner.bind(
                    port=port,
                    snapshot=snapshot,
                    current_source=source,
                    window=window,
                    callback_binding_hash=fixture["callback_binding_hash"],
                    private_commands=commands,
                    private_object_refs=private_refs,
                )
                self.assertTrue(bound.accepted)
                current_source = source
                current_window = window
                callback_hash = fixture["callback_binding_hash"]
                option_index = case["option_index"]
                if case["fault"] == "callback_change":
                    callback_hash = "B" * 64
                elif case["fault"] == "source_mutation":
                    current_source = dict(source)
                    current_source["turn_action_count"] += 1
                elif case["fault"] == "equivalent_window_copy":
                    current_window = build_window(fixture["window"])
                    self.assertEqual(current_window.to_public_dict(), window.to_public_dict())
                    self.assertIsNot(current_window, window)
                elif case["fault"] == "bool_index":
                    option_index = True
                elif case["fault"] in {"negative_index", "out_of_range", "none"}:
                    pass
                else:
                    raise AssertionError(case["fault"])
                result = owner.resolve(
                    binding=bound.binding,
                    port=port,
                    snapshot=snapshot,
                    current_source=current_source,
                    window=current_window,
                    callback_binding_hash=callback_hash,
                    option_index=option_index,
                )
                self.assertEqual(result.accepted, case["expected"]["accepted"])
                self.assertEqual(result.error_code, case["expected"]["error_code"])
                self.assertEqual(result.to_public_dict(), case["expected"])
                self.assertTrue(result.validate_integrity(owner))
                if result.accepted:
                    self.assertIs(result.private_engine_command, commands[option_index])
                    self.assertEqual(len(result.private_object_refs), len(private_refs[option_index]))
                    for actual, expected in zip(result.private_object_refs, private_refs[option_index], strict=True):
                        self.assertIs(actual, expected)
                    self.assertNotIn("private", json.dumps(result.to_public_dict()))

    def test_snapshot_and_binding_replacement_semantics(self) -> None:
        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        first = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        )
        self.assertTrue(first.accepted)

        rejected = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash="bad",
            private_commands=commands, private_object_refs=private_refs,
        )
        self.assertFalse(rejected.accepted)
        still_current = owner.resolve(
            binding=first.binding, port=port, snapshot=snapshot, current_source=source,
            window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
        )
        self.assertTrue(still_current.accepted)

        replacement_commands = [HostRef() for _ in commands]
        replacement = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=replacement_commands, private_object_refs=private_refs,
        )
        self.assertTrue(replacement.accepted)
        self.assertEqual(
            owner.resolve(
                binding=first.binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "binding_not_current",
        )

        published = port.publish(source, fixture["decision_generation"] + 1, fixture["chooser_player_index"])
        self.assertTrue(published.accepted)
        self.assertEqual(
            owner.resolve(
                binding=replacement.binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "snapshot_not_current",
        )

    def test_reference_release_cross_owner_mutation_and_dto_copy_fail_closed(self) -> None:
        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        result = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        )
        binding = result.binding
        other = GodotOptionBinding()
        self.assertEqual(
            other.resolve(
                binding=binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "owner_mismatch",
        )
        copied = copy.deepcopy(binding.to_audit_dict())
        self.assertFalse(hasattr(copied, "validate_integrity"))

        binding._audit["private_engine_command"] = "private-sentinel"
        self.assertFalse(binding.validate_integrity(owner))
        self.assertEqual(binding.to_audit_dict(), {})
        self.assertEqual(
            owner.resolve(
                binding=binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "binding_integrity_invalid",
        )
        self.assertNotIn("private-sentinel", json.dumps(binding.to_audit_dict()))

        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        binding = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        ).binding
        doomed = commands[0]
        commands[0] = None
        refs.pop("command:0")
        del doomed
        gc.collect()
        self.assertEqual(
            owner.resolve(
                binding=binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "reference_released",
        )

        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        binding = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        ).binding
        doomed_object = private_refs[0][0]
        private_refs[0][0] = None
        refs.pop("object:card-choice")
        del doomed_object
        gc.collect()
        self.assertEqual(
            owner.resolve(
                binding=binding, port=port, snapshot=snapshot, current_source=source,
                window=window, callback_binding_hash=fixture["callback_binding_hash"], option_index=0,
            ).error_code,
            "reference_released",
        )

        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        binding = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        ).binding
        owner._current.audit["private_engine_command"] = "private-sentinel"
        self.assertFalse(binding.validate_integrity(owner))
        self.assertEqual(binding.to_audit_dict(), {})
        self.assertNotIn("private-sentinel", json.dumps(binding.to_audit_dict()))

    def test_exact_host_types_and_no_ticket_surface(self) -> None:
        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        for value, expected in (
            (tuple(commands), "invalid_private_commands"),
            ([*commands[:-1], {"call": "private"}], "invalid_private_commands"),
        ):
            with self.subTest(value=type(value).__name__):
                result = owner.bind(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=fixture["callback_binding_hash"],
                    private_commands=value, private_object_refs=private_refs,
                )
                self.assertEqual(result.error_code, expected)
        public_names = set(dir(owner))
        for forbidden in ("ticket", "consume", "commit", "execute", "dispatch"):
            self.assertFalse(any(forbidden in name.lower() for name in public_names))


if __name__ == "__main__":
    unittest.main()
