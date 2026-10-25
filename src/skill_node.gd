class_name SkillNode
extends RefCounted

var id: int
var parent_id: int
var depth: int
var position := Vector2.ZERO
## 効果の配列。各要素は {"type": "flat"|"increased"|"more", "stat": ステータス名, "value": 整数}
var effects: Array[Dictionary] = []


func _init(p_id: int, p_parent_id: int, p_depth: int) -> void:
	id = p_id
	parent_id = p_parent_id
	depth = p_depth
