class_name LockIcon
extends Control
## Candado dibujado con formas, para no depender de glifos de la fuente.

@export var color: Color = Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(40, 48)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := Rect2(Vector2(0, h * 0.45), Vector2(w, h * 0.55))
	draw_rect(body, color)
	draw_arc(Vector2(w / 2, h * 0.45), w * 0.32, PI, TAU, 24, color, 5.0)
	draw_rect(Rect2(Vector2(w * 0.44, h * 0.62), Vector2(w * 0.12, h * 0.18)), TenantTheme.NIGHT)
