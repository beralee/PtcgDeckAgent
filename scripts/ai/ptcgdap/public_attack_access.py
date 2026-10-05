"""Bounded public-state planning. Future steps are conditional, never authority.

The first edge is a current legal option. Subsequent edges pay exact modeled
resources on the same entity, and are rebound after every actual commit. No
draws, hidden state, engine clone, persistent indexes, or win claims are used.
"""
from __future__ import annotations
import copy
import json
from pathlib import Path

CATALOG_PATH = Path(__file__).resolve().parents[3] / 'contracts/ptcgdap/public_attack_access_catalog_v1.json'
_CATALOG = None


def catalog():
    global _CATALOG
    if _CATALOG is None:
        _CATALOG = json.loads(CATALOG_PATH.read_bytes())['cards']
    return _CATALOG


def energy_debt(costs, energies):
    """Maximum bipartite matching: one physical unit pays only one symbol."""
    units = [e['types'] for e in energies for _ in range(min(e['units'], 32))]
    best = 32
    for cost in costs:
        symbols = sorted(cost, key=lambda s: s == 'C')
        paid = [-1] * len(units)
        def match(i, visited):
            for j, types in enumerate(units):
                if j in visited or not (symbols[i] == 'C' or symbols[i] in types or 'ANY' in types): continue
                visited.add(j)
                if paid[j] < 0 or match(paid[j], visited):
                    paid[j] = i
                    return True
            return False
        matched = sum(match(i, set()) for i in range(len(symbols)))
        best = min(best, len(symbols) - matched)
    return best


def _pressure(entity, cards):
    if any(s in entity['conditions'] for s in ('asleep', 'paralyzed')): return 0
    return max((a['pressure'] for a in cards.get(entity['uid'], {}).get('attacks', [])
        if a['index'] in entity['costs'] and energy_debt(entity['costs'][a['index']], entity['energies']) == 0), default=0)


def _resupply(entity, cards):
    """Recompute only audited energy kinds after attachment/evolution.

    Unknown special energy effects fail closed; ordinary unchanged public
    energy supplies remain usable for a route without resupply operations.
    """
    energies = entity['energies']
    models = [cards.get(e['local_card_uid'], {}).get('energy_model') for e in energies]
    if any(m not in ('basic', 'luminous', 'neo_upper') for m in models): return False
    special = sum(m != 'basic' for m in models)
    for e, model in zip(energies, models):
        e['units'] = 2 if model == 'neo_upper' and cards[entity['uid']]['stage'] == 2 else 1
        e['types'] = [cards[e['local_card_uid']]['energy_type']] if model == 'basic' else [
            'ANY' if (model == 'luminous' and special == 1) or (model == 'neo_upper' and e['units'] == 2) else 'C']
    return True


def _investment(entity, cards):
    c = cards.get(entity['uid'], {})
    return 30 * len(entity['energies']) + 45 * max(0, c.get('stage', 0)) + 20 * int(c.get('engine', False))


def _state(frame, cards):
    public = frame['public_state']; own = public['self']; decision = public['decision']
    table = {e['entity_serial']: e for e in decision['entities']}
    board = {}
    for slot in own['active'] + own['bench']:
        uid = slot['local_card_uid']; identity = slot['entity_serial']
        if uid not in cards or identity not in table: continue
        e = table[identity]
        if slot['remaining_hp'] <= 0: continue
        board[identity] = dict(uid=uid, hp=slot['remaining_hp'], prize=slot['prize_value'],
            energies=copy.deepcopy(e['energies']), conditions=list(e['conditions']),
            retreat=e['effective_retreat_cost'], played=e['played_this_turn'], evolved=e['evolved_this_turn'],
            early=e['early_evolution_allowed'], costs={a['attack_index']: a['cost_candidates'] for a in e['attacks']})
    active = own['active'][0]['entity_serial'] if own['active'] else None
    current_pressure = 0
    if active in board:
        for o in frame['options']:
            if o['kind'] == 'attack' and o.get('source_uid') == board[active]['uid']:
                current_pressure = max(current_pressure, max((a['pressure'] for a in cards[board[active]['uid']]['attacks']
                    if a['index'] == o.get('attack_index')), default=0))
    return dict(board=board, active=active, current_pressure=current_pressure, hand=copy.deepcopy(own['hand']),
        attach=own['turn']['manual_attachment_available'], retreat=own['turn']['retreat_available'],
        manual=0, retreat_count=0, spent=0, steps=[])


