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

	assert_eq(allocation.stats(), Stats.calculate([]))


func test_ステータスはアンロック済みノードの効果から計算される():
	a.effects = [{"type": "flat", "stat": "attack", "value": 3}]
	b.effects = [{"type": "flat", "stat": "attack", "value": 2}, {"type": "flat", "stat": "hp", "value": 20}]
	var allocation := SkillAllocation.new(tree, 5)
	allocation.unlock(a.id)
	allocation.unlock(b.id)

	var stats := allocation.stats()

	assert_almost_eq(stats["attack"], Stats.BASE["attack"] + 5.0, 0.001)
	assert_almost_eq(stats["hp"], Stats.BASE["hp"] + 20.0, 0.001)
	assert_almost_eq(stats["defense"], float(Stats.BASE["defense"]), 0.001)


func test_ノードを取得した場合のステータスを事前に計算できる():
	a.effects = [{"type": "flat", "stat": "attack", "value": 3}]
	b.effects = [{"type": "more", "stat": "attack", "value": 100}]
	var allocation := SkillAllocation.new(tree, 5)
	allocation.unlock(a.id)

	var preview := allocation.stats_if_unlocked(b.id)

	assert_almost_eq(preview["attack"], (Stats.BASE["attack"] + 3.0) * 2.0, 0.001)
	assert_false(allocation.is_unlocked(b.id), "事前計算で取得してはいけない")
