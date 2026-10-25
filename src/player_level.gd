class_name PlayerLevel
extends RefCounted
## プレイヤーのレベルとEXP。レベルが1上がるごとにスキルポイントが1もらえる。

var level := 1
## 今のレベルになってから溜めたEXP
var exp := 0


## 次のレベルまでに必要なEXP。レベル1で5、以降2ずつ増える
func exp_to_next() -> int:
	return 3 + level * 2


## EXPを加え、レベルが上がった回数を返す。
func add_exp(amount: int) -> int:
	exp += amount
	var gained := 0
	while exp >= exp_to_next():
		exp -= exp_to_next()
		level += 1
		gained += 1
	return gained
