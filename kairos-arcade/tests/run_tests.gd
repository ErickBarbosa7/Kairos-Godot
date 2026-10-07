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
	ScoreStore.path = "user://test_scoreboard.json"
	ScoreStore.clear()
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
	_check(state.entry_pending, "un puntaje que entra al marcador deja las iniciales pendientes")
	ScoreStore.add("defensa_estelar", "AAA", 120)
	_check(state.entry_pending, "un puntaje que entra al marcador deja las iniciales pendientes")
	ScoreStore.add("defensa_estelar", "AAA", 120)
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
	_check(games == 6, "hay seis juegos en el catálogo")
	var memory_rush := load("res://resources/games/memory_rush.tres") as GameInfo
	_check(memory_rush != null and memory_rush.playable and not memory_rush.has_time_limit, "Memory Rush no tiene límite de tiempo")

	print("ScoreStore")
	ScoreStore.clear()
	_check(ScoreStore.entries("x").is_empty() and ScoreStore.best("x") == 0, "marcador vacío")
	_check(not ScoreStore.qualifies("x", 0), "un puntaje de 0 no entra")
	_check(ScoreStore.add("x", "ABC", 500) == 1, "el primero queda en el puesto 1")
	_check(ScoreStore.add("x", "DEF", 900) == 1 and ScoreStore.best("x") == 900, "uno mayor pasa al puesto 1")
	_check(ScoreStore.add("x", "GHI", 500) == 3, "un empate queda debajo de lo guardado")
	_check(ScoreStore.entries("x")[0].name == "DEF", "ordenado de mayor a menor")
	for i in 12:
		ScoreStore.add("x", "ZZ9", 1000 + i)
	_check(ScoreStore.entries("x").size() == ScoreStore.MAX_ENTRIES, "solo se guardan 10")
	_check(not ScoreStore.qualifies("x", 100) and ScoreStore.qualifies("x", 5000), "entra solo quien supera al décimo")
	_check(ScoreStore.add("x", "ASS", 9999) == 0, "iniciales bloqueadas se rechazan")
	_check(ScoreStore.add("x", "ab", 9999) == 0 and ScoreStore.add("x", "a_c", 9999) == 0, "iniciales inválidas se rechazan")
	_check(ScoreStore.best("otro") == 0, "cada juego tiene su marcador")
	_check(ScoreStore.is_name_allowed("EB7") and ScoreStore.is_name_allowed("JAV") and ScoreStore.is_name_allowed("CON"), "iniciales comunes sí se aceptan")
	_check(not ScoreStore.is_name_allowed("HDP") and not ScoreStore.is_name_allowed("PTA"), "iniciales ofensivas en español se bloquean")
	ScoreStore.clear()
	ScoreStore.path = "user://scoreboard.json"

	print("PlayStats")
	PlayStats.path = "user://test_play_stats.json"
	if FileAccess.file_exists(PlayStats.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayStats.path))
	_check(PlayStats.summary("j").plays == 0 and PlayStats.goal_rate("j") == 0.0, "sin partidas todo está en cero")
	PlayStats.record_play("j", 1000, 5000)
	PlayStats.record_play("j", 6000, 5000)
	PlayStats.record_play("j", 5000, 5000)
	PlayStats.record_play("j", 800, 0)
	var st := PlayStats.summary("j")
	_check(st.plays == 4 and st.goal_reached == 2, "cuenta partidas y metas (sin meta no cuenta)")
	_check(st.score_max == 6000 and st.score_sum == 12800, "guarda máximo y suma de puntajes")
	PlayStats.record_qr_issued("j")
	_check(PlayStats.summary("j").qr_issued == 1 and PlayStats.summary("otro").plays == 0, "cuenta QR por juego")
	_check(is_equal_approx(PlayStats.goal_rate("j"), 50.0), "porcentaje de partidas en la meta")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayStats.path))
	PlayStats.path = "user://play_stats.json"

	print("QrPolicy")
	# Se carga en ejecución: usa el autoload AppConfig, que no existe al compilar este script.
	var policy: GDScript = load("res://scripts/core/qr_policy.gd")
	var goal_game := GameInfo.new()
	goal_game.id = "juego"
	goal_game.qr_goal = 5000
	_check(policy.goal_for(goal_game) == 5000, "usa la meta del juego")
	config.qr_goals = {"juego": 8000}
	_check(policy.goal_for(goal_game) == 8000, "la configuración de la máquina la sobrescribe")
	config.qr_goals = {}
	_check(policy.earned(5000, 5000) and not policy.earned(4999, 5000), "se gana al llegar a la meta")
	_check(not policy.earned(999999, 0), "sin meta no hay QR")

	print("Es256")
	var key := "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721".hex_decode()
	var sig := Es256.sign_digest(key, "sample".sha256_buffer())
	_check(sig.slice(0, 32).hex_encode().to_upper() == "EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716", "r coincide con el vector RFC 6979")
	_check(sig.slice(32, 64).hex_encode().to_upper() == "F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8", "s coincide con el vector RFC 6979")
	_check(Es256.sign_jwt({"a": 1}, "no es una llave") == "", "una llave inválida no firma")
	_check(Es256.base64url(PackedByteArray([251, 255, 254])) == "-__-", "base64url sin relleno")

	print("Llaves y vinculación")
	var rfc_pub := Es256.public_key(key)
	_check(rfc_pub.hex_encode() == "60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299", "la llave pública coincide con la de Node para el mismo privado")
	var fresh := Es256.generate_private_key()
	_check(fresh.size() == 32 and fresh != Es256.generate_private_key(), "genera llaves privadas distintas de 32 bytes")
	var fresh_pub := Es256.public_key(fresh)
	var fresh_pem := Es256.private_pem(fresh, fresh_pub)
	_check(Es256.parse_private_pem(fresh_pem) == fresh, "el PEM privado se lee de vuelta")
	_check(Marshalls.base64_to_raw(Es256.public_pem(fresh_pub).replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "").replace("\n", "")).size() == 91, "el PEM público mide 91 bytes (SPKI P-256)")
	_check(Es256.sign_jwt({"a": 1}, fresh_pem).count(".") == 2, "una llave generada puede firmar")
	_check(LinkService.message_for(0) == Strings.LINK_NETWORK and LinkService.message_for(401) == Strings.LINK_BAD_LOGIN, "mensajes de red y credenciales")
	_check(LinkService.message_for(403) == Strings.LINK_NOT_ADMIN and LinkService.message_for(429) == Strings.LINK_RATE, "mensajes de permisos y límite de intentos")
	_check(LinkService.message_for(400, "Llave no válida") == "Llave no válida" and LinkService.message_for(500) == Strings.LINK_GENERIC, "un 400 muestra el mensaje del servidor; otros, uno genérico")
	LinkService.dir = "user://link_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LinkService.dir))
	_check(LinkService.save_identity("http://api.test/", "store-1", "machine-1", fresh_pem, "Café Sol", "Mostrador"), "guarda la identidad")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(LinkService.dir.path_join(LinkService.CONFIG_NAME)))
	_check(typeof(saved) == TYPE_DICTIONARY and saved.store_id == "store-1" and saved.machine_id == "machine-1" and saved.api_url == "http://api.test", "la configuración guardada tiene sucursal, máquina y URL")
	_check(Es256.parse_private_pem(FileAccess.get_file_as_string(saved.private_key_path)) == fresh, "la llave guardada es la generada")
	_check(not JSON.stringify(saved).contains("password") and not JSON.stringify(saved).contains("token"), "no se guarda contraseña ni token")
	for f in [LinkService.CONFIG_NAME, LinkService.KEY_NAME]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LinkService.dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LinkService.dir))
	LinkService.dir = "user://"

	print("Ayuda y kiosco")
	_check(HelpTexts.GENERAL_STEPS.size() == 4 and not HelpTexts.GENERAL_INTRO.is_empty(), "la explicación general de Kairos tiene 4 pasos")
	var topics_ok := true
	for topic_id in ["menu", "entry", "scoreboard", "result", "link", "admin"]:
		var topic: Dictionary = HelpTexts.topic(topic_id)
		if str(topic.title).is_empty() or topic.blocks.is_empty():
			topics_ok = false
		for block in topic.blocks:
			if str(block.heading).is_empty() or str(block.text).is_empty():
				topics_ok = false
	_check(topics_ok, "cada pantalla tiene ayuda con título y bloques completos")
	_check(HelpTexts.topic("no-existe").blocks.is_empty(), "un tema inexistente no rompe")
	var playable_ok := true
	var playable_count := 0
	for file in DirAccess.get_files_at("res://resources/games"):
		var res_name: String = file.trim_suffix(".remap")
		if res_name.ends_with(".tres"):
			var game_info := load("res://resources/games/" + res_name) as GameInfo
			if game_info and game_info.playable:
				playable_count += 1
				if game_info.how_to_play.strip_edges().length() < 40:
					playable_ok = false
	_check(playable_count >= 2 and playable_ok, "cada juego jugable explica cómo se juega")
	var kiosk_script: GDScript = load("res://scripts/autoload/kiosk.gd")
	_check(kiosk_script.decide(true, PackedStringArray()) and not kiosk_script.decide(false, PackedStringArray()), "el kiosco sigue a la configuración")
	_check(not kiosk_script.decide(true, PackedStringArray(["--windowed"])), "--windowed apaga el kiosco")
	_check(kiosk_script.decide(false, PackedStringArray(["--kiosk"])), "--kiosk lo enciende")
	_check(kiosk_script.decide(true, PackedStringArray(["--kiosk", "--windowed"])) == false, "--windowed gana si vienen los dos")

	print("Ruleta y recompensas")
	var wheel_ok := true
	for count in [1, 2, 3, 5, 8]:
		for winner in count:
			for jitter in [-0.35, 0.0, 0.35]:
				for turns in [1, 6]:
					var ang := WheelMath.final_angle(winner, count, turns, jitter)
					if WheelMath.segment_at(ang, count) != winner or ang < turns * TAU - 0.0001:
						wheel_ok = false
	_check(wheel_ok, "la flecha queda siempre sobre la casilla ganadora (1 a 8 casillas, con holgura y vueltas)")
	_check(WheelMath.segment_at(0.0, 4) == 0 and WheelMath.segment_at(-TAU / 4.0, 4) == 1, "sin girar manda la casilla 0; girar hacia atrás avanza la siguiente")
	var catalog: GDScript = load("res://scripts/core/reward_catalog.gd")
	var clean: Array = catalog.sanitize([
		{"id": "a", "title": " Café gratis ", "description": null, "imageUrl": null, "pointsCost": 100},
		{"id": "", "title": "Sin id"}, {"id": "b", "title": ""}, "no es un diccionario", {"title": "sin id"},
	])
	_check(clean.size() == 1 and clean[0].title == "Café gratis" and clean[0].description == "", "sanitize quita lo inservible y limpia espacios")
	_check(catalog.sanitize("basura").is_empty() and catalog.sanitize(null).is_empty(), "una respuesta que no es lista no rompe")
	var many: Array = []
	for i in 20:
		many.append({"id": str(i), "title": "R%d" % i})
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = 11
	var picked: Array = catalog.pick_segments(many, pick_rng)
	var ids: Array = picked.map(func(r: Dictionary) -> int: return int(r.id))
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	_check(picked.size() == 8 and ids == sorted_ids and ids.size() == ids.duplicate().size(), "con más de 8 recompensas sortea 8 sin repetir y en orden")
	_check(catalog.pick_segments(many.slice(0, 5), pick_rng).size() == 5, "con 8 o menos usa todas")
	catalog.cache_path = "user://test_rewards_cache.json"
	catalog.clear_cache()
	_check(catalog.load_cache("s1").is_empty(), "sin caché devuelve vacío")
	catalog.save_cache("s1", clean)
	_check(catalog.load_cache("s1").size() == 1 and catalog.load_cache("otra").is_empty(), "la caché es por sucursal")
	catalog.clear_cache()
	catalog.cache_path = "user://rewards_cache.json"
	config.store_id = "store-9"
	config.machine_id = "machine-9"
	var ticket_script: GDScript = load("res://scripts/core/qr_ticket.gd")
	var with_prize: Dictionary = ticket_script.build_claims(500, "reward-1", 1000, "jti-1")
	var without: Dictionary = ticket_script.build_claims(500, "", 1000, "jti-1")
	_check(with_prize.reward_id == "reward-1" and not without.has("reward_id"), "el QR lleva reward_id solo si hubo recompensa")
	_check(with_prize.exp - with_prize.iat == 60 and with_prize.store_id == "store-9" and with_prize.machine_id == "machine-9", "el QR dura 60 s y lleva sucursal y máquina")
	_check(HelpTexts.topic("roulette").blocks.size() == 3, "la ruleta tiene su ayuda")
	catalog.image_dir = "user://test_reward_images"
	catalog.images = {}
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	catalog.images["a"] = texture
	var t0 := Time.get_ticks_msec()
	await catalog.ensure_images([
		{"id": "a", "imageUrl": "http://no-existe.invalid/a.png"},
		{"id": "b", "imageUrl": null},
		{"id": "c", "imageUrl": ""},
		{"id": "d", "imageUrl": "http://no-existe.invalid/d.png"},
	])
	_check(catalog.images.size() == 1 and catalog.images["a"] == texture, "ensure_images no vuelve a bajar lo que ya tiene ni inventa imágenes")
	_check(Time.get_ticks_msec() - t0 < 1000, "sin imagen ni red no se queda esperando")
	catalog.images = {}
	var disk_url := "http://no-existe.invalid/foto.png"
	var photo := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	photo.fill(Color.RED)
	catalog.save_image_cache("r-1", disk_url, ImageTexture.create_from_image(photo))
	await catalog.ensure_images([{"id": "r-1", "imageUrl": disk_url}])
	_check(catalog.images.has("r-1") and catalog.images["r-1"].get_width() == 4, "sin red, la imagen sale del disco tras un reinicio")
	_check(catalog.load_image_cache("r-1", "http://no-existe.invalid/otra.png") == null, "si cambia la URL, la imagen vieja ya no sirve")
	_check(catalog.image_path("../escape", disk_url).is_empty() and catalog.image_path("r-1", "").is_empty(), "un id con caracteres raros no se usa como nombre de archivo")
	catalog.save_image_cache("viejo", disk_url, ImageTexture.create_from_image(photo))
	catalog.prune_image_cache([{"id": "r-1", "imageUrl": disk_url}])
	_check(catalog.load_image_cache("r-1", disk_url) != null and catalog.load_image_cache("viejo", disk_url) == null, "limpiar borra lo que ya no existe y conserva lo vigente")
	catalog.prune_image_cache([])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog.image_dir))
	catalog.image_dir = "user://reward_images"
	catalog.images = {}

	print("QrCode")
	var qr := QrCode.encode_text("HELLO WORLD", QrCode.Ecc.MEDIUM)
	_check(qr.version == 1 and qr.size == 21, "texto corto cabe en la versión 1")
	_check(qr.get_module(0, 0) and qr.get_module(6, 0) and not qr.get_module(1, 1), "tiene el patrón de esquina")
	_check(QrCode.encode_text("x".repeat(5000)) == null, "devuelve null si no cabe")
	var big := QrCode.encode_text("y".repeat(356), QrCode.Ecc.MEDIUM)
	_check(big != null and big.version <= 15, "un token de ~356 caracteres cabe en la versión 15 o menos")

	print()
	if _failures == 0:
		print("Todas las pruebas pasaron")
	else:
		printerr("%d prueba(s) fallaron" % _failures)
	quit(1 if _failures > 0 else 0)
