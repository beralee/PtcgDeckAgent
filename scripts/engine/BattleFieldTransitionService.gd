## The single runtime writer for Active/Bench topology.
##
## A field transition is a rule transaction: validate the whole move first,
## commit every slot mutation together, apply leave/entry semantics once, and
## publish one typed audit event. Presentation code may observe the result but
## must never own or defer the rule commit.
class_name BattleFieldTransitionService
extends RefCounted

const BENCH_PLACEMENT_APPEND := "append"
const BENCH_PLACEMENT_REPLACE_INCOMING := "replace_incoming"
const EVENT_LOG_KEY := "_field_transition_events"
const EVENT_SEQUENCE_KEY := "_field_transition_sequence"
const MAX_RETAINED_EVENTS := 128


static func place_initial_active(
	state: GameState,
	player_index: int,
	slot: PokemonSlot,
	reason: String,
	order_stamp: int = -1
) -> bool:
	var player := _player_for(state, player_index)
	if player == null or slot == null or player.active_pokemon != null or slot in player.bench:
		return false
	player.active_pokemon = slot
	slot.mark_became_active(order_stamp)
	_record_transition(state, player_index, "place_initial_active", reason, null, slot, false)
	return true


static func switch_active_with_bench(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String,
	bench_placement: String = BENCH_PLACEMENT_APPEND
) -> bool:
	var player := _player_for(state, player_index)
	if player == null or incoming == null:
		return false
	var outgoing: PokemonSlot = player.active_pokemon
	var incoming_index := player.bench.find(incoming)
	if outgoing == null or incoming_index < 0:
		return false
	if bench_placement not in [BENCH_PLACEMENT_APPEND, BENCH_PLACEMENT_REPLACE_INCOMING]:
		return false

	outgoing.clear_on_leave_active()
	if bench_placement == BENCH_PLACEMENT_REPLACE_INCOMING:
		player.bench[incoming_index] = outgoing
	else:
		player.bench.remove_at(incoming_index)
		player.bench.append(outgoing)
	player.active_pokemon = incoming
	incoming.mark_entered_active_from_bench(state.turn_number)
	_record_transition(state, player_index, "switch", reason, outgoing, incoming, true)
	return true


static func replace_active_with_newcomer(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	var player := _player_for(state, player_index)
	if (
		player == null
		or incoming == null
		or player.active_pokemon == null
		or incoming in player.bench
		or incoming == player.active_pokemon
	):
		return false
	var outgoing: PokemonSlot = player.active_pokemon
	outgoing.clear_on_leave_active()
	player.bench.append(outgoing)
	player.active_pokemon = incoming
	if incoming.top_card_order <= 0:
		var order_stamp := PokemonSlot.next_order_stamp()
		incoming.mark_entered_play(order_stamp)
		incoming.mark_became_active(order_stamp)
	else:
		incoming.mark_became_active()
	_record_transition(state, player_index, "replace_with_newcomer", reason, outgoing, incoming, false)
	return true


static func promote_from_bench(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	var player := _player_for(state, player_index)
	if player == null or incoming == null or player.active_pokemon != null:
		return false
	var incoming_index := player.bench.find(incoming)
	if incoming_index < 0:
		return false
	player.bench.remove_at(incoming_index)
	player.active_pokemon = incoming
	incoming.mark_entered_active_from_bench(state.turn_number)
	_record_transition(state, player_index, "promote", reason, null, incoming, true)
	return true


static func remove_active(
	state: GameState,
	player_index: int,
	outgoing: PokemonSlot,
	reason: String
) -> bool:
	var player := _player_for(state, player_index)
	if player == null or outgoing == null or player.active_pokemon != outgoing:
		return false
	outgoing.clear_on_leave_active()
	player.active_pokemon = null
	_record_transition(state, player_index, "remove_active", reason, outgoing, null, false)
	return true


static func remove_active_and_promote(
	state: GameState,
	player_index: int,
	outgoing: PokemonSlot,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	var player := _player_for(state, player_index)
	if (
		player == null
		or outgoing == null
		or incoming == null
		or player.active_pokemon != outgoing
		or incoming not in player.bench
	):
		return false
	outgoing.clear_on_leave_active()
	player.bench.erase(incoming)
	player.active_pokemon = incoming
	incoming.mark_entered_active_from_bench(state.turn_number)
	_record_transition(state, player_index, "remove_and_promote", reason, outgoing, incoming, true)
	return true


static func get_transition_events(state: GameState) -> Array:
	if state == null:
		return []
	var raw_events: Variant = state.shared_turn_flags.get(EVENT_LOG_KEY, [])
	return (raw_events as Array).duplicate(true) if raw_events is Array else []


static func _player_for(state: GameState, player_index: int) -> PlayerState:
	if state == null or player_index < 0 or player_index >= state.players.size():
		return null
	return state.players[player_index]


static func _record_transition(
	state: GameState,
	player_index: int,
	kind: String,
	reason: String,
	outgoing: PokemonSlot,
	incoming: PokemonSlot,
	incoming_from_bench: bool
) -> void:
	var sequence := int(state.shared_turn_flags.get(EVENT_SEQUENCE_KEY, 0)) + 1
	state.shared_turn_flags[EVENT_SEQUENCE_KEY] = sequence
	var raw_events: Variant = state.shared_turn_flags.get(EVENT_LOG_KEY, [])
	var events: Array = raw_events if raw_events is Array else []
	events.append({
		"sequence": sequence,
		"turn_number": state.turn_number,
		"player_index": player_index,
		"kind": kind,
		"reason": reason.strip_edges() if reason.strip_edges() != "" else "unspecified",
		"outgoing_slot_id": int(outgoing.get_instance_id()) if outgoing != null else -1,
		"outgoing_name": outgoing.get_pokemon_name() if outgoing != null else "",
		"incoming_slot_id": int(incoming.get_instance_id()) if incoming != null else -1,
		"incoming_name": incoming.get_pokemon_name() if incoming != null else "",
		"incoming_from_bench": incoming_from_bench,
	})
	while events.size() > MAX_RETAINED_EVENTS:
		events.pop_front()
	state.shared_turn_flags[EVENT_LOG_KEY] = events
