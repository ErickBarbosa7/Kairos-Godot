extends Control
## Resultado: puntaje, puesto, y a la derecha el QR (si se llegó a la meta) o el avance
## hacia la meta (si no). El QR se firma al abrir esta pantalla, así que su vigencia de
## 60 s empieza cuando el jugador ya terminó de poner sus iniciales.

const MARGIN := 64
const QR_SIDE := 480
const POINTS_QR_SIDE := 280
const IDLE_TO_MENU := 90.0
const STEP := 0.4

var _score_label: Label
var _chip: Control
var _again: Button
var _board: Button
var _menu: Button
var _idle := 0.0
var _ticket: QrTicket
var _qr_slot: VBoxContainer
## Donde vive el QR (y su aviso de vencimiento). En el modo de puntos comparte columna con el avance a la meta.
var _ticket_box: VBoxContainer
var _points_mode := false
var _seconds: Label
var _bar_fill: ColorRect
var _bar_back: ColorRect
var _expired_shown := false


func _ready() -> void:
	_build()
	_wire_focus()
	_animate()
	HelpOverlay.attach(self, "result")


## Orden fijo para las flechas: "Jugar otra vez" arriba; "Marcador" y "Volver al menú" abajo.
## La búsqueda automática por posición saltaba "Volver al menú" desde "Jugar otra vez".
func _wire_focus() -> void:
	_link(_again, _again, _board, _again, _board)  # arriba, abajo, izquierda, derecha
	_link(_board, _again, _again, _board, _menu)
	_link(_menu, _again, _again, _board, _menu)


func _link(b: Button, up: Control, down: Control, left: Control, right: Control) -> void:
	b.focus_neighbor_top = b.get_path_to(up)
	b.focus_neighbor_bottom = b.get_path_to(down)
	b.focus_neighbor_left = b.get_path_to(left)
	b.focus_neighbor_right = b.get_path_to(right)


func _process(delta: float) -> void:
	_idle += delta
	if _ticket != null and _ticket.problem == QrTicket.Problem.NONE and not _expired_shown:
		var left := _ticket.seconds_left()
		_seconds.text = "%d" % ceili(left)
		_bar_fill.size.x = _bar_back.size.x * (left / QrTicket.LIFETIME_SECONDS)
		_seconds.add_theme_color_override("font_color", TenantTheme.WARNING if left <= 15.0 else TenantTheme.TEXT)
		if left <= 0.0:
			_show_expired()
	if _idle >= IDLE_TO_MENU:
		set_process(false)
		Router.to_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Esc / botón "back": salida siempre disponible, también tras morir.
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		set_process(false)
		Router.to_menu()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = TenantTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 80)
	root.add_child(row)
	row.add_child(_build_left())
	row.add_child(_build_right())


func _build_left() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)

	col.add_child(_label(Strings.END_TITLE, UiKit.display(900), 72, TenantTheme.TEXT))
	col.add_child(_label(Strings.END_LIVES if ArcadeState.last_reason == "lives" else Strings.END_TIME, UiKit.accent(), 44, TenantTheme.TEXT_SECONDARY))
	col.add_child(_label(Strings.RESULT_SCORE, UiKit.text(700), 26, TenantTheme.TEXT_SECONDARY))

	_score_label = _label("0", UiKit.display(900), 168, TenantTheme.REWARD)
	col.add_child(_score_label)

	_chip = _build_chip()
	if _chip != null:
		_chip.modulate.a = 0.0
		col.add_child(_chip)

	var best := ScoreStore.best(ArcadeState.game_id)
	col.add_child(_label(Strings.RESULT_BEST % best, UiKit.text(600), 28, TenantTheme.TEXT_SECONDARY))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	col.add_child(spacer)

	_again = UiKit.button(Strings.RESULT_AGAIN, true)
	_again.pressed.connect(_play_again)
	col.add_child(_again)

	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 16)
	var board := UiKit.button(Strings.RESULT_SCOREBOARD, false)
	_board = board
	board.custom_minimum_size = Vector2(0, 96)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.pressed.connect(func() -> void: Router.to_scoreboard(ArcadeState.game_id, Router.RESULT))
	var menu := UiKit.button(Strings.RESULT_MENU, false)
	_menu = menu
	menu.custom_minimum_size = Vector2(0, 96)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(Router.to_menu)
	secondary.add_child(board)
	secondary.add_child(menu)
	col.add_child(secondary)
	_again.grab_focus.call_deferred()
	return col


## Insignia de récord o de puesto. Null si la partida no entró al marcador.
func _build_chip() -> Control:
	var record := ArcadeState.last_was_record and ArcadeState.last_score > 0
	if not record and ArcadeState.last_rank <= 0:
		return null
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	chip.add_child(row)
	if record:
		var star := StarIcon.new()
		star.color = TenantTheme.on_primary
		row.add_child(star)
	var text := Strings.RESULT_RECORD if record else Strings.RANK_CHIP % ArcadeState.last_rank
	row.add_child(_label(text, UiKit.display(900), 40, TenantTheme.on_primary))
	return chip


