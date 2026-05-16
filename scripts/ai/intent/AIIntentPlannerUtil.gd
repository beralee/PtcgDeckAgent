class_name AIIntentPlannerUtil
extends RefCounted


static func best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	var name_en := str(cd.name_en).strip_edges()
	if name_en != "":
		return name_en
	return str(cd.name).strip_edges()


static func normalize_name(value: Variant) -> String:
	return str(value).strip_edges().to_lower()


static func name_matches(actual: Variant, expected: Variant) -> bool:
	var lhs := normalize_name(actual)
	var rhs := normalize_name(expected)
	if lhs == "" or rhs == "":
		return false
	return lhs == rhs or lhs.find(rhs) >= 0 or rhs.find(lhs) >= 0


static func action_id(ref: Dictionary) -> String:
	return str(ref.get("id", ref.get("action_id", "")))


static func ref_type(ref: Dictionary) -> String:
	return str(ref.get("type", ref.get("kind", "")))


static func energy_symbol(raw: Variant) -> String:
	var value := str(raw).strip_edges()
	if value == "":
		return ""
	var upper := value.to_upper()
	if upper in ["R", "P", "L", "F", "G", "W", "D", "M", "C"]:
		return upper
	var lower := value.to_lower()
	if lower.find("fire") >= 0 or value.find("火") >= 0:
		return "R"
	if lower.find("psychic") >= 0 or value.find("超") >= 0:
		return "P"
	if lower.find("lightning") >= 0 or value.find("雷") >= 0 or lower.find("electric") >= 0:
		return "L"
	if lower.find("fighting") >= 0 or value.find("斗") >= 0:
		return "F"
	if lower.find("grass") >= 0 or value.find("草") >= 0:
		return "G"
	if lower.find("water") >= 0 or value.find("水") >= 0:
		return "W"
	if lower.find("dark") >= 0 or value.find("恶") >= 0:
		return "D"
	if lower.find("metal") >= 0 or lower.find("steel") >= 0 or value.find("钢") >= 0:
		return "M"
	if lower.find("colorless") >= 0 or value.find("无") >= 0:
		return "C"
	return upper.substr(0, 1)


static func energy_word(symbol: Variant) -> String:
	match energy_symbol(symbol):
		"R":
			return "Fire"
		"P":
			return "Psychic"
		"L":
			return "Lightning"
		"F":
			return "Fighting"
		"G":
			return "Grass"
		"W":
			return "Water"
		"D":
			return "Darkness"
		"M":
			return "Metal"
		"C":
			return "Colorless"
	return str(symbol)


static func symbols_from_cost(raw_cost: Variant) -> Array[String]:
	var result: Array[String] = []
	var cost := str(raw_cost)
	var bracket_symbols := {
		"火": "R",
		"超": "P",
		"雷": "L",
		"斗": "F",
		"草": "G",
		"水": "W",
		"恶": "D",
		"钢": "M",
		"无": "C",
	}
	for key: String in bracket_symbols.keys():
		var count := cost.count(key)
		for _i: int in count:
			result.append(str(bracket_symbols[key]))
	for i: int in cost.length():
		var ch := cost.substr(i, 1).to_upper()
		if ch in ["R", "P", "L", "F", "G", "W", "D", "M", "C"]:
			result.append(ch)
	return result


static func cost_counts(raw_cost: Variant) -> Dictionary:
	var counts := {}
	for symbol: String in symbols_from_cost(raw_cost):
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


static func attached_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var symbol := energy_symbol(card.card_data.energy_provides)
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


static func total_energy_count(counts: Dictionary) -> int:
	var total := 0
	for key: Variant in counts.keys():
		total += int(counts.get(key, 0))
	return total


static func missing_cost(cost_counts: Dictionary, attached_counts: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var colorless_needed := int(cost_counts.get("C", 0))
	var attached_total := total_energy_count(attached_counts)
	for raw_key: Variant in cost_counts.keys():
		var symbol := str(raw_key)
		if symbol == "C":
			continue
		var need := int(cost_counts.get(symbol, 0))
		var have := int(attached_counts.get(symbol, 0))
		for _i: int in maxi(0, need - have):
			missing.append(symbol)
		attached_total -= mini(have, need)
	for _i: int in maxi(0, colorless_needed - maxi(0, attached_total)):
		missing.append("C")
	return missing


static func parse_damage(raw_damage: Variant) -> int:
	var damage := str(raw_damage)
	var digits := ""
	for i: int in damage.length():
		var ch := damage.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


static func damage_is_scaling(raw_damage: Variant, raw_text: Variant = "") -> bool:
	var combined := ("%s %s" % [str(raw_damage), str(raw_text)]).to_lower()
	return combined.find("x") >= 0 or combined.find("×") >= 0 or combined.find("每") >= 0


static func slot_position(slot: PokemonSlot, game_state: GameState, player_index: int) -> String:
	if game_state == null or slot == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return ""
	if player.active_pokemon == slot:
		return "active"
	for i: int in player.bench.size():
		if player.bench[i] == slot:
			return "bench_%d" % i
	return ""


static func slot_by_position(game_state: GameState, player_index: int, position: String) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return null
	if position == "active":
		return player.active_pokemon
	if position.begins_with("bench_"):
		var index := int(position.replace("bench_", ""))
		if index >= 0 and index < player.bench.size():
			return player.bench[index]
	return null


static func own_slots(game_state: GameState, player_index: int) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return slots
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


static func opponent_active_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return 0
	return int(opponent.active_pokemon.get_remaining_hp())


static func attack_dict(cd: CardData, attack_index: int) -> Dictionary:
	if cd == null or attack_index < 0 or attack_index >= cd.attacks.size():
		return {}
	var raw: Variant = cd.attacks[attack_index]
	return raw.duplicate(true) if raw is Dictionary else {}


static func profile_name_list(profile: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = profile.get(key, [])
	if raw is Array:
		for value: Variant in raw:
			if value is Dictionary:
				var pokemon := str((value as Dictionary).get("pokemon", (value as Dictionary).get("name", "")))
				if pokemon != "":
					result.append(pokemon)
			else:
				result.append(str(value))
	return result


static func profile_has_name(profile: Dictionary, key: String, name: String) -> bool:
	for expected: String in profile_name_list(profile, key):
		if name_matches(name, expected):
			return true
	return false
