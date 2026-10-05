extends RefCounted
## Reviewed current-window conditional comparison. No hidden engine state.
const Access = preload("res://scripts/ai/ptcgdap/public/PublicAttackAccess.gd")
const Damage = preload("res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd")
const CardGoals = preload("res://scripts/ai/ptcgdap/public/PublicCardGoals.gd")
const PROFILE = "resource-continuity-v1"
const MAX_STATES = 256
const MAX_DEPTH = 3
static var _metadata: Dictionary = {}

static func metadata() -> Dictionary:
	if _metadata.is_empty(): _metadata = Damage._load_default_registry_reference().get("cards", {})
	return _metadata

static func _ids(state: Dictionary) -> Array:
	var ids: Array = state.board.keys(); ids.sort(); return ids

static func _printed(entity: Dictionary, cards: Dictionary) -> int:
	return Access._printed_pressure(cards.get(entity.uid, {}))

static func _line(entity: Dictionary, cards: Dictionary) -> int:
	var current: Dictionary = cards.get(entity.uid, {}); var names: Array = [current.get("name")]
	var result := _printed(entity, cards)
	for _n: int in range(2):
		for c: Dictionary in cards.values():
			if c.get("from", "") != "" and c["from"] in names:
				if c.name not in names: names.append(c.name)
				result = maxi(result, Access._printed_pressure(c))
	return result

static func _actions(state: Dictionary, cards: Dictionary) -> Array:
	var result := []; var hand: Array = state.hand.duplicate()
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.serial < b.serial)
	for h: Dictionary in hand:
		var c: Dictionary = cards.get(h.local_card_uid, {})
		for identity: int in _ids(state):
			var entity: Dictionary = state.board[identity]
			if state.attach and c.get("energy_model", "") != "" and (identity == state.active or _line(entity, cards) >= 150):
				result.append({"kind":"attach_energy", "card_serial":int(h.serial), "card_uid":h.local_card_uid, "target":identity})
			if not entity.played and not entity.evolved and c.get("from", "") != "" and c["from"] == cards[entity.uid].name and c.stage == cards[entity.uid].stage + 1:
				result.append({"kind":"evolve", "card_serial":int(h.serial), "card_uid":h.local_card_uid, "target":identity})
	var active: Dictionary = state.board[state.active]
	if state.retreat and "asleep" not in active.conditions and "paralyzed" not in active.conditions:
		for identity: int in _ids(state):
			if identity != state.active and _printed(state.board[identity], cards) >= 90:
				result.append({"kind":"retreat", "target":identity})
	return result

static func _bind(option: Dictionary, action: Dictionary) -> bool:
	if option.kind != action.kind or option.get("target_entity_serial") != action.target: return false
	return action.kind == "retreat" or (option.get("card_serial") == action.card_serial and option.get("card_uid") == action.card_uid)

static func _asset_value(state: Dictionary, cards: Dictionary) -> int:
	var counts := {}; var value := 0
	for h: Dictionary in state.hand:
		var model: String = cards.get(h.local_card_uid, {}).get("energy_model", "")
		if model == "": continue
		counts[h.local_card_uid] = counts.get(h.local_card_uid, 0) + 1
		value += int((100 if model == "neo_upper" else 28 if model == "luminous" else 18) / int(counts[h.local_card_uid]))
	for e: Dictionary in state.board.values():
		for energy: Dictionary in e.energies:
			var model: String = cards.get(energy.local_card_uid, {}).get("energy_model", "")
			value += 50 if model == "neo_upper" else 20 if model == "luminous" else 14
	return value

