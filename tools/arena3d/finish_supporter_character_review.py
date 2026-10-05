"""Encode the complete real-play character showcase with 18 named chapters."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/supporter-characters-20260929'
OUT = ROOT / 'output/supporter-characters-20260929'

def run(args, name):
    with (WORK/name).open('w',encoding='utf-8') as file:
        subprocess.run(args,cwd=ROOT,stdout=file,stderr=file,check=True)

def main():
    source = (ROOT/'scenes/arena3d/ArenaSupporterCatalog.gd').read_text(encoding='utf-8')
    roster = [(name,json.loads(body)) for name,body in re.findall(r'^\s*"(\w+)":(\{.*\}),$',source,re.M)]
    log = (WORK/'recording.log').read_text(encoding='utf-8')
    assert 'SUPPORTER_RECORDING_COMPLETE' in log and 'ERROR:' not in log, 'Recording must finish without engine errors'
    committed = re.findall(r'SUPPORTER_COMMITTED (\w+) at=',log)
    assert committed==[name for name,_ in roster], committed
    startup = int(re.search(r'RECORDING_READY frame=(\d+)',log)[1])/30
    filters = ['drawbox=x=0:y=0:w=iw:h=57:color=0x080d1b:t=fill']
    def label(key,value,x,y,size,color,start=None):
        file = WORK/(key+'.txt');file.write_text(value,encoding='utf-8')
        item = f"drawtext=fontfile='C\\:/Windows/Fonts/msyhbd.ttc':textfile='{file.relative_to(ROOT).as_posix()}':x={x}:y={y}:fontsize={size}:fontcolor=0x{color}"
        if start is not None:item+=f":enable='gte(t,{start})*lt(t,{start+6})'"
        filters.append(item)
    label('collection-title','支援者，全员登场。',28,13,28,'f1f5ff')
    label('collection-subtitle','Windows 3D  /  实机出牌演示',615,21,18,'9caccc')
    metadata = [';FFMETADATA1','title=Windows 3D 支援者人物演出完整版','comment=Actual Windows renderer and real committed trainer plays on staged legal boards; an authored showcase, not a competitive match replay.']
    for index,(name,spec) in enumerate(roster):
        start = index*6
        label('chapter-'+name,f'{index+1:02d} / 18    {spec["name"]}',1110,18,22,spec['color'],start)
        metadata+=['[CHAPTER]','TIMEBASE=1/1000',f'START={start*1000}',f'END={(start+6)*1000}',f'title={spec["name"]}']
        filters.append(f"drawbox=x={index*1600/18:.2f}:y=896:w={1600/18-2:.2f}:h=3:color=0x{spec['color']}:t=fill:enable='gte(t,{start})'")
    script = WORK/'collection.filter';script.write_text(',\n'.join(filters),encoding='utf-8')
    meta = WORK/'collection.ffmeta';meta.write_text('\n'.join(metadata)+'\n',encoding='utf-8')
    video = OUT/'Windows3D_18位支援者人物演出完整版.mp4'
    run(['ffmpeg','-hide_banner','-y','-ss',str(startup),'-i',str(WORK/'characters-live.avi'),'-i',str(meta),'-t','108',
         '-map','0:v:0','-map','0:a:0','-map_metadata','1','-map_chapters','1','-filter_script:v',str(script),
         '-af','volume=3dB,alimiter=limit=0.9:level=false','-c:v','libx264','-crf','18','-preset','medium',
         '-pix_fmt','yuv420p','-c:a','aac','-b:a','256k','-movflags','+faststart',str(video)],'encode.log')
    run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],'decode-check.log')
    run(['ffmpeg','-v','error','-y','-ss','7.75','-i',str(video),'-frames:v','1','-q:v','1',str(OUT/'封面.jpg')],'cover.log')
    result = subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-show_chapters','-of','json',str(video)],capture_output=True,check=True)
    (WORK/'video-verification.json').write_bytes(result.stdout)
    data = json.loads(result.stdout)
    assert len(data['chapters'])==18
    assert 107.9<=float(data['format']['duration'])<=108.1
    stream = next(x for x in data['streams'] if x['codec_type']=='video')
    assert (stream['width'],stream['height'],stream['r_frame_rate'])==(1600,900,'30/1')
    lines = ['# Windows 3D 支援者人物演出','',
             '1 分 48 秒 · 1600×900 · 30 fps · H.264/AAC · 18 个章节。',
             '老大的指令保留已认可的版本，其余 17 位改为独立人物动作，每位六个姿势，共新增 102 个动作画面。',
             '视频在 Windows 游戏渲染器内录制。每段使用布置的合法局面，通过实际出牌执行卡效；这是演出合集，不是完整竞技对局。',
             '人物演出、实际卡效的结果显示、音效、快进及取消清理共用游戏运行时。','',
             '| 时间 | 支援者 |','|---|---|']
    for i,(_,spec) in enumerate(roster):lines.append(f'| {i*6//60:02d}:{i*6%60:02d} | {spec["name"]} |')
    (OUT/'演出清单.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({'video':str(video),'duration':data['format']['duration'],'bytes':video.stat().st_size,'chapters':18,'startup_trim':startup},ensure_ascii=True))

if __name__=='__main__':main()
