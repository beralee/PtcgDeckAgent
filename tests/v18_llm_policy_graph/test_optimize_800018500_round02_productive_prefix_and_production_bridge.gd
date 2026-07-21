extends SceneTree

## Round02 regressions extracted from optimization21 seeds 800018505/507.
## The first half proves that the exact Rule-floor Teal Dance is a monotonic
## productive prefix of the already-legal knockout.  The second half drives the
## Iron Leaves interaction through prepare_decision and the production bridge;
## directly injecting _last_observation is intentionally not sufficient here.

const AbilityScript = preload("res://scripts/effects/pokemon_effects/AbilityBenchEnterSwitchAndMoveEnergy.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018500
const TEAL_UID := "CSV8C_028"
const TEAL_EFFECT_ID := "409898a79b38fe8ca279e7bdaf4fd52e"
const IRON_LEAVES_UID := "CSV7C_033"
const IRON_HANDS_UID := "CSV6C_051"
const PREFIX_CERT := "public_grass_draw_acceleration_before_secured_ko"
const IRON_CERT := "profiled_iron_leaves_same_turn_prize_suffix"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 4, "Round02 requires isolated profile version 4")
	_test_seed505_productive_prefix(profile)
	_test_seed505_fail_closed_boundaries(profile)
	_test_seed507_production_action_binding(profile)
	_test_seed507_real_snapshot_disproves_suffix(profile)
	if _failures.is_empty():
		print("V18CPG 800018500 round02 productive prefix + production bridge: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_seed505_productive_prefix(profile: Dictionary) -> void:
	var built := _seed505_candidates(profile)
	var prefix: Dictionary = built.get("prefix", {})
	var attack: Dictionary = built.get("attack", {})
	_check(not prefix.is_empty() and not attack.is_empty(), "seed505 fixture must expose exact Teal Dance and attack candidates")
	var registry := CapabilityRegistryScript.new()
	var advantage := registry.verify_route_advantage(prefix, attack, _seed505_facts(), profile)
	_check(bool(advantage.get("verified", false)), "exact executable Teal Dance must certify its productive same-turn KO prefix")
	_check(str(advantage.get("certificate_kind", "")) == PREFIX_CERT, "productive prefix must expose the dedicated audited certificate")
	_check(int(advantage.get("prizes_floor", 0)) == 2, "productive prefix must preserve the same two-prize KO floor")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety: Dictionary = strategy.call(
		"_validate_model_route_safety",
		str(attack.get("route_id", "")),
		built.get("pool", []),
		_seed505_facts(),
		str(attack.get("candidate_id", ""))
	)
	_check(not bool(safety.get("valid", true)), "terminal attack must not truncate the certified Teal Dance prefix")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "terminal truncation must fail through the shared suffix safety reason")


func _test_seed505_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var spent := _seed505_observation()
	spent["own"]["active"]["ability_used"] = true
	cases.append({"label": "ability already used", "observation": spent, "facts": _seed505_facts(), "actions": _seed505_actions()})
	var no_grass := _seed505_observation()
	no_grass["own"]["hand"] = []
	no_grass["own"]["hand_count"] = 0
	cases.append({"label": "no visible Grass Energy", "observation": no_grass, "facts": _seed505_facts(), "actions": _seed505_actions()})
	var lost_ko_actions := _seed505_actions()
	lost_ko_actions[1]["projected_knockout"] = false
	lost_ko_actions[1]["projected_damage"] = 60
	cases.append({"label": "original attack no longer knocks out", "observation": _seed505_observation(), "facts": _seed505_facts(), "actions": lost_ko_actions})
	var wrong_source_actions := _seed505_actions()
	wrong_source_actions[1]["source"] = "slot:other"
	wrong_source_actions[1]["source_card"] = _card_ref("CSV5C_010", "Pokemon")
	cases.append({"label": "original attack is no longer legal from the same source", "observation": _seed505_observation(), "facts": _seed505_facts(), "actions": wrong_source_actions})
	var hidden_boundary_actions := _seed505_actions()
	hidden_boundary_actions[0]["source_card"] = _card_ref(TEAL_UID, "Pokemon", TEAL_EFFECT_ID + "-unbound")
	cases.append({"label": "ability crosses an unbound hidden-result boundary", "observation": _seed505_observation(), "facts": _seed505_facts(), "actions": hidden_boundary_actions})
	for invalid: Dictionary in cases:
		var built := _build_candidates(
			invalid.get("observation", {}),
			invalid.get("facts", {}),
			invalid.get("actions", []),
			profile
		)
		var prefix: Dictionary = built.get("prefix", {})
		var attack: Dictionary = built.get("attack", {})
		var advantage := CapabilityRegistryScript.new().verify_route_advantage(prefix, attack, invalid.get("facts", {}), profile)
		_check(not bool(advantage.get("verified", false)), "%s must fail closed" % str(invalid.get("label", "invalid prefix")))


