class_name PlayStats
extends RefCounted
## Estadísticas locales por juego para que el negocio calibre las metas de QR:
## partidas terminadas, cuántas llegaron a la meta y cuántos QR se emitieron.
## Solo cuenta; no guarda iniciales ni datos de personas.

static var path := "user://play_stats.json"


static func all() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func _save(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("PlayStats: no se pudo escribir %s" % path)
		return
	file.store_string(JSON.stringify(data))


static func summary(game_id: String) -> Dictionary:
	var raw: Variant = all().get(game_id, {})
	var s := {"plays": 0, "goal_reached": 0, "qr_issued": 0, "score_sum": 0, "score_max": 0}
	if typeof(raw) == TYPE_DICTIONARY:
		for key in s:
			s[key] = int(raw.get(key, 0))
	return s


## Una partida terminada (no cuenta las abandonadas). goal = 0 si el juego no da QR.
static func record_play(game_id: String, score: int, goal: int) -> void:
	var data := all()
	var s := summary(game_id)
	s.plays += 1
	s.score_sum += score
	s.score_max = maxi(s.score_max, score)
	if goal > 0 and score >= goal:
		s.goal_reached += 1
	data[game_id] = s
	_save(data)


static func record_qr_issued(game_id: String) -> void:
	var data := all()
	var s := summary(game_id)
	s.qr_issued += 1
	data[game_id] = s
	_save(data)


## Porcentaje de partidas que llegaron a la meta (0 si no hay partidas).
static func goal_rate(game_id: String) -> float:
	var s := summary(game_id)
	return 100.0 * s.goal_reached / s.plays if s.plays > 0 else 0.0
