class_name TestGardevoirStrategyChurn
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")

const GARDEVOIR_SET := "CSV2C"
const GARDEVOIR_INDEX := "055"
const KIRLIA_SET := "CS6.5C"
const KIRLIA_INDEX := "030"
const RALTS_SET := "CSV2C"
const RALTS_INDEX := "053"
const DRIFLOON_SET := "CSV2C"
const DRIFLOON_INDEX := "060"
const MUNKIDORI_SET := "CSV8C"
const MUNKIDORI_INDEX := "094"
const FLUTTER_MANE_SET := "CSV7C"
const FLUTTER_MANE_INDEX := "109"
const POFFIN_SET := "CSV7C"
const POFFIN_INDEX := "177"
const TM_EVOLUTION_SET := "CSV5C"
const TM_EVOLUTION_INDEX := "119"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


func _make_energy_cd(name: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_scream_tail_cd() -> CardData:
	var cd := CardData.new()
	cd.name = DeckStrategyGardevoirScript.SCREAM_TAIL
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "P"
	cd.hp = 90
	cd.attacks = [
		{"name": "Scream Tail Attack", "cost": "PC", "damage": "", "text": "", "is_vstar_power": false},
	]
	return cd


func _make_player(pi: int = 0) -> PlayerState:
	var p := PlayerState.new()
	p.player_index = pi
	return p


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := _make_player(pi)
		p.active_pokemon = _make_slot(_make_placeholder_pokemon("Active%d" % pi), pi)
		gs.players.append(p)
	return gs


func _make_placeholder_pokemon(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "C"
	cd.hp = 100
	return cd


func _make_named_pokemon(name: String, name_en: String, hp: int = 100) -> CardData:
	var cd := _make_placeholder_pokemon(name)
	cd.name_en = name_en
	cd.hp = hp
	return cd


func _fill_prizes(player: PlayerState, count: int) -> void:
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), player.player_index))


func _require_card(set_code: String, card_index: String) -> CardData:
	var card_data: CardData = CardDatabase.get_card(set_code, card_index)
	assert_not_null(card_data, "Expected CardDatabase to provide %s/%s" % [set_code, card_index])
	return card_data


func _build_online_shell_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	return gs


func _build_online_shell_with_late_tm_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.bench.append(drifloon)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_mid_tm_state() -> GameState:
	var gs := _build_online_shell_with_late_tm_state()
	gs.turn_number = 6
	return gs


func _build_transition_shell_without_munkidori_state() -> GameState:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_recovery_bait_state() -> GameState:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic E", "P"), 0))
	return gs


func _build_scream_tail_attack_ready_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_scream_tail_manual_psychic_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless A", "C"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_drifloon_manual_psychic_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_without_attacker_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_first_gardevoir_without_kirlia_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state() -> GameState:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	return gs


func _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state() -> GameState:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(_make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	return gs


func _build_online_shell_without_attacker_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_online_shell_without_attacker_vs_raging_bench_ex_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var opponent := gs.players[1]
	var bolt_cd := _make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240)
	bolt_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(bolt_cd, 1)
	var ogerpon_cd := _make_named_pokemon("Teal Mask Ogerpon ex", "Teal Mask Ogerpon ex", 210)
	ogerpon_cd.mechanic = "ex"
	opponent.bench.append(_make_slot(ogerpon_cd, 1))
	return gs


func _build_online_shell_without_attacker_vs_miraidon_pressure_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var opponent := gs.players[1]
	var miraidon_cd := _make_named_pokemon("Miraidon ex", "Miraidon ex", 220)
	miraidon_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(miraidon_cd, 1)
	var support_ex := _make_named_pokemon("Squawkabilly ex", "Squawkabilly ex", 160)
	support_ex.mechanic = "ex"
	opponent.bench.append(_make_slot(support_ex, 1))
	return gs


func _build_drifloon_pressure_needs_fuel_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Hand", "P"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("FuelRouteDeck%d" % i), 0))
	var opponent := gs.players[1]
	var miraidon_cd := _make_named_pokemon("Miraidon ex", "Miraidon ex", 220)
	miraidon_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(miraidon_cd, 1)
	return gs


func _build_online_shell_without_attacker_vs_charizard_weak_bench_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var opponent := gs.players[1]
	var charizard_cd := _make_named_pokemon("Charizard ex", "Charizard ex", 330)
	charizard_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(charizard_cd, 1)
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_unready_attack_shell_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_online_shell_with_unready_attacker_body_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	return gs


func _build_charizard_online_shell_with_unready_attacker_body_state() -> GameState:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var opponent := gs.players[1]
	opponent.active_pokemon = _make_slot(_make_named_pokemon("喷火龙ex", "Charizard ex", 330), 1)
	opponent.bench.append(_make_slot(_make_named_pokemon("波波", "Pidgey", 60), 1))
	return gs


func _build_online_shell_with_attacker_in_discard_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.deck.append(CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_support_only_in_discard_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	var manaphy := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY)
	manaphy.energy_type = "W"
	manaphy.hp = 70
	player.discard_pile.append(CardInstance.create(manaphy, 0))
	return gs


func _build_deck_out_pressure_attack_ready_state(deck_count: int = 4) -> GameState:
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler C"), 0))
	for i: int in deck_count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck%d" % i), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	return gs


func _build_online_shell_attack_ready_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("DeckLive%d" % i), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	return gs


func _build_online_shell_with_ready_drifloon_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_early_artazon_opening_state() -> GameState:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_scream_tail_cd(), 0)
	player.bench.clear()
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0))
	return gs


func test_refinement_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var kirlia_slot: PokemonSlot = player.bench[1]
	player.hand.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia_slot, "ability_index": 0},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell is online and Drifloon is already attack-ready, Refinement should cool off draw churn (got %f)" % score)


func test_radiant_greninja_draw_cools_off_once_shell_and_attacker_are_online_without_fuel() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	player.hand.clear()
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	var greninja := _make_slot(_make_placeholder_pokemon(DeckStrategyGardevoirScript.RADIANT_GRENINJA), 0)
	player.bench.append(greninja)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja, "ability_index": 0},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are online, Concealed Cards should not draw churn without an Energy fuel discard (got %f)" % score)


func test_buddy_buddy_poffin_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0,
		"Once Gardevoir shell and a ready attacker are online, Buddy-Buddy Poffin should stop acting like a live setup card (got %f)" % score)


func test_buddy_buddy_poffin_cools_off_once_online_shell_has_unready_attacker_body() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once Gardevoir ex is online and Drifloon is already on board, Poffin should not steal the conversion turn for bench padding (got %f)" % score)


func test_extra_flutter_mane_bench_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once the shell is online, extra control basics like Flutter Mane should stop taking bench space (got %f)" % score)


func test_first_munkidori_bench_cools_off_once_transition_shell_is_online() -> String:
	var gs := _build_transition_shell_without_munkidori_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 30.0,
		"Once Gardevoir shell is online and a live attacker already exists, first Munkidori should cool off instead of taking a full development turn (got %f)" % score)


func test_dark_attach_to_munkidori_cools_off_once_transition_shell_is_online() -> String:
	var gs := _build_transition_shell_without_munkidori_state()
	var player := gs.players[0]
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(munkidori)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": munkidori,
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once transition shell is online and Drifloon is already live, first Darkness attachment to Munkidori should cool off unless a real conversion window exists (got %f)" % score)


func test_dark_attach_to_munkidori_stays_low_during_closed_loop_attacker_recovery() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel B", "P"), 0))
	var s := _new_strategy()
	var dark_score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(stretcher_score > dark_score,
			"Closed-loop attacker recovery should prioritize Night Stretcher over a support Darkness attachment (stretcher=%f dark=%f)" % [stretcher_score, dark_score]),
		assert_true(dark_score <= 0.0,
			"During closed-loop attacker recovery, Darkness attachment to Munkidori should stay low unless it immediately converts a KO (got %f)" % dark_score),
	])


func test_tm_evolution_attach_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_late_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, late TM Evolution attachment should cool off (got %f)" % score)


func test_tm_evolution_granted_attack_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_late_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, late TM Evolution attack should stop outranking conversion lines (got %f)" % score)


func test_tm_evolution_attach_cools_off_in_midgame_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_mid_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, midgame TM Evolution attachment should also cool off instead of stealing the turn (got %f)" % score)


func test_tm_evolution_granted_attack_cools_off_in_midgame_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_mid_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, midgame TM Evolution attack should cool off instead of outranking conversion lines (got %f)" % score)


func test_tm_evolution_cools_off_in_late_shell_even_without_ready_attacker() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	var ok := attach_score <= 50.0 and attack_score <= 50.0
	return assert_true(ok,
		"Once Gardevoir shell is online in late game, TM Evolution should cool off even without a ready attacker (attach=%f attack=%f)" % [attach_score, attack_score])


func test_night_stretcher_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_recovery_bait_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 100.0,
		"Once the shell is online and recovery is not urgent, Night Stretcher should cool off instead of outranking conversion (got %f)" % score)


func test_super_rod_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_recovery_bait_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)},
		gs,
		0
	)
	return assert_true(score <= 100.0,
		"Once the shell is online and discard fuel is already healthy, Super Rod should cool off instead of churning resources (got %f)" % score)


func test_prof_turo_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and there is no urgent EX rescue, Professor Turo should not outrank conversion just because energies can be dumped (got %f)" % score)


func test_dark_energy_can_finish_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score >= 200.0,
		"When active Scream Tail is one colorless short, Darkness Energy should be allowed to finish the attack instead of being hard-forbidden (got %f)" % score)


func test_tm_evolution_should_not_outrank_finishing_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var dark_attach: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var tm_attach: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(dark_attach >= tm_attach,
		"When active Scream Tail can be made attack-ready immediately, TM Evolution should not outrank the direct attack setup line (dark=%f tm=%f)" % [dark_attach, tm_attach])


func test_tm_evolution_granted_attack_should_not_outrank_finishing_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var dark_attach: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var tm_attack: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(dark_attach >= tm_attack,
		"When active Scream Tail is one attachment away from attacking, TM Evolution's granted attack should not steal the turn (dark=%f tm_attack=%f)" % [dark_attach, tm_attack])


