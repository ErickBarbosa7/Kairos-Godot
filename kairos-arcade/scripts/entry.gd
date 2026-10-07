extends Control
## Iniciales para el marcador: 3 caracteres, como en las máquinas de antes.
## Flechas arriba/abajo cambian la letra, izquierda/derecha cambian de casilla.

const IDLE_SAVE := 30.0
const SLOTS := 3

var _chars: Array[int] = [0, 0, 0]
var _slot := 0
var _idle := 0.0
var _boxes: Array[PanelContainer] = []
var _letters: Array[Label] = []
var _ups: Array[ArrowIcon] = []
var _downs: Array[ArrowIcon] = []
var _done_box: PanelContainer
var _done_label: Label
var _error: Label
var _autosave: Label


func _ready() -> void:
	_build()
	_refresh()
	HelpOverlay.attach(self, "entry", Callable(), false)


func _process(delta: float) -> void:
	_idle += delta
	_autosave.text = Strings.ENTRY_AUTOSAVE % ceili(maxf(IDLE_SAVE - _idle, 0.0))
	if _idle >= IDLE_SAVE:
		set_process(false)
		_submit(true)


func _unhandled_input(event: InputEvent) -> void:
	# Se toma antes de actuar: confirmar puede cambiar de escena y soltar este nodo.
	var viewport := get_viewport()
	var handled := true
	if event.is_action_pressed("move_left"):
		_slot = maxi(_slot - 1, 0)
	elif event.is_action_pressed("move_right"):
		_slot = mini(_slot + 1, SLOTS)
	elif event.is_action_pressed("move_up"):
		_cycle(1)
	elif event.is_action_pressed("move_down"):
		_cycle(-1)
	elif event.is_action_pressed("confirm"):
		if _slot < SLOTS:
			_slot += 1
		else:
			_submit(false)
	else:
		handled = false
	if handled:
		_idle = 0.0
		_error.text = ""
		_error.visible = false
		if is_inside_tree():
			_refresh()
		viewport.set_input_as_handled()


func _cycle(step: int) -> void:
	if _slot >= SLOTS:
		return
	var count := ScoreStore.CHARSET.length()
	_chars[_slot] = (_chars[_slot] + step + count) % count


func _name() -> String:
	var out := ""
	for i in SLOTS:
		out += ScoreStore.CHARSET[_chars[i]]
	return out


func _submit(auto: bool) -> void:
	var initials := _name()
	if not ScoreStore.is_name_allowed(initials):
		if not auto:
			_error.text = Strings.ENTRY_BLOCKED
			_error.visible = true
			return
		initials = ScoreStore.DEFAULT_NAME
	var viewport := get_viewport()
	var rank := ScoreStore.add(ArcadeState.game_id, initials, ArcadeState.last_score)
	ArcadeState.last_rank = rank
	ArcadeState.last_initials = initials if rank > 0 else ""
	ArcadeState.entry_pending = false
	viewport.set_input_as_handled()
	Router.after_entry()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = TenantTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(_label(Strings.ENTRY_TITLE, UiKit.display(900), 72, TenantTheme.TEXT, true))

	var rank := ScoreStore.rank_for(ArcadeState.game_id, ArcadeState.last_score)
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
	chip.add_child(_label(Strings.ENTRY_RANK % rank, UiKit.display(900), 44, TenantTheme.on_primary, true))
	col.add_child(chip)

	col.add_child(_label(str(ArcadeState.last_score), UiKit.display(900), 112, TenantTheme.REWARD, true))
	col.add_child(_label(Strings.ENTRY_HINT % SLOTS, UiKit.accent(), 44, TenantTheme.TEXT_SECONDARY, true))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	col.add_child(row)
	for i in SLOTS:
		row.add_child(_build_slot(i))
	_done_box = PanelContainer.new()
	_done_box.custom_minimum_size = Vector2(300, 0)
	_done_label = _label(Strings.ENTRY_DONE, UiKit.display(900), 64, TenantTheme.TEXT, true)
	_done_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_done_box.add_child(_done_label)
	var done_wrap := VBoxContainer.new()
	done_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	done_wrap.add_child(_done_box)
	row.add_child(done_wrap)

	_error = _label("", UiKit.text(700), 34, TenantTheme.DANGER, true)
	_error.visible = false
	col.add_child(_error)

	var help := HBoxContainer.new()
	help.alignment = BoxContainer.ALIGNMENT_CENTER
	help.add_theme_constant_override("separation", 48)
	help.add_child(_help("↑ ↓", Strings.ENTRY_KEYS_CHANGE))
	help.add_child(_help("← →", Strings.ENTRY_KEYS_MOVE))
	help.add_child(_help(Strings.KEY_SPACE, Strings.ENTRY_KEYS_OK))
	col.add_child(help)

	_autosave = _label("", UiKit.text(500), 26, TenantTheme.TEXT_SECONDARY, true)
	col.add_child(_autosave)


func _build_slot(i: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	var up := ArrowIcon.new()
	up.up = true
	up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(up)
	_ups.append(up)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(180, 210)
	var letter := _label("A", UiKit.display(900), 160, TenantTheme.TEXT, true)
	letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(letter)
	wrap.add_child(box)
	_boxes.append(box)
	_letters.append(letter)
	var down := ArrowIcon.new()
	down.up = false
	down.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(down)
	_downs.append(down)
	return wrap


func _refresh() -> void:
	for i in SLOTS:
		var active := i == _slot
		_letters[i].text = ScoreStore.CHARSET[_chars[i]]
		_boxes[i].add_theme_stylebox_override("panel", UiKit.card_style(active, false))
		_ups[i].color = TenantTheme.primary
		_downs[i].color = TenantTheme.primary
		_ups[i].visible = active
		_downs[i].visible = active
	var done_active := _slot == SLOTS
	var style := UiKit.chip_style(TenantTheme.primary if done_active else Color.TRANSPARENT, TenantTheme.primary if done_active else TenantTheme.NIGHT_LINE)
	style.set_border_width_all(8 if done_active else 4)
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_done_box.add_theme_stylebox_override("panel", style)
	_done_label.add_theme_color_override("font_color", TenantTheme.on_primary if done_active else TenantTheme.TEXT_SECONDARY)


func _label(text: String, font: Font, font_size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _help(key: String, action: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.NIGHT_RAISED, TenantTheme.TEXT_SECONDARY))
	chip.add_child(_label(key, UiKit.display(800), 32, TenantTheme.TEXT, false))
	box.add_child(chip)
	var l := _label(action, UiKit.text(600), 28, TenantTheme.TEXT_SECONDARY, false)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	return box