func _test_seed507_production_action_binding(profile: Dictionary) -> void:
	var fixture := _seed507_pre_action_fixture()
	var state: GameState = fixture.get("state")
	var iron_card: CardInstance = fixture.get("iron_card")
	var action := {"kind": "play_basic_to_bench", "card": iron_card}
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.configure_audit("round02-focused", "seed800018507", false)
	var action_id := strategy.stable_action_id_for_host(action)
	var decision := strategy.prepare_decision(state, 0, [action], {
		"rule_floor_action_id": action_id,
		"rule_floor_certificate": {"action_id": action_id, "scores": {action_id: 1000.0}},
	})
	_check(str(decision.get("owner", "")) == "local_gate", "seed507 production pre-action must be selected by local_gate")
	var binding: Variant = strategy.get("_pending_interaction_certificate_context")
	_check(binding is Dictionary and not (binding as Dictionary).is_empty(), "prepare_decision must freeze an action-bound filtered interaction context")
	if binding is Dictionary:
		_check(str((binding as Dictionary).get("action_id", "")) == action_id, "frozen interaction context must bind the exact selected action")

	var player: PlayerState = fixture.get("player")
	player.hand.erase(iron_card)
	var iron_slot := PokemonSlot.new()
	iron_slot.pokemon_stack.append(iron_card)
	iron_slot.turn_played = state.turn_number
	iron_slot.mark_entered_bench_from_hand(state.turn_number)
	player.bench.append(iron_slot)
	var ability := AbilityScript.new()
	var steps := ability.get_interaction_steps(iron_card, state)
	_check(steps.size() == 1, "real production Iron Leaves effect must expose its energy-transfer step")
	if steps.is_empty():
		return
	var items: Array = steps[0].get("items", [])
	var selected := strategy.pick_interaction_items(items, steps[0], {
		"game_state": state,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": iron_card,
		"pending_effect_slot": iron_slot,
		"pending_effect_ability_index": 0,
		"turn_plan": {},
		"turn_contract": {},
	})
	_check(selected.size() == 2 and items.all(func(item: Variant) -> bool: return item in selected), "production bridge must select both public Grass Energy")
	var audit: Variant = strategy.get("_audit")
	var records: Array[Dictionary] = audit.records() if audit != null and audit.has_method("records") else []
	_check(records.any(func(record: Dictionary) -> bool:
		return str(record.get("event_type", "")) == "module_verified_interaction_override" \
			and str(record.get("certificate_kind", "")) == IRON_CERT \
			and str(record.get("action_owner", "")) == "module_verified_upgrade"
	), "seed507 production bridge must emit the audited Iron Leaves certificate")