func test_tm_evolution_attachment_cools_off_on_first_players_first_turn() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var tm_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(tm_score < end_turn_score,
		"Going first on turn 1 cannot use TM Evolution's attack, so attaching it should cool off below passing (tm=%f end=%f)" % [tm_score, end_turn_score])


func test_first_turn_tool_search_prefers_bravery_over_dead_tm_evolution() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var s := _new_strategy()
	var picked_tool: Variant = s.pick_search_tool([tm, bravery], gs, 0)
	var picked_name := str((picked_tool as CardInstance).card_data.name) if picked_tool is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.BRAVERY_CHARM,
		"On the first player's first turn, Tool search should avoid dead TM Evolution and keep Bravery Charm instead")


func test_tm_evolution_attachment_cools_off_without_energy_to_pay_attack() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var tm_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(tm_score < end_turn_score,
		"TM Evolution should not be attached when the active Pokemon cannot pay its attack this turn and no hand Energy can fix it (tm=%f end=%f)" % [tm_score, end_turn_score])


func test_tool_search_prefers_bravery_when_tm_attack_has_no_energy_payment() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var s := _new_strategy()
	var picked_tool: Variant = s.pick_search_tool([tm, bravery], gs, 0)
	var picked_name := str((picked_tool as CardInstance).card_data.name) if picked_tool is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.BRAVERY_CHARM,
		"When no Energy can pay TM Evolution this turn, Tool search should keep Bravery Charm instead")


func test_tool_search_keeps_tm_when_same_search_can_find_earthen_vessel_payment() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var vessel := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)
	var s := _new_strategy()
	var picked_tool: Variant = s.pick_search_tool([tm, bravery, vessel], gs, 0)
	var picked_name := str((picked_tool as CardInstance).card_data.name) if picked_tool is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.TM_EVOLUTION,
		"If the paired Item search can take Earthen Vessel for the missing payment, Tool search should keep the live TM Evolution line")


func test_tool_search_prefers_bravery_when_active_already_has_non_tm_tool() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var s := _new_strategy()
	var picked_tool: Variant = s.pick_search_tool([tm, bravery], gs, 0)
	var picked_name := str((picked_tool as CardInstance).card_data.name) if picked_tool is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.BRAVERY_CHARM,
		"When the active already has a non-TM Tool, Tool search should avoid a TM Evolution that cannot be attached this turn")


func test_manual_psychic_attach_can_finish_active_drifloon_attack() -> String:
	var gs := _build_drifloon_manual_psychic_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Psychic B", "P"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score > 0.0,
		"When active Drifloon is one attachment away from attacking and no attacker is ready, manual Psychic attachment should stay online instead of being treated as dead tempo (got %f)" % score)


func test_search_priority_prefers_rebuilding_attacker_over_support_piece_once_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var drifloon := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var munkidori := CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var all_items: Array = [munkidori, drifloon]
	var step := {"id": "buddy_poffin_pokemon"}
	var context := {"game_state": gs, "player_index": 0, "all_items": all_items}
	var drifloon_score: float = s.score_interaction_target(drifloon, step, context)
	var munkidori_score: float = s.score_interaction_target(munkidori, step, context)
	return assert_true(drifloon_score > munkidori_score,
		"Once the shell is online but no attacker remains on board, search effects should prefer rebuilding Drifloon over another support piece (drifloon=%f munkidori=%f)" % [drifloon_score, munkidori_score])


func test_poffin_with_support_only_targets_stays_low_during_attacker_rebuild() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var klefki_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.KLEFKI)
	klefki_cd.energy_type = "P"
	klefki_cd.hp = 70
	var klefki := CardInstance.create(klefki_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0),
			"targets": [{"buddy_poffin_pokemon": [klefki]}],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"During attacker rebuild, Poffin should not keep a premium score when its concrete target is only support padding (got %f)" % score)


func test_poffin_with_support_only_targets_stays_low_during_unready_attacker_transition() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_scream_tail_cd(), 0))
	var klefki_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.KLEFKI)
	klefki_cd.energy_type = "P"
	klefki_cd.hp = 70
	var klefki := CardInstance.create(klefki_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0),
			"targets": [{"buddy_poffin_pokemon": [klefki]}],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the first Gardevoir ex has an unready attacker body, Poffin should not spend the transition turn on support padding (got %f)" % score)


func test_poffin_with_support_only_targets_does_not_get_launch_shell_ralts_score() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var manaphy_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY)
	manaphy_cd.energy_type = "W"
	manaphy_cd.hp = 70
	var manaphy := CardInstance.create(manaphy_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0),
			"targets": [{"buddy_poffin_pokemon": [manaphy]}],
		},
		gs,
		0
	)
	return assert_true(score <= 40.0,
		"While launch shell still needs Ralts, Poffin should not get the Ralts-search score when its concrete target is only Manaphy (got %f)" % score)


func test_poffin_with_ralts_targets_keeps_launch_shell_score() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var ralts_a := CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)
	var ralts_b := CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0),
			"targets": [{"buddy_poffin_pokemon": [ralts_a, ralts_b]}],
		},
		gs,
		0
	)
	return assert_true(score >= 800.0,
		"While launch shell still needs Ralts, Poffin should keep the shell-launch score when its concrete targets include Ralts (got %f)" % score)


func test_nest_ball_prioritizes_first_attacker_body_rebuild_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var nest_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0)},
		gs,
		0
	)
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(nest_score > stretcher_score,
		"Once the stage2 shell is online but no attacker body exists, Nest Ball should outrank blind Night Stretcher lines (nest=%f stretcher=%f)" % [nest_score, stretcher_score])


func test_shell_lock_benches_only_attacker_body_before_first_gardevoir_ultra_ball() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	var scream_tail := CardInstance.create(_make_scream_tail_cd(), 0)
	var s := _new_strategy()
	var bench_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": scream_tail},
		gs,
		0
	)
	var ultra_score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
			"targets": [{
				"discard_cards": [scream_tail, CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)],
				"search_pokemon": [CardInstance.create(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)],
			}],
		},
		gs,
		0
	)
	return assert_true(bench_score > ultra_score,
		"When Ultra Ball can make the first Gardevoir ex, the only attacker body should be benched before it can be discarded (bench=%f ultra=%f)" % [bench_score, ultra_score])


func test_turn_plan_switches_to_rebuild_attacker_once_stage2_shell_is_online_without_attacker_body() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker", "Once the stage2 shell is online but no attacker body exists, the turn intent should switch to rebuild_attacker"),
		assert_true(bool(plan.get("flags", {}).get("shell_online", false)), "Stage2 shell should be marked online in the rebuild-attacker window"),
	])


func test_first_gardevoir_online_without_kirlia_still_switches_to_rebuild_attacker() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker", "Once the first Gardevoir ex is online but no attacker body exists yet, intent should still pivot to rebuild_attacker even without Kirlia"),
		assert_true(bool(plan.get("flags", {}).get("has_gardevoir_ex", false)), "The rebuild-attacker window should recognize the first Gardevoir ex as online"),
	])


func test_night_stretcher_stays_low_when_first_attacker_body_is_missing_but_no_attacker_is_in_discard() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the stage2 shell is online but no attacker is in discard, Night Stretcher should stay low and let the deck rebuild a fresh attacker body first (got %f)" % score)


func test_night_stretcher_stays_low_when_only_support_target_is_in_discard() -> String:
	var gs := _build_online_shell_with_support_only_in_discard_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the online shell only has support bodies like Manaphy in discard, Night Stretcher should stay low instead of stealing the turn (got %f)" % score)


func test_bench_priority_prefers_rebuilding_attacker_over_ralts_once_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	var ok := drifloon_score > ralts_score and drifloon_score > munkidori_score and ralts_score <= 20.0 and munkidori_score <= 20.0
	return assert_true(ok,
		"Once the shell is online but no attacker remains, hand benching should rebuild Drifloon while cooling off Ralts and Munkidori (drifloon=%f ralts=%f munkidori=%f)" % [drifloon_score, ralts_score, munkidori_score])


