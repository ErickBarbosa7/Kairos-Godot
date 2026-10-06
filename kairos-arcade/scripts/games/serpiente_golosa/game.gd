class_name SerpienteGolosa
extends ArcadeGame
## Serpiente Golosa: Snake de 60 s. Come productos, crece y encadena para subir el
## multiplicador. Chocar con la pared o contigo cuesta una vida y reinicia la serpiente.

enum Product { DONUT, COFFEE, COOKIE, CUPCAKE, STAR }

class Item:
	var cell := Vector2i.ZERO
	var kind := 0
	var life := -1.0
	var t := 0.0

const CELL := 54
const COLS := 32
const ROWS := 13
const ORIGIN := Vector2(96, 230)
const START_LENGTH := 3
const REGULAR_ITEMS := 2
const STAR_EVERY := 12.0
const STAR_LIFE := 6.0
const STEP_SLOW := 0.16
const STEP_FAST := 0.075
const CRASH_PAUSE := 0.7
const BLINK_SECONDS := 1.2
const BASE_POINTS := 100
const STAR_POINTS := 300

const DONUT_COLOR := Color("#F472B6")
const COFFEE_COLOR := Color("#F2EBE4")
const COFFEE_DRINK := Color("#7C4A2D")
const COOKIE_COLOR := Color("#D4A15A")
const CUPCAKE_BASE := Color("#60A5FA")
const CUPCAKE_CREAM := Color("#FDA4AF")

var board := SnakeBoard.new(COLS, ROWS)
var _items: Array[Item] = []
var _step_cd := 0.5
var _star_cd := STAR_EVERY
var _blink := 0.0


func _ready() -> void:
	super._ready()
	board.reset(START_LENGTH)
	_fill_items()


func _countdown_tick(_delta: float) -> void:
	_read_input()


func _play(delta: float) -> void:
	_read_input()
	keeper.tick(delta)
	_blink = maxf(_blink - delta, 0.0)
	_update_items(delta)
	_step_cd -= delta
	if _step_cd <= 0.0:
		_step_cd += _step_interval()
		_step()


func _on_end() -> void:
	_burst(_center(board.body[0]), TenantTheme.primary, 40, 420.0)


func _step_interval() -> float:
	var grown := float(board.body.size() - START_LENGTH)
	return lerpf(STEP_SLOW, STEP_FAST, clampf(grown / 25.0, 0.0, 1.0))


func _read_input() -> void:
	if Input.is_action_just_pressed("move_left"):
		board.queue_dir(Vector2i.LEFT)
	elif Input.is_action_just_pressed("move_right"):
		board.queue_dir(Vector2i.RIGHT)
	elif Input.is_action_just_pressed("move_up"):
		board.queue_dir(Vector2i.UP)
	elif Input.is_action_just_pressed("move_down"):
		board.queue_dir(Vector2i.DOWN)


func _step() -> void:
	var item := _item_at(board.peek_head())
	var grow_by := 0
	if item:
		grow_by = 2 if item.kind == Product.STAR else 1
	if board.advance(grow_by) == SnakeBoard.Result.CRASHED:
		_crash()
		return
	if item:
		_eat(item)


func _eat(item: Item) -> void:
	_items.erase(item)
	var star := item.kind == Product.STAR
	var pts := keeper.add_kill(STAR_POINTS if star else BASE_POINTS)
	ArcadeState.add_score(pts)
	var at := _center(item.cell)
	_float_text(at, "+%d" % pts, TenantTheme.REWARD)
	_burst(at, _product_color(item.kind), 16 if star else 10, 300.0)
	if not star:
		_fill_items()


func _crash() -> void:
	var at := _center(board.body[0])
	keeper.hit()
	_shake = 0.15
	_burst(at, TenantTheme.DANGER, 20, 360.0)
	_float_text(at, Strings.SNAKE_CRASH, TenantTheme.DANGER)
	if keeper.lives > 0:
		board.reset(START_LENGTH)
		_step_cd = CRASH_PAUSE
		_blink = BLINK_SECONDS


# --- Productos --------------------------------------------------------------

func _item_at(cell: Vector2i) -> Item:
	for it in _items:
		if it.cell == cell:
			return it
	return null


func _item_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for it in _items:
		cells.append(it.cell)
	return cells


func _regular_count() -> int:
	var n := 0
	for it in _items:
		if it.kind != Product.STAR:
			n += 1
	return n


func _fill_items() -> void:
	while _regular_count() < REGULAR_ITEMS:
		_spawn_item(_rng.randi_range(0, Product.CUPCAKE) as int, -1.0)


func _spawn_item(kind: int, life: float) -> void:
	var cell := board.free_cell(_rng, _item_cells())
	if cell.x < 0:
		return
	var it := Item.new()
	it.cell = cell
	it.kind = kind
	it.life = life
	_items.append(it)


func _update_items(delta: float) -> void:
	for it in _items:
		it.t += delta
		if it.life > 0.0:
			it.life -= delta
	_items = _items.filter(func(it: Item) -> bool: return it.kind != Product.STAR or it.life > 0.0)
	_star_cd -= delta
	if _star_cd <= 0.0:
		_star_cd = STAR_EVERY
		_spawn_item(Product.STAR, STAR_LIFE)


func _product_color(kind: int) -> Color:
	match kind:
		Product.DONUT:
			return DONUT_COLOR
		Product.COFFEE:
			return COFFEE_COLOR
		Product.COOKIE:
			return COOKIE_COLOR
		Product.CUPCAKE:
			return CUPCAKE_CREAM
	return TenantTheme.REWARD


func _center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


