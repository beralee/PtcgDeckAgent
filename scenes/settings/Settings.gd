## 设置页面 — ZenMux AI 配置
extends Control


func _ready() -> void:
	%BtnSave.pressed.connect(_on_save)
	%BtnBack.pressed.connect(_on_back)
	_load_config()


func _load_config() -> void:
	var config := GameManager.get_battle_review_api_config()
	%EndpointInput.text = str(config.get("endpoint", ""))
	%ApiKeyInput.text = str(config.get("api_key", ""))
	%ModelInput.text = str(config.get("model", ""))
	%TimeoutInput.value = float(config.get("timeout_seconds", 30.0))
	%StatusLabel.text = ""


func _on_save() -> void:
	var data := {
		"endpoint": %EndpointInput.text.strip_edges(),
		"api_key": %ApiKeyInput.text.strip_edges(),
		"model": %ModelInput.text.strip_edges(),
		"timeout_seconds": %TimeoutInput.value,
	}
	var path := GameManager.get_battle_review_api_config_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		%StatusLabel.text = "保存失败: 无法写入文件"
		%StatusLabel.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	%StatusLabel.text = "已保存"
	%StatusLabel.add_theme_color_override("font_color", Color(0.3, 1, 0.3))


func _on_back() -> void:
	GameManager.goto_main_menu()
