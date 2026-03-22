## 检索能量附着于V效果 - 从牌库中检索基本能量并附着到己方V宝可梦
## 适用: 阿尔宙斯VSTAR"三重新星"(检索最多3张基本能量附着到己方V宝可梦)
## 参数: max_energy_count
class_name AttackSearchAttachToV
extends BaseEffect

## 最多检索并附着的基本能量数量
var max_energy_count: int = 3


func _init(max_count: int = 3) -> void:
	max_energy_count = max_count


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	return _make_delegate().get_attack_interaction_steps(card, attack, state)


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var delegate := _make_delegate()
	delegate.set_attack_interaction_context([get_attack_interaction_context()])
	delegate.execute_attack(attacker, _defender, _attack_index, state)
	delegate.clear_attack_interaction_context()


func _make_delegate() -> AttackSearchAndAttach:
	return AttackSearchAndAttach.new("", max_energy_count, "deck_search", 0, "v_only")


func get_description() -> String:
	return "从牌库检索最多%d张基本能量，附着到己方V宝可梦，然后洗牌" % max_energy_count
