extends GutTest


func test_EXPが必要量に達するとレベルが上がり上がった回数を返す():
	var level := PlayerLevel.new()
	var needed := level.exp_to_next()

	assert_eq(level.add_exp(needed - 1), 0)
	assert_eq(level.level, 1)
	assert_eq(level.add_exp(1), 1)
	assert_eq(level.level, 2)
	assert_eq(level.exp, 0)


func test_必要EXPはレベルとともに増える():
	var level := PlayerLevel.new()
	var first := level.exp_to_next()

	level.add_exp(first)

	assert_gt(level.exp_to_next(), first)


func test_一度に大量のEXPを得ると複数回レベルが上がる():
	var level := PlayerLevel.new()
	var amount := level.exp_to_next()
	level.add_exp(amount)
	amount += level.exp_to_next()

	assert_eq(PlayerLevel.new().add_exp(amount), 2)
