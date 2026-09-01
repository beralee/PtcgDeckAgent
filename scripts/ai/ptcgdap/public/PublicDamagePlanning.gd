class_name PublicDamagePlanning
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const REGISTRY_PATH := "res://contracts/ptcgdap/public_damage_capability_registry_v1.json"
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_SEALED_EXECUTION_PLAN_CACHE := 128
const CAPABILITY_IDS := {
	"attack.fixed_split.v1": true,
	"attack.bench_heal.v1": true,
	"between_turn.ability_counter.v1": true,
	"ability.move_damage_counters.v1": true,
	"tool.conditional_active_damage_bonus.v1": true,
	"attack.mass_devolution.v1": true,
}
const OBJECTIVES := [
	"attack_windows", "prize_yield", "remaining_debt", "overkill", "response_risk",
]
const TARGET_ROLES := {"opponent.active": true, "opponent.bench": true}
const PRIVATE_KEYS := {
	"deck_order": true, "private_state": true, "search_begin_input": true,
	"callback": true, "binding": true, "ticket": true, "command": true,
	"object_ref": true, "instance_id": true, "raw_private_hash": true,
}
const TRANSACTION_STATE_KEYS := [
	"transaction_id", "goal_id", "phase", "target_entity_serial",
	"remaining_damage_debt", "remaining_energy_debt", "deadline_turn",
]

static var _registry_cache: Dictionary = {}
static var _registry_cache_validated := false
static var _registry_cache_hash := ""
static var _sealed_execution_plans: Dictionary = {}
static var _sealed_execution_plan_order: Array[String] = []


static func load_default_registry() -> Dictionary:
	var trusted := _load_default_registry_reference()
	return trusted.duplicate(true) if not trusted.is_empty() else {}


static func _load_default_registry_reference() -> Dictionary:
	if _registry_cache_validated:
		if (
			_registry_cache.is_empty()
			or str(_registry_cache.get("registry_sha256", "")) != _registry_cache_hash
		):
			_registry_cache.clear()
			_registry_cache_hash = ""
			_registry_cache_validated = false
			return {}
		return _registry_cache
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not validate_registry(parsed):
		return {}
	_registry_cache = (parsed as Dictionary).duplicate(true)
	_registry_cache_hash = str(_registry_cache.get("registry_sha256", ""))
	_registry_cache_validated = true
	return _registry_cache