func test_first_gardevoir_online_without_kirlia_still_prefers_rebuilding_attacker_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	return assert_true(drifloon_score > ralts_score,
		"Even with only the first Gardevoir ex online, attacker rebuild should outrank extra Ralts padding (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_search_still_prefers_attacker_rebuild_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var ralts_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(drifloon_score > ralts_score,
		"Even with only the first Gardevoir ex online, search routing should still prefer rebuilding a real attacker over another Ralts (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_night_stretcher_prefers_attacker_rebuild() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state()
	var s := _new_strategy()
	var action_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var drifloon_score: float = s._score_night_stretcher_choice_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		gs,
		0
	)
	var ralts_score: float = s._score_night_stretcher_choice_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		gs,
		0
	)
	return run_checks([
		assert_true(action_score >= 200.0, "Once the first Gardevoir ex is online and fuel exists, Night Stretcher should become a real attacker rebuild action even without Kirlia (got %f)" % action_score),
		assert_true(drifloon_score > ralts_score, "Night Stretcher target routing should prefer Drifloon rebuild over extra Ralts padding once the first Gardevoir ex is online (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score]),
	])


func test_first_gardevoir_online_without_kirlia_handoff_prefers_attacker_body_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var drifloon_slot: PokemonSlot = null
	var ralts_slot: PokemonSlot = null
	for slot: PokemonSlot in player.bench:
		if slot.get_pokemon_name() == DeckStrategyGardevoirScript.DRIFLOON:
			drifloon_slot = slot
		elif slot.get_pokemon_name() == DeckStrategyGardevoirScript.RALTS and ralts_slot == null:
			ralts_slot = slot
	var context := {"game_state": gs, "player_index": 0}
	var drifloon_score: float = s._score_handoff_target(drifloon_slot, "pivot_target", context)
	var ralts_score: float = s._score_handoff_target(ralts_slot, "pivot_target", context)
	return assert_true(drifloon_score > ralts_score,
		"Once the first Gardevoir ex is online, handoff routing should prefer the attacker body over extra Ralts padding even without Kirlia (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_post_stage2_handoff_live_with_attacker_body_and_fuel() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state()
	var s := _new_strategy()
	return assert_true(
		s._post_stage2_handoff_live(gs, gs.players[0], 0),
		"Once the first Gardevoir ex is online, an attacker body exists, and discard fuel is ready, post-stage2 handoff should already be live even without Kirlia"
	)


func test_rebuild_attacker_closed_loop_uses_bridge_target_as_owner_once_first_gardevoir_is_online() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker_closed_loop", "First Gardevoir online plus attacker-in-discard fuel should enter rebuild_attacker_closed_loop"),
		assert_eq(str(plan.get("targets", {}).get("primary_attacker_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild should treat the bridge attacker as the primary attacker target"),
		assert_eq(str(plan.get("targets", {}).get("pivot_target_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild should pivot toward the bridge attacker instead of Gardevoir ex"),
		assert_eq(str(contract.get("owner", {}).get("turn_owner_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild contract owner should move onto the bridge attacker"),
	])


func test_psychic_embrace_stays_off_non_attacker_during_closed_loop_attacker_recovery() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel B", "P"), 0))
	var gardevoir_slot: PokemonSlot = player.bench[0]
	var s := _new_strategy()
	var embrace_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir_slot,
			"targets": [{"embrace_energy": [player.discard_pile[1]], "embrace_target": [gardevoir_slot]}],
		},
		gs,
		0
	)
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(embrace_score < 0.0,
			"Closed-loop attacker recovery should not spend Psychic Embrace damage on Gardevoir ex before recovering the attacker (got %f)" % embrace_score),
		assert_true(stretcher_score > embrace_score,
			"Recovering the attacker should outrank non-attacker Psychic Embrace during closed-loop rebuild (stretcher=%f embrace=%f)" % [stretcher_score, embrace_score]),
	])


func test_post_tm_refinement_waits_when_ultra_ball_can_make_first_gardevoir() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	player.bench.clear()
	var kirlia_a := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	var kirlia_b := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(kirlia_a)
	player.bench.append(kirlia_b)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler Supporter", "Supporter"), 0))
	var s := _new_strategy()
	var refinement_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia_a, "ability_index": 0},
		gs,
		0
	)
	var ultra_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": player.hand[0]},
		gs,
		0
	)
	var ultra_discard_score: float = s.score_interaction_target(
		player.hand[0],
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	var filler_discard_score: float = s.score_interaction_target(
		player.hand[1],
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(ultra_score > refinement_score,
			"After TM Evolution, a direct Ultra Ball line to first Gardevoir ex should be played before Refinement churn (ultra=%f refinement=%f)" % [ultra_score, refinement_score]),
		assert_true(ultra_discard_score < filler_discard_score,
			"Refinement discard targeting should protect Ultra Ball while the first Gardevoir ex is still missing (ultra=%f filler=%f)" % [ultra_discard_score, filler_discard_score]),
	])


func test_post_tm_arven_tool_prefers_bravery_charm_over_second_tm() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var charm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var tools: Array = [tm, charm]
	var s := _new_strategy()
	var tm_score: float = s.score_interaction_target(tm, {"id": "search_tool"}, {"game_state": gs, "player_index": 0, "all_items": tools})
	var charm_score: float = s.score_interaction_target(charm, {"id": "search_tool"}, {"game_state": gs, "player_index": 0, "all_items": tools})
	return assert_true(charm_score > tm_score,
		"After the first TM Evolution established two Kirlia, Arven's tool should become Bravery Charm instead of a redundant second TM (charm=%f tm=%f)" % [charm_score, tm_score])


func test_pre_tm_arven_caches_ultra_ball_and_bravery_before_tm_attack() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var charizard_cd := _make_named_pokemon("Charizard ex", "Charizard ex", 330)
	charizard_cd.mechanic = "ex"
	gs.players[1].active_pokemon = _make_slot(charizard_cd, 1)
	var s := _new_strategy()
	var arven_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	)
	var tm_attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs,
		0
	)
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var picked_tool: Variant = s.pick_search_tool([tm, bravery], gs, 0)
	var tool_ok := picked_tool is CardInstance and str((picked_tool as CardInstance).card_data.name) == DeckStrategyGardevoirScript.BRAVERY_CHARM
	return run_checks([
		assert_true(arven_score > tm_attack_score,
			"Once TM is already attached and two Ralts can evolve, Arven should cache Ultra Ball + Bravery before firing TM Evolution (arven=%f tm=%f)" % [arven_score, tm_attack_score]),
		assert_true(tool_ok,
			"That pre-TM Arven route should choose Bravery Charm over a redundant second TM Evolution"),
	])


func test_pre_tm_arven_cache_stays_off_into_miraidon_pressure() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.hand.clear()
	player.deck.clear()
	var active_cd := _make_named_pokemon(DeckStrategyGardevoirScript.KLEFKI, "Klefki", 70)
	active_cd.energy_type = "P"
	player.active_pokemon = _make_slot(active_cd, 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0))
	var miraidon_cd := _make_named_pokemon("Miraidon ex", "Miraidon ex", 220)
	miraidon_cd.mechanic = "ex"
	gs.players[1].active_pokemon = _make_slot(miraidon_cd, 1)
	var s := _new_strategy()
	var arven_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	)
	var tm_attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs,
		0
	)
	return assert_true(tm_attack_score > arven_score,
		"Into Miraidon-style pressure, do not spend the turn-two Arven cache before the TM Evolution launch (arven=%f tm=%f)" % [arven_score, tm_attack_score])


func test_headless_artazon_uses_gardevoir_strategy_score_into_miraidon_pressure() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var s := _new_strategy()
	var builder := AILegalActionBuilderScript.new()
	builder.set_deck_strategy(s)
	var scream_tail := CardInstance.create(_make_scream_tail_cd(), 0)
	var drifloon := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var items: Array = [scream_tail, drifloon]
	var picked: Array = builder.call(
		"_select_headless_items",
		gsm,
		0,
		0,
		{"id": "artazon_pokemon", "max_select": 1},
		items,
		1,
		{}
	)
	return run_checks([
		assert_eq(picked.size(), 1, "Headless Artazon should select exactly one basic Pokemon"),
		assert_true(picked[0] == drifloon,
			"Headless Artazon should use the deck strategy score and take Drifloon into Miraidon pressure instead of the first listed attacker"),
	])


func test_rules_prefers_bench_gardevoir_ex_evolution_over_active_kirlia() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	var bench_kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(bench_kirlia)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var gardevoir_card := CardInstance.create(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "evolve", "card": gardevoir_card, "target_slot": player.active_pokemon},
		gs,
		0
	)
	var bench_score: float = s.score_action_absolute(
		{"kind": "evolve", "card": gardevoir_card, "target_slot": bench_kirlia},
		gs,
		0
	)
	return run_checks([
		assert_true(active_score <= 0.0, "Active Kirlia should be preserved when a bench Kirlia can become the Gardevoir ex engine (active=%f)" % active_score),
		assert_true(bench_score > active_score, "Bench Gardevoir ex evolution should outrank exposing the active Kirlia as a two-prize pivot (bench=%f active=%f)" % [bench_score, active_score]),
	])


func test_rules_blocks_second_active_gardevoir_ex_after_bench_engine_online() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{
			"kind": "evolve",
			"card": CardInstance.create(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(active_score <= 0.0,
		"Once a bench Gardevoir ex engine is online, active Kirlia should not become a second exposed Gardevoir ex (got %f)" % active_score)


func test_rules_active_gardevoir_non_ko_attack_yields_to_ready_handoff() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var active_gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	active_gardevoir.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Retreat A", "P"), 0))
	active_gardevoir.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Retreat B", "P"), 0))
	player.active_pokemon = active_gardevoir
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 60
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attacker", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attacker Backup", "P"), 0))
	player.bench.append(drifloon)
	gs.players[1].active_pokemon = _make_slot(_make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240), 1)
	var s := _new_strategy()
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 190, "projected_knockout": false},
		gs,
		0
	)
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": drifloon},
		gs,
		0
	)
	return run_checks([
		assert_true(attack_score <= 180.0, "Non-KO Gardevoir ex attacks should cool off when a real attacker handoff is live (got %f)" % attack_score),
		assert_true(retreat_score > attack_score, "Ready attacker handoff should outrank a non-KO Gardevoir ex attack (retreat=%f attack=%f)" % [retreat_score, attack_score]),
	])


func test_rules_active_gardevoir_does_not_retreat_into_second_gardevoir_without_attacker() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var bench_gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	player.bench.append(bench_gardevoir)
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var s := _new_strategy()
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": bench_gardevoir},
		gs,
		0
	)
	return assert_true(retreat_score < 0.0,
		"Active Gardevoir ex should not cycle into a second Gardevoir ex when no real attacker is ready (got %f)" % retreat_score)


func test_rules_active_gardevoir_non_ko_attack_yields_to_first_attacker_body() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var drifloon_instance := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	player.hand.append(drifloon_instance)
	gs.players[1].active_pokemon = _make_slot(_make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240), 1)
	var s := _new_strategy()
	var bench_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": drifloon_instance},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 190, "projected_knockout": false},
		gs,
		0
	)
	return assert_true(bench_score > attack_score,
		"When active Gardevoir ex has no attacker body behind it, benching the first attacker should outrank a non-KO core attack (bench=%f attack=%f)" % [bench_score, attack_score])


func test_rules_active_gardevoir_still_takes_visible_ko() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var drifloon_instance := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	player.hand.append(drifloon_instance)
	var rulebox_defender := _make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 190)
	rulebox_defender.mechanic = "ex"
	gs.players[1].active_pokemon = _make_slot(rulebox_defender, 1)
	var s := _new_strategy()
	var bench_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": drifloon_instance},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 190, "projected_knockout": true},
		gs,
		0
	)
	return assert_true(attack_score > bench_score,
		"Gardevoir ex should still take an immediate rule-box KO instead of delaying for attacker continuity (attack=%f bench=%f)" % [attack_score, bench_score])


func test_ralts_bench_cools_off_once_online_shell_already_has_an_unready_attacker_body() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ralts_score <= 20.0, "Once the shell is online and an attacker body already exists, extra Ralts should cool off instead of rebuilding more shell (got %f)" % ralts_score),
		assert_true(munkidori_score <= 20.0, "Once the shell is online and an attacker body already exists, first Munkidori should also stay cooled off (got %f)" % munkidori_score),
	])


