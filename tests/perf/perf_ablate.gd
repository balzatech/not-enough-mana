extends "res://tests/perf/perf_final.gd"
## Ablacion (V2-34): igual que perf_final.gd pero oculta (visible=false) una parte de la mesa tras montarla.
## Un subarbol oculto no se maqueta ni se dibuja, pero refresh() sigue haciendo su trabajo de nodos; la diferencia del
## fotograma con accion contra la ejecucion sin ocultar es el coste de maquetacion/dibujo diferido de esa parte.
##   godot --path . -s tests/perf/perf_ablate.gd -- <jug> <ancho> <alto> <real|stress> <seg> <semilla> <parte>
## parte: none | hand | log | rivals | center | own | all  (all = las cinco)
## Salida: "PERF {json}" con el campo extra "ablate".

var _part: String = "none"


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_part = a[6] if a.size() > 6 else "none"
	super()


func _make_table(vp: SubViewport, stress: bool, out: Dictionary) -> void:
	super(vp, stress, out)
	out["ablate"] = _part
	var targets: Dictionary = {
		"hand": _t.ctx.hand.hand_view, "log": _t._log, "rivals": _t.ctx.players.rival_fan,
		"center": _t.ctx.center.center, "own": _t.ctx.players.own_panel}
	for k: String in targets:
		if _part == k or _part == "all":
			(targets[k] as Control).visible = false
