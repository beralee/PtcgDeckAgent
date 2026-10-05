extends Node3D
## A real, low polygon table. No desktop GLB, foliage shader or HDR dependency.
var parts: Array[MeshInstance3D] = []
var table_width := -1.0
var table_depth := -1.0

func _init() -> void:
	name = "PortableGrove"
	for index in range(6):
		var part := MeshInstance3D.new()
		part.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = [Color("493629"),Color("244a37"),Color("897351"),Color("897351"),Color("897351"),Color("897351")][index]
		if index == 1: material.resource_name = "playing felt"
		part.mesh.material = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
		parts.append(part)
	fit(23.5,false)

func fit(width: float, cinematic: bool, expanded_portrait: bool = false) -> void:
	var depth := 13.9 if cinematic else (28.0 if expanded_portrait else 19.8)
	if is_equal_approx(table_width,width) and is_equal_approx(table_depth,depth): return
	table_width = width
	table_depth = depth
	parts[0].mesh.size = Vector3(width,.4,depth)
	parts[0].position.y = -.09
	parts[1].mesh.size = Vector3(width-1.2,.04,depth-1.2)
	parts[1].position.y = .14
	for i in range(2,6):
		var vertical := i < 4
		parts[i].mesh.size = Vector3(.065 if vertical else width-.65,.025,depth-.65 if vertical else .065)
		parts[i].position = Vector3((width*.5-.33)*(-1 if i == 2 else 1) if vertical else 0,.17,0 if vertical else (depth*.5-.33)*(-1 if i == 4 else 1))
