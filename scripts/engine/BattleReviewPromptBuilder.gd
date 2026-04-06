class_name BattleReviewPromptBuilder
extends RefCounted

const STAGE1_PROMPT_VERSION := "battle_review_stage1_v3"
const STAGE2_PROMPT_VERSION := "battle_review_stage2_v3"


func build_stage1_payload(compact_match: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": STAGE1_PROMPT_VERSION,
		"response_format": _stage1_schema(),
		"instructions": _stage1_instructions(),
		"match": compact_match,
	}


func build_stage2_payload(turn_packet: Dictionary) -> Dictionary:
	return {
		"system_prompt_version": STAGE2_PROMPT_VERSION,
		"response_format": _stage2_schema(),
		"instructions": _stage2_instructions(),
		"turn_packet": turn_packet,
	}


func _stage1_instructions() -> PackedStringArray:
	return PackedStringArray([
		"用中文回答。",
		"仅使用提供的对局数据。",
		"如果输入中包含 deck_strategies 字段，其中有双方卡组的打法思路。你必须仔细阅读并遵循这些信息进行分析，它比你自身的卡牌知识更准确。",
		"使用双方完整隐藏信息进行赛后分析。",
		"用一句简短的话总结对局局势后再选择关键回合。",
		"每方恰好选择一个关键回合。",
		"保持理由简洁具体。",
		"避免泛泛的战略描述。",
		"仅返回约定 schema 的 JSON。",
		"简要说明每个选定回合值得深入复盘的原因。",
	])


func _stage2_instructions() -> PackedStringArray:
	return PackedStringArray([
		"你是一名世界级PTCG赛后教练，用中文回答。",
		"仅使用提供的回合数据。",
		"如果输入中包含 deck_strategies 字段，其中有双方卡组的打法思路。你必须仔细阅读并遵循这些信息，它比你自身的卡牌知识更准确。",
		"使用双方完整隐藏信息找出真正最强的实战路线。",
		"从场面状态、手牌、弃牌区、牌库计划、奖赏卡地图、行动顺序和对手反制进行推理。",
		"在推荐更优路线前，验证对手最早的现实威胁回合，拒绝依赖虚假时机假设的路线。",
		"如果实际打法已经接近最优，直接说明而不是强行构造反事实。",
		"保持回答简洁：一句总结、最多两个失误、最多四个步骤、一条教训。",
		"避免泛泛的战略描述。",
		"仅返回约定 schema 的 JSON。",
	])


func _stage1_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"winner_index",
			"loser_index",
			"matchup_summary",
			"winner_turns",
			"loser_turns",
		],
		"properties": {
			"winner_index": {"type": "integer"},
			"loser_index": {"type": "integer"},
			"matchup_summary": {"type": "string", "maxLength": 180},
			"winner_turns": {
				"type": "array",
				"minItems": 1,
				"maxItems": 1,
				"items": _selected_turn_schema(),
			},
			"loser_turns": {
				"type": "array",
				"minItems": 1,
				"maxItems": 1,
				"items": _selected_turn_schema(),
			},
		},
	}


func _stage2_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": [
			"turn_number",
			"player_index",
			"judgment",
			"turn_goal",
			"timing_window",
			"why_current_line_falls_short",
			"best_line",
			"coach_takeaway",
			"confidence",
		],
		"properties": {
			"turn_number": {"type": "integer"},
			"player_index": {"type": "integer"},
			"judgment": {"type": "string", "enum": ["optimal", "close_to_optimal", "suboptimal", "missed_line"]},
			"turn_goal": {"type": "string", "maxLength": 140},
			"timing_window": {
				"type": "object",
				"additionalProperties": false,
				"required": ["earliest_opponent_pressure_turn", "assessment"],
				"properties": {
					"earliest_opponent_pressure_turn": {"type": "integer"},
					"assessment": {"type": "string", "maxLength": 180},
				},
			},
			"why_current_line_falls_short": {
				"type": "array",
				"maxItems": 2,
				"items": {"type": "string", "maxLength": 180},
			},
			"best_line": {
				"type": "object",
				"additionalProperties": false,
				"required": ["summary", "steps"],
				"properties": {
					"summary": {"type": "string", "maxLength": 180},
					"steps": {
						"type": "array",
						"maxItems": 4,
						"items": {"type": "string", "maxLength": 180},
					},
				},
			},
			"coach_takeaway": {"type": "string", "maxLength": 180},
			"confidence": {"type": "string"},
		},
	}


func _selected_turn_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["turn_number", "reason"],
		"properties": {
			"turn_number": {"type": "integer"},
			"reason": {"type": "string", "maxLength": 180},
		},
	}


func _string_array_schema() -> Dictionary:
	return {
		"type": "array",
		"items": {"type": "string"},
	}
