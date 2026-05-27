class_name AttackOptionalBonusSelfDamage
extends BaseEffect

const STEP_ID := "optional_bonus_self_damage"

var damage_bonus: int = 0
var self_damage: int = 0
var attack_index_to_match: int = -1
var prompt_title: String = ""


func _init(bonus: int = 0, recoil: int = 0, match_attack_index: int = -1, title: String = "") -> void:
	damage_bonus = bonus
	self_damage = recoil
	attack_index_to_match = match_attack_index
	prompt_title = title


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(_card: CardInstance, attack: Dictionary, _state: GameState) -> Array[Dictionary]:
	var attack_index := int(attack.get("_override_attack_index", attack.get("index", attack_index_to_match)))
	if not applies_to_attack_index(attack_index):
		return []
	var title := prompt_title
	if title == "":
		title = "追加%d伤害，并给自己造成%d伤害？" % [damage_bonus, self_damage]
	return [{
		"id": STEP_ID,
		"title": title,
		"items": ["no", "yes"],
		"labels": ["不追加", "追加"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func get_damage_bonus(_attacker: PokemonSlot, _state: GameState) -> int:
	return damage_bonus if _selected_yes() else 0


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, _state: GameState) -> void:
	if attacker == null or not applies_to_attack_index(attack_index) or not _selected_yes():
		return
	attacker.damage_counters += self_damage


func get_description() -> String:
	return "You may add %d damage. If you do, this Pokemon does %d damage to itself." % [damage_bonus, self_damage]


func _selected_yes() -> bool:
	var selected_raw: Array = get_attack_interaction_context().get(STEP_ID, [])
	return not selected_raw.is_empty() and str(selected_raw[0]) == "yes"
