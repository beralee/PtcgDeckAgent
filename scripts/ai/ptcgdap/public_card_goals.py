"""Public card-effect composition, with fresh binding at every real window.

The search is a proposal generator, not an engine or a learned win predictor.
Known resources are moved, never invented. Unknown draws stop at a checkpoint.
"""
from __future__ import annotations

import copy
import json
from functools import lru_cache

from . import public_attack_access as access

PROFILE = 'card-goals-v1'
STRETCHER = 'CSV8C_183'
CHOICE_SOURCES = {STRETCHER, '30thC_102', '30thC_101', 'CSV8C_158'}
MAX_DEPTH = 5
MAX_STATES = 384
MAX_TOTAL_STATES = 2048
BEAM = 12


@lru_cache(maxsize=1)
def goal_lines():
    cards = access.catalog()
    values = {u: max((a['pressure'] for a in c['attacks']), default=0) for u, c in cards.items()}
    for _ in range(3):
        by_name = {}
        for u, c in cards.items():
            if c.get('from'): by_name[c['from']] = max(by_name.get(c['from'], 0), values[u])
        values = {u: max(v, by_name.get(cards[u]['name'], 0)) for u, v in values.items()}
    return values


def recoverable(uid, cards):
    c = cards.get(uid, {})
    return c.get('stage', -1) >= 0 or c.get('energy_model') == 'basic'


def _state(frame, cards):
    state = access._state(frame, cards)
    state['discard'] = copy.deepcopy(frame['public_state']['self']['discard'])
    facts = {e['entity_serial']: e for e in frame['public_state']['decision']['entities']}
    for identity, entity in state['board'].items():
        entity['information_blocked'] = facts[identity]['ability_disabled']
    state['checkpoint'] = False
    state['evolution_turn_available'] = not frame['public_state']['decision']['self']['is_first_turn']
    return state


def features(state, cards):
    ready = engines = stages = funded = 0
    for e in state['board'].values():
        card = cards[e['uid']]
        engines += int(bool(card.get('information_abilities')) and not e.get('information_blocked', False))
        if goal_lines().get(e['uid'], 0) < 180: continue
        stages += max(0, card['stage'])
        ready += int(access._pressure(e, cards) >= 180)
        # Funding uses a concrete reviewed cost, without pretending the future
        # evolution is already held or legal. It is a progress feature only.
        costs = [a['cost'] for a in card['attacks'] if a['pressure'] >= 180]
        if not costs:
            costs = [a['cost'] for c in cards.values() if c.get('from') == card['name']
                     for a in c['attacks'] if a['pressure'] >= 180]
        if costs: funded += max(0, min(len(c) for c in costs) - access.energy_debt(costs, e['energies']))
    return dict(ready_attackers=ready, active_pressure=access._pressure(state['board'][state['active']], cards),
                information_engines=engines, evolution_progress=stages, funding_progress=funded)


def value(f, state):
    return (f['ready_attackers'] * 300 + f['active_pressure'] // 2 + f['information_engines'] * 70
            + f['evolution_progress'] * 50 + f['funding_progress'] * 35 - state['spent'] * 12)


def _needed(uid, state, cards):
    c = cards.get(uid, {})
    if any(h['local_card_uid'] == uid for h in state['hand']): return False
    if c.get('energy_model') == 'basic':
        if not state['attach']: return False
        for e in state['board'].values():
            if goal_lines().get(e['uid'], 0) < 180: continue
            sample = copy.deepcopy(state)
            sample['hand'].append(dict(serial=-1, local_card_uid=uid))
            moved = access._apply(sample, dict(kind='attach_energy', card_uid=uid, card_serial=-1,
                                              target=next(i for i, x in state['board'].items() if x is e)), cards)
            if moved and features(moved, cards)['funding_progress'] > features(state, cards)['funding_progress']:
                return True
        return False
    return bool(c.get('from')) and any(not e['played'] and not e['evolved']
        and (state['evolution_turn_available'] or e['early'])
        and c['from'] == cards[e['uid']]['name'] for e in state['board'].values())


