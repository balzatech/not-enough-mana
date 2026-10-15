extends GutTest
## Canario de tools/test.sh (V3-12): deja a propósito un nodo huérfano para comprobar que el
## recuento de huérfanos de GUT sigue activo. No lo recoge la suite (su nombre no lleva el
## prefijo test_); solo lo ejecuta tools/test.sh con -gprefix=orphan_canary.

var _leak: Node = null


func test_leaks_one_node() -> void:
	_leak = Node.new()
	assert_not_null(_leak)


func after_all() -> void:
	if is_instance_valid(_leak):
		_leak.free()
