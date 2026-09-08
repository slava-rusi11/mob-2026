extends VehicleBody3D

@export var engine_power = 40.0    # Сила мотора (для массы 1000 ставьте 30-50)
@export var steering_angle = 0.6   # Угол поворота колес в радианах (~35 градусов)
@export var brake_strength = 5.0   # Сила торможения

func _physics_process(delta):
	# Обработка газа
	var acceleration = 0.0
	if Input.is_action_pressed("move_forward"):
		acceleration = engine_power
	if Input.is_action_pressed("move_backward"):
		acceleration = -engine_power  # Едем назад
		
	# Обработка тормоза (обычно пробел)
	var braking = 0.0
	if Input.is_action_pressed("brake"):
		braking = brake_strength

	# Обработка поворота руля
	var turn = 0.0
	if Input.is_action_pressed("steer_left"):
		turn -= 1.0
	if Input.is_action_pressed("steer_right"):
		turn += 1.0
	var steering = turn * steering_angle

	# Применяем значения к физическому телу
	engine_force = acceleration
	steering = steering   # Обратите внимание: переменная называется так же, как метод, но работает
	brake = braking
