extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var frame_script = load("res://scenes/arena3d/ArenaFrame.gd")
	assert(frame_script != null, "3D public presentation projector must exist")
	var gs := GameState.new()
	var player := PlayerState.new()
	var opponent := PlayerState.new()
	gs.players = [player, opponent]
	var secret := CardData.new()
	secret.name = "HIDDEN_SENTINEL"
	var ci := CardInstance.new()
	ci.card_data = secret
	ci.face_up = false
	opponent.hand.append(ci)
	opponent.deck.append(ci)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(ci)
	opponent.active_pokemon = slot
	var frame: Dictionary = frame_script.capture(gs, 0)
	assert(not JSON.stringify(frame).contains("HIDDEN_SENTINEL"))
	assert(frame.players[1].hand_count == 1)
	assert(frame.slots.opp_active.concealed)
	ci.face_up = true
	secret.hp = 120
	slot.damage_counters = 30
	frame = frame_script.capture(gs, 0)
	assert(frame.slots.opp_active.hp == 90)
	assert(frame.slots.opp_active.name == "HIDDEN_SENTINEL")
	assert(not frame.has("deck") and not frame.has("hand"))
	ci.face_up = false
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 1
	frame = frame_script.capture(gs,0)
	assert(not frame.slots.opp_active.concealed,"Post-setup public field stays visible after search effects")
	assert(frame.slots.opp_active.hp == 90)
	print("ARENA3D PASS: hidden identities excluded; public HP and counts correct")
	quit()
