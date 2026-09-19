extends RefCounted
## Versioned public input. Counts use the sealed deck's sorted printing UIDs.
const PROFILE_ID := "ptcgdap_local_semantic_actor_i32_v1"
const FRAME_WIDTH := 128
const OPTION_WIDTH := 32
const KINDS := ["main", "trainer", "play_trainer", "play_basic_to_bench", "evolve", "attach_energy", "ability", "attack", "retreat", "end_turn", "search", "discard", "assignment_source", "assignment_target", "damage_target", "effect_target", "send_out", "setup_active", "setup_bench", "take_prize", "starting_player_choice", "mulligan_draw_count", "self_switch", "opponent_switch", "attack_target", "select_card", "select_number", "yes_no", "stadium", "play_stadium", "use_stadium", "select_energy", "interaction", "attach_tool", "granted_attack", "no", "yes", "use_stadium_effect", "activate", "retreat_energy", "damage_counter", "evolve_from", "evolve_to"]
const TreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CompetitiveScript = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")

static func _code(uid: Variant, codes: Dictionary) -> Variant:
	return codes.get(uid, 0) if uid != null else null

static func _kind(value: Variant) -> Variant:
	return KINDS.find(value) + 1 if value in KINDS else null

static func _count(zone: Array, uid: Variant) -> int:
	var n := 0
	for card: Dictionary in zone:
		if card.get("local_card_uid") == uid: n += 1
	return n

static func _active(side: Dictionary, key: String) -> Variant:
	return side.active[0].get(key) if not side.active.is_empty() else null

static func _sum(slots: Array, key: String) -> int:
	var n := 0
	for slot: Dictionary in slots: n += int(slot.get(key, 0))
	return n

static func _target(option: Dictionary, slot: Dictionary, key: String, fallback: String) -> Variant:
	return option[key] if option.get(key) != null else slot.get(fallback)

static func _pack(values: Array) -> Dictionary:
	var result := PackedInt32Array()
	var presence := PackedInt32Array()
	for value: Variant in values:
		if value == null: result.append(0); presence.append(0)
		elif typeof(value) in [TYPE_INT, TYPE_BOOL] and int(value) >= -2147483648 and int(value) <= 2147483647:
			result.append(int(value)); presence.append(1)
		else: return {}
	return {"values":result, "presence":presence}

