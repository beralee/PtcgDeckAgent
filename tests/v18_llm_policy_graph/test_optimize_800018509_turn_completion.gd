extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const TurnCompletionSolverScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGTurnCompletionSolver.gd")
const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const DecisionClientScript = preload("res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd")
const ObservationGatewayScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const FactBuilderScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")

const DECK_ID := 800018509
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018509.json"
const RAGING_BOLT_UID := "CSV7C_154"
const RAGING_BOLT_EFFECT_ID := "e96bb407c5f18bb9eec55487e70395fd"
const OGERPON_UID := "CSV8C_028"
const HOOTHOOT_UID := "CSV9C_154"
const NOCTOWL_UID := "CSV9C_155"
const AREA_ZERO_UID := "CSV9C_207"
const NEST_BALL_UID := "CSVH1C_043"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []


class ProductionInteractionScene extends Control:
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_kind: String = "attack"
	var _pending_effect_card: CardInstance = null
	var _pending_effect_slot: PokemonSlot = null
	var _pending_effect_ability_index: int = -1
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var picked_indices := PackedInt32Array()

	func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
		return int(step.get("chooser_player_index", 0))

	func _effect_step_uses_counter_distribution_ui(
		_step: Dictionary
	) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _handle_effect_interaction_choice(
		indices: PackedInt32Array
	) -> void:
		picked_indices = indices


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_test_noctowl_completion_review_and_exact_pair()
	_test_minimum_lethal_discard_reaches_execution()
	_test_multi_unit_discard_preserves_one_complete_attack_cost()
	_test_secured_ko_banks_with_live_ogerpon_before_terminal()
	_test_secured_ko_uses_noctowl_for_remaining_continuity_debt()
	_test_noctowl_followup_search_executes_the_continuity_target()
	_test_missing_ogerpon_engine_is_developed_before_terminal()
	_test_full_bench_plays_area_zero_before_nonterminal_attack()
	_test_expanded_bench_builds_hoothoot_root_before_attack()
	_test_tera_enabler_precedes_noctowl_evolution()
	_test_tera_enabler_wakes_live_noctowl_before_commitments()
	_test_fallback_layers_cannot_bypass_completion_prefix()
	_test_ready_hoothoot_evolves_before_attack()
	_test_second_ogerpon_engine_is_built_before_attack()
	_test_engine_root_precedes_rush_attachment()
	_test_nest_ball_acquires_hoothoot_before_rush_attachment()
	_test_unpaired_hoothoot_builds_future_search_lane()
	_test_late_search_root_repairs_the_remaining_clock()
	_test_area_zero_preserves_future_engine_capacity()
	_test_last_normal_bench_slot_can_build_second_ogerpon()
	_test_tera_observation_reads_trait_not_rules_text()
	_test_live_noctowl_requires_a_replacement_search_root()
	_test_area_zero_requires_public_tera_condition()
	_test_secured_ko_closes_after_continuity_floor()
	_test_win_now_overrides_continuity_debt()
	_test_model_prompt_resolves_ko_continuity_precedence()
	_test_payable_gust_constraint_reaches_interaction_scoring()
	_test_all_v18_profiles_inherit_the_completion_contract()
	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty():
		print("optimization 800018509 turn completion: PASS (28/28)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization 800018509 turn completion: FAIL (%d)" % _failures.size())
	quit(1)


func _test_noctowl_completion_review_and_exact_pair() -> void:
	var observation := _completion_observation(false, 230, 70)
	var facts := _facts(true, false, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"ability:noctowl": 100.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var noctowl := _candidate(frontier, "ability:noctowl")
	var annotation := _module_annotation(noctowl, "tera_noctowl_search")
	_check(
		bool(annotation.get("completion_opportunity", false)),
		"a live Noctowl before a non-KO 70-damage attack must expose a route-completion opportunity"
	)
	_check(
		int(annotation.get("completion_damage_floor", 0)) == 210,
		"Raging Bolt Noctowl completion floor must remain 210 damage"
	)
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)),
		"an incomplete public hand/board route must trigger terminal review"
	)
	_check(
		"ability:noctowl" in contract.get("productive_action_ids", []),
		"the completion contract must identify the exact Noctowl action"
	)
	_check(
		str(contract.get("recommended_action_id", "")) == "ability:noctowl",
		"the shared completion barrier must recommend the exact live Noctowl action"
	)
	_check(
		str(contract.get("instruction", "")) == "complete_public_route_then_reobserve",
		"the completion contract must require a new information epoch before attacking"
	)

	var no_rule_avoid: Array = _profile.get("route_preferences", {}).get(
		"avoid_before_ready_attack",
		[]
	)
	_check(
		"noctowl_search" not in no_rule_avoid,
		"Raging Bolt profile must not globally suppress Noctowl before an incomplete attack"
	)
	_check(
		float(_profile.get("route_preferences", {}).get("route_biases", {}).get(
			"route:noctowl_search",
			-1.0
		)) > 0.0,
		"Raging Bolt profile must give a live completion Noctowl positive model priority"
	)

	var search_items: Array = [
		CardInstance.create(_real_card_data("CSV6C_121"), 0),
		CardInstance.create(_real_card_data("CSV6C_115"), 0),
		CardInstance.create(_real_card_data("CSV3C_123"), 0),
		CardInstance.create(_real_card_data("CSVH1C_043"), 0),
	]
	var step := {
		"id": "csv9c_noctowl_trainers",
		"min_select": 0,
		"max_select": 2,
	}
	var context := {
		"v18cpg_facts": facts,
		"v18cpg_observation": observation,
		"turn_completion_contract": contract,
	}
	var picked := NoctowlSearchScript.new().pick_pair(
		search_items,
		step,
		context,
		_profile,
		_manifest,
		"route:noctowl_search"
	)
	var picked_uids := _uids(picked)
	_check(
		picked_uids == ["CSV6C_115", "CSV6C_121"],
		"Noctowl must fetch Earthen Vessel plus Professor Sada as one complementary completion pair"
	)

	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	var request: Dictionary = strategy.call(
		"_build_request_envelope",
		observation,
		facts,
		frontier
	)
	var request_contract: Dictionary = request.get("turn_completion_contract", {}) \
		if request.get("turn_completion_contract", {}) is Dictionary else {}
	_check(
		bool(request_contract.get("must_review_before_terminal", false)) \
			and "ability:noctowl" in request_contract.get("productive_action_ids", []),
		"the exact completion checklist must reach the model request"
	)
	strategy.set("_last_observation", observation)
	var premature_attack := _candidate(frontier, "attack:pressure")
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(premature_attack.get("route_id", "")),
					"candidate_id": str(
						premature_attack.get("candidate_id", "")
					),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) == "ability:noctowl" \
			and str(strategy.get("_current_action_owner")) \
				== "module_verified_upgrade",
		"a model-selected premature attack must be replaced by the exact Noctowl completion action"
	)


