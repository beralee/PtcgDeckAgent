class_name AuthorStrategyDevelopmentPolicy
extends RefCounted

const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const CompetitivePolicyV2Script = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const SemanticTransactionJournalScript = preload(
	"res://scripts/ai/ptcgdap/public/SemanticTransactionJournal.gd"
)
const TurnTransactionJournalScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnTransactionJournal.gd"
)
const TurnProgramJournalScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramJournal.gd"
)
const ExecutorScript = preload("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const ExecutionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const PolicyPackageManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd")
const ConditionedValueScript = preload(
	"res://scripts/ai/ptcgdap/public/StateConditionedTransactionValueV2.gd"
)

const PROFILE_ID := "ptcgdap-author-strategy-development-execution-v1"
const FRAME_PROFILE_ID := "ptcgdap-marnie-package-development-frame-v1"
const STRATEGY_ID := "ptcgdap.marnie.18.0.package-local-v1"
const CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const SOURCE_DECK_ID := 800018501
const SUPPORTED_OPERATORS := [
	"legality_guard",
	"mandatory_terminal_guard",
	"macro_proposal",
	"hard_tier_filter",
	"base_veto",
	"deterministic_fallback",
	"emit_decision",
]
const SUPPORTED_OWNERS := ["base", "base", "adapter", "base", "base", "base", "base"]
const FRAME_KEYS := [
	"schema_version", "profile_id", "strategy_id", "card_id_domain", "sequence",
	"seat", "prompt_kind", "source", "public_state", "select_semantics", "options",
]
const OPTION_KEYS := [
	"index", "kind", "card_uid", "card_serial", "source_uid", "target_uid",
	"target_remaining_hp", "target_prize_value", "attached_energy_count",
	"attack_index", "option_number", "tags", "option_type_raw", "option_card_uid",
	"option_player_index", "energy_type_raw", "energy_count", "special_condition_type",
]
const PRIVATE_KEYS := {
	"deck_order": true,
	"instance_id": true,
	"object_ref": true,
	"official_card_id": true,
	"search_begin_input": true,
	"callback": true,
	"binding": true,
	"ticket": true,
	"command": true,
	"raw_private_hash": true,
}
const TURN_PROGRAM_CONFIG_KEYS := [
	"turn_program_profile_id", "turn_program_mode", "turn_program_model_version",
	"turn_program_weight_prize_gain_milli",
	"turn_program_weight_board_development_milli",
	"turn_program_weight_attack_pressure_milli",
	"turn_program_weight_next_turn_continuity_milli",
	"turn_program_weight_hand_quality_milli",
	"turn_program_weight_disruption_milli",
	"turn_program_weight_resource_preservation_milli",
	"turn_program_weight_risk_milli",
	"turn_program_weight_unresolved_debt_milli",
	"turn_program_allowed_sources", "turn_program_allowed_effects",
	"turn_program_max_uncertainty_milli", "turn_program_minimum_utility_margin",
]
const TURN_PROGRAM_SEMANTIC_CONFIG_KEYS := [
	"turn_program_semantics_profile_id",
	"turn_program_semantic_draw_uids",
	"turn_program_semantic_disruption_uids",
	"turn_program_semantic_search_uids",
	"turn_program_semantic_conversion_uids",
	"turn_program_semantic_evolution_uids",
	"turn_program_semantic_bench_uids",
	"turn_program_semantic_supporter_uids",
]
const TURN_PROGRAM_GUARD_CONFIG_KEYS := [
	"turn_program_semantic_guard_profile_id",
	"turn_program_semantic_guard_draw_max_own_hand",
	"turn_program_semantic_guard_disruption_max_own_hand",
	"turn_program_semantic_guard_disruption_min_opponent_hand",
]
const TURN_PROGRAM_CONDITIONED_VALUE_CONFIG_KEYS := [
	"turn_program_conditioned_value_model",
]
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _pins: Dictionary = {}
var _ir_document: Dictionary = {}
var _adapter_document: Dictionary = {}
var _config_document: Dictionary = {}
var _competitive_policy_v2: Variant = null
var _competitive_policy_v2_hash := ""
var _allowed_uids: Dictionary = {}
var _match_id := ""
var _authority_mode := ExecutionGateScript.DEVELOPMENT_MODE
var _policy_package_pins: Dictionary = {}
var _factory_token: Variant = null
var _selection_calls := 0
var _successful_selections := 0
var _matched_rule_counts: Dictionary = {}
var _macro_preferred_selections := 0
var _semantic_transaction_journal: Variant = null
var _semantic_transaction_seat := -1
var _turn_transaction_journal: Variant = null
var _turn_transaction_seat := -1
var _turn_program_shadow_enabled := false
var _turn_program_journal: Variant = null
var _turn_program_seat := -1
var _turn_program_mode := "off"
var _turn_program_canary_profile: Dictionary = {}
var _turn_program_value_model: Dictionary = {}
var _turn_program_action_semantics: Dictionary = {}


