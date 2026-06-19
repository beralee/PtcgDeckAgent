## 沙奈朵卡组 AI 策略单元测试
class_name TestGardevoirStrategy
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const BUDEW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"
const CRESSELIA_EFFECT_ID := "5a56387211377cf56bfeb12751a5eed3"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


# -- 辅助函数 --

func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	return cd


func _make_budew_cd() -> CardData:
	var cd := _make_pokemon_cd("Budew", "Basic", "G", 30, "", "", [], [
		{"name": "Itchy Pollen", "cost": "0", "damage": "10"},
	])
	cd.effect_id = BUDEW_EFFECT_ID
	cd.retreat_cost = 0
	return cd


func _make_cresselia_cd() -> CardData:
	var cd := _make_pokemon_cd("Cresselia", "Basic", "P", 120, "", "", [], [
		{"name": "Moonglow Reverse", "cost": "P", "damage": ""},
		{"name": "Lunar Blast", "cost": "PPC", "damage": "110"},
	])
	cd.name_en = "Cresselia"
	cd.effect_id = CRESSELIA_EFFECT_ID
	cd.retreat_cost = 1
	return cd


func _make_deck_data(deck_id: int, entries: Array[Dictionary]) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	for entry: Dictionary in entries:
		deck.cards.append(entry.duplicate(true))
	return deck


func _make_tool_cd(pname: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Tool"
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


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
		p.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(p)
	return gs


func _ctx(gs: GameState, pi: int = 0) -> Dictionary:
	return {"game_state": gs, "player_index": pi}


func _card_display_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.effect_id) == BUDEW_EFFECT_ID:
		return "Budew"
	return str(card.card_data.name)


# ============================================================
#  开局规划测试
# ============================================================

func test_setup_prefers_ralts_over_random_basic() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Shinx", "Basic", "L"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	return assert_eq(int(choice.get("active_hand_index", -1)), 1, "拉鲁拉丝应被优先选为前场")


func test_setup_prefers_klefki_active_with_multiple_ralts() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("钥圈儿", "Basic", "Y"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(active_name, "钥圈儿", "有 2 只拉鲁拉丝时应选钥圈儿前场"),
		assert_true(bench_indices.size() >= 2, "后备区应至少有 2 张卡"),
	])


func test_setup_drifloon_active_with_single_ralts() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("飘飘球", "Basic", "P"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "飘飘球", "单拉鲁拉丝时应选飘飘球前场保护拉鲁拉丝")


func test_flutter_mane_preferred_active_in_opening() -> String:
	## 开局振翼发优先上前场
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("飘飘球", "Basic", "P"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "振翼发", "有振翼发时应优先上前场")


# ============================================================
#  动作评分测试
# ============================================================

func test_175_gardevoir_opening_prefers_budew_active_and_benches_ralts() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("鎷夐瞾鎷変笣"), 0))
	player.hand.append(CardInstance.create(_make_budew_cd(), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("鎸考鍙?", "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("鎰垮鐚?", "Basic", "D", 110), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	var bench_names: Array[String] = []
	for idx_variant: Variant in bench_indices:
		bench_names.append(_card_display_name(player.hand[int(idx_variant)]))
	return run_checks([
		assert_eq(_card_display_name(player.hand[active_idx]) if active_idx >= 0 else "", "Budew", "17.5 Gardevoir should open Budew active as the stall buffer"),
		assert_true("鎷夐瞾鎷変笣" in bench_names, "Budew active should preserve Ralts on the bench for setup"),
	])


func test_175_gardevoir_searches_ralts_before_budew_when_shell_missing() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(578647, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
	]))
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "P", 110), 0)
	player.bench.clear()
	var ralts := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	var budew := CardInstance.create(_make_budew_cd(), 0)
	var ralts_score: float = float(s.score_interaction_target(ralts, {"id": "search_pokemon"}, _ctx(gs, 0)))
	var budew_score: float = float(s.score_interaction_target(budew, {"id": "search_pokemon"}, _ctx(gs, 0)))
	return assert_true(
		ralts_score > budew_score,
		"17.5 shell-missing search should prioritize first Ralts over extra Budew stall (ralts=%f budew=%f)" % [ralts_score, budew_score]
	)


func test_175_gardevoir_handoff_uses_budew_buffer_before_shell_online() -> String:
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = null
	var budew := _make_slot(_make_budew_cd(), 0)
	var ralts := _make_slot(_make_pokemon_cd("鎷夐瞾鎷変笣", "Basic", "P", 70), 0)
	player.bench.append(budew)
	player.bench.append(ralts)
	var s := _new_strategy()
	var context := {"game_state": gs, "player_index": 0}
	var budew_score: float = float(s.score_handoff_target(budew, {"id": "send_out"}, context))
	var ralts_score: float = float(s.score_handoff_target(ralts, {"id": "send_out"}, context))
	return assert_true(budew_score > ralts_score + 150.0, "Before the Gardevoir shell is online, send-out should use Budew to protect Ralts")


func test_175_gardevoir_handoff_uses_scream_tail_after_budew_before_shell_online() -> String:
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = null
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	var ralts := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(scream_tail)
	player.bench.append(ralts)
	player.bench.append(kirlia)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var context := {"game_state": gs, "player_index": 0}
	var scream_score: float = float(s.score_handoff_target(scream_tail, {"id": "send_out"}, context))
	var ralts_score: float = float(s.score_handoff_target(ralts, {"id": "send_out"}, context))
	var kirlia_score: float = float(s.score_handoff_target(kirlia, {"id": "send_out"}, context))
	return assert_true(
		scream_score > ralts_score and scream_score > kirlia_score,
		"After Budew is gone but before the shell is online, send-out should use Scream Tail to protect Ralts/Kirlia (scream=%f ralts=%f kirlia=%f)" % [scream_score, ralts_score, kirlia_score]
	)


func test_175_gardevoir_ai_picker_sends_out_scream_tail_over_kirlia_before_shell_online() -> String:
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = null
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	var ralts := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(scream_tail)
	player.bench.append(ralts)
	player.bench.append(kirlia)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	ai.set_deck_strategy(s)
	var picked: PokemonSlot = ai.call("_pick_best_handoff_target", player.bench, gsm, "send_out")
	return assert_eq(picked, scream_tail,
		"AIOpponent send_out should use Scream Tail as the buffer before the first Gardevoir ex is online, preserving Kirlia")


func test_175_gardevoir_budew_item_lock_attack_scores_as_stall_action() -> String:
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("鎷夐瞾鎷変笣", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("鎷夐瞾鎷変笣", "Basic", "P", 70), 0))
	var s := _new_strategy()
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(attack_score >= 620.0, "Budew item-lock attack should be a high-value stall action while Gardevoir develops")


func test_175_gardevoir_launch_budew_plays_safe_shell_search_before_stall_attack() -> String:
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var arven := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)
	var poffin := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)
	var ralts := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	player.hand.append(arven)
	player.hand.append(poffin)
	player.hand.append(ralts)
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	player.deck.append(CardInstance.create(_make_tool_cd(DeckStrategyGardevoirScript.TM_EVOLUTION), 0))
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Dummy Psychic %d" % i, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var has_launch_bonus := false
	for bonus_variant: Variant in continuity.get("action_bonuses", []):
		if not (bonus_variant is Dictionary):
			continue
		var bonus: Dictionary = bonus_variant
		if str(bonus.get("reason", "")) == "continuity_launch_shell_before_budew_stall":
			has_launch_bonus = true
	var attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	var arven_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": arven,
		"targets": [],
	}, gs, 0, turn_contract))
	var poffin_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": poffin,
		"targets": [],
	}, gs, 0, turn_contract))
	var ralts_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_basic_to_bench",
		"card": ralts,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_true(bool(setup_debt.get("need_launch_shell_before_stall", false)),
			"Budew launch turns should expose exact shell setup debt before the stall attack"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)),
			"Budew launch stall attacks must be terminal after safe shell setup debt"),
		assert_true(has_launch_bonus,
			"Safe launch setup should be represented as a continuity action bonus"),
		assert_true(arven_score > attack_score,
			"Arven should happen before Budew's terminal launch stall attack (arven=%f attack=%f)" % [arven_score, attack_score]),
		assert_true(poffin_score > attack_score,
			"Buddy-Buddy Poffin should happen before Budew's terminal launch stall attack (poffin=%f attack=%f)" % [poffin_score, attack_score]),
		assert_true(ralts_score > attack_score,
			"Direct Ralts benching should happen before Budew's terminal launch stall attack (ralts=%f attack=%f)" % [ralts_score, attack_score]),
	])


func test_175_gardevoir_launch_budew_arven_uses_deck_name_en_before_stall_attack() -> String:
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var arven := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)
	player.hand.append(arven)
	var kirlia_cd := _make_pokemon_cd("deck-local-kirlia", "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS)
	kirlia_cd.name_en = "Kirlia"
	var ultra_ball_cd := _make_trainer_cd("deck-local-ultra-ball")
	ultra_ball_cd.name_en = "Ultra Ball"
	player.deck.append(CardInstance.create(kirlia_cd, 0))
	player.deck.append(CardInstance.create(ultra_ball_cd, 0))
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Dummy Psychic %d" % i, "P"), 0))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var arven_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": arven,
		"targets": [],
	}, gs, 0, turn_contract))
	var attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_true(bool(setup_debt.get("need_launch_shell_before_stall", false)),
			"Budew launch continuity should see deck Kirlia through name_en aliases"),
		assert_true(arven_score > attack_score,
			"Arven should search before Budew attacks even when the live deck targets only match by name_en (arven=%f attack=%f)" % [arven_score, attack_score]),
	])