func test_transition_shell_adds_drifloon_backup_when_only_unready_scream_tail_exists() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_make_scream_tail_cd(), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel B", "P"), 0))
	var s := _new_strategy()
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(drifloon_score >= 180.0,
			"When the stage2 shell has only an unready Scream Tail and Psychic fuel, benching a Drifloon backup should be a real transition action (got %f)" % drifloon_score),
		assert_true(drifloon_score > ralts_score,
			"Transition backup benching should prefer Drifloon over extra Ralts padding (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score]),
	])


func test_support_basics_turn_negative_once_stage2_shell_has_attacker_body() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var flutter_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(flutter_score < 0.0, "Once Gardevoir ex is online and an attacker body exists, Flutter Mane should stop padding the bench (got %f)" % flutter_score),
		assert_true(munkidori_score < 0.0, "Once Gardevoir ex is online and an attacker body exists, Munkidori should stay off the bench until a real conversion window exists (got %f)" % munkidori_score),
	])


func test_night_stretcher_outranks_poffin_and_heavy_ball_when_online_shell_needs_attacker_recovery() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var s := _new_strategy()
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	var heavy_ball_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	var ok := stretcher_score > poffin_score and stretcher_score > heavy_ball_score and stretcher_score >= 250.0
	return assert_true(ok,
		"Once the shell is online but no ready attacker exists and one is sitting in discard, Night Stretcher should outrank Poffin/Heavy Ball recovery filler (stretcher=%f poffin=%f heavy=%f)" % [stretcher_score, poffin_score, heavy_ball_score])


func test_secret_box_outranks_super_rod_for_preferred_attacker_recovery() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	var miraidon_cd := _make_named_pokemon("Miraidon ex", "Miraidon ex", 220)
	miraidon_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(miraidon_cd, 1)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler Supporter", "Supporter"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	var s := _new_strategy()
	var box_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": player.hand[0]},
		gs,
		0
	)
	var rod_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": player.hand[1]},
		gs,
		0
	)
	return run_checks([
		assert_true(box_score > rod_score,
			"When preferred Drifloon recovery is live, Secret Box should find Night Stretcher before Super Rod shuffles the attacker/fuel away (box=%f rod=%f)" % [box_score, rod_score]),
		assert_true(rod_score <= 120.0,
			"Super Rod should stay low while a direct preferred-attacker recovery route is available (got %f)" % rod_score),
	])


func test_night_stretcher_cools_off_when_unready_attacker_body_already_exists() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var s := _new_strategy()
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(stretcher_score <= 100.0,
		"When an unready attacker body already exists on board, Night Stretcher should cool off instead of acting like urgent recovery just because another attacker is in discard (got %f)" % stretcher_score)


func test_night_stretcher_choice_prefers_real_attacker_over_munkidori_in_transition_shell() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	player.discard_pile.clear()
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var munkidori_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MUNKIDORI)
	munkidori_cd.energy_type = "D"
	munkidori_cd.hp = 110
	player.discard_pile.append(CardInstance.create(munkidori_cd, 0))
	var s := _new_strategy()
	var drifloon: CardInstance = player.discard_pile[0]
	var munkidori: CardInstance = player.discard_pile[1]
	var drifloon_score: float = s.score_interaction_target(drifloon, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var munkidori_score: float = s.score_interaction_target(munkidori, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(drifloon_score > munkidori_score,
		"Night Stretcher should prefer rebuilding a real attacker over recovering Munkidori in transition-shell states (drifloon=%f munkidori=%f)" % [drifloon_score, munkidori_score])


func test_night_stretcher_choice_prefers_real_attacker_over_manaphy_in_transition_shell() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	var manaphy := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY)
	manaphy.energy_type = "W"
	manaphy.hp = 70
	player.discard_pile.append(CardInstance.create(manaphy, 0))
	var s := _new_strategy()
	var drifloon: CardInstance = player.discard_pile[0]
	var manaphy_card: CardInstance = player.discard_pile[1]
	var drifloon_score: float = s.score_interaction_target(drifloon, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var manaphy_score: float = s.score_interaction_target(manaphy_card, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(drifloon_score > manaphy_score,
		"Night Stretcher should prefer rebuilding a real attacker over recovering Manaphy in transition-shell states (drifloon=%f manaphy=%f)" % [drifloon_score, manaphy_score])


func test_night_stretcher_choice_prefers_first_gardevoir_over_munkidori_when_stage2_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.discard_pile.append(CardInstance.create(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	var munkidori_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MUNKIDORI)
	munkidori_cd.energy_type = "D"
	munkidori_cd.hp = 110
	player.discard_pile.append(CardInstance.create(munkidori_cd, 0))
	var s := _new_strategy()
	var gardevoir: CardInstance = player.discard_pile[0]
	var munkidori: CardInstance = player.discard_pile[1]
	var gardevoir_score: float = s.score_interaction_target(gardevoir, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var munkidori_score: float = s.score_interaction_target(munkidori, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(gardevoir_score > munkidori_score,
		"Night Stretcher should prefer the first Gardevoir ex over Munkidori while the stage2 shell is still missing (gard=%f munk=%f)" % [gardevoir_score, munkidori_score])


func test_preferred_drifloon_recovery_outranks_scream_tail_investment_into_arceus_vstar() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Arceus VSTAR", "Arceus VSTAR", 280), 1)
	opponent.active_pokemon.get_card_data().mechanic = "VSTAR"
	var s := _new_strategy()
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var dark_attach_score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0),
			"target_slot": scream_tail,
		},
		gs,
		0
	)
	var embrace_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[0],
			"targets": [{"embrace_energy": [player.discard_pile[1]], "embrace_target": [scream_tail]}],
		},
		gs,
		0
	)
	return run_checks([
		assert_true(stretcher_score >= 500.0,
			"When Arceus VSTAR demands Drifloon pressure and Drifloon is in discard, Night Stretcher should become the main route (got %f)" % stretcher_score),
		assert_true(stretcher_score > dark_attach_score,
			"Preferred Drifloon recovery should outrank investing Darkness into Scream Tail with no bench-prize route (stretcher=%f dark=%f)" % [stretcher_score, dark_attach_score]),
		assert_true(embrace_score < 0.0,
			"Psychic Embrace should not keep scaling Scream Tail while the preferred Drifloon route is recoverable (got %f)" % embrace_score),
	])


func test_drifloon_pressure_route_prefers_earthen_vessel_over_ultra_ball_search() -> String:
	var gs := _build_drifloon_pressure_needs_fuel_state()
	var s := _new_strategy()
	var earthen := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)
	var ultra := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0)
	var all_items: Array = [ultra, earthen]
	var picked: Variant = s.pick_search_item(all_items, gs, 0)
	var earthen_score: float = s.score_interaction_target(
		earthen,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": all_items}
	)
	var ultra_score: float = s.score_interaction_target(
		ultra,
		{"id": "search_item"},
		{"game_state": gs, "player_index": 0, "all_items": all_items}
	)
	return run_checks([
		assert_eq(str((picked as CardInstance).card_data.name), DeckStrategyGardevoirScript.EARTHEN_VESSEL,
			"Arven-style item routing should take Earthen Vessel when Charmed Drifloon needs discard fuel"),
		assert_true(earthen_score > ultra_score,
			"Earthen Vessel should outrank Ultra Ball for the Charmed Drifloon fuel route (earthen=%f ultra=%f)" % [earthen_score, ultra_score]),
	])


func test_drifloon_pressure_route_plays_earthen_before_low_damage_attack_and_iono() -> String:
	var gs := _build_drifloon_pressure_needs_fuel_state()
	var s := _new_strategy()
	var earthen_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)},
		gs,
		0
	)
	var iono_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 60},
		gs,
		0
	)
	return run_checks([
		assert_true(earthen_score > attack_score,
			"Earthen Vessel should be played before taking a low-damage Charmed Drifloon attack into Miraidon (earthen=%f attack=%f)" % [earthen_score, attack_score]),
		assert_true(iono_score < 0.0,
			"Iono should not shuffle away a live Earthen/Psychic fuel route before Drifloon is scaled (got %f)" % iono_score),
	])


func test_drifloon_pressure_route_keeps_refinement_live_for_extra_psychic_fuel() -> String:
	var gs := _build_drifloon_pressure_needs_fuel_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var kirlia := player.bench[1]
	var ability_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 60},
		gs,
		0
	)
	return assert_true(ability_score > attack_score,
		"Refinement should stay live to discard extra Psychic fuel before a non-KO Charmed Drifloon attack (ability=%f attack=%f)" % [ability_score, attack_score])


func test_drifloon_pressure_route_protects_earthen_from_discard_effects() -> String:
	var gs := _build_drifloon_pressure_needs_fuel_state()
	var s := _new_strategy()
	var earthen := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)
	var filler := CardInstance.create(_make_trainer_cd("Filler Supporter", "Supporter"), 0)
	var earthen_discard_score: float = s.score_interaction_target(
		earthen,
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	var filler_discard_score: float = s.score_interaction_target(
		filler,
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(earthen_discard_score < filler_discard_score,
		"Earthen Vessel should be protected from discard while it is the Charmed Drifloon fuel route (earthen=%f filler=%f)" % [earthen_discard_score, filler_discard_score])


func test_iono_stays_low_while_first_gardevoir_is_still_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"While the first Gardevoir ex is still missing, Iono should stay low instead of interrupting shell completion (got %f)" % score)


func test_prof_turo_stays_low_while_first_gardevoir_is_still_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"While the first Gardevoir ex is still missing, Professor Turo should stay low instead of stealing the rebuild turn (got %f)" % score)


