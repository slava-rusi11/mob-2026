extends Node3D

@export var wheel_speed: float = 5.0
@export var wheel_radius: float = 0.3
@export var max_forward_speed: float = 10.0
@export var max_backward_speed: float = 5.0
@export var max_turn_speed: float = 2.0  # Скорость поворота
@export var acceleration: float = 8.0
@export var deceleration: float = 12.0

# Пути к узлам колес
@export var wheel_front_left: NodePath
@export var wheel_front_right: NodePath
@export var wheel_back_left: NodePath
@export var wheel_back_right: NodePath

var current_speed: float = 0.0
var target_speed: float = 0.0
var current_turn: float = 0.0
var wheel_nodes: Array = []

func _ready():
	# Собираем колеса
	var paths = [wheel_front_left, wheel_front_right, wheel_back_left, wheel_back_right]
	for path in paths:
		if path:
			var node = get_node(path)
			if node:
				wheel_nodes.append(node)
	
	if wheel_nodes.is_empty():
		find_wheels_automatically()

func _process(delta: float) -> void:
	# Ввод с клавиатуры
	var forward_input = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var turn_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	
	# Вычисляем целевую скорость
	if forward_input > 0:
		target_speed = forward_input * max_forward_speed
	elif forward_input < 0:
		target_speed = forward_input * max_backward_speed
	else:
		target_speed = 0.0
	
	# Плавное изменение скорости
	if abs(target_speed) > abs(current_speed):
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, target_speed, deceleration * delta)
	
	# Вычисляем поворот (чем выше скорость, тем меньше поворот)
	if abs(current_speed) > 0.1:
		current_turn = turn_input * max_turn_speed * (1.0 - abs(current_speed) / max_forward_speed * 0.7)
	else:
		current_turn = 0.0
	
	# Движение с поворотом
	var direction = transform.basis.z  # Направление вперед (ось Z)
	global_position += direction * current_speed * delta
	
	# Поворот тележки
	rotate_y(current_turn * delta)
	
	# Вращаем колеса
	rotate_wheels(delta)

func rotate_wheels(delta: float) -> void:
	var angular_speed = current_speed / wheel_radius
	
	var cnt = 0
	
	for wheel in wheel_nodes:
		if wheel is Node3D:
			# Учитываем поворот передних колес
			var is_front = false
			var wheel_name = wheel.name.to_lower()
			if "front" in wheel_name or "перед" in wheel_name:
				is_front = true
			
			# Вращаем колесо
			if is_front and abs(current_turn) > 0.01:
				# Передние колеса поворачиваются
				wheel.rotation.y = current_turn * 0.5
			
			# Вращение колеса вокруг своей оси
			if cnt % 2 == 0:
				wheel.rotation.x -= angular_speed * delta
			else:
				wheel.rotation.x += angular_speed * delta
			
			cnt += 1

func find_wheels_automatically() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is Node3D:
			var name_lower = child.name.to_lower()
			if "wheel" in name_lower or "колесо" in name_lower:
				wheel_nodes.append(child)
				print("Найдено колесо: ", child.name)
