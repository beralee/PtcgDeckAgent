"""Optional, closed, public decision facts. No engine, prediction or action authority.

An absent extension/row/attack/budget is unknown (None), never zero or false.
Printed-attack readiness is cost-only; legal execution is the current frontier.
"""
from __future__ import annotations

import re


def obj(properties):
    return {'type': 'object', 'additionalProperties': False,
            'required': list(properties), 'properties': properties}


def array(items, maximum=60):
    return {'type': 'array', 'items': items, 'maxItems': maximum}


def integer(maximum=9007199254740991, minimum=0):
    return {'type': 'integer', 'minimum': minimum, 'maximum': maximum}


BOOL = {'type': 'boolean'}
UID = {'type': 'string', 'pattern': r'^[A-Za-z0-9.]+_[A-Za-z0-9._]+$', 'minLength': 3, 'maxLength': 64}
CARD = obj({'serial': integer(), 'local_card_uid': UID})
ATTACK = obj({
    'attack_index': integer(31), 'source_uid': UID,
    'cost_candidates': array({'type': 'string', 'pattern': r'^[GWFRLPMDNYC]*$', 'maxLength': 32}, 256),
    'energy_debt': integer(32), 'energy_ready': BOOL,
})
ENERGY = obj({'serial': integer(), 'local_card_uid': UID, 'units': integer(60),
              'types': array({'type': 'string', 'enum': ['G', 'W', 'F', 'R', 'L', 'P', 'M', 'D', 'N', 'Y', 'C', 'ANY']}, 12)})
ENTITY = obj({
    'entity_serial': integer(minimum=1),
    'played_this_turn': BOOL, 'evolved_this_turn': BOOL,
    'conditions': array({'type': 'string', 'enum': ['poisoned', 'burned', 'asleep', 'paralyzed', 'confused']}, 5),
    'effective_retreat_cost': integer(60), 'retreat_energy_units': integer(3600),
    'retreat_energy_ready': BOOL, 'tool_effect_suppressed': BOOL, 'ability_disabled': BOOL,
    'early_evolution_allowed': BOOL, 'ability_use_recorded_this_turn': BOOL,
    'energies': array(ENERGY), 'attacks': array(ATTACK, 32),
})
SIDE = obj({'is_first_turn': BOOL, 'vstar_used': BOOL,
            'knocked_out_previous_opponent_turn': BOOL,
            'bench_capacity': integer(8), 'lost_zone': array(CARD)})
DECISION_SCHEMA = obj({
    'version': {'type': 'integer', 'const': 1},
    'current_player_index': integer(1), 'first_player_index': integer(1),
    'stadium': obj({'card_uid': {'anyOf': [UID, {'type': 'null'}]},
                    'owner_index': {'anyOf': [integer(1), {'type': 'null'}]}}),
    'turn': obj({'stadium_play_available': BOOL, 'stadium_effect_used': BOOL}),
    'selection': obj({
        **{key: {'anyOf': [integer(100), {'type': 'null'}]} for key in [
            'remaining_energy_cost', 'remaining_damage_counters',
            'max_assignments', 'max_assignments_per_target']},
        'allow_partial': {'anyOf': [BOOL, {'type': 'null'}]},
    }),
    'self': SIDE, 'opponent': SIDE, 'entities': array(ENTITY, 18),
})

# Explicit discoverable facts, shared by the author compiler and both evaluators.
DECISION_FACT_TYPES = {
    'decision.option.access_best': 'boolean',
    'decision.option.access_gain': 'integer',
    'decision.option.access_pressure': 'integer',
    'decision.option.access_resource_cost': 'integer',
    'decision.option.counter_prize_plan': 'integer',
    'decision.version': 'integer', 'decision.current_player_index': 'integer',
    'decision.first_player_index': 'integer', 'decision.stadium.card_uid': 'string',
    'decision.stadium.owner_index': 'integer', 'decision.turn.stadium_play_available': 'boolean',
    'decision.turn.stadium_effect_used': 'boolean',
    'decision.selection.remaining_energy_cost': 'integer',
    'decision.selection.remaining_damage_counters': 'integer',
    'decision.selection.max_assignments': 'integer',
    'decision.selection.max_assignments_per_target': 'integer',
    'decision.selection.allow_partial': 'boolean',
}
for _side in ['self', 'opponent']:
    for _key, _type in {'is_first_turn': 'boolean', 'vstar_used': 'boolean',
                        'knocked_out_previous_opponent_turn': 'boolean',
                        'bench_capacity': 'integer', 'lost_zone_count': 'integer',
                        'lost_zone_uids': 'array'}.items():
        DECISION_FACT_TYPES[f'decision.{_side}.{_key}'] = _type
