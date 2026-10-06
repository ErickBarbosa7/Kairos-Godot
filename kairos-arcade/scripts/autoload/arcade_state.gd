extends Node
## Estado global: pantalla actual, partida en curso y resultado.
## No dibuja interfaz; solo guarda estado y avisa con señales.

enum Screen { BOOT, MENU, COUNTDOWN, PLAYING, RESULT }

signal screen_changed(screen: Screen)
signal score_changed(score: int)
signal game_finished(score: int, reason: String)

var screen: Screen = Screen.BOOT
var game_id: String = ""
var score: int = 0
var last_score: int = 0
var last_reason: String = ""
var best_score: int = 0
var last_was_record: bool = false
## Guardar el mejor resultado en disco. Las pruebas lo desactivan.
var persist: bool = true

const BEST_PATH := "user://best_score.json"


func _ready() -> void:
	if persist and FileAccess.file_exists(BEST_PATH):
		var data: Variant = JSON.parse_string(FileAccess.open(BEST_PATH, FileAccess.READ).get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			best_score = int(data.get("best", 0))


func go_to(next: Screen) -> void:
	if next == screen:
		return
	screen = next
	screen_changed.emit(screen)


func start_game(id: String) -> void:
	game_id = id
	score = 0
	score_changed.emit(score)
	go_to(Screen.COUNTDOWN)


func begin_play() -> void:
	go_to(Screen.PLAYING)


func add_score(points: int) -> void:
	if screen != Screen.PLAYING or points <= 0:
		return
	score += points
	score_changed.emit(score)


## Cierra la partida. Devuelve verdadero si superó el mejor resultado local.
func finish_game(reason: String) -> bool:
	if screen != Screen.PLAYING:
		return false
	last_score = score
	last_reason = reason
	var is_record := score > best_score
	last_was_record = is_record
	if is_record:
		best_score = score
		if persist:
			var file := FileAccess.open(BEST_PATH, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify({"best": best_score}))
	game_finished.emit(last_score, last_reason)
	go_to(Screen.RESULT)
	return is_record


func back_to_menu() -> void:
	go_to(Screen.MENU)
