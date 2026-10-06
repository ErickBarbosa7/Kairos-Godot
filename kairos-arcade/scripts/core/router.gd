class_name Router
extends RefCounted
## Cambios de pantalla. Un solo lugar para añadir transiciones después.

const MENU := "res://scenes/menu/menu.tscn"
const RESULT := "res://scenes/ui/result.tscn"

static var current_game: GameInfo


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
	_tree().change_scene_to_packed(info.scene)
	return true


static func to_result() -> void:
	_tree().change_scene_to_file(RESULT)