static func create(
	handle: Variant,
	match_id: Variant,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	var policy_package: Dictionary = PolicyPackageManifestScript.load_and_verify(handle)
	if not bool(policy_package.get("accepted", false)):
		return _error(str(policy_package.get("error_code", "policy_package_integrity_invalid")))
	if not _identifier(match_id) or str(match_id).length() > 64:
		return _error("invalid_match_identity")
	var pins: Dictionary = handle.to_public_dict()
	var pin_error := _pin_error(pins, authority_mode)
	if not pin_error.is_empty():
		return _error(pin_error)
	var local_deck: Array = handle.local_deck_snapshot()
	var allowed_uids := {}
	var card_count := 0
	for row_value: Variant in local_deck:
		if not row_value is Dictionary:
			return _error("package_deck_unmapped")
		var row: Dictionary = row_value
		var uid: Variant = row.get("local_card_uid")
		var count: Variant = row.get("count")
		if not _local_uid(uid) or typeof(count) != TYPE_INT or count <= 0 or allowed_uids.has(uid):
			return _error("package_deck_unmapped")
		allowed_uids[uid] = true
		card_count += count
	if card_count != 60 or allowed_uids.size() != 28:
		return _error("package_deck_unmapped")
	var documents_result: Dictionary = handle.policy_documents()
	if not bool(documents_result.get("ok", false)):
		return _error(str(documents_result.get("error_code", "package_policy_unsupported")))
	var documents: Dictionary = documents_result.get("documents", {})
	var ir_outcome: Variant = StrategicTraceScript.compile_ir(documents.get("policy/policy_ir.json"))
	var raw_adapter: Variant = documents.get("policy/adapter.json")
	var competitive_policy: Variant = null
	var adapter_outcome: Variant
	if raw_adapter is Dictionary and raw_adapter.get("schema_version") == 2:
		adapter_outcome = CompetitivePolicyV2Script.compile_local_uid(
			raw_adapter, allowed_uids.keys()
		)
		competitive_policy = adapter_outcome.get("policy") if adapter_outcome is Dictionary else null
	else:
		adapter_outcome = PublicDeckAdapterScript.compile_local_uid(
			raw_adapter,
			allowed_uids.keys(),
			pins.get("deck_manifest_sha256")
		)
	if (
		ir_outcome == null
		or not bool(ir_outcome.get("accepted"))
		or ir_outcome.get("ir") == null
		or adapter_outcome == null
		or not bool(adapter_outcome.get("accepted"))
		or (
			competitive_policy == null
			and adapter_outcome.get("adapter") == null
		)
	):
		return _error("package_policy_unsupported")
	var ir_document: Dictionary = StrategicTraceScript.ir_public_dict(ir_outcome.get("ir"))
	var adapter_document: Dictionary = CompetitivePolicyV2Script.policy_public_dict(competitive_policy) \
		if competitive_policy != null else PublicDeckAdapterScript.adapter_public_dict(adapter_outcome.get("adapter"))
	if not _supported_ir(ir_document) or not _supported_adapter_for_runtime(adapter_document, competitive_policy):
		return _error("package_policy_unsupported")
	var config_document: Variant = documents.get("policy/config.json")
	var expanded_config := _expand_conditioned_value_config(handle, config_document, pins)
	if not bool(expanded_config.get("ok", false)):
		return _error(str(expanded_config.get("error_code", "package_policy_unsupported")))
	config_document = expanded_config.get("config")
	if not _supported_config(config_document, pins):
		return _error("package_policy_unsupported")
	var claim: Dictionary = handle.claim_for_match(str(match_id))
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "package_handle_already_claimed")))
	var script: GDScript = load("res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd")
	var policy: Variant = script.new(
		pins,
		ir_document,
		adapter_document,
		config_document,
		allowed_uids,
		str(match_id),
		authority_mode,
		policy_package,
		_FACTORY_TOKEN,
		competitive_policy
	)
	return {"ok": true, "error_code": "", "policy": policy}


func _init(
	next_pins: Dictionary = {},
	next_ir: Dictionary = {},
	next_adapter: Dictionary = {},
	next_config: Dictionary = {},
	next_allowed_uids: Dictionary = {},
	next_match_id: String = "",
	next_authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE,
	next_policy_package_pins: Dictionary = {},
	token: Variant = null,
	next_competitive_policy_v2: Variant = null
) -> void:
	if token != _FACTORY_TOKEN:
		return
	_pins = next_pins.duplicate(true)
	_ir_document = next_ir.duplicate(true)
	_adapter_document = next_adapter.duplicate(true)
	_config_document = next_config.duplicate(true)
	_allowed_uids = next_allowed_uids.duplicate(true)
	_match_id = next_match_id
	_authority_mode = next_authority_mode
	_policy_package_pins = next_policy_package_pins.duplicate(true)
	_factory_token = token
	_competitive_policy_v2 = next_competitive_policy_v2
	var turn_program: Dictionary = _turn_program_config_from_values(
		_config_document.get("values", {})
	)
	if not turn_program.is_empty():
		_turn_program_mode = str(turn_program.get("mode", "off"))
		_turn_program_value_model = turn_program.get("value_model", {}).duplicate(true)
		if turn_program.get("canary_profile") is Dictionary:
			_turn_program_canary_profile = turn_program.get("canary_profile", {}).duplicate(true)
		if turn_program.get("action_semantics") is Dictionary:
			_turn_program_action_semantics = turn_program.get("action_semantics", {}).duplicate(true)
	if next_competitive_policy_v2 is Dictionary:
		var candidate_hash: Variant = next_competitive_policy_v2.get("policy_hash")
		if _is_sha(candidate_hash):
			_competitive_policy_v2_hash = str(candidate_hash)


