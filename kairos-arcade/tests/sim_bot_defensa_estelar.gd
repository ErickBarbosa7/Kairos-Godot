extends RefCounted
## Bot de Defensa Estelar para balancear. skill: casual | medio | bueno.
## Solo lo usa la simulación de balance; no forma parte del juego.

var skill: String
var _dir := 0
var _next_think := 0.0
var _t := 0.0
var _wander_x := 960.0
var _rng := RandomNumberGenerator.new()


func _init(level: String) -> void:
	skill = level
	_rng.randomize()


func release() -> void:
	for a in ["move_left", "move_right", "fire"]:
		Input.action_release(a)


func think(game, delta: float) -> void:
	_t += delta
	Input.action_press("fire")
	if _t < _next_think:
		_apply(game)
		return
	match skill:
		"casual":
			_next_think = _t + 0.5
			if _rng.randf() < 0.5:
				_wander_x = _rng.randf_range(150, 1770)
			_dir = signi(int(_wander_x - game.ship_x)) if absf(_wander_x - game.ship_x) > 40 else 0
		"medio":
			_next_think = _t + 0.28
			_dir = _smart(game, 0.55)
		_:
			_next_think = _t + 0.1
			_dir = _smart(game, 0.95)
	_apply(game)


func _apply(game) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if _dir < 0:
		Input.action_press("move_left")
	elif _dir > 0:
		Input.action_press("move_right")


## Esquiva con probabilidad `attention`; si no, solo persigue enemigos.
func _smart(game, attention: float) -> int:
	var sx: float = game.ship_x
	var target := 960.0
	var lowest := -1000.0
	for e in game._enemies:
		if e.pos.y > lowest and e.pos.y < game.SHIP_Y - 120:
			lowest = e.pos.y
			target = e.pos.x
	var dodge := _rng.randf() < attention
	var best_dir := 0
	var best_score := -1.0e9
	for d in [-1, 0, 1]:
		var nx: float = clampf(sx + d * game.SHIP_SPEED * 0.25, game.SHIP_MIN_X, game.SHIP_MAX_X)
		var danger := 0.0
		if dodge:
			for b in game._enemy_bullets:
				var fx: float = b.pos.x + b.vel.x * 0.25
				var fy: float = b.pos.y + b.vel.y * 0.25
				if absf(fx - nx) < 55.0 and fy > game.SHIP_Y - 140.0 and fy < game.SHIP_Y + 40.0:
					danger += 10.0
			for e in game._enemies:
				if absf(e.pos.x - nx) < e.radius + 45.0 and e.pos.y > game.SHIP_Y - 280.0 and e.pos.y < game.SHIP_Y + 60.0:
					danger += 10.0
		var score: float = -danger * 100.0 - absf(nx - target)
		if score > best_score:
			best_score = score
			best_dir = d
	return best_dir
