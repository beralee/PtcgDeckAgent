class_name TestBattleVisualEventBuilder
extends TestBase

const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const PrivacyScript := preload("res://scripts/ui/battle/visuals/BattleVisualPrivacyPolicy.gd")
const BuilderScript := preload("res://scripts/ui/battle/visuals/BattleVisualEventBuilder.gd")


func _card(name: String, owner: int, card_type: String = "Pokemon", hp: int = 100) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	data.hp = hp
	return CardInstance.create(data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _events_of_kind(events: Array, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_variant: Variant in events:
		if event_variant is Dictionary and str((event_variant as Dictionary).get("kind", "")) == kind:
			result.append(event_variant as Dictionary)
	return result


func test_snapshot_captures_every_visual_zone_and_slot_state_without_copying_full_card_data() -> String:
	var state := _state()
	var player := state.players[0]
	var deck_card := _card("Deck Card", 0)
	var hand_card := _card("Hand Card", 0)
	var prize_card := _card("Prize Card", 0)
	var discard_card := _card("Discard Card", 0)
	var lost_card := _card("Lost Card", 0)
	var active_card := _card("Active", 0)
	var energy := _card("Energy", 0, "Energy", 0)
	var tool := _card("Tool", 0, "Tool", 0)
	player.deck = [deck_card]
	player.hand = [hand_card]
	player.set_prizes([prize_card])
	player.discard_pile = [discard_card]
	player.lost_zone = [lost_card]
	player.active_pokemon = _slot(active_card)
	player.active_pokemon.attached_energy = [energy]
	player.active_pokemon.attached_tool = tool
	player.active_pokemon.damage_counters = 30
	player.active_pokemon.status_conditions["poisoned"] = true

	var snapshot: Dictionary = SnapshotScript.capture(state)
	var cards_by_id: Dictionary = snapshot.get("cards_by_id", {})
	var locations: Dictionary = snapshot.get("card_locations", {})
	var active_slot: Dictionary = (snapshot.get("slots", {}) as Dictionary).get("p0.active", {})
	var captured_card: Dictionary = cards_by_id.get(deck_card.instance_id, {})

	return run_checks([
		assert_eq(str(locations.get(deck_card.instance_id, "")), "p0.deck", "Deck location should be captured"),
		assert_eq(str(locations.get(hand_card.instance_id, "")), "p0.hand", "Hand location should be captured"),
		assert_eq(str(locations.get(prize_card.instance_id, "")), "p0.prize.0", "Prize layout slot should be stable"),
		assert_eq(str(locations.get(discard_card.instance_id, "")), "p0.discard", "Discard location should be captured"),
		assert_eq(str(locations.get(lost_card.instance_id, "")), "p0.lost", "Lost-zone location should be captured"),
		assert_eq(str(locations.get(active_card.instance_id, "")), "p0.active.stack", "Pokemon stack should be captured"),
		assert_eq(str(locations.get(energy.instance_id, "")), "p0.active.energy", "Attached Energy should be captured"),
		assert_eq(str(locations.get(tool.instance_id, "")), "p0.active.tool", "Attached Tool should be captured"),
		assert_eq(int(active_slot.get("damage_counters", -1)), 30, "Damage should be captured"),
		assert_true(bool((active_slot.get("status_conditions", {}) as Dictionary).get("poisoned", false)), "Status should be captured"),
		assert_eq(_sorted_keys(captured_card), ["card", "card_name", "card_type", "face_up", "instance_id", "owner_index"], "Visual snapshot should keep only lightweight identity fields"),
	])


func test_zone_diff_emits_one_transfer_and_hides_opponent_draw_identity() -> String:
	var state := _state()
	var hidden := _card("Secret Opponent Card", 1)
	state.players[1].deck = [hidden]
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[1].deck.clear()
	state.players[1].hand.append(hidden)
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.DRAW_CARD, 1, {"count": 1}, 3, "draw")
	var transfers := _events_of_kind(BuilderScript.build(before, after, action, 0), "zone_transfer")
	var event: Dictionary = transfers[0] if transfers.size() == 1 else {}

	return run_checks([
		assert_eq(transfers.size(), 1, "One card move must produce exactly one transfer"),
		assert_eq(str(event.get("source_zone", "")), "p1.deck", "Transfer should keep the real source"),
		assert_eq(str(event.get("target_zone", "")), "p1.hand", "Transfer should keep the real target"),
		assert_eq(str(event.get("visibility", "")), PrivacyScript.VISIBILITY_BACK, "Opponent draw must remain face down"),
		assert_true((event.get("cards", []) as Array).is_empty(), "Hidden transfer must not expose CardInstance references to the renderer"),
		assert_true((event.get("card_names", []) as Array).is_empty(), "Hidden transfer must not expose card names"),
	])


func test_trainer_play_animates_only_the_exact_trainer_when_effect_discards_other_hand_cards() -> String:
	var state := _state()
	var trainer := _card("Ultra Ball", 0, "Item", 0)
	var cost_a := _card("Discard Cost A", 0, "Pokemon", 100)
	var cost_b := _card("Discard Cost B", 0, "Energy", 0)
	var same_name_alternate_art_cost := _card("Ultra Ball", 0, "Item", 0)
	state.players[0].hand = [trainer, cost_a, cost_b, same_name_alternate_art_cost]
	var before := SnapshotScript.capture(state)
	state.players[0].hand.clear()
	state.players[0].discard_pile = [cost_a, cost_b, same_name_alternate_art_cost, trainer]
	var after := SnapshotScript.capture(state)
	var action := GameAction.create(
		GameAction.ActionType.PLAY_TRAINER,
		0,
		{"card_name": "Ultra Ball"},
		3,
		"trainer with discard cost"
	)
	var transfers := _events_of_kind(BuilderScript.build(before, after, action, 0), "zone_transfer")
	var trainer_events: Array[Dictionary] = []
	var other_ids: Array[int] = []
	for event: Dictionary in transfers:
		if str(event.get("semantic", "")) == "trainer_play":
			trainer_events.append(event)
		else:
			for id_variant: Variant in event.get("card_instance_ids", []):
				other_ids.append(int(id_variant))
	return run_checks([
		assert_eq(trainer_events.size(), 1, "One PLAY_TRAINER action should present exactly one Trainer batch"),
		assert_eq(
			trainer_events[0].get("card_instance_ids", []) if not trainer_events.is_empty() else [],
			[trainer.instance_id],
			"Discard costs must never be presented as the Trainer being played"
		),
		assert_true(
			other_ids.has(cost_a.instance_id)
			and other_ids.has(cost_b.instance_id)
			and other_ids.has(same_name_alternate_art_cost.instance_id),
			"Effect costs, including same-name alternate art, should remain separate visual transfers"
		),
		assert_eq(int(trainer_events[0].get("owner_index", -1)) if not trainer_events.is_empty() else -1, 0, "Transfer event must freeze card ownership"),
		assert_eq(int(trainer_events[0].get("view_player", -1)) if not trainer_events.is_empty() else -1, 0, "Transfer event must freeze its capture perspective"),
	])


func test_public_reveal_allows_opponent_card_face_without_changing_hidden_defaults() -> String:
	var state := _state()
	var revealed := _card("Revealed Search", 1)
	state.players[1].deck = [revealed]
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[1].deck.clear()
	state.players[1].hand.append(revealed)
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.PUBLIC_REVEAL, 1, {
		"card_instance_ids": [revealed.instance_id],
		"card_names": [revealed.get_name()],
	}, 3, "public search")
	var transfers := _events_of_kind(BuilderScript.build(before, after, action, 0), "zone_transfer")
	var event: Dictionary = transfers[0] if not transfers.is_empty() else {}
	return run_checks([
		assert_eq(str(event.get("visibility", "")), PrivacyScript.VISIBILITY_FACE, "PUBLIC_REVEAL should permit a face-up result"),
		assert_eq(event.get("card_names", []), ["Revealed Search"], "Public result may expose its name"),
		assert_eq((event.get("cards", []) as Array).size(), 1, "Public result may provide its card view"),
	])


