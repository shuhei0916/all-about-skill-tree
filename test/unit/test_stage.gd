extends GutTest

# 会心が出ないようにして、ダメージを決定的にする
const NO_CRIT := {"type": "more", "stat": "crit_chance", "value": -100}


# 敵が自動では湧かないステージ。テストで置いた敵だけを相手にする
func _stage(effects := []) -> Stage:
	var stage := Stage.new(effects, 1)
	stage.spawning = false
	return stage


func test_プレイヤーはアリーナの中央から始まり移動方向に移動する():
	var stage := _stage()
	var start := stage.player_position

	stage.step(1.0, Vector2.RIGHT)

	assert_eq(start, Stage.ARENA_SIZE / 2.0)
	assert_almost_eq(stage.player_position.x, start.x + Stage.PLAYER_MOVE_SPEED, 0.001)
	assert_almost_eq(stage.player_position.y, start.y, 0.001)


func test_斜め移動でも速さは変わらない():
	var stage := _stage()
	var start := stage.player_position

	stage.step(1.0, Vector2(1, 1))

	assert_almost_eq(stage.player_position.distance_to(start), Stage.PLAYER_MOVE_SPEED, 0.001)


func test_プレイヤーはアリーナの外に出られない():
	var stage := _stage()

	for i in 100:
		stage.step(0.1, Vector2(-1, -1))

	assert_eq(stage.player_position, Vector2(Stage.PLAYER_RADIUS, Stage.PLAYER_RADIUS))


func test_敵はプレイヤーに向かって移動する():
	var stage := _stage()
	var enemy := stage.spawn_enemy(Vector2(100, stage.player_position.y))

	stage.step(1.0, Vector2.ZERO)

	assert_almost_eq(enemy.position.x, 100.0 + enemy.move_speed, 0.001)
	assert_almost_eq(enemy.position.y, stage.player_position.y, 0.001)


func test_敵がプレイヤーに触れるとダメージを与えしばらくは再びダメージを与えない():
	var stage := _stage()
	var enemy := stage.spawn_enemy(stage.player_position + Vector2(20, 0))
	enemy.hp = 100000.0
	# 攻撃力8 × 100 / (100 + 防御10)
	var damage := 8.0 * 100.0 / 110.0

	stage.step(0.1, Vector2.ZERO)
	assert_almost_eq(stage.player_hp, 100.0 - damage, 0.001)

	stage.step(0.5, Vector2.ZERO)
	assert_almost_eq(stage.player_hp, 100.0 - damage, 0.001)

	stage.step(0.5, Vector2.ZERO)
	assert_almost_eq(stage.player_hp, 100.0 - damage * 2, 0.001)


# 倒れない的。防御力0なのでダメージは攻撃力そのまま
func _target(stage: Stage, offset: Vector2) -> StageEnemy:
	var enemy := stage.spawn_enemy(stage.player_position + offset)
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.move_speed = 0.0
	enemy.attack = 0.0
	return enemy


func test_プレイヤーは射程内でいちばん近い敵を素早さに応じた間隔で攻撃する():
	var stage := _stage([NO_CRIT])
	var near := _target(stage, Vector2(100, 0))
	var far := _target(stage, Vector2(-200, 0))

	# 素早さ10なら1秒に1回。1.5秒なら1回だけ攻撃する
	for i in 15:
		stage.step(0.1, Vector2.ZERO)

	assert_almost_eq(near.max_hp - near.hp, 10.0, 0.001)
	assert_eq(far.hp, far.max_hp)


func test_射程内に敵がいなければ攻撃せず準備を溜めたまま待つ():
	var stage := _stage([NO_CRIT])
	var enemy := _target(stage, Vector2(Stage.ATTACK_RANGE + 50, 0))

	for i in 30:
		stage.step(0.1, Vector2.ZERO)
	assert_eq(enemy.hp, enemy.max_hp)

	# 射程に入ったらすぐに1回だけ攻撃する
	enemy.position = stage.player_position + Vector2(100, 0)
	stage.step(0.1, Vector2.ZERO)
	assert_almost_eq(enemy.max_hp - enemy.hp, 10.0, 0.001)


func test_HPが0になった敵は消えEXPが入る():
	var stage := _stage([NO_CRIT])
	var enemy := _target(stage, Vector2(100, 0))
	enemy.hp = 10.0
	enemy.exp = 3

	stage.step(1.0, Vector2.ZERO)

	assert_false(stage.enemies.has(enemy))
	assert_eq(stage.exp, 3)
	assert_eq(stage.kills, 1)


