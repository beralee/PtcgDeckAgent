"""Generate public test signatures. The ephemeral private key is never saved."""
import json
import sys
import tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from scripts.card_content.protocol import build_release, sign_manifest, json_bytes

out=ROOT/'tests/fixtures/card_content'; out.mkdir(parents=True,exist_ok=True)
key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
public=key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo).decode()
with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp)
    (root/'scripts/effects').mkdir(parents=True)
    (root/'data/bundled_user/cards').mkdir(parents=True)
    (root/'scripts/effects/ContentFixture.gd').write_text('extends RefCounted\nfunc damage(): return 10\n')
    (root/'data/bundled_user/cards/CONTENT_001.json').write_text(json.dumps({'set_code':'CONTENT','card_index':'001','name':'Content fixture','effect_id':'content-fixture','card_type':'Pokemon','stage':'Basic','hp':100}))
    manifest,objects=build_release(root,sequence=1,version='fixture-1',minimum='0.6.2')
    (out/'release.json').write_bytes(json_bytes(sign_manifest(manifest,'test-fixture',key)))
    (out/'trust.json').write_bytes(json_bytes({'test-fixture':public}))
    for sha,blob in objects.items(): (out/(sha+'.zip')).write_bytes(blob)
print('Generated public-only signature fixtures')