func test_evolution_is_a_stack_change_not_a_destroy_create_pair() -> String:
	var state := _state()
	var basic := _card("Basic", 0)
	var evolution := _card("Evolution", 0)
	var slot := _slot(basic)
	var opponent_basic := _card("Opponent Basic", 1)
	var opponent_evolution := _card("Opponent Evolution", 1)
	var opponent_slot := _slot(opponent_basic)
	state.players[0].active_pokemon = slot
	state.players[0].hand = [evolution]
	state.players[1].active_pokemon = opponent_slot
	state.players[1].hand = [opponent_evolution]
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[0].hand.clear()
	slot.pokemon_stack.append(evolution)
	# Simulate an unrelated stale stack delta being present in the visual baseline.
	# The current player's exact Evolution action must never animate that other side.
	state.players[1].hand.clear()
	opponent_slot.pokemon_stack.append(opponent_evolution)
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.EVOLVE, 0, {
		"evolution": "Evolution",
		"target_slot_runtime_id": int(slot.get_instance_id()),
	}, 3, "evolve")
	var events: Array = BuilderScript.build(before, after, action, 0)
	var stack_changes := _events_of_kind(events, "stack_change")

	return run_checks([
		assert_eq(stack_changes.size(), 1, "Evolution should produce one stack-change sequence only for its exact target"),
		assert_eq(str(stack_changes[0].get("semantic", "")) if not stack_changes.is_empty() else "", "evolve", "Evolution semantic should be explicit"),
		assert_eq(stack_changes[0].get("card_instance_ids", []) if not stack_changes.is_empty() else [], [evolution.instance_id], "Only the added Evolution card should move"),
		assert_eq(int(stack_changes[0].get("slot_runtime_id", -1)) if not stack_changes.is_empty() else -1, int(slot.get_instance_id()), "Evolution visuals must retain the exact target Pokemon slot identity"),
		assert_eq(str(stack_changes[0].get("target_slot_key", "")) if not stack_changes.is_empty() else "", "p0.active", "Evolution visuals must expose an explicit target slot instead of relying on a generic zone"),
		assert_true(_events_of_kind(events, "zone_transfer").is_empty(), "Evolution card must not also create a duplicate generic transfer"),
		assert_true(_events_of_kind(events, "shuffle").is_empty(), "Evolution must not emit a deck animation when neither player's shuffle count changed"),
	])


