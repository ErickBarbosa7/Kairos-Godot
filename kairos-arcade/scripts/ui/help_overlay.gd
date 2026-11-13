class_name HelpOverlay
extends CanvasLayer
## Botón "?" en la esquina inferior derecha y un panel de ayuda corto: tres pasos y una línea sobre
## la pantalla actual. Se abre con el botón, con la tecla H o con ↓ en el
## menú. Mientras está abierto no deja pasar teclas a la pantalla de abajo.

const IDLE_CLOSE_SECONDS := 30.0
const MARGIN := 64
const BUTTON_SIZE := 72

var is_open := false

var _topic := ""
var _extra: Callable
var _focusable := true
var _button: Button
var _panel: Control
var _left: VBoxContainer
var _close: Button
var _previous_focus: Control
var _idle := 0.0


## Añade el botón y el panel a una pantalla. `extra` (opcional) devuelve bloques adicionales
## { heading, text } que se calculan al abrir. `focusable` false evita que el botón robe las
## flechas en pantallas que manejan su propia navegación.
static func attach(parent: Node, topic: String, extra: Callable = Callable(), focusable: bool = true) -> HelpOverlay:
	var overlay := HelpOverlay.new()
	overlay.layer = 20
	overlay._topic = topic
	overlay._extra = extra
	overlay._focusable = focusable
	parent.add_child(overlay)
	return overlay


func _ready() -> void:
	_build_button()
	_build_panel()


func set_topic(topic: String) -> void:
	_topic = topic


func open() -> void:
	if is_open:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_fill()
	_panel.visible = true
	is_open = true
	_idle = 0.0
	_close.grab_focus()


func close() -> void:
	if not is_open:
		return
	_panel.visible = false
	is_open = false
	if _previous_focus != null and is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree():
		_previous_focus.grab_focus()


func _process(delta: float) -> void:
	if not is_open:
		return
	_idle += delta
	if _idle >= IDLE_CLOSE_SECONDS:
		close()


func _input(event: InputEvent) -> void:
	if is_open and (event is InputEventKey or event is InputEventMouseButton):
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if is_open:
		if event.is_action_pressed("help") or event.is_action_pressed("back"):
			close()
		viewport.set_input_as_handled()
	elif event.is_action_pressed("help"):
		open()
		viewport.set_input_as_handled()


func _build_button() -> void:
	_button = Button.new()
	_button.text = Strings.HELP_BUTTON
	_button.focus_mode = Control.FOCUS_ALL if _focusable else Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	_button.add_theme_font_override("font", UiKit.display(900))
	_button.add_theme_font_size_override("font_size", 52)
	var color := TenantTheme.TEXT
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(state, color)
	for state in ["normal", "hover", "pressed"]:
		_button.add_theme_stylebox_override(state, _round_box(TenantTheme.NIGHT_RAISED, TenantTheme.TEXT_SECONDARY, 4))
	var focus := _round_box(Color.TRANSPARENT, Color.WHITE, 8)
	focus.draw_center = false
	_button.add_theme_stylebox_override("focus", focus)
	_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.offset_left = -MARGIN - BUTTON_SIZE
	_button.offset_top = -MARGIN - BUTTON_SIZE
	_button.offset_right = -MARGIN
	_button.offset_bottom = -MARGIN
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_button.pressed.connect(open)
	add_child(_button)


static func _round_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(BUTTON_SIZE / 2)
	return s


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	add_child(dim)
	_panel = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style(false, false))
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(960, 0)
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)

	box.add_child(_text(HelpTexts.GENERAL_TITLE, UiKit.display(900), 64, TenantTheme.TEXT, 0))
	for i in HelpTexts.GENERAL_STEPS.size():
		box.add_child(_step(i + 1, HelpTexts.GENERAL_STEPS[i]))

	var divider := ColorRect.new()
	divider.color = TenantTheme.NIGHT_LINE
	divider.custom_minimum_size = Vector2(0, 4)
	box.add_child(divider)

	# Lo de la pantalla actual: una línea (y las reglas del juego, en el menú).
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	box.add_child(_left)

	_close = UiKit.button(Strings.HELP_CLOSE, true)
	_close.custom_minimum_size = Vector2(320, 80)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_close.pressed.connect(close)
	box.add_child(_close)


## Rellena la parte de la pantalla actual: su línea de ayuda y los bloques extra del momento.
func _fill() -> void:
	for child in _left.get_children():
		child.queue_free()
	var data := HelpTexts.topic(_topic)
	_left.add_child(_text(str(data.title).to_upper(), UiKit.display(800), 32, TenantTheme.primary, 0))
	if not str(data.hint).is_empty():
		_left.add_child(_text(str(data.hint), UiKit.text(600), 30, TenantTheme.TEXT, 900))
	if _extra.is_valid():
		var more: Variant = _extra.call()
		if typeof(more) == TYPE_ARRAY:
			for block in more:
				_left.add_child(_text(str(block.text), UiKit.text(500), 28, TenantTheme.TEXT_SECONDARY, 900))


func _step(number: int, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var badge := PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
	var n := _text(str(number), UiKit.display(900), 32, TenantTheme.on_primary, 0)
	n.custom_minimum_size = Vector2(28, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(n)
	row.add_child(badge)
	row.add_child(_text(text, UiKit.text(500), 28, TenantTheme.TEXT, 560))
	return row


static func _text(text: String, font: Font, size: int, color: Color, width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l
