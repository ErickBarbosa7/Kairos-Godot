extends Control
## Menú de juegos: tres tarjetas, navegación con las acciones del InputMap.

const GAMES_DIR := "res://resources/games"
const MARGIN := 64

var _cards: Array[GameCard] = []
var _index := 0
var _logo: TextureRect
var _logo_fallback: ColorRect
var _name: Label
var _notice: Label


func _ready() -> void:
	_build()
	TenantTheme.theme_changed.connect(_apply_brand)
	_apply_brand()
	_select(_first_playable())


func _unhandled_input(event: InputEvent) -> void:
	# Se toma antes de actuar: confirmar puede cambiar de escena y soltar este nodo.
	var viewport := get_viewport()
	if event.is_action_pressed("move_left"):
		_select(_index - 1)
	elif event.is_action_pressed("move_right"):
		_select(_index + 1)
	elif event.is_action_pressed("confirm"):
		_confirm()
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

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	root.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_title())

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	column.add_child(row)
	for game in _load_games():
		var card := GameCard.new()
		card.setup(game)
		_cards.append(card)
		row.add_child(card)

	column.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)

	var logo_slot := Control.new()
	logo_slot.custom_minimum_size = Vector2(96, 96)
	header.add_child(logo_slot)
	_logo = TextureRect.new()
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_slot.add_child(_logo)
	_logo_fallback = ColorRect.new()
	_logo_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_slot.add_child(_logo_fallback)

	_name = Label.new()
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.add_theme_font_override("font", UiKit.display(800))
	_name.add_theme_font_size_override("font_size", 48)
	header.add_child(_name)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var signature := Label.new()
	signature.text = "%s kairos" % Strings.POWERED_BY
	signature.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	signature.add_theme_font_override("font", UiKit.accent())
	signature.add_theme_font_size_override("font_size", 32)
	signature.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	header.add_child(signature)
	return header


func _build_title() -> Control:
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_override("normal_font", UiKit.display(900))
	title.add_theme_font_override("italics_font", UiKit.accent())
	title.add_theme_font_size_override("normal_font_size", 88)
	title.add_theme_font_size_override("italics_font_size", 96)
	title.add_theme_color_override("default_color", TenantTheme.TEXT)
	title.text = "%s[i]%s[/i]" % [Strings.MENU_TITLE_PREFIX.to_upper(), Strings.MENU_TITLE_WORD]
	return title


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 40)
	footer.add_child(_help(Strings.KEY_LEFT_RIGHT, Strings.HELP_CHOOSE))
	footer.add_child(_help(Strings.KEY_SPACE, Strings.HELP_PLAY))

	_notice = Label.new()
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice.add_theme_font_override("font", UiKit.text(600))
	_notice.add_theme_font_size_override("font_size", 28)
	footer.add_child(_notice)
	return footer


func _help(key: String, action: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.NIGHT_RAISED, TenantTheme.TEXT_SECONDARY))
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_override("font", UiKit.display(800))
	key_label.add_theme_font_size_override("font_size", 32)
	chip.add_child(key_label)
	box.add_child(chip)
	var label := Label.new()
	label.text = action
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_override("font", UiKit.text(600))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	box.add_child(label)
	return box


func _load_games() -> Array[GameInfo]:
	var games: Array[GameInfo] = []
	for file in DirAccess.get_files_at(GAMES_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var info := load("%s/%s" % [GAMES_DIR, name]) as GameInfo
			if info:
				games.append(info)
	games.sort_custom(func(a: GameInfo, b: GameInfo) -> bool: return a.sort_order < b.sort_order)
	return games


func _apply_brand() -> void:
	_name.text = TenantTheme.tenant_name.to_upper()
	_name.add_theme_color_override("font_color", TenantTheme.TEXT)
	_logo.texture = TenantTheme.logo
	_logo.visible = TenantTheme.logo != null
	_logo_fallback.visible = TenantTheme.logo == null
	_logo_fallback.color = TenantTheme.primary
	_notice.add_theme_color_override("font_color", TenantTheme.WARNING)
	for card in _cards:
		card.refresh()


func _first_playable() -> int:
	for i in _cards.size():
		if _cards[i].info.playable:
			return i
	return 0


func _select(index: int) -> void:
	if _cards.is_empty():
		return
	_index = clampi(index, 0, _cards.size() - 1)
	for i in _cards.size():
		_cards[i].set_selected(i == _index)
	_notice.text = ""


func _confirm() -> void:
	if _cards.is_empty():
		return
	var card := _cards[_index]
	if not card.info.playable:
		card.shake()
		_notice.text = Strings.NOT_AVAILABLE
		return
	if not Router.start_game(card.info):
		_notice.text = Strings.GAME_COMING % card.info.title
