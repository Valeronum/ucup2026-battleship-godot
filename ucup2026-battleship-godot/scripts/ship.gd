extends RefCounted
class_name Ship

var size: int
var id: int
var hits: int = 0
var sunk: bool = false
var cells: Array[Dictionary] = [] # {r,c}

func _init(p_size: int, p_id: int) -> void:
	size = p_size
	id = p_id

func place(r: int, c: int, vertical: bool) -> void:
	cells = []
	for i in range(size):
		cells.append({"r": r + (i if vertical else 0), "c": c + (0 if vertical else i)})

func hit() -> bool:
	hits += 1
	if hits >= size:
		sunk = true
		return true
	return false
