extends RefCounted
class_name AI

const Constants = preload("res://scripts/constants.gd")

var diff: String
var shots: Dictionary = {} # key->true
var hits: Array = [] # {r,c}

func _init(p_diff: String) -> void:
	diff = p_diff

func reset() -> void:
	shots.clear()
	hits.clear()

func choose_shot(board) -> Dictionary:
	if diff == "easy":
		return _random_shot()
	if hits.size() > 0:
		var next_v: Variant = _hunt_shot(board)
		if next_v != null:
			var next: Dictionary = next_v
			return next
	if diff == "hard":
		return _strategic_shot(board)
	return _random_shot()

func _random_shot() -> Dictionary:
	var r: int
	var c: int
	var key: int
	while true:
		r = Constants.rand_i(Constants.BOARD_SIZE)
		c = Constants.rand_i(Constants.BOARD_SIZE)
		key = Constants.rc(r, c)
		if not shots.has(key):
			break
	shots[key] = true
	return {"r": r, "c": c}

func _hunt_shot(board) -> Variant:
	var directions := [[-1, 0], [1, 0], [0, -1], [0, 1]]
	var preferred_dirs: Array = []
	if hits.size() >= 2:
		var same_row := true
		var same_col := true
		for p in hits:
			same_row = same_row and int(p.r) == int(hits[0].r)
			same_col = same_col and int(p.c) == int(hits[0].c)
		if same_row:
			preferred_dirs = [[0, -1], [0, 1]]
		elif same_col:
			preferred_dirs = [[-1, 0], [1, 0]]
	var dirs := preferred_dirs if preferred_dirs.size() > 0 else directions

	for start in hits:
		for d in dirs:
			var r := int(start.r) + int(d[0])
			var c := int(start.c) + int(d[1])
			if not Constants.in_bounds(r, c):
				continue
			var key := Constants.rc(r, c)
			if shots.has(key):
				continue
			if diff == "hard" and _is_adjacent_to_sunk(r, c, board):
				continue
			shots[key] = true
			return {"r": r, "c": c}
	return null

func _strategic_shot(board) -> Dictionary:
	var step := 2
	var candidates: Array = []
	for r in range(Constants.BOARD_SIZE):
		for c in range(Constants.BOARD_SIZE):
			var key := Constants.rc(r, c)
			if shots.has(key):
				continue
			if _is_adjacent_to_sunk(r, c, board):
				continue
			if (r + c) % step == 0:
				candidates.append({"r": r, "c": c})
	if candidates.size() == 0:
		for r in range(Constants.BOARD_SIZE):
			for c in range(Constants.BOARD_SIZE):
				var key := Constants.rc(r, c)
				if shots.has(key):
					continue
				if _is_adjacent_to_sunk(r, c, board):
					continue
				candidates.append({"r": r, "c": c})
	if candidates.size() == 0:
		return _random_shot()
	var pick: Dictionary = candidates[Constants.rand_i(candidates.size())]
	shots[Constants.rc(int(pick.r), int(pick.c))] = true
	return pick

func _is_adjacent_to_sunk(r: int, c: int, board) -> bool:
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var ar := r + dr
			var ac := c + dc
			if not Constants.in_bounds(ar, ac):
				continue
			var cell_data: Dictionary = board.cell(ar, ac)
			if cell_data.is_empty():
				continue
			if cell_data.state == "hit":
				var ship = board._ship_by_id(cell_data.ship_id)
				if ship != null and ship.sunk:
					return true
	return false

func report_result(r: int, c: int, result: String, ship: Variant) -> void:
	if result == "hit":
		hits.append({"r": r, "c": c})
	if ship != null and ship.sunk:
		var new_hits: Array = []
		for p in hits:
			var belongs := false
			for sc in ship.cells:
				if int(sc.r) == int(p.r) and int(sc.c) == int(p.c):
					belongs = true
					break
			if not belongs:
				new_hits.append(p)
		hits = new_hits
