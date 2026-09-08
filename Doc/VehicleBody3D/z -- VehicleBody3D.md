Для этого в Godot есть готовый инструмент — **`VehicleBody3D` + `VehicleWheel3D`**. Колёса там не сталкиваются с рельефом физической формой, а «стреляют» вниз рейкастом и симулируют пружину подвески — именно поэтому такая машина стабильно и реалистично едет по неровностям. Вариант «RigidBody + 4 цилиндра-коллайдера» не советую: колёса будут дёргаться и застревать на стыках меши.

(Кстати, версии 4.7.2 не существует — вероятно, у вас 4.2.x. Всё ниже одинаково для любого Godot 4.)

## Структура сцены

```
Cart (VehicleBody3D)
├── FrameMesh (MeshInstance3D)
├── Collision (CollisionShape3D → BoxShape3D)
├── WheelFL (VehicleWheel3D)
│   └── MeshFL (MeshInstance3D)
├── WheelFR (VehicleWheel3D)
│   └── MeshFR
├── WheelRL (VehicleWheel3D)
│   └── MeshRL
└── WheelRR (VehicleWheel3D)
    └── MeshRR
```

Меши колёс — обязательно **дочерние узлы VehicleWheel3D**: физика сама будет двигать и вращать их.

## Порядок настройки

1. **Рама.** `VehicleBody3D` ставьте в центр рамы. Коллизия — Box по габаритам, но чуть меньше, чтобы не касалась земли и колёс. Задайте `mass` (например 40–100).
2. **У колёс не должно быть физики.** У мешей колёс никаких CollisionShape — колесо это рейкаст, коллайдер сломает поведение.
3. **Меш колеса**: origin в центре колеса (если нет — вложите в пустой узел и сдвиньте), масштаб строго 1 (радиус задаётся числом, scale всё ломает). Колесо вращается вокруг локальной оси **X** узла — если цилиндрический меш «стоит» по Y, поверните меш внутри узла на 90° по Z.
4. **Позиция VehicleWheel3D** — это точка крепления подвески, рейкаст идёт вниз по −Y. Поставьте узел в месте колеса из вашей модели, но на `wheel_rest_length` **выше** центра колеса. Спавните тележку чуть выше земли и дайте подвеске «сесть».
5. **Стартовые значения колеса** (потом тюнить):
   - `wheel_radius` — точный радиус меша
   - `wheel_rest_length` ≈ 0.1
   - `suspension_travel` ≈ 0.15
   - `suspension_stiffness` ≈ 20 (тяжелее тележка → больше)
   - `suspension_max_force` — примерно (масса/4 × 9.8) × 3–5
   - `damping_compression` ≈ 0.3, `damping_relaxation` ≈ 0.5
   - `wheel_friction_slip` 10.5 (меньше — скользит)
   - `use_as_traction` — на ведущих колёсах, `use_as_steering` — на поворотных

## Рельеф

Меш без коллайдера — тележка провалится. Для импортированной модели: Import-панель → **Physics → Generate Collision Shape** (Trimesh) → переимпортировать. Или выделить MeshInstance → меню сверху **Mesh → Create Collision Shape** → Static Body (Concave Polygon). Для Terrain — HeightMapShape.

## Управление

```gdscript
extends VehicleBody3D

@export var max_engine_force := 100.0
@export var max_steer := 0.5   # ~28°
@export var steer_speed := 3.0
@export var brake_force := 5.0

func _physics_process(delta: float) -> void:
	steering = lerpf(steering, Input.get_axis("ui_right", "ui_left") * max_steer, delta * steer_speed)
	engine_force = Input.get_axis("ui_down", "ui_up") * max_engine_force
	brake = brake_force if Input.is_action_pressed("ui_accept") else 0.0
```

(если руль или газ инвертированы — поменяйте местами аргументы `get_axis`)

Если тележка **не моторизованная** (её толкают/катит с горки) — `engine_force` не нужен вообще, ничего не помечайте как traction:

```gdscript
func _physics_process(_delta):
	if Input.is_action_pressed("ui_up"):
		apply_central_force(-global_transform.basis.z * 150.0)  # толкаем вперёд (−Z)
```

## Тюнинг по симптомам

| Симптом | Лечение |
|---|---|
| Проседает до отбойника | ↑ `suspension_stiffness`, ↑ `suspension_max_force` |
| Скачет по мелким кочкам | ↑ damping (0.3→0.7), ↓ stiffness, ↑ `suspension_travel` |
| Опрокидывается | `center_of_mass_mode = Custom` и опустить центр масс, ↓ `rest_length`, ↓ `wheel_roll_influence` |
| Скользит на склонах | ↑ `friction_slip` |
| Визуально дрожит/рывками (физика 60 Гц) | включить **Physics Interpolation** (Project Settings → Physics → Common, с версии 4.3) или плавную камеру |
| Мелкие камни сильно трясут | Physics Ticks Per Second → 120 |

## Частые грабли

- Спавн вплотную к земле → подвеска «выстрелит» вверх. Спавните чуть выше.
- Колёса визуально смещены/повёрнуты — origin меша не в центре колеса или меш не повёрнут по оси X.
- `VehicleWheel3D` нельзя масштабировать узлом — только реальный размер меша.
- «Вперёд» тележки — −Z (как у всех нод Godot): если модель смотрит иначе — поверните меши, а не логику.

Если тележка всё равно ведёт себя странно — начните с дефолтных значений колеса и меняйте **по одному** параметру за раз, так быстрее поймёте, что именно влияет.