class_name EffectSurfer
extends BaseEffect

const STEP_ID := "surfer_switch_target"


func can_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	var player: PlayerState = state.players[card.owner_index]
	return player.active_pokemon != null and not player.bench.is_empty()


func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if not can_execute(card, state):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append(slot.get_pokemon_name())
	return [{
		"id": STEP_ID,
		"title": "选择1只备战宝可梦与战斗宝可梦互换",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not can_execute(card, state):
		return
	var player: PlayerState = state.players[card.owner_index]
	var replacement: PokemonSlot = null
	var raw: Array = get_interaction_context(targets).get(STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot and raw[0] in player.bench:
		replacement = raw[0] as PokemonSlot
	if replacement == null:
		replacement = player.bench[0]
	_switch_active_with_bench(state, card.owner_index, replacement, "surfer")
	_draw_cards_with_log(state, card.owner_index, maxi(0, 5 - player.hand.size()), card, "trainer")


func get_description() -> String:
	return "Switch your Active Pokemon with a Benched Pokemon. Then, draw until you have 5 cards in hand."
