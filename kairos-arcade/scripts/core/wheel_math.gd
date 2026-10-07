class_name WheelMath
extends RefCounted
## Geometría de la ruleta. Los ángulos van en radianes, positivos en sentido horario (como en pantalla).
## Con la rueda sin girar, el segmento 0 empieza justo bajo la flecha (arriba) y los siguientes
## siguen en sentido horario. Una rotación `a` mueve cada segmento `a` radianes en sentido horario.


## Rotación final para que `winner` quede bajo la flecha tras `extra_turns` vueltas completas.
## `jitter` (-0.4 a 0.4) corre el punto de parada dentro del segmento, para que no caiga siempre al centro.
static func final_angle(winner: int, count: int, extra_turns: int, jitter: float = 0.0) -> float:
	var seg := TAU / count
	var j := clampf(jitter, -0.4, 0.4)
	return extra_turns * TAU + wrapf(-(winner + 0.5 + j) * seg, 0.0, TAU)


## Segmento que queda bajo la flecha para una rotación dada.
static func segment_at(angle: float, count: int) -> int:
	var seg := TAU / count
	return clampi(int(floor(wrapf(-angle, 0.0, TAU) / seg)), 0, count - 1)
