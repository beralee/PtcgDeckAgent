extends TestBase

const Cards = preload("res://tests/test_tournament_series59_pokemon.gd")
const Fixtures = preload("res://tests/test_30thdc_cards.gd")
var cards := Cards.new()
var f := Fixtures.new()

class UiCommitHarness extends "res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd":
	func _refresh_ui() -> void:
		pass
	func _maybe_run_ai() -> void:
		pass
	func _log(_message: String, _action: GameAction = null) -> void:
		pass

class DialogHarness extends Control:
	var _pending_choice := ""
	var _dialog_data := {}
	var shown := {}
	func _show_dialog(_title: String, _items: Array, data: Dictionary) -> void:
		shown = data

func _battle(tool_count: int = 3, second_holder: bool = false) -> Dictionary:
	var gsm := cards._battle("151C_085")
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	attacker.attached_energy.assign([f._energy("PSY")])
	var ko := state.players[1].active_pokemon
	ko.get_card_data().hp = 10
	ko.attached_energy.assign([f._energy("GRA", 1), f._energy("FIR", 1), f._energy("LIG", 1)])
	var holder := cards._slot("CSV4C_088", 1)
	state.players[1].bench.append(holder)
	for _i: int in tool_count:
		holder.attached_tools.append(CardInstance.create(cards._card("CSV1C_115"), 1))
	var other := f._slot("024", 1)
	if second_holder:
		other.attached_tool = CardInstance.create(cards._card("CSV1C_115"), 1)
		state.players[1].bench.append(other)
	return {"gsm": gsm, "ko": ko, "holder": holder, "other": other}

func test_each_exp_share_is_optional_and_same_holder_can_receive_two_distinct_energies() -> String:
	var setup := _battle()
	var gsm: GameStateMachine = setup.gsm
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var first: CardInstance = setup.ko.attached_energy[0]
	var second: CardInstance = setup.ko.attached_energy[1]
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	checks.append(assert_eq(gsm.get_pending_decision_snapshot().get("kind"), "exp_share_target"))
	checks.append(assert_true(gsm.resolve_exp_share_choice(1, setup.holder, second)))
	checks.append(assert_eq(setup.holder.attached_energy, [second]))
	checks.append(assert_eq(gsm.get_pending_decision_snapshot().get("kind"), "exp_share_target", "Next tool remains a separate decision"))
	checks.append(assert_false(gsm.resolve_exp_share_choice(1, setup.holder, second), "Already moved energy cannot be reused"))
	checks.append(assert_true(gsm.resolve_exp_share_choice(1, null), "Decline only this tool"))
	checks.append(assert_eq(gsm.get_pending_decision_snapshot().get("kind"), "exp_share_target", "Third card still offers its own choice"))
	checks.append(assert_true(gsm.resolve_exp_share_choice(1, setup.holder, first)))
	checks.append(assert_eq(setup.holder.attached_energy, [second, first]))
	checks.append(assert_false(gsm.get_pending_decision_snapshot().get("kind") == "exp_share_target"))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_exp_share_cannot_choose_another_tools_target_or_stale_energy() -> String:
	var setup := _battle(1, true)
	var gsm: GameStateMachine = setup.gsm
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	var energy: CardInstance = setup.ko.attached_energy[0]
	checks.append(assert_false(gsm.resolve_exp_share_choice(1, setup.other, energy)))
	checks.append(assert_false(gsm.resolve_exp_share_choice(1, setup.holder, f._energy("PSY", 1))))
	checks.append(assert_eq(setup.ko.attached_energy.size(), 3))
	checks.append(assert_true(gsm.resolve_exp_share_choice(1, setup.holder, energy)))
	checks.append(assert_eq(gsm.get_pending_decision_snapshot().get("bench"), [setup.other]))
	checks.append(assert_true(gsm.resolve_exp_share_choice(1, null)))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_exp_share_does_not_trigger_under_jamming_or_non_attack_knockout() -> String:
	var checks: Array[String] = []
	for suppressed: bool in [true, false]:
		var setup := _battle(2)
		var gsm: GameStateMachine = setup.gsm
		var state := gsm.game_state
		var bridge := HeadlessMatchBridge.new()
		bridge.bind(gsm)
		if suppressed:
			var stadium := CardData.new()
			stadium.card_type = "Stadium"
			stadium.effect_id = "4e16157bfa88a41e823d058a732df8e0"
			state.stadium_card = CardInstance.create(stadium, 0)
			checks.append(assert_true(gsm.use_attack(0, 0)))
		else:
			setup.ko.damage_counters = setup.ko.get_max_hp()
			gsm._resolve_mid_turn_knockouts()
		checks.append(assert_false(gsm.get_pending_decision_snapshot().get("kind") == "exp_share_target", "Only unsuppressed opponent attack damage triggers Exp. Share"))
		checks.append(assert_eq(setup.holder.attached_energy.size(), 0))
		bridge.bind(null)
		bridge.free()
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_host_exp_share_reobserves_each_copy_and_chooses_energy_or_declines() -> String:
	var setup := _battle()
	var gsm: GameStateMachine = setup.gsm
	var host: Dictionary = f._host(gsm, 1)
	if not host.get("ok", false):
		gsm.prepare_for_disposal()
		return "Exp. Share Host creation failed"
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var initial: Array = setup.ko.attached_energy.duplicate()
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	var handles: Array = []
	for choice: Array in [[1], [], [0]]:
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		f._check_frame(checkpoint, checks, handles)
		if not checkpoint.get("ok", false):
			break
		checks.append(assert_eq(checkpoint.frame.select_semantics.min_count, 0))
		checks.append(assert_true(host.port.submit(str(checkpoint.window_handle), choice).get("ok", false)))
		checks.append(assert_true(host.owner.run_single_step(bridge, gsm)))
		checks.append(assert_false(host.port.submit(str(checkpoint.window_handle), choice).get("ok", false)))
	checks.append(assert_eq(setup.holder.attached_energy, [initial[1], initial[0]]))
	checks.append(assert_eq(handles.size(), 3))
	bridge.bind(null)
	bridge.free()
	f._close_host(host, gsm, 3, checks)
	return run_checks(checks)