def _actions(state, cards):
    actions = []
    potential = {i: _potential(e, state['hand'], cards) for i, e in state['board'].items()}
    for h in sorted(state['hand'], key=lambda h: h['serial']):
        card = cards.get(h['local_card_uid'], {})
        for identity, entity in sorted(state['board'].items()):
            if state['attach'] and card.get('energy_model') and (identity == state['active'] or potential[identity] >= 150):
                actions.append(dict(kind='attach_energy', card_serial=h['serial'], card_uid=h['local_card_uid'], target=identity))
            if (not entity['played'] and not entity['evolved'] and card.get('from')
                    and card['from'] == cards[entity['uid']]['name']
                    and card['stage'] == cards[entity['uid']]['stage'] + 1
                    and max((a['pressure'] for a in card['attacks']), default=0) >= 150):
                actions.append(dict(kind='evolve', card_serial=h['serial'], card_uid=h['local_card_uid'], target=identity))
    active = state['board'].get(state['active'])
    if active and state['retreat'] and not any(s in active['conditions'] for s in ('asleep', 'paralyzed')):
        for identity in sorted(state['board']):
            if identity != state['active'] and potential[identity] >= 150:
                actions.append(dict(kind='retreat', target=identity))
    return actions


def _potential(entity, hand, cards):
    printed = cards.get(entity['uid'], {})
    value = max((a['pressure'] for a in printed.get('attacks', [])), default=0)
    if not entity['played'] and not entity['evolved']:
        for h in hand:
            c = cards.get(h['local_card_uid'], {})
            if c.get('from') and c['from'] == printed.get('name'):
                value = max(value, max((a['pressure'] for a in c['attacks']), default=0))
    return value


def _apply(state, action, cards):
    new = copy.deepcopy(state); kind = action['kind']; target = new['board'].get(action['target'])
    if target is None: return None
    if kind in ('attach_energy', 'evolve'):
        if not any(h['serial'] == action['card_serial'] and h['local_card_uid'] == action['card_uid'] for h in new['hand']): return None
        observed = copy.deepcopy(target['energies'])
        if not _resupply(target, cards) or target['energies'] != observed:
            return None  # An unmodeled supply modifier is already active.
        if kind == 'attach_energy':
            if not new['attach']: return None
            target['energies'].append(dict(serial=action['card_serial'], local_card_uid=action['card_uid'], units=1, types=['C']))
            new['attach'] = False; new['manual'] += 1; new['spent'] += 1
        else:
            card = cards[action['card_uid']]
            if target['played'] or target['evolved'] or card['from'] != cards[target['uid']]['name']: return None
            old = cards[target['uid']]
            target['hp'] += card['hp'] - old['hp']; target['uid'] = action['card_uid']
            target['evolved'] = True; target['conditions'] = []
            target['costs'] = {a['index']: [a['cost']] for a in card['attacks']}
            # Preserve the observed retreat modifier (e.g. board ability),
            # while tracking the printed cost change as a conditional model.
            target['retreat'] = max(0, target['retreat'] + card['retreat'] - old['retreat'])
            new['spent'] += 1
        if not _resupply(target, cards): return None
        new['hand'] = [h for h in new['hand'] if h['serial'] != action['card_serial']]
    elif kind == 'retreat':
        active = new['board'].get(new['active'])
        if (not active or not new['retreat'] or new['active'] == action['target']
                or any(s in active['conditions'] for s in ('asleep', 'paralyzed'))): return None
        energies = active['energies']; cost = active['retreat']
        if len(energies) > 8: return None
        choices = []
        for mask in range(1 << len(energies)):
            selected = [e for i, e in enumerate(energies) if mask & (1 << i)]
            units = sum(e['units'] for e in selected)
            if units >= cost:
                choices.append((len(selected), units, tuple(sorted(e['serial'] for e in selected)), mask))
        if not choices: return None
        count, units, serials, mask = min(choices)
        active['energies'] = [e for i, e in enumerate(energies) if not mask & (1 << i)]
        if not _resupply(active, cards): return None
        active['conditions'] = []; new['active'] = action['target']; new['retreat'] = False
        new['retreat_count'] += 1; new['spent'] += count + 1
        action = dict(action, discarded_energy_serials=list(serials))
    else: return None
    new['steps'].append(action)
    return new


def _first_actions(frame, state, cards):
    for action in _actions(state, cards):
        for o in frame['options']:
            if o['kind'] != action['kind']: continue
            if action['kind'] == 'retreat':
                if o.get('target_entity_serial') == action['target']:
                    yield o['index'], action
            elif (o.get('card_serial') == action['card_serial'] and o.get('card_uid') == action['card_uid']
                    and o.get('target_entity_serial') == action['target']):
                yield o['index'], action


def _value(state, cards):
    pressure = _pressure(state['board'][state['active']], cards)
    successor = max((_pressure(e, cards) for i, e in state['board'].items() if i != state['active']), default=0)
    reserved = sum(_investment(e, cards) for i, e in state['board'].items() if i != state['active'])
    return pressure, successor, reserved


def _plan(row, initial, first, cards):
    pressure, successor, reserve = _value(row, cards)
    if pressure < 150: return None
    base = initial['current_pressure']
    if (row['active'] == initial['active'] and row['board'][row['active']]['uid'] == initial['board'][initial['active']]['uid']
            and base == 0 and _pressure(initial['board'][initial['active']], cards) > 0):
        return None  # Already paid but no legal attack: an unrelated payment is not a cure.
    if pressure <= base: return None
    # Retaining a ready successor and investment breaks equal attack-pressure
    # ties. These are ordinal features, never a probability of survival.
    return dict(first_index=first, attacker_entity_serial=row['active'], steps=row['steps'],
        pressure=pressure, attack_gain=pressure-base, successor_pressure=successor,
        reserve_value=reserve, resource_cost=row['spent'], manual_attachments=row['manual'],
        retreats=row['retreat_count'], conditional_future=True,
        assumptions=['future_window_legality', 'attack_effects_and_opponent_response_unresolved'],
        score=[pressure, successor, -row['spent'], reserve, -len(row['steps'])])


