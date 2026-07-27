class_name TestOpeningCoinLabels
extends TestBase

const CoinFlipAnimatorScript := preload("res://scenes/battle/CoinFlipAnimator.gd")


func test_coin_animator_supports_opening_labels_without_changing_card_flip_defaults() -> String:
	var animator: Control = CoinFlipAnimatorScript.new()
	var checks: Array[String] = [
		assert_eq(str(animator.call("result_text_for", true, "先攻", "后攻")), "先攻", "Opening heads should be presented as going first"),
		assert_eq(str(animator.call("result_text_for", false, "先攻", "后攻")), "后攻", "Opening tails should be presented as going second"),
		assert_eq(str(animator.call("result_text_for", true)), "正面", "Regular card coin flips should keep the heads label"),
		assert_eq(str(animator.call("result_text_for", false)), "反面", "Regular card coin flips should keep the tails label"),
	]
	animator.free()
	return run_checks(checks)


func test_battle_scene_marks_only_the_random_opening_flip_as_first_player_context() -> String:
	var battle_scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle_scene.set("_coin_animating", true)
	battle_scene.set("_opening_first_player_flip_pending", true)
	battle_scene.call("_on_coin_flipped", true)
	battle_scene.call("_on_coin_flipped", false)

	var label_queue: Array = battle_scene.get("_coin_flip_label_queue") as Array
	var first_labels: Dictionary = label_queue[0] as Dictionary if label_queue.size() > 0 else {}
	var second_labels: Dictionary = label_queue[1] as Dictionary if label_queue.size() > 1 else {}
	var result := run_checks([
		assert_eq(str(first_labels.get("heads", "")), "先攻", "The random opening flip should enqueue first-player wording"),
		assert_eq(str(first_labels.get("tails", "")), "后攻", "The random opening flip should enqueue second-player wording"),
		assert_true(second_labels.is_empty(), "The following card-effect flip should return to normal heads/tails wording"),
		assert_false(bool(battle_scene.get("_opening_first_player_flip_pending")), "Opening context should be consumed by exactly one flip"),
	])

	battle_scene.queue_free()
	return result
