extends Control
## Marcador: los 10 mejores de cada juego. Izquierda/derecha cambia de juego.

const GAMES_DIR := "res://resources/games"
const MARGIN := 64

var _games: Array[GameInfo] = []
var _index := 0
var _title: Label
var _rows: VBoxContainer


func _ready() -> void:
	for file in DirAccess.get_files_at(GAMES_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var info := load("%s/%s" % [GAMES_DIR, name]) as GameInfo
			if info and info.playable:
				_games.append(info)
	_games.sort_custom(func(a: GameInfo, b: GameInfo) -> bool: return a.sort_order < b.sort_order)
	for i in _games.size():
		if _games[i].id == Router.scoreboard_game_id:
			_index = i
	_build()
	_fill()
	HelpOverlay.attach(self, "scoreboard", Callable(), false)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("move_left"):
		_index = (_index - 1 + _games.size()) % _games.size()
		_fill()
	elif event.is_action_pressed("move_right"):
		_index = (_index + 1) % _games.size()
		_fill()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("back"):
		viewport.set_input_as_handled()
		get_tree().change_scene_to_file(Router.scoreboard_return)
		return
	else:
		return
	viewport.set_input_as_handled()


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

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var heading := RichTextLabel.new()
	heading.bbcode_enabled = true
	heading.fit_content = true
	heading.scroll_active = false
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_override("normal_font", UiKit.display(900))
	heading.add_theme_font_size_override("normal_font_size", 88)
	heading.add_theme_color_override("default_color", TenantTheme.TEXT)
	heading.text = Strings.SCOREBOARD_TITLE
	head.add_child(heading)
	_title = Label.new()
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.add_theme_font_override("font", UiKit.display(900))
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", TenantTheme.primary)
	head.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	col.add_child(_rows)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 40)
	footer.add_child(_help("← →", Strings.SCOREBOARD_SWITCH))
	footer.add_child(_help(Strings.KEY_SPACE, Strings.SCOREBOARD_BACK))
	col.add_child(footer)


func _fill() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var game := _games[_index]
	_title.text = game.title
	var list := ScoreStore.entries(game.id)
	var mine := ArcadeState.last_rank if ArcadeState.game_id == game.id else 0
	for i in ScoreStore.MAX_ENTRIES:
		var entry: Dictionary = list[i] if i < list.size() else {}
		_rows.add_child(_row(i + 1, entry, mine == i + 1))


func _row(rank: int, entry: Dictionary, highlight: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)
	var style := StyleBoxFlat.new()
	style.bg_color = TenantTheme.NIGHT_RAISED if highlight else Color.TRANSPARENT
	style.set_border_width_all(4 if highlight else 0)
	style.border_color = TenantTheme.primary
	style.border_width_bottom = 4 if highlight else 2
	if not highlight:
		style.border_color = TenantTheme.NIGHT_LINE
	style.content_margin_left = 24
	style.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	panel.add_child(row)
	var empty := entry.is_empty()
	var color := TenantTheme.TEXT_SECONDARY if empty else (TenantTheme.primary if highlight else TenantTheme.TEXT)
	row.add_child(_cell(str(rank), 56, TenantTheme.TEXT_SECONDARY, 100, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_cell(Strings.SCOREBOARD_EMPTY if empty else str(entry.name), 56, color, 220, HORIZONTAL_ALIGNMENT_LEFT))
	var you := _cell(Strings.SCOREBOARD_YOU if highlight else "", 40, TenantTheme.REWARD, 0, HORIZONTAL_ALIGNMENT_LEFT)
	you.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(you)
	row.add_child(_cell("" if empty else str(entry.score), 56, TenantTheme.REWARD if not empty else TenantTheme.TEXT_SECONDARY, 280, HORIZONTAL_ALIGNMENT_RIGHT))
	return panel


func _cell(text: String, font_size: int, color: Color, min_width: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(min_width, 0)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiKit.display(900))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _help(key: String, action: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.NIGHT_RAISED, TenantTheme.TEXT_SECONDARY))
	var k := Label.new()
	k.text = key
	k.add_theme_font_override("font", UiKit.display(800))
	k.add_theme_font_size_override("font_size", 32)
	chip.add_child(k)
	box.add_child(chip)
	var l := Label.new()
	l.text = action
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override("font", UiKit.text(600))
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	box.add_child(l)
	return box
