class_name TestV18GardevoirMunkidoriDebtRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")

const DECK_PATH := "res://data/bundled_user/decks/800017097.json"
const RABSCA_DECK_PATH := "res://data/bundled_user/decks/800018105.json"
const LEGACY_SIBLING_DECK_PATH := "res://data/bundled_user/decks/578647.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd"
const USED_MARKER := "ability_move_counters_to_opp_used"


func test_registry_debt_ability_outranks_legal_scream_tail_and_drifloon_attacks() -> String:
	var strategy := _registry_strategy(DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")
	var delegate: Variant = strategy.get("_delegate")
	var scream := _scenario(strategy, "CSV6C_065", 40, 260)
	var drifloon := _scenario(strategy, "CSV2C_060", 40, 260)
	return run_checks([
		assert_not_null(delegate, "Deck 800017097 should expose its configured delegate"),
		assert_eq(str(delegate.get_script().resource_path), DELEGATE_PATH, "Debt scoring must run through the production V18 Gardevoir variant delegate"),
		assert_false((scream.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori should be a legal action beside Scream Tail"),
		assert_false((scream.get("attack_action", {}) as Dictionary).is_empty(), "Roaring Scream should be a legal production attack"),
		assert_true(bool(scream.get("debt_live", false)), "Safe Munkidori debt should stay live despite the production Drifloon package"),
		assert_true(float(scream.get("ability_score", 0.0)) > float(scream.get("attack_score", 0.0)), "Safe Munkidori debt must outrank non-final Scream Tail attack"),
		assert_false((drifloon.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori should be a legal action beside Drifloon"),
		assert_false((drifloon.get("attack_action", {}) as Dictionary).is_empty(), "Balloon Blast should be a legal production attack"),
		assert_true(bool(drifloon.get("debt_live", false)), "The same safe debt should be live beside Drifloon"),
		assert_true(float(drifloon.get("ability_score", 0.0)) > float(drifloon.get("attack_score", 0.0)), "Safe Munkidori debt must outrank non-final Drifloon attack"),
	])


func test_used_marker_releases_debt_and_restores_attack_priority() -> String:
	var strategy := _registry_strategy(DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")
	var scenario := _scenario(strategy, "CSV6C_065", 40, 260)
	var state: GameState = scenario.get("state", null)
	var munkidori: PokemonSlot = scenario.get("munkidori", null)
	var builder: RefCounted = scenario.get("builder", null)
	if state == null or munkidori == null or builder == null:
		return assert_true(false, "Used-marker scenario should expose its production state")
	munkidori.effects.append({"type": USED_MARKER, "turn": state.turn_number})
	var actions := _actions(builder, scenario.get("gsm", null))
	var current_ability := _find_action(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == munkidori
	)
	var current_attack := _find_action(actions, "attack", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == state.players[0].active_pokemon and int(action.get("attack_index", -1)) == 1
	)
	var stale_ability: Dictionary = scenario.get("ability_action", {})
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var stale_ability_score := float(strategy.call("score_action_absolute_with_plan", stale_ability, state, 0, contract))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", current_attack, state, 0, contract))
	return run_checks([
		assert_true(bool(scenario.get("debt_live", false)), "Debt should be live before Munkidori is marked used"),
		assert_true(current_ability.is_empty(), "The used Munkidori ability should no longer be a legal action"),
		assert_false(current_attack.is_empty(), "The ready attack should remain legal after Munkidori resolves"),
		assert_false(bool(flags.get("munkidori_damage_transfer_debt", false)), "The used marker should retire Munkidori debt immediately"),
		assert_true(attack_score > stale_ability_score, "Normal attack priority should resume after the used marker"),
	])


func test_debt_stays_closed_without_darkness_or_safe_damage() -> String:
	var strategy := _registry_strategy(DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")
	var no_darkness := _scenario(strategy, "CSV6C_065", 40, 260, -1, 30, false)
	var no_damage := _scenario(strategy, "CSV6C_065", 0, 260, -1, 0, true)
	return run_checks([
		assert_false(bool(no_darkness.get("debt_live", true)), "Munkidori debt still requires Darkness Energy"),
		assert_true((no_darkness.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori without Darkness should remain illegal"),
		assert_false(bool(no_damage.get("debt_live", true)), "Munkidori debt still requires movable safe damage"),
		assert_true((no_damage.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori without movable damage should remain illegal"),
	])


func test_ready_drifloon_and_scream_tail_knockouts_preserve_their_damage() -> String:
	var strategy := _registry_strategy(DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")
	var drifloon_ko := _scenario(strategy, "CSV2C_060", 30, 80, -1, 0)
	var scream_bench_ko := _scenario(strategy, "CSV6C_065", 40, 260, 80, 0)
	return run_checks([
		assert_false((drifloon_ko.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori remains legally usable when Drifloon is damaged"),
		assert_false((drifloon_ko.get("attack_action", {}) as Dictionary).is_empty(), "Drifloon's knockout attack should be legal"),
		assert_false(bool(drifloon_ko.get("debt_live", true)), "Drifloon damage must not become forced debt when it supplies an active knockout"),
		assert_true(float(drifloon_ko.get("attack_score", 0.0)) > float(drifloon_ko.get("ability_score", 0.0)), "The available Drifloon knockout should keep attack priority"),
		assert_false((scream_bench_ko.get("ability_action", {}) as Dictionary).is_empty(), "Munkidori remains legally usable when Scream Tail is damaged"),
		assert_false((scream_bench_ko.get("attack_action", {}) as Dictionary).is_empty(), "Scream Tail's targeted attack should be legal"),
		assert_false(bool(scream_bench_ko.get("debt_live", true)), "Scream Tail damage must not become forced debt when it supplies a bench knockout"),
		assert_true(float(scream_bench_ko.get("attack_score", 0.0)) > float(scream_bench_ko.get("ability_score", 0.0)), "The available Scream Tail bench knockout should keep attack priority"),
	])


func test_final_prize_attack_remains_exempt_from_safe_debt_priority() -> String:
	var strategy := _registry_strategy(DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")
	var final_route := _scenario(strategy, "CSV2C_060", 30, 80, -1, 30, true, 1)
	var attack_action: Dictionary = final_route.get("attack_action", {})
	return run_checks([
		assert_true(bool(final_route.get("debt_live", false)), "Separate Gardevoir damage should keep safe Munkidori debt live"),
		assert_true(bool(attack_action.get("projected_knockout", false)), "The legal Drifloon attack should project the final knockout"),
		assert_true(float(final_route.get("attack_score", 0.0)) > float(final_route.get("ability_score", 0.0)), "A final-prize attack must remain above optional safe debt"),
	])


func test_rabsca_gardevoir_explicitly_opts_in_to_munkidori_debt() -> String:
	var strategy := _registry_strategy(RABSCA_DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800018105 should resolve through DeckStrategyRegistry")
	var scenario := _scenario(strategy, "CSV6C_065", 40, 260)
	return run_checks([
		assert_false((scenario.get("ability_action", {}) as Dictionary).is_empty(), "Rabsca Gardevoir Munkidori should remain legally usable from board state"),
		assert_false((scenario.get("attack_action", {}) as Dictionary).is_empty(), "Rabsca Gardevoir Scream Tail attack should remain legal"),
		assert_true(bool(scenario.get("debt_live", false)), "Deck 800018105 should retain its later exact-ID R06 Munkidori debt opt-in"),
		assert_true(float(scenario.get("ability_score", 0.0)) > float(scenario.get("attack_score", 0.0)), "Rabsca Gardevoir should resolve safe Munkidori debt before a non-final attack"),
	])


func test_legacy_gardevoir_sibling_does_not_inherit_v18_debt_opt_ins() -> String:
	var strategy := _registry_strategy(LEGACY_SIBLING_DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 578647 should resolve through DeckStrategyRegistry")
	var scenario := _scenario(strategy, "CSV6C_065", 40, 260)
	return run_checks([
		assert_false((scenario.get("ability_action", {}) as Dictionary).is_empty(), "Legacy Gardevoir Munkidori should remain legally usable from board state"),
		assert_false((scenario.get("attack_action", {}) as Dictionary).is_empty(), "Legacy Gardevoir Scream Tail attack should remain legal"),
		assert_false(bool(scenario.get("debt_live", true)), "Deck 578647 must not inherit the V18 exact-ID debt opt-ins"),
		assert_true(float(scenario.get("attack_score", 0.0)) > float(scenario.get("ability_score", 0.0)), "Legacy Gardevoir attack scoring should remain unchanged"),
	])


func _scenario(
	strategy: RefCounted,
	attacker_ref: String,
	attacker_damage: int,
	active_defender_hp: int,
	bench_defender_hp: int = -1,
	safe_source_damage: int = 30,
	attach_darkness: bool = true,
	prize_count: int = 6
) -> Dictionary:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	var state := _main_phase_state(prize_count)
	gsm.game_state = state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(_real_card_data(attacker_ref), 0)
	attacker.damage_counters = attacker_damage
	attacker.attached_energy.assign([_energy("P", 0), _energy("P", 0)])
	var gardevoir := _slot(_real_card_data("CSV2C_055"), 0)
	gardevoir.damage_counters = safe_source_damage
	var munkidori := _slot(_real_card_data("CSV8C_094"), 0)
	if attach_darkness:
		munkidori.attached_energy.append(_energy("D", 0))
	player.active_pokemon = attacker
	player.bench.assign([gardevoir, munkidori])
	opponent.active_pokemon = _slot(_defender("Active Defender", active_defender_hp), 1)
	if bench_defender_hp > 0:
		opponent.bench.append(_slot(_defender("Bench Defender", bench_defender_hp), 1))

	var builder: RefCounted = ACTION_BUILDER_SCRIPT.new()
	builder.call("set_deck_strategy", strategy)
	var actions := _actions(builder, gsm)
	var ability_action := _find_action(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == munkidori
	)
	var attack_action := _find_action(actions, "attack", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == attacker and int(action.get("attack_index", -1)) == 1
	)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var ability_score := float(strategy.call("score_action_absolute_with_plan", ability_action, state, 0, contract)) \
		if not ability_action.is_empty() else -INF
	var attack_score := float(strategy.call("score_action_absolute_with_plan", attack_action, state, 0, contract)) \
		if not attack_action.is_empty() else -INF
	return {
		"gsm": gsm,
		"state": state,
		"builder": builder,
		"munkidori": munkidori,
		"ability_action": ability_action,
		"attack_action": attack_action,
		"ability_score": ability_score,
		"attack_score": attack_score,
		"debt_live": bool(flags.get("munkidori_damage_transfer_debt", false)),
	}


func _registry_strategy(deck_path: String) -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(deck_path))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _main_phase_state(prize_count: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 9
	state.phase = GameState.GamePhase.MAIN
	for index: int in 12:
		player.deck.append(_filler("Player deck %d" % index, 0))
		opponent.deck.append(_filler("Opponent deck %d" % index, 1))
	for index: int in prize_count:
		player.prizes.append(_filler("Player prize %d" % index, 0))
	for index: int in 6:
		opponent.prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _actions(builder: RefCounted, gsm: GameStateMachine) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if builder == null or gsm == null:
		return result
	var raw: Variant = builder.call("build_actions", gsm, 0, false)
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				result.append(item)
	return result


func _find_action(actions: Array[Dictionary], kind: String, predicate: Callable = Callable()) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if predicate.is_valid() and not bool(predicate.call(action)):
			continue
		return action
	return {}


func _real_card_data(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _energy(energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy" if energy_type == "P" else "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _defender(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _filler(card_name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)
