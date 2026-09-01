class_name OpponentDeckFingerprintResolver
extends RefCounted

## Deterministic opponent-deck inference for the exact 25 built-in V18 decks.
##
## This resolver never selects the local player's production strategy. Own-deck
## strategy selection must continue to use the exact deck ID through
## DeckStrategyRegistry. This component only classifies an opponent from public
## cards so a strategy can choose matchup-specific policy.

const ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")

const STATUS_UNIQUE := "unique"
const STATUS_AMBIGUOUS := "ambiguous"
const STATUS_UNKNOWN := "unknown"
const STATUS_NO_MATCH := "no_match"
const STATUS_CATALOG_ERROR := "catalog_error"
const DECK_PATH_FORMAT := "res://data/bundled_user/decks/%d.json"
const EXPECTED_DECK_COUNT := 25

static var _catalog_ready := false
static var _catalog_errors: Array[String] = []
static var _deck_card_counts: Dictionary = {}
static var _deck_profiles: Dictionary = {}
static var _key_deck_ids: Dictionary = {}
static var _key_metadata: Dictionary = {}
static var _deck_total_cards: Dictionary = {}


static func classify_game_state(game_state: GameState, observer_player_index: int) -> Dictionary:
	return classify_visible_cards(collect_public_opponent_cards(game_state, observer_player_index))


static func classify_visible_cards(visible_cards: Array) -> Dictionary:
	_ensure_catalog()
	if not _catalog_errors.is_empty():
		return _result(STATUS_CATALOG_ERROR, {}, [], [])

	var observed_counts: Dictionary = {}
	var seen_instance_ids: Dictionary = {}
	for item: Variant in visible_cards:
		var observation := _observation_from_item(item)
		if observation.is_empty():
			continue
		var instance_id := int(observation.get("instance_id", -1))
		if instance_id >= 0:
			if seen_instance_ids.has(instance_id):
				continue
			seen_instance_ids[instance_id] = true
		var key := str(observation.get("key", ""))
		if key == "":
			continue
		observed_counts[key] = int(observed_counts.get(key, 0)) + 1

	return _classify_counts(observed_counts)


static func collect_public_opponent_cards(game_state: GameState, observer_player_index: int) -> Array:
	var cards: Array = []
	if game_state == null or game_state.players.size() < 2:
		return cards
	var opponent_index := _opponent_index(game_state, observer_player_index)
	if opponent_index < 0:
		return cards
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return cards

	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null:
			continue
		cards.append_array(slot.pokemon_stack)
		cards.append_array(slot.attached_energy)
		if slot.attached_tool != null:
			cards.append(slot.attached_tool)
	cards.append_array(opponent.discard_pile)
	cards.append_array(opponent.lost_zone)

	# Stadium ownership is public. Do not attribute an opponent-independent or
	# observer-owned Stadium to the opponent.
	if game_state.stadium_card != null and game_state.stadium_owner_index == opponent_index:
		cards.append(game_state.stadium_card)
	return cards


static func minimal_unique_fingerprint(deck_id: int, max_cards: int = 2) -> Dictionary:
	_ensure_catalog()
	if not _catalog_errors.is_empty():
		return {
			"status": STATUS_CATALOG_ERROR,
			"deck_id": deck_id,
			"evidence": [],
			"evidence_card_count": 0,
		}
	if not _deck_card_counts.has(deck_id):
		return {
			"status": STATUS_NO_MATCH,
			"deck_id": deck_id,
			"evidence": [],
			"evidence_card_count": 0,
		}

	var available: Dictionary = _deck_card_counts[deck_id]
	var evidence := _find_minimal_unique_evidence(available, deck_id, maxi(1, max_cards))
	var profile: Dictionary = _deck_profiles.get(deck_id, {})
	return {
		"status": STATUS_UNIQUE if not evidence.is_empty() else STATUS_AMBIGUOUS,
		"deck_id": deck_id,
		"deck_name": str(profile.get("deck_name", "")),
		"strategy_id": str(profile.get("strategy_id", "")),
		"archetype": str(profile.get("archetype", "")),
		"evidence": evidence,
		"evidence_card_count": _evidence_card_count(evidence),
	}


