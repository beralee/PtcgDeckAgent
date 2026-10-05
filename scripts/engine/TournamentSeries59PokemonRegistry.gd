extends RefCounted

const Effects = preload("res://scripts/effects/pokemon_effects/TournamentSeries59PokemonEffects.gd")
const SelfDamageBonus = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterBonus.gd")
const Recoil = preload("res://scripts/effects/pokemon_effects/EffectSelfDamage.gd")
const Guard = preload("res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd")

static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	match card.effect_id:
		"3c059ab293ff488fdfe4b1b8282053b2": # 151C 085 Dodrio: Raging Draw / Ballistic Beak.
			processor.register_effect(card.effect_id, Effects.RagingDraw.new())
			processor.replace_attack_effects(card.effect_id, [SelfDamageBonus.new(30, 0)])
		"dea85315621ce2efd111b12d1e2fbc79": # CSV6C 015 Espathra ex: Dazzling Gaze / Psy Ball.
			processor.register_effect(card.effect_id, Effects.DazzlingGaze.new())
			processor.replace_attack_effects(card.effect_id, [Effects.ActiveEnergyCountBonus.new(processor, 30, true)])
		"1e38b408b75cc5ec2a7d0cc98a761420": # CSV6C 060 Flittle: Psychic is 10 per opposing Energy.
			processor.replace_attack_effects(card.effect_id, [Effects.ActiveEnergyCountBonus.new(processor, 10, false)])
		"70f02f5c8d8cccba81edc75ac5eb4f46": # CSV1C 044 Magnezone ex.
			processor.replace_attack_effects(card.effect_id, [Effects.OpponentFieldEnergyDamage.new(processor), Recoil.new(30, 1)])
		"ea313f5fb16a8fa1ee1594a403534d27": # CSV1C 071 Annihilape.
			processor.replace_attack_effects(card.effect_id, [Effects.OpponentTakenPrizeDamage.new(), Recoil.new(50, 1)])
		"4364b8582611727c6d832f681c40dfe4": # CSV5C 021 Armarouge ex.
			processor.register_effect(card.effect_id, Effects.CrimsonArmor.new())
			processor.replace_attack_effects(card.effect_id, [Effects.FireEnergyBonus.new(processor)])
		"1d232492f05784c869bd73a62bd1e484": # CSV3C 005 Forretress ex.
			processor.register_effect(card.effect_id, Effects.ExplodingEnergy.new())
			processor.replace_attack_effects(card.effect_id, [Guard.new(30, 0)])
		"9050fd41ac6abcce248c52570001e8e8": # CSV7C 095 Bronzong.
			processor.replace_attack_effects(card.effect_id, [Effects.EvolutionInterference.new()])
		"5eddf621d8b7bca3d4e0f737b4daea19": # CSV1C 015 Smoliv.
			processor.replace_attack_effects(card.effect_id, [Effects.OilSplash.new()])
