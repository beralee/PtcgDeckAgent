extends "res://scripts/performance/ArenaAndroidInputAcceptance.gd"
## Actual setup/verified strategy startup, then deterministic public action fixtures.
## No presenter calls, direct VFX calls, or forced enabled-motion state in battle.
var author_ref: Dictionary = {}
var saw_late_engine := false
var requested_window := Vector2i.ZERO

func _run() -> void:
	get_tree().create_timer(150).timeout.connect(func(): _fail("live_entry_timeout"))
	if not _check(not author_ref.is_empty(),"verified_strategy_fixture_installed"): return
	# Reproduce an old installation with a disabled, previously unreachable 3D flag.
	preload("res://scenes/arena3d/ArenaTheme.gd").save_option("motion",false)
	GameManager.battle_effects_enabled = false
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	get_tree().root.add_child(setup)
	get_tree().current_scene = setup
	await _settle(1)
	setup.call("_select_background_path",preload("res://scripts/ui/battle/BattlePresentation.gd").GROVE_FIELD)
	setup.call("_on_deck_picker_author_strategy_selected",author_ref)
	setup.call("_on_deck_picker_deck_selected",0,575720)
	setup.find_child("FirstPlayerOption",true,false).select(1)
	setup.call("_select_battle_layout_mode",GameManager.BATTLE_LAYOUT_PORTRAIT if requested_window.y > requested_window.x else GameManager.BATTLE_LAYOUT_LANDSCAPE)
	setup.get_node("%BattleEffectsOnButton").pressed.emit()
	if not _check(preload("res://scenes/arena3d/ArenaTheme.gd").option("motion"),"setup_recovers_saved_3d_off"): return
	setup.get_node("%BtnStart").pressed.emit()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 60000:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current == null or current.scene_file_path != "res://scenes/battle/BattleScene.tscn": continue
		battle = current
		if battle.has_node("Arena3DPresenter") and battle.get("_gsm") == null: saw_late_engine = true
		if not battle.call("is_scene_preparation_pending"): break
	if not _check(is_instance_valid(battle) and battle.get("_gsm") != null and str(battle.get("_author_runtime_start_error_code")).is_empty(),"real_author_battle_started"): return
	if not _check(saw_late_engine,"real_async_start_installed_presenter_before_gsm"): return
	p = battle.get_node("Arena3DPresenter")
	tested_window = get_tree().root.size
	if not _check(tested_window == requested_window,"requested_android_orientation_exercised"): return
	if not _check(p.world.motion_enabled and p.world.low_quality,"saved_setup_enables_actual_android_motion"): return
	await _settle(1)
	if not await _check_mobile_speech(): return
	# Keep the real scene, GSM and author owner; replace only the public board for
	# reproducible legal player actions. AI remains idle on the player's turn.
	var gs := _live_fixture()
	gs.players[0].deck.pop_back()
	var research := CardInstance.create(CardDatabase.get_card("CSV1C","121"),0)
	gs.players[0].hand.append(research)
	await _install_live_fixture(gs)
	var notice := battle.get_node_or_null("MulliganNotice") as Control
	if notice != null: notice.hide()
	var card: Control = battle.get("_hand_container").get_child(0)
	await _tap_control(card)
	await _capture("platform-author-supporter-choice.png")
	var use := _use_button(battle)
	if not _check(use != null,"supporter_use_button_available"): return
	await _tap_control(use)
	await _settle(.4)
	if not _check(p.world.supporter_vfx.played == 1 and not p.world.supporter_vfx.active.is_empty(),"touch_supporter_commit_after_async_start"): return
	if not _check(p.world.supporter_vfx.active.hero.is_visible_in_tree(),"supporter_character_rendered"): return
	await _capture("platform-author-live-supporter.png")
	await _settle(6)
	gs = _live_fixture()
	await _install_live_fixture(gs)
	await _touch(_card_point("my_active"),true)
	await _touch(_card_point("my_active"),false)
	var attack := _find_attack(battle.get("_dialog_overlay"))
	if not _check(attack != null,"attack_button_available"): return
	await _tap_control(attack)
	await _settle(.4)
	if not _check(p.world.signature_vfx.played == 1 and not p.world.signature_vfx.sequences.is_empty(),"touch_pokemon_commit_after_async_start"): return
	if not _check(p.world.signature_vfx.last_outcome.species == "dragapult","authored_pokemon_model_selected"): return
	await _capture("platform-author-live-pokemon.png")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"platform":OS.get_name(),"window":[tested_window.x,tested_window.y],"late_engine":saw_late_engine,"supporters":p.world.supporter_vfx.played,"pokemon":p.world.signature_vfx.played,"kind":"arena_actual_author_start_touch_acceptance"}))
	await _settle(1)
	get_tree().quit(0)

func _check_mobile_speech() -> bool:
	await _install_live_fixture(_live_fixture())
	var talk := preload("res://scripts/commentary/OpponentTalkController.gd").new()
	battle.add_child(talk)
	talk.setup(battle,p,{})
	talk.director.opened = true
	# Local words exercise the same presentation as a DeepSeek response, with
	# no credentials or paid requests in the acceptance APK.
	talk.panel.present("别急，我的多龙巴鲁托ex已经准备好了。就决定是你了，幻影潜袭！",{"mood_id":"confident"})
	await _settle(.3)
	var rect: Rect2 = talk.panel.get_global_rect()
	var active: Rect2 = p.world.card_screen_rect("opp_active")
	active.position += p.global_position
	print("ANDROID_SPEECH_GEOMETRY ",rect," active=",active," font=",talk.panel.body.get_theme_font_size("font_size"))
	await _capture("platform-deepseek-mobile-speech.png")
	if not _check(talk.panel.body.text.contains("幻影潜袭"),"mobile_speech_long_line_preserved"): return false
	if not _check(talk.panel.visible and talk.panel.body.get_theme_font_size("font_size") >= 22*p.platform_metrics.scale-.5,"mobile_speech_readable_scale"): return false
	if not _check(absf(rect.get_center().x-battle.get_viewport_rect().get_center().x) < 12 and rect.end.y <= active.position.y,"mobile_speech_centered_above_active"): return false
	if not _check(rect.encloses(talk.panel.body.get_global_rect()) and talk.panel.body.get_line_count() == talk.panel.body.get_visible_line_count(),"mobile_speech_entire_text_visible"): return false
	await _tap_control(talk.panel.close_button)
	if not _check(talk.closed,"mobile_speech_touch_mute"): return false
	await _settle(.3)
	return true

func _use_button(node: Node) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text.begins_with("使用"): return node
	for child in node.get_children():
		var found := _use_button(child)
		if found != null: return found
	return null
