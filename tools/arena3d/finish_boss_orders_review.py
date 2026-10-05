"""Package the recorded live play at normal speed, then a labelled slow replay."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'.tmp/boss-director-20260929'
OUT = ROOT/'output/boss-director-20260929'

def run(command, log):
    with (WORK/log).open('w',encoding='utf-8') as stream:
        subprocess.run(command,cwd=ROOT,stdout=stream,stderr=stream,check=True)

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    captions = {
        'title':'老大的指令 · 3D 演出重制',
        'normal':'正常速度 · 实际出牌',
        'slow':'动作回看 · 0.625×',
    }
    for key,value in captions.items():(WORK/(key+'.txt')).write_text(value,encoding='utf-8')
    font = 'C\\:/Windows/Fonts/msyhbd.ttc'
    prefix = WORK.relative_to(ROOT).as_posix()
    def text(key,x,y,size,color):
        return f"drawtext=fontfile='{font}':textfile='{prefix}/{key}.txt':x={x}:y={y}:fontsize={size}:fontcolor={color}"
    paint = 'drawbox=x=0:y=0:w=iw:h=57:color=0x090b14:t=fill,'+text('title',28,13,27,'0xffe6cc')
    # 18 startup frames belong to fixture loading. Both clips show a real successful play.
    filters = [
        f'[0:v]split=2[n][s]',
        f"[n]trim=start=0.6:duration=5.1,setpts=PTS-STARTPTS,{paint},{text('normal',1270,20,18,'0xc7c1c8')}[nv]",
        f"[s]trim=start=1.30:duration=3.10,setpts=1.6*(PTS-STARTPTS),{paint},{text('slow',1270,20,18,'0xc7c1c8')}[sv]",
        '[0:a]asplit=2[na][sa]',
        '[na]atrim=start=0.6:duration=5.1,asetpts=PTS-STARTPTS,volume=3dB,alimiter=limit=0.9:level=false[nat]',
        '[sa]atrim=start=1.30:duration=3.10,asetpts=PTS-STARTPTS,atempo=0.625,volume=3dB,alimiter=limit=0.9:level=false[sat]',
        '[nv][nat][sv][sat]concat=n=2:v=1:a=1[v][a]',
    ]
    path = WORK/'final.filter'
    path.write_text(';\n'.join(filters),encoding='utf-8')
    video = OUT/'老大的指令_3D人物演出重制.mp4'
    run(['ffmpeg','-hide_banner','-y','-i',str(WORK/'boss-live.avi'),'-filter_complex_script',str(path),
         '-map','[v]','-map','[a]','-r','30','-c:v','libx264','-crf','17','-preset','slow',
         '-pix_fmt','yuv420p','-c:a','aac','-b:a','256k','-movflags','+faststart',
         '-metadata','title=Boss Orders 3D character direction',
         '-metadata','comment=Actual Windows game renderer and committed card play on a staged board. Normal speed followed by labelled 0.625x replay.',
         str(video)],'final-encode.log')
    run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],'decode-check.log')
    run(['ffmpeg','-v','error','-y','-ss','2.2','-i',str(video),'-frames:v','1','-q:v','1',str(OUT/'封面.jpg')],'cover.log')
    info = subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(video)],capture_output=True,check=True)
    (WORK/'video-verification.json').write_bytes(info.stdout)
    data = json.loads(info.stdout)
    print(json.dumps({'video':str(video),'duration':data['format']['duration'],'bytes':video.stat().st_size},ensure_ascii=True))

if __name__=='__main__':main()
