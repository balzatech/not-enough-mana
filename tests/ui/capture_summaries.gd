extends SceneTree
## Captura V2-28: ficha con resumen y zoom (no es un test GUT).
##   godot --path . -s tests/ui/capture_summaries.gd -- <carta> <salida_prefijo> [ancho=720] [alto=1280]
const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_run.call_deferred(a[0] if a.size() > 0 else "lightning", a[1] if a.size() > 1 else "/tmp/v2-28",
		int(a[2]) if a.size() > 2 else 720, int(a[3]) if a.size() > 3 else 1280)


func _run(card: String, out: String, w: int, h: int) -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = H.game(4, {}, 7, [40, 30, 20, 25])
	H.set_hand(s, "p1", ["fire_arrow", "fireball", "lightning", "heal", "magic_shield", "last_wish"])
	H.set_mana(s, "p1", 3)
	H.force_turn(s, "p1")
	s["pending"] = []
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	vp.add_child(t)
	t.set_view(Types.view_for(s, "p1"), "p1")
	for i: int in 8:
		await process_frame
	for c: Variant in H.hand(s, "p1"):
		if String((c as Dictionary)["card_id"]) == card:
			t._on_hand_tapped({"iid": int((c as Dictionary)["iid"])})
			for i: int in 8:
				await process_frame
			vp.get_texture().get_image().save_png(out + "-ficha.png")
			t._show_zoom(c, UiUtil.card_def(card))
	for i: int in 8:
		await process_frame
	vp.get_texture().get_image().save_png(out + "-zoom.png")
	quit()
