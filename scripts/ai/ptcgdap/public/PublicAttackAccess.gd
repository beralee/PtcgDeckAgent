extends RefCounted
## Mirror of public_attack_access.py: conditional public plans, no engine access.
static var _cards: Dictionary = {}

static func cards() -> Dictionary:
	if _cards.is_empty():
		_cards = JSON.parse_string(FileAccess.get_file_as_string("res://contracts/ptcgdap/public_attack_access_catalog_v1.json")).cards
		# JSON numbers are floats; Array membership uses Variant types. This
		# reviewed integer field must match native integer option indexes.
		for uid: String in _cards:
			_cards[uid]["information_abilities"] = _cards[uid].get("information_abilities", []).map(func(i: Variant) -> int: return int(i))
	return _cards

static func _match(i: int, symbols: Array, units: Array, paid: Array, visited: Dictionary) -> bool:
	for j: int in units.size():
		if visited.has(j) or not (symbols[i] == "C" or symbols[i] in units[j] or "ANY" in units[j]): continue
		visited[j] = true
		if paid[j] < 0 or _match(paid[j], symbols, units, paid, visited):
			paid[j] = i
			return true
	return false

static func energy_debt(costs: Array, energies: Array) -> int:
	var units := []
	for e: Dictionary in energies:
		for _i: int in mini(int(e.units), 32): units.append(e.types)
	var best := 32
	for cost: String in costs:
		var symbols := []
		for c: String in cost:
			if c != "C": symbols.append(c)
		for c: String in cost:
			if c == "C": symbols.append(c)
		var paid := []; paid.resize(units.size()); paid.fill(-1)
		var matched := 0
		for i: int in symbols.size():
			if _match(i, symbols, units, paid, {}): matched += 1
		best = mini(best, symbols.size() - matched)
	return best

static func _pressure(entity: Dictionary, catalog: Dictionary) -> int:
	if "asleep" in entity.conditions or "paralyzed" in entity.conditions: return 0
	var pressure := 0
	for a: Dictionary in catalog.get(entity.uid, {}).get("attacks", []):
		if entity.costs.has(int(a.index)) and energy_debt(entity.costs[int(a.index)], entity.energies) == 0:
			pressure = maxi(pressure, int(a.pressure))
	return pressure

static func _resupply(entity: Dictionary, catalog: Dictionary) -> bool:
	var models := []; var special := 0
	for e: Dictionary in entity.energies:
		var model: String = catalog.get(e.local_card_uid, {}).get("energy_model", "")
		if model not in ["basic", "luminous", "neo_upper"]: return false
		models.append(model)
		if model != "basic": special += 1
	for i: int in models.size():
		var e: Dictionary = entity.energies[i]; var model: String = models[i]
		e.units = 2 if model == "neo_upper" and catalog[entity.uid].stage == 2 else 1
		if model == "basic": e.types = [catalog[e.local_card_uid].energy_type]
		else: e.types = ["ANY" if (model == "luminous" and special == 1) or (model == "neo_upper" and e.units == 2) else "C"]
	return true

static func _investment(entity: Dictionary, catalog: Dictionary) -> int:
	var c: Dictionary = catalog.get(entity.uid, {})
	return 30 * entity.energies.size() + 45 * maxi(0, int(c.get("stage", 0))) + 20 * int(c.get("engine", false))

