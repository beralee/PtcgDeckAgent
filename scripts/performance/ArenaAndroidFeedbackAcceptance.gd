extends "res://scripts/performance/ArenaAndroidInputAcceptance.gd"
## Synthetic public boards, real effect owners and Viewport touch. No AI/network.
class QuietBattle extends "res://scenes/battle/BattleScene.gd":
	func _maybe_run_ai() -> void: pass

var requested_window := Vector2i(1080,1920)
var reward_samples: Array[Dictionary] = []

func _run() -> void:
	get_tree().create_timer(145).timeout.connect(func(): _fail("feedback_timeout"))
	if OS.get_name() != "Android":
		get_tree().root.size = requested_window
		get_tree().root.content_scale_size = requested_window
	await _settle(.5)
	tested_window = get_tree().root.size
	if not _check(tested_window == requested_window,"feedback_requested_window"): return
	battle = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(.5)
	battle.call("_apply_non_battle_layout_for_tests",battle.get_viewport_rect().size,"portrait" if tested_window.y > tested_window.x else "landscape")
	await _settle(.3)
	var quit: Control = battle.get_node("%BtnQuit")
	var share: Control = battle.get("_share_button")
	if not _check(battle.get_viewport_rect().encloses(quit.get_global_rect()) and not quit.get_global_rect().intersects(share.get_global_rect()),"home_all_buttons_fit_clear_of_footer"): return
	await _capture("platform-feedback-home.png")
	if not await _home_modal_input(): return
	battle.queue_free()
	await get_tree().process_frame
	GameManager.battle_3d_enabled = true
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT if tested_window.y > tested_window.x else GameManager.BATTLE_LAYOUT_LANDSCAPE
	preload("res://scenes/arena3d/ArenaTheme.gd").save_option("motion",true)
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle.set_script(QuietBattle)
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(.7)
	p = battle.get_node("Arena3DPresenter")
	await _resize(tested_window)
	var gs := _feedback_fixture()
	gs.players[1].active_pokemon.set_status("poisoned",true)
	gs.players[1].active_pokemon.attached_tool = CardInstance.create(CardDatabase.get_card("CSV1C","118"),1)
	await _stage(gs)
	await _capture("platform-feedback-readable-board.png")
	if not await _hotseat_piles(): return
	await _stage(gs)
	await _tap_slot("opp_active")
	if not _check(battle.get("_detail_overlay").visible,"opponent_tap_opens_details"): return
	var text: String = battle.get("_detail_content").text
	if not _check("中毒" in text and "能量" in text and "道具" in text and "HP" in text,"detail_public_resources_and_status"): return
	await _capture("platform-feedback-opponent-detail.png")
	await _tap_control(battle.get("_detail_close_btn"))
	await _settle(.4)
	if not await _dragapult_three_prizes(): return
	if not await _gardevoir_repeats(): return
	if not await _reward_gallery(): return
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"platform":OS.get_name(),"window":[tested_window.x,tested_window.y],"kind":"arena_feedback_touch_acceptance","three_prizes":true,"reward_samples":reward_samples}))
	print("ARENA_FEEDBACK_ACCEPTANCE_PASS")
	get_tree().quit(0)

func _feedback_fixture() -> GameState:
	var gs := _live_fixture()
	for pi in 2:
		for i in 5: gs.players[pi].bench.append(_slot("CSV8C","094",pi))
	return gs

