extends Node

const BOARD_SIZE := 10

const SHIPS_DEF := [
	{ "name": "Лінкор", "size": 4, "count": 1 },
	{ "name": "Крейсер", "size": 3, "count": 2 },
	{ "name": "Есмінець", "size": 2, "count": 3 },
	{ "name": "Катер", "size": 1, "count": 4 },
]

static func total_decks() -> int:
	var s := 0
	for d in SHIPS_DEF:
		s += int(d.size) * int(d.count)
	return s

static func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE

static func rc(r: int, c: int) -> int:
	return r * BOARD_SIZE + c

static func rand_i(max_exclusive: int) -> int:
	return randi() % max_exclusive
