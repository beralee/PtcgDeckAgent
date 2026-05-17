class_name NoivernExEffects
extends BaseEffect

const HIDDEN_FLIGHT_PROTECTION := "noivern_ex_hidden_flight_protection"
const DOMINATING_ECHO_LOCK := "noivern_ex_dominating_echo_lock"
const DOMINATING_ECHO_LOCK_PREFIX := "noivern_ex_dominating_echo_lock_p"

var hidden_flight_attack_index: int = 0
var dominating_echo_attack_index: int = 1
var attack_index_to_match: int = -1
var execute_attack_effects: bool = true


func _init(match_attack_index: int = -1, should_execute_attack_effects: bool = true) -> void:
	attack_index_to_match = match_attack_index
	execute_attack_effects = should_execute_attack_effects


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not execute_attack_effects or not applies_to_attack_index(attack_index):
		return
	if attacker == null or state == null:
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	if attack_index == hidden_flight_attack_index:
		_mark_slot_effect(attacker, HIDDEN_FLIGHT_PROTECTION, state.turn_number)
	elif attack_index == dominating_echo_attack_index:
		var opponent_index := 1 - top.owner_index
		_mark_slot_effect(attacker, DOMINATING_ECHO_LOCK, state.turn_number, {"player_index": opponent_index})
		state.shared_turn_flags[_lock_key(opponent_index)] = state.turn_number + 1


func prevents_damage_from(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	if not _has_slot_effect(defender, HIDDEN_FLIGHT_PROTECTION, state.turn_number - 1):
		return false
	var attacker_data := attacker.get_card_data()
	return attacker_data != null and attacker_data.is_basic_pokemon()


func blocks_card_from_hand(source: PokemonSlot, card: CardInstance, player_index: int, state: GameState) -> bool:
	if source == null or card == null or card.card_data == null or state == null:
		return false
	if not _has_dominating_echo_lock(source, player_index, state):
		return false
	var card_type := str(card.card_data.card_type)
	return card_type == "Special Energy" or card_type == "Stadium"


static func is_player_locked(player_index: int, state: GameState) -> bool:
	if state == null:
		return false
	return int(state.shared_turn_flags.get(_static_lock_key(player_index), -999)) == state.turn_number


func get_description() -> String:
	return "Hidden Flight prevents damage from Basic Pokemon during the opponent's next turn. Dominating Echo stops the opponent from playing Stadium cards or attaching Special Energy from hand during their next turn."


func _has_dominating_echo_lock(source: PokemonSlot, player_index: int, state: GameState) -> bool:
	if int(state.shared_turn_flags.get(_lock_key(player_index), -999)) == state.turn_number:
		return true
	for effect: Dictionary in source.effects:
		if effect.get("type", "") != DOMINATING_ECHO_LOCK:
			continue
		if int(effect.get("player_index", -1)) != player_index:
			continue
		if int(effect.get("turn", -999)) == state.turn_number - 1:
			return true
	return false


func _mark_slot_effect(slot: PokemonSlot, effect_type: String, turn_number: int, extra: Dictionary = {}) -> void:
	for effect: Dictionary in slot.effects:
		if effect.get("type", "") == effect_type and int(effect.get("turn", -999)) == turn_number:
			for key: Variant in extra.keys():
				effect[key] = extra[key]
			return
	var payload := {
		"type": effect_type,
		"turn": turn_number,
	}
	for key: Variant in extra.keys():
		payload[key] = extra[key]
	slot.effects.append(payload)


func _has_slot_effect(slot: PokemonSlot, effect_type: String, turn_number: int) -> bool:
	for effect: Dictionary in slot.effects:
		if effect.get("type", "") == effect_type and int(effect.get("turn", -999)) == turn_number:
			return true
	return false


func _lock_key(player_index: int) -> String:
	return _static_lock_key(player_index)


static func _static_lock_key(player_index: int) -> String:
	return "%s%d" % [DOMINATING_ECHO_LOCK_PREFIX, player_index]
