class_name CampaignBanner
extends RefCounted
## Campañas vigentes del negocio (`/public/stores/:id/campaigns`). Solo sirven de gancho en el menú:
## la terminal no las aplica, el servidor lo hace al acreditar el QR. Sin red no se muestra nada.

const MAX_NAMES := 3


## Nombres no vacíos de la respuesta de la API, como máximo MAX_NAMES.
static func sanitize(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var name := str(item.get("name", "")).strip_edges()
		if not name.is_empty():
			out.append(name)
		if out.size() >= MAX_NAMES:
			break
	return out


## Texto del menú: nombres unidos por " · ", o "" si no hay campañas.
static func line(names: Array) -> String:
	return " · ".join(names)


static func fetch() -> Array:
	if AppConfig.simulated:
		return []
	var response: Dictionary = await ApiClient.get_json("/public/stores/%s/campaigns" % AppConfig.store_id)
	if response.ok and typeof(response.data) == TYPE_DICTIONARY:
		return sanitize(response.data.get("data"))
	return []
