class_name TestV18PureDragapultLiabilityAttachmentRound3
extends TestBase


const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const AI_OPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")

const DECK_ID := 800018499
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategy175PureDragapult.gd"
const MARACTUS_UID := "CSV10C_008"
const MARACTUS_EFFECT_ID := "a5b32602f9c443a038fef288059aeb43"
const HAWLUCHA_UID := "CSV1C_079"
const HAWLUCHA_EFFECT_ID := "74b83ef8987d072950dfe3bde3364d87"
const DRAGAPULT_UID := "CSV8C_159"
const LUMINOUS_UID := "CSV1C_127"
const FIRE_UID := "CSVE1C_FIR"
const PSYCHIC_UID := "CSVE1C_PSY"


func test_partial_maractus_attachment_is_suppressed_only_for_live_core_payment() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var guarded_state := _attachment_state(MARACTUS_UID)
	var guarded_player: PlayerState = guarded_state.players[0]
	var guarded_luminous := _find_hand_card(guarded_player, LUMINOUS_UID)
	var guarded_fire := _find_hand_card(guarded_player, FIRE_UID)
	var guarded_core: PokemonSlot = guarded_player.bench[0]
	var guarded_liability_score := _score(strategy, {
		"kind": "attach_energy",
		"card": guarded_luminous,
		"target_slot": guarded_player.active_pokemon,
	}, guarded_state)
	var core_score := _score(strategy, {
		"kind": "attach_energy",
		"card": guarded_fire,
		"target_slot": guarded_core,
	}, guarded_state)

	var no_alternative_state := _attachment_state(MARACTUS_UID)
	var no_alternative_player: PlayerState = no_alternative_state.players[0]
	var no_alternative_luminous := _find_hand_card(no_alternative_player, LUMINOUS_UID)
	no_alternative_player.hand.erase(_find_hand_card(no_alternative_player, FIRE_UID))
	var unguarded_liability_score := _score(strategy, {
		"kind": "attach_energy",
		"card": no_alternative_luminous,
		"target_slot": no_alternative_player.active_pokemon,
	}, no_alternative_state)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Round 3 must exercise the production V18 rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800018499 must keep its Pure Dragapult delegate"),
		assert_eq(str(guarded_player.active_pokemon.get_card_data().effect_id), MARACTUS_EFFECT_ID, "The partial-retreat fixture must use real Maractus"),
		assert_true(_ready_dragapult(strategy, guarded_player) == null, "The attachment guard requires no Phantom Dive-ready Dragapult"),
		assert_true(
			guarded_liability_score + 500.0 < unguarded_liability_score,
			"Partial Maractus retreat payment should be suppressed only while another hand Energy completes RP (guarded=%f released=%f)" % [
				guarded_liability_score, unguarded_liability_score,
			]
		),
		assert_true(
			core_score > guarded_liability_score,
			"The completing Fire-to-Dragapult attachment must outrank partial Luminous-to-Maractus (core=%f liability=%f)" % [
				core_score, guarded_liability_score,
			]
		),
	])


func test_dragapult_ex_payment_helper_finds_the_alternate_single_attachment() -> String:
	var strategy := _production_strategy()
	var delegate := _delegate(strategy)
	if strategy == null or delegate == null:
		return assert_true(false, "Pure Dragapult production strategy and delegate should instantiate")
	var state := _attachment_state(MARACTUS_UID)
	var player: PlayerState = state.players[0]
	var dragapult: PokemonSlot = player.bench[0]
	var fire := _find_hand_card(player, FIRE_UID)
	var luminous := _find_hand_card(player, LUMINOUS_UID)
	var combinations: Array = delegate.call("_v175_first_attack_payment_combinations", player, dragapult)
	var default_discard_scope_has_payment := bool(delegate.call(
		"_v175_has_first_attack_payment_combination",
		player
	))
	var stage_two_scope_has_payment := bool(delegate.call(
		"_v175_has_first_attack_payment_combination",
		player,
		null,
		true
	))
	var found_fire_completion := false
	for combination: Array in combinations:
		if combination.size() == 1 and combination[0] == fire:
			found_fire_completion = true
			break
	return run_checks([
		assert_eq(_card_uid(dragapult.get_top_card()), DRAGAPULT_UID, "The payment helper fixture must use fielded real Dragapult ex"),
		assert_true(luminous in player.hand and fire in player.hand, "Both competing legal Energy cards must remain in hand"),
		assert_true(found_fire_completion, "A fielded Dragapult ex with Psychic attached should expose Fire as a one-attachment RP completion"),
		assert_false(default_discard_scope_has_payment, "Existing discard calls must keep their Dreepy/Drakloak-only route scope"),
		assert_true(stage_two_scope_has_payment, "Attachment scoring may opt into fielded Dragapult ex payment lookup"),
	])


