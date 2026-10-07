class_name ArrowIcon
extends Control
## Triángulo dibujado (arriba o abajo) que marca la casilla activa.

var up := true
var color: Color = Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(56, 32)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([Vector2(w * 0.1, h), Vector2(w * 0.9, h), Vector2(w / 2, 0)]) if up else PackedVector2Array([Vector2(w * 0.1, 0), Vector2(w * 0.9, 0), Vector2(w / 2, h)])
	draw_colored_polygon(pts, color)
