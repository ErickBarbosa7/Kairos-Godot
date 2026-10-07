extends Control
## Arranque: pide la marca (con la caché ya aplicada) y pasa al menú.
## Nunca espera más de MAX_WAIT; si la marca llega tarde, el menú se actualiza solo.

const MENU_SCENE := "res://scenes/menu/menu.tscn"
const MIN_WAIT := 0.6
const MAX_WAIT := 3.0

var _done := false


func _ready() -> void:
	if AppConfig.needs_link():
		Router.to_link.call_deferred()
		return
	_build()
	_load_brand()
	var elapsed := 0.0
	while elapsed < MAX_WAIT and (not _done or elapsed < MIN_WAIT):
		elapsed += get_process_delta_time() if elapsed > 0.0 else 0.016
		await get_tree().process_frame
	ArcadeState.go_to(ArcadeState.Screen.MENU)
	get_tree().change_scene_to_file(MENU_SCENE)


func _load_brand() -> void:
	var source := await BrandService.load_brand()
	if source == BrandService.Source.FALLBACK and not AppConfig.simulated:
		push_warning("Main: sin marca de red ni caché, se usa el tema Kairos")
	await RewardCatalog.refresh()
	_done = true


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = TenantTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var word := Label.new()
	word.text = "kairos"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_override("font", UiKit.accent())
	word.add_theme_font_size_override("font_size", 144)
	word.add_theme_color_override("font_color", TenantTheme.primary)
	box.add_child(word)

	var loading := Label.new()
	loading.text = Strings.BOOT_LOADING
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_override("font", UiKit.text(600))
	loading.add_theme_font_size_override("font_size", 32)
	loading.add_theme_color_override("font_color", TenantTheme.TEXT_SECONDARY)
	box.add_child(loading)
