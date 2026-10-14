class_name BotEval
extends RefCounted
## Evaluación de cartas y jugadas para el bot (T9). Funciones puras sobre una
## VISTA del jugador (Types.view_for): solo leen información pública y la mano
## propia. Los datos de las cartas salen de CardCatalog (tipo, elemento,
## objetivo y texto de data/cards.json), no de los internos de los efectos.

const DEFENSIVE_IDS: Array[String] = [
	Types.CARD_MAGIC_SHIELD, Types.CARD_MIRROR_SHIELD, Types.CARD_FROZEN_BUNNY,
	Types.CARD_LAST_WISH, Types.CARD_ANNIHILATION,
]

## Solo se cura por debajo de esta vida (evita deshacer el daño de la partida).
const HEAL_BELOW_HP: int = 4

static var _rx_cache: Dictionary = {}


static func _rx(pattern: String) -> RegEx:
	if not _rx_cache.has(pattern):
		var r: RegEx = RegEx.new()
		r.compile(pattern)
		_rx_cache[pattern] = r
	return _rx_cache[pattern]


static func _first_int(text: String, pattern: String) -> int:
	var m: RegExMatch = _rx(pattern).search(text)
	if m == null:
		return 0
	return m.get_string(1).to_int()


# -----------------------------------------------------------------------------
# Lectura de datos
# -----------------------------------------------------------------------------

static func max_hp(view: Dictionary) -> int:
	return int((view["config"] as Dictionary).get("max_hp", 10))


static func player_of(view: Dictionary, pid: String) -> Dictionary:
	return Types.get_player(view, pid)


static func hand_count(p: Dictionary) -> int:
	return int(p.get("hand_count", (p.get("hand", []) as Array).size()))


static func has_artifact(p: Dictionary, card_id: String) -> bool:
	for c: Variant in p.get("artifacts", []) as Array:
		if String((c as Dictionary).get("card_id", "")) == card_id:
			return true
	return false


## Inmune a hechizos (Force Field) o a maldiciones (Runic Armor).
static func is_immune(p: Dictionary, def: Dictionary) -> bool:
	if not bool(def.get("is_spell", false)):
		return false
	if String((p.get("flags", {}) as Dictionary).get("force_field", "")) != "":
		return true
	return String(def.get("type", "")) == Types.CARD_TYPE_CURSE and has_artifact(p, Types.CARD_RUNIC_ARMOR)


## Cuánto amenaza un rival (más maná, más cartas y más artefactos = peor).
static func threat(p: Dictionary) -> float:
	return float(int(p.get("mana", 0))) * 0.3 + float(hand_count(p)) * 0.2 \
		+ float((p.get("artifacts", []) as Array).size()) * 0.7


## Instancia de la mano de `p` con ese iid ({} si no está).
static func hand_card(p: Dictionary, iid: int) -> Dictionary:
	for c: Variant in p.get("hand", []) as Array:
		if int((c as Dictionary).get("iid", -1)) == iid:
			return c
	return {}


# -----------------------------------------------------------------------------
# Perfil del texto de una carta ofensiva
# -----------------------------------------------------------------------------

## Números extraídos del texto de la carta: dmg (vida al objetivo), neighbor
## (vida a los vecinos del objetivo), caster_loss, caster_gain, mana_loss
## (maná que pierde el objetivo), discard (cartas que descarta el objetivo).
static func profile(def: Dictionary) -> Dictionary:
	var text: String = String(def.get("text", ""))
	var life: Array[int] = []
	for m: RegExMatch in _rx("lose[s]? (\\d+)\\{life\\}").search_all(text):
		life.append(m.get_string(1).to_int())
	var dmg: int = life[0] if not life.is_empty() else 0
	var neighbor: int = 0
	if text.contains("next to the target"):
		neighbor = life[1] if life.size() > 1 else dmg
	return {
		"dmg": dmg,
		"neighbor": neighbor,
		"caster_loss": _first_int(text, "caster loses (\\d+)\\{life\\}"),
		"caster_gain": _first_int(text, "caster gains (\\d+)\\{life\\}"),
		"mana_loss": _first_int(text, "and (\\d+)\\{mana\\}"),
		"discard": _first_int(text, "discard (\\d+) card"),
	}


