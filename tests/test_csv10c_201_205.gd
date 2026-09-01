class_name TestCSV10C201To205
extends TestBase

const TARGET_STEP_ID := "opponent_pokemon"
const ENERGY_STEP_ID := "special_energy"


func test_csv10c_201_205_bundle_metadata_and_assets() -> String:
	var expected := {
		"201": ["赫普的讲究头带", "87bf196475e64140c14197af70648893"],
		"202": ["莉莉艾的珍珠", "17c3b922d3e855f12bda63ec5ad6ec55"],
		"203": ["艾莉丝的斗志", "4eadb12f43cd50ddec37821f28ce0359"],
		"204": ["MC的热场", "2d4c85c2075cb99646ad0e5e34f0f825"],
		"205": ["可怕的哥哥", "dacd942c84db0948ced6544bacfa08d7"],
	}
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for index: String in expected:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(index)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		if card == null:
			continue
		checks.append(assert_eq(card.name, expected[index][0], "CSV10C_%s should preserve the API card name" % index))
		checks.append(assert_eq(card.effect_id, expected[index][1], "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid PNG" % index))
		checks.append(assert_true(card_path in manifest, "CSV10C_%s JSON should be listed in the manifest" % index))
		checks.append(assert_true(image_path in manifest, "CSV10C_%s image should be listed in the manifest" % index))
	return run_checks(checks)


func test_csv10c_201_hops_choice_band_reduces_colorless_and_adds_damage() -> String:
	var card := _load_card("201")
	if card == null:
		return "CSV10C_201 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	var hops := _slot("赫普的苍响ex", 0)
	hops.attached_tool = CardInstance.create(card, 0)
	state.players[0].active_pokemon = hops
	var ordinary := _slot("苍响ex", 0)
	ordinary.attached_tool = CardInstance.create(card, 0)
	var attack := {"name": "英勇之刃", "cost": "MMMC", "damage": "240"}
	return run_checks([
		assert_eq(processor.get_attack_colorless_cost_modifier(hops, attack, state), -1, "CSV10C_201 should reduce a Hop Pokemon attack's Colorless cost by 1"),
		assert_eq(processor.get_attacker_modifier(hops, state, state.players[1].active_pokemon), 30, "CSV10C_201 should add 30 attack damage for Hop Pokemon"),
		assert_eq(processor.get_attack_colorless_cost_modifier(ordinary, attack, state), 0, "CSV10C_201 should not reduce an unrelated Pokemon's attack cost"),
		assert_eq(processor.get_attacker_modifier(ordinary, state, state.players[1].active_pokemon), 0, "CSV10C_201 should not boost an unrelated Pokemon"),
	])


func test_csv10c_202_lillies_pearl_reduces_attack_damage_knockout_prizes() -> String:
	var card := _load_card("202")
	if card == null:
		return "CSV10C_202 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	var lillie := _slot("莉莉艾的皮皮ex", 0)
	lillie.attached_tool = CardInstance.create(card, 0)
	var ordinary := _slot("皮皮ex", 0)
	ordinary.attached_tool = CardInstance.create(card, 0)
	return run_checks([
		assert_eq(processor.get_knockout_prize_modifier(lillie, state), -1, "CSV10C_202 should reduce the Prizes taken from a Knocked Out Lillie's Pokemon by 1"),
		assert_eq(processor.get_knockout_prize_modifier(ordinary, state), 0, "CSV10C_202 should not modify Prizes for an unrelated Pokemon"),
	])


