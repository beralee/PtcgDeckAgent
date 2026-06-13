## 效果注册表 - 将所有 effect_id（API 返回的 MD5 哈希）映射到对应的效果类实例
## 并向 EffectProcessor 完成注册。
## 训练家卡/道具/竞技场/特殊能量通过固定 effect_id 注册；
## 宝可梦卡通过特性名/招式名动态匹配注册。
class_name EffectRegistry
extends RefCounted


static var _effect_script_cache: Dictionary = {}
const CSV9CEffects = preload("res://scripts/effects/CSV9CEffects.gd")

const CSV9C_EFFECT_ID_ALIASES = {
	"6b6641a24bd64c822e7ca22834562305": "80861b2bfa9967d1e28a97ee4d1f1316",
	"6c353de6662e532e4c46e3cfae7dfa2f": "3a842d03df3719f7c72c2c0b48d7fd7d",
	"ea16fe3d0ca185db9e37c8e3a2d88efc": "7cffba962d26fc020fa7a823c71157db",
	"408e35f7f658381ad43783473e50049e": "7c7665c11f0e9d13ce39ee63c2f2d85c",
	"30c0f190345a6b72ddf9df7726842de2": "e2114e7b76f6dbbe76ce0aaf2a65bc9c",
	"178c0eaa413487309e4bb17d0a495039": "c155af5a80a873be25372736b49b5829",
	"6c64991ff0cfcc9656603347504deab7": "ae135beb7f4c42139fc38a4f9203db09",
	"990ee62469ff9c158e669543e6d93e00": "975fec278b4ac548e0afd3ed538cb85d",
	"92770a887520f6c4528cf57ae82392b3": "a533d02d029bd799e8c425beecd3ffaa",
	"5185ad3335c161ab7b0714d053721e9d": "4b31ce3c692a0129980d3866878faeb5",
	"57aa4d41e927a2f1cdf846f73509b907": "88b2885578a73494f1eed7c2b53e67c7",
	"398c5e37a64e8f0184c7634bb63a511c": "f518a7e573241c14cc225cc14d6094d3",
	"689549e631f4f93ecf618a215c628bd1": "cd845155473716c29f29efa29da0a869",
	"36d024ba3147200b7a179519b1eb4992": "76ce94424f53e8a93cfb2c2008a84a86",
	"27d1eb5f7abc237f462328c2ff00fdf3": "cfe54f4650db054ec2eec6dfcaaff88a",
	"b081eea7ec634b2aad300056bd7b3fe6": "ccc3bb652f886672fac7b4b0561492d9",
	"59d3af627f14b4a65ab4d589f6cb52db": "79cbb7699c0e663c135524afe4e1cb14",
	"1ff33aa784d1181c5e87ca96bab80ab3": "8c8dbf6bb67e8c8d393f42ed9aead1bf",
	"a8d69abb427e7a074497b66db3f524fb": "74fd967591e71b608b8437f28cdee910",
	"0730af1743d1604c0fdd734359ec239b": "019d762a760de48f1bb05528db2766f3",
	"a92ab1fcfe663d2a56b267a34307fad4": "f8c2715403e3f4ea9783c46be2de832b",
	"61fb0755be18f5fcdc6a30781d5fc05e": "317cdd81106733967d562ad538a7983a",
	"7f156dbd62a95fd428ab7a9ea4b8b89d": "6c6c611ae3397c524ea28fec85c1f8b8",
	"c4ced8d2c2f4129b58fd469712e4d838": "20655f99bed441a33a259b16b9935355",
	"db85afb351bf456c9f6c1ed236ca5457": "5f360b6881fbb857e809ca402ffdfda4",
	"293b8c882a550600a395e3c82b58f833": "668cdee516a1fb4a2ab83835eaf1e035",
	"2a4c4317b6951f2ee8d0bf52c89614a3": "0d1257d702d294733db17470d04e546c",
	"66377923675b93ec93a30c3411292d47": "41dd160743c1707676c4faa6759c718b",
	"9012c0df72a664cd90358d69ec41df45": "66e063ab0666db09ce429dc6974b8df8",
	"d193ab1a44b659f4dfbef13a3a6440f9": "1bf2a3fb6a8f4abebdb7a88992026b7d",
	"62619a01b9dd1e1dec71d6f6557c9cb8": "fa9e235782bba9bdb62005106bbdd6d9",
	"5a1d0fbbb9c71b9ec99b31734560d4d1": "277e3fdeae03359715f5b1432e00619c",
	"cd6b5456da3f4e586959e20ca1b413a0": "571a7dd294812109ab0bf179ecf863eb",
	"e274ef5f7e7bb3915d46ace2f2a50dde": "4a142a526975994a83d3accdc12058a0",
	"cd4296af21eb61bd3078372aef79c6f8": "ecce5b1818ae13630c3a09449489c424",
	"03abed2436ae00ff738a55bc9758c63c": "d6337e0ceed2bf39c2559bec1b517aec",
	"c09bd406f26faeab1683244e53bab0b4": "0f9c649bb3f59a7a342b53cdc78952a4",
	"35449fa64a627725e9f3129b6596b2a7": "5ed7ff97aa96afb6a023ad8ce6636eba",
	"28b17de5f7b3d15229205c65f1173fb7": "950970c1b38c30b33bbb5aa5c3353b48",
	"ec0fdcc9700f2362e584d98dd2a88f88": "f37aecbe63a1039fb481286c9b6fcc3c",
	"3050727a9de336da69b1b7865ad2cf2d": "d3782c7410166c2c7c00b54886241e7b",
	"842bef708173f5e6e1186bfb25e35e38": "f9c6499bbad853ebcb1ca8e3364fc677",
	"fff777c54e423cea55d217f6954f635c": "617649459c3795af10c38e477e35ba73",
	"80825120ec77d6da5fa04c2e5d73f115": "06ff860de906282c96487b440ecfd05e",
	"5de19cbd4b2d1ff80ba14d6d89246ae9": "1e48ba6c2140461745fc407bf34f5598",
	"bccf47163b5058460ec0a00ddb08d0bb": "9c90d75a1cb539e68db4c94e8552884a",
	"3f27c81408709eb3ad93c81b1fbb516f": "e8db81c59ba75ebb6ecf44f7b8519f74",
	"93e504a96d675da78630b8a27ee6199b": "dab635fb86bde2441e38ef00f4b91907",
	"e6d017f040bcadf0006755aa929897b7": "0cfbd28757df8b81a553cf65e3149b1e",
	"a36548792cb4ff401f9b56e3ade897f6": "28f142be07616ba497b1afd206477963",
	"41925a41899add8220e9815466adc265": "23ca13a02f05aed58a4c86c2390bf6de",
	"fa8d8691876be30f245bc878d0a29745": "136fdb6578daa3b81aef369495de4c3d",
	"e0ed0e3e0a6b9e63a201fa79e390a054": "7b6a53e0356c50456b949d1c7104663e",
	"a7a9d14928bdbaf4ec973a65ac878999": "6113c0cc8ab0b7afd2f49a6fc7f7bc3a",
	"49665630511298f462fb938a0e1b3096": "c74d2a9679b8cd5fce900169385c035c",
	"4e63e9081027157f00910ffd8c55c02e": "9ac00d455f68b3217d0a64938081a5fe",
	"4622932a419f939cc537e765a5bbe543": "528f7e92b624e35bb42828e372c45252",
	"cf3124da3d7bf217f7969b6ae4e60e38": "701eb0ccb34fe3d319ea1307bc36c1ef",
	"257e65746310895c10fff95ce172415d": "3b16e8f85f3165586cb0170232a80f1f",
}

const CSV9C_REMOTE_FIXED_EFFECTS = {
	"bccf47163b5058460ec0a00ddb08d0bb": "res://scripts/effects/trainer_effects/CSV9C176EnergySearchPro.gd",
	"3f27c81408709eb3ad93c81b1fbb516f": "res://scripts/effects/trainer_effects/CSV9C178GlassTrumpet.gd",
	"1da701b43813d6ddb1238e54bce95811": "res://scripts/effects/trainer_effects/CSV9C180ScrambleSwitch.gd",
	"93e504a96d675da78630b8a27ee6199b": "res://scripts/effects/trainer_effects/CSV9C181TeraOrb.gd",
	"e6d017f040bcadf0006755aa929897b7": "res://scripts/effects/trainer_effects/CSV9C183PerfectMixer.gd",
	"a36548792cb4ff401f9b56e3ade897f6": "res://scripts/effects/trainer_effects/CSV9C186PreciousTrolley.gd",
	"41925a41899add8220e9815466adc265": "res://scripts/effects/tool_effects/CSV9C190CounterGain.gd",
	"fa8d8691876be30f245bc878d0a29745": "res://scripts/effects/trainer_effects/CSV9C196Crispin.gd",
	"e0ed0e3e0a6b9e63a201fa79e390a054": "res://scripts/effects/trainer_effects/CSV9C198Cilan.gd",
	"a7a9d14928bdbaf4ec973a65ac878999": "res://scripts/effects/trainer_effects/CSV9C202Briar.gd",
	"49665630511298f462fb938a0e1b3096": "res://scripts/effects/trainer_effects/CSV9C204LuciansAppeal.gd",
	"4e63e9081027157f00910ffd8c55c02e": "res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd",
	"4622932a419f939cc537e765a5bbe543": "res://scripts/effects/stadium_effects/CSV9C206VibrantPalace.gd",
	"cf3124da3d7bf217f7969b6ae4e60e38": "res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd",
	"257e65746310895c10fff95ce172415d": "res://scripts/effects/energy_effects/CSV9C208RichEnergy.gd",
}

static func _load_effect_script(path: String) -> GDScript:
	var cached_ref: Variant = _effect_script_cache.get(path, null)
	if cached_ref is WeakRef:
		var cached_script := (cached_ref as WeakRef).get_ref() as GDScript
		if cached_script != null:
			return cached_script
	var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script != null:
		_effect_script_cache[path] = weakref(script)
	return script

static func _instantiate_effect(script_path: String, args: Array = []) -> BaseEffect:
	var script := _load_effect_script(script_path)
	if script == null:
		return null
	return script.callv("new", args) as BaseEffect


static func _canonical_csv9c_effect_id(effect_id: String) -> String:
	return str(CSV9C_EFFECT_ID_ALIASES.get(effect_id, effect_id))

const AttackDefenderAttackLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackDefenderAttackLockNextTurn.gd"
const AttackGreninjaExShinobiBladeEffect = "res://scripts/effects/pokemon_effects/AttackGreninjaExShinobiBlade.gd"
const AttackGreninjaExMirageBarrageEffect = "res://scripts/effects/pokemon_effects/AttackGreninjaExMirageBarrage.gd"
const AbilityZamazentaVSTARShieldEffect = "res://scripts/effects/pokemon_effects/AbilityZamazentaVSTARShield.gd"
const EffectJaninesSecretArtEffect = "res://scripts/effects/trainer_effects/EffectJaninesSecretArt.gd"
const EffectCynthiasAmbitionEffect = "res://scripts/effects/trainer_effects/EffectCynthiasAmbition.gd"
const AbilityRecoverDiscardCardsToHandVSTAR = "res://scripts/effects/pokemon_effects/AbilityRecoverDiscardCardsToHandVSTAR.gd"
const AttackOwnFieldEnergyCountDamage = "res://scripts/effects/pokemon_effects/AttackOwnFieldEnergyCountDamage.gd"
const AttackAttachBasicEnergyFromDeckToSelfAndStatus = "res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDeckToSelfAndStatus.gd"
const AttackBonusIfSelfStatusEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfSelfStatus.gd"
const AttackApplySelfStatusEffect = "res://scripts/effects/pokemon_effects/AttackApplySelfStatus.gd"
const AbilityBruteBonnetToxicPowderEffect = "res://scripts/effects/pokemon_effects/AbilityBruteBonnetToxicPowder.gd"
const AbilityPoisonDamageBoostEffect = "res://scripts/effects/pokemon_effects/AbilityPoisonDamageBoost.gd"
const AbilityTachyonBitsEffect = "res://scripts/effects/pokemon_effects/AbilityTachyonBits.gd"
const AbilitySearchDeckCardTypeEffect = "res://scripts/effects/pokemon_effects/AbilitySearchDeckCardType.gd"
const AttackSelfStatusCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackSelfStatusCountDamage.gd"
const AttackDiscardAllAttachedEnergyFromSelfEffect = "res://scripts/effects/pokemon_effects/AttackDiscardAllAttachedEnergyFromSelf.gd"
const AttackDiscardAllEnergyTakePrizeEffect = "res://scripts/effects/pokemon_effects/AttackDiscardAllEnergyTakePrize.gd"
const EffectSupereffectiveGlassesEffect = "res://scripts/effects/tool_effects/EffectSupereffectiveGlasses.gd"
const EffectToolAncientBoosterEnergyCapsuleEffect = "res://scripts/effects/tool_effects/EffectToolAncientBoosterEnergyCapsule.gd"
const EffectPerilousJungleEffect = "res://scripts/effects/stadium_effects/EffectPerilousJungle.gd"
const AbilitySubjugatingChains = "res://scripts/effects/pokemon_effects/AbilitySubjugatingChains.gd"
const AttackDiscardAttachedEnergyFromSelf = "res://scripts/effects/pokemon_effects/AttackDiscardAttachedEnergyFromSelf.gd"
const AttackSelfLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackSelfLockNextTurn.gd"
const AttackSelfAllAttacksLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd"
const AttackDragonLauncher = "res://scripts/effects/pokemon_effects/AttackDragonLauncher.gd"
const EffectHisuianHeavyBallEffect = "res://scripts/effects/trainer_effects/EffectHisuianHeavyBall.gd"
const EffectRecoverBasicEnergyEffect = "res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd"
const EffectSearchBasicEnergyEffect = "res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd"
const EffectLanceEffect = "res://scripts/effects/trainer_effects/EffectLance.gd"
const EffectDarkPatchEffect = "res://scripts/effects/trainer_effects/EffectDarkPatch.gd"
const EffectEnergyStickerEffect = "res://scripts/effects/trainer_effects/EffectEnergySticker.gd"
const AbilityStarPortalEffect = "res://scripts/effects/pokemon_effects/AbilityStarPortal.gd"
const AbilityBonusDrawIfActiveEffect = "res://scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd"
const AbilityDrawIfActiveEffect = "res://scripts/effects/pokemon_effects/AbilityDrawIfActive.gd"
const AbilityDiscardHandDrawEndTurnEffect = "res://scripts/effects/pokemon_effects/AbilityDiscardHandDrawEndTurn.gd"
const AbilityAttachFromDeckEffect = "res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd"
const AttackSearchDeckToHandEffect = "res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd"
const AttackCoinFlipMultiplierEffect = "res://scripts/effects/pokemon_effects/AttackCoinFlipMultiplier.gd"
const AttackDiscardBasicEnergyFromHandDamageEffect = "res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromHandDamage.gd"
const AttackLookTopPickHandRestLostZoneEffect = "res://scripts/effects/pokemon_effects/AttackLookTopPickHandRestLostZone.gd"
const AttackSearchDeckToTopEffect = "res://scripts/effects/pokemon_effects/AttackSearchDeckToTop.gd"
const AttackDelphoxVMagicFireEffect = "res://scripts/effects/pokemon_effects/AttackDelphoxVMagicFire.gd"
const AttackSelfLockUntilLeaveActiveEffect = "res://scripts/effects/pokemon_effects/AttackSelfLockUntilLeaveActive.gd"
const EffectRoxanneEffect = "res://scripts/effects/trainer_effects/EffectRoxanne.gd"
const EffectCylleneEffect = "res://scripts/effects/trainer_effects/EffectCyllene.gd"
const EffectTrekkingShoesEffect = "res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd"
const EffectPokemonCatcherEffect = "res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd"
const EffectEnergySwitchEffect = "res://scripts/effects/trainer_effects/EffectEnergySwitch.gd"
const EffectScrambleSwitchEffect = "res://scripts/effects/trainer_effects/CSV9C180ScrambleSwitch.gd"
const EffectNightStretcherEffect = "res://scripts/effects/trainer_effects/EffectNightStretcher.gd"
const EffectUnfairStampEffect = "res://scripts/effects/trainer_effects/EffectUnfairStamp.gd"
const EffectCarmineEffect = "res://scripts/effects/trainer_effects/EffectCarmine.gd"
const AbilityMoveOpponentDamageCountersEffect = "res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd"
const AbilityBenchDamageOnPlayEffect = "res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd"
const AbilityPrizeCountColorlessReductionEffect = "res://scripts/effects/pokemon_effects/AbilityPrizeCountColorlessReduction.gd"
const AttackCoinFlipApplyStatusEffect = "res://scripts/effects/pokemon_effects/AttackCoinFlipApplyStatus.gd"
const AbilitySelfHealVSTAREffect = "res://scripts/effects/pokemon_effects/AbilitySelfHealVSTAR.gd"
const AbilityMillDeckRecoverToHandEffect = "res://scripts/effects/pokemon_effects/AbilityMillDeckRecoverToHand.gd"
const AttackMillAndAttachAllEnergyEffect = "res://scripts/effects/pokemon_effects/AttackMillAndAttachAllEnergy.gd"
const AttackOpponentHandCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackOpponentHandCountDamage.gd"
const AttackBonusIfSelfDamagedEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfSelfDamaged.gd"
const AttackAttachBasicEnergyFromDiscardEffect = "res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd"
const AttackMillOpponentDeckEffect = "res://scripts/effects/pokemon_effects/AttackMillOpponentDeck.gd"
const AttackDiscardHandDrawCardsEffect = "res://scripts/effects/pokemon_effects/AttackDiscardHandDrawCards.gd"
const AttackDiscardBasicEnergyFromFieldDamageEffect = "res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromFieldDamage.gd"
const AttackDiscardEnergyMultiDamageEffect = "res://scripts/effects/pokemon_effects/AttackDiscardEnergyMultiDamage.gd"
const AbilityAttachBasicEnergyFromHandDrawEffect = "res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd"
const AbilityAttachBasicEnergyFromHandToBenchDrawEffect = "res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandToBenchDraw.gd"
const AbilityLookTopToHandEffect = "res://scripts/effects/pokemon_effects/AbilityLookTopToHand.gd"
const AbilityDrawIfKnockoutLastTurnEffect = "res://scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd"
const AttackReviveFromDiscardToBenchEffect = "res://scripts/effects/pokemon_effects/AttackReviveFromDiscardToBench.gd"
const AbilitySelfKnockoutDamageCountersEffect = "res://scripts/effects/pokemon_effects/AbilitySelfKnockoutDamageCounters.gd"
const AttackReduceDamageNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd"
const AttackActiveEnergyCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackActiveEnergyCountDamage.gd"
const AttackAnyTargetDamageEffect = "res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd"
const AttackDrawToHandSizeEffect = "res://scripts/effects/pokemon_effects/AttackDrawToHandSize.gd"
const AttackKODefenderIfHasSpecialEnergyEffect = "res://scripts/effects/pokemon_effects/AttackKODefenderIfHasSpecialEnergy.gd"
const AttackMillSelfDeckEffect = "res://scripts/effects/pokemon_effects/AttackMillSelfDeck.gd"
const AbilitySearchBasicWaterEnergyActiveEffect = "res://scripts/effects/pokemon_effects/AbilitySearchBasicWaterEnergyActive.gd"
const AbilityAttachBasicWaterEnergyFromHandEffect = "res://scripts/effects/pokemon_effects/AbilityAttachBasicWaterEnergyFromHand.gd"
const AttackDrawCardsEffect = "res://scripts/effects/pokemon_effects/AttackDrawCards.gd"
const EffectTempleOfSinnohEffect = "res://scripts/effects/stadium_effects/EffectTempleOfSinnoh.gd"
const EffectGravityMountainEffect = "res://scripts/effects/stadium_effects/EffectGravityMountain.gd"
const EffectJammingTowerEffect = "res://scripts/effects/stadium_effects/EffectJammingTower.gd"
const EffectSparklingCrystalEffect = "res://scripts/effects/tool_effects/EffectSparklingCrystal.gd"
const EffectLegacyEnergyEffect = "res://scripts/effects/energy_effects/EffectLegacyEnergy.gd"
const EffectReversalEnergyEffect = "res://scripts/effects/energy_effects/EffectReversalEnergy.gd"
const EffectMelaEffect = "res://scripts/effects/trainer_effects/EffectMela.gd"
const EffectSadasVitalityEffect = "res://scripts/effects/trainer_effects/EffectSadasVitality.gd"
const EffectCherensCareEffect = "res://scripts/effects/trainer_effects/EffectCherensCare.gd"
const EffectTMTurboEnergizeEffect = "res://scripts/effects/trainer_effects/EffectTMTurboEnergize.gd"
const EffectTMCrisisPunchEffect = "res://scripts/effects/trainer_effects/EffectTMCrisisPunch.gd"
const EffectKieranEffect = "res://scripts/effects/trainer_effects/EffectKieran.gd"
const EffectBlackBeltsTrainingEffect = "res://scripts/effects/trainer_effects/EffectBlackBeltsTraining.gd"
const EffectExplorersGuidanceEffect = "res://scripts/effects/trainer_effects/EffectExplorersGuidance.gd"
const AttackDefenderRetreatLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackDefenderRetreatLockNextTurn.gd"
const AttackGreatTuskLandCollapseEffect = "res://scripts/effects/pokemon_effects/AttackGreatTuskLandCollapse.gd"
const AttackSweetTrapEffect = "res://scripts/effects/pokemon_effects/AttackSweetTrap.gd"
const AttackReturnEnergyThenBenchDamageEffect = "res://scripts/effects/pokemon_effects/AttackReturnEnergyThenBenchDamage.gd"
const AttackTargetOwnBenchDamageEffect = "res://scripts/effects/pokemon_effects/AttackTargetOwnBenchDamage.gd"
const AttackTargetOpponentBenchDamageEffect = "res://scripts/effects/pokemon_effects/AttackTargetOpponentBenchDamage.gd"
const AttackCrobatCriticalBiteEffect = "res://scripts/effects/pokemon_effects/AttackCrobatCriticalBite.gd"
const AbilityMoveBasicEnergyToOwnPokemonEffect = "res://scripts/effects/pokemon_effects/AbilityMoveBasicEnergyToOwnPokemon.gd"
const AbilityMoveFireEnergyFromBenchToActiveEffect = "res://scripts/effects/pokemon_effects/AbilityMoveFireEnergyFromBenchToActive.gd"
const AbilityBenchEnterSwitchAndMoveEnergyEffect = "res://scripts/effects/pokemon_effects/AbilityBenchEnterSwitchAndMoveEnergy.gd"
const AbilityPrizeToBenchAndExtraPrizeEffect = "res://scripts/effects/pokemon_effects/AbilityPrizeToBenchAndExtraPrize.gd"
const AbilityPreventDamageFromBasicExEffect = "res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd"
const AbilityPreventDamageFromAttackersWithAbilitiesEffect = "res://scripts/effects/pokemon_effects/AbilityPreventDamageFromAttackersWithAbilities.gd"
const AttackDistributedBenchCountersEffect = "res://scripts/effects/pokemon_effects/AttackDistributedBenchCounters.gd"
const AttackLostMineEffect = "res://scripts/effects/pokemon_effects/AttackLostMine.gd"
const AttackUseDiscardDragonAttackEffect = "res://scripts/effects/pokemon_effects/AttackUseDiscardDragonAttack.gd"
const AttackIgnoreWeaknessResistanceAndEffectsEffect = "res://scripts/effects/pokemon_effects/AttackIgnoreWeaknessResistanceAndEffects.gd"
const EffectTMDevolutionEffect = "res://scripts/effects/trainer_effects/EffectTMDevolution.gd"
const AbilityDiscardDrawAnyEffect = "res://scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd"
const AttackFixedCoinFlipDamageEffect = "res://scripts/effects/pokemon_effects/AttackFixedCoinFlipDamage.gd"
const AttackDiscardAttachedEnergyTypeFromSelfEffect = "res://scripts/effects/pokemon_effects/AttackDiscardAttachedEnergyTypeFromSelf.gd"
const AttackSelectOpponentBenchDamageEffect = "res://scripts/effects/pokemon_effects/AttackSelectOpponentBenchDamage.gd"
const AttackOwnDamageCounterReductionEffect = "res://scripts/effects/pokemon_effects/AttackOwnDamageCounterReduction.gd"
const AttackOpponentRetreatCostReductionEffect = "res://scripts/effects/pokemon_effects/AttackOpponentRetreatCostReduction.gd"
const AttackRecoverTrainerFromDiscardEffect = "res://scripts/effects/pokemon_effects/AttackRecoverTrainerFromDiscard.gd"
const AbilityDrawToHandSizeActiveEffect = "res://scripts/effects/pokemon_effects/AbilityDrawToHandSizeActive.gd"
const AbilityAncientWisdomEffect = "res://scripts/effects/pokemon_effects/AbilityAncientWisdom.gd"
const AttackBonusIfDefenderMechanicEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfDefenderMechanic.gd"
const AbilityPsychicEmbraceEffect = "res://scripts/effects/pokemon_effects/AbilityPsychicEmbrace.gd"
const AttackClearOwnStatusEffect = "res://scripts/effects/pokemon_effects/AttackClearOwnStatus.gd"
const AbilityMoveDamageCountersToOpponentEffect = "res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd"
const AttackSelfDamageCounterTargetDamageEffect = "res://scripts/effects/pokemon_effects/AttackSelfDamageCounterTargetDamage.gd"
const AttackSelfDamageCounterMultiplierEffect = "res://scripts/effects/pokemon_effects/AttackSelfDamageCounterMultiplier.gd"
const AttackSwitchSelfToBenchEffect = "res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd"
const AttackSwitchOpponentActiveEffect = "res://scripts/effects/pokemon_effects/AttackSwitchOpponentActive.gd"
const AbilityBasicLockEffect = "res://scripts/effects/pokemon_effects/AbilityBasicLock.gd"
const AbilityBasicVLockEffect = "res://scripts/effects/pokemon_effects/AbilityBasicVLock.gd"
const AttackDiscardDefenderToolEffect = "res://scripts/effects/pokemon_effects/AttackDiscardDefenderTool.gd"
const EffectSecretBoxEffect = "res://scripts/effects/trainer_effects/EffectSecretBox.gd"
const EffectArtazonEffect = "res://scripts/effects/stadium_effects/EffectArtazon.gd"
const EffectCalamitousWastelandEffect = "res://scripts/effects/stadium_effects/EffectCalamitousWasteland.gd"
const EffectSurvivalBraceEffect = "res://scripts/effects/tool_effects/EffectSurvivalBrace.gd"
const AttackTMEvolutionEffect = "res://scripts/effects/pokemon_effects/AttackTMEvolution.gd"
const AttackSearchEnergyFromDeckToSelfEffect = "res://scripts/effects/pokemon_effects/AttackSearchEnergyFromDeckToSelf.gd"
const AbilityLostZoneAttackCostReductionEffect = "res://scripts/effects/pokemon_effects/AbilityLostZoneAttackCostReduction.gd"
const AbilityFlowerSelectingEffect = "res://scripts/effects/pokemon_effects/AbilityFlowerSelecting.gd"
const AbilityRunAwayDrawEffect = "res://scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd"
const AttackIgnoreWeaknessEffect = "res://scripts/effects/pokemon_effects/AttackIgnoreWeakness.gd"
const AttackCoinFlipPreventDamageAndEffectsNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd"
const AttackKnockoutDefenderThenSelfDamageEffect = "res://scripts/effects/pokemon_effects/AttackKnockoutDefenderThenSelfDamage.gd"
const AttackDiscardStadiumBonusDamageEffect = "res://scripts/effects/pokemon_effects/AttackDiscardStadiumBonusDamage.gd"
const AttackOptionalBonusSelfDamageEffect = "res://scripts/effects/pokemon_effects/AttackOptionalBonusSelfDamage.gd"
const CSV8CConkeldurrEffectsEffect = "res://scripts/effects/pokemon_effects/CSV8CConkeldurrEffects.gd"
const AttackItemLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackItemLockNextTurn.gd"
const EffectMirageGateEffect = "res://scripts/effects/trainer_effects/EffectMirageGate.gd"
const EffectColressExperimentEffect = "res://scripts/effects/trainer_effects/EffectColressExperiment.gd"
const EffectHyperAromaEffect = "res://scripts/effects/trainer_effects/EffectHyperAroma.gd"
const EffectSalvatoreEffect = "res://scripts/effects/trainer_effects/EffectSalvatore.gd"
const EffectExpShareEffect = "res://scripts/effects/tool_effects/EffectExpShare.gd"
const EffectLeagueHQEffect = "res://scripts/effects/stadium_effects/EffectLeagueHQ.gd"
const EffectLuminousEnergyEffect = "res://scripts/effects/energy_effects/EffectLuminousEnergy.gd"
const EffectNeoUpperEnergyEffect = "res://scripts/effects/energy_effects/EffectNeoUpperEnergy.gd"
const EffectMagmaBasinEffect = "res://scripts/effects/stadium_effects/EffectMagmaBasin.gd"
const EffectCyclingRoadEffect = "res://scripts/effects/stadium_effects/EffectCyclingRoad.gd"
const EffectCrushingHammerEffect = "res://scripts/effects/trainer_effects/EffectCrushingHammer.gd"
const EffectEriEffect = "res://scripts/effects/trainer_effects/EffectEri.gd"
const EffectPennyEffect = "res://scripts/effects/trainer_effects/EffectPenny.gd"
const EffectScoopUpCycloneEffect = "res://scripts/effects/trainer_effects/EffectScoopUpCyclone.gd"
const EffectLoveBallEffect = "res://scripts/effects/trainer_effects/EffectLoveBall.gd"
const EffectColressTenacityEffect = "res://scripts/effects/trainer_effects/EffectColressTenacity.gd"
const EffectErikasInvitation = "res://scripts/effects/trainer_effects/EffectErikasInvitation.gd"
const EffectXerosicsMachinations = "res://scripts/effects/trainer_effects/EffectXerosicsMachinations.gd"
const EffectGiacomo = "res://scripts/effects/trainer_effects/EffectGiacomo.gd"
const EffectMissFortuneSisters = "res://scripts/effects/trainer_effects/EffectMissFortuneSisters.gd"
const EffectHandheldFan = "res://scripts/effects/tool_effects/EffectHandheldFan.gd"
const EffectTeamYellsCheer = "res://scripts/effects/trainer_effects/EffectTeamYellsCheer.gd"
const EffectAccompanyingFlute = "res://scripts/effects/trainer_effects/EffectAccompanyingFlute.gd"
const AbilityPreventDamageFromExOrV = "res://scripts/effects/pokemon_effects/AbilityPreventDamageFromExOrV.gd"
const AbilityPreventSleepSelfEffect = "res://scripts/effects/pokemon_effects/AbilityPreventSleepSelf.gd"
const AbilityPreventTeraAttackDamageAndEffectsEffect = "res://scripts/effects/pokemon_effects/AbilityPreventTeraAttackDamageAndEffects.gd"
const AbilityBenchShuffleIntoDeck = "res://scripts/effects/pokemon_effects/AbilityBenchShuffleIntoDeck.gd"
const AbilityActiveRetreatLock = "res://scripts/effects/pokemon_effects/AbilityActiveRetreatLock.gd"
const AttackBonusIfOwnStadium = "res://scripts/effects/pokemon_effects/AttackBonusIfOwnStadium.gd"
const AttackPlaceDamageCountersOnOpponentActive = "res://scripts/effects/pokemon_effects/AttackPlaceDamageCountersOnOpponentActive.gd"
const AttackReviveBasicFromAnyDiscardToBench = "res://scripts/effects/pokemon_effects/AttackReviveBasicFromAnyDiscardToBench.gd"
const AttackReturnSelfAllCardsToHandEffect = "res://scripts/effects/pokemon_effects/AttackReturnSelfAllCardsToHand.gd"
const AttackMoveOwnDamageCountersToOpponentEffect = "res://scripts/effects/pokemon_effects/AttackMoveOwnDamageCountersToOpponent.gd"
const AbilityMoveAnyEnergyToSelfOnActiveEffect = "res://scripts/effects/pokemon_effects/AbilityMoveAnyEnergyToSelfOnActive.gd"
const AttackDiscardOpponentToolsEffect = "res://scripts/effects/pokemon_effects/AttackDiscardOpponentTools.gd"
const AttackBonusIfDefenderEvolvedEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfDefenderEvolved.gd"
const EffectEmergencyJellyEffect = "res://scripts/effects/tool_effects/EffectEmergencyJelly.gd"
const EffectPowerglassEffect = "res://scripts/effects/tool_effects/EffectPowerglass.gd"
const EffectLookBottomCardsEffect = "res://scripts/effects/trainer_effects/EffectLookBottomCards.gd"
const EffectMoonlitHillEffect = "res://scripts/effects/stadium_effects/EffectMoonlitHill.gd"
const EffectRoseannesBackupEffect = "res://scripts/effects/trainer_effects/EffectRoseannesBackup.gd"
const AttackChosenDefenderAttackLockNextTurnEffect = "res://scripts/effects/pokemon_effects/AttackChosenDefenderAttackLockNextTurn.gd"
const AbilityAttachBasicEnergyFromDiscardToOwnEffect = "res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromDiscardToOwn.gd"
const EffectEnhancedHammerEffect = "res://scripts/effects/trainer_effects/EffectEnhancedHammer.gd"
const EffectHealAllPokemonEffect = "res://scripts/effects/trainer_effects/EffectHealAllPokemon.gd"
const AttackFieldEnergyThresholdBonusEffect = "res://scripts/effects/pokemon_effects/AttackFieldEnergyThresholdBonus.gd"
const AttackAncientDiscardCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackAncientDiscardCountDamage.gd"
const EffectLetterOfEncouragementEffect = "res://scripts/effects/trainer_effects/EffectLetterOfEncouragement.gd"
const EffectLuxuriousCapeEffect = "res://scripts/effects/tool_effects/EffectLuxuriousCape.gd"
const EffectDefianceVestEffect = "res://scripts/effects/tool_effects/EffectDefianceVest.gd"
const EffectRigidBandEffect = "res://scripts/effects/tool_effects/EffectRigidBand.gd"
const AttackSelfEnergyCountMultiplierBonusEffect = "res://scripts/effects/pokemon_effects/AttackSelfEnergyCountMultiplierBonus.gd"
const AbilityOvervoltDischargeEffect = "res://scripts/effects/pokemon_effects/AbilityOvervoltDischarge.gd"
const AbilityTorrentHeartEffect = "res://scripts/effects/pokemon_effects/AbilityTorrentHeart.gd"
const AbilityPreEvolutionAttacksEffect = "res://scripts/effects/pokemon_effects/AbilityPreEvolutionAttacks.gd"
const AbilityEeveeExRainbowFactorEffect = "res://scripts/effects/pokemon_effects/AbilityEeveeExRainbowFactor.gd"
const CSV8CGalvantulaEffectsEffect = "res://scripts/effects/pokemon_effects/CSV8CGalvantulaEffects.gd"
const EffectGapejawBogEffect = "res://scripts/effects/stadium_effects/EffectGapejawBog.gd"
const AbilityPlaceDamageCountersVSTAREffect = "res://scripts/effects/pokemon_effects/AbilityPlaceDamageCountersVSTAR.gd"
const AttackBonusIfDefenderDamagedEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfDefenderDamaged.gd"
const AttackAttachBasicEnergyFromHandToOwnPokemonEffect = "res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromHandToOwnPokemon.gd"
const AbilityNoEnergyFreeRetreatEffect = "res://scripts/effects/pokemon_effects/AbilityNoEnergyFreeRetreat.gd"
const AttackMoveAttachedEnergyToOwnBenchEffect = "res://scripts/effects/pokemon_effects/AttackMoveAttachedEnergyToOwnBench.gd"
const AttackCoinFlipDiscardOpponentActiveEnergyEffect = "res://scripts/effects/pokemon_effects/AttackCoinFlipDiscardOpponentActiveEnergy.gd"
const AttackOwnFieldTaggedPokemonCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackOwnFieldTaggedPokemonCountDamage.gd"
const AttackCoinFlipBonusDamageEffect = "res://scripts/effects/pokemon_effects/AttackCoinFlipBonusDamage.gd"
const AttackOpponentFieldEnergyCountDamageEffect = "res://scripts/effects/pokemon_effects/AttackOpponentFieldEnergyCountDamage.gd"
const AttackHealOwnBenchPokemonEffect = "res://scripts/effects/pokemon_effects/AttackHealOwnBenchPokemon.gd"
const AttackSelfDamageCounterBonusEffect = "res://scripts/effects/pokemon_effects/AttackSelfDamageCounterBonus.gd"
const AttackBonusIfDefenderEvolvedDiscardAllEnergyFromSelfEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfDefenderEvolvedDiscardAllEnergyFromSelf.gd"
const AttackBonusIfOpponentActiveTeraEffect = "res://scripts/effects/pokemon_effects/AttackBonusIfOpponentActiveTera.gd"
const Batch3178WorkerCSupportPokemonEffectsScript = preload("res://scripts/effects/pokemon_effects/Batch3178WorkerCSupportPokemonEffects.gd")
const EffectFeatherBallEffect = "res://scripts/effects/trainer_effects/EffectFeatherBall.gd"
const EffectArezuEffect = "res://scripts/effects/trainer_effects/EffectArezu.gd"
const EffectAcademyAtNightEffect = "res://scripts/effects/stadium_effects/EffectAcademyAtNight.gd"
const AttackRagingBoltLightningStormEffect = "res://scripts/effects/pokemon_effects/AttackRagingBoltLightningStorm.gd"
const AttackBruteBonnetDamageCounterBonusEffect = "res://scripts/effects/pokemon_effects/AttackBruteBonnetDamageCounterBonus.gd"
const AttackOpponentFuturePokemonBonusDamageEffect = "res://scripts/effects/pokemon_effects/AttackOpponentFuturePokemonBonusDamage.gd"
const AbilityToedscruelSlimeMoldColonyEffect = "res://scripts/effects/pokemon_effects/AbilityToedscruelSlimeMoldColony.gd"
const AbilityDragonHoardEffect = "res://scripts/effects/pokemon_effects/AbilityDragonHoard.gd"
const NoivernExEffectsEffect = "res://scripts/effects/pokemon_effects/NoivernExEffects.gd"
const CSV9CSimpleHealSelfAfterAttackEffect = "res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd"
## ==================== 主入口 ====================

