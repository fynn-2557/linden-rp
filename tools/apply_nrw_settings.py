#!/usr/bin/env python3
"""Apply German RP display settings to the supplied FivePRS PTB.5 resource.
Backs up each touched file before changing; does not patch compiled core.
"""
from pathlib import Path
import json
import shutil
import sys

RANKS = {
    'police': [
      'Polizeikommissar/-in', 'Polizeioberkommissar/-in',
      'Polizeihauptkommissar/-in', 'Erste/-r Polizeihauptkommissar/-in',
      'Polizeirat/-rätin', 'Polizeioberrat/-rätin',
      'Polizeidirektor/-in', 'Leitende/-r Polizeidirektor/-in'
    ],
    'fire': [
      'Brandmeister/-in', 'Oberbrandmeister/-in', 'Hauptbrandmeister/-in',
      'Brandinspektor/-in', 'Brandoberinspektor/-in',
      'Brandamtmann/-frau', 'Brandamtsrat/-rätin',
      'Brandoberamtsrat/-rätin', 'Brandrat/-rätin',
      'Brandoberrat/-rätin', 'Branddirektor/-in'
    ],
    'ems': [
      'Rettungsdienst-Anwärter/-in (RP)', 'Rettungshelfer/-in',
      'Rettungssanitäter/-in', 'Notfallsanitäter/-in'
    ]
}

def change(file, fn):
    if not file.is_file():
        raise SystemExit(f'Fehlt: {file}')
    original = json.loads(file.read_text(encoding='utf-8-sig'))
    updated = fn(original)
    backup = file.with_name(file.name + '.rpbackup')
    if not backup.exists():
        shutil.copy2(file, backup)
    file.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Aktualisiert:', file, '(Backup:', backup.name + ')')
    return updated

def main(root):
    if not (root/'fxmanifest.lua').is_file() or not (root/'config/settings.json').is_file():
        raise SystemExit('Bitte den FivePRS-Ressourcenordner mit fxmanifest.lua angeben.')
    # FivePRS PTB.5 has no documented 'xpEnabled' setting. Do not claim to disable XP.
    # Character cap and backend XP/ranks MUST be handled in a separate core adaptation.
    for dept, names in RANKS.items():
        def ranks(data, names=names):
            original=data.get('ranks',[])
            # Do not set every XP threshold to zero: it could unlock all ranks instantly.
            # Preserve native XP thresholds and tier values while changing display names only.
            data['ranks']=[dict(row, name=names[i] if i<len(names) else row['name'])
                          for i,row in enumerate(original)]
            return data
        change(root/'config/departments'/dept/'ranks.json',ranks)
    print('WARNUNG: Dies ändert NUR Anzeigenamen. FivePRS-XP, Ränge und Rechte bleiben NATIV aktiv.')

if __name__=='__main__':
    if len(sys.argv)!=2: raise SystemExit('Aufruf: python tools/apply_nrw_settings.py /pfad/zu/resources/fiveprs')
    main(Path(sys.argv[1]).resolve())