static func catalog_report() -> Dictionary:
	_ensure_catalog()
	var deck_ids: Array[int] = []
	for raw_deck_id: Variant in _deck_card_counts.keys():
		deck_ids.append(int(raw_deck_id))
	deck_ids.sort()
	return {
		"valid": _catalog_errors.is_empty(),
		"deck_count": deck_ids.size(),
		"deck_ids": deck_ids,
		"deck_total_cards": _deck_total_cards.duplicate(true),
		"errors": _catalog_errors.duplicate(),
	}


static func reset_catalog_cache_for_tests() -> void:
	_catalog_ready = false
	_catalog_errors.clear()
	_deck_card_counts.clear()
	_deck_profiles.clear()
	_key_deck_ids.clear()
	_key_metadata.clear()
	_deck_total_cards.clear()


static func _classify_counts(observed_counts: Dictionary) -> Dictionary:
	if observed_counts.is_empty():
		return _result(STATUS_UNKNOWN, observed_counts, [], [])
	var candidates := _candidate_deck_ids_for_requirements(observed_counts)
	if candidates.is_empty():
		return _result(STATUS_NO_MATCH, observed_counts, candidates, [])
	if candidates.size() > 1:
		return _result(STATUS_AMBIGUOUS, observed_counts, candidates, [])

	var deck_id := int(candidates[0])
	var evidence := _find_minimal_unique_evidence(observed_counts, deck_id, 2)
	if evidence.is_empty():
		evidence = _evidence_from_requirements(observed_counts)
	return _result(STATUS_UNIQUE, observed_counts, candidates, evidence)


static func _result(
	status: String,
	observed_counts: Dictionary,
	candidate_deck_ids: Array[int],
	evidence: Array[Dictionary]
) -> Dictionary:
	var candidate_decks: Array[Dictionary] = []
	for deck_id: int in candidate_deck_ids:
		candidate_decks.append(_deck_summary(deck_id))
	var result := {
		"status": status,
		"is_unique": status == STATUS_UNIQUE,
		"scope": "v18_builtin_25",
		"deck_id": 0,
		"deck_name": "",
		"strategy_id": "",
		"archetype": "",
		"candidate_deck_ids": candidate_deck_ids.duplicate(),
		"candidate_decks": candidate_decks,
		"observed_cards": _evidence_from_requirements(observed_counts),
		"observed_card_count": _requirement_card_count(observed_counts),
		"evidence": evidence.duplicate(true),
		"evidence_card_count": _evidence_card_count(evidence),
		"catalog_errors": _catalog_errors.duplicate(),
	}
	if status == STATUS_UNIQUE and candidate_deck_ids.size() == 1:
		result.merge(_deck_summary(int(candidate_deck_ids[0])), true)
	return result


static func _deck_summary(deck_id: int) -> Dictionary:
	var profile: Dictionary = _deck_profiles.get(deck_id, {})
	return {
		"deck_id": deck_id,
		"deck_name": str(profile.get("deck_name", "")),
		"strategy_id": str(profile.get("strategy_id", "")),
		"archetype": str(profile.get("archetype", "")),
	}


static func _find_minimal_unique_evidence(
	available_counts: Dictionary,
	deck_id: int,
	max_cards: int
) -> Array[Dictionary]:
	var keys: Array[String] = []
	for raw_key: Variant in available_counts.keys():
		keys.append(str(raw_key))
	keys.sort()

	# One identity can itself be a one-card fingerprint, or a two-copy
	# fingerprint when deck-list counts are the distinguishing fact.
	for key: String in keys:
		var available_count := int(available_counts.get(key, 0))
		for required_count: int in range(1, mini(available_count, max_cards) + 1):
			var requirements := {key: required_count}
			if _is_unique_for_deck(requirements, deck_id):
				return _evidence_from_requirements(requirements)

	if max_cards < 2:
		return []
	for left_index: int in range(keys.size()):
		for right_index: int in range(left_index + 1, keys.size()):
			var requirements := {
				keys[left_index]: 1,
				keys[right_index]: 1,
			}
			if _is_unique_for_deck(requirements, deck_id):
				return _evidence_from_requirements(requirements)
	return []


