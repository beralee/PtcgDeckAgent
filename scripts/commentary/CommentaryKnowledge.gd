extends RefCounted
const PATH := "res://data/commentary/deck_knowledge.json"
var catalog: Dictionary = {}
var seen: Array[Dictionary] = [{}, {}]

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("schema") == 1: catalog = parsed

func observe(state: Dictionary) -> Dictionary:
	var seats: Array = []
	for seat in range(2):
		var player: Dictionary = state.players[seat]
		var ids: Array = player.discard.keys() + player.lost_zone.keys()
		for slot: Dictionary in [player.active] + player.bench:
			ids.append_array(slot.get("evolution", []))
		for uid: String in ids: seen[seat][uid] = true
		var matches: Array = []
		for key: String in catalog.get("profiles", {}):
			var profile: Dictionary = catalog.profiles[key]
			var evidence: Array = []
			for uid: String in seen[seat]:
				if uid in profile.printings: evidence.append(uid)
			if evidence.is_empty(): continue
			matches.append({"id": key, "evidence_uids": evidence, "opening": profile.opening, "engine": profile.engine, "prizes": profile.prizes, "sustain": profile.sustain, "risks": profile.risks})
		matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.evidence_uids.size() != b.evidence_uids.size(): return a.evidence_uids.size() > b.evidence_uids.size()
			return a.id < b.id
		)
		# This is component evidence, not certainty about an unseen full deck.
		seats.append({"seat": seat, "profiles": matches.slice(0, 5), "certainty": "public_components_only", "unknown_variant": true})
	return {"revision": catalog.get("revision", ""), "seats": seats}

static func signature(knowledge: Dictionary) -> String:
	var ids: Array = []
	for seat: Dictionary in knowledge.get("seats", []):
		var keys: Array = []
		for profile: Dictionary in seat.profiles: keys.append(profile.id)
		keys.sort()
		ids.append(keys)
	return JSON.stringify(ids)
