"""Versioned public semantic Actor input; no teacher score or hidden state.

UID columns 32:64, 64:96, 96:128 count own hand, board and discard in
lexicographically sorted sealed deck UID order, padded to 32. Foreign public
opponent printing identities have code zero; their numeric public facts remain.
This profile only admits single-choice windows with a fresh Base frontier.
"""
from __future__ import annotations
import copy
import hashlib
from .cabt_tree_hash import jcs_canonical_json_bytes
from .ptcgai_model_actor import PublicActorTensors, MAX_OPTIONS

PROFILE_ID = 'ptcgdap_local_semantic_actor_i32_v1'
FRAME_WIDTH = 128
OPTION_WIDTH = 32
KINDS = ('main', 'trainer', 'play_trainer', 'play_basic_to_bench', 'evolve', 'attach_energy',
         'ability', 'attack', 'retreat', 'end_turn', 'search', 'discard', 'assignment_source',
         'assignment_target', 'damage_target', 'effect_target', 'send_out', 'setup_active',
         'setup_bench', 'take_prize', 'starting_player_choice', 'mulligan_draw_count',
         'self_switch', 'opponent_switch', 'attack_target', 'select_card', 'select_number',
         'yes_no', 'stadium', 'play_stadium', 'use_stadium', 'select_energy', 'interaction',
         'attach_tool', 'granted_attack', 'no', 'yes', 'use_stadium_effect', 'activate',
         'retreat_energy', 'damage_counter', 'evolve_from', 'evolve_to')


def _i32(values):
    a, p = [], []
    for v in values:
        if v is None: a.append(0); p.append(0)
        elif type(v) in (int, bool) and -(2**31) <= int(v) < 2**31: a.append(int(v)); p.append(1)
        else: raise ValueError('model_feature_range_invalid')
    return tuple(a), tuple(p)


def project_semantic_frame(frame, allowed_uids):
    from .competitive_policy_v2 import _frame_error
    clean = copy.deepcopy(frame)
    for side in ('self', 'opponent'):
        for zone in ('active', 'bench'):
            for slot in clean.get('public_state', {}).get(side, {}).get(zone, []):
                if 'appeared_this_turn' in slot and type(slot.pop('appeared_this_turn')) is not bool:
                    raise ValueError('model_public_frame_invalid')
    if _frame_error(clean): raise ValueError('model_public_frame_invalid')
    uids = sorted(set(allowed_uids))
    if not uids or len(uids) > 32: raise ValueError('model_unknown_uid')
    codes = {uid:i+1 for i,uid in enumerate(uids)}
    state, sem, options = frame['public_state'], frame['select_semantics'], frame['options']
    own, opp = state['self'], state['opponent']
    board = own['active'] + own['bench']; enemy = opp['active'] + opp['bench']
    for card in own['hand'] + own['discard'] + board:
        if card.get('local_card_uid') not in codes: raise ValueError('model_unknown_uid')
    def count(zone, uid): return sum(c.get('local_card_uid') == uid for c in zone)
    def code(uid): return codes.get(uid, 0) if uid is not None else None
    def active(side, key): return side['active'][0].get(key) if side['active'] else None
    def kind(value): return KINDS.index(value) + 1 if value in KINDS else None
    turn = own.get('turn', {})
    f = [state.get('turn_number'), own.get('prizes_remaining'), opp.get('prizes_remaining'),
         own.get('deck_count'), opp.get('deck_count'), len(own['hand']), opp.get('hand_count'),
         len(own['bench']), len(opp['bench']), active(own,'remaining_hp'), active(opp,'remaining_hp'),
         active(own,'attached_energy_count'), active(opp,'attached_energy_count'), active(own,'damage_counters'), active(opp,'damage_counters'),
         sum(s.get('attack_ready') is True for s in board), sum(s.get('attack_ready') is True for s in enemy),
         sem['min_count'], sem['max_count'], sem.get('select_context_raw'), sem.get('select_type_raw'),
         turn.get('supporter_available'), turn.get('manual_attachment_available'), turn.get('retreat_available'),
         code(active(own,'local_card_uid')), code(active(opp,'local_card_uid')), code(sem.get('source_card_uid')),
         sem.get('remain_damage_counter'), sem.get('remain_energy_cost'),
         sum(s.get('damage_counters',0) for s in own['bench']), sum(s.get('damage_counters',0) for s in opp['bench']), kind(frame['prompt_kind'])]
    for zone in (own['hand'], board, own['discard']):
        f.extend([count(zone, uid) for uid in uids] + [None]*(32-len(uids)))
    f, fp = _i32(f)
    rows=[]
    for i,o in enumerate(options):
        if o.get('kind') not in KINDS: raise ValueError('model_unknown_option_shape')
        uid = o.get('target_uid') if o['kind']=='evolve' else o.get('card_uid')
        if uid is None: uid=o.get('source_uid')
        if uid is not None and uid not in codes and o.get('option_player_index') in (None,frame['seat']):
            raise ValueError('model_unknown_uid')
        target = next((s for s in board+enemy if
            (o.get('target_entity_serial') is not None and s.get('entity_serial')==o['target_entity_serial']) or
            (o.get('target_entity_serial') is None and o.get('target_serial') is not None and s.get('serial')==o['target_serial'])), {})
        if not target and o['kind']=='attack' and opp['active']: target=opp['active'][0]
        def target_fact(key, fallback): return o[key] if o.get(key) is not None else target.get(fallback)
        vals=[kind(o['kind']), code(uid), code(o.get('source_uid')), code(o.get('target_uid')),
              o.get('energy_type_raw'), o.get('energy_count'), o.get('attack_index'), o.get('ability_index'),
              target_fact('target_remaining_hp','remaining_hp'), target_fact('target_damage_counters','damage_counters'),
              target_fact('target_attached_energy_count','attached_energy_count'), target_fact('target_energy_debt','energy_debt'),
              target_fact('target_attack_ready','attack_ready'), o.get('projected_damage'), o.get('projected_knockout'),
              target_fact('target_prize_value','prize_value'), o.get('option_player_index')==frame['seat'] if o.get('option_player_index') is not None else None,
              count(own['hand'],uid) if uid is not None else None, count(board,o.get('target_uid')) if o.get('target_uid') else None,
              count(own['discard'],uid) if uid is not None else None, o.get('option_number'), o.get('special_condition_type'),
              o.get('option_area_raw'), target in own['active']+opp['active'] if target else None,
              target in own['bench']+opp['bench'] if target else None,
              target_fact('target_minimum_attack_energy_count','minimum_attack_energy_count'), o.get('pending_assignment_count'),
              o.get('assigned_energy_count'), sem.get('remain_damage_counter'), o.get('option_type_raw'),
              o.get('source_damage_counters'), o.get('source_energy_count')]
        v,p=_i32(vals)
        semantic={k:v for k,v in o.items() if k!='index'}
        key=hashlib.sha256(b'PTCGDAP\0SEMANTIC_MODEL_OPTION_V1\0'+jcs_canonical_json_bytes(semantic)).hexdigest().upper()
        rows.append((key,i,v,p))
    rows.sort(key=lambda r:(r[0],r[1])); n=len(rows)
    indexes=tuple(r[1] for r in rows)
    return PublicActorTensors(PROFILE_ID, f, fp, tuple(r[2] for r in rows)+((0,)*OPTION_WIDTH,)*(MAX_OPTIONS-n),
        tuple(r[3] for r in rows)+((0,)*OPTION_WIDTH,)*(MAX_OPTIONS-n), (1,)*n+(0,)*(MAX_OPTIONS-n),
        tuple(r[0] for r in rows), indexes, {i:r for r,i in enumerate(indexes)}, sem['min_count'],sem['max_count'])


