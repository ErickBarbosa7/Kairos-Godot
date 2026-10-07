class_name Router
extends RefCounted
## Cambios de pantalla. Un solo lugar para añadir transiciones después.

const MENU := "res://scenes/menu/menu.tscn"
const RESULT := "res://scenes/ui/result.tscn"
const ENTRY := "res://scenes/ui/entry.tscn"
const ROULETTE := "res://scenes/ui/roulette.tscn"
const BOOT := "res://scenes/boot/main.tscn"
const LINK := "res://scenes/ui/link.tscn"
const SCOREBOARD := "res://scenes/ui/scoreboard.tscn"

static var current_game: GameInfo
static var scoreboard_game_id: String = ""
static var scoreboard_return: String = MENU


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func to_menu() -> void:
	ArcadeState.back_to_menu()
	_tree().change_scene_to_file(MENU)


## Empieza una partida del juego dado. Devuelve false si no tiene escena.
static func start_game(info: GameInfo) -> bool:
	if info == null or info.scene == null:
		return false
	current_game = info
	ArcadeState.start_game(info.id)
	# Se actualiza mientras se juega: la ruleta usa las recompensas de ese momento.
	RewardCatalog.refresh()
	_tree().change_scene_to_packed(info.scene)
	return true


## Fin de partida: iniciales si entra al marcador, y luego el resultado.
static func after_game() -> void:
	if ArcadeState.entry_pending:
		_tree().change_scene_to_file(ENTRY)
	else:
		after_entry()


## Después de las iniciales (o si no hubo): la ruleta si llegó a la meta, y si no el resultado.
static func after_entry() -> void:
	_tree().change_scene_to_file(ROULETTE if ArcadeState.reward_pending else RESULT)


static func to_result() -> void:
	_tree().change_scene_to_file(RESULT)


## Muestra el marcador de un juego y vuelve a `back_to` al salir.
static func to_scoreboard(game_id: String, back_to: String) -> void:
	scoreboard_game_id = game_id
	scoreboard_return = back_to
	_tree().change_scene_to_file(SCOREBOARD)


static func to_boot() -> void:
	_tree().change_scene_to_file(BOOT)


static func to_link() -> void:
	_tree().change_scene_to_file(LINK)
