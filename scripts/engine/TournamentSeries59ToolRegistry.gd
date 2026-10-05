extends RefCounted

class TuneUp extends BaseEffect:
	func get_tool_limit(_slot: PokemonSlot, _state: GameState) -> int: return 4

static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	if card.effect_id == "ab8223ccdd32e7042b64196017d4d6db":
		processor.register_effect(card.effect_id, TuneUp.new())
		processor.replace_attack_effects(card.effect_id, [AttackReduceDamageNextTurn.new(30, 0)])