func _test_seed507_real_snapshot_disproves_suffix(profile: Dictionary) -> void:
	# Captured from the actual verified-local seed800018507 turn-11 bridge. The
	# selected action binding is valid, but Active Ogerpon + Bench Toedscruel hold
	# the only two Grass Energy and the seven-card hand has no Energy. Moving both
	# therefore cannot pay Prism Edge's GGC cost; the old 2+1 suffix premise is
	# false and ownership must remain with Rule.
	var fixture := _seed507_real_pre_action_fixture()
	var state: GameState = fixture.get("state")
	var iron_card: CardInstance = fixture.get("iron_card")
	var action := {"kind": "play_basic_to_bench", "card": iron_card}
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.configure_audit("round02-focused", "seed800018507-real", false)
	var action_id := strategy.stable_action_id_for_host(action)
	var decision := strategy.prepare_decision(state, 0, [action], {
		"rule_floor_action_id": action_id,
		"rule_floor_certificate": {"action_id": action_id, "scores": {action_id: 1000.0}},
	})
	_check(str(decision.get("owner", "")) == "local_gate", "real seed507 snapshot must still bind the selected local_gate action")
	var player: PlayerState = fixture.get("player")
	player.hand.erase(iron_card)
	var iron_slot := PokemonSlot.new()
	iron_slot.pokemon_stack.append(iron_card)
	iron_slot.turn_played = state.turn_number
	iron_slot.mark_entered_bench_from_hand(state.turn_number)
	player.bench.append(iron_slot)
	var steps := AbilityScript.new().get_interaction_steps(iron_card, state)
	_check(steps.size() == 1 and int(steps[0].get("max_select", 0)) == 2, "real seed507 snapshot must reproduce the exact two-item production step")
	if steps.is_empty():
		return
	var items: Array = steps[0].get("items", [])
	var selected := strategy.pick_interaction_items(items, steps[0], {
		"game_state": state,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": iron_card,
		"pending_effect_slot": iron_slot,
		"pending_effect_ability_index": 0,
		"turn_plan": {},
		"turn_contract": {},
	})
	_check(selected.size() < 2, "real seed507 must fail closed instead of inventing the missing third Energy")
	var audit: Variant = strategy.get("_audit")
	var records: Array[Dictionary] = audit.records() if audit != null and audit.has_method("records") else []
	_check(not records.any(func(record: Dictionary) -> bool:
		return str(record.get("event_type", "")) == "module_verified_interaction_override" \
			and str(record.get("certificate_kind", "")) == IRON_CERT
	), "disproven seed507 suffix must not emit module ownership")


func _seed505_candidates(profile: Dictionary) -> Dictionary:
	return _build_candidates(_seed505_observation(), _seed505_facts(), _seed505_actions(), profile)


func _build_candidates(observation: Dictionary, facts: Dictionary, actions: Array, profile: Dictionary) -> Dictionary:
	observation = observation.duplicate(true)
	observation["legal_actions"] = actions.duplicate(true)
	var scores := {"teal-dance": 10000.0, "secured-ko": 9000.0}
	var pool := RouteSearchScript.new().build_candidate_pool(observation, scores, {}, facts)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == "teal-dance"
	pool = CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
	var result := {"pool": pool, "prefix": {}, "attack": {}}
	for candidate: Dictionary in pool:
		if str(candidate.get("safe_prefix_action_id", "")) == "teal-dance":
			result["prefix"] = candidate
		elif str(candidate.get("safe_prefix_action_id", "")) == "secured-ko":
			result["attack"] = candidate
	return result


func _seed505_actions() -> Array:
	return [{
		"id": "teal-dance",
		"kind": "use_ability",
		"source": "slot:ogerpon",
		"source_card": _card_ref(TEAL_UID, "Pokemon", TEAL_EFFECT_ID),
		"ability_index": 0,
		"requires_interaction": true,
	}, {
		"id": "secured-ko",
		"kind": "attack",
		"source": "slot:ogerpon",
		"source_card": _card_ref(TEAL_UID, "Pokemon", TEAL_EFFECT_ID),
		"target": "slot:opponent-active",
		"attack_index": 0,
		"projected_damage": 180,
		"projected_knockout": true,
		"requires_interaction": false,
	}]


func _seed505_observation() -> Dictionary:
	return {
		"turn": {"number": 7, "current_player": 0, "deterministic_attack_window_open": true, "quotas": {"energy_available": true}},
		"own": {
			"prizes_remaining": 4,
			"deck_count": 18,
			"hand_count": 1,
			"hand": [_card_ref("CSVE1C_GRA", "Basic Energy", "", "G")],
			"active": _slot_ref("slot:ogerpon", TEAL_UID, 210, 2, false),
			"bench": [],
		},
		"opponent": {"prizes_remaining": 4, "active": _slot_ref("slot:opponent-active", IRON_HANDS_UID, 100, 2, false), "bench": []},
		"legal_actions": _seed505_actions(),
		"visibility": {"deck_order_visible": false, "opponent_hand_contents": false, "own_prize_identities": false},
	}


func _seed505_facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 180},
		"board": {"opponent_active_remaining_hp": 100},
		"prize": {"current_swing": 2, "win_now": false},
		"resources": {"energy_on_board": 3, "prizes_remaining": 4, "hand_size": 1, "deck_low": false},
		"turn": {"energy_available": true},
	}


