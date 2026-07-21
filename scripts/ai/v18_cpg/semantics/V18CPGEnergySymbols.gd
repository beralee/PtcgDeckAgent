class_name V18CPGEnergySymbols
extends RefCounted

## One canonical, localization-independent energy alphabet for every V18CPG
## capability.  The engine uses R for Fire and N for Dragon.

const SYMBOLS: Array[String] = ["G", "R", "W", "L", "P", "F", "D", "M", "C", "N"]
const NAME_TO_SYMBOL := {
	"GRASS": "G",
	"FIRE": "R",
	"WATER": "W",
	"LIGHTNING": "L",
	"PSYCHIC": "P",
	"FIGHTING": "F",
	"DARKNESS": "D",
	"DARK": "D",
	"METAL": "M",
	"COLORLESS": "C",
	"DRAGON": "N",
}


static func from_card(card: Dictionary) -> String:
	var raw: Variant = card.get("energy_provides", "")
	if str(raw).strip_edges() == "":
		raw = card.get("energy_type", "")
	return canonical(raw)


static func canonical(raw_value: Variant) -> String:
	var raw := str(raw_value).strip_edges().to_upper()
	if raw in SYMBOLS:
		return raw
	for raw_name: Variant in NAME_TO_SYMBOL.keys():
		var name := str(raw_name)
		if raw.contains(name):
			return str(NAME_TO_SYMBOL[name])
	return "other"


static func canonical_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for raw: Variant in value as Array:
		var symbol := canonical(raw)
		if symbol != "other":
			result.append(symbol)
	return result