def _actions(state, cards, *, acquisition=True):
    from .public_plan_comparison import _actions as ordinary_actions
    actions = ordinary_actions(state, cards)
    actions = [a for a in actions if a['kind'] != 'evolve' or
               state['evolution_turn_available'] or state['board'][a['target']]['early']]
    # The same physical hand copy/target is enumerated once. Equivalent copies
    # are interchangeable here, but identities are retained in actual routes.
    if acquisition:
        items = sorted((h for h in state['hand'] if h['local_card_uid'] == STRETCHER), key=lambda h: h['serial'])
        if items:
            seen = set()
            for h in sorted(state['discard'], key=lambda h: (h['local_card_uid'], h['serial'])):
                uid = h['local_card_uid']
                if uid in seen or not recoverable(uid, cards) or not _needed(uid, state, cards): continue
                seen.add(uid)
                actions.append(dict(kind='recover_to_hand', card_serial=items[0]['serial'], card_uid=STRETCHER,
                    recovered_serial=h['serial'], recovered_uid=uid))
    return actions


def _apply(state, action, cards):
    if action['kind'] == 'recover_to_hand':
        if not recoverable(action['recovered_uid'], cards): return None
        new = copy.deepcopy(state)
        item = next((h for h in new['hand'] if h['serial'] == action['card_serial']
                     and h['local_card_uid'] == STRETCHER), None)
        recovered = next((h for h in new['discard'] if h['serial'] == action['recovered_serial']
                          and h['local_card_uid'] == action['recovered_uid']), None)
        if item is None or recovered is None: return None
        new['hand'].remove(item); new['discard'].remove(recovered)
        new['hand'].append(recovered); new['discard'].append(item)
        new['spent'] += 1; new['steps'].append(copy.deepcopy(action))
        return new
    new = access._apply(state, action, cards)
    if new is None: return None
    if action['kind'] == 'retreat':
        used = new['steps'][-1]['discarded_energy_serials']
        for e in state['board'][state['active']]['energies']:
            if e['serial'] in used:
                new['discard'].append(dict(serial=e['serial'], local_card_uid=e['local_card_uid']))
    if action['kind'] == 'evolve' and cards[action['card_uid']].get('information_abilities'):
        new['checkpoint'] = True
    return new


def _key(state):
    board = [[i, e['uid'], e['evolved'], e['played'],
              [[x['serial'], x['local_card_uid'], x['units'], x['types']] for x in sorted(e['energies'], key=lambda x: x['serial'])]]
             for i, e in sorted(state['board'].items())]
    resources = [[[h['serial'], h['local_card_uid']] for h in sorted(state[z], key=lambda h: h['serial'])]
                 for z in ('hand', 'discard')]
    return json.dumps([board, *resources, state['active'], state['attach'], state['retreat'], state['checkpoint']], separators=(',', ':'))


def search(state, cards, *, acquisition=True, max_states=MAX_STATES):
    """Bounded composition; cutoff means unknown, never an impossibility proof."""
    queue = [state]; seen = {}; best = None; expanded = 0
    while queue:
        current = queue.pop(0)
        signature = _key(current)
        if signature in seen and seen[signature] <= current['spent']: continue
        seen[signature] = current['spent']; expanded += 1
        f = features(current, cards)
        row = dict(value=value(f, current), features=f, steps=copy.deepcopy(current['steps']),
                   resource_cost=current['spent'], checkpoint=current['checkpoint'])
        if best is None or row['value'] > best['value']: best = row
        if expanded >= max_states:
            return dict(best=best, expanded=expanded, truncated=True, exhaustive=False)
        if current['checkpoint'] or len(current['steps']) >= MAX_DEPTH: continue
        children = []
        for action in _actions(current, cards, acquisition=acquisition):
            child = _apply(current, action, cards)
            if child is None: continue
            cf = features(child, cards)
            # A route may temporarily consume a card to acquire a missing one;
            # ordinary resource steps must make progress or change the active.
            if action['kind'] in ('attach_energy', 'evolve') and cf == f: continue
            children.append((value(cf, child), _key(child), child))
        children.sort(key=lambda r: (-r[0], r[1]))
        queue.extend(r[2] for r in children[:BEAM])
    return dict(best=best, expanded=expanded, truncated=False, exhaustive=False)


