from __future__ import annotations

from copy import deepcopy
from enum import IntEnum
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from scripts.ai.ptcgdap.marnie_prompt_broker import MarniePromptBroker, PROFILE_ID


ROOT = Path(__file__).resolve().parents[2]
AUDIT = json.loads(
    (ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json").read_text(encoding="utf-8")
)


class HostCapability:
    pass


class ExactIntTrap(IntEnum):
    VALUE = 8


class StringTrap(str):
    pass


def _window(frame: dict[str, object], mutation=None):
    document = deepcopy(frame["window"])
    if mutation is not None:
        mutation(document)
    select = {
        "type": document["select_type_raw"], "context": document["select_context_raw"],
        "minCount": document["min_count"], "maxCount": document["max_count"],
        "remainDamageCounter": document["remain_damage_counter"],
        "remainEnergyCost": document["remain_energy_cost"],
        "option": document["options"], "deck": document["public_deck_candidates"],
        "contextCard": document["context_card"], "effect": document["effect"],
    }
    built = CabtSelectionWindow.build(
        select,
        public_observation_hash=document["public_observation_hash"],
        public_hash_authority=document["public_hash_authority"],
        chooser_player_index=document["chooser_player_index"],
    )
    if not built.accepted or built.window is None:
        raise AssertionError(built.to_public_dict())
    return built.window


def _published(frame: dict[str, object]):
    source = deepcopy(frame["source"])
    port = EngineDecisionPort(1)
    result = port.publish_p5_extended(source, frame["ordinal"], 0, PROFILE_ID)
    if not result.accepted or result.snapshot is None:
        raise AssertionError(result.error_code)
    return source, port, result.snapshot


class MarniePromptBrokerPropertyTests(unittest.TestCase):
    def test_repeated_full_evaluation_is_deterministic_and_every_index_is_current_window_legal(self) -> None:
        first = MarniePromptBroker.load_default().evaluate_all().to_public_dict()
        second = MarniePromptBroker.load_default().evaluate_all().to_public_dict()
        self.assertEqual(first, second)
        audit_frames = {frame["frame_id"]: frame for frame in AUDIT["frames"]}
        for frame in first["frames"]:
            with self.subTest(frame=frame["frame_id"]):
                expected = audit_frames[frame["frame_id"]]
                self.assertEqual(expected["option_types"], frame["option_types"])
                indexes = frame["selected_indexes"]
                if indexes is not None:
                    self.assertEqual(len(indexes), len(set(indexes)))
                    self.assertTrue(all(type(index) is int and 0 <= index < frame["option_count"] for index in indexes))

    def test_p5_extension_is_opt_in_exact_and_source_drift_is_atomic(self) -> None:
        frame = AUDIT["frames"][3]
        source = deepcopy(frame["source"])
        default_port = EngineDecisionPort(1)
        self.assertFalse(default_port.publish(source, 1, 0).accepted)

        wrong_profile = EngineDecisionPort(1).publish_p5_extended(source, 1, 0, StringTrap(PROFILE_ID))
        self.assertFalse(wrong_profile.accepted)
        self.assertEqual("invalid_decision_source", wrong_profile.error_code)

        enum_source = deepcopy(source)
        enum_source["select"]["option"][0]["type"] = ExactIntTrap.VALUE
        enum_result = EngineDecisionPort(1).publish_p5_extended(enum_source, 1, 0, PROFILE_ID)
        self.assertFalse(enum_result.accepted)

        source, port, snapshot = _published(frame)
        changed = deepcopy(source)
        changed["select"]["option"][0]["inPlayIndex"] += 1
        self.assertEqual("source_mutated", port.rebind(snapshot, changed)["error_code"])

    def test_reorder_attack_id_drift_wrong_profile_and_stale_window_are_rejected(self) -> None:
        cases = (
            (AUDIT["frames"][3], lambda value: value["options"].reverse()),
            (AUDIT["frames"][8], lambda value: value["options"][1].__setitem__("attackId", 938)),
        )
        for frame, mutation in cases:
            with self.subTest(frame=frame["frame_id"]):
                source, port, snapshot = _published(frame)
                window = _window(frame)
                commands = [HostCapability() for _ in range(window.option_count)]
                owner = GodotOptionBinding()
                bound = owner.bind_p5_extended(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=frame["callback_binding_hash"], private_commands=commands,
                    private_object_refs=[[] for _ in commands], extension_profile_id=PROFILE_ID,
                )
                self.assertTrue(bound.accepted, bound.error_code)
                stale_copy = _window(frame)
                self.assertEqual(
                    "window_mismatch",
                    owner.resolve(
                        binding=bound.binding, port=port, snapshot=snapshot, current_source=source,
                        window=stale_copy, callback_binding_hash=frame["callback_binding_hash"], option_index=0,
                    ).error_code,
                )

                drifted = _window(frame, mutation)
                drift_owner = GodotOptionBinding()
                rejected = drift_owner.bind_p5_extended(
                    port=port, snapshot=snapshot, current_source=source, window=drifted,
                    callback_binding_hash=frame["callback_binding_hash"], private_commands=commands,
                    private_object_refs=[[] for _ in commands], extension_profile_id=PROFILE_ID,
                )
                self.assertFalse(rejected.accepted)
                self.assertEqual("window_mismatch", rejected.error_code)

                wrong = GodotOptionBinding().bind_p5_extended(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=frame["callback_binding_hash"], private_commands=commands,
                    private_object_refs=[[] for _ in commands], extension_profile_id=StringTrap(PROFILE_ID),
                )
                self.assertFalse(wrong.accepted)
                self.assertEqual("window_mismatch", wrong.error_code)

    def test_bool_enum_and_string_subclasses_do_not_cross_public_runner_types(self) -> None:
        owner = MarniePromptBroker.load_default()
        expected = {"ok": False, "error_code": "input_type_invalid", "value": None}
        self.assertEqual(expected, owner.run(StringTrap("evaluate_all"), None))
        self.assertEqual(expected, owner.run("evaluate_frame", StringTrap("w3_main")))
        self.assertEqual(expected, owner.run(True, None))
        self.assertEqual(expected, owner.run(ExactIntTrap.VALUE, None))


if __name__ == "__main__":
    unittest.main()
