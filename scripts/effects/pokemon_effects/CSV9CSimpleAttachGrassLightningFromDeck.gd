class_name CSV9CSimpleAttachGrassLightningFromDeck
extends BaseEffect

const GRASS_STEP_ID := "csv9c_grass_energy_assignments"
const LIGHTNING_STEP_ID := "csv9c_lightning_energy_assignments"

var max_per_type: int = 2
var attack_index_to_match: int = -1


func _init(per_type_count: int = 2, match_attack_index: int = -1) -> void:
	max_per_type = max(0, per_type_count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var targets := _own_pokemon(player)
	if targets.is_empty():
		return []
	var steps: Array[Dictionary] = []
	_append_assignment_step(steps, player, targets, "G", GRASS_STEP_ID, "Assign Grass Energy from your deck")
	_append_assignment_step(steps, player, targets, "L", LIGHTNING_STEP_ID, "Assign Lightning Energy from your deck")
	return steps


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
	var player: PlayerState = state.players[top.owner_index]
	var targets := _own_pokemon(player)
	var ctx := get_attack_interaction_context()
	_attach_for_type(player, targets, ctx, "G", GRASS_STEP_ID)
	_attach_for_type(player, targets, ctx, "L", LIGHTNING_STEP_ID)
	player.shuffle_deck()


func _append_assignment_step(
	steps: Array[Dictionary],
	player: PlayerState,
	targets: Array[PokemonSlot],
	energy_type: String,
	step_id: String,
	title: String
) -> void:
	var candidates := _matching_energy(player.deck, energy_type)
	if candidates.is_empty():
		return
	var source_labels: Array[String] = []
	for energy: CardInstance in candidates:
		source_labels.append(energy.card_data.name if energy.card_data != null else "")
	var target_labels := _target_labels(targets)
	steps.append(build_full_library_card_assignment_step(
		step_id,
		title,
		player.deck,
		candidates,
		source_labels,
		targets,
		target_labels,
		0,
		mini(max_per_type, candidates.size()),
		VISIBLE_SCOPE_OWN_FULL_DECK,
		true
	))


func _attach_for_type(
	player: PlayerState,
	targets: Array[PokemonSlot],
	ctx: Dictionary,
	energy_type: String,
	step_id: String
) -> void:
	var candidates := _matching_energy(player.deck, energy_type)
	if candidates.is_empty() or targets.is_empty():
		return
	var assignments := _resolve_assignments(ctx.get(step_id, []), candidates, targets, mini(max_per_type, candidates.size()))
	if assignments.is_empty() and not ctx.has(step_id):
		assignments = _fallback_assignments(candidates, targets[0], mini(max_per_type, candidates.size()))
	for assignment: Dictionary in assignments:
		var source: CardInstance = assignment.get("source")
		var target: PokemonSlot = assignment.get("target")
		if source == null or target == null or not (source in player.deck):
			continue
		player.deck.erase(source)
		source.face_up = true
		target.attached_energy.append(source)


func _resolve_assignments(raw: Array, candidates: Array[CardInstance], targets: Array[PokemonSlot], limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_sources: Dictionary = {}
	for entry: Variant in raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source := _resolve_card(candidates, assignment.get("source"))
		var target := assignment.get("target") as PokemonSlot
		if source == null or target == null or not (target in targets):
			continue
		if used_sources.has(source.instance_id):
			continue
		used_sources[source.instance_id] = true
		result.append({"source": source, "target": target})
		if result.size() >= limit:
			break
	return result


func _fallback_assignments(candidates: Array[CardInstance], target: PokemonSlot, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in limit:
		result.append({"source": candidates[i], "target": target})
	return result


func _matching_energy(cards: Array[CardInstance], energy_type: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if _is_basic_energy_type(card, energy_type):
			result.append(card)
	return result


func _is_basic_energy_type(card: CardInstance, energy_type: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var data := card.card_data
	if data.card_type != "Basic Energy":
		return false
	return data.energy_type == energy_type or data.energy_provides == energy_type


func _own_pokemon(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	if player == null:
		return result
	if player.active_pokemon != null:
		result.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			result.append(slot)
	return result


func _target_labels(targets: Array[PokemonSlot]) -> Array[String]:
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append(slot.get_pokemon_name())
	return labels


func _resolve_card(candidates: Array[CardInstance], entry: Variant) -> CardInstance:
	if entry is CardInstance and entry in candidates:
		return entry
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		var instance_id := int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
		for card: CardInstance in candidates:
			if card.instance_id == instance_id:
				return card
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
	return "Attach up to two Grass and up to two Lightning Basic Energy from your deck to your Pokemon."
