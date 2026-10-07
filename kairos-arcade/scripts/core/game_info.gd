class_name GameInfo
extends Resource
## Describe un juego del menú. Añadir un juego es crear un .tres en resources/games/.

@export var id: String = ""
@export var title: String = ""
@export var tagline: String = ""
@export var duration_seconds: int = 60
## Si es falso, la partida termina por su propia condición (por ejemplo, sin vidas).
@export var has_time_limit: bool = true
@export var playable: bool = false
@export var scene: PackedScene
@export var sort_order: int = 0
## Puntaje mínimo para ganar un QR. Las partidas por debajo no generan código.
@export var qr_goal: int = 0
## Instrucciones breves que muestra el botón de ayuda del menú.
@export_multiline var how_to_play: String = ""
