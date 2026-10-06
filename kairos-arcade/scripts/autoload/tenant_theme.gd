extends Node
## Colores de la terminal: base Kairos fija y colores derivados de la marca del tenant.
## La fórmula de contraste es la misma de packages/design/src/theme-tenant.ts.

signal theme_changed

# Tokens base de Kairos (packages/design/tokens.json). No cambian por tenant.
const NIGHT := Color("#0A0708")
const NIGHT_RAISED := Color("#161012")
const NIGHT_LINE := Color("#3A2A2C")
const REWARD := Color("#FBBF24")
const TEXT := Color("#F2EBE4")
const TEXT_SECONDARY := Color("#C2B5AE")
const WARNING := Color("#FBBF24")
const DANGER := Color("#F87171")
const SUCCESS := Color("#4ADE80")

const FALLBACK_PRIMARY := Color("#B91C1C")
const DARK_TEXT := Color("#140D0E")

const MIN_TEXT_CONTRAST := 4.5
const MIN_UI_CONTRAST := 3.0

var tenant_name: String = "Kairos"
var logo: Texture2D = null
var primary: Color = FALLBACK_PRIMARY
var on_primary: Color = Color.WHITE
var primary_hover: Color = FALLBACK_PRIMARY
var primary_subtle: Color = Color(FALLBACK_PRIMARY, 0.12)
var focus: Color = REWARD
## Verdadero si se usa el tema Kairos porque no hay marca del tenant.
var is_fallback: bool = true


func _ready() -> void:
	_derive(FALLBACK_PRIMARY)


## Aplica la respuesta de GET /public/stores/:id/brand. Devuelve false si es inválida.
func apply_brand(brand: Dictionary) -> bool:
	var hex := str(brand.get("primaryColor", ""))
	if not is_valid_hex(hex):
		return false
	tenant_name = str(brand.get("name", tenant_name))
	_derive(Color(hex))
	is_fallback = false
	theme_changed.emit()
	return true


func set_logo(texture: Texture2D) -> void:
	logo = texture
	theme_changed.emit()


func reset_to_fallback() -> void:
	tenant_name = "Kairos"
	logo = null
	_derive(FALLBACK_PRIMARY)
	is_fallback = true
	theme_changed.emit()


static func is_valid_hex(hex: String) -> bool:
	var re := RegEx.new()
	re.compile("^#[0-9a-fA-F]{6}$")
	return re.search(hex) != null


## Luminancia relativa WCAG 2.x.
static func relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := relative_luminance(a)
	var lb := relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Blanco o casi negro, el que dé mayor contraste sobre el color.
static func pick_on_color(background: Color) -> Color:
	return Color.WHITE if contrast(Color.WHITE, background) >= contrast(DARK_TEXT, background) else DARK_TEXT


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func _derive(base: Color) -> void:
	var adjusted := base
	# Sobre el fondo oscuro el primario debe contrastar al menos 3:1; si no, se aclara.
	var guard := 0
	while contrast(adjusted, NIGHT) < MIN_UI_CONTRAST and guard < 40:
		adjusted = adjusted.lightened(0.05)
		guard += 1
	primary = adjusted
	on_primary = pick_on_color(adjusted)
	primary_hover = adjusted.lightened(0.08)
	primary_subtle = Color(adjusted, 0.12)
	focus = adjusted if contrast(adjusted, NIGHT) >= MIN_UI_CONTRAST else REWARD