static func _state(frame: Dictionary, catalog: Dictionary) -> Dictionary:
	var public: Dictionary = frame.public_state; var own: Dictionary = public.self
	var table := {}; var board := {}
	for e: Dictionary in public.decision.entities: table[int(e.entity_serial)] = e
	for slot: Dictionary in own.active + own.bench:
		var uid: String = slot.local_card_uid; var identity := int(slot.entity_serial)
		if not catalog.has(uid) or not table.has(identity) or slot.remaining_hp <= 0: continue
		var e: Dictionary = table[identity]; var costs := {}
		for a: Dictionary in e.attacks: costs[int(a.attack_index)] = a.cost_candidates.duplicate()
		board[identity] = {"uid": uid, "hp": int(slot.remaining_hp), "prize": int(slot.prize_value),
			"energies": e.energies.duplicate(true), "conditions": e.conditions.duplicate(),
			"retreat": int(e.effective_retreat_cost), "played": e.played_this_turn, "evolved": e.evolved_this_turn,
			"early": e.early_evolution_allowed, "costs": costs}
	var active: Variant = int(own.active[0].entity_serial) if not own.active.is_empty() else null
	var current_pressure := 0
	if board.has(active):
		for o: Dictionary in frame.options:
			if o.kind == "attack" and o.get("source_uid") == board[active].uid:
				for a: Dictionary in catalog[board[active].uid].attacks:
					if a.index == o.get("attack_index"): current_pressure = maxi(current_pressure, int(a.pressure))
	return {"board": board, "active": active, "current_pressure": current_pressure,
		"hand": own.hand.duplicate(true), "attach": own.turn.manual_attachment_available,
		"retreat": own.turn.retreat_available, "manual": 0, "retreat_count": 0, "spent": 0, "steps": []}

static func _actions(state: Dictionary, catalog: Dictionary) -> Array:
	var actions := []; var hand: Array = state.hand.duplicate(); var identities: Array = state.board.keys()
	var potential := {}
	for identity: int in identities: potential[identity] = _potential(state.board[identity], state.hand, catalog)
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.serial < b.serial)
	identities.sort()
	for h: Dictionary in hand:
		var card: Dictionary = catalog.get(h.local_card_uid, {})
		for identity: int in identities:
			var entity: Dictionary = state.board[identity]
			if state.attach and not str(card.get("energy_model", "")).is_empty() and (identity == state.active or potential[identity] >= 150):
				actions.append({"kind": "attach_energy", "card_serial": int(h.serial), "card_uid": h.local_card_uid, "target": identity})
			if not entity.played and not entity.evolved and not str(card.get("from", "")).is_empty() and card["from"] == catalog[entity.uid].name and card.stage == catalog[entity.uid].stage + 1 and _printed_pressure(card) >= 150:
				actions.append({"kind": "evolve", "card_serial": int(h.serial), "card_uid": h.local_card_uid, "target": identity})
	var active: Dictionary = state.board.get(state.active, {})
	if not active.is_empty() and state.retreat and "asleep" not in active.conditions and "paralyzed" not in active.conditions:
		for identity: int in identities:
			if identity != state.active and potential[identity] >= 150: actions.append({"kind": "retreat", "target": identity})
	return actions

static func _printed_pressure(card: Dictionary) -> int:
	var value := 0
	for a: Dictionary in card.get("attacks", []): value = maxi(value, int(a.pressure))
	return value

static func _potential(entity: Dictionary, hand: Array, catalog: Dictionary) -> int:
	var printed: Dictionary = catalog.get(entity.uid, {}); var value := _printed_pressure(printed)
	if not entity.played and not entity.evolved:
		for h: Dictionary in hand:
			var c: Dictionary = catalog.get(h.local_card_uid, {})
			if not str(c.get("from", "")).is_empty() and c["from"] == printed.get("name"): value = maxi(value, _printed_pressure(c))
	return value

static func _less(a: Array, b: Array) -> bool:
	for i: int in mini(a.size(), b.size()):
		if a[i] == b[i]: continue
		if a[i] is Array: return _less(a[i], b[i])
		return a[i] < b[i]
	return a.size() < b.size()