## Daño estimado que `victim` recibiría del hechizo `def` lanzado por `source`,
## aplicando los modificadores públicos (tormentas, artefactos, inmunidades).
static func est_damage(view: Dictionary, def: Dictionary, source: String, victim: String, base: int) -> int:
	var vp: Dictionary = player_of(view, victim)
	if vp.is_empty() or is_immune(vp, def):
		return 0
	var amount: int = base
	var element: String = String(def.get("element", Types.ELEMENT_NONE))
	for m: Variant in view.get("modifiers", []) as Array:
		var md: Dictionary = m
		var stage: String = String(md.get("stage", ""))
		if stage != Types.STAGE_OUTGOING and stage != Types.STAGE_INCOMING:
			continue
		var me_el: String = String(md.get("element", ""))
		if me_el != "" and me_el != element:
			continue
		var side: String = String(md.get("side", Types.SIDE_ANY))
		var owner_id: String = String(md.get("owner", ""))
		var applies: bool = false
		if stage == Types.STAGE_OUTGOING:
			applies = side == Types.SIDE_ANY or (side == Types.SIDE_SOURCE and owner_id == source)
		else:
			applies = side == Types.SIDE_ANY or (side == Types.SIDE_TARGET and owner_id == victim)
		if not applies:
			continue
		var v: int = int(md.get("value", 0))
		match String(md.get("op", "")):
			Types.OP_ADD:
				amount += v
			Types.OP_SUB:
				amount = maxi(0, amount - v)
	return maxi(0, amount)


## Afectados por un hechizo ofensivo: Array de {pid, dmg}.
static func affected(view: Dictionary, def: Dictionary, caster: String, targets: Array) -> Array:
	var prof: Dictionary = profile(def)
	var out: Array = []
	var seen: Dictionary = {}
	var alive: Array[String] = Types.alive_ids(view)
	var dmg: int = int(prof["dmg"])
	match String(def.get("target", Types.TARGET_NONE)):
		Types.TARGET_SINGLE, Types.TARGET_OTHER, Types.TARGET_TWO:
			for t: Variant in targets:
				var tid: String = String(t)
				if not seen.has(tid):
					seen[tid] = true
					out.append({"pid": tid, "dmg": est_damage(view, def, caster, tid, dmg)})
			if int(prof["neighbor"]) > 0:
				for t: Variant in targets:
					for n: String in Types.neighbors(view, String(t)):
						if not seen.has(n):
							seen[n] = true
							out.append({"pid": n, "dmg": est_damage(view, def, caster, n, int(prof["neighbor"]))})
		Types.TARGET_ALL:
			for pid: String in alive:
				out.append({"pid": pid, "dmg": est_damage(view, def, caster, pid, dmg)})
		Types.TARGET_ALL_OTHERS:
			for pid: String in alive:
				if pid != caster:
					out.append({"pid": pid, "dmg": est_damage(view, def, caster, pid, dmg)})
	return out


# -----------------------------------------------------------------------------
# Valor de conservar una carta
# -----------------------------------------------------------------------------

static func keep_value(view: Dictionary, me_id: String, card_id: String) -> float:
	var def: Dictionary = CardCatalog.get_def(card_id)
	if def.is_empty():
		return 1.0
	var me: Dictionary = player_of(view, me_id)
	var v: float = 1.0
	match String(def.get("type", "")):
		Types.CARD_TYPE_OFFENSIVE:
			v = 3.0
		Types.CARD_TYPE_DEFENSIVE:
			v = 3.2
		Types.CARD_TYPE_SUPPORT:
			v = 2.0
		Types.CARD_TYPE_CURSE:
			v = 1.6
		Types.CARD_TYPE_ARTIFACT:
			v = 2.6
	match card_id:
		Types.CARD_CURSE_OF_RULES:
			v = 0.3
		Types.CARD_FIRE_ARROW:
			v = 2.2
		Types.CARD_ARMAGEDDON:
			v = 2.0
		Types.CARD_HEAL, Types.CARD_GREATER_HEAL:
			if int(me.get("hp", 0)) >= max_hp(view):
				v = 1.0
	if String(def.get("type", "")) == Types.CARD_TYPE_ARTIFACT and has_artifact(me, card_id):
		v = 0.3
	return v


# -----------------------------------------------------------------------------
# Valor bruto de jugar una carta (antes de restar maná y pago)
# -----------------------------------------------------------------------------

