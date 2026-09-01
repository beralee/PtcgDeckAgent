extends BaseEffect

var attack_index_to_match: int = -1
var required_defender_mechanic: String = ""


func _init(match_attack_index: int = -1, required_mechanic: String = "") -> void:
	attack_index_to_match = match_attack_index
	required_defender_mechanic = required_mechanic.to_lower()


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return []
	var opponent: PlayerState = state.players[opponent_index]
	var defender: PokemonSlot = opponent.active_pokemon
	if not _is_valid_defender(defender) or defender.attached_energy.is_empty():
		return []
	var items: Array = []
	var labels: Array[String] = []
	for energy: CardInstance in defender.attached_energy:
		items.append(energy)
		labels.append(energy.card_data.name)
	return [{
		"id": "target_energy",
		"title": "选择对手战斗宝可梦身上的1个能量",
		"items": items,
		"labels": labels,
		"card_groups": build_attached_card_groups(opponent, items),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index) or attacker == null or state == null:
		return
	if not _is_valid_defender(defender) or defender.attached_energy.is_empty():
		return
	var selected: CardInstance = null
	var raw: Array = get_attack_interaction_context().get("target_energy", [])
	if not raw.is_empty() and raw[0] is CardInstance and raw[0] in defender.attached_energy:
		selected = raw[0] as CardInstance
	if selected == null:
		selected = defender.attached_energy[0]
	defender.attached_energy.erase(selected)
	var opponent_index := 1 - attacker.get_top_card().owner_index
	state.players[opponent_index].discard_card(selected)
	_record_attack_effect_discarded_attached_energy(attacker, selected, state)


func _is_valid_defender(defender: PokemonSlot) -> bool:
	if defender == null or defender.get_card_data() == null:
		return false
	if required_defender_mechanic == "":
		return true
	var card_data := defender.get_card_data()
	return card_data.mechanic.to_lower() == required_defender_mechanic or card_data.has_tag(required_defender_mechanic)


func get_description() -> String:
	return "Discard an Energy from your opponent's Active Pokemon."
