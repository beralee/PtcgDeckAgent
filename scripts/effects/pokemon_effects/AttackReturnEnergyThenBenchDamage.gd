class_name AttackReturnEnergyThenBenchDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")

var damage_amount: int = 120
var energy_return_count: int = 3
var attack_index_to_match: int = -1


func _init(amount: int = 120, match_attack_index: int = -1, return_count: int = 3) -> void:
	damage_amount = amount
	attack_index_to_match = match_attack_index
	energy_return_count = return_count


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	var energy_items: Array = attacker.attached_energy.duplicate()
	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name)
	var bench_items: Array = state.players[1 - card.owner_index].bench.duplicate()
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in bench_items:
		bench_labels.append(slot.get_pokemon_name())
	var can_return: bool = energy_items.size() >= energy_return_count
	return [
		{
			"id": "return_energy_to_deck",
			"title": "Choose %d Energy to shuffle into the deck" % energy_return_count,
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 0,
			"max_select": mini(energy_return_count, energy_items.size()) if can_return else 0,
			"allow_cancel": true,
		},
		{
			"id": "bench_target",
			"title": "Choose 1 opponent Benched Pokemon",
			"items": bench_items,
			"labels": bench_labels,
			"min_select": 1 if not bench_items.is_empty() else 0,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var energy_raw: Array = ctx.get("return_energy_to_deck", [])
	if energy_raw.size() < energy_return_count:
		return

	var returned: Array[CardInstance] = []
	for selected: Variant in energy_raw:
		if not (selected is CardInstance):
			continue
		var energy: CardInstance = null
		for attached: CardInstance in attacker.attached_energy:
			if attached == selected or attached.instance_id == (selected as CardInstance).instance_id:
				energy = attached
				break
		if energy == null:
			continue
		attacker.attached_energy.erase(energy)
		energy.face_up = false
		player.deck.append(energy)
		returned.append(energy)

	if returned.size() < energy_return_count:
		for energy: CardInstance in returned:
			player.deck.erase(energy)
			attacker.attached_energy.append(energy)
		return

	player.shuffle_deck()
	var target_raw: Array = ctx.get("bench_target", [])
	if target_raw.is_empty() or not (target_raw[0] is PokemonSlot):
		return
	var target: PokemonSlot = target_raw[0]
	if target == null or target == opponent.active_pokemon:
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
		return
	DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "You may shuffle %d Energy into your deck. If you do, deal %d damage to 1 opponent Benched Pokemon." % [energy_return_count, damage_amount]
