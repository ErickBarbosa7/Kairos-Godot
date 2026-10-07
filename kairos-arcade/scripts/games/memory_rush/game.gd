class_name MemoryRush
extends ArcadeGame
## Memory Rush: observa una secuencia de cuatro paneles y repítela con las flechas.

enum Turn { PREPARE, SHOWING, WAITING, FEEDBACK }

const PAD_SIZE := Vector2(310, 230)
const PAD_GAP := 36.0
const BOARD_ORIGIN := Vector2(632, 318)
const SHOW_SECONDS := 0.58
const PAUSE_SECONDS := 0.18
const PRESS_SECONDS := 0.22
const FEEDBACK_SECONDS := 0.95
const BASE_POINTS := 100
const PAD_LABELS := ["←", "↑", "↓", "→"]

var _turn := Turn.PREPARE
var _sequence: Array[int] = []
var _round_length := 3
var _show_index := 0
var _show_lit := false
var _timer := 0.0
var _input_index := 0
var _flash_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _feedback_success := false


func _ready() -> void:
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if phase != Phase.PLAYING or _turn != Turn.WAITING:
		return
	if event.is_action_pressed("move_left"):
		_submit(0)
	elif event.is_action_pressed("move_up"):
		_submit(1)
	elif event.is_action_pressed("move_down"):
		_submit(2)
	elif event.is_action_pressed("move_right"):
		_submit(3)
	else:
		return
	get_viewport().set_input_as_handled()


func _play(delta: float) -> void:
	keeper.tick(delta)
	for i in _flash_times.size():
		_flash_times[i] = maxf(_flash_times[i] - delta, 0.0)
	match _turn:
		Turn.PREPARE:
			_start_round()
		Turn.SHOWING:
			_advance_show(delta)
		Turn.FEEDBACK:
			_timer -= delta
			if _timer <= 0.0:
				_start_round()


func _start_round() -> void:
	_sequence.clear()
	for i in _round_length:
		_sequence.append(_rng.randi_range(0, 3))
	_show_index = 0
	_show_lit = true
	_timer = SHOW_SECONDS
	_input_index = 0
	_turn = Turn.SHOWING


func _advance_show(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _show_lit:
		_show_lit = false
		_timer = PAUSE_SECONDS
		return
	_show_index += 1
	if _show_index >= _sequence.size():
		_turn = Turn.WAITING
		return
	_show_lit = true
	_timer = SHOW_SECONDS


func _submit(pad: int) -> void:
	_flash_times[pad] = PRESS_SECONDS
	if pad == _sequence[_input_index]:
		_input_index += 1
		if _input_index == _sequence.size():
			_round_complete()
		return
	_round_failed()


func _round_complete() -> void:
	var points := keeper.add_kill(_sequence.size() * BASE_POINTS)
	ArcadeState.add_score(points)
	var center := _board_center()
	_float_text(center, "+%d" % points, TenantTheme.REWARD)
	_burst(center, TenantTheme.SUCCESS, 28, 360.0)
	_round_length += 1
	_feedback_success = true
	_timer = FEEDBACK_SECONDS
	_turn = Turn.FEEDBACK


func _round_failed() -> void:
	var failed_pad := _sequence[_input_index]
	_flash_times[failed_pad] = PRESS_SECONDS * 2.0
	keeper.hit()
	_shake = 0.15
	_float_text(_board_center(), Strings.MEMORY_MISTAKE, TenantTheme.DANGER)
	_burst(_board_center(), TenantTheme.DANGER, 20, 300.0)
	if keeper.lives <= 0:
		_end("lives")
		return
	_feedback_success = false
	_timer = FEEDBACK_SECONDS
	_turn = Turn.FEEDBACK


func _on_end() -> void:
	_burst(_board_center(), TenantTheme.primary, 40, 420.0)


func _board_center() -> Vector2:
	return BOARD_ORIGIN + PAD_SIZE + Vector2(PAD_GAP / 2.0, PAD_GAP / 2.0)


func _pad_rect(index: int) -> Rect2:
	var col := index % 2
	var row := index / 2
	return Rect2(BOARD_ORIGIN + Vector2(col * (PAD_SIZE.x + PAD_GAP), row * (PAD_SIZE.y + PAD_GAP)), PAD_SIZE)


func _pad_color(index: int) -> Color:
	match index:
		0:
			return TenantTheme.primary
		1:
			return TenantTheme.REWARD
		2:
			return TenantTheme.SUCCESS
		_:
			return TenantTheme.DANGER


func _current_lit_pad() -> int:
	if _turn == Turn.SHOWING and _show_lit and _show_index < _sequence.size():
		return _sequence[_show_index]
	return -1


func _status_text() -> String:
	match _turn:
		Turn.PREPARE, Turn.SHOWING:
			return Strings.MEMORY_WATCH
		Turn.WAITING:
			return Strings.MEMORY_REPEAT
		Turn.FEEDBACK:
			return Strings.MEMORY_CORRECT if _feedback_success else Strings.MEMORY_TRY_AGAIN
	return ""


func _draw() -> void:
	_draw_background()
	_draw_title()
	_draw_pads()
	_draw_particles()
	_draw_floating()


func _draw_background() -> void:
	for x in range(120, int(SCREEN.x), 120):
		draw_line(Vector2(x, 180), Vector2(x, SCREEN.y - 140), Color(TenantTheme.TEXT, 0.035), 2.0)
	for y in range(220, int(SCREEN.y - 100), 100):
		draw_line(Vector2(80, y), Vector2(SCREEN.x - 80, y), Color(TenantTheme.TEXT, 0.035), 2.0)
	var frame := Rect2(BOARD_ORIGIN - Vector2(34, 34), PAD_SIZE * 2.0 + Vector2(PAD_GAP + 68, PAD_GAP + 68))
	draw_rect(frame, TenantTheme.NIGHT_RAISED)
	draw_rect(frame, TenantTheme.NIGHT_LINE, false, 6.0)


func _draw_title() -> void:
	var display := UiKit.display(900)
	var label := UiKit.text(700)
	draw_string(display, Vector2(0, 220), Strings.MEMORY_TITLE, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 82, TenantTheme.TEXT)
	draw_string(label, Vector2(0, 272), _status_text(), HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 32, TenantTheme.TEXT_SECONDARY)
	draw_string(label, Vector2(0, 1000), Strings.MEMORY_ROUND % _round_length, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 28, TenantTheme.TEXT_SECONDARY)


func _draw_pads() -> void:
	var active := _current_lit_pad()
	var display := UiKit.display(900)
	for i in 4:
		var rect := _pad_rect(i)
		var lit := i == active or _flash_times[i] > 0.0
		var color := _pad_color(i)
		var fill := color.lightened(0.16) if lit else color.darkened(0.34)
		draw_rect(rect, fill)
		draw_rect(rect, Color.WHITE if lit else TenantTheme.TEXT_SECONDARY, false, 6.0)
		if lit:
			draw_rect(rect.grow(14), Color(color, 0.22))
		var glyph: String = PAD_LABELS[i]
		var glyph_width := display.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 116).x
		draw_string(display, rect.get_center() + Vector2(-glyph_width / 2.0, 40), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 116, TenantTheme.pick_on_color(fill))


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var color := TenantTheme.primary if full else TenantTheme.TEXT_SECONDARY
	canvas.draw_circle(c, 22.0, color if full else Color.TRANSPARENT)
	canvas.draw_circle(c, 22.0, color, false, 4.0)
	if full:
		canvas.draw_circle(c, 7.0, TenantTheme.on_primary)
