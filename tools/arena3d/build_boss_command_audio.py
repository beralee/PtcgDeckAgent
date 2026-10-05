"""Original three-beat sound design: entrance, command, physical arrival."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RATE = 48000
t = np.arange(round(3.05*RATE))/RATE
rng = np.random.default_rng(2992)
noise = rng.normal(size=len(t))
air = np.convolve(noise,np.ones(19)/19,mode='same')

def envelope(start,decay,attack=.007):
    x = np.maximum(0,t-start)
    return (t>=start)*(1-np.exp(-x/attack))*np.exp(-x/decay)

def hit(start,weight):
    x = np.maximum(0,t-start)
    phase = 2*np.pi*(43*x+55*.028*(1-np.exp(-x/.028)))
    return weight*(.65*np.sin(phase)*envelope(start,.26)+.9*air*envelope(start,.06))

signal = hit(.12,.58)+hit(1.02,1)+hit(1.78,.66)
# A rising reverse-air bed stops dead at the pointing pose.
riser = np.clip((t-.28)/.70,0,1)**1.5*(t<1.02)
signal += .33*air*riser + .026*np.sin(2*np.pi*(160*t+250*t*t))*riser
signal += .22*air*envelope(1.80,.35,.09)
signal += .07*(np.sin(2*np.pi*73.416*t)+np.sin(2*np.pi*110*t))*envelope(.12,.78,.025)
signal *= np.clip((3.05-t)/.3,0,1)
left = signal+.18*np.r_[np.zeros(3701),signal[:-3701]]
right = signal+.18*np.r_[np.zeros(4907),signal[:-4907]]
stereo = np.stack([left,right],axis=1)
stereo *= .83/max(abs(stereo).max(),1e-9)
path = ROOT/'assets/arena3d/supporters/audio/boss_command.wav'
with wave.open(str(path),'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes((stereo*32767).astype('<i2').tobytes())
print('Authored stereo cue written: 3.05 s, 48 kHz; peaks at entrance, command and release.')
