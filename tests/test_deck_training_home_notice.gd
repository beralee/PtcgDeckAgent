class_name TestDeckTrainingHomeNotice
extends TestBase

const NoticeScript := preload("res://scripts/training/DeckTrainingFeatureNotice.gd")
const NOTICE_STATE_PATH := "user://deck_training_feature_notice.headless.json"


func _remove_notice_state() -> void:
	var absolute_path := ProjectSettings.globalize_path(NOTICE_STATE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func test_feature_notice_persists_the_seen_revision() -> String:
	_remove_notice_state()

	var unseen_before: bool = NoticeScript.is_unseen(NoticeScript.NOTICE_REVISION, NOTICE_STATE_PATH)
	var saved: bool = NoticeScript.mark_seen(NoticeScript.NOTICE_REVISION, NOTICE_STATE_PATH)
	var unseen_after: bool = NoticeScript.is_unseen(NoticeScript.NOTICE_REVISION, NOTICE_STATE_PATH)
	var state: Dictionary = NoticeScript.load_state(NOTICE_STATE_PATH)

	var result := run_checks([
		assert_true(unseen_before, "A fresh install should show the deck-training feature notice"),
		assert_true(saved, "Opening deck training should persist its seen revision"),
		assert_false(unseen_after, "The same feature revision should stop showing after it is seen"),
		assert_eq(str(state.get("last_seen_revision", "")), NoticeScript.NOTICE_REVISION, "The persisted state should own the current notice revision"),
	])

	_remove_notice_state()
	return result


func test_main_menu_training_button_has_distinct_color_flash_and_consumable_new_badge() -> String:
	_remove_notice_state()
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame

	scene.call("_refresh_deck_training_feature_notice")
	var training_button := scene.get_node_or_null("%BtnBattleReplay") as Button
	var deck_button := scene.get_node_or_null("%BtnDeckManager") as Button
	var training_style := training_button.get_theme_stylebox("normal") as StyleBoxFlat if training_button != null else null
	var deck_style := deck_button.get_theme_stylebox("normal") as StyleBoxFlat if deck_button != null else null
	var badge := scene.get("_deck_training_new_badge") as PanelContainer
	var flash_tween: Tween = scene.get("_deck_training_button_flash_tween")

	var before_result := run_checks([
		assert_eq(str(scene.call("_main_menu_button_role", "BtnBattleReplay")), "training_feature", "Deck training should own a distinct home-button color role"),
		assert_true(training_style != null and deck_style != null and training_style.border_color != deck_style.border_color, "Deck training should not reuse the deck-center accent"),
		assert_true(badge != null and badge.visible, "An unseen training update should show a NEW badge"),
		assert_true(flash_tween != null and is_instance_valid(flash_tween), "An unseen training update should start a looping emphasis tween"),
	])

	var saved: bool = bool(scene.call("_mark_deck_training_feature_seen"))
	var badge_after := scene.get("_deck_training_new_badge") as PanelContainer
	var tween_after: Tween = scene.get("_deck_training_button_flash_tween")
	var after_result := run_checks([
		assert_true(saved, "Consuming the training notice should persist before navigation"),
		assert_false(badge_after != null and badge_after.visible, "Entering deck training should immediately hide NEW"),
		assert_true(tween_after == null, "Entering deck training should stop the flashing tween"),
		assert_false(NoticeScript.is_unseen(NoticeScript.NOTICE_REVISION, NOTICE_STATE_PATH), "The hidden badge state should survive scene recreation"),
	])

	scene.queue_free()
	await tree.process_frame
	_remove_notice_state()
	if before_result != "":
		return before_result
	return after_result
