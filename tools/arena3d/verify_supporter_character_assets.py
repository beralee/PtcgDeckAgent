"""Verify the complete atlas set and retain built-in image-generation provenance."""
from pathlib import Path
import hashlib
import json
import re
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/supporter-characters-20260929'
ASSETS = ROOT / 'assets/arena3d/supporters/characters'

def main():
    profiles = (ROOT/'scenes/arena3d/ArenaSupporterCharacterCatalog.gd').read_text(encoding='utf-8')
    ids = re.findall(r'^\s*"(\w+)":\{',profiles,re.M)
    sources = {x['id']:x for x in json.loads((WORK/'generated-all.json').read_text(encoding='utf-8'))}
    references = json.loads((WORK/'references.json').read_text(encoding='utf-8'))
    if isinstance(references, list): references = {r['id']:r for r in references}
    manifest = {'generator':'built-in imagegen','style_reference':'assets/arena3d/supporters/boss-command-hd.png','atlas_grid':[3,2],'postprocessing':'Original alpha preserved; cell-edge feather applied by the runtime shader.','characters':{}}
    for name in ids:
        path = ASSETS/(name+'.png')
        picture = Image.open(path)
        assert picture.mode=='RGBA' and picture.size==(1536,1024),name
        rgba = np.asarray(picture)
        alpha = rgba[:,:,3]
        assert alpha.min()==0 and alpha.max()>=250,name
        transparent = float((alpha==0).mean())
        assert transparent>.15,name
        poses = []
        for frame in range(6):
            cell = rgba[frame//3*512:(frame//3+1)*512,frame%3*512:(frame%3+1)*512]
            assert float((cell[:,:,3]>240).mean())>.15,(name,frame)
            poses.append(hashlib.sha256(cell.tobytes()).hexdigest())
        assert len(set(poses))==6,name
        ref = references.get(name,{})
        manifest['characters'][name] = {'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'dimensions':list(picture.size),'transparent_fraction':round(transparent,4),'pose_sha256':poses,'source_filename':Path(sources[name]['source']).name,'reference_printing':ref.get('uid',''),'prompt':sources[name]['prompt']}
    assert len(manifest['characters'])==17
    (ASSETS/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('17 RGBA atlases / 102 distinct poses / identity references and prompts recorded.')

if __name__=='__main__':main()
