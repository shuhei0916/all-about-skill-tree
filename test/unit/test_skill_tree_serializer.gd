extends GutTest

var serializer: SkillTreeSerializer


func before_each():
	serializer = SkillTreeSerializer.new()


# root(0) ─ a(1) ─ b(2)
func _make_tree() -> SkillTree:
	var tree := SkillTree.new()
	var root := tree.add_node(-1, 0)
	var a := tree.add_node(root.id, 1)
	a.effects = [{"type": "flat", "stat": "attack", "value": 3}]
	var b := tree.add_node(a.id, 2)
	b.effects = [{"type": "flat", "stat": "hp", "value": 20}, {"type": "flat", "stat": "speed", "value": 1}]
	return tree


func test_ツリーを辞書に変換すると各ノードのid・親・補正が含まれる():
	var data := serializer.to_dict(_make_tree())

	assert_eq(data["version"], 1)
	assert_eq(data["nodes"], [
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"attack": 3}},
		{"id": 2, "parent": 1, "bonuses": {"hp": 20, "speed": 1}},
	])


func test_辞書から読み込んだツリーは元のツリーと同じ構造と補正を持つ():
	var original := _make_tree()

	var loaded := serializer.from_dict(serializer.to_dict(original))

	assert_eq(serializer.to_dict(loaded), serializer.to_dict(original))


func test_読み込み時に深さと座標が計算される():
	var loaded := serializer.from_dict(serializer.to_dict(_make_tree()))

	assert_eq(loaded.nodes.map(func(n: SkillNode): return n.depth), [0, 1, 2])
	assert_eq(loaded.root().position, Vector2.ZERO)
	assert_gt(loaded.get_node(2).position.length(), loaded.get_node(1).position.length())


func test_IDが連番でなく親が子より後に書かれていても読み込める():
	var data := {"version": 1, "nodes": [
		{"id": 70, "parent": 30, "bonuses": {"hp": 10}},
		{"id": 30, "parent": 5, "bonuses": {"attack": 1}},
		{"id": 5, "parent": -1, "bonuses": {}},
	]}

	var loaded := serializer.from_dict(data)

	# ルートが0番、それ以外はファイルに書かれた順（70→1, 30→2）
	assert_eq(serializer.to_dict(loaded)["nodes"], [
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 2, "bonuses": {"hp": 10}},
		{"id": 2, "parent": 0, "bonuses": {"attack": 1}},
	])
	assert_eq(loaded.nodes.map(func(n: SkillNode): return n.depth), [0, 2, 1])


func test_JSON由来の小数は整数として扱う():
	var data: Dictionary = JSON.parse_string(
		'{"version": 1, "nodes": [{"id": 0, "parent": -1, "bonuses": {}}, {"id": 1, "parent": 0, "bonuses": {"attack": 3}}]}')

	var loaded := serializer.from_dict(data)

	assert_typeof(loaded.get_node(1).effects[0]["value"], TYPE_INT)


func _assert_rejected(nodes: Array, expected_message: String) -> void:
	var loaded := serializer.from_dict({"version": 1, "nodes": nodes})

	assert_null(loaded)
	assert_string_contains(" / ".join(serializer.errors), expected_message)


func test_ルートがない場合はエラーになる():
	_assert_rejected([{"id": 1, "parent": 2, "bonuses": {}}], "ルート")


func test_ルートが複数ある場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": -1, "bonuses": {}},
	], "ルート")


func test_存在しない親を指すノードがある場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 99, "bonuses": {"hp": 10}},
	], "99")


func test_ルートから辿れないノードがある場合はエラーになる():
	# 1と2が互いを親にしていて、ルートにつながらない
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 2, "bonuses": {"hp": 10}},
		{"id": 2, "parent": 1, "bonuses": {"hp": 10}},
	], "辿れない")


func test_IDが重複している場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"hp": 10}},
		{"id": 1, "parent": 0, "bonuses": {"hp": 10}},
	], "重複")


func test_必須項目がないノードがある場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "bonuses": {"hp": 10}},
	], "parent")


func test_エラーがなければerrorsは空になる():
	serializer.from_dict({"version": 1, "nodes": [{"id": 1, "parent": 2, "bonuses": {}}]})

	serializer.from_dict(serializer.to_dict(_make_tree()))

	assert_eq(serializer.errors, [])


func test_未知のステータスの補正はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"magic": 10}},
	], "magic")


func test_正でない補正値はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"hp": 0}},
	], "hp")


func test_整数でない補正値はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"attack": 2.5}},
	], "attack")


func test_bonusesがオブジェクトでない場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": "attack+3"},
	], "bonuses")


func test_idが整数でない場合はエラーになる():
	_assert_rejected([
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": "fire", "parent": 0, "bonuses": {"hp": 10}},
	], "id")


func test_idとparentで整数と小数が混在していても読み込める():
	var loaded := serializer.from_dict({"version": 1, "nodes": [
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0.0, "bonuses": {"hp": 10}},
	]})

	assert_not_null(loaded, " / ".join(serializer.errors))


func test_ファイルに保存して読み込むと同じツリーに戻る():
	var path := "user://test_skill_tree.json"
	var original := _make_tree()

	assert_eq(serializer.save(original, path), OK)
	var loaded := serializer.load_file(path)
	DirAccess.remove_absolute(path)

	assert_eq(serializer.to_dict(loaded), serializer.to_dict(original))


func test_存在しないファイルを読み込むとエラーになる():
	assert_null(serializer.load_file("user://does_not_exist.json"))
	assert_false(serializer.errors.is_empty())


func test_不正なJSON文字列はエラーになる():
	assert_null(serializer.from_json("{nodes: [}"))
	assert_string_contains(" / ".join(serializer.errors), "JSON")


func test_JSONの最上位がオブジェクトでない場合はエラーになる():
	assert_null(serializer.from_json("[1, 2, 3]"))
	assert_false(serializer.errors.is_empty())


func test_生成したツリーを保存して読み込むとIDも含めて元に戻る():
	var original := SkillTreeGenerator.new().generate(777)

	var loaded := serializer.from_json(serializer.to_json(original))

	assert_eq(serializer.to_dict(loaded), serializer.to_dict(original))
