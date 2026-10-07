extends SceneTree
## Simulación de balance a paso fijo con bots de tres niveles. Uso:
## SIM_GAME=defensa_estelar SIM_RUNS=60 SIM_SKILLS=casual,medio,bueno SIM_GOALS=16000,22000 \
##   godot --headless --path kairos-arcade --script res://tests/balance_sim.gd
## Imprime la distribución de puntajes, la supervivencia y el % de partidas que llegan a cada meta.

const DT := 1.0 / 60.0

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func _go() -> void:
	var which := OS.get_environment("SIM_GAME")
	var runs := int(OS.get_environment("SIM_RUNS"))
	var skills: PackedStringArray = OS.get_environment("SIM_SKILLS").split(",")
	for skill in skills:
		var scores: Array[int] = []
		var survived := 0
		var lives_left := 0
		var elapsed_sum := 0.0
		for r in runs:
			var res := _run(which, skill)
			scores.append(res.score)
			if res.reason == "time":
				survived += 1
			lives_left += res.lives
			elapsed_sum += res.elapsed
		scores.sort()
		var n := scores.size()
		var rates := ""
		for g in OS.get_environment("SIM_GOALS").split(",", false):
			var hits := 0
			for sc in scores:
				if sc >= int(g):
					hits += 1
			rates += "  meta%s=%d%%" % [g, 100 * hits / n]
		print("RATE %s %-7s%s" % [which, skill, rates])
		print("SIM %s %-7s n=%d  p10=%d p25=%d p50=%d p75=%d p90=%d max=%d  | sobrevive=%d%% vidas_prom=%.1f dura_prom=%.0fs" % [which, skill, n, scores[int(n * 0.1)], scores[int(n * 0.25)], scores[int(n * 0.5)], scores[int(n * 0.75)], scores[int(n * 0.9)], scores[n - 1], 100 * survived / n, float(lives_left) / n, elapsed_sum / n])
	quit()

func _run(which: String, skill: String) -> Dictionary:
	var info: GameInfo = load("res://resources/games/%s.tres" % which)
	var router: GDScript = load("res://scripts/core/router.gd")
	router.current_game = info
	var state := root.get_node("ArcadeState")
	state.screen = state.Screen.MENU
	state.start_game(info.id)
	var game = info.scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	var bot = load("res://tests/sim_bot_%s.gd" % which).new(skill)
	var guard := 0
	while game.phase != game.Phase.ENDING and guard < 20000:
		bot.think(game, DT)
		game._process(DT)
		guard += 1
	var out := {"score": game.keeper.score, "reason": game.end_reason, "lives": game.keeper.lives, "elapsed": game.elapsed}
	bot.release()
	root.remove_child(game)
	game.free()
	return out
