extends Node3D
## Shared lifecycle for the approved Boss direction and all authored characters.
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const Profiles := preload("res://scenes/arena3d/ArenaSupporterCharacterCatalog.gd")
const Boss := preload("res://scenes/arena3d/ArenaBossOrdersVfx.gd")
const Character := preload("res://scenes/arena3d/ArenaSupporterCharacterVfx.gd")
var world: Node3D
var active: Dictionary = {}
var last_outcome: Dictionary = {}
var played := 0
var manual_clock := false
var vertex_count := 0
var boss_director: Node3D
var character_director: Node3D

func _ready() -> void:
	name = "SupporterVfx"

func play(cue: Dictionary, speed: float = 1.0) -> bool:
	var id := Catalog.identify(cue)
	if id.is_empty() or world == null or not world.motion_enabled: return false
	var artwork: Texture2D
	if id != "boss":
		var path := Profiles.sheet_path(id)
		if world.low_quality: path = path.replace("/arena3d/", "/arena3d/portable/")
		if not ResourceLoader.exists(path):return false
		artwork = load(path) as Texture2D
		if artwork==null or artwork.get_width()%3!=0 or artwork.get_height()%2!=0:return false
	clear()
	var root := Node3D.new()
	add_child(root)
	var director: Node3D
	if id == "boss":
		boss_director = Boss.new()
		director = boss_director
	else:
		character_director = Character.new()
		character_director.character_id = id
		character_director.artwork = artwork
		director = character_director
	director.world = world
	director.cue = cue.duplicate(true)
	root.add_child(director)
	var audio := AudioStreamPlayer.new()
	root.add_child(audio)
	var sound_id := "boss_command" if id == "boss" else id
	audio.stream = load("res://assets/arena3d/portable/supporters/audio/%s.ogg" % sound_id) if world.low_quality else AudioStreamWAV.load_from_file("res://assets/arena3d/supporters/audio/%s.wav" % sound_id)
	audio.pitch_scale = clampf(speed,.5,3)
	audio.volume_db = -4 if id == "boss" else -6
	if world.sound_enabled:audio.play()
	active = {"root":root,"hero":director.hero,"audio":audio,"cue":cue.duplicate(true),"id":id,"age":0.0,"speed":clampf(speed,.5,3)}
	last_outcome = {"id":id,"mine":bool(cue.get("mine",true)),"source_slot":str(cue.get("source_slot","")),"target_slot":str(cue.get("target_slot",""))}
	played += 1
	sample(0)
	return true

func _process(delta: float) -> void:
	if active.is_empty() or manual_clock: return
	if not world.motion_enabled: clear(); return
	if not world.sound_enabled: active.audio.stop()
	active.age += delta*float(active.speed)
	if active.age >= duration(): clear(); return
	sample(float(active.age))

func sample(age: float) -> void:
	if active.is_empty(): return
	active.age = age
	var director := boss_director if is_instance_valid(boss_director) else character_director
	if not is_instance_valid(director):return
	director.sample(age)
	vertex_count = director.vertex_count

func covers_card(_id: String) -> bool:
	if active.is_empty():return false
	return float(active.age)<duration()-.33

func clear() -> void:
	if world != null:
		world.invalidate_render()
		world.supporter_focus = 0.0
		world.supporter_camera_offset = Vector2.ZERO
	if is_instance_valid(boss_director):boss_director.clear()
	if is_instance_valid(character_director):character_director.clear()
	boss_director = null
	character_director = null
	if not active.is_empty() and is_instance_valid(active.root):
		active.audio.stop()
		active.root.queue_free()
	active.clear()
	vertex_count = 0

func duration() -> float:
	if is_instance_valid(boss_director):return Boss.DURATION
	if is_instance_valid(character_director):return float(character_director.profile.duration)
	return 0.0

func resolution_time() -> float:
	if is_instance_valid(boss_director):return Boss.RESOLVE
	if is_instance_valid(character_director):return float(character_director.profile.resolve)
	return 0.0