func _home_modal_input() -> bool:
	var footer: Array[Button] = []
	var presses := [0]
	for property in ["_non_battle_orientation_button","_feedback_button","_about_button","_manual_update_button","_share_button"]:
		var button: Button = battle.get(property)
		footer.append(button)
		button.pressed.connect(func(): presses[0] += 1)
	# Real footer activation opens the existing about modal; subsequent touches
	# and native mouse clicks must stay in that modal, including outside its panel.
	await _tap_control(battle.get("_about_button"))
	var overlay: Control = battle.call("_active_modal_overlay")
	if not _check(overlay != null,"footer_about_opens_once"): return false
	var baseline: int = presses[0]
	if not _check(baseline == 1,"footer_single_activation"): return false
	for button: Button in footer:
		var point := button.get_global_rect().get_center()
		await _tap_control(button)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			get_tree().root.push_input(event,true)
			await get_tree().process_frame
	if presses[0] != baseline or battle.call("_active_modal_overlay") != overlay:
		await _capture("platform-feedback-footer-failure.png")
		print("FOOTER_MODAL_DIAGNOSTIC ",JSON.stringify({"presses":presses[0],"baseline":baseline,"overlay_rect":str(overlay.get_global_rect()) if is_instance_valid(overlay) else "freed"}))
	if not _check(presses[0] == baseline and battle.call("_active_modal_overlay") == overlay,"all_footer_mouse_touch_blocked_under_modal"): return false
	await _capture("platform-feedback-footer-modal.png")
	# Release echoes after dismiss must not activate any newly exposed control.
	battle.call("_hide_hud_modal")
	await _touch(footer.back().get_global_rect().get_center(),false)
	if not _check(presses[0] == baseline,"footer_dismiss_release_drained"): return false
	await _settle(.3)
	await _tap_control(battle.get("_about_button"))
	if not _check(presses[0] == baseline+1 and battle.call("_active_modal_overlay") != null,"footer_works_after_modal_dismiss"): return false
	battle.call("_hide_hud_modal")
	return true

func _hotseat_piles() -> bool:
	var mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var gs := _feedback_fixture()
	gs.players[0].discard_pile.append(gs.players[0].deck.pop_back())
	for i in 3: gs.players[1].discard_pile.append(gs.players[1].deck.pop_back())
	await _stage(gs)
	for view in [0,1,0]:
		battle.set("_view_player",view)
		p.motion.clear()
		if int(p.motion.shown.get("view",0)) != view: p.motion.hold = 1.0
		p._refresh()
		if not _check(int(p.board_hud.frame.view) == view,"hotseat_view_changes_atomically_even_during_hold"): return false
		await _settle(.3)
		for side in ["my","opp"]:
			var owner: int = view if side == "my" else 1-view
			if not _check(p.world.side_zones.piles[side+"_deck"].count == gs.players[owner].deck.size(),"hotseat_deck_count_"+str(view)+side): return false
			if not _check(p.world.side_zones.piles[side+"_discard"].count == gs.players[owner].discard_pile.size(),"hotseat_discard_count_"+str(view)+side): return false
			await _tap_control(p.zone_buttons[side+"_discard"])
			if not _check(battle.get("_discard_overlay").visible and battle.get("_discard_collection_current_player_index") == owner,"hotseat_discard_tap_owner_"+str(view)+side): return false
			await _capture("platform-feedback-hotseat-%d-%s.png" % [view,side])
			await _tap_control(battle.get("_discard_close_btn"))
			await _settle(.3)
	GameManager.current_mode = mode
	return true

func _stage(gs: GameState) -> void:
	battle.call("_release_game_state_machine")
	battle.set("_gsm",battle.call("_build_game_state_machine"))
	battle.call("_sync_battle_scene_context_runtime")
	for pi in 2:
		for slot: PokemonSlot in gs.players[pi].get_all_pokemon():
			battle.get("_gsm").effect_processor.register_pokemon_card(slot.get_card_data())
		var player: PlayerState = gs.players[pi]
		battle.get("_gsm").game_state = gs
		while battle.get("_gsm").count_player_total_cards(pi) > 60: player.deck.pop_back()
		while battle.get("_gsm").count_player_total_cards(pi) < 60: player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
	battle.set("_pending_prize_animating",false)
	battle.set("_pending_prize_remaining",0)
	battle.set("_pending_prize_player_index",-1)
	battle.call("_hide_field_interaction")
	battle.call("_hide_card_detail")
	p.motion.shown = {}
	p.ability_observed = {}
	await _install_live_fixture(gs)
	var notice := battle.get_node_or_null("MulliganNotice")
	if notice != null: notice.hide()
	await _wait_idle()