static func play_value(view: Dictionary, me_id: String, def: Dictionary, action: Dictionary) -> float:
	match String(def.get("type", "")):
		Types.CARD_TYPE_OFFENSIVE:
			return _offensive_value(view, me_id, def, action)
		Types.CARD_TYPE_SUPPORT:
			return _support_value(view, me_id, def, action)
		Types.CARD_TYPE_CURSE:
			return _curse_value(view, me_id, def)
		Types.CARD_TYPE_ARTIFACT:
			return _artifact_value(view, me_id, def)
	return 0.0


static func _offensive_value(view: Dictionary, me_id: String, def: Dictionary, action: Dictionary) -> float:
	var me: Dictionary = player_of(view, me_id)
	var prof: Dictionary = profile(def)
	var targets: Array = action.get("targets", []) as Array
	var hp_me: int = int(me["hp"])
	var mx: int = max_hp(view)
	var total: float = 0.0
	for e: Variant in affected(view, def, me_id, targets):
		var ed: Dictionary = e
		var pid: String = String(ed["pid"])
		var dmg: int = int(ed["dmg"])
		var pj: Dictionary = player_of(view, pid)
		if pid == me_id:
			if dmg >= hp_me:
				return -1000.0
			total -= float(dmg) * 4.0
		elif dmg > 0:
			var hp_j: int = int(pj["hp"])
			total += float(mini(dmg, hp_j)) * 3.0 + 1.5
			if dmg >= hp_j:
				total += 25.0
			total += float(mx - hp_j) * 0.3 + threat(pj) * 0.2
	var caster_loss: int = int(prof["caster_loss"])
	if caster_loss >= hp_me:
		return -1000.0
	total -= float(caster_loss) * 4.0
	total += float(mini(int(prof["caster_gain"]), maxi(0, mx - hp_me))) * 3.0
	# Efectos secundarios sobre el objetivo principal.
	if not targets.is_empty():
		var tid: String = String(targets[0])
		var tp: Dictionary = player_of(view, tid)
		if not tp.is_empty() and not is_immune(tp, def):
			var sign_f: float = -1.5 if tid == me_id else 1.0
			var extra: float = 0.0
			match String(def.get("id", "")):
				Types.CARD_FREEZE:
					extra += 4.0
				Types.CARD_BLINDING_FLASH:
					extra += 2.0
				Types.CARD_ICY_GRASP:
					if hand_count(tp) > 0:
						extra += 2.0
			if hand_count(tp) > 0:
				extra += float(mini(int(prof["discard"]), hand_count(tp))) * 1.2
			extra += float(mini(int(prof["mana_loss"]), int(tp.get("mana", 0)))) * 1.0
			total += extra * sign_f
	return total


static func _support_value(view: Dictionary, me_id: String, def: Dictionary, action: Dictionary) -> float:
	var me: Dictionary = player_of(view, me_id)
	var hp: int = int(me["hp"])
	var mx: int = max_hp(view)
	var targets: Array = action.get("targets", []) as Array
	var tid: String = String(targets[0]) if not targets.is_empty() else ""
	var cfg: Dictionary = view["config"]
	match String(def.get("id", "")):
		Types.CARD_HEAL, Types.CARD_GREATER_HEAL:
			if tid != me_id:
				return -5.0
			var gain: int = 1 if String(def["id"]) == Types.CARD_HEAL else 2
			var real: int = mini(gain, mx - hp)
			# Con pocas pociones libres el maná se guarda para dañar (no se cura).
			if real <= 0 or hp > HEAL_BELOW_HP or Bot.is_scarce(view, me_id):
				return 0.0
			return float(real) * (1.5 + float(mx - hp) * 0.8) + (4.0 if hp <= 3 else 0.0)
		Types.CARD_FORCE_FIELD:
			if tid != me_id:
				return -3.0
			if hp <= 4:
				return 5.0
			return 2.0 if hp <= 6 else 0.5
		Types.CARD_MAGIC_HAND:
			var tp: Dictionary = player_of(view, tid)
			if tp.is_empty() or hand_count(tp) == 0:
				return 0.0
			return 2.5 + float(hand_count(tp)) * 0.2
		Types.CARD_BOOK_EXCHANGE:
			var tp2: Dictionary = player_of(view, tid)
			if tp2.is_empty():
				return 0.0
			var mine: float = _hand_keep_sum(view, me_id, action)
			return clampf((float(hand_count(tp2)) * 2.2 - mine) * 0.5, -5.0, 6.0)
		Types.CARD_POTENT_ELIXIR:
			if int((me.get("flags", {}) as Dictionary).get("potent_elixir", 0)) > 0:
				return 0.0
			var room: bool = not bool(cfg.get("potion_limit_enabled", true)) \
				or int(me["potions"]) <= int(cfg.get("potion_limit", 10)) - 3
			if not room:
				return 0.0
			return 2.0 if int(me["mana"]) <= 3 else 0.5
		Types.CARD_SPACE_SHIFT:
			var n: int = maxi(0, (me.get("hand", []) as Array).size() - 1 - (action.get("payment", []) as Array).size())
			var keep: float = _hand_keep_sum(view, me_id, action)
			return (float(n) * 2.2 - keep) * 0.7
	return 0.0


