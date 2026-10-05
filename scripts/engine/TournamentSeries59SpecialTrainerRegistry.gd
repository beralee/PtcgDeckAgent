extends RefCounted

const Effects = preload("res://scripts/effects/TournamentSeries59SpecialTrainerEffects.gd")


static func register_fixed(processor: EffectProcessor) -> void:
	processor.register_effect("4d05011aee8f573fbd15fc0cad79bd9f", Effects.GiovanniCharisma.new())
	processor.register_effect("c4ee8747f7ad45f9a828384fb1637fd9", Effects.OgreMask.new())
	processor.register_effect("3f56cb20813b60d36e976cdb5bbe3333", Effects.Drayton.new())
	processor.register_effect("43b20ef70cd362c3a52aa6820cb69829", Effects.TMBlindside.new())
	processor.register_effect("09e67f9448cf4a062206fc6266c94b5f", Effects.VengefulPunch.new())
	processor.register_effect("b2ed6eb5dd7e6221d6673540adb331ab", Effects.DeductionKit.new())
	processor.register_effect("9633328b8477513ca950a1a266c83502", Effects.Miriam.new())
	processor.register_effect("8eb02a558725c4ccde3574f0f9451007", Effects.Rika.new())
