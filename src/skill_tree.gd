class_name SkillTree
extends RefCounted

var nodes: Array[SkillNode] = []


func add_node(parent_id: int, depth: int) -> SkillNode:
	var node := SkillNode.new(nodes.size(), parent_id, depth)
	nodes.append(node)
	return node


func root() -> SkillNode:
	return nodes[0]


func get_node(id: int) -> SkillNode:
	return nodes[id]


func children_of(id: int) -> Array[SkillNode]:
	return nodes.filter(func(n: SkillNode): return n.parent_id == id)
