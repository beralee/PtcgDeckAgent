extends TestBase


func test_passive_locks_tolerate_uninitialized_or_torn_down_game_state() -> String:
	var state := GameState.new()
	return run_checks([
		assert_false(AbilityBasicLock.is_basic_abilities_disabled(state)),
		assert_false(AbilityDisableOpponentAbility.is_opponent_abilities_disabled(state, 0)),
		assert_false(AbilityDisableOpponentAbility.is_opponent_abilities_disabled(state, 1)),
		assert_false(AbilityDisableOpponentAbility.is_opponent_abilities_disabled(state, -1)),
	])
