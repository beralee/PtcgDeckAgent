extends SceneTree
## Explicit visual fixture, not a full-match replay. It uses the shipping world
## and the same supporter renderer as committed plays. No fabricated rule actions.
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const OUT := "res://.tmp/supporter-characters-20260929"
var world: Node3D
var elapsed := 0.0
var shot := -1
var capturing := false
var stills := false
var rig: Node
var shot_speed := 1.0

class Rig extends Node:
	var owner_tree: SceneTree
	func _process(delta: float) -> void: owner_tree.tick(delta)

func _initialize() -> void:
	root.set_meta("performance_bench_offline",true)
	ProjectSettings.set_setting("editor/movie_writer/mjpeg_quality",.86)
	call_deferred("launch")

func launch() -> void:
	stills="--stills" in OS.get_cmdline_user_args()
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	root.msaa_3d=Viewport.MSAA_4X
	world=load("res://scenes/arena3d/ArenaWorld.gd").new()
	root.add_child(world)
	world.cinematic=true
	world.motion_enabled=true
	world.sound_enabled=not stills
	world.configure_quality(false)
	world.screen_size=Vector2(1600,900)
	world.supporter_vfx.manual_clock=true
	var slots: Dictionary={"my_active":_card("CSV5C","075"),"opp_active":_card("CSV8C","159")}
	var prints: Array=[["CSV8C","094"],["CSV7C","154"],["CSV9C","175"],["CSV10C","148"],["CS6.5C","020"]]
	for side: String in ["my","opp"]:
		for i: int in 5:slots[side+"_bench_%d"%i]=_card(prints[i][0],prints[i][1])
	world.display({"slots":slots,"view":0,"players":[{"deck_count":30,"discard_count":0,"prizes":6},{"deck_count":30,"discard_count":0,"prizes":6}]})
	rig=Rig.new()
	rig.owner_tree=self
	rig.process_priority=1000
	root.add_child(rig)
	for i: int in 12:await process_frame
	if stills:
		for id: String in Catalog.ENTRIES:
			if "--first-nine" in OS.get_cmdline_user_args() and id in ["blackbelt","cilan","kieran","judge","lana","lillie","brock","penny"]:continue
			_start(id)
			for i: int in 3:
				world.supporter_vfx.sample(1.18)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"/"+id+".png")
		quit()
	else:
		capturing=true
		elapsed=0
		print("SUPPORTER_RECORDING_BEGIN")

func tick(delta: float) -> void:
	world.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	world.camera.keep_aspect=Camera3D.KEEP_HEIGHT
	world.camera.fov=43
	world.camera.position=Vector3(1.4,15.0,24)
	world.camera.look_at(Vector3(0,1.3,0))
	if not capturing:return
	var next:=int(elapsed/4.0)
	if next>=Catalog.ENTRIES.size():
		print("SUPPORTER_RECORDING_COMPLETE")
		capturing=false
		quit()
		return
	if next!=shot:
		shot=next
		_start(Catalog.ENTRIES.keys()[shot])
		print("SUPPORTER_SHOT ",shot," ",Catalog.ENTRIES.keys()[shot])
	var age: float=fmod(elapsed,4.0)*shot_speed
	if not world.supporter_vfx.active.is_empty() and age<world.supporter_vfx.duration():world.supporter_vfx.sample(age)
	else:world.supporter_vfx.clear()
	elapsed+=delta

func _start(id: String) -> void:
	var spec: Dictionary=Catalog.ENTRIES[id]
	var data: CardData=root.get_node("CardDatabase").get_card(spec.printing[0],spec.printing[1])
	var cue: Dictionary={"public":true,"concealed":false,"card_type":"Supporter","regulation":data.regulation_mark,"identities":data.rule_identity_names(),"name":data.display_name(),"uid":data.get_uid(),"mine":true,
		"image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(data.set_code,data.card_index,data.image_local_path)),
		"source_slot":"opp_bench_2" if id=="boss" else "my_bench_1","target_slot":"opp_active","energy_slots":["my_active","my_bench_1"] if id in ["sada","crispin"] else []}
	shot_speed=1.0
	world.supporter_vfx.play(cue,shot_speed)

func _card(set_code: String,number: String) -> Dictionary:
	var data: CardData=root.get_node("CardDatabase").get_card(set_code,number)
	return {"empty":false,"concealed":false,"uid":data.get_uid(),"visual_id":data.get_uid(),"name":data.display_name(),"hp":data.hp,"max_hp":data.hp,"type":data.energy_type,"energy":["L"],"status":[],"tool":false,"evolution":1,"image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(data.set_code,data.card_index,data.image_local_path))}
