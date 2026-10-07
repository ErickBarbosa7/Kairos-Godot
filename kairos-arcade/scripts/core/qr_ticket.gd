class_name QrTicket
extends RefCounted
## Arma y firma el JWT que viaja en el QR. El QR anuncia la recompensa que salió en la ruleta;
## la API verifica la firma, comprueba que la recompensa sea del negocio y entrega el cupón.

const LIFETIME_SECONDS := 60

enum Problem { NONE, NOT_CONFIGURED, NO_KEY, SIGN_FAILED }

var problem := Problem.NONE
var token := ""
var expires_at := 0


## Datos que viajan firmados en el QR. `reward_id` es la recompensa que salió en la ruleta;
## sin ella el QR es de puntos.
static func build_claims(score: int, reward_id: String, now: int, jti: String) -> Dictionary:
	var claims := {
		"store_id": AppConfig.store_id,
		"machine_id": AppConfig.machine_id,
		"score": score,
		"iat": now,
		"exp": now + LIFETIME_SECONDS,
		"jti": jti,
	}
	if not reward_id.is_empty():
		claims["reward_id"] = reward_id
	return claims


static func create(score: int, reward_id: String = "") -> QrTicket:
	var ticket := QrTicket.new()
	if AppConfig.simulated or AppConfig.machine_id.is_empty():
		ticket.problem = Problem.NOT_CONFIGURED
		return ticket
	if AppConfig.private_key_path.is_empty() or not FileAccess.file_exists(AppConfig.private_key_path):
		ticket.problem = Problem.NO_KEY
		return ticket
	var pem := FileAccess.get_file_as_string(AppConfig.private_key_path)
	var now := int(Time.get_unix_time_from_system())
	var jti := Es256.base64url(Crypto.new().generate_random_bytes(16))
	ticket.token = Es256.sign_jwt(build_claims(score, reward_id, now, jti), pem)
	if ticket.token.is_empty():
		ticket.problem = Problem.SIGN_FAILED
		return ticket
	ticket.expires_at = now + LIFETIME_SECONDS
	return ticket


func seconds_left() -> float:
	return maxf(float(expires_at) - Time.get_unix_time_from_system(), 0.0)
