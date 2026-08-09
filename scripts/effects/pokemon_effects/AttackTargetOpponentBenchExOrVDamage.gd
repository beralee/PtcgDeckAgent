class_name AttackTargetOpponentBenchExOrVDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const STEP_ID := "opponent_bench_ex_v_target"

var damage_amount: int = 60
var attack_index_to_match: int = -1


func _init(amount: int = 60, match_attack_index: int = -1) -> void:
	damage_amount = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func active_damage_is_invariant_under_interaction(attack_index: int) -> bool:
	return applies_to_attack_index(attack_index)


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var legal_targets := _legal_targets(state.players[1 - card.owner_index])
	if legal_targets.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in legal_targets:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": STEP_ID,
		"title": "选择对手备战区中的1只宝可梦ex或宝可梦V",
		"items": legal_targets,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var legal_targets := _legal_targets(state.players[1 - top.owner_index])
	if legal_targets.is_empty():
		return
	var target: PokemonSlot = null
	for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
		if raw is PokemonSlot and raw in legal_targets:
			target = raw
			break
	if target == null:
		target = legal_targets[0]
	if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
		return
	DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _legal_targets(opponent: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	if opponent == null:
		return targets
	for slot: PokemonSlot in opponent.bench:
		if slot != null and _is_pokemon_ex_or_v(slot.get_card_data()):
			targets.append(slot)
	return targets


static func _is_pokemon_ex_or_v(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_pokemon():
		return false
	var mechanic := card_data.mechanic.strip_edges().to_upper()
	if mechanic in ["EX", "V", "VSTAR", "VMAX"]:
		return true
	for raw_tag: String in card_data.is_tags:
		if raw_tag.strip_edges().to_upper() in ["EX", "V", "VSTAR", "VMAX"]:
			return true
	return false


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1


func get_description() -> String:
	return "Deal %d damage to 1 opponent Benched Pokemon ex or Pokemon V." % damage_amount
