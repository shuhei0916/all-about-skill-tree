extends GutTest

var generator: SkillTreeGenerator


func before_each():
	generator = SkillTreeGenerator.new()


func test_生成されたツリーにはルートノードが1つだけある():
	var tree := generator.generate(1)

	var roots := tree.nodes.filter(func(n: SkillNode): return n.parent_id == -1)
	assert_eq(roots.size(), 1)


func test_ルート以外にもノードが生成される():
	var tree := generator.generate(1)

	assert_gt(tree.nodes.size(), 1)


func test_ルート以外のノードはすべて存在する親を持つ():
	var tree := generator.generate(1)
	var ids := tree.nodes.map(func(n: SkillNode): return n.id)

	for node in tree.nodes:
		if node.parent_id == -1:
			continue
		assert_has(ids, node.parent_id, "ノード%dの親が存在しない" % node.id)


func test_すべてのノードの深さは最大深さ以下である():
	generator.max_depth = 3
	var tree := generator.generate(1)

	for node in tree.nodes:
		assert_lte(node.depth, 3)


func test_同じシードからは同じツリーが生成される():
	var a := generator.generate(42)
	var b := generator.generate(42)

	assert_eq(_structure_of(a), _structure_of(b))


func test_異なるシードからは異なるツリーが生成される():
	var a := generator.generate(1)
	var b := generator.generate(2)

	assert_ne(_structure_of(a), _structure_of(b))


# ツリーの形を比較できるよう、各ノードの親IDの並びに変換する
func _structure_of(tree: SkillTree) -> Array:
	return tree.nodes.map(func(n: SkillNode): return n.parent_id)


func test_ルートは中心に配置される():
	var tree := generator.generate(1)

	assert_eq(tree.root().position, Vector2.ZERO)


func test_ノードは親よりも中心から遠くに配置される():
	var tree := generator.generate(1)

	for node in tree.nodes:
		if node.parent_id == -1:
			continue
		var parent := tree.get_node(node.parent_id)
		assert_gt(node.position.length(), parent.position.length())


func test_ルート以外のノードは効果を持つ():
	var tree := generator.generate(1)

	for node in tree.nodes:
		if node.parent_id == -1:
			continue
		assert_false(node.effects.is_empty(), "ノード%dに効果がない" % node.id)
		for effect in node.effects:
			assert_has(Stats.NAMES, effect["stat"])


func test_ルートは効果を持たない():
	var tree := generator.generate(1)

	assert_true(tree.root().effects.is_empty())
