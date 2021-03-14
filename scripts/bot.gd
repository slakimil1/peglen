extends KinematicBody2D

const speed_range = Vector2(100, 200)
var dest_location = Vector2()
var start_pos = Vector2()
var count_time = 0
var current_time = 0

var color = Color(randf(), randf(), randf(), randf())

# Navigation system
var motion = Vector2()
var possible_destinations = []
onready var navigation = Gamestate.navigation
onready var avilable_destinations = Gamestate.destinations
var path = []
var destionation = Vector2()

export var nav_stop_theshold = 5

# Hunting
var targets = {}		# List of targets
var target = null		# Current target
var agressive = false
export (int) var detect_radius

export (int) var health

# Called when the node enters the scene tree for the first time.
func _ready():
	$UnitDisplay/HealthBar.max_value = health
	# Hunting 
	detect_radius = 250
	$Body/DetrctRadius/CollisionRadius.shape.radius = detect_radius
	
	# Calculate a random modulate color - randf() goves a random number in the interval [0,1]
	#$icon.modulate = color
	# And a random position - ideally this initial poaition should be placed on the spawn code
	# however simplicity is required for the tutorial
	position = get_random_location()
	# And the motion variables
	#calculate_motion_vars()
	
	# Navigate system
	possible_destinations = avilable_destinations.get_children()
	make_path()
	
	if agressive:
		$Body/Aggressive.modulate = Color(255, 0, 0)
	else:
		$Body/Aggressive.modulate = Color(0, 255, 0)

func _process(delta):
	if (is_network_master()):
#		if count_time == 0:
#			calculate_motion_vars()
#		else:
#			current_time += delta
#			var alpha = current_time / count_time
#			if (alpha > 1.0):
#				alpha = 1.0
#
#			var nposition = start_pos.linear_interpolate(dest_location, alpha)
#
#			if (alpha >= 1.0):
#				calculate_motion_vars()
#
#			position = nposition

		navigate()

func navigate():
	if path.size() == 0:
		make_path()
		return
	
	destionation = path[0]
		
	var distance_to_distanation = position.distance_to(destionation)
	
	if agressive:
		nav_stop_theshold = 40
	else:
		nav_stop_theshold = 5
	
	if distance_to_distanation > nav_stop_theshold:
		move()
	else:
		update_path()
		
func move():
	#look_at(destionation)
	motion = (destionation - position).normalized() * rand_range(speed_range.x, speed_range.y)
	move_and_slide(motion)
	
func make_path():
	
	var next_destination
	
	if agressive:
		next_destination = target
	elif possible_destinations.size():
		randomize()
		next_destination = possible_destinations[randi() % possible_destinations.size()]

	if next_destination:
		path = navigation.get_simple_path(position, next_destination.position)
		#dest_location = navigation.get_simple_path(position, next_destination.position)
	
func update_path():
	if path.size() == 1:
		make_path()
	else:
		path.remove(0)

func get_random_location():
	var limits = get_viewport_rect().size
	return Vector2(rand_range(0, limits.x), rand_range(0, limits.y))

func calculate_motion_vars():
	#dest_location = get_random_location()
	make_path()
	if path.size():
		dest_location = path[1]
	
		count_time = position.distance_to(dest_location) / rand_range(speed_range.x, speed_range.y)
		current_time = 0
		start_pos = position
	#var angel = get_angle_to(dest_location) + (PI/2) # Angel is in radians
	#rotate(angel)

func update_state(state):
	position = state.location
	#rotation = state.rot
	#color = state.col
	#$icon.modulate = color
	health = state.health
	update_health_bar()

func _on_DetrctRadius_body_entered(body):
	check_agresive(true, body)

func _on_DetrctRadius_body_exited(body):
	check_agresive(false, body)

func check_agresive(agr, b):
	agressive = agr
	if agressive:
		$Body/Aggressive.modulate = Color(255, 0, 0)
		targets[b.name] = {name = b.name, target = b}
	else:
		$Body/Aggressive.modulate = Color(0, 255, 0)
		targets.erase(b.name)
	
	if targets.size() > 0:
		target = targets.values()[0].target
	else:
		target = null
		
	make_path()

func death():
	queue_free()

func take_damage(damage):
	health -= damage
	if health <= 0:
		death()
	
	update_health_bar()

func update_health_bar():
	$UnitDisplay/HealthBar.value = health
