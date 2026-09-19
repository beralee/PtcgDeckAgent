## Exact effect identities from https://tcg.mik.moe/cards/30thDC.
extends RefCounted

const E = preload("res://scripts/effects/ThirtiethDeluxeEffects.gd")
const Celebration = preload("res://scripts/effects/ThirtiethCelebrationEffects.gd")


static func register_fixed(processor: EffectProcessor) -> void:
	processor.register_effect("187d694096b96c54af0f7463c5e2b2b4", E.Potion.new()) # 028
	processor.register_effect("0c06539cb1ff6391b61c2556d2d11e58", E.Waitress.new()) # 035
	processor.register_effect("dab522c268c493ffb5410114f7f1f2ca", EffectDrawCards.new(3)) # 036
	processor.register_effect("d57b61102355e6a0407d0aeb4db9477d", EffectLilliesDetermination.new()) # 040


static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	var effects: Array = []
	match card.effect_id:
		"2919f9b010416347360126d812a61b87": # 001
			effects = [E.AttackComeback.new()]
		"ce61353f9bb746d0f81652fe0e3d7b3c": # 002
			effects = [AttackCoinFlipPreventDamageAndEffectsNextTurn.new(processor.coin_flipper, 0)]
		"4d90b958bac79c1ca798260fab8c7771": # 003
			var attach := AttackSearchAndAttach.new("", 2, "deck_search", 0, "any")
			attach.attack_index_to_match = 0
			effects = [attach]
		"64758fae3b6ce94027c06e119a6b2397": # 004
			var flip := AttackCoinFlipOrFail.new(30, "no_damage", processor.coin_flipper)
			flip.bind_default_attack_index(0)
			effects = [flip]
		"b7f7481e95ba441dd03d3cfe331b3596": # 006 (generic name route only searches one)
			var family := AttackCallForFamily.new(2)
			family.bind_default_attack_index(0)
			effects = [family]
		"d34a44981052506ad934470c29c9ed32": # 007
			effects = [AttackDrawCards.new(1, 0), Celebration.AttackBenchTarget.new(20, 1)]
		"8bb1d36f1e56079e0f50cb0917736300": # 013
			var paralysis := AttackCoinFlipApplyStatus.new("paralyzed", processor.coin_flipper)
			paralysis.bind_default_attack_index(0)
			effects = [paralysis]
		"d765168a2339f9446f4ee88bb9aff5d7": # 014: printed 30 + 30 per Bench = all own Pokemon
			var board := AttackBenchCountDamage.new(30, "self", false)
			board.bind_default_attack_index(0)
			effects = [board]
		"07474feb6ce288c2f43fa9b2f9fc3408": # 015
			effects = [CSV9CSimpleHealSelfAfterAttack.new(30, 0)]
		"71bd2afec3389ee13481c71b980ca790": # 016
			effects = [E.AttackSoothingScent.new()]
		"8e0a04d63667ed7dc2156b4fdb9220ab": # 017
			effects = [AttackBonusIfDefenderDamaged.new(140, 0)]
		"9995fb384ac73eff14fc1f35399ec716": # 018
			effects = [E.AttackGentleGrip.new(processor.coin_flipper)]
		"8a89529177eff0e771a3da6cd765ff54": # 020
			processor.register_effect(card.effect_id, E.AbilityNightPath.new())
			return
		"607f252260b417d92ddbc53cdc07a599": # 023
			effects = [E.AttackTripleBite.new(processor.coin_flipper)]
		"091e1fac0abbaef2722d9a2e82da5e3d": # 024
			effects = [AttackSelfDamageCounterBonus.new(10, 0)]
		"d55a30533789115b7c2d85e09c899e32": # 025/026
			effects = [E.AttackQuickAttack.new(processor.coin_flipper)]
		"84ab979321ed4fbfb16135c683891bb0": # 027
			effects = [E.AttackMeteorShot.new()]
		_:
			return
	processor.replace_attack_effects(card.effect_id, effects)
