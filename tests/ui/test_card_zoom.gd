extends GutTest
## Regresión QA-V2-03-01: el overlay CardZoom salía con tamaño 0.

func before_each() -> void:
	FakeState.install_defs()


func _host() -> Control:
	var host: Control = Control.new()
	host.custom_minimum_size = Vector2(540, 960)
	host.size = Vector2(540, 960)
	add_child_autofree(host)
	return host


func test_zoom_abierto_cubre_el_padre_y_tiene_fondo() -> void:
	var host: Control = _host()
	var z: CardZoom = CardZoom.new()
	host.add_child(z)
	var c: Dictionary = FakeState.make_view(4, "p1")["players"][0]["hand"][0]
	z.show_card(c, UiUtil.card_def(String(c["card_id"])))
	assert_true(z.visible)
	assert_eq(z.size, host.size)
	assert_gt(z._dim.size.x, 0.0)
	assert_gt(z._dim.size.y, 0.0)
	assert_gt(z._dim.color.a, 0.5, "fondo oscuro")
	var col: Control = z._holder.get_child(0)
	assert_gt(col.size.x, 100.0, "la carta se dibuja con ancho útil")


func test_zoom_de_la_mesa_tiene_tamano_y_se_cierra_con_toque() -> void:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.set_view(FakeState.make_view(4, "p1"), "p1")
	await get_tree().process_frame
	var c: Dictionary = FakeState.make_view(4, "p1")["players"][0]["hand"][0]
	t._show_zoom(c, UiUtil.card_def(String(c["card_id"])))
	assert_gt(t._zoom.size.x, 0.0)
	assert_gt(t._zoom.size.y, 0.0)
	assert_true(t._zoom.visible)
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	t._zoom._gui_input(ev)
	assert_false(t._zoom.visible)
