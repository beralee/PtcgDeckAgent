extends RefCounted
## Separate opt-in: enabling commentary never enables an LLM opponent.
const PATH := "user://battle_commentary.cfg"

static func enabled() -> bool:
	var config := ConfigFile.new()
	return config.load(PATH) == OK and bool(config.get_value("commentary", "enabled", false))

static func save_enabled(value: bool) -> Error:
	var config := ConfigFile.new()
	config.set_value("commentary", "enabled", value)
	return config.save(PATH)

static func eligible(opted_in: bool, actual_arena: bool, review: bool, headless: bool) -> bool:
	return opted_in and actual_arena and not review and not headless
