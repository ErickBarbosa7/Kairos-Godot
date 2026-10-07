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
var last_was_record: bool = false
## Puesto en el marcador de la última partida (0 = no entró) y sus iniciales.
var last_rank: int = 0
var last_initials: String = ""
## Verdadero si la última partida entra al marcador y faltan las iniciales.
var entry_pending: bool = false
## Verdadero si la partida llegó a la meta y falta girar la ruleta.
var reward_pending: bool = false
## Recompensa que salió en la ruleta ({} si no hubo). Es la que viaja en el QR.
var won_reward: Dictionary = {}


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


## Cierra la partida. Devuelve verdadero si superó el mejor resultado de ese juego.
func finish_game(reason: String) -> bool:
	if screen != Screen.PLAYING:
		return false
	last_score = score
	last_reason = reason
	last_rank = 0
	last_initials = ""
	won_reward = {}
	last_was_record = score > ScoreStore.best(game_id)
	entry_pending = ScoreStore.qualifies(game_id, score)
	game_finished.emit(last_score, last_reason)
	go_to(Screen.RESULT)
	return last_was_record


func back_to_menu() -> void:
	go_to(Screen.MENU)
