extends Area2D

export (int) var speed
export (int) var damage
export (float) var lifetime
export (bool) var updated
export (int) var type		# player or enemy
var id						# bullet index
var position_to = 0
var position_from = 0
var not_updeted_time = 0

var velocity = Vector2()

func start(_position, _direction):
	position = _position
	rotation = _direction.angle()
	$LifeTimer.wait_time = lifetime
	$LifeTimer.start()
	velocity = _direction * speed
	
func set_type(_type):
	type = _type
	
func _process(delta):
	if get_tree().is_network_server():
		position += velocity * delta
	else:
		if updated:
			not_updeted_time = 0
			show()
		else:
			not_updeted_time += delta
			if not_updeted_time > 0.5:
				hide()
			
#		var alpha = delta / Gamestate.update_delta
#		position = lerp(position_from, position_to, alpha)

func explode():
	queue_free()
	
func _on_LifeTimer_timeout():
	explode()

func _on_Bullet_body_entered(body):
	if get_tree().is_network_server():
		explode()
		if body.has_method('take_damage'):
			body.take_damage(damage)

func update_state(state):
#	position_to = state.location
#	position_from = position
	updated = true
	position = state.location