static func _apply(state: Dictionary, proposed: Dictionary, catalog: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true); var action: Dictionary = proposed.duplicate(true)
	var kind: String = action.kind; var target: Dictionary = next.board.get(action.target, {})
	if target.is_empty(): return {}
	if kind in ["attach_energy", "evolve"]:
		var found := false
		for h: Dictionary in next.hand:
			if h.serial == action.card_serial and h.local_card_uid == action.card_uid: found = true
		if not found: return {}
		var observed: Array = target.energies.duplicate(true)
		if not _resupply(target, catalog) or target.energies != observed: return {}
		if kind == "attach_energy":
			if not next.attach: return {}
			target.energies.append({"serial": action.card_serial, "local_card_uid": action.card_uid, "units": 1, "types": ["C"]})
			next.attach = false; next.manual += 1; next.spent += 1
		else:
			var card: Dictionary = catalog[action.card_uid]; var old: Dictionary = catalog[target.uid]
			if target.played or target.evolved or card["from"] != old.name: return {}
			target.hp += int(card.hp) - int(old.hp); target.uid = action.card_uid
			target.evolved = true; target.conditions = []; target.costs = {}
			for a: Dictionary in card.attacks: target.costs[int(a.index)] = [a.cost]
			target.retreat = maxi(0, target.retreat + int(card.retreat) - int(old.retreat)); next.spent += 1
		if not _resupply(target, catalog): return {}
		var hand := []
		for h: Dictionary in next.hand:
			if h.serial != action.card_serial: hand.append(h)
		next.hand = hand
	elif kind == "retreat":
		var active: Dictionary = next.board.get(next.active, {})
		if active.is_empty() or not next.retreat or next.active == action.target or "asleep" in active.conditions or "paralyzed" in active.conditions: return {}
		var energies: Array = active.energies; var cost: int = active.retreat
		if energies.size() > 8: return {}
		var best := []; var best_mask := 0
		for mask: int in range(1 << energies.size()):
			var serials := []; var units := 0
			for i: int in energies.size():
				if mask & (1 << i):
					units += int(energies[i].units); serials.append(int(energies[i].serial))
			if units < cost: continue
			serials.sort(); var score := [serials.size(), units, serials, mask]
			if best.is_empty() or _less(score, best): best = score; best_mask = mask
		if best.is_empty(): return {}
		var left := []
		for i: int in energies.size():
			if not best_mask & (1 << i): left.append(energies[i])
		active.energies = left
		if not _resupply(active, catalog): return {}
		active.conditions = []; next.active = action.target; next.retreat = false
		next.retreat_count += 1; next.spent += int(best[0]) + 1
		action.discarded_energy_serials = best[2]
	else: return {}
	next.steps.append(action)
	return next

static func _plan(state: Dictionary, initial: Dictionary, first: int, catalog: Dictionary) -> Dictionary:
	var pressure := _pressure(state.board[state.active], catalog)
	if pressure < 150: return {}
	var base: int = initial.current_pressure
	if state.active == initial.active and state.board[state.active].uid == initial.board[initial.active].uid and base == 0 and _pressure(initial.board[initial.active], catalog) > 0: return {}
	if pressure <= base: return {}
	var successor := 0; var reserve := 0
	for identity: int in state.board:
		if identity == state.active: continue
		successor = maxi(successor, _pressure(state.board[identity], catalog)); reserve += _investment(state.board[identity], catalog)
	return {"first_index": first, "attacker_entity_serial": state.active, "steps": state.steps,
		"pressure": pressure, "attack_gain": pressure - base, "successor_pressure": successor,
		"reserve_value": reserve, "resource_cost": state.spent, "manual_attachments": state.manual,
		"retreats": state.retreat_count, "conditional_future": true,
		"assumptions": ["future_window_legality", "attack_effects_and_opponent_response_unresolved"],
		"score": [pressure, successor, -state.spent, reserve, -state.steps.size()]}