## 注册所有已知卡牌效果到 EffectProcessor
## 包含：物品卡、支援者卡、道具、竞技场、特殊能量
static func register_all(processor: EffectProcessor) -> void:
	_register_items(processor)
	_register_supporters(processor)
	_register_tools(processor)
	_register_stadiums(processor)
	_register_special_energies(processor)
	_register_csv9c_effect_aliases(processor)


## 根据宝可梦卡牌数据注册其特性效果和招式附加效果
## 通过特性名称和招式名称进行匹配，无需硬编码 effect_id
static func _register_csv9c_effect_aliases(processor: EffectProcessor) -> void:
	for effect_id: String in CSV9C_REMOTE_FIXED_EFFECTS.keys():
		processor.register_effect(effect_id, _instantiate_effect(str(CSV9C_REMOTE_FIXED_EFFECTS[effect_id])))


static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	var eid: String = card.effect_id
	if eid == "":
		return

	# 注册特性效果
	for ability: Dictionary in card.abilities:
		var ability_name: String = ability.get("name", "")
		if ability_name == "":
			continue
		var ability_effect: BaseEffect = _get_ability_effect(ability_name)
		if ability_effect != null:
			processor.register_effect(eid, ability_effect)

	# 注册招式附加效果
	for attack_index: int in card.attacks.size():
		var attack: Dictionary = card.attacks[attack_index]
		var attack_name: String = attack.get("name", "")
		if attack_name == "":
			continue
		var attack_effects: Array = _get_attack_effects(processor, attack_name)
		for fx: BaseEffect in attack_effects:
			_bind_attack_index_if_supported(fx, attack_index)
			processor.register_attack_effect(eid, fx)

	_register_pokemon_effect_overrides(processor, eid)


static func _bind_attack_index_if_supported(effect: BaseEffect, attack_index: int) -> void:
	if effect == null:
		return
	for property_info: Dictionary in effect.get_property_list():
		if str(property_info.get("name", "")) != "attack_index_to_match":
			continue
		effect.set("attack_index_to_match", attack_index)
		return
	if effect.has_method("bind_default_attack_index"):
		effect.call("bind_default_attack_index", attack_index)


