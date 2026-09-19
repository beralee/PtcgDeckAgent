import copy
import hashlib
import json
from pathlib import Path
import unittest
import zipfile

from scripts.ai.ptcgdap.author_strategy_match_host import (
    AuthorStrategyExactDeckGate, AuthorStrategyMatchError, _matches_source_raw_hash,
)

ROOT = Path(__file__).resolve().parents[2]


class CardSourcePortabilityTests(unittest.TestCase):
    def test_only_exact_or_uniform_lf_crlf_variants_match(self):
        lf = b'{\n  "hp": 70\n}\n'
        crlf = lf.replace(b'\n', b'\r\n')
        sha = lambda data: hashlib.sha256(data).hexdigest().upper()
        for actual, pinned in [(lf, lf), (crlf, crlf), (lf, crlf), (crlf, lf)]:
            self.assertTrue(_matches_source_raw_hash(actual, sha(pinned)))
        for changed in [lf + b' ', lf.replace(b'70', b'80'), lf.replace(b'\n', b'\r'),
                        lf.replace(b'\n', b'\r\n', 1), b'\xff' + lf]:
            self.assertFalse(_matches_source_raw_hash(changed, sha(crlf)))

    def test_real_download_maps_and_tampering_remains_rejected(self):
        with zipfile.ZipFile(ROOT / 'tests/ptcgdap/fixtures/macos/e719-rules-0.4.0.ptcgai') as archive:
            manifest = json.loads(archive.read('deck/deck_manifest.json'))
            rows = AuthorStrategyExactDeckGate.parse_windows_local_deck_csv(archive.read('deck/deck.csv'))
        mapped = AuthorStrategyExactDeckGate.map_windows_local_rows(rows, manifest, root=ROOT)
        self.assertEqual(sum(card['count'] for card in mapped), 60)
        self.assertEqual(len(mapped), 28)
        for field in ['source_raw_sha256', 'source_canonical_sha256']:
            changed = copy.deepcopy(manifest)
            changed['cards'][0][field] = 'A' * 64
            with self.assertRaises(AuthorStrategyMatchError):
                AuthorStrategyExactDeckGate.map_windows_local_rows(rows, changed, root=ROOT)
