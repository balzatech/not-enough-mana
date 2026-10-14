extends GutTest
## Cobertura de efectos: cada id jugable del catálogo debe tener efecto en registry.gd.
## Puede fallar mientras los agentes de efectos no hayan terminado.


func after_all() -> void:
	CardCatalog.load_json()


func test_catalog_effects_registered() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var missing: Array[String] = []
	for id: Variant in CardCatalog.all_defs():
		var d: Dictionary = CardCatalog.get_def(String(id))
		if d["playable"] and not EffectRegistry.has_effect(String(id)):
			missing.append(String(id))
	missing.sort()
	assert_eq(missing, [] as Array[String], "ids jugables sin efecto: %s" % str(missing))
