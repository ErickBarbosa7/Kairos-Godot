class_name GameArt
extends Control
## Ilustración provisional de la tarjeta: estrellas y una nave dibujadas con formas.
## Se reemplaza por arte definitivo sin tocar la tarjeta.

var art_id: String = ""
var ship_color: Color = Color.WHITE
var star_color: Color = Color.WHITE

const STARS := [Vector2(0.12, 0.2), Vector2(0.3, 0.7), Vector2(0.55, 0.15), Vector2(0.78, 0.35),
	Vector2(0.9, 0.8), Vector2(0.2, 0.45), Vector2(0.65, 0.62), Vector2(0.42, 0.3)]


func _draw() -> void:
	if art_id == "serpiente_golosa":
		_draw_snake()
		return
	for star in STARS:
		draw_circle(star * size, 4.0, star_color)
	var c := Vector2(size.x / 2, size.y * 0.64)
	var s := minf(size.x, size.y) * 0.3
	var body := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.8), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.7, s * 0.8)])
	draw_colored_polygon(body, ship_color)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), TenantTheme.TEXT, 4.0)
	draw_rect(Rect2(c + Vector2(-5, -s * 1.75), Vector2(10, s * 0.5)), TenantTheme.REWARD)


func _draw_snake() -> void:
	var cell := minf(size.x / 9.0, size.y / 5.0)
	var origin := Vector2((size.x - cell * 9.0) / 2.0, (size.y - cell * 5.0) / 2.0)
	var path := [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 2), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	for i in range(path.size() - 1, -1, -1):
		var r := Rect2(origin + Vector2(path[i]) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
		draw_rect(r, ship_color if i % 2 == 0 else ship_color.darkened(0.18))
		draw_rect(r, TenantTheme.NIGHT if i > 0 else Color.WHITE, false, 3.0)
	var head := origin + (Vector2(path[path.size() - 1]) + Vector2(0.5, 0.5)) * cell
	draw_circle(head + Vector2(4, -7), 5.0, Color.WHITE)
	draw_circle(head + Vector2(4, 7), 5.0, Color.WHITE)
	# Producto a comer: una dona.
	var food := origin + (Vector2(8, 1) + Vector2(0.5, 0.5)) * cell
	draw_circle(food, cell * 0.38, Color("#F472B6"))
	draw_circle(food, cell * 0.15, Color(star_color, 0.0))
	draw_arc(food, cell * 0.38, 0.0, TAU, 20, Color.WHITE, 3.0)
	draw_circle(food, cell * 0.14, TenantTheme.NIGHT)
