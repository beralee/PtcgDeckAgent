extends SceneTree

const ShapeScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const BenchDamageScript = preload("res://scripts/effects/pokemon_effects/AttackTargetOpponentBenchDamage.gd")
const ActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

class LocalCertificateStrategy:
	extends RefCounted
	var parameters: Dictionary = {}

	func get_runtime_kind() -> String:
		return "v18_conditional_policy"

	func get_v18cpg_action_certificate_parameters() -> Dictionary:
		return parameters.duplicate(true)

var _failures: Array[String] = []


func _initialize() -> void:
	var module = ShapeScript.new()
	module.configure("partner_chain")
	var profile := _profile()
	_validate_engine_builder_seed409_shape(profile)
	var selected := _postwick_candidate()
	var rule_floor := _rule_attack_candidate()
	var certificate: Dictionary = module.verify_route_advantage(selected, rule_floor, {}, profile)
	_check(bool(certificate.get("verified", false)), "exact Postwick -> Zacian attack0 breakpoint must verify")
	_check(str(certificate.get("certificate_kind", "")) == "public_partner_same_turn_prize_breakpoint", \
		"certificate kind must remain explicit")
	_check(int(certificate.get("damage_floor", 0)) == 90, "engine damage floor must remain 90")
	_check(int(certificate.get("dominated_damage", 0)) == 60, "Rule damage floor must remain 60")

	_negative_case(module, profile, selected, rule_floor, "wrong booster", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["prefix"] as Dictionary)["card_uid"] = "WRONG"
	)
	_negative_case(module, profile, selected, rule_floor, "wrong replaced stadium", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["prefix"] as Dictionary)["replaced_stadium_uid"] = "WRONG"
	)
	_negative_case(module, profile, selected, rule_floor, "wrong attacker", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["suffix"] as Dictionary)["attacker_uid"] = "WRONG"
	)
	_negative_case(module, profile, selected, rule_floor, "wrong attack index", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["suffix"] as Dictionary)["attack_index"] = 1
	)
	_negative_case(module, profile, selected, rule_floor, "Rule floor not exact", func(_candidate: Dictionary, top: Dictionary) -> void:
		top["engine_rule_floor_exact"] = false
	)
	_negative_case(module, profile, selected, rule_floor, "Rule already has KO", func(_candidate: Dictionary, top: Dictionary) -> void:
		(top["action_ref"] as Dictionary)["projected_knockout"] = true
	)
	_negative_case(module, profile, selected, rule_floor, "after damage misses HP", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["after"] as Dictionary)["effective_damage"] = 80
	)
	_negative_case(module, profile, selected, rule_floor, "after attack unpayable", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["after"] as Dictionary)["attack_payable"] = false
	)
	_negative_case(module, profile, selected, rule_floor, "damage cancelled", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["after"] as Dictionary)["damage_cancelled"] = true
	)
	_negative_guard_case(module, profile, selected, rule_floor, "survival_hook", true)
	_negative_guard_case(module, profile, selected, rule_floor, "damage_reactive_hook", true)
	_negative_guard_case(module, profile, selected, rule_floor, "random", true)
	_negative_guard_case(module, profile, selected, rule_floor, "hidden_info", true)
	_negative_guard_case(module, profile, selected, rule_floor, "interaction_suffix_bound", false)
	_negative_guard_case(module, profile, selected, rule_floor, "displaced_suffix_dominates", true)
	_negative_case(module, profile, selected, rule_floor, "active interaction changes damage", func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["suffix"] as Dictionary)["active_damage_invariant_under_interaction"] = false
	)

	var bench_effect = BenchDamageScript.new(30, 0)
	_check(bench_effect.active_damage_is_invariant_under_interaction(0), \
		"Hop's Zacian Bench target choice must declare Active damage invariance")
	_check(not bench_effect.active_damage_is_invariant_under_interaction(1), \
		"interaction invariant must stay bound to the exact attack index")

	var strategy = StrategyScript.new()
	var without_local := selected.duplicate(true)
	without_local.erase("local_certificates")
	var with_local_frontier: Array[Dictionary] = [selected]
	var without_local_frontier: Array[Dictionary] = [without_local]
	var compact_with: Variant = strategy.call("_compact_frontier_for_model", with_local_frontier)
	var compact_without: Variant = strategy.call("_compact_frontier_for_model", without_local_frontier)
	_check(JSON.stringify(compact_with) == JSON.stringify(compact_without), \
		"local breakpoint proof must add zero model-wire bytes")
	strategy.configure_profile(profile)
	var profile_wire: Dictionary = strategy.call("_profile_summary_for_model", {})
	_check(not JSON.stringify(profile_wire).contains("same_turn_stadium_attack_breakpoint"), \
		"local engine certificate parameters must not enter the model-facing profile")
	_check(not JSON.stringify(profile_wire).contains("CSV3C_129"), \
		"replaced Stadium identity must stay off the model wire")
	var safety := {"advantage": certificate}
	_check(bool(strategy.call("_can_apply_autonomous_module_upgrade", selected, rule_floor, {}, safety)), \
		"the exact public breakpoint must be an autonomous local upgrade")

	var filler_a := {"candidate_id": "a", "route_id": "route:attack_pressure", "base_score": 1000.0}
	var filler_b := {"candidate_id": "b", "route_id": "route:develop", "base_score": 900.0}
	var low_breakpoint := selected.duplicate(true)
	low_breakpoint["base_score"] = -100.0
	var pruned: Array[Dictionary] = RouteSearchScript.new().prune_frontier(
		[filler_a, filler_b, low_breakpoint], 2
	)
	_check(_contains_candidate(pruned, str(selected.get("candidate_id", ""))), \
		"engine-certified Postwick candidate must survive the frontier cap")

	if _failures.is_empty():
		print("optimization21 800017407 round02 Postwick breakpoint: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800017407 round02 Postwick breakpoint: FAIL (%d)" % _failures.size())
	quit(1)


