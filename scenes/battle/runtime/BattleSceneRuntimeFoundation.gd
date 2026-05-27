## BattleScene
extends Control

# ===================== Constants =====================
const BENCH_SIZE := 5
const MAX_BENCH_SIZE := 8
const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")
const BATTLE_CARD_VIEW := preload("res://scenes/battle/BattleCardView.gd")
const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const BattleAiOpponentFactoryScript := preload("res://scripts/ui/battle/ai/BattleAiOpponentFactory.gd")
const DeckStrategyRegistryScript := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyGardevoirScript := preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript := preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const AIVersionRegistryScript := preload("res://scripts/ai/AIVersionRegistry.gd")
const AIFixedDeckOrderRegistryScript := preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const AgentVersionStoreScript := preload("res://scripts/ai/AgentVersionStore.gd")
const BattleRecorderScript := preload("res://scripts/engine/BattleRecorder.gd")
const BattleReplaySnapshotLoaderScript := preload("res://scripts/engine/BattleReplaySnapshotLoader.gd")
const BattleReplayStateRestorerScript := preload("res://scripts/engine/BattleReplayStateRestorer.gd")
const BattleAdviceServiceScript := preload("res://scripts/engine/BattleAdviceService.gd")
const BattleLearningPoolStoreScript := preload("res://scripts/engine/BattleLearningPoolStore.gd")
const MatchEndQuickReviewServiceScript := preload("res://scripts/engine/MatchEndQuickReviewService.gd")
const BattleReviewArtifactStoreScript := preload("res://scripts/engine/BattleReviewArtifactStore.gd")
const BattleReviewServiceScript := preload("res://scripts/engine/BattleReviewService.gd")
const BattleSceneRefsScript := preload("res://scenes/battle/BattleSceneRefs.gd")
const BattleSceneContextScript := preload("res://scripts/ui/battle/BattleSceneContext.gd")
const BattleI18nScript := preload("res://scripts/ui/battle/BattleI18n.gd")
const BattleAdviceFormatterScript := preload("res://scripts/ui/battle/BattleAdviceFormatter.gd")
const BattleAdviceControllerScript := preload("res://scripts/ui/battle/BattleAdviceController.gd")
const BattleAdviceCoordinatorScript := preload("res://scripts/ui/battle/advice/BattleAdviceCoordinator.gd")
const BattleDiscussionContextBuilderScript := preload("res://scripts/ui/battle/advice/BattleDiscussionContextBuilder.gd")
const BattleMatchEndQuickReviewBuilderScript := preload("res://scripts/ui/battle/advice/BattleMatchEndQuickReviewBuilder.gd")
const BattleActionControllerScript := preload("res://scripts/ui/battle/BattleActionController.gd")
const BattleInvalidActionHintControllerScript := preload("res://scripts/ui/battle/BattleInvalidActionHintController.gd")
const BattleAttackVfxControllerScript := preload("res://scripts/ui/battle/BattleAttackVfxController.gd")
const BattleAttackVfxRegistryScript := preload("res://scripts/ui/battle/BattleAttackVfxRegistry.gd")
const BattleCardDetailCoordinatorScript := preload("res://scripts/ui/battle/display/BattleCardDetailCoordinator.gd")
const BattleDisplayControllerScript := preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleDisplayCoordinatorScript := preload("res://scripts/ui/battle/display/BattleDisplayCoordinator.gd")
const BattleSurfaceStylerScript := preload("res://scripts/ui/battle/display/BattleSurfaceStyler.gd")
const BattleStadiumHudCoordinatorScript := preload("res://scripts/ui/battle/display/BattleStadiumHudCoordinator.gd")
const BattleStadiumBackdropCoordinatorScript := preload("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd")
const BattleDeckShuffleAnimatorScript := preload("res://scripts/ui/battle/display/BattleDeckShuffleAnimator.gd")
const BattlePopupTextScalerScript := preload("res://scripts/ui/battle/display/BattlePopupTextScaler.gd")
const BattleDialogControllerScript := preload("res://scripts/ui/battle/BattleDialogController.gd")
const BattleDrawRevealControllerScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")
const BattleEffectInteractionControllerScript := preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")
const BattleInteractionControllerScript := preload("res://scripts/ui/battle/BattleInteractionController.gd")
const BattleInteractionCoordinatorScript := preload("res://scripts/ui/battle/interactions/BattleInteractionCoordinator.gd")
const BattleDragScrollCoordinatorScript := preload("res://scripts/ui/battle/interactions/BattleDragScrollCoordinator.gd")
const BattleLayoutControllerScript := preload("res://scripts/ui/battle/BattleLayoutController.gd")
const BattleLayoutCoordinatorScript := preload("res://scripts/ui/battle/layouts/BattleLayoutCoordinator.gd")
const BattleLayoutDebugReporterScript := preload("res://scripts/ui/battle/layouts/BattleLayoutDebugReporter.gd")
const BattleOverlayControllerScript := preload("res://scripts/ui/battle/BattleOverlayController.gd")
const BattleOverlayCoordinatorScript := preload("res://scripts/ui/battle/overlays/BattleOverlayCoordinator.gd")
const BattlePromptRouterScript := preload("res://scripts/ui/battle/prompts/BattlePromptRouter.gd")
const BattleReplayControllerScript := preload("res://scripts/ui/battle/BattleReplayController.gd")
const BattleRecordingControllerScript := preload("res://scripts/ui/battle/BattleRecordingController.gd")
const BattleRecordingCoordinatorScript := preload("res://scripts/ui/battle/recording/BattleRecordingCoordinator.gd")
const BattleRuntimeLogControllerScript := preload("res://scripts/ui/battle/BattleRuntimeLogController.gd")
const BattleReviewFormatterScript := preload("res://scripts/ui/battle/BattleReviewFormatter.gd")
const BattleLayoutStateScript := preload("res://scripts/ui/battle/states/BattleLayoutState.gd")
const BattleDialogStateScript := preload("res://scripts/ui/battle/states/BattleDialogState.gd")
const BattleInteractionStateScript := preload("res://scripts/ui/battle/states/BattleInteractionState.gd")
const BattleReplayStateScript := preload("res://scripts/ui/battle/states/BattleReplayState.gd")
const BattleOverlayStateScript := preload("res://scripts/ui/battle/states/BattleOverlayState.gd")
const BattleAiStateScript := preload("res://scripts/ui/battle/states/BattleAiState.gd")
const BattleAdviceStateScript := preload("res://scripts/ui/battle/states/BattleAdviceState.gd")
const BattleRecordingStateScript := preload("res://scripts/ui/battle/states/BattleRecordingState.gd")
const BattleEffectStateScript := preload("res://scripts/ui/battle/states/BattleEffectState.gd")
const DeckDiscussionDialogScene := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const CARD_ASPECT := 0.716
const BATTLE_RUNTIME_LOG_PATH := "user://logs/battle_runtime.log"
const BATTLE_BACKDROP_RESOURCE := "res://assets/ui/background.png"
const PLAYER_CARD_BACK_RESOURCE := "res://assets/ui/card_back_player.svg"
const OPPONENT_CARD_BACK_RESOURCE := "res://assets/ui/card_back_opponent.svg"
const VSTAR_HUD_TEXTURE := preload("res://assets/ui/vstar.png")
const VSTAR_HUD_TEXTURE_1 := preload("res://assets/ui/vstar1.png")
const VSTAR_HUD_TEXTURE_2 := preload("res://assets/ui/vstar2.png")
const VSTAR_HUD_TEXTURE_VARIANTS := [VSTAR_HUD_TEXTURE, VSTAR_HUD_TEXTURE_1, VSTAR_HUD_TEXTURE_2]
const USED_ABILITY_TILT_DEGREES := 15.0
const CoinFlipAnimatorScript := preload("res://scenes/battle/CoinFlipAnimator.gd")
const AI_MAX_ACTIONS_PER_TURN := 20
const AI_ACTION_PAUSE_SECONDS := 2.0
const SLOT_TOUCH_LONG_PRESS_SECONDS := 0.42
const SLOT_TOUCH_LONG_PRESS_MOVE_TOLERANCE := 18.0
const SLOT_FOLLOWUP_CLICK_SUPPRESS_MSEC := 900
const BENCH_PLAY_FOLLOWUP_CLICK_SUPPRESS_MSEC := 160
const MODAL_INPUT_SLOT_SUPPRESS_MSEC := 250
const ACTION_HUD_OPEN_INPUT_SUPPRESS_MSEC := 260
const ACTION_HUD_OPEN_POSITION_GUARD_MSEC := 1400
const ACTION_HUD_OPEN_POSITION_GUARD_TOLERANCE := 96.0
const MODAL_HAND_RELEASE_FALLBACK_WINDOW_MSEC := 1400
const HAND_SCROLL_PANEL_PADDING := 18.0
const HUD_ACTION_TOUCH_MIN_HEIGHT := 44.0
const DIALOG_OVERLAY_Z_INDEX := 220
const HANDOVER_OVERLAY_Z_INDEX := 210
const ACTIVE_MODAL_OVERLAY_Z_INDEX := 300
const DETAIL_OVERLAY_Z_INDEX := 500
const COIN_FLIP_OVERLAY_Z_INDEX := 900
const DISCARD_OVERLAY_Z_INDEX := 90
const STADIUM_CARD_OVERLAY_Z_INDEX := 70
const PORTRAIT_POPUP_FONT_SCALE := 2.0
const PORTRAIT_POPUP_MIN_BUTTON_HEIGHT := 112.0
const PORTRAIT_POPUP_NEAR_WIDTH_RATIO := 0.94
const PORTRAIT_POPUP_COMPACT_WIDTH_RATIO := 0.84
const PORTRAIT_DIRECT_TOP_BUTTON_WIDTH_SCALE := 1.5
const PORTRAIT_POPUP_DETAIL_MAX_HEIGHT_RATIO := 0.78
const PORTRAIT_POPUP_COLLECTION_HEIGHT_RATIO := 0.56
const PORTRAIT_POPUP_COLLECTION_SCROLL_RATIO := 0.42
const PORTRAIT_ACTION_POPUP_BUTTON_HEIGHT := 128.0
const PORTRAIT_ACTION_POPUP_MARGIN := 18.0
const PORTRAIT_EMPTY_STADIUM_HUD_TEXT := "竞技场区"
const PORTRAIT_STADIUM_CARD_SCALE := 2.0 / 3.0
const PORTRAIT_SIDE_HUD_WIDTH_SCALE := 1.3
const VSTAR_LOST_HUD_HEIGHT_SCALE := 1.33
const VSTAR_LOST_HUD_WIDTH_RATIO := 2.4
const LANDSCAPE_VSTAR_LOST_HUD_HEIGHT_SCALE := 0.7
const PORTRAIT_VSTAR_HUD_HEIGHT_SCALE := 0.7
const VSTAR_HUD_HEIGHT_MULTIPLIER := 2.0
const VSTAR_LOST_HUD_VALUE_FONT_RATIO := 0.55
const LANDSCAPE_STADIUM_ACTION_HEIGHT_SCALE := 0.7
const LANDSCAPE_STADIUM_ACTION_FONT_SCALE := 1.3
const RESPONSIVE_LAYOUT_STABILIZATION_FRAMES := 10
const RESPONSIVE_LAYOUT_RESIZE_STABILIZATION_FRAMES := 4
# ===================== State =====================
# These scene-owned fields are intentionally accessed reflectively by extracted
# battle controllers via scene.get()/set()/call(). Godot's static analyzer can't
# follow those accesses, so suppress private-field false positives for the
# declaration blocks and restore warnings before method bodies.
@warning_ignore_start("unused_private_class_variable")
var _gsm: GameStateMachine
var _view_player: int = 0        # Two-player local mode currently visible player
var _selected_hand_card: CardInstance = null
var _pending_choice: String = ""
var _pending_effect_card: CardInstance = null
var _pending_effect_steps: Array[Dictionary] = []
var _pending_effect_step_index: int = -1
var _pending_effect_context: Dictionary = {}
var _pending_effect_kind: String = ""
var _pending_effect_player_index: int = -1
var _pending_effect_slot: PokemonSlot = null
var _pending_effect_ability_index: int = -1
var _pending_effect_attack_data: Dictionary = {}
var _pending_effect_attack_effects: Array[BaseEffect] = []
var _dialog_multi_selected_indices: Array[int] = []
var _slot_card_views: Dictionary = {}
var _detail_card_view = null
var _detail_reveal_tween: Tween = null
var _detail_action_bar: HBoxContainer = null
var _detail_use_btn: Button = null
var _detail_cancel_btn: Button = null
var _detail_hand_action_card: CardInstance = null
var _detail_mode: String = "readonly"
var _slot_touch_long_press_timer: Timer = null
var _slot_touch_long_press_active: bool = false
var _slot_touch_long_press_slot_id: String = ""
var _slot_touch_long_press_index: int = -1
var _slot_touch_long_press_start: Vector2 = Vector2.ZERO
var _slot_touch_long_press_consumed: bool = false
var _suppress_next_slot_left_click_id: String = ""
var _suppress_slot_followup_click_id: String = ""
var _suppress_slot_followup_click_until_msec: int = 0
var _modal_input_slot_suppress_until_msec: int = 0
var _modal_input_finished_at_msec: int = 0
var _action_hud_open_input_suppress_until_msec: int = 0
var _action_hud_open_position_guard_until_msec: int = 0
var _action_hud_open_input_suppress_position: Vector2 = Vector2.ZERO
var _action_hud_open_input_suppress_has_position: bool = false
var _hand_drag_active: bool = false
var _hand_dragging: bool = false
var _hand_drag_start_position: Vector2 = Vector2.ZERO
var _hand_drag_start_scroll: int = 0
var _hand_drag_suppress_click_until_msec: int = 0
var _hand_drag_debug_motion_count: int = 0
var _card_gallery_drag_active_scroll: ScrollContainer = null
var _card_gallery_drag_active: bool = false
var _card_gallery_dragging: bool = false
var _card_gallery_drag_start_position: Vector2 = Vector2.ZERO
var _card_gallery_drag_start_scroll: int = 0
var _card_gallery_drag_suppress_click_until_msec: int = 0

