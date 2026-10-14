class_name FakeState
extends RefCounted
## Datos de prueba para la UI (data/cards.json puede estar vacío): definiciones de
## carta propias y estados completos con 2-6 jugadores. Solo para maquetas/tests.

const NAMES: Array[String] = ["Aldric", "Brisa", "Cael", "Dagna", "Elric", "Fenna"]
const AGES: Array[int] = [34, 28, 41, 19, 52, 23]

static var _next_iid: int = 1


static func _def(id: String, name: String, type: String, element: String, mana: int,
		text: String, target: String = Types.TARGET_NONE, reqs: Array = []) -> Dictionary:
	var d: Dictionary = Types.make_card_def(id, name, type, element, mana, reqs, target)
	d["text"] = text
	return d


## Definiciones de prueba (id -> def). Sin páginas: siempre placeholder.
static func defs() -> Dictionary:
	var list: Array[Dictionary] = [
		_def(Types.CARD_FIRE_ARROW, "Fire Arrow", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_FIRE, 1,
			"Deal 1 fire damage to a wizard.", Types.TARGET_SINGLE),
		_def(Types.CARD_FIREBALL, "Fireball", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_FIRE, 3,
			"Deal 3 fire damage to a wizard.", Types.TARGET_SINGLE),
		_def(Types.CARD_ARMAGEDDON, "Armageddon", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_FIRE, 5,
			"Deal 2 fire damage to all wizards.", Types.TARGET_ALL),
		_def(Types.CARD_ICE_BOLT, "Ice Bolt", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_ICE, 2,
			"Deal 2 ice damage to a wizard.", Types.TARGET_SINGLE),
		_def(Types.CARD_FREEZE, "Freeze", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_ICE, 4,
			"A wizard skips their next turn.", Types.TARGET_SINGLE),
		_def(Types.CARD_LIGHTNING, "Lightning", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_ELECTRIC, 2,
			"Deal 2 electric damage to a wizard.", Types.TARGET_SINGLE),
		_def(Types.CARD_ELECTRIC_ARC, "Electric Arc", Types.CARD_TYPE_OFFENSIVE, Types.ELEMENT_ELECTRIC, 3,
			"Deal 1 electric damage to two wizards.", Types.TARGET_TWO),
		_def(Types.CARD_MAGIC_SHIELD, "Magic Shield", Types.CARD_TYPE_DEFENSIVE, Types.ELEMENT_NONE, 1,
			"Prevent up to 2 damage from a spell."),
		_def(Types.CARD_MIRROR_SHIELD, "Mirror Shield", Types.CARD_TYPE_DEFENSIVE, Types.ELEMENT_NONE, 2,
			"Redirect up to 2 damage to another wizard."),
		_def(Types.CARD_HEAL, "Heal", Types.CARD_TYPE_SUPPORT, Types.ELEMENT_NONE, 2,
			"Restore 2 health.", Types.TARGET_SINGLE),
		_def(Types.CARD_BOOK_EXCHANGE, "Book Exchange", Types.CARD_TYPE_SUPPORT, Types.ELEMENT_NONE, 1,
			"Swap hands with another wizard. Discard a card.", Types.TARGET_OTHER,
			[Types.make_card_req(Types.REQ_ANY, "", 1)]),
		_def(Types.CARD_CURSE_OF_RULES, "Curse of Rules", Types.CARD_TYPE_CURSE, Types.ELEMENT_NONE, 2,
			"Name a rule. Whoever breaks it loses 1 mana.", Types.TARGET_SINGLE),
		_def(Types.CARD_CURSE_OF_EVEN, "Curse of Even", Types.CARD_TYPE_CURSE, Types.ELEMENT_NONE, 2,
			"Even birth months take 1 extra damage.", Types.TARGET_SINGLE),
		_def(Types.CARD_FIREPROOF_TIARA, "Fireproof Tiara", Types.CARD_TYPE_ARTIFACT, Types.ELEMENT_NONE, 2,
			"Take 1 less fire damage."),
		_def(Types.CARD_WILD_FIRE, "Wild Fire", Types.CARD_TYPE_ARTIFACT, Types.ELEMENT_NONE, 3,
			"Your fire spells deal 1 more damage."),
		_def(Types.CARD_SPELLBOOK, "Spellbook", Types.CARD_TYPE_ARTIFACT, Types.ELEMENT_NONE, 2,
			"Your hand limit is 1 higher."),
		_def(Types.CARD_FIRE_STORM, "Fire Storm", Types.CARD_TYPE_EVENT, Types.ELEMENT_FIRE, 0,
			"Until the next event, fire spells cost and deal 1 more."),
		_def(Types.CARD_BLESSING, "Blessing", Types.CARD_TYPE_EVENT, Types.ELEMENT_NONE, 0,
			"Every wizard restores 1 health."),
	]
	var out: Dictionary = {}
	for d: Dictionary in list:
		out[String(d["id"])] = d
	return out


