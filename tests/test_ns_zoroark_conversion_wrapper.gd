class_name TestNsZoroarkConversionWrapper
extends TestBase

const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const NS_ZOROARK_DECK_ID := 800018502


func test_registry_wrapper_scores_unselected_night_joker_copy_as_a_170_ko() -> String:
	var deck := DeckData.new()
	deck.id = NS_ZOROARK_DECK_ID
	var strategy := DeckStrategyRegistryScript.new().resolve_strategy_for_deck(deck)
	if strategy == null:
		return "DeckStrategyRegistry should resolve deck 800018502"

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var zoroark := _make_slot(_make_zoroark(), 0)
	zoroark.attached_energy.assign([
		CardInstance.create(_make_darkness_energy(), 0),
		CardInstance.create(_make_darkness_energy(), 0),
	])
	player.active_pokemon = zoroark
	player.bench.append(_make_slot(_make_reshiram(), 0))
	var zorua := CardInstance.create(_make_zorua(), 0)
	player.hand.append(zorua)
	for index: int in 10:
		player.deck.append(CardInstance.create(_make_filler("Deck %d" % index), 0))

	var defender := _make_slot(_make_defender(), 1)
	defender.damage_counters = 60
	opponent.active_pokemon = defender

	var attack_action := {
		"kind": "attack",
		"source_slot": zoroark,
		"attack_index": 0,
		"attack_name": "Night Joker",
		"projected_damage": 0,
		"projected_knockout": false,
	}
	var trade_action := {
		"kind": "use_ability",
		"source_slot": zoroark,
		"ability_name": "Trade",
	}
	var bench_action := {
		"kind": "play_basic_to_bench",
		"card": zorua,
	}
	var lethal_plan: Dictionary = strategy.build_turn_plan(state, 0, {})
	var prediction: Dictionary = strategy.predict_attacker_damage(zoroark)
	var lethal_remaining_hp := defender.get_remaining_hp()
	var lethal_score: float = strategy.score_action_absolute_with_plan(attack_action, state, 0, lethal_plan)
	var trade_score: float = strategy.score_action_absolute_with_plan(trade_action, state, 0, lethal_plan)
	var bench_score: float = strategy.score_action_absolute_with_plan(bench_action, state, 0, lethal_plan)

	defender.damage_counters = 40
	var nonlethal_plan: Dictionary = strategy.build_turn_plan(state, 0, {})
	var nonlethal_score: float = strategy.score_action_absolute_with_plan(attack_action, state, 0, nonlethal_plan)

	return run_checks([
		assert_eq(str(strategy.get_strategy_id()), "v18_800018502_ns_zoroark", "Deck 800018502 should use its production V18 wrapper"),
		assert_eq(lethal_remaining_hp, 160, "The conversion fixture should leave the opposing Active with exactly 160 HP"),
		assert_eq(int(prediction.get("damage", 0)), 170, "Unselected Night Joker should inherit N's Reshiram's 170 damage during action scoring"),
		assert_true(int(prediction.get("damage", 0)) >= lethal_remaining_hp, "The copied 170 damage should be recognized as a KO into 160 remaining HP"),
		assert_gt(lethal_score, nonlethal_score + 700.0, "Night Joker should gain a KO conversion premium at 160 HP even when the action preview still reports zero"),
		assert_gt(lethal_score, trade_score, "The available Night Joker KO should outrank Trade"),
		assert_gt(lethal_score, bench_score, "The available Night Joker KO should outrank additional setup"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _make_zoroark() -> CardData:
	return _make_pokemon(
		"N的索罗亚克ex",
		"N's Zoroark ex",
		280,
		"Stage 1",
		"ex",
		[{"name": "Trade", "text": "Discard 1 card from your hand. Draw 2 cards."}],
		[{"name": "Night Joker", "name_zh": "暗夜小丑", "cost": "DD", "damage": "0", "text": "Choose 1 of your Benched N's Pokemon's attacks and use it as this attack."}]
	)


func _make_reshiram() -> CardData:
	return _make_pokemon(
		"N的莱希拉姆",
		"N's Reshiram",
		130,
		"Basic",
		"",
		[],
		[
			{"name": "Powerful Rage", "cost": "RL", "damage": "20x", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
			{"name": "Virtuous Flame", "cost": "RRLC", "damage": "170", "text": ""},
		]
	)


func _make_zorua() -> CardData:
	return _make_pokemon(
		"N的索罗亚",
		"N's Zorua",
		70,
		"Basic",
		"",
		[],
		[{"name": "Scratch", "cost": "D", "damage": "20", "text": ""}]
	)


func _make_defender() -> CardData:
	return _make_pokemon("Conversion Target", "Conversion Target", 220, "Basic", "", [], [])


func _make_filler(name: String) -> CardData:
	return _make_pokemon(name, name, 60, "Basic", "", [], [])


func _make_pokemon(
	name: String,
	name_en: String,
	hp: int,
	stage: String,
	mechanic: String,
	abilities: Array,
	attacks: Array
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = "Pokemon"
	card.energy_type = "D"
	card.hp = hp
	card.stage = stage
	card.mechanic = mechanic
	for ability: Variant in abilities:
		card.abilities.append((ability as Dictionary).duplicate(true))
	for attack: Variant in attacks:
		card.attacks.append((attack as Dictionary).duplicate(true))
	return card


func _make_darkness_energy() -> CardData:
	var card := CardData.new()
	card.name = "Darkness Energy"
	card.name_en = "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "D"
	return card


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
