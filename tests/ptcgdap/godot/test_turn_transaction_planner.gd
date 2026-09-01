class_name TestTurnTransactionPlanner
extends RefCounted

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
const JournalScript = preload("res://scripts/ai/ptcgdap/public/TurnTransactionJournal.gd")

const GRIMMSNARL := "M2_001"
const IONO := "PAL_185"
const TM_EVOLUTION := "PAR_178"
const DARK := "SVI_003"


func test_transaction_rebinds_each_window_and_base_remains_final() -> String:
	var compiled: Dictionary = RuntimeScript.compile_local_uid(
		_document(), [GRIMMSNARL, IONO, TM_EVOLUTION]
	)
	if not bool(compiled.get("accepted", false)):
		return "turn transaction compile rejected: %s" % compiled.get("error_code")
	var policy: Dictionary = compiled.get("policy", {})
	var journal: Variant = JournalScript.new("match-1", 0, "test.package@1")
	var first := _frame([
		_option(0, "attack"),
		_option(1, "play_trainer", IONO),
		_option(2, "play_trainer", TM_EVOLUTION),
	], 3)
	var live: Dictionary = RuntimeScript.decide(
		policy, first, [], [], [], [], null, journal
	)
	if not bool(live.get("accepted", false)) or live.get("selected_indexes") != [1]:
		return "live transaction debt did not own Iono: %s" % live
	var transaction: Dictionary = live.get("audit", {}).get("turn_transaction", {})
	if (
		transaction.get("transaction_id") != "develop-before-attack"
		or transaction.get("method_id") != "supporter-then-evolution"
		or transaction.get("step_id") != "refresh-hand"
		or not bool(transaction.get("attack_commit_blocked", false))
	):
		return "live transaction audit mismatch: %s" % transaction

	var second := _frame([
		_option(0, "play_trainer", TM_EVOLUTION),
		_option(1, "attack"),
	], 4)
	second["public_state"]["self"]["hand"] = [
		{"serial": 2, "local_card_uid": TM_EVOLUTION},
	]
	second["public_state"]["self"]["turn"]["supporter_available"] = false
	var rebound: Dictionary = RuntimeScript.decide(
		policy, second, [], [], [], [], null, journal
	)
	if rebound.get("selected_indexes") != [0]:
		return "semantic step did not rebind after reorder: %s" % rebound
	if rebound.get("audit", {}).get("turn_transaction", {}).get("step_id") != "double-evolution":
		return "transaction did not advance to double evolution"
	var snapshot_text := JSON.stringify(journal.snapshot())
	for forbidden: String in ["index", "window", "observation_hash", "score", "binding", "proof"]:
		if forbidden in snapshot_text:
			return "journal persisted stale authority field %s: %s" % [forbidden, snapshot_text]

	var rearbitrate_document := _document()
	rearbitrate_document["turn_transactions"].append({
		"transaction_id": "search-window-transaction",
		"priority": 2000,
		"goal_id": "core-online",
		"deadline_turns": 0,
		"when": [_condition("prompt_kind", "eq", "search")],
		"success_when": [],
		"abort_when": [],
		"methods": [{
			"method_id": "bind-fresh-search-window",
			"priority": 1000,
			"when": [],
			"steps": [{
				"step_id": "select-evolution-tool",
				"prompt_kinds": ["search"],
				"goal_id": "core-online",
				"required_when": [],
				"complete_when": [],
				"option_when": [_condition("option.card_uid", "eq", TM_EVOLUTION)],
				"score_bonus": 300000,
				"selection_count": 1,
				"terminal": true,
				"checkpoint": true,
				"required_before_attack": true,
			}],
		}],
	})
	var rearbitrate_compiled: Dictionary = RuntimeScript.compile_local_uid(
		rearbitrate_document, [GRIMMSNARL, IONO, TM_EVOLUTION]
	)
	if not bool(rearbitrate_compiled.get("accepted", false)):
		return "re-arbitration fixture rejected: %s" % rearbitrate_compiled
	var rearbitrate_journal: Variant = JournalScript.new(
		"match-rearbitrate", 0, "test.package@1"
	)
	RuntimeScript.decide(
		rearbitrate_compiled.get("policy", {}), first,
		[], [], [], [], null, rearbitrate_journal
	)
	var search_window := _frame([_option(0, "search", TM_EVOLUTION)], 3)
	search_window["prompt_kind"] = "search"
	search_window["source"]["public_observation_hash"] = "E".repeat(64)
	search_window["source"]["window_id"] = "F".repeat(64)
	var rearbitrated: Dictionary = RuntimeScript.decide(
		rearbitrate_compiled.get("policy", {}), search_window,
		[], [], [], [], null, rearbitrate_journal
	)
	var rearbitrated_tx: Dictionary = rearbitrated.get(
		"audit", {}
	).get("turn_transaction", {})
	if rearbitrated.get("selected_indexes") != [0] \
			or rearbitrated_tx.get("transaction_id") != "search-window-transaction" \
			or rearbitrated_tx.get("step_id") != "select-evolution-tool":
		return "stale transaction retained authority after entry invalidation: %s" % rearbitrated

	var terminal: Dictionary = RuntimeScript.decide(
		policy, first, [], [0], [], [], null, journal
	)
	if terminal.get("selected_indexes") != [0] \
		or terminal.get("audit", {}).get("owner_layer") != "terminal":
		return "Base terminal authority did not remain final: %s" % terminal
	var no_safe_step := _frame([_option(0, "attack")], 3)
	var fresh_journal: Variant = JournalScript.new("match-2", 0, "test.package@1")
	var attacked: Dictionary = RuntimeScript.decide(
		policy, no_safe_step, [], [], [], [], null, fresh_journal
	)
	if attacked.get("selected_indexes") != [0]:
		return "no-safe-step window created broad attack-last behavior: %s" % attacked
	if bool(attacked.get("audit", {}).get("turn_transaction", {}).get("attack_commit_blocked", true)):
		return "no-safe-step window incorrectly blocked attack"
	var end_commit: Dictionary = RuntimeScript.decide(
		policy,
		_frame([
			_option(0, "play_trainer", IONO),
			_option(1, "end_turn"),
		], 3),
		[], [], [], [], null,
		JournalScript.new("match-end-commit", 0, "test.package@1")
	)
	if end_commit.get("selected_indexes") != [0]:
		return "safe transaction debt did not preempt end-turn commit: %s" % end_commit
	var end_transaction: Dictionary = end_commit.get("audit", {}).get("turn_transaction", {})
	if not bool(end_transaction.get("turn_commit_blocked", false)) \
			or bool(end_transaction.get("attack_commit_blocked", true)):
		return "end-turn commit audit mismatch: %s" % end_transaction

	var attack_window_document := _document()
	attack_window_document["turn_transactions"][0]["methods"][0]["steps"][0][
		"required_when"
	].append(_condition("window.attack_option_count", "gt", 0))
	var attack_window_compiled: Dictionary = RuntimeScript.compile_local_uid(
		attack_window_document, [GRIMMSNARL, IONO, TM_EVOLUTION]
	)
	if not bool(attack_window_compiled.get("accepted", false)):
		return "attack-window transaction fixture rejected: %s" % attack_window_compiled
	var without_attack: Dictionary = RuntimeScript.decide(
		attack_window_compiled.get("policy", {}),
		_frame([
			_option(0, "play_trainer", IONO),
			_option(1, "end_turn"),
		], 3),
		[], [], [], [], null,
		JournalScript.new("match-no-attack", 0, "test.package@1")
	)
	if without_attack.get("selected_indexes") != [1]:
		return "attack-gated debt fired without a legal attack: %s" % without_attack
	var with_attack: Dictionary = RuntimeScript.decide(
		attack_window_compiled.get("policy", {}),
		_frame([
			_option(0, "attack"),
			_option(1, "play_trainer", IONO),
		], 3),
		[], [], [], [], null,
		JournalScript.new("match-live-attack", 0, "test.package@1")
	)
	if with_attack.get("selected_indexes") != [1] \
			or with_attack.get("audit", {}).get(
				"turn_transaction", {}
			).get("step_id") != "refresh-hand":
		return "legal attack did not expose attack-gated debt: %s" % with_attack

	var noncommit_document := _document()
	noncommit_document["turn_transactions"][0]["methods"][0]["steps"][0]["score_bonus"] = 900000
	noncommit_document["turn_transactions"][0]["methods"][0]["steps"][0]["terminal"] = true
	noncommit_document["rules"].append({
		"rule_id": "fund-before-supporter",
		"goal_id": "core-online",
		"goal_stage": "deploy",
		"channel": "tactical",
		"horizon": 0,
		"confidence_milli": 1000,
		"base_score": 400000,
		"when": [_condition("option.kind", "eq", "attach_energy")],
		"score_terms": [],
	})
	var noncommit_compiled: Dictionary = RuntimeScript.compile_local_uid(
		noncommit_document, [DARK, GRIMMSNARL, IONO, TM_EVOLUTION]
	)
	if not bool(noncommit_compiled.get("accepted", false)):
		return "noncommit transaction fixture rejected: %s" % noncommit_compiled
	var noncommit: Dictionary = RuntimeScript.decide(
		noncommit_compiled.get("policy", {}),
		_frame([
			_option(0, "attack"),
			_option(1, "play_trainer", IONO),
			_option(2, "attach_energy", DARK),
		], 3),
		[], [], [], [], null,
		JournalScript.new("match-noncommit", 0, "test.package@1")
	)
	if noncommit.get("selected_indexes") != [2]:
		return "transaction preempted better noncommit proposal: %s" % noncommit
	if bool(noncommit.get("audit", {}).get("turn_contract", {}).get("route_authority_applied", true)):
		return "transaction incorrectly claimed authority over noncommit proposal"

	var route_document := _document()
	route_document["turn_transactions"][0]["methods"][0]["steps"][0]["score_bonus"] = 900000
	route_document["turn_transactions"][0]["methods"][0]["steps"][0]["terminal"] = true
	route_document["turn_routes"] = [{
		"route_id": "supporter-before-commit",
		"priority": 1000,
		"goal_id": "core-online",
		"owner_goal_id": "core-online",
		"bridge_goal_id": "core-online",
		"pivot_goal_id": "core-online",
		"when": [],
		"steps": [{
			"step_id": "disrupt-before-tm",
			"prompt_kinds": ["main"],
			"goal_id": "core-online",
			"when": [],
			"option_when": [_condition("option.card_uid", "eq", IONO)],
			"score_bonus": 600000,
			"selection_count": 1,
			"terminal": false,
			"checkpoint": true,
		}],
	}]
	var route_compiled: Dictionary = RuntimeScript.compile_local_uid(
		route_document, [DARK, GRIMMSNARL, IONO, TM_EVOLUTION]
	)
	if not bool(route_compiled.get("accepted", false)):
		return "route arbitration fixture rejected: %s" % route_compiled
	var route_decision: Dictionary = RuntimeScript.decide(
		route_compiled.get("policy", {}),
		_frame([
			_option(0, "attack"),
			_option(1, "play_trainer", IONO),
			_option(2, "play_trainer", TM_EVOLUTION),
		], 3),
		[], [], [], [], null,
		JournalScript.new("match-route-arbitration", 0, "test.package@1")
	)
	if route_decision.get("selected_indexes") != [1]:
		return "transaction hid independent turn-route proposal: %s" % route_decision
	var route_contract: Dictionary = route_decision.get("audit", {}).get("turn_contract", {})
	if bool(route_contract.get("route_authority_applied", true)) \
			or route_contract.get("proposal_route_id") != "supporter-before-commit":
		return "route arbitration audit mismatch: %s" % route_contract
	return ""


