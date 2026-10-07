class_name WheelView
extends Control
## Dibuja la ruleta con formas (sin imágenes). `rot` es la rotación en radianes, sentido horario;
## la flecha queda fija arriba. La geometría de qué casilla queda bajo la flecha está en WheelMath.

const ARC_STEPS := 28
const LABEL_SIZE := 34
const LABEL_MIN_SIZE := 22

var segments: Array = []
var highlight := -1
var pulse := 0.0
var rot := 0.0:
	set(value):
		rot = value
		queue_redraw()


func _draw() -> void:
	var n := segments.size()
	if n == 0:
		return
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 40.0
	var seg := TAU / n

	draw_circle(center + Vector2(12, 12), radius + 22.0, Color(0, 0, 0, 0.6))
	draw_circle(center, radius + 22.0, TenantTheme.REWARD)
	draw_circle(center, radius + 8.0, TenantTheme.NIGHT)

	for i in n:
		var start := -PI / 2.0 + i * seg + rot
		var pts := PackedVector2Array([center])
		for k in ARC_STEPS + 1:
			pts.append(center + Vector2.from_angle(start + seg * k / ARC_STEPS) * radius)
		draw_colored_polygon(pts, _fill(i, n))
		draw_line(center, center + Vector2.from_angle(start) * radius, TenantTheme.NIGHT, 5.0)

	var font := UiKit.display(800)
	for i in n:
		_draw_label(font, center, radius, seg, i, n)

	if highlight >= 0:
		var hs := -PI / 2.0 + highlight * seg + rot
		var outline := PackedVector2Array([center])
		for k in ARC_STEPS + 1:
			outline.append(center + Vector2.from_angle(hs + seg * k / ARC_STEPS) * radius)
		outline.append(center)
		draw_polyline(outline, Color(1, 1, 1, 0.55 + 0.45 * pulse), 10.0)

	# Luces del borde, alternando.
	for i in n * 3:
		var a := TAU * i / (n * 3) + rot * 0.0
		var lit := i % 2 == 0
		draw_circle(center + Vector2.from_angle(a) * (radius + 15.0), 6.0, Color.WHITE if lit else TenantTheme.NIGHT)

	# Centro.
	draw_circle(center, 64.0, TenantTheme.NIGHT)
	draw_arc(center, 64.0, 0.0, TAU, 40, TenantTheme.primary, 8.0)
	draw_circle(center, 22.0, TenantTheme.REWARD)

	# Flecha fija arriba.
	var tip := center + Vector2(0, -radius + 38.0)
	var arrow := PackedVector2Array([tip, tip + Vector2(-34, -78), tip + Vector2(34, -78)])
	draw_colored_polygon(arrow, TenantTheme.REWARD)
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color.WHITE, 6.0)


func _fill(i: int, n: int) -> Color:
	if n % 2 == 1 and i == n - 1:
		return TenantTheme.primary_hover
	return TenantTheme.primary if i % 2 == 0 else TenantTheme.NIGHT_RAISED.lightened(0.2)


func _text_color(i: int, n: int) -> Color:
	var light := (n % 2 == 1 and i == n - 1) or i % 2 == 0
	return TenantTheme.on_primary if light else TenantTheme.TEXT


func _draw_label(font: Font, center: Vector2, radius: float, seg: float, i: int, n: int) -> void:
	var angle := -PI / 2.0 + (i + 0.5) * seg + rot
	var inner := radius * 0.26
	var fitted := _fit(font, str(segments[i].title), radius * 0.70)
	var width := font.get_string_size(fitted.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted.size).x
	# En la mitad izquierda se gira el texto media vuelta para que siempre se lea de izquierda a derecha.
	var flip := cos(angle) < 0.0
	draw_set_transform(center, angle + (PI if flip else 0.0), Vector2.ONE)
	var x := -(inner + width) if flip else inner
	draw_string(font, Vector2(x, fitted.size * 0.32), fitted.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted.size, _text_color(i, n))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Reduce la letra hasta que el título quepa y, si aún no cabe, lo recorta con "…".
func _fit(font: Font, text: String, max_width: float) -> Dictionary:
	var size := LABEL_SIZE
	while size > LABEL_MIN_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 2
	var out := text
	if font.get_string_size(out, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		while out.length() > 1 and font.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
			out = out.left(out.length() - 1)
		out = out.strip_edges() + "…"
	return {"text": out, "size": size}
