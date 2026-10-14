extends "res://tests/perf/perf_final.gd"
## Coste de dar forma ("reset_size") al texto de los numeros flotantes segun el glifo y la fuente (V2-34).
## Hipotesis medida: el glifo ▼/▲ no esta en la fuente por defecto del motor y cada texto cae a la busqueda de fuente del sistema.
##   godot --path . -s tests/perf/perf_glyph.gd
## Salida: lineas "GLYPH ..." (no "PERF"). Variante B simula una fuente empaquetada con los glifos (DejaVu del sistema, solo para el experimento).

func _run(_args: PackedStringArray) -> void:
	await _frames(5)
	var vp: SubViewport = _new_vp(1080, 1920)
	var host: Control = Control.new()
	host.theme = UiTheme.get_theme()
	vp.add_child(host)
	await _frames(3)
	var texts: Array[String] = ["-3", "▼ -3", "▲ +3", "▼ -3 maná", "Bloqueado"]
	for variant: String in ["A_fuente_por_defecto", "B_fallback_explicito"]:
		var th: Theme = UiTheme.get_theme().duplicate() as Theme
		if variant == "B_fallback_explicito":
			var ff: FontFile = FontFile.new()
			ff.load_dynamic_font("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
			var base_font: Font = host.get_theme_default_font()
			var fv: FontVariation = FontVariation.new()
			fv.base_font = base_font
			fv.fallbacks = [ff]
			th.default_font = fv
		host.theme = th
		await _frames(3)
		for txt: String in texts:
			var ms: Array = []
			for i: int in 12:
				var ft: FloatingText = FloatingText.create()
				host.add_child(ft)
				ft.theme_type_variation = "FloatDamage"
				ft.text = txt + (" " if i % 2 == 0 else "")
				var t0: int = Time.get_ticks_usec()
				ft.size = Vector2.ZERO
				ft.reset_size()
				ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				ft.queue_free()
				await process_frame
			print("GLYPH %s '%s' primero %.2f ms, media del resto %.2f ms" % [variant, txt, ms[0], _mean(ms.slice(1))])
	quit()
