extends SceneTree

const ActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const ObservationGatewayScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const FactBuilderScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const DynamicCostScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGDynamicAttackCost.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const BLOODMOON_UID := "CSV8C_172"
const BLOODMOON_EFFECT_ID := "f2afef80b13b8f6a071facbcade0251c"
const ENERGY_UID := "CSVE1C_GRA"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_public_cost_table_and_real_legal_actions()
	_test_recalculation_after_opponent_prize_change()
	_test_frontier_blocks_redundant_active_attachment()
	_test_paid_bench_bloodmoon_is_visible_on_pivot_candidate()
	_test_unrelated_five_colorless_attacker_is_unchanged()
	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty():
		print("V18CPG Bloodmoon dynamic attack cost: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG Bloodmoon dynamic attack cost: FAIL (%d)" % _failures.size())
	quit(1)


func _test_public_cost_table_and_real_legal_actions() -> void:
	for opponent_prizes_remaining: int in range(6, 0, -1):
		var required := opponent_prizes_remaining - 1
		var exact := _state(opponent_prizes_remaining, required, true)
		var exact_gsm := _gsm(exact)
		var exact_actions: Array[Dictionary] = ActionBuilderScript.new().build_actions(
			exact_gsm,
			0,
			false
		)
		var exact_observation := ObservationGatewayScript.new().build(
			exact,
			0,
			exact_actions
		)
		var exact_facts := FactBuilderScript.new().build(exact_observation)
		var exact_certificate: Dictionary = exact_facts.get("attack", {}).get(
			"dynamic_cost",
			{}
		)
		var exact_executed := exact_gsm.use_attack(0, 0)
		_check(
			int(exact_certificate.get("effective_energy_required", -1)) == required,
			"opponent prizes %d must make Blood Moon cost %d" % [
				opponent_prizes_remaining,
				required,
			]
		)
		_check(
			int(exact_certificate.get("opponent_prizes_taken", -1)) \
				== 6 - opponent_prizes_remaining,
			"the certificate must expose the public prize discount source"
		)
		_check(
			bool(exact_certificate.get("cost_ready", false)) \
				and bool(exact_certificate.get("engine_confirms_cost_paid", false)) \
				and bool(exact_facts.get("attack", {}).get("ready", false)) \
				and exact_executed \
				and exact.players[1].active_pokemon.damage_counters == 240,
			"exactly %d Energy must expose and execute Blood Moon at opponent prizes %d" % [
				required,
				opponent_prizes_remaining,
			]
		)

		if required <= 0:
			continue
		var short := _state(opponent_prizes_remaining, required - 1, true)
		var short_gsm := _gsm(short)
		var short_actions: Array[Dictionary] = ActionBuilderScript.new().build_actions(
			short_gsm,
			0,
			false
		)
		var short_observation := ObservationGatewayScript.new().build(
			short,
			0,
			short_actions
		)
		var short_facts := FactBuilderScript.new().build(short_observation)
		var short_certificate: Dictionary = short_facts.get("attack", {}).get(
			"dynamic_cost",
			{}
		)
		var short_executed := short_gsm.use_attack(0, 0)
		_check(
			int(short_certificate.get("energy_deficit", -1)) == 1 \
				and not bool(short_certificate.get("cost_ready", true)) \
				and not bool(short_facts.get("attack", {}).get("ready", true)) \
				and not short_executed \
				and short.players[1].active_pokemon.damage_counters == 0,
			"one Energy short must remain non-executable at opponent prizes %d" \
				% opponent_prizes_remaining
		)


func _test_recalculation_after_opponent_prize_change() -> void:
	var state := _state(4, 2, true)
	var gateway := ObservationGatewayScript.new()
	var before_gsm := _gsm(state)
	var before_actions: Array[Dictionary] = ActionBuilderScript.new().build_actions(
		before_gsm,
		0,
		false
	)
	var before := gateway.build(state, 0, before_actions)
	var before_facts := FactBuilderScript.new().build(before)
	_check(
		int(before_facts.get("attack", {}).get("energy_deficit", -1)) == 1 \
			and not bool(before_facts.get("attack", {}).get("ready", true)),
		"two Energy must be one short while the opponent has 4 Prizes remaining"
	)

	state.players[1].prizes.pop_back()
	var after_gsm := _gsm(state)
	var after_actions: Array[Dictionary] = ActionBuilderScript.new().build_actions(
		after_gsm,
		0,
		false
	)
	var after := gateway.build(state, 0, after_actions)
	var after_facts := FactBuilderScript.new().build(after)
	_check(
		int(after_facts.get("attack", {}).get("effective_energy_required", -1)) == 2 \
			and int(after_facts.get("attack", {}).get("energy_deficit", -1)) == 0 \
			and bool(after_facts.get("attack", {}).get("ready", false)),
		"the next public observation must immediately turn the same two Energy into a legal attack"
	)


