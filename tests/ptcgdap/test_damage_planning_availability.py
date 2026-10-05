from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.competitive_policy_v2 import CompetitivePolicyV2Compiler, CompetitivePolicyV2Runtime
from scripts.ai.ptcgdap.public_damage_planning import PublicDamageCapabilityRegistry, PublicDamagePlanner, SemanticTransactionJournal

FIXTURE = Path(__file__).parents[1] / 'fixtures' / 'author_damage_catalog_gap.json'
# Never use a real printing as an unknown-card negative control.
UNKNOWN_UIDS = ('UNREGISTERED_001', 'UNREGISTERED_002', 'UNREGISTERED_003')


class DamagePlanningAvailabilityTests(unittest.TestCase):
    def setUp(self):
        self.spec = json.loads(FIXTURE.read_text(encoding='utf-8'))
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(self.spec['policy'], allowed_card_uids=set(self.spec['allowed_card_uids']))
        self.assertTrue(compiled.accepted, compiled.error_code)
        self.policy = compiled.policy

    def test_unknown_board_does_not_abort_independent_policy_rules(self):
        for side in ('self', 'opponent'):
            for uid in UNKNOWN_UIDS:
                with self.subTest(side=side, uid=uid):
                    frame = copy.deepcopy(self.spec['frame'])
                    frame['public_state'][side]['bench'][0]['local_card_uid'] = uid
                    result = CompetitivePolicyV2Runtime.decide(self.policy, frame)
                    self.assertTrue(result.accepted, result.error_code)
                    self.assertEqual([0], result.selected_indexes)
                    damage = result.audit['damage_plan']
                    self.assertEqual('unavailable', damage['status'])
                    self.assertEqual('unknown_damage_card_uid', damage['error_code'])
                    self.assertEqual({}, damage['facts'])
                    matches = [r['rule_id'] for s in result.audit['scorecards'] for r in s['matched_rules']]
                    self.assertIn('independent-attack', matches)
                    self.assertNotIn('unknown-ne-must-not-match', matches)
                    self.assertNotIn('unknown-score-must-not-match', matches)

    def test_unknown_damage_revokes_journal_and_recovers_next_known_window(self):
        frame = copy.deepcopy(self.spec['frame'])
        journal = SemanticTransactionJournal('availability', 0, 'package')
        known = CompetitivePolicyV2Runtime.decide(self.policy, frame, transaction_journal=journal)
        self.assertTrue(known.accepted, known.error_code)
        self.assertTrue(journal.snapshot())
        frame['public_state']['opponent']['bench'][0]['local_card_uid'] = UNKNOWN_UIDS[0]
        unknown = CompetitivePolicyV2Runtime.decide(self.policy, frame, transaction_journal=journal)
        self.assertTrue(unknown.accepted, unknown.error_code)
        self.assertEqual('abort', unknown.audit['semantic_transaction']['event'])
        self.assertEqual('unknown_damage_card_uid', unknown.audit['semantic_transaction']['reason'])
        self.assertEqual({}, unknown.audit['semantic_transaction']['state'])
        self.assertEqual({}, journal.snapshot())
        recovered = CompetitivePolicyV2Runtime.decide(self.policy, self.spec['frame'], transaction_journal=journal)
        self.assertTrue(recovered.accepted, recovered.error_code)
        self.assertTrue(recovered.audit['damage_plan']['facts'])
        self.assertEqual('start', recovered.audit['semantic_transaction']['event'])

    def test_base_guards_and_option_rebinding_still_apply(self):
        frame = copy.deepcopy(self.spec['frame'])
        frame['public_state']['opponent']['bench'][0]['local_card_uid'] = UNKNOWN_UIDS[0]
        for kwargs in ({'mandatory_indexes': [1]}, {'terminal_indexes': [1]}, {'base_vetoed_indexes': [0]}):
            decision = CompetitivePolicyV2Runtime.decide(self.policy, frame, **kwargs)
            self.assertTrue(decision.accepted, decision.error_code)
            self.assertEqual([1], decision.selected_indexes)
        frame['options'].reverse()
        for index, option in enumerate(frame['options']): option['index'] = index
        self.assertEqual([1], CompetitivePolicyV2Runtime.decide(self.policy, frame).selected_indexes)

    def test_damage_planner_and_private_input_still_fail_closed(self):
        frame = copy.deepcopy(self.spec['frame'])
        frame['public_state']['opponent']['bench'][0]['local_card_uid'] = UNKNOWN_UIDS[0]
        damage = PublicDamagePlanner.calculate(frame, self.spec['policy']['damage_plans'], PublicDamageCapabilityRegistry.load_default())
        self.assertFalse(damage['accepted'])
        self.assertEqual('unknown_damage_card_uid', damage['error_code'])
        frame['private_state'] = {'deck_order': ['SECRET_001']}
        self.assertFalse(CompetitivePolicyV2Runtime.decide(self.policy, frame).accepted)

    def test_unknown_active_or_bench_keeps_hard_tier_authority(self):
        for side in ('self', 'opponent'):
            for zone in ('active', 'bench'):
                for uid in UNKNOWN_UIDS:
                    with self.subTest(side=side, zone=zone, uid=uid):
                        frame = copy.deepcopy(self.spec['frame'])
                        frame['public_state'][side][zone][0]['local_card_uid'] = uid
                        decision = CompetitivePolicyV2Runtime.decide(self.policy, frame)
                        self.assertTrue(decision.accepted, decision.error_code)
                        self.assertEqual([0], decision.selected_indexes)
                        guarded = CompetitivePolicyV2Runtime.decide(self.policy, frame,
                            base_hard_tiers=[{'index': 0, 'tier': [1]}, {'index': 1, 'tier': [0]}])
                        self.assertTrue(guarded.accepted, guarded.error_code)
                        self.assertEqual([1], guarded.selected_indexes)

    def test_registered_printings_keep_damage_planning_available(self):
        registry = PublicDamageCapabilityRegistry.load_default()
        for side in ('self', 'opponent'):
            for zone in ('active', 'bench'):
                for uid in ('CSV6C_067', 'CSV6C_097'):
                    with self.subTest(side=side, zone=zone, uid=uid):
                        frame = copy.deepcopy(self.spec['frame'])
                        frame['public_state'][side][zone][0]['local_card_uid'] = uid
                        damage = PublicDamagePlanner.calculate(frame, self.spec['policy']['damage_plans'], registry)
                        self.assertTrue(damage['accepted'], damage['error_code'])
                        decision = CompetitivePolicyV2Runtime.decide(self.policy, frame)
                        self.assertTrue(decision.accepted, decision.error_code)
                        self.assertTrue(decision.audit['damage_plan']['facts'])


class ReviewedDamagePlanningAvailabilityTests(DamagePlanningAvailabilityTests):
    """Run the complete availability contract against the newer forecast mode."""

    def setUp(self):
        super().setUp()
        self.spec['policy']['damage_forecast_profile'] = 'reviewed-gust-v1'
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            self.spec['policy'], allowed_card_uids=set(self.spec['allowed_card_uids']))
        self.assertTrue(compiled.accepted, compiled.error_code)
        self.policy = compiled.policy


if __name__ == '__main__': unittest.main()