func test_175_gardevoir_active_ralts_uses_arven_before_chip_attack_when_kirlia_search_live() -> String:
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var active_ralts_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70, "", "", [], [
		{"name": "Memory Skip", "cost": "P", "damage": "10"},
	])
	player.active_pokemon = _make_slot(active_ralts_cd, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Active Psychic", "P"), 0))
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var arven := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)
	player.hand.append(arven)
	var kirlia_cd := _make_pokemon_cd("deck-local-kirlia", "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS)
	kirlia_cd.name_en = "Kirlia"
	var ultra_ball_cd := _make_trainer_cd("deck-local-ultra-ball")
	ultra_ball_cd.name_en = "Ultra Ball"
	var tm_evolution_cd := _make_tool_cd("deck-local-tm-evolution")
	tm_evolution_cd.name_en = "Technical Machine: Evolution"
	player.deck.append(CardInstance.create(kirlia_cd, 0))
	player.deck.append(CardInstance.create(ultra_ball_cd, 0))
	player.deck.append(CardInstance.create(tm_evolution_cd, 0))
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Dummy Psychic %d" % i, "P"), 0))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var arven_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": arven,
		"targets": [],
	}, gs, 0, turn_contract))
	var attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Memory Skip",
		"projected_damage": 10,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_true(bool(setup_debt.get("need_kirlia_engine", false)),
			"Active Ralts chip turns should expose Kirlia engine setup debt"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)),
			"Ralts chip attack should remain terminal while safe Kirlia search is available"),
		assert_true(arven_score > attack_score,
			"Arven should search Kirlia access before active Ralts uses a 10-damage attack (arven=%f attack=%f)" % [arven_score, attack_score]),
	])


func test_175_gardevoir_budew_stall_remains_terminal_after_launch_debt_clears() -> String:
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, turn_contract))
	return run_checks([
		assert_false(bool(continuity.get("enabled", false)),
			"Budew continuity must clear once no legal safe launch setup action remains"),
		assert_true(attack_score > end_score,
			"After launch setup debt clears, Budew should remain the terminal stall action (attack=%f end=%f)" % [attack_score, end_score]),
	])


func test_175_gardevoir_budew_yields_to_bench_evolution_window() -> String:
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝", "Basic", "P", 70), 0))
	var s := _new_strategy()
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))
	var evolve_score: float = float(s.score_action_absolute({
		"kind": "evolve",
		"card": CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0),
		"target_slot": player.bench[0],
	}, gs, 0))
	return assert_true(attack_score < evolve_score,
		"Budew should be the stall finisher after development actions, not block available Kirlia evolution (attack=%f evolve=%f)" % [attack_score, evolve_score])


func test_175_gardevoir_late_budew_yields_to_visible_kirlia_development() -> String:
	var gs := _make_game_state(34)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var ralts := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	player.bench.append(ralts)
	var kirlia_card := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.hand.append(kirlia_card)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))
	var evolve_score: float = float(s.score_action_absolute({
		"kind": "evolve",
		"card": kirlia_card,
		"target_slot": ralts,
	}, gs, 0))
	return assert_true(evolve_score > attack_score,
		"Late Budew item-lock should not end the turn before visible Kirlia development (evolve=%f attack=%f)" % [evolve_score, attack_score])


func test_175_gardevoir_late_budew_yields_to_visible_munkidori_development() -> String:
	var gs := _make_game_state(34)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var munkidori_card := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.hand.append(munkidori_card)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
	}, gs, 0))
	var bench_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": munkidori_card,
	}, gs, 0))
	return assert_true(bench_score > attack_score,
		"Late Budew item-lock should leave room for visible Munkidori setup before ending the turn (bench=%f attack=%f)" % [bench_score, attack_score])


func test_175_gardevoir_budew_rebuild_plays_safe_stadium_before_stall_attack() -> String:
	var gs := _make_game_state(15)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var artazon := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)
	player.hand.append(artazon)
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0))
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_energy_cd("Dummy Psychic %d" % i, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var has_stadium_bonus := false
	for bonus_variant: Variant in continuity.get("action_bonuses", []):
		if not (bonus_variant is Dictionary):
			continue
		var bonus: Dictionary = bonus_variant
		if str(bonus.get("kind", "")) == "play_stadium" and str(bonus.get("reason", "")) == "continuity_stadium_search_next_attacker":
			has_stadium_bonus = true
	var stadium_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_stadium",
		"card": artazon,
		"targets": [],
	}, gs, 0, turn_contract))
	var budew_attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Itchy Pollen",
		"projected_damage": 10,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_eq(str(turn_contract.get("intent", "")), "rebuild_attacker",
			"Budew active with online Gardevoir but no attacker should stay in rebuild intent"),
		assert_true(bool(setup_debt.get("need_next_attacker_seed", false)),
			"Continuity debt should name the missing next attacker before a support stall attack"),
		assert_true(bool(setup_debt.get("need_stall_safe_attacker_search", false)),
			"Budew stall windows should expose exact safe Stadium search debt instead of relying on raw scores"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)),
			"Budew stall attacks must be terminal after exact safe setup debt"),
		assert_true(has_stadium_bonus,
			"Artazon/Stadium search for the next attacker should be an explicit continuity action bonus"),
		assert_true(stadium_score > budew_attack_score,
			"Safe Stadium setup should happen before Budew's terminal stall attack (stadium=%f attack=%f)" % [stadium_score, budew_attack_score]),
	])


func test_175_gardevoir_ready_scream_tail_handoff_outscores_budew_attack() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	gs.players[1].active_pokemon.damage_counters = 150
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(retreat_score > attack_score,
		"Once Scream Tail is ready, 17.5 Gardevoir should hand off from Budew instead of continuing item-lock attacks (retreat=%f attack=%f)" % [retreat_score, attack_score])


func test_175_gardevoir_scream_tail_attack_targets_visible_bench_prize() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var opponent: PlayerState = gs.players[1]
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var mew := _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180, "", "ex"), 1)
	mew.damage_counters = 120
	opponent.active_pokemon = iron_hands
	opponent.bench.append(mew)
	var s := _new_strategy()
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": scream_tail,
		"attack_index": 1,
		"attack_name": "Roaring Scream",
		"projected_damage": 0,
		"requires_interaction": true,
	}, gs, 0))
	var active_score: float = float(s.score_interaction_target(iron_hands, {"id": "target_pokemon"}, _ctx(gs, 0)))
	var bench_score: float = float(s.score_interaction_target(mew, {"id": "target_pokemon"}, _ctx(gs, 0)))
	return run_checks([
		assert_true(attack_score >= 1000.0, "Scream Tail Roaring Scream should be scored by self-damage KO value, not zero preview damage (score=%f)" % attack_score),
		assert_true(bench_score > active_score, "Scream Tail should target the visible low-HP bench prize over non-KO active pressure (bench=%f active=%f)" % [bench_score, active_score]),
	])


func test_175_gardevoir_turo_unlocks_boss_trapped_active_for_scream_tail_bench_prize() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	var backup_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0),
	]
	player.bench.append(backup_gardevoir)
	player.bench.append(kirlia)
	player.bench.append(scream_tail)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var pidgey_cd := _make_pokemon_cd("Pidgey", "Basic", "C", 60)
	pidgey_cd.name_en = "Pidgey"
	opponent.bench.append(_make_slot(pidgey_cd, 1))
	var turo := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)
	player.hand.append(turo)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	var context := {"game_state": gs, "player_index": 0, "turn_contract": contract}
	var turo_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": turo,
	}, gs, 0, contract))
	var active_target_score: float = float(s.score_interaction_target(active_gardevoir, {"id": "prof_turo_target"}, context))
	var backup_target_score: float = float(s.score_interaction_target(backup_gardevoir, {"id": "prof_turo_target"}, context))
	var replacement_score: float = float(s.score_interaction_target(scream_tail, {"id": "prof_turo_replacement"}, context))
	var engine_replacement_score: float = float(s.score_interaction_target(backup_gardevoir, {"id": "prof_turo_replacement"}, context))
	return run_checks([
		assert_true(bool(contract.get("flags", {}).get("trapped_active_with_ready_bench_attacker", false)),
			"Turn contract should explicitly mark the trapped-active ready-bench-attacker unlock route"),
		assert_eq(str(contract.get("owner", {}).get("pivot_target_name", "")), DeckStrategyGardevoirScript.SCREAM_TAIL,
			"The same contract should keep Scream Tail as the handoff owner"),
		assert_true(turo_score >= 600.0,
			"Professor Turo should be the high-priority bridge when Boss traps active Gardevoir and Scream Tail can take a bench prize (got %f)" % turo_score),
		assert_true(active_target_score > backup_target_score,
			"Turo target selection should pick the trapped active Gardevoir, not the backup engine (active=%f backup=%f)" % [active_target_score, backup_target_score]),
		assert_true(replacement_score > engine_replacement_score,
			"Turo replacement should hand off to ready Scream Tail instead of exposing backup Gardevoir (scream=%f gardevoir=%f)" % [replacement_score, engine_replacement_score]),
	])


func test_175_gardevoir_manual_energy_unlocks_active_retreat_bridge_for_ready_scream_tail() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	active_gardevoir.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.bench.append(kirlia)
	player.bench.append(scream_tail)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var mareep := _make_slot(_make_pokemon_cd("Mareep", "Basic", "L", 60), 1)
	opponent.bench.append(mareep)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var psychic := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0)
	player.hand.append(psychic)
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = contract.get("constraints", {}) if contract.get("constraints", {}) is Dictionary else {}
	var attach_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attach_energy",
		"card": psychic,
		"target_slot": active_gardevoir,
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("active_retreat_bridge_to_ready_bench_attacker", false)),
			"Turn contract should mark the manual retreat-payment bridge when active Gardevoir blocks a ready Scream Tail"),
		assert_true(bool(constraints.get("must_unlock_ready_bench_attacker", false)),
			"The same route should force an unlock step before passing"),
		assert_true(attach_score >= 360.0,
			"Manual Energy to active Gardevoir should be a real bridge payment toward the ready Scream Tail handoff (attach=%f)" % attach_score),
		assert_true(attach_score > end_score + 250.0,
			"Retreat bridge payment should beat passing when a ready Scream Tail is stranded behind active Gardevoir (attach=%f end=%f)" % [attach_score, end_score]),
	])


