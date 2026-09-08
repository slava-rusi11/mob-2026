extends VehicleBody3D
## Контроллер тележки: вперёд / назад / влево / вправо + тормоз.

# ─────────────── Настройки ───────────────

@export_group("Движение")
## Тяга вперёд. Для тележки массой ~50 кг хватит 80–150.
@export var max_engine_force := 120.0
## Тяга назад — обычно слабее.
@export var max_reverse_force := 60.0
## Максимальная скорость вперёд, м/с (10 м/с ≈ 36 км/ч).
@export var max_speed := 10.0
## Максимальная скорость назад, м/с.
@export var max_reverse_speed := 4.0

@export_group("Руль")
## Максимальный угол поворота колёс, радианы (0.5 ≈ 28°).
@export var max_steer := 0.5
## Скорость поворота руля, рад/с.
@export var steer_speed := 3.0
## Возврат руля в ноль — быстрее, чем поворот.
@export var steer_return_speed := 6.0
## 0..1 — насколько душить руль на скорости (антипереворот).
## 0.6 = на максималке угол уменьшится до 40%.
@export var steer_reduction := 0.6

@export_group("Тормоз")
@export var brake_force := 30.0
## Лёгкое торможение почти на месте, чтобы тележка не «ползла».
@export var parking_brake := 10.0

# ─────────────── Служебное ───────────────

signal speed_changed(kmh: float)

var _speed_forward := 0.0  # скорость вдоль «вперёд» (−Z), со знаком


func _physics_process(delta: float) -> void:
	# get_axis(отрицательное действие, положительное) → −1…+1
	var steer_input := Input.get_axis("ui_right", "ui_left")
	var throttle    := Input.get_axis("ui_down", "ui_up")
	var braking     := Input.is_action_pressed("brake") # Тормоз.

	# Скорость «вперёд» = проекция скорости на ось −Z тележки
	_speed_forward = linear_velocity.dot(global_transform.basis.z)
	speed_changed.emit(absf(_speed_forward) * 3.6)

	_update_steering(steer_input, delta)
	_update_engine(throttle, braking)
	
	# -------|
	# Дебаг  |
	#--------:
	if Engine.get_physics_frames() % 60 == 0:
		print("speed=%.2f  engine=%.1f  brake=%.1f  damp=%.2f" %
			[_speed_forward, engine_force, brake, linear_damp])


# ─────────────── Руль ───────────────

func _update_steering(steer_input: float, delta: float) -> void:
	# На высокой скорости ограничиваем угол, иначе переворот:
	# 0 м/с → полный угол, max_speed → угол × (1 − steer_reduction)
	var speed01 := clampf(absf(_speed_forward) / max_speed, 0.0, 1.0)
	var steer_limit := max_steer * lerpf(1.0, 1.0 - steer_reduction, speed01)
	var target := steer_input * steer_limit

	# К нулю руль возвращается быстрее, чем поворачивается
	var rate := steer_speed if absf(target) > absf(steering) else steer_return_speed
	steering = move_toward(steering, target, rate * delta)


# ─────────────── Движение ───────────────

func _update_engine(throttle: float, braking: bool) -> void:
	engine_force = 0.0
	brake = 0.0

	if braking:
		brake = brake_force
		return

	if throttle > 0.0:
		if _speed_forward < -1.0:
			# Катимся назад, жмём «вперёд» → сначала тормозим
			brake = brake_force
		else:
			# Плавная отсечка: последние 2 м/с до max_speed сила гасится
			var cutoff := clampf((max_speed - _speed_forward) / 2.0, 0.0, 1.0)
			engine_force = throttle * max_engine_force * cutoff

	elif throttle < 0.0:
		if _speed_forward > 1.0:
			# Едем вперёд, жмём «назад» → тормозим, реверс включится почти с места
			brake = brake_force
		else:
			# Исправлено: было (-max_reverse_speed - _speed_forward) — знак перепутан
			var cutoff := clampf((max_reverse_speed + _speed_forward) / 1.5, 0.0, 1.0)
			engine_force = throttle * max_reverse_force * cutoff

	else:
		if absf(_speed_forward) < 0.5:
			brake = parking_brake


# ─────────────── Бонус: сброс при перевороте ───────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_cart"):
		reset_cart()


func reset_cart() -> void:
	## Ставит тележку на колёса там, где перевернулась.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD

	global_transform = Transform3D(
		Basis.looking_at(forward, Vector3.UP),
		global_position + Vector3.UP * 0.6
	)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering = 0.0
