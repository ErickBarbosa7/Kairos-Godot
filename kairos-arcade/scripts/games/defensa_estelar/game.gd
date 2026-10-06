class_name DefensaEstelar
extends ArcadeGame
## Defensa Estelar: shooter espacial de 60 s. Toda la lógica y el dibujo viven aquí;
## puntaje, racha y dificultad están en clases aparte (ScoreKeeper, WaveDirector).
## No hay nodos por entidad: son datos en arreglos y se dibujan con formas.

enum Kind { DRONE, SHOOTER, SPECIAL }

class Ent:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var hp := 1
	var kind := 0
	var t := 0.0
	var radius := 20.0
	var flash := 0.0
	var base_x := 0.0
	var amp := 0.0
	var phase := 0.0
	var cooldown := 0.0

const SHIP_Y := 960.0
const SHIP_SPEED := 900.0
const SHIP_MIN_X := 96.0
const SHIP_MAX_X := 1824.0
const SHIP_HITBOX := 16.0
const FIRE_INTERVAL := 0.2
const BULLET_SPEED := 1400.0
const INVULNERABLE_SECONDS := 1.5
const CORE_CHANCE := 0.25

const ENEMY_BULLET := Color("#FF3D9A")
const DRONE_COLOR := Color("#2DD4BF")
const SHOOTER_COLOR := Color("#A78BFA")
const SPECIAL_COLOR := Color("#E879F9")

var ship_x := SCREEN.x / 2
var invulnerable := 0.0
var _fire_cd := 0.0
var _spawn_cd := 1.0
var _special_spawned := false
var _enemies: Array[Ent] = []
var _bullets: Array[Ent] = []
var _enemy_bullets: Array[Ent] = []
var _cores: Array[Ent] = []
var _stars: Array[Vector3] = []


func _ready() -> void:
	super._ready()
	for i in 90:
		_stars.append(Vector3(_rng.randf() * SCREEN.x, _rng.randf() * SCREEN.y, _rng.randf_range(0.3, 1.0)))


func _visuals(delta: float) -> void:
	_update_stars(delta)


func _countdown_tick(delta: float) -> void:
	_move_ship(delta)


func _ending_tick(delta: float) -> void:
	_move_entities(delta)


func _on_end() -> void:
	_burst(Vector2(ship_x, SHIP_Y), TenantTheme.primary, 40, 420.0)


func _play(delta: float) -> void:
	invulnerable = maxf(invulnerable - delta, 0.0)
	keeper.tick(delta)
	_move_ship(delta)
	_fire(delta)
	_spawn(delta)
	_move_entities(delta)
	_collide()


# --- Entrada y nave ---------------------------------------------------------