var _setup_done: Array[bool] = [false, false]
var _play_card_size: Vector2 = Vector2(130, 182)
var _dialog_card_size: Vector2 = Vector2(148, 208)
var _detail_card_size: Vector2 = Vector2(300, 420)
var _last_ui_state_signature: String = ""
var _pending_handover_action: Callable = Callable()
var _opp_prize_slots: Array[BattleCardView] = []
var _my_prize_slots: Array[BattleCardView] = []
var _portrait_prize_dialog_active: bool = false
var _portrait_prize_dialog_player_index: int = -1
var _portrait_prize_dialog_host: VBoxContainer = null
var _portrait_prize_dialog_original_parent: Node = null
var _portrait_prize_dialog_original_index: int = -1
var _portrait_prize_dialog_original_visible: bool = false
var _portrait_prize_dialog_original_minimum_size: Vector2 = Vector2.ZERO
var _opp_deck_preview: BattleCardView = null
var _my_deck_preview: BattleCardView = null
var _opp_discard_preview: BattleCardView = null
var _my_discard_preview: BattleCardView = null
var _deck_shuffle_counts: Dictionary = {}
var _deck_preview_base_positions: Dictionary = {}
var _deck_shuffle_effect_serial: int = 0
var _my_deck_shuffle_tween: Variant = null
var _opp_deck_shuffle_tween: Variant = null
var _draw_reveal_overlay: Control = null
var _attack_vfx_overlay: Control = null
var _draw_reveal_queue: Array[GameAction] = []
var _draw_reveal_active: bool = false
var _draw_reveal_waiting_for_confirm: bool = false
var _draw_reveal_auto_continue_pending: bool = false
var _draw_reveal_pending_hand_refresh: bool = false
var _draw_reveal_current_action: GameAction = null
var _draw_reveal_card_views: Array[BattleCardView] = []
var _draw_reveal_resume_timer: Variant = null
var _draw_reveal_allow_hand_refresh_during_fly: bool = false
var _draw_reveal_visible_instance_ids: Array[int] = []
var _pending_prize_player_index: int = -1
var _pending_prize_remaining: int = 0
var _pending_prize_animating: bool = false
var _ai_opponent = null
var _ai_running: bool = false
var _ai_step_scheduled: bool = false
var _ai_followup_requested: bool = false
var _ai_turn_marker: String = ""
var _ai_actions_this_turn: int = 0
var _ai_action_pause_seconds: float = AI_ACTION_PAUSE_SECONDS
var _ai_action_pause_timer: Variant = null
var _ai_llm_waiting: bool = false
var _ai_llm_turn_requested: int = -1
var _ai_llm_wait_label: Label = null
var _ai_llm_wait_started_msec: int = 0
var _ai_llm_wait_anim_token: int = 0
var _latest_opponent_action_text: String = ""
var _latest_opponent_action_turn_number: int = -1
var _battle_mode: String = "live"
var _replay_match_dir: String = ""
var _replay_turn_numbers: Array[int] = []
var _replay_current_turn_index: int = -1
var _replay_entry_source: String = ""
var _replay_loaded_raw_snapshot: Dictionary = {}
var _replay_loaded_view_snapshot: Dictionary = {}
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
var _ai_fixed_deck_order_registry: RefCounted = AIFixedDeckOrderRegistryScript.new()
var _agent_version_store: RefCounted = AgentVersionStoreScript.new()
var _deck_strategy_registry: RefCounted = DeckStrategyRegistryScript.new()

