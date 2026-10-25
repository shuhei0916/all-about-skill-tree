extends Control
## シード入力・ステータス表示・スキルツリーを並べたメイン画面。

const SKILL_POINTS := 15

var _generator := SkillTreeGenerator.new()
var _allocation: SkillAllocation

var _view: SkillTreeView
var _seed_edit: LineEdit
var _points_label: Label
var _stats_label: Label
var _hover_label: Label


func _ready() -> void:
	_build_ui()
	_randomize_seed()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("1b1d23")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	_view = SkillTreeView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.node_unlocked.connect(func(_node): _refresh_status())
	_view.node_hovered.connect(_on_node_hovered)
	layout.add_child(_view)

	var margin := MarginContainer.new()
	margin.custom_minimum_size.x = 260
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	layout.add_child(margin)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	margin.add_child(panel)

	panel.add_child(_make_label("シード"))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "数値または文字列"
	_seed_edit.text_submitted.connect(func(_text): _generate())
	panel.add_child(_seed_edit)

	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	buttons.add_child(_make_button("生成", _generate))
	buttons.add_child(_make_button("ランダム", _randomize_seed))
	buttons.add_child(_make_button("リセット", _generate))

	panel.add_child(HSeparator.new())
	_points_label = _make_label("")
	panel.add_child(_points_label)
	_stats_label = _make_label("")
	panel.add_child(_stats_label)

	panel.add_child(HSeparator.new())
	_hover_label = _make_label("")
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(_hover_label)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	return button


func _randomize_seed() -> void:
	_seed_edit.text = str(randi())
	_generate()


func _generate() -> void:
	var tree := _generator.generate(_seed_from_text(_seed_edit.text))
	_allocation = SkillAllocation.new(tree, SKILL_POINTS)
	_view.set_tree(tree, _allocation)
	_hover_label.text = "ノードにカーソルを合わせると効果を表示します。\n緑のノードをクリックで取得。"
	_refresh_status()


## 数値ならそのまま、それ以外の文字列はハッシュ値をシードにする。
func _seed_from_text(text: String) -> int:
	return text.to_int() if text.is_valid_int() else hash(text)


func _refresh_status() -> void:
	_points_label.text = "スキルポイント: %d / %d" % [_allocation.points, SKILL_POINTS]
	var stats := _allocation.stats()
	var lines: Array[String] = []
	for stat in Stats.NAMES:
		var bonus: int = stats[stat] - Stats.BASE[stat]
		var suffix := "  (+%d)" % bonus if bonus > 0 else ""
		lines.append("%s: %d%s" % [Stats.LABELS[stat], stats[stat], suffix])
	_stats_label.text = "\n".join(lines)


func _on_node_hovered(node: SkillNode) -> void:
	if node == null:
		return
	if node.parent_id == -1:
		_hover_label.text = "スタート地点"
		return
	var state := "取得済み" if _allocation.is_unlocked(node.id) \
		else "取得可能" if _allocation.can_unlock(node.id) else "未取得"
	_hover_label.text = "%s\n[%s]" % [Stats.describe(node.stat_bonuses), state]