static func validate_registry(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var registry: Dictionary = value
	if registry.get("schema_version") != 1 \
		or registry.get("profile_id") != "ptcgdap-public-damage-capability-registry-v1" \
		or registry.get("card_identity_domain") != "godot_local_card_uid_v1" \
		or not registry.get("cards") is Dictionary \
		or not registry.get("capabilities") is Array:
		return false
	var capability_set := {}
	for capability: Variant in registry.get("capabilities", []):
		capability_set[str(capability)] = true
	if capability_set != CAPABILITY_IDS:
		return false
	var payload := registry.duplicate(true)
	var expected := str(payload.get("registry_sha256", ""))
	payload.erase("registry_sha256")
	if expected != _canonical_sha256(payload):
		return false
	for uid: Variant in registry.get("cards", {}):
		if not _local_uid(uid):
			return false
		var card: Variant = registry.get("cards", {}).get(uid)
		if not card is Dictionary:
			return false
		for capability: Variant in card.get("capability_ids", []):
			if not CAPABILITY_IDS.has(capability):
				return false
	return true


static func validate_damage_plans(value: Variant, registry: Dictionary = {}) -> String:
	var using_default := registry.is_empty()
	var trusted := registry if not using_default else _load_default_registry_reference()
	if trusted.is_empty() or (not using_default and not validate_registry(trusted)):
		return "invalid_damage_capability_registry"
	return _validate_damage_plans_trusted(value, trusted)


static func _validate_damage_plans_trusted(value: Variant, trusted: Dictionary) -> String:
	if not value is Array or value.is_empty() or value.size() > 32:
		return "invalid_damage_plan"
	var seen := {}
	var required := [
		"plan_id", "goal_id", "priority", "horizon_attack_windows", "capability_ids",
		"target_roles", "objective_order",
	]
	for plan_value: Variant in value:
		if not plan_value is Dictionary or not _exact_keys(plan_value, required):
			return "invalid_damage_plan"
		var plan: Dictionary = plan_value
		var plan_id := str(plan.get("plan_id", ""))
		if not _identifier(plan_id) or seen.has(plan_id):
			return "invalid_damage_plan"
		seen[plan_id] = true
		var capabilities: Variant = plan.get("capability_ids")
		if not capabilities is Array or capabilities.is_empty() \
			or capabilities.size() != _unique_count(capabilities):
			return "invalid_damage_plan"
		for capability: Variant in capabilities:
			if capability not in trusted.get("capabilities", []):
				return "unknown_damage_capability"
		if not _identifier(str(plan.get("goal_id", ""))) \
			or not _safe_int(plan.get("priority")) \
			or int(plan.get("horizon_attack_windows", 0)) not in [1, 2] \
			or not plan.get("target_roles") is Array \
			or plan.get("target_roles", []).is_empty() \
			or plan.get("objective_order") != OBJECTIVES:
			return "invalid_damage_plan"
		for role: Variant in plan.get("target_roles", []):
			if not TARGET_ROLES.has(role):
				return "invalid_damage_plan"
	return ""


static func validate_semantic_transactions(value: Variant) -> String:
	var required := [
		"transaction_id", "goal_id", "priority", "max_own_turns", "target_role",
		"start_when", "continue_when", "success_when", "abort_when", "step_prompt_kinds",
	]
	if not value is Array or value.is_empty() or value.size() > 32:
		return "invalid_semantic_transaction"
	var seen := {}
	for raw: Variant in value:
		if not raw is Dictionary or not _exact_keys(raw, required):
			return "invalid_semantic_transaction"
		var definition: Dictionary = raw
		var identifier := str(definition.get("transaction_id", ""))
		if not _identifier(identifier) or seen.has(identifier):
			return "invalid_semantic_transaction"
		seen[identifier] = true
		if not _identifier(str(definition.get("goal_id", ""))) \
			or not _safe_int(definition.get("priority")) \
			or int(definition.get("max_own_turns", 0)) not in [1, 2] \
			or definition.get("target_role") not in ["opponent.pokemon", "self.pokemon"] \
			or not definition.get("step_prompt_kinds") is Array \
			or definition.get("step_prompt_kinds", []).is_empty():
			return "invalid_semantic_transaction"
		for key: String in ["start_when", "continue_when", "success_when", "abort_when"]:
			if not definition.get(key) is Array or definition.get(key, []).size() > 32:
				return "invalid_semantic_transaction"
	return ""


static func compile_execution_plan(
	policy_hash: Variant,
	damage_plans: Variant,
	semantic_transactions: Variant = [],
) -> Dictionary:
	if not _is_sha(policy_hash) or not damage_plans is Array \
		or not semantic_transactions is Array:
		return _execution_plan_error("invalid_damage_execution_plan")
	var trusted := _load_default_registry_reference()
	if trusted.is_empty():
		return _execution_plan_error("invalid_damage_capability_registry")
	if not damage_plans.is_empty():
		var damage_error := _validate_damage_plans_trusted(damage_plans, trusted)
		if not damage_error.is_empty():
			return _execution_plan_error(damage_error)
	if not semantic_transactions.is_empty():
		var transaction_error := validate_semantic_transactions(semantic_transactions)
		if not transaction_error.is_empty():
			return _execution_plan_error(transaction_error)
	var payload := {
		"schema_version": 1,
		"profile_id": "ptcgdap-public-damage-execution-plan-v1",
		"policy_hash": str(policy_hash),
		"registry_sha256": _registry_cache_hash,
		"damage_plans": damage_plans,
		"semantic_transactions": semantic_transactions,
	}
	var execution_plan_hash := _tree_hash(payload)
	if not _is_sha(execution_plan_hash):
		return _execution_plan_error("invalid_damage_execution_plan")
	if not _sealed_execution_plans.has(execution_plan_hash):
		while _sealed_execution_plan_order.size() >= MAX_SEALED_EXECUTION_PLAN_CACHE:
			var evicted_hash: String = _sealed_execution_plan_order.pop_front()
			_sealed_execution_plans.erase(evicted_hash)
		_sealed_execution_plans[execution_plan_hash] = {
			"execution_plan_hash": execution_plan_hash,
			"policy_hash": str(policy_hash),
			"registry_sha256": _registry_cache_hash,
			# The registry reference is private to this module and read-only by
			# convention. Public callers only receive hashes and copied definitions.
			"registry": trusted,
			"damage_plans": damage_plans.duplicate(true),
			"semantic_transactions": semantic_transactions.duplicate(true),
		}
		_sealed_execution_plan_order.append(execution_plan_hash)
	return {
		"accepted": true,
		"error_code": "",
		"execution_plan_hash": execution_plan_hash,
		"policy_hash": str(policy_hash),
		"registry_sha256": _registry_cache_hash,
	}


static func calculate_compiled(
	frame: Variant,
	policy_hash: Variant,
	execution_plan_hash: Variant,
	include_full_audit: bool = true,
) -> Dictionary:
	if _contains_private(frame):
		return _error("private_damage_plan_input")
	var binding_error := _execution_plan_binding_error(policy_hash, execution_plan_hash)
	if not binding_error.is_empty():
		return _error(binding_error)
	var sealed: Dictionary = _sealed_execution_plans.get(str(execution_plan_hash), {})
	if not frame is Dictionary or sealed.get("damage_plans", []).is_empty():
		return _error("invalid_damage_plan_input")
	return _calculate_prevalidated(
		frame,
		sealed.get("damage_plans", []),
		sealed.get("registry", {}),
		include_full_audit
	)


static func compiled_semantic_transactions(
	policy_hash: Variant, execution_plan_hash: Variant
) -> Dictionary:
	var binding_error := _execution_plan_binding_error(policy_hash, execution_plan_hash)
	if not binding_error.is_empty():
		return _execution_plan_error(binding_error)
	var sealed: Dictionary = _sealed_execution_plans.get(str(execution_plan_hash), {})
	var definitions: Variant = sealed.get("semantic_transactions")
	if not definitions is Array or definitions.is_empty():
		return _execution_plan_error("semantic_transaction_unavailable")
	return {
		"accepted": true,
		"error_code": "",
		"definitions": definitions.duplicate(true),
		"execution_plan_hash": str(execution_plan_hash),
		"policy_hash": str(policy_hash),
		"registry_sha256": sealed.get("registry_sha256"),
	}


static func _execution_plan_binding_error(
	policy_hash: Variant, execution_plan_hash: Variant
) -> String:
	if not _is_sha(policy_hash) or not _is_sha(execution_plan_hash):
		return "damage_execution_plan_binding_mismatch"
	var sealed: Variant = _sealed_execution_plans.get(str(execution_plan_hash))
	if not sealed is Dictionary:
		return "damage_execution_plan_unavailable"
	if sealed.get("policy_hash") != policy_hash \
		or sealed.get("execution_plan_hash") != execution_plan_hash:
		return "damage_execution_plan_binding_mismatch"
	var trusted := _load_default_registry_reference()
	if trusted.is_empty() \
		or sealed.get("registry_sha256") != _registry_cache_hash:
		return "damage_execution_plan_registry_changed"
	return ""


static func calculate(frame: Variant, damage_plans: Variant, registry: Dictionary = {}) -> Dictionary:
	if _contains_private(frame) or _contains_private(damage_plans):
		return _error("private_damage_plan_input")
	var using_default := registry.is_empty()
	var trusted := registry if not using_default else _load_default_registry_reference()
	if not frame is Dictionary or trusted.is_empty() \
		or (not using_default and not validate_registry(trusted)):
		return _error("invalid_damage_plan_input")
	var plan_error := _validate_damage_plans_trusted(damage_plans, trusted)
	if not plan_error.is_empty():
		return _error(plan_error)
	return _calculate_prevalidated(frame, damage_plans, trusted)


static func _calculate_prevalidated(
	frame: Dictionary,
	damage_plans: Array,
	trusted: Dictionary,
	include_full_audit: bool = true,
) -> Dictionary:
	var own: Variant = frame.get("public_state", {}).get("self")
	var opponent: Variant = frame.get("public_state", {}).get("opponent")
	if not own is Dictionary or not opponent is Dictionary:
		return _error("invalid_damage_plan_input")
	var own_slots := _slots(own)
	var opponent_slots := _slots(opponent)
	var all_slots := own_slots + opponent_slots
	for slot_value: Variant in all_slots:
		if _card(trusted, str(slot_value.get("local_card_uid", ""))).is_empty():
			return _error("unknown_damage_card_uid")
	var froslass_checks := 0
	for slot_value: Variant in all_slots:
		var card := _card(trusted, str(slot_value.get("local_card_uid", "")))
		if "between_turn.ability_counter.v1" in card.get("capability_ids", []):
			froslass_checks += 1
	var movable_counters := 0
	var ready_movers := 0
	for slot_value: Variant in own_slots:
		var slot: Dictionary = slot_value
		movable_counters += maxi(0, int(slot.get("damage_counters", 0))) / 10
		var card := _card(trusted, str(slot.get("local_card_uid", "")))
		if "ability.move_damage_counters.v1" in card.get("capability_ids", []) \
			and "CSVE1C_DAR" in slot.get("attached_energy_uids", []):
			ready_movers += 1
	var available_movers := ready_movers
	if frame.get("prompt_kind") in ["main", "main_action"]:
		var legal_mover_entities := {}
		var own_by_entity := {}
		for slot_value: Variant in own_slots:
			own_by_entity[int(slot_value.get("entity_serial", 0))] = slot_value
		for option_value: Variant in frame.get("options", []):
			if not option_value is Dictionary or option_value.get("kind") != "use_ability":
				continue
			var source_entity: Variant = option_value.get("source_entity_serial")
			var source_slot: Variant = own_by_entity.get(source_entity)
			var source_uid := str(option_value.get("source_uid", ""))
			if source_uid.is_empty() and source_slot is Dictionary:
				source_uid = str(source_slot.get("local_card_uid", ""))
			var source_card := _card(trusted, source_uid)
			if source_slot is Dictionary \
					and "ability.move_damage_counters.v1" in source_card.get("capability_ids", []) \
					and "CSVE1C_DAR" in source_slot.get("attached_energy_uids", []):
				legal_mover_entities[int(source_entity)] = true
		available_movers = legal_mover_entities.size()
	var transferable := mini(movable_counters, available_movers * 3)
	var best_transfer := mini(3, transferable)
	var bench_heal_amount := _ready_bench_heal_amount(opponent, trusted)
	var option_metrics := {}
	var target_metrics := {}
	var transfer_target_metrics := {}
	var active_target: Variant = opponent_slots[0] if not opponent.get("active", []).is_empty() else null
	var active_entity: Variant = active_target.get("entity_serial") if active_target is Dictionary else null
	for target_value: Variant in opponent_slots:
		var target: Dictionary = target_value
		var metrics := _target_metrics(
			target, trusted, froslass_checks, transferable, 0,
			int(opponent.get("prizes_remaining", 0)),
			target.get("entity_serial") != active_entity,
			bench_heal_amount
		)
		target_metrics[str(target.get("entity_serial"))] = metrics
		transfer_target_metrics[str(target.get("entity_serial"))] = metrics.duplicate(true)
	for option_value: Variant in frame.get("options", []):
		if not option_value is Dictionary or not _safe_int(option_value.get("index")):
			return _error("invalid_damage_plan_input")
		var option: Dictionary = option_value
		var target: Variant = _target_for_option(option, own_slots, opponent_slots)
		var projected := _projected_damage(option, target, own, opponent, own_slots, trusted)
		var metrics := _target_metrics(
			target, trusted, froslass_checks, transferable, projected,
			int(opponent.get("prizes_remaining", 0)),
			target.get("entity_serial") != active_entity,
			bench_heal_amount
		) if target is Dictionary else _neutral_option_metrics()
		metrics["bench_damage"] = _projected_bench_damage(
			option, own_slots, opponent, trusted
		)
		option_metrics[str(option.get("index"))] = metrics
		if target is Dictionary:
			var key := str(target.get("entity_serial"))
			var current: Dictionary = target_metrics.get(key, {})
			if current.is_empty() or _target_less(metrics, current):
				target_metrics[key] = metrics.duplicate(true)
	var best_target := {}
	for metrics_value: Variant in target_metrics.values():
		var metrics: Dictionary = metrics_value
		if best_target.is_empty() or _target_less(metrics, best_target):
			best_target = metrics
	var best_transfer_target := {}
	for metrics_value: Variant in transfer_target_metrics.values():
		var metrics: Dictionary = metrics_value
		if best_transfer_target.is_empty() or _target_less(metrics, best_transfer_target):
			best_transfer_target = metrics
	var attack_options: Array = []
	for option_value: Variant in frame.get("options", []):
		if option_value is Dictionary and option_value.get("kind") in ["attack", "granted_attack"]:
			attack_options.append(option_value)
	var current_attack_damage := 0
	var current_attack_bench_damage := 0
	for option_value: Variant in attack_options:
		current_attack_damage = maxi(
			current_attack_damage,
			_projected_damage(option_value, active_target, own, opponent, own_slots, trusted)
		)
		current_attack_bench_damage = maxi(
			current_attack_bench_damage,
			int(option_metrics.get(str(option_value.get("index")), {}).get("bench_damage", 0))
		)
	var gust_target_metrics := {}
	for target_value: Variant in opponent.get("bench", []):
		if not target_value is Dictionary or not _safe_int(target_value.get("entity_serial")):
			continue
		var target: Dictionary = target_value
		var target_damage := 0
		for option_value: Variant in attack_options:
			var rebound: Dictionary = option_value.duplicate(true)
			rebound["projected_damage"] = null
			target_damage = maxi(
				target_damage,
				_projected_damage(rebound, target, own, opponent, own_slots, trusted)
			)
		gust_target_metrics[str(target.get("entity_serial"))] = _target_metrics(
			target, trusted, 0, 0, target_damage,
			int(opponent.get("prizes_remaining", 0)), false, 0
		)
	var best_gust_target := {}
	for metrics_value: Variant in gust_target_metrics.values():
		var metrics: Dictionary = metrics_value
		if best_gust_target.is_empty() or _target_less(metrics, best_gust_target):
			best_gust_target = metrics
	var facts := {
		"damage.movable_counter_count": transferable,
		"damage.available_mover_count": available_movers,
		"damage.froslass_check_count": froslass_checks,
		"damage.best_transfer_count": best_transfer,
		"damage.best_transfer_target_entity_serial": best_transfer_target.get("target_entity_serial"),
		"damage.best_transfer_attack_windows_to_ko": best_transfer_target.get("attack_windows_to_ko"),
		"damage.best_transfer_prize_yield": best_transfer_target.get("prize_yield"),
		"damage.best_transfer_remaining_debt": best_transfer_target.get("remaining_debt"),
		"damage.best_target_entity_serial": best_target.get("target_entity_serial"),
		"damage.best_attack_windows_to_ko": best_target.get("attack_windows_to_ko"),
		"damage.best_prize_yield": best_target.get("prize_yield"),
		"damage.best_remaining_debt": best_target.get("remaining_debt"),
		"damage.current_attack_damage": current_attack_damage,
		"damage.current_attack_bench_damage": current_attack_bench_damage,
		"damage.best_gust_target_entity_serial": best_gust_target.get("target_entity_serial"),
		"damage.best_gust_attack_windows_to_ko": best_gust_target.get("attack_windows_to_ko"),
		"damage.best_gust_prize_yield": best_gust_target.get("prize_yield"),
		"damage.best_gust_remaining_debt": best_gust_target.get("remaining_debt"),
	}
	var audit_payload := {
		"schema_version": 1,
		"profile_id": "ptcgdap-public-damage-plan-v1",
		"registry_sha256": trusted.get("registry_sha256"),
		"public_observation_hash": frame.get("source", {}).get("public_observation_hash"),
		"window_id": frame.get("source", {}).get("window_id"),
		"plan_ids": damage_plans.map(func(plan: Variant) -> Variant: return plan.get("plan_id")),
		"facts": facts,
		"options": option_metrics,
		"targets": target_metrics,
		"public_only": true,
	}
	return {
		"accepted": true,
		"error_code": "",
		"facts": facts,
		"options": option_metrics,
		"targets": target_metrics,
		"best_target_entity_serial": best_target.get("target_entity_serial"),
		"audit_hash": _tree_hash(audit_payload),
		"audit": audit_payload if include_full_audit else {},
	}


static func _projected_damage(
	option: Dictionary, target: Variant, own: Dictionary, opponent: Dictionary,
	own_slots: Array, registry: Dictionary
) -> int:
	if not target is Dictionary or option.get("kind") not in ["attack", "granted_attack"]:
		return 0
	# The Host derives this from the current legal option after every public
	# damage modifier.  A present zero is meaningful (for example prevention)
	# and must not be replaced with catalog base damage.
	var option_projected: Variant = option.get("projected_damage")
	if _safe_int(option_projected):
		return int(option_projected)
	var source: Variant = null
	for slot_value: Variant in own_slots:
		var slot: Dictionary = slot_value
		if slot.get("entity_serial") == option.get("source_entity_serial") \
			or slot.get("serial") == option.get("source_serial"):
			source = slot
			break
	if not source is Dictionary:
		return 0
	var source_card := _card(registry, str(source.get("local_card_uid", "")))
	var attack: Variant = null
	for attack_value: Variant in source_card.get("attacks", []):
		if attack_value is Dictionary and attack_value.get("attack_index") == option.get("attack_index"):
			attack = attack_value
			break
	if not attack is Dictionary or not _json_nonnegative_int(attack.get("active_damage")):
		return 0
	var damage := maxi(0, int(attack.get("active_damage")))
	var tool_uid: Variant = source.get("attached_tool_uid")
	if typeof(tool_uid) == TYPE_STRING:
		var tool := _card(registry, str(tool_uid))
		if "tool.conditional_active_damage_bonus.v1" in tool.get("capability_ids", []) \
			and int(own.get("prizes_remaining", 0)) > int(opponent.get("prizes_remaining", 0)):
			damage += 30
	var target_card := _card(registry, str(target.get("local_card_uid", "")))
	var source_type := str(source_card.get("energy_type", ""))
	if not source_type.is_empty() and source_type == target_card.get("weakness_energy"):
		damage *= int(target_card.get("weakness_multiplier", 1))
	if not source_type.is_empty() and source_type == target_card.get("resistance_energy"):
		damage = maxi(0, damage - int(target_card.get("resistance_reduction", 0)))
	return damage


static func _projected_bench_damage(
	option: Dictionary, own_slots: Array, opponent: Dictionary, registry: Dictionary
) -> int:
	# Keep the Host-owned post-modifier active projection independent from the
	# trusted fixed secondary bench effect. Active prevention must not erase a
	# still-productive public bench-damage branch.
	if option.get("kind") not in ["attack", "granted_attack"]:
		return 0
	var opponent_bench: Variant = opponent.get("bench", [])
	if not opponent_bench is Array or opponent_bench.is_empty():
		return 0
	var source_uid := str(option.get("source_uid", ""))
	if source_uid.is_empty():
		for slot_value: Variant in own_slots:
			var slot: Dictionary = slot_value
			if slot.get("entity_serial") == option.get("source_entity_serial") \
				or slot.get("serial") == option.get("source_serial"):
				source_uid = str(slot.get("local_card_uid", ""))
				break
	var source_card := _card(registry, source_uid)
	if "attack.fixed_split.v1" not in source_card.get("capability_ids", []):
		return 0
	for attack_value: Variant in source_card.get("attacks", []):
		if attack_value is Dictionary \
			and attack_value.get("attack_index") == option.get("attack_index") \
			and _json_nonnegative_int(attack_value.get("bench_damage")):
			return int(attack_value.get("bench_damage"))
	return 0


static func _target_metrics(
	target: Dictionary, registry: Dictionary, froslass_checks: int, transferable: int,
	projected_damage: int, opponent_prizes: int, is_bench: bool = false,
	bench_heal_amount: int = 0
) -> Dictionary:
	var remaining_hp := maxi(0, int(target.get("remaining_hp", 0)))
	var target_card := _card(registry, str(target.get("local_card_uid", "")))
	var check_damage := froslass_checks * 10 if bool(target_card.get("has_ability", false)) else 0
	var remaining_debt := maxi(0, remaining_hp - projected_damage)
	var transfer_used := mini(transferable, (remaining_debt + 9) / 10) if remaining_debt > 0 else 0
	var immediate_total := projected_damage + transfer_used * 10
	var heal_threat := is_bench and bench_heal_amount > 0 and immediate_total < remaining_hp
	var total := immediate_total
	var check_used := check_damage if total < remaining_hp and not heal_threat else 0
	total += check_used
	var windows := 1 if total >= remaining_hp and total > 0 else (2 if projected_damage > 0 else 3)
	var prize_value := clampi(int(target.get("prize_value", 1)), 1, 3)
	var response_risk := maxi(0, 3 - mini(opponent_prizes, 3))
	if bool(target_card.get("has_ability", false)):
		response_risk += 1
	if heal_threat:
		response_risk += 100 + mini(bench_heal_amount, 400)
	return {
		"target_entity_serial": int(target.get("entity_serial", 0)),
		"projected_damage": projected_damage,
		"attack_windows_to_ko": windows,
		"prize_yield": prize_value,
		"remaining_debt": remaining_debt,
		"overkill": maxi(0, total - remaining_hp),
		"response_risk": response_risk,
		"between_turn_damage": check_used,
		"transferable_damage": transfer_used * 10,
	}


static func _ready_bench_heal_amount(opponent: Dictionary, registry: Dictionary) -> int:
	var active: Variant = opponent.get("active", [])
	if not active is Array or active.is_empty() or not active[0] is Dictionary:
		return 0
	var slot: Dictionary = active[0]
	var card := _card(registry, str(slot.get("local_card_uid", "")))
	if "attack.bench_heal.v1" not in card.get("capability_ids", []):
		return 0
	var attached := int(slot.get("attached_energy_count", 0))
	var amount := 0
	for attack_value: Variant in card.get("attacks", []):
		if not attack_value is Dictionary or not _json_nonnegative_int(
			attack_value.get("bench_heal_amount")
		):
			continue
		if attached >= str(attack_value.get("cost", "")).length():
			amount = maxi(amount, int(attack_value.get("bench_heal_amount", 0)))
	return amount


static func _neutral_option_metrics() -> Dictionary:
	return {
		"target_entity_serial": null, "projected_damage": 0, "bench_damage": 0,
		"attack_windows_to_ko": 3,
		"prize_yield": 0, "remaining_debt": 0, "overkill": 0, "response_risk": 0,
		"between_turn_damage": 0, "transferable_damage": 0,
	}


static func _target_less(left: Dictionary, right: Dictionary) -> bool:
	var left_key := _target_key(left)
	var right_key := _target_key(right)
	for index: int in left_key.size():
		if left_key[index] != right_key[index]:
			return left_key[index] < right_key[index]
	return false


static func _target_key(value: Dictionary) -> Array:
	var serial: Variant = value.get("target_entity_serial")
	return [
		int(value.get("attack_windows_to_ko", 3)), -int(value.get("prize_yield", 0)),
		int(value.get("remaining_debt", 0)), int(value.get("overkill", 0)),
		int(value.get("response_risk", 0)), int(serial) if typeof(serial) == TYPE_INT else MAX_SAFE_INTEGER,
	]


static func _target_for_option(option: Dictionary, _own_slots: Array, opponent_slots: Array) -> Variant:
	var entity: Variant = option.get("target_entity_serial")
	if typeof(entity) == TYPE_INT and int(entity) > 0:
		# Damage plans declare opponent target roles.  An option may also carry a
		# self target (tool attachment, energy attachment, retreat or the source
		# half of a damage-movement interaction); those identities must not enter
		# the opponent damage route or its best-target facts.
		for slot_value: Variant in opponent_slots:
			if slot_value is Dictionary and slot_value.get("entity_serial") == entity:
				return slot_value
	if option.get("kind") in ["attack", "granted_attack"] and not opponent_slots.is_empty():
		return opponent_slots[0]
	return null


static func _slots(player: Dictionary) -> Array:
	var result: Array = []
	for zone: String in ["active", "bench"]:
		for value: Variant in player.get(zone, []):
			if value is Dictionary and _safe_int(value.get("entity_serial")) \
				and int(value.get("entity_serial")) > 0 and _local_uid(value.get("local_card_uid")):
				result.append(value)
	return result


static func _card(registry: Dictionary, uid: String) -> Dictionary:
	var value: Variant = registry.get("cards", {}).get(uid)
	return value if value is Dictionary else {}


static func _contains_private(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				if typeof(key) != TYPE_STRING or PRIVATE_KEYS.has(str(key).to_lower()):
					return true
				stack.append(current[key])
		elif current is Array:
			stack.append_array(current)
	return false


static func _canonical_sha256(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize(value, {
		"max_depth": 64, "max_nodes": 500000,
		"max_input_bytes": 67108864, "max_output_bytes": 67108864,
	})
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK \
		or context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _tree_hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.public_observation_hash(value)
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""


static func _error(code: String) -> Dictionary:
	return {
		"accepted": false, "error_code": code, "facts": {}, "options": {},
		"targets": {}, "audit_hash": "",
	}


static func _execution_plan_error(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"execution_plan_hash": "",
		"policy_hash": "",
		"registry_sha256": "",
	}


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index: int in 64:
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 70)):
			return false
	return true


static func _json_nonnegative_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value)) and float(value) >= 0.0 \
			and float(value) <= float(MAX_SAFE_INTEGER) and floor(float(value)) == float(value)
	return false


static func _local_uid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	var underscore := text.find("_")
	return underscore > 0 and underscore < text.length() - 1 and text.find(" ") < 0


static func _identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code in [45, 46, 95]):
			return false
	return true


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _unique_count(values: Array) -> int:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()