static func _successor_plan(state: Dictionary, cards: Dictionary, frame: Dictionary = {}, weight := 500) -> Dictionary:
	var residual := _asset_value(state, cards)
	var engine := 0
	for e: Dictionary in state.board.values():
		if not cards[e.uid].get("information_abilities",[]).is_empty(): engine += 1
	var best := {"value":0,"entity_serial":null,"debt":32,"residual_value":residual,"engine_count":engine,"future_attachment":false,"reserved_card_serials":[],"joint_value":residual+28*engine}
	var hand: Array = state.hand.duplicate()
	hand.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.serial < b.serial)
	for serial: int in _ids(state):
		var entity: Dictionary = state.board[serial]
		if serial == state.active or _line(entity,cards) < 150: continue
		var variants: Array = [[entity.duplicate(true),[]]]
		for h: Dictionary in hand:
			var c: Dictionary = cards.get(h.local_card_uid,{})
			if c.get("from","") != "" and c["from"] == cards[entity.uid].name and c.stage == cards[entity.uid].stage + 1:
				var e: Dictionary = entity.duplicate(true); e.uid = h.local_card_uid; e.costs = {}
				for a: Dictionary in c.attacks: e.costs[int(a.index)] = [a.cost]
				if Access._resupply(e,cards): variants.append([e,[int(h.serial)]])
		for variant: Array in variants:
			var base: Dictionary = variant[0]; var evolved: Array = variant[1]
			var supplies: Array = [[base,evolved,false]]
			for h: Dictionary in hand:
				if cards.get(h.local_card_uid,{}).get("energy_model","") == "" or h.serial in evolved: continue
				if not frame.is_empty() and frame.public_state.self.turn.manual_attachment_available:
					var observed := false
					for o: Dictionary in frame.options:
						if o.kind == "attach_energy" and o.get("card_serial") == h.serial and o.get("target_entity_serial") == serial: observed = true
					if not observed: continue
				var e: Dictionary = base.duplicate(true)
				e.energies.append({"serial":int(h.serial),"local_card_uid":h.local_card_uid,"units":1,"types":["C"]})
				if Access._resupply(e,cards): supplies.append([e,evolved + [int(h.serial)],true])
			for supply: Array in supplies:
				var e: Dictionary = supply[0]; var reserved: Array = supply[1]; var attached: bool = supply[2]
				var shadow := {"hand":[],"board":state.board.duplicate()}
				for h: Dictionary in hand:
					if h.serial not in reserved: shadow.hand.append(h)
				shadow.board[serial] = e
				residual = _asset_value(shadow,cards)
				engine = 0
				for x: Dictionary in shadow.board.values():
					if not cards[x.uid].get("information_abilities",[]).is_empty(): engine += 1
				for a: Dictionary in cards[e.uid].attacks:
					if a.pressure < 150 or not e.costs.has(int(a.index)): continue
					var missing := Access.energy_debt(e.costs[int(a.index)],e.energies)
					var quality := int(int(a.pressure)*(100 if missing == 0 else 35 if missing == 1 else 10)/100)
					var joint := int(quality*weight/1000) + residual + 28*engine
					if Access._less([best.joint_value,-int(best.future_attachment)],[joint,-int(attached)]):
						var used: Array = reserved.duplicate(); used.sort()
						best = {"value":quality,"entity_serial":serial,"debt":missing,"residual_value":residual,"engine_count":engine,"future_attachment":attached,"reserved_card_serials":used,"joint_value":joint}
	return best

static func _successor(state: Dictionary, cards: Dictionary, frame: Dictionary = {}) -> Array:
	var best := 0; var identity: Variant = null; var debt := 32
	for serial: int in _ids(state):
		var entity: Dictionary = state.board[serial]
		if serial == state.active or _line(entity, cards) < 150: continue
		var variants: Array = [entity.duplicate(true)]
		for h: Dictionary in state.hand:
			var c: Dictionary = cards.get(h.local_card_uid, {})
			if c.get("from", "") != "" and c["from"] == cards[entity.uid].name and c.stage == cards[entity.uid].stage + 1:
				var e: Dictionary = entity.duplicate(true); e.uid = h.local_card_uid; e.costs = {}
				for a: Dictionary in c.attacks: e.costs[int(a.index)] = [a.cost]
				if Access._resupply(e, cards): variants.append(e)
		for base: Dictionary in variants:
			var supplies: Array = [base]
			for h: Dictionary in state.hand:
				if cards.get(h.local_card_uid, {}).get("energy_model", "") == "": continue
				if not frame.is_empty() and frame.public_state.self.turn.manual_attachment_available:
					var observed := false
					for o: Dictionary in frame.options:
						if o.kind == "attach_energy" and o.get("card_serial") == h.serial and o.get("target_entity_serial") == serial: observed = true
					if not observed: continue
				var e: Dictionary = base.duplicate(true)
				e.energies.append({"serial":int(h.serial), "local_card_uid":h.local_card_uid, "units":1, "types":["C"]})
				if Access._resupply(e, cards): supplies.append(e)
			for e: Dictionary in supplies:
				for a: Dictionary in cards[e.uid].attacks:
					if a.pressure < 150 or not e.costs.has(int(a.index)): continue
					var missing := Access.energy_debt(e.costs[int(a.index)], e.energies)
					var quality := int(int(a.pressure) * (100 if missing == 0 else 35 if missing == 1 else 10) / 100)
					if quality > best: best = quality; identity = serial; debt = missing
	return [best, identity, debt]

