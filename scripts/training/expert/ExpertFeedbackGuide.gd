extends RefCounted

const TEMPLATE := "目标：\n顺序：\n取舍：\n换打法条件："
const HINT := "写目标、关键顺序、取舍、换打法条件。只写一两项也行；写具体牌、目标和缺的资源，比‘这手更好’更有用。"
const EXAMPLE := "示例（仅说明写法，不是本题答案）：\n目标：愿增猿转移已有的 30 点伤害。\n顺序：平板找愿增猿 → 上场 → 贴恶能量 → 发动特性。\n取舍：优先打到能改变击倒线的目标。\n换打法条件：我方无伤害、已填能或备战区满时，要重新计算路线。\n打错了也可以写：错在哪一步；当时应怎样改。区分当时的想法和事后发现，不必复述整盘操作。"


static func insert_template(existing: String) -> String:
	return TEMPLATE if existing.strip_edges().is_empty() else existing


static func normalized_note(note: String) -> String:
	return "" if note.strip_edges() == TEMPLATE else note.strip_edges()
