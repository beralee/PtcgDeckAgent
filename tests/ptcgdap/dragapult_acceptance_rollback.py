from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
from typing import Final

from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT: Final = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT: Final = ROOT / "artifacts/ptcgdap/dragapult_python_e2e/parent_snapshot"
MANIFEST_PATH: Final = SNAPSHOT_ROOT / "manifest.json"

ADDITIVE_EXACT_PATHS: Final = frozenset(
    {
        "artifacts/ptcgdap/dragapult_python_e2e_10_games.json",
        "artifacts/ptcgdap/dragapult_python_e2e_both_seats.json",
        "artifacts/ptcgdap/dragapult_python_e2e_smoke.json",
        "contracts/ptcgdap/dragapult_python_strategy.schema.json",
        "contracts/ptcgdap/dragapult_python_strategy_bundle.json",
        "contracts/ptcgdap/dragapult_python_strategy_conformance_vectors.json",
        "contracts/ptcgdap/dragapult_python_strategy_profile.json",
        "data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json",
        "data/ptcgdap/dragapult_python_strategy/policy_v1.json",
        "data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json",
        "scripts/ai/ptcgdap/dragapult_public_strategy.py",
        "tests/ptcgdap/dragapult_acceptance_rollback.py",
        "tests/ptcgdap/test_dragapult_python_acceptance_evidence.py",
        "tests/ptcgdap/test_dragapult_public_strategy.py",
        "tests/ptcgdap/godot/run_dragapult_python_e2e.gd",
        "tests/ptcgdap/godot/run_dragapult_python_e2e.gd.uid",
        "tests/ptcgdap/godot/run_dragapult_python_e2e.tscn",
        "tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd",
        "tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd.uid",
        "tests/test_dragapult_python_public_strategy_e2e.gd",
        "tests/test_dragapult_python_public_strategy_e2e.gd.uid",
        "tools/ptcgdap/build_dragapult_python_strategy_contract.py",
        "tools/ptcgdap/build_dragapult_python_acceptance_evidence.py",
        "tools/ptcgdap/capture_dragapult_python_acceptance_parent.py",
        "tools/ptcgdap/run_dragapult_public_strategy.py",
        "tools/ptcgdap/build_as_wp6_windows_profile_approval_evidence.py",
        "tests/ptcgdap/test_as_wp6_windows_profile_approval_evidence.py",
    }
)