func _profile() -> Dictionary:
	return {"local_action_certificate_parameters": {"partner_chain": {
		"same_turn_stadium_attack_breakpoint": {
			"booster_uid": "CSV10C_218",
			"replaced_stadium_uid": "CSV3C_129",
			"attacker_uid": "CSV10C_161",
			"attack_index": 0,
			"allow_non_ko_damage_upgrade": true,
			"minimum_damage_gain": 30,
		},
	}}}


func _validate_engine_builder_seed409_shape(profile: Dictionary) -> void:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 19
	state.stadium_played_this_turn = false
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	gsm.effect_processor.bind_game_state_machine(gsm)

	var zacian := _pokemon("赫普的苍响ex", "CSV10C", "161", "832e8b704b5457781ee7c52adc1a0571", 230, "M")
	zacian.attacks.append({"name": "刹那斩", "cost": "C", "damage": "30"})
	zacian.attacks.append({"name": "英勇之刃", "cost": "MMMC", "damage": "240"})
	var active := _slot(CardInstance.create(zacian, 0))
	# Reconstruct the formal seed-409 state exactly: Zacian has no Energy, but
	# Hop's Choice Band pays the single Colorless cost and supplies the first +30.
	active.attached_tool = CardInstance.create(
		_tool("赫普的讲究头带", "CSV10C", "201", "87bf196475e64140c14197af70648893"), 0
	)
	state.players[0].active_pokemon = active

	var iron_hands := _pokemon("Iron Hands ex", "CSV6C", "051", "e9f0c124fc2e352af2408a7e61862b95", 230, "L")
	iron_hands.attacks.append({"name": "Arm Press", "cost": "LLC", "damage": "160"})
	var defender := _slot(CardInstance.create(iron_hands, 1))
	defender.damage_counters = 140
	defender.attached_tool = CardInstance.create(
		_tool("Bravery Charm", "CSV1C", "118", "d1c2f018a644e662f2b6895fdfc29281"), 1
	)
	state.players[1].active_pokemon = defender
	var bench_target := _pokemon("Miraidon ex", "CSV1C", "050", "", 220, "L")
	state.players[1].bench.append(_slot(CardInstance.create(bench_target, 1)))

	var snowy := _stadium("Calamitous Snowy Mountain", "CSV3C", "129", "ceac9ee87d5850880f7438665925dbd2")
	state.stadium_card = CardInstance.create(snowy, 0)
	state.stadium_owner_index = 0
	var postwick := CardInstance.create(
		_stadium("化朗镇", "CSV10C", "218", "0c3c21449043e462bb73afac6c389a34"), 0
	)
	state.players[0].hand.append(postwick)

	var preview := gsm.get_v18_public_attack_preview_with_stadium(0, 0, postwick)
	var before_damage := int((preview.get("before", {}) as Dictionary).get("effective_damage", 0))
	var after_damage := int((preview.get("after", {}) as Dictionary).get("effective_damage", 0))
	_check(before_damage == 60, \
		"seed409 engine fixture must preview 60 damage before Postwick, got %d" % before_damage)
	_check(after_damage == 90, \
		"seed409 engine fixture must recompute 90 damage after Postwick, got %d" % after_damage)
	_check(int(preview.get("target_effective_hp", 0)) == 140, \
		"seed409 engine fixture must include Bravery Charm and expose 140 effective HP")
	_check(not bool((preview.get("after", {}) as Dictionary).get("knockout", true)), \
		"seed409 engine fixture must not mislabel 90 damage as a knockout through Bravery Charm")
	_check(bool((preview.get("guards", {}) as Dictionary).get("active_damage_invariant_under_interaction", false)), \
		"Zacian Bench target interaction must preserve Active damage in the engine fixture")

	var strategy := LocalCertificateStrategy.new()
	strategy.parameters = ((profile.get("local_action_certificate_parameters", {}) as Dictionary).get("partner_chain", {}) as Dictionary).duplicate(true)
	var builder = ActionBuilderScript.new()
	builder.set_deck_strategy(strategy)
	var postwick_action: Dictionary = {}
	for action: Dictionary in builder.build_actions(gsm, 0):
		if str(action.get("kind", "")) == "play_stadium" and action.get("card") == postwick:
			postwick_action = action
			break
	_check(not postwick_action.is_empty(), "seed409 engine fixture must expose legal Postwick")
	var local_certificates: Dictionary = postwick_action.get("v18cpg_local_certificates", {}) \
		if postwick_action.get("v18cpg_local_certificates", {}) is Dictionary else {}
	_check(local_certificates.has("partner_damage_breakpoint"), \
		"production action builder must mint the local Postwick breakpoint")
	var local_certificate: Dictionary = local_certificates.get("partner_damage_breakpoint", {}) \
		if local_certificates.get("partner_damage_breakpoint", {}) is Dictionary else {}
	_check(str(local_certificate.get("certificate_kind", "")) == "public_partner_same_turn_damage_upgrade", \
		"the Bravery Charm state must mint a non-KO damage upgrade, never a prize breakpoint")
	var production_strategy = StrategyScript.new()
	production_strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(800017407))
	var production_builder = ActionBuilderScript.new()
	production_builder.set_deck_strategy(production_strategy)
	var production_postwick: Dictionary = {}
	for action: Dictionary in production_builder.build_actions(gsm, 0):
		if str(action.get("kind", "")) == "play_stadium" and action.get("card") == postwick:
			production_postwick = action
			break
	var production_certificates: Dictionary = production_postwick.get("v18cpg_local_certificates", {}) \
		if production_postwick.get("v18cpg_local_certificates", {}) is Dictionary else {}
	_check(production_certificates.has("partner_damage_breakpoint"), \
		"the real deck 800017407 strategy must expose its local certificate parameters to the builder")
	var production_certificate: Dictionary = production_certificates.get("partner_damage_breakpoint", {}) \
		if production_certificates.get("partner_damage_breakpoint", {}) is Dictionary else {}
	_check(str(production_certificate.get("certificate_kind", "")) == "public_partner_same_turn_damage_upgrade", \
		"the real deck strategy must preserve the effective-HP non-KO certificate kind")
	var selected := _postwick_candidate()
	selected["local_certificates"] = {"partner_damage_breakpoint": production_certificate.duplicate(true)}
	var rule_floor := _rule_attack_candidate()
	var suffix: Dictionary = production_certificate.get("suffix", {}) \
		if production_certificate.get("suffix", {}) is Dictionary else {}
	(rule_floor["action_ref"] as Dictionary)["source"] = str(suffix.get("attacker_slot_id", ""))
	var module = ShapeScript.new()
	module.configure("partner_chain")
	var damage_upgrade: Dictionary = module.verify_route_advantage(selected, rule_floor, {}, profile)
	_check(bool(damage_upgrade.get("verified", false)), \
		"the exact effective-HP non-KO Postwick prefix must verify against the Rule attack")
	_check(str(damage_upgrade.get("certificate_kind", "")) == "public_partner_same_turn_damage_upgrade", \
		"module verification must retain the non-KO damage certificate kind")


