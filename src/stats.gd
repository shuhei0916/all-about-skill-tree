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

## 条件付き効果の条件。戦闘中の状況（context）に同じキーで true が入っていれば成立する。
const CONDITION_LABELS := {
	"enemy_blinded": "敵が盲目のとき",
	"enemy_poisoned": "敵が毒のとき",
	"low_hp": "HPが半分以下のとき",
}

## on_hit で敵に付与する状態異常
const STATUS_LABELS := {
	"blind": "盲目",
	"poison": "毒",
}


## 効果を「攻撃力 +3」「攻撃力 +10%」「攻撃力 ×1.3」のような表示用の文字列にする。
static func describe(effects: Array) -> String:
	var lines: Array[String] = []
	for effect in effects:
		lines.append(_describe_one(effect))
	return "\n".join(lines)


static func _describe_one(effect: Dictionary) -> String:
	if effect["type"] == "on_hit":
		return "攻撃時 %d%%で%sを付与" % [effect["chance"], STATUS_LABELS[effect["apply"]]]
	var label: String = LABELS[effect["stat"]]
	var text := ""
	match effect["type"]:
		"flat":
			var unit := "ポイント" if PERCENT_STATS.has(effect["stat"]) else ""
			text = "%s +%d%s" % [label, effect["value"], unit]
		"increased":
			text = "%s +%d%%" % [label, effect["value"]]
		"more":
			text = "%s ×%s" % [label, snappedf(1.0 + effect["value"] / 100.0, 0.01)]
	if effect.has("condition"):
		text = "%s %s" % [CONDITION_LABELS[effect["condition"]], text]
	return text


## 効果を集計して最終的なステータスを返す。
## 最終値 = (基礎 + Σflat) × (1 + Σincreased%) × Π(1 + more%)
## 条件付き効果は、context でその条件が true のときだけ含める。
static func calculate(effects: Array, context := {}) -> Dictionary:
	var flat := {}
	var increased := {}
	var more := {}
	for stat in NAMES:
		flat[stat] = float(BASE[stat])
		increased[stat] = 1.0
		more[stat] = 1.0
	for effect in effects:
		if effect["type"] == "on_hit":
			continue
		if effect.has("condition") and not context.get(effect["condition"], false):
			continue
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