func _test_minimum_lethal_discard_reaches_execution() -> void:
	var state := _game_state()
	var processor := EffectProcessor.new()
	var bolt_data := _real_card_data(RAGING_BOLT_UID)
	processor.register_pokemon_card(bolt_data)
	var bolt := _real_slot(bolt_data, 0)
	var ogerpon := _real_slot(_real_card_data(OGERPON_UID), 0)
	var lightning := _real_energy("CSVE1C_LIG", 0)
	var fighting := _real_energy("CSVE1C_FIG", 0)
	var grass := _real_energy("CSVE1C_GRA", 0)
	bolt.attached_energy = [lightning, fighting]
	ogerpon.attached_energy = [grass]
	state.players[0].active_pokemon = bolt
	state.players[0].bench = [ogerpon]
	state.players[1].active_pokemon = _real_target("Joltik", 30, 1)

	var attack_action := {
		"id": "attack:bellowing-thunder",
		"kind": "attack",
		"source": _slot_id(bolt),
		"source_card": _public_card(bolt.get_top_card()),
		"attack_index": 1,
		"projected_damage": 70,
		"projected_knockout": true,
		"requires_interaction": true,
	}
	var observation := {
		"observation_version": 1,
		"observation_hash": "raging-bolt-joltik-30",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": _public_slot(bolt),
			"bench": [_public_slot(ogerpon)],
			"hand": [],
			"discard": [],
			"deck_count": 20,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _public_slot(state.players[1].active_pokemon),
			"bench": [],
		},
		"legal_actions": [attack_action],
	}
	var facts := _facts(true, true, 70)
	var frontier := _frontier(
		observation,
		facts,
		{"attack:bellowing-thunder": 1000.0},
		"attack:bellowing-thunder"
	)
	var candidate := _candidate(frontier, "attack:bellowing-thunder")
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_last_observation", observation)
	strategy.set("_last_facts", facts)
	strategy.set("_last_frontier", frontier)
	strategy.set("_preferred_action_id", "attack:bellowing-thunder")
	strategy.set("_preferred_candidate_id", str(candidate.get("candidate_id", "")))
	strategy.set("_current_route_id", "route:attack_ko")
	# Production terminal attacks are deliberately installed as a one-shot Rule
	# floor.  The exact resource certificate must still constrain the following
	# attack-effect interaction; ownership is not part of the lethal proof.
	strategy.set("_current_action_owner", "rules_fallback")

	var attack := bolt_data.attacks[1]
	var steps: Array[Dictionary] = processor.get_attack_interaction_steps_by_id(
		RAGING_BOLT_EFFECT_ID,
		1,
		bolt.get_top_card(),
		attack,
		state
	)
	_check(not steps.is_empty(), "real Bellowing Thunder discard step must exist")
	var step: Dictionary = steps[0] if not steps.is_empty() else {
		"id": "discard_basic_energy",
		"min_select": 0,
		"max_select": 3,
	}
	var items: Array = step.get("items", []) if step.get("items", []) is Array else []
	var live_attack_context := {
		"pending_effect_kind": "attack",
		"pending_effect_card": bolt.get_top_card(),
		"pending_effect_slot": bolt,
		"pending_effect_ability_index": 1,
	}
	var picked := strategy.pick_interaction_items(
		items,
		step,
		live_attack_context
	)
	_check(
		picked.size() == 1 and picked[0] == grass,
		"a 30 HP Joltik must cost exactly one expendable Grass Energy"
	)
	strategy.set("_last_frontier", [])
	strategy.set("_preferred_action_id", "")
	strategy.set("_preferred_candidate_id", "")
	var live_only_picked := strategy.pick_interaction_items(
		items,
		step,
		live_attack_context
	)
	_check(
		live_only_picked.size() == 1 and live_only_picked[0] == grass,
		"the live attack source/index must keep the one-Energy cap even after the one-shot Rule route is cleared"
	)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var resolver = AIStepResolverScript.new()
	resolver.deck_strategy = strategy
	var scene := ProductionInteractionScene.new()
	scene._pending_effect_card = bolt.get_top_card()
	scene._pending_effect_slot = bolt
	scene._pending_effect_ability_index = 1
	var production_step := step.duplicate(true)
	production_step["chooser_player_index"] = 0
	scene._pending_effect_steps = [production_step]
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0, [])
	_check(
		resolved and scene.picked_indices.size() == 1,
		"production AIStepResolver must submit one discard instead of its three-item baseline"
	)
	var execution_picked: Array = []
	if scene.picked_indices.size() == 1:
		var selected_index := int(scene.picked_indices[0])
		_check(
			selected_index >= 0 \
				and selected_index < items.size() \
				and items[selected_index] == grass,
			"production AIStepResolver must submit the expendable Grass Energy index"
		)
		if selected_index >= 0 and selected_index < items.size():
			execution_picked.append(items[selected_index])
	scene.free()
	var mismatched_attack := CapabilityRegistryScript.new().pick_verified_interaction_override(
		items,
		step,
		items,
		{
			"v18cpg_observation": observation,
			"v18cpg_preferred_action_ref": attack_action,
			"v18cpg_live_interaction_ref": {
				"kind": "attack",
				"proof_complete": true,
				"source": _slot_id(bolt),
				"source_card": _public_card(bolt.get_top_card()),
				"attack_index": 0,
			},
		},
		_profile,
		"public_minimum_resource_ko"
	)
	_check(
		not bool(mismatched_attack.get("handled", false)),
		"a live attack-index mismatch must fail closed instead of capping the wrong effect"
	)
	var attack_bonus := processor.get_attack_damage_bonus_by_id(
		RAGING_BOLT_EFFECT_ID,
		1,
		bolt,
		state,
		[{"discard_basic_energy": execution_picked}]
	)
	processor.execute_attack_effect_by_id(
		RAGING_BOLT_EFFECT_ID,
		1,
		bolt,
		state.players[1].active_pokemon,
		state,
		[{"discard_basic_energy": execution_picked}]
	)
	var damage := maxi(0, 70 + attack_bonus)
	state.players[1].active_pokemon.damage_counters += damage
	_check(
		damage == 70 \
			and state.players[1].active_pokemon.get_remaining_hp() == 0 \
			and bolt.attached_energy == [lightning, fighting] \
			and ogerpon.attached_energy.is_empty(),
		"minimum discard must execute the KO while preserving Raging Bolt's Lightning/Fighting attack cost"
	)


func _test_secured_ko_banks_with_live_ogerpon_before_terminal() -> void:
	var observation := _completion_observation(true, 30, 70)
	(observation["legal_actions"] as Array).remove_at(1)
	(observation["legal_actions"] as Array).insert(1, _ogerpon_ability_action())
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"ability:teal-dance": 150.0,
		"ability:noctowl": 650.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)),
		"a secured KO must stay open while minimum payment would break the configured energy bank"
	)
	_check(
		str(contract.get("instruction", "")) \
			== "complete_post_attack_continuity_then_reobserve",
		"a secured KO with public continuity debt must enter the shared continuation graph"
	)
	_check(
		str(contract.get("recommended_action_id", "")) == "ability:teal-dance" \
			and "banked_damage_units" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []) \
			and int(contract.get("post_attack_continuity", {}).get(
				"post_payment_banked_units",
				-1
			)) == 1,
		"an already-benched Teal Mask with visible Grass must bank Energy before the cheap KO"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.set("_last_observation", observation)
	var attack_candidate := _candidate(frontier, "attack:pressure")
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(attack_candidate.get("route_id", "")),
					"candidate_id": str(attack_candidate.get("candidate_id", "")),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) == "ability:teal-dance",
		"the terminal barrier must replace a model-selected KO with the exact public Teal Dance prefix"
	)


