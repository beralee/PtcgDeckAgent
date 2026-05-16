class_name AttackSelectOpponentBenchDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const STEP_ID := "opponent_bench_damage_targets"

var damage_amount: int = 40
var target_count: int = 2
var attack_index_to_match: int = -1


func _init(amount: int = 40, count: int = 2, match_attack_index: int = -1) -> void:
	damage_amount = amount
	target_count = count
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	if opponent.bench.is_empty():
		return []
	var items: Array = opponent.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	var count := mini(maxi(0, target_count), items.size())
	if count <= 0:
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose %d opponent Benched Pokemon" % count,
		"items": items,
		"labels": labels,
		"min_select": count,
		"max_select": count,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var chosen: Array[PokemonSlot] = _resolve_targets(opponent, mini(target_count, opponent.bench.size()))
	for target: PokemonSlot in chosen:
		if AbilityBenchImmune.prevents_opponent_attack_damage_or_effect(target, attacker, state):
			continue
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			continue
		if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
			continue
		DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _resolve_targets(opponent: PlayerState, limit: int) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is PokemonSlot and entry in opponent.bench and entry not in result:
			result.append(entry)
			if result.size() >= limit:
				return result
	for slot: PokemonSlot in opponent.bench:
		if slot not in result:
			result.append(slot)
			if result.size() >= limit:
				break
	return result


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Deal %d damage to %d opponent Benched Pokemon." % [damage_amount, target_count]
