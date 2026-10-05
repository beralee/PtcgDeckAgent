extends RefCounted

const E = preload("res://scripts/effects/pokemon_effects/TournamentSeries59AdditionalPokemonEffects.gd")
const CSV9 = preload("res://scripts/effects/CSV9CEffects.gd")
const CSV10 = preload("res://scripts/effects/CSV10C101To200Effects.gd")
const Sinistcha = preload("res://scripts/effects/pokemon_effects/TcgMikTinkatonSinistchaEffects.gd")

static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	var attacks: Array = []
	match card.effect_id:
		"f4d3cb54f0c01ba9b5f2a4cb9fce9ec3": attacks = [EffectSelfDamage.new(10, 0)] # Doduo
		"ff57cea32736dd645dcf07ab54b3f9ea": attacks = [AttackDiscardAttachedEnergyFromSelf.new(1, 0)]
		"55e5e3d815b73dec1f38aa900afba0ee": attacks = [EffectApplyStatus.new("asleep", false, 0)]
		"73bdd71cb7017633aaf201b028bd3652":
			var sleep := AttackSelfSleep.new()
			sleep.bind_default_attack_index(0)
			attacks = [sleep, CSV9CSimpleHealSelfAfterAttack.new(30, 0)]
		"3681b2671b2cfb5cf4381d72d87ed2f6": attacks = [Sinistcha.AttackDistributeOpponentDamageCounters.new(8, 1)]
		"6743b9624831bf2307918dce25e1fb2d":
			processor.register_effect(card.effect_id, E.BronzeBody.new())
			attacks = [CSV10.AttackDamageOwnBenchAll.new(30, 0)]
		"889c7ffe260732b2db55b5c14f05cb33": processor.register_effect(card.effect_id, E.AssaultingHunt.new())
		"b215ad214738ffd22b00673b4a254b15": attacks = [E.MirrorDraw.new()]
		"16a6b9b3e74104caa59751bf55e6cd28", "90343c8393ff4c3a2ee74e551df524d5": attacks = [AttackCoinFlipPreventDamageAndEffectsNextTurn.new(processor.coin_flipper, 0)]
		"93ddf8f138b1edbb9b57620bcaa80b5d": attacks = [AttackMoveOpponentHandCardToDeck.new(0)]
		"bef823435789b8e25911400efe0b50a4": attacks = [E.BothDrawThree.new()]
		"162aa30465bfa41d838cbe010eeed5b2": attacks = [E.CoinDamage.new(3, 60, 60, 0, processor.coin_flipper)]
		"2660960a5e1f7383bd679ca3dc27621f": attacks = [E.FeintAttack.new(), AttackSelfAllAttacksLockNextTurn.new(1)]
		"ec6d0412aa2e5a0b0ed1490ac796df86":
			processor.register_effect(card.effect_id, E.MysteriousShield.new())
			attacks = [AttackIgnoreDefenderEffects.new(0)]
		"b8aaf66c1209ba720cdcabdb011e06e7": attacks = [E.HandEnergyAttach.new(false)]
		"50fcaf60eed755b7394ca95828345980": attacks = [E.HandEnergyAttach.new(true)]
		"54ac40e061bac6c8b358d6247b7a15eb", "d903825962e8a629b0adfd9e03c4a0d6":
			var attach := E.DeckFireAttach.new()
			attach.bind_default_attack_index(0)
			attacks = [attach]
		"044e627b60cfc8c546ef7e172c0a874d": attacks = [EffectApplyStatus.new("burned", false, 0), AttackDefenderRetreatLockNextTurn.new(0), AttackOpponentHiddenHandDiscard.new(1), AttackMillOpponentDeck.new(1, 1)]
		"54984a509550b1cfdbe940c0b20be30f": attacks = [E.HealOneBench.new()]
		"81e1caca63306c340b5915fb14cdb077": attacks = [E.SearchEnergy.new()]
		"b868f9185451bae128d75f0aca7b91f9": attacks = [AttackAttachBasicEnergyFromDiscard.new("W", 2, "own_any", 0), AttackDiscardAttachedEnergyFromSelf.new(2, 1)]
		"31d0610ee2a0b1e904e08ad72251aa48":
			processor.register_effect(card.effect_id, E.MagneticAbsorption.new())
			attacks = [AttackSelfAllAttacksLockNextTurn.new(0)]
		"3fe795cc18c44928e6755503dbc1fdfb": attacks = [E.JetPunchRecoil.new(), E.CoinDamage.new(2, 90, 90, 1, processor.coin_flipper)]
		"12a9c244a95af5d450f3d39ede73a2d2": attacks = [E.PsychicMirror.new()]
		"880f55ba795d8703bc0fbb7266d61cee": attacks = [CSV9.AttackEvolveFromDeck.new(0), E.CoinDamage.new(1, 20, 0, 1, processor.coin_flipper)]
		"d94f8f6e08bc586538c8b77e3c184a56": attacks = [AttackDiscardAttachedEnergyFromSelf.new(1, 1)]
		"83cf2dc98e97628df64ef9f35f1befb3": attacks = [AttackSearchDeckToHand.new(1, "Pokemon", 0)]
		"fb03e90c5a6d772ba32e1451c20cbae6": attacks = [E.ColorfulCatch.new()]
		"a048b275e9d6b42344f9399c374467d0": attacks = [AttackRecoverTrainerFromDiscard.new(1, 0)]
		"e5b5f21d3d91e433188733bbd04a3553":
			processor.register_effect(card.effect_id, E.MetalBridge.new(processor))
			attacks = [AttackSelfAllAttacksLockNextTurn.new(0)]
		"04cb7a5607e2d5e5a5a3daeefc15f64a": attacks = [E.CursedWords.new()]
		"ce9e5d4c4001b526757e2fa1f75d0e05": attacks = [E.CoinDamage.new(3, 10, 10, 0, processor.coin_flipper)]
		"eb1836e87ae4f678bac49ab21623d321":
			processor.register_effect(card.effect_id, AbilityDiscardEnergyDrawToHandSize.new(6, true))
			attacks = [E.CoinDamage.new(1, 90, 0, 0, processor.coin_flipper)]
		"4eaba5926d7967ebdfe2f91c5511060d": attacks = [EffectSelfDamage.new(20, 0)]
	if not attacks.is_empty():
		processor.replace_attack_effects(card.effect_id, attacks)
