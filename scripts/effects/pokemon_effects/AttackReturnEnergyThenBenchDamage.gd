class_name AttackReturnEnergyThenBenchDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const EffectSparklingCrystalScript = preload("res://scripts/effects/tool_effects/EffectSparklingCrystal.gd")
const SPARKLING_CRYSTAL_EFFECT_ID := "12164ed03296d2df4ef6d0fa8b5f8aae"
const JAMMING_TOWER_EFFECT_ID := "4e16157bfa88a41e823d058a732df8e0"

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
	if attacker == null:
		return []
	var required_return_count := _effective_energy_return_count(attacker, attack, state)
	var energy_items: Array = attacker.attached_energy.duplicate()
	if energy_items.size() < required_return_count:
		return []
	if state.players[1 - card.owner_index].bench.is_empty():
		return []
	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name if energy.card_data != null else "")
	return [
		{
			"id": "return_energy_to_deck",
			"title": "选择%d个能量洗回牌库" % required_return_count,
			"items": energy_items,
			"labels": energy_labels,
			"card_groups": build_attached_card_groups(player, energy_items),
			"transparent_battlefield_dialog": true,
			"min_select": required_return_count,
			"max_select": required_return_count,
			"allow_cancel": true,
			"utility_actions": [{"label": "不洗回能量", "index": -1}],
		},
	]


func get_followup_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	var required_return_count := _effective_energy_return_count(attacker, attack, state)
	var energy_raw: Array = resolved_context.get("return_energy_to_deck", [])
	if energy_raw.size() < required_return_count:
		return []
	var bench_items: Array = state.players[1 - card.owner_index].bench.duplicate()
	if bench_items.is_empty():
		return []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in bench_items:
		bench_labels.append(slot.get_pokemon_name())
	return [
		{
			"id": "bench_target",
			"title": "选择对手的1只备战宝可梦",
			"items": bench_items,
			"labels": bench_labels,
			"min_select": 1,
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
	var attack: Dictionary = top.card_data.attacks[attack_index] if top.card_data != null and attack_index >= 0 and attack_index < top.card_data.attacks.size() else {}
	var required_return_count := _effective_energy_return_count(attacker, attack, state)
	var ctx: Dictionary = get_attack_interaction_context()
	var energy_raw: Array = ctx.get("return_energy_to_deck", [])
	if energy_raw.size() < required_return_count:
		return
	var target: PokemonSlot = _resolve_bench_target(ctx.get("bench_target", []), opponent)
	if target == null:
		return

	var returned: Array[CardInstance] = []
	for selected: Variant in energy_raw:
		var energy: CardInstance = _resolve_attached_energy(attacker, selected)
		if energy == null:
			continue
		attacker.attached_energy.erase(energy)
		energy.face_up = false
		player.deck.append(energy)
		returned.append(energy)

	if returned.size() < required_return_count:
		for energy: CardInstance in returned:
			player.deck.erase(energy)
			attacker.attached_energy.append(energy)
		return

	player.shuffle_deck()
	if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
		return
	DamageCalculator.new().apply_damage_to_slot(target, damage_amount)


func _resolve_attached_energy(attacker: PokemonSlot, selected: Variant) -> CardInstance:
	var selected_card: CardInstance = null
	if selected is CardInstance:
		selected_card = selected
	elif selected is Dictionary:
		var selected_dict := selected as Dictionary
		for key: String in ["card", "source", "energy"]:
			var value: Variant = selected_dict.get(key, null)
			if value is CardInstance:
				selected_card = value
				break
	if selected_card == null:
		return null
	for attached: CardInstance in attacker.attached_energy:
		if attached == selected_card or attached.instance_id == selected_card.instance_id:
			return attached
	return null


func _resolve_bench_target(target_raw: Variant, opponent: PlayerState) -> PokemonSlot:
	if not (target_raw is Array):
		return null
	var target_items: Array = target_raw
	if target_items.is_empty() or not (target_items[0] is PokemonSlot):
		return null
	var target: PokemonSlot = target_items[0]
	if target == null or target == opponent.active_pokemon or target not in opponent.bench:
		return null
	return target


func _effective_energy_return_count(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var modifier := _active_sparkling_crystal_any_cost_modifier(attacker, attack, state)
	if modifier < 0:
		return maxi(0, energy_return_count + modifier)
	return energy_return_count


func _active_sparkling_crystal_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	if attacker == null or attacker.attached_tool == null or attacker.attached_tool.card_data == null:
		return 0
	if attacker.attached_tool.card_data.effect_id != SPARKLING_CRYSTAL_EFFECT_ID:
		return 0
	if _is_attached_tool_suppressed(state):
		return 0
	var effect := EffectSparklingCrystalScript.new()
	return int(effect.get_attack_any_cost_modifier(attacker, attack, state))


func _is_attached_tool_suppressed(state: GameState) -> bool:
	if state == null or state.stadium_card == null or state.stadium_card.card_data == null:
		return false
	return state.stadium_card.card_data.effect_id == JAMMING_TOWER_EFFECT_ID


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
	return "You may shuffle %d Energy into your deck. If you do, deal %d damage to 1 opponent Benched Pokemon." % [energy_return_count, damage_amount]
