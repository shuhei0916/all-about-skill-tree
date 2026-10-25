extends GutTest

var view: SkillTreeView
var tree: SkillTree
var node: SkillNode


func before_each():
	tree = SkillTree.new()
	tree.add_node(-1, 0)
	node = tree.add_node(0, 1)
	node.position = Vector2(100, 0)
	view = autofree(SkillTreeView.new())
	view.size = Vector2(400, 400)
	view.set_tree(tree, SkillAllocation.new(tree, 5))


func test_ノードが描かれている位置からそのノードを特定できる():
	var screen_pos := view.to_screen(node.position)

	assert_eq(view.node_at(screen_pos), node)


func test_ノードの少し外側でもノード半径内なら特定できる():
	var screen_pos := view.to_screen(node.position) + Vector2(SkillTreeView.NODE_RADIUS - 1, 0)

	assert_eq(view.node_at(screen_pos), node)


func test_何もない位置ではnullを返す():
	assert_null(view.node_at(Vector2(5, 5)))