static func project(frame: Dictionary, allowed_uids: Dictionary) -> Dictionary:
	if not CompetitiveScript._frame_error(frame).is_empty():
		return {"ok":false, "error_code":"model_public_frame_invalid"}
	var uids: Array = allowed_uids.keys(); uids.sort()
	if uids.is_empty() or uids.size() > 32: return {"ok":false,"error_code":"model_unknown_uid"}
	var codes := {}
	for i: int in uids.size(): codes[uids[i]] = i + 1
	var own: Dictionary = frame.public_state.self
	var opp: Dictionary = frame.public_state.opponent
	var sem: Dictionary = frame.select_semantics
	var board: Array = own.active + own.bench
	var enemy: Array = opp.active + opp.bench
	for card: Dictionary in own.hand + own.discard + board:
		if not codes.has(card.get("local_card_uid")): return {"ok":false,"error_code":"model_unknown_uid"}
	var turn: Dictionary = own.get("turn", {})
	var fv: Array = [frame.public_state.turn_number, own.prizes_remaining, opp.prizes_remaining,
		own.deck_count, opp.deck_count, own.hand.size(), opp.hand_count, own.bench.size(), opp.bench.size(),
		_active(own,"remaining_hp"), _active(opp,"remaining_hp"), _active(own,"attached_energy_count"), _active(opp,"attached_energy_count"),
		_active(own,"damage_counters"), _active(opp,"damage_counters"), _sum(board,"attack_ready"), _sum(enemy,"attack_ready"),
		sem.min_count, sem.max_count, sem.select_context_raw, sem.select_type_raw,
		turn.get("supporter_available"), turn.get("manual_attachment_available"), turn.get("retreat_available"),
		_code(_active(own,"local_card_uid"),codes), _code(_active(opp,"local_card_uid"),codes), _code(sem.get("source_card_uid"),codes),
		sem.get("remain_damage_counter"), sem.get("remain_energy_cost"), _sum(own.bench,"damage_counters"), _sum(opp.bench,"damage_counters"), _kind(frame.prompt_kind)]
	for zone: Array in [own.hand, board, own.discard]:
		for uid: String in uids: fv.append(_count(zone,uid))
		for unused: int in range(uids.size(),32): fv.append(null)
	var packed := _pack(fv)
	if packed.is_empty(): return {"ok":false,"error_code":"model_feature_range_invalid"}
	var rows: Array = []
	for i: int in frame.options.size():
		var o: Dictionary = frame.options[i]
		if o.get("kind") not in KINDS: return {"ok":false,"error_code":"model_unknown_option_shape"}
		var uid: Variant = o.get("target_uid") if o.kind == "evolve" else o.get("card_uid")
		if uid == null: uid = o.get("source_uid")
		if uid != null and not codes.has(uid) and o.get("option_player_index") in [null,frame.seat]:
			return {"ok":false,"error_code":"model_unknown_uid"}
		var target := {}
		for slot: Dictionary in board + enemy:
			if (o.get("target_entity_serial") != null and slot.get("entity_serial") == o.get("target_entity_serial")) or (o.get("target_entity_serial") == null and o.get("target_serial") != null and slot.get("serial") == o.get("target_serial")):
				target = slot; break
		if target.is_empty() and o.kind == "attack" and not opp.active.is_empty(): target = opp.active[0]
		var values: Array = [_kind(o.kind), _code(uid,codes), _code(o.get("source_uid"),codes), _code(o.get("target_uid"),codes),
			o.get("energy_type_raw"),o.get("energy_count"),o.get("attack_index"),o.get("ability_index"),
			_target(o,target,"target_remaining_hp","remaining_hp"), _target(o,target,"target_damage_counters","damage_counters"),
			_target(o,target,"target_attached_energy_count","attached_energy_count"), _target(o,target,"target_energy_debt","energy_debt"),
			_target(o,target,"target_attack_ready","attack_ready"),o.get("projected_damage"),o.get("projected_knockout"),
			_target(o,target,"target_prize_value","prize_value"),o.get("option_player_index") == frame.seat if o.get("option_player_index") != null else null,
			_count(own.hand,uid) if uid != null else null, _count(board,o.get("target_uid")) if o.get("target_uid") != null else null,
			_count(own.discard,uid) if uid != null else null,o.get("option_number"),o.get("special_condition_type"),o.get("option_area_raw"),
			target in own.active + opp.active if not target.is_empty() else null,target in own.bench + opp.bench if not target.is_empty() else null,_target(o,target,"target_minimum_attack_energy_count","minimum_attack_energy_count"),
			o.get("pending_assignment_count"),o.get("assigned_energy_count"),sem.get("remain_damage_counter"),o.get("option_type_raw"),
			o.get("source_damage_counters"),o.get("source_energy_count")]
		var op := _pack(values)
		if op.is_empty(): return {"ok":false,"error_code":"model_feature_range_invalid"}
		var semantic := o.duplicate(true); semantic.erase("index")
		var canonical: Dictionary = TreeScript.canonicalize_artifact_json_bytes(JSON.stringify(semantic).to_utf8_buffer())
		if not canonical.get("ok",false): return {"ok":false,"error_code":"model_public_frame_invalid"}
		var hash_context := HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256)
		hash_context.update("PTCGDAP".to_utf8_buffer())
		hash_context.update(PackedByteArray([0]))
		hash_context.update("SEMANTIC_MODEL_OPTION_V1".to_utf8_buffer())
		hash_context.update(PackedByteArray([0]))
		hash_context.update(canonical.get("bytes",PackedByteArray()))
		rows.append({"index":i,"key":hash_context.finish().hex_encode().to_upper(),"values":op.values,"presence":op.presence})
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		return a.key < b.key if a.key != b.key else a.index < b.index)
	var values := PackedInt32Array(); var presence := PackedInt32Array(); var mask := PackedInt32Array()
	var indexes: Array = []; var keys: Array = []; var reverse := {}
	for r: int in rows.size():
		values.append_array(rows[r].values); presence.append_array(rows[r].presence); mask.append(1)
		indexes.append(rows[r].index); keys.append(rows[r].key); reverse[rows[r].index]=r
	values.resize(1024*OPTION_WIDTH); presence.resize(1024*OPTION_WIDTH); mask.resize(1024)
	return {"ok":true,"error_code":"","profile_id":PROFILE_ID,"option_width":OPTION_WIDTH,
		"frame_i32":packed.values,"frame_presence_i32":packed.presence,"option_i32":values,
		"option_presence_i32":presence,"option_mask_i32":mask,"row_to_current_index":indexes,
		"current_index_to_row":reverse,"semantic_keys":keys}
