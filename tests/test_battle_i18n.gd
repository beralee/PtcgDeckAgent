class_name TestBattleI18n
extends TestBase


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _load_i18n() -> Variant:
	return load("res://scripts/ui/battle/BattleI18n.gd")


func test_battle_i18n_resolves_stable_battle_labels() -> String:
	var script: Variant = _load_i18n()
	if script == null:
		return "BattleI18n script should exist"
	var value: Variant = script.call("t", "battle.top.ai_advice")

	return run_checks([
		assert_eq(str(value), _u([0x41, 0x49, 0x5EFA, 0x8BAE]), "BattleI18n should resolve the AI advice label"),
	])


func test_battle_i18n_interpolates_dialog_params() -> String:
	var script: Variant = _load_i18n()
	if script == null:
		return "BattleI18n script should exist"
	var value: Variant = script.call("t", "battle.dialog.take_prize", {"count": 2})

	return run_checks([
		assert_eq(str(value), _u([0x8BF7, 0x9009, 0x62E9, 0x20, 0x31, 0x20, 0x5F20, 0x5956, 0x8D4F, 0x5361, 0xFF08, 0x5269, 0x4F59, 0x20, 0x32, 0x20, 0x5F20, 0xFF09]), "BattleI18n should interpolate numeric dialog parameters"),
	])


func test_battle_i18n_interpolates_phase_header() -> String:
	var script: Variant = _load_i18n()
	if script == null:
		return "BattleI18n script should exist"
	var value: Variant = script.call("t", "battle.top.phase_line", {
		"deck": _u([0x672A, 0x77E5, 0x724C, 0x7EC4]),
		"count": 3,
	})

	return run_checks([
		assert_eq(str(value), _u([0x5F53, 0x524D, 0x724C, 0x7EC4, 0xFF1A, 0x672A, 0x77E5, 0x724C, 0x7EC4, 0x20, 0x7C, 0x20, 0x5BF9, 0x624B, 0x624B, 0x724C, 0xFF1A, 0x33]), "BattleI18n should render the top-bar phase header template"),
	])


func test_battle_i18n_returns_key_when_missing() -> String:
	var script: Variant = _load_i18n()
	if script == null:
		return "BattleI18n script should exist"
	var value: Variant = script.call("t", "battle.missing.key")

	return run_checks([
		assert_eq(str(value), "battle.missing.key", "BattleI18n should preserve missing keys as fallback output"),
	])