func select(frame: Variant) -> Dictionary:
	_selection_calls += 1
	if not _is_valid_owner():
		return _selection_error("development_policy_invalid")
	if _adapter_document.get("schema_version") == 2:
		return _select_competitive_v2(frame)
	var frame_error := _frame_error(frame)
	if not frame_error.is_empty():
		return _selection_error(frame_error)
	var source: Dictionary = frame.get("source")
	var semantics: Dictionary = frame.get("select_semantics")
	var options: Array = frame.get("options")
	var proposal_result := _macro_proposal(frame)
	var tiers: Array = []
	for index: int in options.size():
		tiers.append({"index": index, "tier": [0]})
	var proposals: Array = []
	if not proposal_result.get("indexes", []).is_empty():
		proposals.append({
			"operator": "macro_proposal",
			"indexes": proposal_result.get("indexes", []).duplicate(true),
			"reason_code": "public_macro_proposal",
		})
	var context_payload := {
		"source": {
			"option_count": options.size(),
			"window_id": source.get("window_id"),
		},
		"select_semantics": {
			"min_count": semantics.get("min_count"),
			"max_count": semantics.get("max_count"),
		},
	}
	var execution_input := {
		"execution_id": "%s.window.%d" % [_match_id, int(frame.get("sequence"))],
		"mandatory_indexes": [],
		"terminal_indexes": [],
		"base_hard_tiers": tiers,
		"base_vetoed_indexes": [],
		"adapter_proposals": proposals,
	}
	var computed: Dictionary = ExecutorScript._compute(context_payload, _ir_document, execution_input)
	if not bool(computed.get("ok", false)):
		return _selection_error(str(computed.get("error_code", "development_policy_failed")))
	var payload: Dictionary = computed.get("payload", {})
	var selected: Variant = payload.get("selected_indexes")
	if not selected is Array:
		return _selection_error("development_policy_failed")
	_successful_selections += 1
	for rule_id: Variant in proposal_result.get("matched_rule_ids", []):
		_matched_rule_counts[rule_id] = int(_matched_rule_counts.get(rule_id, 0)) + 1
	var proposed: Array = proposal_result.get("indexes", [])
	if not proposed.is_empty() and not selected.is_empty() and selected[0] == proposed[0]:
		_macro_preferred_selections += 1
	return {
		"ok": true,
		"error_code": "",
		"selected_indexes": selected.duplicate(true),
		"matched_rule_ids": proposal_result.get("matched_rule_ids", []).duplicate(true),
		"selection_source": "restricted_ir_same_window",
		"public_observation_hash": source.get("public_observation_hash"),
		"window_id": source.get("window_id"),
		"decision_audit": {
			"schema_version": 1,
			"matched_rule_ids": proposal_result.get("matched_rule_ids", []).duplicate(true),
			"macro_proposal_indexes": proposal_result.get("indexes", []).duplicate(true),
			"base_result": payload.duplicate(true),
		},
	}


func requires_competitive_frame_v2() -> bool:
	return _adapter_document.get("schema_version") == 2 and _is_sha(_competitive_policy_v2_hash)


func expected_selection_source() -> String:
	return "competitive_policy_v2_current_window" if requires_competitive_frame_v2() else "restricted_ir_same_window"


func enable_turn_program_shadow(enabled: bool = true) -> void:
	_turn_program_shadow_enabled = enabled
	if not enabled:
		if _turn_program_journal != null:
			_turn_program_journal.clear()
		_turn_program_journal = null
		_turn_program_seat = -1


func _select_competitive_v2(frame: Variant) -> Dictionary:
	var turn_program_runtime_enabled := (
		_turn_program_shadow_enabled or _turn_program_mode in ["shadow", "canary"]
	)
	if (
		not _adapter_document.get("semantic_transactions", []).is_empty()
		or not _adapter_document.get("turn_transactions", []).is_empty()
		or (
			turn_program_runtime_enabled
			and not _adapter_document.get("turn_routes", []).is_empty()
		)
	):
		if not frame is Dictionary or frame.get("seat") not in [0, 1]:
			return _selection_error("invalid_development_frame")
		var current_seat := int(frame.get("seat"))
		var package_identity := "%s@%s#%s" % [
			_pins.get("package_id"), _pins.get("package_version"),
			_pins.get("archive_sha256"),
		]
		if not _adapter_document.get("semantic_transactions", []).is_empty() \
			and _semantic_transaction_journal == null:
			_semantic_transaction_seat = current_seat
			_semantic_transaction_journal = SemanticTransactionJournalScript.new(
				_match_id, current_seat, package_identity
			)
		elif not _adapter_document.get("semantic_transactions", []).is_empty() \
			and _semantic_transaction_seat != current_seat:
			return _selection_error("semantic_transaction_scope_mismatch")
		if not _adapter_document.get("turn_transactions", []).is_empty() \
			and _turn_transaction_journal == null:
			_turn_transaction_seat = current_seat
			_turn_transaction_journal = TurnTransactionJournalScript.new(
				_match_id, current_seat, package_identity
			)
		elif not _adapter_document.get("turn_transactions", []).is_empty() \
			and _turn_transaction_seat != current_seat:
			return _selection_error("turn_transaction_scope_mismatch")
		if turn_program_runtime_enabled and _turn_program_journal == null:
			_turn_program_seat = current_seat
			_turn_program_journal = TurnProgramJournalScript.new(
				_match_id, current_seat, package_identity
			)
		elif turn_program_runtime_enabled and _turn_program_seat != current_seat:
			return _selection_error("turn_program_scope_mismatch")
	var decision: Dictionary = CompetitivePolicyV2Script.decide_compiled(
		_competitive_policy_v2_hash, frame, [], [], [], [],
		_semantic_transaction_journal, _turn_transaction_journal,
		null, _turn_program_journal, turn_program_runtime_enabled,
		(
			_turn_program_canary_profile
			if _turn_program_mode == "canary" else null
		),
		(
			_turn_program_value_model
			if turn_program_runtime_enabled and not _turn_program_value_model.is_empty()
			else null
		),
		(
			_turn_program_action_semantics
			if turn_program_runtime_enabled and not _turn_program_action_semantics.is_empty()
			else null
		)
	)
	if not bool(decision.get("accepted", false)):
		return _selection_error(str(decision.get("error_code", "development_policy_failed")))
	var selected: Variant = decision.get("selected_indexes")
	if not selected is Array:
		return _selection_error("development_policy_failed")
	var audit: Dictionary = decision.get("audit", {})
	var matched_rule_ids: Array = []
	for scorecard_value: Variant in audit.get("scorecards", []):
		if not scorecard_value is Dictionary:
			continue
		for match_value: Variant in scorecard_value.get("matched_rules", []):
			if match_value is Dictionary and typeof(match_value.get("rule_id")) == TYPE_STRING:
				var rule_id := str(match_value.get("rule_id"))
				if rule_id not in matched_rule_ids:
					matched_rule_ids.append(rule_id)
	for rule_id: Variant in matched_rule_ids:
		_matched_rule_counts[rule_id] = int(_matched_rule_counts.get(rule_id, 0)) + 1
	_successful_selections += 1
	var source: Dictionary = frame.get("source", {}) if frame is Dictionary else {}
	return {
		"ok": true,
		"error_code": "",
		"selected_indexes": selected.duplicate(),
		"matched_rule_ids": matched_rule_ids,
		"selection_source": "competitive_policy_v2_current_window",
		"public_observation_hash": source.get("public_observation_hash"),
		"window_id": source.get("window_id"),
		"decision_audit": {
			"schema_version": 2,
			"matched_rule_ids": matched_rule_ids.duplicate(),
			"macro_proposal_indexes": audit.get("ranked_indexes", []).duplicate(),
			"base_result": audit.duplicate(true),
		},
	}


