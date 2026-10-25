class_name SkillTreeView
extends Control
## スキルツリーを描画し、クリックでノードをアンロックする。
## ツリーは表示領域に収まるよう、中心を原点として拡大縮小して描く。

signal node_unlocked(node: SkillNode)
signal node_hovered(node: SkillNode)

const NODE_RADIUS := 10.0
const ROOT_RADIUS := 16.0
## 表示領域の短辺に対して、ツリーの半径が占める割合
const FIT_RATIO := 0.45

const COLOR_UNLOCKED := Color("f2c14e")
const COLOR_AVAILABLE := Color("8fd694")
const COLOR_LOCKED := Color("4a4f5c")
const COLOR_EDGE_UNLOCKED := Color("f2c14e")
const COLOR_EDGE_LOCKED := Color("33373f")
const COLOR_HOVER := Color.WHITE

var tree: SkillTree
var allocation: SkillAllocation
var _hovered: SkillNode


func set_tree(p_tree: SkillTree, p_allocation: SkillAllocation) -> void:
	tree = p_tree
	allocation = p_allocation
	_hovered = null
	queue_redraw()


func to_screen(world_pos: Vector2) -> Vector2:
	return size / 2.0 + world_pos * _view_scale()


func node_at(screen_pos: Vector2) -> SkillNode:
	if tree == null:
		return null
	for node in tree.nodes:
		if to_screen(node.position).distance_to(screen_pos) <= _radius_of(node):
			return node
	return null


func _view_scale() -> float:
	var max_radius := 1.0
	for node in tree.nodes:
		max_radius = maxf(max_radius, node.position.length())
	return minf(size.x, size.y) * FIT_RATIO / max_radius


func _radius_of(node: SkillNode) -> float:
	return ROOT_RADIUS if node.parent_id == -1 else NODE_RADIUS


func _draw() -> void:
	if tree == null:
		return
	for node in tree.nodes:
		if node.parent_id == -1:
			continue
		var color := COLOR_EDGE_UNLOCKED if allocation.is_unlocked(node.id) else COLOR_EDGE_LOCKED
		draw_line(to_screen(tree.get_node(node.parent_id).position), to_screen(node.position), color, 3.0, true)
	for node in tree.nodes:
		var center := to_screen(node.position)
		draw_circle(center, _radius_of(node), _color_of(node))
		if node == _hovered:
			draw_arc(center, _radius_of(node) + 3.0, 0.0, TAU, 32, COLOR_HOVER, 2.0, true)


func _color_of(node: SkillNode) -> Color:
	if allocation.is_unlocked(node.id):
		return COLOR_UNLOCKED
	if allocation.can_unlock(node.id):
		return COLOR_AVAILABLE
	return COLOR_LOCKED


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := node_at(event.position)
		if hovered != _hovered:
			_hovered = hovered
			node_hovered.emit(hovered)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := node_at(event.position)
		if clicked != null and allocation.unlock(clicked.id):
			node_unlocked.emit(clicked)
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
