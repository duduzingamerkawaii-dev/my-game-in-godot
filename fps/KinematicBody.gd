extends KinematicBody

# ===== MOVIMENTO =====
export var speed = 9.0
export var run_speed = 15.0
export var crouch_speed = 3.6
export var jump_force = 8.0
export var gravity = 20.0
export var mouse_sensitivity = 0.1
var velocity = Vector3.ZERO
var is_crouching = false
var is_running = false

# ===== HEAD BOB =====
var bob_time = 0.0
export var bob_speed = 8.0
export var bob_amount = 0.05

# ===== ARMA =====
export var weapon_bob_amount = 0.04
export var weapon_sway_amount = 0.3

onready var camera = $Camera
onready var weapon = $Camera/gun
onready var collision = $CollisionShape  # ajuste o nome se precisar

var weapon_origin = Vector3()
var camera_origin_y = 1.6
var camera_crouch_y = 0.8  # altura da camera agachado

# Altura da colisão
var collision_stand_height = 1.8
var collision_crouch_height = 0.9
var collision_stand_pos = Vector3(0, 0.9, 0)
var collision_crouch_pos = Vector3(0, 0.45, 0)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if weapon:
		weapon_origin = weapon.translation
	else:
		print("ERRO: Nó 'gun' não encontrado!")

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		camera.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)

	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	var direction = Vector3.ZERO

	# ===== AGACHAR =====
	# Troca entre toggle (pressionar uma vez) — mude para is_action_pressed se preferir segurar
	if Input.is_action_just_pressed("crouch"):
		if is_crouching:
			# Tenta levantar — checa se tem espaço acima
			if _can_stand_up():
				_set_crouch(false)
		else:
			_set_crouch(true)

	# ===== CORRIDA =====
	# Só corre se não estiver agachado
	is_running = Input.is_action_pressed("run") and not is_crouching

	# ===== VELOCIDADE ATUAL =====
	var current_speed = speed
	if is_crouching:
		current_speed = crouch_speed
	elif is_running:
		current_speed = run_speed

	# ===== MOVIMENTO =====
	if Input.is_action_pressed("ui_up"):
		direction -= transform.basis.z
	if Input.is_action_pressed("ui_down"):
		direction += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		direction += transform.basis.x

	direction = direction.normalized()
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# Gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Pulo — não pula agachado
	if is_on_floor() and not is_crouching and Input.is_action_just_pressed("jump"):
		velocity.y = jump_force

	velocity = move_and_slide(velocity, Vector3.UP)

	# ===== HEAD BOB =====
	var is_moving = Vector3(velocity.x, 0, velocity.z).length() > 0.1
	var target_bob_speed = bob_speed
	if is_running:
		target_bob_speed = bob_speed * 1.6
	elif is_crouching:
		target_bob_speed = bob_speed * 0.6

	if is_on_floor() and is_moving:
		bob_time += delta * target_bob_speed
	
	var target_cam_y = camera_origin_y if not is_crouching else camera_crouch_y
	if is_on_floor() and is_moving:
		target_cam_y += sin(bob_time) * bob_amount
	
	camera.translation.y = lerp(camera.translation.y, target_cam_y, delta * 12)
	camera.translation.x = lerp(
		camera.translation.x,
		cos(bob_time * 0.5) * bob_amount if (is_on_floor() and is_moving) else 0.0,
		delta * 12
	)

	# ===== WEAPON BOB =====
	if weapon:
		if is_on_floor() and is_moving:
			weapon.translation.x = weapon_origin.x + cos(bob_time * 0.5) * weapon_bob_amount
			weapon.translation.y = weapon_origin.y + sin(bob_time) * weapon_bob_amount
		else:
			weapon.translation = weapon.translation.linear_interpolate(weapon_origin, delta * 10)

# ===== FUNÇÕES AGACHAR =====
func _set_crouch(crouching: bool):
	is_crouching = crouching
	if collision:
		var shape = collision.shape
		if shape is CapsuleShape:
			shape.height = collision_crouch_height if crouching else collision_stand_height
		collision.translation = collision_crouch_pos if crouching else collision_stand_pos

func _can_stand_up() -> bool:
	# Raycast para checar se tem teto acima
	var space = get_world().direct_space_state
	var from = global_transform.origin
	var to = from + Vector3(0, collision_stand_height, 0)
	var result = space.intersect_ray(from, to, [self])
	return result.empty()  # true = livre para levantar
