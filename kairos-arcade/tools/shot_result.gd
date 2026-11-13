extends SceneTree
## Captura la pantalla de resultado con un puntaje dado, sin jugar. Uso:
##   SHOT_SCORE=120 SHOT_OUT=/tmp/resultado.png godot --path kairos-arcade --script res://tools/shot_result.gd -- --config=...

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)


func _go() -> void:
	var state := root.get_node("ArcadeState")
	var router: GDScript = load("res://scripts/core/router.gd")
	var info: GameInfo = load("res://resources/games/%s.tres" % OS.get_environment("SHOT_GAME"))
	router.current_game = info
	state.game_id = info.id
	state.last_score = int(OS.get_environment("SHOT_SCORE"))
	state.screen = state.Screen.RESULT
	var scene: PackedScene = load("res://scenes/ui/result.tscn")
	var node := scene.instantiate()
	root.add_child(node)
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	quit()
