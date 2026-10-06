class_name GameHud
extends Control
## HUD común de los juegos: puntaje, tiempo, vidas, multiplicador, cuenta atrás y
## diálogo de abandono. Lee el estado del juego; no lo modifica salvo por el diálogo.

const MARGIN := 64.0

var game: ArcadeGame
var _dialog: Control
var _dialog_body: Label
var _keep_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dialog()


func _process(_delta: float) -> void:
	queue_redraw()
	if _dialog.visible:
		_dialog_body.text = Strings.ABANDON_BODY % ceili(game.abandon_left)


func _draw() -> void:
	if game == null:
		return
	var k: ScoreKeeper = game.keeper
	var display := UiKit.display(900)
	var label := UiKit.text(700)

	# Puntaje (arriba izquierda)
	draw_string(label, Vector2(MARGIN, MARGIN + 22), Strings.HUD_SCORE, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TenantTheme.TEXT_SECONDARY)
	draw_string(display, Vector2(MARGIN, MARGIN + 112), str(k.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 96, TenantTheme.REWARD)

	# Tiempo (arriba centro): en los últimos 10 s pasa a advertencia y late.
	var left: float = game.time_left()
	var urgent := left <= 10.0 and game.phase == game.Phase.PLAYING
	var time_color := TenantTheme.WARNING if urgent else TenantTheme.TEXT
	var pulse := 1.0 + (sin(left * TAU) * 0.06 if urgent and not AppConfig.reduce_motion else 0.0)
	draw_string(label, Vector2(0, MARGIN + 22), Strings.HUD_TIME, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, TenantTheme.TEXT_SECONDARY)
	draw_string(display, Vector2(0, MARGIN + 112), "%02d" % ceili(left), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(96 * pulse), time_color)
	if urgent:
		_draw_clock(Vector2(size.x / 2 + 88, MARGIN + 70), time_color)

	# Vidas (arriba derecha): la vida perdida es contorno vacío, no solo color apagado.
	draw_string(label, Vector2(0, MARGIN + 22), Strings.HUD_LIVES, HORIZONTAL_ALIGNMENT_RIGHT, size.x - MARGIN, 24, TenantTheme.TEXT_SECONDARY)
	for i in ScoreKeeper.MAX_LIVES:
		var c := Vector2(size.x - MARGIN - 36 - i * 84.0, MARGIN + 74)
		game.draw_life(self, c, i < k.lives)

	# Multiplicador (abajo izquierda)
	var mult := k.multiplier()
	draw_string(display, Vector2(MARGIN, size.y - MARGIN - 28), "x%d" % mult, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, TenantTheme.TEXT if mult == 1 else TenantTheme.REWARD)
	var bar := Rect2(Vector2(MARGIN, size.y - MARGIN - 8), Vector2(220, 14))
	draw_rect(bar, TenantTheme.NIGHT_RAISED)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k.streak_progress(), bar.size.y)), TenantTheme.primary)
	draw_rect(bar, TenantTheme.TEXT_SECONDARY, false, 3.0)

	_draw_banner(display)


func _draw_banner(display: Font) -> void:
	var center_y := size.y * 0.42
	if game.phase == game.Phase.COUNTDOWN:
		var step: float = game.countdown
		var number := ceili(step / game.COUNTDOWN_STEP)
		var text := str(number) if number > 0 else Strings.COUNT_GO
		var frac := fmod(step, game.COUNTDOWN_STEP) / game.COUNTDOWN_STEP
		var grow := 1.0 if AppConfig.reduce_motion else 1.0 + frac * 0.4
		_draw_big(display, text, center_y, int(180 * grow), TenantTheme.primary)
	elif game.phase == game.Phase.ENDING:
		var reason: String = Strings.END_LIVES if game.end_reason == "lives" else Strings.END_TIME
		_draw_big(display, Strings.END_TITLE, center_y, 140, TenantTheme.TEXT)
		draw_string(UiKit.text(600), Vector2(0, center_y + 60), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, TenantTheme.TEXT_SECONDARY)


func _draw_big(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	# Sombra dura detrás, como las tarjetas.
	draw_string(font, Vector2(8, y + 8), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)


func _draw_clock(c: Vector2, color: Color) -> void:
	draw_arc(c, 18, 0, TAU, 24, color, 4.0)
	draw_line(c, c + Vector2(0, -12), color, 4.0)
	draw_line(c, c + Vector2(9, 4), color, 4.0)


# --- Diálogo de abandono ----------------------------------------------------

func show_abandon() -> void:
	_dialog.visible = true
	_keep_button.grab_focus()


func _build_dialog() -> void:
	_dialog = ColorRect.new()
	(_dialog as ColorRect).color = Color(0, 0, 0, 0.8)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.visible = false
	add_child(_dialog)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(false, false))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	panel.add_child(box)

	var title := Label.new()
	title.text = Strings.ABANDON_TITLE
	title.add_theme_font_override("font", UiKit.display(900))
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", TenantTheme.TEXT)
	box.add_child(title)

	_dialog_body = Label.new()
	_dialog_body.add_theme_font_override("font", UiKit.text(500))
	_dialog_body.add_theme_font_size_override("font_size", 30)
	_dialog_body.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	box.add_child(_dialog_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_keep_button = UiKit.button(Strings.ABANDON_KEEP, true)
	_keep_button.pressed.connect(_on_keep)
	row.add_child(_keep_button)
	var quit_button := UiKit.button(Strings.ABANDON_QUIT, false, true)
	quit_button.pressed.connect(func() -> void: game.quit_to_menu())
	row.add_child(quit_button)


func _on_keep() -> void:
	_dialog.visible = false
	game.resume_game()