func audit_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"match_id": _match_id,
		"package_id": _pins.get("package_id"),
		"package_version": _pins.get("package_version"),
		"archive_sha256": _pins.get("archive_sha256"),
		"policy_ir_sha256": _pins.get("policy_ir_sha256"),
		"adapter_sha256": _pins.get("adapter_sha256"),
		"config_sha256": _pins.get("config_sha256"),
		"weights_sha256": _pins.get("weights_sha256"),
		"signature_key_id": _pins.get("signature_key_id"),
		"signature_scope": _pins.get("signature_scope"),
		"card_id_domain": CARD_ID_DOMAIN,
		"authority_mode": _authority_mode,
		"development_execution_only": _authority_mode == ExecutionGateScript.DEVELOPMENT_MODE,
		"device_canary_authority": _authority_mode == ExecutionGateScript.DEVICE_CANARY_MODE,
		"execution_trusted": bool(_pins.get("execution_trusted", false)),
		"player_runtime_authority": false,
		"production_ready": false,
		"policy_package_id": _policy_package_pins.get("package_id"),
		"policy_package_version": _policy_package_pins.get("package_version"),
		"policy_package_manifest_canonical_sha256": _policy_package_pins.get("manifest_canonical_sha256"),
		"execution_location": _policy_package_pins.get("execution_location"),
		"learned_model": _policy_package_pins.get("learned_model"),
		"model_backend": (
			"gdscript_sparse_integer_v2"
			if _conditioned_value_model_loaded() else "none"
		),
		"learned_model_invoked": _conditioned_value_model_loaded() and _selection_calls > 0,
		"selection_calls": _selection_calls,
		"successful_selections": _successful_selections,
		"matched_rule_counts": _matched_rule_counts.duplicate(true),
		"matched_rule_evaluations": _sum_counts(_matched_rule_counts),
		"macro_preferred_selections": _macro_preferred_selections,
		"adapter_schema_version": int(_adapter_document.get("schema_version", 0)),
		"competitive_policy_v2": requires_competitive_frame_v2(),
		"semantic_transaction_state": (
			_semantic_transaction_journal.snapshot()
			if _semantic_transaction_journal != null else {}
		),
		"turn_transaction_state": (
			_turn_transaction_journal.snapshot()
			if _turn_transaction_journal != null else {}
		),
		"turn_program_shadow_enabled": _turn_program_shadow_enabled,
		"turn_program_package_mode": _turn_program_mode,
		"turn_program_canary_configured": not _turn_program_canary_profile.is_empty(),
		"turn_program_minimum_utility_margin": int(_turn_program_canary_profile.get(
			"minimum_utility_margin", 0
		)),
		"turn_program_action_semantics_configured": not _turn_program_action_semantics.is_empty(),
		"turn_program_value_model_version": int(_turn_program_value_model.get(
			"model_version", 0
		)),
		"turn_program_state": (
			_turn_program_journal.snapshot()
			if _turn_program_journal != null else {}
		),
	}


func close() -> void:
	if _semantic_transaction_journal != null:
		_semantic_transaction_journal.clear()
	_semantic_transaction_journal = null
	_semantic_transaction_seat = -1
	if _turn_transaction_journal != null:
		_turn_transaction_journal.clear()
	_turn_transaction_journal = null
	_turn_transaction_seat = -1
	if _turn_program_journal != null:
		_turn_program_journal.clear()
	_turn_program_journal = null
	_turn_program_seat = -1
	_turn_program_shadow_enabled = false


func _is_valid_owner() -> bool:
	return (
		_factory_token == _FACTORY_TOKEN
		and not _match_id.is_empty()
		and _pin_error(_pins, _authority_mode).is_empty()
		and _policy_package_pins.get("package_id") == "ptcgdap.marnie.windows-local.policy"
		and _policy_package_pins.get("learned_model") == _expected_learned_model()
		and _policy_package_pins.get("execution_location") == "device_local"
		and _is_sha(_policy_package_pins.get("manifest_canonical_sha256"))
		and _supported_ir(_ir_document)
		and _supported_config(_config_document, _pins)
		and (
			requires_competitive_frame_v2()
			if _adapter_document.get("schema_version") == 2
			else _supported_adapter_for_runtime(_adapter_document, _competitive_policy_v2)
		)
		and _allowed_uids.size() == 28
	)


func _conditioned_value_model_loaded() -> bool:
	return _turn_program_value_model.get("profile_id") == ConditionedValueScript.PROFILE_ID \
		and ConditionedValueScript.is_model(_turn_program_value_model)


func _expected_learned_model() -> String:
	return ConditionedValueScript.PROFILE_ID if _conditioned_value_model_loaded() else "none"


