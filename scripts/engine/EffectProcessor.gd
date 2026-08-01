class_name EffectProcessor
extends RefCounted

const EffectKieranScript = preload("res://scripts/effects/trainer_effects/EffectKieran.gd")
const EffectBlackBeltsTrainingScript = preload("res://scripts/effects/trainer_effects/EffectBlackBeltsTraining.gd")
const AbilityBasicVLockScript = preload("res://scripts/effects/pokemon_effects/AbilityBasicVLock.gd")
const CSV9CEffects = preload("res://scripts/effects/CSV9CEffects.gd")
const CSV9C202Briar = preload("res://scripts/effects/trainer_effects/CSV9C202Briar.gd")
const NoivernExEffectsScript = preload("res://scripts/effects/pokemon_effects/NoivernExEffects.gd")
const AbilityZamazentaVSTARShieldScript = preload("res://scripts/effects/pokemon_effects/AbilityZamazentaVSTARShield.gd")
const AbilityPreventTeraAttackDamageAndEffectsScript = preload("res://scripts/effects/pokemon_effects/AbilityPreventTeraAttackDamageAndEffects.gd")
const AbilityTingLuCursedLandScript = preload("res://scripts/effects/pokemon_effects/AbilityTingLuCursedLand.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

const SWEET_TRAP_DAMAGE_BONUS_EFFECT_TYPE := "sweet_trap_damage_bonus"
const PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY := "_pending_attack_effect_energy_returns"
const ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY := "_attack_effect_energy_return_depth"
const LAST_INTERACTION_VALIDATION_ERROR_KEY := "_last_interaction_validation_error"

static var _live_refs: Array[WeakRef] = []

var _effect_registry: Dictionary = {}
var _attack_effect_registry: Dictionary = {}
var _registered_pokemon_effect_ids: Dictionary = {}
var _effect_alias_overrides: Dictionary = {}
var coin_flipper: CoinFlipper = null
var _game_state_machine_ref: WeakRef = null


func _init(flipper: CoinFlipper = null) -> void:
	_live_refs.append(weakref(self))
	coin_flipper = flipper if flipper != null else CoinFlipper.new()
	EffectRegistry.register_all(self)


func bind_game_state_machine(gsm: Object) -> void:
	_game_state_machine_ref = weakref(gsm) if gsm != null else null


func _get_bound_game_state_machine() -> Object:
	if _game_state_machine_ref == null:
		return null
	return _game_state_machine_ref.get_ref()


func register_effect(effect_id: String, effect: BaseEffect) -> void:
	_effect_registry[effect_id] = effect


func register_attack_effect(effect_id: String, effect: BaseEffect) -> void:
	if not _attack_effect_registry.has(effect_id):
		_attack_effect_registry[effect_id] = []
	_attack_effect_registry[effect_id].append(effect)


func replace_attack_effects(effect_id: String, effects: Array) -> void:
	if effect_id == "":
		return
	_attack_effect_registry[effect_id] = []
	for item: Variant in effects:
		var effect := item as BaseEffect
		if effect != null:
			_attack_effect_registry[effect_id].append(effect)


func register_effect_alias(alias_effect_id: String, source_effect_id: String) -> void:
	var alias_id := str(alias_effect_id).strip_edges()
	var source_id := str(source_effect_id).strip_edges()
	if alias_id == "" or source_id == "" or alias_id == source_id:
		return
	_effect_alias_overrides[alias_id] = source_id


func resolve_effect_id(effect_id: String) -> String:
	return _resolve_effect_id(effect_id)


func _resolve_effect_id(effect_id: String) -> String:
	var raw_id := str(effect_id).strip_edges()
	if raw_id == "":
		return ""
	var override_id := str(_effect_alias_overrides.get(raw_id, ""))
	if override_id != "":
		return override_id
	var card_database: Node = AutoloadResolverScript.get_card_database()
	if card_database == null:
		return raw_id
	var db_alias: String = str(card_database.get_effect_alias(raw_id))
	return db_alias if db_alias != "" else raw_id


func _get_alias_source_card(effect_id: String) -> CardData:
	if str(_effect_alias_overrides.get(effect_id, "")) != "":
		return null
	var card_database: Node = AutoloadResolverScript.get_card_database()
	return card_database.get_effect_alias_source_card(effect_id) if card_database != null else null


func prepare_for_disposal() -> void:
	_effect_registry.clear()
	_attack_effect_registry.clear()
	_registered_pokemon_effect_ids.clear()
	_effect_alias_overrides.clear()
	_game_state_machine_ref = null
	coin_flipper = null


static func cleanup_live_instances_for_tests() -> void:
	var remaining: Array[WeakRef] = []
	for ref: WeakRef in _live_refs:
		var processor := ref.get_ref() as EffectProcessor
		if processor == null:
			continue
		processor.prepare_for_disposal()
		if ref.get_ref() != null:
			remaining.append(ref)
	_live_refs = remaining


func register_effects(effects: Dictionary) -> void:
	for eid: String in effects.keys():
		register_effect(eid, effects[eid])


func register_attack_effects(effects: Dictionary) -> void:
	for eid: String in effects.keys():
		var effect_list: Array = effects[eid]
		for effect: BaseEffect in effect_list:
			register_attack_effect(eid, effect)


func has_effect(effect_id: String) -> bool:
	return _effect_registry.has(_resolve_effect_id(effect_id))


func has_attack_effect(effect_id: String) -> bool:
	return _attack_effect_registry.has(_resolve_effect_id(effect_id))


func get_registered_count() -> int:
	return _effect_registry.size() + _attack_effect_registry.size()


func get_effect(effect_id: String) -> BaseEffect:
	return _effect_registry.get(_resolve_effect_id(effect_id), null)


func draw_cards_with_log(
	player_index: int,
	count: int,
	state: GameState,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	var game_state_machine := _get_bound_game_state_machine()
	if game_state_machine != null and game_state_machine.has_method("draw_cards_for_effect"):
		if game_state_machine.get("game_state") == state:
			return game_state_machine.call("draw_cards_for_effect", player_index, count, source_card, source_kind)
	return state.players[player_index].draw_cards(count)


func discard_cards_from_hand_with_log(
	player_index: int,
	cards: Array[CardInstance],
	state: GameState,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	var game_state_machine := _get_bound_game_state_machine()
	if game_state_machine != null and game_state_machine.has_method("discard_cards_from_hand_for_effect"):
		if game_state_machine.get("game_state") == state:
			return game_state_machine.call("discard_cards_from_hand_for_effect", player_index, cards, source_card, source_kind)
	var player: PlayerState = state.players[player_index]
	var discarded: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card == null or not (card in player.hand):
			continue
		player.remove_from_hand(card)
		player.discard_card(card)
		discarded.append(card)
	return discarded


func move_public_cards_to_hand_with_log(
	player_index: int,
	cards: Array[CardInstance],
	state: GameState,
	source_card: CardInstance = null,
	source_kind: String = "",
	public_result_kind: String = "search_to_hand",
	public_result_labels: Array[String] = []
) -> Array[CardInstance]:
	var game_state_machine := _get_bound_game_state_machine()
	if game_state_machine != null and game_state_machine.has_method("move_public_cards_to_hand_for_effect"):
		if game_state_machine.get("game_state") == state:
			return game_state_machine.call(
				"move_public_cards_to_hand_for_effect",
				player_index,
				cards,
				source_card,
				source_kind,
				public_result_kind,
				public_result_labels
			)
	var player: PlayerState = state.players[player_index]
	var moved: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for card: CardInstance in cards:
		if card == null or seen_ids.has(card.instance_id) or not (card in player.deck):
			continue
		seen_ids[card.instance_id] = true
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
		moved.append(card)
	return moved


func record_effect_damage(
	player_index: int,
	target: PokemonSlot,
	damage: int,
	state: GameState,
	source_kind: String = ""
) -> void:
	if target == null or damage <= 0:
		return
	var game_state_machine := _get_bound_game_state_machine()
	if game_state_machine != null and game_state_machine.has_method("record_effect_damage"):
		if game_state_machine.get("game_state") == state:
			game_state_machine.call("record_effect_damage", player_index, target, damage, source_kind)


func register_pokemon_card(card: CardData) -> void:
	if card == null or not card.is_pokemon():
		return
	var effect_id: String = card.effect_id
	if effect_id == "":
		return
	if _registered_pokemon_effect_ids.has(effect_id):
		return
	var resolved_effect_id := _resolve_effect_id(effect_id)
	if resolved_effect_id != effect_id:
		var source_card := _get_alias_source_card(effect_id)
		if source_card != null and source_card.effect_id != effect_id:
			register_pokemon_card(source_card)
		_registered_pokemon_effect_ids[effect_id] = true
		return
	EffectRegistry.register_pokemon_card(self, card)
	_registered_pokemon_effect_ids[effect_id] = true


func _get_registered_pokemon_effect(slot: PokemonSlot) -> BaseEffect:
	if slot == null:
		return null
	var card_data: CardData = slot.get_card_data()
	if card_data == null or not card_data.is_pokemon():
		return null
	var existing_effect := get_effect(card_data.effect_id)
	if existing_effect != null:
		return existing_effect
	if card_data.abilities.is_empty():
		return null
	register_pokemon_card(card_data)
	return get_effect(card_data.effect_id)


func get_attack_effects_for_slot(attacker: PokemonSlot, attack_index: int = 0) -> Array[BaseEffect]:
	var result: Array[BaseEffect] = []
	if attacker == null or attacker.get_top_card() == null:
		return result
	var card_data: CardData = attacker.get_card_data()
	if card_data == null:
		return result
	var effect_id: String = _resolve_effect_id(card_data.effect_id)
	if not _attack_effect_registry.has(effect_id):
		register_pokemon_card(card_data)
		effect_id = _resolve_effect_id(card_data.effect_id)
	if not _attack_effect_registry.has(effect_id):
		return result
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		result.append(effect)
	return result


func _record_interaction_validation_result(state: GameState, result: Dictionary) -> bool:
	var valid := bool(result.get("valid", false))
	if state != null:
		if valid:
			state.shared_turn_flags.erase(LAST_INTERACTION_VALIDATION_ERROR_KEY)
		else:
			state.shared_turn_flags[LAST_INTERACTION_VALIDATION_ERROR_KEY] = str(result.get("reason", "invalid interaction context"))
	return valid


func get_last_interaction_validation_error(state: GameState) -> String:
	if state == null:
		return ""
	return str(state.shared_turn_flags.get(LAST_INTERACTION_VALIDATION_ERROR_KEY, ""))


func validate_card_effect_context(card: CardInstance, targets: Array, state: GameState) -> bool:
	if card == null or card.card_data == null:
		return _record_interaction_validation_result(state, {"valid": false, "reason": "card is missing"})
	var effect_id: String = _resolve_effect_id(card.card_data.effect_id)
	if card.card_data.card_type == "Special Energy" and is_special_energy_suppressed(card, state):
		return _record_interaction_validation_result(state, {"valid": true})
	if not _effect_registry.has(effect_id):
		return _record_interaction_validation_result(state, {"valid": true})
	var effect: BaseEffect = _effect_registry[effect_id]
	state.shared_turn_flags["_draw_effect_processor"] = self
	return _record_interaction_validation_result(state, effect.validate_card_interaction(card, targets, state))


func validate_attack_effect_context(
	attacker: PokemonSlot,
	attack_index: int,
	_defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return _record_interaction_validation_result(state, {"valid": false, "reason": "attacker is missing"})
	var card_data: CardData = attacker.get_card_data()
	if card_data == null or attack_index < 0 or attack_index >= card_data.attacks.size():
		return _record_interaction_validation_result(state, {"valid": false, "reason": "attack index is invalid"})
	var effect_id: String = _resolve_effect_id(card_data.effect_id)
	var candidates: Array[BaseEffect] = []
	if _effect_registry.has(effect_id):
		candidates.append(_effect_registry[effect_id])
	if _attack_effect_registry.has(effect_id):
		for attack_effect: BaseEffect in _attack_effect_registry[effect_id]:
			if attack_effect not in candidates:
				candidates.append(attack_effect)
	state.shared_turn_flags["_draw_effect_processor"] = self
	for effect: BaseEffect in candidates:
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		var result := effect.validate_attack_interaction(attacker, attack_index, targets, state)
		if not bool(result.get("valid", false)):
			return _record_interaction_validation_result(state, result)
	return _record_interaction_validation_result(state, {"valid": true})


func execute_card_effect(card: CardInstance, targets: Array, state: GameState) -> bool:
	if card == null or card.card_data == null:
		return false
	var effect_id: String = _resolve_effect_id(card.card_data.effect_id)
	if card.card_data.card_type == "Special Energy" and is_special_energy_suppressed(card, state):
		return true
	if not _effect_registry.has(effect_id):
		return true
	var effect: BaseEffect = _effect_registry[effect_id]
	state.shared_turn_flags["_draw_effect_processor"] = self
	if not effect.can_execute(card, state):
		return false
	if not validate_card_effect_context(card, targets, state):
		return false
	effect.execute(card, targets, state)
	return true


func execute_attack_effect(
	attacker: PokemonSlot,
	attack_index: int,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var card_data: CardData = attacker.get_card_data()
	if attack_index < 0 or attack_index >= card_data.attacks.size():
		return false
	if not validate_attack_effect_context(attacker, attack_index, defender, state, targets):
		return false
	var effect_id: String = _resolve_effect_id(card_data.effect_id)
	_begin_attack_effect_energy_return_window(state)

	if _effect_registry.has(effect_id):
		var card_effect: BaseEffect = _effect_registry[effect_id]
		state.shared_turn_flags["_draw_effect_processor"] = self
		card_effect.set_attack_interaction_context(targets)
		card_effect.execute_attack(attacker, defender, attack_index, state)
		card_effect.clear_attack_interaction_context()
		if state != null and state.is_game_over():
			_finish_attack_effect_energy_return_window(state)
			return true

	if _attack_effect_registry.has(effect_id):
		var already_executed_effect: BaseEffect = _effect_registry.get(effect_id, null)
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if effect == already_executed_effect:
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			state.shared_turn_flags["_draw_effect_processor"] = self
			effect.set_attack_interaction_context(targets)
			effect.execute_attack(attacker, defender, attack_index, state)
			effect.clear_attack_interaction_context()
			if state != null and state.is_game_over():
				_finish_attack_effect_energy_return_window(state)
				return true
	_finish_attack_effect_energy_return_window(state)
	return true


func execute_before_attack_damage_effects(
	attacker: PokemonSlot,
	attack_index: int,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> void:
	if attacker == null or attacker.get_top_card() == null:
		return
	var card_data := attacker.get_card_data()
	if card_data == null or attack_index < 0 or attack_index >= card_data.attacks.size():
		return
	execute_before_attack_damage_effects_by_id(card_data.effect_id, attack_index, attacker, defender, state, targets)


func execute_before_attack_damage_effects_by_id(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> void:
	effect_id = _resolve_effect_id(effect_id)
	var candidates: Array[BaseEffect] = []
	if _effect_registry.has(effect_id):
		candidates.append(_effect_registry[effect_id])
	if _attack_effect_registry.has(effect_id):
		for attack_effect: BaseEffect in _attack_effect_registry[effect_id]:
			if attack_effect not in candidates:
				candidates.append(attack_effect)
	for effect: BaseEffect in candidates:
		if not effect.has_method("before_attack_damage"):
			continue
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		if state != null:
			state.shared_turn_flags["_draw_effect_processor"] = self
		effect.set_attack_interaction_context(targets)
		effect.call("before_attack_damage", attacker, defender, attack_index, state)
		effect.clear_attack_interaction_context()


func _begin_attack_effect_energy_return_window(state: GameState) -> void:
	if state == null:
		return
	var depth := int(state.shared_turn_flags.get(ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY, 0))
	if depth <= 0:
		state.shared_turn_flags[PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY] = []
	state.shared_turn_flags[ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY] = depth + 1


func _finish_attack_effect_energy_return_window(state: GameState) -> void:
	if state == null:
		return
	var depth := int(state.shared_turn_flags.get(ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY, 0)) - 1
	if depth > 0:
		state.shared_turn_flags[ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY] = depth
		return
	_resolve_pending_attack_effect_energy_returns(state)
	state.shared_turn_flags.erase(PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY)
	state.shared_turn_flags.erase(ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY)


func record_attack_effect_discarded_attached_energy(attacker: PokemonSlot, energy: CardInstance, state: GameState) -> void:
	if attacker == null or energy == null or energy.card_data == null or state == null:
		return
	if int(state.shared_turn_flags.get(ATTACK_EFFECT_ENERGY_RETURN_DEPTH_KEY, 0)) <= 0:
		return
	if energy.card_data.card_type != "Special Energy":
		return
	if is_special_energy_suppressed(energy, state):
		return
	var effect := get_effect(energy.card_data.effect_id)
	if effect == null or not effect.has_method("should_return_after_attack_effect_discard"):
		return
	if not bool(effect.call("should_return_after_attack_effect_discard", energy, attacker, state)):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var raw_pending: Variant = state.shared_turn_flags.get(PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY, [])
	var pending: Array = raw_pending if raw_pending is Array else []
	for entry: Variant in pending:
		if entry is Dictionary and (entry as Dictionary).get("energy", null) == energy:
			return
	pending.append({
		"energy": energy,
		"slot": attacker,
		"player_index": int(top.owner_index),
		"pokemon_instance_id": int(top.instance_id),
	})
	state.shared_turn_flags[PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY] = pending


func _resolve_pending_attack_effect_energy_returns(state: GameState) -> void:
	var raw_pending: Variant = state.shared_turn_flags.get(PENDING_ATTACK_EFFECT_ENERGY_RETURNS_KEY, [])
	if not raw_pending is Array:
		return
	for entry: Variant in raw_pending:
		if not entry is Dictionary:
			continue
		var data := entry as Dictionary
		var energy := data.get("energy", null) as CardInstance
		var slot := data.get("slot", null) as PokemonSlot
		var player_index := int(data.get("player_index", -1))
		var pokemon_instance_id := int(data.get("pokemon_instance_id", -1))
		if energy == null or slot == null or player_index < 0 or player_index >= state.players.size():
			continue
		var player: PlayerState = state.players[player_index]
		if not (energy in player.discard_pile):
			continue
		if not _slot_still_in_play_for_player(slot, player):
			continue
		var top := slot.get_top_card()
		if top == null or int(top.instance_id) != pokemon_instance_id:
			continue
		player.discard_pile.erase(energy)
		slot.attached_energy.append(energy)


func _slot_still_in_play_for_player(slot: PokemonSlot, player: PlayerState) -> bool:
	if slot == null or player == null:
		return false
	if player.active_pokemon == slot:
		return true
	return slot in player.bench


## 使用指定的 effect_id 执行攻击效果（用于复制招式场景，如巨龙无双）
## 与 execute_attack_effect 的区别：允许 effect_id 与 attacker 上的卡牌不同
func attack_damage_cancelled(
	attacker: PokemonSlot,
	attack_index: int,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var card_data: CardData = attacker.get_card_data()
	if card_data == null or attack_index < 0 or attack_index >= card_data.attacks.size():
		return false
	var effect_id: String = _resolve_effect_id(card_data.effect_id)
	if _effect_registry.has(effect_id):
		var card_effect: BaseEffect = _effect_registry[effect_id]
		if _attack_damage_cancelled_by_effect(card_effect, attacker, attack_index, defender, state, targets):
			return true
	if _attack_effect_registry.has(effect_id):
		var already_executed_effect: BaseEffect = _effect_registry.get(effect_id, null)
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if effect == already_executed_effect:
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			if _attack_damage_cancelled_by_effect(effect, attacker, attack_index, defender, state, targets):
				return true
	return false


func _attack_damage_cancelled_by_effect(
	effect: BaseEffect,
	attacker: PokemonSlot,
	attack_index: int,
	defender: PokemonSlot,
	state: GameState,
	targets: Array
) -> bool:
	if effect == null or not effect.has_method("cancels_attack_damage"):
		return false
	effect.set_attack_interaction_context(targets)
	var cancelled := bool(effect.call("cancels_attack_damage", attacker, defender, attack_index, state))
	effect.clear_attack_interaction_context()
	return cancelled


func execute_attack_effect_by_id(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> void:
	effect_id = _resolve_effect_id(effect_id)
	_begin_attack_effect_energy_return_window(state)
	if _effect_registry.has(effect_id):
		var card_effect: BaseEffect = _effect_registry[effect_id]
		if exclude_effect_type == null or not is_instance_of(card_effect, exclude_effect_type):
			state.shared_turn_flags["_draw_effect_processor"] = self
			card_effect.set_attack_interaction_context(targets)
			card_effect.execute_attack(attacker, defender, attack_index, state)
			card_effect.clear_attack_interaction_context()
			if state != null and state.is_game_over():
				_finish_attack_effect_energy_return_window(state)
				return

	if _attack_effect_registry.has(effect_id):
		var already_executed_effect: BaseEffect = _effect_registry.get(effect_id, null)
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if effect == already_executed_effect:
				continue
			if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			state.shared_turn_flags["_draw_effect_processor"] = self
			effect.set_attack_interaction_context(targets)
			effect.execute_attack(attacker, defender, attack_index, state)
			effect.clear_attack_interaction_context()
			if state != null and state.is_game_over():
				_finish_attack_effect_energy_return_window(state)
				return
	_finish_attack_effect_energy_return_window(state)


## 根据 effect_id 收集被复制招式的交互步骤（用于巨龙无双等复制招式场景）
func get_attack_interaction_steps_by_id(
	effect_id: String,
	attack_index: int,
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	exclude_effect_type: Variant = null
) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	effect_id = _resolve_effect_id(effect_id)
	if _attack_effect_registry.has(effect_id):
		# 注入 _override_attack_index 以便效果在复制场景中能正确解析攻击索引
		var augmented_attack: Dictionary = attack.duplicate()
		augmented_attack["_override_attack_index"] = attack_index
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
				continue
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			steps.append_array(effect.get_attack_interaction_steps(card, augmented_attack, state))
	return steps


func get_attack_followup_interaction_steps_by_id(
	effect_id: String,
	attack_index: int,
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary,
	exclude_effect_type: Variant = null
) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	effect_id = _resolve_effect_id(effect_id)
	if not _attack_effect_registry.has(effect_id):
		return steps
	var augmented_attack: Dictionary = attack.duplicate()
	augmented_attack["_override_attack_index"] = attack_index
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
			continue
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		steps.append_array(effect.get_followup_attack_interaction_steps(card, augmented_attack, state, resolved_context))
	return steps


func execute_ability_effect(
	pokemon: PokemonSlot,
	ability_index: int,
	targets: Array,
	state: GameState
) -> bool:
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect == null:
		return false
	if not can_use_ability(pokemon, state, ability_index):
		return false
	state.shared_turn_flags["_draw_effect_processor"] = self
	if effect.has_method("validate_ability_interaction"):
		var validation: Variant = effect.call("validate_ability_interaction", pokemon, ability_index, targets, state)
		if validation is Dictionary:
			if not _record_interaction_validation_result(state, validation as Dictionary):
				return false
		elif not bool(validation):
			return _record_interaction_validation_result(state, {
				"valid": false,
				"reason": "ability interaction validation failed",
			})
	effect.call("execute_ability", pokemon, ability_index, targets, state)
	return true


func can_use_ability(pokemon: PokemonSlot, state: GameState, ability_index: int = 0) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	if ability_index < 0:
		return false
	# 道具赋予的特性不受"宝可梦特性压制"影响（振翼发、钥圈儿、铁荆棘等）
	var native_count: int = pokemon.get_card_data().abilities.size() if pokemon.get_card_data() != null else 0
	if ability_index < native_count and is_ability_disabled(pokemon, state):
		return false
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect == null or not effect.has_method("can_use_ability"):
		return false
	if ability_index < native_count and _is_self_knockout_ability_blocked(effect, state):
		return false
	state.shared_turn_flags["_draw_effect_processor"] = self
	return bool(effect.call("can_use_ability", pokemon, state))


func _is_self_knockout_ability_blocked(ability_effect: BaseEffect, state: GameState) -> bool:
	if ability_effect == null or state == null or not ability_effect.has_method("knocks_out_self"):
		return false
	if not bool(ability_effect.call("knocks_out_self")):
		return false
	for player: PlayerState in state.players:
		for source: PokemonSlot in player.get_all_pokemon():
			if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
				continue
			var source_effect := get_effect(source.get_card_data().effect_id)
			if source_effect != null and source_effect.has_method("blocks_self_knockout_abilities"):
				if bool(source_effect.call("blocks_self_knockout_abilities", source, state)):
					return true
	return false


func get_ability_effect(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> BaseEffect:
	if pokemon == null or pokemon.get_top_card() == null:
		return null
	var card_data: CardData = pokemon.get_card_data()
	if card_data == null or ability_index < 0:
		return null

	var native_count: int = card_data.abilities.size()
	if ability_index < native_count:
		return _get_registered_pokemon_effect(pokemon)
	if state != null and ability_index == native_count:
		return _get_tool_granted_ability_effect(pokemon, state)
	return null


func get_ability_source_card(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> CardInstance:
	if pokemon == null or pokemon.get_top_card() == null:
		return null
	var card_data: CardData = pokemon.get_card_data()
	if ability_index < card_data.abilities.size():
		return pokemon.get_top_card()
	if state != null and ability_index == card_data.abilities.size():
		return pokemon.attached_tool
	return null


func get_ability_name(
	pokemon: PokemonSlot,
	ability_index: int = 0,
	state: GameState = null
) -> String:
	if pokemon == null or pokemon.get_top_card() == null:
		return ""
	var card_data: CardData = pokemon.get_card_data()
	if ability_index >= 0 and ability_index < card_data.abilities.size():
		return str(card_data.abilities[ability_index].get("name", ""))
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect != null and effect.has_method("get_ability_name"):
		return str(effect.call("get_ability_name"))
	return ""


func get_granted_abilities(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.get_top_card() == null:
		return entries
	var card_data: CardData = pokemon.get_card_data()
	var native_count: int = card_data.abilities.size()
	var effect: BaseEffect = _get_tool_granted_ability_effect(pokemon, state)
	if effect == null:
		return entries
	entries.append({
		"ability_index": native_count,
		"name": get_ability_name(pokemon, native_count, state),
		"source": "tool",
		"source_card": pokemon.attached_tool,
		"enabled": can_use_ability(pokemon, state, native_count),
	})
	return entries


func get_granted_attacks(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.get_top_card() == null:
		return entries
	entries.append_array(_get_tool_granted_attacks(pokemon, state))
	entries.append_array(_get_field_ability_granted_attacks(pokemon, state))
	return entries


func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var effect: BaseEffect = _resolve_granted_attack_effect(pokemon, granted_attack, state)
	if effect == null or not effect.has_method("get_granted_attack_interaction_steps"):
		return []
	var raw_steps: Variant = effect.call("get_granted_attack_interaction_steps", pokemon, granted_attack, state)
	if raw_steps is Array:
		return raw_steps
	return []


func get_granted_attack_followup_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	var effect: BaseEffect = _resolve_granted_attack_effect(pokemon, granted_attack, state)
	if effect == null or not effect.has_method("get_followup_granted_attack_interaction_steps"):
		return []
	var raw_steps: Variant = effect.call("get_followup_granted_attack_interaction_steps", pokemon, granted_attack, state, resolved_context)
	if raw_steps is Array:
		return raw_steps
	return []


func execute_granted_attack(
	attacker: PokemonSlot,
	granted_attack: Dictionary,
	defender: PokemonSlot,
	state: GameState,
	targets: Array = []
) -> bool:
	var effect: BaseEffect = _resolve_granted_attack_effect(attacker, granted_attack, state)
	if effect == null or not effect.has_method("execute_granted_attack"):
		return false
	_begin_attack_effect_energy_return_window(state)
	if effect.has_method("set_attack_interaction_context"):
		effect.set_attack_interaction_context(targets)
	effect.call("execute_granted_attack", attacker, granted_attack, state, targets)
	if effect.has_method("clear_attack_interaction_context"):
		effect.clear_attack_interaction_context()
	_finish_attack_effect_energy_return_window(state)
	return true


func is_granted_attack_available(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	for available: Dictionary in get_granted_attacks(pokemon, state):
		if _granted_attack_matches(available, granted_attack):
			return true
	return false


func _get_tool_granted_attacks(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.attached_tool == null:
		return entries
	if is_tool_effect_suppressed(pokemon, state):
		return entries
	var effect: BaseEffect = get_effect(pokemon.attached_tool.card_data.effect_id)
	if effect == null or not effect.has_method("get_granted_attacks"):
		return entries
	var raw_entries: Variant = effect.call("get_granted_attacks", pokemon, state)
	if raw_entries is Array:
		for entry: Variant in raw_entries:
			if entry is Dictionary:
				var normalized := (entry as Dictionary).duplicate(true)
				normalized["source"] = str(normalized.get("source", "tool"))
				normalized["source_effect_id"] = pokemon.attached_tool.card_data.effect_id
				normalized["source_card_instance_id"] = int(pokemon.attached_tool.instance_id)
				entries.append(normalized)
	return entries


func _get_field_ability_granted_attacks(pokemon: PokemonSlot, state: GameState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return entries
	var owner_index := int(pokemon.get_top_card().owner_index)
	if owner_index < 0 or owner_index >= state.players.size():
		return entries
	for source: PokemonSlot in state.players[owner_index].get_all_pokemon():
		if source == null or source.get_card_data() == null:
			continue
		if is_ability_disabled(source, state):
			continue
		var effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if effect == null or not effect.has_method("get_granted_attacks_for_target"):
			continue
		var raw_entries: Variant = effect.call("get_granted_attacks_for_target", source, pokemon, state)
		if not (raw_entries is Array):
			continue
		var source_top := source.get_top_card()
		for entry: Variant in raw_entries:
			if not entry is Dictionary:
				continue
			var normalized := (entry as Dictionary).duplicate(true)
			normalized["source"] = str(normalized.get("source", "field_ability"))
			normalized["source_effect_id"] = str(normalized.get("source_effect_id", source.get_card_data().effect_id))
			if source_top != null:
				normalized["source_card_instance_id"] = int(normalized.get("source_card_instance_id", source_top.instance_id))
			entries.append(normalized)
	return entries


func _resolve_granted_attack_effect(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> BaseEffect:
	if pokemon == null or pokemon.get_top_card() == null:
		return null
	if not is_granted_attack_available(pokemon, granted_attack, state):
		return null
	var source_kind := str(granted_attack.get("source", "tool"))
	if source_kind == "tool":
		if pokemon.attached_tool == null or is_tool_effect_suppressed(pokemon, state):
			return null
		return get_effect(pokemon.attached_tool.card_data.effect_id)
	var source_effect_id := str(granted_attack.get("source_effect_id", ""))
	if source_effect_id == "":
		return null
	return get_effect(source_effect_id)


func _granted_attack_matches(left: Dictionary, right: Dictionary) -> bool:
	var left_id := str(left.get("id", ""))
	var right_id := str(right.get("id", ""))
	if left_id != "" and right_id != "" and left_id != right_id:
		return false
	for key: String in [
		"source",
		"source_effect_id",
		"source_card_instance_id",
		"grant_kind",
		"original_card_instance_id",
		"original_effect_id",
		"original_attack_index",
	]:
		if left.has(key) and right.has(key) and str(left.get(key)) != str(right.get(key)):
			return false
	return true


func _get_tool_granted_ability_effect(pokemon: PokemonSlot, state: GameState) -> BaseEffect:
	if pokemon == null or pokemon.attached_tool == null:
		return null
	if is_tool_effect_suppressed(pokemon, state):
		return null
	var tool_eid: String = pokemon.attached_tool.card_data.effect_id
	tool_eid = _resolve_effect_id(tool_eid)
	if not _effect_registry.has(tool_eid):
		return null
	var effect: BaseEffect = _effect_registry[tool_eid]
	if effect is AbilityVSTARSearch and AbilityVSTARSearch.has_vstar_search(pokemon, state):
		return effect
	return null


func get_attacker_modifier(attacker: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> int:
	var total: int = 0
	if state != null:
		state.shared_turn_flags["_draw_effect_processor"] = self
	var pi: int = _get_owner_index(attacker)
	if pi == -1:
		return 0
	total += _get_ability_attack_modifier(attacker, state, pi, defender)
	total += _get_tool_attack_modifier(attacker, state, defender)
	total += _get_stadium_attack_modifier(attacker, state)
	total += _get_energy_attack_modifier(attacker, state)
	for effect_data: Dictionary in attacker.effects:
		if effect_data.get("type", "") == CSV9CEffects.OUTGOING_DAMAGE_REDUCTION_EFFECT_TYPE and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			total -= int(effect_data.get("amount", 0))
	return total


func get_defender_modifier(defender: PokemonSlot, state: GameState, attacker: PokemonSlot = null) -> int:
	var total: int = 0
	var pi: int = _get_owner_index(defender)
	if pi == -1:
		return 0
	total += AbilityZamazentaVSTARShieldScript.get_global_defense_modifier(defender, attacker, state)
	total += _get_ability_defense_modifier(defender, state, pi, attacker)
	total += _get_tool_defense_modifier(defender, state, attacker)
	total += _get_stadium_defense_modifier(defender, state)
	total += _get_energy_defense_modifier(defender, attacker, state)
	for effect_data: Dictionary in defender.effects:
		if effect_data.get("type", "") == "reduce_damage_next_turn" and int(effect_data.get("turn", -999)) == state.turn_number - 1:
			total -= int(effect_data.get("amount", 0))
		elif effect_data.get("type", "") == SWEET_TRAP_DAMAGE_BONUS_EFFECT_TYPE and int(effect_data.get("turn", -999)) == state.turn_number - 2:
			var attacker_owner: int = _get_owner_index(attacker)
			if attacker_owner >= 0 and attacker_owner == int(effect_data.get("source_player_index", -1)):
				total += int(effect_data.get("amount", 0))
	return total


func get_attack_damage_modifier(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack: Dictionary,
	state: GameState,
	targets: Array = [],
	attack_index_override: int = -999999
) -> int:
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = _resolve_effect_id(attacker.get_card_data().effect_id)
	var total: int = 0
	var attack_index: int = attack_index_override
	if attack_index == -999999:
		attack_index = _resolve_attack_index(attacker, _attack)
	if attack_index < 0:
		var original_effect_id := str(_attack.get("original_effect_id", ""))
		var original_attack_index := int(_attack.get("original_attack_index", -1))
		if original_effect_id != "" and original_attack_index >= 0:
			effect_id = _resolve_effect_id(original_effect_id)
			attack_index = original_attack_index
	if attack_index >= 0 and _attack_effect_registry.has(effect_id):
		for effect: BaseEffect in _attack_effect_registry[effect_id]:
			if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
				continue
			if effect.has_method("get_damage_bonus"):
				if state != null:
					state.shared_turn_flags["_draw_effect_processor"] = self
				effect.set_attack_interaction_context(targets)
				total += int(effect.call("get_damage_bonus", attacker, state))
				effect.clear_attack_interaction_context()
	total += EffectKieranScript.get_turn_damage_bonus(attacker, _defender, state)
	total += EffectBlackBeltsTrainingScript.get_turn_damage_bonus(attacker, _defender, state, _attack, total)
	return total


func get_attack_damage_bonus_by_id(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> int:
	if attacker == null or attacker.get_top_card() == null:
		return 0
	effect_id = _resolve_effect_id(effect_id)
	if effect_id == "" or not _attack_effect_registry.has(effect_id):
		return 0
	var total: int = 0
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
			continue
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		if effect.has_method("get_damage_bonus"):
			if state != null:
				state.shared_turn_flags["_draw_effect_processor"] = self
			effect.set_attack_interaction_context(targets)
			total += int(effect.call("get_damage_bonus", attacker, state))
			effect.clear_attack_interaction_context()
	return total


func attack_ignores_weakness_and_resistance(
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	return attack_effect_id_ignores_weakness_and_resistance(effect_id, attack_index, attacker, state, targets)


func attack_ignores_weakness(
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	return attack_effect_id_ignores_weakness(effect_id, attack_index, attacker, state, targets)


func attack_ignores_resistance(
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	return attack_effect_id_ignores_resistance(effect_id, attack_index, attacker, state, targets)


func attack_ignores_defender_effects(
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState,
	targets: Array = []
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	var effect_id: String = attacker.get_card_data().effect_id
	return attack_effect_id_ignores_defender_effects(effect_id, attack_index, attacker, state, targets)


func attack_effect_id_ignores_weakness_and_resistance(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> bool:
	return _attack_effect_id_has_flag(
		effect_id,
		attack_index,
		attacker,
		state,
		["ignores_weakness_and_resistance"],
		targets,
		exclude_effect_type
	)


func attack_effect_id_ignores_weakness(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> bool:
	return _attack_effect_id_has_flag(
		effect_id,
		attack_index,
		attacker,
		state,
		["ignores_weakness", "ignores_weakness_and_resistance"],
		targets,
		exclude_effect_type
	)


func attack_effect_id_ignores_resistance(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> bool:
	return _attack_effect_id_has_flag(
		effect_id,
		attack_index,
		attacker,
		state,
		["ignores_resistance", "ignores_weakness_and_resistance"],
		targets,
		exclude_effect_type
	)


func attack_effect_id_ignores_defender_effects(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> bool:
	return _attack_effect_id_has_flag(
		effect_id,
		attack_index,
		attacker,
		state,
		["ignores_defender_effects"],
		targets,
		exclude_effect_type
	)


func _attack_effect_id_has_flag(
	effect_id: String,
	attack_index: int,
	attacker: PokemonSlot,
	state: GameState,
	method_names: Array,
	targets: Array = [],
	exclude_effect_type: Variant = null
) -> bool:
	if attacker == null or attacker.get_top_card() == null:
		return false
	effect_id = _resolve_effect_id(effect_id)
	if not _attack_effect_registry.has(effect_id):
		return false
	for effect: BaseEffect in _attack_effect_registry[effect_id]:
		if exclude_effect_type != null and is_instance_of(effect, exclude_effect_type):
			continue
		if effect.has_method("applies_to_attack_index") and not bool(effect.call("applies_to_attack_index", attack_index)):
			continue
		effect.set_attack_interaction_context(targets)
		for method_name: String in method_names:
			if effect.has_method(method_name) and bool(effect.call(method_name, attacker, state, attack_index)):
				effect.clear_attack_interaction_context()
				return true
		effect.clear_attack_interaction_context()
	return false


func _resolve_attack_index(attacker: PokemonSlot, attack: Dictionary) -> int:
	if attacker == null or attacker.get_card_data() == null:
		return -1
	for i: int in attacker.get_card_data().attacks.size():
		if attacker.get_card_data().attacks[i] == attack:
			return i
	return -1


func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var total: int = 0
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = _resolve_effect_id(attacker.get_card_data().effect_id)
	if _effect_registry.has(effect_id):
		var native_effect: BaseEffect = _effect_registry[effect_id]
		if native_effect.has_method("get_attack_any_cost_modifier"):
			if native_effect.has_method("is_cost_modifier_ability") and bool(native_effect.call("is_cost_modifier_ability")) and is_ability_disabled(attacker, state):
				pass
			else:
				total += int(native_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	if attacker.attached_tool != null and not is_tool_effect_suppressed(attacker, state):
		var tool_effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_attack_any_cost_modifier"):
			total += int(tool_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_attack_any_cost_modifier"):
			total += int(stadium_effect.call("get_attack_any_cost_modifier", attacker, attack, state))
	return total


func get_attack_colorless_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
	var total: int = 0
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var effect_id: String = _resolve_effect_id(attacker.get_card_data().effect_id)
	if _effect_registry.has(effect_id):
		var native_effect: BaseEffect = _effect_registry[effect_id]
		if native_effect.has_method("get_attack_colorless_cost_modifier"):
			if native_effect.has_method("is_cost_modifier_ability") and bool(native_effect.call("is_cost_modifier_ability")) and is_ability_disabled(attacker, state):
				pass
			else:
				total += int(native_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	if attacker.attached_tool != null and not is_tool_effect_suppressed(attacker, state):
		var tool_effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_attack_colorless_cost_modifier"):
			total += int(tool_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_attack_colorless_cost_modifier"):
			total += int(stadium_effect.call("get_attack_colorless_cost_modifier", attacker, attack, state))
	total += AttackDefenderActionCostIncreaseNextTurn.get_active_modifier(attacker, state)
	return total


func get_weakness_value_override(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> String:
	if CSV9CEffects.defender_has_no_weakness(defender, state) or _defender_ignores_weakness(defender, state):
		return "x1"
	if attacker == null or defender == null or state == null:
		return ""
	if attacker.attached_tool != null and not is_tool_effect_suppressed(attacker, state):
		var effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
		if effect != null and effect.has_method("get_weakness_value_override"):
			var tool_override := str(effect.call("get_weakness_value_override", attacker, defender, state))
			if tool_override != "":
				return tool_override
	var attacker_owner := _get_owner_index(attacker)
	if attacker_owner < 0 or attacker_owner >= state.players.size():
		return ""
	for source: PokemonSlot in state.players[attacker_owner].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = _get_registered_pokemon_effect(source)
		if source_effect != null and source_effect.has_method("get_weakness_value_override_for_target"):
			var override := str(source_effect.call("get_weakness_value_override_for_target", source, defender, state))
			if override != "":
				return override
	return ""


func get_weakness_energy_override(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> String:
	if attacker == null or defender == null or state == null:
		return ""
	var attacker_owner := _get_owner_index(attacker)
	if attacker_owner < 0 or attacker_owner >= state.players.size():
		return ""
	for source: PokemonSlot in state.players[attacker_owner].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = _get_registered_pokemon_effect(source)
		if source_effect != null and source_effect.has_method("get_weakness_energy_override_for_target"):
			var override := str(source_effect.call("get_weakness_energy_override_for_target", source, defender, state))
			if override != "":
				return override
	return ""


func get_retreat_cost_modifier(slot: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	if slot == null:
		return total
	var owner_index := _get_owner_index(slot)
	if state != null and owner_index >= 0:
		for source: PokemonSlot in state.players[owner_index].get_all_pokemon():
			if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
				continue
			var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
			if source_effect != null and source_effect.has_method("get_retreat_cost_modifier_for_slot"):
				total += int(source_effect.call("get_retreat_cost_modifier_for_slot", source, slot, state))
		for player: PlayerState in state.players:
			var active_source: PokemonSlot = player.active_pokemon
			if active_source == null or active_source.attached_tool == null or is_tool_effect_suppressed(active_source, state):
				continue
			var field_tool_effect := get_effect(active_source.attached_tool.card_data.effect_id)
			if field_tool_effect != null and field_tool_effect.has_method("get_retreat_cost_modifier_for_slot"):
				total += int(field_tool_effect.call("get_retreat_cost_modifier_for_slot", active_source, slot, state))
	if slot != null and slot.get_card_data() != null and not is_ability_disabled(slot, state):
		var native_effect: BaseEffect = get_effect(slot.get_card_data().effect_id)
		if native_effect != null and native_effect.has_method("get_retreat_cost_modifier"):
			total += int(native_effect.call("get_retreat_cost_modifier", slot, state))
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect is EffectToolRetreatModifier:
			total += (tool_effect as EffectToolRetreatModifier).retreat_modifier
		elif tool_effect is EffectToolFutureBoost:
			total += (tool_effect as EffectToolFutureBoost).get_retreat_modifier(slot)
		elif tool_effect is EffectToolRescueBoard:
			total += (tool_effect as EffectToolRescueBoard).get_retreat_modifier(slot)
		elif tool_effect != null and tool_effect.has_method("get_retreat_cost_modifier"):
			total += int(tool_effect.call("get_retreat_cost_modifier", slot, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect is EffectStadiumRetreatModifier:
			var stadium_mod: EffectStadiumRetreatModifier = stadium_effect as EffectStadiumRetreatModifier
			if stadium_mod.matches_pokemon(slot):
				total += stadium_mod.retreat_modifier
		elif stadium_effect != null and stadium_effect.has_method("get_retreat_cost_modifier"):
			total += int(stadium_effect.call("get_retreat_cost_modifier", slot, state))
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var energy_effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if energy_effect is EffectSpecialEnergyModifier:
			total += (energy_effect as EffectSpecialEnergyModifier).retreat_modifier
		elif energy_effect != null and energy_effect.has_method("get_retreat_cost_modifier"):
			total += int(energy_effect.call("get_retreat_cost_modifier", slot, state))
	total += AttackDefenderActionCostIncreaseNextTurn.get_active_modifier(slot, state)
	return total


func get_effective_retreat_cost(slot: PokemonSlot, state: GameState) -> int:
	return maxi(0, slot.get_retreat_cost() + get_retreat_cost_modifier(slot, state))


func get_hp_modifier(slot: PokemonSlot, state: GameState = null) -> int:
	var total: int = 0
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_hp_modifier"):
			total += int(tool_effect.call("get_hp_modifier", slot, state))
	if state != null and state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_hp_modifier"):
			total += int(stadium_effect.call("get_hp_modifier", slot, state))
	return total


func get_effective_max_hp(slot: PokemonSlot, state: GameState = null) -> int:
	return slot.get_max_hp() + get_hp_modifier(slot, state)


func get_effective_remaining_hp(slot: PokemonSlot, state: GameState = null) -> int:
	return maxi(0, get_effective_max_hp(slot, state) - slot.damage_counters)


func is_effectively_knocked_out(slot: PokemonSlot, state: GameState = null) -> bool:
	return get_effective_max_hp(slot, state) > 0 and get_effective_remaining_hp(slot, state) <= 0


func apply_attack_damage_survival_tool(
	defender: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	previous_damage: int
) -> bool:
	if defender == null or attacker == null or state == null:
		return false
	if defender.get_card_data() != null and not is_ability_disabled(defender, state):
		var native_effect: BaseEffect = get_effect(defender.get_card_data().effect_id)
		if native_effect != null and native_effect.has_method("try_prevent_attack_knockout"):
			if bool(native_effect.call("try_prevent_attack_knockout", defender, attacker, state, previous_damage, self)):
				return true
	if defender.attached_tool == null or is_tool_effect_suppressed(defender, state):
		return false
	var tool_effect: BaseEffect = get_effect(defender.attached_tool.card_data.effect_id)
	if tool_effect == null or not tool_effect.has_method("try_prevent_attack_knockout"):
		return false
	return bool(tool_effect.call("try_prevent_attack_knockout", defender, attacker, state, previous_damage, self))


func process_after_attack_damage(defender: PokemonSlot, attacker: PokemonSlot, damage: int, state: GameState, targets: Array = []) -> void:
	if defender == null or defender.get_card_data() == null or attacker == null or damage <= 0 or state == null:
		return
	var effect := get_effect(defender.get_card_data().effect_id)
	var attack_reactive := effect != null and effect.has_method("is_attack_damage_reactive_effect") and bool(effect.call("is_attack_damage_reactive_effect"))
	if effect != null and effect.has_method("on_damaged_by_attack") and (attack_reactive or not is_ability_disabled(defender, state)):
		effect.set_attack_interaction_context(targets)
		effect.call("on_damaged_by_attack", defender, attacker, damage, state)
		effect.clear_attack_interaction_context()
	if defender.attached_tool != null and not is_tool_effect_suppressed(defender, state):
		var tool_effect := get_effect(defender.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("on_damaged_by_attack"):
			tool_effect.set_attack_interaction_context(targets)
			tool_effect.call("on_damaged_by_attack", defender, attacker, damage, state)
			tool_effect.clear_attack_interaction_context()
	apply_attack_damage_energy_reactive_effects(attacker, defender, damage, state)


func process_after_energy_attached_from_hand(player_index: int, target: PokemonSlot, state: GameState) -> void:
	if state == null or target == null or player_index < 0 or player_index >= state.players.size():
		return
	for source: PokemonSlot in state.players[player_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var effect := get_effect(source.get_card_data().effect_id)
		if effect != null and effect.has_method("on_energy_attached_from_hand"):
			effect.call("on_energy_attached_from_hand", source, player_index, target, state)
	if state.stadium_card != null and state.stadium_card.card_data != null:
		var stadium_effect := get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("on_any_player_energy_attached_from_hand"):
			stadium_effect.call("on_any_player_energy_attached_from_hand", player_index, target, state)


func apply_attack_damage_energy_reactive_effects(attacker: PokemonSlot, defender: PokemonSlot, damage: int, state: GameState) -> void:
	if attacker == null or defender == null or damage <= 0 or state == null:
		return
	var defender_owner := _get_owner_index(defender)
	var attacker_owner := _get_owner_index(attacker)
	if defender_owner < 0 or attacker_owner != 1 - defender_owner or state.players[defender_owner].active_pokemon != defender:
		return
	var attached_snapshot: Array[CardInstance] = defender.attached_energy.duplicate()
	for energy: CardInstance in attached_snapshot:
		if energy == null or energy.card_data == null or energy.card_data.card_type != "Special Energy" or is_special_energy_suppressed(energy, state):
			continue
		var energy_effect := get_effect(energy.card_data.effect_id)
		if energy_effect != null and energy_effect.has_method("on_attached_pokemon_damaged_by_opponent_attack"):
			energy_effect.call("on_attached_pokemon_damaged_by_opponent_attack", energy, defender, attacker, damage, state)


func get_energy_colorless_count(energy: CardInstance, state: GameState = null) -> int:
	if energy == null or energy.card_data == null:
		return 0
	if state != null and is_special_energy_suppressed(energy, state):
		return 1
	var effect: BaseEffect = get_effect(energy.card_data.effect_id)
	if effect is EffectDoubleColorless:
		return (effect as EffectDoubleColorless).provides_count
	if effect != null and effect.has_method("get_energy_count_for"):
		return int(effect.call("get_energy_count_for", energy, state))
	if effect is EffectSpecialEnergyModifier:
		return (effect as EffectSpecialEnergyModifier).energy_count
	if effect != null and effect.has_method("get_energy_count"):
		return int(effect.call("get_energy_count"))
	return 1


func get_energy_type(energy: CardInstance, state: GameState = null) -> String:
	if energy == null or energy.card_data == null:
		return "C"
	if state != null and is_special_energy_suppressed(energy, state):
		return "C"
	var effect: BaseEffect = get_effect(energy.card_data.effect_id)
	if effect != null and effect.has_method("get_energy_type_for"):
		return str(effect.call("get_energy_type_for", energy, state))
	if effect != null and effect.has_method("provides_any_type") and bool(effect.call("provides_any_type")):
		if state != null and effect.has_method("should_downgrade_to_colorless") and bool(effect.call("should_downgrade_to_colorless", energy, state)):
			return "C"
		return "ANY"
	if effect is EffectSpecialEnergyModifier:
		return (effect as EffectSpecialEnergyModifier).energy_type_provides
	if effect != null and effect.has_method("get_energy_type"):
		return str(effect.call("get_energy_type"))
	var provides: String = energy.card_data.energy_provides
	return provides if provides != "" else "C"


func get_energy_types(energy: CardInstance, state: GameState = null) -> PackedStringArray:
	if energy == null or energy.card_data == null:
		return PackedStringArray()
	if state != null and is_special_energy_suppressed(energy, state):
		return PackedStringArray(["C"])
	var effect: BaseEffect = get_effect(energy.card_data.effect_id)
	if effect != null and effect.has_method("get_energy_types_for"):
		return PackedStringArray(effect.call("get_energy_types_for", energy, state))
	return PackedStringArray([get_energy_type(energy, state)])


func is_ability_disabled(slot: PokemonSlot, state: GameState = null) -> bool:
	if slot == null:
		return false
	# 清除古龙水等通过 effects 数组标记的特性消除
	if state != null and EffectCancelCologne.is_slot_directly_ability_disabled(slot, state):
		return true
	if state != null:
		if AbilityBasicLock.is_locked_by_basic_lock(slot, state):
			return true
		if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state):
			return true
		if AbilityIronThornsInit.is_locked_by_init(slot, state):
			return true
		if AbilityBasicVLockScript.is_locked(slot, state):
			return true
		if AbilityTingLuCursedLandScript.is_locked_by_cursed_land(slot, state):
			return true
		if state.stadium_card != null and state.stadium_card.card_data != null:
			var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
			if stadium_effect != null and stadium_effect.has_method("suppresses_ability") and bool(stadium_effect.call("suppresses_ability", slot, state)):
				return true
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("disables_ability"):
			return bool(tool_effect.call("disables_ability", slot, state))
	return false


func is_special_energy_suppressed(energy: CardInstance, state: GameState) -> bool:
	if energy == null or energy.card_data == null or state == null:
		return false
	if energy.card_data.card_type != "Special Energy":
		return false
	if state.stadium_card == null:
		return false
	var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	return stadium_effect != null and stadium_effect.has_method("suppresses_special_energy_effects") and bool(stadium_effect.call("suppresses_special_energy_effects"))


func is_tool_effect_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or slot.attached_tool == null or state == null:
		return false
	if state.stadium_card == null:
		return false
	var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	return stadium_effect != null and stadium_effect.has_method("suppresses_tool_effects") and bool(stadium_effect.call("suppresses_tool_effects"))


func prevents_special_status(slot: PokemonSlot, state: GameState, status_name: String = "") -> bool:
	if slot == null or state == null:
		return false
	if EffectFestivalGrounds.prevents_special_status(slot, state):
		return true
	var card_data: CardData = slot.get_card_data()
	if card_data != null and not is_ability_disabled(slot, state):
		var pokemon_effect: BaseEffect = get_effect(card_data.effect_id)
		if pokemon_effect != null and pokemon_effect.has_method("prevents_special_status"):
			if bool(pokemon_effect.call("prevents_special_status", slot, state, status_name)):
				return true
	if slot.attached_tool == null or is_tool_effect_suppressed(slot, state):
		return false
	var effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
	return effect != null and effect.has_method("prevents_special_status") and bool(effect.call("prevents_special_status", slot, state, status_name))


func prevents_card_from_hand(player_index: int, card: CardInstance, state: GameState) -> bool:
	if card == null or card.card_data == null or state == null:
		return false
	if NoivernExEffectsScript.is_player_locked(player_index, state):
		var locked_card_type := str(card.card_data.card_type)
		if locked_card_type == "Special Energy" or locked_card_type == "Stadium":
			return true
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if source_effect == null:
			continue
		if source_effect.has_method("blocks_card_from_hand") and bool(source_effect.call("blocks_card_from_hand", source, card, player_index, state)):
			return true
		if source_effect.has_method("blocks_opponent_ace_spec") and bool(source_effect.call("blocks_opponent_ace_spec", source, player_index, card, state)):
			return true
	return false


func get_card_from_hand_block_reason(player_index: int, card: CardInstance, state: GameState) -> String:
	if card == null or card.card_data == null or state == null:
		return ""
	if NoivernExEffectsScript.is_player_locked(player_index, state):
		var locked_card_type := str(card.card_data.card_type)
		if locked_card_type == "Special Energy":
			return "受到对手招式效果影响，当前不能从手牌附着特殊能量。"
		if locked_card_type == "Stadium":
			return "受到对手招式效果影响，当前不能从手牌打出竞技场卡。"
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return ""
	for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if source_effect == null:
			continue
		if source_effect.has_method("blocks_card_from_hand") and bool(source_effect.call("blocks_card_from_hand", source, card, player_index, state)):
			return "受到对手 %s 的效果影响，当前不能从手牌使用这张卡。" % source.get_pokemon_name()
		if source_effect.has_method("blocks_opponent_ace_spec") and bool(source_effect.call("blocks_opponent_ace_spec", source, player_index, card, state)):
			return "受到对手 %s 的效果影响，当前不能使用 ACE SPEC 卡。" % source.get_pokemon_name()
	return ""


func get_effect_unusable_reason(card: CardInstance, state: GameState) -> String:
	if card == null or card.card_data == null:
		return "当前无法使用这张卡。"
	var effect: BaseEffect = get_effect(card.card_data.effect_id)
	if effect != null and effect.has_method("get_unusable_reason"):
		var reason := str(effect.call("get_unusable_reason", card, state))
		if reason != "":
			return reason
	return "%s 当前无法使用。" % card.card_data.name


func get_ability_unusable_reason(pokemon: PokemonSlot, state: GameState, ability_index: int = 0) -> String:
	if pokemon == null or pokemon.get_top_card() == null:
		return "当前没有可以使用特性的宝可梦。"
	var card_data: CardData = pokemon.get_card_data()
	var native_count: int = card_data.abilities.size() if card_data != null else 0
	if ability_index < native_count and is_ability_disabled(pokemon, state):
		return "%s 的特性当前被场上效果关闭。" % pokemon.get_pokemon_name()
	var effect: BaseEffect = get_ability_effect(pokemon, ability_index, state)
	if effect != null and effect.has_method("get_ability_unusable_reason"):
		var reason := str(effect.call("get_ability_unusable_reason", pokemon, state))
		if reason != "":
			return reason
	if effect == null:
		return "%s 当前没有可执行的特性。" % pokemon.get_pokemon_name()
	if not can_use_ability(pokemon, state, ability_index):
		return "%s 当前无法使用这个特性。" % pokemon.get_pokemon_name()
	return ""


func slot_allows_early_evolution(slot: PokemonSlot, player_index: int, state: GameState) -> bool:
	if slot == null or slot.get_card_data() == null or state == null:
		return false
	if is_ability_disabled(slot, state):
		return false
	var effect: BaseEffect = _get_registered_pokemon_effect(slot)
	if effect == null:
		return false
	if effect.has_method("allows_early_evolution"):
		return bool(effect.call("allows_early_evolution", slot, player_index, state))
	if effect.has_method("allows_fast_evolution"):
		return bool(effect.call("allows_fast_evolution", slot, state))
	return false


func slot_allows_evolution_from_hand_onto_self(
	slot: PokemonSlot,
	evolution: CardInstance,
	player_index: int,
	state: GameState
) -> bool:
	if slot == null or slot.get_card_data() == null or evolution == null or evolution.card_data == null or state == null:
		return false
	if is_ability_disabled(slot, state):
		return false
	var effect: BaseEffect = get_effect(slot.get_card_data().effect_id)
	if effect == null or not effect.has_method("allows_evolution_from_hand_onto_self"):
		return false
	return bool(effect.call("allows_evolution_from_hand_onto_self", slot, evolution, player_index, state))


func apply_attack_knockout_extra_prize_effects(attacker: PokemonSlot, knocked_out: PokemonSlot, state: GameState) -> void:
	if attacker == null or knocked_out == null or state == null:
		return
	var attacker_owner := _get_owner_index(attacker)
	if attacker_owner < 0:
		return
	for source: PokemonSlot in state.players[attacker_owner].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if source_effect == null:
			continue
		if source_effect.has_method("try_add_attack_knockout_extra_prize"):
			source_effect.call("try_add_attack_knockout_extra_prize", source, attacker, knocked_out, state)
		elif source_effect.has_method("get_extra_prize_for_active_knockout"):
			var extra := int(source_effect.call("get_extra_prize_for_active_knockout", source, knocked_out, state))
			if extra > 0:
				knocked_out.effects.append({"type": "extra_prize", "count": extra, "source": "field_ability"})
	if CSV9C202Briar.should_apply_extra_prize(state, attacker, knocked_out):
		CSV9CEffects.add_extra_prize_once(knocked_out, "csv9c_briar", 1)


func apply_attack_damage_knockout_reactive_effects(attacker: PokemonSlot, knocked_out: PokemonSlot, state: GameState) -> void:
	if attacker == null or knocked_out == null or state == null:
		return
	if knocked_out.get_card_data() == null or is_ability_disabled(knocked_out, state):
		return
	var effect: BaseEffect = get_effect(knocked_out.get_card_data().effect_id)
	if effect != null and effect.has_method("on_knocked_out_by_attack_damage"):
		effect.call("on_knocked_out_by_attack_damage", knocked_out, attacker, state)


func apply_knockout_prize_prevention_ability(knocked_out: PokemonSlot, state: GameState) -> bool:
	if knocked_out == null or knocked_out.get_card_data() == null or state == null:
		return false
	if is_ability_disabled(knocked_out, state):
		return false
	var effect := _get_registered_pokemon_effect(knocked_out)
	if effect == null or not effect.has_method("try_prevent_knockout_prizes"):
		return false
	return bool(effect.call("try_prevent_knockout_prizes", knocked_out, state))


func get_knockout_prize_modifier(slot: PokemonSlot, state: GameState) -> int:
	if slot == null:
		return 0
	var total: int = 0
	if slot.attached_tool != null and not is_tool_effect_suppressed(slot, state):
		var tool_effect: BaseEffect = get_effect(slot.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("get_knockout_prize_modifier"):
			total += int(tool_effect.call("get_knockout_prize_modifier", slot, state))
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect != null and effect.has_method("get_knockout_prize_modifier"):
			total += int(effect.call("get_knockout_prize_modifier", slot, state))
	return total


func mark_knockout_prize_modifier_consumed(slot: PokemonSlot, state: GameState) -> void:
	if slot == null:
		return
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect != null and effect.has_method("mark_knockout_prize_modifier_consumed"):
			effect.call("mark_knockout_prize_modifier_consumed", slot, state)


## 检查宝可梦是否附有薄雾能量（免疫对手招式效果）
func has_mist_energy_protection(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		if energy.card_data.effect_id == "fb0948c721db1f31767aa6cf0c2ea692":
			return true
	return false


func is_damage_prevented_by_defender_ability(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null:
		return false
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(defender, state):
		return true
	if CSV9CEffects.prevents_damage_from_attack_effect(attacker, defender, state):
		return true
	if state != null and state.stadium_card != null and state.stadium_card.card_data != null:
		var stadium_effect := get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("prevents_attack_damage"):
			if bool(stadium_effect.call("prevents_attack_damage", attacker, defender, state)):
				return true
	if is_ability_disabled(defender, state):
		return false
	var effect: BaseEffect = get_effect(defender.get_card_data().effect_id)
	if effect != null and effect.has_method("prevents_damage_from"):
		return bool(effect.call("prevents_damage_from", attacker, defender, state))
	return false


func is_attack_effect_prevented_by_defender_ability(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null:
		return false
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(defender, state):
		return true
	if has_mist_energy_protection(defender, state):
		return true
	if not is_ability_disabled(defender, state):
		if AbilityIgnoreEffects.has_ignore_effects(defender):
			return true
		var effect: BaseEffect = get_effect(defender.get_card_data().effect_id)
		if effect != null and effect.has_method("prevents_effects_from"):
			if bool(effect.call("prevents_effects_from", attacker, defender, state)):
				return true
	var owner_index := _get_owner_index(defender)
	if owner_index >= 0 and owner_index < state.players.size():
		for source: PokemonSlot in state.players[owner_index].get_all_pokemon():
			if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
				continue
			var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
			if source_effect != null and source_effect.has_method("prevents_attack_effects_to_target"):
				if bool(source_effect.call("prevents_attack_effects_to_target", source, defender, attacker, state)):
					return true
	return false


func is_protected_from_opponent_hand_trainer_effect(target: PokemonSlot, trainer: CardInstance, state: GameState) -> bool:
	if target == null or target.get_card_data() == null or trainer == null or trainer.card_data == null or state == null:
		return false
	if trainer.card_data.card_type not in ["Item", "Supporter"] or target.get_top_card() == null or trainer.owner_index == target.get_top_card().owner_index:
		return false
	if is_ability_disabled(target, state):
		return false
	var effect := get_effect(target.get_card_data().effect_id)
	return effect != null and effect.has_method("prevents_opponent_hand_trainer_effect") and bool(effect.call("prevents_opponent_hand_trainer_effect", target, trainer, state))


func sanitize_opponent_hand_trainer_targets(trainer: CardInstance, targets: Array, state: GameState) -> Array:
	var sanitized: Array = []
	for value: Variant in targets:
		var filtered: Variant = _sanitize_opponent_hand_trainer_target_value(trainer, value, state)
		if filtered != null:
			sanitized.append(filtered)
	return sanitized


func _sanitize_opponent_hand_trainer_target_value(trainer: CardInstance, value: Variant, state: GameState) -> Variant:
	if value is PokemonSlot:
		return null if is_protected_from_opponent_hand_trainer_effect(value, trainer, state) else value
	if value is Array:
		var filtered_array: Array = []
		for entry: Variant in value:
			var filtered_entry: Variant = _sanitize_opponent_hand_trainer_target_value(trainer, entry, state)
			if filtered_entry != null:
				filtered_array.append(filtered_entry)
		return filtered_array
	if value is Dictionary:
		var filtered_dict: Dictionary = {}
		for key: Variant in value.keys():
			filtered_dict[key] = _sanitize_opponent_hand_trainer_target_value(trainer, value[key], state)
		return filtered_dict
	return value


func process_pokemon_check(state: GameState) -> Array[PokemonSlot]:
	var damaged_slots: Array[PokemonSlot] = []
	state.shared_turn_flags["_draw_effect_processor"] = self
	for pi: int in 2:
		var player: PlayerState = state.players[pi]
		var slot: PokemonSlot = player.active_pokemon
		if slot == null:
			continue
		if prevents_special_status(slot, state):
			slot.clear_all_status()
		else:
			_clear_prevented_special_statuses(slot, state)
		var took_damage := false
		if slot.status_conditions.get("poisoned", false):
			slot.damage_counters += 10 + get_poison_damage_bonus(slot, state)
			took_damage = true
		if slot.status_conditions.get("burned", false):
			slot.damage_counters += 20 + get_burn_damage_bonus(slot, state)
			took_damage = true
			if coin_flipper.flip():
				slot.status_conditions["burned"] = false
		if slot.status_conditions.get("asleep", false) and coin_flipper.flip():
			slot.status_conditions["asleep"] = false
		if pi == state.current_player_index and slot.status_conditions.get("paralyzed", false):
			slot.status_conditions["paralyzed"] = false
		if took_damage:
			damaged_slots.append(slot)
	_process_pokemon_check_abilities(state, damaged_slots)
	_process_delayed_end_turn_discards(state)
	return damaged_slots


func _process_delayed_end_turn_discards(state: GameState) -> void:
	if state == null or state.current_player_index < 0 or state.current_player_index >= state.players.size():
		return
	var player := state.players[state.current_player_index]
	var affected: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for marker: Dictionary in slot.effects:
			if marker.get("type", "") != "csv10c_delayed_discard_end_turn":
				continue
			if int(marker.get("source_owner", -1)) == state.current_player_index:
				continue
			if int(marker.get("turn", state.turn_number)) >= state.turn_number:
				continue
			affected.append(slot)
			break
	for slot: PokemonSlot in affected:
		for card: CardInstance in slot.collect_all_cards():
			card.face_up = true
			player.discard_pile.append(card)
		slot.pokemon_stack.clear()
		slot.attached_energy.clear()
		slot.attached_tool = null
		slot.effects.clear()
		slot.clear_all_status()
		if player.active_pokemon == slot:
			player.active_pokemon = null
		else:
			player.bench.erase(slot)


func _process_pokemon_check_abilities(state: GameState, damaged_slots: Array[PokemonSlot]) -> void:
	if state == null:
		return
	for pi: int in 2:
		for source: PokemonSlot in state.players[pi].get_all_pokemon():
			if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
				continue
			var effect := get_effect(source.get_card_data().effect_id)
			if effect != null and effect.has_method("process_pokemon_check"):
				effect.call("process_pokemon_check", source, state, damaged_slots)


func _clear_prevented_special_statuses(slot: PokemonSlot, state: GameState) -> void:
	for status_name: String in ["poisoned", "burned", "asleep", "paralyzed", "confused"]:
		if slot.status_conditions.get(status_name, false) and prevents_special_status(slot, state, status_name):
			slot.status_conditions[status_name] = false


func get_poison_damage_bonus(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return 0
	var total := 0
	for applied_effect: Dictionary in slot.effects:
		if applied_effect.get("type", "") == "csv10c_poison_damage_bonus":
			total += maxi(0, int(applied_effect.get("amount", 0)))
	var owner_index := _get_owner_index(slot)
	if owner_index >= 0:
		var opponent_index := 1 - owner_index
		if opponent_index >= 0 and opponent_index < state.players.size():
			for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
				if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
					continue
				var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
				if source_effect != null and source_effect.has_method("get_poison_damage_bonus_for_target"):
					total += int(source_effect.call("get_poison_damage_bonus_for_target", source, slot, state))
	if state.stadium_card != null:
		var stadium_effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
		if stadium_effect != null and stadium_effect.has_method("get_poison_damage_bonus"):
			total += int(stadium_effect.call("get_poison_damage_bonus", slot, state))
	return total


func get_attack_effect_preview_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState,
	targets: Array = []
) -> int:
	var preview_damage := -1
	for effect: BaseEffect in get_attack_effects_for_slot(attacker, attack_index):
		if not effect.has_method("get_attack_preview_damage"):
			continue
		if state != null:
			state.shared_turn_flags["_draw_effect_processor"] = self
		effect.set_attack_interaction_context(targets)
		preview_damage = max(
			preview_damage,
			int(effect.call("get_attack_preview_damage", attacker, defender, state))
		)
		effect.clear_attack_interaction_context()
	return preview_damage


func get_burn_damage_bonus(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return 0
	var total := 0
	var owner_index := _get_owner_index(slot)
	if owner_index < 0:
		return 0
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var source_effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if source_effect != null and source_effect.has_method("get_burn_damage_bonus_for_target"):
			total += int(source_effect.call("get_burn_damage_bonus_for_target", source, slot, state))
	return total


func get_knockout_attached_cards_to_hand(slot: PokemonSlot, state: GameState, knocked_out_by_attack_damage: bool) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if slot == null or slot.get_card_data() == null or state == null or not knocked_out_by_attack_damage:
		return result
	var owner_index := _get_owner_index(slot)
	if owner_index < 0 or owner_index >= state.players.size():
		return result
	for source: PokemonSlot in state.players[owner_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if effect == null or not effect.has_method("knockout_attached_cards_to_hand"):
			continue
		var returned: Variant = effect.call("knockout_attached_cards_to_hand", source, slot, state)
		if not (returned is Array):
			continue
		for card: Variant in returned:
			if card is CardInstance and card in slot.attached_energy and card not in result:
				result.append(card)
	return result


func attack_active_damage_is_interaction_invariant(
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState
) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var card := attacker.get_top_card()
	var card_data := attacker.get_card_data()
	if card_data == null or attack_index < 0 or attack_index >= card_data.attacks.size():
		return false
	var attack: Dictionary = card_data.attacks[attack_index]
	for effect: BaseEffect in get_attack_effects_for_slot(attacker, attack_index):
		var steps := effect.get_attack_preview_interaction_steps(card, attack, state)
		if steps.is_empty():
			continue
		if not effect.has_method("active_damage_is_invariant_under_interaction") \
				or not bool(effect.call("active_damage_is_invariant_under_interaction", attack_index)):
			return false
	return true


func has_attack_damage_survival_hook(defender: PokemonSlot, state: GameState) -> bool:
	if defender == null or state == null:
		return true
	if defender.get_card_data() != null and not is_ability_disabled(defender, state):
		var native_effect := get_effect(defender.get_card_data().effect_id)
		if native_effect != null and native_effect.has_method("try_prevent_attack_knockout"):
			return true
	if defender.attached_tool != null and not is_tool_effect_suppressed(defender, state):
		var tool_effect := get_effect(defender.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("try_prevent_attack_knockout"):
			return true
	return false


func has_attack_damage_reactive_hook(defender: PokemonSlot, state: GameState) -> bool:
	if defender == null or state == null:
		return true
	if defender.get_card_data() != null:
		var native_effect := get_effect(defender.get_card_data().effect_id)
		if native_effect != null and native_effect.has_method("on_damaged_by_attack"):
			var remains_live_when_disabled := native_effect.has_method("is_attack_damage_reactive_effect") \
				and bool(native_effect.call("is_attack_damage_reactive_effect"))
			if remains_live_when_disabled or not is_ability_disabled(defender, state):
				return true
	if defender.attached_tool != null and not is_tool_effect_suppressed(defender, state):
		var tool_effect := get_effect(defender.attached_tool.card_data.effect_id)
		if tool_effect != null and tool_effect.has_method("on_damaged_by_attack"):
			return true
	for energy: CardInstance in defender.attached_energy:
		if energy == null or energy.card_data == null or energy.card_data.card_type != "Special Energy":
			continue
		if is_special_energy_suppressed(energy, state):
			continue
		var energy_effect := get_effect(energy.card_data.effect_id)
		if energy_effect != null and energy_effect.has_method("on_attached_pokemon_damaged_by_opponent_attack"):
			return true
	return false


func process_after_evolution_from_hand(player_index: int, evolved_slot: PokemonSlot, state: GameState) -> void:
	if state == null or evolved_slot == null or player_index < 0 or player_index >= state.players.size():
		return
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	for source: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if effect != null and effect.has_method("on_opponent_evolved_from_hand"):
			effect.call("on_opponent_evolved_from_hand", source, evolved_slot, player_index, state)
			return


func _get_ability_attack_modifier(attacker: PokemonSlot, state: GameState, pi: int, defender: PokemonSlot = null) -> int:
	var total: int = 0
	var player: PlayerState = state.players[pi]
	total += AbilityFutureDamageBoost.get_future_damage_boost(player, attacker)
	total += AbilityLightningBoost.get_lightning_boost(player, attacker)
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_ability_disabled(slot, state):
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var effect: BaseEffect = _get_registered_pokemon_effect(slot)
		if effect is AbilityFutureDamageBoost:
			continue
		if effect is AbilityDamageModifier:
			var mod: AbilityDamageModifier = effect as AbilityDamageModifier
			if mod.is_attack_modifier() and (not mod.self_only or slot == attacker):
				total += mod.get_modifier()
		if effect != null:
			if effect.has_method("get_attack_modifier_for_attacker"):
				total += int(effect.call("get_attack_modifier_for_attacker", slot, attacker, state, defender))
			if effect.has_method("get_attack_modifier_for_source"):
				total += int(effect.call("get_attack_modifier_for_source", slot, attacker, state))
	return total


func _get_ability_defense_modifier(defender: PokemonSlot, state: GameState, pi: int, attacker: PokemonSlot = null) -> int:
	var total: int = 0
	var player: PlayerState = state.players[pi]
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_ability_disabled(slot, state):
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var effect: BaseEffect = _get_registered_pokemon_effect(slot)
		if effect is AbilityDamageModifier:
			var mod: AbilityDamageModifier = effect as AbilityDamageModifier
			if mod.is_defense_modifier() and (not mod.self_only or slot == defender):
				total += mod.get_modifier()
		if effect != null:
			if effect.has_method("get_defense_modifier_for_defender"):
				total += int(effect.call("get_defense_modifier_for_defender", slot, defender, state))
			if effect.has_method("get_team_defense_modifier"):
				total += int(effect.call("get_team_defense_modifier", slot, defender, attacker, state))
	return total


func _get_tool_attack_modifier(attacker: PokemonSlot, state: GameState, defender: PokemonSlot = null) -> int:
	if attacker.attached_tool == null or is_tool_effect_suppressed(attacker, state):
		return 0
	var effect: BaseEffect = get_effect(attacker.attached_tool.card_data.effect_id)
	if effect is EffectToolDamageModifier:
		var tool_mod: EffectToolDamageModifier = effect as EffectToolDamageModifier
		if tool_mod.is_attack_modifier():
			return tool_mod.damage_modifier
	elif effect is EffectToolConditionalDamage:
		var conditional_mod: EffectToolConditionalDamage = effect as EffectToolConditionalDamage
		return conditional_mod.get_attack_modifier(attacker, state, defender)
	elif effect is EffectToolFutureBoost:
		return (effect as EffectToolFutureBoost).get_attack_bonus(attacker)
	elif effect != null and effect.has_method("get_attack_modifier"):
		return int(effect.call("get_attack_modifier", attacker, state))
	return 0


func _get_tool_defense_modifier(defender: PokemonSlot, state: GameState, attacker: PokemonSlot = null) -> int:
	if defender.attached_tool == null or is_tool_effect_suppressed(defender, state):
		return 0
	var effect: BaseEffect = get_effect(defender.attached_tool.card_data.effect_id)
	if effect is EffectToolDamageModifier:
		var tool_mod: EffectToolDamageModifier = effect as EffectToolDamageModifier
		if tool_mod.is_defense_modifier():
			return tool_mod.damage_modifier
	elif effect != null and effect.has_method("get_defense_modifier"):
		return int(effect.call("get_defense_modifier", defender, state, attacker))
	return 0


func _get_stadium_attack_modifier(attacker: PokemonSlot, state: GameState) -> int:
	if state.stadium_card == null:
		return 0
	var effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	if effect is EffectStadiumDamageModifier:
		var stadium_mod: EffectStadiumDamageModifier = effect as EffectStadiumDamageModifier
		if stadium_mod.is_attack_modifier() and stadium_mod.matches_pokemon(attacker):
			if not stadium_mod.owner_only:
				return stadium_mod.modifier_amount
			var pi: int = _get_owner_index(attacker)
			if pi == state.stadium_owner_index:
				return stadium_mod.modifier_amount
	elif effect != null and effect.has_method("get_attack_modifier"):
		return int(effect.call("get_attack_modifier", attacker, state))
	return 0


func _get_stadium_defense_modifier(defender: PokemonSlot, state: GameState) -> int:
	if state.stadium_card == null:
		return 0
	var effect: BaseEffect = get_effect(state.stadium_card.card_data.effect_id)
	if effect is EffectStadiumDamageModifier:
		var stadium_mod: EffectStadiumDamageModifier = effect as EffectStadiumDamageModifier
		if stadium_mod.is_defense_modifier() and stadium_mod.matches_pokemon(defender):
			if not stadium_mod.owner_only:
				return stadium_mod.modifier_amount
			var pi: int = _get_owner_index(defender)
			if pi == state.stadium_owner_index:
				return stadium_mod.modifier_amount
	elif effect != null and effect.has_method("get_defense_modifier"):
		return int(effect.call("get_defense_modifier", defender, state))
	return 0


func _defender_ignores_weakness(defender: PokemonSlot, state: GameState) -> bool:
	if defender == null or state == null:
		return false
	var owner_index := _get_owner_index(defender)
	if owner_index < 0:
		return false
	for source: PokemonSlot in state.players[owner_index].get_all_pokemon():
		if source == null or source.get_card_data() == null or is_ability_disabled(source, state):
			continue
		var effect: BaseEffect = get_effect(source.get_card_data().effect_id)
		if effect != null and effect.has_method("ignores_weakness_when_defending"):
			if bool(effect.call("ignores_weakness_when_defending", defender, state)):
				return true
	return false


func _get_energy_defense_modifier(defender: PokemonSlot, attacker: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	var v_guard_applied: bool = false
	for energy: CardInstance in defender.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect == null:
			continue
		if effect is EffectVGuardEnergy and attacker != null:
			if not v_guard_applied:
				var vg: EffectVGuardEnergy = effect as EffectVGuardEnergy
				var mod: int = vg.get_defense_modifier(attacker)
				if mod != 0:
					total += mod
					v_guard_applied = true
		elif effect.has_method("get_defense_modifier") and attacker != null:
			total += int(effect.call("get_defense_modifier", attacker))
	return total


func _get_energy_attack_modifier(attacker: PokemonSlot, state: GameState) -> int:
	var total: int = 0
	for energy: CardInstance in attacker.attached_energy:
		if is_special_energy_suppressed(energy, state):
			continue
		var effect: BaseEffect = get_effect(energy.card_data.effect_id)
		if effect is EffectSpecialEnergyModifier:
			total += (effect as EffectSpecialEnergyModifier).damage_modifier
		elif effect != null and effect.has_method("get_attack_modifier"):
			total += int(effect.call("get_attack_modifier", attacker, state))
	return total


func _get_owner_index(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return slot.get_top_card().owner_index
