class_name FeedbackMapper
extends RefCounted
## Traduce una entrada de log en feedback visual (FeedbackItem). Puro y estático.
## Ver docs/TECNICO/bus-presentacion.md §4.1. No compone texto.

const FB_DAMAGE: String = "damage"
const FB_HEAL: String = "heal"
const FB_MANA: String = "mana"
const FB_POTION: String = "potion"
const FB_ELIMINATED: String = "eliminated"
const FB_CARD_PLAYED: String = "card_played"
const LANE_BANNER: String = "banner"
const DUR_PANEL_MS: int = 1200
const DUR_ELIMINATED_MS: int = 2000
const DUR_BANNER_MS: int = 1400
const MIN_DURATION_MS: int = 1000


static func lane_for(pid: String) -> String:
	return "panel:%s" % pid


## 0 o 1 FeedbackItem por entrada.
static func map_entry(entry: Dictionary, rev: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var type: String = String(entry.get("type", ""))
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var actor: String = String(entry.get("player", ""))
	var kind: String = ""
	var target: String = ""
	var amount: int = 0
	var extra: Dictionary = {}
	var dur: int = DUR_PANEL_MS
	var targets: Array = []
	match type:
		Types.LOG_DAMAGE:
			kind = FB_DAMAGE
			target = String(data.get("target", ""))
			amount = -int(data.get("dealt", 0))
			extra = {"prevented": int(data.get("prevented", 0)), "element": data.get("element", ""),
				"kind": String(data.get("kind", ""))}
		Types.LOG_HEAL:
			kind = FB_HEAL
			target = String(data.get("target", ""))
			amount = int(data.get("amount", 0))
		Types.LOG_MANA_CHANGED:
			kind = FB_MANA
			target = String(data.get("target", ""))
			if target == "":
				target = actor
			amount = int(data.get("delta", 0))
			extra = {"missing": int(data.get("missing", 0))}
		Types.LOG_POTION:
			kind = FB_POTION
			target = actor
			amount = int(data.get("amount", 0))
			extra = {"potions": int(data.get("potions", 0))}
		Types.LOG_ELIMINATED:
			kind = FB_ELIMINATED
			target = actor
			extra = {"reason": String(data.get("reason", ""))}
			dur = DUR_ELIMINATED_MS
		Types.LOG_CARD_PLAYED:
			kind = FB_CARD_PLAYED
			amount = -int(data.get("cost", 0))
			extra = {"caster": actor}
			targets = (data.get("targets", []) as Array).duplicate(true)
			dur = DUR_BANNER_MS
		_:
			return out
	var lane: String = LANE_BANNER
	if kind != FB_CARD_PLAYED:
		if target == "":
			target = actor
		if target != "":
			lane = lane_for(target)
	out.append({
		"log_seq": int(entry.get("log_seq", 0)), "rev": rev, "kind": kind, "lane": lane,
		"target": target if kind != FB_CARD_PLAYED else "", "actor": actor, "amount": amount,
		"card_id": String(data.get("card_id", "")), "targets": targets, "extra": extra,
		"visible_to": (entry.get("visible_to", []) as Array).duplicate(),
		"duration_ms": maxi(dur, MIN_DURATION_MS)})
	return out
