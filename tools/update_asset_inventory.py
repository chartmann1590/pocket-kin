"""Rebuild the individual production asset inventory from generation records."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'game/assets'
records=json.loads((ASSETS/'generation-records.json').read_text(encoding='utf-8'))['records']
by_id={x['id']:x for x in records}
items=[]
def add(identifier,file,index,grid,use):
    items.append(dict(id=identifier,file=file,cell=index,grid=grid,use=use,status='generated-integrated',exists=(ASSETS/file).is_file()))
for name in ['mochi','fern','pebble','clover','pippin','lumi']:
    for i,pose in enumerate(['egg','baby','juvenile','adult','delighted','sleeping','dirty','ill']):
        add(f'{name}_{pose}',f'pet_{name}.png',i,[4,2],'Adoption / home / sanctuary / watch')
for i,color in enumerate(['Peach','Sage','Honey','Lavender','Cloud']):
    for j,kind in enumerate(['Cushion','Plant','Lamp','Rug','Bunting','Picture']):add(f'{color} {kind}','decor-final.png',i*6+j,[6,5],'Room shop / furnished home')
for i,name in enumerate(['Peach bow','Sage scarf','Sun crown','Moon ribbon','Berry bow','Cloud scarf','Daisy crown','Leaf ribbon','Honey bow','Lilac scarf','Star crown','Sky ribbon']):add(name,'accessories-final.png',i,[4,3],'Accessory shop / pet')
for i,name in enumerate(['Peach','Berries','Pear','Apple','Melon','Plum','Daisy crown discovery','Smooth pebble','Four-leaf clover','Amber acorn','Fern print','Robin feather','Moon shell','Star lily','Silver reed','Raindrop','Reward parcel','Wicker basket','Food bowl','Soap bubble','Cold compress','Petal coin','Storybook','Star']):add(name,'objects-final.png',i,[6,4],'Care / mini-games / discoveries / rewards')
for i,name in enumerate(['Feed icon','Affection icon','Wash icon','Sleep icon','Paw icon','Petal icon','Reminder icon','Decorate icon','Play icon','Album icon','Settings icon','Confirm icon']):add(name,'ui-icons-final.png',i,[6,2],'Native phone/watch controls')
for i,name in enumerate(['Cottage mornings','Moonlight dreams','Blossom picnic']):add(name,'premium-final.png',i,[3,1],'Premium previews / equipped room collection')
for name in ['home','meadow','woodland','pond','sanctuary']:add(name,name+'.png',0,[1,1],'Background')
add('Pocket Kin launcher','launcher-final.png',0,[1,1],'Phone/watch launcher')
manifest={'version':2,'visual_style':'Original cozy gouache storybook, cream/peach/sage','generation_tool':'built-in imagegen','records_file':'generation-records.json','assets':items,'audio':[{'file':name+'.wav','status':'original-procedural-composition','source':'tools/generate_audio.py'} for name in ['ambient','tap','care','hatch','reward','sleep']],'fonts':[{'file':'Nunito.ttf','license':'OFL-1.1','license_file':'Nunito-OFL.txt'},{'file':'Lora.ttf','license':'OFL-1.1','license_file':'Lora-OFL.txt'}],'archive':['mochi.png','species-reference.png','decor.png','accessories.png','objects.png','ui-icons.png','premium.png','launcher.png','icon.svg'],'notes':['Archive files are excluded from production exports.','Atlas regions are runtime slices, not separately redrawn images.','Decor atlas regions include a small gutter crop to exclude neighboring cell fragments.','Image files retain generated alpha; rendered preview backgrounds can differ from actual transparency.','Generated illustrations, assets and code are original to this project; font licenses are retained.']}
(ASSETS/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
lines=['# Complete generated asset inventory','','User requirement: every visual asset and background is generated and individually tracked. No procedural placeholder graphics are used by the production screens. Native typography and interactive control shapes remain code-rendered for accessibility.','','## Source and verification','','All production illustrations use the built-in image-generation tool. Exact recorded prompts and original output paths are in [generation-records.json](../game/assets/generation-records.json). The machine-readable catalog is [manifest.json](../game/assets/manifest.json). Source images remain in the workspace; individual atlas cells are consumed at runtime.','','Transparency has been checked on production sprite PNGs. Phone screens have been rendered and inspected. Watch rendering is compiled; physical watch verification remains outstanding.','','## Individual visual assets','','| Asset | File | Cell (zero-based) | Use | Status |','|---|---|---:|---|---|']
for x in items:lines.append(f"| {x['id']} | `{x['file']}` | {x['cell']} | {x['use']} | {'generated / integrated' if x['exists'] else 'missing'} |")
lines+=['','## Audio and typography','','Original ambient music and five sound effects are reproducibly composed by `tools/generate_audio.py`; no external samples. Nunito and Lora fonts retain their OFL licenses.','','## Review limits','','Original source/reference and procedural development files are archived, excluded from release packaging, and not counted as finished assets. The generated content is integrated; final store graphics and device-specific marketing screenshots are release materials, not in-game assets.']
(ROOT/'main-plan/asset-inventory.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Indexed {len(items)} individual generated visual assets and 6 original audio files.')
