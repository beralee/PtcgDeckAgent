extends "res://scripts/performance/ArenaPerformanceRunner.gd"
## Rendered visual inventory. Staged public cues, not fabricated game outcomes.
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
const Supporters := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
var visual_checks: Array[Dictionary] = []

func _sample(label: String, gs: GameState) -> void:
	if label == "idle": return
	var world = presenter.world
	world.motion_enabled = true
	world.sound_enabled = false
	var directory := output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	# Exercise each public HUD channel in the captured board before cinematics.
	var slot: PokemonSlot = gs.players[0].active_pokemon
	slot.damage_counters = 50
	slot.set_status("poisoned",true)
	slot.mark_ability_used(gs.turn_number)
	for kind: String in ["FIR","PSY"]:
		slot.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C",kind),0))
	slot.attached_tool = CardInstance.create(CardDatabase.get_card("CSV1C","118"),0)
	battle.call("_refresh_ui")
	presenter.motion.clear()
	await _settle(.3)
	var legacy_stadium: Control = battle.get("_stadium_card_view")
	if is_instance_valid(legacy_stadium) and legacy_stadium.is_visible_in_tree():
		push_error("Legacy stadium card overlays the 3D board")
	await _photo(directory.path_join("board.png"))
	world.signature_vfx.set_process(false)
	var targets: Array[String] = ["opp_active"]
	var counters: Array[Dictionary] = []
	for id: String in Catalog.ENTRIES:
		presenter.motion.clear()
		var card := {"empty":false,"concealed":false,"name":Catalog.ENTRIES[id].aliases[0],"uid":"CSV2C_055" if id == "gardevoir" else ("CSV9C_054" if id == "pikachu_tera" else id)}
		var accepted: bool
		if id == "munkidori": accepted = world.signature_vfx.play_transfer(card,"my_bench_0","my_active","opp_active",3,1)
		elif id == "gardevoir": accepted = world.signature_vfx.play_embrace({"species":id,"public":true,"card":card,"caster":"my_active","target":"my_bench_0","energy_count":1,"damage":20},1)
		else: accepted = world.signature_vfx.play_attack(card,"my_active",targets,counters,1)
		if not accepted:
			push_error("Portable missing character cue: " + id)
			continue
		world.signature_vfx._process(float(world.signature_vfx.timing().hit)+.05)
		var sequence: Dictionary = world.signature_vfx.sequences[0]
		var actor: Node = sequence.actor
		var joints_ok := true
		for joint: String in Catalog.ENTRIES[id].joints: joints_ok = joints_ok and actor.joints.has(joint)
		visual_checks.append({"kind":"pokemon","id":id,"accepted":accepted,"joints_retained":joints_ok,"meshes":actor.model.find_children("*","MeshInstance3D",true,false).size(),"effect_vertices":sequence.stage_effect.vertex_count})
		await _photo(directory.path_join("pokemon-"+id+".png"))
		world.signature_vfx.clear()
		await get_tree().process_frame
	world.signature_vfx.set_process(true)
	world.supporter_vfx.manual_clock = true
	for id: String in Supporters.ENTRIES:
		var spec: Dictionary = Supporters.ENTRIES[id]
		var card: CardData = CardDatabase.get_card(spec.printing[0],spec.printing[1])
		var cue := {"public":true,"concealed":false,"card_type":card.card_type,"regulation":card.regulation_mark,"name":card.display_name(),"identities":card.rule_identity_names(),"uid":card.get_uid(),"mine":true,"source_slot":"opp_bench_1","target_slot":"opp_active","energy_slots":[]}
		var accepted: bool = world.supporter_vfx.play(cue)
		if not accepted:
			push_error("Portable missing supporter cue: " + id)
			continue
		world.supporter_vfx.sample(1.15)
		var hero = world.supporter_vfx.active.hero
		visual_checks.append({"kind":"supporter","id":id,"accepted":accepted,"pose_count":hero.hframes*hero.vframes})
		await _photo(directory.path_join("supporter-"+id+".png"))
		world.supporter_vfx.clear()
		await get_tree().process_frame
	world.supporter_vfx.manual_clock = false
	FileAccess.open(directory.path_join("visual-inventory.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":visual_checks,"window":get_tree().root.size,"low":world.low_quality},"\t"))

func _photo(path: String) -> void:
	presenter.world.invalidate_render()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