func _tap_slot(id: String) -> void:
	await _touch(_card_point(id),true)
	await _touch(_card_point(id),false)
	await _settle(.1)

func _button_containing(node: Node, words: String) -> Control:
	if node is Control and not node.is_visible_in_tree(): return null
	if node is Button and node.is_visible_in_tree() and not node.disabled and words in node.text: return node
	if node is Label and words in node.text:
		var parent := node.get_parent()
		while parent != null:
			if parent is Control and not parent.gui_input.get_connections().is_empty(): return parent
			parent = parent.get_parent()
	for child in node.get_children():
		var found := _button_containing(child,words)
		if found != null: return found
	return null

func _wait_idle() -> void:
	for i in 160:
		if not p.motion.is_busy():
			await _settle(.12)
			return
		await _settle(.05)
	_check(false,"presentation_finishes_within_eight_seconds")

func _dragapult_three_prizes() -> bool:
	var gs := _feedback_fixture()
	gs.players[0].active_pokemon.attached_energy.clear()
	for kind: String in ["FIR","PSY"]: gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C",kind),0))
	gs.players[1].active_pokemon.damage_counters = 120
	gs.players[1].bench[0] = _slot("CSV9.5C","004",1)
	await _stage(gs)
	var gsm: GameStateMachine = battle.get("_gsm")
	await _tap_slot("my_active")
	print("FEEDBACK_ATTACK_INPUT ",JSON.stringify({"pending":battle.get("_pending_choice"),"modal":battle.call("_is_board_modal_overlay_visible"),"can":battle.call("_can_view_player_start_turn_action"),"busy":p.motion.is_busy(),"target":p.touch_target(_card_point("my_active")).get("kind","")}))
	await _capture("platform-feedback-attack-choices.png")
	var attack := _button_containing(battle,"幻影潜袭")
	if not _check(attack != null,"phantom_dive_touch_action_available"): return false
	await _tap_control(attack)
	# Use the current six-counter assignment, then select its public target by tap.
	battle.call("_on_counter_distribution_amount_chosen",6)
	await _settle(.2)
	await _tap_slot("opp_bench_0")
	if not _check(int(gsm.get("_pending_prize_remaining")) == 2,"phantom_dive_commits_active_knockout"): return false
	if not _check(not battle.get("_detail_overlay").visible,"opponent_tap_still_selects_effect_target"): return false
	if not _check(not p.board_hud.prize_ready and p.motion.is_busy(),"attack_finishes_before_prize_selection"): return false
	await _capture("platform-feedback-phantom-attack.png")
	await _wait_idle()
	for picked in 3:
		if picked == 2 and int(gsm.get("_pending_prize_remaining")) == 0:
			# Opponent's replacement window is an independent legal decision.
			# The probe has no running AI: resolve its currently legal survivor.
			if not _check(gsm.send_out_pokemon(1,gs.players[1].bench[1]),"opponent_replacement_before_remaining_prize"): return false
			await _wait_idle()
		await _settle(.25)
		var button: Button
		for candidate: Button in p.prize_buttons:
			if candidate.visible and not candidate.disabled:
				button = candidate
				break
		if not _check(button != null,"all_three_prize_choices_available_"+str(picked)): return false
		await _tap_control(button)
		if not _check(gs.players[0].prizes.size() == 5-picked,"touch_awards_one_prize_"+str(picked)): return false
		await _wait_idle()
		await _settle(.4)
	if not _check(gs.players[0].prizes.size() == 3,"all_three_prizes_received"): return false
	if not _check(p.motion.reward_history.back() == 3,"sequential_knockouts_reach_three_prize_celebration"): return false
	await _capture("platform-feedback-three-prizes-complete.png")
	return true