# D043-D056 were accepted after the Dragapult parent was sealed. Older
# virtual-rollback tests must omit these additive paths while continuing to
# restore every byte that existed in their own parent candidate.
POST_ACCEPTANCE_DEVELOPMENT_PATHS: Final = frozenset(
    {
        "artifacts/ptcgdap/as_wp6_development_execution/README.md",
        "artifacts/ptcgdap/as_wp6_windows_player_owner/README.md",
        "artifacts/ptcgdap/as_wp6_windows_player_owner/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_player_owner/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_player_owner/player_owner_10_games.json",
        "artifacts/ptcgdap/as_wp6_windows_player_owner/test_results.json",
        "artifacts/ptcgdap/marnie_package_rules_e2e_10_games.json",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
        "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
        "tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.gd",
        "tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.tscn",
        "tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.gd",
        "tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.tscn",
        "tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd",
        "tests/ptcgdap/godot/test_author_strategy_package_rules_e2e.gd",
        "tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd",
        "tests/ptcgdap/test_author_strategy_development_execution.py",
        "tests/ptcgdap/test_author_strategy_windows_player_owner_evidence.py",
        # Godot generated these sidecars only after the D044 execution slice
        # had already been accepted.  They are additive even though the owning
        # scripts belong to the preceding work package.
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd.uid",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd.uid",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd.uid",
        "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd.uid",
        "tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.gd.uid",
        "tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.gd.uid",
        "tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd.uid",
        "tests/ptcgdap/godot/test_author_strategy_package_rules_e2e.gd.uid",
        "tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd.uid",
        # D045 exported-Windows complete-match development acceptance.
        "artifacts/ptcgdap/as_wp6_windows_export_match/README.md",
        "artifacts/ptcgdap/as_wp6_windows_export_match/diagnostic_history.md",
        "artifacts/ptcgdap/as_wp6_windows_export_match/export_artifact_summary.json",
        "artifacts/ptcgdap/as_wp6_windows_export_match/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_export_match/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_export_match/reproducibility_audit.json",
        "artifacts/ptcgdap/as_wp6_windows_export_match/runtime_seed_marker.json",
        "artifacts/ptcgdap/as_wp6_windows_export_match/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_export_match/windows_export_match_3games.json",
        "data/bundled_user/_seed_content_sha256.txt",
        "scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsExportMatchAcceptance.gd",
        "scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsExportMatchAcceptance.gd.uid",
        "scripts/tools/run_ptcgdap_exported_windows_match.ps1",
        "scripts/tools/run_ptcgdap_windows_export_match.gd",
        "scripts/tools/run_ptcgdap_windows_export_match.gd.uid",
        "tests/ptcgdap/godot/test_author_strategy_export_match_acceptance.gd",
        "tests/ptcgdap/godot/test_author_strategy_export_match_acceptance.gd.uid",
        "tests/ptcgdap/test_author_strategy_windows_export_match_evidence.py",
        "tests/ptcgdap/test_bundled_seed_revision.py",
        "tools/ptcgdap/build_bundled_seed_revision.py",
        # D046 ordinary Windows UI execution and independent feature rollback.
        "artifacts/ptcgdap/as_wp6_windows_ui_match/README.md",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/rollback_drill.json",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/windows_release_match_summary.json",
        "artifacts/ptcgdap/as_wp6_windows_ui_match/windows_ui_match_summary.json",
        "scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsUiMatchAcceptance.gd",
        "scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsUiMatchAcceptance.gd.uid",
        "scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd",
        "scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd.uid",
        "scripts/tools/run_ptcgdap_windows_ui_match.gd",
        "scripts/tools/run_ptcgdap_windows_ui_match.gd.uid",
        "scripts/tools/run_ptcgdap_windows_ui_match.ps1",
        "scripts/tools/run_ptcgdap_author_strategy_rollback_drill.ps1",
        # Post-D046 AS-WP6 formal Windows OS-isolation evidence tooling.
        "scripts/tools/run_ptcgdap_windows_os_isolation_acceptance.ps1",
        "tests/ptcgdap/test_author_strategy_windows_os_isolation_tool.py",
        "tests/ptcgdap/test_author_strategy_windows_ui_match_evidence.py",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/README.md",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/non_admin_refusal.json",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/timing_smoke_summary.json",
        # D048 production-signed acceptance-only Windows device-canary path.
        "artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/README.md",
        "artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/windows_development_ui_regression.json",
        "data/ptcgdap/author_strategy_device_canary_approvals.json",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd.uid",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd",
        "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd.uid",
        "tests/ptcgdap/test_author_strategy_device_canary_boundary.py",
        # D069 exact-package prompt-conformance evidence-hash binding.
        "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
        "tools/ptcgdap/build_as_wp6_prompt_conformance_binding_evidence.py",
        "tests/ptcgdap/test_as_wp6_prompt_conformance_binding_evidence.py",
        # D070 dedicated product trust and exact package signing.
        "tools/ptcgdap/sign_author_strategy_product_release_candidate.py",
        "tools/ptcgdap/build_as_wp6_product_signing_evidence.py",
        "tests/ptcgdap/test_author_strategy_product_release_signing.py",
        "tests/ptcgdap/test_as_wp6_product_signing_evidence.py",
        # D049 current-observation/current-window policy-response binding.
        "artifacts/ptcgdap/as_wp6_same_window_response_binding/README.md",
        "artifacts/ptcgdap/as_wp6_same_window_response_binding/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_same_window_response_binding/manifest.json",
        "artifacts/ptcgdap/as_wp6_same_window_response_binding/test_results.json",
        # D050 deterministic Godot Windows export-container ownership.
        "artifacts/ptcgdap/as_wp6_windows_deterministic_export/README.md",
        "artifacts/ptcgdap/as_wp6_windows_deterministic_export/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_deterministic_export/manifest.json",
        "artifacts/ptcgdap/as_wp6_windows_deterministic_export/reproducibility_report.json",
        "artifacts/ptcgdap/as_wp6_windows_deterministic_export/test_results.json",
        "tests/ptcgdap/test_as_wp6_deterministic_export_evidence.py",
        "tests/ptcgdap/test_godot_export_canonicalizer.py",
        "tools/ptcgdap/canonicalize_godot_export.py",
        # D051 immutable Windows policy_package_v1 and explicit no-model lane.
        "artifacts/ptcgdap/as_wp6_policy_package_v1/README.md",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/windows_export_manifest.json",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/windows_export_match.json",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/windows_export_inventory_policy_paths.json",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/test_results.json",
        "artifacts/ptcgdap/as_wp6_policy_package_v1/manifest.json",
        "contracts/ptcgdap/policy_package_v1.schema.json",
        "contracts/ptcgdap/policy_package_v1_profile.json",
        "contracts/ptcgdap/policy_package_v1_bundle.json",
        "data/ptcgdap/marnie_windows_policy_package_v1.json",
        "scripts/ai/ptcgdap/policy_package.py",
        "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
        "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd.uid",
        "tests/ptcgdap/test_policy_package_v1.py",
        "tests/ptcgdap/test_as_wp6_policy_package_evidence.py",
        "tools/ptcgdap/build_policy_package_v1.py",
        "tools/ptcgdap/build_as_wp6_policy_package_evidence.py",
        "tools/ptcgdap/refresh_as_wp6_release_evidence.py",
        # D052 current declared no-model Python/GDScript conformance owner.
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/README.md",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/python_report.json",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/test_results.json",
        "artifacts/ptcgdap/as_wp6_policy_executor_conformance/manifest.json",
        "contracts/ptcgdap/policy_executor_conformance_v1.schema.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_profile.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json",
        "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json",
        "scripts/ai/ptcgdap/policy_executor_conformance.py",
        "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd",
        "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd.uid",
        "tests/ptcgdap/godot/test_policy_executor_conformance.gd",
        "tests/ptcgdap/godot/test_policy_executor_conformance.gd.uid",
        "tests/ptcgdap/test_policy_executor_conformance_v1.py",
        "tests/ptcgdap/test_as_wp6_policy_executor_conformance_evidence.py",
        "tools/ptcgdap/build_policy_executor_conformance_v1.py",
        "tools/ptcgdap/run_policy_executor_conformance.py",
        "tools/ptcgdap/build_as_wp6_policy_executor_conformance_evidence.py",
        # D053 current Windows no-model LocalPolicyExecutor owner.
        "artifacts/ptcgdap/as_wp6_local_policy_executor/README.md",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/windows_ui_match_report.json",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/test_results.json",
        "artifacts/ptcgdap/as_wp6_local_policy_executor/manifest.json",
        "contracts/ptcgdap/local_policy_executor_v1.schema.json",
        "contracts/ptcgdap/local_policy_executor_v1_profile.json",
        "contracts/ptcgdap/local_policy_executor_v1_bundle.json",
        "data/ptcgdap/marnie_windows_local_policy_executor_v1.json",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd.uid",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd",
        "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd.uid",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd",
        "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd.uid",
        "tests/ptcgdap/godot/test_local_policy_executor.gd",
        "tests/ptcgdap/godot/test_local_policy_executor.gd.uid",
        "tests/ptcgdap/test_local_policy_executor_v1.py",
        "tests/ptcgdap/test_as_wp6_local_policy_executor_evidence.py",
        "tools/ptcgdap/build_local_policy_executor_v1.py",
        "tools/ptcgdap/build_as_wp6_local_policy_executor_evidence.py",
        # D054 current Windows x86_64 device_manifest_v1 contract.
        "artifacts/ptcgdap/as_wp6_device_manifest/README.md",
        "artifacts/ptcgdap/as_wp6_device_manifest/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_device_manifest/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_device_manifest/test_results.json",
        "artifacts/ptcgdap/as_wp6_device_manifest/manifest.json",
        "contracts/ptcgdap/device_manifest_v1.schema.json",
        "contracts/ptcgdap/device_manifest_v1_profile.json",
        "contracts/ptcgdap/device_manifest_v1_bundle.json",
        "data/ptcgdap/marnie_windows_device_manifest_v1.json",
        "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd",
        "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd.uid",
        "tests/ptcgdap/godot/test_device_manifest.gd",
        "tests/ptcgdap/godot/test_device_manifest.gd.uid",
        "tests/ptcgdap/test_device_manifest_v1.py",
        "tests/ptcgdap/test_as_wp6_device_manifest_evidence.py",
        "tools/ptcgdap/build_device_manifest_v1.py",
        "tools/ptcgdap/build_as_wp6_device_manifest_evidence.py",
        # D055 project-owned Windows build-install-launch-offline entry.
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/README.md",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/windows_offline_entry_report.json",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_offline_entry/manifest.json",
        "scripts/tools/run_ptcgdap_windows_offline_entry.ps1",
        "tests/ptcgdap/test_windows_offline_entry.py",
        "tests/ptcgdap/test_as_wp6_windows_offline_entry_evidence.py",
        "tools/ptcgdap/build_as_wp6_windows_offline_entry_evidence.py",
        # D056 fixed-profile Windows resource qualification evidence.
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/README.md",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/windows_profile_qualification_report.json",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/test_results.json",
        "artifacts/ptcgdap/as_wp6_windows_profile_qualification/manifest.json",
        "scripts/tools/run_ptcgdap_windows_profile_qualification.ps1",
        "tests/ptcgdap/test_windows_profile_qualification.py",
        "tests/ptcgdap/test_as_wp6_windows_profile_qualification_evidence.py",
        "tools/ptcgdap/build_windows_profile_qualification.py",
        "tools/ptcgdap/build_as_wp6_windows_profile_qualification_evidence.py",
        # D058 author developer workbench and public-window simulation.
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/README.md",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/known_gaps.md",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/test_results.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/scaffold_report.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/build_report.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/validate_report.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/simulation_report.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/godot_rules_focused.log",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/evidence_summary.json",
        "artifacts/ptcgdap/as_wp6_author_developer_workbench/manifest.json",
        "docs/ptcgdap/10-author-strategy-developer-guide.md",
        "tools/ptcgdap/author_strategy_developer.py",
        "tools/ptcgdap/build_as_wp6_author_developer_workbench_evidence.py",
        "tests/ptcgdap/test_author_strategy_developer_tool.py",
        "tests/ptcgdap/test_as_wp6_author_developer_workbench_evidence.py",
    }
)

