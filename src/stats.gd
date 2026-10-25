class_name Stats
extends RefCounted
## キャラクターのステータスの定義。

const NAMES: Array[String] = ["hp", "attack", "defense", "speed"]

const LABELS := {
	"hp": "HP",
	"attack": "攻撃力",
	"defense": "防御力",
	"speed": "素早さ",
}

const BASE := {
	"hp": 100,
	"attack": 10,
	"defense": 10,
	"speed": 10,
}

## ノード1つあたりの補正値の範囲 [最小, 最大]
const BONUS_RANGE := {
	"hp": [10, 30],
	"attack": [1, 5],
	"defense": [1, 5],
	"speed": [1, 3],
}


## 補正を「攻撃力 +3」のような表示用の文字列にする。
static func describe(bonuses: Dictionary) -> String:
	var lines: Array[String] = []
	for stat in bonuses:
		lines.append("%s +%d" % [LABELS[stat], bonuses[stat]])
	return "\n".join(lines)