func _frame_error(value: Variant) -> String:
	if _contains_forbidden_value(value):
		return "private_or_runtime_frame"
	if not value is Dictionary or not _has_exact_keys(value, FRAME_KEYS):
		return "invalid_development_frame"
	var frame: Dictionary = value
	if (
		frame.get("schema_version") != 1
		or frame.get("profile_id") != FRAME_PROFILE_ID
		or frame.get("strategy_id") != STRATEGY_ID
		or frame.get("card_id_domain") != CARD_ID_DOMAIN
		or typeof(frame.get("sequence")) != TYPE_INT
		or frame.get("sequence") < 1
		or typeof(frame.get("seat")) != TYPE_INT
		or frame.get("seat") not in [0, 1]
		or typeof(frame.get("prompt_kind")) != TYPE_STRING
		or str(frame.get("prompt_kind")).is_empty()
	):
		return "invalid_development_frame"
	var source: Variant = frame.get("source")
	var state: Variant = frame.get("public_state")
	var semantics: Variant = frame.get("select_semantics")
	var options: Variant = frame.get("options")
	if (
		not source is Dictionary
		or not _has_exact_keys(source, ["public_observation_hash", "window_id"])
		or not _is_sha(source.get("public_observation_hash"))
		or not _is_sha(source.get("window_id"))
		or not state is Dictionary
		or not state.get("self") is Dictionary
		or not state.get("opponent") is Dictionary
		or state.get("opponent").has("hand")
		or not semantics is Dictionary
		or not _has_exact_keys(semantics, ["min_count", "max_count", "select_type_raw", "select_context_raw"])
		or not options is Array
	):
		return "invalid_development_frame"
	var minimum: Variant = semantics.get("min_count")
	var maximum: Variant = semantics.get("max_count")
	if (
		typeof(minimum) != TYPE_INT
		or typeof(maximum) != TYPE_INT
		or minimum < 0
		or maximum < minimum
		or maximum > options.size()
		or typeof(semantics.get("select_type_raw")) != TYPE_INT
		or typeof(semantics.get("select_context_raw")) != TYPE_INT
	):
		return "invalid_development_frame"
	for index: int in options.size():
		var option: Variant = options[index]
		if not option is Dictionary or not _has_exact_keys(option, OPTION_KEYS):
			return "invalid_development_frame"
		if (
			option.get("index") != index
			or typeof(option.get("kind")) != TYPE_STRING
			or str(option.get("kind")).is_empty()
			or typeof(option.get("option_type_raw")) != TYPE_INT
			or option.get("option_type_raw") < 0
			or option.get("option_type_raw") > 16
			or (option.get("option_card_uid") != null and not _local_uid(option.get("option_card_uid")))
			or (option.get("option_player_index") != null and option.get("option_player_index") not in [0, 1])
			or (option.get("card_serial") != null and (typeof(option.get("card_serial")) != TYPE_INT or option.get("card_serial") < 0))
			or (option.get("option_number") != null and typeof(option.get("option_number")) != TYPE_INT)
			or (option.get("energy_type_raw") != null and typeof(option.get("energy_type_raw")) != TYPE_INT)
			or (option.get("energy_count") != null and (typeof(option.get("energy_count")) != TYPE_INT or option.get("energy_count") < 0))
			or (option.get("special_condition_type") != null and typeof(option.get("special_condition_type")) != TYPE_INT)
		):
			return "invalid_development_frame"
	var observation_source := {
		"schema_version": 1,
		"sequence": frame.get("sequence"),
		"seat": frame.get("seat"),
		"prompt_kind": frame.get("prompt_kind"),
		"public_state": state,
	}
	var observation: Dictionary = CabtTreeHashScript.public_observation_hash(observation_source)
	if observation.get("sha256") != source.get("public_observation_hash"):
		return "stale_development_frame"
	var window: Dictionary = CabtTreeHashScript.public_observation_hash({
		"public_observation_hash": source.get("public_observation_hash"),
		"select_semantics": semantics,
		"options": options,
	})
	return "" if window.get("sha256") == source.get("window_id") else "stale_development_frame"


func _macro_proposal(frame: Dictionary) -> Dictionary:
	var best := {}
	var matched_rule_ids: Array = []
	var order := 0
	for rule_value: Variant in _adapter_document.get("rules", []):
		var rule: Dictionary = rule_value
		if rule.get("operator") != "macro_proposal":
			order += 1
			continue
		var rule_matched := false
		for option_value: Variant in frame.get("options", []):
			var option: Dictionary = option_value
			if not _matches(rule.get("predicate", {}), frame, option):
				continue
			rule_matched = true
			var index: int = option.get("index")
			var rank := [int(rule.get("priority")), order]
			if not best.has(index) or _rank_less(rank, best.get(index)):
				best[index] = rank
		if rule_matched:
			matched_rule_ids.append(rule.get("rule_id"))
		order += 1
	var ordered: Array = best.keys()
	ordered.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _rank_less(
			[best.get(left)[0], best.get(left)[1], int(left)],
			[best.get(right)[0], best.get(right)[1], int(right)]
		)
	)
	return {"indexes": ordered, "matched_rule_ids": matched_rule_ids}


func _matches(predicate: Dictionary, frame: Dictionary, option: Dictionary) -> bool:
	var semantics: Dictionary = frame.get("select_semantics")
	var actual := {
		"select_type_raw": semantics.get("select_type_raw"),
		"select_context_raw": semantics.get("select_context_raw"),
		"option_type_raw": option.get("option_type_raw"),
		"option_card_id": option.get("option_card_uid"),
		"option_player_index": option.get("option_player_index"),
	}
	for key: String in ["select_type_raw", "select_context_raw", "option_type_raw", "option_card_id", "option_player_index"]:
		if predicate.get(key) != null and actual.get(key) != predicate.get(key):
			return false
	var state: Dictionary = frame.get("public_state")
	var acting: Dictionary = state.get("self")
	var hand_ids := _uids(acting.get("hand", []))
	var active_ids := _uids(acting.get("active", []))
	if predicate.get("acting_hand_card_id") != null and not hand_ids.has(predicate.get("acting_hand_card_id")):
		return false
	if predicate.get("acting_active_card_id") != null and not active_ids.has(predicate.get("acting_active_card_id")):
		return false
	return true


