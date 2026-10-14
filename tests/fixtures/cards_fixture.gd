extends RefCounted
## Catálogo de PRUEBA para los tests del motor (T4) mientras data/cards.json
## está vacío. Cantidades de REQUERIMIENTOS.md 2.2 (154 jugables + 11 no
## jugables = 165). Los COSTES son de prueba (no los reales): los tests de T4
## dependen de ellos. El resto de metadatos se toma de data/cards.json.
##
## Uso: CardCatalog.set_defs(CardsFixture.defs())
##   const CardsFixture = preload("res://tests/fixtures/cards_fixture.gd")

const OFF: String = Types.CARD_TYPE_OFFENSIVE
const DEF: String = Types.CARD_TYPE_DEFENSIVE
const SUP: String = Types.CARD_TYPE_SUPPORT
const CUR: String = Types.CARD_TYPE_CURSE
const ART: String = Types.CARD_TYPE_ARTIFACT
const EVT: String = Types.CARD_TYPE_EVENT
const NOP: String = Types.CARD_TYPE_NON_PLAYABLE
const FIRE: String = Types.ELEMENT_FIRE
const ICE: String = Types.ELEMENT_ICE
const ELEC: String = Types.ELEMENT_ELECTRIC
const NONE: String = Types.ELEMENT_NONE

