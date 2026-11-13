class_name LaneRacer
extends ArcadeGame
## Lane Racer: cambia de carril para evitar el tráfico y rebasa vehículos.

class TrafficCar:
	var lane := 0
	var y := 0.0
	var speed := 0.0
	var color := Color.WHITE

const ROAD := Rect2(414, 292, 1092, 706)
const LANES := 4
const CAR_Y := 822.0
const PLAYER_W := 118.0
const PLAYER_H := 178.0
const TRAFFIC_W := 108.0
const TRAFFIC_H := 164.0
const LANE_CHANGE_SPEED := 1800.0
const START_INTERVAL := 1.08
const END_INTERVAL := 0.43
const INVULNERABLE_SECONDS := 1.35
const PASS_POINTS := 100

var _player_lane := 1
var _player_x := 0.0
var _traffic: Array[TrafficCar] = []
var _spawn_left := 1.0
var _invulnerable := 0.0
var _road_offset := 0.0
var _passed_count := 0


func _ready() -> void:
	super._ready()
	_player_x = _lane_x(_player_lane)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if phase not in [Phase.COUNTDOWN, Phase.PLAYING]:
		return
	if event.is_action_pressed("move_left"):
		_player_lane = maxi(_player_lane - 1, 0)
	elif event.is_action_pressed("move_right"):
		_player_lane = mini(_player_lane + 1, LANES - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _countdown_tick(delta: float) -> void:
	_move_player(delta)


func _play(delta: float) -> void:
	keeper.tick(delta)
	_move_player(delta)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_road_offset = fmod(_road_offset + _traffic_speed() * delta, 92.0)
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_traffic()
		_spawn_left = lerpf(START_INTERVAL, END_INTERVAL, _difficulty())
	_move_traffic(delta)


func _ending_tick(delta: float) -> void:
	_move_player(delta)
	for car in _traffic:
		car.y += car.speed * delta


func _on_end() -> void:
	_burst(Vector2(_player_x, CAR_Y), TenantTheme.primary, 36, 420.0)


func _move_player(delta: float) -> void:
	_player_x = move_toward(_player_x, _lane_x(_player_lane), LANE_CHANGE_SPEED * delta)


func _traffic_speed() -> float:
	return lerpf(470.0, 780.0, _difficulty())


func _difficulty() -> float:
	return clampf(float(_passed_count) / 52.0, 0.0, 1.0)


func _spawn_traffic() -> void:
	var candidates: Array[int] = []
	for lane in LANES:
		var clear := true
		for car in _traffic:
			if car.lane == lane and car.y < 260.0:
				clear = false
		if clear:
			candidates.append(lane)
	if candidates.is_empty():
		return
	var car := TrafficCar.new()
	car.lane = candidates[_rng.randi_range(0, candidates.size() - 1)]
	car.y = -TRAFFIC_H
	car.speed = _traffic_speed() * _rng.randf_range(0.88, 1.15)
	var colors := [TenantTheme.REWARD, TenantTheme.SUCCESS, TenantTheme.DANGER, TenantTheme.TEXT_SECONDARY]
	car.color = colors[_rng.randi_range(0, colors.size() - 1)]
	_traffic.append(car)


func _move_traffic(delta: float) -> void:
	for car in _traffic.duplicate():
		car.y += car.speed * delta
		if car.y > SCREEN.y + TRAFFIC_H:
			_traffic.erase(car)
			_passed(car)
			continue
		if _invulnerable <= 0.0 and _collides(car):
			_traffic.erase(car)
			_hit()


func _passed(car: TrafficCar) -> void:
	_passed_count += 1
	var points := keeper.add_kill(PASS_POINTS)
	ArcadeState.add_score(points)
	_float_text(Vector2(_lane_x(car.lane), SCREEN.y - 134), "+%d" % points, TenantTheme.REWARD)
	_burst(Vector2(_lane_x(car.lane), SCREEN.y - 100), car.color, 10, 240.0)


func _hit() -> void:
	keeper.hit()
	_invulnerable = INVULNERABLE_SECONDS
	_shake = 0.15
	_burst(Vector2(_player_x, CAR_Y), TenantTheme.DANGER, 24, 380.0)
	_float_text(Vector2(_player_x, CAR_Y - 130), Strings.RACER_CRASH, TenantTheme.DANGER)


func _collides(car: TrafficCar) -> bool:
	return absf(_lane_x(car.lane) - _player_x) < (PLAYER_W + TRAFFIC_W) * 0.42 and absf(car.y - CAR_Y) < (PLAYER_H + TRAFFIC_H) * 0.42


func _lane_x(lane: int) -> float:
	return ROAD.position.x + ROAD.size.x * (float(lane) + 0.5) / LANES


func _draw() -> void:
	_draw_road()
	for car in _traffic:
		_draw_car(Vector2(_lane_x(car.lane), car.y), TRAFFIC_W, TRAFFIC_H, car.color, false)
	if phase != Phase.ENDING or ending_left > ENDING_SECONDS * 0.55:
		_draw_car(Vector2(_player_x, CAR_Y), PLAYER_W, PLAYER_H, TenantTheme.primary, true)
	_draw_particles()
	_draw_floating()


func _draw_road() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), TenantTheme.NIGHT)
	draw_rect(ROAD, TenantTheme.NIGHT_RAISED)
	draw_rect(ROAD, TenantTheme.TEXT_SECONDARY, false, 7.0)
	for lane in range(1, LANES):
		var x := ROAD.position.x + ROAD.size.x * lane / LANES
		for y in range(-92, int(SCREEN.y + 92), 92):
			draw_rect(Rect2(x - 5, y + _road_offset, 10, 48), TenantTheme.TEXT_SECONDARY)
	for y in range(int(ROAD.position.y) + 48, int(ROAD.end.y), 120):
		draw_circle(Vector2(250, y), 5.0, Color(TenantTheme.REWARD, 0.45))
		draw_circle(Vector2(SCREEN.x - 250, y), 5.0, Color(TenantTheme.REWARD, 0.45))
	var display := UiKit.display(900)
	draw_string(display, Vector2(0, 190), Strings.RACER_TITLE, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 82, TenantTheme.TEXT)
	draw_string(UiKit.text(700), Vector2(0, 242), Strings.RACER_HINT, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 30, TenantTheme.TEXT_SECONDARY)