func test_csv10c_202_lillies_comfey_zero_prize_knockout_continues_to_replacement() -> String:
	var pearl := _load_card("202")
	var comfey_data: CardData = CardDatabase.get_card("CSV10C", "094")
	if pearl == null or comfey_data == null:
		return "CSV10C_202 Lillie's Pearl and CSV10C_094 Lillie's Comfey are required"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.first_player_index = 0
	state.current_player_index = 0

	var attacker := _slot("Attack Damage Finisher", 0)
	attacker.get_card_data().attacks = [{"name": "Knock Out", "cost": "", "damage": "100", "text": "", "is_vstar_power": false}]
	state.players[0].active_pokemon = attacker
	var lillies_comfey := PokemonSlot.new()
	lillies_comfey.pokemon_stack.append(CardInstance.create(comfey_data, 1))
	lillies_comfey.attached_tool = CardInstance.create(pearl, 1)
	state.players[1].active_pokemon = lillies_comfey
	var replacement := _slot("Replacement", 1)
	state.players[1].bench = [replacement]
	state.players[0].prizes.clear()
	state.players[1].prizes.clear()
	state.players[0].deck.clear()
	state.players[1].deck.clear()
	for i: int in 6:
		state.players[0].prizes.append(_card("Player 0 Prize %d" % i, "Item", 0))
		state.players[1].prizes.append(_card("Player 1 Prize %d" % i, "Item", 1))
	state.players[1].deck.append(_card("Next turn draw", "Item", 1))

	var choice_types: Array[String] = []
	gsm.player_choice_required.connect(func(choice_type: String, _data: Dictionary) -> void:
		choice_types.append(choice_type)
	)
	var attacked := gsm.use_attack(0, 0)
	var phase_after_knockout := state.phase
	var active_after_knockout := state.players[1].active_pokemon
	var prizes_after_knockout := state.players[0].prizes.size()
	var pending_prizes_after_knockout := int(gsm.get("_pending_prize_remaining"))
	var sent_out := gsm.send_out_pokemon(1, replacement)

	return run_checks([
		assert_true(attacked, "The attack-damage knockout fixture should resolve"),
		assert_null(active_after_knockout, "The Knocked Out Lillie's Comfey should leave the Active Spot before replacement"),
		assert_eq(prizes_after_knockout, 6, "Lillie's Pearl should reduce a one-Prize Lillie's Pokemon knockout to zero Prizes"),
		assert_eq(pending_prizes_after_knockout, 0, "A zero-Prize knockout must not leave Prize selection pending"),
		assert_false("take_prize" in choice_types, "A zero-Prize knockout must not emit a Prize selection prompt"),
		assert_true("send_out_pokemon" in choice_types, "The knockout flow should continue directly to replacement selection"),
		assert_eq(phase_after_knockout, GameState.GamePhase.KNOCKOUT_REPLACE, "The game should wait for a replacement instead of stalling in Pokemon Check"),
		assert_true(sent_out, "The defending player should be able to send out a replacement after the zero-Prize knockout"),
		assert_eq(state.players[1].active_pokemon, replacement, "The selected replacement should become Active"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "After replacement, the defending player's turn should continue normally"),
	])


func test_csv10c_203_iriss_fighting_spirit_discards_one_then_draws_to_six() -> String:
	var card := _load_card("203")
	if card == null:
		return "CSV10C_203 bundled card is required"
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_203 should register a Supporter effect"
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var supporter := CardInstance.create(card, 0)
	var discard_me := _card("Discard me", "Item", 0)
	var keep_me := _card("Keep me", "Item", 0)
	player.hand = [supporter, discard_me, keep_me]
	for i: int in 10:
		player.deck.append(_card("Deck %d" % i, "Item", 0))
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	player.hand.erase(supporter)
	effect.execute(supporter, [{"discard_cards": [discard_me]}], state)
	return run_checks([
		assert_eq(steps.size(), 1, "CSV10C_203 should expose exactly one discard-cost step"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "CSV10C_203 must discard exactly one other hand card"),
		assert_true(discard_me in player.discard_pile, "CSV10C_203 should discard the selected card"),
		assert_true(keep_me in player.hand, "CSV10C_203 should preserve unselected hand cards"),
		assert_eq(player.hand.size(), 6, "CSV10C_203 should draw until the hand contains 6 cards"),
	])


