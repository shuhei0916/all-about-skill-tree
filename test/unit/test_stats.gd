extends GutTest


func test_補正を表示用の文字列にする():
	assert_eq(Stats.describe({"attack": 3}), "攻撃力 +3")


func test_複数の補正は改行でつなぐ():
	assert_eq(Stats.describe({"hp": 20, "speed": 1}), "HP +20\n素早さ +1")
