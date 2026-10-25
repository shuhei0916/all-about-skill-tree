class_name StageView
extends Control
## ステージを描画し、WASD／矢印キーの入力でプレイヤーを動かす。
## アリーナは表示領域に収まるよう拡大縮小して中央に描く。

signal finished(stage: Stage)

const MARGIN := 24.0
const COLOR_ARENA := Color("262932")
const COLOR_ARENA_BORDER := Color("4a4f5c")
const COLOR_PLAYER := Color("f2c14e")
const COLOR_RANGE := Color(1, 1, 1, 0.06)
const COLOR_ENEMY := Color("e05a5a")
const COLOR_BLIND := Color("8a8fa0")
const COLOR_POISON := Color("7bd36a")
const COLOR_HP_BACK := Color("33373f")
const COLOR_HP := Color("8fd694")
const COLOR_TEXT := Color.WHITE

var stage: Stage


func start(p_stage: Stage) -> void:
	stage = p_stage
	queue_redraw()


func _physics_process(delta: float) -> void:
	if stage == null or stage.state != Stage.State.PLAYING:
		return
	stage.step(delta, _input_direction())
	queue_redraw()
	if stage.state != Stage.State.PLAYING:
		finished.emit(stage)


## 入力マップを増やさずに済むよう、キーを直接見る。
func _input_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1
	return direction


func _view_scale() -> float:
	var available := size - Vector2.ONE * MARGIN * 2.0
	return maxf(minf(available.x / Stage.ARENA_SIZE.x, available.y / Stage.ARENA_SIZE.y), 0.01)


func to_screen(arena_pos: Vector2) -> Vector2:
	var arena_on_screen := Stage.ARENA_SIZE * _view_scale()
	return (size - arena_on_screen) / 2.0 + arena_pos * _view_scale()


func _draw() -> void:
	if stage == null:
		return
	var view_scale := _view_scale()
	var arena := Rect2(to_screen(Vector2.ZERO), Stage.ARENA_SIZE * view_scale)
	draw_rect(arena, COLOR_ARENA)
	draw_rect(arena, COLOR_ARENA_BORDER, false, 2.0)

	var player := to_screen(stage.player_position)
	draw_circle(player, Stage.ATTACK_RANGE * view_scale, COLOR_RANGE)
	draw_circle(player, Stage.PLAYER_RADIUS * view_scale, COLOR_PLAYER)

	for enemy in stage.enemies:
		_draw_enemy(enemy, view_scale)
	_draw_hud()


func _draw_enemy(enemy: StageEnemy, view_scale: float) -> void:
	var center := to_screen(enemy.position)
	var radius := enemy.radius * view_scale
	var color := COLOR_ENEMY
	if enemy.statuses.has("blind"):
		color = color.lerp(COLOR_BLIND, 0.6)
	draw_circle(center, radius, color)
	if enemy.statuses.has("poison"):
		draw_arc(center, radius + 2.0, 0.0, TAU, 24, COLOR_POISON, 2.0)
	if enemy.hp < enemy.max_hp:
		_draw_bar(center + Vector2(-radius, -radius - 6.0), radius * 2.0, enemy.hp / enemy.max_hp)


func _draw_bar(top_left: Vector2, width: float, ratio: float) -> void:
	draw_rect(Rect2(top_left, Vector2(width, 4.0)), COLOR_HP_BACK)
	draw_rect(Rect2(top_left, Vector2(width * clampf(ratio, 0.0, 1.0), 4.0)), COLOR_HP)


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var top_left := to_screen(Vector2.ZERO) + Vector2(12, 24)
	var text := "ステージ %d    残り %d秒    撃破 %d    EXP %d" % [
		stage.number, ceili(stage.duration - stage.time), stage.kills, stage.exp]
	draw_string(font, top_left, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)
	draw_string(font, top_left + Vector2(0, 26), "HP %d / %d" % [ceili(stage.player_hp), roundi(stage.player_max_hp)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)
	_draw_bar(top_left + Vector2(0, 34), 200.0, stage.player_hp / stage.player_max_hp)
