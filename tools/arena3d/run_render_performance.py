"""Serial paired 2D/portable-3D measurements in isolated user data or diagnostic APK."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.arena3d.compare_render_performance import compare


def require_window(report, size):
    expected = [int(value) for value in size.split('x')]
    if report.get('platform', {}).get('window') != expected:
        raise RuntimeError(f"Requested {expected}, rendered {report.get('platform', {}).get('window')}")


def run(args, timeout=90):
    result=subprocess.run([str(a) for a in args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    if result.returncode: raise RuntimeError(result.stdout+'\n'+result.stderr)
    return result.stdout


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--godot',type=Path,default=Path('D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'))
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--exe',type=Path)
    parser.add_argument('--device')
    parser.add_argument('--apk',type=Path)
    parser.add_argument('--adb',type=Path,default=Path(os.environ.get('LOCALAPPDATA',''))/'Android/Sdk/platform-tools/adb.exe')
    parser.add_argument('--runs',type=int,default=3)
    parser.add_argument('--seconds',type=int,default=20)
    parser.add_argument('--sizes',nargs='+',default=['390x844','844x390'])
    args=parser.parse_args()
    if args.runs<1 or args.seconds<5 or any(not re.fullmatch(r'\d+x\d+',s) for s in args.sizes): parser.error('Invalid measurement configuration')
    if args.device and not args.apk: parser.error('--device requires the isolated diagnostic APK')
    if args.device and args.seconds!=20: parser.error('The Android diagnostic uses fixed 20 second windows')
    out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    pairs=[]
    (out/'summary.json').write_text(json.dumps({'complete':False,'passed':False,'expected_pairs':len(args.sizes)*args.runs,'pairs':[]}),encoding='utf-8')
    package='com.example.ptcgdeckagent.performance'
    remote=f'/sdcard/Android/data/{package}/files/performance'
    def adb(*parts): return run([args.adb,'-s',args.device,*parts])
    original_size=''
    if args.device:
        aapt=args.adb.parent.parent/'build-tools/36.1.0/aapt.exe'
        badging=run([aapt,'dump','badging',args.apk])
        if not re.search(r"^package: name='"+re.escape(package)+"' ",badging,re.M): raise RuntimeError('Refusing to install/clear a non-diagnostic package')
        adb('wait-for-device')
        adb('install','-r',args.apk.resolve())
        original_size=adb('shell','wm','size')
        (out/'device.json').write_text(json.dumps({'serial':args.device,'size':original_size,
            'model':adb('shell','getprop','ro.product.model'),'abi':adb('shell','getprop','ro.product.cpu.abi'),
            'emulator':adb('shell','getprop','ro.kernel.qemu')},indent=2),encoding='utf-8')
    try:
        for size in args.sizes:
            if args.device: adb('shell','wm','size',size)
            for iteration in range(args.runs):
                reports={}
                for mode in (['2d','3d'] if iteration%2==0 else ['3d','2d']):
                    folder=out/f'{size}-{iteration+1}-{mode}'
                    folder.mkdir()
                    report=folder/'result.json'
                    if args.device:
                        adb('shell','am','force-stop',package)
                        adb('shell','pm','clear',package)
                        request=folder/'request.json'
                        request.write_text(json.dumps({'group':'arena_'+mode,'repeat':1,'window':[int(v) for v in size.split('x')]}),encoding='utf-8')
                        adb('shell','am','start','-W','-n',package+'/com.godot.game.GodotAppLauncher')
                        process=adb('shell','pidof',package).strip()
                        for _ in range(100):
                            probe=subprocess.run([str(args.adb),'-s',args.device,'shell','test','-d',remote],capture_output=True)
                            if probe.returncode==0: break
                            time.sleep(.2)
                        else: raise RuntimeError('Diagnostic request directory missing')
                        adb('push',request,remote+'/request.json')
                        for _ in range(100):
                            probe=subprocess.run([str(args.adb),'-s',args.device,'shell','test','-f',remote+'/result.json'],capture_output=True)
                            if probe.returncode==0: break
                            time.sleep(1)
                        else: raise RuntimeError('Diagnostic report timed out')
                        adb('pull',remote+'/result.json',report)
                        adb('pull',remote+'/result.png',folder/'frame.png')
                        log=adb('logcat','-d',f'--pid={process}','-v','brief')
                    else:
                        env=os.environ.copy()
                        # Keep both the editor and exported macOS/Windows player away from real saves.
                        env['APPDATA']=str(folder/'user')
                        env['XDG_DATA_HOME']=str(folder/'user')
                        command=[str(args.exe or args.godot),'--rendering-method','gl_compatibility','--audio-driver','Dummy']
                        if not args.exe: command+=['--path',str(args.root),'--script','res://tests/performance/ArenaPerformanceCli.gd']
                        command+=['--',f'--arena-perf-mode={mode}','--arena-perf-mobile',f'--arena-perf-size={size}',f'--arena-perf-seconds={args.seconds}',f'--arena-perf-output={report}']
                        if args.exe: command += [f'--perf-group=arena_{mode}',f'--perf-output={report}']
                        startup=None
                        if os.name=='nt':
                            startup=subprocess.STARTUPINFO()
                            startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
                            startup.wShowWindow=subprocess.SW_HIDE
                        try:
                            result=subprocess.run(command,cwd=args.root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                                timeout=args.seconds*3+90,startupinfo=startup)
                        except subprocess.TimeoutExpired as exc:
                            (folder/'engine.log').write_bytes(exc.stdout or b'')
                            raise RuntimeError('Child timed out: '+str(folder/'engine.log')) from exc
                        log=result.stdout.decode('utf-8',errors='replace')
                        (folder/'engine.log').write_text(log,encoding='utf-8')
                        if result.returncode: raise RuntimeError(f'Child exited {result.returncode}: '+log[-1500:])
                    (folder/'engine.log').write_text(log,encoding='utf-8')
                    if re.search(r'SCRIPT ERROR:|(?:^|\s)ERROR:',log,re.M): raise RuntimeError('Engine errors: '+str(folder/'engine.log'))
                    reports[mode]=json.loads(report.read_text(encoding='utf-8-sig'))
                    if args.device: require_window(reports[mode], size)
                    print(f'Captured {size} pair {iteration+1} {mode}',flush=True)
                result=compare(reports['2d'],reports['3d'])
                pairs.append({'size':size,'iteration':iteration+1,**result})
                complete=len(pairs)==len(args.sizes)*args.runs
                (out/'summary.json').write_text(json.dumps({'complete':complete,'passed':complete and all(p['passed'] for p in pairs),'expected_pairs':len(args.sizes)*args.runs,'pairs':pairs},indent=2),encoding='utf-8')
    finally:
        if args.device:
            override=re.search(r'Override size: (\d+x\d+)',original_size)
            adb('shell','wm','size',override[1] if override else 'reset')
            adb('shell','am','force-stop',package)
    return int(not all(p['passed'] for p in pairs))


if __name__=='__main__': raise SystemExit(main())