static func _is_unique_for_deck(requirements: Dictionary, deck_id: int) -> bool:
	var candidates := _candidate_deck_ids_for_requirements(requirements)
	return candidates.size() == 1 and int(candidates[0]) == deck_id


static func _candidate_deck_ids_for_requirements(requirements: Dictionary) -> Array[int]:
	var candidates: Array[int] = []
	for raw_deck_id: Variant in _deck_card_counts.keys():
		var deck_id := int(raw_deck_id)
		var deck_counts: Dictionary = _deck_card_counts[deck_id]
		var matches := true
		for raw_key: Variant in requirements.keys():
			var key := str(raw_key)
			if int(deck_counts.get(key, 0)) < int(requirements.get(key, 0)):
				matches = false
				break
		if matches:
			candidates.append(deck_id)
	candidates.sort()
	return candidates


static func _evidence_from_requirements(requirements: Dictionary) -> Array[Dictionary]:
	var keys: Array[String] = []
	for raw_key: Variant in requirements.keys():
		keys.append(str(raw_key))
	keys.sort()
	var evidence: Array[Dictionary] = []
	for key: String in keys:
		var metadata: Dictionary = _key_metadata.get(key, {})
		evidence.append({
			"key": key,
			"count": int(requirements.get(key, 0)),
			"display_name": str(metadata.get("display_name", key)),
			"name": str(metadata.get("name", "")),
			"name_en": str(metadata.get("name_en", "")),
			"uid": str(metadata.get("uid", "")),
			"effect_id": str(metadata.get("effect_id", "")),
			"card_type": str(metadata.get("card_type", "")),
		})
	return evidence


static func _evidence_card_count(evidence: Array[Dictionary]) -> int:
	var total := 0
	for item: Dictionary in evidence:
		total += int(item.get("count", 0))
	return total


static func _requirement_card_count(requirements: Dictionary) -> int:
	var total := 0
	for count: Variant in requirements.values():
		total += int(count)
	return total


static func _observation_from_item(item: Variant) -> Dictionary:
	var card_data: CardData = null
	var instance_id := -1
	if item is CardInstance:
		var card_instance := item as CardInstance
		card_data = card_instance.card_data
		instance_id = int(card_instance.instance_id)
	elif item is CardData:
		card_data = item as CardData
	elif item is Dictionary:
		var item_dict: Dictionary = item
		var nested: Variant = item_dict.get("card_data", null)
		if nested is CardData:
			card_data = nested as CardData
			instance_id = int(item_dict.get("instance_id", -1))
		else:
			var dictionary_key := _semantic_key_from_dictionary(item_dict)
			return {"key": dictionary_key, "instance_id": int(item_dict.get("instance_id", -1))} if dictionary_key != "" else {}
	if card_data == null:
		return {}
	var key := _semantic_key_from_card_data(card_data)
	return {"key": key, "instance_id": instance_id} if key != "" else {}


static func _semantic_key_from_card_data(card_data: CardData) -> String:
	if card_data == null:
		return ""
	var effect_id := str(card_data.effect_id).strip_edges().to_lower()
	if effect_id != "":
		return "effect:%s" % effect_id
	var uid := str(card_data.get_uid()).strip_edges().to_upper()
	if uid != "" and uid != "_":
		return "uid:%s" % uid
	return _name_key([card_data.name_en, card_data.name_zh, card_data.name])


