class_name SkillNode
extends RefCounted

var id: int
var parent_id: int
var depth: int
var position := Vector2.ZERO
## ステータス名 -> 加算値
var stat_bonuses := {}


func _init(p_id: int, p_parent_id: int, p_depth: int) -> void:
	id = p_id
	parent_id = p_parent_id
	depth = p_depth
