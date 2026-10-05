"""Original 2.1-second supporter sound cues; no samples or voice recordings."""
from pathlib import Path
import json
import re
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/arena3d/supporters/audio'
RATE = 24000

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    catalog = (ROOT/'scenes/arena3d/ArenaSupporterCatalog.gd').read_text(encoding='utf-8')
    ids = re.findall(r'^\s*"(\w+)":\{"name"',catalog,re.M)
    t=np.arange(round(2.1*RATE))/RATE
    for index,name in enumerate(ids):
        rng=np.random.default_rng(2900+index)
        noise=rng.normal(size=len(t))
        air=np.convolve(noise,np.ones(12)/12,mode='same')
        def env(start,decay,attack=.012):
            x=np.maximum(0,t-start)
            return (t>=start)*(1-np.exp(-x/attack))*np.exp(-x/decay)
        f=220*2**([0,7,4,12,9,11,2,16,5,-5,-12,7,2,-7,14,12,-12,9][index]/12)
        tone=np.sin(2*np.pi*(f*t+f*.08*t*t))
        signal=.13*air*env(.04,.35,.08)+.1*tone*env(.12,.27,.08)
        if name in ['boss','blackbelt','kieran','brock']:
            for j in range(3):
                signal+=(.24*air+.15*np.sin(2*np.pi*(85*t-13*t*t)))*env(.54+j*.10,.15)
        elif name in ['cipher','research','arven','penny']:
            for j in range(7):
                signal+=.075*np.sin(2*np.pi*f*2**((j%4)*3/12)*t)*env(.3+j*.11,.14,.004)
        elif name in ['iono','crispin','sada','turo']:
            signal+=(.2*air+.1*np.sin(2*np.pi*f*.5*t))*env(.68,.4)
            signal+=.08*np.sin(2*np.pi*(f*2*t+400*t*t))*env(.27,.27,.05)
        else:
            for j,multiple in enumerate([1,1.25,1.5,2]):
                signal+=.1*np.sin(2*np.pi*f*multiple*t)*env(.32+j*.13,.48,.022)
        signal*=np.minimum(1,t/.02)*np.clip((2.1-t)/.18,0,1)
        left=signal+.14*np.r_[np.zeros(997),signal[:-997]]
        right=signal+.14*np.r_[np.zeros(1387),signal[:-1387]]
        stereo=np.stack([left,right],axis=1)
        stereo*=.7/max(np.abs(stereo).max(),1e-6)
        with wave.open(str(OUT/(name+'.wav')),'wb') as w:
            w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE)
            w.writeframes((stereo*32767).astype('<i2').tobytes())
    (OUT.parent/'provenance.json').write_text(json.dumps({'generator':'tools/arena3d/build_supporter_audio.py','type':'original procedural stereo synthesis','duration':2.1,'sample_rate':RATE,'cues':ids},indent=2)+'\n',encoding='utf-8')
    print(f'Built {len(ids)} original stereo cues')

if __name__=='__main__':build()
