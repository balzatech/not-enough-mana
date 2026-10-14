class_name CardCatalog
extends RefCounted
## Catálogo de definiciones de carta (data/cards.json, lo rellena T3).
##
## Formato de data/cards.json: Array de objetos con las claves de
## Types.make_card_def(). Las claves que falten se completan con sus valores
## por defecto y los números se normalizan a int.
##
## Es un dato estático de solo lectura, por eso se cachea en una variable
## estática (no forma parte del estado de la partida).

const DEFAULT_PATH: String = "res://data/cards.json"

static var _defs: Dictionary = {}   # card_id -> card_def
static var _loaded: bool = false


## Carga el catálogo desde un archivo JSON. Devuelve los errores ([] = ok).
static func load_json(path: String = DEFAULT_PATH) -> Array[String]:
	var errs: Array[String] = []
	if not FileAccess.file_exists(path):
		errs.append("no existe %s" % path)
		return errs
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		errs.append("%s no es un Array JSON" % path)
		return errs
	return set_defs(parsed as Array)


## Sustituye el catálogo por estas definiciones (también para tests con cartas
## de prueba). Devuelve los errores de validación ([] = ok).
static func set_defs(defs: Array) -> Array[String]:
	var errs: Array[String] = []
	_defs.clear()
	for raw: Variant in defs:
		var d: Dictionary = from_json(raw)
		errs.append_array(Types.validate_card_def(d))
		_defs[d["id"]] = d
	_loaded = true
	return errs


## Normaliza una definición leída de JSON (floats -> int, claves por defecto).
static func from_json(raw: Variant) -> Dictionary:
	var src: Dictionary = Types.normalize_value(raw) if raw is Dictionary else {}
	var d: Dictionary = Types.make_card_def(String(src.get("id", "")), String(src.get("name", "")),
		String(src.get("type", Types.CARD_TYPE_NON_PLAYABLE)))
	for k: Variant in src:
		d[k] = src[k]
	var cost: Dictionary = d["cost"] if d["cost"] is Dictionary else {}
	if not cost.has("mana"):
		cost["mana"] = 0
	if not cost.has("cards"):
		cost["cards"] = []
	d["cost"] = cost
	return d


## Definición de una carta, o {} si no existe. Carga el JSON por defecto la
## primera vez si nadie llamó a load_json/set_defs.
static func get_def(card_id: String) -> Dictionary:
	_ensure_loaded()
	return _defs.get(card_id, {})


static func has_def(card_id: String) -> bool:
	_ensure_loaded()
	return _defs.has(card_id)


## Todas las definiciones (copia superficial del diccionario id -> def).
static func all_defs() -> Dictionary:
	_ensure_loaded()
	return _defs.duplicate()


static func is_loaded() -> bool:
	return _loaded


static func _ensure_loaded() -> void:
	if not _loaded:
		load_json()
		_loaded = true