func test_active_bench_swap_moves_slots_once_without_moving_every_attachment() -> String:
	var state := _state()
	var active := _slot(_card("Old Active", 0))
	var bench := _slot(_card("New Active", 0))
	active.attached_energy = [_card("Active Energy", 0, "Energy", 0)]
	bench.attached_tool = _card("Bench Tool", 0, "Tool", 0)
	state.players[0].active_pokemon = active
	state.players[0].bench = [bench]
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[0].active_pokemon = bench
	state.players[0].bench = [active]
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.RETREAT, 0, {}, 3, "retreat")
	var events: Array = BuilderScript.build(before, after, action, 0)
	var field_moves := _events_of_kind(events, "field_move")

	return run_checks([
		assert_eq(field_moves.size(), 2, "Both Pokemon slots should move exactly once"),
		assert_true(_events_of_kind(events, "zone_transfer").is_empty(), "Cards attached to a moved slot must not animate independently"),
	])


func test_knockout_groups_stack_energy_and_tool_and_ignores_bench_compaction() -> String:
	var state := _state()
	var knocked_out := _slot(_card("Knocked Out", 0, "Pokemon", 100))
	knocked_out.attached_energy = [_card("Energy", 0, "Energy", 0)]
	knocked_out.attached_tool = _card("Tool", 0, "Tool", 0)
	var survivor := _slot(_card("Survivor", 0))
	state.players[0].bench = [knocked_out, survivor]
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[0].bench.erase(knocked_out)
	for card: CardInstance in knocked_out.collect_all_cards():
		state.players[0].discard_pile.append(card)
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.KNOCKOUT, 0, {"pokemon_name": "Knocked Out"}, 3, "ko")
	var events: Array = BuilderScript.build(before, after, action, 0)
	var knockout := _events_of_kind(events, "zone_transfer")
	var ids: Array = knockout[0].get("card_instance_ids", []) if knockout.size() == 1 else []

	return run_checks([
		assert_eq(knockout.size(), 1, "A Pokemon stack, its Energy, and Tool should leave as one causal KO group"),
		assert_eq(str(knockout[0].get("semantic", "")) if not knockout.is_empty() else "", "knockout", "KO group should retain its semantic"),
		assert_eq(ids.size(), 3, "KO group should visibly carry all three attached card instances"),
		assert_true(_events_of_kind(events, "field_move").is_empty(), "Bench compaction after a KO must not look like a manual field move"),
	])