func _build_right() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qr_slot = VBoxContainer.new()
	_qr_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_qr_slot.add_theme_constant_override("separation", 12)
	center.add_child(_qr_slot)

	var goal := QrPolicy.goal_for(Router.current_game)
	var score := ArcadeState.last_score
	_ticket_box = VBoxContainer.new()
	_ticket_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ticket_box.add_theme_constant_override("separation", 12)
	if not QrPolicy.earned(score, goal):
		# No llegó a la meta: sin ruleta, pero sus puntos no se pierden. Se suman con un QR sin premio.
		_build_goal_panel(goal, score)
		_qr_slot.add_child(_ticket_box)
		if score > 0:
			_points_mode = true
			_start_points_ticket(score)
		return center
	_qr_slot.add_child(_ticket_box)
	var reward: Dictionary = ArcadeState.won_reward
	if reward.is_empty():
		# Llegó a la meta pero el negocio no tiene recompensas que girar.
		_ticket_box.add_child(_info_panel(Strings.NO_REWARDS_TITLE, Strings.NO_REWARDS_NOTE, TenantTheme.WARNING))
		return center
	if AppConfig.web_terminal:
		_ticket_box.add_child(_label("Preparando tu código…", UiKit.text(700), 30, TenantTheme.TEXT_SECONDARY))
		_load_web_ticket.call_deferred(score, reward)
		return center
	_ticket = QrTicket.create(score, str(reward.id))
	_build_ticket_panel(reward)
	return center


func _load_web_ticket(score: int, reward: Dictionary) -> void:
	_ticket = await QrTicket.create_web(score, str(reward.id))
	for child in _ticket_box.get_children():
		child.queue_free()
	_build_ticket_panel(reward)


## QR de puntos para quien no llegó a la meta. Si la máquina no puede firmar (modo de prueba, sin
## llave) no muestra nada: el aviso de "esta máquina no puede entregar recompensas" sería confuso aquí.
func _start_points_ticket(score: int) -> void:
	if AppConfig.web_terminal:
		_load_web_points_ticket.call_deferred(score)
		return
	_ticket = QrTicket.create(score)
	_build_ticket_panel({})


func _load_web_points_ticket(score: int) -> void:
	_ticket = await QrTicket.create_web(score)
	_build_ticket_panel({})


func _build_ticket_panel(reward: Dictionary) -> void:
	if _ticket == null or _ticket.problem != QrTicket.Problem.NONE:
		if _points_mode:
			_ticket = null
			return
		_build_problem_panel(_ticket.problem if _ticket != null else QrTicket.Problem.SIGN_FAILED)
		return
	var qr := QrCode.encode_text(QrTicket.qr_payload(_ticket.token, AppConfig.wallet_url), QrCode.Ecc.MEDIUM)
	if qr == null:
		if _points_mode:
			_ticket = null
			return
		_ticket.problem = QrTicket.Problem.SIGN_FAILED
		_build_problem_panel(_ticket.problem)
		return
	if not _points_mode:
		PlayStats.record_qr_issued(ArcadeState.game_id)
	_build_qr_panel(qr, reward)


func _white_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_border_width_all(6)
	style.border_color = TenantTheme.NIGHT_LINE
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 1
	style.shadow_offset = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_qr_panel(qr: QrCode, reward: Dictionary) -> void:
	var side := POINTS_QR_SIDE if _points_mode else QR_SIDE
	if _points_mode:
		_ticket_box.add_child(_label(Strings.POINTS_TITLE, UiKit.display(900), 40, TenantTheme.REWARD))
		_add_qr_view_and_timer(qr, side)
		return
	# Qué ganó, encima del código: es lo primero que debe ver.
	_ticket_box.add_child(_label(Strings.RESULT_REWARD_LABEL, UiKit.text(700), 24, TenantTheme.TEXT_SECONDARY))
	var picture: Texture2D = RewardCatalog.images.get(str(reward.id))
	var banner := HBoxContainer.new()
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_theme_constant_override("separation", 20)
	if picture != null:
		# La imagen que puso el administrador al crear la recompensa.
		var thumb := TextureRect.new()
		thumb.texture = picture
		thumb.custom_minimum_size = Vector2(120, 120)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.add_child(thumb)
	var reward_label := _label(str(reward.title), UiKit.display(900), 56, TenantTheme.REWARD)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.custom_minimum_size = Vector2((QR_SIDE - 140.0) if picture != null else (QR_SIDE + 40.0), 0)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if picture != null else HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(reward_label)
	_ticket_box.add_child(banner)
	_add_qr_view_and_timer(qr, side)


