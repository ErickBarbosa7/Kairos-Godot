class_name RewardCatalog
extends RefCounted
## Recompensas del negocio que puede ganar la ruleta. Se piden a la API (`/public/stores/:id/rewards`)
## y se guardan en disco para que la terminal siga funcionando sin red.

const CACHE_PATH := "user://rewards_cache.json"
## Más de 8 casillas se vuelven ilegibles; si el negocio tiene más recompensas, se sortean 8.
const MAX_SEGMENTS := 8
const MAX_REWARDS := 50
## Recompensas de muestra para probar la ruleta cuando la máquina aún no está vinculada.
const DEMO := [
	{"id": "demo-1", "title": "Café gratis", "description": "", "imageUrl": null, "pointsCost": 100},
	{"id": "demo-2", "title": "Postre de la casa", "description": "", "imageUrl": null, "pointsCost": 200},
	{"id": "demo-3", "title": "10 % de descuento", "description": "", "imageUrl": null, "pointsCost": 150},
	{"id": "demo-4", "title": "Galleta", "description": "", "imageUrl": null, "pointsCost": 80},
]

## Imágenes que subió el administrador, por id de recompensa. Se guardan también en disco
## (IMAGE_DIR) para que sobrevivan a un reinicio sin red.
static var images: Dictionary = {}
const IMAGE_DIR := "user://reward_images"
static var image_dir := IMAGE_DIR
static var rewards: Array = []
static var cache_path := CACHE_PATH
## Tiempo máximo que se espera por imágenes antes de mostrar la ruleta sin ellas.
const IMAGE_DEADLINE_MS := 2500
const PRELOAD_IMAGES := 12


## Deja solo lo usable de la respuesta de la API: id y título no vacíos. Máximo MAX_REWARDS.
static func sanitize(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "")).strip_edges()
		var title := str(item.get("title", "")).strip_edges()
		if id.is_empty() or title.is_empty():
			continue
		out.append({
			"id": id,
			"title": title,
			"description": str(item.get("description", "") if item.get("description") != null else ""),
			"imageUrl": item.get("imageUrl"),
			"pointsCost": int(item.get("pointsCost", 0)),
		})
		if out.size() >= MAX_REWARDS:
			break
	return out


## Casillas de la ruleta: todas si caben; si no, MAX_SEGMENTS al azar sin cambiar el orden.
static func pick_segments(list: Array, rng: RandomNumberGenerator, max_segments: int = MAX_SEGMENTS) -> Array:
	if list.size() <= max_segments:
		return list.duplicate()
	var indexes: Array = range(list.size())
	for i in range(indexes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indexes[i]
		indexes[i] = indexes[j]
		indexes[j] = tmp
	var chosen: Array = indexes.slice(0, max_segments)
	chosen.sort()
	return chosen.map(func(i: int) -> Dictionary: return list[i])


static func save_cache(store_id: String, list: Array) -> void:
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		push_warning("RewardCatalog: no se pudo escribir %s" % cache_path)
		return
	file.store_string(JSON.stringify({"store_id": store_id, "rewards": list}))


## Lista guardada de esa sucursal, o [] si no hay.
static func load_cache(store_id: String) -> Array:
	if not FileAccess.file_exists(cache_path):
		return []
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or data.get("store_id") != store_id:
		return []
	return sanitize(data.get("rewards"))


static func clear_cache() -> void:
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))


## Actualiza `rewards`: caché primero (sin esperar), red después. Sin red conserva lo último conocido.
static func refresh() -> void:
	if AppConfig.simulated:
		rewards = DEMO.duplicate(true)
		return
	if rewards.is_empty():
		rewards = load_cache(AppConfig.store_id)
	var response: Dictionary = await ApiClient.get_json("/public/stores/%s/rewards" % AppConfig.store_id)
	if response.ok and typeof(response.data) == TYPE_DICTIONARY:
		rewards = sanitize(response.data.get("data"))
		save_cache(AppConfig.store_id, rewards)
		prune_image_cache(rewards)
	elif response.status == 404:
		# Sucursal inexistente o inactiva: lo guardado ya no vale.
		rewards = []
		clear_cache()
		prune_image_cache([])
	# Se bajan en segundo plano (sin await): no deben retrasar el arranque.
	ensure_images(rewards.slice(0, PRELOAD_IMAGES))


## Descarga las imágenes que falten de esas recompensas. Se detiene al pasar IMAGE_DEADLINE_MS.
static func ensure_images(list: Array) -> void:
	var deadline := Time.get_ticks_msec() + IMAGE_DEADLINE_MS
	for reward in list:
		if Time.get_ticks_msec() > deadline:
			return
		var id := str(reward.get("id", ""))
		var url_value: Variant = reward.get("imageUrl")
		var url := str(url_value) if url_value != null else ""
		if id.is_empty() or url.is_empty() or images.has(id):
			continue
		var from_disk := load_image_cache(id, url)
		if from_disk != null:
			images[id] = from_disk
			continue
		var texture: ImageTexture = await ApiClient.load_image(url)
		if texture != null:
			images[id] = texture
			save_image_cache(id, url, texture)


## Ruta del archivo de esa imagen. Lleva una huella de la URL: si el administrador cambia la imagen,
## la URL cambia y se descarga la nueva. "" si el id no es seguro para usarlo como nombre de archivo.
static func image_path(id: String, url: String) -> String:
	var safe := RegEx.new()
	safe.compile("^[A-Za-z0-9-]{1,64}$")
	if safe.search(id) == null or url.is_empty():
		return ""
	return image_dir.path_join("%s_%s.png" % [id, url.sha256_text().left(12)])


static func load_image_cache(id: String, url: String) -> ImageTexture:
	var path := image_path(id, url)
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


static func save_image_cache(id: String, url: String, texture: Texture2D) -> void:
	var path := image_path(id, url)
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(image_dir))
	var err := texture.get_image().save_png(path)
	if err != OK:
		push_warning("RewardCatalog: no se pudo guardar %s" % path)


## Borra del disco las imágenes de recompensas que ya no existen o cuya imagen cambió.
static func prune_image_cache(list: Array) -> void:
	var keep: Dictionary = {}
	for reward in list:
		var url_value: Variant = reward.get("imageUrl")
		var path := image_path(str(reward.get("id", "")), str(url_value) if url_value != null else "")
		if not path.is_empty():
			keep[path.get_file()] = true
	var dir := DirAccess.open(image_dir)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".png") and not keep.has(file):
			dir.remove(file)