func test_energy_attach_move_and_discard_use_real_source_and_target_semantics() -> String:
	var state := _state()
	var active := _slot(_card("Active", 0))
	var bench := _slot(_card("Bench", 0))
	var energy := _card("Energy", 0, "Energy", 0)
	state.players[0].active_pokemon = active
	state.players[0].bench = [bench]
	state.players[0].hand = [energy]
	var before_attach: Dictionary = SnapshotScript.capture(state)
	state.players[0].hand.clear()
	active.attached_energy.append(energy)
	var after_attach: Dictionary = SnapshotScript.capture(state)
	var attach_events := _events_of_kind(BuilderScript.build(before_attach, after_attach, GameAction.create(GameAction.ActionType.ATTACH_ENERGY, 0, {}, 3, "attach"), 0), "zone_transfer")

	var before_move := after_attach
	active.attached_energy.clear()
	bench.attached_energy.append(energy)
	var after_move: Dictionary = SnapshotScript.capture(state)
	var move_events := _events_of_kind(BuilderScript.build(before_move, after_move, GameAction.create(GameAction.ActionType.USE_ABILITY, 0, {"ability_name": "Move"}, 3, "move"), 0), "zone_transfer")

	var before_discard := after_move
	bench.attached_energy.clear()
	state.players[0].discard_pile.append(energy)
	var after_discard: Dictionary = SnapshotScript.capture(state)
	var discard_events := _events_of_kind(BuilderScript.build(before_discard, after_discard, GameAction.create(GameAction.ActionType.RETREAT, 0, {}, 3, "discard"), 0), "zone_transfer")

	return run_checks([
		assert_eq(str(attach_events[0].get("semantic", "")) if not attach_events.is_empty() else "", "attach_energy", "Hand Energy should use attach animation"),
		assert_eq(str(move_events[0].get("semantic", "")) if not move_events.is_empty() else "", "move_energy", "Attached Energy moving between Pokemon should use transfer animation"),
		assert_eq(str(discard_events[0].get("semantic", "")) if not discard_events.is_empty() else "", "discard_energy", "Retreat cost should visibly detach into discard"),
	])


func test_search_mill_lost_zone_and_hand_reset_build_causal_batches_in_order() -> String:
	var state := _state()
	var old_hand := [_card("Old Hand 1", 0), _card("Old Hand 2", 0)]
	var new_hand := [_card("New Hand 1", 0), _card("New Hand 2", 0)]
	state.players[0].hand.assign(old_hand)
	state.players[0].deck.assign(new_hand)
	var before_reset: Dictionary = SnapshotScript.capture(state)
	state.players[0].hand.assign(new_hand)
	state.players[0].deck.assign(old_hand)
	state.players[0].shuffle_count += 1
	var after_reset: Dictionary = SnapshotScript.capture(state)
	var reset_action := GameAction.create(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "Judge"}, 3, "reset")
	var reset_events: Array = BuilderScript.build(before_reset, after_reset, reset_action, 0)
	var reset_index := _semantic_index(reset_events, "hand_reset")
	var redraw_index := _semantic_index(reset_events, "redraw")
	var shuffle_index := _kind_index(reset_events, "shuffle")

	var mill_card := _card("Milled", 0)
	var lost_card := _card("Lost", 0)
	state.players[0].deck = [mill_card, lost_card]
	state.players[0].discard_pile.clear()
	state.players[0].lost_zone.clear()
	var before_public_moves: Dictionary = SnapshotScript.capture(state)
	state.players[0].deck.clear()
	state.players[0].discard_pile.append(mill_card)
	state.players[0].lost_zone.append(lost_card)
	var after_public_moves: Dictionary = SnapshotScript.capture(state)
	var public_events := _events_of_kind(BuilderScript.build(before_public_moves, after_public_moves, GameAction.create(GameAction.ActionType.ATTACK, 0, {}, 3, "effects"), 0), "zone_transfer")
	var public_semantics: Array[String] = []
	for event: Dictionary in public_events:
		public_semantics.append(str(event.get("semantic", "")))

	return run_checks([
		assert_true(reset_index >= 0 and redraw_index > reset_index and shuffle_index > redraw_index, "Hand reset must collect old hand, deal the new hand, then finish with shuffle feedback"),
		assert_contains(public_semantics, "mill", "Deck-to-discard movement should be identified as milling"),
		assert_contains(public_semantics, "lost_zone", "Deck-to-lost-zone movement should use the lost-zone treatment"),
	])