func test_175_gardevoir_paid_retreat_marks_ready_bench_handoff_contract() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	active_gardevoir.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.bench.append(scream_tail)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Mareep", "Basic", "L", 60), 1))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = contract.get("constraints", {}) if contract.get("constraints", {}) is Dictionary else {}
	var owner: Dictionary = contract.get("owner", {}) if contract.get("owner", {}) is Dictionary else {}
	var retreat_score: float = float(s.score_action_absolute_with_plan({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("active_retreat_bridge_to_ready_bench_attacker", false)),
			"Already-paid active retreat should still mark the ready-bench handoff contract"),
		assert_true(bool(constraints.get("must_unlock_ready_bench_attacker", false)),
			"Already-paid active retreat should force the handoff before passing"),
		assert_eq(str(owner.get("pivot_target_name", "")), DeckStrategyGardevoirScript.SCREAM_TAIL,
			"Ready Scream Tail should own the paid-retreat pivot route"),
		assert_true(retreat_score > end_score + 250.0,
			"Paid retreat into ready Scream Tail should beat passing (retreat=%f end=%f)" % [retreat_score, end_score]),
	])


func test_175_gardevoir_earthen_vessel_search_unlocks_active_retreat_bridge_for_ready_scream_tail() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	active_gardevoir.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.bench.append(scream_tail)
	var vessel := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)
	player.hand.append(vessel)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Mareep", "Basic", "L", 60), 1))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = contract.get("constraints", {}) if contract.get("constraints", {}) is Dictionary else {}
	var owner: Dictionary = contract.get("owner", {}) if contract.get("owner", {}) is Dictionary else {}
	var vessel_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": vessel,
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("active_retreat_energy_search_bridge_to_ready_bench_attacker", false)),
			"Earthen Vessel should mark a search-payment bridge when a ready Scream Tail is stranded behind an active one-Energy retreat gap"),
		assert_true(bool(constraints.get("must_unlock_ready_bench_attacker", false)),
			"Earthen Vessel search-payment bridge should force an unlock step before passing"),
		assert_eq(str(owner.get("pivot_target_name", "")), DeckStrategyGardevoirScript.SCREAM_TAIL,
			"Ready Scream Tail should own the Vessel search-payment pivot route"),
		assert_true(vessel_score > end_score + 250.0,
			"Earthen Vessel should beat passing when it finds the missing retreat payment for a ready Scream Tail handoff (vessel=%f end=%f)" % [vessel_score, end_score]),
	])


func test_175_gardevoir_pick_embrace_pays_active_retreat_before_overcharging_ready_scream_tail() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	active_gardevoir.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Mareep", "Basic", "L", 60), 1))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var picked: Variant = s.pick_embrace_target([scream_tail, active_gardevoir], gs, 0)
	return assert_true(picked == active_gardevoir,
		"Psychic Embrace target picker should pay active retreat before overcharging an already-ready Scream Tail handoff")


func test_175_gardevoir_does_not_mark_unpayable_retreat_bridge_as_ready() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.get_card_data().retreat_cost = 2
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.bench.append(scream_tail)
	player.hand.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Mareep", "Basic", "L", 60), 1))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var constraints: Dictionary = contract.get("constraints", {}) if contract.get("constraints", {}) is Dictionary else {}
	var attach_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attach_energy",
		"card": player.hand[0],
		"target_slot": active_gardevoir,
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_false(bool(flags.get("active_retreat_bridge_to_ready_bench_attacker", false)),
			"Turn contract must not claim a ready-bench handoff when one manual Energy cannot fully pay active Gardevoir's retreat"),
		assert_false(bool(constraints.get("must_unlock_ready_bench_attacker", false)),
			"Unpayable retreat bridges should not force an unlock route that can only pass after attaching"),
		assert_true(attach_score <= end_score + 250.0,
			"Partial retreat payments should not be scored as a real handoff unlock (attach=%f end=%f)" % [attach_score, end_score]),
	])


func test_175_gardevoir_delays_low_pressure_scream_tail_handoff_without_prize_target() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 20
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(retreat_score < attack_score,
		"17.5 Gardevoir should keep Budew active when Scream Tail is ready but only creates low pressure and has no immediate prize target (retreat=%f attack=%f)" % [retreat_score, attack_score])


func test_175_gardevoir_hands_off_scream_tail_early_into_miraidon_pressure() -> String:
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(retreat_score > attack_score,
		"Against Miraidon pressure, 17.5 Gardevoir should hand off to an 80-damage Scream Tail before the late stall window (retreat=%f attack=%f)" % [retreat_score, attack_score])


func test_175_gardevoir_hands_off_to_pressure_scream_tail_after_stall_window() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(retreat_score > attack_score,
		"After the Budew stall window, a ready Scream Tail dealing real two-hit pressure should take over even without an immediate KO (retreat=%f attack=%f)" % [retreat_score, attack_score])


func test_175_gardevoir_benches_munkidori_before_nonlethal_scream_tail_handoff() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var munkidori_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var munkidori_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(munkidori_cd, 0),
	}, gs, 0))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	return assert_true(
		munkidori_score > retreat_score,
		"Before a nonlethal Scream Tail handoff, 17.5 Gardevoir should use the last bench slot for Munkidori support (munkidori=%f retreat=%f)" % [munkidori_score, retreat_score]
	)


func test_175_gardevoir_conversion_window_disables_backup_ralts_continuity_bonus() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = s._gardevoir_continuity_setup_debt(gs, player, 0)
	var action_bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var forced_bonuses: Array = s._gardevoir_continuity_action_bonuses({
		"has_attack_window": true,
		"need_backup_ralts_or_kirlia": true,
		"ready_attackers": 1,
	}, player, gs, 0)
	var has_ralts_seed_bonus := false
	for bonus_variant: Variant in action_bonuses:
		if not (bonus_variant is Dictionary):
			continue
		var bonus: Dictionary = bonus_variant
		if str(bonus.get("kind", "")) != "play_basic_to_bench":
			continue
		if str(bonus.get("reason", "")) == "continuity_seed_backup_ralts":
			has_ralts_seed_bonus = true
	var forced_has_ralts_seed_bonus := false
	for bonus_variant: Variant in forced_bonuses:
		if not (bonus_variant is Dictionary):
			continue
		var bonus: Dictionary = bonus_variant
		if str(bonus.get("kind", "")) != "play_basic_to_bench":
			continue
		if str(bonus.get("reason", "")) == "continuity_seed_backup_ralts":
			forced_has_ralts_seed_bonus = true
	return run_checks([
		assert_eq(str(turn_contract.get("intent", "")), "convert_attack", "Ready Scream Tail behind Budew should put 17.5 Gardevoir into conversion intent"),
		assert_false(bool(setup_debt.get("need_backup_ralts_or_kirlia", false)), "Immediate conversion should close backup Ralts setup debt before continuity bonuses are built"),
		assert_false(has_ralts_seed_bonus, "Conversion window must not add backup Ralts continuity before handing off to the ready Scream Tail"),
		assert_false(forced_has_ralts_seed_bonus, "Continuity action bonuses must ignore backup Ralts debt when a ready attacker already has an attack window"),
	])


func test_175_gardevoir_active_scream_tail_conversion_does_not_reopen_backup_ralts_debt() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.active_pokemon = scream_tail
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var setup_debt: Dictionary = s._gardevoir_continuity_setup_debt(gs, player, 0)
	var forced_bonuses: Array = s._gardevoir_continuity_action_bonuses({
		"has_attack_window": true,
		"need_backup_ralts_or_kirlia": true,
		"ready_attackers": 1,
	}, player, gs, 0)
	var forced_has_ralts_seed_bonus := false
	for bonus_variant: Variant in forced_bonuses:
		if not (bonus_variant is Dictionary):
			continue
		var bonus: Dictionary = bonus_variant
		if str(bonus.get("kind", "")) == "play_basic_to_bench" \
				and str(bonus.get("reason", "")) == "continuity_seed_backup_ralts":
			forced_has_ralts_seed_bonus = true
	return run_checks([
		assert_false(bool(setup_debt.get("need_backup_ralts_or_kirlia", false)),
			"17.5 Scream Tail conversion should not reopen backup Ralts continuity debt after the attacker is already active"),
		assert_false(forced_has_ralts_seed_bonus,
			"17.5 Scream Tail conversion should not receive forced backup Ralts continuity bonuses"),
	])


func test_175_gardevoir_active_tm_does_not_block_ready_scream_tail_handoff() -> String:
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var active_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	active_gardevoir.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	player.active_pokemon = active_gardevoir
	player.bench.clear()
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": scream_tail,
	}, gs, 0))
	return assert_true(retreat_score > 300.0,
		"Once 17.5 Gardevoir has a ready Scream Tail, an active TM Evolution carrier should still hand off (retreat=%f)" % retreat_score)


func test_175_gardevoir_without_drifloon_package_prefers_scream_tail_transition() -> String:
	var gs := _make_game_state(8)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "拉鲁拉丝", "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": "奇鲁莉安", "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": "沙奈朵ex", "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": "吼叫尾", "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "含羞苞", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var preferred: String = s._preferred_transition_attacker_name(gs, 0)
	return assert_eq(preferred, DeckStrategyGardevoirScript.SCREAM_TAIL,
		"17.5 Gardevoir has no Drifloon/Bravery Charm package, so transition pressure should route through Scream Tail")


func test_175_gardevoir_online_shell_benches_scream_tail_before_low_damage_attack() -> String:
	var gs := _make_game_state(14)
	var player: PlayerState = gs.players[0]
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	player.active_pokemon = _make_slot(_make_pokemon_cd("玛纳霏", "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var scream_tail_cd := _make_pokemon_cd("吼叫尾", "Basic", "P", 90, "", "", [], [
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	])
	player.hand.append(CardInstance.create(scream_tail_cd, 0))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "吼叫尾", "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "含羞苞", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var bench_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(scream_tail_cd, 0),
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 140,
	}, gs, 0))
	return assert_true(bench_score > attack_score,
		"After the shell is online, 17.5 Gardevoir should bench Scream Tail before taking low-damage non-attacker attacks (bench=%f attack=%f)" % [bench_score, attack_score])


func test_175_gardevoir_scream_tail_zero_damage_attack_does_not_use_generic_prediction() -> String:
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var scream_tail_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Tiny Cry", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	])
	player.active_pokemon = _make_slot(scream_tail_cd, 0)
	player.active_pokemon.damage_counters = 40
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
	]))
	var zero_damage_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"attack_index": 1,
		"projected_damage": 0,
	}, gs, 0))
	var chip_attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"projected_damage": 30,
	}, gs, 0))
	return assert_true(chip_attack_score > zero_damage_score,
		"An explicit 0-damage Scream Tail attack must not borrow generic predicted damage and outrank a real chip attack (chip=%f zero=%f)" % [chip_attack_score, zero_damage_score])


