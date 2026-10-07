extends SceneTree
## Muestra las estadísticas de la máquina por juego. Uso:
##   godot --headless --path kairos-arcade --script res://tools/stats.gd
## Con `-- --file=<ruta>` lee otro archivo de estadísticas.
## Sirve para decidir si la meta de QR de cada juego está bien calibrada.

const TARGET_MIN := 5.0
const TARGET_MAX := 15.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--file="):
			PlayStats.path = arg.trim_prefix("--file=")
	var data := PlayStats.all()
	if data.is_empty():
		print("Sin partidas registradas todavía.")
		quit()
		return
	print("%-20s %9s %12s %8s %8s %10s %9s" % ["Juego", "Partidas", "En la meta", "% meta", "QR", "Promedio", "Máximo"])
	for game_id in data:
		var s := PlayStats.summary(game_id)
		var rate := PlayStats.goal_rate(game_id)
		var avg: int = int(s.score_sum) / int(s.plays) if int(s.plays) > 0 else 0
		var hint := ""
		if s.plays >= 30:
			if rate > TARGET_MAX:
				hint = "  ← muchos QR: considera subir la meta"
			elif rate < TARGET_MIN:
				hint = "  ← pocos QR: considera bajar la meta"
		print("%-20s %9d %12d %7.1f%% %8d %10d %9d%s" % [game_id, s.plays, s.goal_reached, rate, s.qr_issued, avg, s.score_max, hint])
	print("\nObjetivo orientativo: entre %d %% y %d %% de las partidas en la meta (con 30 partidas o más)." % [TARGET_MIN, TARGET_MAX])
	quit()