func _test_secured_ko_uses_noctowl_for_remaining_continuity_debt() -> void:
	var observation := _completion_observation(true, 30, 70)
	var ogerpon: Dictionary = (observation["own"]["bench"] as Array)[0]
	ogerpon["energy"] = [_energy_ref("G"), _energy_ref("G")]
	ogerpon["energy_count"] = 2
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"ability:noctowl": 150.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	var continuity: Dictionary = contract.get("post_attack_continuity", {})
	var noctowl_effect: Dictionary = {}
	for raw_effect: Variant in continuity.get("candidate_effects", []):
		if raw_effect is Dictionary \
				and str((raw_effect as Dictionary).get("action_id", "")) \
					== "ability:noctowl":
			noctowl_effect = raw_effect as Dictionary
			break
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) == "ability:noctowl" \
			and "next_attacker_root" in continuity.get("debt_types", []) \
			and bool(noctowl_effect.get("progresses_debt", false)) \
			and int(noctowl_effect.get("debt_reduction_count", -1)) == 0 \
			and bool(noctowl_effect.get("requires_reobservation", false)),
		"live Noctowl must open a reobservation checkpoint for the missing route without falsely claiming that the searched Trainers already closed every debt"
	)
	var search_items: Array = [
		CardInstance.create(_real_card_data("CSV6C_121"), 0),
		CardInstance.create(_real_card_data("CSV6C_115"), 0),
		CardInstance.create(_real_card_data("CSVH1C_043"), 0),
		CardInstance.create(_real_card_data("CSVH1aC_023"), 0),
	]
	var picked := NoctowlSearchScript.new().pick_pair(
		search_items,
		{
			"id": "csv9c_noctowl_trainers",
			"min_select": 0,
			"max_select": 2,
		},
		{
			"v18cpg_facts": facts,
			"v18cpg_observation": observation,
			"turn_completion_contract": contract,
		},
		_profile,
		_manifest,
		"route:noctowl_search"
	)
	_check(
		_uids(picked) == ["CSV6C_115", "CSVH1C_043"],
		"Noctowl must translate next-attacker and Energy debt into Nest Ball plus Earthen Vessel"
	)


func _test_noctowl_followup_search_executes_the_continuity_target() -> void:
	var observation := _completion_observation(false, 200, 140)
	var used_noctowl: Dictionary = (observation["own"]["bench"] as Array)[1]
	used_noctowl["ability_used"] = true
	(observation["own"]["bench"] as Array).append(_slot_ref(
		"slot:replacement-hoothoot",
		_card_ref(HOOTHOOT_UID),
		[],
		false
	))
	observation["own"]["hand"] = [_card_ref(NEST_BALL_UID)]
	observation["own"]["hand_count"] = 1
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "search:nest-ball-after-noctowl",
			"kind": "play_trainer",
			"card": _card_ref(NEST_BALL_UID),
			"requires_interaction": true,
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, false, 140)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"search:nest-ball-after-noctowl": 120.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "search:nest-ball-after-noctowl",
		"a Nest Ball fetched by Noctowl must remain an executable continuity checkpoint instead of being left unused before the attack"
	)
	var ogerpon_item := CardInstance.create(_real_card_data(OGERPON_UID), 0)
	var bolt_item := CardInstance.create(_real_card_data(RAGING_BOLT_UID), 0)
	var nest_candidate := _candidate(
		frontier,
		"search:nest-ball-after-noctowl"
	)
	var picked: Dictionary = NoctowlSearchScript.new() \
		.pick_verified_basic_search_override(
			[bolt_item, ogerpon_item],
			{"id": "basic_pokemon", "min_select": 1, "max_select": 1},
			[bolt_item],
			{
				"v18cpg_facts": facts,
				"v18cpg_observation": observation,
				"turn_completion_contract": contract,
				"v18cpg_preferred_action_ref": nest_candidate.get(
					"action_ref",
					{}
				),
			},
			_profile
		)
	var picked_items: Array = picked.get("items", []) \
		if picked.get("items", []) is Array else []
	_check(
		bool(picked.get("handled", false)) \
			and picked_items.size() == 1 \
			and picked_items[0] is CardInstance \
			and (picked_items[0] as CardInstance).card_data.get_uid() \
				.to_upper() == OGERPON_UID,
		"the follow-up Basic search must bind the missing public Energy-engine target rather than falling back to an arbitrary Basic"
	)


func _test_missing_ogerpon_engine_is_developed_before_terminal() -> void:
	var observation := _completion_observation(true, 30, 70)
	(observation["own"]["bench"] as Array).remove_at(0)
	(observation["legal_actions"] as Array).remove_at(1)
	observation["own"]["hand"] = [
		_card_ref(OGERPON_UID),
		_energy_ref("G"),
	]
	observation["own"]["hand_count"] = 2
	(observation["legal_actions"] as Array).insert(1, {
		"id": "develop:ogerpon",
		"kind": "play_basic_to_bench",
		"card": _card_ref(OGERPON_UID),
	})
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"develop:ogerpon": 80.0,
		"ability:noctowl": 150.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:ogerpon" \
			and "live_energy_engine" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"a safe visible Ogerpon plus Grass hand must open the bench-then-Teal-Dance graph"
	)


func _test_full_bench_plays_area_zero_before_nonterminal_attack() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref("slot:filler-1", {"uid": "FILLER_1"}, [], false),
		_slot_ref("slot:filler-2", {"uid": "FILLER_2"}, [], false),
		_slot_ref("slot:filler-3", {"uid": "FILLER_3"}, [], false),
		_slot_ref("slot:filler-4", {"uid": "FILLER_4"}, [], false),
	]
	observation["own"]["hand"] = [
		_card_ref(AREA_ZERO_UID),
		_card_ref(HOOTHOOT_UID),
		_card_ref(OGERPON_UID),
		_energy_ref("G"),
	]
	observation["own"]["hand_count"] = 4
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "stadium:area-zero",
			"kind": "play_stadium",
			"card": _card_ref(AREA_ZERO_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	facts["board"]["bench_full"] = true
	facts["resources"]["bench_slots_free"] = 0
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"stadium:area-zero": 20.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	var continuity: Dictionary = contract.get("post_attack_continuity", {})
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "stadium:area-zero" \
			and "bench_capacity_for_engines" in continuity.get(
				"debt_types",
				[]
			),
		"a full five-slot Tera board with Hoothoot/Ogerpon in hand must play Area Zero before a non-final attack"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.set("_last_observation", observation)
	var attack_candidate := _candidate(frontier, "attack:pressure")
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(attack_candidate.get("route_id", "")),
					"candidate_id": str(
						attack_candidate.get("candidate_id", "")
					),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) \
				== "stadium:area-zero",
		"the execution barrier must replace an accepted rush-attack policy with the exact Area Zero action"
	)