func _draw_car(c: Vector2, width: float, height: float, color: Color, player: bool) -> void:
	if player and _invulnerable > 0.0 and int(_invulnerable * 12.0) % 2 == 0:
		return
	var body := Rect2(c - Vector2(width / 2.0, height / 2.0), Vector2(width, height))
	draw_rect(body, color)
	draw_rect(body, Color.WHITE, false, 5.0)
	var windshield := Rect2(c + Vector2(-width * 0.27, -height * 0.26), Vector2(width * 0.54, height * 0.28))
	draw_rect(windshield, TenantTheme.NIGHT)
	for side in [-1.0, 1.0]:
		var wheel := Rect2(c + Vector2(side * width * 0.48 - 10, -height * 0.27), Vector2(20, height * 0.54))
		draw_rect(wheel, TenantTheme.NIGHT)
	var lights_color := TenantTheme.REWARD if player else Color.WHITE
	draw_rect(Rect2(c + Vector2(-width * 0.29, -height * 0.44), Vector2(width * 0.18, 13)), lights_color)
	draw_rect(Rect2(c + Vector2(width * 0.11, -height * 0.44), Vector2(width * 0.18, 13)), lights_color)


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var width := 32.0
	var height := 46.0
	var body := Rect2(c - Vector2(width / 2.0, height / 2.0), Vector2(width, height))
	if full:
		canvas.draw_rect(body, TenantTheme.primary)
	canvas.draw_rect(body, Color.WHITE if full else TenantTheme.TEXT_SECONDARY, false, 3.0)
