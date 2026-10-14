extends GutTest
## Rng (mulberry32). Vectores de referencia calculados con la implementación JS
## estándar (mulberry32(0)() = 0.26642920868471265 = 1144304738 / 2^32).


func _seq(seed_value: int, n: int) -> Array:
	var s: int = seed_value
	var out: Array = []
	for i: int in n:
		var r: Dictionary = Rng.next(s)
		out.append(r["value"])
		s = r["state"]
	return [out, s]


func test_reference_vectors() -> void:
	assert_eq(_seq(0, 5), [[1144304738, 1416247, 958946056, 627933444, 2007157716], 567894473])
	assert_eq(_seq(1, 5), [[2693262067, 11749833, 2265367787, 4213581821, 4159151403], 567894474])
	assert_eq(_seq(123456789, 5), [[1107202814, 4169434471, 3372958138, 885470128, 1301683845], 691351262])
	assert_eq(_seq(4294967295, 5), [[3850105811, 813802916, 3073704848, 4054706436, 3630262831], 567894472])


func test_state_in_range() -> void:
	var s: int = Rng.seed_from(-12345)
	for i: int in 1000:
		var r: Dictionary = Rng.next(s)
		s = r["state"]
		assert_between(s, 0, Types.RNG_MODULUS - 1)
		assert_between(int(r["value"]), 0, Types.RNG_MODULUS - 1)


func test_next_int_bounds() -> void:
	var s: int = 42
	var seen: Dictionary = {}
	for i: int in 600:
		var r: Dictionary = Rng.next_int(s, 6)
		s = r["state"]
		seen[r["value"]] = true
		assert_between(int(r["value"]), 0, 5)
	assert_eq(seen.size(), 6, "salen los 6 valores")


func test_shuffle_is_pure_and_deterministic() -> void:
	var arr: Array = range(20)
	var a: Dictionary = Rng.shuffle(arr, 99)
	var b: Dictionary = Rng.shuffle(arr, 99)
	assert_eq(arr, range(20), "no muta la entrada")
	assert_eq(a["array"], b["array"], "misma semilla, mismo orden")
	assert_eq(a["state"], b["state"])
	var sorted: Array = (a["array"] as Array).duplicate()
	sorted.sort()
	assert_eq(sorted, arr, "es una permutación")
	assert_ne(a["array"], arr, "baraja de verdad")


func test_state_survives_json() -> void:
	var r: Dictionary = Rng.next(4294967295)
	var back: Variant = Types.normalize_value(JSON.parse_string(JSON.stringify({"s": r["state"]})))
	assert_eq((back as Dictionary)["s"], r["state"])
	assert_eq(typeof((back as Dictionary)["s"]), TYPE_INT)
