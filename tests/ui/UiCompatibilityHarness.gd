extends RefCounted
## Real Control dispatch in isolated viewports; profiles describe input, not an OS emulator.
const PROFILES := [
	{"id": "android_phone", "size": Vector2i(1080, 2400), "mode": "portrait", "touch": true},
	{"id": "web_phone", "size": Vector2i(390, 844), "mode": "portrait", "touch": true},
	{"id": "web_tablet", "size": Vector2i(820, 1180), "mode": "portrait", "touch": true},
	{"id": "windows_mouse", "size": Vector2i(1600, 900), "mode": "landscape", "touch": false},
	{"id": "mac_mouse", "size": Vector2i(1440, 900), "mode": "landscape", "touch": false},
	{"id": "web_desktop", "size": Vector2i(1366, 768), "mode": "landscape", "touch": false},
]
var viewport: SubViewport
var scene: Control
var _saved_emulation: Variant
var _saved_layout: String
var _profile: Dictionary

func mount(packed: PackedScene, profile: Dictionary) -> void:
	_profile = profile
	_saved_layout = GameManager.non_battle_layout_mode
	GameManager.non_battle_layout_mode = profile.mode
	_saved_emulation = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	viewport = SubViewport.new()
	viewport.size = profile.size
	viewport.handle_input_locally = true
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	scene = packed.instantiate()
	scene.set("_skip_service_initialization_for_tests", true)
	viewport.add_child(scene)
	await settle()
	scene.call("_apply_non_battle_layout", Vector2(profile.size), profile.mode)
	await settle()

func select_workspace(workspace: String) -> void:
	scene.call("select_workspace_for_test", workspace)
	# Settings loads persisted preferences in _ready; the matrix owns its test viewport.
	GameManager.non_battle_layout_mode = _profile.mode
	if workspace == "settings":
		scene.get("_ai_settings_content").call("_apply_non_battle_layout", Vector2.ZERO, _profile.mode)
	await settle()
	scene.call("_apply_non_battle_layout", Vector2(_profile.size), _profile.mode)
	await settle()

func settle() -> void:
	for frame in range(4):
		await (Engine.get_main_loop() as SceneTree).process_frame

func touch(pressed: bool, position: Vector2, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	event.canceled = canceled
	viewport.push_input(event, true)

func drag(from: Vector2, to: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.relative = to - from
	event.index = index
	viewport.push_input(event, true)

func swipe(from: Vector2, to: Vector2) -> void:
	touch(true, from)
	for step in range(1, 7):
		var next := from.lerp(to, step / 6.0)
		drag(from.lerp(to, (step - 1) / 6.0), next)
	touch(false, to)
	await settle()

func mouse_click(position: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		event.device = device
		viewport.push_input(event, true)

func dispose() -> void:
	viewport.queue_free()
	await settle()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", _saved_emulation)
	GameManager.non_battle_layout_mode = _saved_layout
