class_name StarIcon
extends Control
## Estrella dibujada con formas. Acompaña al texto de récord.

var color: Color = Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(40, 40)


func _draw() -> void:
	var c := size / 2
	var points := PackedVector2Array()
	for i in 10:
		var r := size.x * (0.5 if i % 2 == 0 else 0.22)
		points.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * r)
	draw_colored_polygon(points, color)
