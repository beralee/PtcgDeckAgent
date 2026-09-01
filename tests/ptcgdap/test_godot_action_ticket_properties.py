from __future__ import annotations

from enum import IntEnum
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer
from scripts.ai.ptcgdap.godot_action_ticket import GodotActionTicketOwner
from tests.ptcgdap.test_godot_action_ticket import claim, issue, ticket_context


class _One(IntEnum):
    VALUE = 1


class _Session(str):
    pass


class GodotActionTicketPropertyTests(unittest.TestCase):
    def test_ordered_selections_preserve_exact_command_identity(self) -> None:
        for indexes in ([0], [1], [1, 0], [0, 1]):
            with self.subTest(indexes=indexes):
                ctx = ticket_context()
                ctx["resolution"] = CabtSelectionSanitizer.resolve_policy_attempt(ctx["window"], indexes)
                self.assertTrue(ctx["resolution"].validate_integrity(ctx["window"]))
                owner = GodotActionTicketOwner()
                issued = issue(owner, ctx)
                self.assertTrue(issued.accepted, issued.to_public_dict())
                self.assertEqual(list(issued.ticket.selected_indexes), indexes)
                claimed = claim(owner, issued.ticket, ctx)
                self.assertTrue(claimed.accepted, claimed.to_public_dict())
                self.assertEqual(
                    [resolution.option_index for resolution in claimed.binding_resolutions],
                    indexes,
                )
                for resolution, index in zip(claimed.binding_resolutions, indexes, strict=True):
                    self.assertIs(resolution.private_engine_command, ctx["commands"][index])

    def test_exact_host_types_fail_closed_without_consuming_authority(self) -> None:
        cases = (
            ({"session_id": _Session("session:fixture")}, "invalid_session_id"),
            ({"public_observation_hash": _Session("A" * 64)}, "invalid_public_observation_hash"),
            ({"callback_binding_hash": _Session("A" * 64)}, "invalid_callback_binding_hash"),
        )
        for overrides, code in cases:
            with self.subTest(code=code):
                ctx = ticket_context()
                owner = GodotActionTicketOwner()
                rejected = issue(owner, ctx, **overrides)
                self.assertFalse(rejected.accepted)
                self.assertEqual(rejected.error_code, code)
                self.assertIsNone(owner.current_ticket())
                accepted = issue(owner, ctx)
                self.assertTrue(accepted.accepted, accepted.to_public_dict())

        ctx = ticket_context()
        owner = GodotActionTicketOwner()
        owner._next_generation = _One.VALUE
        self.assertFalse(owner.validate_integrity())
        self.assertEqual(issue(owner, ctx).error_code, "ticket_integrity_invalid")

    def test_ticket_never_rebinds_to_equivalent_or_foreign_context(self) -> None:
        first = ticket_context()
        first_owner = GodotActionTicketOwner()
        issued = issue(first_owner, first)
        self.assertTrue(issued.accepted)

        equivalent = ticket_context()
        foreign = claim(
            first_owner,
            issued.ticket,
            equivalent,
            session_id=first["session_id"],
            public_observation_hash=first["public_hash"],
            callback_binding_hash=first["callback_hash"],
        )
        self.assertFalse(foreign.accepted)
        self.assertEqual(foreign.error_code, "binding_not_current")
        self.assertIsNone(first_owner.current_ticket())
        self.assertEqual(claim(first_owner, issued.ticket, first).error_code, "ticket_revoked")

        other_owner = GodotActionTicketOwner()
        copied = claim(other_owner, issued.ticket, first)
        self.assertFalse(copied.accepted)
        self.assertEqual(copied.error_code, "owner_mismatch")

        object.__setattr__(issued.ticket, "selected_indexes", (1,))
        self.assertFalse(issued.ticket.validate_integrity(first_owner))
        self.assertEqual(issued.ticket.to_public_dict(), {})
        self.assertEqual(claim(first_owner, issued.ticket, first).error_code, "ticket_integrity_invalid")


if __name__ == "__main__":
    unittest.main()