var _field_interaction_overlay: Control = null
var _field_interaction_layout: VBoxContainer = null
var _field_interaction_top_spacer: Control = null
var _field_interaction_bottom_spacer: Control = null
var _field_interaction_panel: PanelContainer = null
var _field_interaction_title_lbl: Label = null
var _field_interaction_status_lbl: Label = null
var _field_interaction_scroll: ScrollContainer = null
var _field_interaction_row: HBoxContainer = null
var _field_interaction_buttons: HBoxContainer = null
var _field_interaction_clear_btn: Button = null
var _field_interaction_cancel_btn: Button = null
var _field_interaction_confirm_btn: Button = null
var _field_interaction_mode: String = ""
var _field_interaction_data: Dictionary = {}
var _field_interaction_slot_index_by_id: Dictionary = {}
var _field_interaction_selected_indices: Array[int] = []
var _field_interaction_assignment_selected_source_index: int = -1
var _field_interaction_assignment_entries: Array[Dictionary] = []
var _field_interaction_position: String = "center"

var _player_card_back_texture: Texture2D = null
var _opponent_card_back_texture: Texture2D = null
var _vstar_hud_texture_indices_by_player: Array[int] = []
var _battle_recorder: RefCounted = null
var _battle_recording_started: bool = false
var _battle_recording_context_captured: bool = false
var _battle_recording_output_root: String = ""
var _turn_start_snapshot_recorded_keys: Dictionary = {}
var _battle_review_service: RefCounted = null
var _battle_review_store: RefCounted = BattleReviewArtifactStoreScript.new()
var _battle_learning_store: RefCounted = BattleLearningPoolStoreScript.new()
var _battle_review_match_dir: String = ""
var _battle_review_last_review: Dictionary = {}
var _battle_review_busy: bool = false
var _battle_review_progress_text: String = ""
var _battle_review_winner_index: int = -1
var _battle_review_reason: String = ""
var _battle_review_formatter: RefCounted = BattleReviewFormatterScript.new()
var _match_end_stats: Dictionary = {}
var _match_end_quick_review_service: RefCounted = null
var _match_end_quick_review_result: Dictionary = {}
var _match_end_quick_review_busy: bool = false
var _match_end_quick_review_progress_text: String = ""
var _match_end_quick_review_requested: bool = false
var _match_end_non_battle_orientation_restored: bool = false
var _match_end_overlay: Panel = null
var _match_end_title: Label = null
var _match_end_subtitle: Label = null
var _match_end_reason: Label = null
var _match_end_stats_grid: GridContainer = null
var _match_end_player_summary: RichTextLabel = null
var _match_end_action_summary: RichTextLabel = null
var _match_end_ai_title: Label = null
var _match_end_ai_content: RichTextLabel = null
var _match_end_ai_button: Button = null
var _match_end_review_button: Button = null
var _match_end_learning_button: Button = null
var _match_end_return_button: Button = null
var _battle_advice_controller: RefCounted = BattleAdviceControllerScript.new()
var _battle_advice_coordinator: RefCounted = BattleAdviceCoordinatorScript.new()
var _battle_discussion_context_builder: RefCounted = BattleDiscussionContextBuilderScript.new()
var _match_end_quick_review_builder: RefCounted = BattleMatchEndQuickReviewBuilderScript.new()
var _battle_advice_service: RefCounted = null
var _battle_action_controller: RefCounted = BattleActionControllerScript.new()
var _battle_invalid_action_hint_controller: RefCounted = BattleInvalidActionHintControllerScript.new()
var _battle_attack_vfx_controller: RefCounted = BattleAttackVfxControllerScript.new()
var _battle_attack_vfx_registry: RefCounted = BattleAttackVfxRegistryScript.new()
var _battle_card_detail_coordinator: RefCounted = BattleCardDetailCoordinatorScript.new()
var _battle_display_controller: RefCounted = BattleDisplayControllerScript.new()
var _battle_display_coordinator: RefCounted = BattleDisplayCoordinatorScript.new()
var _battle_surface_styler: RefCounted = BattleSurfaceStylerScript.new()
var _battle_stadium_hud_coordinator: RefCounted = BattleStadiumHudCoordinatorScript.new()
var _battle_stadium_backdrop_coordinator: RefCounted = BattleStadiumBackdropCoordinatorScript.new()
var _battle_deck_shuffle_animator: RefCounted = BattleDeckShuffleAnimatorScript.new()
var _battle_popup_text_scaler: RefCounted = BattlePopupTextScalerScript.new()
var _battle_dialog_controller: RefCounted = BattleDialogControllerScript.new()
var _battle_draw_reveal_controller: RefCounted = BattleDrawRevealControllerScript.new()
var _battle_effect_interaction_controller: RefCounted = BattleEffectInteractionControllerScript.new()
var _battle_interaction_controller: RefCounted = BattleInteractionControllerScript.new()
var _battle_interaction_coordinator: RefCounted = BattleInteractionCoordinatorScript.new()
var _battle_drag_scroll_coordinator: RefCounted = BattleDragScrollCoordinatorScript.new()
var _battle_layout_controller: RefCounted = BattleLayoutControllerScript.new()
var _battle_layout_coordinator: RefCounted = BattleLayoutCoordinatorScript.new()
var _battle_layout_debug_reporter: RefCounted = BattleLayoutDebugReporterScript.new()
var _battle_overlay_controller: RefCounted = BattleOverlayControllerScript.new()
var _battle_overlay_coordinator: RefCounted = BattleOverlayCoordinatorScript.new()
var _battle_prompt_router: RefCounted = BattlePromptRouterScript.new()
var _battle_replay_snapshot_loader: RefCounted = BattleReplaySnapshotLoaderScript.new()
var _battle_replay_state_restorer: RefCounted = BattleReplayStateRestorerScript.new()
var _battle_scene_refs: RefCounted = BattleSceneRefsScript.new()
var _battle_scene_context: RefCounted = BattleSceneContextScript.new()
var _battle_i18n: RefCounted = BattleI18nScript.new()
var _battle_ai_opponent_factory: RefCounted = BattleAiOpponentFactoryScript.new()
var _battle_layout_state: RefCounted = BattleLayoutStateScript.new()
var _battle_dialog_state: RefCounted = BattleDialogStateScript.new()
var _battle_interaction_state: RefCounted = BattleInteractionStateScript.new()
var _battle_replay_state: RefCounted = BattleReplayStateScript.new()
var _battle_overlay_state: RefCounted = BattleOverlayStateScript.new()
var _battle_ai_state: RefCounted = BattleAiStateScript.new()
var _battle_advice_state: RefCounted = BattleAdviceStateScript.new()
var _battle_recording_state: RefCounted = BattleRecordingStateScript.new()
var _battle_effect_state: RefCounted = BattleEffectStateScript.new()
var _battle_replay_controller: RefCounted = BattleReplayControllerScript.new()
var _battle_recording_controller: RefCounted = BattleRecordingControllerScript.new()
var _battle_recording_coordinator: RefCounted = BattleRecordingCoordinatorScript.new()
var _battle_runtime_log_controller: RefCounted = BattleRuntimeLogControllerScript.new()
var _battle_advice_last_result: Dictionary = {}
var _battle_advice_busy: bool = false
var _battle_advice_progress_text: String = ""
var _battle_advice_initial_snapshot: Dictionary = {}
var _battle_advice_pinned: bool = false
var _battle_advice_formatter: RefCounted = BattleAdviceFormatterScript.new()
var _battle_advice_panel: PanelContainer = null
var _battle_advice_panel_title: Label = null
var _battle_advice_panel_toggle_btn: Button = null
var _battle_advice_panel_content: RichTextLabel = null
var _battle_advice_panel_collapsed: bool = false
var _review_pin_btn: Button = null
var _review_overlay_mode: String = ""
var _battle_discussion_dialog: AcceptDialog = null
var _battle_discussion_signature := ""
var _battle_discussion_flash_tween: Tween = null
var _portrait_my_bench_grid: Container = null
var _portrait_opp_bench_grid: Container = null
var _portrait_actions_popup: PopupPanel = null
var _rotated_portrait_canvas_active: bool = false
var _rotated_portrait_physical_viewport_size: Vector2 = Vector2.ZERO
var _portrait_layout_frame_rect: Rect2 = Rect2()
var _portrait_layout_full_size: Vector2 = Vector2.ZERO
var _responsive_layout_stabilization_frames_remaining: int = 0
var _active_battle_layout_mode: String = ""
var _bench_display_size_snapshot: int = BENCH_SIZE

