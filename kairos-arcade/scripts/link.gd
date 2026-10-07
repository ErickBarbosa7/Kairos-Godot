extends Control
## Vinculación de la máquina con el negocio, en tres pasos:
## 1) inicio de sesión del administrador, 2) sucursal y nombre, 3) listo.
## Se muestra sola la primera vez en una app instalada. El token vive solo en esta pantalla.

enum Step { LOGIN, ADMIN, STORE, DONE }

var _step := Step.LOGIN
var _api_url := ""
var _token := ""
var _business := ""
var _stores: Array = []
var _selected_store := -1
var _busy := false

var _content: VBoxContainer
var _error: Label
var _slug: LineEdit
var _email: LineEdit
var _password: LineEdit
var _label_edit: LineEdit
var _primary: Button
var _store_buttons: Array[Button] = []
var _help: HelpOverlay


func _ready() -> void:
	_api_url = AppConfig.api_url
	var bg := ColorRect.new()
	bg.color = TenantTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(960, 0)
	_content.add_theme_constant_override("separation", 20)
	center.add_child(_content)
	_help = HelpOverlay.attach(self, "link")
	_show_login()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not AppConfig.loaded_from.is_empty() and _step != Step.DONE:
		Router.to_menu()
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for child in _content.get_children():
		child.queue_free()
	_store_buttons.clear()


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _error_label() -> Label:
	_error = _label("", UiKit.text(700), 30, TenantTheme.DANGER)
	_error.visible = false
	return _error


func _fail(message: String) -> void:
	_error.text = message
	_error.visible = true


# --- Paso 1: inicio de sesión -----------------------------------------------

func _show_login() -> void:
	_step = Step.LOGIN
	_help.set_topic("link")
	_token = ""
	_clear()
	_content.add_child(_label(Strings.LINK_TITLE, UiKit.display(900), 80, TenantTheme.TEXT))
	_content.add_child(_label(Strings.LINK_SUBTITLE, UiKit.text(500), 30, TenantTheme.TEXT_SECONDARY))
	if not AppConfig.loaded_from.is_empty():
		_content.add_child(_label(Strings.LINK_ALREADY % (AppConfig.business_name if not AppConfig.business_name.is_empty() else AppConfig.store_id), UiKit.text(600), 28, TenantTheme.WARNING))

	_slug = UiKit.line_edit(Strings.LINK_SLUG + " · " + Strings.LINK_SLUG_HINT)
	_email = UiKit.line_edit(Strings.LINK_EMAIL)
	_password = UiKit.line_edit(Strings.LINK_PASSWORD, true)
	for field in [_slug, _email, _password]:
		_content.add_child(field)
	_slug.text_submitted.connect(func(_t: String) -> void: _email.grab_focus())
	_email.text_submitted.connect(func(_t: String) -> void: _password.grab_focus())
	_password.text_submitted.connect(func(_t: String) -> void: _do_login())

	_content.add_child(_error_label())
	_primary = UiKit.button(Strings.LINK_CONTINUE, true)
	_primary.pressed.connect(_do_login)
	_content.add_child(_primary)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if not AppConfig.loaded_from.is_empty():
		var cancel := UiKit.button(Strings.LINK_CANCEL, false)
		cancel.pressed.connect(Router.to_menu)
		row.add_child(cancel)
	if AppConfig.can_skip_link() and AppConfig.loaded_from.is_empty():
		var skip := UiKit.button(Strings.LINK_SKIP, false)
		skip.pressed.connect(Router.to_menu)
		row.add_child(skip)
	if row.get_child_count() > 0:
		_content.add_child(row)
	_content.add_child(_label(Strings.LINK_SERVER % _api_url, UiKit.text(500), 24, TenantTheme.TEXT_SECONDARY))
	_slug.grab_focus.call_deferred()


func _do_login() -> void:
	if _busy:
		return
	if _slug.text.strip_edges().is_empty() or _email.text.strip_edges().is_empty() or _password.text.is_empty():
		_fail(Strings.LINK_REQUIRED)
		return
	_set_busy(true, Strings.LINK_CONNECTING)
	var login: Dictionary = await LinkService.login(_api_url, _slug.text, _email.text, _password.text)
	if not login.ok:
		_set_busy(false, Strings.LINK_CONTINUE)
		_fail(login.message)
		return
	_token = login.token
	_business = login.business_name
	_password.text = ""
	var stores: Dictionary = await LinkService.list_stores(_api_url, _token)
	_set_busy(false, Strings.LINK_CONTINUE)
	if not stores.ok:
		_fail(stores.message)
		return
	_stores = stores.stores
	# Una máquina ya vinculada ofrece opciones de administrador; una nueva sigue a la sucursal.
	if AppConfig.loaded_from.is_empty():
		_show_store()
	else:
		_show_admin()


func _set_busy(busy: bool, text: String) -> void:
	_busy = busy
	if _error != null and busy:
		_error.visible = false
	if _primary != null:
		_primary.disabled = busy
		_primary.text = text


