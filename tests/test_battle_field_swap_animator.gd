class_name TestBattleFieldSwapAnimator
extends TestBase

const AnimatorScript := preload("res://scripts/ui/battle/BattleFieldSwapAnimator.gd")


func test_detects_two_card_active_bench_exchange_generically() -> String:
	CardInstance.reset_id_counter()
	var animator: RefCounted = AnimatorScript.new()
	var gs := _make_state()
	var player: PlayerState = gs.players[0]
	var old_active := _slot("Old Active", 0)
	var new_active := _slot("New Active", 0)
	var filler := _slot("Filler", 0)
	player.active_pokemon = old_active
	player.bench.append(new_active)
	player.bench.append(filler)
	var before: Dictionary = animator.call("capture_field_snapshot", gs, 0)

	player.bench.erase(new_active)
	player.bench.append(old_active)
	player.active_pokemon = new_active
	var after: Dictionary = animator.call("capture_field_snapshot", gs, 0)
	var movement: Dictionary = animator.call("detect_active_field_movement", before, after)
	var moves: Array = movement.get("moves", [])
	var from_to := _from_to_pairs(moves)

	return run_checks([
		assert_eq(moves.size(), 2, "Active/Bench exchange should animate both Pokemon"),
		assert_contains(from_to, "my_bench_0->my_active", "New Active should fly from its old Bench slot to Active"),
		assert_contains(from_to, "my_active->my_bench_1", "Old Active should fly to its new Bench slot"),
		assert_false(_contains_pair(from_to, "my_bench_1->my_bench_0"), "Bench compaction should not animate as an active handoff"),
	])


func test_detects_single_send_out_after_knockout_generically() -> String:
	CardInstance.reset_id_counter()
	var animator: RefCounted = AnimatorScript.new()
	var gs := _make_state()
	var player: PlayerState = gs.players[0]
	var replacement := _slot("Replacement", 0)
	var backup := _slot("Backup", 0)
	player.active_pokemon = null
	player.bench.append(replacement)
	player.bench.append(backup)
	var before: Dictionary = animator.call("capture_field_snapshot", gs, 0)

	player.bench.erase(replacement)
	player.active_pokemon = replacement
	var after: Dictionary = animator.call("capture_field_snapshot", gs, 0)
	var movement: Dictionary = animator.call("detect_active_field_movement", before, after)
	var moves: Array = movement.get("moves", [])
	var from_to := _from_to_pairs(moves)

	return run_checks([
		assert_eq(moves.size(), 1, "Send-out replacement should animate the promoted Pokemon only"),
		assert_contains(from_to, "my_bench_0->my_active", "Replacement should fly from Bench to Active"),
		assert_false(_contains_pair(from_to, "my_bench_1->my_bench_0"), "Bench-only shifts should stay silent"),
	])


func test_ignores_view_player_flip_and_bench_only_reorder() -> String:
	CardInstance.reset_id_counter()
	var animator: RefCounted = AnimatorScript.new()
	var gs := _make_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot("Active", 0)
	var bench_a := _slot("Bench A", 0)
	var bench_b := _slot("Bench B", 0)
	player.bench.append(bench_a)
	player.bench.append(bench_b)
	var before: Dictionary = animator.call("capture_field_snapshot", gs, 0)

	player.bench.clear()
	player.bench.append(bench_b)
	player.bench.append(bench_a)
	var bench_reorder_after: Dictionary = animator.call("capture_field_snapshot", gs, 0)
	var bench_reorder: Dictionary = animator.call("detect_active_field_movement", before, bench_reorder_after)
	var view_flip_after: Dictionary = animator.call("capture_field_snapshot", gs, 1)
	var view_flip: Dictionary = animator.call("detect_active_field_movement", before, view_flip_after)

	return run_checks([
		assert_true(bench_reorder.is_empty(), "Bench-only reorder should not play field swap animation"),
		assert_true(view_flip.is_empty(), "Changing viewed side should not look like a field movement"),
	])


func _make_state() -> GameState:
	var gs := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gs.players.append(player)
		player.active_pokemon = _slot("P%d Active" % player_index, player_index)
	return gs


func _slot(name: String, owner: int) -> PokemonSlot:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	var inst := CardInstance.create(card, owner)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(inst)
	return slot


func _from_to_pairs(moves: Array) -> Array:
	var result: Array = []
	for move_variant: Variant in moves:
		if not (move_variant is Dictionary):
			continue
		var move: Dictionary = move_variant
		result.append("%s->%s" % [str(move.get("from_slot_id", "")), str(move.get("to_slot_id", ""))])
	return result


func _contains_pair(pairs: Array, pair: String) -> bool:
	return pair in pairs
