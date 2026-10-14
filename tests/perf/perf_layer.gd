extends "res://tests/perf/perf_final.gd"
## Desglose de FeedbackLayer.play (V2-34): coste de cada paso y del primer uso frente al uso con pool caliente.
##   godot --path . -s tests/perf/perf_layer.gd -- 3 1080 1920 real 1 11
## Salida "PERF {json}" con mode="layer".

func _run(args: PackedStringArray) -> void:
	_np = int(args[0]) if args.size() > 0 else 3
	var w: int = int(args[1]) if args.size() > 1 else 1080
	var h: int = int(args[2]) if args.size() > 2 else 1920
	_sd = 11
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Dictionary = {"players": _np, "w": w, "h": h, "mode": "layer", "seed": _sd}
	await _load_textures(out)
	var vp: SubViewport = _new_vp(w, h)
	await _frames(3)
	_make_table(vp, false, out)
	_ls.auto_run_bots = false
	_ls.cancel_bot()
	await _frames(30)
	var layer: FeedbackLayer = _t.feedback().layer
	var pid: String = "p2"
	var kinds: Array = [FeedbackMapper.FB_DAMAGE, FeedbackMapper.FB_HEAL, FeedbackMapper.FB_MANA, FeedbackMapper.FB_POTION]
	var calls: Array = []
	# 40 llamadas separadas por fotogramas; los numeros se terminan al cabo de ~1 s (pool).
	for i: int in 40:
		var item: Dictionary = {"kind": kinds[i % kinds.size()], "target": pid, "amount": -(i % 5) - 1, "duration_ms": 1000,
			"extra": {}, "log_seq": i + 1000}
		if i % kinds.size() == 1 or i % kinds.size() == 3:
			item["amount"] = (i % 5) + 1
		var t0: int = Time.get_ticks_usec()
		layer.play(item)
		var t1: int = Time.get_ticks_usec()
		await process_frame
		var t2: int = Time.get_ticks_usec()
		calls.append([String(item["kind"]), snappedf((t1 - t0) / 1000.0, 0.01), snappedf((t2 - t1) / 1000.0, 0.01)])
		await _frames(2)
	out["calls"] = calls
	# Banner de carta jugada.
	var bn: Array = []
	for i: int in 6:
		var item2: Dictionary = {"kind": FeedbackMapper.FB_CARD_PLAYED, "actor": "p2", "card_id": "fireball", "targets": ["p1"],
			"amount": 0, "duration_ms": 1000, "extra": {"caster": "p2"}, "log_seq": 2000 + i}
		var t0: int = Time.get_ticks_usec()
		layer.play(item2)
		bn.append(snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.01))
		await _frames(3)
	out["banner_calls"] = bn
	# Piezas aisladas (sin pool): creacion de FloatingText y del material de destello.
	var cr: Array = []
	var mats: Array = []
	for i: int in 10:
		var t0: int = Time.get_ticks_usec()
		var ft: FloatingText = FloatingText.create()
		cr.append((Time.get_ticks_usec() - t0) / 1000.0)
		layer.add_child(ft)
		var t1: int = Time.get_ticks_usec()
		ft.play("▼ -%d" % (i + 1), true, Vector2(300, 600), 1000)
		mats.append((Time.get_ticks_usec() - t1) / 1000.0)
		await process_frame
	out["floating_create_ms"] = _mean(cr)
	out["floating_play_newnode_ms"] = _mean(mats)
	out["floating_play_newnode_first_ms"] = float(mats[0])
	# Pasos de FloatingText.play medidos por separado (nodo nuevo cada vez, mismos pasos que play()).
	var steps: Dictionary = {"variation": [], "color": [], "text": [], "reset_size": [], "material": [], "tween": []}
	for i: int in 12:
		var ft2: FloatingText = FloatingText.create()
		layer.add_child(ft2)
		var a0: int = Time.get_ticks_usec()
		ft2.theme_type_variation = "FloatDamage"
		var a1: int = Time.get_ticks_usec()
		ft2.remove_theme_color_override("font_color")
		var a2: int = Time.get_ticks_usec()
		ft2.text = "▼ -%d" % (i + 1)
		var a3: int = Time.get_ticks_usec()
		ft2.size = Vector2.ZERO
		ft2.reset_size()
		var a4: int = Time.get_ticks_usec()
		ft2._mat.set_shader_parameter("fade", 1.0)
		ft2.visible = true
		var a5: int = Time.get_ticks_usec()
		var tw: Tween = ft2.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ft2, "position:y", 100.0, 1.0)
		tw.tween_method(ft2._set_fade, 1.0, 0.0, 0.35).set_delay(0.65)
		var a6: int = Time.get_ticks_usec()
		(steps["variation"] as Array).append((a1 - a0) / 1000.0)
		(steps["color"] as Array).append((a2 - a1) / 1000.0)
		(steps["text"] as Array).append((a3 - a2) / 1000.0)
		(steps["reset_size"] as Array).append((a4 - a3) / 1000.0)
		(steps["material"] as Array).append((a5 - a4) / 1000.0)
		(steps["tween"] as Array).append((a6 - a5) / 1000.0)
		await process_frame
	var so: Dictionary = {}
	for k: String in steps:
		so[k] = [snappedf(float((steps[k] as Array)[0]), 0.001), snappedf(_mean((steps[k] as Array).slice(1)), 0.001)]
	out["play_steps_first_and_mean_ms"] = so
	print("PERF " + JSON.stringify(out))
	quit()
