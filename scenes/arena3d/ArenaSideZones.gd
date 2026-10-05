extends Node3D
## Physical stacks from public counts and the public discard top card only.
const Backs := preload("res://scenes/arena3d/ArenaCardBacks.gd")
var world: Node3D
var frame: Dictionary = {}
var piles: Dictionary = {}
var cache: Dictionary = {}

func _ready() -> void:
	for side in ["my","opp"]:
		for kind in ["deck","discard"]:
			var pile := Node3D.new()
			pile.name = side+"_"+kind
			add_child(pile)
			# A flush dark base, not an oversized reflective plate. The old metal
			# tray also turned white under the moving lamps in the Grove theme.
			var tray: MeshInstance3D = world._card_body(1.85,2.60,.06,.09,Color("102430"))
			tray.position.y = .06
			pile.add_child(tray)
			var body: MeshInstance3D = world._card_body(1.85,2.60,.025,.09,Color("25364a"))
			pile.add_child(body)
			var face := MeshInstance3D.new()
			face.mesh = world._rounded_mesh(1.85,2.60,.09)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			mat.albedo_color = Color(.73,.73,.73)
			face.material_override = mat
			pile.add_child(face)
			piles[pile.name] = {"node":pile,"tray":tray,"face":face,"body":body,"count":-1,"path":""}

func location(side: String, kind: String) -> Vector3:
	var lane: int = ["deck","discard"].find(kind)
	if world.compact_board and world.portrait_board:
		return Vector3(5.0+lane*2.15,.30,world.portrait_pile_z()*(1 if side == "my" else -1))
	return Vector3(world.side_x-.1+(lane-.5)*2.30,.30,2.1 if side == "my" else -2.7)

func screen_rect(side: String, kind: String) -> Rect2:
	var at := location(side,kind)
	var scale_value := .8 if world.compact_board and world.portrait_board else 1.0
	var a: Vector2 = world.project(at+Vector3(-1.05,.4,-1.45)*scale_value)
	var b: Vector2 = world.project(at+Vector3(1.05,0,1.45)*scale_value)
	return Rect2(a,b-a).abs()

func display(value: Dictionary) -> void:
	frame = value
	if frame.get("players",[]).size() != 2: return
	for side in ["my","opp"]:
		var player: Dictionary = frame.players[frame.view if side == "my" else 1-frame.view]
		for kind in ["deck","discard"]:
			var entry: Dictionary = piles[side+"_"+kind]
			var count := int(player.get(kind+"_count",0))
			var thickness := .025+maxi(0,mini(count,60)-1)*.0035
			if entry.count != count:
				entry.body.mesh = world._card_solid_mesh(1.85,2.60,thickness,.09,clampi(count,1,8))
				entry.count = count
			entry.body.visible = count > 0
			entry.body.position.y = .09+thickness*.5
			entry.face.visible = count > 0
			entry.face.position.y = .09+thickness+.001
			var texture: Texture2D = Backs.for_side(side == "my")
			if kind != "deck":
				var path: String = player.get(kind+"_top",{}).get("image","")
				entry.path = path
				if not cache.has(path): cache[path] = _load_public_image(path)
				texture = cache[path]
			entry.face.material_override.albedo_texture = texture
			entry.face.material_override.albedo_color = Color(.73,.73,.73) if texture != null else Color("203f50")

func _load_public_image(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path): return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(bytes): error = img.load_png_from_buffer(bytes)
	elif CardData.has_jpg_signature(bytes): error = img.load_jpg_from_buffer(bytes)
	elif CardData.has_webp_signature(bytes): error = img.load_webp_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if error == OK else null

func _process(_delta: float) -> void:
	visible = true
	for side in ["my","opp"]:
		for kind in ["deck","discard"]:
			piles[side+"_"+kind].node.position = location(side,kind)
			piles[side+"_"+kind].node.scale = Vector3.ONE*(.8 if world.compact_board and world.portrait_board else 1.0)