static func _register_pokemon_effect_overrides(processor: EffectProcessor, effect_id: String) -> void:
	match _canonical_csv9c_effect_id(effect_id):
		"00d90ff674296941a9da9d9a0255aa2d":
			processor.register_effect(effect_id, _instantiate_effect(AbilityZamazentaVSTARShieldEffect))
			var zamazenta_lock := _instantiate_effect(AttackSelfLockNextTurnEffect)
			_bind_attack_index_if_supported(zamazenta_lock, 0)
			processor.register_attack_effect(effect_id, zamazenta_lock)
		"9f00ff54c265aa486652154a5e976c67":
			processor.replace_attack_effects(effect_id, [AttackMoonlightShuriken.new(50, 2)])
		"28505a8ad6e07e74382c1b5e09737932":
			var budew_lock := _instantiate_effect(AttackItemLockNextTurnEffect)
			_bind_attack_index_if_supported(budew_lock, 0)
			processor.register_attack_effect(effect_id, budew_lock)
		"930f07ef177d44b0e1084343b66b13af":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOpponentFieldEnergyCountDamageEffect, [60, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackHealOwnBenchPokemonEffect, [100, 1]))
		"313cc7781c8489ce8c45d3597dfce241":
			var flareon_attach := AttackSearchAndAttach.new("", 2, "deck_search", 0, "any")
			flareon_attach.single_target_only = true
			flareon_attach.attack_index_to_match = 0
			processor.register_attack_effect(effect_id, flareon_attach)
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfAllAttacksLockNextTurnEffect, [1]))
		"76f4e0d39348c21f1f1a4be4d653b6a5":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPreventSleepSelfEffect))
		"f70ca79aa9a395b44c6ab39dda0062d3":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDefenderRetreatLockNextTurnEffect, [0]))
		"d0d0f124636acb646f26f6b06c203d80":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSwitchSelfToBenchEffect))
		"b49466f5df9dfcef38331df65187f068":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSwitchOpponentActiveEffect, [1]))
		"db55f545bfa9fdddaf526a23431e7434":
			processor.register_effect(effect_id, _instantiate_effect(AbilityTorrentHeartEffect, [5, 120]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfLockNextTurnEffect))
		"d348652e6296773db8b777e20e79fa4c":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPreEvolutionAttacksEffect, [processor]))
		"553639840a44f19ad83b89a892a21f98":
			processor.register_effect(effect_id, AbilityOnBenchEnter.new("search_supporter"))
		"5a80f8eb94c6fcc27c475c10a63cf856":
			processor.register_effect(effect_id, AbilityBenchImmune.new())
		"daab918dc820662c599221a8a1d85114":
			processor.register_effect(effect_id, AbilityMetalMaker.new(4, "M"))
		"e470ac9bf3503ca157a8679c91e19fb1":
			if not processor.has_attack_effect(effect_id):
				processor.register_attack_effect(effect_id, AttackEnergyCountDamage.new("M", 40, true, 0))
				processor.register_attack_effect(effect_id, AttackVSTARExtraTurn.new(1))
		"9d268c8f6262a80a57c6e645d7c9a18f":
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(10))
		"4e07b2880d96deaa7a9afef69575d6c8":
			processor.register_effect(effect_id, _instantiate_effect(AbilityLostZoneAttackCostReductionEffect, [4]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackIgnoreWeaknessEffect, [0]))
		"9561f33b1bcf22820a53bf2de8ba6e35":
			processor.register_effect(effect_id, _instantiate_effect(AbilityFlowerSelectingEffect))
		"47676dfc37415cfdf3b3992b1de64141":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDefenderAttackLockNextTurnEffect, ["evolved_only"]))
		"720fd5ca597f96db0f5f00d3ac16febb":
			processor.register_effect(effect_id, _instantiate_effect(AbilityStarPortalEffect))
			processor.register_attack_effect(effect_id, AttackBenchCountDamage.new(20, "both"))
		"63cf95979c653e65cbd502a4c0d3fbdd":
			var palkia_search := _instantiate_effect(AttackSearchDeckToHandEffect, [1, "Stadium"])
			_bind_attack_index_if_supported(palkia_search, 0)
			processor.register_attack_effect(effect_id, palkia_search)
			var palkia_lock := AttackSelfLockNextTurn.new()
			_bind_attack_index_if_supported(palkia_lock, 1)
			processor.register_attack_effect(effect_id, palkia_lock)
		"8bcc42363d38245b8b408cfaafa1ba30":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipMultiplierEffect, [20]))
		"07f01f4f21033a1bbc058e4af555420a":
			processor.register_effect(effect_id, _instantiate_effect(AbilityBonusDrawIfActiveEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardBasicEnergyFromHandDamageEffect, [50]))
		"74b83ef8987d072950dfe3bde3364d87":
			processor.register_effect(effect_id, _instantiate_effect(AbilityBenchDamageOnPlayEffect, [10, 2]))
		"f2afef80b13b8f6a071facbcade0251c":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPrizeCountColorlessReductionEffect))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"0a2064b80b0edf2b2ec683210e77e1f2":
			processor.register_attack_effect(effect_id, AttackCoinFlipOrFail.new(40, "no_damage", processor.coin_flipper))
		"99041ad1ee1b4ff984b57638cae3caf9":
			processor.register_attack_effect(effect_id, _instantiate_effect(
				AttackOptionalBonusSelfDamageEffect,
				[30, 30, 1, "追加造成30伤害，并给这只宝可梦造成30伤害？"]
			))
		"898ff379e73790978b8bdf6dfafc511f":
			processor.register_effect(effect_id, _instantiate_effect(CSV8CConkeldurrEffectsEffect))
			var conkeldurr_rampage := _instantiate_effect(CSV8CConkeldurrEffectsEffect)
			_bind_attack_index_if_supported(conkeldurr_rampage, 0)
			processor.register_attack_effect(effect_id, conkeldurr_rampage)
		"4aa937bbc437cbfd7b64597b7bcee0d2":
			processor.register_effect(effect_id, _instantiate_effect(CSV8CGalvantulaEffectsEffect, [0]))
			var galvantula_web := _instantiate_effect(CSV8CGalvantulaEffectsEffect, [0])
			_bind_attack_index_if_supported(galvantula_web, 0)
			processor.register_attack_effect(effect_id, galvantula_web)
		"f822c0b2e4cb2865a8ac7af9d3018969":
			processor.register_effect(effect_id, _instantiate_effect(AbilityRunAwayDrawEffect, [3]))
		"8c23889e3e58324f3d58029f72379fac":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipApplyStatusEffect, ["confused"]))
		"ea2b685fc75e11c65704bc2709c9af96":
			var frogadier_paralysis := _instantiate_effect(AttackCoinFlipApplyStatusEffect, ["paralyzed", processor.coin_flipper])
			_bind_attack_index_if_supported(frogadier_paralysis, 0)
			processor.register_attack_effect(effect_id, frogadier_paralysis)
		"11e3c629e34562a7061a05c483eb5718":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackLostMineEffect, [10, 120, 1]))
		"013d589bd3c3a4c3472231a966ff6786":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfSelfDamagedEffect, [70, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackIgnoreWeaknessEffect, [0]))
		"c3ada06b5a60fb63228d9f704109718b":
			processor.register_effect(effect_id, _instantiate_effect(AbilitySelfHealVSTAREffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackReduceDamageNextTurnEffect, [80]))
		"90c9e117fa846938024ae15eb859f1b6":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillAndAttachAllEnergyEffect, [3, 0]))
			processor.register_attack_effect(effect_id, AttackBenchSnipe.new(30, 1, 0, 1))
		"749d2f12d33057c8cc20e52c1b11bcbf":
			processor.register_effect(effect_id, _instantiate_effect(AbilityMillDeckRecoverToHandEffect, [7, 2, true]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackUseDiscardDragonAttackEffect, [processor]))
		"68244d82147e13bb7d77116ffedf6162":
			processor.register_effect(effect_id, _instantiate_effect(AbilityMoveOpponentDamageCountersEffect))
			var alakazam_mind_ruler := _instantiate_effect(AttackOpponentHandCountDamageEffect, [20, false, 20])
			_bind_attack_index_if_supported(alakazam_mind_ruler, 0)
			processor.register_attack_effect(effect_id, alakazam_mind_ruler)
		"5fbf2a43fe0f6df85dd1b7eb420ac678":
			var dialga_attach := _instantiate_effect(AttackAttachBasicEnergyFromDiscardEffect, ["M", 2])
			_bind_attack_index_if_supported(dialga_attach, 0)
			processor.register_attack_effect(effect_id, dialga_attach)
		"29f94ee004e4c312dbea4a7930d33544":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillOpponentDeckEffect, [1, 0]))
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(90, 1))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("burned", false, 1))
		"23706c5baababfabc76355e59709f4ec":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackGreatTuskLandCollapseEffect, [0]))
		"26afb8b359bdeb40834a9dafbba4218b":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSweetTrapEffect, [0]))
		"6027bb335acb1104add360a9425637af":
			processor.register_effect(effect_id, _instantiate_effect(AbilityDiscardDrawAnyEffect, [2]))
		"32dc6702e4af79d3715c6af88dee65d5":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackFixedCoinFlipDamageEffect, [3, 10, 10, 0, processor.coin_flipper]))
		"2317be04afe1bd94899a29fe09b84d96":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackFixedCoinFlipDamageEffect, [3, 10, 10, 0, processor.coin_flipper]))
		"bcd9644ea935ce567829f4a76756059b":
			processor.register_effect(effect_id, _instantiate_effect(AbilityAttachBasicEnergyFromHandToBenchDrawEffect, ["P", 2]))
		"2976780d606bf72db47d00825db85124":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyTypeFromSelfEffect, ["L", -1, 1]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelectOpponentBenchDamageEffect, [40, 2, 1]))
		"a300320fd4775b3a95e5aa87d0c75378":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOwnDamageCounterReductionEffect, [20, 1]))
		"873e6ea15bc769061eda7a433d95e9d6":
			var regice_gate := AttackCallForFamily.new(1)
			_bind_attack_index_if_supported(regice_gate, 0)
			processor.register_attack_effect(effect_id, regice_gate)
			var regice_lock := _instantiate_effect(AttackDefenderAttackLockNextTurnEffect, ["pokemon_v_only"])
			_bind_attack_index_if_supported(regice_lock, 1)
			processor.register_attack_effect(effect_id, regice_lock)
		"627d479a2e71c50d5c8d9bcfdd26bd0b":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackRecoverTrainerFromDiscardEffect, [1, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyTypeFromSelfEffect, ["L", 2, 1]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackTargetOpponentBenchDamageEffect, [120, 1]))
		"399668227ca75416c9e72e83d1810457":
			var regirock_gate := AttackCallForFamily.new(1)
			_bind_attack_index_if_supported(regirock_gate, 0)
			processor.register_attack_effect(effect_id, regirock_gate)
			var regirock_lock := _instantiate_effect(AttackSelfLockNextTurnEffect)
			_bind_attack_index_if_supported(regirock_lock, 1)
			processor.register_attack_effect(effect_id, regirock_lock)
		"db12f1eb552377de4cda107fbb6e1eb4":
			var registeel_gate := AttackCallForFamily.new(1)
			_bind_attack_index_if_supported(registeel_gate, 0)
			processor.register_attack_effect(effect_id, registeel_gate)
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOpponentRetreatCostReductionEffect, [50, 1]))
		"e49bf2cfe3c7948b0dcebbe1b1b7aa76":
			processor.register_effect(effect_id, _instantiate_effect(AbilityDragonHoardEffect, [4]))
		"d699ab2122b5617fe5a5c97e60ae4dac":
			processor.register_effect(effect_id, _instantiate_effect(AbilityAncientWisdomEffect, [3]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfDefenderMechanicEffect, [150, "VMAX", 0]))
		"e96bb407c5f18bb9eec55487e70395fd":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardHandDrawCardsEffect, [6, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardBasicEnergyFromFieldDamageEffect, [70, 1]))
		"90b0d1f117df6523fd92b9f3168d7f7e":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackKnockoutDefenderThenSelfDamageEffect, [200, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardStadiumBonusDamageEffect, [120, 1]))
		"3b9d970012f38e8fc348c5dbaf172802":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipPreventDamageAndEffectsNextTurnEffect, [processor.coin_flipper, 1]))
		"4e13cd08de3b6d141ce8e2f09d17a3a4":
			processor.register_effect(effect_id, _instantiate_effect(AbilityLookTopToHandEffect, [2, "", false, false, true]))
		"1ceeba6dac51ccc19833c5a513fe3fc6":
			processor.register_effect(effect_id, _instantiate_effect(AbilityLookTopToHandEffect, [6, "Supporter", true, true, false]))
		"57e95f8cb1129f6b45b7bbbc1a45b643":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPreventTeraAttackDamageAndEffectsEffect))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("asleep", false, 0))
		"233350ffecdbfac2a8fab27e7f7da282":
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("confused", false, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAllEnergyTakePrizeEffect, [1]))
		"ab6c3357e2b8a8385a68da738f41e0c1":
			processor.register_effect(effect_id, _instantiate_effect(AbilityDrawIfKnockoutLastTurnEffect, [3, "fezandipiti"]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackAnyTargetDamageEffect, [100]))
		"98ecdb0066cdc5dc6697a0075bcfa4a9":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyFromSelf, [1, 0]))
		"32ad0aabda779aea0420eed4505407be":
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("asleep", false, 1))
		"6d8bfccd0e05c3cfdea28540dce2deab":
			processor.register_effect(effect_id, _instantiate_effect(AbilityRecoverDiscardCardsToHandVSTAR, [2, "Item"]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOwnFieldEnergyCountDamage, ["D", 30]))
		"0da4be5989cece0719477261c8571fd9":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackAttachBasicEnergyFromDeckToSelfAndStatus, ["D", 2, "poisoned", 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfSelfStatusEffect, ["poisoned", 130, 1]))
		"e92d1881bfe5e0b957b87c93cd757fc7":
			processor.register_effect(effect_id, _instantiate_effect(AbilitySubjugatingChains))
			processor.register_attack_effect(effect_id, AttackPrizeCountDamage.new(60))
		"f3543bd547e44612b034263374aa0ef1":
			processor.register_effect(effect_id, _instantiate_effect(AbilityDiscardHandDrawEndTurnEffect, [5]))
			processor.register_attack_effect(effect_id, AttackPrizeCountDamage.new(30))
		"79513e01fbf5084d23e6c60232e2338c":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPrizeToBenchAndExtraPrizeEffect, [processor.coin_flipper]))
		"8c812520b47c53417bf960f22970dd18":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackTargetOwnBenchDamageEffect, [10, 0]))
		"ddf863adb9287aa59fd079a80a94f05a":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDragonLauncher, [100, 0]))
		"fd252ce877c709e9e3161c56ef98aff8":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPreventDamageFromBasicExEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackTargetOpponentBenchDamageEffect, [30, 0]))
		"4550f14d2ebd9d202a0c4ea5af9ec4d9":
			processor.register_effect(effect_id, _instantiate_effect(AbilityMoveBasicEnergyToOwnPokemonEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDrawToHandSizeEffect, [6, 0]))
		"4f4c17fe9f3429419f9e344fbecb140d":
			processor.register_effect(effect_id, _instantiate_effect(AbilityMoveFireEnergyFromBenchToActiveEffect))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("burned", false, 0))
		"2e307380eb013c4e20db0a19816ba3b9":
			processor.register_effect(effect_id, _instantiate_effect(AbilityBenchEnterSwitchAndMoveEnergyEffect))
		"ce6db179c3d166130e7a637581da3aa2":
			# 渡魂：从弃牌区选择最多3张「夜巡灵」放到备战区
			var duskull_revive := _instantiate_effect(AttackReviveFromDiscardToBenchEffect, [3, "夜巡灵"])
			_bind_attack_index_if_supported(duskull_revive, 0)
			processor.register_attack_effect(effect_id, duskull_revive)
		"ad031124df2ede62f945220fbbd680b3":
			processor.register_effect(effect_id, _instantiate_effect(AbilitySelfKnockoutDamageCountersEffect, [5]))
		"2a4178f21ba2bf13285bbb43ecaaa472":
			processor.register_effect(effect_id, _instantiate_effect(AbilitySelfKnockoutDamageCountersEffect, [13]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDefenderRetreatLockNextTurnEffect, [0]))
		"14cf8080c35f652fe13a579f1b50542a":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDefenderRetreatLockNextTurnEffect, [0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackReturnEnergyThenBenchDamageEffect, [120, 1]))
		"4f25f668ee0ab45c68f6954324c73003":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPreventDamageFromAttackersWithAbilitiesEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackIgnoreWeaknessResistanceAndEffectsEffect, [0]))
		"52a205820de799a53a689f23cbeb8622":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDistributedBenchCountersEffect, [60, 1]))
		"e45788bd7d9ffec5b3da3730d2dc806f":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackKODefenderIfHasSpecialEnergyEffect, [0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillSelfDeckEffect, [3, 1]))
		"409898a79b38fe8ca279e7bdaf4fd52e":
			processor.register_effect(effect_id, _instantiate_effect(AbilityAttachBasicEnergyFromHandDrawEffect, ["G", 1]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackActiveEnergyCountDamageEffect, [30]))
		"3c6c028efc71a5e7ee0fbd2e8f70ece9":
			processor.register_effect(effect_id, _instantiate_effect(AbilityDrawIfActiveEffect, [1]))
			processor.register_attack_effect(effect_id, AttackBenchCountDamage.new(20, "both"))
		"21cad77ee66ee136c386e766736ec247":
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("burned", false, 0))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("confused", false, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDelphoxVMagicFireEffect, [1]))
		"2d2fed5a4681c1000b070227a730eaff":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfLockUntilLeaveActiveEffect, [1]))
		"abf4ae7b5adf11b9d4f46ffda1417ac2":
			processor.register_effect(effect_id, _instantiate_effect(AbilityActiveRetreatLock))
			processor.register_attack_effect(effect_id, AttackSelfSleep.new())
		"db7b9902fd4fed3b6f9d94a7ee7a12ba":
			processor.register_effect(effect_id, _instantiate_effect(AbilityBasicVLockEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackReturnSelfAllCardsToHandEffect))
		"5a56387211377cf56bfeb12751a5eed3":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMoveOwnDamageCountersToOpponentEffect, [20, 0]))
		"32f943010bf08cb6046c0bcc64e1d7b8":
			processor.register_effect(effect_id, _instantiate_effect(AbilityMoveAnyEnergyToSelfOnActiveEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfEnergyCountMultiplierBonusEffect, [40]))
		"683af7fe3f0a254c5de433dfae8e1562":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardOpponentToolsEffect, [2, 1]))
		"73e3252852acd5361a563d7f88aef367":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfDefenderEvolvedEffect, [30, 0]))
		"5a6897e20f399a4a0e2403f06a0c3e55":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackChosenDefenderAttackLockNextTurnEffect))
		"15eb5f310fd523c4c468e4519e30ae70":
			processor.register_effect(effect_id, _instantiate_effect(AbilityAttachBasicEnergyFromDiscardToOwnEffect))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"0d7ccbc99ac0f5108c6c7d7d5506f64b":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackFieldEnergyThresholdBonusEffect, [3, 70, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackIgnoreWeaknessEffect, [0]))
		"9a425a2ace730ecdd272b7ea6d0b9db1":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackAncientDiscardCountDamageEffect, [10, 0]))
		"2f6f444122be1e8d9af6c5a134f66572":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillOpponentDeckEffect, [2, 0]))
			var chi_yu_attach := AttackSearchAndAttach.new("R", 3, "deck_search", 0, "bench")
			chi_yu_attach.max_assignments_per_target = 1
			chi_yu_attach.attack_index_to_match = 1
			processor.register_attack_effect(effect_id, chi_yu_attach)
		"a0383c4a4ff14425610be52afedf41ae":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPlaceDamageCountersVSTAREffect, [4]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfDefenderDamagedEffect, [110, 0]))
		"a8f9150f088068e75cc8acf87773691a":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardOpponentToolsEffect, [2, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyFromSelf, [1, 1]))
		"ebbb788ed6a19af88042c8b125d5b8a5":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackAttachBasicEnergyFromHandToOwnPokemonEffect, ["", 1, 0]))
			var chansey_lock := _instantiate_effect(AttackSelfLockNextTurnEffect)
			_bind_attack_index_if_supported(chansey_lock, 1)
			processor.register_attack_effect(effect_id, chansey_lock)
		"03866b81bfc30ea4727f58e792c6dd2a":
			var magnemite_attach := _instantiate_effect(AttackAttachBasicEnergyFromDiscardEffect, ["L", 2, "own_bench"])
			_bind_attack_index_if_supported(magnemite_attach, 0)
			processor.register_attack_effect(effect_id, magnemite_attach)
		"fe8b1bda35af50a16e59e2dcd7cd473f":
			var scyther_attach := AttackAttachBasicEnergyFromDiscard.new("G", 1, "own_bench")
			_bind_attack_index_if_supported(scyther_attach, 0)
			processor.register_attack_effect(effect_id, scyther_attach)
		"1b1e45dbcbf4b21a5af893ad492b7c66":
			processor.register_attack_effect(effect_id, AttackCoinFlipMultiplier.new(30, processor.coin_flipper))
		"0fc11aeb024998d63c530b67f99c8bbb":
			processor.register_attack_effect(effect_id, AttackOpponentAbilityCountDamage.new(50, 0))
		"4e41398ab9262f85910de1d9b3a4f027":
			processor.register_effect(effect_id, AbilityTeamBenchShield.new())
			processor.register_attack_effect(effect_id, AttackOpponentActiveEnergyCountDamage.new(30, 0))
		"936b27cc51f950a455c824375d621421":
			processor.register_effect(effect_id, AbilityFestivalDrumSearch.new())
		"266f2933c7baa1b640d9b55a38c76db4":
			processor.register_attack_effect(effect_id, AttackDefenderActionCostIncreaseNextTurn.new(1, 0))
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(50, 1))
		"95d820ef31a7e8ad71a89fcf8fb85c90":
			processor.register_attack_effect(effect_id, AttackCoinFlipBonusDamage.new(20, 0, processor.coin_flipper))
		"144b6904892dc89e3efb81067c5668c4":
			processor.register_effect(effect_id, AbilityFestivalLead.new())
			processor.register_attack_effect(effect_id, AttackBenchCountDamage.new(20, "self", true))
		"2e5819cd4e1c354b8a9945525c54ec71":
			processor.register_effect(effect_id, _instantiate_effect(EffectCynthiasAmbitionEffect))
		"7580acd5669bac12cb1af8007d2e6a6a":
			processor.register_effect(effect_id, AbilityFestivalLead.new())
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipDiscardOpponentActiveEnergyEffect, [0, processor.coin_flipper]))
		"c2d6b5ec0bc365112105fea079a22fd7":
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(10, 0))
		"f189ac39dca6332f0b3af7b65cea8220":
			processor.register_effect(effect_id, _instantiate_effect(AbilityNoEnergyFreeRetreatEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMoveAttachedEnergyToOwnBenchEffect, [2, "D", 0]))
		"5c0716ee309a1b95a0ae5c534069b0d2", "c52439ea1ed321c25091b60e04c0d1da", "65442467f2645f5983fe6604e5bdc8d2":
			for fx: BaseEffect in Batch3178WorkerCSupportPokemonEffectsScript.create_attack_effects_for_effect_id(effect_id):
				processor.register_attack_effect(effect_id, fx)
		"12b30b5d9a0bd31a8e033bf2f2cfead3":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackRagingBoltLightningStormEffect, [30, 0]))
		"c6083ce0a1d2bda048f3eb948b8abca8":
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("poisoned", false, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBruteBonnetDamageCounterBonusEffect, [50, 1]))
		"f133f2b8d38148794b81a8b4ca135cff":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOpponentFuturePokemonBonusDamageEffect, [120, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyTypeFromSelfEffect, ["", 2, 1]))
		"880338810e1bc9460b1d20044377e08c":
			processor.register_effect(effect_id, _instantiate_effect(AbilityToedscruelSlimeMoldColonyEffect))
			processor.register_attack_effect(effect_id, _instantiate_effect(CSV9CSimpleHealSelfAfterAttackEffect, [30, 0]))
		"7f21a88085207d28e38ca3593994edc2":
			processor.register_effect(effect_id, _instantiate_effect(NoivernExEffectsEffect, [-1, false]))
			processor.register_attack_effect(effect_id, _instantiate_effect(NoivernExEffectsEffect, [0, true]))
			processor.register_attack_effect(effect_id, _instantiate_effect(NoivernExEffectsEffect, [1, true]))
		"f986b356ae9703ac2d1667d1897cfdb6":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfSelfStatusEffect, ["any", 160, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackApplySelfStatusEffect, ["burned", 1]))
		"a5438c6290fdef331fe1ba579b6f4928":
			processor.register_effect(effect_id, _instantiate_effect(AbilityBruteBonnetToxicPowderEffect))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"146a354ca20b3943ab792aa29b070fda":
			processor.register_effect(effect_id, _instantiate_effect(AbilityPoisonDamageBoostEffect))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("poisoned", false, 0))
		"930008a5b5f22ceabca6767aafd93a35":
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("poisoned", false, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCrobatCriticalBiteEffect, [30, 2, 1]))
		"b417ad06ad8e4aa783b35fe1f3f27010":
			processor.register_effect(effect_id, _instantiate_effect(AbilityTachyonBitsEffect))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"c5783c83303269674231483fede75e99":
			processor.register_effect(effect_id, _instantiate_effect(AbilitySearchDeckCardTypeEffect, [2, "Tool", true, true]))
			processor.register_attack_effect(effect_id, AttackOpponentActiveEnergyCountDamage.new(50, 0))
		"f9a90aafccf9445be72a6ed15f66bcd6":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfStatusCountDamageEffect, [100, 100, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAllAttachedEnergyFromSelfEffect, [1]))
		"80861b2bfa9967d1e28a97ee4d1f1316":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackEvolveFromDeck.new(0))
		"3a842d03df3719f7c72c2c0b48d7fd7d":
			processor.register_effect(effect_id, CSV9CEffects.AbilityBenchMillOnPlay.new())
			processor.register_attack_effect(effect_id, AttackPrizeDamageBonus.new(30))
		"7c7665c11f0e9d13ce39ee63c2f2d85c":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackPreventDamageNextTurn.new("basic", 0))
		"e2114e7b76f6dbbe76ce0aaf2a65bc9c":
			processor.register_effect(effect_id, CSV9CEffects.AbilityAttachEnergyFromHandHeal.new("G", 30))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackOwnFieldEnergyCountDamage, ["G", 30, 0]))
		"c155af5a80a873be25372736b49b5829":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackTeraBenchBonusDamage.new(100, 1))
		"ae135beb7f4c42139fc38a4f9203db09":
			processor.register_effect(effect_id, CSV9CEffects.AbilityFireEvolutionBoost.new(10))
		"a533d02d029bd799e8c425beecd3ffaa":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackDiscardPileEnergyBonus.new(20, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAllAttachedEnergyFromSelfEffect, [1]))
		"4b31ce3c692a0129980d3866878faeb5":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfDamageCounterMultiplierEffect, [10]))
		"88b2885578a73494f1eed7c2b53e67c7":
			processor.register_effect(effect_id, CSV9CEffects.AbilityPreventOpponentReturnToHand.new())
		"f518a7e573241c14cc225cc14d6094d3":
			processor.register_effect(effect_id, CSV9CEffects.AbilityBenchDiscardStadiumOnPlay.new())
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackReturnEnergyToHand.new(0))
		"cd845155473716c29f29efa29da0a869":
			processor.register_effect(effect_id, CSV9CEffects.AbilitySurviveAtFullHP.new())
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyFromSelf, [3, 0]))
		"76ce94424f53e8a93cfb2c2008a84a86":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackJoltikCharge.new(0))
		"cfe54f4650db054ec2eec6dfcaaff88a":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackRuleBoxBonusDamage.new(110, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAllAttachedEnergyFromSelfEffect, [1]))
			var galvantula_lock := _instantiate_effect(AttackItemLockNextTurnEffect)
			_bind_attack_index_if_supported(galvantula_lock, 1)
			processor.register_attack_effect(effect_id, galvantula_lock)
		"ccc3bb652f886672fac7b4b0561492d9":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackRecoverPokemonFromDiscard.new(1, 0))
		"79cbb7699c0e663c135524afe4e1cb14":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackSlowkingInspiration.new(0, processor))
		"74fd967591e71b608b8437f28cdee910":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackHealSelf.new(30, 0))
		"019d762a760de48f1bb05528db2766f3":
			processor.register_effect(effect_id, CSV9CEffects.AbilityTogekissExtraPrize.new(processor.coin_flipper))
		"f8c2715403e3f4ea9783c46be2de832b":
			processor.register_effect(effect_id, CSV9CEffects.AbilityBasicFreeRetreat.new())
			var latias_lock := _instantiate_effect(AttackSelfLockNextTurnEffect)
			_bind_attack_index_if_supported(latias_lock, 0)
			processor.register_attack_effect(effect_id, latias_lock)
		"317cdd81106733967d562ad538a7983a":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackReduceDefenderOutgoingDamage.new(100, 0))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackReturnOpponentBenchToDeck.new(2, 1))
		"6c6c611ae3397c524ea28fec85c1f8b8":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackSearchBasicEnergyToHand.new(2, 0))
		"20655f99bed441a33a259b16b9935355":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackFixedCoinFlipDamageEffect, [2, 10, 10, 0, processor.coin_flipper]))
		"5f360b6881fbb857e809ca402ffdfda4":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipDiscardOpponentActiveEnergyEffect, [0, processor.coin_flipper]))
		"668cdee516a1fb4a2ab83835eaf1e035":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackApplySelfStatusEffect, ["confused", 0]))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackBothActiveKnockout.new(1))
		"0d1257d702d294733db17470d04e546c":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackOpponentFieldSpecialEnergyDamage.new(40, 0))
		"41dd160743c1707676c4faa6759c718b":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackPreviousAncientBonus.new(150, 0))
		"66e063ab0666db09ce429dc6974b8df8":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillOpponentDeckEffect, [1, 0]))
		"1bf2a3fb6a8f4abebdb7a88992026b7d":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillOpponentDeckEffect, [2, 0]))
		"fa9e235782bba9bdb62005106bbdd6d9":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackMillOpponentDeckEffect, [3, 0]))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackBenchMultiDamage.new(130, 2, 1))
		"277e3fdeae03359715f5b1432e00619c":
			processor.register_effect(effect_id, CSV9CEffects.AbilityPoisonDamageBoostActive.new(50))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackPoisonAndRetreatLock.new(0))
		"571a7dd294812109ab0bf179ecf863eb":
			processor.register_effect(effect_id, CSV9CEffects.AbilityBlockAceSpecIfTooled.new())
		"4a142a526975994a83d3accdc12058a0":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackDiscardAttachedEnergyFromSelf, [2, 1]))
		"ecce5b1818ae13630c3a09449489c424":
			processor.register_effect(effect_id, CSV9CEffects.AbilityEvolveAttachMetalFromDiscard.new())
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackNoWeaknessNextTurn.new(0))
		"d6337e0ceed2bf39c2559bec1b517aec":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackGholdengoEvolvedBonus.new(90, 0))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackReturnSelfToDeck.new(1))
		"0f9c649bb3f59a7a342b53cdc78952a4":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackHandBasicEnergyAttach.new(0))
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackBasicPokemonKnockoutCoin.new(1, processor.coin_flipper))
		"5ed7ff97aa96afb6a023ad8ce6636eba":
			processor.register_effect(effect_id, CSV9CEffects.AbilityKyuremCostReduction.new())
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackTriFrost.new(110, 3, 0))
		"950970c1b38c30b33bbb5aa5c3353b48":
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackHealOwnPokemon.new(30, 0))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackCoinFlipBonusDamageEffect, [30, 1, processor.coin_flipper]))
		"f37aecbe63a1039fb481286c9b6fcc3c":
			processor.register_effect(effect_id, CSV9CEffects.AbilityEeveeEarlyEvolution.new())
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(10, 0))
		"62bbe4c45b6f0406104dc382a620e017":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfDamageCounterBonusEffect, [10, 1]))
		"afe6e5fb7931c8c529e43134ef264885":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackSelfDamageCounterMultiplierEffect, [20, 0]))
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfDefenderEvolvedDiscardAllEnergyFromSelfEffect, [140, 1]))
		"efa5883e7d648ebc984f161b2c7d8fe9":
			processor.register_effect(effect_id, _instantiate_effect(AbilityEeveeExRainbowFactorEffect))
		"d5ab8efe3bcad6f39e9a434ae6d8de7a":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackBonusIfOpponentActiveTeraEffect, [230, 0]))
		"d3782c7410166c2c7c00b54886241e7b":
			processor.register_attack_effect(effect_id, _instantiate_effect(AttackFixedCoinFlipDamageEffect, [3, 10, 10, 0, processor.coin_flipper]))
		"f9c6499bbad853ebcb1ca8e3364fc677":
			processor.register_effect(effect_id, CSV9CEffects.AbilityNoctowlTeraTrainerSearch.new())
		"617649459c3795af10c38e477e35ba73":
			processor.register_effect(effect_id, CSV9CEffects.AbilityFanCall.new())
			processor.register_attack_effect(effect_id, CSV9CEffects.AttackStadiumRequired.new(70, 0))
		"06ff860de906282c96487b440ecfd05e":
			processor.register_effect(effect_id, CSV9CEffects.AbilityBouffalantDefense.new())
			var bouffalant_lock := _instantiate_effect(AttackSelfLockNextTurnEffect)
			_bind_attack_index_if_supported(bouffalant_lock, 0)
			processor.register_attack_effect(effect_id, bouffalant_lock)
		"1e48ba6c2140461745fc407bf34f5598":
			var terapagos_unified_beat := AttackBenchCountDamage.new(30, "self", true)
			_bind_attack_index_if_supported(terapagos_unified_beat, 0)
			processor.register_attack_effect(effect_id, terapagos_unified_beat)
			var terapagos_crown_opal := CSV9CEffects.AttackPreventDamageNextTurn.new("basic_non_colorless", 1)
			_bind_attack_index_if_supported(terapagos_crown_opal, 1)
			processor.register_attack_effect(effect_id, terapagos_crown_opal)


