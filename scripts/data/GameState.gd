## 游戏状态 - 完整的对战状态数据
class_name GameState
extends RefCounted

## 游戏阶段
enum GamePhase {
	SETUP,              ## 对战准备
	MULLIGAN,           ## 重抽判定
	SETUP_PLACE,        ## 放置宝可梦阶段
	DRAW,               ## 抽牌阶段
	MAIN,               ## 主阶段（自由操作）
	ATTACK,             ## 攻击阶段
	POKEMON_CHECK,      ## 宝可梦检查
	BETWEEN_TURNS,      ## 回合间
	KNOCKOUT_REPLACE,   ## 昏厥后替换宝可梦
	GAME_OVER,          ## 游戏结束
}

## 双方玩家状态
var players: Array[PlayerState] = []
## 当前操作玩家索引
var current_player_index: int = 0
## 回合数（从1开始）
var turn_number: int = 0
## 先攻玩家索引
var first_player_index: int = 0

## 场上竞技场卡
var stadium_card: CardInstance = null
## 竞技场卡持有者索引
var stadium_owner_index: int = -1

## 当前游戏阶段
var phase: GamePhase = GamePhase.SETUP

## 回合内状态追踪
var energy_attached_this_turn: bool = false
var supporter_used_this_turn: bool = false
var stadium_played_this_turn: bool = false
var retreat_used_this_turn: bool = false
var stadium_effect_used_turn: int = -1
var stadium_effect_used_player: int = -1
var stadium_effect_used_effect_id: String = ""

## VSTAR力量使用记录 [player_0, player_1]
var vstar_power_used: Array[bool] = [false, false]
var last_knockout_turn_against: Array[int] = [-999, -999]
## Tracks the stricter card-text condition "during your opponent's turn".
## The legacy turn array above intentionally remains for replay/scenario
## compatibility and for effects whose wording only says "last turn".
var last_knockout_during_opponent_turn_against: Array[int] = [-999, -999]
var knockout_provenance_tracked_against: Array[bool] = [false, false]
var shared_turn_flags: Dictionary = {}

## 胜者索引（-1 表示未决出胜负）
var winner_index: int = -1
## 胜利原因
var win_reason: String = ""


## 获取当前操作玩家
func get_current_player() -> PlayerState:
	return players[current_player_index]


## 获取对手玩家
func get_opponent_player() -> PlayerState:
	return players[1 - current_player_index]


## 获取指定玩家
func get_player(index: int) -> PlayerState:
	return players[index]


## 是否为先攻玩家的首回合
func is_first_turn_of_first_player() -> bool:
	return turn_number == 1 and current_player_index == first_player_index


func is_first_turn_for_player(player_index: int) -> bool:
	if player_index == first_player_index:
		return turn_number == 1
	return turn_number == 2


func record_knockout_against(
	player_index: int,
	during_opponents_turn_override: int = -1
) -> void:
	if player_index < 0 or player_index >= last_knockout_turn_against.size():
		return
	last_knockout_turn_against[player_index] = turn_number
	knockout_provenance_tracked_against[player_index] = true
	var during_opponents_turn := (
		current_player_index == 1 - player_index
		and phase != GamePhase.POKEMON_CHECK
		and phase != GamePhase.BETWEEN_TURNS
	)
	if during_opponents_turn_override >= 0:
		during_opponents_turn = during_opponents_turn_override != 0
	if during_opponents_turn:
		last_knockout_during_opponent_turn_against[player_index] = turn_number


func was_knocked_out_during_opponents_previous_turn(player_index: int) -> bool:
	if player_index < 0 or player_index >= last_knockout_turn_against.size():
		return false
	if bool(knockout_provenance_tracked_against[player_index]):
		return int(last_knockout_during_opponent_turn_against[player_index]) == turn_number - 1
	# Old replays and authored scenarios predate provenance tracking. Preserve
	# their explicit intent until they are saved in the richer format.
	return int(last_knockout_turn_against[player_index]) == turn_number - 1


## 重置回合内状态（新回合开始时调用）
func reset_turn_flags() -> void:
	energy_attached_this_turn = false
	supporter_used_this_turn = false
	stadium_played_this_turn = false
	retreat_used_this_turn = false


## 切换到下一位玩家
func switch_player() -> void:
	current_player_index = 1 - current_player_index


## 推进回合（切换玩家后增加回合数）
func advance_turn() -> void:
	switch_player()
	# 当先攻方再次行动时，回合数+1
	if current_player_index == first_player_index:
		turn_number += 1
	reset_turn_flags()


## 设置游戏结束
func set_game_over(winner: int, reason: String) -> void:
	phase = GamePhase.GAME_OVER
	winner_index = winner
	win_reason = reason


## 游戏是否已结束
func is_game_over() -> bool:
	return phase == GamePhase.GAME_OVER