def compare_card_goals(frame, ordered, *, validated=False):
    from .competitive_policy_v2 import _frame_error
    from .public_plan_comparison import compare_plans, _information, _bind
    base = compare_plans(frame, ordered, validated=validated, profile='resource-continuity-v2')
    result = dict(base, profile=PROFILE, card_goal_plans=[],
                  value_kind='public_goal_progress_ordinal', expected_value_proven=False)
    if not base['accepted'] or not frame.get('public_state', {}).get('decision'): return result
    if not validated and _frame_error(frame): return dict(result, accepted=False)
    # Optional single-card search still has a ranking frontier. Quantity remains
    # entirely with Base; this proposal never turns a zero-count choice into one.
    if frame['select_semantics']['max_count'] != 1: return result
    if frame['prompt_kind'] == 'main' and frame['select_semantics']['min_count'] != 1: return result
    cards = access.catalog(); initial = _state(frame, cards)
    if (initial['active'] not in initial['board'] or len(initial['board']) !=
        len(frame['public_state']['self']['active'] + frame['public_state']['self']['bench'])): return result
    baseline = base['proposed_index']; baseline_option = frame['options'][baseline]
    first = []
    main = frame['prompt_kind'] == 'main'
    if main:
        # Keep actual information, unmodeled setup/search, and proven finishes.
        if base['reason'] == 'current_proven_finish' or _information(frame, ordered, initial, cards): return result
        if baseline_option['kind'] in ('use_ability', 'play_basic_to_bench'): return result
        if baseline_option['kind'] == 'play_trainer' and baseline_option.get('card_uid') != STRETCHER: return result
        for action in _actions(initial, cards):
            for index in ordered:
                o = frame['options'][index]
                bound = (o['kind'] == 'play_trainer' and o.get('card_uid') == STRETCHER
                         and o.get('card_serial') == action.get('card_serial')) if action['kind'] == 'recover_to_hand' else _bind(o, action)
                if bound:
                    child = _apply(initial, action, cards)
                    if child: first.append((index, child))
    elif frame['prompt_kind'] in ('search', 'recovery', 'effect_target'):
        sources = {frame['options'][i].get('source_uid') for i in ordered}
        if len(sources) != 1 or next(iter(sources)) not in CHOICE_SOURCES: return result
        source = next(iter(sources))
        for index in ordered:
            o = frame['options'][index]; uid = o.get('card_uid'); serial = o.get('card_serial')
            if (o['kind'] not in ('search', 'recovery', 'effect_target') or uid not in cards
                or type(serial) is not int or o.get('target_entity_serial') is not None): continue
            if source == STRETCHER and (not recoverable(uid, cards) or
                not any(h['serial'] == serial and h['local_card_uid'] == uid for h in initial['discard'])): continue
            if any(h['serial'] == serial for h in initial['hand']): continue
            child = copy.deepcopy(initial)
            child['discard'] = [h for h in child['discard'] if h['serial'] != serial]
            child['hand'].append(dict(serial=serial, local_card_uid=uid))
            child['steps'].append(dict(kind='choose_to_hand', source_uid=source, card_uid=uid, card_serial=serial))
            first.append((index, child))
    else: return result
    plans = {}; total = 0
    for index, child in first:
        if total >= MAX_TOTAL_STATES:
            return dict(result, reason='card_goal_budget_unknown', card_goal_expanded=total)
        found = search(child, cards, max_states=min(MAX_STATES, MAX_TOTAL_STATES-total))
        total += found['expanded']
        if found['truncated']: return dict(result, reason='card_goal_budget_unknown', card_goal_expanded=total)
        row = dict(found['best'], first_index=index)
        if index not in plans or row['value'] > plans[index]['value']: plans[index] = row
    result.update(card_goal_plans=[plans[i] for i in sorted(plans)], card_goal_expanded=total,
                  requires_reobservation=True, future_legality_proven=False)
    if not plans: return result
    reference = plans.get(baseline)
    if reference is None:
        if main and baseline_option['kind'] in ('attack', 'end_turn'):
            f = features(initial, cards)
            reference = dict(value=value(f, initial), features=f)
        else: return result
    chosen = max((i for i in ordered if i in plans), key=lambda i: plans[i]['value'])
    best = plans[chosen]; gain = best['value'] - reference['value']
    if best['features']['active_pressure'] < reference['features']['active_pressure']:
        return dict(result, reason='card_goal_preserve_attack_access')
    productive = any(best['features'][k] > reference['features'][k] for k in
                     ('ready_attackers', 'information_engines', 'evolution_progress', 'funding_progress'))
    if productive and gain >= (40 if main else 20):
        result.update(proposed_index=chosen, reason='card_goal_resource_route', card_goal_advantage=gain,
                      card_goal_selected=best)
    return result