func test_prof_turo_rescues_trapped_active_gardevoir_into_ready_drifloon_ko() -> String:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var active_gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	active_gardevoir.damage_counters = 160
	player.active_pokemon = active_gardevoir
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	for i: int in 3:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.bench.append(drifloon)
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Raikou V", "Raikou V", 200), 1)
	opponent.active_pokemon.get_card_data().mechanic = "V"
	opponent.active_pokemon.damage_counters = 120
	var turo := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)
	var filler_a := CardInstance.create(_make_trainer_cd("Filler A"), 0)
	var filler_b := CardInstance.create(_make_trainer_cd("Filler B"), 0)
	player.hand.append(turo)
	player.hand.append(filler_a)
	player.hand.append(filler_b)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0))
	var s := _new_strategy()
	var turo_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": turo},
		gs,
		0
	)
	var secret_score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0),
			"targets": [{"discard_cards": [turo, filler_a, filler_b]}],
		},
		gs,
		0
	)
	return run_checks([
		assert_true(turo_score >= 600.0,
			"Professor Turo should be a high-priority bridge when Boss traps active Gardevoir ex and a ready Drifloon can KO (got %f)" % turo_score),
		assert_true(turo_score > secret_score,
			"Secret Box should not discard Professor Turo in the trapped-Gardevoir handoff window (turo=%f secret=%f)" % [turo_score, secret_score]),
	])


func test_refinement_shuts_off_under_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[1],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the deck is almost empty and an attacker is already online, Kirlia's Refinement should shut off instead of spending more deck (got %f)" % score)


func test_iono_shuts_off_under_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the deck is under deck-out pressure and an attacker is already ready, Iono should shut off instead of burning more draws (got %f)" % score)


func test_refinement_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var player := gs.players[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[1],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When only eight cards remain and an attacker is already online, Kirlia's Refinement should already cool off to avoid self-decking (got %f)" % score)


func test_iono_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When only eight cards remain and an attacker is already online, Iono should stop burning deck on redraw churn (got %f)" % score)


func test_iono_shuts_off_once_shell_and_attacker_are_online_without_real_comeback_need() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell and a ready attacker are already online, Iono should cool off to a low score unless the game truly needs a comeback reset (got %f)" % score)


func test_iono_shuts_off_with_stable_hand_once_shell_and_attacker_are_online_even_if_behind() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.hand.clear()
	player.prizes.clear()
	opponent.prizes.clear()
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler C"), 0))
	_fill_prizes(player, 4)
	_fill_prizes(opponent, 3)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Even when slightly behind, Iono should stay off once the shell and a ready attacker are online and the hand is stable (got %f)" % score)


func test_radiant_greninja_bench_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_make_placeholder_pokemon(DeckStrategyGardevoirScript.RADIANT_GRENINJA), 0),
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Radiant Greninja should stay off once the shell and a ready attacker are already online, instead of burning a bench slot for late churn (got %f)" % score)


func test_ralts_bench_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"When only eight cards remain and an attacker is already online, rebuilding another Ralts line should cool off instead of outranking conversion (got %f)" % score)


func test_late_rebuild_draw_abilities_shut_off_under_expanded_deck_out_lock() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Hand", "P"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Darkness Hand", "D"), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ThinDeck%d" % i), 0))
	var greninja := _make_slot(_make_placeholder_pokemon(DeckStrategyGardevoirScript.RADIANT_GRENINJA), 0)
	player.bench.append(greninja)
	var s := _new_strategy()
	var kirlia_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.bench[1]},
		gs,
		0
	)
	var greninja_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja},
		gs,
		0
	)
	return run_checks([
		assert_true(kirlia_score <= 0.0,
			"Once the stage2 shell is online and only twelve cards remain, Kirlia draw should be locked out during rebuild instead of causing late deck-out churn (got %f)" % kirlia_score),
		assert_true(greninja_score <= 0.0,
			"Once the stage2 shell is online and only twelve cards remain, Greninja draw should be locked out during rebuild instead of causing late deck-out churn (got %f)" % greninja_score),
	])


func test_late_rebuild_draw_abilities_stay_locked_after_recovery_lifts_deck_above_pressure_threshold() -> String:
	var gs := _build_online_shell_without_attacker_state()
	gs.turn_number = 30
	var player := gs.players[0]
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Hand", "P"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Darkness Hand", "D"), 0))
	for i: int in 18:
		player.deck.append(CardInstance.create(_make_trainer_cd("RecoveredDeck%d" % i), 0))
	var greninja := _make_slot(_make_placeholder_pokemon(DeckStrategyGardevoirScript.RADIANT_GRENINJA), 0)
	player.bench.append(greninja)
	var s := _new_strategy()
	var kirlia_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.bench[1]},
		gs,
		0
	)
	var greninja_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja},
		gs,
		0
	)
	return run_checks([
		assert_true(kirlia_score <= 0.0,
			"After a long rebuild loop, Kirlia draw should remain locked even if recovery temporarily lifts the deck above the numeric pressure threshold (got %f)" % kirlia_score),
		assert_true(greninja_score <= 0.0,
			"After a long rebuild loop, Greninja draw should remain locked even if recovery temporarily lifts the deck above the numeric pressure threshold (got %f)" % greninja_score),
	])


func test_artazon_scores_as_live_opening_stadium_in_absolute_strategy_path() -> String:
	var gs := _build_early_artazon_opening_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var stadium_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_stadium",
			"card": stadium_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score >= 200.0,
		"Artazon should be treated as a live early-game setup action in the absolute strategy path instead of falling through to zero (got %f)" % score)


func test_super_rod_stays_negative_during_shell_lock_without_real_recovery_targets() -> String:
	var gs := _build_shell_lock_with_empty_night_stretcher_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"During shell lock, Super Rod should stay negative if it is not actually recovering a core shell piece or attacker (got %f)" % score)


func test_manaphy_bench_stays_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY), 0),
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Manaphy should stay off once the shell and a ready attacker are already online instead of stealing a bench slot from conversion (got %f)" % score)


func test_munkidori_ability_turns_negative_without_immediate_ko_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[2],
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are already online, Munkidori should not spend turns moving damage unless it can immediately convert into a KO (got %f)" % score)


func test_munkidori_ability_stays_negative_when_total_damage_exceeds_hp_but_single_use_cannot_ko() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	player.active_pokemon.damage_counters = 40
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_placeholder_pokemon("Tight Target"), 1)
	gs.players[1].active_pokemon.pokemon_stack[0].card_data.hp = 40
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[2],
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Munkidori should stay negative when the board has 40 damage total but a single ability use can only move 30 damage (got %f)" % score)


func test_munkidori_partial_headless_action_stays_negative_even_when_ko_math_exists() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.active_pokemon.damage_counters = 30
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	var munkidori: PokemonSlot = player.bench[2]
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	opponent.active_pokemon.pokemon_stack[0].card_data.hp = 100
	opponent.active_pokemon.damage_counters = 80
	var partial_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": munkidori,
			"targets": [{"source_pokemon": [player.active_pokemon]}],
		},
		gs,
		0
	)
	var resolved_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": munkidori,
			"targets": [{
				"source_pokemon": [player.active_pokemon],
				"target_damage_counters": [{"target": opponent.active_pokemon, "amount": 20}],
			}],
		},
		gs,
		0
	)
	return run_checks([
		assert_true(partial_score < 0.0,
			"Partial Munkidori source-only actions should not be treated as conversion KOs because they make no progress in headless play (got %f)" % partial_score),
		assert_true(resolved_score > partial_score,
			"A fully resolved Munkidori counter-transfer target should still score above the source-only stalled action (resolved=%f partial=%f)" % [resolved_score, partial_score]),
	])


func test_buddy_buddy_poffin_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are online, Buddy-Buddy Poffin should be actively worse than ending turn or attacking (got %f)" % score)


func test_continuity_contract_lifts_backup_ralts_before_nonfinal_attack() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	opponent.active_pokemon.pokemon_stack[0].card_data.hp = 220
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ContinuityDeck%d" % i), 0))
	player.hand.append(CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var ralts_action := {
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
	}
	var attack_action := {
		"kind": "attack",
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var ralts_score: float = s.score_action_absolute_with_plan(ralts_action, gs, 0, turn_contract)
	var attack_score: float = s.score_action_absolute_with_plan(attack_action, gs, 0, turn_contract)
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Continuity should be enabled while a ready attacker lacks a backup Ralts/Kirlia line"),
		assert_true(bool(continuity.get("setup_debt", {}).get("need_backup_ralts_or_kirlia", false)), "Continuity debt should name the missing backup Ralts/Kirlia line"),
		assert_true(ralts_score > attack_score, "Safe backup Ralts setup should outrank a non-final attack through score_action_absolute_with_plan (ralts=%f attack=%f)" % [ralts_score, attack_score]),
	])


func test_continuity_bonus_does_not_lift_nest_ball_when_it_searches_support_only() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	opponent.active_pokemon.pokemon_stack[0].card_data.hp = 220
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ContinuityDeck%d" % i), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var nest_munkidori_action := {
		"kind": "play_trainer",
		"card": player.hand[player.hand.size() - 1],
		"targets": [{"basic_pokemon": [CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)]}],
	}
	var attack_action := {
		"kind": "attack",
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var nest_score: float = s.score_action_absolute_with_plan(nest_munkidori_action, gs, 0, turn_contract)
	var attack_score: float = s.score_action_absolute_with_plan(attack_action, gs, 0, turn_contract)
	return assert_true(nest_score < attack_score,
		"Continuity should not inflate Nest Ball when its resolved target is support-only instead of the owed backup line (nest=%f attack=%f)" % [nest_score, attack_score])


func test_continuity_contract_does_not_delay_final_prize_ko() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ContinuityDeck%d" % i), 0))
	player.hand.append(CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0))
	_fill_prizes(player, 1)
	_fill_prizes(opponent, 4)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var ralts_action := {
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
	}
	var attack_action := {
		"kind": "attack",
		"projected_damage": 120,
		"projected_knockout": true,
	}
	var ralts_score: float = s.score_action_absolute_with_plan(ralts_action, gs, 0, turn_contract)
	var attack_score: float = s.score_action_absolute_with_plan(attack_action, gs, 0, turn_contract)
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	return run_checks([
		assert_false(bool(continuity.get("enabled", false)), "Continuity should be disabled when the current attack takes the final prize"),
		assert_true(attack_score > ralts_score, "Final-prize KO must not be delayed by optional setup (attack=%f ralts=%f)" % [attack_score, ralts_score]),
	])


