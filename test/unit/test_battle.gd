extends GutTest

# 会心が出ないようにして、ダメージを決定的にする
const NO_CRIT := {"type": "more", "stat": "crit_chance", "value": -100}


# 攻撃してこない、倒れない的
func _dummy(overrides := {}) -> Dictionary:
	var enemy := {"hp": 100000.0, "attack": 0.0, "defense": 0.0, "speed": 10.0, "crit_chance": 0.0, "crit_damage": 150.0}
	enemy.merge(overrides, true)
	return enemy


func _run(effects: Array, enemy: Dictionary, max_time: float, seed := 1) -> Dictionary:
	var battle := Battle.new(effects, enemy, seed)
	battle.max_time = max_time
	return battle.run()


func test_素早さ10なら1秒に1回攻撃する():
	var result := _run([NO_CRIT], _dummy(), 10.0)

	# 攻撃力10 × 10回
	assert_almost_eq(result["damage_dealt"], 100.0, 0.001)


func test_防御力100の相手には半分のダメージになる():
	var result := _run([NO_CRIT], _dummy({"defense": 100.0}), 10.0)

	assert_almost_eq(result["damage_dealt"], 50.0, 0.001)


func test_会心が出るとダメージが会心ダメージ倍になる():
	# 会心率 5 + 95 = 100%、会心ダメージ150%
	var result := _run([{"type": "flat", "stat": "crit_chance", "value": 95}], _dummy(), 10.0)

	assert_almost_eq(result["damage_dealt"], 150.0, 0.001)


func test_敵のHPが0になると勝利する():
	var result := _run([NO_CRIT], _dummy({"hp": 25.0}), 60.0)

	assert_true(result["won"])
	assert_false(result["timed_out"])
	assert_almost_eq(result["time"], 3.0, 0.001)


func test_自分のHPが0になると敗北する():
	var result := _run([NO_CRIT], _dummy({"attack": 1000.0}), 60.0)

	assert_false(result["won"])
	assert_false(result["timed_out"])
	assert_eq(result["player_hp"], 0.0)


func test_決着がつかなければ時間切れになる():
	var result := _run([NO_CRIT], _dummy(), 5.0)

	assert_false(result["won"])
	assert_true(result["timed_out"])
	assert_almost_eq(result["time"], 5.0, 0.001)


func test_同じシードなら同じ結果になる():
	var a := _run([], Battle.STANDARD_ENEMY, 60.0, 42)
	var b := _run([], Battle.STANDARD_ENEMY, 60.0, 42)

	assert_eq(a, b)


func test_on_hitで敵に状態異常を付与すると条件付き効果が有効になる():
	var effects := [
		NO_CRIT,
		{"type": "on_hit", "chance": 100, "apply": "blind"},
		{"type": "increased", "stat": "attack", "value": 100, "condition": "enemy_blinded"},
	]

	var result := _run(effects, _dummy(), 3.0)

	# 1回目は盲目を付与する前なので10、2回目以降は20
	assert_almost_eq(result["damage_dealt"], 50.0, 0.001)


func test_盲目の敵は攻撃を外すことがある():
	var enemy := _dummy({"attack": 1.0})
	var blind := {"type": "on_hit", "chance": 100, "apply": "blind"}

	var normal := _run([NO_CRIT], enemy, 60.0)
	var blinded := _run([NO_CRIT, blind], enemy, 60.0)

	assert_lt(blinded["damage_taken"], normal["damage_taken"])


func test_毒は時間経過でダメージを与える():
	var poison := {"type": "on_hit", "chance": 100, "apply": "poison"}

	var result := _run([NO_CRIT, poison], _dummy(), 10.0)

	assert_gt(result["damage_dealt"], 100.0)


func test_自分のHPが半分以下になるとlow_hpの効果が有効になる():
	# 敵の攻撃 66 × 100 / (100 + 防御10) = 60ダメージ。1秒目の被弾でHPが40になる
	var enemy := _dummy({"attack": 66.0})
	var low_hp_bonus := {"type": "more", "stat": "attack", "value": 100, "condition": "low_hp"}

	var result := _run([NO_CRIT, low_hp_bonus], enemy, 2.0)

	# 1秒目は10、2秒目はHPが半分以下なので20
	assert_almost_eq(result["damage_dealt"], 30.0, 0.001)


func test_複数回戦わせて勝率とDPSを集計できる():
	var strong := [{"type": "more", "stat": "attack", "value": 1000}, {"type": "more", "stat": "hp", "value": 1000}]

	var summary := Battle.evaluate(strong, Battle.STANDARD_ENEMY, 10)

	assert_eq(summary["win_rate"], 1.0)
	assert_gt(summary["dps"], 0.0)
	assert_gt(summary["hp_left_ratio"], 0.0)
	assert_eq(Battle.evaluate(strong, Battle.STANDARD_ENEMY, 10), summary)