func test_175_gardevoir_active_scream_tail_embrace_outscores_low_damage_slap() -> String:
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 20
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.active_pokemon = scream_tail
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	player.bench.append(gardevoir)
	player.discard_pile.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
	]))
	var embrace_score: float = float(s.score_action_absolute({
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
		"targets": [{
			"embrace_energy": [player.discard_pile[0]],
			"embrace_target": [scream_tail],
		}],
	}, gs, 0))
	var slap_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"projected_damage": 30,
	}, gs, 0))
	return assert_true(embrace_score > slap_score,
		"Active Scream Tail should keep using Psychic Embrace before settling for low-damage Slap (embrace=%f slap=%f)" % [embrace_score, slap_score])


func test_175_gardevoir_active_scream_tail_continuity_embraces_before_nonlethal_roaring_scream_under_deck_out_pressure() -> String:
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 20
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	player.active_pokemon = scream_tail
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex", [
		{"name": "Psychic Embrace"},
	]), 0)
	player.bench.append(gardevoir)
	player.discard_pile.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	for i: int in 5:
		player.deck.append(CardInstance.create(_make_energy_cd("Low Deck Psychic %d" % i, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var has_active_scream_tail_embrace_bonus := false
	for bonus_variant: Variant in continuity.get("action_bonuses", []):
		if bonus_variant is Dictionary and str((bonus_variant as Dictionary).get("reason", "")) == "continuity_active_scream_tail_embrace_damage":
			has_active_scream_tail_embrace_bonus = true
	var embrace_score: float = float(s.score_action_absolute_with_plan({
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
	}, gs, 0, turn_contract))
	var attack_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": scream_tail,
		"attack_index": 1,
		"attack_name": "Roaring Scream",
		"projected_damage": 40,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_true(bool(setup_debt.get("avoid_deck_out", false)),
			"This regression should preserve the low-deck trace condition"),
		assert_true(bool(setup_debt.get("need_active_scream_tail_embrace_damage", false)),
			"Active nonlethal Scream Tail should expose a Psychic Embrace damage debt before attacking"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)),
			"Psychic Embrace is a safe non-draw setup step even under deck-out pressure"),
		assert_true(has_active_scream_tail_embrace_bonus,
			"The continuity contract should name the exact Gardevoir ex ability bonus"),
		assert_true(embrace_score > attack_score,
			"Psychic Embrace should happen before nonlethal Roaring Scream under deck-out pressure (embrace=%f attack=%f)" % [embrace_score, attack_score]),
	])


func test_175_gardevoir_active_scream_tail_continuity_embraces_before_low_damage_slap_under_deck_out_pressure() -> String:
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	player.active_pokemon = scream_tail
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex", [
		{"name": "Psychic Embrace"},
	]), 0)
	player.bench.append(gardevoir)
	player.discard_pile.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	for i: int in 5:
		player.deck.append(CardInstance.create(_make_energy_cd("Low Deck Psychic %d" % i, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
	]))
	var turn_contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var has_active_scream_tail_embrace_bonus := false
	for bonus_variant: Variant in continuity.get("action_bonuses", []):
		if bonus_variant is Dictionary and str((bonus_variant as Dictionary).get("reason", "")) == "continuity_active_scream_tail_embrace_damage":
			has_active_scream_tail_embrace_bonus = true
	var embrace_score: float = float(s.score_action_absolute_with_plan({
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
	}, gs, 0, turn_contract))
	var slap_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": scream_tail,
		"attack_index": 0,
		"attack_name": "Slap",
		"projected_damage": 30,
		"projected_knockout": false,
	}, gs, 0, turn_contract))
	return run_checks([
		assert_true(bool(setup_debt.get("avoid_deck_out", false)),
			"This regression should keep the low-deck pressure from the seed5044 trace"),
		assert_true(bool(setup_debt.get("need_active_scream_tail_embrace_damage", false)),
			"Zero-counter Scream Tail should still expose a safe Embrace debt before settling for Slap"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)),
			"Low-deck Scream Tail Slap should still enable the non-draw continuity window"),
		assert_true(has_active_scream_tail_embrace_bonus,
			"The continuity contract should include the exact Gardevoir ex ability bonus for the low-damage Slap trace"),
		assert_true(embrace_score > slap_score,
			"Psychic Embrace should open Roaring Scream pressure before low-damage Slap under deck-out pressure (embrace=%f slap=%f)" % [embrace_score, slap_score]),
	])


func test_175_gardevoir_scream_tail_prediction_requires_roaring_scream_cost() -> String:
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 20
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var s := _new_strategy()
	var now: Dictionary = s.predict_attacker_damage(scream_tail, 0)
	var after: Dictionary = s.predict_attacker_damage(scream_tail, 1)
	return run_checks([
		assert_false(bool(now.get("can_attack", false)),
			"One Energy only pays Scream Tail's Slap; Roaring Scream pressure should not be treated as attack-ready"),
		assert_true(bool(after.get("can_attack", false)),
			"One extra Psychic Embrace should pay Roaring Scream and make the pressure route live"),
	])


func test_175_gardevoir_cresselia_attack_scores_counter_conversion_ko() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "Cresselia", "name_en": "Cresselia", "card_type": "Pokemon", "effect_id": CRESSELIA_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	var cresselia := _make_slot(_make_cresselia_cd(), 0)
	cresselia.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.active_pokemon = cresselia
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	gardevoir.damage_counters = 20
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	kirlia.damage_counters = 20
	player.bench.clear()
	player.bench.append(gardevoir)
	player.bench.append(kirlia)
	var opponent_active := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent_active.damage_counters = 200
	gs.players[1].active_pokemon = opponent_active
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"projected_damage": 0,
	}, gs, 0))
	var low_attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"attack_index": 1,
		"projected_damage": 110,
	}, gs, 0))
	return assert_true(attack_score > low_attack_score,
		"Cresselia should prioritize Moonglow Reverse when the damage-counter pool converts a prize (moon=%f low=%f)" % [attack_score, low_attack_score])


func test_175_gardevoir_hands_off_budew_to_ready_cresselia_prize_route() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "Cresselia", "name_en": "Cresselia", "card_type": "Pokemon", "effect_id": CRESSELIA_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	gardevoir.damage_counters = 20
	var cresselia := _make_slot(_make_cresselia_cd(), 0)
	cresselia.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.bench.append(gardevoir)
	player.bench.append(cresselia)
	var opponent_active := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent_active.damage_counters = 200
	gs.players[1].active_pokemon = opponent_active
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": cresselia,
	}, gs, 0))
	var budew_attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"projected_damage": 10,
	}, gs, 0))
	return assert_true(retreat_score > budew_attack_score,
		"Budew should hand off to ready Cresselia when Moonglow Reverse converts a prize (retreat=%f budew=%f)" % [retreat_score, budew_attack_score])


func test_175_gardevoir_non_attacker_hands_off_to_ready_cresselia_pressure() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "Cresselia", "name_en": "Cresselia", "card_type": "Pokemon", "effect_id": CRESSELIA_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	player.bench.clear()
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	gardevoir.damage_counters = 20
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	kirlia.damage_counters = 20
	var cresselia := _make_slot(_make_cresselia_cd(), 0)
	cresselia.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.bench.append(gardevoir)
	player.bench.append(kirlia)
	player.bench.append(cresselia)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var retreat_score: float = float(s.score_action_absolute({
		"kind": "retreat",
		"bench_target": cresselia,
	}, gs, 0))
	var end_score: float = float(s.score_action_absolute({"kind": "end_turn"}, gs, 0))
	return assert_true(retreat_score > end_score + 300.0,
		"Non-attacker active should hand off to ready Cresselia once the Stage 2 shell has a damage-counter pool (retreat=%f end=%f)" % [retreat_score, end_score])


func test_175_gardevoir_embrace_seeds_cresselia_counter_route() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": "Cresselia", "name_en": "Cresselia", "card_type": "Pokemon", "effect_id": CRESSELIA_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	var cresselia := _make_slot(_make_cresselia_cd(), 0)
	cresselia.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.bench.append(gardevoir)
	player.bench.append(cresselia)
	var opponent_active := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent_active.damage_counters = 200
	gs.players[1].active_pokemon = opponent_active
	var psychic := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0)
	player.discard_pile.append(psychic)
	var embrace_score: float = float(s.score_action_absolute({
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
		"targets": [{
			"embrace_energy": [psychic],
			"embrace_target": [cresselia],
		}],
	}, gs, 0))
	var end_score: float = float(s.score_action_absolute({"kind": "end_turn"}, gs, 0))
	return assert_true(embrace_score > end_score + 300.0,
		"Psychic Embrace should seed Cresselia's Moonglow Reverse pool when that creates a counter-prize route (embrace=%f end=%f)" % [embrace_score, end_score])


func test_175_gardevoir_reserves_attacker_slot_by_searching_scream_tail_over_extra_ralts() -> String:
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_budew_cd(), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var scream_score: float = float(s.score_interaction_target(
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	))
	var ralts_score: float = float(s.score_interaction_target(
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0),
		{"id": "artazon_pokemon"},
		{"game_state": gs, "player_index": 0}
	))
	return assert_true(scream_score > ralts_score,
		"17.5 Gardevoir should reserve a bench slot for Scream Tail once the shell body count is enough (scream=%f ralts=%f)" % [scream_score, ralts_score])


func test_175_gardevoir_online_shell_picks_nest_ball_before_vessel_when_missing_attacker() -> String:
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var nest_ball := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0)
	var vessel := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var picked: Variant = s.pick_search_item([vessel, nest_ball], gs, 0)
	return assert_true(picked == nest_ball,
		"17.5 Gardevoir should pick Nest Ball over Earthen Vessel when the online shell still needs its first attacker body")


