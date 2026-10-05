extends SceneTree
const Frame = preload("res://scenes/arena3d/ArenaFrame.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var db = root.get_node("CardDatabase")
	var stadium: CardData = db.get_card("CSV9C","207")
	assert(stadium != null)
	var processor := EffectProcessor.new()
	assert(processor.get_effect(stadium.effect_id) is CSV9C207AreaZeroUnderdepths)
	var tera: CardData
	for card: CardData in db.get_all_cards():
		if card.is_basic_pokemon() and card.is_tera_pokemon():
			tera = card
			break
	assert(tera != null)
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	gs.players.assign([PlayerState.new(),PlayerState.new()])
	gs.players[1].player_index = 1
	gs.stadium_card = CardInstance.create(stadium,0)
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(tera,0))
	gs.players[0].active_pokemon = active
	assert(BenchLimitHelper.get_bench_limit_for_player(gs,gs.players[0]) == 8)
	var frame: Dictionary = Frame.capture(gs,0)
	if not frame.slots.has("my_bench_7"):
		push_error("ARENA_BENCH_CAPACITY_FAIL: legal empty slots 6-8 missing before cards are placed")
		quit(1)
		return
	assert(frame.slots.my_bench_7.empty and not frame.slots.has("opp_bench_5"))
	gs.stadium_card = null
	frame = Frame.capture(gs,0)
	assert(not frame.slots.has("my_bench_5"))
	gs.stadium_card = CardInstance.create(stadium,0)
	gs.players[0].active_pokemon = null
	frame = Frame.capture(gs,0)
	assert(not frame.slots.has("my_bench_5"))
	print("ARENA_BENCH_CAPACITY_PASS: real CSV9C/207 registration; eligible empty slots; no-Tera and stadium removal")
	quit()

