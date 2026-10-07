class_name HelpTexts
extends RefCounted
## Textos de ayuda de cada pantalla, en español. Cada tema es una lista de bloques
## { heading, text }. La explicación general de Kairos es común a todas las pantallas.

const GENERAL_TITLE := "¿QUÉ ES KAIROS?"
const GENERAL_INTRO := "Kairos es el programa de puntos de este negocio: juegas aquí, ganas puntos y los cambias por premios."
const GENERAL_STEPS: Array[String] = [
	"Elige un juego y juega una partida de 60 segundos.",
	"Si llegas a la meta de recompensa del juego, ¡giras la ruleta!",
	"La recompensa que salga aparece como un código: escanéalo con la app Kairos antes de 60 segundos.",
	"Tu recompensa queda en tu cuenta. Preséntala en caja para recibirla.",
]
const GENERAL_WHY_GOAL := "La recompensa solo se da al llegar a la meta para que ganarla sea un reto."

const TOPICS := {
	"menu": {
		"title": "ELEGIR JUEGO",
		"blocks": [
			{"heading": "Cómo moverte", "text": "Usa ← → para elegir un juego y ESPACIO para jugar."},
			{"heading": "La meta de recompensa", "text": "Cada juego muestra su meta de recompensa. Llega a ese puntaje en una sola partida para girar la ruleta y ganarla."},
			{"heading": "Marcador", "text": "Pulsa ↑ para ver los 10 mejores de cada juego en esta máquina."},
		],
	},
	"entry": {
		"title": "TUS INICIALES",
		"blocks": [
			{"heading": "Entraste al marcador", "text": "Tu puntaje está entre los 10 mejores de este juego. Elige 3 caracteres para tu nombre."},
			{"heading": "Cómo se eligen", "text": "↑ ↓ cambian la letra, ← → cambian de casilla y ESPACIO confirma. En LISTO se guarda."},
			{"heading": "Si no haces nada", "text": "Se guarda solo a los 30 segundos con lo que tengas."},
		],
	},
	"scoreboard": {
		"title": "MARCADOR",
		"blocks": [
			{"heading": "Qué ves", "text": "Los 10 mejores puntajes de cada juego en esta máquina, con sus iniciales."},
			{"heading": "Cómo moverte", "text": "← → cambia de juego. ESPACIO o ESC vuelve."},
		],
	},
	"result": {
		"title": "TU RESULTADO",
		"blocks": [
			{"heading": "Si llegaste a la meta", "text": "Giraste la ruleta y verás tu recompensa con un código para escanear. Dura 60 segundos: ábrelo con la app Kairos en tu teléfono y escanéalo."},
			{"heading": "Si no llegaste", "text": "La barra muestra cuánto te faltó. Juega otra vez para intentarlo."},
			{"heading": "Qué puedes hacer", "text": "Jugar otra vez, ver el marcador o volver al menú."},
		],
	},
	"roulette": {
		"title": "LA RULETA",
		"blocks": [
			{"heading": "Un solo intento", "text": "Llegaste a la meta, así que ganas un giro. Pulsa ESPACIO para girar; si no haces nada, gira sola."},
			{"heading": "Qué puedes ganar", "text": "Cada casilla es una recompensa de este negocio. La que quede bajo la flecha es tuya."},
			{"heading": "Después", "text": "Verás tu recompensa con un código para escanear con la app Kairos."},
		],
	},
	"link": {
		"title": "VINCULAR LA MÁQUINA",
		"blocks": [
			{"heading": "Solo para el administrador", "text": "Esta pantalla conecta la máquina con tu negocio. Usa el mismo correo y contraseña del panel de Kairos."},
			{"heading": "Identificador del negocio", "text": "Es el nombre corto con el que entras al panel, por ejemplo cafeteria-aurora."},
			{"heading": "Qué pasa al vincular", "text": "La máquina crea su propia llave de seguridad y registra solo la parte pública. Tu contraseña no se guarda."},
		],
	},
	"admin": {
		"title": "OPCIONES DE ADMINISTRADOR",
		"blocks": [
			{"heading": "Vincular de nuevo", "text": "Registra esta máquina otra vez como una máquina nueva. Revoca la anterior en el panel."},
			{"heading": "Salir de la aplicación", "text": "Cierra Kairos Arcade. Si la máquina está en modo kiosco, se vuelve a abrir al reiniciar el equipo."},
		],
	},
}


## Tema de una pantalla o uno vacío si no existe.
static func topic(id: String) -> Dictionary:
	return TOPICS.get(id, {"title": Strings.HELP_TITLE, "blocks": []})
