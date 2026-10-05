"""Conservative destination forecasts; never creates a legal action.

Only reviewed board abilities, no tools, and no unreviewed stadiums enter this
branch. The typed Boss/Catcher suffix models Dragapult's paid Phantom Dive;
the main prefix requires an actual legal attack. Temporary effects absent from
the public contract remain an explicit model limitation.
"""
import json
from functools import lru_cache
from pathlib import Path


@lru_cache(maxsize=1)
def scope():
    return json.loads((Path(__file__).resolve().parents[3] /
        'contracts/ptcgdap/public_gust_scope_v1.json').read_bytes())


def inputs(frame, cards):
    public = frame.get('public_state', {})
    own, opponent = public.get('self', {}), public.get('opponent', {})
    reviewed = scope()
    stadium = public.get('decision', {}).get('stadium', {}).get('card_uid')
    if stadium is not None and (stadium not in reviewed['stadiums'] or
            reviewed['stadiums'][stadium] != cards.get(stadium, {}).get('effect_id')):
        return [], set(), False
    slots = [s for p in (own, opponent) for z in ('active','bench') for s in p.get(z, [])]
    for slot in slots:
        uid = slot.get('local_card_uid'); card = cards.get(uid, {})
        if not card or slot.get('attached_tool_uid') is not None:
            return [], set(), False
        if card.get('has_ability') and reviewed['board_abilities'].get(uid) != card.get('effect_id'):
            return [], set(), False
    targets = {s['entity_serial'] for s in opponent.get('bench', [])
        if s.get('remaining_hp', 0) > 0 and s.get('local_card_uid') not in reviewed['decline_targets']}
    attacks = [o for o in frame.get('options', []) if o.get('kind') in ('attack','granted_attack')]
    typed = frame.get('prompt_kind') == 'effect_target' and any(
        o.get('source_uid') in ('30thDC_039','CSV6C_114') for o in frame.get('options', []))
    if typed and len(own.get('active', [])) == 1:
        active = own['active'][0]
        entity = next((e for e in public.get('decision', {}).get('entities', [])
            if e.get('entity_serial') == active['entity_serial']), {})
        if (active.get('local_card_uid') == 'CSV8C_159' and entity and
                entity.get('conditions') == [] and any(a.get('source_uid') == 'CSV8C_159' and
                    a.get('attack_index') == 1 and a.get('energy_ready') is True and
                    a.get('energy_debt') == 0 for a in entity.get('attacks', []))):
            attacks = [dict(kind='attack',source_entity_serial=active['entity_serial'],
                source_serial=active['serial'],source_uid='CSV8C_159',attack_index=1,projected_damage=None)]
    return attacks, targets, typed
