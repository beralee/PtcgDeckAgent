## Conditional tool damage bonus for active-spot damage checks.
class_name EffectToolConditionalDamage
extends BaseEffect

var damage_bonus: int = 0
var condition: String = ""


func _init(bonus: int = 0, cond: String = "") -> void:
	damage_bonus = bonus
	condition = cond


func is_active(attacker_slot: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> bool:
	var top: CardInstance = attacker_slot.get_top_card()
	if top == null:
		return false
	var attacker_pi: int = top.owner_index
	var opponent_pi: int = 1 - attacker_pi
	if defender != null and defender != state.players[opponent_pi].active_pokemon:
		return false

	match condition:
		"ex":
			var target_ex: PokemonSlot = _get_target(attacker_slot, state, defender)
			if target_ex == null:
				return false
			var opp_data: CardData = target_ex.get_card_data()
			return opp_data != null and opp_data.mechanic == "ex"
		"V":
			var target_v: PokemonSlot = _get_target(attacker_slot, state, defender)
			if target_v == null:
				return false
			var opp_data_v: CardData = target_v.get_card_data()
			return opp_data_v != null and opp_data_v.mechanic in ["V", "VSTAR", "VMAX"]
		"prize_behind":
			return state.players[attacker_pi].prizes.size() > state.players[opponent_pi].prizes.size()
		"poisoned_self":
			return bool(attacker_slot.status_conditions.get("poisoned", false))
		_:
			return false


func get_bonus() -> int:
	return damage_bonus


func get_attack_modifier(attacker_slot: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> int:
	return damage_bonus if is_active(attacker_slot, state, defender) else 0


func _get_target(attacker_slot: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> PokemonSlot:
	if defender != null:
		return defender
	var top: CardInstance = attacker_slot.get_top_card()
	if top == null:
		return null
	return state.players[1 - top.owner_index].active_pokemon


func get_description() -> String:
	var cond_map := {
		"ex": "when the opponent's Active Pokemon is an ex",
		"V": "when the opponent's Active Pokemon is a V",
		"prize_behind": "when you are behind on prizes",
		"poisoned_self": "when the attached Pokemon is Poisoned",
	}
	var cond_str: String = str(cond_map.get(condition, condition))
	return "%s: attack damage +%d" % [cond_str, damage_bonus]
