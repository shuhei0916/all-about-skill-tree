class_name Stage
extends RefCounted
## 移動操作型の対CPU戦1ステージ分のロジック。描画からは切り離し、step で時間を進める。
## ダメージ = 攻撃力 × (会心なら会心ダメージ%) × 100 / (100 + 相手の防御力)（Battle と同じ）

enum State { PLAYING, CLEARED, FAILED }

const ARENA_SIZE := Vector2(1200, 800)
## プレイヤーの移動速度（ピクセル/秒）
const PLAYER_MOVE_SPEED := 200.0
const PLAYER_RADIUS := 16.0
const ATTACK_RANGE := 300.0
## 弾の速さ（ピクセル/秒）と当たり判定の半径。弾は射程のこの倍率まで飛ぶと消える
const PROJECTILE_SPEED := 600.0
const PROJECTILE_RADIUS := 4.0
const PROJECTILE_RANGE_RATIO := 1.5
## 攻撃ゲージがこの値まで溜まると1回攻撃する。素早さ10なら1秒に1回（Battle と同じ）
const ACTION_GAUGE := 100.0
## 敵が一度接触ダメージを与えてから、次に与えられるようになるまでの秒数
const CONTACT_COOLDOWN := 1.0
## 敵が湧く間隔（秒）。ステージの始めから終わりにかけて短くなる。
## 逃げ回るだけの自動操縦でノードをランダムに振ると、5〜8ステージ以上もつ程度にしてある（2026-10-25 に調整）
const SPAWN_INTERVAL_START := 3.0
const SPAWN_INTERVAL_END := 1.2
## ステージが1つ進むごとに、敵のHPと攻撃力がこの割合だけ増える（1ステージ目が基準）
const HP_GROWTH := 0.3
const ATTACK_GROWTH := 0.25

## 何ステージ目か。1から始まる
var number: int
var state := State.PLAYING
var duration := 60.0
var time := 0.0
## false にすると敵が自動では湧かない（テスト用）
var spawning := true
var player_position := ARENA_SIZE / 2.0
var player_hp: float
var player_max_hp: float
var enemies: Array[StageEnemy] = []
var projectiles: Array[StageProjectile] = []
## このステージで得たEXPと倒した敵の数
var exp := 0
var kills := 0

var _effects: Array
var _on_hits: Array
var _rng := RandomNumberGenerator.new()
var _attack_gauge := 0.0
var _spawn_timer := 0.0


func _init(player_effects: Array, seed: int, p_number := 1) -> void:
	number = p_number
	_effects = player_effects
	_on_hits = player_effects.filter(func(e: Dictionary): return e["type"] == "on_hit")
	_rng.seed = seed
	player_max_hp = Stats.calculate(_effects)["hp"]
	player_hp = player_max_hp


func spawn_enemy(position: Vector2) -> StageEnemy:
	var enemy := StageEnemy.new(position)
	enemy.max_hp *= 1.0 + HP_GROWTH * (number - 1)
	enemy.hp = enemy.max_hp
	enemy.attack *= 1.0 + ATTACK_GROWTH * (number - 1)
	# 後のステージほど倒せる数が減るので、1体あたりのEXPを増やしてレベルアップの頻度を保つ
	enemy.exp = number
	enemies.append(enemy)
	return enemy


## delta 秒だけ時間を進める。move はプレイヤーの移動方向。
func step(delta: float, move: Vector2) -> void:
	if state != State.PLAYING:
		return
	time += delta
	player_position += move.limit_length(1.0) * PLAYER_MOVE_SPEED * delta
	player_position = player_position.clamp(Vector2.ONE * PLAYER_RADIUS, ARENA_SIZE - Vector2.ONE * PLAYER_RADIUS)
	_player_attack(delta)
	_move_projectiles(delta)
	_enemies_act(delta)
	if state == State.FAILED:
		return
	# 0.1 を足し続けたときの誤差で1回分ずれないよう、わずかな差は到達とみなす
	if time >= duration - 0.0001:
		time = duration
		state = State.CLEARED
		return
	if spawning:
		_spawn(delta)


func _spawn(delta: float) -> void:
	_spawn_timer += delta
	var interval := lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, clampf(time / duration, 0.0, 1.0))
	if _spawn_timer >= interval:
		_spawn_timer -= interval
		spawn_enemy(_random_edge_position())


## アリーナの外周上のランダムな点。
func _random_edge_position() -> Vector2:
	var w := ARENA_SIZE.x
	var h := ARENA_SIZE.y
	var d := _rng.randf() * (w + h) * 2.0
	if d < w:
		return Vector2(d, 0)
	d -= w
	if d < h:
		return Vector2(w, d)
	d -= h
	if d < w:
		return Vector2(w - d, h)
	return Vector2(0, h - (d - w))


func _player_attack(delta: float) -> void:
	_attack_gauge += Stats.calculate(_effects)["speed"] * 10.0 * delta
	while _attack_gauge >= ACTION_GAUGE:
		var target := _nearest_enemy_in_range()
		if target == null:
			# 敵が来るまで次の1回分の準備を持ち越す
			_attack_gauge = ACTION_GAUGE
			return
		_attack_gauge -= ACTION_GAUGE
		var direction := player_position.direction_to(target.position)
		projectiles.append(StageProjectile.new(player_position, direction * PROJECTILE_SPEED))


func _move_projectiles(delta: float) -> void:
	for projectile in projectiles.duplicate():
		var from: Vector2 = projectile.position
		projectile.position += projectile.velocity * delta
		projectile.traveled += projectile.velocity.length() * delta
		var hit := _first_enemy_on_segment(from, projectile.position)
		if hit != null:
			projectiles.erase(projectile)
			_hit(hit)
		elif projectile.traveled >= ATTACK_RANGE * PROJECTILE_RANGE_RATIO:
			projectiles.erase(projectile)


## from から to へ動いた弾が触れる敵のうち、from にいちばん近いもの。
func _first_enemy_on_segment(from: Vector2, to: Vector2) -> StageEnemy:
	var first: StageEnemy = null
	var first_distance := INF
	for enemy in enemies:
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		if closest.distance_to(enemy.position) > enemy.radius + PROJECTILE_RADIUS:
			continue
		var distance := from.distance_to(closest)
		if distance < first_distance:
			first = enemy
			first_distance = distance
	return first


## 弾が当たった敵にダメージと on_hit を与える。条件付き効果はその敵の状態で判定する。
func _hit(enemy: StageEnemy) -> void:
	var stats := Stats.calculate(_effects, _context(enemy))
	var damage: float = stats["attack"]
	if _rng.randf() * 100.0 < stats["crit_chance"]:
		damage *= stats["crit_damage"] / 100.0
	enemy.hp -= _damage(damage, enemy.defense)
	for on_hit in _on_hits:
		if _rng.randf() * 100.0 < on_hit["chance"]:
			_apply_status(enemy, on_hit["apply"], stats)
	if enemy.hp <= 0.0:
		_defeat(enemy)


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
			if player_hp <= 0.0:
				player_hp = 0.0
				state = State.FAILED
				return


func _touches_player(enemy: StageEnemy) -> bool:
	return enemy.position.distance_to(player_position) <= PLAYER_RADIUS + enemy.radius


func _damage(attack: float, target_defense: float) -> float:
	return attack * 100.0 / (100.0 + target_defense)
