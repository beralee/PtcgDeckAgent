"""Original stereo cues synchronized to each character's gesture and resolution."""
from pathlib import Path
import json
import re
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/arena3d/supporters/audio'
RATE = 48000

def profiles():
    source = (ROOT / 'scenes/arena3d/ArenaSupporterCharacterCatalog.gd').read_text(encoding='utf-8')
    result = {}
    for name, body in re.findall(r'^\s*"(\w+)":(\{.*\}),$', source, re.M):
        result[name] = json.loads(re.sub(r'(?<=:)\.(\d+)', r'0.\1', body))
    return result

def build():
    manifest = {}
    for index, (name, profile) in enumerate(profiles().items()):
        duration, command, resolve = profile['duration'], profile['hit'], profile['resolve']
        t = np.arange(round(duration * RATE)) / RATE
        rng = np.random.default_rng(29920 + index)
        noise = rng.normal(size=len(t))
        air = np.convolve(noise, np.ones(17) / 17, mode='same')
        def env(start, decay, attack=.012):
            x = np.maximum(0, t - start)
            return (t >= start) * (1 - np.exp(-x / attack)) * np.exp(-x / decay)
        def hit(start, weight):
            x = np.maximum(0, t - start)
            phase = 2*np.pi*(49*x+48*.035*(1-np.exp(-x/.035)))
            return weight*(.48*np.sin(phase)*env(start,.25)+.65*air*env(start,.07))
        soft = name in ['lana', 'lillie', 'cipher', 'penny']
        f = 220 * 2**([7,4,12,-5,11,2,16,5,-5,-12,7,2,-7,14,12,-12,9][index]/12)
        signal = hit(.12,.34) + hit(command,.48 if soft else .88) + hit(resolve,.35)
        riser = np.clip((t-.28)/(command-.28),0,1)**1.6 * (t<command)
        signal += (.20*air+.018*np.sin(2*np.pi*(f*t+180*t*t)))*riser
        if profile['style'] in ['data','code','search','pixel','broadcast']:
            for j in range(4):
                signal += .08*np.sin(2*np.pi*f*2**((j*3)/12)*t)*env(.28+j*(command-.3)/4,.13,.005)
        elif profile['style'] in ['wave','stars','crystal','temporal']:
            for j, harmonic in enumerate([1,1.25,1.5,2]):
                signal += .07*np.sin(2*np.pi*f*harmonic*t)*env(command+j*.065,.45,.025)
        else:
            signal += .16*air*env(command,.26,.025)
        signal += .075*np.sin(2*np.pi*f*.5*t)*env(resolve,.40,.035)
        signal *= np.minimum(1,t/.02)*np.clip((duration-t)/.25,0,1)
        left = signal + .16*np.r_[np.zeros(3001),signal[:-3001]]
        right = signal + .16*np.r_[np.zeros(4307),signal[:-4307]]
        stereo = np.stack([left,right],axis=1)
        stereo *= .80/max(np.abs(stereo).max(),1e-9)
        with wave.open(str(OUT/(name+'.wav')),'wb') as file:
            file.setnchannels(2); file.setsampwidth(2); file.setframerate(RATE)
            file.writeframes((stereo*32767).astype('<i2').tobytes())
        manifest[name] = dict(duration=duration,gesture=command,resolve=resolve)
    (OUT.parent/'character-audio-provenance.json').write_text(json.dumps(dict(generator='tools/arena3d/build_supporter_character_audio.py',type='original procedural stereo synthesis; no voice or sampled recordings',sample_rate=RATE,cues=manifest),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Built {len(manifest)} synchronized cues; approved Boss audio preserved.')

if __name__ == '__main__':
    build()
