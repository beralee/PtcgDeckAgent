class_name AttackMoveAttachedEnergyToOwnBench
extends BaseEffect

const ENERGY_STEP_ID := "move_attached_energy"
const TARGET_STEP_ID := "move_energy_target"

var move_count: int = 2
var required_energy_type: String = ""
var attack_index_to_match: int = -1


func _init(count: int = 2, energy_type: String = "", match_attack_index: int = -1) -> void:
	move_count = max(0, count)
	required_energy_type = energy_type
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	if attacker == null or player.bench.is_empty():
		return []
	var energy_items := _matching_attached_energy(attacker)
	if energy_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name if energy.card_data != null else "")

	var bench_items: Array = []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		bench_items.append(slot)
		bench_labels.append(slot.get_pokemon_name())

	var required: int = mini(move_count, energy_items.size())
	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "Select attached Energy to move",
			"items": energy_items,
			"labels": energy_labels,
			"card_groups": build_attached_card_groups(player, energy_items),
			"transparent_battlefield_dialog": true,
			"min_select": required,
			"max_select": required,
			"allow_cancel": false,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "Select a Benched Pokemon to receive Energy",
			"items": bench_items,
			"labels": bench_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		},
	]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.bench.is_empty():
		return

	var selected_energy := _selected_energy(attacker)
	if selected_energy.is_empty():
		selected_energy = _matching_attached_energy(attacker)
	if selected_energy.is_empty():
		return
	if selected_energy.size() > move_count:
		selected_energy = selected_energy.slice(0, move_count)

	var target := _selected_target(player)
	if target == null:
		target = player.bench[0]

	for energy: CardInstance in selected_energy:
		if energy in attacker.attached_energy:
			attacker.attached_energy.erase(energy)
			target.attached_energy.append(energy)


func _matching_attached_energy(attacker: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for energy: CardInstance in attacker.attached_energy:
		if _matches_energy_type(energy):
			result.append(energy)
	return result


func _matches_energy_type(energy: CardInstance) -> bool:
	if required_energy_type == "":
		return true
	if energy == null or energy.card_data == null:
		return false
	var provides := energy.card_data.energy_provides
	if provides == "":
		provides = energy.card_data.energy_type
	return provides == required_energy_type


func _selected_energy(attacker: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	var ctx := get_attack_interaction_context()
	var raw: Array = ctx.get(ENERGY_STEP_ID, [])
	for entry: Variant in raw:
		var energy := _resolve_energy(attacker, entry)
		if energy != null and not seen_ids.has(energy.instance_id):
			seen_ids[energy.instance_id] = true
			result.append(energy)
	return result


func _resolve_energy(attacker: PokemonSlot, entry: Variant) -> CardInstance:
	if entry is CardInstance and entry in attacker.attached_energy and _matches_energy_type(entry):
		return entry
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		var instance_id: int = int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
		for energy: CardInstance in attacker.attached_energy:
			if energy.instance_id == instance_id and _matches_energy_type(energy):
				return energy
	return null


func _selected_target(player: PlayerState) -> PokemonSlot:
	var ctx := get_attack_interaction_context()
	var raw: Array = ctx.get(TARGET_STEP_ID, [])
	if raw.is_empty():
		return null
	if raw[0] is PokemonSlot and raw[0] in player.bench:
		return raw[0]
	return null


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
	return "Move attached Energy from this Pokemon to one of your Benched Pokemon."
