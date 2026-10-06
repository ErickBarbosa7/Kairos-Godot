class_name BrandService
extends RefCounted
## Carga la marca del tenant: caché primero (sin parpadeo), red después.

enum Source { FALLBACK, CACHE, NETWORK }


## Devuelve de dónde salió la marca que quedó aplicada.
static func load_brand() -> Source:
	var source := Source.FALLBACK
	var cached := BrandCache.load_for(AppConfig.store_id)
	if not cached.is_empty() and TenantTheme.apply_brand(cached):
		source = Source.CACHE
		await _load_logo(cached)

	var response: Dictionary = await ApiClient.get_json("/public/stores/%s/brand" % AppConfig.store_id)
	if response.ok and typeof(response.data) == TYPE_DICTIONARY and TenantTheme.apply_brand(response.data):
		BrandCache.save(AppConfig.store_id, response.data)
		await _load_logo(response.data)
		return Source.NETWORK

	# 404 = sucursal inexistente o inactiva: la caché de esa sucursal ya no vale.
	if response.status == 404:
		BrandCache.clear()
		TenantTheme.reset_to_fallback()
		return Source.FALLBACK
	return source


static func _load_logo(brand: Dictionary) -> void:
	var url := str(brand.get("logoUrl", ""))
	if url.is_empty():
		TenantTheme.set_logo(null)
		return
	TenantTheme.set_logo(await ApiClient.load_image(url))
