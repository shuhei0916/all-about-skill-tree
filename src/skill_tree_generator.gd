class_name SkillTreeGenerator
extends RefCounted

var max_depth := 5
var min_branches := 3
var max_branches := 6
var max_children := 2


func generate(seed: int) -> SkillTree:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tree := SkillTree.new()
	var root := tree.add_node(-1, 0)
	for i in rng.randi_range(min_branches, max_branches):
		_grow(tree, rng, _add_node(tree, rng, root))
	RadialTreeLayout.new().apply(tree)
	return tree


func _grow(tree: SkillTree, rng: RandomNumberGenerator, node: SkillNode) -> void:
	if node.depth >= max_depth:
		return
	# 浅い階層で枝が途切れないよう、最初の数段は必ず1本以上伸ばす
	var min_children := 1 if node.depth < 3 else 0
	for i in rng.randi_range(min_children, max_children):
		_grow(tree, rng, _add_node(tree, rng, node))


func _add_node(tree: SkillTree, rng: RandomNumberGenerator, parent: SkillNode) -> SkillNode:
	var node := tree.add_node(parent.id, parent.depth + 1)
	var stat: String = Stats.NAMES[rng.randi_range(0, Stats.NAMES.size() - 1)]
	var bonus_range: Array = Stats.BONUS_RANGE[stat]
	node.effects.append({"type": "flat", "stat": stat, "value": rng.randi_range(bonus_range[0], bonus_range[1])})
	return node
