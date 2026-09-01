class_name CabtOptionFingerprint
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const DOMAIN_ROOT := "PTCGDAP"
const WINDOW_PROFILE := "cabt_selection_window_v1"
const OPTION_PROFILE := "cabt_option_fingerprint_v1"
const INITIAL_DECK_PROFILE := "cabt_initial_deck_v1"


static func hash_profile_tree(
	selection_profile: Variant,
	profile_id: Variant,
	payload: Variant
) -> String:
	if typeof(selection_profile) != TYPE_DICTIONARY or typeof(profile_id) != TYPE_STRING:
		return ""
	if not [WINDOW_PROFILE, OPTION_PROFILE, INITIAL_DECK_PROFILE].has(profile_id):
		return ""
	var profile: Dictionary = selection_profile
	var hash_contract_value: Variant = profile.get("hash_contract")
	if typeof(hash_contract_value) != TYPE_DICTIONARY:
		return ""
	var profiles_value: Variant = (hash_contract_value as Dictionary).get("profiles")
	if typeof(profiles_value) != TYPE_DICTIONARY:
		return ""
	var profiles: Dictionary = profiles_value
	if not profiles.has(profile_id) or typeof(profiles.get(profile_id)) != TYPE_DICTIONARY:
		return ""
	var profile_contract: Dictionary = profiles.get(profile_id)
	if typeof(profile_contract.get("payload")) != TYPE_DICTIONARY:
		return ""
	var prefix := _locked_profile_prefix(profile_id, profile_contract)
	if prefix.is_empty():
		return ""
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize(payload)
	if not bool(canonical.get("ok", false)):
		return ""
	var digest_input := PackedByteArray()
	digest_input.append_array(prefix)
	var canonical_bytes: PackedByteArray = canonical.get("bytes", PackedByteArray())
	digest_input.append_array(canonical_bytes)
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(digest_input) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _locked_profile_prefix(profile_id: String, profile_contract: Dictionary) -> PackedByteArray:
	var prefix_hex_value: Variant = profile_contract.get("prefix_utf8_hex")
	if typeof(prefix_hex_value) != TYPE_STRING:
		return PackedByteArray()
	var prefix_hex: String = prefix_hex_value
	if prefix_hex.is_empty() or prefix_hex.length() % 2 != 0 or prefix_hex != prefix_hex.to_upper():
		return PackedByteArray()
	for character: String in prefix_hex:
		if character not in "0123456789ABCDEF":
			return PackedByteArray()
	var decoded := prefix_hex.hex_decode()
	var expected := PackedByteArray()
	expected.append_array(DOMAIN_ROOT.to_utf8_buffer())
	expected.append(0)
	expected.append_array(profile_id.to_upper().to_utf8_buffer())
	expected.append(0)
	if decoded != expected:
		return PackedByteArray()
	return decoded


static func window_id(
	selection_profile: Dictionary,
	chooser_player_index: int,
	public_observation_hash: String,
	select_payload: Dictionary
) -> String:
	return hash_profile_tree(selection_profile, WINDOW_PROFILE, {
		"chooser_player_index": chooser_player_index,
		"public_observation_hash": public_observation_hash,
		"select": select_payload.duplicate(true),
	})


static func option_fingerprint(
	selection_profile: Dictionary,
	window_id_value: String,
	public_observation_hash: String,
	option_index: int,
	select_type_raw: int,
	select_context_raw: int,
	option: Dictionary,
	context_card: Variant,
	effect: Variant
) -> String:
	return hash_profile_tree(selection_profile, OPTION_PROFILE, {
		"window_id": window_id_value,
		"public_observation_hash": public_observation_hash,
		"option_index": option_index,
		"select_type_raw": select_type_raw,
		"select_context_raw": select_context_raw,
		"option": option.duplicate(true),
		"context_card": _deep_copy_json(context_card),
		"effect": _deep_copy_json(effect),
	})


static func initial_deck_hash(
	selection_profile: Dictionary,
	card_ids: Array
) -> String:
	return hash_profile_tree(selection_profile, INITIAL_DECK_PROFILE, {
		"card_ids": card_ids.duplicate(true),
	})


static func _deep_copy_json(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value