func _test_frontier_blocks_redundant_active_attachment() -> void:
	var observation := {
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {"energy_available": true, "supporter_available": true},
		},
		"own": {
			"prizes_remaining": 3,
			"deck_count": 20,
			"hand": [_energy_card()],
			"hand_count": 1,
			"active": _public_slot(
				"slot:bloodmoon",
				BLOODMOON_UID,
				BLOODMOON_EFFECT_ID,
				[_energy_card(), _energy_card()]
			),
			"bench": [],
		},
		"opponent": {
			"prizes_remaining": 3,
			"active": {
				"slot_id": "slot:target",
				"pokemon": {"uid": "TARGET"},
				"remaining_hp": 240,
				"prize_count": 2,
			},
			"bench": [],
		},
		"legal_actions": [
			{
				"id": "attach:redundant",
				"kind": "attach_energy",
				"card": _energy_card(),
				"target": "slot:bloodmoon",
			},
			{
				"id": "attack:bloodmoon",
				"kind": "attack",
				"source": "slot:bloodmoon",
				"source_card": _card(BLOODMOON_UID, BLOODMOON_EFFECT_ID),
				"attack_index": 0,
				"projected_damage": 240,
				"projected_knockout": true,
			},
		],
	}
	var facts := FactBuilderScript.new().build(observation)
	var pool := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"attach:redundant": 1000.0, "attack:bloodmoon": 900.0},
		{},
		facts
	)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		pool,
		observation,
		facts,
		{},
		{}
	)
	var attach := _candidate(annotated, "attach:redundant")
	var attack := _candidate(annotated, "attack:bloodmoon")
	var attachment_annotation: Dictionary = attach.get("module_annotations", {}).get(
		DynamicCostScript.MODULE_ID,
		{}
	)
	var registry := CapabilityRegistryScript.new()
	var attack_advantage := registry.verify_route_advantage(
		attack,
		attach,
		facts,
		{}
	)
	var redundant_switch := registry.validate_route_switch(
		attach,
		attack,
		facts,
		{}
	)
	var strategy := StrategyScript.new()
	strategy.set("_profile", {})
	var automatic_upgrade: Dictionary = strategy.call(
		"_find_module_verified_upgrade",
		annotated,
		facts
	)
	_check(
		bool(attachment_annotation.get("redundant_active_cost_attachment", false)),
		"an attachment to already-paid active Bloodmoon must be marked redundant"
	)
	_check(
		bool(attack_advantage.get("verified", false)) \
			and str(attack_advantage.get("certificate_kind", "")) \
				== "public_dynamic_cost_ready_attack_over_redundant_attachment",
		"a legal Blood Moon must own execution over a redundant same-Pokemon attachment"
	)
	_check(
		not bool(redundant_switch.get("valid", true)) \
			and str(redundant_switch.get("reason", "")) \
				== "dynamic_attack_cost_already_paid",
		"the execution safety layer must reject re-attaching to an already-paid active Bloodmoon"
	)
	_check(
		str(automatic_upgrade.get("safe_prefix_action_id", "")) \
			== "attack:bloodmoon",
		"the V18 base must autonomously execute Blood Moon when Rule ranks a redundant attachment first"
	)
	_check(
		bool(strategy.call("_can_apply_initial_module_upgrade", automatic_upgrade)),
		"the same execution certificate must also be valid on the first observation of a match"
	)


func _test_unrelated_five_colorless_attacker_is_unchanged() -> void:
	var observation := {
		"turn": {"quotas": {}},
		"own": {
			"active": _public_slot(
				"slot:ordinary",
				"ORDINARY_5C",
				"ordinary_effect",
				[_energy_card(), _energy_card()]
			),
			"bench": [],
		},
		"opponent": {"prizes_remaining": 3},
		"legal_actions": [],
	}
	var snapshot := DynamicCostScript.new().public_snapshot(observation)
	_check(
		(snapshot.get("active", {}) as Dictionary).is_empty() \
			and (snapshot.get("cards", []) as Array).is_empty(),
		"the Bloodmoon-specific public rule must not discount unrelated 5C attackers"
	)


