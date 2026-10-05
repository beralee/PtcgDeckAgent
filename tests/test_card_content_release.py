"""Public wire/build contract: first RED before adding the implementation."""
import base64
import copy
import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from scripts.card_content.protocol import (ContentError, sign_manifest, verify_envelope,
    validate_manifest, validate_pack, digest, make_pack, build_release)


class CardContentReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.public = cls.key.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo).decode()
        cls.trust = {'test': cls.public}

    def release(self, root, sequence=1):
        (root / 'scripts/effects').mkdir(parents=True, exist_ok=True)
        (root / 'data/bundled_user/cards').mkdir(parents=True, exist_ok=True)
        (root / 'scripts/effects/Example.gd').write_text('extends RefCounted\nfunc damage(): return 10\n')
        (root / 'data/bundled_user/cards/TEST_001.json').write_text(json.dumps(
            {'set_code': 'TEST', 'card_index': '001', 'name': 'Example', 'effect_id': 'test'}))
        return build_release(root, sequence=sequence, version='test', minimum='0.6.2')

    def test_signature_binds_exact_bytes_and_trust(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest, objects = self.release(Path(tmp))
            envelope = sign_manifest(manifest, 'test', self.key)
            self.assertEqual(manifest, verify_envelope(envelope, self.trust))
            wrong = copy.deepcopy(envelope)
            wrong['payload'] = base64.b64encode(b'{}').decode()
            for bad, trust in [(wrong, self.trust), (envelope, {})]:
                with self.assertRaises(ContentError): verify_envelope(bad, trust)

    def test_build_is_deterministic_and_reuses_unchanged_objects(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, objects = self.release(Path(tmp))
            b, again = self.release(Path(tmp), 2)
            self.assertEqual(objects, again)
            self.assertNotEqual(digest(json.dumps(a).encode()), digest(json.dumps(b).encode()))
            for pack in a['packs']:
                validate_pack(objects[pack['sha256']], pack)
            self.assertIn('TEST_001', a['cards'])
            self.assertIn('scripts/effects/Example.gd.remap', a['packs'][0]['files'])

    def test_rejects_paths_duplicate_members_and_tampered_pack(self):
        for path in ['../escape.gd', 'project.godot', 'scripts/card_content/Bootstrap.gd',
                     'scripts/effects/../evil.gd', 'scripts/effects/native.dll']:
            with self.assertRaises(ContentError): make_pack({path: b'bad'})
        data, descriptor = make_pack({'scripts/effects/Example.gd': b'extends RefCounted\n'})
        with self.assertRaises(ContentError): validate_pack(data + b'bad', descriptor)
        with self.assertRaises(ContentError): make_pack({'scripts/effects/A.gd': b'a', 'scripts/effects/a.gd': b'b'})

    def test_rejects_unknown_fields_unclosed_cards_and_invalid_numbers(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest, _ = self.release(Path(tmp))
            for mutate in [lambda m: m.update(sequence=1.5), lambda m: m.update(extra=True),
                           lambda m: m['cards']['TEST_001'].update(source_sha256='a'*64),
                           lambda m: m.update(runtime_abi='unknown')]:
                bad = copy.deepcopy(manifest); mutate(bad)
                with self.assertRaises(ContentError): validate_manifest(bad)

    def test_new_revision_changes_only_owning_pack(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); a, old = self.release(root)
            (root / 'scripts/effects/Example.gd').write_text('extends RefCounted\nfunc damage(): return 30\n')
            b, new = build_release(root, sequence=2, version='fix', minimum='0.6.2')
            self.assertEqual(1, len(set(new) - set(old)))
            self.assertEqual(a['cards'], b['cards'])

    def test_new_global_effect_classes_bind_without_client_class_cache_rebuild(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); self.release(root)
            (root/'scripts/effects/NewEffect.gd').write_text('class_name NewEffect\nextends RefCounted\n')
            (root/'scripts/effects/Example.gd').write_text('extends RefCounted\nfunc create(): return NewEffect.new()\n')
            manifest,objects=build_release(root,sequence=2,version='new-class',minimum='0.6.2')
            with zipfile.ZipFile(io.BytesIO(objects[manifest['packs'][0]['sha256']])) as archive:
                script=archive.read('scripts/effects/Example.gd').decode()
                self.assertIn('const NewEffect = preload("res://scripts/effects/NewEffect.gd")',script)

    def test_malformed_envelopes_fail_with_typed_errors(self):
        for value in [None, [], {'schema_version':1,'key_id':[],'payload':0,'signature':None},
                      {'schema_version':True,'key_id':'test','payload':None,'signature':{} }]:
            with self.assertRaises(ContentError): verify_envelope(value,self.trust)


if __name__ == '__main__': unittest.main()