func test_full_retreat_payment_releases_both_real_liabilities() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var partial_state := _attachment_state(MARACTUS_UID)
	var partial_player: PlayerState = partial_state.players[0]
	var partial_score := _score(strategy, {
		"kind": "attach_energy",
		"card": _find_hand_card(partial_player, LUMINOUS_UID),
		"target_slot": partial_player.active_pokemon,
	}, partial_state)
	var checks: Array[String] = []
	for fixture: Dictionary in [
		{"uid": MARACTUS_UID, "effect_id": MARACTUS_EFFECT_ID, "pre_attached": true},
		{"uid": HAWLUCHA_UID, "effect_id": HAWLUCHA_EFFECT_ID, "pre_attached": false},
	]:
		var state := _attachment_state(str(fixture.get("uid", "")), bool(fixture.get("pre_attached", false)))
		var player: PlayerState = state.players[0]
		var luminous := _find_hand_card(player, LUMINOUS_UID)
		var released_score := _score(strategy, {
			"kind": "attach_energy",
			"card": luminous,
			"target_slot": player.active_pokemon,
		}, state)
		var remaining_retreat_gap := maxi(
			0,
			int(player.active_pokemon.get_card_data().retreat_cost) - player.active_pokemon.attached_energy.size() - 1
		)
		checks.append(assert_eq(
			str(player.active_pokemon.get_card_data().effect_id),
			str(fixture.get("effect_id", "")),
			"The release fixture must retain the real liability effect identity"
		))
		checks.append(assert_eq(remaining_retreat_gap, 0, "The proposed attachment must fully pay the Active retreat cost"))
		checks.append(assert_true(
			released_score > partial_score + 500.0,
			"A full retreat payment must release %s from the partial-payment guard (released=%f partial=%f)" % [
				str(fixture.get("uid", "")), released_score, partial_score,
			]
		))
	return run_checks(checks)


func test_legal_action_selection_prefers_fire_to_dragapult_over_luminous_to_maractus() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var state := _attachment_state(MARACTUS_UID)
	var player: PlayerState = state.players[0]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := AILegalActionBuilder.new()
	builder.set_deck_strategy(strategy)
	var actions := builder.build_actions(gsm, 0)
	var luminous_to_maractus := _find_attach_action(
		actions,
		LUMINOUS_UID,
		player.active_pokemon
	)
	var fire_to_dragapult := _find_attach_action(actions, FIRE_UID, player.bench[0])
	var ai = AI_OPPONENT_SCRIPT.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var turn_contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, turn_contract)
	var best_action: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}
	return run_checks([
		assert_false(luminous_to_maractus.is_empty(), "Legal actions must contain Luminous-to-Maractus"),
		assert_false(fire_to_dragapult.is_empty(), "Legal actions must contain Fire-to-Dragapult"),
		assert_eq(str(best_action.get("kind", "")), "attach_energy", "The production rules selector should choose an Energy attachment"),
		assert_eq(_card_uid(best_action.get("card", null)), FIRE_UID, "The selected Energy should be basic Fire"),
		assert_true(best_action.get("target_slot", null) == player.bench[0], "The selected target should be the fielded Dragapult ex"),
	])


func _production_strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return STRATEGY_REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attachment_state(active_uid: String, active_has_retreat_energy: bool = false) -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
		_set_prizes(player, 6)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card(active_uid, 0))
	if active_has_retreat_energy:
		player.active_pokemon.attached_energy.append(_real_card(PSYCHIC_UID, 0))
	var dragapult := _slot(_real_card(DRAGAPULT_UID, 0))
	dragapult.attached_energy.append(_real_card(PSYCHIC_UID, 0))
	player.bench.append(dragapult)
	player.hand.assign([
		_real_card(LUMINOUS_UID, 0),
		_real_card(FIRE_UID, 0),
	])
	state.players[1].active_pokemon = _slot(_real_card("CSV1C_050", 1))
	return state


func _ready_dragapult(strategy: RefCounted, player: PlayerState) -> PokemonSlot:
	var delegate := _delegate(strategy)
	if delegate == null:
		return null
	var value: Variant = delegate.call("_best_ready_dragapult_slot", player)
	return value as PokemonSlot if value is PokemonSlot else null


func _delegate(strategy: RefCounted) -> RefCounted:
	if strategy == null:
		return null
	var value: Variant = strategy.get("_delegate")
	return value as RefCounted if value is RefCounted else null


func _delegate_path(strategy: RefCounted) -> String:
	var value := _delegate(strategy)
	return value.get_script().resource_path if value != null else ""


func _find_attach_action(actions: Array[Dictionary], card_uid: String, target: PokemonSlot) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != "attach_energy":
			continue
		if _card_uid(action.get("card", null)) == card_uid and action.get("target_slot", null) == target:
			return action
	return {}


func _find_hand_card(player: PlayerState, uid: String) -> CardInstance:
	for card: CardInstance in player.hand:
		if _card_uid(card) == uid:
			return card
	return null


func _set_prizes(player: PlayerState, count: int) -> void:
	for index: int in count:
		var card_data := CardData.new()
		card_data.name = "Prize %d" % index
		card_data.name_en = card_data.name
		card_data.card_type = "Item"
		player.prizes.append(CardInstance.create(card_data, player.player_index))


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parts := uid.rsplit("_", true, 1)
	var card_data: CardData = CardDatabase.get_card(parts[0], parts[1]) if parts.size() == 2 else null
	return CardInstance.create(card_data, owner_index) if card_data != null else null


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _card_uid(card: Variant) -> String:
	if card is CardInstance:
		var instance := card as CardInstance
		return instance.card_data.get_uid() if instance.card_data != null else ""
	return ""
