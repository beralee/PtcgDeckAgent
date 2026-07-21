extends RefCounted


func test_sync_pass() -> String:
	return ""


func test_async_pass() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is unavailable"
	await tree.process_frame
	return ""
