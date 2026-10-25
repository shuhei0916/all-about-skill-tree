extends GutTest

var serializer: SkillTreeSerializer


func before_each():
	serializer = SkillTreeSerializer.new()


# root(0) ─ a(1) ─ b(2)
func _make_tree() -> SkillTree:
	var tree := SkillTree.new()
	var root := tree.add_node(-1, 0)
	var a := tree.add_node(root.id, 1)
	a.effects = [_flat("attack", 3)]
	var b := tree.add_node(a.id, 2)
	b.kind = "keystone"
	b.name = "ガラスの大砲"
	b.effects = [_more("attack", 80), _more("hp", -50)]
	return tree


func _flat(stat: String, value: int) -> Dictionary:
	return {"type": "flat", "stat": stat, "value": value}


func _more(stat: String, value: int) -> Dictionary:
	return {"type": "more", "stat": stat, "value": value}


func _root_entry() -> Dictionary:
	return {"id": 0, "parent": -1, "kind": "root", "effects": []}


func _entry(id: Variant, parent: Variant, effects: Variant = [_flat("hp", 10)], kind: Variant = "small") -> Dictionary:
	return {"id": id, "parent": parent, "kind": kind, "effects": effects}


func test_ツリーを辞書に変換すると各ノードのid・親・種類・名前・効果が含まれる():
	var data := serializer.to_dict(_make_tree())

	assert_eq(data["version"], 2)
	assert_eq(data["nodes"], [
		{"id": 0, "parent": -1, "kind": "root", "effects": []},
		{"id": 1, "parent": 0, "kind": "small", "effects": [_flat("attack", 3)]},
		{"id": 2, "parent": 1, "kind": "keystone", "name": "ガラスの大砲", "effects": [_more("attack", 80), _more("hp", -50)]},
	])


func test_辞書から読み込んだツリーは元のツリーと同じ構造と効果を持つ():
	var original := _make_tree()

	var loaded := serializer.from_dict(serializer.to_dict(original))

	assert_eq(serializer.to_dict(loaded), serializer.to_dict(original))


func test_読み込み時に深さと座標が計算される():
	var loaded := serializer.from_dict(serializer.to_dict(_make_tree()))

	assert_eq(loaded.nodes.map(func(n: SkillNode): return n.depth), [0, 1, 2])
	assert_eq(loaded.root().position, Vector2.ZERO)
	assert_gt(loaded.get_node(2).position.length(), loaded.get_node(1).position.length())


func test_IDが連番でなく親が子より後に書かれていても読み込める():
	var data := {"version": 2, "nodes": [
		_entry(70, 30, [_flat("hp", 10)]),
		_entry(30, 5, [_flat("attack", 1)]),
		{"id": 5, "parent": -1, "kind": "root", "effects": []},
	]}

	var loaded := serializer.from_dict(data)

	# ルートが0番、それ以外はファイルに書かれた順（70→1, 30→2）
	assert_eq(loaded.nodes.map(func(n: SkillNode): return n.parent_id), [-1, 2, 0])
	assert_eq(loaded.nodes.map(func(n: SkillNode): return n.depth), [0, 2, 1])


func test_JSON由来の小数は整数として扱う():
	var data: Dictionary = JSON.parse_string(JSON.stringify(serializer.to_dict(_make_tree())))

	var loaded := serializer.from_dict(data)

	assert_typeof(loaded.get_node(1).effects[0]["value"], TYPE_INT)


func test_idとparentで整数と小数が混在していても読み込める():
	var loaded := serializer.from_dict({"version": 2, "nodes": [_root_entry(), _entry(1, 0.0)]})

	assert_not_null(loaded, " / ".join(serializer.errors))


func _assert_rejected(nodes: Array, expected_message: String) -> void:
	var loaded := serializer.from_dict({"version": 2, "nodes": nodes})

	assert_null(loaded)
	assert_string_contains(" / ".join(serializer.errors), expected_message)


func test_ルートがない場合はエラーになる():
	_assert_rejected([_entry(1, 2)], "ルート")


func test_ルートが複数ある場合はエラーになる():
	_assert_rejected([_root_entry(), {"id": 1, "parent": -1, "kind": "root", "effects": []}], "ルート")


func test_存在しない親を指すノードがある場合はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 99)], "99")


func test_ルートから辿れないノードがある場合はエラーになる():
	# 1と2が互いを親にしていて、ルートにつながらない
	_assert_rejected([_root_entry(), _entry(1, 2), _entry(2, 1)], "辿れない")


func test_IDが重複している場合はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0), _entry(1, 0)], "重複")


func test_必須項目がないノードがある場合はエラーになる():
	_assert_rejected([_root_entry(), {"id": 1, "kind": "small", "effects": []}], "parent")


func test_idが整数でない場合はエラーになる():
	_assert_rejected([_root_entry(), _entry("fire", 0)], "id")


func test_エラーがなければerrorsは空になる():
	serializer.from_dict({"version": 2, "nodes": [_entry(1, 2)]})

	serializer.from_dict(serializer.to_dict(_make_tree()))

	assert_eq(serializer.errors, [])


func test_未知の種類はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [_flat("hp", 10)], "legendary")], "legendary")


func test_effectsが配列でない場合はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, "attack+3")], "effects")


func test_未知の効果の型はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [{"type": "double", "stat": "hp", "value": 2}])], "double")


func test_未知のステータスはエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [_flat("magic", 10)])], "magic")


func test_整数でない効果の値はエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [{"type": "flat", "stat": "attack", "value": 2.5}])], "attack")


func test_flatとincreasedは正の値でなければエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [{"type": "increased", "stat": "hp", "value": -10}])], "hp")


func test_moreは0やマイナス100以下だとエラーになる():
	_assert_rejected([_root_entry(), _entry(1, 0, [_more("speed", 0)])], "speed")
	_assert_rejected([_root_entry(), _entry(1, 0, [_more("speed", -100)])], "speed")


func test_旧形式のbonusesはflat効果として読み込める():
	var loaded := serializer.from_dict({"version": 1, "nodes": [
		{"id": 0, "parent": -1, "bonuses": {}},
		{"id": 1, "parent": 0, "bonuses": {"attack": 3, "hp": 20}},
	]})

	assert_not_null(loaded, " / ".join(serializer.errors))
	assert_eq(loaded.get_node(1).kind, "small")
	assert_eq(loaded.get_node(1).effects, [_flat("attack", 3), _flat("hp", 20)])


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
