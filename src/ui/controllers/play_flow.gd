class_name PlayFlow
extends RefCounted
## Asistente para jugar una carta (PLAY_CARD) o responder (REACT) eligiendo
## solo entre acciones legales. Recibe las candidatas (ActionOptions.plays_for /
## reacts_for) y las va filtrando paso a paso:
##   1) objetivos (magos)   2) carta objetivo (Annihilation)
##   3) opción extra (Mirror Shield: a quién proteges)   4) pago en cartas
## Cada paso se salta solo si hay una única posibilidad. El pago admite
## comodines en mesa (Scroll of Elements): sus iids aparecen en el pago legal.

const UNSET: int = -2

var cands: Array = []
var targets: Array[String] = []
var target_card: int = UNSET
var extra_chosen: bool = false
var extra: Dictionary = {}


static func create(p_cands: Array) -> PlayFlow:
	var f: PlayFlow = PlayFlow.new()
	f.cands = p_cands.duplicate(true)
	return f


func is_empty() -> bool:
	return cands.is_empty()


# ---------------------------------------------------------------- objetivos

## Nº de magos objetivo que exige la carta (0 si no elige objetivos).
func need_targets() -> int:
	var n: int = 0
	for a: Variant in cands:
		n = maxi(n, ((a as Dictionary)["targets"] as Array).size())
	return n


func targets_done() -> bool:
	return targets.size() >= need_targets()


## Candidatas compatibles con los objetivos elegidos hasta ahora.
func _by_targets() -> Array:
	var out: Array = []
	for a: Variant in cands:
		var ts: Array = (a as Dictionary)["targets"]
		var ok: bool = true
		for t: String in targets:
			if not ts.has(t):
				ok = false
				break
		if ok:
			out.append(a)
	return out


## Magos que se pueden elegir como siguiente objetivo.
func target_choices() -> Array[String]:
	var out: Array[String] = []
	if targets_done():
		return out
	for a: Variant in _by_targets():
		for t: Variant in (a as Dictionary)["targets"]:
			var ts: String = String(t)
			if not targets.has(ts) and not out.has(ts):
				out.append(ts)
	return out


## Marca/desmarca un objetivo. Devuelve false si no es válido.
func toggle_target(pid: String) -> bool:
	if targets.has(pid):
		targets.erase(pid)
		return true
	if need_targets() == 1 and not targets.is_empty():
		targets.clear()
	if not target_choices().has(pid):
		return false
	targets.append(pid)
	return true


# ---------------------------------------------------------------- carta objetivo

func _by_target_card() -> Array:
	var out: Array = []
	for a: Variant in _by_targets():
		var ad: Dictionary = a
		if target_card == UNSET or int(ad["target_card"]) == target_card:
			out.append(ad)
	return out


## iids posibles como carta objetivo (vacío si la carta no la usa).
func target_card_choices() -> Array[int]:
	var out: Array[int] = []
	for a: Variant in _by_targets():
		var tc: int = int((a as Dictionary)["target_card"])
		if tc >= 0 and not out.has(tc):
			out.append(tc)
	return out


func needs_target_card() -> bool:
	if target_card != UNSET:
		return false
	var choices: Array[int] = target_card_choices()
	if choices.size() == 1:
		target_card = choices[0]
		return false
	return choices.size() > 1


func choose_target_card(iid: int) -> void:
	target_card = iid


# ---------------------------------------------------------------- extra

func _by_extra() -> Array:
	var out: Array = []
	for a: Variant in _by_target_card():
		var ad: Dictionary = a
		if not extra_chosen or ad["extra"] == extra:
			out.append(ad)
	return out


func extra_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Variant in _by_target_card():
		var ex: Dictionary = (a as Dictionary)["extra"]
		if not out.has(ex):
			out.append(ex)
	return out


func needs_extra() -> bool:
	if extra_chosen:
		return false
	var choices: Array[Dictionary] = extra_choices()
	if choices.size() <= 1:
		extra = choices[0] if choices.size() == 1 else {}
		extra_chosen = true
		return false
	return true


