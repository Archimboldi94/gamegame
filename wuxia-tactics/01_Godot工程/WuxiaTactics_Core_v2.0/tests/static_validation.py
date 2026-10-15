"""仅验证资源/数据契约；不解析或执行GDScript。"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / 'project.godot').read_text(encoding='utf-8')
assert 'res://scenes/Main.tscn' in project
for folder, pattern in [('scripts', '*.gd'), ('scenes', '*.tscn'), ('tests', '*.gd')]:
    for source in (ROOT / folder).glob(pattern):
        for dependency in re.findall(r'res://[^"\'\n]+', source.read_text(encoding='utf-8')):
            assert (ROOT / dependency.removeprefix('res://')).is_file(), (source.name, dependency)

mapdata = json.loads((ROOT / 'data/b1_map.json').read_text(encoding='utf-8'))
rows = mapdata['terrain_grid']
w, h = mapdata['width'], mapdata['height']
assert (w, h) == (12, 12)
assert len(rows) == h and all(len(row) == w for row in rows)
assert set(''.join(rows)) <= set('.~ChH#=m')
assert rows[7][3] == 'm' and rows[4][5] == 'C'
starting = {}
for marker, points in mapdata['markers'].items():
    assert len(points) == 1
    x, y = points[0]
    assert 0 <= x < w and 0 <= y < h and rows[y][x] not in '#~ChH'
    assert (x, y) not in starting.values()
    starting[marker] = (x, y)
assert len(starting) == 5
combat = json.loads((ROOT / 'data/b1_combat.json').read_text(encoding='utf-8'))
skills, units = combat['skills'], combat['units']
assert [unit['id'] for unit in units] == list(range(5))
assert [unit['side'] for unit in units].count('player') == 3
assert [unit['side'] for unit in units].count('enemy') == 2
assert {unit['marker'] for unit in units} == set(starting)
for unit in units:
    assert unit['marker'] in starting
    assert 0 < unit['hp'] <= unit['max_hp'] and 0 <= unit['qi'] <= 12
    assert tuple(unit['facing']) in [(x, y) for x in (-1, 0, 1) for y in (-1, 0, 1) if (x, y) != (0, 0)]
    assert len(unit['skills']) == (3 if unit['side'] == 'player' else 0)
    assert len(set(unit['skills'])) == len(unit['skills'])
    assert all(name in skills for name in unit['skills'])
    assert 'inner' in unit and unit['lightfoot'] in skills
for name, skill in skills.items():
    assert skill['ap'] >= 0 and skill['qi'] >= 0
    if 'power' in skill:
        assert skill['range'] > 0 and 0 < skill['base_hit'] <= 100
assert skills['回锋剑']['retreat_safe'] and skills['回锋剑']['retreat_once']
print('PASS: 场景/脚本资源引用、B1地图/部署、单位/武学JSON数据契约')
print('CAUTION: 静态检查不验证GDScript解析、输入或战斗运行；请继续运行Godot测试')