func _add_qr_view_and_timer(qr: QrCode, side: int) -> void:
	var panel := _white_panel()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var view := QrView.new()
	view.setup(qr, side)
	panel.add_child(view)
	_ticket_box.add_child(panel)

	var timer_row := HBoxContainer.new()
	timer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_row.add_theme_constant_override("separation", 16)
	timer_row.add_child(_label(Strings.QR_VALID, UiKit.text(700), 28, TenantTheme.TEXT_SECONDARY))
	_seconds = _label("60", UiKit.display(900), 72, TenantTheme.TEXT)
	timer_row.add_child(_seconds)
	timer_row.add_child(_label("s", UiKit.display(800), 40, TenantTheme.TEXT_SECONDARY))
	_ticket_box.add_child(timer_row)

	_bar_back = ColorRect.new()
	_bar_back.color = TenantTheme.NIGHT_RAISED
	_bar_back.custom_minimum_size = Vector2(view.custom_minimum_size.x, 14)
	_bar_fill = ColorRect.new()
	_bar_fill.color = TenantTheme.primary
	_bar_fill.size = Vector2(view.custom_minimum_size.x, 14)
	_bar_back.add_child(_bar_fill)
	_ticket_box.add_child(_bar_back)

	var hint := _label(Strings.POINTS_NOTE if _points_mode else Strings.QR_SCAN, UiKit.text(600), 28, TenantTheme.TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(view.custom_minimum_size.x, 0)
	_ticket_box.add_child(hint)


func _show_expired() -> void:
	_expired_shown = true
	for child in _ticket_box.get_children():
		child.queue_free()
	var note := Strings.QR_EXPIRED_POINTS_NOTE if _points_mode else Strings.QR_EXPIRED_NOTE
	_ticket_box.add_child(_info_panel(Strings.QR_EXPIRED_TITLE, note, TenantTheme.WARNING))


func _build_goal_panel(goal: int, score: int) -> void:
	if goal <= 0:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(QR_SIDE + 64, 0)
	var compact := _points_mode_pending(score)
	box.add_theme_constant_override("separation", 10 if compact else 20)
	box.add_child(_label(Strings.GOAL_TITLE, UiKit.display(900), 40 if compact else 56, TenantTheme.TEXT))
	var note := _label(Strings.GOAL_NOTE % (goal - score), UiKit.text(600), 24 if compact else 32, TenantTheme.TEXT_SECONDARY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

	var back := ColorRect.new()
	back.color = TenantTheme.NIGHT_RAISED
	back.custom_minimum_size = Vector2(0, 20 if compact else 28)
	var fill := ColorRect.new()
	fill.color = TenantTheme.primary
	fill.size = Vector2((QR_SIDE + 64) * clampf(float(score) / goal, 0.0, 1.0), 20 if compact else 28)
	back.add_child(fill)
	box.add_child(back)

	var numbers := HBoxContainer.new()
	numbers.add_child(_label(str(score), UiKit.display(900), 36 if compact else 48, TenantTheme.REWARD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numbers.add_child(spacer)
	numbers.add_child(_label(Strings.GOAL_TARGET % goal, UiKit.display(900), 36 if compact else 48, TenantTheme.TEXT))
	box.add_child(numbers)

	if not compact:
		var tip := _label(Strings.GOAL_TIP, UiKit.accent(), 36, TenantTheme.TEXT_SECONDARY)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(tip)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(false, false))
	panel.add_child(box)
	_qr_slot.add_child(panel)


## El panel de la meta se compacta cuando comparte columna con el QR de puntos.
func _points_mode_pending(score: int) -> bool:
	return score > 0


func _build_problem_panel(problem: QrTicket.Problem) -> void:
	var note := Strings.QR_PROBLEM_SIGN
	if problem == QrTicket.Problem.NOT_CONFIGURED:
		note = Strings.QR_PROBLEM_CONFIG
	elif problem == QrTicket.Problem.NO_KEY:
		note = Strings.QR_PROBLEM_KEY
	_ticket_box.add_child(_info_panel(Strings.QR_PROBLEM_TITLE, note, TenantTheme.DANGER))


func _info_panel(title: String, note: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	var style := UiKit.card_style(false, false)
	style.border_color = accent
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(QR_SIDE, 0)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_label(title, UiKit.display(900), 52, accent))
	var n := _label(note, UiKit.text(600), 30, TenantTheme.TEXT_SECONDARY)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(n)
	return panel


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _animate() -> void:
	var target := ArcadeState.last_score
	if AppConfig.reduce_motion or target == 0:
		_score_label.text = str(target)
		if _chip != null:
			_chip.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_interval(STEP)
	tween.tween_method(func(v: float) -> void: _score_label.text = str(int(v)), 0.0, float(target), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _chip != null:
		tween.tween_property(_chip, "modulate:a", 1.0, 0.2)


func _play_again() -> void:
	if not Router.start_game(Router.current_game):
		Router.to_menu()
