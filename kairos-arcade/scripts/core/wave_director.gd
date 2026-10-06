class_name WaveDirector
extends RefCounted
## Curva de dificultad de una partida de 60 s. Solo funciones puras de t (segundos).

const DURATION := 60.0
## Durante este tiempo nadie puede quitar la última vida.
const SAFE_SECONDS := 10.0
const SPECIAL_AT := 42.0
const FINAL_BURST_AT := 55.0


static func spawn_interval(t: float) -> float:
	if t < SAFE_SECONDS:
		return 1.5
	if t < 40.0:
		return lerpf(1.1, 0.6, (t - SAFE_SECONDS) / 30.0)
	if t < FINAL_BURST_AT:
		return 0.45
	return 0.35


static func enemy_speed(t: float) -> float:
	return minf(120.0 + 3.0 * t, 300.0)


## Fracción de enemigos nuevos que disparan.
static func shooter_ratio(t: float) -> float:
	if t < SAFE_SECONDS:
		return 0.0
	return clampf((t - SAFE_SECONDS) / 50.0, 0.0, 1.0) * 0.45


static func fire_interval(t: float) -> float:
	return lerpf(2.4, 1.3, clampf(t / DURATION, 0.0, 1.0))


static func in_final_burst(t: float) -> bool:
	return t >= FINAL_BURST_AT


## Verdadero si un impacto puede costar la última vida.
static func can_take_last_life(t: float) -> bool:
	return t >= SAFE_SECONDS
