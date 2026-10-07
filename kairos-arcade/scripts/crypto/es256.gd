class_name Es256
extends RefCounted
## Firma ECDSA P-256 con SHA-256 (JWT ES256). El nonce es determinista (RFC 6979),
## así que no depende de la calidad del azar de la máquina.


## Extrae la clave privada (32 bytes) de un PEM PKCS#8 de curva P-256. Vacío si no es válido.
static func parse_private_pem(pem: String) -> PackedByteArray:
	var body := ""
	for line in pem.split("\n"):
		var l := line.strip_edges()
		if not l.is_empty() and not l.begins_with("-----"):
			body += l
	var der := Marshalls.base64_to_raw(body)
	# SEC1 dentro de PKCS#8: 02 01 01 04 20 <32 bytes>
	var marker := PackedByteArray([0x02, 0x01, 0x01, 0x04, 0x20])
	for i in range(der.size() - marker.size() - 32 + 1):
		var match_here := true
		for j in marker.size():
			if der[i + j] != marker[j]:
				match_here = false
				break
		if match_here:
			return der.slice(i + marker.size(), i + marker.size() + 32)
	return PackedByteArray()


# Cabeceras DER fijas de las llaves P-256: la estructura no cambia, solo cambian los bytes de la llave.
const SPKI_PREFIX := "3059301306072A8648CE3D020106082A8648CE3D030107034200"
const PKCS8_PREFIX := "308187020100301306072A8648CE3D020106082A8648CE3D030107046D306B0201010420"
const PKCS8_SUFFIX := "A144034200"


## Llave privada nueva (32 bytes, 1 <= d < n) con el azar seguro del sistema.
static func generate_private_key() -> PackedByteArray:
	var fn := P256.field_n()
	var crypto := Crypto.new()
	for attempt in 16:
		var d := crypto.generate_random_bytes(32)
		var limbs := MontField.from_bytes(d)
		if not MontField.is_zero(limbs) and not MontField.ge(limbs, fn.m):
			return d
	return PackedByteArray()


## Llave pública sin comprimir (x || y, 64 bytes) de una privada.
static func public_key(private_key: PackedByteArray) -> PackedByteArray:
	var xy := P256.base_mul(private_key)
	return (xy[0] as PackedByteArray) + (xy[1] as PackedByteArray)


static func _pem(label: String, der: PackedByteArray) -> String:
	var b64 := Marshalls.raw_to_base64(der)
	var lines := PackedStringArray(["-----BEGIN %s-----" % label])
	for i in range(0, b64.length(), 64):
		lines.append(b64.substr(i, 64))
	lines.append("-----END %s-----" % label)
	return "\n".join(lines) + "\n"


## PEM SPKI de la llave pública: el formato que registra el panel.
static func public_pem(public_key_xy: PackedByteArray) -> String:
	return _pem("PUBLIC KEY", SPKI_PREFIX.hex_decode() + PackedByteArray([4]) + public_key_xy)


## PEM PKCS#8 de la llave privada: el mismo formato que genera `gen:machine-key`.
static func private_pem(private_key: PackedByteArray, public_key_xy: PackedByteArray) -> String:
	return _pem("PRIVATE KEY", PKCS8_PREFIX.hex_decode() + private_key + PKCS8_SUFFIX.hex_decode() + PackedByteArray([4]) + public_key_xy)


static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


## Firma r||s (64 bytes) del resumen SHA-256 ya calculado.
static func sign_digest(private_key: PackedByteArray, digest: PackedByteArray) -> PackedByteArray:
	var fn := P256.field_n()
	var d := MontField.from_bytes(private_key)
	var z := fn.reduce_once(MontField.from_bytes(digest))
	var crypto := Crypto.new()
	var h1 := MontField.to_bytes(z)

	var v := PackedByteArray()
	v.resize(32)
	v.fill(1)
	var k := PackedByteArray()
	k.resize(32)
	k.fill(0)
	k = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v + PackedByteArray([0]) + private_key + h1)
	v = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v)
	k = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v + PackedByteArray([1]) + private_key + h1)
	v = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v)

	for attempt in 16:
		v = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v)
		var nonce := MontField.from_bytes(v)
		if not MontField.is_zero(nonce) and not MontField.ge(nonce, fn.m):
			var r_bytes := P256.base_mul_x(v)
			var r := fn.reduce_once(MontField.from_bytes(r_bytes))
			if not MontField.is_zero(r):
				var k_inv := fn.inv(fn.to_mont(nonce))
				var inner := fn.add(fn.to_mont(z), fn.mul(fn.to_mont(r), fn.to_mont(d)))
				var s := fn.from_mont(fn.mul(k_inv, inner))
				if not MontField.is_zero(s):
					return MontField.to_bytes(r) + MontField.to_bytes(s)
		k = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v + PackedByteArray([0]))
		v = crypto.hmac_digest(HashingContext.HASH_SHA256, k, v)
	return PackedByteArray()


## JWT compacto firmado con ES256. Devuelve "" si la clave no es válida.
static func sign_jwt(claims: Dictionary, private_pem: String) -> String:
	var key := parse_private_pem(private_pem)
	if key.size() != 32:
		return ""
	var header := base64url('{"alg":"ES256"}'.to_utf8_buffer())
	var payload := base64url(JSON.stringify(claims, "", false).to_utf8_buffer())
	var signing_input := "%s.%s" % [header, payload]
	var signature := sign_digest(key, signing_input.sha256_buffer())
	if signature.size() != 64:
		return ""
	return "%s.%s" % [signing_input, base64url(signature)]
