class_name TestBattleActionLogPresenter
extends TestBase

const BattleActionLogPresenterScript = preload("res://scripts/ui/battle/BattleActionLogPresenter.gd")
const BattleLogRichTextRendererScript = preload("res://scripts/ui/battle/BattleLogRichTextRenderer.gd")


func test_action_log_presenter_marks_players_and_damage_tokens() -> String:
	var presenter := BattleActionLogPresenterScript.new()
	var raw_text := "小林使用 雷电冲击 对 青木的皮卡丘造成 120 点伤害"
	var action := GameAction.create(
		GameAction.ActionType.DAMAGE_DEALT,
		0,
		{"damage": 120, "target": "皮卡丘"},
		3,
		raw_text
	)
	var entry: Dictionary = presenter.call("format_action", action, raw_text, ["小林", "青木"])

	return run_checks([
		assert_eq(str(entry.get("raw_text", "")), raw_text, "Presenter should keep the original display text"),
		assert_true(_has_token_kind(entry, "player_0"), "Presenter should mark player 1 display names"),
		assert_true(_has_token_kind(entry, "player_1"), "Presenter should mark player 2 display names"),
		assert_true(_has_token_kind(entry, "damage"), "Presenter should mark damage values"),
		assert_true(_has_token_text(entry, "120"), "Damage token should keep the raw damage number"),
	])


func test_action_log_renderer_preserves_plain_text_with_bbcode_like_names() -> String:
	var presenter := BattleActionLogPresenterScript.new()
	var renderer := BattleLogRichTextRendererScript.new()
	var raw_text := "玩家1 使用 [b]测试[/b] 对 玩家2 造成 30 点伤害"
	var action := GameAction.create(
		GameAction.ActionType.DAMAGE_DEALT,
		0,
		{"damage": 30},
		1,
		raw_text
	)
	var entry: Dictionary = presenter.call("format_action", action, raw_text, ["玩家1", "玩家2"])
	var rendered := str(renderer.call("render_entry", entry))
	var rich_text := RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.append_text(rendered)
	var parsed := rich_text.get_parsed_text()
	rich_text.queue_free()

	return run_checks([
		assert_eq(parsed, raw_text, "Rendered battle log BBCode should parse back to the original text"),
		assert_true(rendered.find("[lb]b[rb]测试[lb]/b[rb]") >= 0, "Renderer should escape raw BBCode-looking card names"),
	])


func test_plain_log_message_marks_zone_hp_prize_and_count_tokens() -> String:
	var presenter := BattleActionLogPresenterScript.new()
	var text := "玩家2卡牌总计: 60 张 (牌库40 手牌7 奖赏6 弃牌3 HP 230/280)"
	var entry: Dictionary = presenter.call("format_plain_message", text, ["玩家1", "玩家2"])

	return run_checks([
		assert_true(_has_token_kind(entry, "player_1"), "Plain messages should still mark player labels"),
		assert_true(_has_token_kind(entry, "zone"), "Plain messages should mark card zones"),
		assert_true(_has_token_kind(entry, "prize"), "Plain messages should mark prize words"),
		assert_true(_has_token_kind(entry, "hp"), "Plain messages should mark HP values"),
		assert_true(_has_token_kind(entry, "count"), "Plain messages should mark card counts"),
	])


func _has_token_kind(entry: Dictionary, kind: String) -> bool:
	var tokens: Array = entry.get("tokens", [])
	for token_variant: Variant in tokens:
		var token: Dictionary = token_variant if token_variant is Dictionary else {}
		if str(token.get("kind", "")) == kind:
			return true
	return false


func _has_token_text(entry: Dictionary, text: String) -> bool:
	var tokens: Array = entry.get("tokens", [])
	for token_variant: Variant in tokens:
		var token: Dictionary = token_variant if token_variant is Dictionary else {}
		if str(token.get("text", "")) == text:
			return true
	return false
