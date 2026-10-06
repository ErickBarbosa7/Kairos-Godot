extends Control
## Pantalla de resultado: puntaje, récord, espacio reservado para el QR y dos acciones.
## El QR firmado llega en la Fase 4; aquí queda su panel blanco con el tamaño final.

const MARGIN := 64
const QR_SIZE := 480
const IDLE_TO_MENU := 90.0
const STEP := 0.4

var _score_label: Label
var _record: Control
var _again: Button
var _idle := 0.0


func _ready() -> void:
	_build()
	_animate()


func _process(delta: float) -> void:
	_idle += delta
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
	row.add_theme_constant_override("separation", 96)
	root.add_child(row)

	row.add_child(_build_left())
	row.add_child(_build_qr())


func _build_left() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)

	var title := Label.new()
	title.text = Strings.END_TITLE
	title.add_theme_font_override("font", UiKit.display(900))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", TenantTheme.TEXT)
	col.add_child(title)

	var reason := Label.new()
	reason.text = Strings.END_LIVES if ArcadeState.last_reason == "lives" else Strings.END_TIME
	reason.add_theme_font_override("font", UiKit.accent())
	reason.add_theme_font_size_override("font_size", 48)
	reason.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	col.add_child(reason)

	var caption := Label.new()
	caption.text = Strings.RESULT_SCORE
	caption.add_theme_font_override("font", UiKit.text(700))
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	col.add_child(caption)

	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.add_theme_font_override("font", UiKit.display(900))
	_score_label.add_theme_font_size_override("font_size", 192)
	_score_label.add_theme_color_override("font_color", TenantTheme.REWARD)
	col.add_child(_score_label)

	_record = _build_record_chip()
	_record.modulate.a = 0.0
	_record.visible = ArcadeState.last_was_record and ArcadeState.last_score > 0
	col.add_child(_record)

	var best := Label.new()
	best.text = Strings.RESULT_BEST % ArcadeState.best_score
	best.add_theme_font_override("font", UiKit.text(600))
	best.add_theme_font_size_override("font_size", 28)
	best.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	col.add_child(best)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)

	_again = UiKit.button(Strings.RESULT_AGAIN, true)
	_again.pressed.connect(_play_again)
	var menu := UiKit.button(Strings.RESULT_MENU, false)
	menu.pressed.connect(Router.to_menu)
	col.add_child(_again)
	col.add_child(menu)
	_again.grab_focus.call_deferred()
	return col


func _build_record_chip() -> Control:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	chip.add_child(row)
	var star := StarIcon.new()
	star.color = TenantTheme.on_primary
	row.add_child(star)
	var label := Label.new()
	label.text = Strings.RESULT_RECORD
	label.add_theme_font_override("font", UiKit.display(900))
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", TenantTheme.on_primary)
	row.add_child(label)
	return chip


func _build_qr() -> Control:
	var center := CenterContainer.new()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(QR_SIZE + 64, QR_SIZE + 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_border_width_all(6)
	style.border_color = TenantTheme.NIGHT_LINE
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 1
	style.shadow_offset = Vector2(12, 12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.text = Strings.RESULT_QR_SOON
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", UiKit.display(900))
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.BLACK)
	box.add_child(title)

	var note := Label.new()
	note.text = Strings.RESULT_QR_NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_override("font", UiKit.text(500))
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", Color("#3A3A3A"))
	box.add_child(note)
	return center


func _animate() -> void:
	var target := ArcadeState.last_score
	if AppConfig.reduce_motion or target == 0:
		_score_label.text = str(target)
		_record.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_interval(STEP)
	tween.tween_method(func(v: float) -> void: _score_label.text = str(int(v)), 0.0, float(target), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_record, "modulate:a", 1.0, 0.2)


func _play_again() -> void:
	if not Router.start_game(Router.current_game):
		Router.to_menu()
