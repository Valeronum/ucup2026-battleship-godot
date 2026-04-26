extends RefCounted
class_name Board

const Constants = preload("res://scripts/constants.gd")
const ShipClass = preload("res://scripts/ship.gd")

var grid: Array = []
var ships: Array = []

func _init() -> void:
	_reset()

func _reset() -> void:
	grid.clear()
	grid.resize(Constants.BOARD_SIZE * Constants.BOARD_SIZE)
	for i in range(grid.size()):
		grid[i] = {"ship_id": null, "state": "empty", "revealed": false, "sunk": false}
	ships.clear()

func cell(r: int, c: int) -> Dictionary:
	if not Constants.in_bounds(r, c):
		return {}
	return grid[Constants.rc(r, c)]

func can_place(r: int, c: int, size: int, vertical: bool) -> bool:
	for i in range(size):
		var rr := r + (i if vertical else 0)
		var cc := c + (0 if vertical else i)
		if not Constants.in_bounds(rr, cc):
			return false
		if grid[Constants.rc(rr, cc)].ship_id != null:
			return false
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				var ar := rr + dr
				var ac := cc + dc
				if Constants.in_bounds(ar, ac) and grid[Constants.rc(ar, ac)].ship_id != null:
					return false
	return true

func place_ship(ship: ShipClass, r: int, c: int, vertical: bool) -> void:
	ship.place(r, c, vertical)
	for p in ship.cells:
		grid[Constants.rc(int(p.r), int(p.c))] = {"ship_id": ship.id, "state": "ship", "revealed": false, "sunk": false}
	ships.append(ship)

func auto_place_all() -> bool:
	_reset()
	var id := 0
	for def in Constants.SHIPS_DEF:
		for _n in range(int(def.count)):
			var ship := ShipClass.new(int(def.size), id)
			id += 1
			var placed := false
			var attempts := 0
			while not placed and attempts < 1000:
				attempts += 1
				var r := Constants.rand_i(Constants.BOARD_SIZE)
				var c := Constants.rand_i(Constants.BOARD_SIZE)
				var v := randf() < 0.5
				if can_place(r, c, int(def.size), v):
					place_ship(ship, r, c, v)
					placed = true
			if not placed:
				return false
	return true

func receive_shot(r: int, c: int) -> Variant:
	if not Constants.in_bounds(r, c):
		return null
	var idx := Constants.rc(r, c)
	var cell_data: Dictionary = grid[idx]
	if cell_data.state == "hit" or cell_data.state == "miss":
		return null
	if cell_data.state == "empty":
		cell_data.state = "miss"
		grid[idx] = cell_data
		return {"result": "miss"}

	cell_data.state = "hit"
	grid[idx] = cell_data
	var ship := _ship_by_id(cell_data.ship_id)
	var sunk := ship.hit()
	if sunk:
		_mark_ship_sunk(ship)
	return {"result": "hit", "ship": ship, "sunk": sunk}

func area_attack(center_r: int, center_c: int) -> Array:
	var res: Array = []
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var r := center_r + dr
			var c := center_c + dc
			if Constants.in_bounds(r, c):
				var cell_data: Dictionary = cell(r, c)
				if cell_data.state != "hit" and cell_data.state != "miss":
					var shot_v: Variant = receive_shot(r, c)
					if shot_v != null:
						var shot: Dictionary = shot_v
						var out := {"r": r, "c": c}
						out.merge(shot)
						res.append(out)
				else:
					res.append({"r": r, "c": c, "result": null})
	return res

func radar_scan(center_r: int, center_c: int) -> Array:
	var res: Array = []
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var r := center_r + dr
			var c := center_c + dc
			if Constants.in_bounds(r, c):
				var cell_data: Dictionary = cell(r, c)
				res.append({"r": r, "c": c, "has_ship": cell_data.state == "ship"})
	return res

func all_ships_sunk() -> bool:
	for s in ships:
		if not s.sunk:
			return false
	return true

func to_snapshot() -> Dictionary:
	var snap_ships: Array = []
	for s in ships:
		snap_ships.append({"size": s.size, "id": s.id, "hits": s.hits, "sunk": s.sunk, "cells": s.cells})
	return {"grid": grid, "ships": snap_ships}

func from_snapshot(data: Dictionary) -> void:
	grid = data.get("grid", [])
	ships.clear()
	for s in data.get("ships", []):
		var ship := ShipClass.new(int(s.size), int(s.id))
		ship.hits = int(s.hits)
		ship.sunk = bool(s.sunk)
		ship.cells = s.cells
		ships.append(ship)

func _ship_by_id(ship_id: Variant) -> ShipClass:
	for s in ships:
		if s.id == int(ship_id):
			return s
	return null

func _mark_ship_sunk(ship: ShipClass) -> void:
	for p in ship.cells:
		var r := int(p.r)
		var c := int(p.c)
		var idx := Constants.rc(r, c)
		var cd: Dictionary = grid[idx]
		cd.sunk = true
		grid[idx] = cd
