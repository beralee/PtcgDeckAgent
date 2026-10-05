extends RefCounted
## Designed game states, not a psychological diagnosis or an LLM guess.
## The portrait, visible label and speech variant share the same canonical ID.
const ATLAS := "res://assets/ui/opponent_emotions/portraits.png"
const CELL := 256
const IDS := ["eager", "focused", "confident", "confused", "anxious", "frustrated", "surprised", "determined", "proud", "relieved", "joyful", "respectful"]
const DATA := {
	"eager": ["跃跃欲试", "74d8cb", 0.6, 0.6, "开场期待，愿意认真陪练"],
	"focused": ["专注", "7ab8e5", 0.1, 0.4, "认真执行当前招式，不提前宣称战果"],
	"confident": ["自信", "e5bd73", 0.6, 0.5, "自己的主力实际登场，信心增加"],
	"confused": ["犯难", "aeb9ce", -0.2, 0.3, "首次公开展开停滞，有点挠头"],
	"anxious": ["紧张", "e6a473", -0.5, 0.8, "玩家已接近拿完奖赏，自己仍落后"],
	"frustrated": ["郁闷", "bfa0d5", -0.6, 0.5, "连续两个自己的回合没有公开进展，适度自嘲"],
	"surprised": ["意外", "f0c583", -0.2, 0.8, "玩家真实连取多奖后的吃惊"],
	"determined": ["不服输", "eea26e", 0.1, 0.7, "承认压力或损失，仍准备认真应对"],
	"proud": ["小得意", "e7cb75", 0.7, 0.6, "自己实际连取多奖，可以俏皮得意"],
	"relieved": ["松口气", "91d7b1", 0.5, 0.2, "落后时追回奖赏，或停滞后终于接上进攻"],
	"joyful": ["开心", "f1d987", 0.9, 0.8, "已确认获胜，真诚庆祝"],
	"respectful": ["服气", "9ac7d9", 0.1, 0.2, "已确认输棋，认可结果和陪练关系"],
}
const DEFAULTS := {"opening": "eager", "attack_call": "focused", "ace_arrival": "confident", "stalled": "confused", "prize_burst": "proud", "setback": "determined", "recovery": "relieved", "victory": "joyful", "defeat": "respectful"}
const LINE_KEYS := ["opening/eager", "attack_call/focused", "attack_call/anxious", "ace_arrival/confident", "stalled/confused", "stalled/anxious", "stalled/frustrated", "prize_burst/proud", "prize_burst/relieved", "setback/surprised", "setback/determined", "recovery/relieved", "recovery/determined", "victory/joyful", "defeat/respectful"]

static func entry(id: String) -> Dictionary:
	if not DATA.has(id): id = "focused"
	var row: Array = DATA[id]
	return {"id": id, "label": row[0], "color": row[1], "valence": row[2], "arousal": row[3], "meaning": row[4], "index": IDS.find(id)}

static func bind(cue: Dictionary) -> Dictionary:
	var result := cue.duplicate(true)
	var trigger := str(cue.get("trigger", ""))
	var id := str(cue.get("mood_id", DEFAULTS.get(trigger, "focused")))
	if (trigger + "/" + id) not in LINE_KEYS: id = str(DEFAULTS.get(trigger, "focused"))
	result.mood_id = id
	result.mood = entry(id).label
	return result

static func line_key(cue: Dictionary) -> String:
	var canonical := bind(cue)
	return str(canonical.get("trigger", "")) + "/" + str(canonical.mood_id)

static func portrait(id: String) -> AtlasTexture:
	var index := int(entry(id).index)
	var texture := AtlasTexture.new()
	texture.atlas = load(ATLAS)
	texture.region = Rect2((index % 4) * CELL, (index / 4) * CELL, CELL, CELL)
	texture.filter_clip = true
	return texture

static func contract() -> Dictionary:
	var result := {}
	for key: String in LINE_KEYS: result[key] = entry(key.get_slice("/", 1)).meaning
	return result
