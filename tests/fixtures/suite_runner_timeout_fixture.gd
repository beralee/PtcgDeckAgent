extends RefCounted


func test_watchdog_terminates_unfinished_test() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.create_timer(600).timeout
	return ""
