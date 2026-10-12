extends Node
## Player inventory: a quantity per item id.

signal changed(item_id: String, quantity: int)

var _quantities: Dictionary[String, int] = {}


func add(item_id: String, quantity: int = 1) -> void:
	if quantity <= 0:
		return
	if not GameData.items.has(item_id):
		push_error("Inventory: unknown item '%s'" % item_id)
		return
	_quantities[item_id] = count(item_id) + quantity
	changed.emit(item_id, _quantities[item_id])


## Removes the quantity if available; returns false and changes nothing otherwise.
func remove(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or count(item_id) < quantity:
		return false
	var left := count(item_id) - quantity
	if left == 0:
		_quantities.erase(item_id)
	else:
		_quantities[item_id] = left
	changed.emit(item_id, left)
	return true


func count(item_id: String) -> int:
	return _quantities.get(item_id, 0)


func get_all() -> Dictionary[String, int]:
	return _quantities.duplicate()
