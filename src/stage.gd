class_name Stage
extends RefCounted
## 移動操作型の対CPU戦1ステージ分のロジック。描画からは切り離し、step で時間を進める。
## ダメージ = 攻撃力 × (会心なら会心ダメージ%) × 100 / (100 + 相手の防御力)（Battle と同じ）

const ARENA_SIZE := Vector2(1200, 800)
## プレイヤーの移動速度（ピクセル/秒）
const PLAYER_MOVE_SPEED := 200.0
const PLAYER_RADIUS := 16.0
const ATTACK_RANGE := 300.0
## 攻撃ゲージがこの値まで溜まると1回攻撃する。素早さ10なら1秒に1回（Battle と同じ）
const ACTION_GAUGE := 100.0
## 敵が一度接触ダメージを与えてから、次に与えられるようになるまでの秒数
const CONTACT_COOLDOWN := 1.0

var player_position := ARENA_SIZE / 2.0
var player_hp: float
var player_max_hp: float
var enemies: Array[StageEnemy] = []

var _effects: Array
var _rng := RandomNumberGenerator.new()
var _attack_gauge := 0.0


func _init(player_effects: Array, seed: int) -> void:
	_effects = player_effects
	_rng.seed = seed
	player_max_hp = Stats.calculate(_effects)["hp"]
	player_hp = player_max_hp


func spawn_enemy(position: Vector2) -> StageEnemy:
	var enemy := StageEnemy.new(position)
	enemies.append(enemy)
	return enemy


## delta 秒だけ時間を進める。move はプレイヤーの移動方向。
func step(delta: float, move: Vector2) -> void:
	player_position += move.limit_length(1.0) * PLAYER_MOVE_SPEED * delta
	player_position = player_position.clamp(Vector2.ONE * PLAYER_RADIUS, ARENA_SIZE - Vector2.ONE * PLAYER_RADIUS)
	_player_attack(delta)
	_enemies_act(delta)


func _player_attack(delta: float) -> void:
	_attack_gauge += Stats.calculate(_effects)["speed"] * 10.0 * delta
	while _attack_gauge >= ACTION_GAUGE:
		var target := _nearest_enemy_in_range()
		if target == null:
			# 敵が来るまで次の1回分の準備を持ち越す
			_attack_gauge = ACTION_GAUGE
			return
		_attack_gauge -= ACTION_GAUGE
		var stats := Stats.calculate(_effects)
		var damage: float = stats["attack"]
		if _rng.randf() * 100.0 < stats["crit_chance"]:
			damage *= stats["crit_damage"] / 100.0
		target.hp -= _damage(damage, target.defense)


func _nearest_enemy_in_range() -> StageEnemy:
	var nearest: StageEnemy = null
	var nearest_distance := ATTACK_RANGE
	for enemy in enemies:
		var distance := enemy.position.distance_to(player_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _enemies_act(delta: float) -> void:
	var stats := Stats.calculate(_effects)
	for enemy in enemies:
		enemy.position = enemy.position.move_toward(player_position, enemy.move_speed * delta)
		enemy.contact_cooldown = maxf(enemy.contact_cooldown - delta, 0.0)
		if enemy.contact_cooldown <= 0.0 and _touches_player(enemy):
			player_hp -= _damage(enemy.attack, stats["defense"])
			enemy.contact_cooldown = CONTACT_COOLDOWN


func _touches_player(enemy: StageEnemy) -> bool:
	return enemy.position.distance_to(player_position) <= PLAYER_RADIUS + enemy.radius


func _damage(attack: float, target_defense: float) -> float:
	return attack * 100.0 / (100.0 + target_defense)
