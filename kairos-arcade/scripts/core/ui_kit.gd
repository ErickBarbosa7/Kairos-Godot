class_name UiKit
extends RefCounted
## Fuentes y estilos compartidos. Los colores salen de TenantTheme, nunca de aquí.

const FONT_DISPLAY := "res://assets/fonts/big-shoulders-display.woff2"
const FONT_TEXT := "res://assets/fonts/figtree.woff2"
const FONT_ACCENT := "res://assets/fonts/instrument-serif-italic.woff2"

static var _cache: Dictionary = {}


static func display(weight: int = 800) -> Font:
	return _variable(FONT_DISPLAY, weight)


static func text(weight: int = 500) -> Font:
	return _variable(FONT_TEXT, weight)


static func accent() -> Font:
	return load(FONT_ACCENT)


static func _variable(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if not _cache.has(key):
		var font := FontVariation.new()
		font.base_font = load(path)
		var tag := TextServerManager.get_primary_interface().name_to_tag("weight")
		font.variation_opentype = {tag: weight}
		_cache[key] = font
	return _cache[key]


## Tarjeta de juego. Seleccionada: borde y sombra del tenant. Bloqueada: apagada.
static func card_style(selected: bool, locked: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TenantTheme.NIGHT_RAISED
	s.set_border_width_all(6 if selected else 4)
	s.border_color = TenantTheme.primary if selected else TenantTheme.NIGHT_LINE
	s.set_corner_radius_all(4)
	s.shadow_color = TenantTheme.primary if selected else Color(0, 0, 0, 0.6)
	s.shadow_size = 1
	s.shadow_offset = Vector2(12, 12) if selected else Vector2(8, 8)
	s.set_content_margin_all(32)
	if locked:
		s.bg_color = TenantTheme.NIGHT_RAISED.darkened(0.2)
	return s


static func chip_style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(3)
	s.border_color = border
	s.set_corner_radius_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Botón grande con estados de foco visibles. primary: relleno del tenant. danger: advertencia.
static func button(label: String, primary: bool, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(380, 96)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", display(800))
	b.add_theme_font_size_override("font_size", 40)
	var fill := TenantTheme.primary if primary else TenantTheme.NIGHT_RAISED
	var text_color := TenantTheme.on_primary if primary else TenantTheme.TEXT
	var edge := TenantTheme.NIGHT_LINE
	if danger:
		edge = TenantTheme.DANGER
		text_color = TenantTheme.DANGER
	b.add_theme_stylebox_override("normal", _button_box(fill, edge, 4))
	b.add_theme_stylebox_override("hover", _button_box(fill.lightened(0.08), TenantTheme.TEXT, 4))
	b.add_theme_stylebox_override("pressed", _button_box(fill.darkened(0.1), TenantTheme.TEXT, 4))
	# Foco: borde grueso blanco, no solo color.
	b.add_theme_stylebox_override("focus", _focus_box(Color.WHITE, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	return b


static func _button_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(2)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 1
	s.shadow_offset = Vector2(6, 6)
	return s


static func _focus_box(border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(2)
	return s