static func _damage(uid: String, attack_index: int, target_uid: String, meta: Dictionary) -> Variant:
	var c: Dictionary = meta.get(uid, {}); var target: Dictionary = meta.get(target_uid, {}); var damage: Variant = null
	for a: Dictionary in c.get("attacks", []):
		if a.attack_index == attack_index: damage = a.get("active_damage"); break
	if damage == null: return null
	damage = int(damage)
	if c.get("energy_type", "") != "" and c.energy_type == target.get("weakness_energy"):
		damage *= int(target.get("weakness_multiplier", 1))
	if c.get("energy_type", "") != "" and c.energy_type == target.get("resistance_energy"):
		damage = maxi(0, damage - int(target.get("resistance_reduction", 0)))
	return damage

static func _attack(state: Dictionary, initial: Dictionary, frame: Dictionary, cards: Dictionary, meta: Dictionary, wait := false, attack_index: Variant = null) -> Dictionary:
	var result := {"damage":0,"prizes":0,"counters":0,"pressure":0,"finishes":false,"conditional":false,"defender_ko":false,"attack_index":null}
	if wait: return result
	var d: Dictionary = frame.public_state.decision
	if d.self.is_first_turn and d.current_player_index == d.first_player_index: return result
	var opponent: Dictionary = frame.public_state.opponent
	if opponent.active.is_empty(): return result
	var e: Dictionary = state.board[state.active]; var target: Dictionary = opponent.active[0]
	if "asleep" in e.conditions or "paralyzed" in e.conditions: return result
	for a: Dictionary in cards[e.uid].attacks:
		if attack_index != null and a.index != attack_index: continue
		if not e.costs.has(int(a.index)) or Access.energy_debt(e.costs[int(a.index)], e.energies) != 0: continue
		var legal: Dictionary = {}
		for o: Dictionary in frame.options:
			if o.kind == "attack" and o.get("source_uid") == e.uid and o.get("attack_index") == a.index and state.active == initial.active:
				legal = o; break
		var unchanged: bool = state.active == initial.active and e.uid == initial.board[initial.active].uid
		if unchanged and Access._pressure(initial.board[initial.active], cards) > 0 and legal.is_empty(): continue
		var damage: Variant = legal.get("projected_damage") if not legal.is_empty() else _damage(e.uid, int(a.index), target.local_card_uid, meta)
		if damage == null: continue
		damage = int(damage)
		var conditional := legal.is_empty(); var ko: bool = damage >= target.remaining_hp and damage > 0
		var prizes: int = int(target.prize_value) if ko else 0
		var counters := 60 if e.uid == "CSV8C_159" and a.index == 1 else 0
		var budget := counters; var bench_prizes := 0; var bench: Array = opponent.bench.duplicate()
		bench.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return Access._less([-x.prize_value,x.remaining_hp,x.entity_serial],[-y.prize_value,y.remaining_hp,y.entity_serial]))
		for b: Dictionary in bench:
			if b.remaining_hp > 0 and b.remaining_hp <= budget:
				budget -= int((int(b.remaining_hp)+9)/10)*10; bench_prizes += int(b.prize_value)
		var finishes: bool = not conditional and ko and prizes >= frame.public_state.self.prizes_remaining
		var candidate := {"damage":mini(damage,int(target.remaining_hp)),"prizes":prizes+bench_prizes,"counters":counters,"pressure":int(a.pressure),"finishes":finishes,"conditional":conditional,"defender_ko":ko,"attack_index":int(a.index)}
		if Access._less([int(result.finishes),result.prizes,result.damage+result.counters], [int(candidate.finishes),candidate.prizes,candidate.damage+counters]): result = candidate
	return result

