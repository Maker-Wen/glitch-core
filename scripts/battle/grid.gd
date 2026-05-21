class_name Grid extends RefCounted
## 8x8 game board. Holds tile types and tile HP. Provides pathfinding with
## deterministic N->E->S->W tie-break (see docs/design/ui_decision_rules.md §1.1).

const SIZE := 8

enum TileType { EMPTY, PILLAR, BUILDING, RIFT, RUIN }

## Direction priority order for tie-break: North, East, South, West.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),  # N
	Vector2i(1, 0),   # E
	Vector2i(0, 1),   # S
	Vector2i(-1, 0),  # W
]

var tiles: PackedInt32Array = PackedInt32Array()
var tile_hp: Dictionary = {}  # Vector2i -> int (only for PILLAR / BUILDING)

func _init() -> void:
	tiles.resize(SIZE * SIZE)
	tiles.fill(TileType.EMPTY)

func clone() -> Grid:
	var g := Grid.new()
	g.tiles = tiles.duplicate()
	g.tile_hp = tile_hp.duplicate()
	return g

func _idx(p: Vector2i) -> int:
	return p.y * SIZE + p.x

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < SIZE and p.y >= 0 and p.y < SIZE

func get_tile(p: Vector2i) -> int:
	if not in_bounds(p):
		return TileType.EMPTY
	return tiles[_idx(p)]

func set_tile(p: Vector2i, t: int) -> void:
	if not in_bounds(p):
		return
	tiles[_idx(p)] = t

## True if the tile occupies the cell and blocks unit movement onto it.
## PILLAR + BUILDING block. RIFT + RUIN + EMPTY do not.
func blocks_movement(p: Vector2i) -> bool:
	var t := get_tile(p)
	return t == TileType.PILLAR or t == TileType.BUILDING

## Reachable cells via 4-direction BFS up to max_steps.
## `blocked` is a set of additional cells (e.g. occupied by other units) that
## cannot be entered. The starting cell is NOT included in the result.
func reachable_cells(from: Vector2i, max_steps: int, blocked: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if max_steps <= 0:
		return result
	var visited: Dictionary = {from: 0}
	var frontier: Array = [from]
	while not frontier.is_empty():
		var next: Array = []
		for cell in frontier:
			var dist: int = visited[cell]
			if dist >= max_steps:
				continue
			for d in DIRS:
				var n: Vector2i = cell + d
				if not in_bounds(n):
					continue
				if blocks_movement(n):
					continue
				if blocked.has(n):
					continue
				if visited.has(n):
					continue
				visited[n] = dist + 1
				result.append(n)
				next.append(n)
		frontier = next
	return result

## Find shortest path (excluding `from`, including `to`) using BFS with
## N->E->S->W tie-break. Returns empty array if unreachable.
func find_path(from: Vector2i, to: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	if from == to:
		return []
	var came_from: Dictionary = {from: from}
	var frontier: Array = [from]
	var found := false
	while not frontier.is_empty() and not found:
		var next: Array = []
		for cell in frontier:
			for d in DIRS:
				var n: Vector2i = cell + d
				if not in_bounds(n):
					continue
				if n != to and blocks_movement(n):
					continue
				if n != to and blocked.has(n):
					continue
				if came_from.has(n):
					continue
				came_from[n] = cell
				if n == to:
					found = true
					break
				next.append(n)
			if found:
				break
		frontier = next
	if not came_from.has(to):
		return []
	var path: Array[Vector2i] = []
	var cur: Vector2i = to
	while cur != from:
		path.push_front(cur)
		cur = came_from[cur]
	return path

## Manhattan distance (for AI heuristic / sort).
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