# D044 also touched six tracked files which were clean in every parent
# candidate covered by this compatibility helper.  They must disappear from
# those historical status records just like a later additive file.
POST_ACCEPTANCE_DEVELOPMENT_CLEAN_PATHS: Final = frozenset(
    {
        "scenes/battle/BattleSceneRuntime.gd",
        "scenes/battle/runtime/BattleSceneBoardActionRuntime.gd",
        "scripts/ui/battle/BattleDrawRevealController.gd",
        "scripts/ui/battle/BattleEffectInteractionController.gd",
        "scripts/ui/battle/ai/BattleAIWatchdog.gd",
        "tests/test_ai_watchdog.gd",
        # These startup owners were clean at every sealed parent and first
        # changed for D045's fresh-user-data exported executable path.
        "scenes/main_menu/MainMenu.gd",
        "scripts/autoload/CardDatabase.gd",
        "scripts/tools/run_godot_tests.ps1",
        "tests/test_card_database_seed.gd",
        # D050 changed pre-existing release/export validation owners.
        "scripts/tools/export_ptcgdap_device_release.ps1",
        "tests/ptcgdap/test_author_strategy_release_boundaries.py",
    }
)

# D051 extended this suite after the Dragapult snapshot, but the file itself
# was already an untracked member of the AS-WP5/AS-WP6 parent candidates.
# Earlier parents must omit it; AS-WP5/AS-WP6 must restore their captured byte
# versions and retain the historical untracked status record.
POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS: Final = frozenset(
    {"tests/ptcgdap/godot/test_author_strategy_match_host.gd"}
)