func _pokemon(
	name: String,
	set_code: String,
	card_index: String,
	effect_id: String,
	hp: int,
	energy_type: String
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	card.hp = hp
	card.energy_type = energy_type
	return card


func _tool(name: String, set_code: String, card_index: String, effect_id: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Tool"
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	return card


func _stadium(name: String, set_code: String, card_index: String, effect_id: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Stadium"
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	return card


func _basic_energy(name: String, symbol: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return card


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = 1
	return slot


func _postwick_candidate() -> Dictionary:
	return {
		"candidate_id": "candidate:postwick",
		"route_id": "route:stadium",
		"action_kind": "play_stadium",
		"action_ref": {"card": {"uid": "CSV10C_218"}},
		"local_certificates": {"partner_damage_breakpoint": {
			"schema_version": 1,
			"certificate_kind": "public_partner_same_turn_prize_breakpoint",
			"prefix": {
				"kind": "play_stadium",
				"card_uid": "CSV10C_218",
				"replaced_stadium_uid": "CSV3C_129",
			},
			"suffix": {
				"attacker_slot_id": "slot:6",
				"attacker_uid": "CSV10C_161",
				"attack_index": 0,
				"target_slot_id": "slot:58",
				"active_damage_invariant_under_interaction": true,
			},
			"before": {
				"attack_payable": true,
				"damage_cancelled": false,
				"effective_damage": 60,
				"target_effective_hp": 90,
				"knockout": false,
				"prizes": 0,
			},
			"after": {
				"attack_payable": true,
				"damage_cancelled": false,
				"effective_damage": 90,
				"target_effective_hp": 90,
				"knockout": true,
				"prizes": 2,
			},
			"guards": {
				"attack_window_open": true,
				"target_stable": true,
				"survival_hook": false,
				"damage_reactive_hook": false,
				"random": false,
				"hidden_info": false,
				"interaction_suffix_bound": true,
				"displaced_suffix_dominates": false,
			},
			"evidence_kind": "engine_public_same_turn_suffix",
		}},
		"outcome": {},
	}


func _rule_attack_candidate() -> Dictionary:
	return {
		"candidate_id": "candidate:rule",
		"route_id": "route:attack_pressure",
		"action_kind": "attack",
		"engine_rule_floor_exact": true,
		"action_ref": {
			"source": "slot:6",
			"source_card": {"uid": "CSV10C_161"},
			"attack_index": 0,
			"projected_damage": 60,
			"projected_knockout": false,
		},
		"outcome": {"terminal": true},
	}


func _negative_case(
	module: RefCounted,
	profile: Dictionary,
	selected: Dictionary,
	rule_floor: Dictionary,
	label: String,
	mutate: Callable
) -> void:
	var candidate := selected.duplicate(true)
	var top := rule_floor.duplicate(true)
	mutate.call(candidate, top)
	var result: Dictionary = module.call("verify_route_advantage", candidate, top, {}, profile)
	_check(not bool(result.get("verified", false)), "%s must fail closed" % label)


func _negative_guard_case(
	module: RefCounted,
	profile: Dictionary,
	selected: Dictionary,
	rule_floor: Dictionary,
	guard: String,
	value: bool
) -> void:
	_negative_case(module, profile, selected, rule_floor, guard, func(candidate: Dictionary, _top: Dictionary) -> void:
		(candidate["local_certificates"]["partner_damage_breakpoint"]["guards"] as Dictionary)[guard] = value
	)


func _contains_candidate(frontier: Array[Dictionary], candidate_id: String) -> bool:
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
