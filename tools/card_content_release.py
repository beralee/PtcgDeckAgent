"""First-party content publisher. Never rebuilds the player application.

python tools/card_content_release.py --help
Signing private keys belong outside the repository. HTTP credentials are read
from PTCG_CARD_CONTENT_ADMIN_TOKEN or an explicit admin session file.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from scripts.card_content.protocol import (ContentError, build_release, sign_manifest,
    verify_envelope, json_bytes, read_json, release_id, require, digest, validate_pack)


def keygen(private, trust, key_id):
    private, trust = Path(private).resolve(), Path(trust).resolve()
    require(not private.is_relative_to(ROOT) and not private.exists(), 'private_key_must_be_new_and_outside_repository')
    require(not trust.exists() or read_json(trust.read_bytes()) == {}, 'trust_file_not_empty')
    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    private.parent.mkdir(parents=True, exist_ok=True)
    body = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    descriptor = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'wb') as stream: stream.write(body)
    public = key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    trust.parent.mkdir(parents=True, exist_ok=True)
    trust.write_bytes(json_bytes({key_id: public}))


def load_key(path):
    path = Path(path).resolve()
    require(not path.is_relative_to(ROOT), 'private_key_in_repository')
    return serialization.load_pem_private_key(path.read_bytes(), password=None)


def write_bundle(out, manifest, objects, key_id, key):
    out = Path(out)
    require(not out.exists(), 'output_exists')
    out.mkdir(parents=True)
    (out / 'objects').mkdir()
    envelope = sign_manifest(manifest, key_id, key)
    (out / 'release.json').write_bytes(json_bytes(envelope))
    for sha, body in objects.items(): (out / 'objects' / sha).write_bytes(body)
    return {'release_id': release_id(envelope), 'sequence': manifest['sequence'],
            'objects': len(objects), 'bytes': sum(map(len, objects.values()))}


class ControlClient:
    def __init__(self, origin, session_file=None):
        self.origin = origin.rstrip('/')
        url = urlsplit(origin)
        require(url.scheme == 'https' or (url.scheme == 'http' and url.hostname in ('127.0.0.1','localhost')), 'https_required')
        require(not url.username and not url.password and url.path in ('','/') and not url.query and not url.fragment, 'origin_invalid')
        self.headers = {}
        if session_file:
            value = read_json(Path(session_file).read_bytes())
            self.headers = {'Cookie': value['cookie'], 'X-CSRF-Token': value['csrf_token']}
        else:
            token = os.environ.get('PTCG_CARD_CONTENT_ADMIN_TOKEN', '')
            require(bool(token), 'admin_token_missing')
            self.headers = {'Authorization': 'Bearer ' + token}

    def request(self, path, value=None):
        raw = isinstance(value, bytes)
        body = value if raw else json_bytes(value) if value is not None else None
        headers = dict(self.headers)
        if body is not None: headers['Content-Type'] = 'application/octet-stream' if raw else 'application/json'
        # Authentication must not follow redirects to another origin.
        from urllib.request import build_opener, HTTPRedirectHandler
        class NoRedirect(HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs): return None
        try:
            with build_opener(NoRedirect).open(Request(self.origin + path, data=body, headers=headers), timeout=90) as response:
                return read_json(response.read())
        except HTTPError as exc:
            raise ContentError('control_http_' + str(exc.code)) from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    key = sub.add_parser('keygen'); key.add_argument('--private', required=True); key.add_argument('--trust', required=True); key.add_argument('--key-id', required=True)
    for command in ('build', 'rollback'):
        cmd = sub.add_parser(command)
        cmd.add_argument('--source', default=str(ROOT) if command == 'build' else None, required=command == 'rollback')
        cmd.add_argument('--out', required=True); cmd.add_argument('--sequence', type=int, required=True)
        cmd.add_argument('--version', required=True); cmd.add_argument('--minimum', default='0.6.2')
        cmd.add_argument('--notes', default=''); cmd.add_argument('--private', required=True); cmd.add_argument('--key-id', required=True)
        cmd.add_argument('--trust', default=str(ROOT / 'data/card_content/trust.json'))
    check = sub.add_parser('verify'); check.add_argument('--bundle', required=True); check.add_argument('--trust', default=str(ROOT / 'data/card_content/trust.json'))
    for command in ('upload', 'publish'):
        cmd = sub.add_parser(command); cmd.add_argument('--origin', required=True); cmd.add_argument('--session-file')
        if command == 'upload':
            cmd.add_argument('--bundle', required=True); cmd.add_argument('--trust', default=str(ROOT / 'data/card_content/trust.json'))
        else:
            cmd.add_argument('--release-id', required=True); cmd.add_argument('--expected-release-id', required=True)
    args = parser.parse_args()
    if args.command == 'keygen':
        keygen(args.private, args.trust, args.key_id)
        return {'status': 'key_created', 'key_id': args.key_id}
    if args.command in ('build', 'rollback'):
        trust = read_json(Path(args.trust).read_bytes())
        if args.command == 'build':
            manifest, objects = build_release(args.source, sequence=args.sequence, version=args.version, minimum=args.minimum, notes=args.notes)
        else:
            bundle = Path(args.source)
            manifest = verify_envelope(read_json((bundle / 'release.json').read_bytes()), trust)
            require(args.sequence > manifest['sequence'], 'rollback_sequence_must_increase')
            manifest.update(sequence=args.sequence, content_version=args.version, notes=args.notes)
            objects = {p.name: p.read_bytes() for p in (bundle / 'objects').iterdir() if p.is_file()}
        key = load_key(args.private)
        verify_envelope(sign_manifest(manifest, args.key_id, key), trust)
        return write_bundle(args.out, manifest, objects, args.key_id, key)
    if args.command in ('verify', 'upload'):
        bundle = Path(args.bundle)
        envelope = read_json((bundle / 'release.json').read_bytes())
        manifest = verify_envelope(envelope, read_json(Path(args.trust).read_bytes()))
        objects = {}
        for pack in manifest['packs']:
            body = (bundle / 'objects' / pack['sha256']).read_bytes()
            validate_pack(body, pack); objects[pack['sha256']] = body
        for card in manifest['cards'].values():
            if card['image']:
                image = card['image']; body = (bundle / 'objects' / image['sha256']).read_bytes()
                require(len(body) == image['size'] and digest(body) == image['sha256'], 'image_hash_mismatch')
                objects[image['sha256']] = body
        if args.command == 'verify': return {'status': 'verified', 'release_id': release_id(envelope), 'objects': len(objects)}
        client = ControlClient(args.origin, args.session_file)
        missing = client.request('/v1/admin/card-content/missing', {'sha256': list(objects)})['missing']
        for sha in missing:
            require(sha in objects, 'server_object_invalid')
            client.request('/v1/admin/card-content/objects/' + sha, objects[sha])
        receipt = client.request('/v1/admin/card-content/releases', envelope)
        return {**receipt, 'uploaded_objects':len(missing), 'reused_objects':len(objects)-len(missing), 'status':'draft'}
    client = ControlClient(args.origin, args.session_file)
    return client.request('/v1/admin/card-content/publish', {'release_id':args.release_id, 'expected_release_id':args.expected_release_id})


if __name__ == '__main__':
    try: print(json.dumps(main(), ensure_ascii=False))
    except (ContentError, OSError, ValueError) as exc:
        print(json.dumps({'status':'failed','error_code':getattr(exc,'code','io_or_configuration_failed')}))
        raise SystemExit(1)