func choose_extra(ex: Dictionary) -> void:
	extra = ex.duplicate(true)
	extra_chosen = true


# ---------------------------------------------------------------- pago

## Candidatas tras objetivos, carta y extra.
func remaining() -> Array:
	return _by_extra()


func needs_payment() -> bool:
	for a: Variant in remaining():
		if not ((a as Dictionary)["payment"] as Array).is_empty():
			return true
	return false


## Nº de cartas que hay que pagar.
func payment_size() -> int:
	var n: int = 0
	for a: Variant in remaining():
		n = maxi(n, ((a as Dictionary)["payment"] as Array).size())
	return n


## iids que se pueden añadir al pago `selected` (mano o comodín en mesa).
func payment_choices(selected: Array) -> Array[int]:
	var out: Array[int] = []
	for a: Variant in remaining():
		var pay: Array = (a as Dictionary)["payment"]
		var ok: bool = true
		for x: Variant in selected:
			if not pay.has(int(x)):
				ok = false
				break
		if not ok:
			continue
		for x: Variant in pay:
			if not selected.has(int(x)) and not out.has(int(x)):
				out.append(int(x))
	return out


## Todos los iids que aparecen en algún pago legal.
func payment_pool() -> Array[int]:
	return payment_choices([])


## Combinaciones de pago distintas (como conjuntos) de las candidatas vigentes.
func payment_combos() -> Array:
	var out: Array = []
	for a: Variant in remaining():
		var pay: Array = (a as Dictionary)["payment"]
		if pay.is_empty():
			continue
		var dup: bool = false
		for o: Variant in out:
			if ActionOptions.same_set(o as Array, pay):
				dup = true
				break
		if not dup:
			out.append(pay.duplicate())
	return out


## La única combinación válida ([] si hay varias o ninguna).
func sole_payment() -> Array:
	var c: Array = payment_combos()
	return c[0] if c.size() == 1 else []


## Texto del requisito de pago de `def` ("1 carta de fuego"); añade " (o tu
## Scroll of Elements)" si hay varias combinaciones y alguna usa un comodín en
## mesa (iid que no está en `hand_ids`).
func requirement_for(def: Dictionary, hand_ids: Array) -> String:
	var reqs: Array = (def.get("cost", {}) as Dictionary).get("cards", []) as Array
	var combos: Array = payment_combos()
	var scroll: bool = false
	if combos.size() > 1:
		for c: Variant in combos:
			for x: Variant in c as Array:
				if not hand_ids.has(int(x)):
					scroll = true
	return Strings.requirement_text(reqs, scroll)


func payment_valid(selected: Array) -> bool:
	return not _match_payment(selected).is_empty()


func _match_payment(selected: Array) -> Dictionary:
	for a: Variant in remaining():
		var ad: Dictionary = a
		if ActionOptions.same_set(ad["payment"] as Array, selected):
			return ad
	return {}


# ---------------------------------------------------------------- resultado

## ¿Ya se puede construir la acción (con este pago)?
func is_ready(selected_payment: Array = []) -> bool:
	if not targets_done() or needs_target_card() or needs_extra():
		return false
	if needs_payment():
		return payment_valid(selected_payment)
	return not remaining().is_empty()


## Acción final (copia de la candidata elegida). extra_overrides se fusiona en
## action.extra (p. ej. {"rule": texto} para Curse of Rules). {} si no hay.
func build(selected_payment: Array = [], extra_overrides: Dictionary = {}) -> Dictionary:
	if not targets_done() or needs_target_card() or needs_extra():
		return {}
	var a: Dictionary = {}
	if needs_payment():
		a = _match_payment(selected_payment)
	elif not remaining().is_empty():
		a = remaining()[0]
	if a.is_empty():
		return {}
	a = a.duplicate(true)
	var ex: Dictionary = a["extra"]
	for k: Variant in extra_overrides:
		ex[k] = extra_overrides[k]
	return a