# These two runtime files were also clean at the sealed AS-WP6 parent, but
# earlier rollback lanes already restore them through the AS-WP5 snapshot.
POST_ACCEPTANCE_AS_WP6_CLEAN_PATHS: Final = frozenset(
    {
        "scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd",
        "scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd",
    }
)

# D044 extended three pre-existing AS-WP4/AS-WP5 files.  Historical virtual
# rollback records bind file length and SHA rather than storing duplicate
# payloads, so replay the already-sealed implementation records at the two
# affected parent cursors.
_PRE_AUTHOR_PLAYER_OWNER_RECORDS: Final = {
    "factory": {
        "path": "scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd",
        "bytes": 1904,
        "sha256": "CA6C49577FE2083F643D1556B449AF9CB882EF6FC513CC310789A6F609B54D9C",
    },
    "foundation": {
        "path": "scenes/battle/runtime/BattleSceneRuntimeFoundation.gd",
        "bytes": 40674,
        "sha256": "E048A912F67B754E440D348E3DE653F9A351EAF08642324D32542C788ADA12D8",
    },
    "dialog": {
        "path": "scripts/ui/battle/BattleDialogController.gd",
        "bytes": 246628,
        "sha256": "45E183C99A4DE0A0C21621B2D21C9426FE14407CCF39B6369837F1843F845E3B",
    },
}

