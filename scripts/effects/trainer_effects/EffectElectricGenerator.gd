## Electric Generator - reveal the top 5 cards, then attach found Lightning Energy.
class_name EffectElectricGenerator
extends BaseEffect

const ASSIGNMENT_STEP_ID := "energy_assignments"

func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return false
	for slot: PokemonSlot in player.bench:
		if slot.get_energy_type() == "L":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	var reveal_labels: Array[String] = []
	for idx: int in mini(5, player.deck.size()):
		var reveal_card: CardInstance = player.deck[idx]
		reveal_labels.append(reveal_card.card_data.name)
		if _is_basic_lightning_energy(reveal_card):
			energy_items.append(reveal_card)
			energy_labels.append(reveal_card.card_data.name)

	var bench_items: Array = []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		if slot.get_energy_type() == "L":
			bench_items.append(slot)
			bench_labels.append("%s (%d/%d)" % [
				slot.get_pokemon_name(),
				slot.get_remaining_hp(),
				slot.get_max_hp(),
			])

	var reveal_title: String = "查看牌库顶端 5 张：%s" % ", ".join(reveal_labels)
	if energy_items.is_empty():
		return [{
			"id": "reveal_only",
			"title": "%s\n未找到可附着的基础雷能量" % reveal_title,
			"items": ["继续"],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	return [build_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"%s\n选择基础雷能量并分配给备战区雷属性宝可梦" % reveal_title,
		energy_items,
		energy_labels,
		bench_items,
		bench_labels,
		1,
		mini(2, energy_items.size()),
		true
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var reveal_cards: Array[CardInstance] = []
	for idx: int in mini(5, player.deck.size()):
		reveal_cards.append(player.deck[idx])

	var assignments: Array[Dictionary] = _resolve_assignments(player, reveal_cards, ctx)
	if assignments.is_empty():
		player.shuffle_deck()
		return

	for assignment: Dictionary in assignments:
		var energy: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy == null or target_slot == null:
			continue
		player.deck.erase(energy)
		energy.face_up = true
		target_slot.attached_energy.append(energy)

	player.shuffle_deck()


func get_description() -> String:
	return "查看牌库顶端 5 张，选择最多 2 张基础雷能量附着到备战区雷属性宝可梦。"


func _is_basic_lightning_energy(card: CardInstance) -> bool:
	return (
		card.card_data.card_type == "Basic Energy"
		and card.card_data.energy_provides == "L"
	)


func _resolve_assignments(player: PlayerState, reveal_cards: Array[CardInstance], ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_raw: Array = ctx.get(ASSIGNMENT_STEP_ID, [])
	var valid_targets: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.bench:
		if slot.get_energy_type() == "L":
			valid_targets.append(slot)
	var used_sources: Array[CardInstance] = []

	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy: CardInstance = source as CardInstance
		var slot: PokemonSlot = target as PokemonSlot
		if energy not in reveal_cards or not _is_basic_lightning_energy(energy):
			continue
		if slot not in valid_targets or energy in used_sources:
			continue
		used_sources.append(energy)
		result.append({
			"source": energy,
			"target": slot,
		})
		if result.size() >= 2:
			break
	return result
