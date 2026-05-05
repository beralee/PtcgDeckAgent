## 伏特旋风 - 选择攻击者身上1个能量，转附于备战宝可梦
class_name AttackMoveEnergyToBench
extends BaseEffect


func get_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var attacker: PokemonSlot = player.active_pokemon
	if attacker == null or attacker.attached_energy.is_empty() or player.bench.is_empty():
		return []

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for e: CardInstance in attacker.attached_energy:
		energy_items.append(e)
		energy_labels.append(e.card_data.name if e.card_data != null else "能量")

	var bench_items: Array = []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		bench_items.append(slot)
		bench_labels.append(slot.get_pokemon_name())

	return [
		{
			"id": "move_energy",
			"title": "选择要转移的1个能量",
			"items": energy_items,
			"labels": energy_labels,
			"card_groups": build_attached_card_groups(player, energy_items),
			"transparent_battlefield_dialog": true,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "move_target",
			"title": "选择要接收能量的备战宝可梦",
			"items": bench_items,
			"labels": bench_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or attacker.get_top_card() == null:
		return
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	if attacker.attached_energy.is_empty() or player.bench.is_empty():
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var energy: CardInstance = null
	var target: PokemonSlot = null

	var energy_raw: Array = ctx.get("move_energy", [])
	if not energy_raw.is_empty() and energy_raw[0] is CardInstance:
		var selected: CardInstance = energy_raw[0]
		if selected in attacker.attached_energy:
			energy = selected

	var target_raw: Array = ctx.get("move_target", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var selected: PokemonSlot = target_raw[0]
		if selected in player.bench:
			target = selected

	if energy == null:
		energy = attacker.attached_energy[0]
	if target == null:
		target = player.bench[0]

	attacker.attached_energy.erase(energy)
	target.attached_energy.append(energy)


func get_description() -> String:
	return "选择攻击者身上1个能量，转附于备战宝可梦"
