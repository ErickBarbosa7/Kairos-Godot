class_name RutaNebular
extends ArcadeGame
## Ruta Nebular: brick breaker de oleadas. La esfera rebota en la barra y elimina
## bloques; al caer pierde una vida. No tiene límite de tiempo.

class Brick:
	var rect := Rect2()
	var color := Color.WHITE

const FIELD := Rect2(214, 300, 1492, 700)
const PADDLE_Y := 910.0
const PADDLE_WIDTH := 260.0
const PADDLE_HEIGHT := 32.0
const BALL_RADIUS := 17.0
const PADDLE_SPEED := 1050.0
const BRICK_ROWS := 6
const BRICK_COLS := 10
const BRICK_GAP := 10.0
const BRICK_HEIGHT := 48.0
const BRICK_POINTS := 150

var _paddle_x := SCREEN.x / 2.0
var _ball := Vector2.ZERO
var _velocity := Vector2.ZERO
var _bricks: Array[Brick] = []
var _wave := 1
var _trail: Array[Vector2] = []


func _ready() -> void:
	super._ready()
	_new_wave()


func _countdown_tick(delta: float) -> void:
	_move_paddle(delta)


func _play(delta: float) -> void:
	keeper.tick(delta)
	_move_paddle(delta)
	_move_ball(delta)


func _ending_tick(delta: float) -> void:
	_move_ball(delta)


func _on_end() -> void:
	_burst(_ball, TenantTheme.primary, 42, 440.0)


func _move_paddle(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	_paddle_x = clampf(_paddle_x + direction * PADDLE_SPEED * delta, FIELD.position.x + PADDLE_WIDTH / 2.0, FIELD.end.x - PADDLE_WIDTH / 2.0)


func _move_ball(delta: float) -> void:
	_trail.push_front(_ball)
	if _trail.size() > 10:
		_trail.pop_back()
	_ball += _velocity * delta
	_bounce_walls()
	_bounce_paddle()
	_hit_brick()
	if _ball.y - BALL_RADIUS > FIELD.end.y:
		_lose_ball()


func _bounce_walls() -> void:
	if _ball.x - BALL_RADIUS <= FIELD.position.x:
		_ball.x = FIELD.position.x + BALL_RADIUS
		_velocity.x = absf(_velocity.x)
	elif _ball.x + BALL_RADIUS >= FIELD.end.x:
		_ball.x = FIELD.end.x - BALL_RADIUS
		_velocity.x = -absf(_velocity.x)
	if _ball.y - BALL_RADIUS <= FIELD.position.y:
		_ball.y = FIELD.position.y + BALL_RADIUS
		_velocity.y = absf(_velocity.y)


func _bounce_paddle() -> void:
	if _velocity.y <= 0.0:
		return
	var paddle := _paddle_rect()
	if not _circle_hits_rect(_ball, BALL_RADIUS, paddle):
		return
	_ball.y = paddle.position.y - BALL_RADIUS
	var offset := (_ball.x - _paddle_x) / (PADDLE_WIDTH / 2.0)
	var speed := _velocity.length()
	_velocity = Vector2(offset * speed * 0.78, -absf(speed * (1.0 - absf(offset) * 0.20))).normalized() * speed
	_burst(_ball, TenantTheme.primary, 6, 170.0)


func _hit_brick() -> void:
	for brick in _bricks.duplicate():
		if not _circle_hits_rect(_ball, BALL_RADIUS, brick.rect):
			continue
		_bricks.erase(brick)
		_velocity.y *= -1.0
		var points := keeper.add_kill(BRICK_POINTS)
		ArcadeState.add_score(points)
		_float_text(brick.rect.get_center(), "+%d" % points, TenantTheme.REWARD)
		_burst(brick.rect.get_center(), brick.color, 14, 290.0)
		if _bricks.is_empty():
			_wave += 1
			_float_text(Vector2(SCREEN.x / 2.0, 330), Strings.NEBULA_WAVE % _wave, TenantTheme.SUCCESS)
			_new_wave()
		return


func _lose_ball() -> void:
	if phase != Phase.PLAYING:
		# Ya terminó la partida: la esfera sigue cayendo pero no cuesta otra vida.
		_velocity = Vector2.ZERO
		return
	keeper.hit()
	_shake = 0.15
	_float_text(Vector2(_paddle_x, PADDLE_Y - 80), Strings.NEBULA_LOST, TenantTheme.DANGER)
	_burst(Vector2(_paddle_x, PADDLE_Y), TenantTheme.DANGER, 22, 350.0)
	if keeper.lives <= 0:
		_end("lives")
		return
	_reset_ball()


func _new_wave() -> void:
	_bricks.clear()
	var inner_width := FIELD.size.x - 2.0 * BRICK_GAP
	var brick_width := (inner_width - BRICK_GAP * (BRICK_COLS - 1)) / BRICK_COLS
	var colors := [TenantTheme.primary, TenantTheme.REWARD, TenantTheme.SUCCESS, TenantTheme.DANGER]
	for row in BRICK_ROWS:
		for col in BRICK_COLS:
			var brick := Brick.new()
			brick.rect = Rect2(FIELD.position.x + BRICK_GAP + col * (brick_width + BRICK_GAP), FIELD.position.y + 58 + row * (BRICK_HEIGHT + BRICK_GAP), brick_width, BRICK_HEIGHT)
			brick.color = colors[(row + col + _wave) % colors.size()]
			_bricks.append(brick)
	_reset_ball()


func _reset_ball() -> void:
	_paddle_x = SCREEN.x / 2.0
	_ball = Vector2(_paddle_x, PADDLE_Y - 72)
	var speed := 640.0 + minf(float(_wave - 1) * 52.0, 280.0)
	_velocity = Vector2(0.42, -0.91).normalized() * speed
	_trail.clear()


func _paddle_rect() -> Rect2:
	return Rect2(_paddle_x - PADDLE_WIDTH / 2.0, PADDLE_Y - PADDLE_HEIGHT / 2.0, PADDLE_WIDTH, PADDLE_HEIGHT)


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) <= radius * radius