func test_continuity_contract_does_not_delay_key_rulebox_ko() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	var rulebox_defender := _make_placeholder_pokemon("Rulebox Defender")
	rulebox_defender.mechanic = "ex"
	rulebox_defender.hp = 120
	opponent.active_pokemon = _make_slot(rulebox_defender, 1)
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ContinuityDeck%d" % i), 0))
	player.hand.append(CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var ralts_action := {
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
	}
	var attack_action := {
		"kind": "attack",
		"projected_damage": 120,
		"projected_knockout": true,
	}
	var ralts_score: float = s.score_action_absolute_with_plan(ralts_action, gs, 0, turn_contract)
	var attack_score: float = s.score_action_absolute_with_plan(attack_action, gs, 0, turn_contract)
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	return run_checks([
		assert_false(bool(continuity.get("enabled", false)), "Continuity should be disabled for an immediate rule-box KO"),
		assert_true(attack_score > ralts_score, "A key rule-box KO must not be delayed by optional setup (attack=%f ralts=%f)" % [attack_score, ralts_score]),
	])


func test_continuity_contract_stops_inflating_churn_when_debt_is_paid() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	var backup_scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	backup_scream_tail.damage_counters = 40
	backup_scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Backup", "P"), 0))
	backup_scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Backup", "D"), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(backup_scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel B", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel C", "P"), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("ContinuityDeck%d" % i), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var poffin_action := {
		"kind": "play_trainer",
		"card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0),
	}
	var direct_score: float = s.score_action_absolute(poffin_action, gs, 0)
	var planned_score: float = s.score_action_absolute_with_plan(poffin_action, gs, 0, turn_contract)
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	return run_checks([
		assert_false(bool(continuity.get("enabled", false)), "Continuity should disable once backup line, fuel, and next attacker are already covered"),
		assert_eq(planned_score, direct_score, "Paid continuity debt should not inflate Poffin or other churn actions"),
		assert_true(planned_score <= 0.0, "Poffin should remain cooled off after continuity is complete (got %f)" % planned_score),
	])


func test_one_energy_attacker_body_is_not_counted_as_ready_attacker() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	var s := _new_strategy()
	return assert_eq(s._count_ready_attackers(player), 0, "A one-energy Drifloon body should not be counted as a ready attacker")


func test_zero_damage_scream_tail_is_not_counted_as_ready_attacker() -> String:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.bench.append(scream_tail)
	var s := _new_strategy()
	return assert_eq(s._count_ready_attackers(player), 0,
		"Scream Tail with enough energy but no damage counters should not count as a ready attacker")


func test_boss_orders_stays_low_when_only_one_energy_attacker_body_exists() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	gs.players[1].bench.append(_make_slot(_make_placeholder_pokemon("Weak Target"), 1))
	gs.players[1].bench[0].pokemon_stack[0].card_data.hp = 60
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Boss should stay low when the only bench attacker body has one energy and cannot actually attack this turn (got %f)" % score)


func test_ultra_ball_does_not_discard_only_rebuild_attacker_body_for_backup_ralts() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var drifloon := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var poffin := CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)
	var s := _new_strategy()
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var bench_score: float = s.score_action_absolute_with_plan(
		{"kind": "play_basic_to_bench", "card": drifloon},
		gs,
		0,
		turn_contract
	)
	var bad_ultra_score: float = s.score_action_absolute_with_plan(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
			"targets": [{
				"discard_cards": [drifloon, poffin],
				"search_pokemon": [CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)],
			}],
		},
		gs,
		0,
		turn_contract
	)
	return assert_true(bench_score > bad_ultra_score,
		"Once the Gardevoir shell is online with no ready attacker, Ultra Ball should not discard the only rebuild attacker just to satisfy backup Ralts debt (bench=%f ultra=%f)" % [bench_score, bad_ultra_score])


func test_ultra_ball_discarding_rebuild_attacker_is_penalized_vs_filler_discard() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var drifloon := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var poffin := CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)
	var filler := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)
	var s := _new_strategy()
	var bad_score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
			"targets": [{
				"discard_cards": [drifloon, poffin],
				"search_pokemon": [CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)],
			}],
		},
		gs,
		0
	)
	var filler_score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
			"targets": [{
				"discard_cards": [filler, poffin],
				"search_pokemon": [CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)],
			}],
		},
		gs,
		0
	)
	return assert_true(bad_score < filler_score,
		"Discarding the only rebuild attacker should carry a route penalty compared with filler discard (bad=%f filler=%f)" % [bad_score, filler_score])


func test_psychic_embrace_cools_off_under_deck_out_pressure_when_ready_attacker_cannot_pivot() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	gardevoir.get_card_data().retreat_cost = 2
	player.active_pokemon = gardevoir
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(kirlia)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.bench.append(drifloon)
	player.deck.append(CardInstance.create(_make_trainer_cd("LastDeckCard"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic E", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(score <= 80.0,
		"Under deck-out pressure, extra Psychic Embrace should cool off when a ready attacker exists but the active Pokemon cannot pivot this turn (got %f)" % score)


func test_psychic_embrace_scores_explicit_target_instead_of_abstract_best_target() -> String:
	var gs := _make_game_state(18)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	player.active_pokemon = gardevoir
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(kirlia)
	var dead_scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	dead_scream_tail.damage_counters = 90
	player.bench.append(dead_scream_tail)
	var live_drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	live_drifloon.damage_counters = 20
	live_drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(live_drifloon)
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_trainer_cd("DeckOutLock%d" % i), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel A", "P"), 0))
	opponent.active_pokemon.pokemon_stack[0].card_data.hp = 120
	var s := _new_strategy()
	var dead_target_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir,
			"targets": [{"embrace_energy": [player.discard_pile[0]], "embrace_target": [dead_scream_tail]}],
		},
		gs,
		0
	)
	var live_target_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir,
			"targets": [{"embrace_energy": [player.discard_pile[0]], "embrace_target": [live_drifloon]}],
		},
		gs,
		0
	)
	return run_checks([
		assert_true(dead_target_score < 0.0,
			"Explicit Psychic Embrace actions targeting a dead attacker should be rejected instead of borrowing score from a better abstract target (got %f)" % dead_target_score),
		assert_true(live_target_score > dead_target_score,
			"A live attacker target should still score above a dead explicit Embrace target (live=%f dead=%f)" % [live_target_score, dead_target_score]),
	])


func test_rules_psychic_embrace_extends_charmed_drifloon_to_ko_threshold() -> String:
	var gs := _make_game_state(18)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	player.active_pokemon = gardevoir
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	for i: int in 3:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	drifloon.damage_counters = 60
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.bench.append(drifloon)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Raikou V", "Raikou V", 200), 1)
	var s := _new_strategy()
	var score_with_charm: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir,
			"targets": [{"embrace_energy": [player.discard_pile[0]], "embrace_target": [drifloon]}],
		},
		gs,
		0
	)
	var picked: Variant = s.pick_embrace_target([drifloon], gs, 0)
	drifloon.attached_tool = null
	var score_without_charm: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir,
			"targets": [{"embrace_energy": [player.discard_pile[0]], "embrace_target": [drifloon]}],
		},
		gs,
		0
	)
	return run_checks([
		assert_true(score_with_charm >= 600.0,
			"Charmed Drifloon at raw 10 HP should accept one more Psychic Embrace when it reaches a 200 HP KO (got %f)" % score_with_charm),
		assert_true(picked == drifloon,
			"Psychic Embrace target routing should keep a Bravery Charm Drifloon live instead of treating raw 10 HP as dead"),
		assert_true(score_without_charm < 0.0,
			"Without Bravery Charm, the same raw 10 HP Drifloon must not be over-Embraced (got %f)" % score_without_charm),
	])


func test_rules_psychic_embrace_keeps_scaling_charmed_drifloon_toward_bolt_ko() -> String:
	var gs := _make_game_state(18)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	player.active_pokemon = gardevoir
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	for i: int in 2:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	drifloon.damage_counters = 40
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.bench.append(drifloon)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240), 1)
	var s := _new_strategy()
	var embrace_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gardevoir,
			"targets": [{"embrace_energy": [player.discard_pile[0]], "embrace_target": [drifloon]}],
		},
		gs,
		0
	)
	return assert_true(embrace_score >= 500.0,
		"Charmed Drifloon should keep scaling from 120 toward the 240 Raging Bolt KO line instead of settling for a low-value hit (got %f)" % embrace_score)


func test_rules_bravery_charm_to_active_drifloon_outranks_non_ko_attack() -> String:
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	for i: int in 3:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	drifloon.damage_counters = 60
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240), 1)
	var s := _new_strategy()
	var charm_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0),
			"target_slot": drifloon,
		},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 180, "projected_knockout": false},
		gs,
		0
	)
	return run_checks([
		assert_true(charm_score >= 700.0,
			"Bravery Charm on the active Drifloon should be treated as route-critical before the final Embrace (got %f)" % charm_score),
		assert_true(charm_score > attack_score,
			"Drifloon should attach Bravery Charm before taking a non-KO 180 attack into a 240 HP active (charm=%f attack=%f)" % [charm_score, attack_score]),
	])


func test_arven_stays_live_to_fetch_bravery_for_active_drifloon_pressure() -> String:
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	for i: int in 3:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	drifloon.damage_counters = 60
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Raging Bolt ex", "Raging Bolt ex", 240), 1)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score >= 360.0,
		"Arven should stay live when it can fetch Bravery Charm for the active Drifloon KO route (got %f)" % score)


func test_rules_refinement_protects_bravery_charm_before_drifloon_conversion() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var expendable_supporter := CardInstance.create(_make_trainer_cd("Filler Supporter", "Supporter"), 0)
	player.hand.append(bravery)
	player.hand.append(expendable_supporter)
	player.hand.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var s := _new_strategy()
	var bravery_score: float = s.score_interaction_target(
		bravery,
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	var supporter_score: float = s.score_interaction_target(
		expendable_supporter,
		{"id": "discard_card"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(bravery_score < supporter_score,
		"Refinement should protect Bravery Charm once Kirlia can soon convert into a Drifloon attacker route (bravery=%f supporter=%f)" % [bravery_score, supporter_score])


func test_rules_refinement_does_not_spend_only_bravery_before_artazon_attacker_access() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var player := gs.players[0]
	player.deck.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.hand.append(bravery)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0))
	var s := _new_strategy()
	var refinement_score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[1],
			"targets": [{"discard_card": [bravery]}],
		},
		gs,
		0
	)
	var artazon_score: float = s.score_action_absolute(
		{
			"kind": "play_stadium",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0),
		},
		gs,
		0
	)
	return assert_true(artazon_score > refinement_score,
		"When Bravery Charm is the route piece and Artazon can still find Drifloon, play Artazon before Refinement can discard the charm (artazon=%f refinement=%f)" % [artazon_score, refinement_score])