func test_csv10c_204_mc_excitement_draws_two_or_four_by_opponent_prizes() -> String:
	var card := _load_card("204")
	if card == null:
		return "CSV10C_204 bundled card is required"
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_204 should register a Supporter effect"
	var normal := _make_state()
	for i: int in 6:
		normal.players[0].deck.append(_card("Normal %d" % i, "Item", 0))
	for i: int in 4:
		normal.players[1].prizes.append(_card("Prize %d" % i, "Item", 1))
	effect.execute(CardInstance.create(card, 0), [], normal)
	var comeback := _make_state()
	for i: int in 6:
		comeback.players[0].deck.append(_card("Comeback %d" % i, "Item", 0))
	for i: int in 3:
		comeback.players[1].prizes.append(_card("Prize %d" % i, "Item", 1))
	effect.execute(CardInstance.create(card, 0), [], comeback)
	return run_checks([
		assert_eq(normal.players[0].hand.size(), 2, "CSV10C_204 should normally draw 2 cards"),
		assert_eq(comeback.players[0].hand.size(), 4, "CSV10C_204 should draw 4 cards when the opponent has at most 3 Prizes remaining"),
	])


func test_csv10c_205_scary_big_brother_discards_tool_and_chosen_special_energy() -> String:
	var card := _load_card("205")
	if card == null:
		return "CSV10C_205 bundled card is required"
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_205 should register a Supporter effect"
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	var target := opponent.bench[0]
	var tool := _card("Target Tool", "Tool", 1)
	var special_a := _card("Special A", "Special Energy", 1)
	var special_b := _card("Special B", "Special Energy", 1)
	var basic := _card("Basic", "Basic Energy", 1)
	target.attached_tool = tool
	target.attached_energy = [special_a, special_b, basic]
	var supporter := CardInstance.create(card, 0)
	var protected := PokemonSlot.new()
	protected.pokemon_stack.append(CardInstance.create(_load_card("234"), 1))
	var protected_tool := _card("Protected Tool", "Tool", 1)
	var protected_energy := _card("Protected Special", "Special Energy", 1)
	protected.attached_tool = protected_tool
	protected.attached_energy = [protected_energy]
	opponent.bench[1] = protected
	processor.register_pokemon_card(protected.get_card_data())
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(supporter, state, {TARGET_STEP_ID: [target]})
	effect.execute(supporter, [{TARGET_STEP_ID: [target], ENERGY_STEP_ID: [special_b]}], state)
	var sanitized := processor.sanitize_opponent_hand_trainer_targets(supporter, [{TARGET_STEP_ID: [protected]}], state)
	processor.execute_card_effect(supporter, sanitized, state)
	return run_checks([
		assert_eq(steps.size(), 1, "CSV10C_205 should first expose one opponent-Pokemon target step"),
		assert_true(target in (steps[0].get("items", []) as Array) if not steps.is_empty() else false, "CSV10C_205 should allow an opponent Bench Pokemon to be selected"),
		assert_eq(followup.size(), 1, "CSV10C_205 should expose a follow-up choice when multiple Special Energy are attached"),
		assert_true(special_b in (followup[0].get("items", []) as Array) if not followup.is_empty() else false, "CSV10C_205 should expose attached Special Energy choices"),
		assert_eq(target.attached_tool, null, "CSV10C_205 should discard the target's Pokemon Tool"),
		assert_true(tool in opponent.discard_pile, "CSV10C_205 should put the Tool in the opponent's discard pile"),
		assert_true(special_b in opponent.discard_pile, "CSV10C_205 should discard the selected Special Energy"),
		assert_true(special_a in target.attached_energy and basic in target.attached_energy, "CSV10C_205 should preserve unselected Energy"),
		assert_true(protected not in (steps[0].get("items", []) as Array) if not steps.is_empty() else false, "CSV10C_205 UI should omit a Cetitan ex protected from opponent Supporters"),
		assert_eq(protected.attached_tool, protected_tool, "CSV10C_205 should not fall back onto a protected Cetitan after target sanitization"),
		assert_eq(protected.attached_energy, [protected_energy], "CSV10C_205 should leave a protected Cetitan's Special Energy attached"),
	])


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot("Active %d" % pi, pi)
		player.bench = [_slot("Bench %d A" % pi, pi), _slot("Bench %d B" % pi, pi)]
		state.players.append(player)
	return state


func _slot(name: String, owner_index: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 200
	data.attacks = [{"name": "Strike", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner_index))
	return slot


func _card(name: String, card_type: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner_index)