func _document() -> Dictionary:
	return {
		"schema_version": 2,
		"adapter_id": "test.turn-transaction-v1",
		"adapter_version": 2,
		"goals": [{
			"goal_id": "core-online",
			"stage": "deploy",
			"priority": 1000,
			"requirements": [{
				"card_uid": GRIMMSNARL,
				"ready_target_count": 1,
				"energy_required": 2,
			}],
		}],
		"count_rules": [],
		"rules": [{
			"rule_id": "neutral.attack",
			"goal_id": "core-online",
			"goal_stage": "execute",
			"channel": "tactical",
			"horizon": 0,
			"confidence_milli": 1000,
			"base_score": 0,
			"when": [_condition("option.kind", "eq", "attack")],
			"score_terms": [],
		}],
		"turn_transactions": [{
			"transaction_id": "develop-before-attack",
			"priority": 1000,
			"goal_id": "core-online",
			"deadline_turns": 1,
			"when": [_condition("prompt_kind", "eq", "main")],
			"success_when": [
				_condition("self.hand.count_uid", "eq", 0, IONO),
				_condition("self.hand.count_uid", "eq", 0, TM_EVOLUTION),
			],
			"abort_when": [],
			"methods": [{
				"method_id": "supporter-then-evolution",
				"priority": 1000,
				"when": [],
				"steps": [
					{
						"step_id": "refresh-hand",
						"prompt_kinds": ["main"],
						"goal_id": "core-online",
						"required_when": [
							_condition("self.hand.count_uid", "gte", 1, IONO),
							_condition("turn.supporter_available", "eq", true),
						],
						"complete_when": [_condition("self.hand.count_uid", "eq", 0, IONO)],
						"option_when": [_condition("option.card_uid", "eq", IONO)],
						"score_bonus": 200000,
						"selection_count": 1,
						"terminal": false,
						"checkpoint": true,
						"required_before_attack": true,
					},
					{
						"step_id": "double-evolution",
						"prompt_kinds": ["main"],
						"goal_id": "core-online",
						"required_when": [_condition("self.hand.count_uid", "gte", 1, TM_EVOLUTION)],
						"complete_when": [_condition("self.hand.count_uid", "eq", 0, TM_EVOLUTION)],
						"option_when": [_condition("option.card_uid", "eq", TM_EVOLUTION)],
						"score_bonus": 200000,
						"selection_count": 1,
						"terminal": true,
						"checkpoint": true,
						"required_before_attack": true,
					},
				],
			}],
		}],
	}