# ===================== UI References =====================
@onready var _log_list: RichTextLabel = %LogList
@onready var _log_title: Label = $MainArea/LogPanel/LogPanelVBox/LogTitle

# Top status
@onready var _lbl_phase: Label = %LblPhase
@onready var _lbl_turn: Label = %LblTurn
@onready var _top_bar: PanelContainer = $TopBar

# Top actions
@onready var _btn_end_turn: Button = %BtnEndTurn
@onready var _btn_back: Button = %BtnBack
@onready var _btn_ai_advice: Button = %BtnAiAdvice
@onready var _btn_battle_discuss_ai: Button = %BtnBattleDiscussAI
@onready var _btn_attack_vfx_preview: Button = %BtnAttackVfxPreview
@onready var _btn_opponent_hand: Button = %BtnOpponentHand
@onready var _btn_zeus_help: Button = %BtnZeusHelp
@onready var _btn_battle_layout: Button = %BtnBattleLayout
@onready var _btn_battle_more: Button = %BtnBattleMore
@onready var _btn_replay_prev_turn: Button = %BtnReplayPrevTurn
@onready var _btn_replay_next_turn: Button = %BtnReplayNextTurn
@onready var _btn_replay_continue: Button = %BtnReplayContinue
@onready var _btn_replay_back_to_list: Button = %BtnReplayBackToList
@onready var _hud_end_turn_btn: Button = %HudEndTurnBtn
@onready var _opp_hand_bar: PanelContainer = $MainArea/CenterField/OppHandBar
@onready var _left_panel: VBoxContainer = $MainArea/LeftPanel
@onready var _right_panel: VBoxContainer = $MainArea/RightPanel

