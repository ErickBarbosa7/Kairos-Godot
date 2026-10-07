extends Control
## Resultado: puntaje, puesto, y a la derecha el QR (si se llegó a la meta) o el avance
## hacia la meta (si no). El QR se firma al abrir esta pantalla, así que su vigencia de
## 60 s empieza cuando el jugador ya terminó de poner sus iniciales.

const MARGIN := 64
const QR_SIDE := 480
const IDLE_TO_MENU := 90.0
const STEP := 0.4

var _score_label: Label
var _chip: Control
var _again: Button
var _idle := 0.0
var _ticket: QrTicket
var _qr_slot: VBoxContainer
var _seconds: Label
var _bar_fill: ColorRect
var _bar_back: ColorRect
var _expired_shown := false


func _ready() -> void:
	_build()
	_animate()
	HelpOverlay.attach(self, "result")


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
	board.custom_minimum_size = Vector2(0, 96)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.pressed.connect(func() -> void: Router.to_scoreboard(ArcadeState.game_id, Router.RESULT))
	var menu := UiKit.button(Strings.RESULT_MENU, false)
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
	if not QrPolicy.earned(score, goal):
		_build_goal_panel(goal, score)
		return center
	var reward: Dictionary = ArcadeState.won_reward
	if reward.is_empty():
		# Llegó a la meta pero el negocio no tiene recompensas que girar.
		_qr_slot.add_child(_info_panel(Strings.NO_REWARDS_TITLE, Strings.NO_REWARDS_NOTE, TenantTheme.WARNING))
		return center
	_ticket = QrTicket.create(score, str(reward.id))
	if _ticket.problem != QrTicket.Problem.NONE:
		_build_problem_panel(_ticket.problem)
		return center
	var qr := QrCode.encode_text(_ticket.token, QrCode.Ecc.MEDIUM)
	if qr == null:
		_ticket.problem = QrTicket.Problem.SIGN_FAILED
		_build_problem_panel(_ticket.problem)
		return center
	PlayStats.record_qr_issued(ArcadeState.game_id)
	_build_qr_panel(qr, reward)
	return center


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
	# Qué ganó, encima del código: es lo primero que debe ver.
	_qr_slot.add_child(_label(Strings.RESULT_REWARD_LABEL, UiKit.text(700), 24, TenantTheme.TEXT_SECONDARY))
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
	_qr_slot.add_child(banner)
	var panel := _white_panel()
	var view := QrView.new()
	view.setup(qr, QR_SIDE)
	panel.add_child(view)
	_qr_slot.add_child(panel)

	var timer_row := HBoxContainer.new()
	timer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_row.add_theme_constant_override("separation", 16)
	timer_row.add_child(_label(Strings.QR_VALID, UiKit.text(700), 28, TenantTheme.TEXT_SECONDARY))
	_seconds = _label("60", UiKit.display(900), 72, TenantTheme.TEXT)
	timer_row.add_child(_seconds)
	timer_row.add_child(_label("s", UiKit.display(800), 40, TenantTheme.TEXT_SECONDARY))
	_qr_slot.add_child(timer_row)

	_bar_back = ColorRect.new()
	_bar_back.color = TenantTheme.NIGHT_RAISED
	_bar_back.custom_minimum_size = Vector2(view.custom_minimum_size.x, 14)
	_bar_fill = ColorRect.new()
	_bar_fill.color = TenantTheme.primary
	_bar_fill.size = Vector2(view.custom_minimum_size.x, 14)
	_bar_back.add_child(_bar_fill)
	_qr_slot.add_child(_bar_back)

	var hint := _label(Strings.QR_SCAN, UiKit.text(600), 28, TenantTheme.TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(view.custom_minimum_size.x, 0)
	_qr_slot.add_child(hint)


func _show_expired() -> void:
	_expired_shown = true
	for child in _qr_slot.get_children():
		child.queue_free()
	_qr_slot.add_child(_info_panel(Strings.QR_EXPIRED_TITLE, Strings.QR_EXPIRED_NOTE, TenantTheme.WARNING))


func _build_goal_panel(goal: int, score: int) -> void:
	if goal <= 0:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(QR_SIDE + 64, 0)
	box.add_child(_label(Strings.GOAL_TITLE, UiKit.display(900), 56, TenantTheme.TEXT))
	var note := _label(Strings.GOAL_NOTE % (goal - score), UiKit.text(600), 32, TenantTheme.TEXT_SECONDARY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

	var back := ColorRect.new()
	back.color = TenantTheme.NIGHT_RAISED
	back.custom_minimum_size = Vector2(0, 28)
	var fill := ColorRect.new()
	fill.color = TenantTheme.primary
	fill.size = Vector2((QR_SIDE + 64) * clampf(float(score) / goal, 0.0, 1.0), 28)
	back.add_child(fill)
	box.add_child(back)

	var numbers := HBoxContainer.new()
	numbers.add_child(_label(str(score), UiKit.display(900), 48, TenantTheme.REWARD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numbers.add_child(spacer)
	numbers.add_child(_label(Strings.GOAL_TARGET % goal, UiKit.display(900), 48, TenantTheme.TEXT))
	box.add_child(numbers)

	var tip := _label(Strings.GOAL_TIP, UiKit.accent(), 36, TenantTheme.TEXT_SECONDARY)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(false, false))
	panel.add_child(box)
	_qr_slot.add_child(panel)


func _build_problem_panel(problem: QrTicket.Problem) -> void:
	var note := Strings.QR_PROBLEM_SIGN
	if problem == QrTicket.Problem.NOT_CONFIGURED:
		note = Strings.QR_PROBLEM_CONFIG
	elif problem == QrTicket.Problem.NO_KEY:
		note = Strings.QR_PROBLEM_KEY
	_qr_slot.add_child(_info_panel(Strings.QR_PROBLEM_TITLE, note, TenantTheme.DANGER))


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
