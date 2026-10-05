extends RefCounted
## Public effect composition. Every suffix is conditional on fresh observation.
const Access = preload("res://scripts/ai/ptcgdap/public/PublicAttackAccess.gd")
const PROFILE = "card-goals-v1"
const STRETCHER = "CSV8C_183"
const CHOICE_SOURCES = [STRETCHER, "30thC_102", "30thC_101", "CSV8C_158"]
const MAX_DEPTH = 5
const MAX_STATES = 384
const MAX_TOTAL_STATES = 2048
const BEAM = 12
static var _lines: Dictionary = {}

static func goal_lines(cards: Dictionary) -> Dictionary:
	if not _lines.is_empty(): return _lines
	for u: String in cards: _lines[u] = Access._printed_pressure(cards[u])
	for _n: int in range(3):
		var by_name := {}
		for u: String in cards:
			var c: Dictionary = cards[u]
			if c.get("from", "") != "": by_name[c["from"]] = maxi(by_name.get(c["from"], 0), _lines[u])
		for u: String in cards: _lines[u] = maxi(_lines[u], by_name.get(cards[u].name, 0))
	return _lines

static func _ids(state: Dictionary) -> Array:
	var ids: Array = state.board.keys(); ids.sort(); return ids

static func _sorted_cards(rows: Array) -> Array:
	var result := rows.duplicate()
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.serial < b.serial)
	return result

static func recoverable(uid: String, cards: Dictionary) -> bool:
	var c: Dictionary = cards.get(uid, {})
	return c.get("stage", -1) >= 0 or c.get("energy_model", "") == "basic"

static func _state(frame: Dictionary, cards: Dictionary) -> Dictionary:
	var state := Access._state(frame, cards)
	state.discard = frame.public_state.self.discard.duplicate(true)
	for e: Dictionary in frame.public_state.decision.entities:
		if state.board.has(int(e.entity_serial)):
			state.board[int(e.entity_serial)].information_blocked = e.ability_disabled
	state.checkpoint = false
	state.evolution_turn_available = not frame.public_state.decision.self.is_first_turn
	return state

static func features(state: Dictionary, cards: Dictionary) -> Dictionary:
	var ready := 0; var engines := 0; var stages := 0; var funded := 0
	var lines := goal_lines(cards)
	for e: Dictionary in state.board.values():
		var card: Dictionary = cards[e.uid]
		engines += int(not card.get("information_abilities", []).is_empty() and not e.get("information_blocked", false))
		if lines.get(e.uid, 0) < 180: continue
		stages += maxi(0, card.stage)
		ready += int(Access._pressure(e, cards) >= 180)
		var costs := []
		for a: Dictionary in card.attacks:
			if a.pressure >= 180: costs.append(a.cost)
		if costs.is_empty():
			for c: Dictionary in cards.values():
				if c.get("from", "") != card.name: continue
				for a: Dictionary in c.attacks:
					if a.pressure >= 180: costs.append(a.cost)
		if not costs.is_empty():
			var size := 32
			for cost: String in costs: size = mini(size, cost.length())
			funded += maxi(0, size - Access.energy_debt(costs, e.energies))
	return {"ready_attackers":ready,"active_pressure":Access._pressure(state.board[state.active],cards),
		"information_engines":engines,"evolution_progress":stages,"funding_progress":funded}

static func value(f: Dictionary, state: Dictionary) -> int:
	return f.ready_attackers*300 + int(f.active_pressure/2) + f.information_engines*70 + f.evolution_progress*50 + f.funding_progress*35 - state.spent*12