# --- Opponent field ---
@onready var _opp_prizes: Label = %OppPrizesCount
@onready var _opp_prizes_title: Label = $MainArea/LeftPanel/OppPrizesBox/OppPrizesLbl
@onready var _opp_deck: Label = %OppDeck
@onready var _opp_discard: Label = %OppDiscard
@onready var _opp_hand_lbl: Label = %OppHandLbl
@onready var _opp_prizes_box: VBoxContainer = $MainArea/LeftPanel/OppPrizesBox
@onready var _opp_deck_box: VBoxContainer = $MainArea/RightPanel/OppDeckBox
@onready var _opp_active: PanelContainer = %OppActive
@onready var _opp_bench: HBoxContainer = %OppBench
@onready var _opp_active_lbl: RichTextLabel = %OppActiveLbl
@onready var _opp_field_shell: HBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell
@onready var _opp_hud_left: PanelContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft
@onready var _opp_hud_right: PanelContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight
@onready var _opp_prize_hud_count: Label = %OppHudLeftValue
@onready var _opp_prize_hud_title: Label = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle
@onready var _opp_prize_hud_host: VBoxContainer = %OppPrizeHudHost
@onready var _opp_deck_hud_box: VBoxContainer = %OppDeckHudBox
@onready var _opp_deck_hud_value: Label = %OppDeckHudValue
@onready var _opp_discard_hud_box: VBoxContainer = %OppDiscardHudBox
@onready var _opp_discard_hud_value: Label = %OppDiscardHudValue

