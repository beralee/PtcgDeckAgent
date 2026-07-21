class_name CSV10C101To200Registry
extends RefCounted

const E = preload("res://scripts/effects/CSV10C101To200Effects.gd")
const CSV9C = preload("res://scripts/effects/CSV9CEffects.gd")


static func register_fixed(processor: EffectProcessor) -> void:
	processor.register_effect("a5dc954d89a78f95da6d24298c927da1", E.EffectHealSelectedPokemonDiscardEnergy.new(60)) # CSV10C_189 Potion
	processor.register_effect("e3908e818bdcdbc87e67222ef9239fb3", EffectNsPPUp.new()) # CSV10C_190 N's PP Up
	processor.register_effect("8399ac187218ab69e12cc78b09b5cc90", E.EffectReturnDiscardCardsToDeck.new("basic_energy", 5)) # CSV10C_191 Energy Recycler
	processor.register_effect("3ca2a0a5dba175e675a7c3affce3eec2", E.EffectReturnDiscardCardsToDeck.new("pokemon", 5)) # CSV10C_192 Sacred Ash
	processor.register_effect("6c48ceec110a6f65a07e0547b059e7aa", E.EffectExchangeAllPrizes.new()) # CSV10C_193 Exchange Ticket
	processor.register_effect("bff815683aaa1957457e11941267549c", E.EffectHealActiveNamedTeam.new(30, 100, PackedStringArray(["派帕的", "Arven's "]))) # CSV10C_194 Arven's Sandwich
	processor.register_effect("517d6bf6e21dbaf53ab99bbb392f2460", E.EffectSearchBasicNamedPokemonToBench.new(PackedStringArray(["赫普的", "Hop's "]), 2)) # CSV10C_195 Hop's Bag
	processor.register_effect("9707225aba6fd9a9e58e59c939051e70", E.EffectHiddenPrizeHandSwap.new()) # CSV10C_196 Team Rocket's Orbeetle
	processor.register_effect("867c87a80d5c22096ab56e692bf2324d", E.EffectCoinSearchNamedPokemonByStage.new(PackedStringArray(["火箭队的", "Team Rocket's "]), processor.coin_flipper)) # CSV10C_197 Team Rocket's Great Ball
	processor.register_effect("b5c3b1d60d20441ae0a636b09549cd22", E.EffectCoinDamageCountersOpponentOrSelf.new(2, processor.coin_flipper)) # CSV10C_198 Team Rocket's Scare Bomb
	processor.register_effect("8eddb3dcb79eb6e9017d8ae85708eef2", E.EffectSearchNamedSupporter.new(PackedStringArray(["火箭队", "Team Rocket"]))) # CSV10C_199 Team Rocket's Receiver
	processor.register_effect("a13a8391817936aaa9c79cd3cfe5483f", E.EffectNamedTeamHPModifier.new(70, PackedStringArray(["竹兰的", "Cynthia's "]))) # CSV10C_200 Cynthia's Power Weight


