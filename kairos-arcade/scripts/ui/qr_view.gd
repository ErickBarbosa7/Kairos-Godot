class_name QrView
extends Control
## Dibuja un QR en negro sobre blanco con zona silenciosa de 4 módulos. Nunca se tematiza.

const QUIET := 4

var qr: QrCode
var module_px := 6


## El lado mide al menos `min_side` píxeles, con módulos de tamaño entero para que queden nítidos.
func setup(code: QrCode, min_side: int = 480) -> void:
	qr = code
	var total := code.size + QUIET * 2
	module_px = maxi(ceili(min_side / float(total)), 4)
	custom_minimum_size = Vector2.ONE * total * module_px


func _draw() -> void:
	if qr == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	for y in qr.size:
		var x := 0
		while x < qr.size:
			if qr.get_module(x, y):
				var start := x
				while x < qr.size and qr.get_module(x, y):
					x += 1
				draw_rect(Rect2(Vector2(start + QUIET, y + QUIET) * module_px, Vector2(x - start, 1) * module_px), Color.BLACK)
			else:
				x += 1