func _test_expanded_bench_builds_hoothoot_root_before_attack() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["stadium"] = _card_ref(AREA_ZERO_UID)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref("slot:filler-1", {"uid": "FILLER_1"}, [], false),
		_slot_ref("slot:filler-2", {"uid": "FILLER_2"}, [], false),
		_slot_ref("slot:filler-3", {"uid": "FILLER_3"}, [], false),
		_slot_ref("slot:filler-4", {"uid": "FILLER_4"}, [], false),
	]
	observation["own"]["hand"] = [
		_card_ref(HOOTHOOT_UID),
		_card_ref(NOCTOWL_UID),
		_card_ref(OGERPON_UID),
		_energy_ref("G"),
	]
	observation["own"]["hand_count"] = 4
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "develop:hoothoot",
			"kind": "play_basic_to_bench",
			"card": _card_ref(HOOTHOOT_UID),
		},
		{
			"id": "develop:second-ogerpon",
			"kind": "play_basic_to_bench",
			"card": _card_ref(OGERPON_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	facts["resources"]["bench_slots_free"] = 3
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"develop:hoothoot": 10.0,
		"develop:second-ogerpon": 30.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:hoothoot" \
			and "search_engine_root" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"Area Zero's extra slots must be spent first on a Hoothoot root that preserves the next Fan Call epoch"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.set("_last_observation", observation)
	var lower_priority_engine := _candidate(
		frontier,
		"develop:second-ogerpon"
	)
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(
						lower_priority_engine.get("route_id", "")
					),
					"candidate_id": str(
						lower_priority_engine.get("candidate_id", "")
					),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) \
				== "develop:hoothoot",
		"the completion barrier must order forced setup prefixes, so a model cannot bench the second Ogerpon before the higher-priority Hoothoot root"
	)
	var continuation: Dictionary = strategy.call(
		"_completion_override_for_rule_root",
		frontier,
		facts,
		observation
	)
	_check(
		bool(continuation.get("handled", false)) \
			and str(continuation.get("action_id", "")) \
				== "develop:hoothoot",
		"after the first accepted model judgment, the local reobservation path must continue the exact Hoothoot prefix without another model call"
	)
	var pre_judgment_prefix: Dictionary = strategy.call(
		"_pre_judgment_completion_override",
		frontier,
		facts,
		observation,
		true
	)
	_check(
		bool(pre_judgment_prefix.get("handled", false)) \
			and str(pre_judgment_prefix.get("action_id", "")) \
				== "develop:hoothoot",
		"a mandatory public prefix must execute before the first model request instead of leaking an unselectable recommended candidate into that request"
	)


