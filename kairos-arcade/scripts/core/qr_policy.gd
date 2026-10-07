class_name QrPolicy
extends RefCounted
## Cuándo una partida gana un QR. No todas lo ganan: hay que llegar a la meta del juego.
## La meta sale del recurso del juego y el negocio puede cambiarla en machine.config.json
## con "qr_goals": {"id_del_juego": puntos}.


## Puntaje mínimo para ganar el QR. 0 = sin QR para ese juego.
static func goal_for(info: GameInfo) -> int:
	if info == null:
		return 0
	var overrides: Variant = AppConfig.qr_goals.get(info.id, null)
	if overrides != null and int(overrides) > 0:
		return int(overrides)
	return info.qr_goal


static func earned(score: int, goal: int) -> bool:
	return goal > 0 and score >= goal
