extends GutTest

# 会心が出ないようにして、ダメージを決定的にする
const NO_CRIT := {"type": "more", "stat": "crit_chance", "value": -100}


func _stage(effects := []) -> Stage:
	return Stage.new(effects, 1)


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