# --- Stadium ---
@onready var _stadium_lbl: Label = %StadiumLbl
@onready var _btn_stadium_action: Button = %BtnStadiumAction
@onready var _lost_zone_section: PanelContainer = %LostZoneSection
@onready var _stadium_center_section: PanelContainer = %StadiumCenterSection
@onready var _vstar_section: PanelContainer = %VstarSection
@onready var _enemy_vstar_value: Label = %EnemyVstarValue
@onready var _my_vstar_value: Label = %MyVstarValue
@onready var _enemy_lost_value: Label = %EnemyLostValue
@onready var _my_lost_value: Label = %MyLostValue
var _stadium_card_overlay: Control = null
var _stadium_card_view: BattleCardView = null
var _stadium_card_view_metrics: Vector2 = Vector2.ZERO
var _field_active_card_size: Vector2 = Vector2.ZERO

# --- Player field ---
@onready var _my_prizes: Label = %MyPrizesCount
@onready var _my_prizes_title: Label = $MainArea/LeftPanel/MyPrizesBox/MyPrizesLbl
@onready var _my_deck: Label = %MyDeck
@onready var _my_discard: Label = %MyDiscard
@onready var _my_prizes_box: VBoxContainer = $MainArea/LeftPanel/MyPrizesBox
@onready var _my_deck_box: VBoxContainer = $MainArea/RightPanel/MyDeckBox
@onready var _my_active: PanelContainer = %MyActive
@onready var _my_bench: HBoxContainer = %MyBench
@onready var _my_active_lbl: RichTextLabel = %MyActiveLbl
@onready var _my_field_shell: HBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell
@onready var _my_hud_left: PanelContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft
@onready var _my_hud_right: PanelContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight
@onready var _my_prize_hud_count: Label = %MyHudLeftValue
@onready var _my_prize_hud_title: Label = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle
@onready var _my_prize_hud_host: VBoxContainer = %MyPrizeHudHost
@onready var _my_deck_hud_box: VBoxContainer = %MyDeckHudBox
@onready var _my_deck_hud_value: Label = %MyDeckHudValue
@onready var _my_discard_hud_box: VBoxContainer = %MyDiscardHudBox
@onready var _my_discard_hud_value: Label = %MyDiscardHudValue

