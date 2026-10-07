class_name ScoreStore
extends RefCounted
## Marcador local por juego: los 10 mejores puntajes con iniciales de 3 caracteres.
## Se guarda en disco de la máquina; no se sincroniza con la API.

const MAX_ENTRIES := 10
const NAME_LENGTH := 3
const CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const DEFAULT_NAME := "AAA"
## Combinaciones ofensivas (inglés y español) que no se aceptan como iniciales.
## Es una lista corta y editable: evita las más evidentes sin bloquear iniciales comunes.
const BLOCKED := [
	"ASS", "SEX", "FUK", "FCK", "KKK", "SHT", "DIK", "CUM", "TIT", "CNT", "NIG", "FAG",
	"PTO", "PUT", "PTA", "PNE", "CUL", "MRD", "JOD", "CAG", "HDP",
]

static var path := "user://scoreboard.json"


static func _load_all() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func _save_all(all: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("ScoreStore: no se pudo escribir %s" % path)
		return
	file.store_string(JSON.stringify(all))


## Entradas del juego, de mayor a menor puntaje: [{name, score, ts}].
static func entries(game_id: String) -> Array:
	var raw: Variant = _load_all().get(game_id, [])
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("score"):
			out.append({"name": str(e.name), "score": int(e.score), "ts": int(e.get("ts", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	return out.slice(0, MAX_ENTRIES)


static func best(game_id: String) -> int:
	var list := entries(game_id)
	return int(list[0].score) if not list.is_empty() else 0


## Puesto (1 = primero) que tendría ese puntaje. En empate queda debajo de lo ya guardado.
static func rank_for(game_id: String, score: int) -> int:
	var rank := 1
	for e in entries(game_id):
		if e.score >= score:
			rank += 1
	return rank


static func qualifies(game_id: String, score: int) -> bool:
	return score > 0 and rank_for(game_id, score) <= MAX_ENTRIES


static func is_name_allowed(name: String) -> bool:
	if name.length() != NAME_LENGTH:
		return false
	for c in name:
		if not CHARSET.contains(c):
			return false
	return not BLOCKED.has(name)


## Guarda el puntaje y devuelve el puesto, o 0 si no entra o las iniciales no son válidas.
static func add(game_id: String, name: String, score: int) -> int:
	if not qualifies(game_id, score) or not is_name_allowed(name):
		return 0
	var rank := rank_for(game_id, score)
	var all := _load_all()
	var list := entries(game_id)
	list.append({"name": name, "score": score, "ts": int(Time.get_unix_time_from_system())})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	all[game_id] = list.slice(0, MAX_ENTRIES)
	_save_all(all)
	return rank


static func clear(game_id: String = "") -> void:
	if game_id.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var all := _load_all()
	all.erase(game_id)
	_save_all(all)
