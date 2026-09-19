from time import perf_counter

from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes


def test_repeated_public_ascii_payloads_do_not_scan_each_character_in_python():
    frame = {"value": "a" * 100_000}
    expected = b'{"value":"' + b"a" * 100_000 + b'"}'
    started = perf_counter()
    for _ in range(100):
        assert jcs_canonical_json_bytes(frame) == expected
    elapsed = perf_counter() - started
    assert elapsed < 1.0, f"repeated public hashing spent {elapsed:.3f}s in string serialization"