func _move_ship(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	ship_x = clampf(ship_x + dir * SHIP_SPEED * delta, SHIP_MIN_X, SHIP_MAX_X)


func _fire(delta: float) -> void:
	_fire_cd -= delta
	if Input.is_action_pressed("fire") and _fire_cd <= 0.0:
		_fire_cd = FIRE_INTERVAL
		var b := Ent.new()
		b.pos = Vector2(ship_x, SHIP_Y - 44)
		b.vel = Vector2(0, -BULLET_SPEED)
		b.radius = 10.0
		_bullets.append(b)
		_burst(b.pos, TenantTheme.TEXT, 3, 160.0)


# --- Generación -------------------------------------------------------------

func _spawn(delta: float) -> void:
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	_spawn_cd = WaveDirector.spawn_interval(elapsed)
	if WaveDirector.in_final_burst(elapsed):
		_spawn_core(Vector2(_rng.randf_range(160, 1760), -40))
	var e := Ent.new()
	e.base_x = _rng.randf_range(200, 1720)
	e.pos = Vector2(e.base_x, -60)
	e.phase = _rng.randf() * TAU
	e.amp = _rng.randf_range(40, 140)
	var speed := WaveDirector.enemy_speed(elapsed)
	if elapsed >= WaveDirector.SPECIAL_AT and not _special_spawned:
		_special_spawned = true
		e.kind = Kind.SPECIAL
		e.hp = 5
		e.radius = 52.0
		e.vel.y = speed * 0.5
		e.amp = 120.0
	elif _rng.randf() < WaveDirector.shooter_ratio(elapsed):
		e.kind = Kind.SHOOTER
		e.radius = 30.0
		e.vel.y = speed * 0.8
		e.cooldown = _rng.randf_range(0.6, 1.4)
	else:
		e.kind = Kind.DRONE
		e.radius = 26.0
		e.vel.y = speed
	_enemies.append(e)


func _spawn_core(at: Vector2) -> void:
	var c := Ent.new()
	c.pos = at
	c.vel = Vector2(0, 260)
	c.radius = 22.0
	_cores.append(c)


# --- Movimiento -------------------------------------------------------------

func _move_entities(delta: float) -> void:
	for b in _bullets:
		b.pos += b.vel * delta
	_bullets = _bullets.filter(func(b: Ent) -> bool: return b.pos.y > -60)

	for e in _enemies:
		e.t += delta
		e.flash = maxf(e.flash - delta, 0.0)
		e.pos.y += e.vel.y * delta
		e.pos.x = e.base_x + sin(e.t * 1.6 + e.phase) * e.amp
		if e.kind != Kind.DRONE and phase == Phase.PLAYING:
			e.cooldown -= delta
			if e.cooldown <= 0.0 and e.pos.y > 40 and e.pos.y < SHIP_Y - 200:
				e.cooldown = WaveDirector.fire_interval(elapsed) * (0.6 if e.kind == Kind.SPECIAL else 1.0)
				_enemy_shoot(e)
	_enemies = _enemies.filter(func(e: Ent) -> bool: return e.pos.y < SCREEN.y + 80)

	for b in _enemy_bullets:
		b.pos += b.vel * delta
	_enemy_bullets = _enemy_bullets.filter(func(b: Ent) -> bool: return b.pos.y < SCREEN.y + 60 and b.pos.x > -60 and b.pos.x < SCREEN.x + 60)

	for c in _cores:
		c.t += delta
		c.pos += c.vel * delta
	_cores = _cores.filter(func(c: Ent) -> bool: return c.pos.y < SCREEN.y + 60)


func _enemy_shoot(e: Ent) -> void:
	var b := Ent.new()
	b.pos = e.pos + Vector2(0, e.radius)
	var dir := (Vector2(ship_x, SHIP_Y) - b.pos).normalized()
	b.vel = dir * 360.0
	b.radius = 12.0
	_enemy_bullets.append(b)


# --- Colisiones -------------------------------------------------------------

func _collide() -> void:
	var ship := Vector2(ship_x, SHIP_Y)

	for b in _bullets.duplicate():
		for e in _enemies:
			if b.pos.distance_to(e.pos) < b.radius + e.radius:
				_bullets.erase(b)
				_damage_enemy(e)
				break

	for b in _enemy_bullets.duplicate():
		if b.pos.distance_to(ship) < b.radius + SHIP_HITBOX:
			_enemy_bullets.erase(b)
			_player_hit()

	for e in _enemies.duplicate():
		if e.pos.distance_to(ship) < e.radius * 0.8 + SHIP_HITBOX:
			_enemies.erase(e)
			_burst(e.pos, _enemy_color(e), 14, 300.0)
			_player_hit()

	for c in _cores.duplicate():
		if c.pos.distance_to(ship) < c.radius + 40.0:
			_cores.erase(c)
			var pts := keeper.add_bonus(150)
			ArcadeState.add_score(pts)
			_float_text(c.pos, "+%d" % pts, TenantTheme.REWARD)
			_burst(c.pos, TenantTheme.REWARD, 12, 260.0)


func _damage_enemy(e: Ent) -> void:
	e.hp -= 1
	e.flash = 0.06
	_burst(e.pos, TenantTheme.TEXT, 4, 200.0)
	if e.hp > 0:
		return
	_enemies.erase(e)
	var base := 100
	if e.kind == Kind.SHOOTER:
		base = 200
	elif e.kind == Kind.SPECIAL:
		base = 600
	var pts := keeper.add_kill(base)
	ArcadeState.add_score(pts)
	_float_text(e.pos, "+%d" % pts, TenantTheme.REWARD)
	_burst(e.pos, _enemy_color(e), 24 if e.kind == Kind.SPECIAL else 14, 340.0)
	if e.kind == Kind.SPECIAL:
		_shake = 0.15
	if _rng.randf() < CORE_CHANCE or e.kind == Kind.SPECIAL:
		_spawn_core(e.pos)


func _player_hit() -> void:
	if invulnerable > 0.0:
		return
	if keeper.lives == 1 and not WaveDirector.can_take_last_life(elapsed):
		# Margen de gracia: en los primeros segundos no se pierde la última vida.
		invulnerable = INVULNERABLE_SECONDS
		return
	keeper.hit()
	invulnerable = INVULNERABLE_SECONDS
	_shake = 0.15
	_burst(Vector2(ship_x, SHIP_Y), TenantTheme.DANGER, 18, 360.0)


func _enemy_color(e: Ent) -> Color:
	match e.kind:
		Kind.SHOOTER:
			return SHOOTER_COLOR
		Kind.SPECIAL:
			return SPECIAL_COLOR
	return DRONE_COLOR


func _update_stars(delta: float) -> void:
	if AppConfig.reduce_motion:
		return
	for i in _stars.size():
		var s := _stars[i]
		s.y += 40.0 * s.z * delta
		if s.y > SCREEN.y:
			s.y = 0.0
			s.x = _rng.randf() * SCREEN.x
		_stars[i] = s


# --- Dibujo -----------------------------------------------------------------

func _draw() -> void:
	for s in _stars:
		draw_circle(Vector2(s.x, s.y), 1.0 + s.z * 1.6, Color(TenantTheme.TEXT, 0.15 + s.z * 0.35))

	for c in _cores:
		_draw_core(c)
	for e in _enemies:
		_draw_enemy(e)
	for b in _enemy_bullets:
		_draw_enemy_bullet(b)
	for b in _bullets:
		draw_rect(Rect2(b.pos + Vector2(-5, -22), Vector2(10, 44)), TenantTheme.primary)
		draw_rect(Rect2(b.pos + Vector2(-2, -22), Vector2(4, 44)), Color.WHITE)
	_draw_particles()
	if phase != Phase.ENDING or ending_left > ENDING_SECONDS * 0.7:
		_draw_ship()
	_draw_floating()


func _draw_ship() -> void:
	if invulnerable > 0.0 and int(invulnerable * 12.0) % 2 == 0:
		return
	var c := Vector2(ship_x, SHIP_Y)
	var flame := 18.0 + _rng.randf() * 10.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 30), c + Vector2(10, 30), c + Vector2(0, 30 + flame)]), TenantTheme.REWARD)
	var body := PackedVector2Array([c + Vector2(0, -46), c + Vector2(40, 34), c + Vector2(0, 16), c + Vector2(-40, 34)])
	draw_colored_polygon(body, TenantTheme.primary)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), Color.WHITE, 4.0)


