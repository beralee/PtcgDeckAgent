"""Install one isolated debug APK, then update scripts without reinstalling it."""
import argparse
import json
import os
import shutil
import shlex
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT))
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from scripts.card_content.protocol import build_release,sign_manifest,json_bytes,digest
from frozen_client_acceptance import MAIN
PKG='org.ptcgdap.cardcontentlab'

def run(godot, adb, serial, output):
    output.mkdir(parents=True,exist_ok=False)
    project=output/'project'; project.mkdir()
    shutil.copytree(ROOT/'scripts/card_content',project/'scripts/card_content',ignore=shutil.ignore_patterns('__pycache__','*.py','*.pyc','ContentUpdatePanel.gd*'))
    (project/'scripts/effects').mkdir(parents=True); (project/'data/card_content').mkdir(parents=True)
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    public=key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    (project/'data/card_content/trust.json').write_bytes(json_bytes({'android-fixture':public}))
    (project/'scripts/effects/Existing.gd').write_text('extends RefCounted\nfunc damage(): return 10\n')
    start=MAIN.index('    var action ='); end=MAIN.index('    var report =')
    code=MAIN[:start]+'''    var command = JSON.parse_string(FileAccess.get_file_as_string("user://command.json"))
    var action = command.get("action", "probe")
    var output = "user://result.json"
'''+MAIN[end:]
    code=code.replace('var file = FileAccess.open(output', 'report.case = command.get("case", "")\n    var file = FileAccess.open(output')
    (project/'Main.gd').write_text(code)
    (project/'Main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://Main.gd" id="1"]\n[node name="Main" type="Node"]\nscript = ExtResource("1")\n')
    state={'envelope':{},'objects':{},'requests':[],'corrupt':False}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def do_GET(self):
            if self.path.endswith('/channels/stable'): body=json_bytes(state['envelope'])
            elif '/objects/' in self.path:
                sha=self.path.rsplit('/',1)[-1]; state['requests'].append(sha)
                body=b'corrupt' if state['corrupt'] else state['objects'][sha]
            else: self.send_error(404); return
            self.send_response(200); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    port=server.server_port
    (project/'project.godot').write_text(f'''config_version=5
[application]
config/name="CardContentLab"
config/version="0.6.2"
run/main_scene="res://Main.tscn"
[autoload]
CardContentBootstrap="*res://scripts/card_content/ContentBootstrap.gd"
CardContentUpdater="*res://scripts/card_content/ContentUpdater.gd"
[ptcgdap]
card_content/base_url="http://127.0.0.1:{port}"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
''')
    (project/'export_presets.cfg').write_text(f'''[preset.0]
name="Android Content"
platform="Android"
runnable=true
custom_features="card_content_test"
export_filter="all_resources"
include_filter="data/**"
exclude_filter=""
script_export_mode=2
[preset.0.options]
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=false
architectures/x86=false
architectures/x86_64=true
version/code=1
version/name="1.0.0"
package/unique_name="{PKG}"
package/name="Card Content Lab"
package/signed=true
permissions/internet=true
user_data_backup/allow=false
''')
    def device(*args,check=True):
        result=subprocess.run([str(adb),'-s',serial,*args],capture_output=True,timeout=60)
        if check and result.returncode: raise AssertionError((result.stdout+result.stderr).decode(errors='replace'))
        return result.stdout
    def export(label,*args):
        result=subprocess.run([str(godot),'--headless','--path',str(project),*args],capture_output=True,timeout=120)
        (output/(label+'.log')).write_bytes(result.stdout+result.stderr)
        if result.returncode: raise AssertionError('Android export failed: '+label)
    try:
        export('import','--editor','--import')
        apk=output/'frozen.apk'; export('export','--export-debug','Android Content',str(apk))
        frozen_hash=digest(apk.read_bytes())
        device('wait-for-device')
        device('install','--no-incremental','-r',str(apk))
        device('shell','pm','clear',PKG)  # Only this isolated acceptance application.
        component=device('shell','cmd','package','resolve-activity','--brief',PKG).decode().strip().splitlines()[-1]
        assert component.startswith(PKG+'/'),component
        device('reverse','tcp:'+str(port),'tcp:'+str(port))
        evidence=[]
        def launch(label, action='probe'):
            device('shell','am','force-stop',PKG)
            value=json.dumps({'case':label,'action':action})
            command="mkdir -p files && printf '%s' "+shlex.quote(value)+" > files/command.json"
            device('shell','run-as',PKG,'sh','-c',shlex.quote(command))
            device('shell','am','start','-n',component)
            deadline=time.monotonic()+35
            while time.monotonic()<deadline:
                raw=device('exec-out','run-as',PKG,'cat','files/result.json',check=False)
                try: value=json.loads(raw)
                except (ValueError,UnicodeError): value={}
                if value.get('case')==label:
                    evidence.append(value); print('PASS Android '+label,flush=True); return value
                time.sleep(.4)
            (output/(label+'-logcat.log')).write_bytes(device('logcat','-d','-t','2000'))
            raise AssertionError('Android runtime timeout: '+label)
        source=output/'source'; (source/'scripts/effects').mkdir(parents=True); (source/'data/bundled_user/cards').mkdir(parents=True)
        (source/'data/bundled_user/cards/ANDROID_001.json').write_bytes(json_bytes({'set_code':'ANDROID','card_index':'001'}))
        def release(sequence,damage):
            (source/'scripts/effects/Existing.gd').write_text('extends RefCounted\nfunc damage(): return %d\n'%damage)
            (source/'scripts/effects/NewCard.gd').write_text('extends RefCounted\nfunc damage(): return 7\n')
            manifest,objects=build_release(source,sequence=sequence,version=str(sequence),minimum='0.6.2')
            state['envelope']=sign_manifest(manifest,'android-fixture',key); state['objects'].update(objects)
        assert launch('baseline')['damage']==10
        release(1,20); assert launch('download-new','update')['update']['state']=='ready'
        value=launch('activate-new'); assert value['damage']==20 and value['new_damage']==7,value
        before=len(state['requests']); release(2,30)
        assert launch('download-fix','update')['damage']==20
        assert len(state['requests'])-before==1
        assert launch('activate-fix')['damage']==30
        release(3,40); state['corrupt']=True
        assert launch('reject-corrupt','update')['update']['state']=='failed'
        assert launch('still-current')['damage']==30
        state['corrupt']=False; release(4,20)
        assert launch('stage-rollback','update')['update']['state']=='ready'
        assert launch('activate-rollback')['damage']==20
        assert digest(apk.read_bytes())==frozen_hash
        report={'status':'passed','platform':'android-x86_64-emulator','install_count':1,'apk_sha256':frozen_hash,'evidence':evidence}
        (output/'report.json').write_bytes(json_bytes(report)); return report
    finally:
        server.shutdown();server.server_close();thread.join()
        device('reverse','--remove','tcp:'+str(port),check=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--godot',type=Path,required=True);parser.add_argument('--adb',type=Path,required=True)
    parser.add_argument('--serial',required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();report=run(args.godot.resolve(),args.adb.resolve(),args.serial,args.output.resolve())
    print(json.dumps({'status':report['status'],'steps':len(report['evidence']),'install_count':1}))
