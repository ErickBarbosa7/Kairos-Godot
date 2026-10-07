extends RefCounted
## Bot de Serpiente Golosa para balancear. skill: casual | medio | bueno.
## Solo lo usa la simulación de balance; no forma parte del juego.

var skill: String
var _rng := RandomNumberGenerator.new()
var _last_step_check := -1
var _decision := Vector2i.ZERO


func _init(level: String) -> void:
	skill = level
	_rng.randomize()


func release() -> void:
	pass


func think(game, _delta: float) -> void:
	if game.phase != game.Phase.PLAYING and game.phase != game.Phase.COUNTDOWN:
		return
	var attention := 0.35 if skill == "casual" else (0.75 if skill == "medio" else 1.0)
	if _rng.randf() > attention * 0.2 + (0.8 if skill == "bueno" else 0.0):
		return
	var b: SnakeBoard = game.board
	var d := _choose(game, b)
	if d != Vector2i.ZERO:
		b.queue_dir(d)


func _choose(game, b: SnakeBoard) -> Vector2i:
	var head: Vector2i = b.body[0]
	var targets: Array[Vector2i] = []
	for it in game._items:
		targets.append(it.cell)
	if skill == "bueno":
		var path := _bfs(b, head, targets)
		if path != Vector2i.ZERO:
			return path
		return _any_safe(b, head)
	# casual y medio: ir hacia el objetivo más cercano en línea recta
	var best: Vector2i = Vector2i.ZERO
	var best_d := 1 << 30
	for t in targets:
		var dist := absi(t.x - head.x) + absi(t.y - head.y)
		if dist < best_d:
			best_d = dist
			best = t
	var want := Vector2i.ZERO
	if best.x != head.x:
		want = Vector2i(signi(best.x - head.x), 0)
	elif best.y != head.y:
		want = Vector2i(0, signi(best.y - head.y))
	if skill == "medio" and not _safe(b, head + want):
		return _any_safe(b, head)
	return want


func _safe(b: SnakeBoard, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= b.cols or cell.y >= b.rows:
		return false
	var n := b.body.size()
	for i in n - 1:
		if b.body[i] == cell:
			return false
	return true


func _any_safe(b: SnakeBoard, head: Vector2i) -> Vector2i:
	var options := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	options.shuffle()
	for o in options:
		if o != -b.dir and _safe(b, head + o):
			return o
	return Vector2i.ZERO


func _bfs(b: SnakeBoard, head: Vector2i, targets: Array[Vector2i]) -> Vector2i:
	if targets.is_empty():
		return _any_safe(b, head)
	var blocked := {}
	for i in b.body.size() - 1:
		blocked[b.body[i]] = true
	var first := {}
	var seen := {head: true}
	var queue: Array[Vector2i] = []
	for o in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if o == -b.dir:
			continue
		var c: Vector2i = head + o
		if c.x < 0 or c.y < 0 or c.x >= b.cols or c.y >= b.rows or blocked.has(c):
			continue
		seen[c] = true
		first[c] = o
		queue.append(c)
	var idx := 0
	while idx < queue.size():
		var cur := queue[idx]
		idx += 1
		if targets.has(cur):
			return first[cur]
		for o in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var nxt: Vector2i = cur + o
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= b.cols or nxt.y >= b.rows or blocked.has(nxt) or seen.has(nxt):
				continue
			seen[nxt] = true
			first[nxt] = first[cur]
			queue.append(nxt)
	return _any_safe(b, head)