static func _pin_error(pins: Dictionary, authority_mode: String) -> String:
	return ExecutionGateScript.validate_handle_pins(pins, authority_mode)


static func _supported_config(value: Variant, pins: Dictionary) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, ["config_profile_id", "document_type", "schema_version", "values"]):
		return false
	var values: Variant = value.get("values")
	var required := [
		"cabt_exportable", "card_id_domain", "deck_manifest_sha256",
		"platform_scope", "source_deck_id",
	]
	if values is Dictionary and values.has("turn_program_profile_id"):
		required.append_array(TURN_PROGRAM_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_semantics_profile_id"):
		required.append_array(TURN_PROGRAM_SEMANTIC_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_semantic_guard_profile_id"):
		required.append_array(TURN_PROGRAM_GUARD_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_conditioned_value_model"):
		required.append_array(TURN_PROGRAM_CONDITIONED_VALUE_CONFIG_KEYS)
	return (
		value.get("schema_version") == 1
		and value.get("config_profile_id") == "ptcgdap-author-policy-config-v1"
		and value.get("document_type") == "author_policy_config_v1"
		and values is Dictionary
		and _has_exact_keys(values, required)
		and values.get("cabt_exportable") == false
		and values.get("card_id_domain") == CARD_ID_DOMAIN
		and values.get("deck_manifest_sha256") == pins.get("deck_manifest_sha256")
		and values.get("platform_scope") == "windows"
		and values.get("source_deck_id") == SOURCE_DECK_ID
		and (
			not values.has("turn_program_profile_id")
			or not _turn_program_config_from_values(values).is_empty()
		)
	)


static func _expand_conditioned_value_config(
	handle: Variant,
	value: Variant,
	pins: Dictionary
) -> Dictionary:
	if not value is Dictionary or not value.get("values") is Dictionary:
		return _error("package_policy_unsupported")
	var raw_values: Dictionary = value.get("values")
	if not raw_values.has("turn_program_conditioned_value_sha256"):
		return {"ok": true, "error_code": "", "config": value.duplicate(true)}
	var expected_sha: Variant = raw_values.get("turn_program_conditioned_value_sha256")
	if not _is_sha(expected_sha) or pins.get("weights_sha256") != expected_sha \
			or handle == null or not handle.has_method("policy_weights_payload"):
		return _error("package_policy_unsupported")
	var payload_result: Dictionary = handle.policy_weights_payload()
	var payload: Variant = payload_result.get("payload")
	if not bool(payload_result.get("ok", false)) or not payload is PackedByteArray \
			or payload_result.get("sha256") != expected_sha:
		return _error("package_policy_unsupported")
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		payload,
		{"max_input_bytes": 1048576, "max_output_bytes": 1048576, "max_nodes": 65536}
	)
	if not bool(canonical.get("ok", false)) or canonical.get("bytes") != payload:
		return _error("package_policy_unsupported")
	var model: Variant = JSON.parse_string(str(canonical.get("text", "")))
	model = _coerce_integral_numbers(model)
	if not ConditionedValueScript.is_model(model):
		return _error("package_policy_unsupported")
	var expanded: Dictionary = value.duplicate(true)
	var expanded_values: Dictionary = expanded.get("values")
	expanded_values.erase("turn_program_conditioned_value_sha256")
	expanded_values["turn_program_conditioned_value_model"] = model
	return {"ok": true, "error_code": "", "config": expanded}


static func _turn_program_config_from_values(values: Variant) -> Dictionary:
	if not values is Dictionary or not values.has("turn_program_profile_id"):
		return {}
	for key: String in TURN_PROGRAM_CONFIG_KEYS:
		if not values.has(key):
			return {}
	var weights := {
		"prize_gain_milli": values.get("turn_program_weight_prize_gain_milli"),
		"board_development_milli": values.get("turn_program_weight_board_development_milli"),
		"attack_pressure_milli": values.get("turn_program_weight_attack_pressure_milli"),
		"next_turn_continuity_milli": values.get("turn_program_weight_next_turn_continuity_milli"),
		"hand_quality_milli": values.get("turn_program_weight_hand_quality_milli"),
		"disruption_milli": values.get("turn_program_weight_disruption_milli"),
		"resource_preservation_milli": values.get("turn_program_weight_resource_preservation_milli"),
		"risk_milli": values.get("turn_program_weight_risk_milli"),
		"unresolved_debt_milli": values.get("turn_program_weight_unresolved_debt_milli"),
	}
	var sources: Array = str(values.get("turn_program_allowed_sources", "")).split(",", false)
	var effects: Array = str(values.get("turn_program_allowed_effects", "")).split(",", false)
	var action_semantics: Variant = null
	if values.has("turn_program_semantics_profile_id"):
		action_semantics = _turn_program_action_semantics_from_values(values)
		if action_semantics == null:
			return {}
	var value_model: Dictionary = {
		"profile_id": "ptcgdap-turn-program-value-v1",
		"model_version": values.get("turn_program_model_version"),
		"feature_weights_milli": weights,
	}
	if values.has("turn_program_conditioned_value_model"):
		var conditioned: Variant = values.get("turn_program_conditioned_value_model")
		if not conditioned is Dictionary or not ConditionedValueScript.is_model(conditioned) \
				or conditioned.get("model_version") != values.get("turn_program_model_version") \
				or conditioned.get("fallback_value_model", {}).get(
					"feature_weights_milli", {}
				) != weights:
			return {}
		value_model = conditioned.duplicate(true)
	var minimum_utility_margin := int(values.get("turn_program_minimum_utility_margin"))
	if value_model.get("profile_id") == ConditionedValueScript.PROFILE_ID:
		minimum_utility_margin = maxi(
			minimum_utility_margin,
			int(value_model.get("calibration", {}).get(
				"minimum_override_margin_utility", 0
			))
		)
	var result := {
		"profile_id": values.get("turn_program_profile_id"),
		"mode": values.get("turn_program_mode"),
		"value_model": value_model,
		"canary_profile": {
			"profile_id": "ptcgdap-turn-program-canary-v1",
			"allowed_source_kinds": sources,
			"allowed_current_effect_kinds": effects,
			"max_uncertainty_milli": values.get("turn_program_max_uncertainty_milli"),
			"minimum_utility_margin": minimum_utility_margin,
		},
		"action_semantics": action_semantics,
	}
	return result if _supported_turn_program_config(result) else {}


static func _turn_program_action_semantics_from_values(values: Dictionary) -> Variant:
	if values.get("turn_program_semantics_profile_id") \
			!= "ptcgdap-turn-program-action-semantics-v1":
		return null
	var effect_kinds := {}
	var claims := {}
	for effect_kind: String in [
		"draw", "disruption", "search", "conversion", "evolution", "bench",
	]:
		var key := "turn_program_semantic_%s_uids" % effect_kind
		for uid: Variant in str(values.get(key, "")).split(",", false):
			if str(uid).is_empty() or effect_kinds.has(uid):
				return null
			effect_kinds[uid] = effect_kind
			claims[uid] = "none"
	var supporter_uids: Array = str(values.get(
		"turn_program_semantic_supporter_uids", ""
	)).split(",", false)
	var seen_supporters := {}
	for uid: Variant in supporter_uids:
		if seen_supporters.has(uid) or not effect_kinds.has(uid):
			return null
		seen_supporters[uid] = true
		claims[uid] = "supporter"
	var public_guards := {}
	if values.has("turn_program_semantic_guard_profile_id"):
		if values.get("turn_program_semantic_guard_profile_id") \
				!= "ptcgdap-turn-program-public-guard-v1":
			return null
		var draw_max: Variant = values.get("turn_program_semantic_guard_draw_max_own_hand")
		var disruption_max: Variant = values.get(
			"turn_program_semantic_guard_disruption_max_own_hand"
		)
		var disruption_min: Variant = values.get(
			"turn_program_semantic_guard_disruption_min_opponent_hand"
		)
		for amount: Variant in [draw_max, disruption_max, disruption_min]:
			if typeof(amount) != TYPE_INT or int(amount) < 0 or int(amount) > 30:
				return null
		for uid: Variant in str(values.get(
			"turn_program_semantic_draw_uids", ""
		)).split(",", false):
			public_guards[uid] = {
				"mode": "all", "max_own_hand_count": draw_max,
				"min_opponent_hand_count": null,
			}
		for uid: Variant in str(values.get(
			"turn_program_semantic_disruption_uids", ""
		)).split(",", false):
			public_guards[uid] = {
				"mode": "any", "max_own_hand_count": disruption_max,
				"min_opponent_hand_count": disruption_min,
			}
	var result := {
		"profile_id": "ptcgdap-turn-program-action-semantics-v1",
		"uid_effect_kinds": effect_kinds,
		"uid_resource_claims": claims,
		"uid_public_guards": public_guards,
	}
	return result if _supported_turn_program_action_semantics(result) else null


static func _supported_turn_program_action_semantics(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, [
		"profile_id", "uid_effect_kinds", "uid_resource_claims", "uid_public_guards",
	]) or value.get("profile_id") != "ptcgdap-turn-program-action-semantics-v1" \
			or not value.get("uid_effect_kinds") is Dictionary \
			or value.get("uid_effect_kinds", {}).is_empty() \
			or not value.get("uid_resource_claims") is Dictionary:
		return false
	var effects: Dictionary = value.get("uid_effect_kinds")
	var claims: Dictionary = value.get("uid_resource_claims")
	if effects.size() != claims.size():
		return false
	for uid: Variant in effects:
		if typeof(uid) != TYPE_STRING or str(uid).is_empty() or str(uid).length() > 128 \
				or not claims.has(uid) or effects.get(uid) not in [
					"draw", "disruption", "search", "conversion", "evolution", "bench",
				] or claims.get(uid) not in ["none", "supporter"]:
			return false
	var guards: Variant = value.get("uid_public_guards")
	if not guards is Dictionary:
		return false
	for uid: Variant in guards:
		var guard: Variant = guards.get(uid)
		if not effects.has(uid) or not guard is Dictionary or not _has_exact_keys(
			guard, ["mode", "max_own_hand_count", "min_opponent_hand_count"]
		) or guard.get("mode") not in ["all", "any"]:
			return false
		for key: String in ["max_own_hand_count", "min_opponent_hand_count"]:
			var amount: Variant = guard.get(key)
			if amount != null and (typeof(amount) != TYPE_INT \
					or int(amount) < 0 or int(amount) > 30):
				return false
		if guard.get("max_own_hand_count") == null \
				and guard.get("min_opponent_hand_count") == null:
			return false
	return true


static func _supported_turn_program_config(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, [
		"profile_id", "mode", "value_model", "canary_profile", "action_semantics",
	]) or value.get("profile_id") != "ptcgdap-turn-program-package-v1" \
			or value.get("mode") not in ["shadow", "canary"] \
			or not _supported_turn_program_value_model(value.get("value_model")):
		return false
	if value.get("mode") == "shadow":
		return value.get("canary_profile") == null
	return _supported_turn_program_canary_profile(value.get("canary_profile")) \
		and (value.get("action_semantics") == null \
		or _supported_turn_program_action_semantics(value.get("action_semantics")))


static func _supported_turn_program_value_model(value: Variant) -> bool:
	if value is Dictionary and value.get("profile_id") == ConditionedValueScript.PROFILE_ID:
		return ConditionedValueScript.is_model(value)
	var features := [
		"prize_gain_milli", "board_development_milli", "attack_pressure_milli",
		"next_turn_continuity_milli", "hand_quality_milli", "disruption_milli",
		"resource_preservation_milli", "risk_milli", "unresolved_debt_milli",
	]
	if not value is Dictionary or not _has_exact_keys(value, [
		"profile_id", "model_version", "feature_weights_milli",
	]) or value.get("profile_id") != "ptcgdap-turn-program-value-v1" \
			or typeof(value.get("model_version")) != TYPE_INT \
			or int(value.get("model_version")) < 1 \
			or not value.get("feature_weights_milli") is Dictionary \
			or not _has_exact_keys(value.get("feature_weights_milli", {}), features):
		return false
	for weight: Variant in value.get("feature_weights_milli", {}).values():
		if typeof(weight) != TYPE_INT or abs(int(weight)) > 100000:
			return false
	return true


static func _supported_turn_program_canary_profile(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, [
		"profile_id", "allowed_source_kinds", "allowed_current_effect_kinds",
		"max_uncertainty_milli", "minimum_utility_margin",
	]) or value.get("profile_id") != "ptcgdap-turn-program-canary-v1" \
			or not value.get("allowed_source_kinds") is Array \
			or value.get("allowed_source_kinds", []).is_empty() \
			or not value.get("allowed_current_effect_kinds") is Array \
			or value.get("allowed_current_effect_kinds", []).is_empty() \
			or typeof(value.get("max_uncertainty_milli")) != TYPE_INT \
			or int(value.get("max_uncertainty_milli")) < 0 \
			or int(value.get("max_uncertainty_milli")) > 1000 \
			or typeof(value.get("minimum_utility_margin")) != TYPE_INT \
			or int(value.get("minimum_utility_margin")) < 0 \
			or int(value.get("minimum_utility_margin")) > 10000000:
		return false
	var seen := {}
	for source: Variant in value.get("allowed_source_kinds", []):
		if source not in ["turn_transaction", "turn_route", "base_action"] or seen.has(source):
			return false
		seen[source] = true
	seen.clear()
	for effect: Variant in value.get("allowed_current_effect_kinds", []):
		if effect not in [
			"ability", "bench", "conversion", "damage_transfer", "disruption",
			"draw", "energy", "evolution", "handoff", "search", "tool",
		] or seen.has(effect):
			return false
		seen[effect] = true
	return true


static func _supported_ir(value: Dictionary) -> bool:
	var nodes: Variant = value.get("nodes")
	if (
		value.get("schema_version") != 1
		or value.get("profile_id") != "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
		or value.get("graph_id") != PACKAGE_ID
		or value.get("entry_node_id") != "n00"
		or not nodes is Array
		or nodes.size() != SUPPORTED_OPERATORS.size()
	):
		return false
	for index: int in nodes.size():
		var node: Variant = nodes[index]
		if not node is Dictionary:
			return false
		var expected_next: Array = [] if index == nodes.size() - 1 else [str(nodes[index + 1].get("node_id"))]
		if (
			node.get("operator") != SUPPORTED_OPERATORS[index]
			or node.get("owner") != SUPPORTED_OWNERS[index]
			or node.get("next_node_ids") != expected_next
		):
			return false
	return nodes[5].get("config", {}).get("strategy") == "same_window_first_min"


static func _supported_adapter(value: Dictionary) -> bool:
	return (
		value.get("schema_version") == 1
		and value.get("adapter_id") == PACKAGE_ID
		and value.get("adapter_version") == 1
		and value.get("card_id_domain") == CARD_ID_DOMAIN
		and value.get("rules") is Array
		and value.get("rules").size() == 7
	)


static func _supported_adapter_for_runtime(value: Dictionary, competitive_policy: Variant) -> bool:
	if value.get("schema_version") == 2:
		return (
			competitive_policy != null
			and not CompetitivePolicyV2Script.policy_public_dict(competitive_policy).is_empty()
			and CompetitivePolicyV2Script.policy_public_dict(competitive_policy) == value
		)
	return _supported_adapter(value)


static func _uids(value: Variant) -> Dictionary:
	var result := {}
	if value is Array:
		for item: Variant in value:
			if item is Dictionary and _local_uid(item.get("local_card_uid")):
				result[item.get("local_card_uid")] = true
	return result


static func _rank_less(left: Array, right: Array) -> bool:
	for index: int in mini(left.size(), right.size()):
		if left[index] == right[index]:
			continue
		return int(left[index]) < int(right[index])
	return left.size() < right.size()


static func _sum_counts(counts: Dictionary) -> int:
	var result := 0
	for value: Variant in counts.values():
		result += int(value)
	return result


static func _contains_forbidden_value(value: Variant) -> bool:
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return true
	if value is Array:
		for child: Variant in value:
			if _contains_forbidden_value(child):
				return true
	elif value is Dictionary:
		for key: Variant in value:
			if typeof(key) != TYPE_STRING or PRIVATE_KEYS.has(str(key).to_lower()) or _contains_forbidden_value(value[key]):
				return true
	return false


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value \
			and absf(value) <= 9007199254740991.0:
		return int(value)
	if value is Array:
		var array: Array = []
		for child: Variant in value:
			array.append(_coerce_integral_numbers(child))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key: Variant in value:
			dictionary[key] = _coerce_integral_numbers(value[key])
		return dictionary
	return value


static func _has_exact_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _local_uid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() < 3 or str(value).length() > 64:
		return false
	var separator := str(value).rfind("_")
	if separator <= 0 or separator == str(value).length() - 1:
		return false
	for index: int in str(value).length():
		var character := str(value).substr(index, 1)
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [".", "_"]):
			return false
	return true


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty():
		return false
	for index: int in str(value).length():
		var character := str(value).substr(index, 1)
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if (index == 0 and not alphanumeric) or (index > 0 and not alphanumeric and character not in [".", "_", "-"]):
			return false
	return true


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _selection_error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "selected_indexes": []}


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "policy": null}
