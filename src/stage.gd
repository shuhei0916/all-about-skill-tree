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
## このステージで得たEXPと倒した敵の数
var exp := 0
var kills := 0

var _effects: Array
var _on_hits: Array
var _rng := RandomNumberGenerator.new()
var _attack_gauge := 0.0


func _init(player_effects: Array, seed: int) -> void:
	_effects = player_effects
	_on_hits = player_effects.filter(func(e: Dictionary): return e["type"] == "on_hit")
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
		var stats := Stats.calculate(_effects, _context(target))
		var damage: float = stats["attack"]
		if _rng.randf() * 100.0 < stats["crit_chance"]:
			damage *= stats["crit_damage"] / 100.0
		target.hp -= _damage(damage, target.defense)
		for on_hit in _on_hits:
			if _rng.randf() * 100.0 < on_hit["chance"]:
				_apply_status(target, on_hit["apply"], stats)
		if target.hp <= 0.0:
			_defeat(target)


## 条件付き効果の判定に使う状況。敵の状態は、いま相手にしている敵で判定する。
func _context(enemy: StageEnemy) -> Dictionary:
	return {
		"enemy_blinded": enemy.statuses.has("blind"),
		"enemy_poisoned": enemy.statuses.has("poison"),
		"low_hp": player_hp <= player_max_hp * Battle.LOW_HP_RATIO,
	}


## 重ねがけすると持続時間が戻る。
func _apply_status(enemy: StageEnemy, status: String, stats: Dictionary) -> void:
	enemy.statuses[status] = Battle.STATUS_DURATION[status]
	if status == "poison":
		enemy.poison_dps = stats["attack"] * Battle.POISON_DAMAGE_RATIO


func _defeat(enemy: StageEnemy) -> void:
	enemies.erase(enemy)
	exp += enemy.exp
	kills += 1


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
	# 倒した敵はリストから消えるので、複製を回す
	for enemy in enemies.duplicate():
		if enemy.statuses.has("poison"):
			enemy.hp -= enemy.poison_dps * delta
			if enemy.hp <= 0.0:
				_defeat(enemy)
				continue
		for status in enemy.statuses.keys():
			enemy.statuses[status] -= delta
			if enemy.statuses[status] <= 0.0:
				enemy.statuses.erase(status)
		enemy.position = enemy.position.move_toward(player_position, enemy.move_speed * delta)
		enemy.contact_cooldown = maxf(enemy.contact_cooldown - delta, 0.0)
		if enemy.contact_cooldown <= 0.0 and _touches_player(enemy):
			enemy.contact_cooldown = CONTACT_COOLDOWN
			if enemy.statuses.has("blind") and _rng.randf() < Battle.BLIND_MISS_CHANCE:
				continue
			player_hp -= _damage(enemy.attack, Stats.calculate(_effects, _context(enemy))["defense"])


func _touches_player(enemy: StageEnemy) -> bool:
	return enemy.position.distance_to(player_position) <= PLAYER_RADIUS + enemy.radius


func _damage(attack: float, target_defense: float) -> float:
	return attack * 100.0 / (100.0 + target_defense)
