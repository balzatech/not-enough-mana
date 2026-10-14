class_name UiUtil
extends RefCounted
## Utilidades de UI: texturas con caché, definiciones de carta, fábricas de nodos.

const CARD_DIR: String = "res://assets/cards/"
const BG_DIR: String = "res://assets/bg/"
const CARD_BACK: String = "res://assets/cardback.webp"
const MIN_TOUCH: int = 96

const MONTHS: Array[String] = [
	"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
	"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]

## Definiciones adicionales (fixtures/tests) usadas si el catálogo no las tiene.
static var extra_defs: Dictionary = {}
## true => extra_defs manda sobre el catálogo (tests deterministas).
static var prefer_extra: bool = false
static var _tex_cache: Dictionary = {}


## Carga una textura de res:// (importada o, si no, directamente del disco).
## Devuelve null si no existe.
static func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_tex_cache[path] = tex
	return tex


static func card_texture(def: Dictionary) -> Texture2D:
	var pages: Array = def.get("pages", [])
	if pages.is_empty():
		return null
	return load_texture(CARD_DIR + "%03d.webp" % int(pages[0]))


static func card_back_texture() -> Texture2D:
	return load_texture(CARD_BACK)


## Primer fondo disponible en res://assets/bg/ (null si no hay).
static func background_texture() -> Texture2D:
	if _tex_cache.has("__bg"):
		return _tex_cache["__bg"] as Texture2D
	var tex: Texture2D = null
	var files: PackedStringArray = DirAccess.get_files_at(BG_DIR)
	var names: Array[String] = []
	for f: String in files:
		var lower: String = f.to_lower()
		if lower.ends_with(".webp") or lower.ends_with(".png") or lower.ends_with(".jpg"):
			names.append(f)
	names.sort()
	if not names.is_empty():
		tex = load_texture(BG_DIR + names[0])
	if tex != null:
		_tex_cache["__bg"] = tex
	return tex


## Definición de carta: catálogo, luego extra_defs, luego una genérica.
static func card_def(card_id: String) -> Dictionary:
	if prefer_extra and extra_defs.has(card_id):
		return extra_defs[card_id] as Dictionary
	var d: Dictionary = CardCatalog.get_def(card_id)
	if not d.is_empty():
		return d
	if extra_defs.has(card_id):
		return extra_defs[card_id] as Dictionary
	return Types.make_card_def(card_id, card_id.replace("_", " ").capitalize(),
		Types.CARD_TYPE_SUPPORT)


## Fondo de pantalla: imagen de assets/bg oscurecida o color liso.
static func make_background() -> Control:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: ColorRect = ColorRect.new()
	base.color = UiTheme.COL_BG
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	var tex: Texture2D = background_texture()
	if tex != null:
		var img_rect: TextureRect = TextureRect.new()
		img_rect.texture = tex
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(img_rect)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.07, 0.72 if tex != null else 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	return root


static func label(text: String, font_size: int = 30, color: Color = UiTheme.COL_TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, font_size: int = 32, min_h: int = MIN_TOUCH) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(MIN_TOUCH, min_h)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Botón de dos estados cuyo texto cambia con el valor.
static func toggle_button(text_on: String, text_off: String, value: bool, font_size: int = 30) -> Button:
	var b: Button = button(text_on if value else text_off, font_size, 80)
	b.toggle_mode = true
	b.button_pressed = value
	b.toggled.connect(func(on: bool) -> void: b.text = text_on if on else text_off)
	return b


static func spacer(h: int = 0, expand: bool = false) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func clear_children(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Color asociado a un elemento / tipo de carta (placeholder y bordes).
static func card_color(def: Dictionary) -> Color:
	var element: String = String(def.get("element", Types.ELEMENT_NONE))
	match element:
		Types.ELEMENT_FIRE:
			return Color(0.55, 0.16, 0.10)
		Types.ELEMENT_ICE:
			return Color(0.12, 0.34, 0.52)
		Types.ELEMENT_ELECTRIC:
			return Color(0.50, 0.42, 0.08)
	match String(def.get("type", "")):
		Types.CARD_TYPE_DEFENSIVE:
			return Color(0.14, 0.30, 0.46)
		Types.CARD_TYPE_SUPPORT:
			return Color(0.13, 0.38, 0.24)
		Types.CARD_TYPE_CURSE:
			return Color(0.35, 0.14, 0.45)
		Types.CARD_TYPE_ARTIFACT:
			return Color(0.42, 0.32, 0.14)
		Types.CARD_TYPE_EVENT:
			return Color(0.45, 0.14, 0.34)
	return Color(0.22, 0.22, 0.30)


static func type_name(type: String) -> String:
	match type:
		Types.CARD_TYPE_OFFENSIVE:
			return "Ofensiva"
		Types.CARD_TYPE_DEFENSIVE:
			return "Defensiva"
		Types.CARD_TYPE_SUPPORT:
			return "Soporte"
		Types.CARD_TYPE_CURSE:
			return "Maldición"
		Types.CARD_TYPE_ARTIFACT:
			return "Artefacto"
		Types.CARD_TYPE_EVENT:
			return "Evento"
	return ""


static func element_name(element: String) -> String:
	match element:
		Types.ELEMENT_FIRE:
			return "Fuego"
		Types.ELEMENT_ICE:
			return "Hielo"
		Types.ELEMENT_ELECTRIC:
			return "Electricidad"
	return ""


## Mensaje en español para un código de error del motor.
static func error_text(code: String) -> String:
	match code:
		Types.ERR_NOT_YOUR_TURN:
			return "No es tu turno."
		Types.ERR_INSUFFICIENT_MANA:
			return "No tienes maná suficiente."
		Types.ERR_INVALID_TARGET:
			return "Objetivo no válido."
		Types.ERR_INVALID_PAYMENT:
			return "Las cartas de pago no sirven."
		Types.ERR_REACTION_PENDING:
			return "Hay una reacción en curso."
		Types.ERR_PROMPT_PENDING:
			return "Tienes una decisión pendiente."
		Types.ERR_BLINDED:
			return "Estás cegado: no puedes lanzar ofensivas."
		Types.ERR_TARGET_IMMUNE:
			return "El objetivo es inmune."
		Types.ERR_WRONG_PHASE:
			return "No se puede hacer ahora."
		Types.ERR_CARD_NOT_PLAYABLE:
			return "Esa carta no se puede jugar ahora."
		Types.ERR_ARTIFACT_LIMIT:
			return "Ya tienes ese artefacto."
		Types.ERR_STALE_REV:
			return "El estado cambió; inténtalo de nuevo."
		Types.ERR_NOT_IMPLEMENTED:
			return "Acción aún no implementada."
		Types.ERR_NOT_YOUR_DECISION:
			return "Ahora no te toca decidir."
		Types.ERR_NO_REACTION:
			return "No hay ninguna reacción abierta."
		Types.ERR_PROMPT_NOT_FOUND:
			return "Esa decisión ya no está pendiente."
		Types.ERR_CARD_NOT_IN_HAND:
			return "Esa carta ya no está en tu mano."
		Types.ERR_CARD_NOT_IN_PLAY:
			return "Esa carta ya no está en juego."
		Types.ERR_INVALID_CHOICE:
			return "Elección no válida."
		Types.ERR_NOTHING_TO_DISCARD:
			return "Elige al menos una carta para descartar."
		Types.ERR_ARTIFACT_ALREADY_USED:
			return "Ya has usado ese artefacto este turno."
		Types.ERR_GAME_NOT_PLAYING:
			return "La partida ha terminado."
		Types.ERR_PLAYER_ELIMINATED:
			return "Estás eliminado."
		Types.ERR_INVALID_ACTION:
			return "Acción no válida."
		Types.ERR_NO_EFFECT, Types.ERR_UNKNOWN_CARD:
			return "Esa carta no tiene efecto disponible."
		Types.ERR_UNKNOWN_PLAYER:
			return "Jugador desconocido."
	return "Acción rechazada (%s)." % code
