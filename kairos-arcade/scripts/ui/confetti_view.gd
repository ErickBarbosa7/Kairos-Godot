class_name ConfettiView
extends Control
## Confeti breve con rectángulos. Sin imágenes y sin nada que parpadee: cae y se apaga solo.

const COUNT := 110

var _pieces: Array = []
var _running := false


func burst() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors := [TenantTheme.primary, TenantTheme.REWARD, TenantTheme.TEXT, TenantTheme.SUCCESS]
	_pieces.clear()
	for i in COUNT:
		_pieces.append({
			"pos": Vector2(rng.randf_range(0.0, size.x), rng.randf_range(-size.y * 0.5, 0.0)),
			"vel": Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(260.0, 620.0)),
			"size": Vector2(rng.randf_range(10.0, 20.0), rng.randf_range(16.0, 30.0)),
			"color": colors[rng.randi_range(0, colors.size() - 1)],
			"phase": rng.randf() * TAU,
		})
	_running = true
	set_process(true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return
	var alive := 0
	for p in _pieces:
		p.pos += p.vel * delta
		p.pos.x += sin(p.phase + p.pos.y * 0.01) * 40.0 * delta
		if p.pos.y < size.y + 40.0:
			alive += 1
	if alive == 0:
		_running = false
		_pieces.clear()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for p in _pieces:
		draw_rect(Rect2(p.pos, p.size), p.color)