_PRE_D044_BOUNDARY_RECORDS: Final = {
    "tests/ptcgdap/test_author_strategy_match_host_boundary.py": {
        "bytes": 4732,
        "sha256": "1878A4ADA28720EB0E61DA17E49991D00555A8CE6ABA0170EC9E9488D1424EEF",
    },
    "tests/ptcgdap/test_p4_wp2_boundaries.py": {
        "bytes": 11065,
        "sha256": "266E17CCDAB0CC99A3E0779E935439CC292D4920A9CE6C26B8A5F61611EFB832",
    },
    "tests/ptcgdap/test_p4_wp3_boundaries.py": {
        "bytes": 7429,
        "sha256": "69BBD04BD7563DE88BA46BBA73AEC2DC5BD160DB1BB7119B3431C170C769BBA8",
    },
    "tests/ptcgdap/test_p4_wp4_boundaries.py": {
        "bytes": 7341,
        "sha256": "2E2D9A9EF7083B10422F92631E55241C3A930FE5F20131B87038B419B5C5B4B8",
    },
}
_PRE_AS_WP5_P2_WP1_BOUNDARY_RECORD: Final = {
    "bytes": 9525,
    "sha256": "0F385C628A922311D0625D5B1D990C24F322B7A25B958BCB80E1A4EFBE5E5811",
}
_POST_AS_WP5_P2_WP1_BOUNDARY_RECORD: Final = {
    "bytes": 9744,
    "sha256": "43B40CD454E2106F4F6D1DBCACEC4D5639F8D8BC9C13691E39D03BA842DF11C9",
}
_PRE_D045_PROJECT_RECORD: Final = {
    "bytes": 1459,
    "sha256": "881001A61BCB40535CDEEAF176B26D7E3CC08EB0FAE1CC0DADB35B3C8B39086C",
}
_AS_WP2_CASES_PATH: Final = "tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json"
_PRE_D048_AS_WP2_CASES_SHA256: Final = "8388B214CE56D8CA56016EB17DFD52E8B45599662CED9B7D276C770EDA784F24"
_POST_D048_AS_WP2_CASES_SHA256: Final = "2683C6A943A2A92AEE62F6FC6F7EC516B74BD04BF35C174D31FA18EBE701F899"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def is_dragapult_acceptance_additive(path: str) -> bool:
    return (
        path == "tests/TestSuiteCatalog.gd"
        or path in ADDITIVE_EXACT_PATHS
        or path in POST_ACCEPTANCE_DEVELOPMENT_PATHS
        or path in POST_ACCEPTANCE_DEVELOPMENT_CLEAN_PATHS
        or path in POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS
        or path.startswith("artifacts/ptcgdap/dragapult_python_e2e/")
        or path.startswith("artifacts/ptcgdap/as_wp6_windows_profile_approval/")
        or path.startswith("artifacts/ptcgdap/as_wp6_prompt_conformance_binding/")
        or path.startswith("artifacts/ptcgdap/as_wp6_product_signing/")
    )


