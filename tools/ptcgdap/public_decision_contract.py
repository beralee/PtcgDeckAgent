"""Audited API extension and authored cross-runtime decision probes."""
import copy

from scripts.ai.ptcgdap.public_decision_facts import DECISION_SCHEMA, DECISION_FACT_TYPES


def decision_fixture(option, frame):
    value = frame([option(0, kind='switch', target_entity_serial=10),
                   option(1, kind='switch', target_entity_serial=11)], 'switch', 1, 1)
    entities = []
    for slot in value['public_state']['self']['active'] + value['public_state']['self']['bench']:
        slot['entity_serial'] = slot['serial']
        energies = [{'serial': 100+i, 'local_card_uid': uid, 'units': 1, 'types': ['P']}
                    for i, uid in enumerate(slot['attached_energy_uids'])]
        entities.append({
            'entity_serial': slot['serial'], 'played_this_turn': False, 'evolved_this_turn': False,
            'conditions': [], 'effective_retreat_cost': 1, 'retreat_energy_units': len(energies),
            'retreat_energy_ready': len(energies) >= 1, 'tool_effect_suppressed': False,
            'ability_disabled': False, 'early_evolution_allowed': False,
            'ability_use_recorded_this_turn': False, 'energies': energies,
            'attacks': [
                {'attack_index': 0, 'source_uid': slot['local_card_uid'], 'cost_candidates': [''], 'energy_debt': 0, 'energy_ready': True},
                {'attack_index': 1, 'source_uid': slot['local_card_uid'], 'cost_candidates': ['RP'], 'energy_debt': 1, 'energy_ready': False},
            ],
        })
    side = {'is_first_turn': False, 'vstar_used': False, 'knocked_out_previous_opponent_turn': False,
            'bench_capacity': 5, 'lost_zone': []}
    value['public_state']['decision'] = {
        'version': 1, 'current_player_index': 0, 'first_player_index': 1,
        'stadium': {'card_uid': None, 'owner_index': None},
        'turn': {'stadium_play_available': True, 'stadium_effect_used': False},
        'selection': {'remaining_energy_cost': None, 'remaining_damage_counters': None,
                      'max_assignments': None, 'max_assignments_per_target': None, 'allow_partial': None},
        'self': copy.deepcopy(side), 'opponent': copy.deepcopy(side), 'entities': entities,
    }
    return value


def decision_cases(sample_policy, option, frame):
    value = decision_fixture(option, frame)
    policy = sample_policy()
    policy['count_rules'] = []
    goal = policy['goals'][0]['goal_id']
    condition = lambda fact, op, v: {'fact': fact, 'op': op, 'value': v, 'card_uid': None}
    rule = lambda name, score, when: {
        'rule_id': name, 'goal_id': goal, 'goal_stage': 'execute', 'channel': 'interaction',
        'horizon': 0, 'confidence_milli': 1000, 'base_score': score, 'when': when, 'score_terms': [],
    }
    policy['rules'] = [
        rule('decision.fallback', 100, [condition('option.target_entity_serial', 'eq', 11)]),
        rule('decision.main-attack', 200, [condition('option.target_entity_serial', 'eq', 10),
             condition('decision.option.target.attack.1.energy_ready', 'eq', True),
             condition('decision.option.target.evolved_this_turn', 'eq', False),
             condition('decision.option.target.conditions', 'not_contains', 'asleep')]),
    ]
    cases = []
    def add(name, f, indexes=None, error=''):
        cases.append({'case_id': 'public-decision-' + name, 'operation': 'decide',
                      'policy': copy.deepcopy(policy), 'allowed_card_uids': ['SVI_003', 'M2_001', 'M2_002'],
                      'frame': copy.deepcopy(f), 'expected': {'accepted': not error, 'error_code': error,
                       'selected_indexes': indexes or []}})
    add('cheap-attack-is-not-main-ready', value, [1])
    ready = copy.deepcopy(value)
    ready['public_state']['decision']['entities'][0]['attacks'][1].update(energy_debt=0, energy_ready=True)
    add('main-cost-paid-flip', ready, [0])
    for name, key, v in [('evolved', 'evolved_this_turn', True), ('asleep', 'conditions', ['asleep'])]:
        changed = copy.deepcopy(ready)
        changed['public_state']['decision']['entities'][0][key] = v
        add(name + '-flip', changed, [1])
    reordered = copy.deepcopy(ready)
    reordered['options'].reverse()
    for i, opt in enumerate(reordered['options']):
        opt['index'] = i
    reordered['public_state']['decision']['entities'].reverse()
    add('reordered-identity-join', reordered, [1])
    absent = copy.deepcopy(ready)
    del absent['public_state']['decision']
    add('legacy-unknown', absent, [1])
    wrong_target = copy.deepcopy(ready)
    wrong_target['options'][0]['target_entity_serial'] = 100
    add('absent-target-unknown', wrong_target, [1])
    missing_attack = copy.deepcopy(ready)
    missing_attack['public_state']['decision']['entities'][0]['attacks'].pop()
    add('absent-attack-unknown', missing_attack, [1])
    for name, mutate in [
        ('unknown-field', lambda e: e.update(winner_prediction=True)),
        ('version', lambda e: e.update(version=2)),
        ('bool-integer', lambda e: e.update(current_player_index=True)),
        ('unknown-condition', lambda e: e['entities'][0].update(conditions=['frozen'])),
        ('unknown-energy-type', lambda e: e['entities'][0]['energies'][0].update(types=['FAKE'])),
        ('unknown-uid', lambda e: e['entities'][0]['attacks'][0].update(source_uid='bad')),
        ('wrong-attack-source', lambda e: e['entities'][0]['attacks'][0].update(source_uid='M2_002')),
        ('energy-count', lambda e: e['entities'][0].update(energies=[])),
        ('duplicate-entity', lambda e: e['entities'].append(copy.deepcopy(e['entities'][0]))),
        ('missing-entity', lambda e: e['entities'].pop()),
        ('retreat-debt', lambda e: e['entities'][0].update(retreat_energy_ready=False)),
        ('attack-debt', lambda e: e['entities'][0]['attacks'][1].update(energy_debt=1)),
        ('negative-budget', lambda e: e['selection'].update(remaining_energy_cost=-1)),
        ('budget-type', lambda e: e['selection'].update(remaining_energy_cost=True)),
    ]:
        invalid = copy.deepcopy(ready)
        mutate(invalid['public_state']['decision'])
        add(name, invalid, error='invalid_public_frame')
    hidden = copy.deepcopy(ready)
    hidden['public_state']['decision']['opponent']['deck_order'] = ['M2_001']
    add('hidden-data', hidden, error='private_or_runtime_frame')
    return cases


