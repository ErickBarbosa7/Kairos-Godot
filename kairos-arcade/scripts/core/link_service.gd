class_name LinkService
extends RefCounted
## Vincula esta máquina con un negocio: inicia sesión como administrador, genera aquí el par
## de llaves, registra solo la pública en el panel y guarda la configuración.
## La llave privada nunca sale del equipo y ni la contraseña ni el token se guardan.

const CONFIG_NAME := "machine.config.json"
const KEY_NAME := "machine.private.pem"

## Carpeta donde se guarda la identidad. Las pruebas la cambian para no tocar la real.
static var dir := "user://"


static func message_for(status: int, server_message: String = "") -> String:
	match status:
		0:
			return Strings.LINK_NETWORK
		401:
			return Strings.LINK_BAD_LOGIN
		403:
			return Strings.LINK_NOT_ADMIN
		429:
			return Strings.LINK_RATE
	if status == 400 and not server_message.is_empty():
		return server_message
	return Strings.LINK_GENERIC


static func _error_message(response: Dictionary) -> String:
	var server := ""
	var data: Variant = response.get("data")
	if typeof(data) == TYPE_DICTIONARY and typeof(data.get("error")) == TYPE_DICTIONARY:
		server = str(data.error.get("message", ""))
	return message_for(int(response.status), server)


## Paso 1. Devuelve { ok, token, business_name, message }.
static func login(api_url: String, slug: String, email: String, password: String) -> Dictionary:
	var client: Node = Engine.get_main_loop().root.get_node("ApiClient")
	var r: Dictionary = await client.send_json(HTTPClient.METHOD_POST, api_url, "/auth/tenant/login", {
		"tenantSlug": slug.strip_edges().to_lower(),
		"email": email.strip_edges(),
		"password": password,
	})
	if not r.ok:
		return {"ok": false, "message": _error_message(r)}
	var user: Variant = r.data.get("user", {}) if typeof(r.data) == TYPE_DICTIONARY else {}
	if typeof(user) == TYPE_DICTIONARY and str(user.get("role", "")) != "tenant_admin":
		return {"ok": false, "message": Strings.LINK_NOT_ADMIN}
	var token := str(r.data.get("accessToken", ""))
	return {"ok": true, "token": token, "business_name": await _business_name(api_url, token, slug)}


## Nombre del negocio para mostrarlo. Si /auth/me falla, se usa el identificador.
static func _business_name(api_url: String, token: String, fallback: String) -> String:
	var client: Node = Engine.get_main_loop().root.get_node("ApiClient")
	var me: Dictionary = await client.send_json(HTTPClient.METHOD_GET, api_url, "/auth/me", null, token)
	if me.ok and typeof(me.data) == TYPE_DICTIONARY and typeof(me.data.get("tenant")) == TYPE_DICTIONARY:
		var name := str(me.data.tenant.get("name", ""))
		if not name.is_empty():
			return name
	return fallback


## Paso 2. Sucursales activas del negocio: { ok, stores: [{id, name}], message }.
static func list_stores(api_url: String, token: String) -> Dictionary:
	var client: Node = Engine.get_main_loop().root.get_node("ApiClient")
	var r: Dictionary = await client.send_json(HTTPClient.METHOD_GET, api_url, "/tenant/stores", null, token)
	if not r.ok:
		return {"ok": false, "message": _error_message(r)}
	var stores: Array = []
	var rows: Variant = r.data.get("data", []) if typeof(r.data) == TYPE_DICTIONARY else []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and bool(row.get("isActive", true)):
			stores.append({"id": str(row.id), "name": str(row.name)})
	return {"ok": true, "stores": stores}


## Paso 3. Genera las llaves, registra la pública y guarda la identidad.
## Devuelve { ok, machine_id, message }.
static func link_machine(api_url: String, token: String, store: Dictionary, label: String, business_name: String) -> Dictionary:
	var private_key := Es256.generate_private_key()
	if private_key.size() != 32:
		return {"ok": false, "message": Strings.LINK_KEY_FAILED}
	var public_key := Es256.public_key(private_key)
	var client: Node = Engine.get_main_loop().root.get_node("ApiClient")
	var r: Dictionary = await client.send_json(HTTPClient.METHOD_POST, api_url, "/tenant/machines", {
		"storeId": store.id,
		"label": label.strip_edges(),
		"keyAlgorithm": "ES256",
		"publicKey": Es256.public_pem(public_key),
	}, token)
	if not r.ok:
		return {"ok": false, "message": _error_message(r)}
	var machine_id := str(r.data.get("id", ""))
	if machine_id.is_empty():
		return {"ok": false, "message": Strings.LINK_GENERIC}
	if not save_identity(api_url, str(store.id), machine_id, Es256.private_pem(private_key, public_key), business_name, label.strip_edges()):
		return {"ok": false, "message": Strings.LINK_SAVE_FAILED}
	return {"ok": true, "machine_id": machine_id}


static func save_identity(api_url: String, store_id: String, machine_id: String, private_pem: String, business_name: String, label: String) -> bool:
	var key_path := dir.path_join(KEY_NAME)
	var key_file := FileAccess.open(key_path, FileAccess.WRITE)
	if key_file == null:
		return false
	key_file.store_string(private_pem)
	key_file.close()
	_restrict(key_path)
	var config := {
		"api_url": api_url.rstrip("/"),
		"store_id": store_id,
		"machine_id": machine_id,
		"private_key_path": ProjectSettings.globalize_path(key_path),
		"business_name": business_name,
		"machine_label": label,
		"linked_at": int(Time.get_unix_time_from_system()),
	}
	var config_path := dir.path_join(CONFIG_NAME)
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(config, "  "))
	file.close()
	_restrict(config_path)
	return true


## Solo el usuario del equipo puede leer la llave (Linux y macOS; en Windows lo hace la carpeta de usuario).
static func _restrict(path: String) -> void:
	if OS.has_feature("linuxbsd") or OS.has_feature("macos"):
		OS.execute("chmod", ["600", ProjectSettings.globalize_path(path)])
