extends CanvasLayer
## Traduce toques a las acciones existentes y muestra controles grandes sobre los juegos.
## Así los juegos conservan el mismo InputMap en escritorio, Web, Android e iPad.

var _overlay: TouchOverlay
var _touches: Dictionary = {}
var _held_action := ""

func _ready() -> void:
	layer = 40
	_overlay = TouchOverlay.new()
	add_child(_overlay)

func _process(_delta: float) -> void:
	_overlay.visible = _is_gameplay()
	# Si la partida terminó con el dedo apoyado, no dejar la acción "pegada" en otra pantalla.
	if not _held_action.is_empty() and not _is_gameplay():
		Input.action_release(_held_action)
		_held_action = ""
		_touches.clear()
	_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# El ratón facilita probar los controles táctiles desde el editor.
		_handle_touch(-1, event.position, event.pressed)

func _handle_touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		_touches[index] = {"start": position, "last": position}
		if _is_gameplay():
			_hold_for(position)
		elif _is_menu():
			_menu_tap(position)
		# En las demás pantallas (resultado, ruleta, iniciales...) los botones reciben el
		# toque por sí solos: emitir acciones aquí activaba el botón enfocado en vez del tocado.
		return
	var start: Vector2 = _touches.get(index, {}).get("start", position)
	_touches.erase(index)
	if _is_gameplay() and _game_id() == "serpiente_golosa":
		_swipe(start, position)
	if _touches.is_empty() and not _held_action.is_empty():
		Input.action_release(_held_action)
		_held_action = ""

func _is_menu() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == Router.MENU

func _is_gameplay() -> bool:
	return Router.current_game != null and get_tree().current_scene is ArcadeGame

func _game_id() -> String:
	return Router.current_game.id if Router.current_game else ""

func _logical_position(position: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return position
	return Vector2(position.x / size.x, position.y / size.y)

func _menu_tap(position: Vector2) -> void:
	var p := _logical_position(position)
	if p.x < 0.30:
		_emit("move_left")
	elif p.x > 0.70:
		_emit("move_right")
	else:
		_emit("confirm")

func _hold_for(position: Vector2) -> void:
	var id := _game_id()
	var p := _logical_position(position)
	if p.x > 0.80 and p.y > 0.86:
		return  # botón "Salir": que el toque no mueva al jugador
	if id == "stack_tower":
		_emit("confirm")
		return
	if id == "memory_rush":
		if p.y < 0.5:
			_emit("move_left" if p.x < 0.5 else "move_up")
		else:
			_emit("move_down" if p.x < 0.5 else "move_right")
		return
	if id == "serpiente_golosa":
		return
	var action := "move_left" if p.x < 0.5 else "move_right"
	if id == "defensa_estelar" and p.y < 0.42:
		_emit("fire")
		return
	if _held_action != action:
		if not _held_action.is_empty(): Input.action_release(_held_action)
		_held_action = action
		Input.action_press(action)

func _swipe(start: Vector2, ending: Vector2) -> void:
	var delta := ending - start
	if delta.length() < 35.0:
		return
	if absf(delta.x) > absf(delta.y):
		_emit("move_right" if delta.x > 0.0 else "move_left")
	else:
		_emit("move_down" if delta.y > 0.0 else "move_up")

## Pulsa y suelta la acción. Sin soltarla, Godot la deja "presionada" para siempre y los
## juegos siguientes ven una tecla pegada.
func _emit(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.parse_input_event(release))

class TouchOverlay:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if Router.current_game == null or not get_tree().current_scene is ArcadeGame:
			return
		var id := Router.current_game.id
		var rect := get_rect()
		var color := Color(TenantTheme.primary, 0.20)
		var line := Color(TenantTheme.TEXT, 0.48)
		if id == "memory_rush":
			for x in [0.25, 0.75]:
				for y in [0.72, 0.90]:
					draw_circle(Vector2(rect.size.x * x, rect.size.y * y), 48.0, color)
					draw_circle(Vector2(rect.size.x * x, rect.size.y * y), 48.0, line, false, 3.0)
		elif id == "stack_tower":
			draw_circle(Vector2(rect.size.x * 0.5, rect.size.y * 0.87), 64.0, color)
			draw_circle(Vector2(rect.size.x * 0.5, rect.size.y * 0.87), 64.0, line, false, 3.0)
		elif id != "serpiente_golosa":
			var left := Rect2(28, rect.size.y - 148, 160, 110)
			var right := Rect2(rect.size.x - 188, rect.size.y - 148, 160, 110)
			draw_rect(left, color, true)
			draw_rect(right, color, true)
			draw_rect(left, line, false, 3.0)
			draw_rect(right, line, false, 3.0)