## ==================== 物品卡注册（register_effect）====================

static func _register_items(processor: EffectProcessor) -> void:
	# 反击捕捉器
	processor.register_effect("06bc00d5dcec33898dc6db2e4c4d10ec", EffectCounterCatcher.new())
	# 巢穴球
	processor.register_effect("1af63a7e2cb7a79215474ad8db8fd8fd", EffectNestBall.new())
	# 清除古龙水
	processor.register_effect("66b2f1d77328b6578b1bf0d58d98f66b", EffectCancelCologne.new())
	# 放逐吸尘器
	processor.register_effect("8f655fea1f90164bfbccb7a95c223e17", EffectLostVacuum.new())
	# 高级球
	processor.register_effect("a337ed34a45e63c6d21d98c3d8e0cb6e", EffectUltraBall.new())
	# 朋友手册
	processor.register_effect("a47d5a8ed00e14a2146fc511745d23b5", EffectPalPad.new())
	processor.register_effect("15b5bf0cc2edae9b9cd0bc24389ad355", _instantiate_effect(EffectMirageGateEffect))
	# 厉害钓竿
	processor.register_effect("c9c948169525fbb3dce70c477ec7a90a", EffectSuperRod.new())
	# 神奇糖果
	processor.register_effect("d3891abcfe3277c8811cde06741d3236", EffectRareCandy.new())
	# 友好宝芬
	processor.register_effect("f866dfee26cd6b0dbbb52b74438d0a59", EffectBuddyPoffin.new())
	# 宝可装置3.0：查看顶部7张，选1张支援者加入手牌
	processor.register_effect("768b545a38fccd5e265093b5adce10af", EffectLookTopCards.new(7, "Supporter"))
	# 超级球：查看顶部7张，选1张宝可梦加入手牌
	processor.register_effect("1838e8afe529b519a57dd8bbd307905a", EffectLookTopCards.new(7, "Pokemon"))
	# 捕获香氛
	processor.register_effect("7cd68d9e286b78a7f9c799fce24a7d6c", EffectCapturingAroma.new(processor.coin_flipper))
	# 宝可梦交替：切换己方战斗宝可梦
	processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", EffectSwitchPokemon.new("self"))
	# Escape Rope
	processor.register_effect("c6bc96f30e19315b2e59451b3f9b92cd", EffectSwitchPokemon.new("both"))
	# 顶尖捕捉器
	processor.register_effect("4ec261453212280d0eb03ed8254ca97f", EffectPrimeCatcher.new())
	processor.register_effect("c1acc32f6333793f261c9c132435fdfa", _instantiate_effect(EffectScoopUpCycloneEffect))
	# 大师球：搜索牌库任意1只宝可梦
	processor.register_effect("30e7c440d69817592656f5b44e444111", EffectSearchDeck.new(1, 0, "Pokemon"))
	processor.register_effect("ee2e1cc534d39f1710b1c590bf585ae5", _instantiate_effect(EffectLoveBallEffect))
	# 电气发生器
	processor.register_effect("2234845fbc2e11ab95587e1b393bb318", EffectElectricGenerator.new())
	# 高科技雷达
	processor.register_effect("8b0d4f541f256d67f0757efe4fc8b407", EffectTechnoRadar.new())
	# 交替推车
	processor.register_effect("8342fe3eeec6f897f3271be1aa26a412", EffectSwitchCart.new())
	# Hisuian Heavy Ball
	processor.register_effect("2f68195255c863293be4fad262bf23d2", _instantiate_effect(EffectHisuianHeavyBallEffect))
	# Feather Ball
	processor.register_effect("b029fdcf35f970d5d2254778009fa2fe", _instantiate_effect(EffectFeatherBallEffect))
	# Superior Energy Retrieval
	processor.register_effect("ff7e5670880217816bcf5d34388624cd", _instantiate_effect(EffectRecoverBasicEnergyEffect, [4, 2]))
	# Earthen Vessel
	processor.register_effect("e366f56ecd3f805a28294109a1a37453", _instantiate_effect(EffectSearchBasicEnergyEffect, [2, 1]))
	# Energy Retrieval
	processor.register_effect("8538726d6cdfad2fa3ca5f4b462c12c5", _instantiate_effect(EffectRecoverBasicEnergyEffect, [2, 0]))
	# Trekking Shoes
	processor.register_effect("70d14b4a5a9c15581b8a0c8dfd325717", _instantiate_effect(EffectTrekkingShoesEffect))
	# TM: Devolution
	processor.register_effect("e228e825c541ce80e2507c557cb506c3", _instantiate_effect(EffectTMDevolutionEffect))
	# 秘密箱
	processor.register_effect("e92a86246f44351d023bd4fa271089aa", _instantiate_effect(EffectSecretBoxEffect))
	# Unfair Stamp
	processor.register_effect("d324e01179ab048ed023bf4a20bf658d", _instantiate_effect(EffectUnfairStampEffect))
	# Night Stretcher
	processor.register_effect("3e6f1daf545dfed48d0588dd50792a2e", _instantiate_effect(EffectNightStretcherEffect))
	# Max Rod
	processor.register_effect("6a7fe7ec3f22c435f50b49909e85b3d3", EffectLanasAid.new(5, true))
	# Pokemon Catcher
	processor.register_effect("3a6d419769778b40091e69fbd76737ec", _instantiate_effect(EffectPokemonCatcherEffect, [processor.coin_flipper]))
	# Energy Switch
	processor.register_effect("294212d9c02dc0acb886a7ef01ebeac4", _instantiate_effect(EffectEnergySwitchEffect))
	# Dark Patch
	processor.register_effect("11ca8ef52edb2599280e7d5827e9dfb1", _instantiate_effect(EffectDarkPatchEffect))
	# Energy Sticker
	processor.register_effect("2b717e54cc20a24a70439066c4a24968", _instantiate_effect(EffectEnergyStickerEffect, [processor.coin_flipper]))
	# Energy Search
	processor.register_effect("e508908b9311c0ef5e70e9de44892e26", _instantiate_effect(EffectSearchBasicEnergyEffect, [1, 0]))
	# Picnic Basket
	processor.register_effect("276cc8e3fd9a7b7c18f5da7715fe8460", _instantiate_effect(EffectHealAllPokemonEffect, [30]))
	# Mirage Gate
	processor.register_effect("15b5bf0cc2edae9b9cd0bc24389ad355", _instantiate_effect(EffectMirageGateEffect))
	# 高级香氛
	processor.register_effect("e8942749749a9d0069b3b47562ddb415", _instantiate_effect(EffectHyperAromaEffect))
	# 能量签：查看顶部7张，选1张能量加入手牌
	processor.register_effect("543fc44ba3b2509b7165d86fc83cd14f", EffectLookTopCards.new(7, "Energy"))
	processor.register_effect("adf4d1157e58b1421d1b6d0871b2fc88", EffectBugCatchingSet.new())
	# 粉碎之锤：投币正面弃对手1个能量
	processor.register_effect("77a259dbcc81481b6d06e3fc18f29c3c", _instantiate_effect(EffectCrushingHammerEffect, [processor.coin_flipper]))
	processor.register_effect("a13ba21d54c2f0e8ea4f7d5b2ca37380", _instantiate_effect(EffectLookBottomCardsEffect, [7, "Pokemon", 1]))
	processor.register_effect("23ee27488d0c1317557a3106a1fc7db3", _instantiate_effect(EffectEnhancedHammerEffect))
	processor.register_effect("5ad6b7f0c1b9da35cd0d284de31b65a3", _instantiate_effect(EffectLetterOfEncouragementEffect))
	processor.register_effect("9c90d75a1cb539e68db4c94e8552884a", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C176EnergySearchPro.gd"))
	processor.register_effect("e8db81c59ba75ebb6ecf44f7b8519f74", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C178GlassTrumpet.gd"))
	processor.register_effect("1da701b43813d6ddb1238e54bce95811", _instantiate_effect(EffectScrambleSwitchEffect))
	processor.register_effect("dab635fb86bde2441e38ef00f4b91907", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C181TeraOrb.gd"))
	processor.register_effect("0cfbd28757df8b81a553cf65e3149b1e", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C183PerfectMixer.gd"))
	processor.register_effect("28f142be07616ba497b1afd206477963", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C186PreciousTrolley.gd"))


## ==================== 支援者卡注册（register_effect）====================

static func _register_supporters(processor: EffectProcessor) -> void:
	# 派帕
	processor.register_effect("5bdbc985f9aa2e6f248b53f6f35d1d37", EffectArven.new())
	# 弗图博士的剧本
	processor.register_effect("73d5f46ecf3a6d71b23ce7bc1a28d4f4", EffectProfTuro.new())
	# 老大的指令
	processor.register_effect("8e1fa2c9018db938084c94c7c970d419", EffectBossOrders.new())
	# 奇树
	processor.register_effect("af514f82d182aeae5327b2c360df703d", EffectIono.new())
	processor.register_effect("8be6a0e0835e0caba9acb7bf8e9c9ce0", _instantiate_effect(EffectCherensCareEffect))
	# 博士的研究：弃掉手牌，摸7张
	processor.register_effect("aecd80ca2722885c3d062a2255346f3e", EffectDrawCards.new(7, true))
	# 裁判：双方将手牌洗入牌库，各摸4张
	processor.register_effect("0a9bdf265647461dd5c6c827ffc19e61", EffectShuffleDrawCards.new(4, false, true))
	# 暗码迷的解读
	processor.register_effect("1b5fc2ed2bce98ef93457881c05354e2", EffectCiphermaniac.new())
	# 捩木
	processor.register_effect("05b9dc8ee5c16c46da20f47a04907856", EffectThorton.new())
	# 莎莉娜
	processor.register_effect("d83b170c43c0ade1f81c817c4488d5db", EffectSerena.new())
	# 吉尼亚
	processor.register_effect("a8a2b27c2641d8d7212fc887ca032e4c", EffectJacq.new())
	# 珠贝
	processor.register_effect("4f53ab6bf158fd1a8869ae037f4a0d6d", EffectIrida.new())
	# Roxanne
	processor.register_effect("889c893f76d8be0261cd53daad5e3c11", _instantiate_effect(EffectRoxanneEffect))
	# Lance
	processor.register_effect("2df65fcd5de0d9d9e24486b059981cdf", _instantiate_effect(EffectLanceEffect))
	# Cyllene
	processor.register_effect("e5c317e428f0cfd885b53d4d058b5d5b", _instantiate_effect(EffectCylleneEffect))
	# Mela
	processor.register_effect("f9162d9c9d98c74523257f17dcb6053b", _instantiate_effect(EffectMelaEffect))
	# Professor Sada's Vitality
	processor.register_effect("651276c51911345aa091c1c7b87f3f4f", _instantiate_effect(EffectSadasVitalityEffect))
	# Carmine
	processor.register_effect("8150af4062192998497e376ad931bea4", _instantiate_effect(EffectCarmineEffect))
	# Colress's Experiment
	processor.register_effect("9c6f696e9eb8f0c53b5f1057141a1227", _instantiate_effect(EffectColressExperimentEffect))
	# 赛吉
	processor.register_effect("08c2507538f1574c5ceda18017ab5031", _instantiate_effect(EffectSalvatoreEffect))
	# 枇琶：查看对手手牌，弃最多2张物品
	processor.register_effect("aaf64ab87ad571cdf40cc78538c9c0b4", _instantiate_effect(EffectEriEffect))
	# 牡丹：选择己方1只基础宝可梦放回手牌
	processor.register_effect("9fb5f53c9952d10b4fe26508ecbc644a", _instantiate_effect(EffectPennyEffect))
	# 阿克罗玛的执念：搜索竞技场和能量各1张
	processor.register_effect("f7415384905a382f6f8ffe95dca595cb", _instantiate_effect(EffectColressTenacityEffect))
	processor.register_effect("0176c179359368cdb84ff754e0bbd701", _instantiate_effect(EffectErikasInvitation))
	processor.register_effect("15f9d5ea244ceaa819ecafc18644be17", _instantiate_effect(EffectXerosicsMachinations))
	processor.register_effect("69c6f343fad1310d0008894c15bd6388", _instantiate_effect(EffectGiacomo))
	processor.register_effect("b8e6d6a0e1cd50214902a5cbf7b6b7c4", _instantiate_effect(EffectMissFortuneSisters))
	processor.register_effect("050b081d65e7c3ccff3eed61107e17a5", _instantiate_effect(EffectJaninesSecretArtEffect))
	processor.register_effect("c982e26b140aa1c9230fb1018b62ef1e", _instantiate_effect(EffectTeamYellsCheer))
	processor.register_effect("d4a94445aa981c2f84e4df9b0525eeb0", _instantiate_effect(EffectKieranEffect))
	processor.register_effect("1b9696068a599e81c705bcb3648f0213", _instantiate_effect(EffectRoseannesBackupEffect))
	processor.register_effect("b79ddb9a6aab6d346f6a1f71b7fcd3de", EffectLanasAid.new())
	processor.register_effect("60efb96839df10bb78737047da1c4fb1", _instantiate_effect("res://scripts/effects/trainer_effects/CSV95C182AokisSkill.gd"))
	# Arezu
	processor.register_effect("c29db727ed3ad15978addfc5d8ed6451", _instantiate_effect(EffectArezuEffect))
	processor.register_effect("2e5819cd4e1c354b8a9945525c54ec71", _instantiate_effect(EffectCynthiasAmbitionEffect))
	processor.register_effect("0f4743343a173fdba38290050453a8c8", _instantiate_effect(EffectExplorersGuidanceEffect))
	processor.register_effect("136fdb6578daa3b81aef369495de4c3d", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C196Crispin.gd"))
	processor.register_effect("7b6a53e0356c50456b949d1c7104663e", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C198Cilan.gd"))
	processor.register_effect("6113c0cc8ab0b7afd2f49a6fc7f7bc3a", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C202Briar.gd"))
	processor.register_effect("c74d2a9679b8cd5fce900169385c035c", _instantiate_effect("res://scripts/effects/trainer_effects/CSV9C204LuciansAppeal.gd"))
	processor.register_effect("a444b83881df9e2a0225aee95bbc853a", _instantiate_effect(EffectBlackBeltsTrainingEffect))


## ==================== 道具卡注册（register_effect）====================

static func _register_tools(processor: EffectProcessor) -> void:
	processor.register_effect("0ad0108e5ab1346d88f6ce11b75028d7", _instantiate_effect(EffectSupereffectiveGlassesEffect))
	processor.register_effect("8da8631aa1827b122ec65b712939ad48", _instantiate_effect(EffectToolAncientBoosterEnergyCapsuleEffect))
	# 极限腰带：对ex伤害+50
	processor.register_effect("2e07a9870350b611a3d21ab2053dfa2a", EffectToolConditionalDamage.new(50, "ex"))
	# 森林封印石（VSTAR特技：搜索牌库任意2张卡）
	processor.register_effect("9fa9943ccda36f417ac3cb675177c216", AbilityVSTARSearch.new())
	# 不服输头带：对奖励牌数多的对手伤害+30
	processor.register_effect("e242d711feffd98f3fbb5c511d00d667", EffectToolConditionalDamage.new(30, "prize_behind"))
	# 讲究腰带：对V宝可梦伤害+30
	processor.register_effect("36939b241f51e497487feb52e0ea8994", EffectToolConditionalDamage.new(30, "V"))
	processor.register_effect("a77ef1e9df5b37e1d529682b2b38a4b8", EffectToolConditionalDamage.new(40, "poisoned_self"))
	# 勇气护符：HP+50，不禁用特性
	processor.register_effect("d1c2f018a644e662f2b6895fdfc29281", EffectToolHPModifier.new(50, false, true))
	# 驱劲能量 未来（道具：给未来宝可梦的招式增益）
	processor.register_effect("54920a273edba38ce45f3bc8f6e8ff25", EffectToolFutureBoost.new())
	# 沉重接力棒
	processor.register_effect("770c741043025f241dbd81422cb8987d", EffectToolHeavyBaton.new())
	# 紧急滑板
	processor.register_effect("0b4cc131a19862f92acf71494f29a0ed", EffectToolRescueBoard.new())
	# Sparkling Crystal
	processor.register_effect("12164ed03296d2df4ef6d0fa8b5f8aae", _instantiate_effect(EffectSparklingCrystalEffect))
	processor.register_effect("cd9192e99ba06596352434d53223514f", EffectToolHPModifier.new(100))
	# 招式学习器 进化
	processor.register_effect("43386015be5c073ba2e5b9d3692ece3f", _instantiate_effect(AttackTMEvolutionEffect, [2]))
	processor.register_effect("2614722b9b28d9df8fd769b926ec82f2", _instantiate_effect(EffectTMTurboEnergizeEffect))
	processor.register_effect("23fe3b6aa9af9b5c4b5639cbc1b80076", _instantiate_effect(EffectTMCrisisPunchEffect))
	# 学习装置
	processor.register_effect("40d67cc66ad153ee1d54c6213c50b4a1", _instantiate_effect(EffectExpShareEffect))
	processor.register_effect("1bc2bed91258ca0ecfb69e5ee8dc0c79", _instantiate_effect(EffectHandheldFan))
	processor.register_effect("e9bd0b4b3d97716a9757e6bccb1446ac", _instantiate_effect(EffectAccompanyingFlute))
	processor.register_effect("56a847e3573ccf9a991205169463218f", _instantiate_effect(EffectEmergencyJellyEffect))
	processor.register_effect("1dc38c46be0951b2b135e1df2e5e7767", _instantiate_effect(EffectPowerglassEffect))
	processor.register_effect("f474805425d4849d8dc4c8c1e1af750a", EffectToolDamageModifier.new(10, "attack"))
	processor.register_effect("3f2231d269066792b860d31b568aaf2a", _instantiate_effect(EffectLuxuriousCapeEffect))
	processor.register_effect("8661d78f9695838cee64d65fb73ddf58", _instantiate_effect(EffectDefianceVestEffect))
	processor.register_effect("6ec876cf4467166edf6e90fa1cc321eb", _instantiate_effect(EffectRigidBandEffect))
	processor.register_effect("1201698f44df09377c26288931d18b36", _instantiate_effect(EffectSurvivalBraceEffect))
	processor.register_effect("23ca13a02f05aed58a4c86c2390bf6de", _instantiate_effect("res://scripts/effects/tool_effects/CSV9C190CounterGain.gd"))


## ==================== 竞技场卡注册（register_effect）====================

static func _register_stadiums(processor: EffectProcessor) -> void:
	processor.register_effect("16a6fb86a8ebd1cffc6f171250057d5c", _instantiate_effect(EffectPerilousJungleEffect))
	# 崩塌的竞技场
	processor.register_effect("fb3628071280487676f79281696ffbd9", EffectCollapsedStadium.new())
	# 放逐市
	processor.register_effect("7f4e493ec0d852a5bb31c02bdbdb2c4e", EffectLostCity.new())
	# 城镇百货
	processor.register_effect("13b3caaa408a85dfd1e2a5ad797e8b8a", EffectTownStore.new())
	# Full Metal Lab
	processor.register_effect("59e1e1faa3ceb8c3ae801979a499532e", EffectStadiumDamageModifier.new(-30, "defense", "M"))
	# Magma Basin
	processor.register_effect("d781c9da21b24ff7a1453150a534c9df", _instantiate_effect(EffectMagmaBasinEffect))
	# Cycling Road
	processor.register_effect("79292d4ceeac1081fe39c155c677c7b3", _instantiate_effect(EffectCyclingRoadEffect))
	# Temple of Sinnoh
	processor.register_effect("53864b068a4a1e8dce3c53c884b67efa", _instantiate_effect(EffectTempleOfSinnohEffect))
	# Gravity Mountain
	processor.register_effect("aee486132c2ba880232a477fe0fe7a03", _instantiate_effect(EffectGravityMountainEffect))
	# Jamming Tower
	processor.register_effect("4e16157bfa88a41e823d058a732df8e0", _instantiate_effect(EffectJammingTowerEffect))
	# 深钵镇
	processor.register_effect("c117bea3cc758d46430d6bef11062a56", _instantiate_effect(EffectArtazonEffect))
	# 宝可梦联盟总部
	processor.register_effect("b87089abe625a7abb3c523074a8497df", _instantiate_effect(EffectLeagueHQEffect))
	processor.register_effect("ed39476ac2c269054525ab0b0f79d58c", _instantiate_effect("res://scripts/effects/stadium_effects/EffectMesagoza.gd", [processor.coin_flipper]))
	processor.register_effect("2027b11b9630f8c24d2fdf19130a7111", _instantiate_effect(EffectMoonlitHillEffect))
	processor.register_effect("8784f5412bf62ce1356d2480df0b139b", _instantiate_effect(EffectGapejawBogEffect))
	processor.register_effect("357d55b54ded5db071b55ebe165749fc", EffectFestivalGrounds.new())
	processor.register_effect("b599512657c5c23024fde7875db3ba2d", _instantiate_effect(EffectCalamitousWastelandEffect))
	# Academy at Night
	processor.register_effect("e75fad9484071647f96e9f41beeb4a99", _instantiate_effect(EffectAcademyAtNightEffect))
	processor.register_effect("9ac00d455f68b3217d0a64938081a5fe", _instantiate_effect("res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd"))
	processor.register_effect("528f7e92b624e35bb42828e372c45252", _instantiate_effect("res://scripts/effects/stadium_effects/CSV9C206VibrantPalace.gd"))
	processor.register_effect("701eb0ccb34fe3d319ea1307bc36c1ef", _instantiate_effect("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd"))


## ==================== 特殊能量注册（register_effect）====================

static func _register_special_energies(processor: EffectProcessor) -> void:
	# 双重涡轮能量：提供2个无色能量，伤害-20
	processor.register_effect("9c04dd0addf56a7b2c88476bc8e45c0e", EffectSpecialEnergyModifier.new(-20, 0, "C", 2))
	# 喷射能量
	processor.register_effect("1323733f19cc04e54090b39bc1a393b8", EffectJetEnergy.new())
	# 治疗能量
	processor.register_effect("2c65697c2aceac4e6a1f85f810fa386f", EffectTherapeuticEnergy.new())
	# V防守能量
	processor.register_effect("88bf9902f1d769a667bbd3939fc757de", EffectVGuardEnergy.new())
	# 馈赠能量
	processor.register_effect("dbb3f3d2ef2f3372bc8b21336e6c9bc6", EffectGiftEnergy.new())
	processor.register_effect("cbadb3473273c14cf667d495d44d111b", _instantiate_effect(EffectReversalEnergyEffect))
	# 薄雾能量
	processor.register_effect("fb0948c721db1f31767aa6cf0c2ea692", EffectMistEnergy.new())
	# Legacy Energy
	processor.register_effect("6f31b7241a181631016466e561f148f3", _instantiate_effect(EffectLegacyEnergyEffect))
	# 夜光能量
	processor.register_effect("540ee48bb93584e4bfe3d7f5d0ee0efc", _instantiate_effect(EffectLuminousEnergyEffect))
	processor.register_effect("3b16e8f85f3165586cb0170232a80f1f", _instantiate_effect("res://scripts/effects/energy_effects/CSV9C208RichEnergy.gd"))
	processor.register_effect("83aba7d0c92c81e8c03b3785af695c2f", _instantiate_effect(EffectNeoUpperEnergyEffect))


## ==================== 特性名称 → 效果实例映射 ====================

## 根据特性名称返回对应的效果实例，未知特性返回 null
static func _get_ability_effect(ability_name: String) -> BaseEffect:
	match ability_name:
		"浪花水帘":
			return AbilityBenchProtect.new()
		"再起动":
			return AbilityDrawToN.new(3)
		"勤奋门牙":
			return AbilityDrawToN.new(5)
		"音速搜索":
			return AbilitySearchAny.new(1, true, false, "ability_search_any_quick_search")
		"星耀诞生":
			# VSTAR 特技：搜索牌库最多2张任意卡
			return AbilitySearchAny.new(2, true, true)
		"烈炎支配":
			# 进化时可从牌库附加最多3个火能量
			return _instantiate_effect(AbilityAttachFromDeckEffect, ["R", 3, "own", true, false])
		"原始涡轮":
			# 每回合一次：从牌库附加1张特殊能量
			return _instantiate_effect(AbilityAttachFromDeckEffect, ["Special Energy", 2, "own_one", false, true])
		"夜光信号":
			# 进入备战区时：搜索支援者卡加入手牌
			return AbilityOnBenchEnter.new("search_supporter")
		"快速游标":
			# 进入备战区时：切换己方战斗宝可梦
			return AbilityOnBenchEnter.new("rush_in")
		"快速充电":
			# 回合结束时摸3张
			return AbilityEndTurnDraw.new(3)
		"隐藏牌":
			# 丢弃手牌换取摸牌
			return AbilityDiscardDraw.new()
		"战栗冷气":
			return _instantiate_effect(AbilitySearchBasicWaterEnergyActiveEffect, [2])
		"极低温":
			return _instantiate_effect(AbilityAttachBasicWaterEnergyFromHandEffect)
		"英武重抽":
			# 先手第一回合额外摸牌
			return AbilityFirstTurnDraw.new()
		"巢穴藏身":
			# 将手牌洗入牌库后摸牌
			return AbilityShuffleHandDraw.new()
		"串联装置":
			# 搜索最多2只闪电系基础宝可梦放到备战区
			return AbilitySearchPokemonToBench.new("L", 2)
		"金属制造者":
			return AbilityMetalMaker.new()
		"星耀汇聚":
			# VSTAR 特技：特殊召唤
			return AbilityVSTARSummon.new()
		"毫不在意":
			# 备战区宝可梦免疫对方效果
			return AbilityBenchImmune.new()
		"闪焰之幕":
			# 忽略对方效果
			return AbilityIgnoreEffects.new()
		"无畏脂肪":
			# 忽略对方效果
			return AbilityIgnoreEffects.new()
		"挡道":
			return _instantiate_effect(AbilityActiveRetreatLock)
		"神秘守护":
			return _instantiate_effect(AbilityPreventDamageFromExOrV)
		"消失之翼":
			return _instantiate_effect(AbilityBenchShuffleIntoDeck)
		"强力吹风机":
			# 将对方备战区宝可梦调至战斗位
			return AbilityGustFromBench.new()
		"蔚蓝指令":
			# 未来宝可梦伤害提升
			return AbilityFutureDamageBoost.new()
		"暗夜振翼":
			# 禁用对方特性
			return AbilityDisableOpponentAbility.new()
		"电气象征":
			# 闪电属性伤害加成
			return AbilityLightningBoost.new()
		"慈爱帘幕":
			# 降低V宝可梦受到的伤害
			return AbilityVReduceDamage.new()
		"振奋之心":
			# 减少与对手已获得奖赏卡张数相同数量的无色能量
			return _instantiate_effect(AbilityPrizeCountColorlessReductionEffect)
		"金属之盾":
			# 满足条件时减伤
			return AbilityConditionalDefense.new()
		"瞬步":
			# 迅雷充电
			return AbilityThunderousCharge.new()
		"精炼":
			# 奇鲁莉安：弃1张任意手牌，抽2张
			return _instantiate_effect(AbilityDiscardDrawAnyEffect, [2])
		"精神拥抱":
			# 沙奈朵ex：从弃牌区附着超能量+放置2个伤害指示物
			return _instantiate_effect(AbilityPsychicEmbraceEffect)
		"亢奋脑力":
			# 愿增猿：转移己方宝可梦伤害指示物到对手
			return _instantiate_effect(AbilityMoveDamageCountersToOpponentEffect, [3])
		"恶作剧之锁":
			# 钥圈儿：双方基础宝可梦特性无效化
			return _instantiate_effect(AbilityBasicLockEffect)
		"初始化":
			# 铁荆棘ex：压制规则宝可梦（非未来）特性
			return AbilityIronThornsInit.new()
		"变身启动":
			# 百变怪：第一回合从牌库选基础宝可梦替换自身
			return AbilityDittoTransform.new()
		"过量放电":
			return _instantiate_effect(AbilityOvervoltDischargeEffect)
		_:
			return null


## ==================== 招式名称 → 效果实例列表映射 ====================

## 根据招式名称返回对应的效果实例数组（可能包含多个效果）
## 返回空数组表示该招式无附加效果
static func _get_attack_effects(processor: EffectProcessor, attack_name: String) -> Array:
	match attack_name:
		"三重蓄能":
			# 从牌库搜索3张能量附加到V宝可梦
			return [AttackSearchAndAttach.new("", 3, "deck_search", 0, "v_only")]
		"快速充能":
			# 从牌库搜索1张雷能量附着给自己
			return [_instantiate_effect(AttackSearchEnergyFromDeckToSelfEffect, ["L", 1])]
		"巅峰加速":
			# 从牌库选择最多2张基本能量附着于自己的未来宝可梦
			return [AttackSearchAndAttach.new("", 2, "deck_search", 0, "any", CardData.FUTURE_TAG)]
		"基因侵入":
			# 复制对方的招式
			return [AttackCopyAttack.new(processor)]
		"废品短路":
			return [AttackScrapShort.new(40)]
		"燃烧黑暗":
			# 喷火龙ex：基础180，按对手已拿走的奖赏卡数额外+30/张
			return [AttackPrizeCountDamage.new(30)]
		"炎爆":
			# 光辉喷火龙：下回合无法使用此招式
			return [AttackSelfLockNextTurn.new()]
		"棱镜利刃":
			# 下回合无法使用此招式
			return [AttackSelfLockNextTurn.new()]
		"光子引爆":
			# 下回合无法使用此招式
			return [AttackSelfLockNextTurn.new()]
		"轰隆鼾声":
			# 使用后自身进入睡眠状态
			return [AttackSelfSleep.new()]
		"瘫倒":
			return [AttackSelfSleep.new()]
		"乘风飞翔":
			return [_instantiate_effect(AttackBonusIfOwnStadium, [80])]
		"幽灵之眼":
			return [_instantiate_effect(AttackPlaceDamageCountersOnOpponentActive, [70])]
		"搬运上岸":
			return [_instantiate_effect(AttackReviveBasicFromAnyDiscardToBench)]
		"呼朋引伴":
			# 从牌库搜索最多2只基础宝可梦放到备战区
			return [AttackCallForFamily.new(2)]
		"水流回转":
			# 攻击后返回牌库
			return [AttackReturnToDeck.new()]
		"强劲电光":
			# 弃任意数量雷能量，每张60伤害
			return [_instantiate_effect(AttackDiscardEnergyMultiDamageEffect, ["L", 60])]
		"雷电回旋曲":
			# 双方备战区每只宝可梦+20伤害
			return [AttackBenchCountDamage.new(20, "both")]
		"多谢款待":
			# 额外获取1张奖励牌
			return [AttackExtraPrize.new(1)]
		"放逐冲击":
			# 将自身场上2个能量放入放逐区
			return [AttackLostZoneEnergy.new(2, true, true)]
		"星耀安魂曲":
			# VSTAR 特技：放逐区KO效果
			return [AttackLostZoneKO.new()]
		"星耀时刻":
			# VSTAR 特技：额外回合
			return [AttackVSTARExtraTurn.new()]
		"握握抽取":
			# 摸牌至手牌7张
			return [AttackDrawTo7.new()]
		"阴影包围":
			return [_instantiate_effect(AttackItemLockNextTurnEffect, [true, processor.coin_flipper])]
		"暗夜难明":
			return [_instantiate_effect(AttackItemLockNextTurnEffect)]
		"灵骚":
			return [_instantiate_effect(AttackOpponentHandCountDamageEffect, [60, true, 60])]
		"月光手里剑":
			# 选择对手的2只宝可梦各90伤害 + 弃2能量
			return [AttackMoonlightShuriken.new(90, 2), EffectDiscardEnergy.new(2)]
		"冰雹利刃":
			return [_instantiate_effect(AttackDiscardEnergyMultiDamageEffect, ["W", 60])]
		"招来":
			return [_instantiate_effect(AttackDrawCardsEffect, [1])]
		"双刃":
			# 对备战区1只宝可梦120伤害，自身受30反伤
			return [AttackBenchSnipe.new(120, 1, 30)]
		"狂风呼啸":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"气旋俯冲":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"风暴俯冲":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"深渊探求":
			# 查看牌库顶部4张，选2张加入手牌，其余放逐
			return [_instantiate_effect(AttackLookTopPickHandRestLostZoneEffect, [4, 2])]
		"磁力抬升":
			# 从牌库搜索1张牌，洗牌后将其放回牌库顶
			return [_instantiate_effect(AttackSearchDeckToTopEffect, [1])]
		"金属爆破":
			# 己方场上每个金属能量+40伤害
			return [AttackEnergyCountDamage.new("M", 40, true)]
		"精神强念":
			# 对方宝可梦身上每个超能量+50伤害
			return [AttackEnergyCountDamage.new("P", 50, false)]
		"烧光":
			# 弃掉竞技场
			return [AttackDiscardStadium.new()]
		"跳一下":
			# 呱呱泡蛙：投币反面则招式失败
			return [AttackCoinFlipOrFail.new(30, "no_damage")]
		"终结门牙":
			# 投币背面则此招式无效果
			return [AttackCoinFlipOrFail.new(30, "no_damage")]
		"长尾粉碎":
			# 投币背面则此招式无效果
			return [AttackCoinFlipOrFail.new(100, "no_damage")]
		"鼓足干劲":
			# 从弃牌区选择最多2张基本能量附着于1只备战宝可梦
			return [AttackAttachBasicEnergyFromDiscard.new("", 2, "own_bench")]
		"读风":
			# 攻击后摸牌
			return [AttackReadWindDraw.new()]
		"特殊滚动":
			# 己方身上每张特殊能量+70伤害
			return [AttackSpecialEnergyMultiDamage.new(70)]
		"飞来横祸":
			# 振翼发：将2个伤害指示物以任意方式分配到对方备战区
			return [_instantiate_effect(AttackDistributedBenchCountersEffect, [20])]
		"原生乱打":
			# 故勒顿：己方场上每只古代宝可梦造成30伤害
			return [_instantiate_effect(AttackOwnFieldTaggedPokemonCountDamageEffect, [CardData.ANCIENT_TAG, 30, true])]
		"撕裂":
			# 无视防守方效果
			return [AttackIgnoreDefenderEffects.new()]
		"报仇":
			# 己方有宝可梦昏厥时额外+120伤害
			return [AttackRevengeBonus.new(120)]
		"忍刃":
			return [_instantiate_effect(AttackGreninjaExShinobiBladeEffect)]
		"分身连打":
			return [_instantiate_effect(AttackGreninjaExMirageBarrageEffect)]
		"三重新星":
			# 从牌库搜索能量附加到V宝可梦
			return [AttackSearchAttachToV.new()]
		"瞬移破坏":
			# 拉鲁拉丝：造成伤害后与备战宝可梦交换
			return [_instantiate_effect(AttackSwitchSelfToBenchEffect)]
		"互斥":
			return [_instantiate_effect(AttackSwitchSelfToBenchEffect)]
		"凶暴吼叫":
			# 吼叫尾：自身伤害指示物数x20伤害到目标
			return [_instantiate_effect(AttackSelfDamageCounterTargetDamageEffect, [20])]
		"气球炸弹":
			# 飘飘球：自身伤害指示物数x30伤害
			return [_instantiate_effect(AttackSelfDamageCounterMultiplierEffect, [30])]
		"狙落":
			# 钥圈儿：弃掉对手战斗宝可梦道具
			return [_instantiate_effect(AttackDiscardDefenderToolEffect)]
		"精神幻觉":
			# 愿增猿：60伤害+混乱
			return [EffectApplyStatus.new("confused", false)]
		"奇迹之力":
			# 沙奈朵ex：190伤害+清除自身状态
			return [_instantiate_effect(AttackClearOwnStatusEffect)]
		"伏特旋风":
			# 铁荆棘ex：转移1个能量到备战区
			return [AttackMoveEnergyToBench.new()]
		_:
			return []


## ==================== 调试统计 ====================

## 返回各分类已注册的效果数量，用于调试和覆盖率检查
## 返回格式：{ "items": int, "supporters": int, "tools": int, "stadiums": int, "energies": int }
static func get_registered_count() -> Dictionary:
	# 物品卡数量（硬编码，与 _register_items 保持同步）
	var items_count: int = 48
	# 支援者卡数量（硬编码，与 _register_supporters 保持同步）
	var supporters_count: int = 39
	# 道具数量（硬编码，与 _register_tools 保持同步）
	var tools_count: int = 25
	# 竞技场数量（硬编码，与 _register_stadiums 保持同步）
	var stadiums_count: int = 19
	# 特殊能量数量（硬编码，与 _register_special_energies 保持同步）
	var energies_count: int = 11

	return {
		"items": items_count,
		"supporters": supporters_count,
		"tools": tools_count,
		"stadiums": stadiums_count,
		"energies": energies_count,
		"total_static": items_count + supporters_count + tools_count + stadiums_count + energies_count
	}
