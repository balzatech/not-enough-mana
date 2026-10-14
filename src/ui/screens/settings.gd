class_name Settings
extends Control
## Ajustes (user://settings.cfg). Música, Efectos y Vibración están ocultos mientras
## no exista audio ni vibración (QA-V2-35-03); sus claves se conservan en el archivo.

const PATH: String = "user://settings.cfg"

var auto_navigate: bool = true
var reaction_btn: Button
var _reaction_value: String = ReactionRelevance.MODE_AFFECTING

const REACTION_TEXT: Dictionary = {
	"affecting": "Solo de hechizos que me afectan",
	"all": "De todos",
}


## Preferencia "Avisarme de reacciones" (uno por dispositivo). Sin archivo o con
## un valor desconocido: "affecting".
static func load_reaction_notify(path: String = PATH) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(path)
	var v: String = String(cfg.get_value("reactions", "notify", ReactionRelevance.MODE_AFFECTING))
	if v != ReactionRelevance.MODE_ALL and v != ReactionRelevance.MODE_AFFECTING:
		return ReactionRelevance.MODE_AFFECTING
	return v


## Guarda la preferencia conservando el resto de claves del archivo.
static func save_reaction_notify(value: String, path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(path)
	cfg.set_value("reactions", "notify", value)
	cfg.save(path)


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	margin.add_child(col)
	col.add_child(UiUtil.label("Ajustes", 64, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	# Música, Efectos y Vibración ocultos: nada los lee todavía (vibración: v0.3).
	_reaction_value = load_reaction_notify()
	col.add_child(UiUtil.label("Avisarme de reacciones", 30, UiTheme.COL_MUTED))
	reaction_btn = UiUtil.button(REACTION_TEXT[_reaction_value], 30, UiTheme.BUTTON_MIN_H)
	reaction_btn.pressed.connect(_toggle_reaction)
	col.add_child(reaction_btn)
	col.add_child(UiUtil.label("Idioma: español", 28, UiTheme.COL_MUTED))
	col.add_child(UiUtil.spacer(0, true))
	var back: Button = UiUtil.button("Guardar y volver", 40, 130)
	back.pressed.connect(_on_back)
	col.add_child(back)


func _toggle_reaction() -> void:
	_reaction_value = ReactionRelevance.MODE_ALL if _reaction_value == ReactionRelevance.MODE_AFFECTING \
		else ReactionRelevance.MODE_AFFECTING
	reaction_btn.text = REACTION_TEXT[_reaction_value]


func _on_back() -> void:
	save_reaction_notify(_reaction_value)  # conserva el resto de claves (audio, vibración)
	if auto_navigate:
		UiNav.open_main_menu(get_tree())
