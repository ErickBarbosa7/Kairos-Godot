extends Node
## Configuración de la máquina. Lee un archivo externo; nunca guarda secretos.

const CONFIG_FILE := "machine.config.json"
const SIMULATED_STORE_ID := "00000000-0000-0000-0000-000000000000"

var api_url: String = _default_api_url()
var store_id: String = SIMULATED_STORE_ID
var machine_id: String = ""
## Ruta de la llave privada ES256 (PEM). Vive fuera del repositorio.
var private_key_path: String = ""
## Metas de QR por juego, para sobrescribir las del recurso: {"id_del_juego": puntos}.
var qr_goals: Dictionary = {}
var dev_mode: bool = false
## Sin sacudida, partículas ni fondo animado.
var reduce_motion: bool = false
## Modo kiosco: pantalla completa y sin poder cerrar la ventana. Activo por defecto en la app
## exportada; al desarrollar desde el editor está apagado.
var kiosk: bool = not OS.has_feature("editor")
## Verdadero si no hubo archivo de configuración: no se hacen peticiones de red.
var simulated: bool = true
var loaded_from: String = ""
## Nombre del negocio y de la máquina que dejó la vinculación (solo informativo).
var business_name: String = ""
var machine_label: String = ""


func _ready() -> void:
	reload()


## URL de la API que viene incluida en la app (ajuste kairos/api_url) o la de KAIROS_API_URL.
static func _default_api_url() -> String:
	var env := OS.get_environment("KAIROS_API_URL")
	if not env.is_empty():
		return env.rstrip("/")
	return str(ProjectSettings.get_setting("kairos/api_url", "http://localhost:3000")).rstrip("/")


## Vuelve a leer la configuración. Se llama al terminar de vincular la máquina.
func reload() -> void:
	var path := _find_config_path()
	if path.is_empty():
		push_warning("AppConfig: sin %s, se usa configuración simulada" % CONFIG_FILE)
		return
	if not apply_file(path):
		push_warning("AppConfig: no se pudo leer %s, se usa configuración simulada" % path)


## Devuelve la ruta del archivo de configuración o "" si no existe.
func _find_config_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="):
			var given := arg.trim_prefix("--config=")
			return given if FileAccess.file_exists(given) else ""
	var env := OS.get_environment("KAIROS_CONFIG")
	if not env.is_empty():
		return env if FileAccess.file_exists(env) else ""
	var beside := OS.get_executable_path().get_base_dir().path_join(CONFIG_FILE)
	if not OS.has_feature("editor") and FileAccess.file_exists(beside):
		return beside
	var user_path := "user://" + CONFIG_FILE
	if FileAccess.file_exists(user_path):
		return user_path
	return ""


func apply_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	apply(data)
	loaded_from = path
	return true


func apply(data: Dictionary) -> void:
	api_url = str(data.get("api_url", api_url)).rstrip("/")
	store_id = str(data.get("store_id", store_id))
	machine_id = str(data.get("machine_id", machine_id))
	business_name = str(data.get("business_name", business_name))
	machine_label = str(data.get("machine_label", machine_label))
	private_key_path = str(data.get("private_key_path", private_key_path))
	var goals: Variant = data.get("qr_goals", qr_goals)
	qr_goals = goals if typeof(goals) == TYPE_DICTIONARY else {}
	dev_mode = bool(data.get("dev_mode", dev_mode)) or OS.has_feature("editor")
	reduce_motion = bool(data.get("reduce_motion", reduce_motion))
	kiosk = bool(data.get("kiosk", kiosk))
	simulated = store_id.is_empty() or store_id == SIMULATED_STORE_ID


## Verdadero si esta ejecución debe pedir la vinculación: no hay configuración y es una app
## exportada (o se pidió con `-- --link`). Al desarrollar desde el editor se salta.
func needs_link() -> bool:
	if not loaded_from.is_empty():
		return false
	return not OS.has_feature("editor") or OS.get_cmdline_user_args().has("--link")


## Solo se permite omitir la vinculación al desarrollar.
func can_skip_link() -> bool:
	return OS.has_feature("editor") or dev_mode