func test_175_gardevoir_closed_loop_rebuild_recovers_attacker_before_backup_ralts() -> String:
	var gs := _make_game_state(28)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.hand = [
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0),
	]
	player.deck.clear()
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.discard_pile = [
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var owner: Dictionary = contract.get("owner", {}) if contract.get("owner", {}) is Dictionary else {}
	var priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	var search_priority: Array = priorities.get("search", []) if priorities.get("search", []) is Array else []
	var continuity: Dictionary = s.build_continuity_contract(gs, 0, contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var ralts_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_basic_to_bench",
		"card": player.hand[0],
	}, gs, 0, contract))
	var stretcher_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": player.hand[1],
	}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("attacker_rebuild_closed_loop", false)),
			"Closed-loop attacker rebuild should be detected when the online shell has only a discarded attacker"),
		assert_eq(str(owner.get("turn_owner_name", "")), DeckStrategyGardevoirScript.SCREAM_TAIL,
			"Closed-loop rebuild should make the recoverable Scream Tail the turn owner"),
		assert_true(search_priority.size() > 0 and str(search_priority[0]) == DeckStrategyGardevoirScript.SCREAM_TAIL,
			"Closed-loop rebuild search priority should start with the recoverable attacker"),
		assert_false(bool(setup_debt.get("need_backup_ralts_or_kirlia", false)),
			"Closed-loop rebuild must not reopen backup Ralts continuity before recovering the missing attacker"),
		assert_true(stretcher_score > ralts_score,
			"Night Stretcher attacker recovery should outrank backup Ralts during closed-loop rebuild (stretcher=%f ralts=%f)" % [stretcher_score, ralts_score]),
	])


func test_175_gardevoir_closed_loop_rebuild_cools_off_artazon_without_attacker_target() -> String:
	var gs := _make_game_state(28)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.deck.clear()
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var manaphy_card := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	var munkidori_card := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.deck.append(manaphy_card)
	player.deck.append(munkidori_card)
	player.discard_pile = [
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	var artazon := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)
	gs.stadium_card = artazon
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.MANAPHY, "name_en": "Manaphy", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var generic_stadium_score: float = float(s.score_action_absolute_with_plan({
		"kind": "use_stadium_effect",
		"card": artazon,
	}, gs, 0, contract))
	var manaphy_stadium_score: float = float(s.score_action_absolute_with_plan({
		"kind": "use_stadium_effect",
		"card": artazon,
		"targets": [{
			"artazon_pokemon": [manaphy_card],
		}],
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("attacker_rebuild_closed_loop", false)),
			"This regression should keep the closed-loop attacker recovery state from the long-loss trace"),
		assert_true(generic_stadium_score < end_score,
			"Artazon should not receive a generic positive score when closed-loop rebuild has no attacker target in deck (stadium=%f end=%f)" % [generic_stadium_score, end_score]),
		assert_true(manaphy_stadium_score < end_score,
			"Artazon should reject non-attacker support basics during closed-loop attacker rebuild (manaphy=%f end=%f)" % [manaphy_stadium_score, end_score]),
	])


func test_175_gardevoir_closed_loop_low_deck_rejects_iono_without_recovery_resource() -> String:
	var gs := _make_game_state(15)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KLEFKI, "Basic", "P", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.hand = [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0),
	]
	player.deck.clear()
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.discard_pile = [
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var iono_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": player.hand[0],
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("deck_out_pressure", false)),
			"This regression must run under the same low-deck pressure as the deck-out trace"),
		assert_true(bool(flags.get("attacker_rebuild_closed_loop", false)),
			"This regression should keep the closed-loop attacker recovery state"),
		assert_true(iono_score < end_score,
			"Low-deck closed-loop rebuild should not spend the last hand card on blind Iono without a recovery resource (iono=%f end=%f)" % [iono_score, end_score]),
	])


func test_175_gardevoir_charges_benched_scream_tail_when_preferred_drifloon_has_no_recovery_access() -> String:
	var gs := _make_game_state(28)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0)
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.append(gardevoir)
	player.bench.append(kirlia)
	player.bench.append(scream_tail)
	var hand_psychic := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0)
	player.hand = [hand_psychic]
	player.deck.clear()
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var discard_psychic := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0)
	player.discard_pile = [
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0),
		discard_psychic,
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 1))
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.DRIFLOON, "name_en": "Drifloon", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var attach_score: float = float(s.score_action_absolute_with_plan({
		"kind": "attach_energy",
		"card": hand_psychic,
		"target_slot": scream_tail,
	}, gs, 0, contract))
	var embrace_score: float = float(s.score_action_absolute_with_plan({
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
		"targets": [{
			"embrace_energy": [discard_psychic],
			"embrace_target": [scream_tail],
		}],
	}, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("handoff_window", false)),
			"After Artazon has already found Scream Tail, the online shell should remain in a handoff/conversion window"),
		assert_true(attach_score > end_score + 250.0,
			"Manual Psychic should charge the benched Scream Tail when preferred Drifloon is discarded but not recoverable this turn (attach=%f end=%f)" % [attach_score, end_score]),
		assert_true(embrace_score > end_score + 150.0,
			"Psychic Embrace should also charge the benched Scream Tail instead of passing in the same no-recovery-access state (embrace=%f end=%f)" % [embrace_score, end_score]),
	])


func test_175_gardevoir_reserves_last_bench_slot_for_attacker_over_support_basic() -> String:
	var gs := _make_game_state(14)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_budew_cd(), 0))
	var support_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110)
	var attacker_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var support_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(support_cd, 0),
	}, gs, 0))
	var attacker_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(attacker_cd, 0),
	}, gs, 0))
	return run_checks([
		assert_true(support_score < 0.0,
			"Support basics must not tie end turn when the final bench slot belongs to the first attacker (support=%f)" % support_score),
		assert_true(attacker_score > support_score + 500.0,
			"Scream Tail should strongly outrank support basics for the reserved attacker slot (attacker=%f support=%f)" % [attacker_score, support_score]),
	])


func test_175_gardevoir_reserves_conversion_support_slot_over_klefki() -> String:
	var gs := _make_game_state(15)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var klefki_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.KLEFKI, "Basic", "P", 70)
	var munkidori_cd := _make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var klefki_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(klefki_cd, 0),
	}, gs, 0))
	var munkidori_score: float = float(s.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": CardInstance.create(munkidori_cd, 0),
	}, gs, 0))
	return run_checks([
		assert_true(klefki_score < 0.0,
			"17.5 Gardevoir should keep the remaining two bench slots for Scream Tail plus Munkidori, not late Klefki padding (klefki=%f)" % klefki_score),
		assert_true(munkidori_score > klefki_score + 250.0,
			"Munkidori should outrank Klefki as the conversion support body for the Budew/Scream Tail route (munkidori=%f klefki=%f)" % [munkidori_score, klefki_score]),
	])


func test_175_gardevoir_routes_darkness_to_munkidori_before_scream_tail() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "P", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move damage counters."},
	], [
		{"name": "Mind Bend", "cost": "PC", "damage": "60"},
	]), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220), 1)
	gs.players[1].active_pokemon.damage_counters = 190
	player.discard_pile = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	var dark := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0)
	var scream_score: float = s.score_action_absolute({
		"kind": "attach_energy",
		"card": dark,
		"target_slot": player.bench[2],
	}, gs, 0)
	var munkidori_score: float = s.score_action_absolute({
		"kind": "attach_energy",
		"card": dark,
		"target_slot": player.bench[3],
	}, gs, 0)
	return run_checks([
		assert_true(munkidori_score > scream_score,
			"17.5 Gardevoir should preserve Darkness for Munkidori conversion when Scream Tail can be paid by Psychic Embrace (munkidori=%f scream=%f)" % [munkidori_score, scream_score]),
		assert_true(munkidori_score >= 500.0,
			"Darkness to Munkidori should be a real conversion setup action in the 17.5 Budew shell (got %f)" % munkidori_score),
	])


func test_175_gardevoir_blocks_energy_switch_moving_darkness_off_munkidori() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	var munkidori := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	var kirlia := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	var dark := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0)
	munkidori.attached_energy.append(dark)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(kirlia)
	player.bench.append(munkidori)
	var energy_switch := CardInstance.create(_make_trainer_cd("能量转移"), 0)
	energy_switch.card_data.name_en = "Energy Switch"
	var score: float = float(s.score_action_absolute({
		"kind": "play_trainer",
		"card": energy_switch,
		"targets": [{
			"energy_assignment": [{
				"source": dark,
				"target": kirlia,
			}],
		}],
	}, gs, 0))
	return assert_true(score < -200.0,
		"17.5 Gardevoir should block Energy Switch lines that move Darkness off Munkidori (score=%f)" % score)


func test_175_gardevoir_scores_unresolved_munkidori_followup_when_ko_live() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(19)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	player.active_pokemon.damage_counters = 30
	var munkidori := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move damage counters."},
	]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0))
	player.bench.append(munkidori)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	gs.players[1].active_pokemon.damage_counters = 190
	var score: float = float(s.score_action_absolute({
		"kind": "use_ability",
		"source_slot": munkidori,
		"ability_index": 0,
		"targets": [],
		"requires_interaction": true,
	}, gs, 0))
	return assert_true(score >= 500.0,
		"Unresolved Munkidori follow-up should still score as a KO conversion action so the resolver can pick targets (score=%f)" % score)


func test_175_gardevoir_munkidori_damage_transfer_debt_beats_end_turn_without_ko() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(21)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	var gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0)
	gardevoir.damage_counters = 30
	player.bench.append(gardevoir)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 30
	player.bench.append(scream_tail)
	var munkidori := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move damage counters."},
	]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0))
	player.bench.append(munkidori)
	var charizard := _make_slot(_make_pokemon_cd("喷火龙ex", "Stage 2", "D", 330, "", "ex"), 1)
	charizard.damage_counters = 100
	gs.players[1].active_pokemon = charizard
	var pidgey := _make_slot(_make_pokemon_cd("波波", "Basic", "C", 60), 1)
	pidgey.damage_counters = 20
	gs.players[1].bench.append(pidgey)
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var action := {
		"kind": "use_ability",
		"source_slot": munkidori,
		"ability_index": 0,
		"targets": [],
		"requires_interaction": true,
	}
	var action_score: float = float(s.score_action_absolute_with_plan(action, gs, 0, contract))
	var end_score: float = float(s.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, contract))
	var context := {"game_state": gs, "player_index": 0, "turn_contract": contract}
	var source_gardevoir_score: float = float(s.score_interaction_target(gardevoir, {"id": "source_pokemon"}, context))
	var source_scream_score: float = float(s.score_interaction_target(scream_tail, {"id": "source_pokemon"}, context))
	var target_pidgey_score: float = float(s.score_interaction_target(pidgey, {"id": "target_damage_counters"}, context))
	var target_charizard_score: float = float(s.score_interaction_target(charizard, {"id": "target_damage_counters"}, context))
	return run_checks([
		assert_true(bool(contract.get("flags", {}).get("munkidori_damage_transfer_debt", false)),
			"Turn contract should mark unresolved Munkidori damage-transfer debt before ending the turn"),
		assert_true(action_score > end_score + 250.0,
			"Munkidori damage transfer should replace stale end_turn even without an immediate KO (munkidori=%f end=%f)" % [action_score, end_score]),
		assert_true(source_gardevoir_score > source_scream_score,
			"Munkidori should prefer non-attacker support damage over draining Scream Tail damage (gardevoir=%f scream=%f)" % [source_gardevoir_score, source_scream_score]),
		assert_true(target_pidgey_score > target_charizard_score,
			"Munkidori should prefer the low-HP bench prize over padding Charizard damage (pidgey=%f charizard=%f)" % [target_pidgey_score, target_charizard_score]),
	])


