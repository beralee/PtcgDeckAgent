class_name AttackGreninjaExMirageBarrage
extends BaseEffect

var attack_index_to_match: int = -1
var damage_amount: int = 120
var discard_count: int = 2


func _init(match_attack_index: int = -1, damage: int = 120, energy_to_discard: int = 2) -> void:
	attack_index_to_match = match_attack_index
	damage_amount = damage
	discard_count = energy_to_discard


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	if attacker != null:
		energy_items = attacker.attached_energy.duplicate()
		for energy: CardInstance in energy_items:
			energy_labels.append(energy.card_data.name)

	var target_items: Array = state.players[1 - card.owner_index].get_all_pokemon()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())

	return [{
		"id": "greninja_ex_discard_energy",
		"title": "Choose 2 attached Energy to discard",
		"items": energy_items,
		"labels": energy_labels,
		"min_select": mini(discard_count, energy_items.size()),
		"max_select": mini(discard_count, energy_items.size()),
		"allow_cancel": false,
	}, {
		"id": "greninja_ex_targets",
		"title": "Choose up to 2 opponent Pokemon",
		"items": target_items,
		"labels": target_labels,
		"min_select": mini(2, target_items.size()),
		"max_select": mini(2, target_items.size()),
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()

	var selected_energy_ids: Dictionary = {}
	for entry: Variant in ctx.get("greninja_ex_discard_energy", []):
		if entry is CardInstance:
			selected_energy_ids[(entry as CardInstance).instance_id] = true
	if selected_energy_ids.is_empty():
		return

	var discarded: Array[CardInstance] = []
	var kept_energy: Array[CardInstance] = []
	for energy: CardInstance in attacker.attached_energy:
		if discarded.size() < discard_count and selected_energy_ids.has(energy.instance_id):
			discarded.append(energy)
		else:
			kept_energy.append(energy)
	if discarded.size() < mini(discard_count, attacker.attached_energy.size()):
		return
	attacker.attached_energy = kept_energy
	for energy: CardInstance in discarded:
		energy.face_up = true
		player.discard_pile.append(energy)

	var selected_targets: Dictionary = {}
	for entry: Variant in ctx.get("greninja_ex_targets", []):
		if not (entry is PokemonSlot):
			continue
		var target := entry as PokemonSlot
		if target in opponent.get_all_pokemon():
			selected_targets[target.get_instance_id()] = target

	for target: PokemonSlot in selected_targets.values():
		if target in opponent.bench and AbilityBenchImmune.has_bench_immune(target):
			continue
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			continue
		target.damage_counters += damage_amount


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))


func get_description() -> String:
	return "Discard 2 Energy from this Pokemon and deal damage to 2 opponent Pokemon."
