class_name Batch3178WorkerCSupportPokemonEffects
extends RefCounted

const EffectSelfDamageScript = preload("res://scripts/effects/pokemon_effects/EffectSelfDamage.gd")
const AttackCallForFamilyScript = preload("res://scripts/effects/pokemon_effects/AttackCallForFamily.gd")

const EFFECT_151C_081_MAGNEMITE := "5c0716ee309a1b95a0ae5c534069b0d2"
const EFFECT_CSV2C_036_MAGNEMITE := "ace38c46277a54785c65568606be8e92"
const EFFECT_CSV9C_055_MAGNEMITE := "9623df4f29632710111721868fa5e7a5"
const EFFECT_151C_016_PIDGEY := "c52439ea1ed321c25091b60e04c0d1da"
const EFFECT_CSV7C_159_HOOTHOOT := "65442467f2645f5983fe6604e5bdc8d2"


static func create_attack_effects_for_effect_id(effect_id: String) -> Array[BaseEffect]:
	match effect_id:
		EFFECT_151C_081_MAGNEMITE:
			return [EffectSelfDamageScript.new(60, 1)]
		EFFECT_151C_016_PIDGEY:
			var call_for_family: BaseEffect = AttackCallForFamilyScript.new(2)
			call_for_family.bind_default_attack_index(0)
			return [call_for_family]
		EFFECT_CSV7C_159_HOOTHOOT:
			return [SilentWingsOpponentHandPreview.new(0)]
		EFFECT_CSV2C_036_MAGNEMITE, EFFECT_CSV9C_055_MAGNEMITE:
			return []
		_:
			return []


static func get_lead_attack_registration_rows() -> Array[Dictionary]:
	return [
		{
			"effect_id": EFFECT_151C_081_MAGNEMITE,
			"class": "EffectSelfDamage",
			"constructor": "new(60, 1)",
			"attack_index": 1,
			"attack_name": "Explosion",
		},
		{
			"effect_id": EFFECT_151C_016_PIDGEY,
			"class": "AttackCallForFamily",
			"constructor": "new(2)",
			"attack_index": 0,
			"attack_name": "Call for Family",
		},
		{
			"effect_id": EFFECT_CSV7C_159_HOOTHOOT,
			"class": "Batch3178WorkerCSupportPokemonEffects.SilentWingsOpponentHandPreview",
			"constructor": "new(0)",
			"attack_index": 0,
			"attack_name": "Silent Wings",
		},
	]


class SilentWingsOpponentHandPreview extends BaseEffect:
	var attack_index_to_match: int = 0


	func _init(match_attack_index: int = 0) -> void:
		attack_index_to_match = match_attack_index


	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index_to_match == attack_index


	func get_attack_interaction_steps(
		card: CardInstance,
		_attack: Dictionary,
		state: GameState
	) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var owner_index := card.owner_index
		var opponent_index := 1 - owner_index
		if opponent_index < 0 or opponent_index >= state.players.size():
			return []
		var opponent: PlayerState = state.players[opponent_index]
		if opponent == null or opponent.hand.is_empty():
			return []

		var cards: Array = opponent.hand.duplicate()
		var labels: Array[String] = []
		for hand_card: CardInstance in cards:
			labels.append(_label_for_card(hand_card))
		return [{
			"id": "opponent_hand_preview",
			"title": "View opponent hand",
			"items": cards,
			"labels": labels,
			"min_select": 0,
			"max_select": 0,
			"allow_cancel": false,
			"presentation": "cards",
			"card_items": cards,
			"card_click_selectable": false,
			"force_confirm": true,
			"visible_scope": "opponent_hand",
			"utility_actions": [{"label": "Continue", "index": -1}],
		}]


	func execute_attack(
		_attacker: PokemonSlot,
		_defender: PokemonSlot,
		_attack_index: int,
		_state: GameState
	) -> void:
		pass


	func get_description() -> String:
		return "View the opponent's hand."


	func _label_for_card(card: CardInstance) -> String:
		if card == null or card.card_data == null:
			return "Unknown"
		var cd := card.card_data
		var name := str(cd.name_en).strip_edges()
		if name == "":
			name = str(cd.name).strip_edges()
		if cd.is_pokemon():
			return "%s (HP %d)" % [name, cd.hp]
		return name