func _test_tera_enabler_precedes_noctowl_evolution() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:hoothoot",
			_card_ref(HOOTHOOT_UID),
			[],
			false
		),
	]
	observation["own"]["hand"] = [
		_card_ref(NOCTOWL_UID),
		_card_ref(OGERPON_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "evolve:noctowl-before-tera",
			"kind": "evolve",
			"card": _card_ref(NOCTOWL_UID),
			"target": "slot:hoothoot",
		},
		{
			"id": "develop:tera-enabler",
			"kind": "play_basic_to_bench",
			"card": _card_ref(OGERPON_UID),
		},
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	facts["board"]["has_tera"] = false
	facts["fan_call"]["available"] = false
	var frontier := _frontier(observation, facts, {
		"evolve:noctowl-before-tera": 900.0,
		"develop:tera-enabler": 10.0,
		"energy:rush-bolt": 800.0,
		"end:premature": 0.0,
	}, "evolve:noctowl-before-tera")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:tera-enabler" \
			and "tera_enabler_for_search_activation" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"a legal Noctowl evolution should first establish a visible Tera Pokemon so Jewel Seeker can enter the next executable prefix immediately"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.set("_last_observation", observation)
	var premature_evolution := _candidate(
		frontier,
		"evolve:noctowl-before-tera"
	)
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(
						premature_evolution.get("route_id", "")
					),
					"candidate_id": str(
						premature_evolution.get("candidate_id", "")
					),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) \
				== "develop:tera-enabler",
		"the execution barrier must replace a model- or Rule-selected premature Noctowl evolution with the exact Tera enabler action"
	)

	var enabled_observation: Dictionary = observation.duplicate(true)
	enabled_observation["own"]["bench"] = [
		_slot_ref(
			"slot:hoothoot",
			_card_ref(HOOTHOOT_UID),
			[],
			false
		),
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[],
			true
		),
	]
	enabled_observation["own"]["hand"] = [_card_ref(NOCTOWL_UID)]
	enabled_observation["own"]["hand_count"] = 1
	enabled_observation["legal_actions"] = [
		{
			"id": "evolve:noctowl-after-tera",
			"kind": "evolve",
			"card": _card_ref(NOCTOWL_UID),
			"target": "slot:hoothoot",
		},
		{
			"id": "energy:after-tera",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{"id": "end:after-tera", "kind": "end_turn"},
	]
	var enabled_facts := _facts(false, false, 0)
	enabled_facts["board"]["has_tera"] = true
	enabled_facts["fan_call"]["available"] = false
	var enabled_frontier := _frontier(
		enabled_observation,
		enabled_facts,
		{
			"evolve:noctowl-after-tera": 10.0,
			"energy:after-tera": 800.0,
			"end:after-tera": 0.0,
		},
		"energy:after-tera"
	)
	var enabled_contract: Dictionary = TurnCompletionSolverScript.new().build(
		enabled_observation,
		enabled_facts,
		enabled_frontier,
		_profile
	)
	_check(
		str(enabled_contract.get("recommended_action_id", "")) \
			== "evolve:noctowl-after-tera",
		"after the Tera enabler resolves, local reobservation must advance the same certified prefix into Noctowl evolution"
	)


func _test_tera_enabler_wakes_live_noctowl_before_commitments() -> void:
	var observation := _completion_observation(false, 230, 0)
	var dormant_noctowl := _slot_ref(
		"slot:noctowl",
		_card_ref(NOCTOWL_UID),
		[],
		false
	)
	dormant_noctowl["ability_used"] = false
	observation["own"]["bench"] = [dormant_noctowl]
	observation["own"]["hand"] = [
		_card_ref(OGERPON_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		{
			"id": "develop:tera-for-live-noctowl",
			"kind": "play_basic_to_bench",
			"card": _card_ref(OGERPON_UID),
		},
		{
			"id": "energy:rush-before-noctowl",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	facts["board"]["has_tera"] = false
	facts["fan_call"]["available"] = false
	var frontier := _frontier(observation, facts, {
		"develop:tera-for-live-noctowl": 10.0,
		"energy:rush-before-noctowl": 900.0,
		"end:premature": 0.0,
	}, "energy:rush-before-noctowl")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		str(contract.get("recommended_action_id", "")) \
			== "develop:tera-for-live-noctowl" \
			and "tera_enabler_for_search_activation" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"an unused live Noctowl must establish the visible Tera enabler before ordinary attachment or supporter commitments"
	)

	var awakened_observation: Dictionary = observation.duplicate(true)
	awakened_observation["own"]["bench"] = [
		dormant_noctowl,
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[],
			true
		),
	]
	awakened_observation["legal_actions"] = [
		{
			"id": "ability:noctowl-after-tera",
			"kind": "use_ability",
			"source": "slot:noctowl",
			"source_card": _card_ref(NOCTOWL_UID),
			"ability_index": 0,
			"requires_interaction": true,
		},
		{
			"id": "energy:after-live-noctowl",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{"id": "end:after-live-noctowl", "kind": "end_turn"},
	]
	var awakened_facts := _facts(false, false, 0)
	awakened_facts["board"]["has_tera"] = true
	awakened_facts["fan_call"]["available"] = true
	var awakened_frontier := _frontier(
		awakened_observation,
		awakened_facts,
		{
			"ability:noctowl-after-tera": 10.0,
			"energy:after-live-noctowl": 900.0,
			"end:after-live-noctowl": 0.0,
		},
		"energy:after-live-noctowl"
	)
	var awakened_contract: Dictionary = TurnCompletionSolverScript.new().build(
		awakened_observation,
		awakened_facts,
		awakened_frontier,
		_profile
	)
	_check(
		str(awakened_contract.get("recommended_action_id", "")) \
			== "ability:noctowl-after-tera",
		"after the Tera enabler resolves, the certified prefix must activate Noctowl before returning to ordinary commitments"
	)


func _test_fallback_layers_cannot_bypass_completion_prefix() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref(
			"slot:hoothoot",
			_card_ref(HOOTHOOT_UID),
			[],
			false
		),
	]
	observation["own"]["hand"] = [
		_card_ref(NOCTOWL_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		{
			"id": "energy:fallback-rush",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "evolve:fallback-noctowl",
			"kind": "evolve",
			"card": _card_ref(NOCTOWL_UID),
			"target": "slot:hoothoot",
		},
		{"id": "end:fallback", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	var frontier := _frontier(observation, facts, {
		"energy:fallback-rush": 900.0,
		"evolve:fallback-noctowl": 10.0,
		"end:fallback": 0.0,
	}, "energy:fallback-rush")
	for owner: String in ["schema_fallback", "deadline_fallback"]:
		var strategy = StrategyScript.new()
		strategy.configure_profile(_profile, _manifest)
		strategy.set("_last_observation", observation)
		strategy.set("_last_facts", facts)
		strategy.set("_last_frontier", frontier)
		var handled := bool(strategy.call(
			"_install_completion_aware_fallback",
			frontier,
			owner,
			facts,
			observation
		))
		_check(
			handled \
				and str(strategy.get("_preferred_action_id")) \
					== "evolve:fallback-noctowl" \
				and str(strategy.get("_current_action_owner")) \
					== "module_verified_upgrade",
			"%s must execute the same certified Noctowl prefix instead of bypassing Base through the Rule attachment" % owner
		)


func _test_ready_hoothoot_evolves_before_attack() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["stadium"] = _card_ref(AREA_ZERO_UID)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref(
			"slot:hoothoot",
			_card_ref(HOOTHOOT_UID),
			[],
			false
		),
	]
	observation["own"]["hand"] = [_card_ref(NOCTOWL_UID)]
	observation["own"]["hand_count"] = 1
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "evolve:noctowl",
			"kind": "evolve",
			"card": _card_ref(NOCTOWL_UID),
			"target": "slot:hoothoot",
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"evolve:noctowl": 15.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "evolve:noctowl" \
			and "search_engine_activation" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"a publicly evolvable Hoothoot must become Noctowl before a non-final attack so Jewel Seeker can open the next information epoch"
	)


func _test_second_ogerpon_engine_is_built_before_attack() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["stadium"] = _card_ref(AREA_ZERO_UID)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref(
			"slot:hoothoot",
			_card_ref(HOOTHOOT_UID),
			[],
			false
		),
	]
	observation["own"]["hand"] = [
		_card_ref(OGERPON_UID),
		_energy_ref("G"),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "develop:second-ogerpon",
			"kind": "play_basic_to_bench",
			"card": _card_ref(OGERPON_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"develop:second-ogerpon": 20.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:second-ogerpon" \
			and "energy_engine_width" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"one Teal Mask is not a sustainable engine board; a visible second copy plus Grass must be developed before attacking"
	)


func _test_engine_root_precedes_rush_attachment() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["stadium"] = _card_ref(AREA_ZERO_UID)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
	]
	observation["own"]["hand"] = [
		_card_ref(HOOTHOOT_UID),
		_card_ref(NOCTOWL_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "develop:hoothoot",
			"kind": "play_basic_to_bench",
			"card": _card_ref(HOOTHOOT_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"develop:hoothoot": 10.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:hoothoot",
		"the engine completion graph must run before a rush attachment even when the attack is not ready yet"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.set("_last_observation", observation)
	var attachment := _candidate(frontier, "energy:rush-bolt")
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(attachment.get("route_id", "")),
					"candidate_id": str(
						attachment.get("candidate_id", "")
					),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) \
				== "develop:hoothoot",
		"an accepted model policy that rushes attachment must be replaced by the exact Hoothoot setup action"
	)


func _test_nest_ball_acquires_hoothoot_before_rush_attachment() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
	]
	observation["own"]["hand"] = [
		_card_ref(NEST_BALL_UID),
		_card_ref(NOCTOWL_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "search:nest-ball",
			"kind": "play_trainer",
			"card": _card_ref(NEST_BALL_UID),
			"requires_interaction": true,
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"search:nest-ball": 120.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "search:nest-ball" \
			and "search_engine_root" in contract.get(
				"post_attack_continuity",
				{}
			).get("debt_types", []),
		"when Hoothoot is not in hand, an available Nest Ball must become the engine-root acquisition checkpoint before a rush attachment"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_last_observation", observation)
	var attachment := _candidate(frontier, "energy:rush-bolt")
	var barrier_install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(attachment.get("route_id", "")),
					"candidate_id": str(attachment.get("candidate_id", "")),
				},
			}],
		},
	}, frontier, facts)
	_check(
		bool(barrier_install.get("valid", false)) \
			and bool(barrier_install.get("turn_completion_override", false)) \
			and str(strategy.get("_preferred_action_id")) \
				== "search:nest-ball",
		"the execution barrier must replace a rush attachment with the exact Nest Ball acquisition checkpoint"
	)
	strategy.set("_last_facts", facts)
	strategy.set("_last_frontier", frontier)
	var search_items: Array = [
		CardInstance.create(_real_card_data(OGERPON_UID), 0),
		CardInstance.create(_real_card_data(HOOTHOOT_UID), 0),
	]
	var picked := strategy.pick_interaction_items(
		search_items,
		{
			"id": "basic_pokemon",
			"min_select": 0,
			"max_select": 1,
		},
		{}
	)
	_check(
		picked.size() == 1 \
			and picked[0] is CardInstance \
			and (picked[0] as CardInstance).card_data.get_uid().to_upper() \
				== HOOTHOOT_UID,
		"after Nest Ball opens the deck, the interaction layer must select Hoothoot instead of falling back to an unrelated Basic"
	)


