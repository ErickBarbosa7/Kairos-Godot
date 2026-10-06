extends SceneTree
## Pruebas sin dependencias. Uso:
## godot --headless --path kairos-arcade --script res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	# Los autoloads existen cuando termina el primer fotograma.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)


func _run() -> void:
	var theme := root.get_node("TenantTheme")
	var state := root.get_node("ArcadeState")
	var config := root.get_node("AppConfig")

	print("TenantTheme")
	_check(theme.contrast(Color.WHITE, Color.BLACK) > 20.9, "contraste blanco/negro es 21:1")
	_check(theme.pick_on_color(Color("#FFFF00")) == theme.DARK_TEXT, "texto oscuro sobre amarillo")
	_check(theme.pick_on_color(Color("#1E3A8A")) == Color.WHITE, "texto blanco sobre azul oscuro")
	_check(theme.is_valid_hex("#7C3AED"), "hex válido")
	_check(not theme.is_valid_hex("7C3AED") and not theme.is_valid_hex("#xyz"), "hex inválido rechazado")
	_check(theme.is_fallback, "arranca con tema Kairos")
	_check(not theme.apply_brand({"primaryColor": "rojo"}), "marca con color inválido se rechaza")
	_check(theme.is_fallback, "tras marca inválida sigue el tema Kairos")
	_check(theme.apply_brand({"name": "Café Sol", "primaryColor": "#0A0A40"}), "marca válida se aplica")
	_check(theme.contrast(theme.primary, theme.NIGHT) >= 3.0, "primario oscuro se aclara a 3:1 sobre el fondo")
	_check(theme.contrast(theme.on_primary, theme.primary) >= 4.5, "texto sobre primario cumple 4.5:1")
	theme.reset_to_fallback()
	_check(theme.tenant_name == "Kairos" and theme.is_fallback, "reset vuelve al tema Kairos")

	print("AppConfig")
	_check(config.simulated, "sin archivo la configuración es simulada")
	config.apply({"api_url": "http://api.test/", "store_id": "abc", "machine_id": "m1"})
	_check(config.api_url == "http://api.test", "quita la barra final de la URL")
	_check(not config.simulated, "con store_id real deja de ser simulada")

	print("ArcadeState")
	state.persist = false
	state.best_score = 0
	state.go_to(state.Screen.MENU)
	state.add_score(50)
	_check(state.score == 0, "no suma puntos fuera de partida")
	state.start_game("defensa_estelar")
	_check(state.screen == state.Screen.COUNTDOWN, "start_game pasa a cuenta atrás")
	state.begin_play()
	state.add_score(120)
	state.add_score(-5)
	_check(state.score == 120, "suma puntos y ignora negativos")
	_check(state.finish_game("time"), "primer resultado es récord")
	_check(state.screen == state.Screen.RESULT and state.last_score == 120, "pasa a resultado con el puntaje")
	state.back_to_menu()
	state.start_game("defensa_estelar")
	state.begin_play()
	state.add_score(10)
	_check(not state.finish_game("lives"), "un puntaje menor no es récord")

	print("ScoreKeeper")
	var k := ScoreKeeper.new()
	_check(k.multiplier() == 1 and k.lives == 3, "empieza en x1 con 3 vidas")
	_check(k.add_kill(100) == 100, "primer acierto suma 100")
	for i in 3:
		k.add_kill(100)
	_check(k.multiplier() == 2, "4 aciertos seguidos suben a x2")
	_check(k.add_kill(100) == 200, "x2 duplica los puntos")
	_check(k.add_bonus(150) == 300 and k.streak == 5, "el bono usa el multiplicador sin alargar la racha")
	for i in 40:
		k.add_kill(1)
	_check(k.multiplier() == ScoreKeeper.MAX_MULTIPLIER and k.streak_progress() == 1.0, "el multiplicador tiene tope")
	_check(not k.hit() and k.lives == 2 and k.streak == 0 and k.multiplier() == 1, "un impacto quita vida y reinicia la racha")
	k.hit()
	_check(k.hit() and k.lives == 0, "sin vidas hit() devuelve verdadero")
	var d := ScoreKeeper.new()
	d.add_kill(1)
	d.add_kill(1)
	d.add_kill(1)
	d.add_kill(1)
	d.tick(ScoreKeeper.STREAK_GRACE - 0.1)
	_check(d.streak == 4, "dentro del margen la racha no baja")
	d.tick(1.2)
	_check(d.streak == 3, "pasado el margen la racha baja de a una")

	print("SnakeBoard")
	var b := SnakeBoard.new(10, 8)
	b.reset(3)
	_check(b.body.size() == 3 and b.body[0] == Vector2i(5, 4) and b.dir == Vector2i.RIGHT, "empieza centrada mirando a la derecha")
	_check(b.advance() == SnakeBoard.Result.MOVED and b.body[0] == Vector2i(6, 4) and b.body.size() == 3, "avanza sin crecer")
	b.queue_dir(Vector2i.LEFT)
	_check(b.peek_head() == Vector2i(7, 4), "no permite girar en sentido contrario")
	b.queue_dir(Vector2i.UP)
	b.advance()
	_check(b.body[0] == Vector2i(6, 3), "el giro encolado se aplica")
	var g := SnakeBoard.new(10, 8)
	g.reset(3)
	g.advance(2)
	_check(g.body.size() == 4, "comer crece 1 en el mismo paso")
	g.advance()
	_check(g.body.size() == 5, "el crecimiento pendiente se aplica después")
	g.advance()
	_check(g.body.size() == 5, "luego deja de crecer")
	var w := SnakeBoard.new(10, 8)
	w.reset(3)
	var steps := 0
	while w.advance() == SnakeBoard.Result.MOVED and steps < 50:
		steps += 1
	_check(steps == 4, "choca contra la pared derecha")
	var s2 := SnakeBoard.new(20, 20)
	s2.reset(6)
	s2.advance(3)
	s2.advance()
	s2.advance()
	s2.queue_dir(Vector2i.DOWN)
	s2.advance()
	s2.queue_dir(Vector2i.LEFT)
	s2.advance()
	s2.queue_dir(Vector2i.UP)
	_check(s2.advance() == SnakeBoard.Result.CRASHED, "choca consigo misma")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	for i in 100:
		if s2.contains(s2.free_cell(rng)):
			ok = false
	_check(ok, "free_cell nunca cae sobre la serpiente")
	var q := SnakeBoard.new(10, 8)
	q.reset(3)
	q.queue_dir(Vector2i.UP)
	q.queue_dir(Vector2i.LEFT)
	q.queue_dir(Vector2i.DOWN)
	q.advance()
	q.advance()
	q.advance()
	_check(q.dir == Vector2i.LEFT, "la cola de giros tiene tope de 2")

	print("WaveDirector")
	_check(WaveDirector.shooter_ratio(5.0) == 0.0, "sin disparos enemigos en los primeros 10 s")
	_check(not WaveDirector.can_take_last_life(5.0) and WaveDirector.can_take_last_life(10.0), "la última vida es segura 10 s")
	_check(WaveDirector.spawn_interval(30.0) < WaveDirector.spawn_interval(5.0), "más enemigos con el tiempo")
	_check(WaveDirector.enemy_speed(60.0) <= 300.0, "la velocidad tiene tope")
	_check(WaveDirector.in_final_burst(56.0) and not WaveDirector.in_final_burst(54.0), "ráfaga final desde los 55 s")

	print("BrandCache")
	BrandCache.clear()
	_check(BrandCache.load_for("a").is_empty(), "sin caché devuelve vacío")
	BrandCache.save("a", {"name": "Café Sol", "primaryColor": "#FF700A"})
	_check(BrandCache.load_for("a").get("name") == "Café Sol", "guarda y lee la marca")
	_check(BrandCache.load_for("b").is_empty(), "la caché de otra sucursal no se usa")
	BrandCache.clear()
	_check(BrandCache.load_for("a").is_empty(), "clear borra la caché")

	print("Menú")
	var games := 0
	for file in DirAccess.get_files_at("res://resources/games"):
		if file.trim_suffix(".remap").ends_with(".tres"):
			var info := load("res://resources/games/" + file.trim_suffix(".remap")) as GameInfo
			if info:
				games += 1
	_check(games == 3, "hay tres juegos en el catálogo")

	print()
	if _failures == 0:
		print("Todas las pruebas pasaron")
	else:
		printerr("%d prueba(s) fallaron" % _failures)
	quit(1 if _failures > 0 else 0)
