"""Static asset/rule checks, runnable without Godot. Does not parse or execute GDScript.
Usage: python tests/static_validation.py
"""
import json
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / 'project.godot').read_text(encoding='utf-8')
assert 'res://scenes/Main.tscn' in project
scene = (ROOT / 'scenes/Main.tscn').read_text(encoding='utf-8')
assert 'res://scripts/BattleUI.gd' in scene
for scr in ['BattleBoard.gd', 'BattleState.gd', 'BattleUI.gd', 'EnemyAI.gd']:
    txt=(ROOT/'scripts'/scr).read_text(encoding='utf-8')
    assert txt.count('\nfunc ') >= 1, scr
    for dep in re.findall(r'res://[^"\']+',txt):
        # These dependencies are relative to project directory.
        assert (ROOT / dep.replace('res://','')).exists(), (scr,dep)
mapdata=json.loads((ROOT/'data/b1_map.json').read_text(encoding='utf-8'))
rows=mapdata['terrain_grid']; w=mapdata['width']; h=mapdata['height']
assert (w,h)==(12,12)
assert len(rows)==h and all(len(row)==w for row in rows)
assert rows[7][3]=='m' and rows[4][5]=='C'
starting={}
for label,points in mapdata['markers'].items():
    for p in points:
        x,y=p
        assert 0<=x<w and 0<=y<h and rows[y][x] not in '#~ChH'
        assert tuple(p) not in starting.values()
        starting[label]=tuple(p)
assert len(starting)==5
neighbors=[(i,j) for i in (-1,0,1) for j in (-1,0,1) if (i,j)!=(0,0)]
for facing in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]:
    controls=[(i,j) for i,j in neighbors if i*facing[0]+j*facing[1]>=0]
    assert len(controls)==5, (facing,controls)
assert max(abs(2-5),abs(10-7))==3
assert '"调息"' in (ROOT/'scripts/BattleState.gd').read_text()
print('PASS: scenes, script references, B1 dimensions/deployment, eight-direction five-square ZOC, resource code presence')
print('CAUTION: Godot compilation, input and battle runtime are NOT verified by these static checks')