# --- Opciones de administrador (máquina ya vinculada) -------------------------

func _show_admin() -> void:
	_step = Step.ADMIN
	_help.set_topic("admin")
	_clear()
	_content.add_child(_label(Strings.ADMIN_TITLE, UiKit.display(900), 72, TenantTheme.TEXT))
	_content.add_child(_label(Strings.ADMIN_SESSION % _business, UiKit.text(500), 30, TenantTheme.TEXT_SECONDARY))
	var relink := UiKit.button(Strings.ADMIN_RELINK, false)
	relink.pressed.connect(_show_store)
	var quit := UiKit.button(Strings.ADMIN_QUIT, false, true)
	quit.pressed.connect(func() -> void:
		_token = ""
		Kiosk.quit_app())
	var back := UiKit.button(Strings.ADMIN_BACK, true)
	back.pressed.connect(func() -> void:
		_token = ""
		Router.to_menu())
	for b in [relink, quit, back]:
		_content.add_child(b)
	back.grab_focus.call_deferred()


# --- Paso 2: sucursal y nombre ----------------------------------------------

func _show_store() -> void:
	_step = Step.STORE
	_help.set_topic("link")
	_clear()
	_selected_store = 0 if _stores.size() == 1 else -1
	_content.add_child(_label(Strings.LINK_STORE_TITLE, UiKit.display(900), 80, TenantTheme.TEXT))
	_content.add_child(_label("%s · %s" % [_business, Strings.LINK_STORE_HINT], UiKit.text(500), 30, TenantTheme.TEXT_SECONDARY))

	if _stores.is_empty():
		_content.add_child(_label(Strings.LINK_NO_STORES, UiKit.text(700), 32, TenantTheme.WARNING))
		var back := UiKit.button(Strings.LINK_BACK, false)
		back.pressed.connect(_show_login)
		_content.add_child(back)
		back.grab_focus.call_deferred()
		return

	for i in _stores.size():
		var b := UiKit.button(str(_stores[i].name), false)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select_store.bind(i))
		_store_buttons.append(b)
		_content.add_child(b)
	_content.add_child(_label(Strings.LINK_MACHINE_NAME, UiKit.text(700), 26, TenantTheme.TEXT_SECONDARY))
	_label_edit = UiKit.line_edit(Strings.LINK_MACHINE_NAME)
	_label_edit.text = Strings.LINK_MACHINE_DEFAULT
	_content.add_child(_label_edit)
	_content.add_child(_error_label())
	_primary = UiKit.button(Strings.LINK_DO, true)
	_primary.pressed.connect(_do_link)
	_content.add_child(_primary)
	var back_row := UiKit.button(Strings.LINK_BACK, false)
	back_row.pressed.connect(_show_login)
	_content.add_child(back_row)
	_select_store(_selected_store)
	(_store_buttons[0] if _selected_store < 0 else _primary).grab_focus.call_deferred()


func _select_store(index: int) -> void:
	_selected_store = index
	for i in _store_buttons.size():
		_store_buttons[i].set_pressed_no_signal(i == index)
		# El seleccionado lleva borde grueso del color del tenant y una marca, no solo color.
		_store_buttons[i].add_theme_stylebox_override("normal", _store_style(i == index))
		_store_buttons[i].text = ("●  " if i == index else "○  ") + str(_stores[i].name)


func _store_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TenantTheme.NIGHT_RAISED
	s.set_border_width_all(8 if selected else 4)
	s.border_color = TenantTheme.primary if selected else TenantTheme.NIGHT_LINE
	s.set_corner_radius_all(2)
	s.content_margin_left = 24
	return s


func _do_link() -> void:
	if _busy:
		return
	if _selected_store < 0 or _label_edit.text.strip_edges().length() < 2:
		_fail(Strings.LINK_REQUIRED)
		return
	_set_busy(true, Strings.LINK_LINKING)
	var store: Dictionary = _stores[_selected_store]
	var result: Dictionary = await LinkService.link_machine(_api_url, _token, store, _label_edit.text, _business)
	_set_busy(false, Strings.LINK_DO)
	if not result.ok:
		_fail(result.message)
		return
	_token = ""
	_show_done(str(store.name))


# --- Paso 3: listo ----------------------------------------------------------

func _show_done(store_name: String) -> void:
	_step = Step.DONE
	_clear()
	_content.add_child(_label(Strings.LINK_DONE_TITLE, UiKit.display(900), 88, TenantTheme.SUCCESS))
	_content.add_child(_label(Strings.LINK_DONE_BODY % [_business, store_name], UiKit.text(600), 36, TenantTheme.TEXT))
	var start := UiKit.button(Strings.LINK_DONE_START, true)
	start.pressed.connect(func() -> void:
		AppConfig.reload()
		Router.to_boot())
	_content.add_child(start)
	start.grab_focus.call_deferred()
