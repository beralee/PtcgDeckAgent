extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cd := CardData.new()
	cd.name = "手牌显示策略"
	cd.card_type = "Basic Energy"
	var card := CardInstance.create(cd,0)
	var view := BattleCardView.new()
	view.info_overlay_enabled = false
	view.setup_from_instance(card,BattleCardView.MODE_HAND)
	assert(not view.get("_info_panel").visible)
	root.add_child(view)
	await process_frame
	assert(not view.get("_info_panel").visible,"Ready must not expose a suppressed hand label")
	for i in range(4):
		view.setup_from_instance(card,BattleCardView.MODE_HAND)
		view.set_selected(i%2 == 0)
		view.set_info("旧名称","旧说明")
		assert(not view.get("_info_panel").visible,"Refresh and selection must preserve presentation policy")
	view.info_overlay_enabled = true
	assert(view.get("_info_panel").visible,"Legacy 2D text presentation remains available")
	view.queue_free()
	await process_frame
	print("ARENA_HAND_OVERLAY_PASS: before tree, ready, refresh, selection, legacy opt-in")
	quit()
