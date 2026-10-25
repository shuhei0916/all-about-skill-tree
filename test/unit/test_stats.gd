extends GutTest


func test_効果を表示用の文字列にする():
	assert_eq(Stats.describe([{"type": "flat", "stat": "attack", "value": 3}]), "攻撃力 +3")


func test_複数の効果は改行でつなぐ():
	assert_eq(Stats.describe([{"type": "flat", "stat": "hp", "value": 20}, {"type": "flat", "stat": "speed", "value": 1}]), "HP +20\n素早さ +1")


func test_flatは基礎値に足される():
	var stats := Stats.calculate([
		{"type": "flat", "stat": "attack", "value": 3},
		{"type": "flat", "stat": "attack", "value": 2},
	])

	assert_almost_eq(stats["attack"], Stats.BASE["attack"] + 5.0, 0.001)
	assert_almost_eq(stats["hp"], float(Stats.BASE["hp"]), 0.001)


func test_increasedは同じステータス同士で足し合わせてから掛ける():
	# 基礎10 × (1 + 0.1 + 0.2) = 13
	var stats := Stats.calculate([
		{"type": "increased", "stat": "attack", "value": 10},
		{"type": "increased", "stat": "attack", "value": 20},
	])

	assert_almost_eq(stats["attack"], 13.0, 0.001)


func test_moreは1つずつ掛け合わせる():
	# 基礎10 × 1.5 × 1.5 = 22.5
	var stats := Stats.calculate([
		{"type": "more", "stat": "attack", "value": 50},
		{"type": "more", "stat": "attack", "value": 50},
	])

	assert_almost_eq(stats["attack"], 22.5, 0.001)


func test_マイナスのmoreは値を減らす():
	# 基礎10 × 0.7 = 7
	var stats := Stats.calculate([{"type": "more", "stat": "attack", "value": -30}])

	assert_almost_eq(stats["attack"], 7.0, 0.001)


func test_基礎とflatの合計にincreasedとmoreを順に掛ける():
	# (10 + 10) × (1 + 0.5) × 2 = 60
	var stats := Stats.calculate([
		{"type": "more", "stat": "attack", "value": 100},
		{"type": "increased", "stat": "attack", "value": 50},
		{"type": "flat", "stat": "attack", "value": 10},
	])

	assert_almost_eq(stats["attack"], 60.0, 0.001)


func test_increasedは百分率で表示する():
	assert_eq(Stats.describe([{"type": "increased", "stat": "attack", "value": 10}]), "攻撃力 +10%")


func test_moreは倍率で表示する():
	assert_eq(Stats.describe([{"type": "more", "stat": "attack", "value": 30}]), "攻撃力 ×1.3")
	assert_eq(Stats.describe([{"type": "more", "stat": "speed", "value": -25}]), "素早さ ×0.75")


func test_会心率と会心ダメージを持つ():
	assert_has(Stats.NAMES, "crit_chance")
	assert_has(Stats.NAMES, "crit_damage")


func test_条件付き効果は状況が条件を満たすときだけ計算に含まれる():
	var effects := [{"type": "increased", "stat": "attack", "value": 50, "condition": "enemy_blinded"}]

	assert_almost_eq(Stats.calculate(effects, {"enemy_blinded": true})["attack"], 15.0, 0.001)
	assert_almost_eq(Stats.calculate(effects, {"enemy_blinded": false})["attack"], 10.0, 0.001)


func test_状況を渡さなければ条件付き効果は含まれない():
	var effects := [{"type": "more", "stat": "attack", "value": 50, "condition": "low_hp"}]

	assert_almost_eq(Stats.calculate(effects)["attack"], 10.0, 0.001)


func test_on_hitはステータスの計算に影響しない():
	var stats := Stats.calculate([{"type": "on_hit", "chance": 20, "apply": "blind"}])

	assert_eq(stats, Stats.calculate([]))


func test_条件付き効果は条件を先頭に付けて表示する():
	var effect := {"type": "increased", "stat": "crit_chance", "value": 25, "condition": "enemy_blinded"}

	assert_eq(Stats.describe([effect]), "敵が盲目のとき 会心率 +25%")


func test_on_hitは発動率と付与する状態異常を表示する():
	assert_eq(Stats.describe([{"type": "on_hit", "chance": 20, "apply": "poison"}]), "攻撃時 20%で毒を付与")


func test_百分率のステータスのflatはポイントで表示する():
	assert_eq(Stats.describe([{"type": "flat", "stat": "crit_chance", "value": 20}]), "会心率 +20ポイント")
