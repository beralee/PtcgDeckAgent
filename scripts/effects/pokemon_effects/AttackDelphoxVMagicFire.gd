## Delphox V - lost zone 2 attached Energy, then deal 120 to a chosen opponent Benched Pokemon.
class_name AttackDelphoxVMagicFire
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const ENERGY_STEP_ID := "delphox_v_lost_zone_energy"
const TARGET_STEP_ID := "delphox_v_bench_target"
const DAMAGE_AMOUNT: int = 120
const ENERGY_COUNT: int = 2

var attack_index_to_match: int = 1


func _init(match_attack_index: int = 1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.active_pokemon == null or player.active_pokemon.get_top_card() != card:
		return []
	if player.active_pokemon.attached_energy.size() < ENERGY_COUNT:
		return []
	if state.players[1 - card.owner_index].bench.is_empty():
		return []

	var energy_items: Array = player.active_pokemon.attached_energy.duplicate()
	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name)

	var target_items: Array = state.players[1 - card.owner_index].bench.duplicate()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "选择2个附着的能量放入放逐区",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": ENERGY_COUNT,
			"max_select": ENERGY_COUNT,
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "选择对手的1只备战宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


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
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()

	var selected_energy: Array[CardInstance] = _resolve_selected_energy(attacker, ctx.get(ENERGY_STEP_ID, []))
	if selected_energy.size() < ENERGY_COUNT:
		selected_energy = _fallback_energy(attacker)
	if selected_energy.size() < ENERGY_COUNT:
		return

	var target_slot: PokemonSlot = _resolve_target(opponent, ctx.get(TARGET_STEP_ID, []))
	if target_slot == null:
		return

	for energy_card: CardInstance in selected_energy:
		attacker.attached_energy.erase(energy_card)
		energy_card.face_up = true
		player.lost_zone.append(energy_card)

	if AbilityBenchImmune.has_bench_immune(target_slot):
		return
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target_slot, state):
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target_slot, state):
		return
	target_slot.damage_counters += DAMAGE_AMOUNT


func _resolve_selected_energy(attacker: PokemonSlot, selected_raw: Array) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry
		if selected in attacker.attached_energy and selected not in result:
			result.append(selected)
			if result.size() >= ENERGY_COUNT:
				break
	return result


func _fallback_energy(attacker: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for energy_card: CardInstance in attacker.attached_energy:
		result.append(energy_card)
		if result.size() >= ENERGY_COUNT:
			break
	return result


func _resolve_target(opponent: PlayerState, selected_raw: Array) -> PokemonSlot:
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in opponent.bench:
			return candidate
	return opponent.bench[0] if not opponent.bench.is_empty() else null


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
	return "Put 2 Energy attached to this Pokemon into the Lost Zone, then deal 120 to 1 opponent Benched Pokemon."
