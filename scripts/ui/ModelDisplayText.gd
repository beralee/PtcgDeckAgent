extends RefCounted
## Provider output is text, not authority to add BBCode tags or clickable links.
static func escape_tree(value: Variant) -> Variant:
	if value is String:
		return value.replace("[", "[lb]")
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(escape_tree(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = escape_tree(value[key])
		return result
	return value