static func _response(state: Dictionary, frame: Dictionary, attack: Dictionary, meta: Dictionary) -> Dictionary:
	var e: Dictionary = state.board[state.active]; var public: Dictionary = frame.public_state; var opp: Dictionary = public.opponent
	var entities := {}; var exposure := 0; var damage := 0; var unknown := false
	for r: Dictionary in public.decision.entities: entities[int(r.entity_serial)] = r
	for slot: Dictionary in opp.active + opp.bench:
		if attack.defender_ko and slot in opp.active: continue
		var source: Dictionary = entities.get(int(slot.entity_serial), {})
		for a: Dictionary in source.get("attacks", []):
			var amount: Variant = _damage(slot.local_card_uid,int(a.attack_index),e.uid,meta)
			if amount == null: unknown = true; continue
			var missing := int(a.energy_debt)
			if missing > 1: continue
			var weight := 1000 if missing == 0 else 450
			if slot in opp.bench and not attack.defender_ko: weight = int(weight*3/4)
			damage = maxi(damage,int(int(amount)*weight/1000))
			if amount >= e.hp: exposure = maxi(exposure,weight)
	return {"active_ko_exposure":exposure,"damage":damage,"unknown":unknown}

static func _evaluate(state: Dictionary, initial: Dictionary, frame: Dictionary, cards: Dictionary, meta: Dictionary, wait := false, attack_index: Variant = null, joint_resources := false) -> Dictionary:
	if not joint_resources: return _evaluate_legacy(state,initial,frame,cards,meta,wait,attack_index)
	var attack := _attack(state,initial,frame,cards,meta,wait,attack_index)
	var response := _response(state,frame,attack,meta)
	var active: Dictionary = state.board[state.active]; var current := Access._pressure(active,cards)
	var exposure := int(response.active_ko_exposure)
	var successor := _successor_plan(state,cards,frame,500+exposure)
	var residual := int(successor.residual_value)
	var lost_prize := int(active.prize)*exposure; var own_prizes := int(frame.public_state.self.prizes_remaining)
	var their_prizes := int(frame.public_state.opponent.prizes_remaining); var engine := int(successor.engine_count)
	var score: int = mini(own_prizes,int(attack.prizes))*220 + int((int(attack.damage)+int(attack.counters))/3) + int(current*(1000-exposure)/2000) + int(int(successor.value)*(500+exposure)/1000) + residual + 28*engine - int(lost_prize*130/1000) - int(state.retreat_count)*8
	if exposure > 0 and active.prize >= their_prizes: score -= int(exposure*500/1000)
	if attack.finishes: score += 100000
	return {"value":score,"attack":attack,"response":response,"successor_value":successor.value,"successor_entity_serial":successor.entity_serial,"successor_debt":successor.debt,"successor_commitment":successor,"opportunity_cost":maxi(0,_asset_value(initial,cards)-residual),"resource_cost":state.spent,"steps":state.steps.duplicate(true)}

static func _evaluate_legacy(state: Dictionary, initial: Dictionary, frame: Dictionary, cards: Dictionary, meta: Dictionary, wait := false, attack_index: Variant = null) -> Dictionary:
	var attack := _attack(state,initial,frame,cards,meta,wait,attack_index)
	var response := _response(state,frame,attack,meta); var successor := _successor(state,cards,frame)
	var active: Dictionary = state.board[state.active]; var current := Access._pressure(active,cards)
	var residual := _asset_value(state,cards); var exposure := int(response.active_ko_exposure)
	var lost_prize := int(active.prize)*exposure; var own_prizes := int(frame.public_state.self.prizes_remaining)
	var their_prizes := int(frame.public_state.opponent.prizes_remaining); var engine := 0
	for e: Dictionary in state.board.values():
		if not cards[e.uid].get("information_abilities",[]).is_empty(): engine += 1
	var score: int = mini(own_prizes,int(attack.prizes))*220 + int((int(attack.damage)+int(attack.counters))/3) + int(current*(1000-exposure)/2000) + int(int(successor[0])*(500+exposure)/1000) + residual + 28*engine - int(lost_prize*130/1000) - int(state.retreat_count)*8
	if exposure > 0 and active.prize >= their_prizes: score -= int(exposure*500/1000)
	if attack.finishes: score += 100000
	return {"value":score,"attack":attack,"response":response,"successor_value":successor[0],"successor_entity_serial":successor[1],"successor_debt":successor[2],"opportunity_cost":maxi(0,_asset_value(initial,cards)-residual),"resource_cost":state.spent,"steps":state.steps.duplicate(true)}


