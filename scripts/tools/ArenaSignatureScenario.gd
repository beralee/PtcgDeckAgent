extends Node
## Explicit local visual acceptance fixture. Initial boards are staged; every
## showcased move goes through the production interaction and rules owners.
class Scene extends "res://scenes/battle/BattleScene.gd":
	func _start_battle() -> void: pass
	func _maybe_run_ai() -> void: pass

var battle: Control
var gsm: GameStateMachine
var acting := 1
var combat_species := ""
var combat_attack_index := 0

const COMBAT_CARDS := {
	"dragapult":["CSV8C","159",1], "charizard":["CSV5C","075",0],
	"munkidori":["CSV8C","094",0], "ceruledge":["CSV9C","034",0],
	"terapagos":["CSV9C","175",1], "grimmsnarl":["CSV10C","148",0],
	"zoroark":["CSV10C","145",0], "archaludon":["CSV9C","138",0],
	"ho_oh":["CSV10C","035",0], "budew":["CSV9.5C","004",0],
	"garchomp":["CSV10C","113",1], "raging_bolt":["CSV7C","154",1],
	"pikachu_tera":["CSV9C","054",0],
	"gardevoir":["CSV2C","055",0],
}

## Stages legal resources for a real move; it never fabricates an attack event.
func mount_combat(species: String) -> void:
	assert(COMBAT_CARDS.has(species))
	await mount("dragapult",1)
	combat_species=species
	combat_attack_index=int(COMBAT_CARDS[species][2])
	var data: CardData=CardDatabase.get_card(COMBAT_CARDS[species][0],COMBAT_CARDS[species][1])
	var player: PlayerState=gsm.game_state.players[acting]
	var defender: PlayerState=gsm.game_state.players[1-acting]
	defender.active_pokemon=_slot(CardDatabase.get_card("CSV8C","159"),1-acting)
	for pi: int in 2:
		gsm.game_state.players[pi].bench[1]=_slot(CardDatabase.get_card("CSV9C","175"),pi)
	if species!="munkidori":
		player.active_pokemon=_slot(data,acting)
		gsm.effect_processor.register_pokemon_card(data)
		for symbol: String in str(data.attacks[combat_attack_index].cost):
			player.active_pokemon.attached_energy.append(CardInstance.create(_energy("R" if symbol=="C" else symbol),acting))
	if species=="ceruledge":
		for i: int in 8:player.discard_pile.append(CardInstance.create(_energy("R"),acting))
	if species=="zoroark":
		var reshiram:=CardDatabase.get_card("CSV10C","166")
		gsm.effect_processor.register_pokemon_card(reshiram)
		player.bench[1]=_slot(reshiram,acting)
	if species=="ho_oh":
		for slot: PokemonSlot in player.get_all_pokemon():slot.damage_counters=50
	if species=="gardevoir":
		for i: int in 2:player.discard_pile.append(CardInstance.create(_energy("P"),acting))
	for pi: int in 2:
		var p: PlayerState=gsm.game_state.players[pi]
		while gsm.count_player_total_cards(pi)>60:p.deck.pop_back()
		while gsm.count_player_total_cards(pi)<60:p.deck.append(CardInstance.create(_energy("R"),pi))
	battle.call("_refresh_ui")
	var presenter: Node=battle.get_node("Arena3DPresenter")
	presenter.motion.clear()
	presenter.motion.shown={}
	presenter._refresh()
	for i: int in 3:await get_tree().process_frame

func combat_move_name() -> String:
	if combat_species=="munkidori":return "亢奋脑力 · 转移 3 个伤害指示物"
	if combat_species=="gardevoir":return str(gsm.game_state.players[acting].active_pokemon.get_top_card().card_data.abilities[0].name)
	var text: String=gsm.game_state.players[acting].active_pokemon.get_attacks()[combat_attack_index].name
	if combat_species=="zoroark":text+=" · 复制纯真火焰"
	return text

func combat_recipient() -> PokemonSlot:
	return gsm.game_state.players[acting].bench[0] if combat_species=="gardevoir" else gsm.game_state.players[1-acting].active_pokemon

