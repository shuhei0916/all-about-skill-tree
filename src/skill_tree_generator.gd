class_name SkillTreeGenerator
extends RefCounted
## シードからスキルツリーを生成する。
## まず木の形を作り、その後で種類と効果を割り当てる。
## keystone は遠い末端に置き、notable は末端と道中の両方に置く（PoE2の配置に倣う）。

var max_depth := 5
var min_branches := 3
var max_branches := 6
var max_children := 2
## 1つのツリーに置くキーストーンの数 [最小, 最大]
var keystone_count := [1, 2]
## 枝の途中・末端のノードがnotableになる確率
var notable_chance_on_path := 0.15
var notable_chance_at_leaf := 0.45

## flat効果の値の範囲 [最小, 最大]。会心系は固定値だと分かりにくいので %系の効果だけにする。
const FLAT_RANGE := {
	"hp": [10, 30],
	"attack": [1, 5],
	"defense": [1, 5],
	"speed": [1, 3],
}
const SMALL_INCREASED_RANGE := [4, 8]
const NOTABLE_INCREASED_RANGE := [10, 20]

## キーストーンの候補。大きな利得と、それに見合う代償を持つ。
const KEYSTONES := [
	{"name": "狂戦士の誓い", "effects": [
		{"type": "more", "stat": "attack", "value": 50},
		{"type": "more", "stat": "defense", "value": -40}]},
	{"name": "不動の構え", "effects": [
		{"type": "more", "stat": "defense", "value": 80},
		{"type": "more", "stat": "speed", "value": -30}]},
	{"name": "研ぎ澄まされた刃", "effects": [
		{"type": "more", "stat": "crit_chance", "value": 100},
		{"type": "more", "stat": "hp", "value": -25}]},
	{"name": "疾風", "effects": [
		{"type": "more", "stat": "speed", "value": 40},
		{"type": "more", "stat": "attack", "value": -20}]},
	{"name": "巨人の血", "effects": [
		{"type": "more", "stat": "hp", "value": 60},
		{"type": "more", "stat": "speed", "value": -25}]},
	{"name": "一撃必殺", "effects": [
		{"type": "more", "stat": "crit_damage", "value": 80},
		{"type": "more", "stat": "crit_chance", "value": -30}]},
	{"name": "ガラスの大砲", "effects": [
		{"type": "more", "stat": "attack", "value": 80},
		{"type": "more", "stat": "hp", "value": -50}]},
]


## テーマ。付与する側（enabler）と、その状態を活かす側（payoffs）のノータブルをセットで置く。
## 値は [最小, 最大] の範囲から決める。
const THEMES := [
	{"enabler": {"name": "目くらまし", "effects": [
		{"type": "on_hit", "chance": [20, 30], "apply": "blind"},
		{"type": "increased", "stat": "speed", "value": [5, 10]}]},
	"payoffs": [
		{"name": "闇討ち", "effects": [
			{"type": "flat", "stat": "crit_chance", "value": [15, 25], "condition": "enemy_blinded"},
			{"type": "increased", "stat": "crit_damage", "value": [15, 25], "condition": "enemy_blinded"}]},
		{"name": "見えざる刃", "effects": [
			{"type": "increased", "stat": "attack", "value": [20, 30], "condition": "enemy_blinded"},
			{"type": "increased", "stat": "defense", "value": [15, 25]}]}]},
	{"enabler": {"name": "毒塗りの刃", "effects": [
		{"type": "on_hit", "chance": [25, 35], "apply": "poison"},
		{"type": "increased", "stat": "attack", "value": [5, 10]}]},
	"payoffs": [
		{"name": "弱みにつけこむ", "effects": [
			{"type": "increased", "stat": "attack", "value": [25, 40], "condition": "enemy_poisoned"},
			{"type": "increased", "stat": "speed", "value": [10, 15], "condition": "enemy_poisoned"}]},
		{"name": "致死の調合", "effects": [
			{"type": "increased", "stat": "crit_damage", "value": [30, 50], "condition": "enemy_poisoned"},
			{"type": "increased", "stat": "hp", "value": [10, 15]}]}]},
	{"enabler": {},
	"payoffs": [
		{"name": "背水の陣", "effects": [
			{"type": "more", "stat": "attack", "value": [25, 40], "condition": "low_hp"},
			{"type": "increased", "stat": "hp", "value": [10, 20]}]},
		{"name": "窮鼠", "effects": [
			{"type": "increased", "stat": "defense", "value": [40, 60], "condition": "low_hp"},
			{"type": "increased", "stat": "speed", "value": [15, 25], "condition": "low_hp"}]}]},
]
## 1つのツリーに入れるテーマの数 [最小, 最大]
var theme_count := [1, 2]


