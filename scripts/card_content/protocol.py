"""Signed complete snapshots. No service implementation or credentials live here."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import re
import stat
import zipfile
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

ABI = 'godot-4.6-card-content-1'
MAX_OBJECT = 64 * 1024 * 1024
MAX_EXPANDED = 128 * 1024 * 1024
MAX_MANIFEST = 8 * 1024 * 1024
HEX = re.compile(r'^[0-9a-f]{64}$')
UID = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.-]*_[A-Za-z0-9][A-Za-z0-9.-]*$')
SCRIPT_ROOTS = ('scripts/effects/', 'scripts/engine/', 'scripts/data/', 'scripts/ai/ptcgdap/')


class ContentError(ValueError):
    def __init__(self, code='content_invalid'):
        self.code = code
        super().__init__(code)


def require(condition, code='content_invalid'):
    if not condition:
        raise ContentError(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def read_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate_json_key')
            result[key] = value
        return result
    try:
        return json.loads(data, object_pairs_hook=pairs, parse_constant=lambda _: require(False))
    except (ValueError, UnicodeError) as exc:
        raise ContentError('invalid_json') from exc


def allowed_path(path):
    if not isinstance(path, str) or len(path) > 240 or not re.fullmatch(r'[A-Za-z0-9_./-]+', path):
        return False
    if any(p in ('', '.', '..') for p in path.split('/')):
        return False
    if path.startswith(SCRIPT_ROOTS):
        return path.endswith(('.gd', '.gd.remap'))
    if path.startswith(('data/bundled_user/cards/', 'data/card_catalog/')):
        return path.endswith('.json')
    if path.startswith('contracts/ptcgdap/'):
        return path.endswith('.json') and not any(x in path.lower() for x in ('trust', 'signing', 'private', 'secret'))
    return False


def object_descriptor(data):
    return {'sha256': digest(data), 'size': len(data)}


def validate_object(item):
    require(type(item) is dict and set(item) == {'sha256', 'size'})
    require(isinstance(item['sha256'], str) and HEX.fullmatch(item['sha256']))
    require(type(item['size']) is int and 0 < item['size'] <= MAX_OBJECT)


def make_pack(files):
    """Raw GDScript + explicit remaps work with an already bytecode-exported base."""
    files = dict(files)
    require(bool(files), 'empty_pack')
    for path, data in list(files.items()):
        require(allowed_path(path) and not path.endswith('.remap'), 'pack_path_rejected')
        require(type(data) is bytes and 0 < len(data) <= MAX_OBJECT)
        if path.endswith('.gd'):
            # Keep the original script identity. Mapping to a hash-named .gd
            # changes its fully-qualified class path and breaks typed/preloaded
            # consumers in exported Godot 4.6. A self-remap shadows base .gdc.
            files[path + '.remap'] = f'[remap]\n\npath="res://{path}"\n'.encode()
    require(len({p.lower() for p in files}) == len(files), 'pack_path_collision')
    require(len(files) <= 20000 and sum(map(len, files.values())) <= MAX_EXPANDED)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, data in sorted(files.items()):
            info = zipfile.ZipInfo(path, (2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, data)
    blob = buffer.getvalue()
    descriptor = {**object_descriptor(blob), 'files': {p: object_descriptor(b) for p, b in sorted(files.items())}}
    validate_pack(blob, descriptor)
    return blob, descriptor


def validate_pack(blob, descriptor):
    require(len(blob) == descriptor['size'] and digest(blob) == descriptor['sha256'], 'object_hash_mismatch')
    expected = descriptor['files']
    try:
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            items = archive.infolist()
            require(len(items) == len(expected) <= 20000, 'pack_members_invalid')
            require(len({i.filename.lower() for i in items}) == len(items), 'pack_path_collision')
            require(sum(i.file_size for i in items) <= MAX_EXPANDED, 'pack_too_large')
            for item in items:
                require(allowed_path(item.filename) and item.filename in expected, 'pack_path_rejected')
                require(not stat.S_ISLNK(item.external_attr >> 16), 'pack_link_rejected')
                entry = expected[item.filename]
                require(item.file_size == entry['size'], 'pack_size_mismatch')
                data = archive.read(item)
                require(digest(data) == entry['sha256'], 'pack_hash_mismatch')
                if item.filename.endswith('.gd.remap'):
                    source = item.filename[:-6]
                    require(source in expected and data == f'[remap]\n\npath="res://{source}"\n'.encode(), 'pack_remap_invalid')
    except (zipfile.BadZipFile, RuntimeError, KeyError) as exc:
        raise ContentError('pack_invalid') from exc


def validate_manifest(value):
    required = {'schema_version', 'sequence', 'content_version', 'runtime_abi', 'min_client_version', 'platforms', 'notes', 'packs', 'cards'}
    require(type(value) is dict and set(value) == required, 'manifest_fields_invalid')
    require(type(value['schema_version']) is int and value['schema_version'] == 1)
    require(type(value['sequence']) is int and 0 < value['sequence'] <= 9007199254740991)
    require(isinstance(value['content_version'], str) and 0 < len(value['content_version']) <= 80)
    require(value['runtime_abi'] == ABI, 'runtime_incompatible')
    require(isinstance(value['min_client_version'], str) and re.fullmatch(r'\d+\.\d+\.\d+', value['min_client_version']))
    require(type(value['platforms']) is list and value['platforms'] and all(type(p) is str for p in value['platforms']))
    require(len(set(value['platforms'])) == len(value['platforms']))
    require(all(p in ('windows', 'android', 'linux', 'macos', 'web') for p in value['platforms']))
    require(isinstance(value['notes'], str) and len(value['notes']) <= 4000)
    require(type(value['packs']) is list and 0 < len(value['packs']) <= 32)
    paths, digests, expanded = {}, set(), 0
    for pack in value['packs']:
        require(type(pack) is dict and set(pack) == {'sha256', 'size', 'files'})
        validate_object({k: pack[k] for k in ('sha256', 'size')})
        require(pack['sha256'] not in digests); digests.add(pack['sha256'])
        require(type(pack['files']) is dict and 0 < len(pack['files']) <= 20000)
        for path, entry in pack['files'].items():
            require(allowed_path(path), 'pack_path_rejected'); validate_object(entry)
            require(path.lower() not in paths, 'pack_path_collision')
            paths[path.lower()] = entry
            expanded += entry['size']
    require(expanded <= MAX_EXPANDED, 'release_too_large')
    require(type(value['cards']) is dict and 0 < len(value['cards']) <= 30000)
    for uid, entry in value['cards'].items():
        require(bool(UID.fullmatch(uid)) and type(entry) is dict and set(entry) == {'source_sha256', 'image'})
        source = paths.get(f'data/bundled_user/cards/{uid}.json'.lower())
        require(source is not None and source['sha256'] == entry['source_sha256'], 'card_source_missing')
        require(entry['image'] is None or type(entry['image']) is dict)
        if entry['image'] is not None:
            validate_object(entry['image'])
    require(len(json_bytes(value)) <= MAX_MANIFEST, 'manifest_too_large')
    return value


def sign_manifest(manifest, key_id, key):
    validate_manifest(manifest)
    require(isinstance(key, rsa.RSAPrivateKey) and key.key_size >= 2048)
    payload = json_bytes(manifest)
    signature = key.sign(payload, padding.PKCS1v15(), hashes.SHA256())
    return {'schema_version': 1, 'key_id': key_id, 'payload': base64.b64encode(payload).decode(), 'signature': base64.b64encode(signature).decode()}


def verify_envelope(envelope, trust):
    require(type(envelope) is dict and set(envelope) == {'schema_version', 'key_id', 'payload', 'signature'}, 'envelope_invalid')
    require(type(envelope['schema_version']) is int and envelope['schema_version'] == 1 and
            type(envelope['key_id']) is str and envelope['key_id'] in trust, 'signature_untrusted')
    require(type(envelope['payload']) is str and len(envelope['payload']) <= MAX_MANIFEST * 2 and
            type(envelope['signature']) is str and len(envelope['signature']) <= 2048 and
            type(trust[envelope['key_id']]) is str, 'envelope_invalid')
    try:
        payload = base64.b64decode(envelope['payload'], validate=True)
        signature = base64.b64decode(envelope['signature'], validate=True)
        require(len(payload) <= MAX_MANIFEST)
        key = serialization.load_pem_public_key(trust[envelope['key_id']].encode())
        require(isinstance(key, rsa.RSAPublicKey) and key.key_size >= 2048)
        key.verify(signature, payload, padding.PKCS1v15(), hashes.SHA256())
    except (ValueError, TypeError, InvalidSignature) as exc:
        raise ContentError('signature_invalid') from exc
    return validate_manifest(read_json(payload))


def release_id(envelope):
    return digest(base64.b64decode(envelope['payload'], validate=True))


def script_classes(files):
    classes = {}
    for path, raw in files.items():
        if not path.endswith('.gd'): continue
        match = re.search(r'^class_name\s+([A-Za-z_][A-Za-z_0-9]*)\b', raw.decode('utf-8-sig'), re.M)
        if match:
            require(match[1] not in classes, 'duplicate_global_class')
            classes[match[1]] = path
    return classes


def _identifiers(source):
    """Scan identifiers without interpreting quoted strings or comments."""
    tokens, index = set(), 0
    while index < len(source):
        char = source[index]
        if char == '#':
            end = source.find('\n', index); index = len(source) if end < 0 else end + 1
        elif char in ('"', "'"):
            quote = char * 3 if source[index:index+3] == char * 3 else char
            index += len(quote)
            while index < len(source):
                if source[index] == '\\': index += 2
                elif source.startswith(quote, index): index += len(quote); break
                else: index += 1
        elif char.isalpha() or char == '_':
            start=index; index += 1
            while index < len(source) and (source[index].isalnum() or source[index]=='_'): index += 1
            tokens.add(source[start:index])
        else: index += 1
    return tokens


def bind_new_classes(groups, base_classes):
    files = {path: raw for group in groups.values() for path, raw in group.items()}
    classes = script_classes(files)
    for name, path in classes.items():
        require(name not in base_classes or base_classes[name] == path, 'base_class_path_changed')
    added = {name:path for name,path in classes.items() if name not in base_classes}
    for group in groups.values():
        for path, raw in list(group.items()):
            if not path.endswith('.gd') or not added: continue
            source=raw.decode('utf-8-sig')
            needed=[]
            for name in sorted(_identifiers(source) & added.keys()):
                if path == added[name] or re.search(r'^(?:const|var|class)\s+'+re.escape(name)+r'\b', source, re.M): continue
                source=re.sub(r'^extends\s+'+re.escape(name)+r'\s*$', 'extends "res://'+added[name]+'"', source, flags=re.M)
                needed.append(f'const {name} = preload("res://{added[name]}")\n')
            if needed:
                lines=source.splitlines(keepends=True)
                insertion=max((i+1 for i,line in enumerate(lines) if line.startswith(('extends ', 'class_name '))),default=0)
                lines[insertion:insertion]=['\n# Explicit imports for classes added after the frozen client.\n',*needed,'\n']
                group[path]=''.join(lines).encode('utf-8')


def build_release(root, *, sequence, version, minimum, notes='', platforms=None):
    root = Path(root).resolve()
    groups = {}
    for prefix in (*SCRIPT_ROOTS, 'contracts/ptcgdap/', 'data/card_catalog/', 'data/bundled_user/cards/'):
        files = {}
        for file in sorted((root / prefix).rglob('*')):
            if not file.is_file(): continue
            path = file.relative_to(root).as_posix()
            if not allowed_path(path) or path.endswith('.remap'): continue
            require(not file.is_symlink() and file.resolve().is_relative_to(root), 'source_link_rejected')
            files[path] = file.read_bytes()
        if files: groups[prefix] = files
    objects, packs, cards = {}, [], {}
    baseline = root / 'data/card_content/runtime_classes.json'
    base_classes = read_json(baseline.read_bytes()).get('classes', {}) if baseline.exists() else {}
    bind_new_classes(groups, base_classes)
    for files in groups.values():
        blob, descriptor = make_pack(files)
        objects[descriptor['sha256']] = blob; packs.append(descriptor)
    for path, raw in groups.get('data/bundled_user/cards/', {}).items():
        uid = Path(path).stem
        card = read_json(raw)
        require(UID.fullmatch(uid) and f'{card.get("set_code")}_{card.get("card_index")}' == uid, 'card_identity_invalid')
        image = root / 'data/bundled_user/cards/images' / card['set_code'] / (card['card_index'] + '.png.bin')
        if not image.exists() and card['set_code'] == '30thC':
            image = root / 'data/bundled_user/cards/images/30THC' / (card['card_index'] + '.png.bin')
        descriptor = None
        if image.is_file():
            require(not image.is_symlink(), 'source_link_rejected')
            blob = image.read_bytes(); descriptor = object_descriptor(blob)
            objects[descriptor['sha256']] = blob
        cards[uid] = {'source_sha256': digest(raw), 'image': descriptor}
    manifest = {'schema_version': 1, 'sequence': sequence, 'content_version': version,
        'runtime_abi': ABI, 'min_client_version': minimum,
        'platforms': platforms or ['windows', 'android', 'linux', 'macos'],
        'notes': notes, 'packs': packs, 'cards': cards}
    return validate_manifest(manifest), objects
