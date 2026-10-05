"""Exercise the real CardDatabase/EffectRegistry/EffectProcessor in one frozen game.

The exported game's bootstrap remains untouched. A late-loaded external probe
avoids loading game classes before its first autoload. Test releases are staged
only in this run's isolated APPDATA, never in a player's installation.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT))
from scripts.card_content.protocol import build_release, sign_manifest, json_bytes, release_id, digest
from tools.card_content_release import load_key

PROBE='''extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var instance_script = load("res://scripts/data/CardInstance.gd")
    var data_script = load("res://scripts/data/CardData.gd")
    var state_script = load("res://scripts/data/GameState.gd")
    var player_script = load("res://scripts/data/PlayerState.gd")
    var processor = load("res://scripts/engine/EffectProcessor.gd").new()
    var report = {"release_id": load("res://scripts/card_content/ContentPaths.gd").release_id()}
    var database = root.get_node("CardDatabase")
    var added = database.get_card("CONTENTLIVE", "001")
    report.new_card = added != null
    report.catalog_has_new = load("res://scripts/card_catalog/CardCatalogIndex.gd").new().has_card("CONTENTLIVE", "001")
    for effect_id in ["aecd80ca2722885c3d062a2255346f3e", "content-added-effect"]:
        var effect = processor.get_effect(effect_id)
        if effect == null:
            report[effect_id] = -1
            continue
        var state = state_script.new()
        state.players.append(player_script.new())
        state.players.append(player_script.new())
        var card = data_script.from_dict({"set_code":"CONTENTLIVE","card_index":"001","effect_id":effect_id,"card_type":"Trainer","trainer_type":"Supporter"})
        for i in range(20): state.players[0].deck.append(instance_script.create(card,0))
        var source = instance_script.create(card,0)
        report[effect_id+"_executed"] = processor.execute_card_effect(source,[],state)
        report[effect_id] = state.players[0].hand.size()
    root.get_node("CardContentBootstrap").confirm_boot()
    var file = FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
    file.store_string(JSON.stringify(report)); file.close()
    processor = null
    quit()
'''

def run(executable, private, key_id, output, godot):
    output.mkdir(parents=True,exist_ok=False)
    # Copied class_name scripts are test inputs, never parent-project classes.
    # Write the marker before creating any scripts, even with a custom output.
    (output/'.gdignore').write_text('')
    original_hash=digest(executable.read_bytes())
    probe=output/'probe.gd'; probe.write_text(PROBE)
    env=dict(os.environ,APPDATA=str(output/'userdata'))
    content=Path(env['APPDATA'])/'Godot/app_userdata/PtcgDeckAgent/card_content'
    evidence=[]
    def execute(label):
        target=output/(label+'.json')
        # Release templates intentionally ignore --script. The same-version
        # console runner opens the frozen exported pack and supplies only this
        # external observer; all game scripts come from the exported client.
        result=subprocess.run([str(godot),'--main-pack',str(executable),'--headless','--script',str(probe),'--quit-after','240','--',str(target)],env=env,capture_output=True,timeout=90)
        (output/(label+'.log')).write_bytes(result.stdout+result.stderr)
        if result.returncode or not target.exists(): raise AssertionError('Full runtime failed: '+label)
        text=(result.stdout+result.stderr).decode(errors='replace')
        if 'SCRIPT ERROR' in text: raise AssertionError('Full runtime script error: '+label)
        value=json.loads(target.read_bytes()); evidence.append({'step':label,**value}); return value
    baseline=execute('baseline')
    assert baseline['aecd80ca2722885c3d062a2255346f3e']==7 and not baseline['new_card'], baseline
    source=output/'source'
    (source/'data/card_content').mkdir(parents=True)
    shutil.copyfile(ROOT/'data/card_content/runtime_classes.json',source/'data/card_content/runtime_classes.json')
    for relative in ['scripts/effects','scripts/engine','scripts/data','scripts/ai/ptcgdap','contracts/ptcgdap']:
        shutil.copytree(ROOT/relative,source/relative,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    cards=source/'data/bundled_user/cards'; cards.mkdir(parents=True)
    (cards/'CONTENTLIVE_001.json').write_bytes(json_bytes({'set_code':'CONTENTLIVE','card_index':'001','name':'Content test trainer','card_type':'Trainer','trainer_type':'Item','effect_id':'content-added-effect'}))
    (source/'scripts/effects/trainer_effects/ContentAddedEffect.gd').write_text('class_name ContentAddedEffect\nextends "res://scripts/effects/trainer_effects/EffectDrawCards.gd"\nfunc _init():\n\tsuper(2, false)\n')
    registry=source/'scripts/engine/EffectRegistry.gd'
    code=registry.read_text(encoding='utf-8')
    anchor='static func _register_items(processor: EffectProcessor) -> void:\n'
    assert anchor in code
    registry.write_text(code.replace(anchor,anchor+'\tprocessor.register_effect("content-added-effect", ContentAddedEffect.new())\n',1),encoding='utf-8')
    key=load_key(private)
    def stage(sequence):
        manifest,objects=build_release(source,sequence=sequence,version='full-runtime-'+str(sequence),minimum='0.6.2')
        envelope=sign_manifest(manifest,key_id,key); rid=release_id(envelope)
        (content/'objects').mkdir(parents=True,exist_ok=True); (content/'releases').mkdir(exist_ok=True)
        for pack in manifest['packs']: (content/'objects'/(pack['sha256']+'.zip')).write_bytes(objects[pack['sha256']])
        (content/'releases'/(rid+'.json')).write_bytes(json_bytes(envelope))
        (content/'pending.json').write_bytes(json_bytes({'release_id':rid}))
    stage(1)
    added=execute('new-card')
    assert added['new_card'] and added['catalog_has_new'] and added['content-added-effect']==2 and added['aecd80ca2722885c3d062a2255346f3e']==7, added
    effect=source/'scripts/effects/trainer_effects/EffectDrawCards.gd'
    effect.write_text(effect.read_text(encoding='utf-8').replace('draw_count = count','draw_count = count + 1'),encoding='utf-8')
    stage(2)
    fixed=execute('effect-fix')
    assert fixed['aecd80ca2722885c3d062a2255346f3e']==8 and fixed['content-added-effect']==3, fixed
    assert digest(executable.read_bytes())==original_hash
    report={'status':'passed','frozen_executable_sha256':original_hash,'runner':'same-version-console-with-frozen-export-pack','evidence':evidence}
    (output/'report.json').write_bytes(json_bytes(report)); return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--client',type=Path,required=True)
    parser.add_argument('--private',type=Path,required=True); parser.add_argument('--key-id',required=True); parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--godot',type=Path,required=True)
    args=parser.parse_args(); report=run(args.client.resolve(),args.private,args.key_id,args.output.resolve(),args.godot.resolve())
    print(json.dumps({'status':report['status'],'steps':len(report['evidence']),'report':str(args.output/'report.json')}))