func _test_paid_bench_bloodmoon_is_visible_on_pivot_candidate() -> void:
	var observation := {
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {"retreat_available": true},
		},
		"own": {
			"active": _public_slot("slot:pivot", "PIVOT", "pivot_effect", []),
			"bench": [_public_slot(
				"slot:bloodmoon",
				BLOODMOON_UID,
				BLOODMOON_EFFECT_ID,
				[_energy_card(), _energy_card()]
			)],
		},
		"opponent": {"prizes_remaining": 3},
		"legal_actions": [{
			"id": "retreat:to-bloodmoon",
			"kind": "retreat",
			"target": "slot:bloodmoon",
		}],
	}
	var facts := FactBuilderScript.new().build(observation)
	var pool := RouteSearchScript.new().build_candidate_pool(
		observation,
		{"retreat:to-bloodmoon": 0.0},
		{},
		facts
	)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(
		pool,
		observation,
		facts,
		{},
		{}
	)
	var pivot := _candidate(annotated, "retreat:to-bloodmoon")
	var annotation: Dictionary = pivot.get("module_annotations", {}).get(
		DynamicCostScript.MODULE_ID,
		{}
	)
	var target_after: Dictionary = annotation.get("target_after", {}) \
		if annotation.get("target_after", {}) is Dictionary else {}
	_check(
		bool(annotation.get("attack_paid_after_pivot", false)) \
			and int(target_after.get("effective_energy_required", -1)) == 2 \
			and int(target_after.get("energy_deficit", -1)) == 0,
		"a pivot candidate must expose that a two-Energy Bloodmoon is fully paid when the opponent has 3 Prizes"
	)


func _state(
	opponent_prizes_remaining: int,
	energy_count: int,
	use_real_bloodmoon: bool
) -> GameState:
	var state := GameState.new()
	state.players = [PlayerState.new(), PlayerState.new()]
	for index: int in state.players.size():
		state.players[index].player_index = index
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	var bloodmoon_data := _load_real_card(BLOODMOON_UID) if use_real_bloodmoon \
		else _pokemon_card("Ordinary 5C", "ORDINARY_5C", "ordinary_effect", 260)
	var bloodmoon := PokemonSlot.new()
	bloodmoon.pokemon_stack.append(CardInstance.create(bloodmoon_data, 0))
	for index: int in energy_count:
		bloodmoon.attached_energy.append(CardInstance.create(_basic_energy(), 0))
	state.players[0].active_pokemon = bloodmoon
	state.players[1].active_pokemon = _target()
	_fill_prizes(state.players[0], 3, "OWN_PRIZE")
	_fill_prizes(state.players[1], opponent_prizes_remaining, "OPP_PRIZE")
	state.players[0].deck = [_filler("OWN_DRAW", 0)]
	state.players[1].deck = [_filler("OPP_DRAW", 1)]
	return state


func _gsm(state: GameState) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(state.players[0].active_pokemon.get_card_data())
	return gsm


func _load_real_card(uid: String) -> CardData:
	var parts := uid.split("_", false, 1)
	var path := "res://data/bundled_user/cards/%s_%s.json" % [parts[0], parts[1]]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon_card(name: String, uid: String, effect_id: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.effect_id = effect_id
	var parts := uid.split("_", false, 1)
	card.set_code = parts[0] if not parts.is_empty() else uid
	card.card_index = parts[1] if parts.size() > 1 else "001"
	card.attacks = [{
		"name": "Five Colorless",
		"cost": "CCCCC",
		"damage": "240",
		"text": "",
		"is_vstar_power": false,
	}]
	return card


func _basic_energy() -> CardData:
	var card := CardData.new()
	card.name_en = "Grass Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "G"
	card.energy_provides = "G"
	card.set_code = "CSVE1C"
	card.card_index = "GRA"
	return card


func _target() -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(
		_pokemon_card("Public target", "TARGET_001", "target_effect", 300),
		1
	))
	return slot


func _fill_prizes(player: PlayerState, count: int, prefix: String) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler("%s_%d" % [prefix, index], player.player_index))


func _filler(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Item"
	card.set_code = "TEST"
	card.card_index = name.sha256_text().substr(0, 8)
	return CardInstance.create(card, owner)


func _public_slot(
	slot_id: String,
	uid: String,
	effect_id: String,
	energy: Array
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid, effect_id),
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
	}


func _card(uid: String, effect_id: String = "") -> Dictionary:
	return {
		"uid": uid,
		"effect_id": effect_id,
		"name": "Bloodmoon Ursaluna ex" if uid == BLOODMOON_UID else uid,
		"type": "Pokemon",
	}


func _energy_card() -> Dictionary:
	return {
		"uid": ENERGY_UID,
		"name": "Grass Energy",
		"type": "Basic Energy",
		"energy_type": "G",
		"energy_provides": "G",
	}


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
