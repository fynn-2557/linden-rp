#!/usr/bin/env python3
"""Optional UI-only patch: hide FivePRS's old Characters icon on the terminal home screen.
The original server-side handler remains active; this patch is NOT an authorization barrier.
Run: python tools/patch_fiveprs_characters.py path/to/resources/fiveprs
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit('Usage: python tools/patch_fiveprs_characters.py <fiveprs resource path>')
file = Path(sys.argv[1]) / 'nui' / 'app.js'
original = file.read_text(encoding='utf-8')
old = 'return [...(state.apps ?? [])].sort((a, b) => a.order - b.order);'
new = "return [...(state.apps ?? [])].filter(a => a.id !== 'characters').sort((a, b) => a.order - b.order);"
if new in original:
    print('Already patched')
elif original.count(old) == 1:
    file.with_suffix('.js.backup').write_text(original, encoding='utf-8')
    file.write_text(original.replace(old,new), encoding='utf-8')
    print('FivePRS native Characters tile hidden; backup: app.js.backup')
else:
    raise SystemExit('Version mismatch: expected app.js string not found; no changes made.')