func generate(seed: int) -> SkillTree:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tree := SkillTree.new()
	var root := tree.add_node(-1, 0)
	for i in rng.randi_range(min_branches, max_branches):
		_grow(tree, rng, tree.add_node(root.id, 1))
	_assign_kinds(tree, rng)
	_assign_themes(tree, rng)
	RadialTreeLayout.new().apply(tree)
	return tree


func _grow(tree: SkillTree, rng: RandomNumberGenerator, node: SkillNode) -> void:
	if node.depth >= max_depth:
		return
	# 浅い階層で枝が途切れないよう、最初の数段は必ず1本以上伸ばす
	var min_children := 1 if node.depth < 3 else 0
	for i in rng.randi_range(min_children, max_children):
		_grow(tree, rng, tree.add_node(node.id, node.depth + 1))


func _assign_kinds(tree: SkillTree, rng: RandomNumberGenerator) -> void:
	var leaves: Array[SkillNode] = []
	for node in tree.nodes:
		if node.kind == "root":
			continue
		if tree.children_of(node.id).is_empty():
			leaves.append(node)
		elif node.depth >= 2 and rng.randf() < notable_chance_on_path:
			_make_notable(node, rng)
		else:
			_make_small(node, rng)

	# キーストーンはなるべく遠い末端に置く
	leaves.sort_custom(func(a: SkillNode, b: SkillNode): return a.depth > b.depth)
	var keystones := KEYSTONES.duplicate()
	_shuffle(keystones, rng)
	var count := mini(rng.randi_range(keystone_count[0], keystone_count[1]), leaves.size())
	for i in leaves.size():
		if i < count:
			_make_keystone(leaves[i], keystones[i])
		elif rng.randf() < notable_chance_at_leaf:
			_make_notable(leaves[i], rng)
		else:
			_make_small(leaves[i], rng)


## 既存のnotableの一部をテーマのノータブルに置き換える。足りなければ道中の小ノードをnotableに格上げする。
func _assign_themes(tree: SkillTree, rng: RandomNumberGenerator) -> void:
	var themes := THEMES.duplicate()
	_shuffle(themes, rng)
	var candidates := tree.nodes.filter(func(n: SkillNode): return n.kind == "notable")
	var promotable := tree.nodes.filter(func(n: SkillNode): return n.kind == "small" and n.depth >= 2)
	_shuffle(candidates, rng)
	_shuffle(promotable, rng)
	candidates.append_array(promotable)
	for theme in themes.slice(0, rng.randi_range(theme_count[0], theme_count[1])):
		var templates: Array = theme["payoffs"].duplicate()
		if not theme["enabler"].is_empty():
			templates.push_front(theme["enabler"])
		# 付与する側を置けないなら、活かす側も置かない
		if candidates.size() < templates.size():
			continue
		for template in templates:
			_make_themed_notable(candidates.pop_front(), template, rng)


func _make_themed_notable(node: SkillNode, template: Dictionary, rng: RandomNumberGenerator) -> void:
	node.kind = "notable"
	node.name = template["name"]
	node.effects.clear()
	for effect in template["effects"]:
		var rolled: Dictionary = effect.duplicate()
		for key in ["value", "chance"]:
			if rolled.has(key):
				rolled[key] = _roll(rolled[key], rng)
		node.effects.append(rolled)


func _make_small(node: SkillNode, rng: RandomNumberGenerator) -> void:
	node.kind = "small"
	if rng.randf() < 0.5:
		var stat: String = _pick(FLAT_RANGE.keys(), rng)
		node.effects.append({"type": "flat", "stat": stat, "value": _roll(FLAT_RANGE[stat], rng)})
	else:
		node.effects.append({"type": "increased", "stat": _pick(Stats.NAMES, rng), "value": _roll(SMALL_INCREASED_RANGE, rng)})


func _make_notable(node: SkillNode, rng: RandomNumberGenerator) -> void:
	node.kind = "notable"
	var stats := Stats.NAMES.duplicate()
	_shuffle(stats, rng)
	for stat in stats.slice(0, 2):
		node.effects.append({"type": "increased", "stat": stat, "value": _roll(NOTABLE_INCREASED_RANGE, rng)})


func _make_keystone(node: SkillNode, template: Dictionary) -> void:
	node.kind = "keystone"
	node.name = template["name"]
	for effect in template["effects"]:
		node.effects.append(effect.duplicate())


func _pick(items: Array, rng: RandomNumberGenerator) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]


func _roll(value_range: Array, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(value_range[0], value_range[1])


## Array.shuffle() はグローバルな乱数を使うため、シードを効かせるには自前で混ぜる。
func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
