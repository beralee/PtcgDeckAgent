class_name CSV9CHelpers
extends RefCounted

const PREVENT_DAMAGE_EFFECT_TYPE := "csv9c_prevent_attack_damage"
const NO_WEAKNESS_EFFECT_TYPE := "csv9c_no_weakness_next_turn"
const OUTGOING_DAMAGE_REDUCTION_EFFECT_TYPE := "csv9c_outgoing_damage_reduction"
const EVOLVED_FROM_HAND_EFFECT_TYPE := "csv9c_evolved_from_hand"
const ANGELITE_USED_PREFIX := "csv9c_angelite_used_p"
const BRIAR_USED_PREFIX := "csv9c_briar_used_p"
const FAN_CALL_USED_PREFIX := "csv9c_fan_call_used_p"
const LAST_ATTACK_TURN_PREFIX := "csv9c_last_attack_turn_p"
const LAST_ATTACK_SLOT_PREFIX := "csv9c_last_attack_slot_p"
const LAST_ATTACK_ANCIENT_PREFIX := "csv9c_last_attack_ancient_p"
const MILOTIC_CALMING_SHORE_EFFECT_ID := "88b2885578a73494f1eed7c2b53e67c7"
const MILOTIC_CALMING_SHORE_REMOTE_EFFECT_ID := "57aa4d41e927a2f1cdf846f73509b907"
const VIBRANT_PALACE_EFFECT_ID := "528f7e92b624e35bb42828e372c45252"
const VIBRANT_PALACE_REMOTE_EFFECT_ID := "4622932a419f939cc537e765a5bbe543"

const KNOWN_TERA_EFFECT_IDS := {
	"a533d02d029bd799e8c425beecd3ffaa": true,
	"cd845155473716c29f29efa29da0a869": true,
	"cfe54f4650db054ec2eec6dfcaaff88a": true,
	"317cdd81106733967d562ad538a7983a": true,
	"fa9e235782bba9bdb62005106bbdd6d9": true,
	"0f9c649bb3f59a7a342b53cdc78952a4": true,
	"1e48ba6c2140461745fc407bf34f5598": true,
	"92770a887520f6c4528cf57ae82392b3": true,
	"689549e631f4f93ecf618a215c628bd1": true,
	"27d1eb5f7abc237f462328c2ff00fdf3": true,
	"61fb0755be18f5fcdc6a30781d5fc05e": true,
	"62619a01b9dd1e1dec71d6f6557c9cb8": true,
	"c09bd406f26faeab1683244e53bab0b4": true,
	"5de19cbd4b2d1ff80ba14d6d89246ae9": true,
}

const KNOWN_ANCIENT_EFFECT_IDS := {
	"41dd160743c1707676c4faa6759c718b": true,
	"66377923675b93ec93a30c3411292d47": true,
}