static func plan(frame: Dictionary) -> Dictionary:
	# Host validates the public frame before calling this internal module.
	if not frame.get("public_state", {}).has("decision"): return {"accepted": false, "reason": "unqualified_public_position", "plans": []}
	if frame.prompt_kind != "main": return {"accepted": false, "reason": "unsupported_planning_window", "plans": []}
	var catalog := cards(); var checkpoints := []
	var own_board := {}
	for zone: String in ["active", "bench"]:
		for slot: Dictionary in frame.public_state.self[zone]: own_board[slot.entity_serial] = slot.local_card_uid
	if frame.public_state.self.deck_count > 0:
		for option: Dictionary in frame.options:
			if option.kind == "use_ability" and own_board.has(option.get("source_entity_serial")) and own_board[option.source_entity_serial] == option.get("source_uid") and frame.public_state.self.deck_count >= catalog.get(option.get("source_uid"), {}).get("information_minimum_deck_count", 0) and option.get("ability_index") in catalog.get(option.get("source_uid"), {}).get("information_abilities", []):
				checkpoints.append({"entity_serial": option.get("source_entity_serial"), "source_uid": option.source_uid, "ability_index": option.ability_index})
	if not checkpoints.is_empty():
		checkpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entity_serial < b.entity_serial or (a.entity_serial == b.entity_serial and a.ability_index < b.ability_index))
		return {"accepted": true, "reason": "information_checkpoint", "plans": [], "expanded": 0, "checkpoints": checkpoints, "current_window_only": true, "stale_plan_has_authority": false}
	var initial := _state(frame, catalog)
	if not initial.board.has(initial.active): return {"accepted": false, "reason": "unknown_active_capability", "plans": []}
	var ceiling := 0
	for e: Dictionary in initial.board.values(): ceiling = maxi(ceiling, _potential(e, initial.hand, catalog))
	if ceiling < 150 or ceiling <= initial.current_pressure:
		return {"accepted": true, "reason": "", "plans": [], "expanded": 0, "current_window_only": true, "stale_plan_has_authority": false}
	var d: Dictionary = frame.public_state.decision
	if d.self.is_first_turn and d.current_player_index == d.first_player_index: return {"accepted": false, "reason": "first_player_attack_blocked", "plans": []}
	var best := {}; var expanded := 0
	for action: Dictionary in _actions(initial, catalog):
		for option: Dictionary in frame.options:
			if option.kind != action.kind: continue
			if action.kind == "retreat" and option.get("target_entity_serial") != action.target: continue
			if action.kind != "retreat" and (option.get("card_serial") != action.card_serial or option.get("card_uid") != action.card_uid or option.get("target_entity_serial") != action.target): continue
			var first := int(option.index); var child := _apply(initial, action, catalog)
			if child.is_empty(): continue
			var queue := [child]
			while not queue.is_empty():
				var state: Dictionary = queue.pop_back(); expanded += 1
				if expanded > 4096: return {"accepted": false, "reason": "planning_budget_exceeded", "plans": [], "expanded": expanded}
				var row := _plan(state, initial, first, catalog)
				if not row.is_empty() and (not best.has(first) or _less(best[first].score, row.score)): best[first] = row
				if state.steps.size() >= 3: continue
				for followup: Dictionary in _actions(state, catalog):
					if not row.is_empty() and followup.kind != "evolve": continue
					var next := _apply(state, followup, catalog)
					if not next.is_empty(): queue.append(next)
	var plans := []; var indexes: Array = best.keys(); indexes.sort()
	for i: int in indexes: plans.append(best[i])
	return {"accepted": true, "reason": "", "plans": plans, "expanded": expanded, "current_window_only": true, "stale_plan_has_authority": false}

static func fact(frame: Dictionary, option: Variant, name: String) -> Variant:
	var result: Dictionary = frame.get("_derived_access", {})
	if result.is_empty(): result = plan(frame)
	if not result.get("accepted", false) or not option is Dictionary: return null
	var row := {}; var best := []
	for p: Dictionary in result.plans:
		if int(p.first_index) == int(option.index): row = p
		if best.is_empty() or _less(best, p.score): best = p.score
	if row.is_empty(): return null
	if name == "decision.option.access_gain": return row.attack_gain
	if name == "decision.option.access_pressure": return row.pressure
	if name == "decision.option.access_resource_cost": return row.resource_cost
	if name == "decision.option.access_best": return row.score == best
	return null

static func uses_attack_access(value: Variant) -> bool:
	if value is Dictionary:
		if str(value.get("fact", "")).begins_with("decision.option.access_"): return true
		for child: Variant in value.values():
			if (child is Dictionary or child is Array) and uses_attack_access(child): return true
	elif value is Array:
		for child: Variant in value:
			if uses_attack_access(child): return true
	return false
