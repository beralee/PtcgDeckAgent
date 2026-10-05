extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var frame_script = load("res://scenes/arena3d/ArenaFrame.gd")
	var gs := GameState.new()
	gs.players.assign([PlayerState.new(),PlayerState.new()])
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	var secret := CardData.new()
	secret.name = "SECRET_IDENTITY_MUST_NOT_APPEAR"
	secret.set_code = "SECRET"
	secret.card_index = "999"
	var public_card := CardData.new()
	public_card.name = "公开最新牌"
	public_card.set_code = "PUBLIC"
	public_card.card_index = "001"
	for pi in range(2):
		var player := gs.players[pi]
		player.deck.append(CardInstance.create(secret,pi))
		player.hand.append(CardInstance.create(secret,pi))
		player.prizes.append(CardInstance.create(secret,pi))
		player.discard_card(CardInstance.create(public_card,pi))
		player.lost_zone.append(CardInstance.create(public_card,pi))
	for view in range(2):
		var frame: Dictionary = frame_script.capture(gs,view)
		assert(not "SECRET" in JSON.stringify(frame),"Deck / prizes / opponent hand identities must never enter the renderer")
		for player: Dictionary in frame.players:
			assert(player.deck_count == 1 and not player.has("deck_top"))
			assert(player.discard_top.uid == public_card.get_uid() and player.discard_count == 1)
			assert(not player.has("lost_top") and not player.has("lost_count"),"The 3D renderer no longer presents the Lost Zone")
	gs.players[0].discard_pile.clear()
	gs.players[0].lost_zone.clear()
	var empty: Dictionary = frame_script.capture(gs,0)
	assert(empty.players[0].discard_top.is_empty())
	print("ARENA_PUBLIC_PILES_PASS: both perspectives, public identities only, empty zones, hidden deck/prize/hand boundary")
	quit()
