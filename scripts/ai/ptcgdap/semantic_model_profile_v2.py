"""Additive public board/target profile; no entity serial is a learned feature.

V1 remains the validation and original-column owner. V2 retains every public
board slot (active plus up to eight bench slots per side) and current candidate
relations. Categorical hashes are identifiers, never numeric magnitudes.
"""
from dataclasses import replace
import hashlib

from .semantic_model_profile import project_semantic_frame, _i32

PROFILE_ID = 'ptcgdap_local_semantic_actor_i32_v2'
FRAME_WIDTH = 416
OPTION_WIDTH = 48
BOARD_SLOTS_PER_SIDE = 9
BOARD_FIELDS = (
    'public_printing_key', 'own_printing_code', 'remaining_hp', 'max_hp',
    'damage_counters', 'attached_energy_count', 'energy_debt', 'attack_ready',
    'prize_value', 'appeared_this_turn', 'evolution_stack_size', 'tool_printing_key',
    'has_current_evolve_option', 'has_current_attack_option', 'energy_multiset_key', 'is_active',
)
OPTION_FIELDS = (
    'action_own_printing_code', 'target_appeared_this_turn', 'target_evolution_stack_size',
    'target_tool_printing_key', 'target_max_hp', 'target_has_current_evolve_option',
    'action_public_printing_key', 'target_public_printing_key', 'source_public_printing_key',
    'target_energy_multiset_key', 'target_has_current_attack_option', 'target_board_slot',
    'source_appeared_this_turn', 'source_energy_multiset_key', 'source_board_slot', 'target_has_tool',
)


def public_category(value, domain, seen):
    if value is None:
        return None
    if type(value) is not str:
        raise ValueError('model_public_category_invalid')
    identity = (domain, value)
    digest = hashlib.sha256(('PTCGDAP\0PUBLIC_CATEGORY_V2\0'+domain+'\0'+value).encode('utf-8')).digest()
    key = int.from_bytes(digest[:4], 'big') % 2147483647 + 1
    if key in seen and seen[key] != identity:
        raise ValueError('model_public_category_collision')
    seen[key] = identity
    return key


def project_semantic_frame_v2(frame, allowed_uids):
    base = project_semantic_frame(frame, allowed_uids)
    state = frame['public_state']
    own, opponent = state['self'], state['opponent']
    for side in (own, opponent):
        if len(side['active']) > 1 or len(side['bench']) > 8:
            raise ValueError('model_board_capacity_exceeded')
    slots = []
    for side in (own, opponent):
        slots += (side['active'] or [None]) + side['bench'] + [None]*(8-len(side['bench']))
    codes = {uid:i+1 for i,uid in enumerate(sorted(set(allowed_uids)))}
    for option in frame['options']:
        if (option.get('card_uid') is not None and option['card_uid'] not in codes
                and option.get('option_player_index') in (None, frame['seat'])):
            raise ValueError('model_unknown_uid')
    seen = {}
    def card(uid): return public_category(uid, 'printing', seen)
    def energy(slot):
        if slot is None or 'attached_energy_uids' not in slot: return None
        values = slot['attached_energy_uids']
        if type(values) is not list or any(type(v) is not str or '|' in v for v in values):
            raise ValueError('model_public_category_invalid')
        return public_category('|'.join(sorted(values)), 'energy_multiset', seen)
    def tool(slot):
        if slot is None or 'attached_tool_uid' not in slot: return None
        return card(slot['attached_tool_uid']) if slot['attached_tool_uid'] is not None else 0
    def stack(slot):
        if slot is None or 'pokemon_stack_uids' not in slot: return None
        return len(slot['pokemon_stack_uids'])
    def resolve(option, prefix):
        entity, serial = option.get(prefix+'_entity_serial'), option.get(prefix+'_serial')
        found = [i for i,s in enumerate(slots) if s is not None and
                 ((entity is not None and s.get('entity_serial') == entity) or
                  (entity is None and serial is not None and s.get('serial') == serial))]
        if len(found) > 1: raise ValueError('model_public_target_ambiguous')
        if found: return found[0]
        if option['kind'] in ('attack', 'granted_attack'):
            default = 9 if prefix == 'target' else 0
            if slots[default] is not None: return default
        return None
    targets = [resolve(o, 'target') for o in frame['options']]
    sources = [resolve(o, 'source') for o in frame['options']]
    evolves = {targets[i] for i,o in enumerate(frame['options']) if o['kind'] == 'evolve'}
    attacks = {sources[i] for i,o in enumerate(frame['options']) if o['kind'] in ('attack', 'granted_attack')}
    extra = []
    for i,s in enumerate(slots):
        if s is None:
            extra += [None]*len(BOARD_FIELDS)
            continue
        extra += [card(s['local_card_uid']), codes.get(s['local_card_uid'], 0),
                  s.get('remaining_hp'), s.get('max_hp'), s.get('damage_counters'),
                  s.get('attached_energy_count'), s.get('energy_debt'), s.get('attack_ready'),
                  s.get('prize_value'), s.get('appeared_this_turn'), stack(s), tool(s),
                  i in evolves, i in attacks, energy(s), i in (0,9)]
    fv, fp = _i32(extra)
    rows, presence = [], []
    for r,index in enumerate(base.row_to_current_index):
        option = frame['options'][index]
        ti, si = targets[index], sources[index]
        target = slots[ti] if ti is not None else None
        source = slots[si] if si is not None else None
        def fact(slot, name): return slot.get(name) if slot is not None else None
        values = [codes.get(option['card_uid'],0) if option.get('card_uid') is not None else None,
                  fact(target,'appeared_this_turn'), stack(target), tool(target), fact(target,'max_hp'),
                  ti in evolves if ti is not None else None,
                  card(option.get('card_uid')), card(fact(target,'local_card_uid')),
                  card(option.get('source_uid')), energy(target), ti in attacks if ti is not None else None,
                  ti, fact(source,'appeared_this_turn'), energy(source), si,
                  target.get('attached_tool_uid') is not None if target is not None and 'attached_tool_uid' in target else None]
        ov, op = _i32(values)
        rows.append(base.option_i32[r]+ov)
        presence.append(base.option_presence_i32[r]+op)
    padding = ((0,)*OPTION_WIDTH,)*(1024-len(rows))
    return replace(base, profile_id=PROFILE_ID, frame_i32=base.frame_i32+fv,
                   frame_presence_i32=base.frame_presence_i32+fp,
                   option_i32=tuple(rows)+padding, option_presence_i32=tuple(presence)+padding)
