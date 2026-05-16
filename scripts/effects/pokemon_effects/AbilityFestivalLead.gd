class_name AbilityFestivalLead
extends BaseEffect

const FESTIVAL_GROUNDS_EFFECT_ID := "357d55b54ded5db071b55ebe165749fc"
const FESTIVAL_LEAD_EFFECT_IDS := {
	"144b6904892dc89e3efb81067c5668c4": true, # Dipplin CSV8C
	"7580acd5669bac12cb1af8007d2e6a6a": true, # Goldeen CSV8C
}
const PENDING_PLAYER_KEY := "festival_lead_pending_player"
const PENDING_SLOT_KEY := "festival_lead_pending_slot"


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


static func has_festival_lead(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return bool(FESTIVAL_LEAD_EFFECT_IDS.get(slot.get_card_data().effect_id, false))


static func can_take_second_attack(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null or not has_festival_lead(slot):
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null or top.owner_index != state.current_player_index:
		return false
	if state.stadium_card == null or state.stadium_card.card_data == null:
		return false
	if state.stadium_card.card_data.effect_id != FESTIVAL_GROUNDS_EFFECT_ID:
		return false
	var used_key := _used_key(slot, state)
	return not bool(state.shared_turn_flags.get(used_key, false))


static func mark_second_attack_pending(slot: PokemonSlot, state: GameState) -> bool:
	if not can_take_second_attack(slot, state):
		return false
	var top: CardInstance = slot.get_top_card()
	state.shared_turn_flags[_used_key(slot, state)] = true
	state.shared_turn_flags[PENDING_PLAYER_KEY] = top.owner_index
	state.shared_turn_flags[PENDING_SLOT_KEY] = int(slot.get_instance_id())
	return true


static func consume_second_attack_pending(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	if int(state.shared_turn_flags.get(PENDING_PLAYER_KEY, -1)) != top.owner_index:
		return false
	if int(state.shared_turn_flags.get(PENDING_SLOT_KEY, -1)) != int(slot.get_instance_id()):
		return false
	state.shared_turn_flags.erase(PENDING_PLAYER_KEY)
	state.shared_turn_flags.erase(PENDING_SLOT_KEY)
	return true


static func _used_key(slot: PokemonSlot, state: GameState) -> String:
	return "festival_lead_used_%d_%d" % [int(slot.get_instance_id()), state.turn_number]


func get_description() -> String:
	return "If Festival Grounds is in play, this Pokemon may attack twice."
