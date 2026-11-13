extends Node
## Grabación corta para la landing: menú + una toma breve de algunos juegos.
##   godot --path kairos-arcade res://tools/demo_reel.tscn --write-movie reel.avi --fixed-fps 60

const GAMES_DIR := "res://resources/games"
const MENU_SECONDS := 3.0
const CLIP_SECONDS := 3.5
const MAX_CLIPS := 4

var _games: Array[GameInfo] = []
var _t := 0.0
var _clip := -1
var _clip_t := 0.0
var _held := {}
var _skipped := false


func _ready() -> void:
	for f in DirAccess.get_files_at(GAMES_DIR):
		if f.ends_with(".tres"):
			var g := load(GAMES_DIR + "/" + f) as GameInfo
			if g != null and g.playable:
				_games.append(g)
	_games.sort_custom(func(a: GameInfo, b: GameInfo) -> bool: return a.sort_order < b.sort_order)
	_games = _games.slice(0, MAX_CLIPS)
	_detach.call_deferred()


## Se cuelga de root: si no, el cambio de escena lo borraría junto con la escena actual.
func _detach() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file(Router.MENU)


func _process(delta: float) -> void:
	_t += delta
	if _clip < 0:
		if _t >= MENU_SECONDS:
			_next_clip()
		return
	_clip_t += delta
	_skip_countdown()
	_drive()
	if _clip_t >= CLIP_SECONDS:
		_next_clip()


func _skip_countdown() -> void:
	var scene := get_tree().current_scene
	if _skipped or scene == null or not (scene is ArcadeGame):
		return
	(scene as ArcadeGame).countdown = 0.05
	_skipped = true


func _next_clip() -> void:
	print("REEL clip ", _clip + 1, " games=", _games.size())
	_release_all()
	_clip += 1
	_clip_t = 0.0
	_skipped = false
	if _clip >= _games.size():
		get_tree().quit()
		return
	Router.start_game(_games[_clip])


func _drive() -> void:
	var s := sin(_clip_t * 2.2)
	var c := cos(_clip_t * 1.4)
	_press("move_left", s < -0.25)
	_press("move_right", s > 0.25)
	_press("move_up", c > 0.5)
	_press("move_down", c < -0.5)
	_press("fire", fmod(_clip_t, 0.45) < 0.2)


func _press(action: String, on: bool) -> void:
	if _held.get(action, false) == on:
		return
	_held[action] = on
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)


func _release_all() -> void:
	for a in _held.keys():
		_press(a, false)