static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	if processor == null or card == null:
		return
	match card.effect_id:
		"9850efd2238a2b27da02faa85e772a71": # CSV10C_101 Ethan's Sudowoodo
			processor.register_attack_effect(card.effect_id, AttackDefenderRetreatLockNextTurn.new(0))
			processor.register_attack_effect(card.effect_id, E.AttackCoinFlipCopyOpponentAttack.new(processor, 1, processor.coin_flipper))
		"e81894ba20ba5db44d8a4133f78564c2": # CSV10C_104 Mamoswine ex
			processor.register_effect(card.effect_id, AbilitySearchDeckCardType.new(1, "Pokemon"))
			processor.register_attack_effect(card.effect_id, E.AttackOwnBenchStageCountDamage.new("Stage 2", 40, 0))
		"b079e5d2d7eb44d40d83b65a1993a7c5": # CSV10C_105 Larvitar
			processor.register_attack_effect(card.effect_id, AttackCoinFlipDiscardOpponentActiveEnergy.new(0, processor.coin_flipper))
		"39866ee7ab0952e17e4ab945543644e1": # CSV10C_106 Pupitar
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(20, 0))
		"cf234d660ec8aa5fa2b8788ce645e288": # CSV10C_107 Team Rocket's Larvitar
			processor.register_attack_effect(card.effect_id, AttackMillOpponentDeck.new(1, 0))
		"de9d694af9e030045ae32cd2dd0d2a9d": # CSV10C_108 Team Rocket's Pupitar
			processor.register_attack_effect(card.effect_id, CSV9C.AttackEvolveFromDeck.new(0))
		"dad264893399fad513042008e679aa5a": # CSV10C_109 Team Rocket's Tyranitar
			processor.register_effect(card.effect_id, E.AbilityActiveOpponentBasicPokemonCheckDamage.new(2))
			processor.register_attack_effect(card.effect_id, E.AttackDiscardOpponentActiveEnergy.new(0))
		"a368ab722e082899d1e3c82c61e7efcf": # CSV10C_110 Regirock ex
			var regi_charge := AttackAttachBasicEnergyFromDiscard.new("F", 2, "self", 0)
			processor.register_attack_effect(card.effect_id, regi_charge)
			processor.register_attack_effect(card.effect_id, E.AttackBonusIfDefenderStage.new("Stage 2", 140, 1))
		"1bbd1874c0cc4c60d3f1128e8583d583": # CSV10C_111 Cynthia's Gible
			processor.register_attack_effect(card.effect_id, E.AttackIgnoreResistance.new(0))
		"23e6f24fc40bdb19384bc3c7822beea1": # CSV10C_112 Cynthia's Gabite
			processor.register_effect(card.effect_id, E.AbilitySearchNamedPokemon.new(PackedStringArray(["竹兰的", "Cynthia's "]), 1))
		"b494c15a64405edbc24ed017733ad8a5": # CSV10C_113 Cynthia's Garchomp ex
			processor.register_attack_effect(card.effect_id, AttackDrawToHandSize.new(6, 0))
			processor.register_attack_effect(card.effect_id, AttackDiscardAllAttachedEnergyFromSelf.new(1))
		"12bb9f931bf0c4b4dbca4eb2e72c67b8": # CSV10C_114 Rockruff
			processor.register_attack_effect(card.effect_id, E.AttackLookTopOptionalDiscard.new(0))
		"52d6e7a0eb426bce6daf869431f4e4ad": # CSV10C_115 Lycanroc
			processor.register_effect(card.effect_id, E.AbilityEvolveAttachNamedEnergyFromDiscard.new(PackedStringArray(["尖钉能量", "Spiky Energy"]), 2))
			processor.register_attack_effect(card.effect_id, E.AttackDefenderDamageCounterMultiplierBonus.new(40, 0))
		"af4394988573b624bae734bf81eeb073": # CSV10C_116 Hop's Silicobra
			var stadium_search := AttackSearchDeckToHand.new(1, "Stadium")
			stadium_search.attack_index_to_match = 0
			processor.register_attack_effect(card.effect_id, stadium_search)
		"abc6975b8fa8c658db65abc9faa2e164": # CSV10C_117 Hop's Sandaconda
			processor.register_attack_effect(card.effect_id, AttackDefenderRetreatLockNextTurn.new(0))
			processor.register_attack_effect(card.effect_id, E.AttackDamageOwnBenchAll.new(20, 1))
		"bd88f54af10747edd293731c2a175187": # CSV10C_118 Arven's Toedscool
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(10, 0))
		"bb238b4e456286a7c12b1c52dca11b95": # CSV10C_119 Arven's Toedscruel
			processor.register_attack_effect(card.effect_id, E.AttackChooseOpponentBenchAsActive.new(0))
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(30, 1))
		"84c51481512329e1f964df78727f4770": # CSV10C_120 Team Rocket's Ekans
			var paralyze := AttackCoinFlipApplyStatus.new("paralyzed", processor.coin_flipper)
			paralyze.bind_default_attack_index(0)
			processor.register_attack_effect(card.effect_id, paralyze)
		"9e832b50de492aef54f2a9d3c4e588f0": # CSV10C_121 Team Rocket's Arbok
			processor.register_effect(card.effect_id, E.AbilityActiveBlocksOpponentAbilityPokemonExceptNamed.new(PackedStringArray(["火箭队的", "Team Rocket's "])))
			processor.register_attack_effect(card.effect_id, E.AttackDamageAllOpponentPokemon.new(30, 0))
		"08c6e88a72b93aee828002c14a636d18": # CSV10C_122 Team Rocket's Nidoran
			processor.register_attack_effect(card.effect_id, AttackCoinFlipOrFail.new(30, "no_damage", processor.coin_flipper))
		"9000626963c7391cedd939f1be76757c": # CSV10C_123 Team Rocket's Nidorina
			processor.register_attack_effect(card.effect_id, E.AttackEvolveOwnPokemonFromDeck.new(2, "D", 0))
		"8c200bf19f07f9de65672801e59e8166": # CSV10C_124 Team Rocket's Nidoqueen
			processor.register_attack_effect(card.effect_id, E.AttackBonusIfOwnBenchNameContains.new(PackedStringArray(["尼多王", "Nidoking"]), 120, 0))
		"aeb8b9043b6fbea8e4fdc506661c75aa": # CSV10C_126 Team Rocket's Nidorino
			processor.register_attack_effect(card.effect_id, AttackBonusIfDefenderDamaged.new(60, 1))
		"54a2289d69bc02af78261838357cbb6e": # CSV10C_127 Team Rocket's Nidoking ex
			processor.register_attack_effect(card.effect_id, E.AttackApplySeverePoison.new(80, 0))
		"1a347bef4d52c03ce432583c26c6f554": # CSV10C_128 Team Rocket's Zubat
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("poisoned", false, 0))
		"1a3488e81af859182b43c818b5ccc5a6": # CSV10C_129 Team Rocket's Golbat
			processor.register_effect(card.effect_id, E.AbilityEvolvePlaceDamageCounters.new(1, 2))
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("confused", false, 0))
		"c4cf39844b70f177c0f202f57e1f0841": # CSV10C_130 Team Rocket's Crobat ex
			processor.register_effect(card.effect_id, E.AbilityEvolvePlaceDamageCounters.new(2, 2))
			processor.register_attack_effect(card.effect_id, E.AttackOptionalReturnPokemonStackToHand.new(0))
		"1962fef82166907f7b80aa1fd038aeb3": # CSV10C_131 Team Rocket's Grimer
			processor.register_attack_effect(card.effect_id, E.AttackDelayedDiscardEndOpponentTurn.new(0))
		"aa86b36c41444cac942922eb06dadca6": # CSV10C_132 Team Rocket's Muk
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("confused", false, 0))
			processor.register_attack_effect(card.effect_id, AttackDefenderRetreatLockNextTurn.new(0))
			processor.register_attack_effect(card.effect_id, E.AttackSpecialConditionCountDamage.new(100, 100, 1))
		"0c65d1d9705ccf735d3780b072e3924d": # CSV10C_133 Team Rocket's Koffing
			processor.register_effect(card.effect_id, E.AbilityActiveDamagedSearchNamedPokemonToBench.new(PackedStringArray(["瓦斯弹", "Koffing"]), 2))
		"890fa0b0b7e2ed3fb41dd9b8e4eb2a51": # CSV10C_134 Team Rocket's Weezing
			processor.register_attack_effect(card.effect_id, E.AttackBothFieldsNameCountDamage.new(PackedStringArray(["瓦斯弹", "双弹瓦斯", "Koffing", "Weezing"]), 40, 40, 0))
		"8ef7f03a3fb643c476b844417ba8f30a": # CSV10C_135 Team Rocket's Murkrow
			var supporter_search := AttackSearchDeckToHand.new(1, "Supporter")
			supporter_search.attack_index_to_match = 0
			processor.register_attack_effect(card.effect_id, supporter_search)
			var chosen_lock := AttackChosenDefenderAttackLockNextTurn.new()
			chosen_lock.attack_index_to_match = 1
			processor.register_attack_effect(card.effect_id, chosen_lock)
		"229553991d51f4a78665aad3ba87c08e": # CSV10C_136 Team Rocket's Sneasel
			processor.register_attack_effect(card.effect_id, E.AttackDamagedBenchCounterMultiplier.new(20, 1))
		"379d058282df2408f8849dcb9167c980": # CSV10C_137 Tyranitar
			processor.register_effect(card.effect_id, E.AbilityActiveBlocksOpponentCardType.new("Item"))
			processor.register_attack_effect(card.effect_id, AttackMillOpponentDeck.new(2, 0))
		"3c4ab79ab7320fa3a57639e232f507e9": # CSV10C_138 Cynthia's Spiritomb
			processor.register_attack_effect(card.effect_id, E.AttackOwnBenchNamedDamageCounterScale.new(PackedStringArray(["竹兰的", "Cynthia's "]), 10, 10, 0))
			processor.register_attack_effect(card.effect_id, AttackIgnoreWeakness.new(0))
		"d62a976a196af2f33b094d58c08d128d": # CSV10C_139 N's Purrloin
			processor.register_attack_effect(card.effect_id, E.AttackRevealOpponentHandCardToBottom.new(0))
		"5ea0f3f71ae8603163b4fa339fc49a43": # CSV10C_140 Marnie's Purrloin
			processor.register_attack_effect(card.effect_id, AttackBonusIfDefenderMechanic.new(40, "ex", 0))
		"5d0fee78450f0859b8045b35b16d16c8": # CSV10C_141 Marnie's Liepard
			processor.register_attack_effect(card.effect_id, AttackBonusIfDefenderMechanic.new(70, "ex", 0))
		"36386b20071019c802d59b64efd8b684": # CSV10C_142 Marnie's Scraggy
			processor.register_attack_effect(card.effect_id, E.AttackDiscardOpponentActiveEnergy.new(0))
		"8984ccb7b301d7269b82e545d8effa34": # CSV10C_143 Marnie's Scrafty
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(30, 1))
		"a1742becbf9fdc6a66ddfb1b306c4bc0": # CSV10C_145 N's Zoroark ex
			processor.register_effect(card.effect_id, AbilityDiscardDrawAny.new(2))
			processor.register_attack_effect(card.effect_id, AttackCopyOwnBenchNamedPokemonAttack.new(
				processor,
				"N's ",
				PackedStringArray(["Night Joker", "暗夜王牌"])
			))
		"cd9d3ec383aa409ff7930840c21d43b0": # CSV10C_146 Marnie's Impidimp
			processor.register_attack_effect(card.effect_id, AttackDrawCards.new(1, 0))
		"863479acd128e1e5e2643a3a1e77ce26": # CSV10C_148 Marnie's Grimmsnarl ex
			processor.register_effect(card.effect_id, AbilityMarniesGrimmsnarlPunkUp.new())
			processor.register_attack_effect(card.effect_id, AttackSelectOpponentBenchDamage.new(30, 1, 0))
		"046bba89abfe0be6ef012e1c64c6eb36": # CSV10C_149 Marnie's Morpeko
			processor.register_attack_effect(card.effect_id, AttackEnergyCountDamage.new("D", 40, false, 0))
		"5d6fdb8a31831315e14728bf8d8fe534": # CSV10C_151 Arven's Mabosstiff ex
			processor.register_attack_effect(card.effect_id, E.AttackBonusIfSelfUndamaged.new(120, 0))
			processor.register_attack_effect(card.effect_id, AttackSelfLockNextTurn.new(1))
		"7be05f290250debafdfc03b854543c12": # CSV10C_152 Steven's Skarmory
			processor.register_attack_effect(card.effect_id, E.AttackDamageTwoOpponentPokemon.new(50, 2, 1))
		"b583dc8cbe7ef6da1f4f5c3ca5a228c6": # CSV10C_154 Steven's Metang
			processor.register_attack_effect(card.effect_id, AttackSelfAllAttacksLockNextTurn.new(0))
		"68e01e0f386e67ffd8bd2ad3a721507c": # CSV10C_155 Steven's Metagross ex
			processor.register_effect(card.effect_id, E.AbilitySearchPsychicMetalEnergyAssign.new())
		"237025b75c5d507d816bbcdf0e7ea95b": # CSV10C_156 N's Klink
			processor.register_attack_effect(card.effect_id, AttackFixedCoinFlipDamage.new(2, 10, 10, 0, processor.coin_flipper))
		"7e21f2f4a1130c63d6e64f016ebc8804": # CSV10C_157 N's Klang
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("confused", false, 0))
		"5d3ad89b9136693fc6dd3e91cde6849c": # CSV10C_158 N's Klinklang
			processor.register_attack_effect(card.effect_id, AttackFixedCoinFlipDamage.new(3, 120, 120, 1, processor.coin_flipper))
		"b546d9d9e11f6329bc743986c3b578c2": # CSV10C_159 Magearna
			processor.register_effect(card.effect_id, E.AbilityActiveHealHandEnergyAttachmentTarget.new(90))
			processor.register_attack_effect(card.effect_id, AttackDrawCards.new(2, 0))
		"a81e10b6d9d5244d4486f63d8fc779c6": # CSV10C_160 Hop's Corviknight
			processor.register_attack_effect(card.effect_id, AttackTargetOpponentBenchDamage.new(50, 0))
			processor.register_attack_effect(card.effect_id, AttackReduceDamageNextTurn.new(60, 1))
		"832e8b704b5457781ee7c52adc1a0571": # CSV10C_161 Hop's Zacian ex
			processor.register_attack_effect(card.effect_id, AttackTargetOpponentBenchDamage.new(30, 0))
			processor.register_attack_effect(card.effect_id, AttackSelfLockNextTurn.new(1))
		"494f56182b19e1fbd9b77d79db6ab08a": # CSV10C_163 Bagon
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(10, 1))
		"a00721dec62ea70957614dbaa43a3e1c": # CSV10C_164 Shelgon
			processor.register_attack_effect(card.effect_id, AttackReduceDamageNextTurn.new(30, 0))
		"f0c413ebe4cec489e68fdf6afb19f3a2": # CSV10C_165 Salamence ex
			var all_bench_damage := EffectBenchDamage.new(50, true, "opponent")
			all_bench_damage.bind_default_attack_index(0)
			processor.register_attack_effect(card.effect_id, all_bench_damage)
			processor.register_attack_effect(card.effect_id, E.AttackDiscardSelectedSelfEnergy.new(2, 1))
		"a5c060009e97c6343b07b9d3f9d42e48": # CSV10C_167 Team Rocket's Rattata
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("poisoned", false, 0))
		"1094d9ed366ef996bb18448b465cf8ca": # CSV10C_168 Team Rocket's Raticate
			processor.register_attack_effect(card.effect_id, E.AttackRecoilIfAllCoinFlipsTails.new(2, 90, 0, processor.coin_flipper))
		"ce73887b24bb5292b4f72887d2687c93": # CSV10C_169 Team Rocket's Meowth
			var hidden_hand_shuffle := AttackMoveOpponentHandCardToDeck.new()
			hidden_hand_shuffle.attack_index_to_match = 0
			processor.register_attack_effect(card.effect_id, hidden_hand_shuffle)
			processor.register_attack_effect(card.effect_id, AttackFixedCoinFlipDamage.new(3, 20, 20, 1, processor.coin_flipper))
		"d7c0c50d9f82eb297d7b6b26850a91a3": # CSV10C_170 Team Rocket's Persian ex
			processor.register_attack_effect(card.effect_id, E.AttackCopyOpponentTopDeckPokemonAttack.new(processor, 10, 0))
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("confused", false, 1))
		"58c077f6422fa13c3421b2365544b898": # CSV10C_171 Kangaskhan
			processor.register_attack_effect(card.effect_id, AttackFixedCoinFlipDamage.new(2, 90, 90, 1, processor.coin_flipper))
		"95c1b5a4e4c56d33c91448a057edb9a8": # CSV10C_172 Team Rocket's Porygon
			processor.register_attack_effect(card.effect_id, E.AttackBothPlayersDiscardSelectedHandCard.new(0))
		"e1b852f805dfbdcc1f2d5e2787bc3bb4": # CSV10C_173 Team Rocket's Porygon2
			processor.register_attack_effect(card.effect_id, E.AttackRocketSupporterDiscardCountDamage.new(20, 20, 0))
		"e6f6954a902f34ad6277c44dc364c515": # CSV10C_174 Team Rocket's Porygon-Z
			processor.register_effect(card.effect_id, E.AbilityDiscardTwoDrawOne.new())
			processor.register_attack_effect(card.effect_id, E.AttackRocketSupporterDiscardCountDamage.new(20, 20, 0))
		"49c917fdc3770a031e96267e6add09ab": # CSV10C_175 Hop's Snorlax
			processor.register_effect(card.effect_id, E.AbilityNonStackingNamedTeamDamageBoost.new(30, PackedStringArray(["赫普的", "Hop's "])))
			processor.register_attack_effect(card.effect_id, EffectSelfDamage.new(80, 0))
		"80bd5ab62b8c3026d06e79be772eb2fb": # CSV10C_178 Dunsparce
			var switch_self := AttackSwitchSelfToBench.new()
			switch_self.attack_index_to_match = 0
			processor.register_attack_effect(card.effect_id, switch_self)
		"eba0db61ad014da367f3bfd7a8e9ea0b": # CSV10C_180 Noibat
			processor.register_attack_effect(card.effect_id, AttackDrawCards.new(1, 0))
		"c7128bf64fd4476dd387ce3f592e78c2": # CSV10C_181 Noivern
			processor.register_effect(card.effect_id, E.AbilityEqualHandSizeFreeAttack.new(PackedStringArray(["恐慌嗥鸣", "Panic Howl"])))
			processor.register_attack_effect(card.effect_id, EffectApplyStatus.new("confused", false, 0))
		"bd60c6a39ca30046d3e3610e1bbf7595": # CSV10C_182 Arven's Greedent
			processor.register_attack_effect(card.effect_id, E.AttackDiscardDefenderToolBeforeDamage.new(0))
		"a43f9457986f98ac84942ab4b9656eb5": # CSV10C_183 Arven's Greedent
			processor.register_effect(card.effect_id, E.AbilityEvolveRecoverNamedItems.new(PackedStringArray(["派帕的三明治", "Arven's Sandwich", "Arven’s Sandwich"]), 2))
		"197f84bf11c45303a20030cad37be2d0": # CSV10C_184 Hop's Rookidee
			processor.register_attack_effect(card.effect_id, E.AttackReduceDefenderOutgoingDamageNextTurn.new(20, 0))
		"9b26bed081404948d6ba57bf004b1d7e": # CSV10C_187 Hop's Dubwool
			processor.register_effect(card.effect_id, E.AbilityEvolveGustOpponentBench.new())
		"a250d62a3355b00d48f2eaa8be6a5dfb": # CSV10C_188 Hop's Cramorant
			processor.register_attack_effect(card.effect_id, E.AttackCancelUnlessOpponentPrizeCount.new(PackedInt32Array([3, 4]), 0))
