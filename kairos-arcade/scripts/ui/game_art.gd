class_name GameArt
extends Control
## Ilustración provisional de la tarjeta: estrellas y una nave dibujadas con formas.
## Se reemplaza por arte definitivo sin tocar la tarjeta.

var ship_color: Color = Color.WHITE
var star_color: Color = Color.WHITE

const STARS := [Vector2(0.12, 0.2), Vector2(0.3, 0.7), Vector2(0.55, 0.15), Vector2(0.78, 0.35),
	Vector2(0.9, 0.8), Vector2(0.2, 0.45), Vector2(0.65, 0.62), Vector2(0.42, 0.3)]


func _draw() -> void:
	for star in STARS:
		draw_circle(star * size, 4.0, star_color)
	var c := Vector2(size.x / 2, size.y * 0.64)
	var s := minf(size.x, size.y) * 0.3
	var body := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.8), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.7, s * 0.8)])
	draw_colored_polygon(body, ship_color)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), TenantTheme.TEXT, 4.0)
	draw_rect(Rect2(c + Vector2(-5, -s * 1.75), Vector2(10, s * 0.5)), TenantTheme.REWARD)