# --- Dibujo -----------------------------------------------------------------

func _draw() -> void:
	_draw_board()
	for it in _items:
		_draw_item(it)
	if phase != Phase.ENDING or ending_left > ENDING_SECONDS * 0.6:
		_draw_snake()
	_draw_particles()
	_draw_floating()


func _draw_board() -> void:
	var rect := Rect2(ORIGIN, Vector2(COLS, ROWS) * CELL)
	draw_rect(rect, TenantTheme.NIGHT_RAISED)
	for y in ROWS:
		for x in COLS:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)), Color(1, 1, 1, 0.025))
	draw_rect(rect.grow(4), TenantTheme.NIGHT_LINE, false, 8.0)


func _draw_snake() -> void:
	if _blink > 0.0 and int(_blink * 12.0) % 2 == 0:
		return
	var n := board.body.size()
	for i in range(n - 1, -1, -1):
		var r := Rect2(ORIGIN + Vector2(board.body[i]) * CELL + Vector2(4, 4), Vector2(CELL - 8, CELL - 8))
		var shade := TenantTheme.primary if i % 2 == 0 else TenantTheme.primary.darkened(0.18)
		if i == 0:
			shade = TenantTheme.primary_hover
		draw_rect(r, shade)
		draw_rect(r, TenantTheme.NIGHT if i > 0 else Color.WHITE, false, 3.0)
	_draw_eyes()


func _draw_eyes() -> void:
	var c := _center(board.body[0])
	var d := Vector2(board.dir)
	var side := Vector2(-d.y, d.x)
	for s in [-1.0, 1.0]:
		var eye: Vector2 = c + d * 8.0 + side * s * 10.0
		draw_circle(eye, 7.0, Color.WHITE)
		draw_circle(eye + d * 2.0, 3.5, TenantTheme.NIGHT)


func _draw_item(it: Item) -> void:
	var c := _center(it.cell)
	var bob := sin(it.t * 5.0) * 2.0
	c.y += bob
	match it.kind:
		Product.DONUT:
			draw_circle(c, 21.0, DONUT_COLOR)
			draw_circle(c, 8.0, TenantTheme.NIGHT_RAISED)
			draw_arc(c, 21.0, 0.0, TAU, 24, Color.WHITE, 3.0)
			for a in [0.4, 1.7, 3.0, 4.3, 5.5]:
				draw_rect(Rect2(c + Vector2.from_angle(a) * 14.0 - Vector2(3, 1.5), Vector2(6, 3)), Color.WHITE)
		Product.COFFEE:
			draw_rect(Rect2(c + Vector2(-16, -14), Vector2(32, 30)), COFFEE_COLOR)
			draw_rect(Rect2(c + Vector2(-16, -14), Vector2(32, 9)), COFFEE_DRINK)
			draw_arc(c + Vector2(18, 0), 9.0, -PI / 2, PI / 2, 12, COFFEE_COLOR, 5.0)
			draw_rect(Rect2(c + Vector2(-16, -14), Vector2(32, 30)), TenantTheme.NIGHT, false, 3.0)
			draw_line(c + Vector2(-6, -22), c + Vector2(-6, -30), Color(1, 1, 1, 0.7), 3.0)
			draw_line(c + Vector2(6, -22), c + Vector2(6, -30), Color(1, 1, 1, 0.7), 3.0)
		Product.COOKIE:
			draw_circle(c, 21.0, COOKIE_COLOR)
			draw_arc(c, 21.0, 0.0, TAU, 24, TenantTheme.NIGHT, 3.0)
			for p in [Vector2(-8, -6), Vector2(7, -9), Vector2(2, 6), Vector2(-9, 8), Vector2(11, 5)]:
				draw_circle(c + p, 3.5, COFFEE_DRINK)
		Product.CUPCAKE:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -2), c + Vector2(17, -2), c + Vector2(12, 20), c + Vector2(-12, 20)]), CUPCAKE_BASE)
			draw_circle(c + Vector2(0, -8), 15.0, CUPCAKE_CREAM)
			draw_arc(c + Vector2(0, -8), 15.0, 0.0, TAU, 20, Color.WHITE, 3.0)
			draw_circle(c + Vector2(0, -22), 5.0, TenantTheme.DANGER)
		Product.STAR:
			_draw_star(c, it)


func _draw_star(c: Vector2, it: Item) -> void:
	var pulse := 1.0 + sin(it.t * 9.0) * 0.12
	var points := PackedVector2Array()
	for i in 10:
		var r := (24.0 if i % 2 == 0 else 11.0) * pulse
		points.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * r)
	draw_circle(c, 30.0 * pulse, Color(TenantTheme.REWARD, 0.22))
	draw_colored_polygon(points, TenantTheme.REWARD)
	points.append(points[0])
	draw_polyline(points, Color.WHITE, 3.0)
	# Anillo que se vacía: cuánto falta para que desaparezca.
	var left := clampf(it.life / STAR_LIFE, 0.0, 1.0)
	draw_arc(c, 33.0, -PI / 2, -PI / 2 + TAU * left, 32, Color.WHITE, 4.0)


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var r := Rect2(c - Vector2(20, 20), Vector2(40, 40))
	if full:
		canvas.draw_rect(r, TenantTheme.primary_hover)
		for s in [-1.0, 1.0]:
			canvas.draw_circle(c + Vector2(8, s * 8), 5.0, Color.WHITE)
			canvas.draw_circle(c + Vector2(10, s * 8), 2.5, TenantTheme.NIGHT)
	canvas.draw_rect(r, Color.WHITE if full else TenantTheme.TEXT_SECONDARY, false, 3.0)