def restore_pre_author_player_owner_record(
    work_package: str,
    record: dict[str, object],
) -> dict[str, object]:
    path = record.get("path")
    # A predecessor/successor snapshot may already have restored an earlier
    # byte version.  Only replace a row that still describes today's edited
    # working-tree file.
    if type(path) is str and (ROOT / path).is_file():
        current = (ROOT / path).read_bytes()
        if record.get("bytes") != len(current) or record.get("sha256") != sha(current):
            return record
    allowed_keys = ("factory",) if work_package == "AS-WP5" else (
        "factory",
        "foundation",
        "dialog",
    ) if work_package == "AS-WP6" else ()
    for key in allowed_keys:
        sealed = _PRE_AUTHOR_PLAYER_OWNER_RECORDS[key]
        if record.get("path") == sealed["path"]:
            return {
                **record,
                "bytes": sealed["bytes"],
                "sha256": sealed["sha256"],
            }
    if path == "tests/ptcgdap/test_p2_wp1_boundaries.py":
        sealed = (
            _POST_AS_WP5_P2_WP1_BOUNDARY_RECORD
            if work_package == "AS-WP6"
            else _PRE_AS_WP5_P2_WP1_BOUNDARY_RECORD
        )
        return {**record, **sealed}
    if path in _PRE_D044_BOUNDARY_RECORDS:
        return {**record, **_PRE_D044_BOUNDARY_RECORDS[path]}
    if path == "project.godot" and work_package in {"AS-WP3", "AS-WP4", "AS-WP5", "AS-WP6"}:
        return {**record, **_PRE_D045_PROJECT_RECORD}
    return record


def _parent_bytes() -> dict[str, bytes]:
    manifest = load_json_strict(MANIFEST_PATH)
    if type(manifest) is not dict or manifest.get("work_package") != "DRA-WINDOWS-PYTHON-E2E":
        raise AssertionError("invalid Dragapult acceptance parent snapshot")
    output: dict[str, bytes] = {}
    for row in manifest.get("files", []):
        if type(row) is not dict:
            raise AssertionError("invalid Dragapult acceptance parent row")
        path = row.get("original_path")
        snapshot_name = row.get("snapshot_path")
        if type(path) is not str or type(snapshot_name) is not str or "/" in snapshot_name or "\\" in snapshot_name:
            raise AssertionError("unsafe Dragapult acceptance parent path")
        encoded = b"".join((SNAPSHOT_ROOT / snapshot_name).read_bytes().split())
        value = base64.b64decode(encoded, validate=True)
        if len(value) != row.get("bytes") or sha(value) != row.get("raw_sha256"):
            raise AssertionError("Dragapult acceptance parent snapshot drift")
        output[path] = value
    return output


def restore_pre_dragapult_bytes(path: str, current: bytes | None) -> bytes | None:
    if path == _AS_WP2_CASES_PATH and current is not None and sha(current) == _POST_D048_AS_WP2_CASES_SHA256:
        document = json.loads(current.decode("utf-8"))
        added_keys = {
            "source_deck_id",
            "deck_card_id_domain",
            "deck_platform_scope",
            "deck_card_count",
        }

        def strip_metadata(value: object) -> None:
            if type(value) is dict:
                for key in added_keys:
                    value.pop(key, None)

        for case in document["cases"] + document["loader_cases"]:
            strip_metadata(case.get("expected_metadata"))
        for case in document["catalog_cases"]:
            expected = case.get("expected", {})
            for metadata in expected.get("metadata_records", []) + expected.get("ready_records", []):
                strip_metadata(metadata)
        restored = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if sha(restored) != _PRE_D048_AS_WP2_CASES_SHA256:
            raise AssertionError("pre-D048 AS-WP2 fixture restoration drift")
        return restored
    return _parent_bytes().get(path, current)


__all__ = [
    "ADDITIVE_EXACT_PATHS",
    "POST_ACCEPTANCE_AS_WP6_CLEAN_PATHS",
    "POST_ACCEPTANCE_DEVELOPMENT_CLEAN_PATHS",
    "POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS",
    "POST_ACCEPTANCE_DEVELOPMENT_PATHS",
    "is_dragapult_acceptance_additive",
    "restore_pre_author_player_owner_record",
    "restore_pre_dragapult_bytes",
]
