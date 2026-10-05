"""Reject 3D arena media in 2D exports, including Godot's imported copies."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.ptcgdap.canonicalize_godot_export import read_pck_members

IMPORTED_PATH = re.compile(r'"res://(\.godot/imported/[^"\r\n]+)"')


def read_export(path: Path) -> dict[str, bytes]:
    if path.suffix.lower() == '.pck':
        return read_pck_members(path.read_bytes())
    prefix = 'assets/' if path.suffix.lower() == '.apk' else ''
    with zipfile.ZipFile(path) as archive:
        # Only remap descriptors need payloads; texture/model presence is enough.
        return {info.filename[len(prefix):]: archive.read(info) if info.filename.endswith('.import') else b''
                for info in archive.infolist() if not info.is_dir() and info.filename.startswith(prefix)}


def required_2d_resources(root: Path) -> list[str]:
    backgrounds = [f'assets/ui/background{i or ""}.png' for i in range(5)]
    registry = (root / 'scripts/ui/battle/BattleAttackVfxRegistry.gd').read_text(encoding='utf-8-sig')
    vfx = re.findall(r'"res://(assets/[^"\r\n]+\.(?:png|jpg|webp))"', registry)
    return sorted(set(backgrounds + vfx))


def inspect_members(members: dict[str, bytes], root: Path, required: list[str], arena_mode: str = '2d') -> dict:
    # Portable exports retain every authored actor/pose, using baked LODs.
    # Derive completeness from desktop sources, not the exported manifest alone.
    allowed = set()
    if arena_mode == 'portable':
        allowed = {'assets/arena3d/previews/grove.png', 'assets/arena3d/portable/manifest.json',
                   'assets/arena3d/portable/grove_table.glb', 'assets/arena3d/portable/reward_cradle.glb'}
        for source in (root / 'assets/arena3d/pokemon').glob('*.glb'):
            allowed.add('assets/arena3d/portable/pokemon/' + source.name)
        for source in (root / 'assets/arena3d/supporters').rglob('*.png'):
            allowed.add('assets/arena3d/portable/' + source.relative_to(root / 'assets/arena3d').as_posix())
        # Godot extracts embedded GLB diffuse images beside the portable model.
        for source in (root / 'assets/arena3d/portable').glob('grove_table_*'):
            if source.suffix in ['.png', '.jpg']:
                allowed.add(source.relative_to(root).as_posix())
        for directory in ['pokemon/audio', 'pokemon/vfx', 'supporters/audio']:
            for source in (root / 'assets/arena3d' / directory).rglob('*'):
                if source.is_file() and source.suffix in ['.wav', '.png']:
                    allowed.add(('assets/arena3d/portable/' + source.relative_to(root / 'assets/arena3d').with_suffix('.ogg').as_posix()) if source.suffix == '.wav' else source.relative_to(root).as_posix())
    required = list(required) + sorted(allowed)
    allowed_members = set(allowed) | {p + '.import' for p in allowed}
    for source in allowed:
        descriptor = root / (source + '.import')
        if descriptor.is_file():
            allowed_members.update(IMPORTED_PATH.findall(descriptor.read_text(encoding='utf-8-sig')))
    imported_arena = set()
    for descriptor in (root / 'assets/arena3d').rglob('*.import'):
        imported_arena.update(IMPORTED_PATH.findall(descriptor.read_text(encoding='utf-8-sig')))
    forbidden = sorted(name for name in members if (name.startswith('assets/arena3d/') or name in imported_arena) and name not in allowed_members)
    missing = []
    for source in required:
        if source in members:
            continue
        descriptor = members.get(source + '.import', b'').decode('utf-8-sig')
        targets = set(IMPORTED_PATH.findall(descriptor))
        if not targets or not targets.issubset(members):
            missing.append(source)
    return {'schema_version': 1, 'arena_mode': arena_mode, 'passed': not forbidden and not missing,
            'member_count': len(members), 'arena_import_targets_checked': len(imported_arena),
            'required_2d_resource_count': len(required), 'forbidden_members': forbidden,
            'missing_resources': missing}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--arena-mode', choices=['2d', 'portable'], default='2d')
    args = parser.parse_args()
    try:
        result = inspect_members(read_export(args.archive), args.root, required_2d_resources(args.root), args.arena_mode)
        with args.archive.open('rb') as stream:
            result.update(archive=str(args.archive.resolve()), bytes=args.archive.stat().st_size,
                          sha256=hashlib.file_digest(stream, 'sha256').hexdigest())
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        result = {'schema_version': 1, 'passed': False, 'error': str(exc)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
