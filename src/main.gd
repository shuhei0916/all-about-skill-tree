extends Control
## シード入力・ステータス表示・スキルツリーを並べたメイン画面。

const SKILL_POINTS := 15
const TREES_DIR := "user://trees"
const KIND_LABELS := {"small": "小ノード", "notable": "ノータブル", "keystone": "キーストーン"}
## 戦闘シミュレーションを何回繰り返して平均をとるか
const BATTLE_RUNS := 20

var _generator := SkillTreeGenerator.new()
var _serializer := SkillTreeSerializer.new()
var _allocation: SkillAllocation
var _battle_summary := {}

var _view: SkillTreeView
var _seed_edit: LineEdit
var _points_label: Label
var _stats_label: Label
var _hover_label: Label
var _save_dialog: FileDialog
var _open_dialog: FileDialog


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
	margin.custom_minimum_size.x = 300
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	layout.add_child(margin)

	# ノードの説明が長くなってもはみ出さないよう、パネルはスクロールできるようにする
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)

	panel.add_child(_make_label("シード"))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "数値または文字列"
	_seed_edit.text_submitted.connect(func(_text): _generate())
	panel.add_child(_seed_edit)

	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	buttons.add_child(_make_button("生成", _generate))
	buttons.add_child(_make_button("ランダム", _randomize_seed))
	buttons.add_child(_make_button("リセット", _reset))

	var file_buttons := HBoxContainer.new()
	panel.add_child(file_buttons)
	file_buttons.add_child(_make_button("保存", func(): _save_dialog.popup_centered_ratio(0.6)))
	file_buttons.add_child(_make_button("読み込み", func(): _open_dialog.popup_centered_ratio(0.6)))

	panel.add_child(HSeparator.new())
	_points_label = _make_label("")
	panel.add_child(_points_label)
	_stats_label = _make_label("")
	panel.add_child(_stats_label)

	panel.add_child(HSeparator.new())
	_hover_label = _make_label("")
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(_hover_label)

	_save_dialog = _make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	_save_dialog.file_selected.connect(_save_tree)
	_open_dialog = _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	_open_dialog.file_selected.connect(_load_tree)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	return button


func _make_file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; スキルツリー"])
	DirAccess.make_dir_recursive_absolute(TREES_DIR)
	dialog.current_dir = ProjectSettings.globalize_path(TREES_DIR)
	add_child(dialog)
	return dialog


func _randomize_seed() -> void:
	_seed_edit.text = str(randi())
	_generate()


func _generate() -> void:
	_show_tree(_generator.generate(_seed_from_text(_seed_edit.text)))


## 取得状況だけを初期化し、表示中のツリーはそのまま使う。
func _reset() -> void:
	_show_tree(_allocation.tree)


func _show_tree(tree: SkillTree) -> void:
	_allocation = SkillAllocation.new(tree, SKILL_POINTS)
	_view.set_tree(tree, _allocation)
	_hover_label.text = "ノードにカーソルを合わせると効果を表示します。\n緑のノードをクリックで取得。"
	_refresh_status()


func _save_tree(path: String) -> void:
	var error := _serializer.save(_allocation.tree, path)
	_hover_label.text = "保存しました: %s" % path if error == OK \
		else "保存に失敗しました: %s" % error_string(error)


func _load_tree(path: String) -> void:
	var tree := _serializer.load_file(path)
	if tree == null:
		_hover_label.text = "読み込みに失敗しました:\n" + "\n".join(_serializer.errors)
		return
	_seed_edit.text = ""
	_seed_edit.placeholder_text = path.get_file()
	_show_tree(tree)


## 数値ならそのまま、それ以外の文字列はハッシュ値をシードにする。
func _seed_from_text(text: String) -> int:
	return text.to_int() if text.is_valid_int() else hash(text)


func _refresh_status() -> void:
	_points_label.text = "スキルポイント: %d / %d" % [_allocation.points, SKILL_POINTS]
	var stats := _allocation.stats()
	var base := Stats.calculate([])
	_battle_summary = Battle.evaluate(_allocation.unlocked_effects(), Battle.STANDARD_ENEMY, BATTLE_RUNS)
	var lines: Array[String] = [
		"基準の敵と%d回戦った結果" % BATTLE_RUNS,
		"  勝率 %s ／ DPS %s" % [_format_win_rate(_battle_summary), _format_dps(_battle_summary)],
		"  撃破時間 %s ／ 残りHP %s" % [_format_win_time(_battle_summary), _format_hp_left(_battle_summary)],
	]
	for stat in Stats.NAMES:
		var diff := roundi(stats[stat]) - roundi(base[stat])
		var suffix := "  (%+d)" % diff if diff != 0 else ""
		lines.append("%s: %s%s" % [Stats.LABELS[stat], _format_stat(stat, stats[stat]), suffix])
	_stats_label.text = "\n".join(lines)


func _format_stat(stat: String, value: float) -> String:
	return "%d%%" % roundi(value) if Stats.PERCENT_STATS.has(stat) else str(roundi(value))


func _format_win_rate(summary: Dictionary) -> String:
	return "%d%%" % roundi(summary["win_rate"] * 100.0)


func _format_dps(summary: Dictionary) -> String:
	return "%.1f" % summary["dps"]


func _format_win_time(summary: Dictionary) -> String:
	return "-" if is_inf(summary["avg_win_time"]) else "%.1f秒" % summary["avg_win_time"]


func _format_hp_left(summary: Dictionary) -> String:
	return "%d%%" % roundi(summary["hp_left_ratio"] * 100.0)


func _on_node_hovered(node: SkillNode) -> void:
	if node == null:
		return
	if node.kind == "root":
		_hover_label.text = "スタート地点"
		return
	var title: String = node.name if node.name != "" else KIND_LABELS[node.kind]
	var lines: Array[String] = ["【%s】" % title, Stats.describe(node.effects)]
	if _allocation.is_unlocked(node.id):
		lines.append("取得済み")
	else:
		# 取得した場合に戦闘結果がどう変わるかを見せ、トレードオフを判断しやすくする
		var after := Battle.evaluate(_allocation.unlocked_effects() + node.effects, Battle.STANDARD_ENEMY, BATTLE_RUNS)
		lines.append("取得すると 勝率 %s → %s" % [_format_win_rate(_battle_summary), _format_win_rate(after)])
		lines.append("  DPS %s → %s ／ 残りHP %s → %s" % [
			_format_dps(_battle_summary), _format_dps(after), _format_hp_left(_battle_summary), _format_hp_left(after)])
		if not _allocation.can_unlock(node.id):
			lines.append("（まだ取得できません）")
	_hover_label.text = "\n".join(lines)