static func _needed(uid: String, state: Dictionary, cards: Dictionary) -> bool:
	var c: Dictionary = cards.get(uid,{})
	for h: Dictionary in state.hand:
		if h.local_card_uid == uid: return false
	if c.get("energy_model", "") == "basic":
		if not state.attach: return false
		for identity: int in _ids(state):
			var e: Dictionary = state.board[identity]
			if goal_lines(cards).get(e.uid,0) < 180: continue
			var sample: Dictionary = state.duplicate(true)
			sample.hand.append({"serial":-1,"local_card_uid":uid})
			var moved: Variant = Access._apply(sample,{"kind":"attach_energy","card_uid":uid,"card_serial":-1,"target":identity},cards)
			if not moved.is_empty() and features(moved,cards).funding_progress > features(state,cards).funding_progress: return true
		return false
	if c.get("from", "") == "": return false
	for e: Dictionary in state.board.values():
		if not e.played and not e.evolved and (state.evolution_turn_available or e.early) and c["from"] == cards[e.uid].name: return true
	return false

static func _actions(state: Dictionary, cards: Dictionary, acquisition := true) -> Array:
	var actions := []
	for h: Dictionary in _sorted_cards(state.hand):
		var c: Dictionary = cards.get(h.local_card_uid,{})
		for identity: int in _ids(state):
			var e: Dictionary = state.board[identity]
			if state.attach and c.get("energy_model", "") != "" and (identity == state.active or goal_lines(cards).get(e.uid,0) >= 150):
				actions.append({"kind":"attach_energy","card_serial":int(h.serial),"card_uid":h.local_card_uid,"target":identity})
			if not e.played and not e.evolved and (state.evolution_turn_available or e.early) and c.get("from", "") != "" and c["from"] == cards[e.uid].name and c.stage == cards[e.uid].stage+1:
				actions.append({"kind":"evolve","card_serial":int(h.serial),"card_uid":h.local_card_uid,"target":identity})
	var active: Dictionary = state.board[state.active]
	if state.retreat and "asleep" not in active.conditions and "paralyzed" not in active.conditions:
		for identity: int in _ids(state):
			if identity != state.active and Access._printed_pressure(cards[state.board[identity].uid]) >= 90:
				actions.append({"kind":"retreat","target":identity})
	if acquisition:
		var items := []
		for h: Dictionary in _sorted_cards(state.hand):
			if h.local_card_uid == STRETCHER: items.append(h)
		if not items.is_empty():
			var seen := {}; var discarded: Array = state.discard.duplicate()
			discarded.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.local_card_uid < b.local_card_uid if a.local_card_uid != b.local_card_uid else a.serial < b.serial)
			for h: Dictionary in discarded:
				var uid: String = h.local_card_uid
				if seen.has(uid) or not recoverable(uid,cards) or not _needed(uid,state,cards): continue
				seen[uid] = true
				actions.append({"kind":"recover_to_hand","card_serial":int(items[0].serial),"card_uid":STRETCHER,"recovered_serial":int(h.serial),"recovered_uid":uid})
	return actions

static func _apply(state: Dictionary, action: Dictionary, cards: Dictionary) -> Variant:
	if action.kind == "recover_to_hand":
		if not recoverable(action.recovered_uid,cards): return null
		var new: Dictionary = state.duplicate(true); var item: Variant = null; var recovered: Variant = null
		for h: Dictionary in new.hand:
			if h.serial == action.card_serial and h.local_card_uid == STRETCHER: item = h
		for h: Dictionary in new.discard:
			if h.serial == action.recovered_serial and h.local_card_uid == action.recovered_uid: recovered = h
		if item == null or recovered == null: return null
		new.hand.erase(item); new.discard.erase(recovered); new.hand.append(recovered); new.discard.append(item)
		new.spent += 1; new.steps.append(action.duplicate(true))
		return new
	var new: Variant = Access._apply(state,action,cards)
	if new.is_empty(): return null
	if action.kind == "retreat":
		var used: Array = new.steps[-1].discarded_energy_serials
		for e: Dictionary in state.board[state.active].energies:
			if e.serial in used: new.discard.append({"serial":int(e.serial),"local_card_uid":e.local_card_uid})
	if action.kind == "evolve" and not cards[action.card_uid].get("information_abilities",[]).is_empty(): new.checkpoint = true
	return new

