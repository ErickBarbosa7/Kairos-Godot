class_name HelpTexts
extends RefCounted
## Ayuda de la terminal, a propósito muy corta: la gente la lee de pie y con prisa.
## Tres pasos que explican qué es esto y una línea sobre la pantalla actual.

const GENERAL_TITLE := "¿CÓMO FUNCIONA?"
const GENERAL_STEPS: Array[String] = [
	"Juega y llega a la meta.",
	"Gira la ruleta.",
	"Escanea tu código y recibe tu recompensa.",
]

const TOPICS := {
	"menu": {"title": "Elegir juego", "hint": "← → elige  ·  ESPACIO juega  ·  ↑ marcador"},
	"entry": {"title": "Tus iniciales", "hint": "↑ ↓ cambia la letra  ·  ← → mueve  ·  ESPACIO confirma"},
	"scoreboard": {"title": "Marcador", "hint": "← → cambia de juego  ·  ESPACIO vuelve"},
	"result": {"title": "Tu resultado", "hint": "Escanea el código con la app Kairos antes de que se acabe el tiempo."},
	"roulette": {"title": "La ruleta", "hint": "Pulsa ESPACIO para girar. Un solo intento."},
	"link": {"title": "Vincular la máquina", "hint": "Solo para el administrador. Usa el correo y la contraseña del panel."},
	"admin": {"title": "Administrador", "hint": "Vincular de nuevo crea una máquina nueva. Salir cierra la aplicación."},
}


## Tema de una pantalla, o uno vacío si no existe.
static func topic(id: String) -> Dictionary:
	return TOPICS.get(id, {"title": Strings.HELP_TITLE, "hint": ""})
