class_name TestMarnieGiftBoxTurnTransactionR55ChainOnly
extends TestBase

const FullSuiteScript = preload(
	"res://tests/ptcgdap/godot/test_marnie_gift_box_turn_transaction_r55_exams.gd"
)


func test_r55_same_turn_transaction_chain_only() -> String:
	return FullSuiteScript.new().test_r55_same_turn_transaction_rebinds_evolution_disruption_energy_then_attack()


func test_r55_wall_and_two_prize_race_only() -> String:
	return FullSuiteScript.new().test_r55_zero_damage_wall_is_one_devolution_transaction()


func test_r55_munkidori_self_preservation_only() -> String:
	return FullSuiteScript.new().test_r55_low_hp_munkidori_moves_its_own_damage_before_commit()


func test_r55_survival_reserve_only() -> String:
	return FullSuiteScript.new().test_r55_survival_phase_benches_useful_reserve_but_never_late_budew()


func test_r55_development_search_only() -> String:
	return FullSuiteScript.new().test_r55_search_stage_builds_two_safe_tm_evolution_targets_without_budew()


func test_r55_tm_postcondition_only() -> String:
	return FullSuiteScript.new().test_r55_tm_evolution_transaction_requires_two_safe_targets_before_commit()


func test_r55_spikemuth_backup_chain_only() -> String:
	return FullSuiteScript.new().test_r55_spikemuth_completes_backup_grimmsnarl_before_turn_commit()


func test_r55_rescue_board_retreat_gate_only() -> String:
	return FullSuiteScript.new().test_r55_low_hp_munkidori_retreat_transaction_requires_rescue_board_window()


func test_r55_search_owned_tm_chains_only() -> String:
	return FullSuiteScript.new().test_r55_search_owned_tm_chains_fund_active_before_evolution_or_devolution()
