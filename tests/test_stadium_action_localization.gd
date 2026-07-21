class_name TestStadiumActionLocalization
extends TestBase

const BattleDialogControllerScript := preload("res://scripts/ui/battle/BattleDialogController.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")


class EnglishFallbackEffect:
	extends BaseEffect

	func get_description() -> String:
		return "English implementation fallback"


func test_stadium_action_body_prefers_localized_card_text_for_every_registered_stadium() -> String:
	var controller := BattleDialogControllerScript.new()
	var db := CardDatabaseScript.new()
	var processor := EffectProcessor.new()
	var mismatches: Array[String] = []
	var audited := 0
	for card: CardData in db.get_all_cards():
		if card == null or card.card_type != "Stadium" or card.description.strip_edges() == "" or card.effect_id == "":
			continue
		var effect: BaseEffect = processor.get_effect(card.effect_id)
		if effect == null:
			continue
		audited += 1
		var body := str(controller.call("_stadium_action_body", card, effect))
		if body != card.description.strip_edges():
			mismatches.append("%s %s => %s" % [card.get_uid(), card.display_name(), body])
	db.free()
	return run_checks([
		assert_gt(audited, 30, "The regression should audit the full registered Stadium localization batch"),
		assert_true(mismatches.is_empty(), "Stadium action HUD should prefer localized card text; mismatches: %s" % " | ".join(mismatches)),
	])


func test_calamitous_snowy_mountain_click_body_uses_its_simplified_chinese_card_text() -> String:
	var controller := BattleDialogControllerScript.new()
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV3C", "129")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var body := str(controller.call("_stadium_action_body", card, effect)) if card != null else ""
	db.free()
	return run_checks([
		assert_not_null(card, "CSV3C_129 Calamitous Snowy Mountain should load"),
		assert_not_null(effect, "CSV3C_129 Stadium effect should register"),
		assert_eq(body, card.description.strip_edges() if card != null else "", "Clicking Calamitous Snowy Mountain should show its Simplified Chinese card text"),
		assert_false(body.contains("Whenever either player"), "Calamitous Snowy Mountain should not expose its English implementation description"),
	])


func test_stadium_action_body_keeps_ability_text_first_and_effect_description_last() -> String:
	var controller := BattleDialogControllerScript.new()
	var effect := EnglishFallbackEffect.new()
	var card := CardData.new()
	card.name = "测试竞技场"
	card.card_type = "Stadium"
	card.description = "中文牌面说明"
	var localized_body := str(controller.call("_stadium_action_body", card, effect))
	card.abilities = [{"name": "可用能力", "text": "中文主动能力说明"}]
	var ability_body := str(controller.call("_stadium_action_body", card, effect))
	card.abilities.clear()
	card.description = ""
	var fallback_body := str(controller.call("_stadium_action_body", card, effect))
	return run_checks([
		assert_eq(localized_body, "中文牌面说明", "Localized source text should outrank implementation descriptions"),
		assert_eq(ability_body, "中文主动能力说明", "Explicit Stadium action ability text should remain the most specific body"),
		assert_eq(fallback_body, effect.get_description(), "Effect descriptions should remain a fallback when source text is missing"),
	])
