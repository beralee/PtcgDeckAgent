from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_match_host_contract import build_artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class AuthorStrategyMatchHostContractBuilderTests(unittest.TestCase):
    def test_builder_reproduces_all_contract_artifacts(self) -> None:
        artifacts = build_artifacts()
        self.assertEqual(
            {
                "author_strategy_match_host.schema.json",
                "author_strategy_match_host_profile.json",
                "author_strategy_match_host_conformance_vectors.json",
                "author_strategy_match_host_bundle.json",
            },
            set(artifacts),
        )
        for name, document in artifacts.items():
            self.assertEqual(document, load_json_strict(CONTRACT_ROOT / name), name)

    def test_bundle_binds_contract_and_parent_authorities(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "author_strategy_match_host_bundle.json")
        self.assertEqual("ptcgdap-author-strategy-match-host-as-wp4-v1", bundle["bundle_id"])
        self.assertEqual("B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B", bundle["parent_author_package_bundle_canonical_sha256"])
        self.assertEqual("2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294", bundle["cabt_contract_canonical_sha256"])
        self.assertEqual("AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4", bundle["card_catalog_bundle_canonical_sha256"])
        self.assertEqual("69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389", bundle["restricted_base_executor_bundle_canonical_sha256"])
        self.assertEqual("18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4", bundle["portable_backend_bundle_canonical_sha256"])
        for entry in bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            digest = hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()
            self.assertEqual(entry["canonical_sha256"], digest)


if __name__ == "__main__":
    unittest.main()
