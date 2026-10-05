extends "res://tests/TestBase.gd"
const Settings := preload("res://scenes/settings/Settings.tscn")

class Client:
	var callbacks: Array[Callable] = []
	func set_timeout_seconds(_seconds: float) -> void: pass
	func request_json(_parent: Node, _url: String, _key: String, _payload: Dictionary, callback: Callable) -> int:
		callbacks.append(callback)
		return OK

func test_connection_result_cannot_verify_edited_credentials() -> String:
	var path := GameManager.get_battle_review_api_config_path()
	var previous := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var scene := Settings.instantiate()
	scene.call("_ready")
	var client := Client.new()
	scene.set("_test_client", client)
	var endpoint := scene.find_child("EndpointInput", true, false) as LineEdit
	var key := scene.find_child("ApiKeyInput", true, false) as LineEdit
	endpoint.text = "https://api.deepseek.com"
	key.text = "fixture-old-key"
	scene.call("_on_test_connection")
	key.text = "fixture-new-key"
	client.callbacks[0].call({"ok": true})
	var persisted := GameManager.get_battle_review_api_config()
	var stale_rejected: bool = not (persisted.get("api_key") == "fixture-new-key" and persisted.get("ai_test_passed", false))
	scene.call("_on_test_connection")
	scene.call("_on_test_connection")
	var request_count := client.callbacks.size()
	client.callbacks.back().call({"ok": true})
	persisted = GameManager.get_battle_review_api_config()
	var checks: Array[String] = [
		assert_true(stale_rejected, "An old connection response must never verify a newly edited key"),
		assert_eq(request_count, 2, "Repeated Test activation must not start duplicate requests"),
		assert_true(persisted.get("api_key") == "fixture-new-key" and persisted.get("ai_test_passed", false), "An unchanged successful test must still verify and save its exact configuration"),
	]
	scene.free()
	if previous.is_empty():
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(previous)
	return run_checks(checks)
