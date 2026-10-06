class_name BrandCache
extends RefCounted
## Guarda la última marca válida por sucursal para que la terminal funcione sin red.

const PATH := "user://brand_cache.json"


static func save(store_id: String, brand: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BrandCache: no se pudo escribir %s" % PATH)
		return
	file.store_string(JSON.stringify({"store_id": store_id, "brand": brand}))


## Devuelve la marca guardada de esa sucursal o {} si no hay.
static func load_for(store_id: String) -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or data.get("store_id") != store_id:
		return {}
	var brand: Variant = data.get("brand")
	return brand if typeof(brand) == TYPE_DICTIONARY else {}


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
