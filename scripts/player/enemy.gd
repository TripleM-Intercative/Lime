class_name BigEnemy
extends CharacterBody2D
## Big Enemy "Turret": langsamer Artillerie-Gegner.
## Hält Abstand zum Spieler, positioniert sich so, dass der Spieler etwa mittig in der
## Attack-Range steht, und beschießt ihn mit Raketen (Attacke 1 = Streufeuer, Attacke 2 = Präzisionsrakete).
##
## Alle Distanzen sind in FELDERN (Zellen), nicht in Pixeln.

signal charging_started(attack_type: int)
signal attack_fired(attack_type: int)
signal died

enum State { IDLE, REPOSITION, FLEE, CHARGING, RECOVERY }
enum AttackType { BARRAGE, BIG_ROCKET }

const DIRS_4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS_DIAG := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

@export_group("References")
## Wird vom Spawner gesetzt. Falls leer, wird %MapPathfinding bzw. ../Player gesucht.
@export var map: TileMapLayer
@export var pathfinding: Node
@export var player: Node2D

@export_group("Stats")
@export var max_health := 100
@export var movement_duration := 0.8  ## Sekunden pro Feld (langsam)
@export var allow_diagonal := false
@export var think_interval := 0.1  ## Wie oft der Gegner im Stand neu entscheidet

@export_group("Ranges (in Feldern)")
@export var sight_radius := 20.0  ## Sichtfeld, groß
@export var attack_range := 12.0  ## Attack-Range, größer als Reaktionsfeld
@export var reaction_radius := 5.0  ## Reaktionsfeld: darin hat Fliehen Vorrang vor Angriff
@export var approach_distance := 7.0  ## Gegner läuft auf den Spieler zu, bis er so nah ist (> reaction_radius!)

@export_group("Attack 1 - Barrage")
@export var barrage_interval := 4.0
@export var barrage_charge_time := 0.8
@export var barrage_rocket_count := 10
@export var barrage_flight_time := 1.6
@export var barrage_flight_jitter := 0.3  ## Zufällige Abweichung der Flugzeit je Rakete (+/-)
@export var barrage_damage := 10
@export var min_barrage_range := 3.0  ## Direkter Umkreis, den Attacke 1 nicht trifft
@export var barrage_player_bonus := 6.0  ## Zusatzgewicht für Felder nahe am Spieler
@export var barrage_player_focus_radius := 3.0
@export var barrage_enemy_avoid_radius := 2.5  ## Um andere Gegner herum werden weniger Raketen abgefeuert
@export var barrage_enemy_avoid_factor := 0.1  ## Gewicht-Multiplikator in dieser Zone (0 = gar nicht)
@export var barrage_color := Color(1.0, 0.45, 0.1)

@export_group("Attack 2 - Big Rocket")
@export var big_cooldown := 8.0
@export var big_charge_time := 1.0
@export var big_flight_time := 1.4
@export_range(1, 9, 2) var big_size := 3  ## Kantenlänge der AoE (ungerade)
@export var big_damage := 30
@export var big_wall_distance := 1  ## Spieler muss höchstens so viele Felder von einer Wand entfernt sein
@export var big_enemy_clear_radius := 4.0  ## Keine anderen Gegner in diesem Umkreis um den Spieler
@export var big_color := Color(1.0, 0.1, 0.1)

@export_group("Misc")
@export var recovery_time := 0.5  ## Pause nach dem Abfeuern, bevor wieder bewegt wird
@export var debug_draw := true  ## Zeichnet Sicht-, Attack-, Reaktions- und Approach-Radius

var current_cell := Vector2i.ZERO
var target_cell := Vector2i.ZERO
var state := State.IDLE
var register_value

var is_moving := false
var movement_timer := 0.0

var _health := 0
var _think_timer := 0.0
var _attack1_timer := 0.0
var _big_timer := 0.0
var _charge_timer := 0.0
var _recovery_timer := 0.0
var _pending_attack := AttackType.BARRAGE