func test_prize_take_reveals_only_to_the_player_whose_hand_receives_it() -> String:
	var state := _state()
	var prize := _card("Secret Prize", 1)
	state.players[1].set_prizes([prize])
	var before: Dictionary = SnapshotScript.capture(state)
	state.players[1].take_prize_from_slot(0)
	var after: Dictionary = SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.TAKE_PRIZE, 1, {"count": 1}, 3, "prize")
	var opponent_view := _events_of_kind(BuilderScript.build(before, after, action, 0), "zone_transfer")
	var owner_view := _events_of_kind(BuilderScript.build(before, after, action, 1), "zone_transfer")
	return run_checks([
		assert_eq(str(opponent_view[0].get("visibility", "")) if not opponent_view.is_empty() else "", PrivacyScript.VISIBILITY_BACK, "Opponent should see only a Prize card back entering hand"),
		assert_true((opponent_view[0].get("card_names", []) as Array).is_empty() if not opponent_view.is_empty() else false, "Opponent Prize event must not expose its name"),
		assert_eq(str(owner_view[0].get("visibility", "")) if not owner_view.is_empty() else "", PrivacyScript.VISIBILITY_FACE, "Prize owner should see the taken card face"),
	])


func test_damage_heal_status_shuffle_phase_and_result_diffs_are_deterministic() -> String:
	var state := _state()
	var slot := _slot(_card("Target", 0, "Pokemon", 200))
	state.players[0].active_pokemon = slot
	var baseline: Dictionary = SnapshotScript.capture(state)
	slot.damage_counters = 40
	slot.status_conditions["burned"] = true
	state.players[0].shuffle_count = 1
	state.phase = GameState.GamePhase.POKEMON_CHECK
	var changed: Dictionary = SnapshotScript.capture(state)
	var damage_action := GameAction.create(GameAction.ActionType.DAMAGE_DEALT, 1, {}, 3, "damage")
	var first: Array = BuilderScript.build(baseline, changed, damage_action, 0)
	var second: Array = BuilderScript.build(baseline, changed, damage_action, 0)
	var damage := _events_of_kind(first, "damage_delta")
	var status := _events_of_kind(first, "status_delta")
	var shuffle := _events_of_kind(first, "shuffle")
	var phase := _events_of_kind(first, "phase_banner")

	var before_heal: Dictionary = changed
	slot.damage_counters = 10
	var after_heal: Dictionary = SnapshotScript.capture(state)
	var heal := _events_of_kind(BuilderScript.build(before_heal, after_heal, GameAction.create(GameAction.ActionType.HEAL, 0, {}, 3, "heal"), 0), "heal_delta")

	var before_end: Dictionary = after_heal
	state.set_game_over(0, "all_prizes_taken")
	var after_end: Dictionary = SnapshotScript.capture(state)
	var result := _events_of_kind(BuilderScript.build(before_end, after_end, GameAction.create(GameAction.ActionType.GAME_END, 0, {"reason": "all_prizes_taken"}, 3, "end"), 0), "match_result")

	return run_checks([
		assert_eq(first, second, "The same snapshots and action must produce an identical ordered event list"),
		assert_eq(int(damage[0].get("amount", 0)) if not damage.is_empty() else 0, 40, "Damage delta should use the actual state change"),
		assert_eq(str(status[0].get("status", "")) if not status.is_empty() else "", "burned", "Status delta should identify the changed condition"),
		assert_eq(shuffle.size(), 1, "Shuffle counter delta should create one shuffle event"),
		assert_eq(phase.size(), 1, "Phase change should create one phase banner"),
		assert_eq(int(heal[0].get("amount", 0)) if not heal.is_empty() else 0, 30, "Healing delta should use the actual reduced damage"),
		assert_eq(int(result[0].get("winner_index", -1)) if not result.is_empty() else -1, 0, "Match result should preserve the winner"),
		assert_eq(str(result[0].get("reason", "")) if not result.is_empty() else "", "all_prizes_taken", "Match result should preserve the reason"),
	])


