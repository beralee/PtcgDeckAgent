class_name TestNsZoroarkCilanRound2
extends TestBase

const DeckStrategyNsZoroarkScript = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_cilan_bridge_requires_zorua_and_a_deck_zoroark_ex_target() -> String:
	var live_rig := _make_rig()
	if live_rig.has("error"):
		return str(live_rig["error"])
	var no_zorua_rig := _make_rig(false)
	var target_in_hand_rig := _make_rig(true, true)
	var online_rig := _make_rig(true, false, true)
	var no_deck_target_rig := _make_rig(true, false, false, false)
	for rig: Dictionary in [no_zorua_rig, target_in_hand_rig, online_rig, no_deck_target_rig]:
		if rig.has("error"):
			return str(rig["error"])

	var live_score := _score_cilan(live_rig)
	var no_zorua_score := _score_cilan(no_zorua_rig)
	var target_in_hand_score := _score_cilan(target_in_hand_rig)
	var online_score := _score_cilan(online_rig)
	var no_deck_target_score := _score_cilan(no_deck_target_rig)

	return run_checks([
		assert_eq(str((live_rig["cilan"] as CardInstance).card_data.get_uid()), "CSV9C_198", "Round 2 must score the exact CSV9C_198 Cilan print"),
		assert_eq(live_score, 400.0, "Cilan should become a high-priority evolution bridge when Zorua is waiting for a deck Zoroark ex"),
		assert_eq(no_zorua_score, 20.0, "Cilan should keep the ordinary trainer score without Zorua on the field"),
		assert_eq(target_in_hand_score, 20.0, "Cilan should not receive the bridge score when Zoroark ex is already in hand"),
		assert_eq(online_score, 20.0, "Cilan should not receive the bridge score after Zoroark ex is online"),
		assert_eq(no_deck_target_score, 20.0, "Cilan should not receive the bridge score when no Zoroark ex remains in the deck"),
	])


func test_immediate_knockout_attack_outranks_live_cilan_bridge() -> String:
	var rig := _make_rig(true, false, false, true, true)
	if rig.has("error"):
		return str(rig["error"])
	var strategy: RefCounted = rig["strategy"]
	var state: GameState = rig["state"]
	var cilan_score := _score_cilan(rig)
	var knockout_score := float(strategy.call(
		"score_action_absolute",
		{
			"kind": "attack",
			"attack_name": "Powerful Rage",
			"projected_damage": 20,
			"projected_knockout": true,
		},
		state,
		0
	))

	return run_checks([
		assert_eq(cilan_score, 400.0, "The live bridge fixture should activate Cilan's Round 2 score"),
		assert_gt(knockout_score, cilan_score, "An immediate knockout must stay ahead of the Cilan evolution bridge"),
	])


func _score_cilan(rig: Dictionary) -> float:
	return float((rig["strategy"] as RefCounted).call(
		"score_action_absolute",
		{"kind": "play_trainer", "card": rig["cilan"]},
		rig["state"],
		0
	))


func _make_rig(
	has_zorua: bool = true,
	zoroark_in_hand: bool = false,
	zoroark_on_field: bool = false,
	zoroark_in_deck: bool = true,
	reshiram_active: bool = false
) -> Dictionary:
	var zorua_data: CardData = CardDatabase.get_card("CSV10C", "144")
	var zoroark_data: CardData = CardDatabase.get_card("CSV10C", "145")
	var reshiram_data: CardData = CardDatabase.get_card("CSV10C", "166")
	var cilan_data: CardData = CardDatabase.get_card("CSV9C", "198")
	if zorua_data == null or zoroark_data == null or reshiram_data == null or cilan_data == null:
		return {"error": "CSV10C_144, CSV10C_145, CSV10C_166, or CSV9C_198 fixture missing"}

	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var player: PlayerState = state.players[0]
	if reshiram_active:
		player.active_pokemon = _make_slot(reshiram_data, 0)
		player.active_pokemon.attached_energy.assign([
			CardInstance.create(_make_darkness_energy(), 0),
			CardInstance.create(_make_darkness_energy(), 0),
		])
	elif has_zorua:
		player.active_pokemon = _make_slot(zorua_data, 0)
	else:
		player.active_pokemon = _make_slot(_make_filler("Active Pivot"), 0)
	if has_zorua and reshiram_active:
		player.bench.append(_make_slot(zorua_data, 0))
	if zoroark_on_field:
		player.bench.append(_make_slot(zoroark_data, 0))

	var cilan := CardInstance.create(cilan_data, 0)
	player.hand.append(cilan)
	if zoroark_in_hand:
		player.hand.append(CardInstance.create(zoroark_data, 0))
	if zoroark_in_deck:
		player.deck.append(CardInstance.create(zoroark_data, 0))
	player.deck.append(CardInstance.create(_make_filler("Deck Filler"), 0))
	state.players[1].active_pokemon = _make_slot(_make_filler("Defender"), 1)
	if reshiram_active:
		state.players[1].active_pokemon.damage_counters = 80

	return {
		"strategy": DeckStrategyNsZoroarkScript.new(),
		"state": state,
		"cilan": cilan,
	}


func _make_darkness_energy() -> CardData:
	var card := CardData.new()
	card.name = "Darkness Energy"
	card.name_en = "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "D"
	return card


func _make_filler(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = 100
	return card


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