static func _information(frame: Dictionary, ordered: Array, state: Dictionary, cards: Dictionary) -> Array:
	if frame.public_state.self.deck_count < 2: return []
	var found := []
	for i: int in ordered:
		var o: Dictionary = frame.options[i]
		if o.kind == "use_ability":
			var e: Dictionary = state.board.get(o.get("source_entity_serial"),{}); var c: Dictionary = cards.get(e.get("uid"),{})
			if e.get("uid") == o.get("source_uid") and o.get("ability_index") in c.get("information_abilities",[]):
				found.append({"index":i,"reason":"information_checkpoint"})
		elif o.kind == "evolve":
			var e: Dictionary = state.board.get(o.get("target_entity_serial"),{}); var c: Dictionary = cards.get(o.get("card_uid"),{})
			var in_hand := false
			for h: Dictionary in state.hand:
				if h.serial == o.get("card_serial") and h.local_card_uid == o.get("card_uid"): in_hand = true
			if not e.is_empty() and not c.get("information_abilities",[]).is_empty() and not e.played and not e.evolved and c.get("from") == cards[e.uid].name and c.stage == cards[e.uid].stage + 1 and in_hand:
				found.append({"index":i,"reason":"information_predecessor"})
	found.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var x: Dictionary = frame.options[a.index]; var y: Dictionary = frame.options[b.index]
		var xi: int = x.source_entity_serial if x.kind == "use_ability" else x.target_entity_serial
		var yi: int = y.source_entity_serial if y.kind == "use_ability" else y.target_entity_serial
		var xk := [0 if x.kind == "use_ability" else 1,-state.board[xi].energies.size(),xi,int(x.get("card_serial") if x.get("card_serial") != null else 0),int(x.get("ability_index") if x.get("ability_index") != null else 0)]
		var yk := [0 if y.kind == "use_ability" else 1,-state.board[yi].energies.size(),yi,int(y.get("card_serial") if y.get("card_serial") != null else 0),int(y.get("ability_index") if y.get("ability_index") != null else 0)]
		for k: int in xk.size():
			if xk[k] != yk[k]: return xk[k] < yk[k]
		return false)
	return found

static func _voluntary_switch(frame: Dictionary, ordered: Array, result: Dictionary) -> Dictionary:
	if frame.select_semantics.select_context_raw != 3 or frame.public_state.decision.current_player_index != frame.seat:
		result.reason = "unsupported_planning_window"; return result
	var cards := Access.cards(); var initial := Access._state(frame,cards); var meta := metadata()
	if not initial.board.has(initial.active) or initial.board.size() != frame.public_state.self.active.size()+frame.public_state.self.bench.size():
		result.reason = "unknown_board_capability"; return result
	var baseline_control: bool = frame.options[ordered[0]].get("target_uid") == "CSV9.5C_004"
	var choices := []; var best := {}; var best_key := []
	for index: int in ordered:
		var o: Dictionary = frame.options[index]; var identity: Variant = o.get("target_entity_serial"); var e: Dictionary = initial.board.get(identity,{})
		if o.kind != "send_out" or e.is_empty() or e.uid != o.get("target_uid") or identity == initial.active: continue
		var state: Dictionary = initial.duplicate(true); state.active = identity
		var attack := _attack(state,initial,frame,cards,meta)
		var finish: bool = attack.defender_ko and frame.public_state.opponent.active[0].prize_value >= frame.public_state.self.prizes_remaining
		if baseline_control and not finish: continue
		if not finish and not (attack.defender_ko or attack.pressure >= 150): continue
		var row := {"index":index,"entity_serial":identity,"attack":attack,"finish_forecast":finish}
		choices.append(row)
		var key := [int(finish),attack.prizes,attack.damage+attack.counters,attack.pressure,-int(identity)]
		if best.is_empty() or Access._less(best_key,key): best=row; best_key=key
	if choices.is_empty(): result.reason="voluntary_switch_baseline"; return result
	result.merge({"proposed_index":best.index,"reason":"voluntary_attack_switch","switch_candidates":choices},true)
	return result

