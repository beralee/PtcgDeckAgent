class_name TestBattleSceneRefs
extends TestBase

const BattleSceneRefsScript := preload("res://scenes/battle/BattleSceneRefs.gd")


class RefSceneStub:
	extends Control

	func _init() -> void:
		name = "BattleSceneStub"
		_add_panel("TopBar")
		_add_label("LogList", RichTextLabel.new())
		_add_label("LogTitle", Label.new())
		_add_label("LblPhase", Label.new())
		_add_label("LblTurn", Label.new())
		_add_button("BtnEndTurn")
		_add_button("HudEndTurnBtn")
		_add_button("BtnBack")
		_add_button("BtnAiAdvice")
		_add_button("BtnBattleDiscussAI")
		_add_button("BtnAttackVfxPreview")
		_add_button("BtnOpponentHand")
		_add_button("BtnZeusHelp")
		_add_button("BtnBattleLayout")
		_add_button("BtnBattleMore")
		_add_button("BtnReplayPrevTurn")
		_add_button("BtnReplayNextTurn")
		_add_button("BtnReplayContinue")
		_add_button("BtnReplayBackToList")
		_add_panel("LeftPanel", VBoxContainer.new())
		_add_panel("RightPanel", VBoxContainer.new())
		_add_panel("OppActive")
		_add_panel("MyActive")
		_add_panel("OppBench", HBoxContainer.new())
		_add_panel("MyBench", HBoxContainer.new())
		_add_panel("HandScroll", ScrollContainer.new())
		_add_panel("HandContainer", HBoxContainer.new())
		_add_panel("DialogOverlay", Panel.new())
		_add_panel("DialogBox")
		_add_label("DialogTitle", Label.new())
		_add_button("DialogConfirm")
		_add_button("DialogCancel")
		_add_panel("HandoverPanel", Panel.new())
		_add_panel("DetailOverlay", Panel.new())
		_add_panel("DiscardOverlay", Panel.new())
		_add_panel("ReviewOverlay", Panel.new())
		_add_label("ReviewTitle", Label.new())
		_add_label("ReviewContent", RichTextLabel.new())
		_add_button("ReviewRegenerateBtn")

	func _add_button(node_name: String) -> void:
		var button := Button.new()
		button.name = node_name
		add_child(button)

	func _add_label(node_name: String, label: Control) -> void:
		label.name = node_name
		add_child(label)

	func _add_panel(node_name: String, panel: Control = null) -> void:
		var node := panel if panel != null else PanelContainer.new()
		node.name = node_name
		add_child(node)


func test_bind_from_scene_exposes_core_regions() -> String:
	var scene := RefSceneStub.new()
	var refs := BattleSceneRefsScript.new()

	refs.call("bind_from_scene", scene)

	var result := run_checks([
		assert_eq(refs.get("root"), scene, "Refs should keep the scene root"),
		assert_not_null(refs.get("top_bar"), "Refs should expose the top bar"),
		assert_not_null(refs.get("hand_scroll"), "Refs should expose the hand scroll"),
		assert_not_null(refs.get("hand_container"), "Refs should expose the hand container"),
		assert_not_null(refs.get("dialog_overlay"), "Refs should expose the dialog overlay"),
		assert_not_null(refs.get("dialog_confirm_button"), "Refs should expose the dialog confirm button"),
		assert_not_null(refs.get("review_overlay"), "Refs should expose the review overlay"),
		assert_not_null(refs.get("detail_overlay"), "Refs should expose the detail overlay"),
		assert_not_null(refs.get("opponent_active_slot"), "Refs should expose the opponent active slot"),
		assert_not_null(refs.get("player_active_slot"), "Refs should expose the player active slot"),
	])
	scene.free()
	return result


func test_bind_from_scene_keeps_replay_button_group_compatible() -> String:
	var scene := RefSceneStub.new()
	var refs := BattleSceneRefsScript.new()

	refs.call("bind_from_scene", scene)
	var buttons: Array = refs.call("replay_buttons")

	var result := run_checks([
		assert_eq(buttons.size(), 4, "Refs should keep the existing replay button group contract"),
		assert_not_null(refs.get("replay_prev_turn_button"), "Previous replay button should be bound"),
		assert_not_null(refs.get("replay_next_turn_button"), "Next replay button should be bound"),
		assert_not_null(refs.get("replay_continue_button"), "Continue replay button should be bound"),
		assert_not_null(refs.get("replay_back_to_list_button"), "Back-to-list replay button should be bound"),
	])
	scene.free()
	return result
