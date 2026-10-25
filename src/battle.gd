class_name Battle
extends RefCounted
## プレイヤーと敵1体の自動戦闘をシミュレートする。
## 0.1秒刻みで時間を進め、各自が素早さに応じて溜まるゲージ（100で1回）で攻撃する。素早さ10なら1秒に1回。
## ダメージ = 攻撃力 × (会心なら会心ダメージ%) × 100 / (100 + 相手の防御力)

const TICK := 0.1
const ACTION_GAUGE := 100.0
const LOW_HP_RATIO := 0.5

## 盲目: 敵の攻撃が一定確率で外れる
const BLIND_MISS_CHANCE := 0.5
## 毒: 付与時の攻撃力に対するこの割合のダメージを毎秒与える
const POISON_DAMAGE_RATIO := 0.3
## 状態異常の持続時間（秒）。重ねがけすると持続時間が戻る。
const STATUS_DURATION := {"blind": 3.0, "poison": 4.0}

## 基準となる敵。何も取得していなければ負け、適当に15ポイント振ると勝ったり負けたり、
## 考えて振るとほぼ勝てる強さにしてある（2026-10-25 に生成器のシード0〜7で調整）。
const STANDARD_ENEMY := {
	"hp": 300.0,
	"attack": 12.0,
	"defense": 15.0,
	"speed": 10.0,
	"crit_chance": 5.0,
	"crit_damage": 150.0,
}

var max_time := 60.0

var _effects: Array
var _on_hits: Array
var _enemy: Dictionary
var _rng := RandomNumberGenerator.new()

var _player_hp: float
var _player_max_hp: float
var _enemy_hp: float
## 状態異常名 -> 残りティック数
var _enemy_statuses := {}
var _poison_dps := 0.0
var _damage_dealt := 0.0
var _damage_taken := 0.0


func _init(player_effects: Array, enemy: Dictionary, seed: int) -> void:
	_effects = player_effects
	_on_hits = player_effects.filter(func(e: Dictionary): return e["type"] == "on_hit")
	_enemy = enemy
	_rng.seed = seed


## 複数回戦わせた結果を集計する。runs 回それぞれ別のシードで戦う。
static func evaluate(player_effects: Array, enemy: Dictionary, runs := 20) -> Dictionary:
	var wins := 0
	var win_time := 0.0
	var total_time := 0.0
	var total_damage := 0.0
	var hp_left_ratio := 0.0
	for seed in runs:
		var result := Battle.new(player_effects, enemy, seed).run()
		total_time += result["time"]
		total_damage += result["damage_dealt"]
		hp_left_ratio += result["player_hp"] / result["player_max_hp"]
		if result["won"]:
			wins += 1
			win_time += result["time"]
	return {
		"win_rate": float(wins) / runs,
		"avg_win_time": win_time / wins if wins > 0 else INF,
		"dps": total_damage / total_time if total_time > 0.0 else 0.0,
		"hp_left_ratio": hp_left_ratio / runs,
	}


func run() -> Dictionary:
	_player_max_hp = Stats.calculate(_effects)["hp"]
	_player_hp = _player_max_hp
	_enemy_hp = _enemy["hp"]
	var player_gauge := 0.0
	var enemy_gauge := 0.0
	var ticks := roundi(max_time / TICK)
	for tick in range(1, ticks + 1):
		_update_statuses()
		if _enemy_hp <= 0.0:
			return _result(tick, true)

		var stats := Stats.calculate(_effects, _context())
		player_gauge += stats["speed"]
		while player_gauge >= ACTION_GAUGE:
			player_gauge -= ACTION_GAUGE
			_player_attack(Stats.calculate(_effects, _context()))
			if _enemy_hp <= 0.0:
				return _result(tick, true)

		enemy_gauge += _enemy["speed"]
		while enemy_gauge >= ACTION_GAUGE:
			enemy_gauge -= ACTION_GAUGE
			_enemy_attack(Stats.calculate(_effects, _context()))
			if _player_hp <= 0.0:
				_player_hp = 0.0
				return _result(tick, false)
	return _result(ticks, false, true)


## 条件付き効果の判定に使う、今の戦闘の状況。
func _context() -> Dictionary:
	return {
		"enemy_blinded": _enemy_statuses.has("blind"),
		"enemy_poisoned": _enemy_statuses.has("poison"),
		"low_hp": _player_hp <= _player_max_hp * LOW_HP_RATIO,
	}


func _update_statuses() -> void:
	if _enemy_statuses.has("poison"):
		_deal_damage(_poison_dps * TICK)
	for status in _enemy_statuses.keys():
		_enemy_statuses[status] -= 1
		if _enemy_statuses[status] <= 0:
			_enemy_statuses.erase(status)


func _player_attack(stats: Dictionary) -> void:
	_deal_damage(_hit_damage(stats, _enemy["defense"]))
	for on_hit in _on_hits:
		if _rng.randf() * 100.0 < on_hit["chance"]:
			_apply_status(on_hit["apply"], stats)


func _enemy_attack(player_stats: Dictionary) -> void:
	if _enemy_statuses.has("blind") and _rng.randf() < BLIND_MISS_CHANCE:
		return
	var damage := _hit_damage(_enemy, player_stats["defense"])
	_player_hp -= damage
	_damage_taken += damage


func _hit_damage(attacker: Dictionary, target_defense: float) -> float:
	var damage: float = attacker["attack"]
	if _rng.randf() * 100.0 < attacker["crit_chance"]:
		damage *= attacker["crit_damage"] / 100.0
	return damage * 100.0 / (100.0 + target_defense)


func _apply_status(status: String, stats: Dictionary) -> void:
	_enemy_statuses[status] = roundi(STATUS_DURATION[status] / TICK)
	if status == "poison":
		_poison_dps = stats["attack"] * POISON_DAMAGE_RATIO


func _deal_damage(damage: float) -> void:
	_enemy_hp -= damage
	_damage_dealt += damage


func _result(tick: int, won: bool, timed_out := false) -> Dictionary:
	return {
		"won": won,
		"timed_out": timed_out,
		"time": tick * TICK,
		"damage_dealt": _damage_dealt,
		"damage_taken": _damage_taken,
		"player_hp": _player_hp,
		"player_max_hp": _player_max_hp,
	}
