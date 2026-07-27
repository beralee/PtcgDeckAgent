extends SceneTree

const ObservationGatewayScript = preload(
	"res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd"
)
const ResourceLedgerScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGResourceLedger.gd"
)
const TransitionStateScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionState.gd"
)
const TransitionEvaluatorScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGCandidateTransitionEvaluator.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_test_manual_attachment_prediction_matches_engine()
	_test_stale_prediction_cannot_authorize_a_second_attachment()
	if _failures.is_empty():
		print("V18CPG route-value execution witness: PASS (2 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG route-value execution witness: FAIL (%d)" % _failures.size())
	quit(1)


func _test_manual_attachment_prediction_matches_engine() -> void:
	var fixture := _attachment_fixture()
	var gsm: GameStateMachine = fixture["gsm"]
	var player: PlayerState = gsm.game_state.players[0]
	var energy: CardInstance = fixture["energy"]
	var active: PokemonSlot = player.active_pokemon
	var raw_action := {
		"kind": "attach_energy",
		"card": energy,
		"target_slot": active,
	}
	var gateway = ObservationGatewayScript.new()
	var before: Dictionary = gateway.build(
		gsm.game_state,
		0,
		[raw_action]
	)
	var action_ref: Dictionary = before.get("legal_actions", [])[0]
	var ledger := ResourceLedgerScript.new().build(before, {}, {})
	var state := TransitionStateScript.new().build(
		before,
		ledger,
		{},
		{}
	)
	var transition: Dictionary = TransitionEvaluatorScript.new().evaluate(
		{
			"candidate_id": "candidate:witness",
			"route_id": "route:energy_commit",
			"action_kind": "attach_energy",
			"safe_prefix_action_id": str(action_ref.get("id", "")),
			"action_ref": action_ref,
			"checkpoint_after": "action_resolved",
		},
		state,
		before,
		{}
	)
	var executed := gsm.attach_energy(0, energy, active)
	var after: Dictionary = gateway.build(gsm.game_state, 0, [])
	_check(executed, "engine witness attachment must execute")
	_check(bool(transition.get("supported", false)), "transition must support the same exact engine action")
	_check(
		int(transition.get("predicted_state", {}).get("own", {}).get("active", {}).get("energy_count", -1))
			== int(after.get("own", {}).get("active", {}).get("energy_count", -2)),
		"predicted attached energy count must match the real engine state"
	)
	_check(
		bool(transition.get("predicted_state", {}).get("quotas", {}).get("energy_attachment", true))
			== bool(after.get("turn", {}).get("quotas", {}).get("energy_available", false)),
		"predicted energy quota must match the real engine state"
	)
	_check(
		str(transition.get("transition_certificate", {}).get("source_state_hash", ""))
			!= str(transition.get("transition_certificate", {}).get("predicted_state_hash", "")),
		"a material transition must change the public state hash"
	)


func _test_stale_prediction_cannot_authorize_a_second_attachment() -> void:
	var fixture := _attachment_fixture()
	var gsm: GameStateMachine = fixture["gsm"]
	var player: PlayerState = gsm.game_state.players[0]
	var first_energy: CardInstance = fixture["energy"]
	var active: PokemonSlot = player.active_pokemon
	_check(gsm.attach_energy(0, first_energy, active), "first engine attachment must execute")
	var second_data := CardData.new()
	second_data.card_type = "Basic Energy"
	second_data.energy_provides = "F"
	var second_energy := CardInstance.create(second_data, 0)
	player.hand.append(second_energy)
	var gateway = ObservationGatewayScript.new()
	var observation := gateway.build(gsm.game_state, 0, [])
	var state := TransitionStateScript.new().build(
		observation,
		ResourceLedgerScript.new().build(observation, {}, {}),
		{},
		{}
	)
	var synthetic_action := {
		"id": "action:stale-second-attach",
		"kind": "attach_energy",
		"target": str(observation.get("own", {}).get("active", {}).get("slot_id", "")),
		"card": {
			"instance_id": second_energy.instance_id,
			"uid": second_energy.card_data.get_uid(),
			"type": "Basic Energy",
			"energy_provides": "F",
		},
	}
	var transition: Dictionary = TransitionEvaluatorScript.new().evaluate(
		{
			"candidate_id": "candidate:stale",
			"route_id": "route:energy_commit",
			"action_kind": "attach_energy",
			"safe_prefix_action_id": "action:stale-second-attach",
			"action_ref": synthetic_action,
			"checkpoint_after": "action_resolved",
		},
		state,
		observation,
		{}
	)
	_check(not bool(transition.get("supported", true)), "spent quota must reject a stale projected attachment")
	_check(
		str(transition.get("unsupported_reason", "")) == "energy_quota_spent",
		"stale prediction must fail for the exact quota reason"
	)
	_check(
		not gsm.attach_energy(0, second_energy, active),
		"real engine must agree that the second attachment is illegal"
	)


func _attachment_fixture() -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	var pokemon_data := CardData.new()
	pokemon_data.name_en = "Witness Pokemon"
	pokemon_data.card_type = "Pokemon"
	pokemon_data.stage = "Basic"
	pokemon_data.hp = 120
	pokemon_data.retreat_cost = 1
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(pokemon_data, 0))
	gsm.game_state.players[0].active_pokemon = active
	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(pokemon_data, 1))
	gsm.game_state.players[1].active_pokemon = opponent_active
	var energy_data := CardData.new()
	energy_data.card_type = "Basic Energy"
	energy_data.energy_provides = "L"
	var energy := CardInstance.create(energy_data, 0)
	gsm.game_state.players[0].hand.append(energy)
	return {"gsm": gsm, "energy": energy}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