static func owner_index_for_slot(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return -1
	for pi: int in state.players.size():
		if slot in state.players[pi].get_all_pokemon():
			return pi
	return -1


static func card_label(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return card.card_data.name


static func _is_milotic_calming_shore_effect_id(effect_id: String) -> bool:
	return effect_id == MILOTIC_CALMING_SHORE_EFFECT_ID or effect_id == MILOTIC_CALMING_SHORE_REMOTE_EFFECT_ID


static func _is_vibrant_palace_effect_id(effect_id: String) -> bool:
	return effect_id == VIBRANT_PALACE_EFFECT_ID or effect_id == VIBRANT_PALACE_REMOTE_EFFECT_ID


static func slot_label(slot: PokemonSlot, state: GameState = null) -> String:
	if slot == null:
		return ""
	var remaining := slot.get_remaining_hp()
	var maximum := slot.get_max_hp()
	if state != null:
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null:
			if processor.has_method("get_effective_remaining_hp"):
				remaining = int(processor.call("get_effective_remaining_hp", slot, state))
			if processor.has_method("get_effective_max_hp"):
				maximum = int(processor.call("get_effective_max_hp", slot, state))
		elif state.stadium_card != null and state.stadium_card.card_data != null and _is_vibrant_palace_effect_id(str(state.stadium_card.card_data.effect_id)):
			if slot.get_card_data() != null and slot.get_card_data().is_basic_pokemon():
				maximum += 30
				remaining = maxi(0, maximum - slot.damage_counters)
	return "%s (HP %d/%d)" % [slot.get_pokemon_name(), remaining, maximum]


static func is_basic_energy(card: CardInstance, energy_type: String = "") -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	if cd.card_type != "Basic Energy":
		return false
	return energy_type == "" or cd.energy_provides == energy_type or cd.energy_type == energy_type


static func basic_energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if card.card_data.energy_provides != "":
		return card.card_data.energy_provides
	return card.card_data.energy_type


static func is_tera_card_data(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	if cd.is_tera_pokemon():
		return true
	if KNOWN_TERA_EFFECT_IDS.has(cd.effect_id):
		return true
	for tag: String in cd.is_tags:
		var normalized := tag.to_lower()
		if normalized == "tera" or normalized == "terastal" or tag == "太晶":
			return true
	for attack: Dictionary in cd.attacks:
		var seen_types: Dictionary = {}
		for symbol: String in CardData.normalize_attack_cost(str(attack.get("cost", ""))):
			if symbol != "C":
				seen_types[symbol] = true
		if seen_types.size() >= 3:
			return true
	return false


static func is_tera_slot(slot: PokemonSlot) -> bool:
	return slot != null and is_tera_card_data(slot.get_card_data())


static func player_has_tera(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_tera_slot(slot):
			return true
	return false


static func has_tera_on_bench(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if is_tera_slot(slot):
			return true
	return false


static func is_ancient_card_data(cd: CardData) -> bool:
	if cd == null:
		return false
	return cd.is_ancient_pokemon() or KNOWN_ANCIENT_EFFECT_IDS.has(cd.effect_id)


static func is_basic_colorless_pokemon(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd := slot.get_card_data()
	return cd.is_basic_pokemon() and cd.energy_type == "C"


static func player_field_return_to_hand_blocked(player_index: int, state: GameState) -> bool:
	if state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	for slot: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if slot != null and slot.get_card_data() != null and _is_milotic_calming_shore_effect_id(str(slot.get_card_data().effect_id)):
			if processor != null and processor.has_method("is_ability_disabled"):
				if bool(processor.call("is_ability_disabled", slot, state)):
					continue
			elif _ability_disabled_without_processor(slot, state):
				continue
			return true
	return false


static func _ability_disabled_without_processor(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	for effect: Dictionary in slot.effects:
		if String(effect.get("type", "")) == "ability_disabled" and (state == null or int(effect.get("turn", -999)) == state.turn_number):
			return true
	if state != null:
		if AbilityBasicLock.is_locked_by_basic_lock(slot, state):
			return true
		if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state):
			return true
		if AbilityIronThornsInit.is_locked_by_init(slot, state):
			return true
		if AbilityBasicVLock.is_locked(slot, state):
			return true
	return false


static func remove_effect_type(slot: PokemonSlot, effect_type: String) -> void:
	if slot == null:
		return
	for i: int in range(slot.effects.size() - 1, -1, -1):
		if String(slot.effects[i].get("type", "")) == effect_type:
			slot.effects.remove_at(i)


static func find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	if card == null or player == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


static func return_cards_to_deck(player: PlayerState, cards: Array[CardInstance], shuffle_after: bool = true) -> void:
	for card: CardInstance in cards:
		if card == null:
			continue
		card.face_up = false
		player.deck.append(card)
	if shuffle_after:
		player.shuffle_deck()


static func prevents_damage_from_attack_effect(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") != PREVENT_DAMAGE_EFFECT_TYPE:
			continue
		if int(effect.get("turn", -999)) != state.turn_number - 1:
			continue
		var mode := str(effect.get("mode", "basic"))
		var attacker_cd := attacker.get_card_data()
		if attacker_cd == null:
			continue
		match mode:
			"basic":
				if attacker_cd.is_basic_pokemon():
					return true
			"basic_non_colorless":
				if attacker_cd.is_basic_pokemon() and attacker_cd.energy_type != "C":
					return true
	return false


static func defender_has_no_weakness(defender: PokemonSlot, state: GameState) -> bool:
	if defender == null or state == null:
		return false
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") == NO_WEAKNESS_EFFECT_TYPE and int(effect.get("turn", -999)) == state.turn_number - 1:
			return true
	return false


static func record_attack_completed(attacker: PokemonSlot, state: GameState) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	var pi := attacker.get_top_card().owner_index
	var cd := attacker.get_card_data()
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_TURN_PREFIX, pi]] = state.turn_number
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_SLOT_PREFIX, pi]] = int(attacker.get_instance_id())
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_ANCIENT_PREFIX, pi]] = is_ancient_card_data(cd)


static func previous_own_turn_different_ancient_attacked(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	if int(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_TURN_PREFIX, pi], -999)) != state.turn_number - 2:
		return false
	if not bool(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_ANCIENT_PREFIX, pi], false)):
		return false
	return int(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_SLOT_PREFIX, pi], -1)) != int(attacker.get_instance_id())


