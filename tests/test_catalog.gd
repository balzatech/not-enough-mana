extends NemTest
## Auditoría del catálogo real (data/cards.json). T7.
## 61 diseños (58 jugables + quick_reference, blank y anti_joker), 165 cartas, 154 jugables.

const NON_PLAYABLE_IDS: Array[String] = ["quick_reference", "blank", "anti_joker"]

var _raw: Array = []


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	assert_true(parsed is Array, "cards.json es un Array")
	_raw = parsed if parsed is Array else []


func after_all() -> void:
	CardCatalog.load_json()


func test_design_count() -> void:
	assert_eq(_raw.size(), 61, "61 diseños")


func test_quantities() -> void:
	var total: int = 0
	var playable: int = 0
	var playable_designs: int = 0
	for r: Variant in _raw:
		var d: Dictionary = r
		total += int(d["quantity"])
		if d["playable"]:
			playable += int(d["quantity"])
			playable_designs += 1
	assert_eq(total, 165, "165 cartas en total")
	assert_eq(playable, 154, "154 jugables")
	assert_eq(playable_designs, 58, "58 diseños jugables")


func test_non_playable_set() -> void:
	var ids: Array[String] = []
	for r: Variant in _raw:
		var d: Dictionary = r
		if not d["playable"]:
			ids.append(String(d["id"]))
	ids.sort()
	var expected: Array[String] = NON_PLAYABLE_IDS.duplicate()
	expected.sort()
	assert_eq(ids, expected, "solo quick_reference, blank y anti_joker no son jugables")


func test_unique_ids() -> void:
	var seen: Dictionary = {}
	for r: Variant in _raw:
		var id: String = String((r as Dictionary)["id"])
		assert_false(seen.has(id), "id duplicado: %s" % id)
		seen[id] = true
	assert_eq(seen.size(), 61)


func test_pages_cover_1_to_165_without_overlap() -> void:
	var owner_of: Dictionary = {}
	for r: Variant in _raw:
		var d: Dictionary = r
		var pages: Array = d["pages"]
		assert_eq(pages.size(), int(d["quantity"]), "%s: quantity == nº de páginas" % d["id"])
		for p: Variant in pages:
			var n: int = int(p)
			assert_false(owner_of.has(n), "página %d solapada (%s / %s)" % [n, owner_of.get(n, ""), d["id"]])
			owner_of[n] = d["id"]
	for n: int in range(1, 166):
		assert_true(owner_of.has(n), "falta la página %d" % n)
		assert_true(FileAccess.file_exists("res://assets/cards/%03d.webp" % n), "falta la imagen %03d.webp" % n)
	assert_eq(owner_of.size(), 165)


func test_each_entry_valid() -> void:
	var errs: Array[String] = CardCatalog.load_json()
	assert_eq(errs, [] as Array[String], "validate_card_def sin errores")
	for r: Variant in _raw:
		var d: Dictionary = CardCatalog.get_def(String((r as Dictionary)["id"]))
		assert_false(d.is_empty(), "def cargada: %s" % (r as Dictionary)["id"])
		assert_eq(Types.validate_card_def(d), [] as Array[String], "válida: %s" % d.get("id", ""))


func test_entries_match_make_card_def_shape() -> void:
	for r: Variant in _raw:
		var d: Dictionary = CardCatalog.from_json(r)
		var ref: Dictionary = Types.make_card_def(String(d["id"]), String(d["name"]), String(d["type"]))
		for k: String in ref.keys():
			assert_true(d.has(k), "%s: falta clave %s" % [d["id"], k])


func test_flags_consistent_with_type() -> void:
	for r: Variant in _raw:
		var d: Dictionary = r
		var t: String = String(d["type"])
		assert_eq(bool(d["playable"]), t != "non_playable", "%s: playable vs type" % d["id"])
		assert_eq(bool(d["defensive"]), t == "defensive", "%s: defensive vs type" % d["id"])
		assert_eq(bool(d["is_spell"]), t in ["offensive", "support", "curse"], "%s: is_spell vs type" % d["id"])


func test_ids_are_known_constants() -> void:
	var consts: Dictionary = {}
	var script: Script = load("res://src/engine/types.gd")
	var cmap: Dictionary = script.get_script_constant_map()
	for k: Variant in cmap:
		if String(k).begins_with("CARD_") and cmap[k] is String:
			consts[cmap[k]] = true
	for r: Variant in _raw:
		var d: Dictionary = r
		if d["playable"]:
			assert_true(consts.has(d["id"]), "%s sin constante CARD_* en types.gd" % d["id"])
