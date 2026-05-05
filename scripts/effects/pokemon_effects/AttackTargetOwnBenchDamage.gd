class_name AttackTargetOwnBenchDamage
extends BaseEffect

const STEP_ID := "self_bench_target"

var damage_amount: int = 10
var attack_index_to_match: int = -1


func _init(amount: int = 10, match_attack_index: int = -1) -> void:
	damage_amount = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.bench.is_empty():
		return []
	var items: Array = player.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": STEP_ID,
		"title": "选择己方1只备战宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.bench.is_empty():
		return
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var target: PokemonSlot = null
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot and selected_raw[0] in player.bench:
		target = selected_raw[0]
	if target == null:
		target = player.bench[0]
	DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1
