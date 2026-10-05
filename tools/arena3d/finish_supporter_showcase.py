"""Add chapter captions to the recorded in-engine supporter showcase."""
from pathlib import Path
import json
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.tmp/arena-supporters-20260929'
OUT=ROOT/'output/arena3d-supporters-20260929'

def finish():
    OUT.mkdir(parents=True,exist_ok=True)
    source=(ROOT/'scenes/arena3d/ArenaSupporterCatalog.gd').read_text(encoding='utf-8')
    roster=[]
    for line in source.splitlines():
        match=re.match(r'\s*"(\w+)":(\{.*\}),$',line)
        if match:roster.append((match[1],json.loads(match[2])))
    filters=['drawbox=x=0:y=0:w=iw:h=138:color=0x050b14@0.55:t=fill',
             'drawbox=x=0:y=784:w=iw:h=116:color=0x050b14@0.82:t=fill']
    def label(key,text,x,y,size,color,start=None,end=None):
        file=WORK/(key+'.txt');file.write_text(text,encoding='utf-8')
        filt=f"drawtext=fontfile='C\\:/Windows/Fonts/msyhbd.ttc':textfile='{file.relative_to(ROOT).as_posix()}':x={x}:y={y}:fontsize={size}:fontcolor=0x{color}"
        if start is not None:filt+=f":enable='gte(t,{start})*lt(t,{end})'"
        filters.append(filt)
    label('title','支援者，也有主场。',55,34,40,'f0f5ff')
    label('subtitle','G / H / I / J  ·  18 张支援者  ·  Windows 3D 演出合集',57,93,20,'87b8d7')
    label('footer','PtcgDeckAgent  /  实机录制 · 演示场景',55,858,18,'93a5b8')
    chapters=[';FFMETADATA1','title=Windows 3D 支援者演出合集','comment=Actual Windows engine presentation, staged visual demonstration.']
    for index,(key,spec) in enumerate(roster):
        start=index*3; end=start+3
        label('chapter-'+key,f'{index+1:02d} / 18    {spec["name"]}   ·   {spec["motif"]}',55,808,28,spec['color'],start,end)
        filters.append(f"drawbox=x={55+index*82}:y=890:w=80:h=3:color=0x{spec['color']}:t=fill:enable='gte(t,{start})'")
        chapters+=['[CHAPTER]','TIMEBASE=1/1000',f'START={start*1000}',f'END={end*1000}',f'title={spec["name"]} · {spec["motif"]}']
    script=WORK/'captions.filter';script.write_text(',\n'.join(filters),encoding='utf-8')
    metadata=WORK/'chapters.ffmeta';metadata.write_text('\n'.join(chapters)+'\n',encoding='utf-8')
    video=OUT/'Windows3D_18张支援者演出合集.mp4'
    command=['ffmpeg','-hide_banner','-y','-i',str(WORK/'supporters-master.mp4'),'-i',str(metadata),
             '-map','0:v:0','-map','0:a:0','-map_metadata','1','-map_chapters','1',
             '-filter_script:v',str(script),'-af','volume=5dB,alimiter=limit=0.85:level=false',
             '-c:v','libx264','-crf','17','-preset','slow','-pix_fmt','yuv420p',
             '-c:a','aac','-b:a','256k','-movflags','+faststart',str(video)]
    with (WORK/'final-encode.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=ROOT,stdout=log,stderr=log,check=True)
    subprocess.run(['ffmpeg','-v','error','-y','-ss','4.2','-i',str(video),'-frames:v','1','-q:v','1',str(OUT/'封面.jpg')],check=True)
    listing=['# Windows 3D 支援者演出','',
             '54 秒 / 1600×900 / 30 fps / 含 18 种原创合成音效。',
             '演示使用当前 Windows 林间道馆、真实本地卡图和游戏运行时的同一套支援者动画；画面是布置的展示场景，不是完整对局录像。',
             '老大采用高清人物 cut-in，其余卡图采用面向镜头的卡面展示；场内光环、路径、门、晶体和道具使用 3D 几何。','',
             '| 起始时间 | 支援者 | 演出主题 |','|---|---|---|']
    for i,(_,spec) in enumerate(roster):listing.append(f'| 00:{i*3:02d} | {spec["name"]} | {spec["motif"]} |')
    listing+=['','大部分演出长 2.1 秒，合集按 0.78 倍展示；人物版老大长 3.05 秒，在三秒章节中按约 1.12 倍展示。快进统一为 1.8 倍。',
              '关闭动态效果时直接使用普通结果显示；关闭音效、缩放窗口或退出场景会清理对应声音与临时效果。']
    (OUT/'演出清单.md').write_text('\n'.join(listing)+'\n',encoding='utf-8')
    probe=subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-show_chapters','-of','json',str(video)],capture_output=True,check=True)
    (WORK/'video-verification.json').write_bytes(probe.stdout)
    subprocess.run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],check=True)
    print('Video exported and decoded successfully; 18 named chapters.')

if __name__=='__main__':finish()