def base_model_frontier(*, frame, selected, tiers, vetoed, mandatory, terminal, evaluated, audit):
    """Called only by Base after adjudication; never reconstruct from ranking."""
    reason = ''
    sem=frame['select_semantics']
    if terminal or mandatory: reason='forced'
    elif any(o['kind'] in ('attack','granted_attack') and o.get('projected_knockout') is True
             and (o.get('target_prize_value') or (frame['public_state']['opponent']['active'][0].get('prize_value',0)
                  if frame['public_state']['opponent']['active'] else 0)) >= frame['public_state']['self']['prizes_remaining'] > 0
             for o in frame['options']): reason='terminal_attack'
    elif sem['min_count'] != 1 or sem['max_count'] != 1 or len(selected)!=1: reason='cardinality'
    elif evaluated.get('selection_quotas') is not None: reason='quota'
    elif audit.get('fallback_used'): reason='base_fallback'
    elif audit.get('turn_contract',{}).get('route_authority_applied'): reason='route'
    elif audit.get('turn_program_canary',{}).get('applied'): reason='canary'
    elif any(audit.get(k,{}).get('selected_transaction_id') or audit.get(k,{}).get('transaction_id') or
             audit.get(k,{}).get('state') or audit.get(k,{}).get('current_indexes')
             for k in ('semantic_transaction','turn_transaction')): reason='transaction'
    elif frame['prompt_kind'] in ('starting_player_choice','mulligan_draw_count','setup_active','setup_bench','take_prize','send_out'): reason='protected_prompt'
    indexes=list(selected)
    learning_kinds = ('attach_energy','play_basic_to_bench','play_stadium','end_turn',
                     'use_stadium_effect','retreat','play_trainer','attack','attach_tool','evolve','granted_attack')
    if not reason and (frame['prompt_kind'] != 'main' or any(o['kind'] not in learning_kinds for o in frame['options'])):
        reason='unsupported_learning_context'
    if not reason and tiers:
        best=min(tiers.values())
        indexes=[i for i in range(len(frame['options'])) if tiers[i]==best and i not in vetoed]
        if any(i not in indexes for i in selected): reason='authority_mismatch'; indexes=list(selected)
        elif len(indexes)<2: reason='unique'
    return {'profile_id':'ptcgdap-base-model-frontier-v1','enabled':not bool(reason),'reason':reason,
            'indexes':indexes, 'public_observation_hash':frame['source']['public_observation_hash'],
            'window_id':frame['source']['window_id']}