def plan_attack_access(frame, *, cards=None, validated=False):
    """Read-only planner for a VALIDATED public frame; bounded to three edges."""
    from .competitive_policy_v2 import _frame_error
    if type(frame) is not dict:
        return dict(accepted=False, reason='unqualified_public_position', plans=[])
    if (not validated and _frame_error(frame)) or not frame.get('public_state', {}).get('decision'):
        return dict(accepted=False, reason='unqualified_public_position', plans=[])
    if frame['prompt_kind'] != 'main':
        return dict(accepted=False, reason='unsupported_planning_window', plans=[])
    cards = catalog() if cards is None else cards
    checkpoints = []
    own_board = {s['entity_serial']: s['local_card_uid'] for zone in ('active','bench')
                 for s in frame['public_state']['self'][zone]}
    if frame['public_state']['self']['deck_count'] > 0:
        for option in frame['options']:
            if (option['kind'] == 'use_ability' and option.get('source_entity_serial') in own_board
                    and own_board[option['source_entity_serial']] == option.get('source_uid')
                    and frame['public_state']['self']['deck_count'] >= cards.get(option.get('source_uid'), {}).get('information_minimum_deck_count', 0)
                    and option.get('ability_index') in
                    cards.get(option.get('source_uid'), {}).get('information_abilities', [])):
                checkpoints.append(dict(entity_serial=option.get('source_entity_serial'),
                    source_uid=option['source_uid'], ability_index=option['ability_index']))
    if checkpoints:
        # Do not search through an unknown information result or erase a
        # beneficial pre-evolution ability. Base/old routes own the current
        # checkpoint, then this module rebuilds from the new actual hand.
        return dict(accepted=True, reason='information_checkpoint', plans=[], expanded=0,
            checkpoints=sorted(checkpoints,key=lambda r:(r['entity_serial'],r['ability_index'])),
            current_window_only=True, stale_plan_has_authority=False)
    initial = _state(frame, cards)
    if initial['active'] not in initial['board']:
        return dict(accepted=False, reason='unknown_active_capability', plans=[])
    ceiling = max((_potential(e, initial['hand'], cards) for e in initial['board'].values()), default=0)
    if ceiling < 150 or ceiling <= initial['current_pressure']:
        return dict(accepted=True, reason='', plans=[], expanded=0,
            current_window_only=True, stale_plan_has_authority=False)
    # No guessed opening-turn attack, and no revived stale public proof.
    d = frame['public_state']['decision']
    if d['self']['is_first_turn'] and d['current_player_index'] == d['first_player_index']:
        return dict(accepted=False, reason='first_player_attack_blocked', plans=[])
    best = {}; expanded = 0
    for first, action in _first_actions(frame, initial, cards):
        child = _apply(initial, action, cards)
        if child is None: continue
        queue = [child]
        while queue:
            state = queue.pop(); expanded += 1
            if expanded > 4096:
                return dict(accepted=False, reason='planning_budget_exceeded', plans=[], expanded=expanded)
            row = _plan(state, initial, first, cards)
            if row and (first not in best or row['score'] > best[first]['score']): best[first] = row
            if len(state['steps']) >= 3: continue
            for followup in _actions(state, cards):
                # No irrelevant investment after an attack is already unlocked;
                # preparation can be reconsidered on the next observed window.
                if row and followup['kind'] != 'evolve': continue
                next_state = _apply(state, followup, cards)
                if next_state: queue.append(next_state)
    return dict(accepted=True, reason='', plans=[best[i] for i in sorted(best)], expanded=expanded,
        current_window_only=True, stale_plan_has_authority=False)


def access_fact(frame, option, name):
    """Only a per-decision derived result may feed the author IR."""
    result = frame.get('_derived_access')
    if result is None: result = plan_attack_access(frame)
    if not result.get('accepted') or not option: return None
    rows = result['plans']; row = next((p for p in rows if p['first_index'] == option['index']), None)
    if row is None: return None
    if name == 'decision.option.access_gain': return row['attack_gain']
    if name == 'decision.option.access_pressure': return row['pressure']
    if name == 'decision.option.access_resource_cost': return row['resource_cost']
    if name == 'decision.option.access_best':
        return row['score'] == max(p['score'] for p in rows)
    return None


def uses_attack_access(value):
    if isinstance(value, dict):
        if str(value.get('fact', '')).startswith('decision.option.access_'): return True
        return any(uses_attack_access(child) for child in value.values() if isinstance(child, (dict, list)))
    if isinstance(value, list): return any(uses_attack_access(child) for child in value)
    return False
