extends RefCounted

const BattleReviewUiFormatterScript := preload("res://scripts/ui/battle/BattleReviewFormatter.gd")

var _formatter: RefCounted = BattleReviewUiFormatterScript.new()


func format_review(review: Dictionary) -> String:
	return str(_formatter.call("format_review", review))
