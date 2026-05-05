class_name TestFullLibrarySearchSupporterStadiumUI
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


func _make_state_with_deck(deck_cards: Array[CardInstance]) -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_make_pokemon_data("Active %d" % pi), pi))
		active.turn_played = 0
		player.active_pokemon = active
		state.players.append(player)
	state.players[0].deck.append_array(deck_cards)
	return state


func _make_pokemon_data(
	name: String,
	energy_type: String = "C",
	stage: String = "Basic",
	hp: int = 100,
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	return cd


func _make_trainer_data(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_energy_data(name: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = "C"
	cd.energy_type = "C"
	return cd


func _assert_full_deck_step(
	step: Dictionary,
	visible_deck: Array,
	legal_items: Array,
	expected_indices: Array,
	step_id: String,
	card_name: String
) -> String:
	var card_items: Array = step.get("card_items", [])
	var items: Array = step.get("items", [])
	var choice_labels: Array = step.get("choice_labels", [])
	return run_checks([
		assert_eq(str(step.get("id", "")), step_id, "%s should keep the original step id" % card_name),
		assert_eq(items, legal_items, "%s items must contain only legal selectable cards" % card_name),
		assert_eq(card_items, visible_deck, "%s card_items must expose the complete own deck" % card_name),
		assert_gt(card_items.size(), items.size(), "%s visible cards should exceed selectable cards" % card_name),
		assert_eq(step.get("card_indices", []), expected_indices, "%s card_indices should map visible cards to legal item indices" % card_name),
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "%s should declare own_full_deck visibility" % card_name),
		assert_eq(choice_labels.size(), visible_deck.size(), "%s should label every visible card" % card_name),
		assert_eq(int(step.get("visible_count", -1)), visible_deck.size(), "%s should report visible_count" % card_name),
		assert_eq(int(step.get("selectable_count", -1)), legal_items.size(), "%s should report selectable_count" % card_name),
	])


func _bench_names(player: PlayerState) -> Array[String]:
	var names: Array[String] = []
	for slot: PokemonSlot in player.bench:
		names.append(slot.get_pokemon_name())
	return names


func test_arven_multistep_full_deck_visible_and_ignores_visible_only_cards() -> String:
	var item := CardInstance.create(_make_trainer_data("Legal Item", "Item"), 0)
	var water := CardInstance.create(_make_pokemon_data("Visible Water", "W"), 0)
	var tool := CardInstance.create(_make_trainer_data("Legal Tool", "Tool"), 0)
	var energy := CardInstance.create(_make_energy_data("Visible Energy"), 0)
	var state := _make_state_with_deck([item, water, tool, energy])
	var player: PlayerState = state.players[0]
	var visible_deck := player.deck.duplicate()
	var effect := EffectArven.new()
	var card := CardInstance.create(_make_trainer_data("Arven", "Supporter"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var item_step: Dictionary = steps[0] if steps.size() > 0 else {}
	var tool_step: Dictionary = steps[1] if steps.size() > 1 else {}
	effect.execute(card, [{
		"search_item": [water, item],
		"search_tool": [energy, tool],
	}], state)

	var checks: Array[String] = [
		assert_eq(steps.size(), 2, "Arven should keep separate Item and Tool search steps"),
		_assert_full_deck_step(item_step, visible_deck, [item], [0, -1, -1, -1], "search_item", "Arven Item"),
		_assert_full_deck_step(tool_step, visible_deck, [tool], [-1, -1, 0, -1], "search_tool", "Arven Tool"),
		assert_true(item in player.hand, "Arven should move the legal Item to hand"),
		assert_true(tool in player.hand, "Arven should move the legal Tool to hand"),
		assert_true(water in player.deck, "Arven must ignore a visible-only Pokemon in the Item step"),
		assert_true(energy in player.deck, "Arven must ignore a visible-only Energy in the Tool step"),
	]
	return run_checks(checks)


func test_colress_tenacity_multistep_full_deck_visible_and_ignores_visible_only_cards() -> String:
	var stadium := CardInstance.create(_make_trainer_data("Legal Stadium", "Stadium"), 0)
	var item := CardInstance.create(_make_trainer_data("Visible Item", "Item"), 0)
	var energy := CardInstance.create(_make_energy_data("Legal Energy"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Visible Pokemon"), 0)
	var state := _make_state_with_deck([stadium, item, energy, pokemon])
	var player: PlayerState = state.players[0]
	var visible_deck := player.deck.duplicate()
	var effect := EffectColressTenacity.new()
	var card := CardInstance.create(_make_trainer_data("Colress's Tenacity", "Supporter"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var stadium_step: Dictionary = steps[0] if steps.size() > 0 else {}
	var energy_step: Dictionary = steps[1] if steps.size() > 1 else {}
	effect.execute(card, [{
		"search_stadium": [item, stadium],
		"search_energy": [pokemon, energy],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 2, "Colress's Tenacity should keep Stadium and Energy search steps"),
		_assert_full_deck_step(stadium_step, visible_deck, [stadium], [0, -1, -1, -1], "search_stadium", "Colress Stadium"),
		_assert_full_deck_step(energy_step, visible_deck, [energy], [-1, -1, 0, -1], "search_energy", "Colress Energy"),
		assert_true(stadium in player.hand, "Colress should move the legal Stadium to hand"),
		assert_true(energy in player.hand, "Colress should move the legal Energy to hand"),
		assert_true(item in player.deck, "Colress must ignore a visible-only Item in the Stadium step"),
		assert_true(pokemon in player.deck, "Colress must ignore a visible-only Pokemon in the Energy step"),
	])


func test_town_store_full_deck_visible_but_only_tools_selectable() -> String:
	var item := CardInstance.create(_make_trainer_data("Visible Item", "Item"), 0)
	var tool := CardInstance.create(_make_trainer_data("Legal Tool", "Tool"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Visible Pokemon"), 0)
	var state := _make_state_with_deck([item, tool, pokemon])
	var player: PlayerState = state.players[0]
	var visible_deck := player.deck.duplicate()
	var effect := EffectTownStore.new()
	var stadium := CardInstance.create(_make_trainer_data("Town Store", "Stadium"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.execute(stadium, [{
		"town_store_tool": [item, tool],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Town Store should expose one Tool search step"),
		_assert_full_deck_step(step, visible_deck, [tool], [-1, 0, -1], "town_store_tool", "Town Store"),
		assert_true(tool in player.hand, "Town Store should move the legal Tool to hand"),
		assert_true(item in player.deck, "Town Store must not treat Items as selectable"),
		assert_true(pokemon in player.deck, "Town Store must ignore visible-only Pokemon"),
	])


func test_artazon_full_deck_visible_preserves_rule_box_filter() -> String:
	var legal := CardInstance.create(_make_pokemon_data("Legal Basic", "G", "Basic", 70), 0)
	var rule_box := CardInstance.create(_make_pokemon_data("Rule Box ex", "G", "Basic", 180, "ex"), 0)
	var stage_one := CardInstance.create(_make_pokemon_data("Stage One", "G", "Stage 1", 90), 0)
	var item := CardInstance.create(_make_trainer_data("Visible Item", "Item"), 0)
	var state := _make_state_with_deck([legal, rule_box, stage_one, item])
	var player: PlayerState = state.players[0]
	player.bench.clear()
	var visible_deck := player.deck.duplicate()
	var effect := EffectArtazon.new()
	var stadium := CardInstance.create(_make_trainer_data("Artazon", "Stadium"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.execute(stadium, [{
		"artazon_pokemon": [rule_box, legal],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Artazon should expose one Basic Pokemon search step"),
		_assert_full_deck_step(step, visible_deck, [legal], [0, -1, -1, -1], "artazon_pokemon", "Artazon"),
		assert_true("Legal Basic" in _bench_names(player), "Artazon should bench the legal non-rule Basic Pokemon"),
		assert_true(rule_box in player.deck, "Artazon must keep rule-box Pokemon visible-only"),
		assert_true(stage_one in player.deck, "Artazon must keep Evolution Pokemon visible-only"),
		assert_true(item in player.deck, "Artazon must ignore visible-only Trainer cards"),
	])


func test_mesagoza_heads_full_deck_visible_preserves_coin_gate() -> String:
	var item := CardInstance.create(_make_trainer_data("Visible Item", "Item"), 0)
	var pokemon_a := CardInstance.create(_make_pokemon_data("Legal Pokemon A"), 0)
	var energy := CardInstance.create(_make_energy_data("Visible Energy"), 0)
	var pokemon_b := CardInstance.create(_make_pokemon_data("Legal Pokemon B", "W"), 0)
	var state := _make_state_with_deck([item, pokemon_a, energy, pokemon_b])
	var player: PlayerState = state.players[0]
	var visible_deck := player.deck.duplicate()
	var effect := EffectMesagoza.new(RiggedCoinFlipper.new([true]))
	var stadium := CardInstance.create(_make_trainer_data("Mesagoza", "Stadium"), 0)

	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.execute(stadium, [{
		"mesagoza_pokemon": [item, pokemon_b],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Mesagoza heads should expose one Pokemon search step"),
		assert_true(bool(step.get("wait_for_coin_animation", false)), "Mesagoza should keep the coin animation gate on its search step"),
		_assert_full_deck_step(step, visible_deck, [pokemon_a, pokemon_b], [-1, 0, -1, 1], "mesagoza_pokemon", "Mesagoza"),
		assert_true(pokemon_b in player.hand, "Mesagoza should move the legal selected Pokemon to hand"),
		assert_true(item in player.deck, "Mesagoza must ignore visible-only non-Pokemon cards"),
		assert_true(energy in player.deck, "Mesagoza must ignore visible-only Energy cards"),
	])
