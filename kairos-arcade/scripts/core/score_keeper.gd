class_name ScoreKeeper
extends RefCounted
## Puntaje, racha, multiplicador y vidas. Sin nodos: se prueba con pruebas unitarias.

signal changed

const MAX_LIVES := 3
const MAX_MULTIPLIER := 5
const KILLS_PER_LEVEL := 4
## Segundos sin aciertos antes de que la racha empiece a bajar.
const STREAK_GRACE := 4.0

var score: int = 0
var lives: int = MAX_LIVES
var streak: int = 0
var _idle: float = 0.0
var _decay: float = 0.0


func multiplier() -> int:
	return mini(1 + streak / KILLS_PER_LEVEL, MAX_MULTIPLIER)


## Avance hacia el siguiente nivel de multiplicador, de 0 a 1.
func streak_progress() -> float:
	if multiplier() >= MAX_MULTIPLIER:
		return 1.0
	return float(streak % KILLS_PER_LEVEL) / KILLS_PER_LEVEL


## Destruir un enemigo: suma con el multiplicador actual y alarga la racha.
func add_kill(base_points: int) -> int:
	var points := base_points * multiplier()
	score += points
	streak += 1
	_idle = 0.0
	changed.emit()
	return points


## Puntos extra (núcleos): usan el multiplicador pero no alargan la racha.
func add_bonus(base_points: int) -> int:
	var points := base_points * multiplier()
	score += points
	_idle = 0.0
	changed.emit()
	return points


## Recibir un impacto. Devuelve verdadero si no quedan vidas.
func hit() -> bool:
	lives = maxi(lives - 1, 0)
	streak = 0
	changed.emit()
	return lives <= 0


func tick(delta: float) -> void:
	if streak == 0:
		return
	_idle += delta
	if _idle < STREAK_GRACE:
		return
	_decay += delta
	if _decay >= 1.0:
		_decay -= 1.0
		streak -= 1
		changed.emit()
