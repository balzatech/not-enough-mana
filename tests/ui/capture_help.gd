extends SceneTree
## Captura V2-30: ayuda desde el menú principal y desde la partida (no es un test GUT).
##   godot --path . -s tests/ui/capture_help.gd -- <dir> [ancho=720] [alto=1280]
const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_run.call_deferred(a[0] if a.size() > 0 else "/tmp", int(a[1]) if a.size() > 1 else 720,
		int(a[2]) if a.size() > 2 else 1280)


func _vp(w: int, h: int) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _run(dir: String, w: int, h: int) -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var vp: SubViewport = _vp(w, h)
	var hs: HelpScreen = (load(UiNav.HELP) as PackedScene).instantiate()
	hs.auto_navigate = false
	vp.add_child(hs)
	for i: int in 8:
		await process_frame
	vp.get_texture().get_image().save_png(dir + "/v2-30-menu.png")
	vp.queue_free()
	var vp2: SubViewport = _vp(w, h)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	vp2.add_child(t)
	t.set_view(Types.view_for(H.game(4, {"potion_limit_enabled": false, "start_hp": 12}, 7), "p1"), "p1")
	for i: int in 8:
		await process_frame
	t.ctx.menu.open_help()
	for i: int in 8:
		await process_frame
	t.ctx.menu.help_overlay.scroll.scroll_vertical = 1100
	for i: int in 8:
		await process_frame
	vp2.get_texture().get_image().save_png(dir + "/v2-30-partida.png")
	quit()
