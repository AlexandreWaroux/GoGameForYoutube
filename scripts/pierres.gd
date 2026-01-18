extends Node3D

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var stone_white_scene: PackedScene = preload("res://scenes/stone_white_001.tscn")
@onready var stone_black_scene: PackedScene = preload("res://scenes/stone_black_002.tscn")

const GRID_SIZE = 0.65
const GRID_COUNT = 19
const LOGIC_Y = 0.0 # utilisé UNIQUEMENT pour les clés

# grid_pos_logic -> { "color": String, "node": Node3D, "world_pos": Vector3 }
var occupied_positions := {}

var white_turn := true

func _input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		spawn_stone()

func spawn_stone():
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2 # EXACTEMENT comme ton code qui marche

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return

	var world_pos := snap_to_grid(hit.position)
	var logic_pos := to_logic_pos(world_pos)

	if occupied_positions.has(logic_pos):
		print("Case occupée !")
		return

	var color: String
	if white_turn:
		color = "white"
	else:
		color = "black"

	# placement temporaire
	occupied_positions[logic_pos] = {
		"color": color,
		"node": null,
		"world_pos": world_pos
	}

	# captures adverses
	var captured_any := false
	for neighbor in get_neighbors(logic_pos):
		if occupied_positions.has(neighbor):
			if occupied_positions[neighbor].color != color:
				var group = get_group(neighbor)
				if count_liberties(group) == 0:
					remove_group(group)
					captured_any = true

	# vérification suicide
	var my_group = get_group(logic_pos)
	if count_liberties(my_group) == 0 and not captured_any:
		occupied_positions.erase(logic_pos)
		print("Coup suicidaire interdit")
		return

	# instanciation finale (VISUEL INCHANGÉ)
	var stone: Node3D
	if color == "white":
		stone = stone_white_scene.instantiate()
	else:
		stone = stone_black_scene.instantiate()

	add_child(stone)
	stone.global_position = world_pos
	occupied_positions[logic_pos].node = stone

	white_turn = not white_turn

func snap_to_grid(pos: Vector3) -> Vector3:
	var x = round(pos.x / GRID_SIZE) * GRID_SIZE
	var z = round(pos.z / GRID_SIZE) * GRID_SIZE
	return Vector3(x, pos.y, z) # EXACTEMENT COMME TON CODE QUI MARCHE

# --- LOGIQUE DU GO (Y FIXE) ---

func to_logic_pos(world_pos: Vector3) -> Vector3:
	return Vector3(world_pos.x, LOGIC_Y, world_pos.z)

# ---------- CHANGEMENT PRINCIPAL ----------
# calcule les voisins à partir d'indices entiers pour éviter les erreurs de float
func get_neighbors(pos: Vector3) -> Array:
	var xi = int(round(pos.x / GRID_SIZE))
	var zi = int(round(pos.z / GRID_SIZE))
	return [
		Vector3((xi + 1) * GRID_SIZE, LOGIC_Y, zi * GRID_SIZE),
		Vector3((xi - 1) * GRID_SIZE, LOGIC_Y, zi * GRID_SIZE),
		Vector3(xi * GRID_SIZE, LOGIC_Y, (zi + 1) * GRID_SIZE),
		Vector3(xi * GRID_SIZE, LOGIC_Y, (zi - 1) * GRID_SIZE)
	]
# ------------------------------------------

func get_group(start_pos: Vector3) -> Array:
	var color = occupied_positions[start_pos].color
	var visited := {}
	var stack := [start_pos]
	var group := []

	while stack.size() > 0:
		var pos = stack.pop_back()
		if visited.has(pos):
			continue
		visited[pos] = true
		group.append(pos)

		for neighbor in get_neighbors(pos):
			if occupied_positions.has(neighbor):
				if occupied_positions[neighbor].color == color:
					stack.append(neighbor)

	return group

func count_liberties(group: Array) -> int:
	var liberties := {}
	for pos in group:
		for neighbor in get_neighbors(pos):
			if not occupied_positions.has(neighbor):
				liberties[neighbor] = true
	return liberties.size()

func remove_group(group: Array):
	for pos in group:
		var stone = occupied_positions[pos].node
		if stone:
			stone.queue_free()
		occupied_positions.erase(pos)