func test_rules_artazon_effect_scores_as_attacker_access_when_online_shell_has_no_attacker() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var s := _new_strategy()
	var artazon_score: float = s.score_action_absolute(
		{
			"kind": "use_stadium_effect",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0),
			"targets": [{"artazon_pokemon": [CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)]}],
		},
		gs,
		0
	)
	return assert_true(artazon_score >= 500.0,
		"Artazon's effect should be scored as live attacker access once Gardevoir ex is online but no attacker body exists (got %f)" % artazon_score)


func test_rules_ultra_ball_does_not_discard_bravery_before_active_drifloon_conversion() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	opponent.active_pokemon = _make_slot(_make_named_pokemon("Miraidon ex", "Miraidon ex", 220), 1)
	opponent.active_pokemon.get_card_data().mechanic = "ex"
	var bravery := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	var munkidori_card := CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.hand.append(bravery)
	player.hand.append(munkidori_card)
	var s := _new_strategy()
	var charm_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": bravery,
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var ultra_score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
			"targets": [{"discard_cards": [munkidori_card, bravery], "search_pokemon": [CardInstance.create(_make_scream_tail_cd(), 0)]}],
		},
		gs,
		0
	)
	return assert_true(charm_score > ultra_score,
		"Active Drifloon conversion should attach Bravery Charm before Ultra Ball is allowed to discard it for a secondary attacker (charm=%f ultra=%f)" % [charm_score, ultra_score])


func test_rules_refinement_protects_recovery_cards_for_single_drifloon_loop() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	var stretcher := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)
	var rod := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)
	var expendable_supporter := CardInstance.create(_make_trainer_cd("Filler Supporter", "Supporter"), 0)
	player.hand.append(stretcher)
	player.hand.append(rod)
	player.hand.append(expendable_supporter)
	var s := _new_strategy()
	var stretcher_score: float = s.score_interaction_target(stretcher, {"id": "discard_card"}, {"game_state": gs, "player_index": 0})
	var rod_score: float = s.score_interaction_target(rod, {"id": "discard_card"}, {"game_state": gs, "player_index": 0})
	var supporter_score: float = s.score_interaction_target(expendable_supporter, {"id": "discard_card"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(stretcher_score < supporter_score,
			"Night Stretcher should be protected as the single-Drifloon loop recovery card (stretcher=%f supporter=%f)" % [stretcher_score, supporter_score]),
		assert_true(rod_score < supporter_score,
			"Super Rod should be protected as the single-Drifloon loop recovery card (rod=%f supporter=%f)" % [rod_score, supporter_score]),
	])


func test_rules_bravery_charm_can_preload_drifloon_during_near_online_shell() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.active_pokemon = kirlia
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	player.bench.append(drifloon)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	var s := _new_strategy()
	var charm_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0),
			"target_slot": drifloon,
		},
		gs,
		0
	)
	return assert_true(charm_score > 0.0,
		"Near an online shell, Bravery Charm should be allowed to preload Drifloon instead of being blocked by shell-lock scoring (got %f)" % charm_score)


func test_rules_retreat_does_not_hide_charmed_drifloon_behind_gardevoir_ex() -> String:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.active_pokemon = drifloon
	player.bench.clear()
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var flutter_mane := _make_slot(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)
	player.bench.append(gardevoir)
	player.bench.append(flutter_mane)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	var s := _new_strategy()
	var engine_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": gardevoir},
		gs,
		0
	)
	var single_prize_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": flutter_mane},
		gs,
		0
	)
	return run_checks([
		assert_true(engine_score < 0.0,
			"An in-progress Charmed Drifloon should not retreat behind Gardevoir ex and expose the two-prize engine (got %f)" % engine_score),
		assert_true(single_prize_score > engine_score,
			"If Drifloon must be benched for later Embrace scaling, a single-prize pivot should outrank Gardevoir ex (single=%f engine=%f)" % [single_prize_score, engine_score]),
	])


func test_rules_retreat_does_not_spend_charmed_drifloon_energy_to_unready_scream_tail() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.active_pokemon = drifloon
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(scream_tail)
	var s := _new_strategy()
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": scream_tail},
		gs,
		0
	)
	return assert_true(retreat_score < 0.0,
		"An in-progress Charmed Drifloon should not discard its Psychic Energy to retreat into an unready Scream Tail (got %f)" % retreat_score)


func test_arven_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are online, Arven should stop spending full supporter turns on setup cards (got %f)" % score)




func _make_radiant_greninja_cd() -> CardData:
	var cd := CardData.new()
	cd.name = DeckStrategyGardevoirScript.RADIANT_GRENINJA
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "W"
	cd.hp = 130
	cd.abilities = [
		{"name": "Concealed Cards", "effect_type": "Concealed Cards"},
	]
	return cd


func _build_shell_lock_with_greninja_and_search_state() -> GameState:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_radiant_greninja_cd(), 0)
	player.bench.clear()
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	return gs


func _build_shell_lock_with_empty_night_stretcher_state() -> GameState:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	player.bench.clear()
	return gs


func test_radiant_greninja_concealed_cards_waits_while_shell_lock_and_search_are_available() -> String:
	var gs := _build_shell_lock_with_greninja_and_search_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gs.players[0].active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"During shell lock, Radiant Greninja should wait if shell search is already available in hand instead of discarding early fuel for churn (got %f)" % score)


func test_night_stretcher_stays_negative_when_shell_lock_is_active_without_real_recovery_targets() -> String:
	var gs := _build_shell_lock_with_empty_night_stretcher_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0),
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Night Stretcher should stay negative during shell lock when discard does not contain a meaningful recovery target (got %f)" % score)


func test_artazon_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once the shell and a ready attacker are online, Artazon should shut off instead of padding the board (got %f)" % score)


func test_charizard_rebuild_lock_turns_munkidori_bench_and_dark_attach_negative() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var bench_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0), "target_slot": gs.players[0].active_pokemon},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_score < 0.0, "Into Charizard, Munkidori should stay off the bench once the stage2 shell and an attacker body are already online (got %f)" % bench_score),
		assert_true(attach_score < 0.0, "Into Charizard, manual Darkness attachment into Munkidori should stay negative unless it immediately converts a KO (got %f)" % attach_score),
	])


func test_charizard_rebuild_lock_turns_artazon_and_heavy_ball_negative() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var artazon_score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	var heavy_ball_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(artazon_score < 0.0, "Into Charizard, Artazon should cool off once the stage2 shell and an attacker body are already online (got %f)" % artazon_score),
		assert_true(heavy_ball_score < 0.0, "Into Charizard, Heavy Ball should also cool off in the same rebuild-lock window (got %f)" % heavy_ball_score),
	])


func test_charizard_rebuild_lock_cools_off_extra_ralts_search() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var ralts_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(ralts_score < drifloon_score,
		"Into Charizard, once the shell and an attacker body are online, extra Ralts search should cool off below attacker-line search (ralts=%f drifloon=%f)" % [ralts_score, drifloon_score])


func test_search_priority_prefers_scream_tail_into_weak_bench_targets() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When the opponent exposes weak bench targets, rebuilding Scream Tail should outrank Drifloon to pressure those prizes (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_search_priority_prefers_scream_tail_into_raging_bolt_bench_ex_targets() -> String:
	var gs := _build_online_shell_without_attacker_vs_raging_bench_ex_state()
	var s := _new_strategy()
	var preferred: String = s._preferred_transition_attacker_name(gs, 0)
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_eq(preferred, DeckStrategyGardevoirScript.SCREAM_TAIL, "A 210HP benched Raging Bolt support ex should make Scream Tail the preferred transition attacker"),
		assert_true(scream_tail_score > drifloon_score,
			"Search should treat Scream Tail as the visible two-prize bench route against Raging Bolt support ex (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score]),
	])


func test_scream_tail_attack_targets_raging_bolt_bench_ex_prize() -> String:
	var gs := _build_online_shell_without_attacker_vs_raging_bench_ex_state()
	var player := gs.players[0]
	var scream_tail_cd := _make_scream_tail_cd()
	scream_tail_cd.hp = 140
	var scream_tail := _make_slot(scream_tail_cd, 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	scream_tail.damage_counters = 110
	player.active_pokemon = scream_tail
	var opponent := gs.players[1]
	var s := _new_strategy()
	var active_score: float = s.score_interaction_target(opponent.active_pokemon, {"id": "target_pokemon"}, {"game_state": gs, "player_index": 0})
	var bench_score: float = s.score_interaction_target(opponent.bench[0], {"id": "target_pokemon"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(bench_score > active_score, "Scream Tail should aim the 220-damage line at the benched two-prize support ex over the non-KO active (bench=%f active=%f)" % [bench_score, active_score]),
		assert_true(bench_score >= 1500.0, "A visible Scream Tail bench ex KO should receive a decisive interaction score (got %f)" % bench_score),
	])


func test_embrace_prefers_scream_tail_when_extra_counter_unlocks_bench_prize() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.damage_counters = 20
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	drifloon.damage_counters = 20
	player.bench.append(scream_tail)
	player.bench.append(drifloon)
	var s := _new_strategy()
	var picked: Variant = s.pick_embrace_target([scream_tail, drifloon], gs, 0)
	return assert_true(picked == scream_tail,
		"When one extra Embrace lets Scream Tail pick off a weak bench target, it should outrank Drifloon as the embrace target")


func test_psychic_embrace_turns_negative_when_stage2_shell_is_online_but_no_attacker_body_exists() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.bench[0]},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once Gardevoir ex is online but no attacker body exists on board, Psychic Embrace should stay negative and let the turn rebuild a real attacker first (got %f)" % score)


func test_psychic_embrace_waits_for_attacker_body_even_when_kirlia_is_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	player.active_pokemon = gardevoir
	player.bench.clear()
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": gardevoir},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"With Gardevoir ex online but no Drifloon/Scream Tail body yet, Psychic Embrace should not preload Gardevoir ex just because Kirlia is missing (got %f)" % score)


