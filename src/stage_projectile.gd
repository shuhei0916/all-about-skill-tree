class_name StageProjectile
extends RefCounted
## プレイヤーが撃った弾。まっすぐ飛び、最初に触れた敵に当たる。

var position: Vector2
## 速度（ピクセル/秒）
var velocity: Vector2
## これまでに飛んだ距離
var traveled := 0.0


func _init(p_position: Vector2, p_velocity: Vector2) -> void:
	position = p_position
	velocity = p_velocity
