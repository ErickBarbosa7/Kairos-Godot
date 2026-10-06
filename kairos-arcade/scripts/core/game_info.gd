class_name GameInfo
extends Resource
## Describe un juego del menú. Añadir un juego es crear un .tres en resources/games/.

@export var id: String = ""
@export var title: String = ""
@export var tagline: String = ""
@export var duration_seconds: int = 60
@export var playable: bool = false
@export var scene: PackedScene
@export var sort_order: int = 0