func _test_unpaired_hoothoot_builds_future_search_lane() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
	]
	observation["own"]["hand"] = [
		_card_ref(HOOTHOOT_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "develop:unpaired-hoothoot",
			"kind": "play_basic_to_bench",
			"card": _card_ref(HOOTHOOT_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"develop:unpaired-hoothoot": 10.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		str(contract.get("recommended_action_id", "")) \
			== "develop:unpaired-hoothoot",
		"a safe Hoothoot root must build the future search lane even when Noctowl is not already visible in hand"
	)


func _test_late_search_root_repairs_the_remaining_clock() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
	]
	observation["own"]["prizes_remaining"] = 3
	observation["own"]["hand"] = [
		_card_ref(HOOTHOOT_UID),
		_card_ref(NOCTOWL_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "develop:late-hoothoot",
			"kind": "play_basic_to_bench",
			"card": _card_ref(HOOTHOOT_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	facts["resources"]["prizes_remaining"] = 3
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"develop:late-hoothoot": 10.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		str(contract.get("recommended_action_id", "")) \
			== "develop:late-hoothoot",
		"with three Prizes left, the graph must still invest in a future search checkpoint instead of collapsing to the current attack route"
	)


func _test_area_zero_preserves_future_engine_capacity() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref("slot:filler-1", {"uid": "FILLER_1"}, [], false),
		_slot_ref("slot:filler-2", {"uid": "FILLER_2"}, [], false),
		_slot_ref("slot:filler-3", {"uid": "FILLER_3"}, [], false),
		_slot_ref("slot:filler-4", {"uid": "FILLER_4"}, [], false),
	]
	observation["own"]["hand"] = [
		_card_ref(AREA_ZERO_UID),
		_card_ref(HOOTHOOT_UID),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "stadium:area-zero",
			"kind": "play_stadium",
			"card": _card_ref(AREA_ZERO_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	facts["board"]["bench_full"] = true
	facts["resources"]["bench_slots_free"] = 0
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"stadium:area-zero": 20.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		str(contract.get("recommended_action_id", "")) \
			== "stadium:area-zero",
		"Area Zero must open capacity for the visible Hoothoot root so the future search lane is not sacrificed to the current attack"
	)


func _test_last_normal_bench_slot_can_build_second_ogerpon() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref("slot:filler-1", {"uid": "FILLER_1"}, [], false),
		_slot_ref("slot:filler-2", {"uid": "FILLER_2"}, [], false),
		_slot_ref("slot:filler-3", {"uid": "FILLER_3"}, [], false),
	]
	observation["own"]["hand"] = [
		_card_ref(OGERPON_UID),
		_energy_ref("G"),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "develop:second-ogerpon",
			"kind": "play_basic_to_bench",
			"card": _card_ref(OGERPON_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	facts["resources"]["bench_slots_free"] = 1
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"develop:second-ogerpon": 80.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		bool(contract.get("must_review_before_terminal", false)) \
			and str(contract.get("recommended_action_id", "")) \
				== "develop:second-ogerpon",
		"when no Hoothoot or Area Zero prefix is currently executable, the second Ogerpon plus visible Grass must be allowed to use the last normal bench slot"
	)


func _test_tera_observation_reads_trait_not_rules_text() -> void:
	var state := _game_state()
	state.players[0].active_pokemon = _real_slot(
		_real_card_data(RAGING_BOLT_UID),
		0
	)
	state.players[0].bench = [
		_real_slot(_real_card_data(OGERPON_UID), 0),
		_real_slot(_real_card_data(NOCTOWL_UID), 0),
	]
	state.players[1].active_pokemon = _real_target(
		"Public target",
		120,
		1
	)
	var observation: Dictionary = ObservationGatewayScript.new().build(
		state,
		0,
		[]
	)
	var bench: Array = observation.get("own", {}).get("bench", [])
	var facts: Dictionary = FactBuilderScript.new().build(
		observation,
		"",
		_profile
	)
	_check(
		bench.size() == 2 \
			and bool((bench[0] as Dictionary).get("tera", false)) \
			and not bool((bench[1] as Dictionary).get("tera", true)) \
			and bool(facts.get("board", {}).get("has_tera", false)),
		"the observation boundary must recognize Teal Mask Ogerpon's Tera trait and must not misclassify Noctowl merely because its rules text mentions Tera"
	)


func _test_live_noctowl_requires_a_replacement_search_root() -> void:
	var observation := _completion_observation(false, 230, 0)
	observation["own"]["bench"] = [
		_slot_ref(
			"slot:ogerpon",
			_card_ref(OGERPON_UID),
			[_energy_ref("G")],
			true
		),
		_slot_ref(
			"slot:noctowl",
			_card_ref(NOCTOWL_UID),
			[],
			false
		),
	]
	observation["own"]["hand"] = [
		_card_ref(NEST_BALL_UID),
		_card_ref(NOCTOWL_UID),
		_energy_ref("L"),
	]
	observation["own"]["hand_count"] = 3
	observation["legal_actions"] = [
		{
			"id": "energy:rush-bolt",
			"kind": "attach_energy",
			"card": _energy_ref("L"),
			"target": "slot:bolt",
		},
		{
			"id": "search:nest-ball",
			"kind": "play_trainer",
			"card": _card_ref(NEST_BALL_UID),
			"requires_interaction": true,
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(false, false, 0)
	facts["fan_call"]["available"] = false
	var frontier := _frontier(observation, facts, {
		"energy:rush-bolt": 900.0,
		"search:nest-ball": 120.0,
		"end:premature": 0.0,
	}, "energy:rush-bolt")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		"search_engine_root" in contract.get(
			"post_attack_continuity",
			{}
		).get("debt_types", []) \
			and str(contract.get("recommended_action_id", "")) \
				== "search:nest-ball",
		"an available Noctowl must require one replacement Hoothoot lane so the search engine survives the current activation"
	)


func _test_area_zero_requires_public_tera_condition() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["own"]["bench"] = [
		_slot_ref("slot:filler-0", {"uid": "FILLER_0"}, [], false),
		_slot_ref("slot:filler-1", {"uid": "FILLER_1"}, [], false),
		_slot_ref("slot:filler-2", {"uid": "FILLER_2"}, [], false),
		_slot_ref("slot:filler-3", {"uid": "FILLER_3"}, [], false),
		_slot_ref("slot:filler-4", {"uid": "FILLER_4"}, [], false),
	]
	observation["own"]["hand"] = [
		_card_ref(AREA_ZERO_UID),
		_card_ref(HOOTHOOT_UID),
	]
	observation["own"]["hand_count"] = 2
	observation["legal_actions"] = [
		(observation["legal_actions"] as Array)[0],
		{
			"id": "stadium:area-zero",
			"kind": "play_stadium",
			"card": _card_ref(AREA_ZERO_UID),
		},
		{"id": "end:premature", "kind": "end_turn"},
	]
	var facts := _facts(true, true, 70)
	facts["board"]["has_tera"] = false
	facts["board"]["bench_full"] = true
	facts["resources"]["bench_slots_free"] = 0
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 900.0,
		"stadium:area-zero": 20.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		str(contract.get("recommended_action_id", "")) \
			!= "stadium:area-zero",
		"Area Zero must not be certified as bench expansion without a public Tera Pokemon in play"
	)


func _test_secured_ko_closes_after_continuity_floor() -> void:
	var observation := _completion_observation(true, 30, 70)
	var next_bolt := _slot_ref(
		"slot:next-bolt",
		_card_ref(RAGING_BOLT_UID),
		[_energy_ref("L"), _energy_ref("F")],
		false
	)
	(observation["own"]["bench"] as Array).append(next_bolt)
	var ogerpon: Dictionary = (observation["own"]["bench"] as Array)[0]
	ogerpon["energy"] = [_energy_ref("G"), _energy_ref("G")]
	ogerpon["energy_count"] = 2
	(observation["own"]["bench"] as Array).append(_slot_ref(
		"slot:reserve-ogerpon",
		_card_ref(OGERPON_UID),
		[_energy_ref("G")],
		true
	))
	(observation["own"]["bench"] as Array).append(_slot_ref(
		"slot:next-hoothoot",
		_card_ref(HOOTHOOT_UID),
		[],
		false
	))
	var facts := _facts(true, true, 70)
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"ability:noctowl": 650.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		not bool(contract.get("must_review_before_terminal", true)) \
			and bool(contract.get("post_attack_continuity", {}).get(
				"floor_met",
				false
			)) \
			and str(contract.get("instruction", "")) \
				== "commit_minimum_lethal_resource",
		"a secured KO must stop optional churn once the next attacker, cost, engine, and Energy bank are safe"
	)


func _test_win_now_overrides_continuity_debt() -> void:
	var observation := _completion_observation(true, 30, 70)
	observation["own"]["prizes_remaining"] = 1
	(observation["legal_actions"] as Array).insert(1, _ogerpon_ability_action())
	var facts := _facts(true, true, 70)
	facts["resources"]["prizes_remaining"] = 1
	facts["prize"]["current_swing"] = 1
	facts["prize"]["win_now"] = true
	var frontier := _frontier(observation, facts, {
		"attack:pressure": 700.0,
		"ability:teal-dance": 150.0,
		"ability:noctowl": 650.0,
		"end:premature": 0.0,
	}, "attack:pressure")
	var contract: Dictionary = TurnCompletionSolverScript.new().build(
		observation,
		facts,
		frontier,
		_profile
	)
	_check(
		not bool(contract.get("must_review_before_terminal", true)) \
			and bool(contract.get("post_attack_continuity", {}).get(
				"win_now_override",
				false
			)),
		"a final-prize KO must attack immediately instead of building a future turn"
	)


func _test_payable_gust_constraint_reaches_interaction_scoring() -> void:
	var lethal := _real_target("Lethal target", 60, 1)
	lethal.damage_counters = 30
	var nonlethal := _real_target("Nonlethal target", 220, 2)
	var lethal_instance_id := int(lethal.get_top_card().instance_id)
	var gust_candidate := {
		"candidate_id": "candidate:bound-gust",
		"route_id": "route:gust",
		"safe_prefix_action_id": "trainer:gust",
		"hard_guard_target_constraint": {
			"kind": "public_lethal_only",
			"eligible_slot_ids": ["slot:%d" % lethal_instance_id],
			"eligible_instance_ids": [lethal_instance_id],
			"max_damage": 60,
		},
	}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_current_route_id", "route:gust")
	strategy.set("_preferred_candidate_id", "candidate:bound-gust")
	strategy.set("_preferred_action_id", "trainer:gust")
	var bound_frontier: Array[Dictionary] = [gust_candidate]
	strategy.set("_last_frontier", bound_frontier)
	var lethal_score := strategy.score_interaction_target(
		lethal,
		{"id": "gust_target"}
	)
	var nonlethal_score := strategy.score_interaction_target(
		nonlethal,
		{"id": "gust_target"}
	)
	_check(
		lethal_score > 0.0 and nonlethal_score <= -100000000000.0,
		"the interaction layer must execute the hard-guard lethal target and make every nonlethal gust target impossible"
	)


func _test_multi_unit_discard_preserves_one_complete_attack_cost() -> void:
	var state := _game_state()
	var processor := EffectProcessor.new()
	var bolt_data := _real_card_data(RAGING_BOLT_UID)
	processor.register_pokemon_card(bolt_data)
	var bolt := _real_slot(bolt_data, 0)
	var ogerpon := _real_slot(_real_card_data(OGERPON_UID), 0)
	var expendable_lightning := _real_energy("CSVE1C_LIG", 0)
	var retained_lightning := _real_energy("CSVE1C_LIG", 0)
	var retained_fighting := _real_energy("CSVE1C_FIG", 0)
	var grass := _real_energy("CSVE1C_GRA", 0)
	bolt.attached_energy = [
		expendable_lightning,
		retained_lightning,
		retained_fighting,
	]
	ogerpon.attached_energy = [grass]
	state.players[0].active_pokemon = bolt
	state.players[0].bench = [ogerpon]
	state.players[1].active_pokemon = _real_target("Two-prize target", 140, 2)

	var action_ref := {
		"id": "attack:bellowing-thunder-140",
		"kind": "attack",
		"source": _slot_id(bolt),
		"source_card": _public_card(bolt.get_top_card()),
		"attack_index": 1,
		"projected_damage": 140,
		"projected_knockout": true,
		"requires_interaction": true,
	}
	var observation := {
		"observation_version": 1,
		"observation_hash": "raging-bolt-two-unit-lethal",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": _public_slot(bolt),
			"bench": [_public_slot(ogerpon)],
			"hand": [],
			"discard": [],
			"deck_count": 20,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _public_slot(state.players[1].active_pokemon),
			"bench": [],
		},
		"legal_actions": [action_ref],
	}
	var facts := _facts(true, true, 140)
	var frontier := _frontier(
		observation,
		facts,
		{"attack:bellowing-thunder-140": 1000.0},
		"attack:bellowing-thunder-140"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_last_observation", observation)
	strategy.set("_last_facts", facts)
	strategy.set("_last_frontier", frontier)
	strategy.set("_preferred_action_id", "attack:bellowing-thunder-140")
	strategy.set("_preferred_candidate_id", str(
		_candidate(frontier, "attack:bellowing-thunder-140").get(
			"candidate_id",
			""
		)
	))
	strategy.set("_current_route_id", "route:attack_ko")
	strategy.set("_current_action_owner", "module_verified_upgrade")

	var attack := bolt_data.attacks[1]
	var steps: Array[Dictionary] = processor.get_attack_interaction_steps_by_id(
		RAGING_BOLT_EFFECT_ID,
		1,
		bolt.get_top_card(),
		attack,
		state
	)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", []) if step.get("items", []) is Array else []
	var picked := strategy.pick_interaction_items(items, step, {})
	_check(
		picked.size() == 2 \
			and grass in picked \
			and (expendable_lightning in picked or retained_lightning in picked) \
			and retained_fighting not in picked,
		"a two-unit KO must spend Grass plus only one duplicate Lightning"
	)
	var remaining_symbols: Array[String] = []
	for item: CardInstance in bolt.attached_energy:
		if item not in picked:
			remaining_symbols.append(item.card_data.energy_provides)
	remaining_symbols.sort()
	_check(
		remaining_symbols == ["F", "L"],
		"minimum lethal payment must preserve one complete Lightning/Fighting attack cost"
	)


func _test_model_prompt_resolves_ko_continuity_precedence() -> void:
	var payload: Dictionary = DecisionClientScript.new().call(
		"_build_payload",
		{},
		512,
		false
	)
	var messages: Array = payload.get("messages", []) \
		if payload.get("messages", []) is Array else []
	var system_prompt := str(
		(messages[0] as Dictionary).get("content", "")
	) if not messages.is_empty() and messages[0] is Dictionary else ""
	_check(
		system_prompt.contains(
			"ko_available=true permits immediate attack only when post_attack_continuity.floor_met=true"
		),
		"the model prompt must make continuity debt take precedence over an already-payable KO"
	)


func _test_all_v18_profiles_inherit_the_completion_contract() -> void:
	var observation := _completion_observation(false, 230, 70)
	var facts := _facts(true, false, 70)
	var empty_frontier: Array[Dictionary] = []
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var strategy = StrategyScript.new()
		strategy.configure_profile(
			ProfileCatalogScript.get_profile_for_deck(deck_id),
			{}
		)
		var request: Dictionary = strategy.call(
			"_build_request_envelope",
			observation,
			facts,
			empty_frontier
		)
		var contract: Variant = request.get("turn_completion_contract", null)
		_check(
			contract is Dictionary \
				and int((contract as Dictionary).get("schema_version", 0)) == 2 \
				and (contract as Dictionary).get(
					"post_attack_continuity",
					null
				) is Dictionary,
			"deck %d must inherit the shared pre-terminal completion contract" \
				% deck_id
		)


func _completion_observation(knockout: bool, target_hp: int, damage: int) -> Dictionary:
	var active := _slot_ref(
		"slot:bolt",
		_card_ref(RAGING_BOLT_UID),
		[_energy_ref("L"), _energy_ref("F")],
		false
	)
	var ogerpon := _slot_ref(
		"slot:ogerpon",
		_card_ref(OGERPON_UID),
		[_energy_ref("G")],
		true
	)
	var noctowl := _slot_ref("slot:noctowl", _card_ref(NOCTOWL_UID), [], false)
	return {
		"observation_version": 1,
		"observation_hash": "raging-completion-%s" % str(knockout),
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {"supporter_available": true, "energy_available": true},
		},
		"own": {
			"active": active,
			"bench": [ogerpon, noctowl],
			"hand": [_energy_ref("G")],
			"hand_count": 1,
			"discard": [_energy_ref("F")],
			"deck_count": 20,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": {
				"slot_id": "slot:opponent-active",
				"pokemon": {"uid": "PUBLIC_TARGET"},
				"remaining_hp": target_hp,
				"prize_count": 1,
			},
			"bench": [],
		},
		"legal_actions": [
			{
				"id": "attack:pressure",
				"kind": "attack",
				"source": "slot:bolt",
				"source_card": _card_ref(RAGING_BOLT_UID),
				"attack_index": 1,
				"projected_damage": damage,
				"projected_knockout": knockout,
				"requires_interaction": true,
			},
			{
				"id": "ability:noctowl",
				"kind": "use_ability",
				"source": "slot:noctowl",
				"source_card": _card_ref(NOCTOWL_UID),
				"ability_index": 0,
				"requires_interaction": true,
			},
			{"id": "end:premature", "kind": "end_turn"},
		],
	}


