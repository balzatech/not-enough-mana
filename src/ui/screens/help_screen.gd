class_name HelpScreen
extends Control
## "Cómo se juega" (V2-30): las 8 secciones de StringsAyuda con desplazamiento vertical.
## Como escena propia (menú principal) vuelve con UiNav; como superposición de la mesa
## (menú de la partida) solo emite `back_pressed` y no toca el estado de la partida.

signal back_pressed

const TITLE_SIZE: int = 36
const BODY_SIZE: int = 26

## Configuración activa (vacío = valores por defecto).
var config: Dictionary = {}
## true: Volver cambia a UiNav.MAIN_MENU (poner a false en tests y en la mesa).
var auto_navigate: bool = true
var scroll: ScrollContainer
var back_btn: Button
var hint_label: Label
var title_labels: Array[Label] = []
var body_labels: Array[Label] = []


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 50)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	col.add_child(UiUtil.label(StringsAyuda.SCREEN_TITLE, 60, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for sec: Dictionary in StringsAyuda.sections(config):
		var t: Label = UiUtil.label(String(sec["title"]), TITLE_SIZE, UiTheme.COL_ACCENT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(t)
		title_labels.append(t)
		var b: Label = UiUtil.label(String(sec["body"]), BODY_SIZE, UiTheme.COL_TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(b)
		body_labels.append(b)
		list.add_child(UiUtil.spacer(16))
	back_btn = UiUtil.button(StringsAyuda.BACK_LABEL, 36, UiTheme.BUTTON_MIN_H)
	back_btn.pressed.connect(_on_back)
	col.add_child(back_btn)
	hint_label = UiUtil.label(StringsAyuda.VIEW_CARD_HINT, UiTheme.FONT_MIN, UiTheme.COL_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint_label)


func _on_back() -> void:
	back_pressed.emit()
	if auto_navigate and is_inside_tree():
		UiNav.go(get_tree(), UiNav.MAIN_MENU)