func test_ui_exp_share_allows_zero_and_preserves_synchronously_published_next_copy() -> String:
	var setup := _battle(2)
	var gsm: GameStateMachine = setup.gsm
	var ui := UiCommitHarness.new()
	ui.set("_gsm", gsm)
	var relay := func(kind: String, data: Dictionary) -> void:
		ui.set("_pending_choice", kind)
		ui.set("_dialog_data", data)
	gsm.player_choice_required.connect(relay)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	var source_energy: CardInstance = setup.ko.attached_energy[1]
	ui._commit_exp_share_assignment([])
	checks.append(assert_eq(ui.get("_pending_choice"), "exp_share_target", "Decline keeps the next tool prompt"))
	checks.append(assert_eq(setup.holder.attached_energy.size(), 0))
	ui._commit_exp_share_assignment([{"source": source_energy, "target": setup.holder}])
	checks.append(assert_eq(setup.holder.attached_energy, [source_energy]))
	checks.append(assert_eq(ui.get("_pending_choice"), "take_prize", "UI commit must preserve the next knockout decision"))
	var dialog := DialogHarness.new()
	var sources: Array[CardInstance] = [source_energy]
	var targets: Array[PokemonSlot] = [setup.holder]
	BattleDialogController.new().show_exp_share_dialog(dialog, 1, targets, setup.ko, sources)
	checks.append(assert_eq(dialog.shown.min_select, 0, "Confirming empty assignment is available in the real dialog definition"))
	dialog.free()
	gsm.player_choice_required.disconnect(relay)
	ui.set("_gsm", null)
	ui.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_classic_ai_consumes_each_exp_share_without_clearing_the_followup_prompt() -> String:
	var setup := _battle(3)
	var gsm: GameStateMachine = setup.gsm
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var ai := AIOpponent.new()
	ai.configure(1, 1)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	for count: int in range(1, 4):
		checks.append(assert_true(ai.run_single_step(bridge, gsm)))
		checks.append(assert_eq(setup.holder.attached_energy.size(), count))
		if count < 3:
			checks.append(assert_eq(bridge._pending_choice, "exp_share_target"))
	checks.append(assert_eq(bridge._pending_choice, "take_prize"))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)
