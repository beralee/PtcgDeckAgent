extends RefCounted

const E = preload("res://scripts/effects/ThirtiethCelebrationEffects.gd")
const Existing = preload("res://scripts/effects/CSV10C101To200Effects.gd")


static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	match card.effect_id:
		"0718f0d8e41f74fee27dd895fab2a9bf": # 096 Igglybuff
			processor.replace_attack_effects(card.effect_id, [E.AttackThirtyHPCircle.new()])
		"cb21f414f39c7d17fc3f47144ed2c342": # 097 Lugia
			processor.replace_attack_effects(card.effect_id, [E.AttackDiscardEnergyRequirements.new("RWL", 0)])
		"1aacf3bfb76bd000769bddef339474fe": # 099 Hisuian Zoroark
			processor.replace_attack_effects(card.effect_id, [E.AttackGrudgeVortex.new()])
		"4482a5c8b104aa74ad1a4f488e5bdb17": # 100 Maushold
			processor.replace_attack_effects(card.effect_id, [E.AttackGnawTogether.new(processor.coin_flipper)])
		"ae8b67067d78d9ed2768fcb38a2f18d4": # 092 Meowth
			processor.replace_attack_effects(card.effect_id, [AttackDrawCards.new(1, 0)])
		"06a0c72fadedf66b5169678d05d53132": # 093 Ditto
			processor.replace_attack_effects(card.effect_id, [E.AttackPrankTransform.new(processor.coin_flipper)])
		"010b6a244ea472834e1384bc4efb7634": # 094 Eevee
			processor.replace_attack_effects(card.effect_id, [E.AttackBuryItem.new()])
		"c580b384fb944d40c09ebdcda9c6d94f": # 095 Snorlax
			processor.register_effect(card.effect_id, E.AbilitySoundSleep.new())
			processor.replace_attack_effects(card.effect_id, [AttackApplySelfStatus.new("asleep", 0)])
		"a4dd7f1126ac49fc7ec08efe43097cf8": # 086 Zamazenta
			processor.replace_attack_effects(card.effect_id, [E.AttackKnockOff.new(), AttackReduceDamageNextTurn.new(50, 1)])
		"fecc124734bc8d0b3d50e6915d4958ee": # 087 Gholdengo
			processor.replace_attack_effects(card.effect_id, [E.AttackFestivity.new(), E.AttackTripleSmash.new(processor.coin_flipper)])
		"8b1f439835db2ae1688662a68d3ac62c": # 088 Salamence ex
			processor.replace_attack_effects(card.effect_id, [E.AttackRoaringCall.new(), AttackMillSelfDeck.new(2, 1)])
		"f9ce260f2d33fd863626d289736c0cc6": # 089 Jangmo-o
			processor.replace_attack_effects(card.effect_id, [E.AttackScreech.new()])
		"b64c857949b418dc7c83e2d803fa5f60": # 081 Jirachi ex
			var swift := AttackIgnoreWeaknessResistanceAndEffects.new(1)
			swift.bind_default_attack_index(1)
			processor.replace_attack_effects(card.effect_id, [E.AttackWishComeTrue.new(), swift])
		"3ab33883e0c28b50994d0369caf2a261": # 082 Dialga
			processor.replace_attack_effects(card.effect_id, [E.AttackReverseClock.new()])
		"e94c582847c08c302ce02aa2f4e3ed55": # 083 Ferrothorn
			processor.replace_attack_effects(card.effect_id, [E.AttackExplosiveNeedles.new(), EffectSelfDamage.new(130, 1)])
		"caeed4efe12242b3c0177cf125d42f12": # 084 Solgaleo
			processor.register_effect(card.effect_id, E.AbilitySunrise.new())
			processor.replace_attack_effects(card.effect_id, [AttackDiscardAllAttachedEnergyFromSelf.new(0)])
		"0b1754ca815d6f06b3ae1dcf7565fc73": # 085 Zacian
			processor.replace_attack_effects(card.effect_id, [E.AttackToolBonus.new(), AttackSelfLockNextTurn.new(1)])
		"3aa3c4269d9f1a5cd5dcbb52a16a9c1d": # 076 Gengar ex
			processor.register_effect(card.effect_id, E.AbilityDeathSentence.new(processor.coin_flipper))
			processor.replace_attack_effects(card.effect_id, [AttackChooseOpponentPokemonDamageCounters.new(13, 0)])
		"3860e7c78ea98edb870cdd58b5001170": # 077 Umbreon
			processor.replace_attack_effects(card.effect_id, [E.AttackDamageKORevenge.new()])
		"3dd4bd773322d8d5040badce1f880c61": # 078 Scraggy
			processor.replace_attack_effects(card.effect_id, [E.AttackOpponentShuffleDrawFour.new()])
		"d39da7a78d3666d00e84860f5d122649": # 079 Yveltal
			processor.register_effect(card.effect_id, E.AbilityLifeConstraint.new())
		"2b9a93502964323c8ee21715e1b9d1ff": # 080 Galarian Meowth
			processor.replace_attack_effects(card.effect_id, [AttackDrawCards.new(1, 0), E.AttackHandSizeDamage.new()])
		"e9c95aca720c468d19bc2c9b4f0e90a8": # 071 Lycanroc
			processor.replace_attack_effects(card.effect_id, [E.AttackCounterDamage.new()])
		"7deaab75aeac8b6a9f1a4c6182ee0485": # 072 Koraidon
			processor.replace_attack_effects(card.effect_id, [E.AttackDiscardEnergyRequirements.new("FF", 1)])
		"adc2b7eef45640632f3c67ec02aed83b": # 073 Nidoran F
			processor.replace_attack_effects(card.effect_id, [CSV9CEffects.AttackReduceDefenderOutgoingDamage.new(30, 0)])
		"2212a16966600c8c707bcfbfcce7cd1a": # 074 Nidorina
			processor.register_effect(card.effect_id, E.AbilityShareHappiness.new())
		"a4813d15f7f218c519135b8fa6e6b34d": # 075 Alolan Meowth
			processor.replace_attack_effects(card.effect_id, [AttackDrawCards.new(1, 0)])
		"c8015fd4179304101ddb870edfffc872": # 066 Lunala
			processor.replace_attack_effects(card.effect_id, [CSV9CEffects.AttackDiscardPileEnergyBonus.new(20, 0)])
		"9b7a3e1691f97e2d30d8437093c3500c": # 067 Gimmighoul
			processor.replace_attack_effects(card.effect_id, [E.AttackCoinSearch.new(processor.coin_flipper)])
		"262402030e46715de21eb138e520134f": # 068 Groudon
			processor.replace_attack_effects(card.effect_id, [E.AttackOwnBenchWave.new()])
		"00265a9c83b1196e14f44c7e6ce90bac": # 069 Lucario
			processor.replace_attack_effects(card.effect_id, [E.AttackBenchTarget.new(60, 0)])
		"5e8f8e53cc52507e705900387a3be87a": # 070 Seismitoad
			processor.replace_attack_effects(card.effect_id, [E.AttackVibrationPunch.new()])
		"b813a0097cf2b40184888c03f51832fd": # 061 Drifloon
			processor.replace_attack_effects(card.effect_id, [E.AttackDrifloonReturn.new()])
		"035ac595564a924d0d2563f374e4adb9": # 062 Chandelure
			processor.replace_attack_effects(card.effect_id, [EffectApplyStatus.new("burned", false, 0), EffectApplyStatus.new("confused", false, 0)])
		"7b1750e79eb2adf1fc8cc4ba79e713a3": # 063 Xerneas
			processor.replace_attack_effects(card.effect_id, [AttackSearchDeckToHand.new(2, "Stadium", 0)])
		"9163fc34feb6948638166d7d08e215a1": # 065 Cosmoem
			processor.replace_attack_effects(card.effect_id, [AttackReduceDamageNextTurn.new(60, 0)])
		"91e47d789c8f695b74e59253913e15d2": # 056 Mew
			processor.replace_attack_effects(card.effect_id, [E.AttackPsychic.new()])
		"dd6e658057478ff1eb223c71000b08a2": # 057/135 Mew ex, API printing (legacy photo identity remains supported)
			processor.register_effect(card.effect_id, AbilityOwnBenchAttacks.new(processor))
			var teleport := AttackSwitchSelfToBench.new()
			teleport.bind_default_attack_index(0)
			processor.replace_attack_effects(card.effect_id, [teleport])
		"4e8f2003856715ec3ae5e5b65ebe2e75": # 058 Espeon
			processor.replace_attack_effects(card.effect_id, [E.AttackMiracleBeam.new()])
		"c1adb66087005031a31ed27fb30dcd96": # 059 Sylveon ex
			processor.replace_attack_effects(card.effect_id, [E.AttackColorfulHarmony.new()])
		"20f3bd0141978828bc0e191ce5090b98": # 060 Unown
			processor.replace_attack_effects(card.effect_id, [AttackExtraPrize.new(1, 0)])
		"2210e38ce299e07646e3a1a67fc1b258": # 051 Toxtricity
			processor.register_attack_effect(card.effect_id, AttackSelfAllAttacksLockNextTurn.new(1))
		"508470eb99327c31713a9a0543dbb5bc": # 052 Morpeko
			processor.register_attack_effect(card.effect_id, E.AttackPickSnack.new())
		"ab01ac05b94cfa923001e55a1dfde220": # 053 Miraidon
			processor.replace_attack_effects(card.effect_id, [E.AttackDiscardEnergyRequirements.new("LL", 1)])
		"41d19b25408b67ee69dd56dc60f094f8": # 054 Mewtwo
			processor.register_attack_effect(card.effect_id, AttackAttachBasicEnergyFromDiscard.new("", 2, "own_any", 0))
			processor.register_attack_effect(card.effect_id, AttackDiscardAttachedEnergyFromSelf.new(1, 1))
		"11641ee70b056fe9c3ef8d2e04ef6dd7": # 055 Mewtwo ex
			processor.register_attack_effect(card.effect_id, E.AttackPhotonBullet.new())
			processor.register_attack_effect(card.effect_id, AttackSelfAllAttacksLockNextTurn.new(1))
		"df07c7c9e66ddd482c9f94cd9015ba3c": # 046 Pikachu
			processor.register_attack_effect(card.effect_id, AttackSelfDamageCounterBonus.new(10, 0))
		"2418309668a6102d250f4bdb4fd89742": # 047 Pikachu ex
			var parade := AttackCallForFamily.new(60)
			parade.bind_default_attack_index(0)
			processor.register_attack_effect(card.effect_id, parade)
			processor.register_attack_effect(card.effect_id, AttackDiscardAllAttachedEnergyFromSelf.new(1))
		"a15ad334101499f5283f47631736ee1c": # 048 Pikachu ex
			processor.register_attack_effect(card.effect_id, CSV9CEffects.AttackHandBasicEnergyAttach.new(0))
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(30, 1))
		"23a00b18e1944b72ea1e1598affc5fe4": # 049 Zapdos
			processor.register_effect(card.effect_id, E.AbilityLegendaryBirdAttachment.new("L", [PackedStringArray(["火焰鸟", "Moltres"]), PackedStringArray(["急冻鸟", "Articuno"])]))
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(60, 0))
		"67895895dd26e7d68e8854f48ff88e37": # 050 Zekrom
			processor.register_attack_effect(card.effect_id, E.AttackAttachedTypeBonus.new("R", 80, 1))
		"eca0671907dac835ac5b50bb62c630c3": # 041 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackPlayRough.new(processor.coin_flipper))
		"2abf73288ff5b3acd4652dcf84641f96": # 042 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackCollectBasicEnergy.new())
		"53f077cda92c302a72e7f6ab5e57798b": # 043 Pikachu
			processor.register_attack_effect(card.effect_id, AttackBonusIfDefenderMechanic.new(80, "ex", 0))
		"ae37c5bd0e12492200c33c025fd686cb": # 045 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackThunderCrash.new())
		"7753f583491e6aae491e9774e2a778de": # 036 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackChargeDash.new(processor.coin_flipper))
		"707f8f3d4ef85eb5f679761bd0f89fa9": # 037 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackTropicalMood.new())
		"215450d0afa5da811b5be9f24b779ad7": # 038 Pikachu
			processor.register_attack_effect(card.effect_id, AttackCoinFlipPreventDamageAndEffectsNextTurn.new(processor.coin_flipper, 0))
		"86c2e2cd7c5443dd1ad6e3a0b7bcf6cc": # 039 Pikachu
			processor.register_attack_effect(card.effect_id, AttackDrawCards.new(1, 0))
		"b53b2abedf7bf024e0b886b1e64c7e8e": # 040 Pikachu
			processor.register_attack_effect(card.effect_id, AttackClearOwnStatus.new(0))
		"8466088fd32e6b7496ce3462a6e65aff": # 031 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackSearchEnergy.new())
		"ed842de73ebe6fb24ce3236e371fa49d": # 032 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackAnyTargetFixed.new(20))
		"6299b6e51aaec31bb5b709b318f9c956": # 033 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackIronTail.new(processor.coin_flipper))
		"602b93b1b8f83af2c2ed08ed93715884": # 034 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackRewriteVolt.new())
		"5caef03379545b126b26ba32fa3900d8": # 026 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackMandatorySelfSwitch.new())
		"6198144fca9bc57c5ffa06bcac4c1933": # 027 Pikachu
			processor.register_effect(card.effect_id, AbilityBenchImmune.new())
		"b16f2a48835dd0ee4f9b7a5718feb46f": # 028 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackPikachuChain.new())
		"e744c180a78847f1fb4c25eadc3c08dd": # 030 Pikachu
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(10, 0))
		"728e4471a1c8d8d5ce730a31051f31a3": # 021 Pikachu
			processor.register_attack_effect(card.effect_id, CSV9CSimpleHealSelfAfterAttack.new(30, 0))
		"cf9419068cb1df6aec5ad050d16039fb": # 022 Pikachu
			processor.register_effect(card.effect_id, E.AbilityLonelyGaze.new())
		"87dc2fa8cddd65cd238e462f2238e000": # 023 Pikachu
			processor.register_attack_effect(card.effect_id, AttackSearchDeckToHand.new(1, "Pokemon", 0))
		"2b88722cf752d07c0234a9dd2da0ca39": # 016 Wishiwashi
			processor.register_effect(card.effect_id, E.AbilitySchoolingRetaliation.new())
			processor.register_attack_effect(card.effect_id, AttackCoinFlipOrFail.new(30, "no_damage", processor.coin_flipper))
		"b67eb0b4a33026c81e8347de890f489f": # 017 Pikachu
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("paralyzed", true, 0))
		"0cce96ae9a96da81a435b8bc6b616d40": # 018 Pikachu
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(30, 0))
		"b4cd2c7e5bd5040d5b3809105f8411be": # 019 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackBenchTarget.new(20, 0))
		"c24ad9eb6576efbeed0ac25016a926d7": # 020 Pikachu
			processor.register_attack_effect(card.effect_id, E.AttackPeek.new(0))
		"fcdfdf2c053d45b97f98ac821dbdf7a8": # 011 Lapras
			processor.register_attack_effect(card.effect_id, AttackSearchDeckToHand.new(1, "Supporter", 0))
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("paralyzed", true, 1))
		"831872607eca83307cb94cfa8afc7730": # 012 Articuno
			processor.register_effect(card.effect_id, E.AbilityLegendaryBirdAttachment.new("W", [PackedStringArray(["火焰鸟", "Moltres"]), PackedStringArray(["闪电鸟", "Zapdos"])]))
			processor.register_attack_effect(card.effect_id, E.AttackHail.new())
		"35da9bccad39223d970a5dcaade97abf": # 013 Kyogre
			processor.register_attack_effect(card.effect_id, E.AttackWaterEnergyBonus.new())
		"1bb5d4a79e97af758bb961e3501b26a7": # 014 Palkia
			processor.register_attack_effect(card.effect_id, E.AttackWormhole.new())
		"de1d3ab0a4a8f5e15498e7a5413c039c": # 015 Greninja ex
			processor.register_attack_effect(card.effect_id, E.AttackStealthSlash.new())
		"efa2faba61d1b2cd26c7371fe79c23b0": # 006 Moltres
			processor.register_effect(card.effect_id, E.AbilityLegendaryBirdAttachment.new("R", [PackedStringArray(["急冻鸟", "Articuno"]), PackedStringArray(["闪电鸟", "Zapdos"])]))
			processor.replace_attack_effects(card.effect_id, [E.AttackDiscardEnergyRequirements.new("CC", 0)])
		"040aed788238e1f99d1278fa1ea1a7e7": # 007 Ho-Oh
			processor.register_attack_effect(card.effect_id, E.AttackSacredBreath.new())
		"eca20db642e6e7ab1af841dc90d9b347": # 008 Reshiram
			processor.register_attack_effect(card.effect_id, E.AttackAttachedTypeBonus.new("L", 80, 1))
		"4c6d5da418dfa92f148946c38e0227c6": # 009 Fuecoco ex
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("burned", false, 0))
			processor.register_attack_effect(card.effect_id, E.AttackOwnTakenPrizeMultiplier.new())
		"2240b955de9bb9bf1339f846e023f1e7": # 010 Slowpoke
			processor.register_attack_effect(card.effect_id, AttackCoinFlipPreventDamageAndEffectsNextTurn.new(processor.coin_flipper, 0))
		"d1f3b4174792a4a51d66a96108302713": # 001 Exeggcute
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("asleep", false, 0))
		"c77d3be6b3f3347323cd1b3df86dde1d": # 002 Alolan Exeggutor
			processor.register_effect(card.effect_id, E.AbilityGrassEnergyHP.new())
			processor.register_attack_effect(card.effect_id, CSV9CSimpleHealSelfAfterAttack.new(50, 0))
		"e47c3acd5fdeb66f6535ab4daca5ab28": # 003 Volbeat
			processor.register_attack_effect(card.effect_id, Existing.AttackChooseOpponentBenchAsActive.new(0))
		"392dd3f185cc878a05428f48fa76c736": # 004 Illumise
			processor.register_effect(card.effect_id, E.AbilityExcellentPheromone.new())
		"48e8990e5652874688fcd2ce0b8cf9e4": # 005 Vivillon
			processor.register_effect(card.effect_id, E.AbilityGuidingDance.new(processor.coin_flipper))
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("poisoned", false, 0))
