class_name TestT3178WorkerBTrainerToolStadiumEffects
extends TestBase

const EffectFeatherBallScript = preload("res://scripts/effects/trainer_effects/EffectFeatherBall.gd")
const EffectArezuScript = preload("res://scripts/effects/trainer_effects/EffectArezu.gd")
const EffectAcademyAtNightScript = preload("res://scripts/effects/stadium_effects/EffectAcademyAtNight.gd")

const ANCIENT_CAPSULE_ID := "8da8631aa1827b122ec65b712939ad48"
const GLASSES_ID := "0ad0108e5ab1346d88f6ce11b75028d7"
const FEATHER_BALL_ID := "b029fdcf35f970d5d2254778009fa2fe"
const AREZU_ID := "c29db727ed3ad15978addfc5d8ed6451"
const ACADEMY_ID := "e75fad9484071647f96e9f41beeb4a99"


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _pokemon(name: String, stage: String = "Basic", retreat_cost: int = 1, mechanic: String = "", tags: Array[String] = []) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = 100
	cd.energy_type = "C"
	cd.retreat_cost = retreat_cost
	cd.mechanic = mechanic
	var packed := PackedStringArray()
	for tag: String in tags:
		packed.append(tag)
	cd.is_tags = packed
	return cd


func _attacker(name: String, attack_type: String, damage: String = "100") -> CardData:
	var cd := _pokemon(name, "Basic", 1)
	cd.energy_type = attack_type
	cd.attacks = [{"name": "Hit", "cost": "", "damage": damage, "text": "", "is_vstar_power": false}]
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _slot(card_data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _full_deck_step_checks(step: Dictionary, visible_cards: Array, legal_cards: Array, indices: Array, step_id: String) -> Array[String]:
	return [
		assert_eq(str(step.get("id", "")), step_id, "step id should remain stable"),
		assert_eq(step.get("card_items", []), visible_cards, "full deck search must expose every own deck card to UI"),
		assert_eq(step.get("items", []), legal_cards, "items must contain only selectable legal cards"),
		assert_eq(step.get("card_indices", []), indices, "card_indices must map visible cards to selectable indices"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "own deck searches must declare full-deck scope"),
		assert_eq(int(step.get("visible_count", 0)), visible_cards.size(), "visible_count should include non-candidates"),
		assert_eq(int(step.get("selectable_count", 0)), legal_cards.size(), "selectable_count should only include candidates"),
	]


func _find_action(actions: Array[Dictionary], kind: String, card: CardInstance = null) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if card != null and action.get("card", null) != card:
			continue
		return action
	return {}


func test_csv6c_118_ancient_booster_capsule_hp_and_status_boundaries() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var ancient := _slot(_pokemon("Ancient Holder", "Basic", 2, "", [CardData.ANCIENT_TAG]), 0)
	var normal := _slot(_pokemon("Normal Holder", "Basic", 2), 0)
	state.players[0].active_pokemon = ancient
	state.players[0].bench.append(normal)
	ancient.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_CAPSULE_ID), 0)
	normal.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_CAPSULE_ID), 0)
	ancient.set_status("burned", true)
	normal.set_status("burned", true)

	processor.execute_card_effect(ancient.attached_tool, [ancient], state)
	EffectApplyStatus.new("poisoned").execute_attack(null, ancient, 0, state)
	EffectApplyStatus.new("poisoned").execute_attack(null, normal, 0, state)
	var unsuppressed_hp_bonus := processor.get_hp_modifier(ancient, state)

	state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	EffectApplyStatus.new("asleep").execute_attack(null, ancient, 0, state)

	return run_checks([
		assert_not_null(processor.get_effect(ANCIENT_CAPSULE_ID), "Ancient Booster Energy Capsule should be registered"),
		assert_eq(unsuppressed_hp_bonus, 60, "Ancient holder should get +60 HP without tool suppression"),
		assert_eq(processor.get_hp_modifier(normal, state), 0, "Non-Ancient holder should not get HP"),
		assert_false(ancient.status_conditions.get("burned", false), "Ancient holder should clear existing Special Conditions"),
		assert_false(ancient.status_conditions.get("poisoned", false), "Ancient holder should prevent new Special Conditions"),
		assert_true(normal.status_conditions.get("burned", false), "Non-Ancient holder should keep existing status"),
		assert_true(normal.status_conditions.get("poisoned", false), "Non-Ancient holder should not be protected"),
		assert_eq(processor.get_hp_modifier(ancient, state), 0, "Jamming Tower should suppress Ancient Booster HP bonus"),
		assert_true(ancient.status_conditions.get("asleep", false), "Jamming Tower should suppress Ancient Booster status prevention"),
	])


