extends Node2D
## 挂在BattleScene（其中有名为Ground的TileMapLayer）。
## 鼠标/画面坐标 <-> 战棋逻辑格；不要在业务逻辑中手算菱形投影。
@onready var ground: TileMapLayer = $Ground

func mouse_cell() -> Vector2i:
    var mouse_world: Vector2 = get_global_mouse_position()
    return ground.local_to_map(ground.to_local(mouse_world))

func cell_world_center(cell: Vector2i) -> Vector2:
    return ground.to_global(ground.map_to_local(cell))

## 逻辑规则仍须由BattleGrid检查：地图边界、占用、地形、墙角和AP。
