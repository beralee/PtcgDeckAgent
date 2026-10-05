extends RefCounted
## Additive current-public-board profile. Serial values are used only for binding.
const BaseInput = preload("res://scripts/ai/ptcgdap/host/godot/SemanticModelInput.gd")
const PROFILE_ID := "ptcgdap_local_semantic_actor_i32_v2"
const FRAME_WIDTH := 416
const OPTION_WIDTH := 48

static func _category(value: Variant, domain: String, seen: Dictionary) -> Variant:
	if value == null: return null
	if typeof(value) != TYPE_STRING:
		seen["error"] = "model_public_category_invalid"; return null
	# A Godot String cannot preserve NUL; hash the exact UTF-8 byte framing.
	var content := "PTCGDAP".to_utf8_buffer(); content.append(0)
	content.append_array("PUBLIC_CATEGORY_V2".to_utf8_buffer()); content.append(0)
	content.append_array(domain.to_utf8_buffer()); content.append(0)
	content.append_array(value.to_utf8_buffer())
	var hashing := HashingContext.new(); hashing.start(HashingContext.HASH_SHA256); hashing.update(content)
	var key: int = hashing.finish().hex_encode().substr(0,8).hex_to_int() % 2147483647 + 1
	var identity: Array = [domain,value]
	if seen.has(key) and seen[key] != identity:
		seen["error"] = "model_public_category_collision"; return null
	seen[key] = identity
	return key

static func _card(value: Variant, seen: Dictionary) -> Variant:
	return _category(value,"printing",seen)

static func _fact(slot: Variant, key: String) -> Variant:
	return slot.get(key) if slot is Dictionary else null

static func _energy(slot: Variant, seen: Dictionary) -> Variant:
	if not slot is Dictionary or not slot.has("attached_energy_uids"): return null
	var values: Variant = slot.attached_energy_uids
	if not values is Array:
		seen["error"] = "model_public_category_invalid"; return null
	var sorted_values: Array = values.duplicate()
	for value: Variant in sorted_values:
		if typeof(value) != TYPE_STRING or "|" in value:
			seen["error"] = "model_public_category_invalid"; return null
	sorted_values.sort()
	return _category("|".join(sorted_values),"energy_multiset",seen)

static func _tool(slot: Variant, seen: Dictionary) -> Variant:
	if not slot is Dictionary or not slot.has("attached_tool_uid"): return null
	return _card(slot.attached_tool_uid,seen) if slot.attached_tool_uid != null else 0

static func _stack(slot: Variant) -> Variant:
	return slot.pokemon_stack_uids.size() if slot is Dictionary and slot.has("pokemon_stack_uids") else null

static func _resolve(option: Dictionary, prefix: String, slots: Array) -> int:
	var entity: Variant = option.get(prefix+"_entity_serial")
	var serial: Variant = option.get(prefix+"_serial")
	var found := -1
	for i: int in slots.size():
		var slot: Variant = slots[i]
		if slot == null: continue
		if (entity != null and slot.get("entity_serial") == entity) or (entity == null and serial != null and slot.get("serial") == serial):
			if found >= 0: return -2
			found = i
	if found >= 0: return found
	if option.kind in ["attack","granted_attack"]:
		var fallback := 9 if prefix == "target" else 0
		if slots[fallback] != null: return fallback
	return -1

static func project(frame: Dictionary, allowed_uids: Dictionary) -> Dictionary:
	var base: Dictionary = BaseInput.project(frame,allowed_uids)
	if not base.get("ok",false): return base
	var own: Dictionary = frame.public_state.self
	var opp: Dictionary = frame.public_state.opponent
	var slots: Array = []
	for side: Dictionary in [own,opp]:
		if side.active.size() > 1 or side.bench.size() > 8:
			return {"ok":false,"error_code":"model_board_capacity_exceeded"}
		slots.append_array(side.active if not side.active.is_empty() else [null])
		slots.append_array(side.bench)
		for unused: int in range(side.bench.size(),8): slots.append(null)
	var codes := {}
	var uids: Array = allowed_uids.keys(); uids.sort()
	for i: int in uids.size(): codes[uids[i]] = i+1
	for option: Dictionary in frame.options:
		if option.get("card_uid") != null and not codes.has(option.card_uid) and option.get("option_player_index") in [null,frame.seat]:
			return {"ok":false,"error_code":"model_unknown_uid"}
	var seen := {}
	var targets: Array = []; var sources: Array = []
	var evolves: Array = []; var attacks: Array = []
	for option: Dictionary in frame.options:
		var ti := _resolve(option,"target",slots); var si := _resolve(option,"source",slots)
		if ti == -2 or si == -2: return {"ok":false,"error_code":"model_public_target_ambiguous"}
		targets.append(ti); sources.append(si)
		if option.kind == "evolve": evolves.append(ti)
		if option.kind in ["attack","granted_attack"]: attacks.append(si)
	var extra: Array = []
	for i: int in slots.size():
		var slot: Variant = slots[i]
		if slot == null:
			for unused: int in 16: extra.append(null)
			continue
		extra.append_array([_card(slot.local_card_uid,seen),codes.get(slot.local_card_uid,0),
			slot.get("remaining_hp"),slot.get("max_hp"),slot.get("damage_counters"),
			slot.get("attached_energy_count"),slot.get("energy_debt"),slot.get("attack_ready"),
			slot.get("prize_value"),slot.get("appeared_this_turn"),_stack(slot),_tool(slot,seen),
			i in evolves,i in attacks,_energy(slot,seen),i in [0,9]])
	var packed: Dictionary = BaseInput._pack(extra)
	if packed.is_empty(): return {"ok":false,"error_code":"model_feature_range_invalid"}
	base.frame_i32.append_array(packed.values)
	base.frame_presence_i32.append_array(packed.presence)
	var rows := PackedInt32Array(); var presence := PackedInt32Array()
	for r: int in base.row_to_current_index.size():
		var index: int = base.row_to_current_index[r]
		var option: Dictionary = frame.options[index]
		var ti: int = targets[index]; var si: int = sources[index]
		var target: Variant = slots[ti] if ti >= 0 else null
		var source: Variant = slots[si] if si >= 0 else null
		var values: Array = [codes.get(option.card_uid,0) if option.get("card_uid") != null else null,
			_fact(target,"appeared_this_turn"),_stack(target),_tool(target,seen),_fact(target,"max_hp"),
			ti in evolves if ti >= 0 else null,_card(option.get("card_uid"),seen),
			_card(_fact(target,"local_card_uid"),seen),_card(option.get("source_uid"),seen),_energy(target,seen),
			ti in attacks if ti >= 0 else null,ti if ti >= 0 else null,
			_fact(source,"appeared_this_turn"),_energy(source,seen),si if si >= 0 else null,
			target.get("attached_tool_uid") != null if target is Dictionary and target.has("attached_tool_uid") else null]
		var op: Dictionary = BaseInput._pack(values)
		if op.is_empty(): return {"ok":false,"error_code":"model_feature_range_invalid"}
		rows.append_array(base.option_i32.slice(r*32,(r+1)*32)); rows.append_array(op.values)
		presence.append_array(base.option_presence_i32.slice(r*32,(r+1)*32)); presence.append_array(op.presence)
	if seen.has("error"): return {"ok":false,"error_code":seen.error}
	rows.resize(1024*OPTION_WIDTH); presence.resize(1024*OPTION_WIDTH)
	base.profile_id = PROFILE_ID; base.option_width = OPTION_WIDTH
	base.option_i32 = rows; base.option_presence_i32 = presence
	return base
