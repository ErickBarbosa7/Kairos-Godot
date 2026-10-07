extends Node
## Modo kiosco: pantalla completa, ventana que no se puede cerrar y cursor oculto.
## Solo se bloquea cuando la máquina ya está vinculada: durante la instalación el técnico
## puede cerrar la ventana. La salida del público está cerrada; el administrador sale desde
## sus opciones (que piden el inicio de sesión del negocio).
##
## Esto no sustituye el bloqueo del sistema operativo (Alt+Tab, tecla Windows, Ctrl+Alt+Supr):
## ver installer/README.md.

const CURSOR_CHECK_SECONDS := 0.5
## Pantallas que sí necesitan ratón y cursor visible.
const MOUSE_SCENES := ["Link"]

var enabled := false
var _cursor_timer := 0.0


## Decisión pura para poder probarla: los argumentos mandan sobre la configuración.
static func decide(config_value: bool, args: PackedStringArray) -> bool:
	if args.has("--windowed"):
		return false
	if args.has("--kiosk"):
		return true
	return config_value


func _ready() -> void:
	# La ventana no se cierra sola: decidimos en _notification según el modo.
	get_tree().auto_accept_quit = false
	enabled = decide(AppConfig.kiosk, OS.get_cmdline_user_args())
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	set_process(enabled)


## Verdadero si no se debe poder cerrar la app: kiosco activo y máquina ya vinculada.
func is_locked() -> bool:
	return enabled and not AppConfig.loaded_from.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not is_locked():
		get_tree().quit()


## Salida intencional (opciones de administrador). Código 0: el reinicio automático no la repite.
func quit_app() -> void:
	get_tree().quit(0)


func _process(delta: float) -> void:
	_cursor_timer += delta
	if _cursor_timer < CURSOR_CHECK_SECONDS:
		return
	_cursor_timer = 0.0
	var scene := get_tree().current_scene
	var needs_mouse := scene != null and MOUSE_SCENES.has(String(scene.name))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if needs_mouse else Input.MOUSE_MODE_HIDDEN
