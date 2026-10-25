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


## 基礎値にアンロック済みノードの補正を合算したステータスを返す。
func stats() -> Dictionary:
	var result := Stats.BASE.duplicate()
	for node in unlocked_nodes():
		for stat in node.stat_bonuses:
			result[stat] += node.stat_bonuses[stat]
	return result
