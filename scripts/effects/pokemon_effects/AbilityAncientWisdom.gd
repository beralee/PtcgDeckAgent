class_name AbilityAncientWisdom
extends BaseEffect

const ENERGY_STEP_ID := "ancient_wisdom_energy"
const TARGET_STEP_ID := "ancient_wisdom_target"
const USED_KEY := "ability_ancient_wisdom_used"
const REQUIRED_REGIS := ["regirock", "regice", "registeel", "regieleki", "regidrago"]

var attach_count: int = 3


func _init(count: int = 3) -> void:
	attach_count = max(0, count)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	if _has_used_this_turn(pokemon, state):
		return false
	var player: PlayerState = state.players[pi]
	return _has_required_regis(player) and not _energy_cards(player.discard_pile).is_empty() and not player.get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var energies: Array[CardInstance] = _energy_cards(player.discard_pile)
	if energies.is_empty():
		return []
	var energy_labels: Array[String] = []
	for energy: CardInstance in energies:
		energy_labels.append(energy.card_data.name if energy.card_data != null else "")
	var targets: Array = player.get_all_pokemon()
	if targets.is_empty():
		return []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in targets:
		target_labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "Choose up to %d Energy cards from your discard pile" % attach_count,
			"items": energies,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": mini(attach_count, energies.size()),
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "Choose 1 of your Pokemon to attach the Energy to",
			"items": targets,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_energy: Array[CardInstance] = _resolve_energy(player, ctx)
	var target_slot: PokemonSlot = _resolve_target(player, ctx)
	if selected_energy.is_empty() or target_slot == null:
		return
	for energy: CardInstance in selected_energy:
		if energy not in player.discard_pile:
			continue
		player.discard_pile.erase(energy)
		energy.face_up = true
		target_slot.attached_energy.append(energy)
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func _resolve_energy(player: PlayerState, ctx: Dictionary) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var candidates: Array[CardInstance] = _energy_cards(player.discard_pile)
	var selected_raw: Array = ctx.get(ENERGY_STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in candidates and entry not in result:
			result.append(entry)
			if result.size() >= attach_count:
				return result
	if not result.is_empty() or ctx.has(ENERGY_STEP_ID):
		return result
	for i: int in mini(attach_count, candidates.size()):
		result.append(candidates[i])
	return result


func _resolve_target(player: PlayerState, ctx: Dictionary) -> PokemonSlot:
	var selected_raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot and selected_raw[0] in player.get_all_pokemon():
		return selected_raw[0]
	var targets: Array[PokemonSlot] = player.get_all_pokemon()
	return targets[0] if not targets.is_empty() else null


func _energy_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.is_energy():
			result.append(card)
	return result


func _has_required_regis(player: PlayerState) -> bool:
	var found: Dictionary = {}
	for slot: PokemonSlot in player.get_all_pokemon():
		var key := _regi_key(slot)
		if key != "":
			found[key] = true
	for required: String in REQUIRED_REGIS:
		if not found.has(required):
			return false
	return true


func _regi_key(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return ""
	var names := [cd.name.to_lower(), cd.name_en.to_lower()]
	for name: String in names:
		if name.contains("regirock") or name.contains("雷吉洛克"):
			return "regirock"
		if name.contains("regice") or name.contains("雷吉艾斯"):
			return "regice"
		if name.contains("registeel") or name.contains("雷吉斯奇鲁"):
			return "registeel"
		if name.contains("regieleki") or name.contains("雷吉艾勒奇"):
			return "regieleki"
		if name.contains("regidrago") or name.contains("雷吉铎拉戈"):
			return "regidrago"
	return ""


func _has_used_this_turn(pokemon: PokemonSlot, state: GameState) -> bool:
	for effect: Dictionary in pokemon.effects:
		if effect.get("type", "") == USED_KEY and int(effect.get("turn", -999)) == state.turn_number:
			return true
	return false


func get_description() -> String:
	return "If you have Regirock, Regice, Registeel, Regieleki, and Regidrago in play, attach up to 3 Energy from your discard pile to 1 of your Pokemon."
