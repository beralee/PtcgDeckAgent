class_name TestMarnieGiftBoxTurnProgramShadowR55
extends RefCounted

const FullSuiteScript = preload(
	"res://tests/ptcgdap/godot/test_marnie_gift_box_turn_transaction_r55_exams.gd"
)


func test_r55_real_window_whole_turn_shadow_only() -> String:
	return FullSuiteScript.new().test_r55_real_window_generates_non_authoritative_whole_turn_shadow()