## [id, tipo, elemento, maná, objetivo, cantidad, requisitos de cartas]
static func rows() -> Array:
	var fire_req: Array = [Types.make_card_req(Types.REQ_BY_ELEMENT, FIRE, 1)]
	return [
		[Types.CARD_QUICK_REFERENCE, NOP, NONE, 0, Types.TARGET_NONE, 6, []],
		[Types.CARD_BLANK, NOP, NONE, 0, Types.TARGET_NONE, 4, []],
		[Types.CARD_ANTI_JOKER, NOP, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_FIRE_ARROW, OFF, FIRE, 1, Types.TARGET_SINGLE, 8, []],
		[Types.CARD_FIREBALL, OFF, FIRE, 2, Types.TARGET_SINGLE, 6, []],
		[Types.CARD_METEOR_SHOWER, OFF, FIRE, 3, Types.TARGET_SINGLE, 3, []],
		[Types.CARD_ARMAGEDDON, OFF, FIRE, 5, Types.TARGET_ALL, 1, []],
		[Types.CARD_MANA_IMPLOSION, OFF, FIRE, 3, Types.TARGET_SINGLE, 2, []],
		[Types.CARD_ICE_BOLT, OFF, ICE, 1, Types.TARGET_SINGLE, 6, []],
		[Types.CARD_BLIZZARD, OFF, ICE, 3, Types.TARGET_SINGLE, 3, []],
		[Types.CARD_ICE_BOOMERANG, OFF, ICE, 2, Types.TARGET_SINGLE, 3, []],
		[Types.CARD_VAMPIRIC_TOUCH, OFF, ICE, 2, Types.TARGET_SINGLE, 5, []],
		[Types.CARD_FREEZE, OFF, ICE, 3, Types.TARGET_SINGLE, 2, []],
		[Types.CARD_ICY_GRASP, OFF, ICE, 2, Types.TARGET_OTHER, 2, []],
		[Types.CARD_LIGHTNING, OFF, ELEC, 2, Types.TARGET_SINGLE, 10, []],
		[Types.CARD_ELECTRIC_EXPLOSION, OFF, ELEC, 2, Types.TARGET_ALL_OTHERS, 3, fire_req],
		[Types.CARD_BLINDING_FLASH, OFF, ELEC, 2, Types.TARGET_SINGLE, 2, []],
		[Types.CARD_ELECTRIC_ARC, OFF, ELEC, 2, Types.TARGET_TWO, 5, []],
		[Types.CARD_PARALYSING_TOUCH, OFF, ELEC, 3, Types.TARGET_SINGLE, 2, []],
		[Types.CARD_MAGIC_SHIELD, DEF, NONE, 1, Types.TARGET_NONE, 11, []],
		[Types.CARD_MIRROR_SHIELD, DEF, NONE, 2, Types.TARGET_NONE, 5, []],
		[Types.CARD_FROZEN_BUNNY, DEF, NONE, 3, Types.TARGET_NONE, 1, []],
		[Types.CARD_LAST_WISH, DEF, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_MAGIC_CAPTURE, DEF, NONE, 1, Types.TARGET_NONE, 3, []],
		[Types.CARD_ANNIHILATION, DEF, NONE, 2, Types.TARGET_CARD_IN_PLAY, 2, []],
		[Types.CARD_HEAL, SUP, NONE, 1, Types.TARGET_SINGLE, 10, []],
		[Types.CARD_GREATER_HEAL, SUP, NONE, 2, Types.TARGET_SINGLE, 4, []],
		[Types.CARD_BOOK_EXCHANGE, SUP, NONE, 2, Types.TARGET_OTHER, 2, []],
		[Types.CARD_MAGIC_HAND, SUP, NONE, 2, Types.TARGET_OTHER, 2, []],
		[Types.CARD_FORCE_FIELD, SUP, NONE, 3, Types.TARGET_SINGLE, 3, []],
		[Types.CARD_POTENT_ELIXIR, SUP, NONE, 1, Types.TARGET_NONE, 4, []],
		[Types.CARD_SPACE_SHIFT, SUP, NONE, 1, Types.TARGET_NONE, 2, []],
		[Types.CARD_CURSE_OF_RULES, CUR, NONE, 1, Types.TARGET_NONE, 3, []],
		[Types.CARD_CURSE_OF_THE_ELDER, CUR, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_CURSE_OF_THE_YOUNGER, CUR, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_CURSE_OF_VIGOUR, CUR, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_CURSE_OF_EVEN, CUR, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_CURSE_OF_ODD, CUR, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_FIREPROOF_TIARA, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_PADDED_BOOTS, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_FARADAYS_CLOAK, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_WILD_FIRE, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_DRAGON_GLASS, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_TESLA_COIL, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_SPELLBOOK, ART, NONE, 2, Types.TARGET_NONE, 3, []],
		[Types.CARD_MAGIC_CAP, ART, NONE, 2, Types.TARGET_NONE, 3, []],
		[Types.CARD_RUNIC_ARMOR, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_SCROLL_OF_ELEMENTS, ART, NONE, 1, Types.TARGET_NONE, 7, []],
		[Types.CARD_TRANSFORMATION_GLOVE, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_TWARDOWSKYS_MIRROR, ART, NONE, 2, Types.TARGET_NONE, 1, []],
		[Types.CARD_VISIT_OF_THE_ARCHMAGE, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_NOT_ENOUGH_MANA, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_SHOT_GLASS, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_FIRE_STORM, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_ICE_STORM, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_LIGHTNING_STORM, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_MANA_FOCUS, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_DISRUPTED_GRAVITY, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_BLESSING, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_WARP_DISCHARGE, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
		[Types.CARD_ELIXIR_TRANSMUTATION, EVT, NONE, 0, Types.TARGET_NONE, 1, []],
	]


## Definiciones del catálogo de prueba. Los METADATOS (objetivo, flags
## is_spell/persistent/defensive, elemento…) se copian de data/cards.json
## cuando existe, porque los efectos reales registrados confían en ellos (p. ej.
## Magic Shield lee targets[0]); solo el COSTE y la cantidad salen de rows().
static func defs() -> Array:
	var real: Dictionary = real_defs()
	var out: Array = []
	for r: Variant in rows():
		var row: Array = r
		var id: String = row[0]
		var d: Dictionary
		if real.has(id):
			d = (real[id] as Dictionary).duplicate(true)
		else:
			d = Types.make_card_def(id, id.capitalize(), String(row[1]), String(row[2]), 0, [],
				String(row[4]), int(row[5]))
			if id == Types.CARD_CURSE_OF_RULES:
				d["persistent"] = true
		d["cost"] = {"mana": int(row[3]), "cards": (row[6] as Array).duplicate(true)}
		d["quantity"] = int(row[5])
		d["notes"] = "fixture T4"
		out.append(d)
	return out


## Definiciones de data/cards.json (id -> def) o {} si no existe o está vacío.
static func real_defs() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(CardCatalog.DEFAULT_PATH):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CardCatalog.DEFAULT_PATH))
	if not (parsed is Array):
		return out
	for raw: Variant in (parsed as Array):
		var d: Dictionary = CardCatalog.from_json(raw)
		out[String(d["id"])] = d
	return out


## Catálogo mínimo a medida: cada elemento es [id, tipo, cantidad] o una def completa.
static func small(entries: Array) -> Array:
	var out: Array = []
	for e: Variant in entries:
		if e is Dictionary:
			out.append(e)
			continue
		var row: Array = e
		out.append(Types.make_card_def(String(row[0]), String(row[0]), String(row[1]), Types.ELEMENT_NONE,
			0, [], Types.TARGET_NONE, int(row[2])))
	return out
