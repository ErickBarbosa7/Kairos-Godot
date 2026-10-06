class_name SnakeBoard
extends RefCounted
## Lógica de la serpiente sobre una cuadrícula. Sin nodos: se prueba con pruebas unitarias.

enum Result { MOVED, CRASHED }

const MAX_QUEUED := 2

var cols: int
var rows: int
## Celdas de la serpiente; la cabeza es body[0].
var body: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var _queue: Array[Vector2i] = []
var _pending_growth := 0


func _init(columns: int, row_count: int) -> void:
	cols = columns
	rows = row_count


## Coloca la serpiente en el centro mirando a la derecha.
func reset(length: int = 3) -> void:
	body.clear()
	_queue.clear()
	_pending_growth = 0
	dir = Vector2i.RIGHT
	var head := Vector2i(cols / 2, rows / 2)
	for i in length:
		body.append(head - Vector2i(i, 0))


## Encola un giro. Ignora la dirección contraria o repetida, y limita la cola.
func queue_dir(d: Vector2i) -> void:
	var last: Vector2i = _queue.back() if not _queue.is_empty() else dir
	if d == last or d == -last or _queue.size() >= MAX_QUEUED:
		return
	_queue.append(d)


## Celda donde caerá la cabeza en el próximo paso.
func peek_head() -> Vector2i:
	var next_dir: Vector2i = _queue.front() if not _queue.is_empty() else dir
	return body[0] + next_dir


## Avanza un paso. grow_by suma celdas que la serpiente crecerá en los siguientes pasos.
func advance(grow_by: int = 0) -> Result:
	if not _queue.is_empty():
		dir = _queue.pop_front()
	var head := body[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= cols or head.y >= rows:
		return Result.CRASHED
	_pending_growth += grow_by
	# Si la cola se queda quieta este paso (crece), también cuenta como cuerpo.
	var solid := body.size() if _pending_growth > 0 else body.size() - 1
	for i in solid:
		if body[i] == head:
			_pending_growth -= grow_by
			return Result.CRASHED
	body.push_front(head)
	if _pending_growth > 0:
		_pending_growth -= 1
	else:
		body.pop_back()
	return Result.MOVED


func contains(cell: Vector2i) -> bool:
	return body.has(cell)


## Celda libre al azar, fuera de la serpiente y de las celdas a evitar. (-1,-1) si no hay.
func free_cell(rng: RandomNumberGenerator, avoid: Array[Vector2i] = []) -> Vector2i:
	for attempt in 40:
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if not body.has(c) and not avoid.has(c):
			return c
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if not body.has(c) and not avoid.has(c):
				return c
	return Vector2i(-1, -1)
