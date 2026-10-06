extends Node
## Peticiones HTTP a la API de Kairos. No decide lógica de juego.

const TIMEOUT_SECONDS := 3.0
const MAX_IMAGE_BYTES := 2 * 1024 * 1024


## GET con JSON. Devuelve { ok: bool, status: int, data: Variant }.
## status 0 significa sin red o tiempo agotado.
func get_json(path: String) -> Dictionary:
	if AppConfig.simulated:
		return {"ok": false, "status": 0, "data": null}
	var result := await _request(AppConfig.api_url + path)
	if result.error != OK:
		return {"ok": false, "status": 0, "data": null}
	var status: int = result.status
	var data: Variant = JSON.parse_string((result.body as PackedByteArray).get_string_from_utf8())
	return {"ok": status >= 200 and status < 300, "status": status, "data": data}


## Descarga una imagen PNG, JPEG o WebP. Devuelve ImageTexture o null.
func load_image(url: String) -> ImageTexture:
	if url.is_empty() or AppConfig.simulated:
		return null
	var result := await _request(url)
	if result.error != OK or result.status != 200:
		return null
	var body: PackedByteArray = result.body
	if body.size() > MAX_IMAGE_BYTES:
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if body.size() > 8 and body[0] == 0x89 and body[1] == 0x50:
		err = image.load_png_from_buffer(body)
	elif body.size() > 3 and body[0] == 0xFF and body[1] == 0xD8:
		err = image.load_jpg_from_buffer(body)
	elif body.size() > 12 and body.slice(0, 4).get_string_from_ascii() == "RIFF":
		err = image.load_webp_from_buffer(body)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _request(url: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return {"error": err, "status": 0, "body": PackedByteArray()}
	var response: Array = await http.request_completed
	http.queue_free()
	var request_result: int = response[0]
	return {
		"error": OK if request_result == HTTPRequest.RESULT_SUCCESS else FAILED,
		"status": response[1],
		"body": response[3],
	}
