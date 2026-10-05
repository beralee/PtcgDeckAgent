"""Export ONCE, then update the bytecode-exported application over real HTTP.

This is an engine/export acceptance test, not a Python emulation of hot loading.
Run: python tests/card_content/frozen_client_acceptance.py --godot <console.exe>
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from scripts.card_content.protocol import build_release, sign_manifest, json_bytes, release_id

MAIN = '''extends Node
const Existing = preload("res://scripts/effects/Existing.gd")
func _ready():
    var action = "probe"
    var output = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--action="): action = arg.trim_prefix("--action=")
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    var report = {"damage": Existing.new().damage(), "new_damage": -1,
        "release_id": preload("res://scripts/card_content/ContentPaths.gd").release_id()}
    if ResourceLoader.exists("res://scripts/effects/NewCard.gd"):
        report.new_damage = load("res://scripts/effects/NewCard.gd").new().damage()
    CardContentBootstrap.confirm_boot()
    if action == "update":
        await CardContentUpdater.check_for_updates(true)
        while CardContentUpdater.snapshot().busy:
            await CardContentUpdater.state_changed
        report.update = CardContentUpdater.snapshot()
    var file = FileAccess.open(output, FileAccess.WRITE)
    file.store_string(JSON.stringify(report))
    file.close()
    get_tree().quit()
'''


def run_acceptance(godot: Path, output: Path):
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'; project.mkdir()
    shutil.copytree(ROOT / 'scripts/card_content', project / 'scripts/card_content', ignore=shutil.ignore_patterns('__pycache__', '*.py', '*.pyc', 'ContentUpdatePanel.gd*'))
    (project / 'data/card_content').mkdir(parents=True)
    (project / 'scripts/effects').mkdir(parents=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public = key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    (project / 'data/card_content/trust.json').write_bytes(json_bytes({'export-fixture':public}))
    source = output / 'source'; (source / 'scripts/effects').mkdir(parents=True)
    (source / 'data/bundled_user/cards').mkdir(parents=True)
    (source / 'data/bundled_user/cards/HOT_001.json').write_bytes(json_bytes({'set_code':'HOT','card_index':'001','hp':100}))
    existing = 'extends RefCounted\nfunc damage(): return %d\n'
    (project / 'scripts/effects/Existing.gd').write_text(existing % 10)
    (project / 'Main.gd').write_text(MAIN)
    (project / 'Main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://Main.gd" id="1"]\n[node name="Main" type="Node"]\nscript = ExtResource("1")\n')
    state = {'envelope':None,'objects':{},'requests':[], 'corrupt':False}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_GET(self):
            if self.path == '/v1/card-content/channels/stable':
                body = json_bytes(state['envelope']); content_type='application/json'
            elif self.path.startswith('/v1/card-content/objects/'):
                sha = self.path.rsplit('/',1)[-1]; state['requests'].append(sha)
                body = b'corrupt' if state['corrupt'] else state['objects'][sha]; content_type='application/octet-stream'
            else:
                self.send_error(404); return
            self.send_response(200); self.send_header('Content-Type',content_type)
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    server = ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    origin = 'http://127.0.0.1:' + str(server.server_port)
    (project / 'project.godot').write_text(f'''config_version=5
[application]
config/name="FrozenCardContentAcceptance"
config/version="0.6.2"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")
[autoload]
CardContentBootstrap="*res://scripts/card_content/ContentBootstrap.gd"
CardContentUpdater="*res://scripts/card_content/ContentUpdater.gd"
[ptcgdap]
card_content/base_url="{origin}"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    (project / 'export_presets.cfg').write_text('''[preset.0]
name="Frozen"
platform="Windows Desktop"
runnable=true
custom_features="card_content_test"
export_filter="all_resources"
include_filter="data/**"
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''')
    executable = output / 'frozen.exe'
    template = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.6.1.stable/windows_release_x86_64.exe'
    with (project / 'export_presets.cfg').open('a') as stream:
        stream.write('\ncustom_template/release="' + template.as_posix() + '"\n')
    env = dict(os.environ, APPDATA=str(output / 'userdata'))
    evidence = []
    def command(args, label, timeout=90):
        result = subprocess.run([str(x) for x in args], env=env, capture_output=True, timeout=timeout)
        (output / (label + '.log')).write_bytes(result.stdout + result.stderr)
        return result
    try:
        imported=command([godot,'--headless','--path',project,'--editor','--import'], 'import')
        if imported.returncode: raise AssertionError('Editor import failed; inspect import.log')
        exported=command([godot,'--headless','--path',project,'--export-release','Frozen',executable], 'export')
        if exported.returncode: raise AssertionError('Export failed; inspect export.log')
        pack = output / 'frozen.pck'
        frozen_hash = hashlib.sha256(pack.read_bytes()).hexdigest()
        def probe(label, action='probe', expect_failure=False):
            target=output/(label+'.json')
            result=command([executable,'--headless','--quit-after','120','--','--action='+action,'--output='+str(target)],label)
            if expect_failure:
                if target.exists(): raise AssertionError('Broken script unexpectedly ran')
                return {}
            if result.returncode or not target.exists(): raise AssertionError('Runtime failed: '+label)
            report=json.loads(target.read_bytes()); evidence.append({'step':label,**report}); return report
        def release(sequence, damage, bad=False):
            (source/'scripts/effects/Existing.gd').write_text('this is invalid GDScript !!!\n' if bad else existing % damage)
            (source/'scripts/effects/NewCard.gd').write_text(existing % 7)
            manifest,objects=build_release(source,sequence=sequence,version=str(sequence),minimum='0.6.2')
            state['envelope']=sign_manifest(manifest,'export-fixture',key)
            state['objects'].update(objects)
            return manifest
        assert probe('baseline')['damage']==10
        release(1,20)
        staged=probe('download-new-card','update')
        assert staged['damage']==10 and staged['new_damage']==-1 and staged['update']['state']=='ready', staged
        active=probe('activate-new-card')
        assert active['damage']==20 and active['new_damage']==7, active
        before=len(state['requests']); release(2,30)
        assert probe('download-effect-fix','update')['damage']==20
        assert len(state['requests'])-before==1, 'Unchanged catalog was downloaded again'
        assert probe('activate-effect-fix')['damage']==30
        release(3,40,bad=True)
        assert probe('stage-broken','update')['update']['state']=='ready'
        probe('broken-boot',expect_failure=True)
        assert probe('automatic-recovery')['damage']==30
        release(4,40); state['corrupt']=True
        assert probe('reject-corrupt-download','update')['update']['state']=='failed'
        assert probe('old-rules-after-corruption')['damage']==30
        state['corrupt']=False; release(5,20)
        assert probe('stage-signed-rollback','update')['update']['state']=='ready'
        assert probe('activate-signed-rollback')['damage']==20
        server.shutdown(); server.server_close(); thread.join()
        assert probe('offline-restart')['damage']==20
        assert hashlib.sha256(pack.read_bytes()).hexdigest()==frozen_hash
        result={'status':'passed','frozen_pck_sha256':frozen_hash,'export_count':1,'evidence':evidence,'object_requests':state['requests']}
        (output/'report.json').write_bytes(json_bytes(result)); return result
    finally:
        if thread.is_alive(): server.shutdown(); server.server_close(); thread.join()


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--godot',type=Path,required=True); parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    from datetime import datetime
    out=args.output or ROOT/'artifacts/card_content'/datetime.now().strftime('frozen-%Y%m%d-%H%M%S')
    result=run_acceptance(args.godot.resolve(),out.resolve())
    print(json.dumps({'status':result['status'],'export_count':1,'steps':len(result['evidence']),'report':str(out/'report.json')}))
