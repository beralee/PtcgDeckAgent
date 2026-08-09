class_name BattleTurnActionPolicy
extends RefCounted

const HUMAN_TURN_ONLY_PROMPTS := {
	"pokemon_action": true,
	"zeus_help": true,
}


static func is_human_turn_only_prompt(pending_choice: String) -> bool:
	return bool(HUMAN_TURN_ONLY_PROMPTS.get(pending_choice, false))


static func can_view_player_start_normal_action(
	game_state: GameState,
	view_player: int,
	pending_choice: String
) -> bool:
	return (
		is_view_player_turn(game_state, view_player)
		and pending_choice == ""
	)


static func is_view_player_turn(game_state: GameState, view_player: int) -> bool:
	return (
		game_state != null
		and game_state.phase == GameState.GamePhase.MAIN
		and view_player >= 0
		and view_player < game_state.players.size()
		and game_state.current_player_index == view_player
	)


static func is_stale_human_prompt_on_ai_turn(
	pending_choice: String,
	game_state: GameState,
	ai_player_index: int
) -> bool:
	return (
		is_human_turn_only_prompt(pending_choice)
		and game_state != null
		and ai_player_index >= 0
		and game_state.current_player_index == ai_player_index
	)