## Registra las definiciones de prueba en UiUtil (sin tocar el CardCatalog).
static func install_defs() -> void:
	UiUtil.extra_defs = defs()


static func _card(card_id: String) -> Dictionary:
	var c: Dictionary = Types.make_card_instance(_next_iid, card_id)
	_next_iid += 1
	return c


static func _table_card(card_id: String, owner: String, data: Dictionary = {}) -> Dictionary:
	var iid: int = _next_iid
	_next_iid += 1
	return Types.make_table_card(iid, card_id, owner, data)


## Estado completo de prueba con n jugadores (2-6). Turno del primero.
static func make_state(n: int = 4) -> Dictionary:
	install_defs()
	_next_iid = 1
	n = clampi(n, 2, 6)
	var s: Dictionary = Types.make_state({}, 7)
	var hand_ids: Array[String] = [
		Types.CARD_FIREBALL, Types.CARD_MAGIC_SHIELD, Types.CARD_HEAL, Types.CARD_BOOK_EXCHANGE,
		Types.CARD_WILD_FIRE, Types.CARD_CURSE_OF_RULES, Types.CARD_ICE_BOLT]
	for i: int in n:
		var p: Dictionary = Types.make_player("p%d" % (i + 1), NAMES[i], AGES[i], 1 + i * 2, i >= 3)
		p["hp"] = clampi(10 - i * 2, 3, 10)
		p["mana"] = 1 + (i * 2) % 7
		p["potions"] = i
		var hand: Array = []
		for k: int in (7 if i == 0 else 5 - (i % 2)):
			hand.append(_card(hand_ids[(k + i) % hand_ids.size()]))
		p["hand"] = hand
		(s["players"] as Array).append(p)
	var p2: Dictionary = (s["players"] as Array)[1]
	(p2["artifacts"] as Array).append(_table_card(Types.CARD_FIREPROOF_TIARA, "p2"))
	(p2["artifacts"] as Array).append(_table_card(Types.CARD_SPELLBOOK, "p2"))
	var p1: Dictionary = (s["players"] as Array)[0]
	(p1["artifacts"] as Array).append(_table_card(Types.CARD_WILD_FIRE, "p1"))
	(p1["curses"] as Array).append(_table_card(Types.CARD_CURSE_OF_RULES, "p1", {"rule": "No decir 'sí'"}))
	if n >= 3:
		var p3: Dictionary = (s["players"] as Array)[2]
		(p3["curses"] as Array).append(_table_card(Types.CARD_CURSE_OF_EVEN, "p3"))
		(p3["flags"] as Dictionary)["frozen"] = 1
	if n >= 5:
		var p5: Dictionary = (s["players"] as Array)[4]
		p5["eliminated"] = true
		p5["hp"] = 0
		p5["eliminated_reason"] = Types.ELIM_HP
	if n >= 6:
		var p6: Dictionary = (s["players"] as Array)[5]
		p6["connected"] = false
	var deck: Array = []
	for k: int in 30:
		deck.append(_card(hand_ids[k % hand_ids.size()]))
	s["deck"] = deck
	s["discard"] = [_card(Types.CARD_FIRE_ARROW), _card(Types.CARD_LIGHTNING)]
	s["active_event"] = _table_card(Types.CARD_FIRE_STORM, "")
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = {"number": 3, "current": "p1", "phase": Types.PHASE_MAIN, "exchanges": 0}
	s["rev"] = 12
	s["card_total"] = Types.all_card_iids(s).size()
	s["log"] = [
		Types.make_log_entry(Types.LOG_GAME_STARTED, 0),
		Types.make_log_entry(Types.LOG_TURN_STARTED, 1, "p1"),
		Types.make_log_entry(Types.LOG_CARD_PLAYED, 1, "p1", {"card_id": Types.CARD_FIREBALL, "target": "p2"}),
		Types.make_log_entry(Types.LOG_DAMAGE, 1, "p1", {"target": "p2", "amount": 3}),
		Types.make_log_entry(Types.LOG_POTION, 2, "p3"),
		Types.make_log_entry(Types.LOG_EVENT_DRAWN, 3, "", {"card_id": Types.CARD_FIRE_STORM}),
		Types.make_log_entry(Types.LOG_TURN_STARTED, 3, "p1"),
	]
	return s


## Vista (formato Types.view_for) de pid sobre un estado de prueba.
static func make_view(n: int = 4, pid: String = "p1") -> Dictionary:
	return Types.view_for(make_state(n), pid)


## Añade una ventana de reacción: p2 lanza Fireball contra p1; p1 debe decidir.
static func with_reaction(state: Dictionary, deadline_ms: int = 0) -> Dictionary:
	var spell: Dictionary = Types.make_spell(_card(Types.CARD_FIREBALL), "p2", ["p1"])
	var r: Dictionary = Types.make_reaction(spell, ["p1"])
	r["deadline_ms"] = deadline_ms
	state["reaction"] = r
	state["card_total"] = Types.all_card_iids(state).size()
	return state
