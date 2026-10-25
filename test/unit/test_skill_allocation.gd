extends GutTest

# root(0) ─ a(1) ─ b(2)
var tree: SkillTree
var root: SkillNode
var a: SkillNode
var b: SkillNode


func before_each():
	tree = SkillTree.new()
	root = tree.add_node(-1, 0)
	a = tree.add_node(root.id, 1)
	b = tree.add_node(a.id, 2)


func test_初期状態ではルートだけがアンロックされている():
	var allocation := SkillAllocation.new(tree, 5)

	assert_true(allocation.is_unlocked(root.id))
	assert_false(allocation.is_unlocked(a.id))
	assert_false(allocation.is_unlocked(b.id))


func test_親がアンロック済みのノードはアンロックできる():
	var allocation := SkillAllocation.new(tree, 5)

	assert_true(allocation.unlock(a.id))
	assert_true(allocation.is_unlocked(a.id))


func test_親がアンロックされていないノードはアンロックできない():
	var allocation := SkillAllocation.new(tree, 5)

	assert_false(allocation.unlock(b.id))
	assert_false(allocation.is_unlocked(b.id))


func test_アンロックするとスキルポイントが1減る():
	var allocation := SkillAllocation.new(tree, 5)

	allocation.unlock(a.id)

	assert_eq(allocation.points, 4)


func test_スキルポイントが足りなければアンロックできない():
	var allocation := SkillAllocation.new(tree, 0)

	assert_false(allocation.unlock(a.id))
	assert_false(allocation.is_unlocked(a.id))


func test_アンロック済みのノードは再度アンロックできない():
	var allocation := SkillAllocation.new(tree, 5)
	allocation.unlock(a.id)

	assert_false(allocation.unlock(a.id))
	assert_eq(allocation.points, 4)


func test_何もアンロックしていなければステータスは基礎値のまま():
	var allocation := SkillAllocation.new(tree, 5)

	assert_eq(allocation.stats(), Stats.BASE)


func test_ステータスは基礎値とアンロック済みノードの補正の合計である():
	a.stat_bonuses = {"attack": 3}
	b.stat_bonuses = {"attack": 2, "hp": 20}
	var allocation := SkillAllocation.new(tree, 5)
	allocation.unlock(a.id)
	allocation.unlock(b.id)

	var stats := allocation.stats()

	assert_eq(stats["attack"], Stats.BASE["attack"] + 5)
	assert_eq(stats["hp"], Stats.BASE["hp"] + 20)
	assert_eq(stats["defense"], Stats.BASE["defense"])