func _ready() -> void:
	assert(map, "No Map in BigEnemy")
	if pathfinding == null:
		pathfinding = get_node_or_null("%MapPathfinding")
	if player == null:
		player = get_node_or_null("../Player")
	assert(pathfinding != null and player != null, "BigEnemy braucht MapPathfinding und Player")

	add_to_group("enemies")
	add_to_group("big_enemies")

	current_cell = map.local_to_map(position)
	target_cell = current_cell
	position = map.map_to_local(current_cell)

	_health = max_health
	# Gegner nicht alle synchron feuern lassen
	_attack1_timer = randf_range(barrage_interval * 0.5, barrage_interval)
	_big_timer = big_cooldown * 0.5

	register_value = pathfinding.register_entity(Enums.EntityType.BigEnemy, current_cell)

	_validate_settings()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_attack1_timer = maxf(_attack1_timer - delta, 0.0)
	_big_timer = maxf(_big_timer - delta, 0.0)

	if is_moving:
		_process_movement(delta)
	else:
		_think(delta)


# ---------------------------------------------------------------------------
# Movement (Grid-basiert, ein Feld pro Schritt)
# ---------------------------------------------------------------------------

func _start_step(cell: Vector2i) -> void:
	target_cell = cell
	movement_timer = 0.0
	is_moving = true
	# MapPathfinding bekommt das Zielfeld sofort, damit andere Gegner es meiden
	pathfinding.update_pos(register_value, target_cell)


func _process_movement(delta: float) -> void:
	movement_timer += delta / movement_duration
	position = map.map_to_local(current_cell).lerp(
		map.map_to_local(target_cell), clampf(movement_timer, 0.0, 1.0))

	if movement_timer >= 1.0:
		is_moving = false
		movement_timer = 0.0
		current_cell = target_cell
		_think_timer = 0.0  # direkt nach dem Schritt neu entscheiden


# ---------------------------------------------------------------------------
# Entscheidungslogik (läuft nur zwischen zwei Feldern)
# ---------------------------------------------------------------------------

func _think(delta: float) -> void:
	# Einmal begonnene Attacken werden IMMER ausgeführt, egal wo der Spieler hinläuft.
	match state:
		State.CHARGING:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_fire()
			return
		State.RECOVERY:
			_recovery_timer -= delta
			if _recovery_timer <= 0.0:
				state = State.IDLE
			return

	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = think_interval

	var player_cell := _player_cell()
	var dist := _cell_dist(current_cell, player_cell)

	# Spieler außerhalb des Sichtfelds
	if dist > sight_radius:
		state = State.IDLE
		return

	# 1) Reaktionsfeld: Fliehen hat Vorrang vor Angriff
	var in_reaction := dist <= reaction_radius
	if in_reaction:
		var flee_cell := _find_flee_cell(player_cell)
		if flee_cell != current_cell:
			state = State.FLEE
			_start_step(flee_cell)
			return
		# in die Ecke gedrängt -> darf angreifen

	# 2) Angriff, falls möglich
	if _try_start_attack(player_cell, dist):
		return

	# 3) Positionierung: näher an den Spieler, bis er etwa mittig in der Range steht
	if not in_reaction and dist > approach_distance:
		var next_cell = pathfinding.calculate_next_path_secment(register_value, player_cell)
		if next_cell is Vector2i and next_cell != current_cell and not _is_blocked(next_cell):
			state = State.REPOSITION
			_start_step(next_cell)
			return

	state = State.IDLE


func _find_flee_cell(player_cell: Vector2i) -> Vector2i:
	## Wählt unter den Nachbarfeldern das, das den Abstand zum Spieler vergrößert.
	## Felder mit mehr freien Nachbarn werden bevorzugt, damit der Gegner nicht in Sackgassen flieht.
	var best := current_cell
	var best_score := -INF
	var current_dist := _cell_dist(current_cell, player_cell)

	for cell in _neighbors(current_cell):
		if _is_blocked(cell):
			continue
		var d := _cell_dist(cell, player_cell)
		if d <= current_dist:
			continue
		var openness := 0
		for n in _neighbors(cell):
			if _is_walkable(n):
				openness += 1
		var score := d + openness * 0.3
		if score > best_score:
			best_score = score
			best = cell
	return best