## Suma de keep_value de la mano sin la carta jugada ni las de pago.
static func _hand_keep_sum(view: Dictionary, me_id: String, action: Dictionary) -> float:
	var me: Dictionary = player_of(view, me_id)
	var skip: Array = (action.get("payment", []) as Array).duplicate()
	skip.append(int(action.get("card", -1)))
	var sum: float = 0.0
	for c: Variant in me["hand"] as Array:
		var cd: Dictionary = c
		if skip.has(int(cd["iid"])):
			continue
		sum += keep_value(view, me_id, String(cd["card_id"]))
	return sum


static func _curse_value(view: Dictionary, me_id: String, def: Dictionary) -> float:
	var cid: String = String(def.get("id", ""))
	if cid == Types.CARD_CURSE_OF_RULES:
		return 0.0
	var me: Dictionary = player_of(view, me_id)
	var gain: float = 0.0
	var lose: float = 0.0
	for pid: String in Types.alive_ids(view):
		var p: Dictionary = player_of(view, pid)
		var hit: bool = false
		match cid:
			Types.CARD_CURSE_OF_THE_ELDER:
				hit = int(p["age"]) > int(me["age"])
			Types.CARD_CURSE_OF_THE_YOUNGER:
				hit = int(p["age"]) < int(me["age"])
			Types.CARD_CURSE_OF_VIGOUR:
				hit = int(p["hp"]) >= int(me["hp"])
			Types.CARD_CURSE_OF_EVEN:
				hit = int(p["birth_month"]) % 2 == 0
			Types.CARD_CURSE_OF_ODD:
				hit = int(p["birth_month"]) % 2 == 1
		if not hit or is_immune(p, def):
			continue
		var lost: float = float(mini(3, int(p["mana"])))
		if pid == me_id:
			lose += lost * 1.2
		else:
			gain += lost
	var v: float = gain - lose
	return v if v >= 1.5 else 0.0


static func _artifact_value(view: Dictionary, me_id: String, def: Dictionary) -> float:
	var me: Dictionary = player_of(view, me_id)
	var cid: String = String(def.get("id", ""))
	if has_artifact(me, cid):
		return -1.0
	var el: String = ""
	match cid:
		Types.CARD_WILD_FIRE:
			el = Types.ELEMENT_FIRE
		Types.CARD_DRAGON_GLASS:
			el = Types.ELEMENT_ICE
		Types.CARD_TESLA_COIL:
			el = Types.ELEMENT_ELECTRIC
	if el != "":
		var n: int = 0
		for c: Variant in me["hand"] as Array:
			var cd: Dictionary = CardCatalog.get_def(String((c as Dictionary)["card_id"]))
			if String(cd.get("type", "")) == Types.CARD_TYPE_OFFENSIVE and String(cd.get("element", "")) == el:
				n += 1
		return 1.5 + 1.6 * float(n)
	match cid:
		Types.CARD_MAGIC_CAP:
			return 4.0
		Types.CARD_SPELLBOOK:
			return 2.5
		Types.CARD_FIREPROOF_TIARA, Types.CARD_PADDED_BOOTS, Types.CARD_FARADAYS_CLOAK:
			return 3.0
		Types.CARD_RUNIC_ARMOR, Types.CARD_TRANSFORMATION_GLOVE:
			return 2.5
		Types.CARD_TWARDOWSKYS_MIRROR:
			return 2.0
		Types.CARD_SCROLL_OF_ELEMENTS:
			return 1.0
	return 2.0
