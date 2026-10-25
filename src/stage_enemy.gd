class_name StageEnemy
extends RefCounted
## ステージに出てくる敵1体の状態。

var position: Vector2
var hp := 20.0
var max_hp := 20.0
var attack := 8.0
var defense := 0.0
## 移動速度（ピクセル/秒）
var move_speed := 80.0
var radius := 14.0
## 倒したときに得られるEXP
var exp := 1
## 状態異常名 -> 残り秒数
var statuses := {}
## 毒の毎秒ダメージ（付与したときの攻撃力で決まる）
var poison_dps := 0.0
## 次に接触ダメージを与えられるようになるまでの秒数
var contact_cooldown := 0.0


func _init(p_position: Vector2) -> void:
	position = p_position
