#!/usr/bin/env python3
"""Offline, hash-guarded patch for the diagnosed ESX/FivePRS versions.
Default is a read-only plan. No SQL, secrets or server.cfg are modified.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

SPEC = Path(__file__).resolve().parents[1] / 'compat/esx-1.16.3-fiveprs-ptb5.json'

def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()

def plan(root, spec=SPEC):
    root = Path(root).resolve(strict=True)
    result = []
    for change in json.loads(Path(spec).read_text(encoding='utf-8'))['changes']:
        path = root / change['path']
        resolved = path.resolve(strict=True)
        chain = [path, *path.parents]
        redirected = any(p.is_symlink() or (hasattr(p, 'is_junction') and p.is_junction()) for p in chain)
        if not resolved.is_relative_to(root / 'resources') or redirected:
            raise ValueError('Unsafe resource path: ' + change['path'])
        # Normalise only line endings/BOM for release files from Windows.
        text = path.read_text(encoding='utf-8-sig')
        if text == change['updated']:
            continue
        if digest(text) != change['sha256'] or text != change['original']:
            raise ValueError('Version/local modification mismatch: ' + change['path'])
        result.append((path, change['updated']))
    return result

def require_offline(confirmed):
    if not confirmed:
        raise ValueError('--server-stopped is required; keep txAdmin auto-restarts disabled during maintenance')
    if os.name != 'nt':
        raise ValueError('Applying this Windows compatibility patch requires Windows')
    proc = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq FXServer.exe', '/FO', 'CSV', '/NH'],
                          capture_output=True, text=True, check=True)
    if 'fxserver.exe' in proc.stdout.lower():
        raise ValueError('FXServer is running; no patch applied')

def atomic_write(path, text):
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        temp.write_text(text, encoding='utf-8', newline='\n')
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()

def apply(root, confirmed=False):
    changes = plan(root)  # Validate ALL inputs before creating a backup or editing.
    if not changes:
        return None
    require_offline(confirmed)
    root = Path(root).resolve()
    backup = root / '.linden-compat' / uuid.uuid4().hex
    backup.mkdir(parents=True)
    # Preserve original bytes, including BOM and CRLF, before the first mutation.
    for path, _ in changes:
        dest = backup / path.relative_to(root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
    changed = []
    try:
        for path, updated in changes:
            changed.append(path)
            atomic_write(path, updated)
    except Exception:
        for path in reversed(changed):
            shutil.copy2(backup / path.relative_to(root), path)
        raise
    return backup

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('server_data', type=Path)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--server-stopped', action='store_true')
    args = parser.parse_args()
    if args.apply:
        print('Backup:', apply(args.server_data, args.server_stopped) or 'already patched')
    else:
        for path, _ in plan(args.server_data):
            print('Would patch:', path.relative_to(args.server_data.resolve()))
