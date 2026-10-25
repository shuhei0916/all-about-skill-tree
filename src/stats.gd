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


## 効果を「攻撃力 +3」のような表示用の文字列にする。
static func describe(effects: Array) -> String:
	var lines: Array[String] = []
	for effect in effects:
		lines.append("%s +%d" % [LABELS[effect["stat"]], effect["value"]])
	return "\n".join(lines)


## 効果を集計して最終的なステータスを返す。
## 最終値 = (基礎 + Σflat) × (1 + Σincreased%) × Π(1 + more%)
static func calculate(effects: Array) -> Dictionary:
	var flat := {}
	var increased := {}
	var more := {}
	for stat in NAMES:
		flat[stat] = float(BASE[stat])
		increased[stat] = 1.0
		more[stat] = 1.0
	for effect in effects:
		var stat: String = effect["stat"]
		match effect["type"]:
			"flat":
				flat[stat] += effect["value"]
			"increased":
				increased[stat] += effect["value"] / 100.0
			"more":
				more[stat] *= 1.0 + effect["value"] / 100.0
	var result := {}
	for stat in NAMES:
		result[stat] = flat[stat] * increased[stat] * more[stat]
	return result
