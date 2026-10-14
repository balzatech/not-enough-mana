class_name FloatingText
extends Label
## Número flotante de feedback ("▼ -2", "▲ +3 maná", "Bloqueado"): sube y se
## desvanece en `duration_ms` (>= 1 s) con un Tween propio. Lo usa FeedbackLayer,
## que los reutiliza (pool): `play` reinicia el nodo por completo.
## Estilo del tema (docs/arte/tecnico.md): variación FloatDamage / FloatHeal
## (fuente FONT_FLOAT, contorno y sombra) + make_float_material (uniform `fade`).

signal done(node: FloatingText)

const RISE_PX: float = 70.0
## Fracción final de la duración en la que se desvanece.
const FADE_FROM: float = 0.65

var _tween: Tween = null
var _mat: ShaderMaterial = null


static func create() -> FloatingText:
	var ft: FloatingText = FloatingText.new()
	ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ft.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ft._mat = UiTheme.make_float_material(true)
	ft.material = ft._mat
	ft.visible = false
	return ft


## Muestra `msg` centrado en `center` (coordenadas de la capa padre).
## damage elige la variación del tema; `tint` (alfa > 0) sustituye el color de fuente.
func play(msg: String, damage: bool, center: Vector2, duration_ms: int,
		tint: Color = Color(0, 0, 0, 0)) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	theme_type_variation = "FloatDamage" if damage else "FloatHeal"
	if tint.a > 0.0:
		add_theme_color_override("font_color", tint)
	else:
		remove_theme_color_override("font_color")
	text = msg
	size = Vector2.ZERO
	reset_size()
	var start: Vector2 = center - size * 0.5
	position = start
	_mat.set_shader_parameter("fade", 1.0)
	visible = true
	var secs: float = maxf(float(duration_ms), 1000.0) / 1000.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", start.y - RISE_PX, secs) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_fade, 1.0, 0.0, secs * (1.0 - FADE_FROM)).set_delay(secs * FADE_FROM)
	_tween.chain().tween_callback(_finish)


func is_playing() -> bool:
	return visible


func _set_fade(v: float) -> void:
	_mat.set_shader_parameter("fade", v)


func _finish() -> void:
	visible = false
	done.emit(self)