func test_trainer_ability_stadium_and_turn_actions_add_semantic_feedback_without_fake_state_changes() -> String:
	var state := _state()
	var snapshot: Dictionary = SnapshotScript.capture(state)
	var trainer := GameAction.create(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "Professor"}, 3, "trainer")
	var ability := GameAction.create(GameAction.ActionType.USE_ABILITY, 0, {"pokemon_name": "Pokemon", "ability_name": "Ability"}, 3, "ability")
	var stadium := GameAction.create(GameAction.ActionType.USE_STADIUM, 0, {"card_name": "Stadium"}, 3, "stadium")
	var turn := GameAction.create(GameAction.ActionType.TURN_START, 0, {}, 4, "turn")

	return run_checks([
		assert_eq(str((_events_of_kind(BuilderScript.build(snapshot, snapshot, trainer, 0), "trigger_pulse")[0]).get("semantic", "")), "trainer_play", "Trainer action should create presentation feedback"),
		assert_eq(str((_events_of_kind(BuilderScript.build(snapshot, snapshot, ability, 0), "trigger_pulse")[0]).get("semantic", "")), "ability", "Ability action should create presentation feedback"),
		assert_eq(str((_events_of_kind(BuilderScript.build(snapshot, snapshot, stadium, 0), "trigger_pulse")[0]).get("semantic", "")), "stadium", "Stadium action should create presentation feedback"),
		assert_eq(_events_of_kind(BuilderScript.build(snapshot, snapshot, turn, 0), "phase_banner").size(), 1, "TURN_START should create a banner even before a phase-state delta"),
	])


func test_ai_ability_feedback_resolves_only_the_acting_players_matching_pokemon() -> String:
	var state := _state()
	var my_match := _slot(_card("Teal Mask Ogerpon ex", 0))
	var ai_match := _slot(_card("Teal Mask Ogerpon ex", 1))
	state.players[0].bench.append(my_match)
	state.players[1].bench.append(ai_match)
	var snapshot := SnapshotScript.capture(state)
	var action := GameAction.create(GameAction.ActionType.USE_ABILITY, 1, {
		"pokemon_name": "Teal Mask Ogerpon ex",
		"ability_name": "Teal Dance",
		"source_slot_runtime_id": int(ai_match.get_instance_id()),
	}, 3, "AI ability")
	var pulses := _events_of_kind(BuilderScript.build(snapshot, snapshot, action, 0), "trigger_pulse")
	var pulse: Dictionary = pulses[0] if not pulses.is_empty() else {}
	return run_checks([
		assert_eq(str(pulse.get("source_slot_key", "")), "p1.bench.0", "AI Ability feedback must anchor to the AI Pokemon even when both players have the same Pokemon name"),
		assert_eq(int(pulse.get("player_index", -1)), 1, "AI Ability feedback must preserve the acting player"),
	])


func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _semantic_index(events: Array, semantic: String) -> int:
	for index: int in range(events.size()):
		if events[index] is Dictionary and str((events[index] as Dictionary).get("semantic", "")) == semantic:
			return index
	return -1


func _kind_index(events: Array, kind: String) -> int:
	for index: int in range(events.size()):
		if events[index] is Dictionary and str((events[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1