func test_on_hitの状態異常は攻撃した敵に付き条件付き効果はその敵の状態で判定する():
	var effects := [
		NO_CRIT,
		{"type": "on_hit", "chance": 100, "apply": "blind"},
		{"type": "increased", "stat": "attack", "value": 100, "condition": "enemy_blinded"},
	]
	var stage := _stage(effects)
	var enemy := _target(stage, Vector2(100, 0))

	for i in 25:
		stage.step(0.1, Vector2.ZERO)

	# 1回目は盲目を付与する前なので10、2回目は20
	assert_true(enemy.statuses.has("blind"))
	assert_almost_eq(enemy.max_hp - enemy.hp, 30.0, 0.001)


func test_毒は時間経過で敵にダメージを与える():
	var stage := _stage([NO_CRIT, {"type": "on_hit", "chance": 100, "apply": "poison"}])
	var enemy := _target(stage, Vector2(100, 0))

	for i in 25:
		stage.step(0.1, Vector2.ZERO)

	# 攻撃2回で20。それに毒のダメージが加わる
	assert_gt(enemy.max_hp - enemy.hp, 20.0)


func test_盲目の敵は接触ダメージを外すことがある():
	var normal := _stage([NO_CRIT])
	var blinded := _stage([NO_CRIT, {"type": "on_hit", "chance": 100, "apply": "blind"}])
	for stage in [normal, blinded]:
		_target(stage, Vector2(20, 0)).attack = 1.0
		for i in 300:
			stage.step(0.1, Vector2.ZERO)

	assert_gt(blinded.player_hp, normal.player_hp)


func _on_edge(position: Vector2) -> bool:
	return is_zero_approx(position.x) or is_zero_approx(position.y) \
		or is_equal_approx(position.x, Stage.ARENA_SIZE.x) or is_equal_approx(position.y, Stage.ARENA_SIZE.y)


func test_時間とともに敵がアリーナの端に湧く():
	var stage := Stage.new([], 1)

	for i in 50:
		stage.step(0.1, Vector2.ZERO)
		if not stage.enemies.is_empty():
			break

	assert_eq(stage.enemies.size(), 1)
	assert_true(_on_edge(stage.enemies[0].position), "湧いた位置: %s" % stage.enemies[0].position)


func test_制限時間まで生き延びるとクリアし時間が止まる():
	var stage := _stage()
	stage.duration = 5.0
	assert_eq(stage.state, Stage.State.PLAYING)

	for i in 80:
		stage.step(0.1, Vector2.ZERO)

	assert_eq(stage.state, Stage.State.CLEARED)
	assert_almost_eq(stage.time, 5.0, 0.001)


func test_HPが0になると失敗し時間が止まる():
	var stage := _stage()
	_target(stage, Vector2(20, 0)).attack = 1000.0

	stage.step(0.1, Vector2.ZERO)
	stage.step(0.1, Vector2.ZERO)

	assert_eq(stage.state, Stage.State.FAILED)
	assert_eq(stage.player_hp, 0.0)
	assert_almost_eq(stage.time, 0.1, 0.001)


func _play(seed: int, seconds: float) -> Stage:
	var stage := Stage.new([], seed)
	for i in roundi(seconds / 0.1):
		# 円を描くように逃げ回る
		stage.step(0.1, Vector2.RIGHT.rotated(i * 0.1))
	return stage


func test_同じシード同じ操作なら同じ結果になる():
	var a := _play(7, 20.0)
	var b := _play(7, 20.0)

	assert_gt(a.kills, 0)
	assert_eq([a.player_hp, a.exp, a.kills, a.enemies.size()], [b.player_hp, b.exp, b.kills, b.enemies.size()])


func test_ステージが進むほど敵が強くなる():
	var first := Stage.new([], 1, 1).spawn_enemy(Vector2.ZERO)
	var third := Stage.new([], 1, 3).spawn_enemy(Vector2.ZERO)

	assert_gt(third.max_hp, first.max_hp)
	assert_eq(third.hp, third.max_hp)
	assert_gt(third.attack, first.attack)


func test_ステージが進むほど敵を倒したときのEXPが増える():
	var first := Stage.new([], 1, 1).spawn_enemy(Vector2.ZERO)
	var third := Stage.new([], 1, 3).spawn_enemy(Vector2.ZERO)

	assert_gt(third.exp, first.exp)