static func angelite_locked(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	return int(state.shared_turn_flags.get("%s%d" % [ANGELITE_USED_PREFIX, pi], -999)) == state.turn_number - 2


static func mark_angelite_used(attacker: PokemonSlot, state: GameState) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	state.shared_turn_flags["%s%d" % [ANGELITE_USED_PREFIX, attacker.get_top_card().owner_index]] = state.turn_number


static func mark_evolved_from_hand(slot: PokemonSlot, state: GameState) -> void:
	if slot == null or state == null:
		return
	remove_effect_type(slot, EVOLVED_FROM_HAND_EFFECT_TYPE)
	slot.effects.append({"type": EVOLVED_FROM_HAND_EFFECT_TYPE, "turn": state.turn_number})


static func evolved_from_hand_this_turn(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	for effect: Dictionary in slot.effects:
		if String(effect.get("type", "")) == EVOLVED_FROM_HAND_EFFECT_TYPE and int(effect.get("turn", -999)) == state.turn_number:
			return true
	return false


static func prevents_attack_effects(target: PokemonSlot, state: GameState) -> bool:
	return AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(target, state)


static func can_damage_bench_target(attacker: PokemonSlot, target: PokemonSlot, state: GameState) -> bool:
	if target == null or target.get_top_card() == null:
		return false
	if AbilityBenchImmune.prevents_opponent_attack_damage_or_effect(target, attacker, state):
		return false
	return true


static func apply_attack_damage_to_slot(attacker: PokemonSlot, target: PokemonSlot, state: GameState, base_damage: int) -> void:
	if target == null or target.get_top_card() == null:
		return
	var damage := int(base_damage)
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("get_defender_modifier"):
		damage += int(processor.call("get_defender_modifier", target, state, attacker))
	damage = maxi(0, damage)
	if damage <= 0:
		return
	DamageCalculator.new().apply_damage_to_slot(target, damage)


static func briar_bonus_applies(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	return int(state.shared_turn_flags.get("%s%d" % [BRIAR_USED_PREFIX, pi], -999)) == state.turn_number and is_tera_slot(attacker)


static func mark_briar_used(player_index: int, state: GameState) -> void:
	state.shared_turn_flags["%s%d" % [BRIAR_USED_PREFIX, player_index]] = state.turn_number


static func add_extra_prize_once(defender: PokemonSlot, source: String, count: int = 1) -> void:
	if defender == null or count <= 0:
		return
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") == "extra_prize" and effect.get("source", "") == source:
			return
	defender.effects.append({
		"type": "extra_prize",
		"count": count,
		"source": source,
	})