func perform_combat() -> bool:
	if combat_species=="munkidori":
		transfer()
		return str(battle.get("_pending_effect_kind"))==""
	if combat_species=="dragapult":
		attack()
		return str(battle.get("_pending_effect_kind"))==""
	var attacker: PokemonSlot=gsm.game_state.players[acting].active_pokemon
	if combat_species=="gardevoir":
		battle.call("_try_use_ability_with_interaction",acting,attacker,0)
	else:
		if not gsm.can_use_attack(acting,combat_attack_index):return false
		battle.call("_try_use_attack_with_interaction",acting,attacker,combat_attack_index)
	# Bind each selection to the current freshly observed interaction step.
	for guard: int in 8:
		if str(battle.get("_pending_effect_kind"))=="":return true
		var steps: Array=battle.get("_pending_effect_steps")
		var index: int=int(battle.get("_pending_effect_step_index"))
		if index<0 or index>=steps.size():return false
		var step: Dictionary=steps[index]
		var picked:=PackedInt32Array()
		var count: int=int(step.get("min_select",1))
		if str(step.get("id",""))=="discard_basic_energy":count=3
		if str(step.get("id",""))=="copied_attack":
			picked.append(1) # N's Reshiram's second, currently offered attack.
		elif str(step.get("id",""))=="embrace_target":
			var offered: Array=step.get("items",[])
			var current_index:=offered.find(combat_recipient())
			if current_index<0:return false
			picked.append(current_index)
		else:
			for i: int in mini(count,step.get("items",[]).size()):picked.append(i)
		battle.call("_handle_effect_interaction_choice",picked)
	return str(battle.get("_pending_effect_kind"))==""

func mount(species: String = "dragapult", owner: int = 1, use_arena: bool = true) -> void:
	acting = owner
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.battle_3d_enabled = use_arena
	GameManager.battle_effects_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	battle.set_script(Scene)
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	gsm = GameStateMachine.new()
	gsm.game_state = GameState.new()
	var gs := gsm.game_state
	gs.current_player_index = owner
	gs.first_player_index = 0
	gs.turn_number = 5
	gs.phase = GameState.GamePhase.MAIN
	var dragapult := CardDatabase.get_card("CSV8C", "159")
	var charizard := CardDatabase.get_card("CSV5C", "075")
	var munkidori := CardDatabase.get_card("CSV8C", "094")
	var support := CardDatabase.get_card("CSV1C", "050")
	for cd: CardData in [dragapult,charizard,munkidori,support]:
		gsm.effect_processor.register_pokemon_card(cd)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gs.players.append(player)
		var attacker := charizard if species == "charizard" else dragapult
		player.active_pokemon = _slot(attacker if pi == owner else charizard, pi)
		for cd: CardData in [munkidori, support, dragapult]:
			player.bench.append(_slot(cd, pi))
		for energy: String in (["R","R"] if pi == owner and species == "charizard" else ["R","P"]):
			player.active_pokemon.attached_energy.append(CardInstance.create(_energy(energy), pi))
		player.bench[0].attached_energy.append(CardInstance.create(_energy("D"), pi))
		var prizes: Array[CardInstance] = []
		for i: int in 6: prizes.append(CardInstance.create(_energy("R"), pi))
		player.set_prizes(prizes)
		for cd: CardData in [support, munkidori, _energy("R"), _energy("P")]:
			player.hand.append(CardInstance.create(cd, pi))
		while gsm.count_player_total_cards(pi) < 60:
			player.deck.append(CardInstance.create(_energy("R"), pi))
	gs.players[owner].active_pokemon.damage_counters = 60
	battle.set("_gsm", gsm)
	battle.set("_view_player", 0)
	battle.call("_bind_game_state_machine_signals", gsm)
	battle.call("_setup_ai_for_tests")
	var ai := AIOpponent.new()
	ai.configure(1, 1)
	battle.set("_ai_opponent", ai)
	battle.call("_refresh_ui")
	for i: int in 12: await get_tree().process_frame
	if not use_arena: return
	var presenter := battle.get_node("Arena3DPresenter")
	presenter.world.motion_enabled = true
	presenter.motion.fast_enabled = false
	presenter.world.sound_enabled = true
	presenter.motion.clear()
	presenter.motion.shown = {}
	presenter._refresh()

func _slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	var card := CardInstance.create(data,owner)
	card.face_up = true
	slot.pokemon_stack.append(card)
	slot.turn_played = 0
	return slot

func _energy(attribute: String) -> CardData:
	for data: CardData in CardDatabase.get_all_cards():
		if data.card_type == "Basic Energy" and data.energy_provides == attribute: return data
	return null

func attack() -> void:
	var attacker := gsm.game_state.players[acting].active_pokemon
	var index := 1 if attacker.get_pokemon_name().contains("多龙") else 0
	battle.call("_try_use_attack_with_interaction",acting,attacker,index)
	if index == 1:
		# Six committed counters, split 3/2/1 across real opposing Bench slots.
		for target: int in [0,0,0,1,1,2]:
			battle.call("_on_counter_distribution_amount_chosen",1)
			battle.call("_handle_counter_distribution_target",target)

func transfer() -> void:
	var monkey := gsm.game_state.players[acting].bench[0]
	battle.call("_try_use_ability_with_interaction",acting,monkey,0)
	battle.call("_handle_field_slot_select_index",0)
	battle.call("_on_counter_distribution_amount_chosen",3)
	battle.call("_handle_counter_distribution_target",0)

func close() -> void:
	if is_instance_valid(battle):
		get_tree().root.remove_child(battle)
		for i: int in 3: await get_tree().process_frame
		battle.free()
	battle = null