static func _key(state: Dictionary) -> String:
	var board := []; var resources := []
	for identity: int in _ids(state):
		var e: Dictionary = state.board[identity]; var energies := []
		for x: Dictionary in _sorted_cards(e.energies): energies.append([int(x.serial),x.local_card_uid,int(x.units),x.types])
		board.append([identity,e.uid,e.evolved,e.played,energies])
	for zone: String in ["hand","discard"]:
		var rows := []
		for h: Dictionary in _sorted_cards(state[zone]): rows.append([int(h.serial),h.local_card_uid])
		resources.append(rows)
	return JSON.stringify([board,resources[0],resources[1],state.active,state.attach,state.retreat,state.checkpoint])

static func search(state: Dictionary, cards: Dictionary, acquisition := true, max_states := MAX_STATES) -> Dictionary:
	var queue := [state]; var seen := {}; var best: Variant = null; var expanded := 0
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front(); var signature := _key(current)
		if seen.has(signature) and seen[signature] <= current.spent: continue
		seen[signature] = current.spent; expanded += 1
		var f := features(current,cards)
		var row := {"value":value(f,current),"features":f,"steps":current.steps.duplicate(true),"resource_cost":current.spent,"checkpoint":current.checkpoint}
		if best == null or row.value > best.value: best = row
		if expanded >= max_states: return {"best":best,"expanded":expanded,"truncated":true,"exhaustive":false}
		if current.checkpoint or current.steps.size() >= MAX_DEPTH: continue
		var children := []
		for action: Dictionary in _actions(current,cards,acquisition):
			var child: Variant = _apply(current,action,cards)
			if child == null: continue
			var cf := features(child,cards)
			if action.kind in ["attach_energy","evolve"] and cf == f: continue
			children.append([value(cf,child),_key(child),child])
		children.sort_custom(func(a: Array,b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
		for row_index: int in range(mini(BEAM,children.size())): queue.append(children[row_index][2])
	return {"best":best,"expanded":expanded,"truncated":false,"exhaustive":false}

static func _bind(o: Dictionary,a: Dictionary) -> bool:
	if o.kind != a.kind or o.get("target_entity_serial") != a.get("target"): return false
	return a.kind == "retreat" or (o.get("card_serial") == a.get("card_serial") and o.get("card_uid") == a.get("card_uid"))

static func _information(frame: Dictionary, ordered: Array, state: Dictionary, cards: Dictionary) -> bool:
	if frame.public_state.self.deck_count < 2: return false
	for index: int in ordered:
		var o: Dictionary = frame.options[index]
		if o.kind == "use_ability":
			var e: Dictionary = state.board.get(o.get("source_entity_serial"),{})
			if not e.is_empty() and e.uid == o.get("source_uid") and o.get("ability_index") in cards[e.uid].get("information_abilities",[]): return true
		elif o.kind == "evolve":
			var e: Dictionary = state.board.get(o.get("target_entity_serial"),{}); var c: Dictionary = cards.get(o.get("card_uid"),{})
			if e.is_empty() or c.get("information_abilities",[]).is_empty() or e.played or e.evolved or c.get("from") != cards[e.uid].name or c.stage != cards[e.uid].stage+1: continue
			for h: Dictionary in state.hand:
				if h.serial == o.get("card_serial") and h.local_card_uid == o.get("card_uid"): return true
	return false

static func compare(frame: Dictionary, ordered: Array, base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result.merge({"profile":PROFILE,"card_goal_plans":[],"value_kind":"public_goal_progress_ordinal","expected_value_proven":false},true)
	if not base.accepted or not frame.public_state.has("decision"): return result
	if frame.select_semantics.max_count != 1: return result
	if frame.prompt_kind == "main" and frame.select_semantics.min_count != 1: return result
	var cards := Access.cards(); var initial := _state(frame,cards)
	if not initial.board.has(initial.active) or initial.board.size() != frame.public_state.self.active.size()+frame.public_state.self.bench.size(): return result
	var baseline: int = base.proposed_index; var option: Dictionary = frame.options[baseline]
	var first := []; var main: bool = frame.prompt_kind == "main"
	if main:
		if base.reason == "current_proven_finish" or _information(frame,ordered,initial,cards): return result
		if option.kind in ["use_ability","play_basic_to_bench"]: return result
		if option.kind == "play_trainer" and option.get("card_uid") != STRETCHER: return result
		for action: Dictionary in _actions(initial,cards):
			for index: int in ordered:
				var o: Dictionary = frame.options[index]
				var bound: bool = o.kind == "play_trainer" and o.get("card_uid") == STRETCHER and o.get("card_serial") == action.get("card_serial") if action.kind == "recover_to_hand" else _bind(o,action)
				if bound:
					var child: Variant = _apply(initial,action,cards)
					if child != null:
						first.append([index,child])
	elif frame.prompt_kind in ["search","recovery","effect_target"]:
		var sources := {}
		for index: int in ordered: sources[frame.options[index].get("source_uid")] = true
		if sources.size() != 1 or sources.keys()[0] not in CHOICE_SOURCES: return result
		var source: String = sources.keys()[0]
		for index: int in ordered:
			var o: Dictionary = frame.options[index]; var uid: Variant = o.get("card_uid"); var serial: Variant = o.get("card_serial")
			if o.kind not in ["search","recovery","effect_target"] or not cards.has(uid) or serial == null or o.get("target_entity_serial") != null: continue
			if source == STRETCHER:
				if not recoverable(uid,cards): continue
				var found := false
				for h: Dictionary in initial.discard:
					if h.serial == serial and h.local_card_uid == uid: found = true
				if not found: continue
			var held := false
			for h: Dictionary in initial.hand:
				if h.serial == serial: held = true
			if held: continue
			var child: Dictionary = initial.duplicate(true); var discarded := []
			for h: Dictionary in child.discard:
				if h.serial != serial: discarded.append(h)
			child.discard = discarded; child.hand.append({"serial":int(serial),"local_card_uid":uid})
			child.steps.append({"kind":"choose_to_hand","source_uid":source,"card_uid":uid,"card_serial":int(serial)})
			first.append([index,child])
	else: return result
	var plans := {}; var total := 0
	for entry: Array in first:
		if total >= MAX_TOTAL_STATES:
			result.merge({"reason":"card_goal_budget_unknown","card_goal_expanded":total},true); return result
		var index: int = entry[0]; var found := search(entry[1],cards,true,mini(MAX_STATES,MAX_TOTAL_STATES-total)); total += found.expanded
		if found.truncated:
			result.merge({"reason":"card_goal_budget_unknown","card_goal_expanded":total},true); return result
		var row: Dictionary = found.best.duplicate(true); row.first_index = index
		if not plans.has(index) or row.value > plans[index].value: plans[index] = row
	var rows := []; var indexes: Array = plans.keys(); indexes.sort()
	for index: int in indexes: rows.append(plans[index])
	result.merge({"card_goal_plans":rows,"card_goal_expanded":total,"requires_reobservation":true,"future_legality_proven":false},true)
	if plans.is_empty(): return result
	var reference: Variant = plans.get(baseline)
	if reference == null:
		if main and option.kind in ["attack","end_turn"]:
			var f := features(initial,cards); reference = {"value":value(f,initial),"features":f}
		else: return result
	var chosen := -1
	for index: int in ordered:
		if plans.has(index) and (chosen == -1 or plans[index].value > plans[chosen].value): chosen = index
	var best: Dictionary = plans[chosen]; var gain: int = best.value-reference.value; var productive := false
	if best.features.active_pressure < reference.features.active_pressure:
		result.reason = "card_goal_preserve_attack_access"; return result
	for name: String in ["ready_attackers","information_engines","evolution_progress","funding_progress"]:
		if best.features[name] > reference.features[name]: productive = true
	if productive and gain >= (40 if main else 20):
		result.merge({"proposed_index":chosen,"reason":"card_goal_resource_route","card_goal_advantage":gain,"card_goal_selected":best},true)
	return result
