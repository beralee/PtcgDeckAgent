class_name AttackCoinFlipDiscardOpponentActiveEnergy
extends BaseEffect

const ENERGY_STEP_ID := "discard_opponent_active_energy"

var attack_index_to_match: int = -1
var _coin_flipper: CoinFlipper = null


func _init(match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
	attack_index_to_match = match_attack_index
	_coin_flipper = flipper


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var active: PokemonSlot = opponent.active_pokemon
	if active == null or active.attached_energy.is_empty():
		return []
	var labels: Array[String] = []
	for energy: CardInstance in active.attached_energy:
		labels.append(energy.card_data.name if energy.card_data != null else "")
	return [{
		"id": ENERGY_STEP_ID,
		"title": "Select an Energy attached to the opponent Active to discard if heads",
		"items": active.attached_energy.duplicate(),
		"labels": labels,
		"card_groups": build_attached_card_groups(opponent, active.attached_energy),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
	if not flipper.flip():
		return

	var opponent: PlayerState = state.players[1 - top.owner_index]
	var active: PokemonSlot = opponent.active_pokemon
	if active == null or active.attached_energy.is_empty():
		return

	var energy := _selected_energy(active)
	if energy == null:
		energy = active.attached_energy[0]
	active.attached_energy.erase(energy)
	opponent.discard_card(energy)


func _selected_energy(active: PokemonSlot) -> CardInstance:
	var ctx := get_attack_interaction_context()
	var raw: Array = ctx.get(ENERGY_STEP_ID, [])
	if raw.is_empty():
		return null
	if raw[0] is CardInstance and raw[0] in active.attached_energy:
		return raw[0]
	if raw[0] is Dictionary:
		var entry: Dictionary = raw[0]
		var instance_id: int = int(entry.get("instance_id", entry.get("card_instance_id", -1)))
		for energy: CardInstance in active.attached_energy:
			if energy.instance_id == instance_id:
				return energy
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
	return "Flip a coin. If heads, discard an Energy from the opponent Active Pokemon."
