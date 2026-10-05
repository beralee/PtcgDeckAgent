extends SceneTree
class DisplayOwner extends RefCounted:
	func _build_battle_status(_slot: PokemonSlot) -> Dictionary:
		return {"hp_current":180,"hp_max":270,"energy_icons":["L","L","C","C"],"ability_used_this_turn":true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cd := CardData.new()
	cd.name = "公开状态测试"
	cd.hp = 220
	var tool_data := CardData.new()
	tool_data.name = "公开道具"
	var slot := PokemonSlot.new()
	var card := CardInstance.create(cd,0)
	card.face_up = true
	slot.pokemon_stack.append(card)
	slot.attached_tool = CardInstance.create(tool_data,0)
	var visible: Dictionary = load("res://scenes/arena3d/ArenaFrame.gd")._slot(slot,true)
	assert(visible.get("tool_name","") == "公开道具","Public card HUD needs the actual attached tool, not an unexplained diamond")
	var effective: Dictionary = load("res://scenes/arena3d/ArenaFrame.gd")._slot(slot,true,DisplayOwner.new())
	assert(effective.hp == 180 and effective.max_hp == 270,"HUD must reuse the existing effective HP projection, including tool/ability modifiers")
	assert(effective.energy_icons == ["L","L","C","C"],"Multi-unit energy must use the existing effective energy display")
	card.face_up = false
	var hidden: Dictionary = load("res://scenes/arena3d/ArenaFrame.gd")._slot(slot,false)
	assert(not hidden.has("tool_name") and not hidden.has("energy"),"Concealed slots must not reveal attachments")
	var host := Control.new()
	host.size = Vector2(1920,800)
	root.add_child(host)
	var view := SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size = Vector2i(1920,800)
	host.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	var hud = load("res://scenes/arena3d/ArenaBoardHud.gd").new()
	hud.world = world
	host.add_child(hud)
	await process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2 = hud.prize_rect(0,true)
	assert(rect.size.x >= 48 and rect.size.y >= 64,"Reward cards require a readable and generous pointer target")
	for index in range(6):
		var target: Rect2 = hud.prize_rect(index,true)
		assert(not target.intersects(world.card_screen_rect("my_active")))
		for other in range(index): assert(not target.intersects(hud.prize_rect(other,true)),"Prize hit regions must remain distinct")
	print("ARENA_TACTICAL_HUD_PASS: public tool identity, concealed boundary, reward readability and target separation")
	host.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	quit()