func _draw_enemy(e: Ent) -> void:
	var col := Color.WHITE if e.flash > 0.0 else _enemy_color(e)
	var r := e.radius
	match e.kind:
		Kind.DRONE:
			var d := PackedVector2Array([e.pos + Vector2(0, -r), e.pos + Vector2(r, 0), e.pos + Vector2(0, r), e.pos + Vector2(-r, 0)])
			draw_colored_polygon(d, col)
			draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), TenantTheme.NIGHT, 4.0)
			draw_circle(e.pos, r * 0.25, TenantTheme.NIGHT)
		Kind.SHOOTER:
			var h := PackedVector2Array()
			for i in 6:
				h.append(e.pos + Vector2.from_angle(PI / 6 + i * TAU / 6) * r)
			draw_colored_polygon(h, col)
			h.append(h[0])
			draw_polyline(h, TenantTheme.NIGHT, 4.0)
			draw_rect(Rect2(e.pos + Vector2(-5, 0), Vector2(10, r + 8)), TenantTheme.NIGHT)
		Kind.SPECIAL:
			var o := PackedVector2Array()
			for i in 8:
				o.append(e.pos + Vector2.from_angle(PI / 8 + i * TAU / 8 + e.t * 0.5) * r)
			draw_colored_polygon(o, col)
			o.append(o[0])
			draw_polyline(o, Color.WHITE, 5.0)
			draw_circle(e.pos, r * 0.35, TenantTheme.NIGHT)
			draw_circle(e.pos, r * 0.16, TenantTheme.REWARD)


func _draw_enemy_bullet(b: Ent) -> void:
	var r := b.radius
	var d := PackedVector2Array([b.pos + Vector2(0, -r * 1.3), b.pos + Vector2(r * 0.8, 0), b.pos + Vector2(0, r * 1.3), b.pos + Vector2(-r * 0.8, 0)])
	draw_colored_polygon(d, ENEMY_BULLET)
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color.WHITE, 3.0)


func _draw_core(c: Ent) -> void:
	var pulse := 1.0 + sin(c.t * 8.0) * 0.12
	draw_circle(c.pos, c.radius * pulse + 6.0, Color(TenantTheme.REWARD, 0.25))
	draw_circle(c.pos, c.radius * pulse, TenantTheme.REWARD)
	draw_arc(c.pos, c.radius * pulse, 0.0, TAU, 24, Color.WHITE, 3.0)
	draw_circle(c.pos, c.radius * 0.4, TenantTheme.NIGHT)


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var body := PackedVector2Array([c + Vector2(0, -26), c + Vector2(24, 20), c + Vector2(0, 9), c + Vector2(-24, 20)])
	var outline := PackedVector2Array([body[0], body[1], body[2], body[3], body[0]])
	if full:
		canvas.draw_colored_polygon(body, TenantTheme.primary)
		canvas.draw_polyline(outline, Color.WHITE, 3.0)
	else:
		canvas.draw_polyline(outline, TenantTheme.TEXT_SECONDARY, 3.0)
