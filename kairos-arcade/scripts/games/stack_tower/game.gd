class_name StackTower
extends ArcadeGame
## Stack Tower: fija bloques móviles sobre la torre. El sobrante se recorta; no
## alcanzar el bloque anterior cuesta una vida. No hay límite de tiempo.

class Block:
	var x := 0.0
	var y := 0.0
	var width := 0.0
	var color := Color.WHITE

const BASE_Y := 902.0
const BLOCK_HEIGHT := 48.0
const START_WIDTH := 470.0
const MIN_X := 160.0
const MAX_X := 1760.0
const BASE_SPEED := 480.0
const POINTS_PER_BLOCK := 250
const BLOCKS_PER_SECTION := 11

var _stack: Array[Block] = []
var _moving: Block
var _direction := 1.0
var _placed_total := 0
var _perfect_flash := 0.0


func _ready() -> void:
	super._ready()
	_reset_tower()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if phase != Phase.PLAYING or not event.is_action_pressed("confirm"):
		return
	_place_block()
	get_viewport().set_input_as_handled()


func _play(delta: float) -> void:
	keeper.tick(delta)
	_perfect_flash = maxf(_perfect_flash - delta, 0.0)
	_move_block(delta)


func _ending_tick(delta: float) -> void:
	_move_block(delta)


func _on_end() -> void:
	_burst(Vector2(SCREEN.x / 2.0, BASE_Y), TenantTheme.primary, 42, 460.0)


func _reset_tower() -> void:
	_stack.clear()
	var base := Block.new()
	base.width = START_WIDTH
	base.x = SCREEN.x / 2.0
	base.y = BASE_Y
	base.color = TenantTheme.primary
	_stack.append(base)
	_new_moving_block()


func _new_moving_block() -> void:
	var target: Block = _stack.back()
	_moving = Block.new()
	_moving.width = target.width
	_moving.y = target.y - BLOCK_HEIGHT
	_moving.x = MIN_X + _moving.width / 2.0 if _direction > 0.0 else MAX_X - _moving.width / 2.0
	_moving.color = _next_color()
	_direction *= -1.0


func _move_block(delta: float) -> void:
	if _moving == null:
		return
	var speed := BASE_SPEED + minf(float(_placed_total) * 24.0, 380.0)
	_moving.x += _direction * speed * delta
	var half := _moving.width / 2.0
	if _moving.x - half <= MIN_X:
		_moving.x = MIN_X + half
		_direction = 1.0
	elif _moving.x + half >= MAX_X:
		_moving.x = MAX_X - half
		_direction = -1.0


func _place_block() -> void:
	var target: Block = _stack.back()
	var left := maxf(_moving.x - _moving.width / 2.0, target.x - target.width / 2.0)
	var right := minf(_moving.x + _moving.width / 2.0, target.x + target.width / 2.0)
	var overlap := right - left
	if overlap <= 0.0:
		_miss()
		return
	var perfect := absf(_moving.x - target.x) < 10.0
	_moving.width = overlap
	_moving.x = (left + right) / 2.0
	_stack.append(_moving)
	_placed_total += 1
	var points := keeper.add_kill(POINTS_PER_BLOCK + (100 if perfect else 0))
	ArcadeState.add_score(points)
	var at := Vector2(_moving.x, _moving.y)
	_float_text(at - Vector2(0, 42), "+%d" % points, TenantTheme.REWARD)
	_burst(at, _moving.color, 16 if perfect else 9, 260.0)
	if perfect:
		_perfect_flash = 0.32
		_float_text(at - Vector2(0, 82), Strings.TOWER_PERFECT, TenantTheme.SUCCESS)
	if _stack.size() >= BLOCKS_PER_SECTION:
		_float_text(Vector2(SCREEN.x / 2.0, 330), Strings.TOWER_SECTION, TenantTheme.SUCCESS)
		_reset_tower()
	else:
		_new_moving_block()


func _miss() -> void:
	var at := Vector2(_moving.x, _moving.y)
	_burst(at, TenantTheme.DANGER, 20, 340.0)
	_float_text(at - Vector2(0, 50), Strings.TOWER_MISS, TenantTheme.DANGER)
	keeper.hit()
	_shake = 0.15
	if keeper.lives <= 0:
		_end("lives")
		return
	_reset_tower()


func _next_color() -> Color:
	var colors := [TenantTheme.primary, TenantTheme.REWARD, TenantTheme.SUCCESS, TenantTheme.DANGER]
	return colors[_placed_total % colors.size()]


func _draw() -> void:
	_draw_background()
	for block in _stack:
		_draw_block(block)
	if _moving and (phase != Phase.ENDING or ending_left > ENDING_SECONDS * 0.55):
		_draw_block(_moving, true)
	_draw_particles()
	_draw_floating()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), TenantTheme.NIGHT)
	for y in range(300, 1000, 80):
		draw_line(Vector2(180, y), Vector2(SCREEN.x - 180, y), Color(TenantTheme.TEXT, 0.035), 2.0)
	var display := UiKit.display(900)
	draw_string(display, Vector2(0, 220), Strings.TOWER_TITLE, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 82, TenantTheme.TEXT)
	draw_string(UiKit.text(700), Vector2(0, 270), Strings.TOWER_HINT, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, 30, TenantTheme.TEXT_SECONDARY)
	if _perfect_flash > 0.0:
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Color(TenantTheme.SUCCESS, _perfect_flash * 0.16))


func _draw_block(block: Block, moving: bool = false) -> void:
	var rect := Rect2(block.x - block.width / 2.0, block.y - BLOCK_HEIGHT / 2.0, block.width, BLOCK_HEIGHT)
	draw_rect(rect, block.color)
	draw_rect(rect, Color.WHITE if moving else TenantTheme.NIGHT, false, 4.0)
	if moving:
		draw_line(Vector2(rect.position.x, rect.position.y - 14), Vector2(rect.end.x, rect.position.y - 14), TenantTheme.TEXT_SECONDARY, 2.0)


func draw_life(canvas: CanvasItem, c: Vector2, full: bool) -> void:
	var rect := Rect2(c - Vector2(26, 16), Vector2(52, 32))
	if full:
		canvas.draw_rect(rect, TenantTheme.primary)
	canvas.draw_rect(rect, Color.WHITE if full else TenantTheme.TEXT_SECONDARY, false, 3.0)
