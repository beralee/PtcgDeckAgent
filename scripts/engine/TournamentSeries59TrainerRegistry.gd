extends RefCounted

const E := preload("res://scripts/effects/TournamentSeries59TrainerEffects.gd")

static func register_fixed(processor: EffectProcessor) -> void:
	processor.register_effect("b9c904c0285e30282f6bc5b43b5479c4", E.HealTargets.new(50, 2, false, false, false, processor)) # CSV2C_122 Saguaro
	processor.register_effect("c2910457bc7fd02aa51bb4fa59618368", E.HealTargets.new(0, 1, true, false, true, processor)) # CSV7C_198 Bianca
	processor.register_effect("2002cf21cc417f766451ab5760e81560", E.HealTargets.new(150, 1, false, false, false, processor)) # CSV8C_180 Poke Vital A
	processor.register_effect("601387a0c0610f55b540d562e9379fa5", E.HealTargets.new(60, 1, false, true, false, processor)) # SVP_341 Pokemon Center Lady
	processor.register_effect("10aa378456f578af10dfb5c2ff38c878", EffectStadiumRetreatModifier.new(-1, "Basic"))
	processor.register_effect("45e96e576a5a81e61acd2e46a81547b4", E.PracticeStudio.new())
	processor.register_effect("716f25159d0f0b7693eb93f3fb26a4cd", E.MedicalEnergy.new())
	processor.register_effect("cbc04dc354816e1a5795de522630d8d1", E.DangerousLaser.new())
	processor.register_effect("2c910670d5c291e5f2c379190be91ee8", E.CommunityCenter.new())
	processor.register_effect("941f9d4ce0aff2ae62b21503b7615e1b", E.HandTrimmer.new())
