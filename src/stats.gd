class_name Stats
extends RefCounted
## キャラクターのステータスの定義と計算。

const NAMES: Array[String] = ["hp", "attack", "defense", "speed", "crit_chance", "crit_damage"]

const LABELS := {
	"hp": "HP",
	"attack": "攻撃力",
	"defense": "防御力",
	"speed": "素早さ",
	"crit_chance": "会心率",
	"crit_damage": "会心ダメージ",
}

const BASE := {
	"hp": 100,
	"attack": 10,
	"defense": 10,
	"speed": 10,
	"crit_chance": 5,
	"crit_damage": 150,
}

## 百分率で表示するステータス
const PERCENT_STATS: Array[String] = ["crit_chance", "crit_damage"]


## 効果を「攻撃力 +3」「攻撃力 +10%」「攻撃力 ×1.3」のような表示用の文字列にする。
static func describe(effects: Array) -> String:
	var lines: Array[String] = []
	for effect in effects:
		var label: String = LABELS[effect["stat"]]
		match effect["type"]:
			"flat":
				lines.append("%s +%d" % [label, effect["value"]])
			"increased":
				lines.append("%s +%d%%" % [label, effect["value"]])
			"more":
				lines.append("%s ×%s" % [label, snappedf(1.0 + effect["value"] / 100.0, 0.01)])
	return "\n".join(lines)


## 火力の目安。1秒あたりのダメージの期待値に相当する（素早さ10で1回攻撃）。
static func offense(stats: Dictionary) -> float:
	var crit_chance := clampf(stats["crit_chance"] / 100.0, 0.0, 1.0)
	var crit_multiplier: float = 1.0 + crit_chance * (stats["crit_damage"] / 100.0 - 1.0)
	return stats["attack"] * stats["speed"] / 10.0 * crit_multiplier


## 耐久の目安。防御力100で受けるダメージが半分になる想定。
static func defense(stats: Dictionary) -> float:
	return stats["hp"] * (1.0 + stats["defense"] / 100.0)


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