func _condition(fact: String, op: String, value: Variant, card_uid: Variant = null) -> Dictionary:
	return {"fact": fact, "op": op, "value": value, "card_uid": card_uid}


func _frame(options: Array, turn_number: int) -> Dictionary:
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": turn_number,
		"seat": 0,
		"prompt_kind": "main",
		"source": {
			"public_observation_hash": ("A" if turn_number == 3 else "C").repeat(64),
			"window_id": ("B" if turn_number == 3 else "D").repeat(64),
		},
		"public_state": {
			"turn_number": turn_number,
			"phase": "MAIN",
			"self": {
				"hand": [
					{"serial": 1, "local_card_uid": IONO},
					{"serial": 2, "local_card_uid": TM_EVOLUTION},
				],
				"active": [], "bench": [], "discard": [],
				"deck_count": 30, "prizes_remaining": 4,
				"turn": {
					"supporter_available": true,
					"manual_attachment_available": true,
					"retreat_available": true,
				},
			},
			"opponent": {
				"hand_count": 7, "active": [], "bench": [], "discard": [],
				"deck_count": 28, "prizes_remaining": 4,
			},
		},
		"select_semantics": {
			"min_count": 1, "max_count": 1,
			"select_type_raw": 1, "select_context_raw": 0,
		},
		"options": options,
	}


func _option(index: int, kind: String, card_uid: Variant = null) -> Dictionary:
	var attack_source: Variant = GRIMMSNARL if kind == "attack" else null
	return {
		"index": index, "kind": kind,
		"card_uid": card_uid, "card_serial": 1000 + index if card_uid != null else null,
		"source_uid": attack_source,
		"source_serial": 2000 + index if attack_source != null else null,
		"target_uid": null, "target_serial": null,
		"target_remaining_hp": null, "target_prize_value": null,
		"target_attached_energy_count": null, "target_attached_energy_uids": null,
		"target_minimum_attack_energy_count": null, "target_attack_ready": null,
		"target_energy_debt": null, "projected_damage": 160 if kind == "attack" else null,
		"projected_knockout": false, "requires_interaction": false,
		"attack_index": 0 if kind == "attack" else null,
		"option_number": null, "ability_index": null,
		"energy_type_raw": null, "energy_count": null,
		"special_condition_type": null, "pending_assignment_count": 0,
		"tags": [], "option_type_raw": 14 if kind == "end_turn" else (13 if kind == "attack" else 7),
		"option_player_index": 0,
	}