func _ogerpon_ability_action() -> Dictionary:
	return {
		"id": "ability:teal-dance",
		"kind": "use_ability",
		"source": "slot:ogerpon",
		"source_card": _card_ref(OGERPON_UID),
		"ability_index": 0,
		"requires_interaction": true,
	}


func _frontier(
	observation: Dictionary,
	facts: Dictionary,
	scores: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation,
		scores,
		_manifest,
		facts
	)
	var rule_index := -1
	for index: int in pool.size():
		pool[index]["engine_rule_floor_exact"] = false
		if str(pool[index].get("safe_prefix_action_id", "")) == rule_action_id:
			rule_index = index
	if rule_index >= 0:
		var rule_floor := pool[rule_index].duplicate(true)
		rule_floor["engine_rule_floor_exact"] = true
		pool.remove_at(rule_index)
		pool.insert(0, rule_floor)
	return CapabilityRegistryScript.new().annotate_frontier(
		pool,
		observation,
		facts,
		_profile,
		_manifest
	)


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate %s must exist" % action_id)
	return {}


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}


func _facts(attack_ready: bool, ko_available: bool, max_damage: int) -> Dictionary:
	return {
		"attack": {
			"ready": attack_ready,
			"ko_available": ko_available,
			"max_damage": max_damage,
		},
		"board": {
			"bench_full": false,
			"has_tera": true,
			"opponent_active_remaining_hp": 30 if ko_available else 230,
		},
		"fan_call": {"available": true},
		"information": {"material_action_available": true},
		"resources": {
			"deck_low": false,
			"bench_slots_free": 2,
			"energy_on_board": 3,
			"hand_size": 1,
			"prizes_remaining": 6,
		},
		"prize": {"current_swing": 1 if ko_available else 0, "win_now": false},
		"route": {"current_valid": true},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _slot_ref(
	slot_id: String,
	pokemon: Dictionary,
	energy: Array,
	tera: bool
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": pokemon,
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": 240,
		"max_hp": 240,
		"prize_count": 2,
		"tera": tera,
	}


func _card_ref(uid: String) -> Dictionary:
	for raw_card: Variant in _manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			return {
				"uid": uid,
				"effect_id": str((raw_card as Dictionary).get("effect_id", "")),
				"name": str((raw_card as Dictionary).get("name", "")),
				"type": str((raw_card as Dictionary).get("type", "")),
				"semantic_roles": (raw_card as Dictionary).get("roles", []).duplicate(),
			}
	return {"uid": uid}


func _energy_ref(symbol: String) -> Dictionary:
	var uid: String = str({
		"G": "CSVE1C_GRA",
		"F": "CSVE1C_FIG",
		"L": "CSVE1C_LIG",
	}.get(symbol, "CSVE1C_GRA"))
	var card := _card_ref(uid)
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	card["type"] = "Basic Energy"
	return card


func _game_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card_data(uid: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % uid
	))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _real_energy(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _real_target(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	return _real_slot(data, 1)


func _public_slot(slot: PokemonSlot) -> Dictionary:
	var energy: Array = []
	for card: CardInstance in slot.attached_energy:
		energy.append(_public_card(card))
	return {
		"slot_id": _slot_id(slot),
		"pokemon": _public_card(slot.get_top_card()),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": slot.get_remaining_hp(),
		"max_hp": slot.get_max_hp(),
		"prize_count": slot.get_prize_count(),
	}


func _public_card(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	return {
		"instance_id": card.instance_id,
		"uid": card.card_data.get_uid(),
		"effect_id": card.card_data.effect_id,
		"name": card.card_data.name_en if card.card_data.name_en != "" else card.card_data.name,
		"type": card.card_data.card_type,
		"energy_type": card.card_data.energy_type,
		"energy_provides": card.card_data.energy_provides,
	}


func _slot_id(slot: PokemonSlot) -> String:
	return "slot:%d" % int(slot.get_top_card().instance_id)


func _uids(items: Array) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in items:
		if item is CardInstance and (item as CardInstance).card_data != null:
			result.append((item as CardInstance).card_data.get_uid())
	result.sort()
	return result


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain JSON" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
