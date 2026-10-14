extends GutTest
## Registro de efectos y catálogo (contrato T1).


static func _fake_effect(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var p: Dictionary = Types.get_player(state, String((ctx["targets"] as Array)[0]))
	p["hp"] = int(p["hp"]) - 1
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_DAMAGE, 1, String(ctx["caster"]), {"amount": 1}))
	return state


func before_each() -> void:
	EffectRegistry.reset()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func test_register_and_call_static_func() -> void:
	assert_false(EffectRegistry.get_effect("fake").is_valid())
	EffectRegistry.register("fake", _fake_effect)
	assert_true(EffectRegistry.has_effect("fake"))
	var s: Dictionary = Types.make_state()
	(s["players"] as Array).append(Types.make_player("a", "A"))
	var ctx: Dictionary = Types.make_effect_ctx(Types.make_card_instance(1, "fake"), {}, "a", ["a"])
	var out: Dictionary = EffectRegistry.get_effect("fake").call(s, ctx)
	assert_eq(Types.get_player(out, "a")["hp"], 9)
	assert_eq((ctx["events"] as Array).size(), 1)
	assert_eq(ctx["error"], Types.ERR_NONE)


func test_hooks() -> void:
	EffectRegistry.register_hook(Types.HOOK_USE, "fake", _fake_effect)
	assert_true(EffectRegistry.get_hook(Types.HOOK_USE, "fake").is_valid())
	assert_false(EffectRegistry.get_hook(Types.HOOK_EVENT_END, "fake").is_valid())
	EffectRegistry.reset()
	assert_false(EffectRegistry.get_hook(Types.HOOK_USE, "fake").is_valid())


func test_catalog_set_defs_normalizes() -> void:
	var raw: Array = JSON.parse_string(JSON.stringify([
		{"id": "fireball", "name": "Fireball", "type": "offensive", "element": "fire",
		 "cost": {"mana": 2}, "target": "single", "quantity": 6, "pages": [19, 20]},
	]))
	var errs: Array[String] = CardCatalog.set_defs(raw)
	assert_eq(errs, [] as Array[String])
	var d: Dictionary = CardCatalog.get_def("fireball")
	assert_eq(typeof(d["quantity"]), TYPE_INT)
	assert_eq((d["cost"] as Dictionary)["cards"], [])
	assert_true(CardCatalog.get_def("nope").is_empty())


func test_catalog_loads_project_json() -> void:
	assert_eq(CardCatalog.load_json(), [] as Array[String], "data/cards.json válido")


func test_static_func_of_other_class_as_callable() -> void:
	# Patrón que usarán las líneas de registry.gd: ClaseEfectos.funcion
	var c: Callable = Rng.seed_from
	assert_true(c.is_valid())
	assert_eq(c.call(-1), 4294967295)