static func _semantic_key_from_dictionary(card: Dictionary) -> String:
	var explicit_key := str(card.get("key", "")).strip_edges()
	if explicit_key != "":
		return explicit_key
	var effect_id := str(card.get("effect_id", "")).strip_edges().to_lower()
	if effect_id != "":
		return "effect:%s" % effect_id
	var uid := str(card.get("uid", "")).strip_edges().to_upper()
	if uid == "":
		var set_code := str(card.get("set_code", "")).strip_edges().to_upper()
		var card_index := str(card.get("card_index", "")).strip_edges().to_upper()
		if set_code != "" and card_index != "":
			uid = "%s_%s" % [set_code, card_index]
	if uid != "" and uid != "_":
		return "uid:%s" % uid
	return _name_key([card.get("name_en", ""), card.get("name_zh", ""), card.get("name", ""), card.get("display_name", "")])


static func _name_key(names: Array) -> String:
	for raw_name: Variant in names:
		var normalized := str(raw_name).strip_edges().to_lower()
		if normalized != "":
			return "name:%s" % normalized
	return ""


static func _opponent_index(game_state: GameState, observer_player_index: int) -> int:
	if observer_player_index < 0 or observer_player_index >= game_state.players.size():
		return -1
	for candidate_index: int in range(game_state.players.size()):
		if candidate_index != observer_player_index:
			return candidate_index
	return -1


static func _ensure_catalog() -> void:
	if _catalog_ready:
		return
	_catalog_ready = true
	var deck_ids: Array[int] = ProfileCatalogScript.deck_ids()
	if deck_ids.size() != EXPECTED_DECK_COUNT:
		_catalog_errors.append("expected_%d_decks_got_%d" % [EXPECTED_DECK_COUNT, deck_ids.size()])
	var seen_deck_ids: Dictionary = {}
	for deck_id: int in deck_ids:
		if seen_deck_ids.has(deck_id):
			_catalog_errors.append("duplicate_deck_id_%d" % deck_id)
			continue
		seen_deck_ids[deck_id] = true
		_load_deck(deck_id)


static func _load_deck(deck_id: int) -> void:
	var profile: Dictionary = ProfileCatalogScript.get_profile_for_deck(deck_id)
	if profile.is_empty() or str(profile.get("strategy_id", "")) == "":
		_catalog_errors.append("missing_profile_%d" % deck_id)
		return
	var path := DECK_PATH_FORMAT % deck_id
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_catalog_errors.append("missing_deck_%d" % deck_id)
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		_catalog_errors.append("invalid_deck_json_%d" % deck_id)
		return
	var payload: Dictionary = parser.data
	var cards_variant: Variant = payload.get("cards", [])
	if not (cards_variant is Array):
		_catalog_errors.append("missing_cards_%d" % deck_id)
		return

	var counts: Dictionary = {}
	var total_cards := 0
	for card_variant: Variant in cards_variant:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var count := int(card.get("count", 0))
		total_cards += count
		var key := _semantic_key_from_dictionary(card)
		if key == "" or count <= 0:
			continue
		counts[key] = int(counts.get(key, 0)) + count
		_register_key_metadata(key, card)
		var member_ids: Array = _key_deck_ids.get(key, [])
		if deck_id not in member_ids:
			member_ids.append(deck_id)
		_key_deck_ids[key] = member_ids
	_deck_card_counts[deck_id] = counts
	_deck_profiles[deck_id] = profile.duplicate(true)
	_deck_total_cards[deck_id] = total_cards
	if total_cards != 60:
		_catalog_errors.append("deck_%d_has_%d_cards" % [deck_id, total_cards])


static func _register_key_metadata(key: String, card: Dictionary) -> void:
	if _key_metadata.has(key):
		return
	var set_code := str(card.get("set_code", "")).strip_edges().to_upper()
	var card_index := str(card.get("card_index", "")).strip_edges().to_upper()
	var uid := "%s_%s" % [set_code, card_index] if set_code != "" and card_index != "" else ""
	var display_name := str(card.get("name_en", "")).strip_edges()
	if display_name == "":
		display_name = str(card.get("name", "")).strip_edges()
	_key_metadata[key] = {
		"display_name": display_name,
		"name": str(card.get("name", "")),
		"name_en": str(card.get("name_en", "")),
		"uid": uid,
		"effect_id": str(card.get("effect_id", "")),
		"card_type": str(card.get("card_type", "")),
	}
