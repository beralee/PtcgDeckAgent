extends RefCounted

const OIL_TYPE := "smoliv_oil_attack_failure"
const EVOLUTION_LOCK_PREFIX := "bronzong_hand_evolution_lock:"

static func hand_evolution_blocked(state: GameState, player_index: int) -> bool:
	return state != null and int(state.shared_turn_flags.get(EVOLUTION_LOCK_PREFIX + str(player_index), -999)) == state.turn_number

static func oil_check_required(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	for effect: Dictionary in attacker.effects:
		if effect.get("type") == OIL_TYPE and int(effect.get("turn", -999)) == state.turn_number - 1 and int(effect.get("top_instance_id", -1)) == attacker.get_top_card().instance_id:
			return true
	return false
