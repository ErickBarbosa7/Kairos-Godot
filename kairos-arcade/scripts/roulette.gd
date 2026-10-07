extends Control
## Ruleta: un solo giro por partida que llegó a la meta. Cada casilla es una recompensa del negocio
## y la que queda bajo la flecha es la que viaja en el QR. El resultado se decide al empezar a girar
## (no depende de cuándo se detenga la animación) y se guarda en ArcadeState.won_reward.

enum State { READY, SPINNING, REVEALED }

const WHEEL_SIDE := 640.0
const SPIN_SECONDS := 6.0
const AUTO_SPIN_SECONDS := 20.0
const AUTO_CONTINUE_SECONDS := 15.0

var _segments: Array = []
var _winner := -1
var _state := State.READY
var _idle := 0.0
var _wheel: WheelView
var _prompt: Label
var _auto: Label
var _reveal: Control
var _reveal_name: Label
var _confetti: ConfettiView
var _pulse_time := 0.0
var _built := false
var _reveal_image: TextureRect


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_segments = RewardCatalog.pick_segments(RewardCatalog.rewards, rng)
	if _segments.is_empty():
		# Sin recompensas no hay nada que girar: el resultado explica la situación.
		ArcadeState.reward_pending = false
		Router.to_result.call_deferred()
		return
	# Las imágenes suelen estar ya descargadas; si faltan, se espera un poco y se sigue sin ellas.
	await RewardCatalog.ensure_images(_segments)
	_build()
	HelpOverlay.attach(self, "roulette", Callable(), false)
	_built = true


func _process(delta: float) -> void:
	if not _built:
		return
	_idle += delta
	match _state:
		State.READY:
			_auto.text = Strings.ROULETTE_AUTO % ceili(maxf(AUTO_SPIN_SECONDS - _idle, 0.0))
			if _idle >= AUTO_SPIN_SECONDS:
				_spin()
		State.REVEALED:
			_pulse_time += delta
			_wheel.pulse = 0.5 + 0.5 * sin(_pulse_time * (2.0 if AppConfig.reduce_motion else 6.0))
			_wheel.queue_redraw()
			if _idle >= AUTO_CONTINUE_SECONDS:
				_continue()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if not _built or not event.is_action_pressed("confirm"):
		return
	if _state == State.READY:
		_spin()
		viewport.set_input_as_handled()
	elif _state == State.REVEALED:
		viewport.set_input_as_handled()
		_continue()


func _spin() -> void:
	_state = State.SPINNING
	_idle = 0.0
	_prompt.text = Strings.ROULETTE_SPINNING
	_auto.text = ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_winner = rng.randi_range(0, _segments.size() - 1)
	ArcadeState.won_reward = _segments[_winner]
	var turns := 1 if AppConfig.reduce_motion else rng.randi_range(5, 7)
	var target := WheelMath.final_angle(_winner, _segments.size(), turns, rng.randf_range(-0.35, 0.35))
	var tween := create_tween()
	tween.tween_property(_wheel, "rot", target, 0.6 if AppConfig.reduce_motion else SPIN_SECONDS).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_stopped)


func _on_stopped() -> void:
	_state = State.REVEALED
	_idle = 0.0
	_wheel.highlight = _winner
	_reveal_name.text = str(_segments[_winner].title)
	var picture: Texture2D = RewardCatalog.images.get(str(_segments[_winner].id))
	_reveal_image.texture = picture
	_reveal_image.visible = picture != null
	_reveal.visible = true
	_prompt.get_parent().visible = false
	if not AppConfig.reduce_motion:
		_reveal.scale = Vector2(0.85, 0.85)
		var t := create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_reveal, "scale", Vector2.ONE, 0.35)
		_confetti.burst()


func _continue() -> void:
	set_process(false)
	ArcadeState.reward_pending = false
	Router.to_result()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = TenantTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	col.add_child(_label(Strings.ROULETTE_TITLE, UiKit.display(900), 72, TenantTheme.TEXT))
	col.add_child(_label(Strings.ROULETTE_SUBTITLE, UiKit.accent(), 44, TenantTheme.TEXT_SECONDARY))

	_wheel = WheelView.new()
	_wheel.segments = _segments
	_wheel.custom_minimum_size = Vector2(WHEEL_SIDE + 120.0, WHEEL_SIDE + 40.0)
	col.add_child(_wheel)

	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UiKit.chip_style(TenantTheme.primary, TenantTheme.primary))
	_prompt = _label(Strings.ROULETTE_PRESS, UiKit.display(900), 44, TenantTheme.on_primary)
	chip.add_child(_prompt)
	col.add_child(chip)
	_auto = _label("", UiKit.text(500), 26, TenantTheme.TEXT_SECONDARY)
	col.add_child(_auto)

	_confetti = ConfettiView.new()
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confetti)
	_build_reveal()


func _build_reveal() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_reveal = PanelContainer.new()
	_reveal.visible = false
	_reveal.pivot_offset = Vector2(560, 200)
	_reveal.add_theme_stylebox_override("panel", UiKit.card_style(true, false))
	holder.add_child(_reveal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	_reveal.add_child(row)
	# La imagen que puso el administrador al crear la recompensa.
	_reveal_image = TextureRect.new()
	_reveal_image.custom_minimum_size = Vector2(300, 300)
	_reveal_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reveal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal_image.visible = false
	row.add_child(_reveal_image)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 12)
	row.add_child(box)
	box.add_child(_label(Strings.ROULETTE_WON, UiKit.display(900), 64, TenantTheme.SUCCESS))
	_reveal_name = _label("", UiKit.display(900), 104, TenantTheme.REWARD)
	_reveal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_reveal_name)
	box.add_child(_label(Strings.ROULETTE_CONTINUE, UiKit.text(600), 30, TenantTheme.TEXT_SECONDARY))


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
