extends Node3D
## Visual identity and clock only. Never receives mutable game objects.
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
const Choreography := preload("res://scenes/arena3d/ArenaPokemonChoreography.gd")
const PerformanceVfx := preload("res://scenes/arena3d/ArenaPokemonPerformance.gd")
const PortablePalette := preload("res://scenes/arena3d/PortableActorPalette.gdshader")
var species := ""
var model: Node3D
var joints: Dictionary = {}
var rest: Dictionary = {}
var performance: Node3D
var audio: AudioStreamPlayer
var target_local := Vector3(0,1,4.5)
var stage_directed := false
var low_quality := false

func build(id: String) -> void:
	if model != null or not Catalog.ENTRIES.has(id): return
	species = id
	var packed := load(("res://assets/arena3d/portable/pokemon/%s.glb" if low_quality else "res://assets/arena3d/pokemon/%s.glb") % id) as PackedScene
	if packed == null: return
	model = packed.instantiate()
	add_child(model)
	if low_quality:
		var palette := ShaderMaterial.new()
		palette.shader = PortablePalette
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = palette
	for part: Node in model.find_children("*","Node3D",true,false):
		if part is MeshInstance3D: continue
		joints[str(part.name)] = part
		rest[str(part.name)] = part.transform
	performance = PerformanceVfx.new()
	add_child(performance)
	performance.build(self)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -9
	add_child(audio)
	var path := "res://assets/arena3d/pokemon/audio/%s.wav" % id
	if low_quality: path = path.replace("/arena3d/","/arena3d/portable/").replace(".wav",".ogg")
	if ResourceLoader.exists(path): audio.stream = load(path)

func play_sound(speed: float = 1.0) -> void:
	if audio != null and audio.stream != null and is_inside_tree():
		audio.pitch_scale = speed
		audio.play()

func pose(age: float, performing: bool = true) -> void:
	for id: String in joints: joints[id].transform = rest[id]
	Choreography.sample(self,age,performing)
	if performance != null and performance.visible: performance.sample(age,performing,target_local)

func turn(id: String, angles: Vector3) -> void:
	if not joints.has(id): return
	joints[id].rotate_x(angles.x)
	joints[id].rotate_y(angles.y)
	joints[id].rotate_z(angles.z)

func move_joint(id: String, offset: Vector3) -> void:
	if joints.has(id): joints[id].position += offset

func scale_joint(id: String, value: Vector3) -> void:
	if joints.has(id): joints[id].scale *= value

func local_joint(id: String, offset: Vector3 = Vector3.ZERO) -> Vector3:
	if not joints.has(id): return Vector3(0,1.7,0)
	var part: Node3D = joints[id]
	var result: Transform3D = part.transform
	while part.get_parent() != self and part.get_parent() is Node3D:
		part = part.get_parent()
		result = part.transform * result
	return result*offset

func mouth_local() -> Vector3:
	# The breath leaves the oral cavity, not the rotating lower lip.
	return local_joint("Head",Vector3(0,-.08,.67))

func emit_point() -> Vector3:
	if joints.has("Jaw"): return to_global(mouth_local())
	if joints.has("Head"): return joints.Head.global_position
	return global_position + Vector3.UP