func test_score_evolve_kirlia_higher_than_generic() -> String:
	var gs := _make_game_state()
	var s := _new_strategy()
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝")
	var generic_cd := _make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey")
	var score_kirlia: float = s.score_action({"kind": "evolve", "card": CardInstance.create(kirlia_cd, 0)}, _ctx(gs))
	var score_generic: float = s.score_action({"kind": "evolve", "card": CardInstance.create(generic_cd, 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_kirlia > score_generic, "奇鲁莉安进化分 (%f) 应高于通用进化 (%f)" % [score_kirlia, score_generic]),
		assert_true(score_kirlia >= 150.0, "奇鲁莉安进化分应 >= 150 (got %f)" % score_kirlia),
	])


func test_score_evolve_gardevoir_ex_highest() -> String:
	var gs := _make_game_state()
	var s := _new_strategy()
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝")
	var score_gard: float = s.score_action({"kind": "evolve", "card": CardInstance.create(gardevoir_cd, 0)}, _ctx(gs))
	var score_kirlia: float = s.score_action({"kind": "evolve", "card": CardInstance.create(kirlia_cd, 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_gard >= 300.0, "首只沙奈朵ex进化分应 >= 300 (got %f)" % score_gard),
		assert_true(score_gard > score_kirlia, "沙奈朵ex进化分应高于奇鲁莉安"),
	])


func test_score_psychic_embrace_respects_empty_discard() -> String:
	var gs := _make_game_state(4)
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	gs.players[0].active_pokemon = _make_slot(gardevoir_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action({
		"kind": "use_ability",
		"source_slot": gs.players[0].active_pokemon,
		"ability_index": 0,
	}, _ctx(gs))
	return assert_true(score < 0.0, "弃牌堆无超能量时 Psychic Embrace delta 应为负分 (got %f)" % score)


func test_score_psychic_embrace_with_discard_fuel() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	for i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	player.active_pokemon = _make_slot(gardevoir_cd, 0)
	var s := _new_strategy()
	var score: float = s.score_action({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, _ctx(gs))
	# 有燃料但无好目标时 delta 可能不高；关键是比无燃料时高
	return assert_true(score > -210.0, "弃牌堆有超能量时 Psychic Embrace delta 应高于无燃料 (got %f)" % score)


func test_score_munkidori_only_when_ko_possible() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var munki_cd := _make_pokemon_cd("愿增猿", "Basic", "D", 110, "", "",
		[{"name": "Adrenaline Poisoning", "text": "test"}])
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.damage_counters = 30
	player.bench.append(munki_slot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Defender", "Basic", "C", 200), 1)
	var s := _new_strategy()
	var action := {"kind": "use_ability", "source_slot": munki_slot, "ability_index": 0}
	var score_no_ko: float = s.score_action(action, _ctx(gs))
	gs.players[1].active_pokemon.damage_counters = 190
	var score_ko: float = s.score_action(action, _ctx(gs))
	return assert_true(score_ko > score_no_ko, "能凑 KO 时分数 (%f) 应高于不能时 (%f)" % [score_ko, score_no_ko])


func test_refinement_scored_high_with_hand_cards() -> String:
	## 精炼特性在手牌多时应高分（A 段）
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝", "",
		[{"name": "精炼", "text": "弃1抽2"}])
	var kirlia_slot := _make_slot(kirlia_cd, 0)
	player.bench.append(kirlia_slot)
	# 手里有多余卡牌
	player.hand.append(CardInstance.create(_make_pokemon_cd("玛纳霏", "Basic", "W"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.hand.append(CardInstance.create(_make_tool_cd("招式学习器 进化"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia_slot, "ability_index": 0},
		gs, 0
	)
	return assert_true(score >= 350.0,
		"精炼在手牌多时应高分 (got %f)" % score)


func test_concealed_cards_high_with_psychic_energy_in_hand() -> String:
	## 隐藏牌（光辉甲贺忍蛙）有超能量时应高分
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var greninja_cd := _make_pokemon_cd("光辉甲贺忍蛙", "Basic", "W", 120, "", "",
		[{"name": "隐藏牌", "text": "弃1能量抽2"}])
	var greninja_slot := _make_slot(greninja_cd, 0)
	player.bench.append(greninja_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja_slot, "ability_index": 0},
		gs, 0
	)
	return assert_true(score >= 400.0,
		"隐藏牌有超能量时应在 A 段 (got %f)" % score)


# ============================================================
#  弃牌优先级测试
# ============================================================

func test_discard_priority_psychic_energy_highest() -> String:
	var s := _new_strategy()
	var score_psychic: int = s.get_discard_priority(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var score_dark: int = s.get_discard_priority(CardInstance.create(_make_energy_cd("恶能量", "D"), 0))
	var score_item: int = s.get_discard_priority(CardInstance.create(_make_trainer_cd("Potion"), 0))
	var score_gard: int = s.get_discard_priority(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	return run_checks([
		assert_true(score_psychic > score_dark, "超能量弃牌优先级应高于恶能量"),
		assert_true(score_dark > score_item, "恶能量弃牌优先级应高于道具"),
		assert_true(score_item > score_gard, "道具弃牌优先级应高于核心卡沙奈朵ex"),
		assert_eq(score_psychic, 250, "超能量弃牌优先级应为 250"),
	])


func test_refinement_discard_prefers_psychic_energy() -> String:
	## 精炼优先弃超能量（场面感知版）
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬"), 0)
	var score_p: int = s.get_discard_priority_contextual(psychic, gs, 0)
	var score_d: int = s.get_discard_priority_contextual(dark, gs, 0)
	var score_poffin: int = s.get_discard_priority_contextual(poffin, gs, 0)
	return run_checks([
		assert_true(score_p > score_d, "超能量弃牌优先级应高于恶能量 (P=%d, D=%d)" % [score_p, score_d]),
		assert_true(score_p > score_poffin, "超能量弃牌优先级应高于宝芬 (P=%d, poffin=%d)" % [score_p, score_poffin]),
	])


func test_refinement_discard_deprioritizes_poffin_when_bench_full() -> String:
	## 满板时宝芬降低优先级
	var gs := _make_game_state(3)
	var player := gs.players[0]
	# 填满后备区（5 个）
	for i: int in 5:
		player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬"), 0)
	var score_full: int = s.get_discard_priority_contextual(poffin, gs, 0)
	# 清空后备区
	player.bench.clear()
	var score_empty: int = s.get_discard_priority_contextual(poffin, gs, 0)
	return assert_true(score_full > score_empty,
		"满板时宝芬弃牌优先级 (%d) 应高于空板时 (%d)" % [score_full, score_empty])


# ============================================================
#  早期铺板 + 贴能测试
# ============================================================

func test_early_game_prioritizes_bench_development() -> String:
	var gs := _make_game_state(1)
	var s := _new_strategy()
	var score_ralts: float = s.score_action({"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0)}, _ctx(gs))
	var score_pidgey: float = s.score_action({"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_ralts > score_pidgey, "早期拉鲁拉丝上板分 (%f) 应高于 Pidgey (%f)" % [score_ralts, score_pidgey]),
		assert_true(score_ralts >= 150.0, "早期拉鲁拉丝上板 delta 应 >= 150 (got %f)" % score_ralts),
	])


func test_attach_dark_energy_only_to_munkidori() -> String:
	## 恶能量唯一目标是愿增猿，给辅助型负分
	var gs := _make_game_state(4)
	var munki_cd := _make_pokemon_cd("愿增猿", "Basic", "D", 110, "", "", [], [{"name": "Poison", "cost": "DC", "damage": "40"}])
	var munki_slot := _make_slot(munki_cd, 0)
	var mana_slot := _make_slot(_make_pokemon_cd("玛纳霏", "Basic", "W", 70, "", "", [{"name": "Wave Veil", "text": "test"}]), 0)
	var ralts_slot := _make_slot(_make_pokemon_cd("拉鲁拉丝"), 0)
	gs.players[0].active_pokemon = ralts_slot
	gs.players[0].bench.append(munki_slot)
	gs.players[0].bench.append(mana_slot)
	var s := _new_strategy()
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var score_munki: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": munki_slot}, _ctx(gs))
	var score_mana: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": mana_slot}, _ctx(gs))
	var score_ralts: float = s.score_action({"kind": "attach_energy", "card": dark, "target_slot": ralts_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_munki > 0.0, "恶能量给愿增猿应正分 (got %f)" % score_munki),
		assert_true(score_mana < 0.0, "恶能量给玛纳霏应负分 (got %f)" % score_mana),
		assert_true(score_ralts < 0.0, "恶能量给拉鲁拉丝应负分 (got %f)" % score_ralts),
	])


func test_attach_psychic_energy_always_negative() -> String:
	## 超能量永远不手贴，无论目标是谁
	var gs := _make_game_state(4)
	var drifloon_slot := _make_slot(_make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [], [{"name": "Spin", "cost": "PC", "damage": "30"}]), 0)
	var klefki_slot := _make_slot(_make_pokemon_cd("钥圈儿", "Basic", "Y", 70), 0)
	gs.players[0].active_pokemon = drifloon_slot
	gs.players[0].bench.append(klefki_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var score_drifloon: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": drifloon_slot}, _ctx(gs))
	var score_klefki: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": klefki_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_drifloon < -200.0, "超能量给飘飘球应大负分 (got %f)" % score_drifloon),
		assert_true(score_klefki < -200.0, "超能量给钥圈儿应大负分 (got %f)" % score_klefki),
	])


func test_psychic_energy_manual_attach_allows_active_drifloon_emergency_line() -> String:
	## 超能量永不手贴 — 无论目标是谁
	var gs := _make_game_state(4)
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [], [{"name": "Spin", "cost": "PC", "damage": "30"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var gard_slot := _make_slot(gard_cd, 0)
	gs.players[0].active_pokemon = drifloon_slot
	gs.players[0].bench.append(gard_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var score_drifloon: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": drifloon_slot}, _ctx(gs))
	var score_gard: float = s.score_action({"kind": "attach_energy", "card": psychic, "target_slot": gard_slot}, _ctx(gs))
	return run_checks([
		assert_true(score_drifloon > 0.0, "Active Drifloon can receive emergency Psychic attachment when it opens an attack line (got %f)" % score_drifloon),
		assert_true(score_gard < -200.0, "Psychic manual attachment to Gardevoir ex should stay strongly negative (got %f)" % score_gard),
	])


# ============================================================
#  训练师评分测试
# ============================================================

func test_175_gardevoir_manual_psychic_recharges_existing_scream_tail_when_no_ready_attacker() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(
		DeckStrategyGardevoirScript.GARDEVOIR_EX,
		"Stage 2",
		"P",
		310,
		DeckStrategyGardevoirScript.KIRLIA,
		"ex"
	), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(
		DeckStrategyGardevoirScript.SCREAM_TAIL,
		"Basic",
		"P",
		90,
		"",
		"",
		[],
		[
			{"name": "Roaring Scream", "cost": "PC", "damage": ""},
		]
	), 0)
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var psychic := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0)
	var attach_score: float = s.score_action_absolute({
		"kind": "attach_energy",
		"card": psychic,
		"target_slot": scream_tail,
	}, gs, 0)
	var end_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score >= 300.0,
			"17.5 Gardevoir should recharge an existing unready Scream Tail once the Stage 2 shell is online (attach=%f)" % attach_score),
		assert_true(attach_score > end_score + 250.0,
			"Manual Psychic to Scream Tail should beat passing when no attacker is ready (attach=%f end=%f)" % [attach_score, end_score]),
	])


func test_175_gardevoir_manual_darkness_recharges_scream_tail_when_munkidori_absent() -> String:
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": DeckStrategyGardevoirScript.MUNKIDORI, "name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var gs := _make_game_state(17)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(
		DeckStrategyGardevoirScript.GARDEVOIR_EX,
		"Stage 2",
		"P",
		310,
		DeckStrategyGardevoirScript.KIRLIA,
		"ex"
	), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(
		DeckStrategyGardevoirScript.SCREAM_TAIL,
		"Basic",
		"P",
		90,
		"",
		"",
		[],
		[
			{"name": "Roaring Scream", "cost": "PC", "damage": ""},
		]
	), 0)
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var dark := CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0)
	var attach_score: float = s.score_action_absolute({
		"kind": "attach_energy",
		"card": dark,
		"target_slot": scream_tail,
	}, gs, 0)
	var end_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score >= 300.0,
			"17.5 Gardevoir should use Darkness as Scream Tail colorless payment when Munkidori is not on board (attach=%f)" % attach_score),
		assert_true(attach_score > end_score + 250.0,
			"Darkness to Scream Tail should beat passing when it is the only visible attacker recharge route (attach=%f end=%f)" % [attach_score, end_score]),
	])


