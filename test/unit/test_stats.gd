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


func test_火力の目安は攻撃力と素早さと会心の期待値から計算する():
	# 攻撃力20 × 素早さ15/10 × (1 + 会心率40% × (会心ダメージ200% - 100%)) = 20 × 1.5 × 1.4 = 42
	var stats := {"hp": 100.0, "attack": 20.0, "defense": 0.0, "speed": 15.0, "crit_chance": 40.0, "crit_damage": 200.0}

	assert_almost_eq(Stats.offense(stats), 42.0, 0.001)


func test_会心率は100パーセントを超えても100パーセントとして扱う():
	var stats := {"hp": 100.0, "attack": 10.0, "defense": 0.0, "speed": 10.0, "crit_chance": 150.0, "crit_damage": 200.0}

	assert_almost_eq(Stats.offense(stats), 20.0, 0.001)


func test_耐久の目安はHPと防御力から計算する():
	# HP200 × (1 + 防御力50/100) = 300
	var stats := {"hp": 200.0, "attack": 10.0, "defense": 50.0, "speed": 10.0, "crit_chance": 0.0, "crit_damage": 150.0}

	assert_almost_eq(Stats.defense(stats), 300.0, 0.001)
