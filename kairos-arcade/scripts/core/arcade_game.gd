class_name ArcadeGame
extends Node2D
## Base común de los juegos: fases (cuenta atrás, partida, final, abandono), puntaje,
## efectos y HUD. Cada juego implementa los ganchos marcados como "virtual".

enum Phase { COUNTDOWN, PLAYING, ENDING, ABANDONING }

class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 0.4
	var color := Color.WHITE
	var size := 5.0

class Floating:
	var pos := Vector2.ZERO
	var text := ""
	var life := 0.7
	var color := Color.WHITE

const SCREEN := Vector2(1920, 1080)
const DURATION := 60.0
const COUNTDOWN_STEP := 1.0
const COUNTDOWN_STEPS := 3
const ENDING_SECONDS := 1.4
const MAX_PARTICLES := 200

var keeper := ScoreKeeper.new()
var phase := Phase.COUNTDOWN
var elapsed := 0.0
var countdown := float(COUNTDOWN_STEPS) * COUNTDOWN_STEP
var ending_left := 0.0
var end_reason := ""
var abandon_left := 0.0

var _shake := 0.0
var _particles: Array[Particle] = []
var _floating: Array[Floating] = []
var _rng := RandomNumberGenerator.new()
var _hud: GameHud


func _ready() -> void:
	_rng.randomize()
	keeper.changed.connect(func() -> void: ArcadeState.score = keeper.score)
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = GameHud.new()
	_hud.game = self
	layer.add_child(_hud)


func time_left() -> float:
	return maxf(DURATION - elapsed, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and phase in [Phase.COUNTDOWN, Phase.PLAYING]:
		phase = Phase.ABANDONING
		abandon_left = 10.0
		_hud.show_abandon()


func _process(delta: float) -> void:
	_update_effects(delta)
	_visuals(delta)
	match phase:
		Phase.COUNTDOWN:
			_countdown_tick(delta)
			countdown -= delta
			if countdown <= 0.0:
				phase = Phase.PLAYING
				ArcadeState.begin_play()
		Phase.PLAYING:
			elapsed += delta
			_play(delta)
			if phase == Phase.PLAYING:
				if keeper.lives <= 0:
					_end("lives")
				elif elapsed >= DURATION:
					_end("time")
		Phase.ENDING:
			_ending_tick(delta)
			ending_left -= delta
			if ending_left <= 0.0:
				ArcadeState.score = keeper.score
				ArcadeState.finish_game(end_reason)
				Router.to_result()
				set_process(false)
		Phase.ABANDONING:
			abandon_left -= delta
			if abandon_left <= 0.0:
				quit_to_menu()
	queue_redraw()


func _end(reason: String) -> void:
	end_reason = reason
	phase = Phase.ENDING
	ending_left = ENDING_SECONDS
	_on_end()


func resume_game() -> void:
	phase = Phase.PLAYING if ArcadeState.screen == ArcadeState.Screen.PLAYING else Phase.COUNTDOWN


func quit_to_menu() -> void:
	set_process(false)
	Router.to_menu()


# --- Ganchos virtuales ------------------------------------------------------

func _visuals(_delta: float) -> void:
	pass


func _countdown_tick(_delta: float) -> void:
	pass


func _play(_delta: float) -> void:
	pass


func _ending_tick(_delta: float) -> void:
	pass


func _on_end() -> void:
	pass


## Icono de una vida en el HUD. Cada juego dibuja el suyo.
func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var r := Rect2(c - Vector2(20, 20), Vector2(40, 40))
	if full:
		canvas.draw_rect(r, TenantTheme.primary)
	canvas.draw_rect(r, Color.WHITE if full else TenantTheme.TEXT_SECONDARY, false, 3.0)


# --- Efectos compartidos ----------------------------------------------------

func _burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	var n := count / 3 if AppConfig.reduce_motion else count
	for i in n:
		if _particles.size() >= MAX_PARTICLES:
			return
		var p := Particle.new()
		p.pos = at
		p.vel = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.3, 1.0) * speed
		p.max_life = _rng.randf_range(0.25, 0.5)
		p.life = p.max_life
		p.color = color
		p.size = _rng.randf_range(3.0, 7.0)
		_particles.append(p)


func _float_text(at: Vector2, text: String, color: Color) -> void:
	var f := Floating.new()
	f.pos = at
	f.text = text
	f.color = color
	_floating.append(f)


func _update_effects(delta: float) -> void:
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)
	for f in _floating:
		f.life -= delta
		f.pos.y -= 70.0 * delta
	_floating = _floating.filter(func(f: Floating) -> bool: return f.life > 0.0)
	_shake = maxf(_shake - delta, 0.0)
	position = Vector2.ZERO
	if _shake > 0.0 and not AppConfig.reduce_motion:
		position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 14.0 * (_shake / 0.15)


func _draw_particles() -> void:
	for p in _particles:
		draw_rect(Rect2(p.pos - Vector2.ONE * p.size / 2, Vector2.ONE * p.size), Color(p.color, p.life / p.max_life))


func _draw_floating() -> void:
	var font := UiKit.display(800)
	for f in _floating:
		draw_string(font, f.pos - Vector2(100, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 200, 40, Color(f.color, clampf(f.life / 0.4, 0.0, 1.0)))
