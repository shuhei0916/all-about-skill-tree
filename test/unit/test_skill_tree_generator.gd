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


func _nodes_of_kind(tree: SkillTree, kind: String) -> Array:
	return tree.nodes.filter(func(n: SkillNode): return n.kind == kind)


func test_生成されたツリーにはsmall・notable・keystoneが含まれる():
	for seed in 20:
		var tree := generator.generate(seed)

		assert_eq(tree.root().kind, "root")
		assert_false(_nodes_of_kind(tree, "small").is_empty(), "seed %d" % seed)
		assert_false(_nodes_of_kind(tree, "notable").is_empty(), "seed %d" % seed)
		assert_false(_nodes_of_kind(tree, "keystone").is_empty(), "seed %d" % seed)


func test_keystoneは枝の末端に置かれる():
	for seed in 20:
		var tree := generator.generate(seed)

		for node in _nodes_of_kind(tree, "keystone"):
			assert_true(tree.children_of(node.id).is_empty(), "seed %d: ノード%dの先にまだノードがある" % [seed, node.id])


func _count_over_seeds(predicate: Callable) -> int:
	var count := 0
	for seed in 20:
		var tree := generator.generate(seed)
		count += tree.nodes.filter(func(n: SkillNode): return predicate.call(tree, n)).size()
	return count


func test_notableは枝の途中にも置かれる():
	var count := _count_over_seeds(func(tree: SkillTree, n: SkillNode):
		return n.kind == "notable" and not tree.children_of(n.id).is_empty())

	assert_gt(count, 0)


func test_末端にはsmallも置かれる():
	var count := _count_over_seeds(func(tree: SkillTree, n: SkillNode):
		return n.kind == "small" and tree.children_of(n.id).is_empty())

	assert_gt(count, 0)


func test_notableはルート以外のノードの3割以下():
	var notables := _count_over_seeds(func(_t: SkillTree, n: SkillNode): return n.kind == "notable")
	var non_root := _count_over_seeds(func(_t: SkillTree, n: SkillNode): return n.kind != "root")

	assert_lte(float(notables) / non_root, 0.3)


func test_smallはflatかincreasedを1つ持つ():
	var tree := generator.generate(1)

	for node in _nodes_of_kind(tree, "small"):
		assert_eq(node.effects.size(), 1)
		assert_has(["flat", "increased"], node.effects[0]["type"])
		assert_gt(node.effects[0]["value"], 0)


func test_notableはincreasedを2つ以上持つ():
	var tree := generator.generate(1)

	for node in _nodes_of_kind(tree, "notable"):
		assert_gte(node.effects.size(), 2)
		for effect in node.effects:
			assert_eq(effect["type"], "increased")


func test_keystoneは名前を持ちプラスのmoreとマイナスのmoreを両方持つ():
	var tree := generator.generate(1)

	for node in _nodes_of_kind(tree, "keystone"):
		assert_ne(node.name, "")
		var mores: Array = node.effects.filter(func(e): return e["type"] == "more").map(func(e): return e["value"])
		assert_true(mores.any(func(v): return v > 0), "%s に利得がない" % node.name)
		assert_true(mores.any(func(v): return v < 0), "%s に代償がない" % node.name)
