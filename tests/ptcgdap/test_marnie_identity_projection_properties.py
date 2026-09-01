from __future__ import annotations

from copy import deepcopy
import random
import unittest

from scripts.ai.ptcgdap.marnie_identity_projection import MarnieIdentityProjection


class MarnieIdentityProjectionPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.runtime = MarnieIdentityProjection.load_default()

    def test_seeded_frame_order_and_repeated_reads_are_deterministic(self) -> None:
        baseline = self.runtime.audit_all()
        frames = baseline["value"]["frames"]
        rng = random.Random(0x50575034)
        order = list(range(len(frames)))
        for _ in range(12):
            rng.shuffle(order)
            for index in order:
                result = self.runtime.audit_frame(frames[index]["frame_id"])
                self.assertTrue(result["ok"])
                self.assertEqual([frames[index]], result["value"]["frames"])
        self.assertEqual(baseline, self.runtime.audit_all())

    def test_every_public_frame_has_closed_identity_partitions_and_relations(self) -> None:
        value = self.runtime.audit_all()["value"]
        union = set()
        for frame in value["frames"]:
            ids = set(frame["distinct_official_card_ids"])
            mapped = set(frame["mapped_official_card_ids"])
            unmapped = set(frame["known_unmapped_official_card_ids"])
            self.assertFalse(mapped & unmapped)
            self.assertEqual(ids, mapped | unmapped)
            self.assertTrue(frame["serial_relation_consistent"])
            self.assertTrue(frame["top_serial_distinct_from_pre_evolution"])
            self.assertTrue(frame["hidden_identity_absent"])
            self.assertTrue(frame["host_entity_absent"])
            union.update(ids)
        self.assertEqual(set(value["summary"]["distinct_official_card_ids"]), union)

    def test_mutation_probe_is_atomic_and_cannot_change_baseline(self) -> None:
        baseline = self.runtime.audit_all()
        for mutation in [
            "card_unknown", "serial_relation_conflict", "player_index_invalid",
            "attack_unknown", "attack_owner_mismatch", "hidden_private_key",
            "host_entity_key",
        ]:
            result = self.runtime.run("probe_frame_mutation", {"frame_id": "w6_shadow_bullet_target", "mutation": mutation})
            self.assertFalse(result["ok"])
            self.assertIsNone(result["value"])
        self.assertEqual(baseline, self.runtime.audit_all())


if __name__ == "__main__":
    unittest.main()
