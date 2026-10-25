class_name RadialTreeLayout
extends RefCounted
## ルートを中心に、深さごとの同心円上へノードを配置する。
## 各部分木には葉の数に比例した角度の幅を割り当て、枝同士が重ならないようにする。

var ring_spacing := 80.0


func apply(tree: SkillTree) -> void:
	_place(tree, tree.root(), 0.0, TAU)


func _place(tree: SkillTree, node: SkillNode, start_angle: float, span: float) -> void:
	var angle := start_angle + span / 2.0
	node.position = Vector2.from_angle(angle) * ring_spacing * node.depth
	var children := tree.children_of(node.id)
	var total_leaves := _count_leaves(tree, node)
	var cursor := start_angle
	for child in children:
		var child_span := span * _count_leaves(tree, child) / total_leaves
		_place(tree, child, cursor, child_span)
		cursor += child_span


func _count_leaves(tree: SkillTree, node: SkillNode) -> int:
	var children := tree.children_of(node.id)
	if children.is_empty():
		return 1
	var count := 0
	for child in children:
		count += _count_leaves(tree, child)
	return count