func _draw() -> void:
	_draw_field()
	for brick in _bricks:
		draw_rect(brick.rect, brick.color)
		draw_rect(brick.rect, TenantTheme.NIGHT, false, 3.0)
	_draw_trail()
	draw_circle(_ball, BALL_RADIUS, TenantTheme.TEXT)
	draw_circle(_ball, BALL_RADIUS, TenantTheme.NIGHT, false, 3.0)
	var paddle := _paddle_rect()
	draw_rect(paddle, TenantTheme.primary)
	draw_rect(paddle, Color.WHITE, false, 4.0)
	_draw_particles()
	_draw_floating()


func _draw_field() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), TenantTheme.NIGHT)
	draw_rect(FIELD, TenantTheme.NIGHT_RAISED)
	draw_rect(FIELD, TenantTheme.TEXT_SECONDARY, false, 6.0)
	for x in range(int(FIELD.position.x) + 60, int(FIELD.end.x), 90):
		for y in range(int(FIELD.position.y) + 40, int(FIELD.end.y), 120):
			draw_circle(Vector2(x, y), 2.0, Color(TenantTheme.TEXT, 0.18))
	var display := UiKit.display(900)
	draw_string(display, Vector2(0, 220), Strings.NEBULA_TITLE, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 82, TenantTheme.TEXT)
	draw_string(UiKit.text(700), Vector2(0, 270), Strings.NEBULA_HINT, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 30, TenantTheme.TEXT_SECONDARY)
	draw_string(UiKit.text(700), Vector2(0, 1038), Strings.NEBULA_WAVE % _wave, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 28, TenantTheme.TEXT_SECONDARY)


func _draw_trail() -> void:
	for i in _trail.size():
		var alpha := 0.30 * (1.0 - float(i) / _trail.size())
		draw_circle(_trail[i], BALL_RADIUS * (1.0 - float(i) * 0.06), Color(TenantTheme.TEXT, alpha))


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	if full:
		canvas.draw_circle(c, 18.0, TenantTheme.primary)
	canvas.draw_circle(c, 18.0, Color.WHITE if full else TenantTheme.TEXT_SECONDARY, false, 4.0)
	canvas.draw_line(c + Vector2(-28, 23), c + Vector2(28, 23), TenantTheme.TEXT_SECONDARY, 4.0)