# ---------------------------------------------------------------------------
# Attacken
# ---------------------------------------------------------------------------

func _try_start_attack(player_cell: Vector2i, dist: float) -> bool:
	if dist > attack_range:
		return false

	# Attacke 2 hat Vorrang, wenn ihre Bedingungen erfüllt sind
	if _big_timer <= 0.0 and _can_use_big_rocket(player_cell):
		_begin_charge(AttackType.BIG_ROCKET, big_charge_time)
		return true

	if _attack1_timer <= 0.0:
		_begin_charge(AttackType.BARRAGE, barrage_charge_time)
		return true

	return false


func _begin_charge(type: AttackType, charge_time: float) -> void:
	state = State.CHARGING
	_pending_attack = type
	_charge_timer = charge_time
	charging_started.emit(type)


func _fire() -> void:
	match _pending_attack:
		AttackType.BARRAGE:
			_fire_barrage()
			_attack1_timer = barrage_interval
		AttackType.BIG_ROCKET:
			_fire_big_rocket()
			_big_timer = big_cooldown
			_attack1_timer = barrage_interval  # Attacke 2 setzt den Timer von Attacke 1 zurück

	attack_fired.emit(_pending_attack)
	state = State.RECOVERY
	_recovery_timer = recovery_time


# --- Attacke 1 --------------------------------------------------------------

func _fire_barrage() -> void:
	var cells := _pick_barrage_cells(_player_cell(), barrage_rocket_count)
	for cell in cells:
		var flight := maxf(barrage_flight_time + randf_range(-barrage_flight_jitter, barrage_flight_jitter), 0.2)
		var single: Array[Vector2i] = [cell]
		_spawn_impact(single, flight, barrage_damage, barrage_color)


func _pick_barrage_cells(player_cell: Vector2i, count: int) -> Array[Vector2i]:
	var enemy_cells := _other_enemy_cells()
	var candidates: Array[Vector2i] = []
	var weights: Array[float] = []

	var r := int(ceil(attack_range))
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var offset := Vector2i(x, y)
			var d := offset.length()
			if d > attack_range or d < min_barrage_range:
				continue
			var cell := current_cell + offset
			if not _is_walkable(cell):
				continue

			var w := 1.0
			# Tendenziell mehr Raketen in die Nähe des Spielers (Gauß-Kurve um den Spieler)
			var dp := _cell_dist(cell, player_cell)
			var sigma := barrage_player_focus_radius
			w += barrage_player_bonus * exp(-(dp * dp) / (2.0 * sigma * sigma))
			# Weniger Raketen in die Nähe anderer Gegner
			for ec in enemy_cells:
				if _cell_dist(cell, ec) <= barrage_enemy_avoid_radius:
					w *= barrage_enemy_avoid_factor

			if w > 0.0:
				candidates.append(cell)
				weights.append(w)

	# Gewichtete Auswahl ohne Zurücklegen (jedes Feld höchstens einmal)
	var picked: Array[Vector2i] = []
	var total := 0.0
	for w in weights:
		total += w

	for _i in mini(count, candidates.size()):
		if total <= 0.0:
			break
		var roll := randf() * total
		var acc := 0.0
		for j in candidates.size():
			if weights[j] <= 0.0:
				continue
			acc += weights[j]
			if roll <= acc:
				picked.append(candidates[j])
				total -= weights[j]
				weights[j] = 0.0
				break
	return picked


# --- Attacke 2 --------------------------------------------------------------

func _can_use_big_rocket(player_cell: Vector2i) -> bool:
	# Bedingung 1: Spieler steht höchstens big_wall_distance Felder von einer Wand entfernt
	var near_wall := false
	for dx in range(-big_wall_distance, big_wall_distance + 1):
		for dy in range(-big_wall_distance, big_wall_distance + 1):
			if not _is_walkable(player_cell + Vector2i(dx, dy)):
				near_wall = true
	if not near_wall:
		return false

	# Bedingung 2: keine anderen Gegner im Umkreis um den Spieler
	for ec in _other_enemy_cells():
		if _cell_dist(ec, player_cell) <= big_enemy_clear_radius:
			return false
	return true


