"""Deterministic original sound design. No official cries or sampled recordings.
24 kHz stereo WAV cues follow species direction clocks; peak below -3 dBFS.
"""
import math, random, wave, array, re
from pathlib import Path
OUT=Path(__file__).resolve().parents[2]/'assets/arena3d/pokemon/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=24000
direction=(OUT.parents[3]/'scenes/arena3d/ArenaPokemonDirection.gd').read_text(encoding='utf-8')
TIMINGS={m[0]:[float(v) for v in m[1].split(',')] for m in re.findall(r'"([a-z_]+)": \[([0-9.,]+)\]',direction)}
CONFIG={
 'dragapult':('ghost',310),'charizard':('fire',77),'munkidori':('psychic',523),
 'ceruledge':('slash',360),'terapagos':('crystal',784),'grimmsnarl':('dark',63),
 'zoroark':('illusion',247),'archaludon':('metal',146),'ho_oh':('feather',587),
 'budew':('pollen',1046),'garchomp':('sonic',130),'raging_bolt':('thunder',52),'pikachu_tera':('electric',660),'gardevoir':('embrace',440)}
def envelope(t,start,attack,decay):
 x=t-start
 return 0 if x<0 else min(1,x/attack)*math.exp(-x/decay)
def build():
 for index,(name,(kind,frequency)) in enumerate(CONFIG.items()):
  DURATION,HIT,SETTLE,_=TIMINGS[name];N=int(RATE*DURATION)
  rng=random.Random(2950+index);samples=[];low=0;last=0
  for i in range(N):
   t=i/RATE;noise=rng.uniform(-1,1);low+=.08*(noise-low);high=noise-last;last=noise
   charge=envelope(t,.10,HIT*.55,HIT*.75);hit=envelope(t,HIT,.009,.22);tail=envelope(t,HIT+.025,.06,.50)
   f=frequency;phase=math.tau*(f*t+f*.19*t*t)
   tone=math.sin(phase);v=0
   if kind=='ghost':
    v=.16*tone*charge+.50*low*envelope(t,.70,.012,.20)+.42*low*envelope(t,.87,.012,.20)+.18*math.sin(phase*.5)*tail
   elif kind=='fire':v=.24*low*charge+(.70*low+.18*math.sin(math.tau*(82*t-12*t*t)))*tail+.12*noise*hit
   elif kind=='psychic':v=(tone*.19+math.sin(phase*1.501)*.12)*charge+(math.sin(phase*2)*.14+math.sin(phase*3)*.08)*tail
   elif kind=='slash':v=.08*low*charge+.60*high*envelope(t,HIT-.20,.015,.075)+.50*high*envelope(t,HIT,.008,.11)+.17*math.sin(math.tau*f*.7*t)*hit
   elif kind=='crystal':v=sum(math.sin(math.tau*f*q*t)*envelope(t,.25+k*.065,.01,.38)*.10 for k,q in enumerate([1,1.25,1.5,2,2.5]))+.15*low*tail
   elif kind=='dark':v=.13*tone*charge+.34*math.sin(math.tau*(90*t-20*t*t))*hit+.38*low*tail
   elif kind=='illusion':v=.30*low*envelope(t,.25,.12,.16)+.15*math.sin(phase*.5)*envelope(t,1.30,.08,.15)+.5*high*hit+.16*math.sin(math.tau*49*t)*tail
   elif kind=='metal':v=.14*tone*charge+sum(math.sin(math.tau*f*q*t)*hit*.13 for q in [1,2.73,4.15])+.16*low*tail
   elif kind=='feather':v=.24*low*charge+sum(math.sin(math.tau*f*q*t)*envelope(t,.55+k*.055,.03,.45)*.07 for k,q in enumerate([1,1.5,2,2.5]))+.16*low*tail
   elif kind=='pollen':v=.14*tone*envelope(t,.2,.01,.13)+.20*low*envelope(t,.70,.02,.25)+sum(math.sin(math.tau*f*(1+k*.25)*t)*envelope(t,.80+k*.1,.004,.13)*.07 for k in range(4))
   elif kind=='thunder':
    rumble=envelope(t,HIT+.10,.07,1.05)
    v=.13*low*charge+.45*high*hit+.80*low*rumble+.31*math.sin(math.tau*(55*t-5*t*t))*rumble+.21*high*envelope(t,HIT+.23,.002,.09)
   elif kind=='electric':v=.13*(tone+.33*math.sin(phase*3))*charge+(.30*high+.17*math.sin(phase*1.7))*hit+.16*math.sin(math.tau*1320*t)*tail
   elif kind=='sonic':
    v=sum((.5*low+.16*noise)*envelope(t,start,.055,.07) for start in [.47,.96,1.43])+(.48*low+.18*math.sin(math.tau*57*t))*hit+.18*low*tail
   elif kind=='embrace':
    v=sum(math.sin(math.tau*f*q*t)*envelope(t,.2+k*.12,.12,.8)*.09 for k,q in enumerate([1,1.25,1.5,2]))+.15*math.sin(math.tau*880*t)*tail
    v+=sum(math.sin(math.tau*1320*t)*envelope(t,HIT+k*.13,.005,.11)*.07 for k in range(2))
   v*=min(1,t/.008)*min(1,(DURATION-t)/.12)
   samples.append(v)
  # Short asymmetric reflections provide width without artificial long reverb tails.
  stereo=[]
  for i,v in enumerate(samples):
   l=v+(samples[i-997]*.17 if i>=997 else 0)+(samples[i-2279]*.09 if i>=2279 else 0)
   r=v+(samples[i-1373]*.16 if i>=1373 else 0)+(samples[i-2671]*.08 if i>=2671 else 0)
   pan=math.sin(i/RATE*5.8)*.60 if kind=='sonic' else 0
   stereo.extend([l*(1-pan*.45),r*(1+pan*.45)])
  peak=max(abs(v) for v in stereo) or 1
  data=array.array('h',[int(v/peak*.70*32767) for v in stereo])
  with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(data.tobytes())
  print(name,len(data)*2,'bytes')
if __name__=='__main__':build()