# Hand area
@onready var _hand_title: Label = $MainArea/CenterField/HandArea/HandVBox/HandTitle
@onready var _hand_container: HBoxContainer = %HandContainer
@onready var _hand_scroll: ScrollContainer = %HandScroll

# Dialog UI
@onready var _dialog_overlay: Panel = %DialogOverlay
@onready var _dialog_title: Label = %DialogTitle
@onready var _dialog_list: ItemList = %DialogList
@onready var _dialog_confirm: Button = %DialogConfirm
@onready var _dialog_cancel: Button = %DialogCancel
@onready var _dialog_box: PanelContainer = $DialogOverlay/DialogCenter/DialogBox
@onready var _dialog_vbox: VBoxContainer = $DialogOverlay/DialogCenter/DialogBox/DialogVBox

# Handover overlay
@onready var _handover_panel: Panel = %HandoverPanel
@onready var _handover_lbl: Label = %HandoverLbl
@onready var _handover_btn: Button = %HandoverBtn

# Coin flip overlay
@onready var _coin_overlay: Panel = %CoinFlipOverlay
@onready var _coin_result_lbl: Label = %CoinResultLbl
@onready var _coin_ok_btn: Button = %CoinOkBtn

# Coin flip animation state
var _coin_animator: Node = null
var _coin_flip_queue: Array[bool] = []
var _coin_animating: bool = false
var _coin_animation_resume_effect_step: bool = false