def counter_plan_cases(sample_policy, option, frame):
    """The same authored allocation decisions run in Python and GDScript."""
    policy = sample_policy()
    policy['count_rules'] = []
    policy['rules'] = [{
        'rule_id': 'counter.plan', 'goal_id': policy['goals'][0]['goal_id'],
        'goal_stage': 'execute', 'channel': 'interaction', 'horizon': 0,
        'confidence_milli': 1000, 'base_score': 500,
        'when': [{'fact':'decision.option.counter_prize_plan','op':'gt','value':0,'card_uid':None}],
        'score_terms': [{'fact':'decision.option.counter_prize_plan','coefficient':10,'minimum':0,'maximum':6}],
    }]
    cases=[]
    for name,hps,prizes,budget,pending,expected in [
        ('three-before-two',[20,20,20,60],[1,1,1,2],6,[0,0,0,0],[0]),
        ('already-paid',[20,40],[1,1],4,[2,0],[1]),
        ('budget-three',[21,30],[1,2],3,[0,0],[1]),
        ('budget-two',[21,30],[1,2],2,[0,0],[0]),
    ]:
        f=frame([option(i,kind='assignment_source',card_uid='M2_002',target_uid='M2_002',
            target_entity_serial=51+i,target_remaining_hp=hp,target_prize_value=prizes[i],
            target_pending_damage_counters=pending[i],remaining_damage_counters=budget)
            for i,hp in enumerate(hps)],'assignment_source',1,1,select_context_raw=14)
        sample=copy.deepcopy(f['public_state']['self']['bench'][0])
        f['public_state']['opponent']['bench']=[]
        for i,hp in enumerate(hps):
            s=copy.deepcopy(sample);s.update(serial=51+i,entity_serial=51+i,local_card_uid='M2_002',
                remaining_hp=hp,max_hp=hp,damage_counters=0,prize_value=prizes[i])
            f['public_state']['opponent']['bench'].append(s)
        for reverse in ([False] if name=='three-before-two' else [False,True]):
            g=copy.deepcopy(f);selected=expected
            if reverse:
                g['options'].reverse()
                for i,o in enumerate(g['options']):o['index']=i
                selected=[len(hps)-1-i for i in expected]
            cases.append(dict(case_id='public-counter-plan-'+name+('-reorder' if reverse else ''),
                operation='decide',policy=copy.deepcopy(policy),allowed_card_uids=['SVI_003','M2_001','M2_002'],
                frame=g,expected=dict(accepted=True,error_code='',selected_indexes=selected)))
    return cases


def extend_decision_contract(documents, sample_policy, option, frame):
    documents['schema']['$defs']['public_frame']['properties']['public_state']['properties']['decision'] = copy.deepcopy(DECISION_SCHEMA)
    documents['profile']['public_decision_api'] = {
        'version': 1, 'optional_legacy_compatible': True,
        'facts': DECISION_FACT_TYPES,
        'unknown': 'Absent extension, entity, attack or selection budget returns null; never infer zero/false.',
        'attack_scope': 'Current printed attacks, effective cost-only readiness; no prospective legality or damage guarantee.',
        'authority': 'Only the current immutable options authorize actions; reobserve and rebind after each choice.',
    }
    documents['vectors']['cases'].extend(decision_cases(sample_policy, option, frame))
    documents['vectors']['cases'].extend(counter_plan_cases(sample_policy, option, frame))
