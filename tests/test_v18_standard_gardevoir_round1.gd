class_name TestV18StandardGardevoirRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")

const STANDARD_DECK_PATH := "res://data/bundled_user/decks/800018497.json"
const VARIANT_DECK_PATH := "res://data/bundled_user/decks/800017097.json"
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const MATURE_GARDEVOIR_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"
const GARDEVOIR_VARIANTS_PATH := "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd"


func test_registry_resolves_standard_deck_to_mature_gardevoir_delegate() -> String:
	var strategy := _registry_strategy(STANDARD_DECK_PATH)
	var variant_strategy := _registry_strategy(VARIANT_DECK_PATH)
	if strategy == null or variant_strategy == null:
		return assert_true(false, "Both production Gardevoir strategies should resolve through DeckStrategyRegistry")
	var delegate: Variant = strategy.get("_delegate")
	var variant_delegate: Variant = variant_strategy.get("_delegate")
	return run_checks([
		assert_eq(str(strategy.get_script().resource_path), RULES_PATH, "Deck 800018497 should use the production V18 rules wrapper"),
		assert_not_null(delegate, "Deck 800018497 should expose its configured Gardevoir delegate"),
		assert_eq(str(delegate.get_script().resource_path), MATURE_GARDEVOIR_PATH, "Deck 800018497 should use the mature Gardevoir delegate"),
		assert_eq(str(delegate.call("get_strategy_id")), "gardevoir", "Deck 800018497 should keep the mature Gardevoir strategy identity"),
		assert_not_null(variant_delegate, "The existing no-balloon variant should keep its delegate"),
		assert_eq(str(variant_delegate.get_script().resource_path), GARDEVOIR_VARIANTS_PATH, "The existing variant atomic route must remain on its deck-owned delegate"),
	])