func test_cs5ac_118_supereffective_glasses_weakness_x3_and_suppression() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(_attacker("Fighting Attacker", "F", "100"), 0)
	var defender_data := _pokemon("Weak Defender", "Basic", 1)
	defender_data.weakness_energy = "F"
	defender_data.weakness_value = "x2"
	player.active_pokemon = attacker
	opponent.active_pokemon = _slot(defender_data, 1)
	attacker.attached_tool = CardInstance.create(_trainer("Supereffective Glasses", "Tool", GLASSES_ID), 0)
	var boosted_damage := gsm.get_attack_preview_damage(0, 0)

	gsm.game_state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var suppressed_damage := gsm.get_attack_preview_damage(0, 0)

	return run_checks([
		assert_not_null(gsm.effect_processor.get_effect(GLASSES_ID), "Supereffective Glasses should be registered"),
		assert_eq(boosted_damage, 300, "Weakness should be calculated as x3"),
		assert_eq(suppressed_damage, 200, "Tool suppression should restore normal x2 Weakness"),
	])


func test_cs5ac_116_feather_ball_full_library_search_and_execution() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(FEATHER_BALL_ID, EffectFeatherBallScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var free_a := CardInstance.create(_pokemon("Free Retreat A", "Basic", 0), 0)
	var paid := CardInstance.create(_pokemon("Paid Retreat", "Basic", 1), 0)
	var item := CardInstance.create(_trainer("Deck Item", "Item"), 0)
	var free_b := CardInstance.create(_pokemon("Free Retreat B", "Stage 1", 0), 0)
	player.deck.append_array([free_a, paid, item, free_b])
	var card := CardInstance.create(_trainer("Feather Ball", "Item", FEATHER_BALL_ID), 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(FEATHER_BALL_ID)
	var steps := effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", card)
	var played := gsm.play_trainer(0, card, [{"search_pokemon": [paid, free_b]}])

	var checks := _full_deck_step_checks(step, visible_deck, [free_a, free_b], [0, -1, -1, 1], "search_pokemon")
	checks.append(assert_eq(int(step.get("min_select", -1)), 0, "Feather Ball searches a hidden deck and must allow whiffing"))
	checks.append(assert_true(bool(step.get("force_confirm", false)), "Feather Ball should expose a confirm path for selecting no card"))
	checks.append(assert_false(action.is_empty(), "AI/headless should enumerate Feather Ball"))
	checks.append(assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Feather Ball from legal candidates"))
	checks.append(assert_true(played, "Feather Ball should play through GameStateMachine"))
	checks.append(assert_true(free_b in player.hand, "Selected legal no-retreat Pokemon should move to hand"))
	checks.append(assert_false(paid in player.hand, "Pokemon with Retreat Cost must not move to hand"))
	checks.append(assert_true(paid in player.deck, "Invalid selected Pokemon must remain in deck"))
	return run_checks(checks)


func test_cs5ac_116_feather_ball_can_whiff_hidden_deck_search() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(FEATHER_BALL_ID, EffectFeatherBallScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var free_target := CardInstance.create(_pokemon("Free Retreat", "Basic", 0), 0)
	var paid := CardInstance.create(_pokemon("Paid Retreat", "Basic", 1), 0)
	player.deck.append_array([free_target, paid])
	var card := CardInstance.create(_trainer("Feather Ball", "Item", FEATHER_BALL_ID), 0)
	player.hand.append(card)

	var played := gsm.play_trainer(0, card, [{"search_pokemon": []}])

	return run_checks([
		assert_true(played, "Feather Ball should be playable with an explicit whiff"),
		assert_false(free_target in player.hand, "Whiffing should not move a legal target to hand"),
		assert_true(free_target in player.deck, "Legal target should remain in deck after whiff"),
		assert_true(card in player.discard_pile, "Feather Ball should still be consumed after whiff"),
	])


func test_cs5dc_147_arezu_searches_non_rule_box_evolutions_only() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(AREZU_ID, EffectArezuScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var stage_one := CardInstance.create(_pokemon("Stage One", "Stage 1", 1), 0)
	var basic := CardInstance.create(_pokemon("Basic Pokemon", "Basic", 1), 0)
	var stage_two_ex := CardInstance.create(_pokemon("Stage Two ex", "Stage 2", 2, "ex"), 0)
	var vmax := CardInstance.create(_pokemon("VMAX Pokemon", "VMAX", 3, "VMAX"), 0)
	var stage_two := CardInstance.create(_pokemon("Stage Two", "Stage 2", 2), 0)
	var stage_one_b := CardInstance.create(_pokemon("Stage One B", "Stage 1", 1), 0)
	var stage_two_b := CardInstance.create(_pokemon("Stage Two B", "Stage 2", 2), 0)
	player.deck.append_array([stage_one, basic, stage_two_ex, vmax, stage_two, stage_one_b, stage_two_b])
	var card := CardInstance.create(_trainer("Arezu", "Supporter", AREZU_ID), 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(AREZU_ID)
	var steps := effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", card)
	var played := gsm.play_trainer(0, card, [{"search_pokemon": [stage_two_ex, stage_one, vmax, stage_two, stage_one_b, stage_two_b]}])

	var checks := _full_deck_step_checks(step, visible_deck, [stage_one, stage_two, stage_one_b, stage_two_b], [0, -1, -1, -1, 1, 2, 3], "search_pokemon")
	checks.append(assert_eq(int(step.get("min_select", -1)), 0, "Arezu is an up-to-3 search and should allow selecting none"))
	checks.append(assert_eq(int(step.get("max_select", -1)), 3, "Arezu should cap selection at 3 even when more legal evolutions exist"))
	checks.append(assert_true(bool(step.get("force_confirm", false)), "Arezu should expose a confirm path for selecting no card"))
	checks.append(assert_false(action.is_empty(), "AI/headless should enumerate Arezu"))
	checks.append(assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Arezu from legal candidates"))
	checks.append(assert_true(played, "Arezu should play through GameStateMachine"))
	checks.append(assert_true(stage_one in player.hand and stage_two in player.hand and stage_one_b in player.hand, "Selected legal evolutions should move to hand up to the cap"))
	checks.append(assert_false(stage_two_ex in player.hand, "Rule Box evolution Pokemon must not move to hand"))
	checks.append(assert_false(vmax in player.hand, "VMAX Rule Box Pokemon must not move to hand"))
	checks.append(assert_true(stage_two_ex in player.deck and vmax in player.deck, "Rule Box selections should remain in deck"))
	checks.append(assert_true(stage_two_b in player.deck, "Fourth legal evolution should remain in deck because Arezu selects at most 3"))
	return run_checks(checks)


func test_csv8c_205_academy_at_night_stadium_action_once_per_turn() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(ACADEMY_ID, EffectAcademyAtNightScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var stadium := CardInstance.create(_trainer("Academy at Night", "Stadium", ACADEMY_ID), 0)
	var keep := CardInstance.create(_trainer("Keep", "Item"), 0)
	var top_choice := CardInstance.create(_trainer("Top Choice", "Item"), 0)
	var invalid_opponent_card := CardInstance.create(_trainer("Opponent Card", "Item"), 1)
	var old_top := CardInstance.create(_trainer("Old Top", "Item"), 0)
	player.hand.append_array([keep, top_choice])
	player.deck.append(old_top)
	opponent.hand.append(invalid_opponent_card)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 1
	var effect: BaseEffect = gsm.effect_processor.get_effect(ACADEMY_ID)
	var steps := effect.get_interaction_steps(stadium, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "use_stadium_effect", stadium)
	var first_use := gsm.use_stadium_effect(0, [{"academy_at_night_card": [invalid_opponent_card, top_choice]}])
	var second_use := gsm.use_stadium_effect(0, [{"academy_at_night_card": [keep]}])
	var opponent_kept_after_player_use := invalid_opponent_card in opponent.hand
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 3
	var opponent_use := gsm.use_stadium_effect(1, [{"academy_at_night_card": [invalid_opponent_card]}])

	return run_checks([
		assert_eq(str(step.get("id", "")), "academy_at_night_card", "Academy at Night should expose a hand-card choice"),
		assert_eq(step.get("items", []), [keep, top_choice], "Only current player's hand should be selectable"),
		assert_false(action.is_empty(), "AI/headless should enumerate Academy at Night stadium action"),
		assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Academy at Night"),
		assert_true(first_use, "First stadium use this turn should succeed"),
		assert_false(second_use, "Same player should not reuse the same Stadium effect this turn"),
		assert_eq(player.deck[0], top_choice, "Selected hand card should be placed on top of deck"),
		assert_false(top_choice in player.hand, "Selected hand card should leave hand"),
		assert_true(opponent_kept_after_player_use, "Opponent hand card must not be selectable or moved by player 0"),
		assert_true(opponent_use, "Opponent should be able to use Academy at Night on their own turn"),
		assert_eq(opponent.deck[0], invalid_opponent_card, "Opponent's own hand card should go to the top of their deck"),
	])
