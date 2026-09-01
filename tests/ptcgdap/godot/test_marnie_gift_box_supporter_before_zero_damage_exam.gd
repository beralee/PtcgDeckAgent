class_name TestMarnieGiftBoxSupporterBeforeZeroDamageExam
extends TestBase

const CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const EXAM_IDS := {
	"t7_research_before_zero_damage_attack_to_find_munkidori_energy": true,
	"t7_attach_dark_to_munkidori_after_research_before_zero_damage_attack": true,
	"t21_attach_active_munkidori_before_iono_at_opponent_one_prize": true,
	"t4_research_before_shadow_bullet_with_two_unevolved_snorunt": true,
	"t13_attach_tm_devolution_before_ending_into_evolved_damage_wall": true,
	"t13_use_tm_devolution_granted_attack_after_attaching_into_damage_wall": true,
	"t5_retreat_weak_impidimp_into_ready_grimmsnarl_before_attack": true,
	"t19_shadow_bullet_chip_lower_hp_crustle_for_froslass_finish": true,
	"t6_morgrem_take_two_prize_ko_instead_of_empty_tm_evolution": true,
	"t5_attach_munkidori_before_hand_evolving_preserved_morgrem_bridge": true,
	"t3_arven_prefers_poffin_without_active_budew_tm_pivot": true,
	"t3_arven_keeps_ultra_ball_without_active_budew_tm_pivot": true,
	"t31_do_not_add_second_froslass_after_damage_engine_expiry": true,
	"t5_night_stretcher_takes_dark_energy_before_zero_energy_morgrem": true,
	"t5_iono_before_zero_active_damage_shadow_bullet_while_core_incomplete": true,
	"t8_energy_search_before_nonterminal_shadow_bullet_to_fund_first_munkidori": true,
	"t5_boss_gusts_two_prize_ogerpon_before_zero_damage_wall_attack": true,
	"t5_night_stretcher_keeps_impidimp_when_morgrem_bridge_has_no_dark_energy": true,
	"t11_evolve_funded_impidimp_to_morgrem_before_nonterminal_ko": true,
	"t13_counter_catcher_two_prize_route_before_weak_impidimp_attack": true,
	"t26_do_not_boss_before_funding_one_energy_grimmsnarl": true,
	"t26_end_turn_after_munkidori_and_attachment_into_late_wall": true,
	"t6_iono_draws_for_first_froslass_instead_of_arven_dead_end": true,
	"t18_iono_denies_opponent_last_prize_before_ending": true,
	"t8_spikemuth_completes_energy_bearing_morgrem_backup": true,
	"t10_bench_munkidori_after_arven_before_nonterminal_shadow_bullet": true,
	"t11_send_out_ready_impidimp_over_zero_energy_grimmsnarl": true,
	"t5_arven_over_iono_with_two_snorunt_and_full_bench": true,
	"t19_energy_search_before_end_to_finish_active_munkidori": true,
	"t4_energy_search_after_supporter_before_nonterminal_shadow_bullet": true,
	"t4_research_before_nonterminal_shadow_bullet_without_froslass": true,
	"t3_retreat_early_budew_into_funded_impidimp_for_live_tm_evolution": true,
	"t5_attach_tm_evolution_before_zero_damage_grimmsnarl_wall_attack": true,
	"t25_secret_box_preserves_boss_for_last_prize_candy_grimmsnarl_chain": true,
	"t25_secret_box_takes_night_stretcher_for_candy_grimmsnarl_last_prize_chain": true,
	"t3_retreat_developed_active_froslass_into_ready_grimmsnarl_before_ending": true,
	"t5_attach_tm_evolution_to_funded_impidimp_before_optional_munkidori_energy_search": true,
	"t9_skip_energy_search_when_munkidori_already_has_dark": true,
	"t9_send_out_funded_munkidori_over_unevolved_snorunt_for_live_transfer_line": true,
	"t7_retreat_active_munkidori_into_ready_grimmsnarl_before_passing": true,
	"t10_bench_munkidori_before_spending_supporter_with_live_froslass_transfer": true,
	"t18_research_for_gust_or_devolution_out_before_zero_damage_last_chance_end": true,
	"t16_use_active_munkidori_before_retreating_into_ready_grimmsnarl": true,
	"t16_hold_low_hp_funded_munkidori_after_transfer_instead_of_spending_retreat": true,
	"t7_iono_before_zero_damage_wall_chip_with_completed_core": true,
	"t15_do_not_bench_unfunded_backup_munkidori_before_supporter": true,
	"t4_retreat_budew_into_funded_impidimp_from_second_own_turn": true,
	"t4_keep_budew_wall_when_ready_grimmsnarl_core_is_already_built": true,
	"t6_spikemuth_and_froslass_development_before_active_munkidori_retreat": true,
	"t7_artazon_development_before_active_munkidori_retreat": true,
	"t6_send_out_ready_grimmsnarl_before_late_munkidori_transfer_phase": true,
	"t7_tm_evolution_selects_energy_morgrem_and_snorunt_together": true,
	"t15_research_before_zero_damage_end_with_stalled_grimmsnarl": true,
	"t21_evolve_froslass_before_end_with_funded_munkidori": true,
	"t9_spikemuth_before_tm_devolution_with_funded_impidimp": true,
	"t8_hold_healthy_funded_munkidori_after_transfer_with_live_froslass": true,
	"t7_fund_active_munkidori_before_ready_grimmsnarl_retreat": true,
	"t14_iono_over_arven_at_even_two_prizes_without_core": true,
	"t14_evolve_froslass_before_tm_evolution_granted_attack": true,
	"t15_research_before_nonterminal_shadow_bullet_with_double_munkidori_no_froslass": true,
	"t12_research_before_last_prize_pass_with_active_froslass_ready_grimmsnarl_bench": true,
	"t13_iono_before_pass_with_unfunded_active_munkidori_ready_grimmsnarl_bench": true,
	"t13_self_switch_rebinds_ready_grimmsnarl_after_munkidori_retreat": true,
	"t12_research_before_last_prize_pass_when_retreat_ledger_unused_but_no_retreat_option": true,
}
const HarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)


func test_research_before_zero_damage_attack_to_find_munkidori_energy() -> String:
	var corpus: Dictionary = HarnessScript.load_corpus(CORPUS_PATH)
	var selected_exams: Array[Dictionary] = []
	for exam_value: Variant in corpus.get("exams", []):
		if exam_value is Dictionary and EXAM_IDS.has(exam_value.get("exam_id")):
			selected_exams.append(exam_value)
	corpus["exams"] = selected_exams
	var report: Dictionary = HarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_eq(selected_exams.size(), 64),
		assert_true(bool(report.get("ok", false)), "exam runner failed: %s" % report),
		assert_true(
			bool(report.get("all_passed", false)),
			"supporter-before-zero-damage mismatch: %s" % report
		),
	])