func test_trainer_earthen_vessel_high_mid_game() -> String:
	var gs := _make_game_state(3)
	# 手里有超能量时大地容器价值更高（弃超能 = Embrace 燃料）
	gs.players[0].hand.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var s := _new_strategy()
	var score_vessel: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("大地容器"), 0)}, _ctx(gs))
	var score_potion: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Potion"), 0)}, _ctx(gs))
	return run_checks([
		assert_true(score_vessel > score_potion, "大地容器中期分 (%f) 应高于 Potion (%f)" % [score_vessel, score_potion]),
		assert_true(score_vessel >= 150.0, "大地容器中期 delta 应 >= 150 (got %f)" % score_vessel),
	])


func test_rare_candy_with_ralts_and_gardevoir_in_hand() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	var s := _new_strategy()
	var score: float = s.score_action({"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Rare Candy"), 0)}, _ctx(gs))
	return assert_true(score >= 300.0, "Rare Candy + 拉鲁拉丝 + 沙奈朵ex应得极高分 (got %f)" % score)


func test_boss_orders_high_when_can_ko_bench_target() -> String:
	## 能击倒后备时老大指令应在 S 段
	var gs := _make_game_state(5)
	var player := gs.players[0]
	# 攻击手在前场，有攻击能力
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "气球炸弹", "cost": "PP", "damage": "60"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.active_pokemon = drifloon_slot
	# 对手后备有低 HP 目标
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("弱小目标", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("老大的指令", "Supporter"), 0)},
		gs, 0
	)
	return assert_true(score >= 800.0,
		"能击倒后备弱目标时老大指令应在 S 段 (got %f)" % score)


func test_arven_high_when_deck_has_ultra_ball_and_need_gardevoir() -> String:
	## 派帕决策链：牌库有高级球 + 场上有奇鲁莉安 + 无沙奈朵 → 高分
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	# 牌库放入高级球
	var ultra_ball_cd := _make_trainer_cd("高级球")
	player.deck.append(CardInstance.create(ultra_ball_cd, 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("派帕", "Supporter"), 0)},
		gs, 0
	)
	return assert_true(score >= 250.0,
		"派帕能找高级球启动引擎时应高分 (got %f)" % score)


func test_arven_picks_ultra_ball_when_need_gardevoir() -> String:
	## 派帕搜索目标选择：需要沙奈朵时优先找高级球
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("高级球"), 0)
	var potion := CardInstance.create(_make_trainer_cd("Potion"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("巢穴球"), 0)
	var items: Array = [potion, nest_ball, ultra_ball]
	var s := _new_strategy()
	var picked: Variant = s.pick_search_item(items, gs, 0)
	var picked_name: String = ""
	if picked is CardInstance:
		picked_name = str((picked as CardInstance).card_data.name)
	return assert_eq(picked_name, "高级球", "需要沙奈朵时派帕应优先找高级球")


func test_175_gardevoir_research_outranks_arven_when_kirlia_online_without_direct_gardevoir_search() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var kirlia_en_cd := _make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts")
	kirlia_en_cd.name_en = "Kirlia"
	player.bench.append(_make_slot(kirlia_en_cd, 0))
	player.bench.append(_make_slot(kirlia_en_cd, 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0))
	player.deck.append(CardInstance.create(_make_tool_cd(DeckStrategyGardevoirScript.TM_EVOLUTION), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	var research_cd := _make_trainer_cd("Professor's Research", "Supporter")
	research_cd.name_en = "Professor's Research"
	research_cd.effect_id = DeckStrategyGardevoirScript.PROFESSORS_RESEARCH_EFFECT_ID
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
	]))
	var research_score: float = float(s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(research_cd, 0)},
		gs,
		0
	))
	var arven_score: float = float(s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	))
	return assert_true(
		research_score > arven_score,
		"17.5 Gardevoir should draw toward the first Gardevoir ex instead of using Arven for Secret Box/TM detours (research=%f arven=%f)" % [research_score, arven_score]
	)


func test_175_gardevoir_low_deck_blocks_research_for_first_gardevoir_churn() -> String:
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.deck.clear()
	for i: int in 5:
		if i == 0:
			player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
		else:
			player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.active_pokemon = _make_slot(_make_budew_cd(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var research_cd := _make_trainer_cd("Professor's Research", "Supporter")
	research_cd.name_en = "Professor's Research"
	research_cd.effect_id = DeckStrategyGardevoirScript.PROFESSORS_RESEARCH_EFFECT_ID
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
	]))
	var research_score: float = float(s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(research_cd, 0)},
		gs,
		0
	))
	return assert_true(research_score <= 120.0,
		"Low-deck Gardevoir should not burn Professor's Research just to gamble for first Stage 2 without an attack window (score=%f)" % research_score)


func test_175_gardevoir_empty_deck_still_blocks_research_churn() -> String:
	var gs := _make_game_state(30)
	var player := gs.players[0]
	player.deck.clear()
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var research_cd := _make_trainer_cd("Professor's Research", "Supporter")
	research_cd.name_en = "Professor's Research"
	research_cd.effect_id = DeckStrategyGardevoirScript.PROFESSORS_RESEARCH_EFFECT_ID
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var contract: Dictionary = s.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var research_score: float = float(s.score_action_absolute_with_plan({
		"kind": "play_trainer",
		"card": CardInstance.create(research_cd, 0),
	}, gs, 0, contract))
	return run_checks([
		assert_true(bool(flags.get("deck_out_pressure", false)),
			"An empty deck during the main phase must still be treated as deck-out pressure"),
		assert_true(research_score < 0.0,
			"Empty-deck Gardevoir should not score Professor's Research as a safe churn action (score=%f)" % research_score),
	])


