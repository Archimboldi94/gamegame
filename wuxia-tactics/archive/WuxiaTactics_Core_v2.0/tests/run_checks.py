"""BOX可重复验证入口；只重定向本进程的XDG目录，不更改工程或全局用户环境。"""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'artifacts'
LOGS.mkdir(exist_ok=True)
GODOT = os.environ.get('GODOT_BIN', '/home/box/.local/bin/godot')
ENV = os.environ.copy()
for key, leaf in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
    directory = Path(tempfile.gettempdir()) / 'wuxia-core-validation' / leaf
    directory.mkdir(parents=True, exist_ok=True)
    ENV[key] = str(directory)
steps = [
    ('static', [sys.executable, 'tests/static_validation.py']),
    ('editor', [GODOT, '--headless', '--path', '.', '--editor', '--quit-after', '2']),
    ('import', [GODOT, '--headless', '--path', '.', '--import']),
    ('combat', [GODOT, '--headless', '--path', '.', '--script', 'res://tests/CombatTests.gd']),
    ('ui', [GODOT, '--headless', '--path', '.', '--script', 'res://tests/UITests.gd']),
    ('main', [GODOT, '--headless', '--path', '.', '--quit-after', '120']),
]
failed = False
summary = []
for name, command in steps:
    try:
        run = subprocess.run(command, cwd=ROOT, env=ENV, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        output, code = run.stdout, run.returncode
    except (OSError, subprocess.TimeoutExpired) as error:
        output, code = str(error), -1
    (LOGS / f'final_{name}.log').write_text(output, encoding='utf-8')
    error_lines = re.findall(r'^(?:SCRIPT )?ERROR:.*$|^.*Parse Error:.*$', output, re.M)
    allowed_socket_errors = [
        'ERROR: Condition "_sock == -1" is true. Returning: FAILED',
        'ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE',
    ]
    # 仅编辑器的两个确定的沙箱TCP监听错误可列作环境限制；其他错误一律失败。
    sandbox_socket = name in ('editor', 'import') and bool(error_lines) and len(error_lines) % 2 == 0 and error_lines == allowed_socket_errors * (len(error_lines) // 2) and 'drivers/unix/net_socket_unix.cpp' in output and 'core/io/tcp_server.cpp' in output
    bad = code != 0 or (bool(error_lines) and not sandbox_socket) or 'instances leaked' in output or 'FAIL:' in output
    if name == 'combat':
        bad = bad or not re.search(r'TEST RESULT: \d+ checks, 0 failures', output)
    if name == 'ui':
        bad = bad or not re.search(r'UI TEST RESULT: \d+ checks, 0 failures', output)
    failed |= bad
    status = 'FAIL' if bad else ('PASS（沙箱TCP监听受限）' if sandbox_socket else 'PASS')
    line = f'{name}: {status}; exit={code}; log=artifacts/final_{name}.log'
    summary.append(line)
    print(line)
    for result in output.splitlines():
        if 'TEST RESULT:' in result or result.startswith('B1 '):
            print('  ' + result)
(LOGS / 'final_summary.log').write_text('\n'.join(summary) + '\n', encoding='utf-8')
sys.exit(1 if failed else 0)