func test_embrace_target_never_falls_back_to_dead_slot() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	var dead_ralts := _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	dead_ralts.damage_counters = 70
	player.bench.append(dead_ralts)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	var s := _new_strategy()
	var picked: Variant = s.pick_embrace_target([dead_ralts, player.bench[2]], gs, 0)
	return assert_true(picked == player.bench[2],
		"Psychic Embrace should never fall back to a dead shell slot when a live attacker body exists")


func test_bench_priority_prefers_scream_tail_even_with_ready_attacker_when_weak_bench_is_exposed() -> String:
	var gs := _build_online_shell_with_ready_drifloon_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_scream_tail_cd(), 0)},
		gs,
		0
	)
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When a ready attacker is already online but the opponent exposes weak bench prizes, adding Scream Tail should outrank another generic attacker body (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_search_priority_prefers_scream_tail_even_with_ready_attacker_when_weak_bench_is_exposed() -> String:
	var gs := _build_online_shell_with_ready_drifloon_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When a ready attacker is already online but the opponent exposes weak bench prizes, search should still prefer Scream Tail over another generic attacker body (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_boss_orders_stays_low_when_no_same_turn_gust_attack_exists_even_if_weak_bench_is_exposed() -> String:
	var gs := _build_unready_attack_shell_vs_weak_bench_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When no same-turn gust attack exists yet, Boss's Orders should stay low even if the opponent exposes a weak bench target (got %f)" % score)


func test_counter_catcher_stays_low_when_no_same_turn_gust_attack_exists_even_if_weak_bench_is_exposed() -> String:
	var gs := _build_unready_attack_shell_vs_weak_bench_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When no same-turn gust attack exists yet, Counter Catcher should stay low even if the opponent exposes a weak bench target (got %f)" % score)


func test_counter_catcher_waits_when_active_drifloon_pressure_attack_is_underpowered() -> String:
	var gs := _build_drifloon_pressure_needs_fuel_state()
	var s := _new_strategy()
	var catcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "attack", "projected_damage": 60},
		gs,
		0
	)
	return run_checks([
		assert_true(attack_score > 0.0,
			"The fixture should still have a same-turn Drifloon attack window (attack=%f)" % attack_score),
		assert_true(catcher_score < 0.0,
			"Counter Catcher should be held when Charmed Drifloon can only make a non-KO pressure attack and still needs fuel (catcher=%f)" % catcher_score),
	])


func test_manual_attach_psychic_bridges_benched_drifloon_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(drifloon)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic B", "P"), 0), "target_slot": drifloon},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score > 0.0, "Once the stage2 shell is online but no attacker is ready, manual attach should help bridge benched Drifloon (got %f)" % attach_score),
		assert_true(attach_score > end_turn_score, "Bridging benched Drifloon should outrank passing the turn (attach=%f end=%f)" % [attach_score, end_turn_score]),
	])


func test_manual_attach_psychic_bridges_drifloon_once_first_gardevoir_is_online_without_kirlia() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	player.bench.append(drifloon)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic A", "P"), 0), "target_slot": drifloon},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score > 0.0,
			"Once the first Gardevoir ex is online, Drifloon should accept manual Psychic even if Kirlia is temporarily missing (got %f)" % attach_score),
		assert_true(attach_score > end_turn_score,
			"Manual Psychic to Drifloon should outrank passing in the first-Gardevoir transition window (attach=%f end=%f)" % [attach_score, end_turn_score]),
	])


func test_manual_attach_psychic_starts_zero_energy_drifloon_close_loop_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	player.bench.append(drifloon)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic A", "P"), 0), "target_slot": drifloon},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score > 0.0,
			"Once Gardevoir ex is online, zero-energy Drifloon should still accept the first manual Psychic attach to start the Embrace close-loop (got %f)" % attach_score),
		assert_true(attach_score > end_turn_score,
			"Starting the zero-energy Drifloon close-loop should outrank passing (attach=%f end=%f)" % [attach_score, end_turn_score]),
	])


func test_manual_attach_dark_bridges_benched_scream_tail_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(scream_tail)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0), "target_slot": scream_tail},
		gs,
		0
	)
	return assert_true(attach_score >= 500.0,
		"When the stage2 shell is online and Scream Tail is one Dark Energy short of a bench prize line, manual Dark attach should become a real bridge action (got %f)" % attach_score)


func test_manual_attach_psychic_starts_benched_scream_tail_closed_loop_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	player.bench.append(scream_tail)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic A", "P"), 0), "target_slot": scream_tail},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score > 0.0,
			"Once the stage2 shell is online and Scream Tail has just been rebuilt, manual Psychic attach should start the Embrace close-loop instead of being dead tempo (got %f)" % attach_score),
		assert_true(attach_score > end_turn_score,
			"Starting the Scream Tail close-loop should outrank passing the turn (attach=%f end=%f)" % [attach_score, end_turn_score]),
	])


func test_handoff_prefers_scream_tail_owner_into_weak_bench_transition_shell() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var scream_send_out: float = s.score_handoff_target(scream_tail, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var kirlia_send_out: float = s.score_handoff_target(kirlia, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var munkidori_send_out: float = s.score_handoff_target(munkidori, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var scream_switch: float = s.score_handoff_target(scream_tail, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	var drifloon_switch: float = s.score_handoff_target(drifloon, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(scream_send_out > drifloon_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before Drifloon (scream=%f drifloon=%f)" % [scream_send_out, drifloon_send_out]),
		assert_true(scream_send_out > kirlia_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before shell pieces like Kirlia (scream=%f kirlia=%f)" % [scream_send_out, kirlia_send_out]),
		assert_true(scream_send_out > munkidori_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before Munkidori (scream=%f munkidori=%f)" % [scream_send_out, munkidori_send_out]),
		assert_true(scream_switch > drifloon_switch,
			"Switch-like handoffs should agree with send_out and keep attack ownership on Scream Tail in the weak-bench transition window (scream=%f drifloon=%f)" % [scream_switch, drifloon_switch]),
	])


func test_handoff_prefers_drifloon_owner_into_miraidon_pressure_even_with_bench_target() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var s := _new_strategy()
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var scream_send_out: float = s.score_handoff_target(scream_tail, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return assert_true(drifloon_send_out > scream_send_out,
		"Against Miraidon/Raikou pressure, Drifloon should own the transition even if Scream Tail sees a bench prize target (drifloon=%f scream=%f)" % [drifloon_send_out, scream_send_out])


func test_handoff_protects_gardevoir_ex_when_online_shell_has_no_attacker_body() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	player.bench.clear()
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var flutter_mane := _make_slot(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)
	player.bench.append(gardevoir)
	player.bench.append(flutter_mane)
	var s := _new_strategy()
	var gardevoir_score: float = s.score_handoff_target(gardevoir, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	var flutter_score: float = s.score_handoff_target(flutter_mane, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	return assert_true(flutter_score > gardevoir_score,
		"When the shell is online but no attacker body exists, Ralts-style switch handoff should protect Gardevoir ex behind a single-prize pivot (flutter=%f gardevoir=%f)" % [flutter_score, gardevoir_score])


func test_handoff_preserves_charmed_drifloon_on_bench_for_final_scaling() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	drifloon.damage_counters = 40
	for i: int in 2:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached %d" % i, "P"), 0))
	player.bench.append(drifloon)
	for i: int in 2:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Fuel %d" % i, "P"), 0))
	var s := _new_strategy()
	var ralts_slot: PokemonSlot = player.bench[2]
	var ralts_send_out: float = s.score_handoff_target(ralts_slot, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return assert_true(ralts_send_out > drifloon_send_out,
		"When Charmed Drifloon can still scale from the bench into a Miraidon KO, a spare Ralts should be sent out first (ralts=%f drifloon=%f)" % [ralts_send_out, drifloon_send_out])


func test_handoff_preserves_charmed_drifloon_when_fuel_route_needs_search() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var player := gs.players[0]
	player.bench.clear()
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Attached B", "P"), 0))
	player.bench.append(gardevoir)
	player.bench.append(kirlia)
	player.bench.append(drifloon)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0))
	var s := _new_strategy()
	var kirlia_send_out: float = s.score_handoff_target(kirlia, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var gardevoir_send_out: float = s.score_handoff_target(gardevoir, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(kirlia_send_out > drifloon_send_out,
			"When Charmed Drifloon still needs Earthen Vessel fuel, send_out should preserve it behind Kirlia instead of exposing the attacker (kirlia=%f drifloon=%f)" % [kirlia_send_out, drifloon_send_out]),
		assert_true(kirlia_send_out > gardevoir_send_out,
			"The same handoff should avoid feeding the two-prize Gardevoir ex while a single-prize shell body can buy the fuel turn (kirlia=%f gardevoir=%f)" % [kirlia_send_out, gardevoir_send_out]),
	])


func test_artazon_prefers_drifloon_into_miraidon_pressure_even_with_bench_target() -> String:
	var gs := _build_online_shell_without_attacker_vs_miraidon_pressure_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(drifloon_score > scream_tail_score,
		"Artazon should use the same fast-pressure transition owner as search and take Drifloon before Scream Tail (drifloon=%f scream=%f)" % [drifloon_score, scream_tail_score])


func test_artazon_keeps_scream_tail_window_into_charizard_weak_bench() -> String:
	var gs := _build_online_shell_without_attacker_vs_charizard_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(scream_tail_score > drifloon_score,
		"Into Charizard/Pidgeot, a live weak-bench route should still let Artazon take Scream Tail before Drifloon (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_handoff_prefers_drifloon_owner_when_no_weak_bench_window_exists() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var scream_send_out: float = s.score_handoff_target(scream_tail, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var munkidori_send_out: float = s.score_handoff_target(munkidori, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(drifloon_send_out > scream_send_out,
			"Without a weak-bench prize window, send_out should hand off to Drifloon before Scream Tail (drifloon=%f scream=%f)" % [drifloon_send_out, scream_send_out]),
		assert_true(drifloon_send_out > munkidori_send_out,
			"Without a weak-bench prize window, send_out should hand off to Drifloon before Munkidori (drifloon=%f munkidori=%f)" % [drifloon_send_out, munkidori_send_out]),
	])
