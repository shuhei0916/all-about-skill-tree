class_name SkillTreeSerializer
extends RefCounted
## スキルツリーとJSON互換の辞書を相互に変換する。
## 保存するのは構造と効果だけで、深さと座標は読み込み時に計算する。

const VERSION := 1
const REQUIRED_KEYS := ["id", "parent", "bonuses"]

## 直前の読み込みで見つかった問題。AIに修正を依頼するときにもそのまま渡せる文言にする。
var errors: Array[String] = []


func to_dict(tree: SkillTree) -> Dictionary:
	var nodes := []
	for node in tree.nodes:
		nodes.append({"id": node.id, "parent": node.parent_id, "bonuses": _bonuses_of(node)})
	return {"version": VERSION, "nodes": nodes}


func _bonuses_of(node: SkillNode) -> Dictionary:
	var bonuses := {}
	for effect in node.effects:
		bonuses[effect["stat"]] = effect["value"]
	return bonuses


func to_json(tree: SkillTree) -> String:
	return JSON.stringify(to_dict(tree), "	")


func from_json(text: String) -> SkillTree:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.assign(["JSONとして読めません（%d行目: %s）" % [json.get_error_line(), json.get_error_message()]])
		return null
	if not json.data is Dictionary:
		errors.assign(["JSONの最上位はオブジェクトにしてください"])
		return null
	return from_dict(json.data)


func save(tree: SkillTree, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json(tree))
	return OK


func load_file(path: String) -> SkillTree:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.assign(["ファイルを開けません: %s（%s）" % [path, error_string(FileAccess.get_open_error())]])
		return null
	return from_json(file.get_as_text())


## 読み込みに失敗した場合は null を返し、理由を errors に入れる。
func from_dict(data: Dictionary) -> SkillTree:
	errors.clear()
	var entries := _validate_entries(data)
	if not errors.is_empty():
		return null

	var root_entry := _find_root(entries)
	_validate_parents(entries)
	if not errors.is_empty():
		return null

	var tree := _build(entries, root_entry)
	if _assign_depths(tree) < tree.nodes.size():
		errors.append("ルートから辿れないノードがあります（親子関係が循環していないか確認してください）")
		return null
	RadialTreeLayout.new().apply(tree)
	return tree


func _validate_entries(data: Dictionary) -> Array:
	if not data.get("nodes") is Array:
		errors.append("nodes が配列ではありません")
		return []
	var entries := []
	var seen_ids := {}
	for i in data["nodes"].size():
		var entry = data["nodes"][i]
		if not _validate_entry(i, entry):
			continue
		# 辞書のキーとして 1 と 1.0 は別物なので、IDは整数にそろえる
		var normalized := {"id": int(entry["id"]), "parent": int(entry["parent"]), "bonuses": entry["bonuses"]}
		if seen_ids.has(normalized["id"]):
			errors.append("ID %d が重複しています" % normalized["id"])
		seen_ids[normalized["id"]] = true
		entries.append(normalized)
	return entries


## 1ノード分の記述を検証し、問題がなければ true を返す。
func _validate_entry(index: int, entry: Variant) -> bool:
	if not entry is Dictionary:
		errors.append("nodes[%d] がオブジェクトではありません" % index)
		return false
	var error_count := errors.size()
	for key in REQUIRED_KEYS:
		if not entry.has(key):
			errors.append("nodes[%d] に %s がありません" % [index, key])
	for key in ["id", "parent"]:
		if entry.has(key) and not _is_integer(entry[key]):
			errors.append("nodes[%d] の %s が整数ではありません: %s" % [index, key, entry[key]])
	if entry.has("bonuses"):
		_validate_bonuses(index, entry["bonuses"])
	return errors.size() == error_count


func _validate_bonuses(index: int, bonuses: Variant) -> void:
	if not bonuses is Dictionary:
		errors.append("nodes[%d] の bonuses がオブジェクトではありません" % index)
		return
	for stat in bonuses:
		if not Stats.NAMES.has(stat):
			errors.append("nodes[%d] の %s は未知のステータスです（使えるのは %s）" % [index, stat, ", ".join(Stats.NAMES)])
		elif not _is_integer(bonuses[stat]) or bonuses[stat] <= 0:
			errors.append("nodes[%d] の %s の補正値は正の整数にしてください: %s" % [index, stat, bonuses[stat]])


## JSONの数値は小数として読まれるため、小数部がなければ整数とみなす。
func _is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and value == floorf(value)


func _find_root(entries: Array) -> Dictionary:
	var roots := entries.filter(func(e: Dictionary): return e["parent"] == -1)
	if roots.size() != 1:
		errors.append("ルート（parent が -1 のノード）はちょうど1つ必要です（現在%d個）" % roots.size())
		return {}
	return roots[0]


func _validate_parents(entries: Array) -> void:
	var ids := entries.map(func(e: Dictionary): return e["id"])
	for entry in entries:
		if entry["parent"] != -1 and not ids.has(entry["parent"]):
			errors.append("ノード %d の親 %d が存在しません" % [entry["id"], entry["parent"]])


## 内部のIDは、ルートを0番、それ以外をファイルに書かれた順に振り直す。
## 生成したツリーは元からこの順で並んでいるため、保存して読み込むと同じIDに戻る。
func _build(entries: Array, root_entry: Dictionary) -> SkillTree:
	var ordered := [root_entry]
	ordered.append_array(entries.filter(func(e: Dictionary): return e != root_entry))
	var new_ids := {-1: -1}
	for i in ordered.size():
		new_ids[ordered[i]["id"]] = i

	var tree := SkillTree.new()
	for entry in ordered:
		var node := tree.add_node(new_ids[entry["parent"]], 0)
		for stat in entry["bonuses"]:
			node.effects.append({"type": "flat", "stat": stat, "value": int(entry["bonuses"][stat])})
	return tree


## ルートから幅優先で辿って深さを決め、辿り着けたノードの数を返す。
func _assign_depths(tree: SkillTree) -> int:
	var queue: Array[SkillNode] = [tree.root()]
	var reached := 0
	while not queue.is_empty():
		var node: SkillNode = queue.pop_front()
		reached += 1
		for child in tree.children_of(node.id):
			child.depth = node.depth + 1
			queue.append(child)
	return reached