func test_175_gardevoir_low_deck_cools_off_iono_with_online_shell_and_live_attacker() -> String:
	var gs := _make_game_state(23)
	var player := gs.players[0]
	player.deck.clear()
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0))
	player.prizes = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
	]
	gs.players[1].prizes = [
		CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 1),
		CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 1),
	]
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90, "", "", [], [
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.DARK_ENERGY, "D"), 0),
	]
	player.active_pokemon = scream_tail
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	player.hand = [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0),
		CardInstance.create(_make_energy_cd(DeckStrategyGardevoirScript.PSYCHIC_ENERGY, "P"), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0),
	]
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var s := _new_strategy()
	s.configure_from_deck(_make_deck_data(610080, [
		{"name": DeckStrategyGardevoirScript.RALTS, "name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.KIRLIA, "name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name": DeckStrategyGardevoirScript.GARDEVOIR_EX, "name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name": DeckStrategyGardevoirScript.SCREAM_TAIL, "name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name": "Budew", "name_en": "Budew", "card_type": "Pokemon", "effect_id": BUDEW_EFFECT_ID, "count": 1},
	]))
	var iono_score: float = float(s.score_action_absolute({
		"kind": "play_trainer",
		"card": player.hand[0],
	}, gs, 0))
	var attack_score: float = float(s.score_action_absolute({
		"kind": "attack",
		"source_slot": scream_tail,
		"attack_index": 0,
		"attack_name": "Roaring Scream",
		"projected_damage": 120,
	}, gs, 0))
	return run_checks([
		assert_true(iono_score < 0.0,
			"Low-deck Gardevoir with an online shell and live attacker should cool off Iono churn even after Kirlia leaves play (iono=%f)" % iono_score),
		assert_true(attack_score > iono_score,
			"The live Scream Tail attack should outrank Iono deck-out churn (attack=%f iono=%f)" % [attack_score, iono_score]),
	])


func test_second_gardevoir_evolve_low_when_losing_last_kirlia() -> String:
	## 第二只沙奈朵进化会失去最后一只奇鲁莉安时应低分
	var gs := _make_game_state(5)
	var player := gs.players[0]
	# 场上已有 1 只沙奈朵ex
	player.bench.append(_make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	# 只有 1 只奇鲁莉安（进化后就没了）
	var kirlia_slot := _make_slot(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0)
	player.bench.append(kirlia_slot)
	var s := _new_strategy()
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var score: float = s.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(gard_cd, 0)}, gs, 0)
	return assert_true(score <= 150.0,
		"失去最后一只奇鲁莉安时第二只沙奈朵分应低 (got %f)" % score)


# ============================================================
#  检索偏好测试
# ============================================================

func test_search_priority_ralts_highest() -> String:
	var s := _new_strategy()
	var score_ralts: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("拉鲁拉丝"), 0))
	var score_pidgey: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C"), 0))
	var score_kirlia: int = s.get_search_priority(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	return run_checks([
		assert_true(score_ralts > score_kirlia, "拉鲁拉丝检索优先级应高于奇鲁莉安"),
		assert_true(score_kirlia > score_pidgey, "奇鲁莉安检索优先级应高于 Pidgey"),
	])


# ============================================================
#  AIHeuristics 集成测试
# ============================================================

func test_heuristics_delegates_gardevoir_bias() -> String:
	CardInstance.reset_id_counter()
	var heuristics := AIHeuristicsScript.new()
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.hand.append(CardInstance.create(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0))
	var action := {
		"kind": "evolve",
		"card": CardInstance.create(_make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80, "拉鲁拉丝"), 0),
		"reason_tags": [],
	}
	var ctx := {"gsm": null, "game_state": gs, "player_index": 0, "features": {}}
	var score: float = heuristics.score_action(action, ctx)
	return assert_true(score >= 300.0, "Heuristics 应委托策略类给出高分 (got %f)" % score)


# ============================================================
#  绝对分评估 + Combo 测试
# ============================================================

func test_score_action_absolute_gardevoir_evolve_s_tier() -> String:
	## 首只沙奈朵ex进化应该在 S 段（800+）
	var gs := _make_game_state(4)
	var s := _new_strategy()
	var gard_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex")
	var score: float = s.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(gard_cd, 0)},
		gs, 0
	)
	return assert_true(score >= 800.0, "首只沙奈朵ex进化绝对分应 >= 800 (got %f)" % score)


func test_combo_refinement_boosts_embrace() -> String:
	## Combo: 弃牌堆加速 — 弃牌堆有超能量时 Embrace 分数应高于无燃料时
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex",
		[{"name": "精神拥抱", "text": "test"}])
	var gard_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gard_slot
	# 添加一个攻击手到后备（Embrace 的贴能目标）
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "Balloon Bomb", "cost": "PP", "damage": "0"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	player.bench.append(drifloon_slot)
	var s := _new_strategy()
	var action := {"kind": "use_ability", "source_slot": gard_slot, "ability_index": 0}
	# 无燃料
	var score_no_fuel: float = s.score_action_absolute(action, gs, 0)
	# 添加弃牌堆超能量（模拟 Refinement 弃了超能量）
	for i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	var score_with_fuel: float = s.score_action_absolute(action, gs, 0)
	return run_checks([
		assert_true(score_with_fuel > score_no_fuel,
			"弃牌堆有燃料时 Embrace 绝对分 (%f) 应高于无燃料时 (%f)" % [score_with_fuel, score_no_fuel]),
		assert_true(score_with_fuel >= 250.0,
			"有攻击手 + 燃料时 Embrace 应高分 (got %f)" % score_with_fuel),
	])


func test_combo_embrace_enables_attack() -> String:
	## Combo: Embrace 给攻击手贴能后 attack 分数应在正区间
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [],
		[{"name": "Balloon Bomb", "cost": "PP", "damage": "0"}])
	var drifloon_slot := _make_slot(drifloon_cd, 0)
	# 模拟 Embrace 已贴了 2 个能量 + 伤害指示物
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("超能量", "P"), 0))
	player.active_pokemon = drifloon_slot
	# 对手
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Defender", "Basic", "C", 100), 1)
	var s := _new_strategy()
	var attack_action := {"kind": "attack", "attack_index": 0, "projected_damage": 120}
	var score: float = s.score_action_absolute(attack_action, gs, 0)
	return assert_true(score >= 800.0,
		"Embrace 后能击倒对手时 attack 应在 S 段 (got %f)" % score)


func test_negative_action_blocked() -> String:
	## 超能量手贴、能量给错目标应该分数 ≤ 0
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var ralts_slot := _make_slot(_make_pokemon_cd("拉鲁拉丝"), 0)
	var klefki_slot := _make_slot(_make_pokemon_cd("钥圈儿", "Basic", "Y", 70), 0)
	player.active_pokemon = ralts_slot
	player.bench.append(klefki_slot)
	var s := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("超能量", "P"), 0)
	var dark := CardInstance.create(_make_energy_cd("恶能量", "D"), 0)
	var score_psychic_ralts: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": psychic, "target_slot": ralts_slot}, gs, 0)
	var score_dark_klefki: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": dark, "target_slot": klefki_slot}, gs, 0)
	return run_checks([
		assert_true(score_psychic_ralts <= 0.0,
			"超能量手贴给拉鲁拉丝绝对分应 <= 0 (got %f)" % score_psychic_ralts),
		assert_true(score_dark_klefki <= 0.0,
			"恶能量给钥圈儿绝对分应 <= 0 (got %f)" % score_dark_klefki),
	])


# ============================================================
#  TM Evolution 道具赋予招式测试
# ============================================================

func test_tm_evolution_tool_scored_high_with_bench_ralts() -> String:
	## TM Evolution 在有可进化后备拉鲁拉丝 + 前场有/可贴能量时高分
	var gs := _make_game_state(2)
	var player := gs.players[0]
	# 前场振翼发（控制型），已有1个能量（可支付进化招式费用 C）
	var flutter_slot := _make_slot(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0)
	flutter_slot.attached_energy.append(CardInstance.create(_make_energy_cd("恶能量", "D"), 0))
	player.active_pokemon = flutter_slot
	# 后备拉鲁拉丝（可进化目标）
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var tm_card := CardInstance.create(_make_tool_cd("招式学习器 进化"), 0)
	var score_active: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": tm_card, "target_slot": flutter_slot},
		gs, 0
	)
	# 贴给后备应负分
	var bench_slot: PokemonSlot = player.bench[0]
	var score_bench: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": tm_card, "target_slot": bench_slot},
		gs, 0
	)
	return run_checks([
		assert_true(score_active >= 500.0,
			"TM Evolution 贴给前场 + 有能量 + 有可进化后备时应 >= 500 (got %f)" % score_active),
		assert_true(score_bench < 0.0,
			"TM Evolution 贴给后备应负分 (got %f)" % score_bench),
	])


func test_granted_attack_tm_evolution_high_with_targets() -> String:
	## TM Evolution 进化招式在有可进化后备时 A 段
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("振翼发", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("拉鲁拉丝"), 0))
	var s := _new_strategy()
	var action := {
		"kind": "granted_attack",
		"granted_attack_data": {"name": "进化", "cost": "", "damage": 0},
		"attack_index": -1,
		"source_slot": player.active_pokemon,
	}
	var score: float = s.score_action_absolute(action, gs, 0)
	return assert_true(score >= 600.0,
		"TM Evolution 进化招式在有可进化后备时应 >= 600 (got %f)" % score)


# ============================================================
#  MCTS + 策略评估测试
# ============================================================

func test_mcts_evaluate_board_used_over_rollout() -> String:
	## MCTSPlanner 有 deck_strategy 时应用 evaluate_board 而非 rollout
	var s := _new_strategy()
	var planner := preload("res://scripts/ai/MCTSPlanner.gd").new()
	planner.deck_strategy = s
	# 构造一个简单 GameState
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.bench.append(_make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "奇鲁莉安", "ex"), 0))
	# evaluate_board 应返回正值（场上有沙奈朵ex引擎）
	var raw: float = s.evaluate_board(gs, 0)
	# 归一化后应在 (0, 1)
	var normalized: float = clampf((raw + 2000.0) / 6000.0, 0.0, 1.0)
	return run_checks([
		assert_true(raw > 0.0, "有沙奈朵ex引擎时 evaluate_board 应正值 (got %f)" % raw),
		assert_true(normalized > 0.3, "归一化后应 > 0.3 (got %f)" % normalized),
		assert_true(normalized < 1.0, "归一化后应 < 1.0 (got %f)" % normalized),
	])


func test_get_mcts_config_returns_valid_config() -> String:
	## get_mcts_config 应返回有效配置字典
	var s := _new_strategy()
	var config: Dictionary = s.get_mcts_config()
	return run_checks([
		assert_true(config.has("branch_factor"), "应包含 branch_factor"),
		assert_true(config.has("time_budget_ms"), "应包含 time_budget_ms"),
		assert_eq(int(config.get("rollouts_per_sequence", -1)), 0, "rollouts_per_sequence 应为 0（不 rollout）"),
		assert_eq(int(config.get("branch_factor", 0)), 3, "branch_factor 应为 3"),
	])
