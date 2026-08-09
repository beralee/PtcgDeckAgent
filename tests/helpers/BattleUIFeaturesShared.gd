## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleScenePacked = preload("res://scenes/battle/BattleScene.tscn")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const CoinFlipAnimatorScript = preload("res://scenes/battle/CoinFlipAnimator.gd")
const BattleDisplayControllerScript = preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleStadiumBackdropCoordinatorScript = preload("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd")
const BattlePortraitLayoutViewScript = preload("res://scripts/ui/battle/layouts/BattlePortraitLayoutView.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const BattleSetupScript = preload("res://scenes/battle_setup/BattleSetup.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const EffectBossOrdersScript = preload("res://scripts/effects/trainer_effects/EffectBossOrders.gd")
const EffectCounterCatcherScript = preload("res://scripts/effects/trainer_effects/EffectCounterCatcher.gd")
const EffectElectricGeneratorScript = preload("res://scripts/effects/trainer_effects/EffectElectricGenerator.gd")
const EffectPrimeCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPrimeCatcher.gd")
const EffectEnergySwitchScript = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectPokemonCatcherScript = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectCapturingAromaScript = preload("res://scripts/effects/trainer_effects/EffectCapturingAroma.gd")
const EffectMirageGateScript = preload("res://scripts/effects/trainer_effects/EffectMirageGate.gd")
const EffectScoopUpCycloneScript = preload("res://scripts/effects/trainer_effects/EffectScoopUpCyclone.gd")
const EffectPerfectMixerScript = preload("res://scripts/effects/trainer_effects/CSV9C183PerfectMixer.gd")
const EffectSwitchCartScript = preload("res://scripts/effects/trainer_effects/EffectSwitchCart.gd")
const EffectSwitchPokemonScript = preload("res://scripts/effects/trainer_effects/EffectSwitchPokemon.gd")
const EffectRareCandyScript = preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
const EffectCarmineScript = preload("res://scripts/effects/trainer_effects/EffectCarmine.gd")
const EffectMelaScript = preload("res://scripts/effects/trainer_effects/EffectMela.gd")
const EffectCollapsedStadiumScript = preload("res://scripts/effects/stadium_effects/EffectCollapsedStadium.gd")
const EffectAreaZeroUnderdepthsScript = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")
const EffectGrandTreeScript = preload("res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd")
const AbilitySelfKnockoutDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilitySelfKnockoutDamageCounters.gd")
const AbilityPsychicEmbraceScript = preload("res://scripts/effects/pokemon_effects/AbilityPsychicEmbrace.gd")
const AbilityStarPortalScript = preload("res://scripts/effects/pokemon_effects/AbilityStarPortal.gd")
const AbilityGustFromBenchScript = preload("res://scripts/effects/pokemon_effects/AbilityGustFromBench.gd")
const AbilityBenchDamageOnPlayScript = preload("res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd")
const AbilityRunAwayDrawScript = preload("res://scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd")
const EffectSadasVitalityScript = preload("res://scripts/effects/trainer_effects/EffectSadasVitality.gd")
const AbilityAttachFromDeckScript = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackAttachBasicEnergyFromDiscardScript = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AttackSearchAndAttachScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAndAttach.gd")
const AttackSearchAttachToVScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAttachToV.gd")
const AttackReturnEnergyThenBenchDamageScript = preload("res://scripts/effects/pokemon_effects/AttackReturnEnergyThenBenchDamage.gd")
const AttackSwitchSelfToBenchScript = preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")
const AttackAnyTargetDamageScript = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
const AttackSelfDamageCounterTargetDamageScript = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterTargetDamage.gd")
const AttackTMEvolutionScript = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")
const AttackDiscardBasicEnergyFromFieldDamageScript = preload("res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromFieldDamage.gd")
const AbilityMoveDamageCountersToOpponentScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")
const AbilityMoveOpponentDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


class FakeBattleReviewService extends RefCounted:
	var generate_calls: Array[Dictionary] = []

	func generate_review(host: Node, match_dir: String, api_config: Dictionary) -> Dictionary:
		generate_calls.append({
			"host": host,
			"match_dir": match_dir,
			"api_config": api_config.duplicate(true),
		})
		return {"status": "started"}


class FakeBattleRecorder extends RefCounted:
	var events: Array[Dictionary] = []

	func record_event(event_data: Dictionary) -> void:
		events.append(event_data.duplicate(true))


class FakeCoinAnimator extends Node:
	var played_results: Array[bool] = []

	func play(result: bool) -> void:
		played_results.append(result)


class FakeLayeredCoinAnimator extends Control:
	var played_results: Array[bool] = []

	func play(result: bool) -> void:
		played_results.append(result)


class FakeHandCardScene extends RefCounted:
	var _play_card_size := Vector2(130, 182)
	var _selected_hand_card: CardInstance = null
	var detail_calls: int = 0
	var hand_detail_calls: int = 0
	var execute_calls: int = 0
	var last_hand_detail_card: CardInstance = null
	var last_detail_card: CardData = null

	func _show_hand_card_detail(inst: CardInstance) -> void:
		hand_detail_calls += 1
		last_hand_detail_card = inst

	func _show_card_detail(cd: CardData) -> void:
		detail_calls += 1
		last_detail_card = cd

	func _on_hand_card_clicked(_inst: CardInstance, _panel: PanelContainer) -> void:
		execute_calls += 1


class FakeStadiumActionEffect extends BaseEffect:
	var execute_calls: int = 0

	func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
		return true

	func can_execute(_card: CardInstance, _state: GameState) -> bool:
		return true

	func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
		execute_calls += 1


class SpyRetreatGameStateMachine extends GameStateMachine:
	var retreat_calls: int = 0
	var retreat_result: bool = true
	var last_energy_to_discard: Array[CardInstance] = []
	var last_bench_target: PokemonSlot = null

	func retreat(_player_index: int, energy_to_discard: Array[CardInstance], bench_target: PokemonSlot) -> bool:
		retreat_calls += 1
		last_energy_to_discard = energy_to_discard.duplicate()
		last_bench_target = bench_target
		return retreat_result


class SetupThenEndTurnAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0
	var end_turn_calls: int = 0
	var _delegate = AIOpponentScript.new()

	func _init(next_player_index: int = 1) -> void:
		player_index = next_player_index
		_delegate.configure(next_player_index, difficulty)

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		return _delegate.should_control_turn(game_state, ui_blocked)

	func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
		run_count += 1
		if (
			gsm != null
			and gsm.game_state != null
			and gsm.game_state.phase == GameState.GamePhase.MAIN
			and gsm.game_state.current_player_index == player_index
			and str(battle_scene.get("_pending_choice")) == ""
		):
			end_turn_calls += 1
			battle_scene.call("_on_end_turn", player_index)
			return true
		return _delegate.run_single_step(battle_scene, gsm)



## 构建测试用 CardData（宝可梦）

func _make_pokemon_cd(pname: String, hp: int, energy: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = hp
	cd.energy_type = energy
	cd.retreat_cost = 1
	cd.weakness_energy = "W"
	cd.weakness_value = "×2"
	cd.resistance_energy = ""
	cd.resistance_value = ""
	cd.attacks = [
		{"name": "撞击", "cost": "RC", "damage": "30", "text": "", "is_vstar_power": false},
		{"name": "火焰喷射", "cost": "RRC", "damage": "90", "text": "弃置1个火能量。", "is_vstar_power": false},
	]
	cd.abilities = [{"name": "闪焰", "text": "每回合可抽1张牌"}]
	cd.evolves_from = ""
	return cd


## 构建测试用 CardData（训练家卡）
func _make_trainer_cd(tname: String, card_type: String, desc: String) -> CardData:
	var cd := CardData.new()
	cd.name = tname
	cd.card_type = card_type
	cd.description = desc
	return cd


## 构建测试用 CardData（能量卡）
func _make_energy_cd(ename: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = ename
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return cd


func _make_battle_scene_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_active_battle_layout_mode", "landscape")
	battle_scene.set("_dialog_title", Label.new())
	battle_scene.set("_dialog_list", ItemList.new())
	battle_scene.set("_dialog_card_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_card_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_panel", VBoxContainer.new())
	battle_scene.set("_dialog_assignment_source_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_source_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_target_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_target_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_summary_lbl", Label.new())
	battle_scene.set("_dialog_utility_row", HBoxContainer.new())
	battle_scene.set("_dialog_confirm", Button.new())
	battle_scene.set("_dialog_cancel", Button.new())
	battle_scene.set("_dialog_status_lbl", Label.new())
	battle_scene.set("_dialog_overlay", Panel.new())
	battle_scene.set("_handover_panel", Panel.new())
	battle_scene.set("_handover_lbl", Label.new())
	battle_scene.set("_handover_btn", Button.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_log_list", RichTextLabel.new())
	battle_scene.set("_lbl_phase", Label.new())
	battle_scene.set("_lbl_turn", Label.new())
	battle_scene.set("_opp_prizes", Label.new())
	battle_scene.set("_opp_deck", Label.new())
	battle_scene.set("_opp_discard", Label.new())
	battle_scene.set("_opp_hand_lbl", Label.new())
	battle_scene.set("_opp_hand_bar", PanelContainer.new())
	battle_scene.set("_opp_prize_hud_count", Label.new())
	battle_scene.set("_opp_deck_hud_value", Label.new())
	battle_scene.set("_opp_discard_hud_value", Label.new())
	battle_scene.set("_my_prizes", Label.new())
	battle_scene.set("_my_deck", Label.new())
	battle_scene.set("_my_discard", Label.new())
	battle_scene.set("_my_prize_hud_count", Label.new())
	battle_scene.set("_my_deck_hud_value", Label.new())
	battle_scene.set("_my_discard_hud_value", Label.new())
	battle_scene.set("_btn_end_turn", Button.new())
	battle_scene.set("_btn_back", Button.new())
	battle_scene.set("_btn_attack_vfx_preview", Button.new())
	battle_scene.set("_btn_ai_advice", Button.new())
	battle_scene.set("_btn_battle_discuss_ai", Button.new())
	battle_scene.set("_btn_zeus_help", Button.new())
	battle_scene.set("_btn_opponent_hand", Button.new())
	battle_scene.set("_btn_replay_prev_turn", Button.new())
	battle_scene.set("_btn_replay_next_turn", Button.new())
	battle_scene.set("_btn_replay_continue", Button.new())
	battle_scene.set("_btn_replay_back_to_list", Button.new())
	battle_scene.set("_hud_end_turn_btn", Button.new())
	battle_scene.set("_stadium_lbl", Label.new())
	battle_scene.set("_btn_stadium_action", Button.new())
	battle_scene.set("_enemy_vstar_value", Label.new())
	battle_scene.set("_my_vstar_value", Label.new())
	battle_scene.set("_enemy_lost_value", Label.new())
	battle_scene.set("_my_lost_value", Label.new())
	battle_scene.set("_hand_container", HBoxContainer.new())
	# Match the packed BattleScene startup contract. Fresh Controls default to
	# visible, while these modal overlays are hidden in the real scene until an
	# interaction explicitly opens them. Leaving the discard overlay visible in
	# this stub falsely blocks every AI continuation via _is_ui_blocking_ai().
	for overlay_name: String in ["_dialog_overlay", "_handover_panel", "_coin_overlay", "_detail_overlay", "_discard_overlay"]:
		var overlay: Control = battle_scene.get(overlay_name) as Control
		if overlay != null:
			overlay.visible = false
	return battle_scene


func _make_named_deck_cards(owner_index: int, names: Array[String]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for name: String in names:
		cards.append(CardInstance.create(_make_pokemon_cd(name, 60, "C"), owner_index))
	return cards


func _seed_battle_scene_deck_previews(scene: Control) -> void:
	var my_preview := BattleCardViewScript.new()
	var opp_preview := BattleCardViewScript.new()
	scene.add_child(my_preview)
	scene.add_child(opp_preview)
	scene.set("_my_deck_preview", my_preview)
	scene.set("_opp_deck_preview", opp_preview)


func _seed_battle_scene_discard_previews(scene: Control) -> void:
	var my_preview := BattleCardViewScript.new()
	var opp_preview := BattleCardViewScript.new()
	scene.add_child(my_preview)
	scene.add_child(opp_preview)
	scene.set("_my_discard_preview", my_preview)
	scene.set("_opp_discard_preview", opp_preview)


func _prepare_detail_scene() -> Control:
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_detail_overlay", scene.find_child("DetailOverlay", true, false))
	scene.set("_detail_title", scene.find_child("DetailTitle", true, false))
	scene.set("_detail_content", scene.find_child("DetailContent", true, false))
	scene.set("_detail_close_btn", scene.find_child("DetailCloseBtn", true, false))
	scene.set("_handover_panel", scene.find_child("HandoverPanel", true, false))
	scene.set("_hand_container", HBoxContainer.new())
	scene.call("_setup_detail_preview")
	return scene


func _count_pointer_blocking_children(node: Node, ignored: Node = null) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child == ignored:
			continue
		var control := child as Control
		if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			count += 1
		count += _count_pointer_blocking_children(child, ignored)
	return count


func _prepare_overflowing_hand_scroll_for_drag_test(hand_scroll: ScrollContainer) -> void:
	if hand_scroll == null:
		return
	hand_scroll.size = Vector2(400, 200)
	hand_scroll.custom_minimum_size = Vector2(400, 200)
	var hand_content := hand_scroll.get_child(0) as Control if hand_scroll.get_child_count() > 0 else null
	if hand_content != null:
		hand_content.size = Vector2(1400, 180)
		hand_content.custom_minimum_size = Vector2(1400, 180)
	var hbar := hand_scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1000.0
		hbar.page = 400.0


func _attach_test_center_field(scene: Control, position: Vector2, size: Vector2) -> Control:
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2.ZERO
	main_area.size = Vector2(1280, 720)
	scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = position
	center_field.size = size
	main_area.add_child(center_field)
	return center_field


func _attach_test_field_area(scene: Control, center_field_position: Vector2, center_field_size: Vector2, field_area_position: Vector2, field_area_size: Vector2) -> Control:
	var center_field := _attach_test_center_field(scene, center_field_position, center_field_size)
	var field_area := Control.new()
	field_area.name = "FieldArea"
	field_area.position = field_area_position
	field_area.size = field_area_size
	center_field.add_child(field_area)
	return field_area


func _attach_test_main_area_with_hand_area(
	scene: Control,
	main_area_position: Vector2,
	main_area_size: Vector2,
	center_field_position: Vector2,
	center_field_size: Vector2,
	hand_area_position: Vector2,
	hand_area_size: Vector2,
	log_panel_position: Vector2 = Vector2(-1, -1),
	log_panel_size: Vector2 = Vector2.ZERO
) -> Dictionary:
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = main_area_position
	main_area.size = main_area_size
	scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = center_field_position
	center_field.size = center_field_size
	main_area.add_child(center_field)

	var hand_area := Control.new()
	hand_area.name = "HandArea"
	hand_area.position = hand_area_position
	hand_area.size = hand_area_size
	center_field.add_child(hand_area)

	var log_panel: Control = null
	if log_panel_position.x >= 0.0 and log_panel_position.y >= 0.0:
		log_panel = Control.new()
		log_panel.name = "LogPanel"
		log_panel.position = log_panel_position
		log_panel.size = log_panel_size
		main_area.add_child(log_panel)

	return {
		"main_area": main_area,
		"center_field": center_field,
		"hand_area": hand_area,
		"log_panel": log_panel,
	}


func _sample_raw_replay_snapshot() -> Dictionary:
	return {
		"event_type": "state_snapshot",
		"turn_number": 6,
		"phase": "main",
		"player_index": 1,
		"snapshot_reason": "turn_start",
		"state": {
			"turn_number": 6,
			"phase": "main",
			"current_player_index": 1,
			"first_player_index": 0,
			"winner_index": -1,
			"win_reason": "",
			"energy_attached_this_turn": false,
			"supporter_used_this_turn": false,
			"stadium_played_this_turn": false,
			"retreat_used_this_turn": false,
			"stadium_card": {},
			"stadium_owner_index": -1,
			"players": [
				{
					"player_index": 0,
					"hand": [],
					"deck": [],
					"prizes": [],
					"discard_pile": [],
					"lost_zone": [],
					"active": {
						"damage_counters": 0,
						"retreat_cost": 1,
						"attached_energy": [],
						"attached_tool": {},
						"status_conditions": {"poisoned": false, "burned": false, "asleep": false, "paralyzed": false, "confused": false},
						"effects": [],
						"turn_played": 4,
						"turn_evolved": -1,
						"pokemon_stack": [{
							"card_name": "Opponent Active",
							"instance_id": 10,
							"owner_index": 0,
							"face_up": true,
							"card_type": "Pokemon",
							"stage": "Basic",
							"hp": 70,
							"energy_type": "P",
							"effect_id": "",
							"energy_provides": "",
							"attacks": [],
							"abilities": [],
						}],
					},
					"bench": [],
				},
				{
					"player_index": 1,
					"hand": [{
						"card_name": "Switch",
						"instance_id": 20,
						"owner_index": 1,
						"face_up": true,
						"card_type": "Trainer",
						"stage": "",
						"hp": 0,
						"energy_type": "",
						"effect_id": "",
						"energy_provides": "",
						"attacks": [],
						"abilities": [],
					}],
					"deck": [],
					"prizes": [],
					"discard_pile": [],
					"lost_zone": [],
					"active": {
						"damage_counters": 0,
						"retreat_cost": 1,
						"attached_energy": [],
						"attached_tool": {},
						"status_conditions": {"poisoned": false, "burned": false, "asleep": false, "paralyzed": false, "confused": false},
						"effects": [],
						"turn_played": 5,
						"turn_evolved": -1,
						"pokemon_stack": [{
							"card_name": "Player Active",
							"instance_id": 21,
							"owner_index": 1,
							"face_up": true,
							"card_type": "Pokemon",
							"stage": "Basic",
							"hp": 120,
							"energy_type": "R",
							"effect_id": "",
							"energy_provides": "",
							"attacks": [{"name": "Test", "cost": "R", "damage": "30", "text": "", "is_vstar_power": false}],
							"abilities": [],
						}],
					},
					"bench": [],
				},
			],
		},
	}


func _make_regidrago_vstar_cd() -> CardData:
	var cd := CardData.new()
	cd.name = "Regidrago VSTAR"
	cd.card_type = "Pokemon"
	cd.stage = "VSTAR"
	cd.hp = 280
	cd.energy_type = "N"
	cd.mechanic = "V"
	cd.effect_id = "749d2f12d33057c8cc20e52c1b11bcbf"
	cd.attacks = [{
		"name": "Apex Dragon",
		"cost": "GGR",
		"damage": "",
		"text": "Choose an attack from a Dragon Pokemon in your discard pile and use it as this attack.",
		"is_vstar_power": false,
	}]
	return cd


func _make_dragapult_ex_cd() -> CardData:
	var cd := CardData.new()
	cd.name = "Dragapult ex"
	cd.card_type = "Pokemon"
	cd.stage = "Stage 2"
	cd.hp = 320
	cd.energy_type = "N"
	cd.mechanic = "ex"
	cd.effect_id = "52a205820de799a53a689f23cbeb8622"
	cd.attacks = [
		{"name": "Jet Headbutt", "cost": "C", "damage": "70", "text": "", "is_vstar_power": false},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "", "is_vstar_power": false},
	]
	return cd


# ===================== 投币测试 =====================

## 测试：CoinFlipper 的 coin_flipped 信号是否正确发出
func legacy_battle_scene_earthen_vessel_empty_search_preview_can_be_opened_and_consumes_card() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Deck Pokemon", 90, "C"), 0),
	])

	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	player.hand.append_array([earthen_vessel, discard_cost])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var resolution_title := (battle_scene.get("_dialog_title") as Label).text
	var resolution_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_str_contains(first_step_title, "弃", "Earthen Vessel should still ask the player to pay its discard cost first"),
		assert_str_contains(resolution_title, "没有", "After paying the discard cost, Earthen Vessel should explain that no Basic Energy were found"),
		assert_eq(resolution_items.size(), 2, "Earthen Vessel whiffs should offer continue and preview options"),
		assert_str_contains(preview_title, "牌库", "Choosing preview after an Earthen Vessel whiff should open the deck preview"),
		assert_eq(preview_items.size(), 2, "Earthen Vessel whiff previews should show the remaining deck"),
		assert_true(earthen_vessel in player.discard_pile, "Earthen Vessel should still be consumed after closing the empty-search preview"),
		assert_true(discard_cost in player.discard_pile, "Earthen Vessel should still discard the paid cost card on a whiff"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the empty-search preview, the trainer interaction should finish cleanly"),
	])


func _run_self_knockout_damage_counters_field_target_test(counter_count: int, expected_damage: int, effect_id: String) -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Own Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot
	var self_ko_cd := _make_pokemon_cd("Self KO", 90, "P")
	self_ko_cd.effect_id = effect_id
	self_ko_cd.abilities = [{"name": "Cursed Blast", "text": ""}]
	var self_ko_card := CardInstance.create(self_ko_cd, 0)
	var self_ko_slot := PokemonSlot.new()
	self_ko_slot.pokemon_stack.append(self_ko_card)
	gsm.game_state.players[0].bench = [self_ko_slot]
	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active
	var opp_bench := PokemonSlot.new()
	opp_bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench", 220, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench]

	var effect := AbilitySelfKnockoutDamageCountersScript.new(counter_count)
	gsm.effect_processor.register_effect(effect_id, effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(self_ko_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "ability", 0, steps, self_ko_card, self_ko_slot, 0)
	var field_item_count := int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size())
	var target_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	var bench_slot_id := str(battle_scene.call("_slot_id_from_slot", opp_bench))
	var bench_target_index := int(target_map.get(bench_slot_id, -1))
	var field_mode := str(battle_scene.get("_field_interaction_mode"))
	var field_position := str(battle_scene.get("_field_interaction_position"))

	battle_scene.call("_try_handle_field_interaction_slot_click", bench_slot_id, opp_bench)

	return run_checks([
		assert_true(bench_target_index >= 0, "Self-KO ability should expose the opponent Bench target as selectable"),
		assert_eq(opp_active.damage_counters, 0, "Self-KO ability should not fall back to the opponent Active when Bench was selected"),
		assert_eq(opp_bench.damage_counters, expected_damage, "Self-KO ability should place counters on the selected Bench target"),
		assert_eq(field_mode, "slot_select", "自爆放伤害指示物应在场上选择对手目标"),
		assert_eq(field_position, "bottom", "攻击对方场上的特性目标面板应下移"),
		assert_eq(field_item_count, 2, "应展示对手全部可选宝可梦"),
	])


func _first_action_hud_option(scene: Control) -> Control:
	var dialog_card_row := scene.get("_dialog_card_row") as HBoxContainer
	if dialog_card_row == null:
		return null
	return _action_hud_option_at_index(scene, 0)


func _dialog_rendered_choice_count(scene: Control) -> int:
	var row := _dialog_rendered_choice_row(scene)
	return row.get_child_count() if row != null else 0


func _dialog_rendered_choice_card_view(scene: Control, index: int) -> BattleCardView:
	var row := _dialog_rendered_choice_row(scene)
	if row == null or index < 0 or index >= row.get_child_count():
		return null
	return _first_battle_card_view(row.get_child(index))


func _dialog_rendered_choice_row(scene: Control) -> HBoxContainer:
	if scene == null:
		return null
	if bool(scene.get("_dialog_library_search_board_mode")):
		var library_row := scene.find_child("LibraryCardRow", true, false) as HBoxContainer
		if library_row != null:
			return library_row
	return scene.get("_dialog_card_row") as HBoxContainer


func _first_battle_card_view(node: Node) -> BattleCardView:
	if node == null:
		return null
	var direct := node as BattleCardView
	if direct != null:
		return direct
	for child: Node in node.get_children():
		var found := _first_battle_card_view(child)
		if found != null:
			return found
	return null


func _action_hud_option_at_index(scene: Control, action_index: int) -> Control:
	var dialog_card_row := scene.get("_dialog_card_row") as HBoxContainer
	if dialog_card_row == null:
		return null
	var current_index := 0
	for child: Node in dialog_card_row.get_children():
		if not child is VBoxContainer:
			continue
		for option: Node in child.get_children():
			if option is Control:
				if current_index == action_index:
					return option as Control
				current_index += 1
	return null


func _emit_action_hud_mouse_click(option: Control, local_position: Vector2 = Vector2(18, 18), global_position: Vector2 = Vector2(360, 180)) -> void:
	if option == null:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local_position
	press.global_position = global_position
	option.emit_signal("gui_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = local_position
	release.global_position = global_position
	option.emit_signal("gui_input", release)


func _emit_action_hud_mouse_release(option: Control, local_position: Vector2 = Vector2(18, 18), global_position: Vector2 = Vector2(360, 180)) -> void:
	if option == null:
		return
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = local_position
	release.global_position = global_position
	option.emit_signal("gui_input", release)


func _emit_action_hud_touch_tap(option: Control, touch_index: int, position: Vector2) -> void:
	if option == null:
		return
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = touch_index
	press.position = position
	option.emit_signal("gui_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = touch_index
	release.position = position
	option.emit_signal("gui_input", release)


func _emit_slot_mouse_click(scene: Control, slot_id: String, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	scene.call("_on_slot_input", press, slot_id)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	scene.call("_on_slot_input", release, slot_id)


func _emit_slot_touch_tap(scene: Control, slot_id: String, touch_index: int, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = touch_index
	press.position = position
	scene.call("_on_slot_input", press, slot_id)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = touch_index
	release.position = position
	scene.call("_on_slot_input", release, slot_id)


func _make_portrait_retreat_action_hud_scene() -> Control:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Portrait Tap Active", 120, "C")
	active_cd.attacks = []
	active_cd.abilities = []
	active_cd.retreat_cost = 0
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	game_state.players[0].active_pokemon = active_slot

	var bench_slot := PokemonSlot.new()
	var bench_cd := _make_pokemon_cd("Retreat Receiver", 90, "C")
	bench_cd.attacks = []
	bench_cd.abilities = []
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	game_state.players[0].bench.append(bench_slot)

	var opp_active := PokemonSlot.new()
	var opp_cd := _make_pokemon_cd("Opponent Active", 120, "C")
	opp_cd.attacks = []
	opp_cd.abilities = []
	opp_active.pokemon_stack.append(CardInstance.create(opp_cd, 1))
	game_state.players[1].active_pokemon = opp_active

	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _make_koraidon_action_hud_scene(layout_mode: String = "portrait") -> Control:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", layout_mode)
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Koraidon", 130, "F")
	active_cd.effect_id = "41dd160743c1707676c4faa6759c718b"
	active_cd.attacks = [
		{"name": "Primitive Beatdown", "cost": "CC", "damage": "30+", "text": "If another Ancient Pokemon attacked during your last turn, this attack does 150 more damage.", "is_vstar_power": false},
		{"name": "Headbutt", "cost": "FFC", "damage": "110", "text": "", "is_vstar_power": false},
	]
	active_cd.abilities = []
	active_cd.retreat_cost = 2
	active_cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting A", "F"), 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting B", "F"), 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless", "C"), 0))
	game_state.players[0].active_pokemon = active_slot

	var bench_slot := PokemonSlot.new()
	var bench_cd := _make_pokemon_cd("Ancient Bench", 90, "F")
	bench_cd.attacks = []
	bench_cd.abilities = []
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	game_state.players[0].bench.append(bench_slot)

	var opp_active := PokemonSlot.new()
	var opp_cd := _make_pokemon_cd("Opponent Active", 300, "C")
	opp_cd.attacks = []
	opp_cd.abilities = []
	opp_active.pokemon_stack.append(CardInstance.create(opp_cd, 1))
	game_state.players[1].active_pokemon = opp_active

	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _make_portrait_koraidon_action_hud_scene() -> Control:
	return _make_koraidon_action_hud_scene("portrait")


func _make_rotated_portrait_koraidon_action_hud_scene() -> Control:
	var battle_scene := _make_koraidon_action_hud_scene("portrait")
	battle_scene.set("_rotated_portrait_canvas_active", true)
	battle_scene.set("_rotated_portrait_physical_viewport_size", Vector2(1600, 900))
	return battle_scene


func _make_lugia_vstar_action_hud_scene(rotated_portrait: bool = false) -> Control:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	if rotated_portrait:
		battle_scene.set("_rotated_portrait_canvas_active", true)
		battle_scene.set("_rotated_portrait_physical_viewport_size", Vector2(1600, 900))

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	game_state.turn_number = 4
	game_state.vstar_power_used = [false, false]
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	var lugia_cd := _make_pokemon_cd("Lugia VSTAR", 280, "C")
	lugia_cd.name_en = "Lugia VSTAR"
	lugia_cd.stage = "VSTAR"
	lugia_cd.mechanic = "V"
	lugia_cd.effect_id = "b219587ea29cd6901c83f698ed25f052"
	lugia_cd.abilities = [{"name": "星耀汇聚", "text": "Put up to 2 Colorless Pokemon from your discard pile onto your Bench."}]
	lugia_cd.attacks = [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220", "text": "", "is_vstar_power": false}]
	lugia_cd.retreat_cost = 2
	gsm.effect_processor.register_pokemon_card(lugia_cd)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(lugia_cd, 0))
	for i: int in 4:
		active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lugia Energy %d" % i, "C"), 0))
	game_state.players[0].active_pokemon = active_slot

	var archeops_cd := _make_pokemon_cd("Archeops", 150, "C")
	archeops_cd.name_en = "Archeops"
	archeops_cd.stage = "Stage 2"
	archeops_cd.mechanic = ""
	archeops_cd.abilities = []
	archeops_cd.attacks = [{"name": "Speed Wing", "cost": "CCC", "damage": "120", "text": "", "is_vstar_power": false}]
	game_state.players[0].discard_pile.append(CardInstance.create(archeops_cd, 0))

	var opp_active := PokemonSlot.new()
	var opp_cd := _make_pokemon_cd("Opponent Active", 300, "C")
	opp_cd.attacks = []
	opp_cd.abilities = []
	opp_active.pokemon_stack.append(CardInstance.create(opp_cd, 1))
	game_state.players[1].active_pokemon = opp_active

	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _prepare_real_portrait_battle_scene() -> Control:
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_handover_panel", battle_scene.find_child("HandoverPanel", true, false))
	battle_scene.set("_my_prizes_title", battle_scene.find_child("MyPrizesLbl", true, false))
	battle_scene.set("_opp_prizes_title", battle_scene.find_child("OppPrizesLbl", true, false))
	battle_scene.set("_my_prize_hud_title", battle_scene.find_child("MyHudLeftTitle", true, false))
	battle_scene.set("_opp_prize_hud_title", battle_scene.find_child("OppHudLeftTitle", true, false))
	battle_scene.set("_my_hud_left", battle_scene.find_child("MyHudLeft", true, false))
	battle_scene.set("_opp_hud_left", battle_scene.find_child("OppHudLeft", true, false))
	battle_scene.set("_my_prize_hud_host", battle_scene.find_child("MyPrizeHudHost", true, false))
	battle_scene.set("_opp_prize_hud_host", battle_scene.find_child("OppPrizeHudHost", true, false))
	battle_scene.set("_my_deck_hud_box", battle_scene.find_child("MyDeckHudBox", true, false))
	battle_scene.set("_opp_deck_hud_box", battle_scene.find_child("OppDeckHudBox", true, false))
	battle_scene.set("_my_discard_hud_box", battle_scene.find_child("MyDiscardHudBox", true, false))
	battle_scene.set("_opp_discard_hud_box", battle_scene.find_child("OppDiscardHudBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	battle_scene.call("_setup_side_previews")
	battle_scene.call("_setup_prize_viewer")
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _make_real_portrait_lugia_vstar_knockout_scene() -> Control:
	var battle_scene := _prepare_real_portrait_battle_scene()
	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	game_state.turn_number = 4
	game_state.vstar_power_used = [false, false]
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	var lugia_cd := _make_pokemon_cd("Lugia VSTAR", 280, "C")
	lugia_cd.name_en = "Lugia VSTAR"
	lugia_cd.stage = "VSTAR"
	lugia_cd.mechanic = "V"
	lugia_cd.effect_id = "b219587ea29cd6901c83f698ed25f052"
	lugia_cd.abilities = [{"name": "Summoning Star", "text": "Put up to 2 Colorless Pokemon from your discard pile onto your Bench."}]
	lugia_cd.attacks = [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220", "text": "", "is_vstar_power": false}]
	lugia_cd.retreat_cost = 2
	gsm.effect_processor.register_pokemon_card(lugia_cd)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(lugia_cd, 0))
	for i: int in 4:
		active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Lugia Energy %d" % i, "C"), 0))
	game_state.players[0].active_pokemon = active_slot

	var archeops_cd := _make_pokemon_cd("Archeops", 150, "C")
	archeops_cd.name_en = "Archeops"
	archeops_cd.stage = "Stage 2"
	archeops_cd.mechanic = ""
	archeops_cd.abilities = []
	archeops_cd.attacks = [{"name": "Speed Wing", "cost": "CCC", "damage": "120", "text": "", "is_vstar_power": false}]
	game_state.players[0].discard_pile.append(CardInstance.create(archeops_cd, 0))

	var opp_active := PokemonSlot.new()
	var opp_cd := _make_pokemon_cd("Opponent Active", 300, "C")
	opp_cd.attacks = []
	opp_cd.abilities = []
	opp_active.pokemon_stack.append(CardInstance.create(opp_cd, 1))
	opp_active.damage_counters = 80
	game_state.players[1].active_pokemon = opp_active

	for i: int in 6:
		game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Lugia Dialog Prize %d" % i, 60, "C"), 0))

	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	return battle_scene


func _make_landscape_charmander_tm_evolution_action_hud_scene() -> Control:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "landscape")

	var gsm := GameStateMachine.new()
	var game_state := GameState.new()
	game_state.current_player_index = 0
	game_state.phase = GameState.GamePhase.MAIN
	game_state.turn_number = 4
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		game_state.players.append(player)

	var charmander_cd := _make_pokemon_cd("小火龙", 70, "R")
	charmander_cd.name_en = "Charmander"
	charmander_cd.attacks = []
	charmander_cd.abilities = []
	charmander_cd.retreat_cost = 1
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(charmander_cd, 0))
	game_state.players[0].active_pokemon = active_slot

	var bench_cd := _make_pokemon_cd("Bench Basic", 70, "R")
	bench_cd.attacks = []
	bench_cd.abilities = []
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	game_state.players[0].bench = [bench_slot]

	var evo_cd := _make_pokemon_cd("Bench Evolution", 110, "R")
	evo_cd.stage = "Stage 1"
	evo_cd.evolves_from = "Bench Basic"
	game_state.players[0].deck = [CardInstance.create(evo_cd, 0)]

	var fire_energy := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var tm_cd := _make_trainer_cd("Technical Machine: Evolution", "Tool", "")
	tm_cd.effect_id = "43386015be5c073ba2e5b9d3692ece3f"
	var tm_evolution := CardInstance.create(tm_cd, 0)
	game_state.players[0].hand = [fire_energy, tm_evolution]

	var opp_active := PokemonSlot.new()
	var opp_cd := _make_pokemon_cd("Opponent Active", 120, "C")
	opp_cd.attacks = []
	opp_cd.abilities = []
	opp_active.pokemon_stack.append(CardInstance.create(opp_cd, 1))
	game_state.players[1].active_pokemon = opp_active

	gsm.game_state = game_state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	(battle_scene.get("_dialog_overlay") as Panel).visible = false
	(battle_scene.get("_handover_panel") as Panel).visible = false
	return battle_scene


func _send_prize_card_view_input(prize_slot: BattleCardView, input_mode: String) -> void:
	if input_mode == "touch":
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 0
		press.position = Vector2(24, 24)
		prize_slot.call("_gui_input", press)
		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.index = 0
		release.position = Vector2(24, 24)
		prize_slot.call("_gui_input", release)
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(24, 24)
	click.global_position = Vector2(24, 24)
	prize_slot.call("_gui_input", click)