for _ref in ['self.active', 'opponent.active', 'option.target', 'option.source']:
    for _key, _type in {'played_this_turn': 'boolean', 'evolved_this_turn': 'boolean',
                        'conditions': 'array', 'effective_retreat_cost': 'integer',
                        'retreat_energy_units': 'integer', 'retreat_energy_ready': 'boolean',
                        'tool_effect_suppressed': 'boolean', 'ability_disabled': 'boolean',
                        'early_evolution_allowed': 'boolean',
                        'ability_use_recorded_this_turn': 'boolean'}.items():
        DECISION_FACT_TYPES[f'decision.{_ref}.{_key}'] = _type
    # Index is a printed attack identity, not a stale option index. Full table is
    # available to SDK queries; eight slots cover the current reviewed catalog.
    for _index in range(8):
        for _key, _type in {'energy_debt': 'integer', 'energy_ready': 'boolean', 'cost_candidates': 'array'}.items():
            DECISION_FACT_TYPES[f'decision.{_ref}.attack.{_index}.{_key}'] = _type


def schema_error(value, schema):
    if 'anyOf' in schema:
        return all(schema_error(value, choice) for choice in schema['anyOf'])
    kind = schema['type']
    expected = {'object': dict, 'array': list, 'integer': int, 'boolean': bool, 'string': str, 'null': type(None)}[kind]
    if type(value) is not expected:
        return True
    if 'const' in schema and value != schema['const']:
        return True
    if 'enum' in schema and value not in schema['enum']:
        return True
    if kind == 'object':
        return set(value) != set(schema['properties']) or any(schema_error(value[k], s) for k, s in schema['properties'].items())
    if kind == 'array':
        return len(value) > schema['maxItems'] or any(schema_error(v, schema['items']) for v in value)
    if kind == 'integer':
        return not schema.get('minimum', 0) <= value <= schema.get('maximum', 9007199254740991)
    if kind == 'string':
        return (not schema.get('minLength', 0) <= len(value) <= schema.get('maxLength', 64)
                or ('pattern' in schema and re.fullmatch(schema['pattern'], value) is None))
    return False


def decision_error(state):
    """Validate the optional extension and public entity joins, fail closed."""
    if type(state) is not dict or 'decision' not in state:
        return False
    extension = state['decision']
    if schema_error(extension, DECISION_SCHEMA):
        return True
    board = {}
    for side in ['self', 'opponent']:
        public_side = state.get(side, {})
        if type(public_side) is not dict:
            return True
        for zone in ['active', 'bench']:
            if type(public_side.get(zone)) is not list:
                return True
            for slot in public_side[zone]:
                if type(slot) is not dict or type(slot.get('entity_serial')) is not int or slot['entity_serial'] in board:
                    return True
                board[slot['entity_serial']] = slot
    seen = set()
    for entity in extension['entities']:
        identity = entity['entity_serial']
        if identity in seen or identity not in board:
            return True
        seen.add(identity)
        slot = board[identity]
        if len(entity['energies']) != slot.get('attached_energy_count'):
            return True
        if [e['local_card_uid'] for e in entity['energies']] != slot.get('attached_energy_uids'):
            return True
        if len({e['serial'] for e in entity['energies']}) != len(entity['energies']):
            return True
        if len(set(entity['conditions'])) != len(entity['conditions']):
            return True
        if entity['retreat_energy_units'] != sum(e['units'] for e in entity['energies']):
            return True
        if entity['retreat_energy_ready'] != (entity['retreat_energy_units'] >= entity['effective_retreat_cost']):
            return True
        for i, attack in enumerate(entity['attacks']):
            if attack['attack_index'] != i or attack['source_uid'] != slot.get('local_card_uid') or not attack['cost_candidates']:
                return True
            if attack['energy_ready'] != (attack['energy_debt'] == 0):
                return True
    return seen != set(board)


