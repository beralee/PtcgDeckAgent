class_name TestCS4DaC313ZamazentaV
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript = preload("res://scenes/deck_editor/DeckEditor.gd")


func test_cs4dac_313_zamazenta_v_is_bundled_with_image_and_effect() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var card_path := "res://data/bundled_user/cards/CS4DaC_313.json"
	var image_path := "res://data/bundled_user/cards/images/CS4DaC/313.png.bin"
	var card: CardData = db.get_card("CS4DaC", "313")
	var found: CardData = null
	for candidate: CardData in db.get_all_cards():
		if candidate.get_uid() == "CS4DaC_313":
			found = candidate
			break
	return run_checks([
		assert_true(card_path in manifest, "CS4DaC_313 card JSON should be listed in bundled seed manifest"),
		assert_true(image_path in manifest, "CS4DaC_313 image should be listed in bundled seed manifest"),
		assert_true(FileAccess.file_exists(card_path), "CS4DaC_313 bundled card JSON should exist"),
		assert_true(FileAccess.file_exists(image_path), "CS4DaC_313 bundled card image should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CS4DaC_313 bundled card image should be valid"),
		assert_not_null(card, "CS4DaC_313 should load through CardDatabase bundled fallback"),
		assert_not_null(found, "CardDatabase.get_all_cards should include bundle-only CS4DaC_313"),
		assert_eq(str(card.name_en) if card != null else "", "Zamazenta V", "CS4DaC_313 should keep source English name"),
		assert_eq(str(card.card_type) if card != null else "", "Pokemon", "CS4DaC_313 should keep source card type"),
		assert_eq(str(card.effect_id) if card != null else "", "f3543bd547e44612b034263374aa0ef1", "CS4DaC_313 should keep source effect id"),
	])


func test_deck_editor_pokemon_pool_includes_cs4dac_313_zamazenta_v() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var pokemon_cards: Array = pool_by_category[0] if pool_by_category.size() > 0 else []
	var found: CardData = null
	for card: CardData in pokemon_cards:
		if card.get_uid() == "CS4DaC_313":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "DeckEditor Pokemon tab should include bundle-only CS4DaC_313"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Zamazenta V", "DeckEditor should keep Zamazenta V metadata in the Pokemon pool"))
		checks.append(assert_eq(str(found.energy_type), "M", "DeckEditor should keep Zamazenta V Metal typing"))
		checks.append(assert_eq(str(found.mechanic), "V", "DeckEditor should keep Zamazenta V mechanic"))
	editor.free()
	return run_checks(checks)


func test_cs4dac_313_zamazenta_v_regal_stance_discards_hand_draws_five_and_ends_turn() -> String:
	var card := _load_card()
	if card == null:
		return "CS4DaC_313 should load before Regal Stance can be tested"
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var zamazenta := _slot(card, 0)
	player.active_pokemon = zamazenta
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	opponent.deck.clear()
	for i: int in 3:
		player.hand.append(CardInstance.create(_trainer("Hand %d" % i), 0))
	for i: int in 5:
		player.deck.append(CardInstance.create(_trainer("Draw %d" % i), 0))
	for i: int in 2:
		opponent.deck.append(CardInstance.create(_trainer("Opponent Draw %d" % i), 1))

	gsm.effect_processor.register_pokemon_card(card)
	var used := gsm.use_ability(0, zamazenta, 0)

	return run_checks([
		assert_true(used, "Regal Stance should be usable during its owner's turn"),
		assert_eq(player.hand.size(), 5, "Regal Stance should draw five cards after discarding the original hand"),
		assert_eq(player.discard_pile.size(), 3, "Regal Stance should discard the original hand"),
		assert_true(zamazenta.has_ability_used(2), "Regal Stance should mark the Ability used for the turn"),
		assert_eq(gsm.game_state.current_player_index, 1, "Regal Stance should end the current player's turn"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "Regal Stance should advance to the next player's Main phase"),
		assert_eq(gsm.game_state.turn_number, 3, "Regal Stance should advance the turn counter"),
		assert_eq(opponent.hand.size(), 1, "The next player should draw for turn after Regal Stance ends the turn"),
	])


func test_cs4dac_313_zamazenta_v_revenge_blast_adds_opponent_prizes_taken_damage() -> String:
	var card := _load_card()
	if card == null:
		return "CS4DaC_313 should load before Revenge Blast can be tested"
	var gsm := _make_gsm()
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("High HP Defender", "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.game_state.players[1].prizes.clear()
	for i: int in 4:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_trainer("Opponent Prize %d" % i), 1))
	_attach_energy(attacker, 0, "M", 3)

	gsm.effect_processor.register_pokemon_card(card)
	var attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(gsm.effect_processor.has_effect(card.effect_id), "Zamazenta V should register Regal Stance by effect id"),
		assert_true(gsm.effect_processor.has_attack_effect(card.effect_id), "Zamazenta V should register Revenge Blast by effect id"),
		assert_eq(attack_effects.size(), 1, "Revenge Blast should resolve exactly one damage-bonus attack effect"),
		assert_true(used, "Zamazenta V should use Revenge Blast through GameStateMachine"),
		assert_eq(defender.damage_counters, 180, "Revenge Blast should deal 120 plus 30 for each of the opponent's two taken prizes"),
	])


func _load_card() -> CardData:
	return CardDatabaseScript.new().get_card("CS4DaC", "313")


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("Active %d" % pi, "C", 120), pi)
		for prize_index: int in 6:
			player.prizes.append(CardInstance.create(_trainer("Prize %d_%d" % [pi, prize_index]), pi))
		gsm.game_state.players.append(player)
	return gsm


func _pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.energy_type = energy_type
	card.stage = "Basic"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "30", "text": "", "is_vstar_power": false}]
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	card.effect_id = "test_%s" % name
	return card


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))