# Card detail overlay
@onready var _detail_overlay: Panel = %DetailOverlay
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_content: RichTextLabel = %DetailContent
@onready var _detail_close_btn: Button = %DetailCloseBtn

# Discard viewer overlay
@onready var _discard_overlay: Panel = %DiscardOverlay
@onready var _discard_title: Label = %DiscardTitle
@onready var _discard_list: ItemList = %DiscardList
@onready var _discard_close_btn: Button = %DiscardCloseBtn
@onready var _review_overlay: Panel = %ReviewOverlay
@onready var _review_title: Label = %ReviewTitle
@onready var _review_content: RichTextLabel = %ReviewContent
@onready var _review_close_btn: Button = %ReviewCloseBtn
@onready var _review_regenerate_btn: Button = %ReviewRegenerateBtn
@warning_ignore_restore("unused_private_class_variable")


# ===================== Lifecycle =====================

# ===================== Scene Callbacks =====================

# ===================== Setup Flow (UI-driven) =====================

# ===================== Field Interactions =====================

# ===================== Dialog State =====================

@warning_ignore_start("unused_private_class_variable")
var _dialog_data: Dictionary = {}
var _dialog_items_data: Array = []
var _dialog_card_scroll: ScrollContainer = null
var _dialog_card_row: HBoxContainer = null
var _dialog_utility_row: HBoxContainer = null
var _dialog_status_lbl: Label = null
var _dialog_card_selected_indices: Array[int] = []
var _dialog_card_page: int = 0
var _dialog_card_page_size: int = 0
var _dialog_card_mode: bool = false
var _dialog_assignment_mode: bool = false
var _dialog_assignment_panel: VBoxContainer = null
var _dialog_assignment_source_scroll: ScrollContainer = null
var _dialog_assignment_source_row: HBoxContainer = null
var _dialog_assignment_target_scroll: ScrollContainer = null
var _dialog_assignment_target_row: HBoxContainer = null
var _dialog_assignment_summary_lbl: Label = null
var _dialog_assignment_selected_source_index: int = -1
var _dialog_assignment_assignments: Array[Dictionary] = []
var _discard_card_scroll: ScrollContainer = null
var _discard_card_row: HBoxContainer = null
var _discard_utility_row: HBoxContainer = null
var _discard_card_page: int = 0
var _discard_card_page_size: int = 0
@warning_ignore_restore("unused_private_class_variable")


## After each interaction step completes, check whether the copied effect injected any follow-up dynamic steps.
## Example: Regidrago VSTAR copying Dragapult ex may append a second assignment step for damage counters.