func _seed507_pre_action_fixture() -> Dictionary:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 11
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = false
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	var fez := _pokemon_slot("Fezandipiti ex", "CSV8C", "135", 210, "ex", 0)
	var toedscruel := _pokemon_slot("Toedscruel", "CSV5C", "009", 120, "", 0)
	var ogerpon := _pokemon_slot("Teal Mask Ogerpon ex", "CSV8C", "028", 210, "ex", 0)
	toedscruel.attached_energy.append(_energy_instance(0))
	ogerpon.attached_energy.append(_energy_instance(0))
	player.active_pokemon = fez
	player.bench = [toedscruel, ogerpon]
	var iron_data := _pokemon_data("Iron Leaves ex", "CSV7C", "033", 220, "ex")
	iron_data.effect_id = "2e307380eb013c4e20db0a19816ba3b9"
	iron_data.abilities = [{"name": "Rapid Vernier", "text": ""}]
	iron_data.attacks = [{"name": "Prism Edge", "cost": "GGC", "damage": "180", "text": "", "is_vstar_power": false}]
	var iron_card := CardInstance.create(iron_data, 0)
	player.hand = [iron_card, _energy_instance(0), _dummy_card("Prime Catcher", 0), _dummy_card("Bug Catching Set", 0)]
	for index: int in 4:
		player.prizes.append(_dummy_card("Own Prize %d" % index, 0))
	var target := _pokemon_slot("Iron Hands ex", "CSV6C", "051", 230, "ex", 1)
	target.damage_counters = 160
	opponent.active_pokemon = target
	for index: int in 4:
		opponent.prizes.append(_dummy_card("Opponent Prize %d" % index, 1))
	return {"state": state, "player": player, "iron_card": iron_card}


func _seed507_real_pre_action_fixture() -> Dictionary:
	var fixture := _seed507_pre_action_fixture()
	var state: GameState = fixture.get("state")
	var player: PlayerState = fixture.get("player")
	var iron_card: CardInstance = fixture.get("iron_card")
	var fez: PokemonSlot = player.active_pokemon
	var toedscruel: PokemonSlot = player.bench[0]
	var ogerpon: PokemonSlot = player.bench[1]
	player.active_pokemon = ogerpon
	player.bench = [toedscruel, fez]
	player.hand = [
		iron_card,
		_dummy_card("Energy Switch", 0),
		_dummy_card("Area Zero Underdepths", 0),
		_dummy_card("Boss's Orders", 0),
		_pokemon_card("Toedscruel ex", "CSV5C", "010", 270, "ex", 0),
		_dummy_card("Iono", 0),
		_dummy_card("Professor's Research", 0),
	]
	state.energy_attached_this_turn = false
	return fixture


func _slot_ref(slot_id: String, uid: String, hp: int, prizes: int, ability_used: bool) -> Dictionary:
	return {"slot_id": slot_id, "pokemon": _card_ref(uid, "Pokemon"), "energy": [], "energy_count": 0, "damage": 0, "remaining_hp": hp, "max_hp": hp, "prize_count": prizes, "ability_used": ability_used}


func _card_ref(uid: String, type_name: String, effect_id: String = "", energy_symbol: String = "") -> Dictionary:
	var ref := {"uid": uid, "type": type_name, "effect_id": effect_id}
	if energy_symbol != "":
		ref["energy_provides"] = energy_symbol
		ref["energy_type"] = energy_symbol
	return ref


func _pokemon_data(name: String, set_code: String, card_index: String, hp: int, mechanic: String) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "G"
	data.hp = hp
	data.mechanic = mechanic
	data.set_code = set_code
	data.card_index = card_index
	return data


func _pokemon_slot(name: String, set_code: String, card_index: String, hp: int, mechanic: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_pokemon_data(name, set_code, card_index, hp, mechanic), owner))
	return slot


func _pokemon_card(name: String, set_code: String, card_index: String, hp: int, mechanic: String, owner: int) -> CardInstance:
	return CardInstance.create(_pokemon_data(name, set_code, card_index, hp, mechanic), owner)


func _energy_instance(owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = "Grass Energy"
	data.name_en = "Grass Energy"
	data.card_type = "Basic Energy"
	data.energy_type = "G"
	data.energy_provides = "G"
	data.set_code = "CSVE1C"
	data.card_index = "GRA"
	return CardInstance.create(data, owner)


func _dummy_card(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
