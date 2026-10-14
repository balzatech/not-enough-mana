class_name Rng
extends RefCounted
## PRNG mulberry32 con estado entero de 32 bits (0 <= state < 2^32).
##
## Funciones PURAS: reciben el estado y devuelven el valor y el estado nuevo.
## El estado se guarda en state["rng_state"] y sobrevive a JSON/Firebase sin
## perder precisión (cabe en un double). Uso típico dentro del motor:
##
##   var r: Dictionary = Rng.next_int(state["rng_state"], hand.size())
##   state["rng_state"] = r["state"]
##   var idx: int = r["value"]
##
## Prohibido en src/engine/: randi(), randf(), RandomNumberGenerator.

const MASK32: int = 0xFFFFFFFF
const INCREMENT: int = 0x6D2B79F5


## Normaliza cualquier int (semilla) al rango [0, 2^32).
static func seed_from(value: int) -> int:
	return value & MASK32


## Siguiente número. Devuelve {"value": int en [0, 2^32), "state": int}.
static func next(state: int) -> Dictionary:
	var a: int = (state + INCREMENT) & MASK32
	var t: int = a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & MASK32)) & MASK32
	var value: int = (t ^ (t >> 14)) & MASK32
	return {"value": value, "state": a}


## Entero uniforme en [0, n). Devuelve {"value", "state"}. n debe ser >= 1.
static func next_int(state: int, n: int) -> Dictionary:
	assert(n >= 1, "Rng.next_int: n debe ser >= 1")
	var r: Dictionary = next(state)
	var v: int = r["value"]
	# (v * n) >> 32: sin sesgo apreciable para n pequeños; v*n cabe en 64 bits.
	return {"value": (v * n) >> 32, "state": r["state"]}


## Entero uniforme en [lo, hi] (ambos incluidos). Devuelve {"value", "state"}.
static func next_range(state: int, lo: int, hi: int) -> Dictionary:
	var r: Dictionary = next_int(state, hi - lo + 1)
	return {"value": lo + int(r["value"]), "state": r["state"]}


## Fisher-Yates. NO muta `arr`: devuelve {"array": copia barajada, "state"}.
static func shuffle(arr: Array, state: int) -> Dictionary:
	var out: Array = arr.duplicate()
	var s: int = state
	var i: int = out.size() - 1
	while i > 0:
		var r: Dictionary = next_int(s, i + 1)
		s = r["state"]
		var j: int = r["value"]
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
		i -= 1
	return {"array": out, "state": s}


## Multiplicación de 32 bits con desbordamiento (Math.imul sin signo), sin
## depender del desbordamiento de int64: parte el operando en mitades de 16 bits.
static func _imul(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var a_lo: int = a & 0xFFFF
	var a_hi: int = a >> 16
	var lo: int = a_lo * b
	var hi: int = ((a_hi * (b & 0xFFFF)) & 0xFFFF) << 16
	return (lo + hi) & MASK32