func _gardevoir_repeats() -> bool:
	var gs := _feedback_fixture()
	gs.players[0].active_pokemon = _slot("CSV2C","055",0)
	gs.players[0].bench[0] = _slot("CSV2C","055",0)
	for i in 3: gs.players[0].discard_pile.append(CardInstance.create(CardDatabase.get_card("CSVE1C","PSY"),0))
	await _stage(gs)
	var recipient := gs.players[0].bench[0]
	var initial: int = p.motion.embrace_repeats
	for use in 3:
		await _tap_slot("my_active")
		var ability := _button_containing(battle,"精神拥抱")
		if not _check(ability != null,"psychic_embrace_touch_available_"+str(use)): return false
		await _tap_control(ability)
		battle.call("_handle_effect_interaction_choice",PackedInt32Array([0]))
		var steps: Array = battle.get("_pending_effect_steps")
		var step: Dictionary = steps[int(battle.get("_pending_effect_step_index"))]
		var offered: Array = step.get("items",[])
		if not _check(offered.has(recipient),"fresh_embrace_target_offered"): return false
		# Choice is rebound from each new interaction window; never reuse indexes.
		battle.call("_handle_effect_interaction_choice",PackedInt32Array([offered.find(recipient)]))
		if not _check(recipient.attached_energy.size() == use+1 and recipient.damage_counters == (use+1)*20,"embrace_energy_and_damage_commit_"+str(use)): return false
		if use == 0:
			await _settle(.7)
			await _capture("platform-feedback-gardevoir-first.png")
			await _wait_idle()
		else:
			print("EMBRACE_REPEAT ",JSON.stringify({"use":use,"key":p.motion.last_embrace_key,"repeats":p.motion.embrace_repeats,"busy":p.motion.busy_time,"hand":p.motion.hand_transfer.is_busy(),"played":p.world.signature_vfx.played}))
			if not _check(not p.motion.is_busy(),"repeat_embrace_has_no_cinematic_wait"): return false
			await _settle(.12)
	await _capture("platform-feedback-gardevoir-repeat.png")
	return _check(p.motion.embrace_repeats == initial+2,"two_repeats_use_short_target_pulses")

func _reward_gallery() -> bool:
	for count in range(1,7):
		var gs := _feedback_fixture()
		gs.players[0].active_pokemon.attached_energy.clear()
		for kind: String in ["FIR","PSY"]: gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C",kind),0))
		# Public, synthetic prize modifier exercises all six tiers through real KO.
		gs.players[1].active_pokemon.damage_counters = 250
		gs.players[1].active_pokemon.effects.append({"type":"extra_prize","count":count-2})
		await _stage(gs)
		var gsm: GameStateMachine = battle.get("_gsm")
		var history: int = p.motion.reward_history.size()
		if not _check(gsm.use_attack(0,0),"gallery_real_attack"): return false
		# The 70-damage attack uses an already injured defender for this fixture.
		for i in 140:
			if p.motion.reward_history.size() > history: break
			await _settle(.05)
		if not _check(p.motion.reward_history.size() == history+1,"tier_celebration_started_"+str(count)): return false
		await _settle(.12)
		await _capture("platform-feedback-reward-ball-%d.png" % count)
		await _settle(.75)
		await _capture("platform-feedback-reward-%d.png" % count)
		reward_samples.append({"count":count,"presented":p.motion.reward_history.back(),"prize_ready":p.board_hud.prize_ready})
		if not _check(p.motion.reward_history.back() == count and not p.board_hud.prize_ready and not battle.get("_dialog_overlay").visible,"correct_tier_before_selection_without_legacy_popup"): return false
		await _wait_idle()
		if count == 1:
			for button: Button in p.prize_buttons:
				if not _check(button.visible and button.icon != null and button.size.y > button.size.x,"six_full_card_backs_after_animation"): return false
			await _capture("platform-feedback-six-prize-cards.png")
	return true