static func compare_plans(frame: Dictionary, ordered: Array, profile: String = PROFILE) -> Dictionary:
	# Only called after the Host/SDK has validated the public frame.
	if profile == "card-goals-v1":
		return CardGoals.compare(frame, ordered, compare_plans(frame, ordered, "resource-continuity-v2"))
	var result := {"accepted":false,"proposed_index":null,"reason":"unqualified_public_position","plans":[],"current_window_only":true,"stale_plan_has_authority":false,"profile":profile,"value_kind":"ordinal_public_response_critic","expected_value_proven":false}
	if not frame.get("public_state",{}).has("decision"): return result
	var seen := {}
	if profile not in ["resource-continuity-v1","resource-continuity-v2"]: result.reason = "unsupported_plan_profile"; return result
	if ordered.is_empty(): result.reason = "invalid_current_frontier"; return result
	for i: Variant in ordered:
		if not i is int or i < 0 or i >= frame.options.size() or seen.has(i): result.reason = "invalid_current_frontier"; return result
		seen[i] = true
	var baseline: int = ordered[0]
	result.merge({"accepted":true,"proposed_index":baseline,"baseline_index":baseline,"reason":"baseline"},true)
	if frame.select_semantics.min_count != 1 or frame.select_semantics.max_count != 1:
		result.reason="unsupported_planning_window"; return result
	if frame.prompt_kind != "main":
		if profile == "resource-continuity-v2" and frame.prompt_kind in ["send_out","self_switch"]: return _voluntary_switch(frame,ordered,result)
		result.reason="unsupported_planning_window"; return result
	var cards := Access.cards(); var meta := metadata(); var initial := Access._state(frame,cards)
	if not initial.board.has(initial.active): result.reason = "unknown_active_capability"; return result
	if initial.board.size() != frame.public_state.self.active.size()+frame.public_state.self.bench.size(): result.reason = "unknown_board_capability"; return result
	var baseline_option: Dictionary = frame.options[baseline]
	if profile == "resource-continuity-v2" and baseline_option.kind == "evolve":
		var target: Variant = baseline_option.get("target_entity_serial"); var entity: Dictionary = initial.board.get(target,{})
		for i: int in ordered:
			var o: Dictionary = frame.options[i]; var identity: Variant = o.get("target_entity_serial")
			if not entity.is_empty() and o.kind == "evolve" and o.get("card_serial") == baseline_option.get("card_serial") and o.get("card_uid") == baseline_option.get("card_uid") and initial.board.get(identity,{}) == entity and (identity == initial.active) == (target == initial.active):
				if identity < frame.options[baseline].target_entity_serial: baseline=i
		baseline_option = frame.options[baseline]
		result.baseline_index = baseline; result.proposed_index = baseline
	var known := ["attach_energy","evolve","retreat","attack","end_turn"]
	if baseline_option.kind not in known: result.reason = "baseline_unmodeled_checkpoint"; return result
	var current := _attack(initial,initial,frame,cards,meta)
	if current.finishes:
		for i: int in ordered:
			if frame.options[i].kind == "attack" and frame.options[i].get("attack_index") == current.attack_index:
				result.proposed_index = i; result.reason = "current_proven_finish"; return result
	var info := _information(frame,ordered,initial,cards)
	if not info.is_empty() and not current.finishes:
		result.merge({"proposed_index":info[0].index,"reason":info[0].reason,"information_candidates":info,"requires_reobservation":true},true); return result
	if profile == "resource-continuity-v2" and ((baseline_option.kind == "retreat" and baseline_option.get("target_uid") == "CSV9.5C_004") or (baseline_option.kind == "attack" and baseline_option.get("source_uid") == "CSV9.5C_004")):
		result.reason="unmodeled_control_route_protected"; return result
	var joint_resources := profile == "resource-continuity-v2"
	var actions := _actions(initial,cards); var best := {}; var expanded := 0
	for index: int in ordered:
		var option: Dictionary = frame.options[index]
		if option.kind not in known: continue
		if option.kind in ["attack","end_turn"]:
			var row := _evaluate(initial,initial,frame,cards,meta,option.kind=="end_turn",option.get("attack_index"),joint_resources)
			row.first_index = index; best[index] = row; continue
		for action: Dictionary in actions:
			if not _bind(option,action): continue
			var child := Access._apply(initial,action,cards)
			if child.is_empty(): continue
			var queue: Array = [child]
			while not queue.is_empty():
				var state: Dictionary = queue.pop_front(); expanded += 1
				var row := _evaluate(state,initial,frame,cards,meta,false,null,joint_resources); row.first_index = index
				if not best.has(index) or row.value > best[index].value: best[index] = row
				if expanded >= MAX_STATES: break
				if state.steps.size() >= MAX_DEPTH: continue
				var next_rows := []; var information_stop := false
				for s: Dictionary in state.steps:
					if s.kind == "evolve" and not cards[state.board[s.target].uid].get("information_abilities",[]).is_empty(): information_stop = true
				if not information_stop:
					for follow: Dictionary in _actions(state,cards):
						var nxt := Access._apply(state,follow,cards)
						if not nxt.is_empty(): next_rows.append([_evaluate(nxt,initial,frame,cards,meta,false,null,joint_resources).value,nxt,next_rows.size()])
				# Explicit stable tie order matches Python stable sort.
				next_rows.sort_custom(func(a: Array,b: Array) -> bool: return a[0]>b[0] or (a[0]==b[0] and a[2]<b[2]))
				for k: int in mini(4,next_rows.size()): queue.append(next_rows[k][1])
			if expanded >= MAX_STATES: break
		if expanded >= MAX_STATES: break
	var indexes: Array = best.keys(); indexes.sort(); var plans := []
	for i: int in indexes: plans.append(best[i])
	result.merge({"plans":plans,"expanded":expanded},true)
	if expanded >= MAX_STATES: result.reason = "planning_budget_exceeded"; return result
	if not best.has(baseline) or best.is_empty(): result.reason = "baseline_not_modeled"; return result
	var chosen := baseline
	for i: int in ordered:
		if not best.has(i): continue
		var left := [best[chosen].value,-int(best[chosen].successor_commitment.future_attachment) if joint_resources else 0]
		var right := [best[i].value,-int(best[i].successor_commitment.future_attachment) if joint_resources else 0]
		if Access._less(left,right): chosen = i
	var advantage: int = best[chosen].value-best[baseline].value
	if joint_resources and chosen != baseline and baseline_option.kind == "evolve":
		var current_plan: Dictionary = best[baseline]; var alternative: Dictionary = best[chosen]
		var akey := [alternative.attack.prizes,alternative.attack.damage+alternative.attack.counters]
		var bkey := [current_plan.attack.prizes,current_plan.attack.damage+current_plan.attack.counters]
		if not Access._less(bkey,akey) and alternative.successor_value <= current_plan.successor_value and alternative.response.active_ko_exposure >= current_plan.response.active_ko_exposure:
			result.reason="preparation_value_unproven"; result.advantage=advantage; return result
	if frame.options[chosen].kind == "end_turn" and (baseline_option.kind == "evolve" or (baseline_option.kind == "attach_energy" and baseline_option.get("target_entity_serial") != initial.active)):
		result.reason = "preparation_floor_protected"; result.advantage = advantage; return result
	var margin := 60 if best[chosen].attack.conditional else 20
	if advantage >= margin: result.proposed_index = chosen; result.reason = "comparative_plan_advantage"
	result.required_margin = margin
	result.advantage = advantage
	return result