def counter_prize_plan(frame):
    """Bounded subset search over published opponent counter targets (<=9).

    Maximize unclaimed prize arithmetic, then KO count, then save counters.
    Recompute after every assignment; never retain an index or assume effect
    prevention, future attacks, gust, or hidden cards. Missing/capped scopes
    are unknown. Leftovers concentrate on the lowest uncommitted HP.
    """
    semantics = frame.get('select_semantics', {})
    options = frame.get('options', [])
    if (semantics.get('select_type_raw') != 1 or semantics.get('select_context_raw') not in (13,14)
            or not 1 <= len(options) <= 9):
        return None
    budget = options[0].get('remaining_damage_counters')
    if type(budget) is not int or not 1 <= budget <= 6:
        return None
    state = frame.get('public_state', {})
    selection = state.get('decision', {}).get('selection', {})
    if selection.get('max_assignments_per_target') is not None:
        return None  # Distinct/capped allocation needs a different proof.
    board = {s.get('entity_serial'): s for zone in ('active','bench')
             for s in state.get('opponent', {}).get(zone, [])}
    rows = []
    seen = set()
    for o in options:
        identity = o.get('target_entity_serial')
        hp, prize, pending = (o.get(k) for k in
            ('target_remaining_hp','target_prize_value','target_pending_damage_counters'))
        s = board.get(identity, {})
        if (type(identity) is not int or identity <= 0 or identity in seen
                or any(type(v) is not int for v in (hp,prize,pending))
                or hp <= 0 or not 1 <= prize <= 3 or not 0 <= pending <= 6
                or o.get('remaining_damage_counters') != budget
                or s.get('local_card_uid') != o.get('target_uid')
                or s.get('remaining_hp') != hp or s.get('prize_value') != prize):
            return None
        seen.add(identity)
        residual = max(0,hp-10*pending)
        rows.append((identity,residual,prize,(residual+9)//10))
    rows.sort()
    best_key = (-1,-1,-100)
    allocation = [0]*len(rows)
    # Sorted identities plus strict improvement give an order-invariant tie.
    for mask in range(1 << len(rows)):
        cost = prizes = kos = 0
        for i,(_,hp,p,n) in enumerate(rows):
            if mask & (1 << i):
                if hp == 0:
                    cost = budget+1
                    break
                cost += n; prizes += p; kos += 1
        key = (prizes,kos,-cost)
        if cost <= budget and key > best_key:
            best_key = key
            allocation = [r[3] if mask & (1 << i) else 0 for i,r in enumerate(rows)]
    left = budget-sum(allocation)
    for i in sorted(range(len(rows)),key=lambda i:(rows[i][1],rows[i][0])):
        residual = rows[i][1]-10*allocation[i]
        if residual > 0:
            spend = min(left,(residual+9)//10)
            allocation[i] += spend; left -= spend
    if left:
        allocation[0] += left  # Every target is already lethal; mandatory pool.
    return {row[0]:allocation[i] for i,row in enumerate(rows)}


def decision_fact(frame, option, fact):
    if fact not in DECISION_FACT_TYPES:
        return None
    if fact.startswith('decision.option.access_'):
        from .public_attack_access import access_fact
        return access_fact(frame, option, fact)
    if fact == 'decision.option.counter_prize_plan':
        plan = counter_prize_plan(frame)
        return plan.get((option or {}).get('target_entity_serial')) if plan is not None else None
    state = frame.get('public_state', {})
    extension = state.get('decision')
    if extension is None:
        return None
    path = fact.split('.')[1:]
    if len(path) >= 3 and '.'.join(path[:2]) in ['self.active', 'opponent.active', 'option.target', 'option.source']:
        if path[0] == 'option':
            identity = (option or {}).get(path[1] + '_entity_serial')
        else:
            slots = state.get(path[0], {}).get('active', [])
            identity = slots[0].get('entity_serial') if slots else None
        entity = next((e for e in extension['entities'] if e['entity_serial'] == identity), None)
        if entity is None:
            return None
        path = path[2:]
        if path[0] == 'attack':
            attack = next((a for a in entity['attacks'] if a['attack_index'] == int(path[1])), None)
            return attack.get(path[2]) if attack is not None else None
        return entity.get(path[0])
    if len(path) == 2 and path[1] in ['lost_zone_count', 'lost_zone_uids']:
        cards = extension[path[0]]['lost_zone']
        return len(cards) if path[1] == 'lost_zone_count' else [c['local_card_uid'] for c in cards]
    value = extension
    for key in path:
        value = value.get(key) if isinstance(value, dict) else None
    return value