func test_standard_gardevoir_atomic_escape_recycles_retreat_energy_into_scream_tail_ko() -> String:
	var strategy := _registry_strategy(STANDARD_DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800018497 should resolve through DeckStrategyRegistry")

	var gardevoir_card := CardDatabase.get_card("CSV2C", "055")
	var scream_tail_card := CardDatabase.get_card("CSV6C", "065")
	var kirlia_card := CardDatabase.get_card("CS6.5C", "030")
	var charm_card := CardDatabase.get_card("CSV1C", "118")
	var psychic_card := CardDatabase.get_card("CSVE1C", "PSY")
	var research_card := CardDatabase.get_card("CSV1C", "121")
	var iono_card := CardDatabase.get_card("CSV3C", "123")
	if gardevoir_card == null or scream_tail_card == null or kirlia_card == null \
			or charm_card == null or psychic_card == null or research_card == null or iono_card == null:
		return assert_true(false, "The production Gardevoir atomic-escape cards should load from CardDatabase")

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	var state := _main_phase_state()
	gsm.game_state = state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var gardevoir := _slot(gardevoir_card, 0)
	var scream_tail := _slot(scream_tail_card, 0)
	var kirlia := _slot(kirlia_card, 0)
	var defender := _slot(_defender_card(), 1)
	var manual_psychic := CardInstance.create(psychic_card, 0)
	var discard_psychic := CardInstance.create(psychic_card, 0)
	var research := CardInstance.create(research_card, 0)
	var iono := CardInstance.create(iono_card, 0)
	scream_tail.attached_tool = CardInstance.create(charm_card, 0)
	player.active_pokemon = gardevoir
	player.bench.assign([scream_tail, kirlia])
	player.hand.assign([manual_psychic, research, iono])
	player.discard_pile.append(discard_psychic)
	opponent.active_pokemon = defender

	var builder: RefCounted = ACTION_BUILDER_SCRIPT.new()
	builder.call("set_deck_strategy", strategy)
	var checks: Array[String] = [
		assert_eq(gardevoir.attached_energy.size(), 0, "The gusted Active Gardevoir should start with zero Energy"),
		assert_eq(scream_tail.attached_energy.size(), 0, "The Charmed Scream Tail should start with zero Energy"),
		assert_not_null(scream_tail.attached_tool, "Scream Tail should carry Bravery Charm for the two-Embrace route"),
		assert_eq(_psychic_count(player.discard_pile), 1, "The discard should start with the minimum Psychic fuel for the atomic recycle"),
	]

	var actions := _actions(builder, gsm)
	var manual_attach := _find_action(actions, "attach_energy", func(action: Dictionary) -> bool:
		return action.get("card", null) == manual_psychic and action.get("target_slot", null) == gardevoir
	)
	checks.append(assert_false(manual_attach.is_empty(), "Manual Psychic attachment to Active Gardevoir should be legal"))
	checks.append_array(_route_dominance_checks(strategy, state, actions, manual_attach, kirlia, "manual attach to Gardevoir"))
	var attached := false if manual_attach.is_empty() else gsm.attach_energy(0, manual_psychic, gardevoir)
	checks.append(assert_true(attached, "GameStateMachine should execute the manual attachment"))
	checks.append(assert_eq(gardevoir.attached_energy.size(), 1, "Gardevoir should hold the manual retreat Energy"))

	actions = _actions(builder, gsm)
	var first_embrace_action := _find_action(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == gardevoir and int(action.get("ability_index", -1)) == 0
	)
	checks.append(assert_false(first_embrace_action.is_empty(), "Psychic Embrace should be legal after the manual attachment"))
	checks.append_array(_route_dominance_checks(strategy, state, actions, first_embrace_action, kirlia, "Embrace to Gardevoir"))
	var first_pick: Variant = _pick_embrace_target(strategy, gsm, gardevoir)
	checks.append(assert_eq(first_pick, gardevoir, "The first Psychic Embrace must finish Gardevoir's retreat cost"))
	var first_embrace := _use_embrace(gsm, gardevoir, discard_psychic, first_pick)
	checks.append(assert_true(first_embrace, "GameStateMachine should execute Psychic Embrace on Gardevoir"))
	checks.append(assert_eq(gardevoir.attached_energy.size(), 2, "Gardevoir should reach its exact two-Energy retreat cost"))

	actions = _actions(builder, gsm)
	var retreat := _find_action(actions, "retreat", func(action: Dictionary) -> bool:
		return action.get("bench_target", null) == scream_tail and (action.get("energy_to_discard", []) as Array).size() == 2
	)
	checks.append(assert_false(retreat.is_empty(), "The paid retreat into Scream Tail should be legal"))
	checks.append_array(_route_dominance_checks(strategy, state, actions, retreat, kirlia, "retreat into Scream Tail"))
	var retreat_energy: Array[CardInstance] = []
	if not retreat.is_empty():
		for item: Variant in retreat.get("energy_to_discard", []):
			if item is CardInstance:
				retreat_energy.append(item)
	var retreated := not retreat_energy.is_empty() and gsm.retreat(0, retreat_energy, scream_tail)
	checks.append(assert_true(retreated, "GameStateMachine should retreat Gardevoir by discarding both Psychic Energy"))
	checks.append(assert_eq(player.active_pokemon, scream_tail, "Scream Tail should become Active after the retreat"))
	checks.append(assert_eq(gardevoir.attached_energy.size(), 0, "The former Active Gardevoir should have no Energy after retreat"))
	checks.append(assert_eq(_psychic_count(player.discard_pile), 2, "Both retreat Energy should become the exact Scream Tail rebuild fuel"))

	for embrace_number: int in [1, 2]:
		actions = _actions(builder, gsm)
		var embrace_action := _find_action(actions, "use_ability", func(action: Dictionary) -> bool:
			return action.get("source_slot", null) == gardevoir and int(action.get("ability_index", -1)) == 0
		)
		checks.append(assert_false(embrace_action.is_empty(), "Psychic Embrace %d to Scream Tail should be legal" % embrace_number))
		checks.append_array(_route_dominance_checks(strategy, state, actions, embrace_action, kirlia, "Embrace %d to Scream Tail" % embrace_number))
		var scream_pick: Variant = _pick_embrace_target(strategy, gsm, gardevoir)
		checks.append(assert_eq(scream_pick, scream_tail, "Psychic Embrace %d must target the Active Scream Tail" % embrace_number))
		var next_energy: CardInstance = _first_psychic(player.discard_pile)
		checks.append(assert_not_null(next_energy, "Retreat fuel should remain for Psychic Embrace %d" % embrace_number))
		var embraced := next_energy != null and _use_embrace(gsm, gardevoir, next_energy, scream_pick)
		checks.append(assert_true(embraced, "GameStateMachine should execute Psychic Embrace %d on Scream Tail" % embrace_number))
		checks.append(assert_eq(scream_tail.attached_energy.size(), embrace_number, "Scream Tail should gain one Psychic Energy per Embrace"))
		checks.append(assert_eq(scream_tail.damage_counters, embrace_number * 20, "Scream Tail should gain two damage counters per Embrace"))

	actions = _actions(builder, gsm)
	var roaring_scream := _find_action(actions, "attack", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == scream_tail and int(action.get("attack_index", -1)) == 1
	)
	checks.append(assert_false(roaring_scream.is_empty(), "Roaring Scream should be a legal production attack after two Embraces"))
	checks.append(assert_eq(int(roaring_scream.get("projected_damage", -1)), 80, "The production action builder should preview Roaring Scream's dynamic 80 damage"))
	checks.append(assert_true(bool(roaring_scream.get("projected_knockout", false)), "The production action builder should mark the visible 80 HP knockout"))
	var attack_prediction: Dictionary = strategy.call("predict_attacker_damage", scream_tail, 0)
	checks.append(assert_eq(int(attack_prediction.get("damage", -1)), 80, "The mature Gardevoir delegate should predict 80 Roaring Scream damage"))
	checks.append(assert_true(bool(attack_prediction.get("can_attack", false)), "The mature delegate should identify Roaring Scream as fully powered"))
	checks.append_array(_route_dominance_checks(strategy, state, actions, roaring_scream, kirlia, "Roaring Scream knockout"))
	var attacked := not roaring_scream.is_empty() and gsm.use_attack(0, 1, [{"target_pokemon": [defender]}])
	checks.append(assert_true(attacked, "GameStateMachine should execute Roaring Scream"))
	checks.append(assert_eq(defender.damage_counters, 80, "Roaring Scream preview support must not double-apply its effect damage"))
	checks.append(assert_true(defender.is_knocked_out(), "Roaring Scream should knock out the 80 HP target"))
	checks.append(assert_true(opponent.active_pokemon != defender, "The knocked-out target should leave the opponent's Active Spot"))

	return run_checks(checks)


func test_gust_insurance_waits_for_active_charmed_scream_tail_visible_ko_threshold() -> String:
	var strategy := _registry_strategy(STANDARD_DECK_PATH)
	if strategy == null:
		return assert_true(false, "Deck 800018497 should resolve through DeckStrategyRegistry")
	var delegate: Variant = strategy.get("_delegate")
	if delegate == null:
		return assert_true(false, "Deck 800018497 should expose the mature Gardevoir delegate")

	var gardevoir_card := CardDatabase.get_card("CSV2C", "055")
	var scream_tail_card := CardDatabase.get_card("CSV6C", "065")
	var charm_card := CardDatabase.get_card("CSV1C", "118")
	var psychic_card := CardDatabase.get_card("CSVE1C", "PSY")
	if gardevoir_card == null or scream_tail_card == null or charm_card == null or psychic_card == null:
		return assert_true(false, "The production Gardevoir gust-insurance cards should load from CardDatabase")

	CardInstance.reset_id_counter()
	var state := _main_phase_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var gardevoir := _slot(gardevoir_card, 0)
	var scream_tail := _slot(scream_tail_card, 0)
	var defender := _slot(_defender_card(), 1)
	scream_tail.attached_tool = CardInstance.create(charm_card, 0)
	scream_tail.attached_energy.assign([
		CardInstance.create(psychic_card, 0),
		CardInstance.create(psychic_card, 0),
	])
	scream_tail.damage_counters = 20
	player.active_pokemon = scream_tail
	player.bench.assign([gardevoir])
	player.discard_pile.assign([
		CardInstance.create(psychic_card, 0),
		CardInstance.create(psychic_card, 0),
	])
	opponent.active_pokemon = defender

	var now: Dictionary = delegate.call("predict_attacker_damage", scream_tail, 0)
	var after: Dictionary = delegate.call("predict_attacker_damage", scream_tail, 1)
	var pick_before: Variant = delegate.call("pick_embrace_target", [gardevoir, scream_tail], state, 0)
	var insurance_before: float = float(delegate.call(
		"_score_gardevoir_gust_insurance",
		gardevoir,
		player,
		state,
		0
	))
	var checks: Array[String] = [
		assert_not_null(scream_tail.attached_tool, "The Active Scream Tail should carry Bravery Charm"),
		assert_true(bool(now.get("can_attack", false)), "The Active Scream Tail should already be attack-ready"),
		assert_eq(int(now.get("damage", -1)), 40, "Scream Tail should start below the visible 80 HP knockout threshold"),
		assert_true(bool(after.get("can_attack", false)), "The next safe Psychic Embrace should remain a legal attack route"),
		assert_eq(int(after.get("damage", -1)), 80, "The next Psychic Embrace should cross the visible knockout threshold"),
		assert_eq(insurance_before, 0.0, "Gardevoir gust insurance should yield while the next legal Embrace crosses a visible KO threshold"),
		assert_eq(pick_before, scream_tail, "Psychic Embrace should first charge the Active Charmed Scream Tail across the visible KO threshold"),
	]

	var threshold_energy: CardInstance = _first_psychic(player.discard_pile)
	checks.append(assert_not_null(threshold_energy, "A legal Psychic Embrace payment should remain in the discard pile"))
	if threshold_energy != null:
		player.discard_pile.erase(threshold_energy)
		scream_tail.attached_energy.append(threshold_energy)
		scream_tail.damage_counters += 20
	checks.append(assert_eq(scream_tail.damage_counters, 40, "Scream Tail should reach the 80-damage knockout threshold"))

	var insurance_after: float = float(delegate.call(
		"_score_gardevoir_gust_insurance",
		gardevoir,
		player,
		state,
		0
	))
	var pick_after: Variant = delegate.call("pick_embrace_target", [gardevoir, scream_tail], state, 0)
	checks.append(assert_eq(insurance_after, 760.0, "Gardevoir gust insurance should recover after Scream Tail reaches the visible KO threshold"))
	checks.append(assert_eq(pick_after, gardevoir, "The next Psychic Embrace should restore the benched Gardevoir insurance route"))

	return run_checks(checks)


func _route_dominance_checks(
	strategy: RefCounted,
	state: GameState,
	actions: Array[Dictionary],
	route_action: Dictionary,
	kirlia: PokemonSlot,
	label: String
) -> Array[String]:
	var checks: Array[String] = []
	if route_action.is_empty():
		return ["The next route action is missing before score comparison: %s" % label]
	var end_turn := _find_action(actions, "end_turn")
	var research := _find_action(actions, "play_trainer", func(action: Dictionary) -> bool:
		return _name_en(action.get("card", null)) == "Professor's Research"
	)
	var iono := _find_action(actions, "play_trainer", func(action: Dictionary) -> bool:
		return _name_en(action.get("card", null)) == "Iono"
	)
	var refinement := _find_action(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == kirlia
	)
	var distractors := {
		"end_turn": end_turn,
		"Professor's Research": research,
		"Iono": iono,
		"Refinement": refinement,
	}
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var route_score := float(strategy.call("score_action_absolute_with_plan", route_action, state, 0, contract))
	for distractor_name: String in distractors:
		var distractor: Dictionary = distractors[distractor_name]
		checks.append(assert_false(distractor.is_empty(), "%s should be legal while checking %s" % [distractor_name, label]))
		if distractor.is_empty():
			continue
		var distractor_score := float(strategy.call("score_action_absolute_with_plan", distractor, state, 0, contract))
		checks.append(assert_true(
			route_score > distractor_score,
			"%s must outrank %s (route=%f distractor=%f)" % [label, distractor_name, route_score, distractor_score]
		))
	return checks


func _actions(builder: RefCounted, gsm: GameStateMachine) -> Array[Dictionary]:
	var raw: Variant = builder.call("build_actions", gsm, 0, false)
	var result: Array[Dictionary] = []
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


func _pick_embrace_target(strategy: RefCounted, gsm: GameStateMachine, gardevoir: PokemonSlot) -> Variant:
	var effect: BaseEffect = gsm.effect_processor.get_ability_effect(gardevoir, 0, gsm.game_state)
	if effect == null:
		return null
	for step: Dictionary in effect.get_interaction_steps(gardevoir.get_top_card(), gsm.game_state):
		if str(step.get("id", "")) != "embrace_target":
			continue
		var items: Array = step.get("items", [])
		var picked: Array = strategy.call("pick_interaction_items", items, step, {
			"game_state": gsm.game_state,
			"player_index": 0,
			"all_items": items,
		})
		return picked[0] if not picked.is_empty() else null
	return null


func _use_embrace(
	gsm: GameStateMachine,
	gardevoir: PokemonSlot,
	energy: CardInstance,
	target: Variant
) -> bool:
	if energy == null or not target is PokemonSlot:
		return false
	return gsm.use_ability(0, gardevoir, 0, [{
		"embrace_energy": [energy],
		"embrace_target": [target],
	}])


func _registry_strategy(deck_path: String) -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(deck_path))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _main_phase_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	for index: int in 12:
		player.deck.append(_filler("Player deck %d" % index, 0))
		opponent.deck.append(_filler("Opponent deck %d" % index, 1))
	for index: int in 2:
		player.prizes.append(_filler("Player prize %d" % index, 0))
		opponent.prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(CardInstance.create(card, owner_index))
	return result


func _defender_card() -> CardData:
	var card := CardData.new()
	card.name = "Atomic Escape Target"
	card.name_en = "Atomic Escape Target"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = 80
	return card


func _filler(card_name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _first_psychic(cards: Array[CardInstance]) -> CardInstance:
	for card: CardInstance in cards:
		if card != null and card.card_data != null \
				and card.card_data.card_type == "Basic Energy" \
				and str(card.card_data.energy_provides) == "P":
			return card
	return null


func _psychic_count(cards: Array[CardInstance]) -> int:
	var count := 0
	for card: CardInstance in cards:
		if card != null and card.card_data != null \
				and card.card_data.card_type == "Basic Energy" \
				and str(card.card_data.energy_provides) == "P":
			count += 1
	return count


func _name_en(item: Variant) -> String:
	if item is CardInstance and (item as CardInstance).card_data != null:
		return str((item as CardInstance).card_data.name_en)
	return ""
