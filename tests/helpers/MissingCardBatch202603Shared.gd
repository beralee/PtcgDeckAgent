extends TestBase

const EffectRoxanne = preload("res://scripts/effects/trainer_effects/EffectRoxanne.gd")
const EffectCyllene = preload("res://scripts/effects/trainer_effects/EffectCyllene.gd")
const EffectTrekkingShoes = preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd")
const EffectPokemonCatcher = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectEnergySwitch = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectNightStretcher = preload("res://scripts/effects/trainer_effects/EffectNightStretcher.gd")
const EffectUnfairStamp = preload("res://scripts/effects/trainer_effects/EffectUnfairStamp.gd")
const EffectCarmine = preload("res://scripts/effects/trainer_effects/EffectCarmine.gd")
const EffectHandheldFan = preload("res://scripts/effects/tool_effects/EffectHandheldFan.gd")
const AbilityMoveOpponentDamageCounters = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")
const AbilityBenchDamageOnPlay = preload("res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd")
const AbilityPrizeCountColorlessReduction = preload("res://scripts/effects/pokemon_effects/AbilityPrizeCountColorlessReduction.gd")
const AttackCoinFlipApplyStatus = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipApplyStatus.gd")
const AttackCoinFlipOrFail = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipOrFail.gd")
const AbilitySelfHealVSTAR = preload("res://scripts/effects/pokemon_effects/AbilitySelfHealVSTAR.gd")
const AbilityMillDeckRecoverToHand = preload("res://scripts/effects/pokemon_effects/AbilityMillDeckRecoverToHand.gd")
const AttackAttachBasicEnergyFromDiscard = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AbilityAttachBasicEnergyFromHandDraw = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd")
const AbilityLookTopToHand = preload("res://scripts/effects/pokemon_effects/AbilityLookTopToHand.gd")
const AbilityDrawIfKnockoutLastTurn = preload("res://scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd")
const AttackLostZoneEnergy = preload("res://scripts/effects/pokemon_effects/AttackLostZoneEnergy.gd")
const AttackLookTopPickHandRestLostZone = preload("res://scripts/effects/pokemon_effects/AttackLookTopPickHandRestLostZone.gd")
const AttackAnyTargetDamage = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
const AttackKnockoutDefenderThenSelfDamage = preload("res://scripts/effects/pokemon_effects/AttackKnockoutDefenderThenSelfDamage.gd")
const AttackDefenderRetreatLockNextTurn = preload("res://scripts/effects/pokemon_effects/AttackDefenderRetreatLockNextTurn.gd")
const EffectGiftEnergy = preload("res://scripts/effects/energy_effects/EffectGiftEnergy.gd")
const EffectMistEnergy = preload("res://scripts/effects/energy_effects/EffectMistEnergy.gd")
const EffectVGuardEnergy = preload("res://scripts/effects/energy_effects/EffectVGuardEnergy.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		if _results.is_empty():
			return false
		var result: bool = _results.pop_front()
		coin_flipped.emit(result)
		return result


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "CCC", "damage": "60", "text": "", "is_vstar_power": false}]
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _load_card_data(path: String) -> CardData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return null
	return CardData.from_dict(json.data)


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		var active_cd := _make_basic_pokemon_data("Active%d" % pi, "C", 130)
		var active := _make_slot(active_cd, pi)
		player.active_pokemon = active

		for bi: int in 2:
			var bench_cd := _make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "C", 90)
			var bench := _make_slot(bench_cd, pi)
			player.bench.append(bench)

		for di: int in 4:
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("Deck%d_%d" % [pi, di], "C"), pi))

		for hi: int in 3:
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand%d_%d" % [pi, hi], "C"), pi))

		for pri: int in 6:
			player.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize%d_%d" % [pi, pri], "C"), pi))

		state.players.append(player)

	return state


