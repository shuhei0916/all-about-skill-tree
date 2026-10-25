class_name SkillAllocation
extends RefCounted
## スキルツリー上でどのノードをアンロックしたかと、残りのスキルポイントを管理する。

var tree: SkillTree
var points: int
var _unlocked := {}


func _init(p_tree: SkillTree, p_points: int) -> void:
	tree = p_tree
	points = p_points
	_unlocked[tree.root().id] = true


func is_unlocked(id: int) -> bool:
	return _unlocked.has(id)


func can_unlock(id: int) -> bool:
	return points > 0 \
		and not is_unlocked(id) \
		and is_unlocked(tree.get_node(id).parent_id)


func unlock(id: int) -> bool:
	if not can_unlock(id):
		return false
	_unlocked[id] = true
	points -= 1
	return true


func unlocked_nodes() -> Array[SkillNode]:
	return tree.nodes.filter(func(n: SkillNode): return is_unlocked(n.id))


## アンロック済みノードの効果をすべて反映したステータスを返す。
func stats() -> Dictionary:
	return Stats.calculate(_unlocked_effects())


## 指定したノードも取得した場合のステータスを返す。実際には取得しない。
func stats_if_unlocked(id: int) -> Dictionary:
	return Stats.calculate(_unlocked_effects() + tree.get_node(id).effects)


func _unlocked_effects() -> Array:
	var effects := []
	for node in unlocked_nodes():
		effects.append_array(node.effects)
	return effects
