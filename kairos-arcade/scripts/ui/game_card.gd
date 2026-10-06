class_name GameCard
extends PanelContainer
## Tarjeta del menú. Muestra un juego; el menú decide cuál está seleccionada.

var info: GameInfo
var selected := false

var _art: ColorRect
var _game_art: GameArt
var _title: Label
var _tagline: Label
var _chip: PanelContainer
var _chip_label: Label
var _lock: LockIcon
var _tween: Tween


func setup(game: GameInfo) -> void:
	info = game
	custom_minimum_size = Vector2(540, 620)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	resized.connect(func(): pivot_offset = size / 2)
	refresh()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	add_child(box)

	_art = ColorRect.new()
	_art.custom_minimum_size = Vector2(0, 280)
	box.add_child(_art)

	_game_art = GameArt.new()
	_game_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.add_child(_game_art)

	_lock = LockIcon.new()
	_lock.set_anchors_preset(Control.PRESET_CENTER)
	_lock.custom_minimum_size = Vector2(72, 86)
	_lock.position = Vector2(-36, -43)
	_art.add_child(_lock)

	_title = Label.new()
	_title.add_theme_font_override("font", UiKit.display(900))
	_title.add_theme_font_size_override("font_size", 64)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.text = info.title
	box.add_child(_title)

	_tagline = Label.new()
	_tagline.add_theme_font_override("font", UiKit.text(500))
	_tagline.add_theme_font_size_override("font_size", 28)
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tagline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tagline.text = info.tagline
	box.add_child(_tagline)

	_chip = PanelContainer.new()
	_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chip_label = Label.new()
	_chip_label.add_theme_font_override("font", UiKit.display(800))
	_chip_label.add_theme_font_size_override("font_size", 28)
	_chip.add_child(_chip_label)
	box.add_child(_chip)


## Reaplica colores y estado. Se llama al cambiar la marca o la selección.
func refresh() -> void:
	var locked := not info.playable
	add_theme_stylebox_override("panel", UiKit.card_style(selected, locked))

	_art.color = TenantTheme.NIGHT.lerp(TenantTheme.primary, 0.28) if not locked else TenantTheme.NIGHT_LINE.darkened(0.3)
	_game_art.visible = not locked
	_game_art.ship_color = TenantTheme.primary
	_game_art.star_color = TenantTheme.TEXT
	_game_art.queue_redraw()
	_lock.visible = locked
	_lock.color = TenantTheme.TEXT_SECONDARY
	_lock.queue_redraw()
	_title.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY if locked else TenantTheme.TEXT)
	_tagline.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)

	if locked:
		_chip.visible = true
		_chip.add_theme_stylebox_override("panel", UiKit.chip_style(Color.TRANSPARENT, TenantTheme.NIGHT_LINE))
		_chip_label.text = Strings.IN_PROGRESS
		_chip_label.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	elif selected:
		_chip.visible = true
		_chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
		_chip_label.text = Strings.PRESS_TO_PLAY
		_chip_label.add_theme_color_override("font_color", TenantTheme.on_primary)
	else:
		_chip.visible = true
		_chip.add_theme_stylebox_override("panel", UiKit.chip_style(Color.TRANSPARENT, TenantTheme.NIGHT_LINE))
		_chip_label.text = Strings.DURATION % info.duration_seconds
		_chip_label.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)


func set_selected(value: bool) -> void:
	selected = value
	refresh()
	_animate_scale(1.04 if value else 1.0)


## Sacudida corta para "no disponible". Con movimiento reducido solo hay cambio de borde.
func shake() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation", 0.012, 0.05)
	_tween.tween_property(self, "rotation", -0.012, 0.08)
	_tween.tween_property(self, "rotation", 0.0, 0.05)


func _animate_scale(target: float) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "scale", Vector2(target, target), 0.12)