func _fire_big_rocket() -> void:
	# Ziel wird erst im Moment des Abfeuerns gewählt: Spieler steht in der Mitte der AoE
	var center := _player_cell()
	var half := big_size >> 1
	var cells: Array[Vector2i] = []
	for x in range(-half, half + 1):
		for y in range(-half, half + 1):
			var cell := center + Vector2i(x, y)
			if _is_walkable(cell):
				cells.append(cell)
	_spawn_impact(cells, big_flight_time, big_damage, big_color)


func _spawn_impact(cells: Array[Vector2i], flight_time: float, damage: int, color: Color) -> void:
	var impact := RocketImpact.new()
	impact.setup(map, pathfinding, cells, flight_time, damage, color)
	map.add_child(impact)  # als Kind der Map -> Zellkoordinaten passen direkt


# ---------------------------------------------------------------------------
# Schaden / Tod
# ---------------------------------------------------------------------------

func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		_die()


func _die() -> void:
	pathfinding.remove_from_register(register_value)
	died.emit()
	queue_free()


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

func _player_cell() -> Vector2i:
	var c = player.get("current_cell")
	if c is Vector2i:
		return c
	return map.local_to_map(map.to_local(player.global_position))


func _entity_cell(node: Node2D) -> Vector2i:
	return map.local_to_map(map.to_local(node.global_position))


func _other_enemy_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not node is Node2D:
			continue
		result.append(_entity_cell(node))
	return result


func _cell_dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()


func _is_walkable(cell: Vector2i) -> bool:
	# TODO: durch die echte Begehbarkeits-Abfrage deiner MapPathfinding ersetzen
	if pathfinding.has_method("is_walkable"):
		return pathfinding.call("is_walkable", cell)
	return map.get_cell_source_id(cell) != -1


func _is_blocked(cell: Vector2i) -> bool:
	if not _is_walkable(cell):
		return true
	if cell == _player_cell():
		return true
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		if node.get("current_cell") == cell or node.get("target_cell") == cell:
			return true
	return false


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRS_4:
		result.append(cell + dir)
	if allow_diagonal:
		for dir in DIRS_DIAG:
			# keine Ecken schneiden
			if _is_walkable(cell + Vector2i(dir.x, 0)) and _is_walkable(cell + Vector2i(0, dir.y)):
				result.append(cell + dir)
	return result


func _validate_settings() -> void:
	if reaction_radius >= attack_range:
		push_warning("BigEnemy: reaction_radius sollte kleiner als attack_range sein")
	if sight_radius < attack_range:
		push_warning("BigEnemy: sight_radius sollte groesser als attack_range sein")
	if approach_distance <= reaction_radius:
		push_warning("BigEnemy: approach_distance muss groesser als reaction_radius sein, sonst laeuft er hin und her")
	if min_barrage_range >= attack_range:
		push_warning("BigEnemy: min_barrage_range muss kleiner als attack_range sein")


func _draw() -> void:
	if not debug_draw or map == null:
		return
	var px := float(map.tile_set.tile_size.x)
	draw_arc(Vector2.ZERO, sight_radius * px, 0.0, TAU, 96, Color(1, 1, 1, 0.25), 1.0)
	draw_arc(Vector2.ZERO, attack_range * px, 0.0, TAU, 96, Color(1, 0.5, 0.1, 0.6), 1.5)
	draw_arc(Vector2.ZERO, approach_distance * px, 0.0, TAU, 96, Color(0.3, 0.8, 1, 0.5), 1.0)
	draw_arc(Vector2.ZERO, reaction_radius * px, 0.0, TAU, 96, Color(1, 0.1, 0.1, 0.7), 1.5)
	draw_arc(Vector2.ZERO, min_barrage_range * px, 0.0, TAU, 96, Color(0.6, 0.6, 0.6, 0.5), 1.0)
