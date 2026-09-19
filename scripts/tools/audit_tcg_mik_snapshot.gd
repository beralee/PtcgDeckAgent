extends SceneTree


func _effect_ref(effect: BaseEffect) -> String:
	if effect == null:
		return ""
	var script: GDScript = effect.get_script()
	if not script.resource_path.is_empty():
		return script.resource_path
	for path in ["res://scripts/effects/ThirtiethCelebrationEffects.gd", "res://scripts/effects/CSV9CEffects.gd", "res://scripts/effects/CSV10CEffects.gd", "res://scripts/effects/CSV10C101To200Effects.gd"]:
		var constants: Dictionary = load(path).get_script_constant_map()
		for key: String in constants:
			if constants[key] is GDScript and constants[key] == script:
				return path + "::" + key
	return "inner_class:" + str(script.get_instance_id())


func _initialize() -> void:
	var source := "res://.tmp/30thc-card-audit/source"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
	var inventory: Array = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("inventory.json")))
	var processor := EffectProcessor.new()
	var report: Array = []
	for entry: Dictionary in inventory:
		if not bool(entry.in_scope):
			continue
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join(str(entry.card_index) + ".json")))
		var card := CardData.from_api_json(raw)
		processor.register_pokemon_card(card)
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(card, 0))
		var attacks: Array = []
		for index in card.attacks.size():
			var paths: Array = []
			for effect: BaseEffect in processor.get_attack_effects_for_slot(slot, index):
				paths.append(_effect_ref(effect))
			attacks.append({"index": index, "rule": card.attacks[index], "effects": paths})
		var effect := processor.get_effect(card.effect_id)
		var row := entry.duplicate()
		row["status"] = CardImplementationStatus.get_status(card)
		row["effect"] = _effect_ref(effect)
		row["attacks"] = attacks
		row["abilities"] = card.abilities
		row["description"] = card.description
		report.append(row)
	var output := FileAccess.open(source.get_base_dir().path_join("registration-audit.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	processor.prepare_for_disposal()
	print("Audited %d source printings" % report.size())
	quit()
