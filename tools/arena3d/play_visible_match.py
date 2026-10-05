"""Drive the opt-in CLI mouse bridge from visible UI only; record each decision.
No engine, card database, private replay, or hidden state is read.
"""
import argparse, json, pathlib, time, shutil, re

p=argparse.ArgumentParser(); p.add_argument('session'); p.add_argument('output'); p.add_argument('--steps',type=int,default=240)
a=p.parse_args(); session=pathlib.Path(a.session); out=pathlib.Path(a.output); out.mkdir(parents=True,exist_ok=True)
used=set(); selected_hand=False; selected_basic=False; must_end=False; last=-1; events=[]; pause_next=False; chosen=set()

def send(o, command):
    tmp=session/'command.tmp'; tmp.write_text(json.dumps(dict(snapshot=o['snapshot'],**command)),encoding='utf-8'); tmp.replace(session/'command.json')

for step in range(a.steps):
    deadline=time.monotonic()+30
    while True:
        try: o=json.loads((session/'observation.json').read_text(encoding='utf-8-sig'))
        except (FileNotFoundError, PermissionError, json.JSONDecodeError):
            if time.monotonic()>deadline: raise RuntimeError('No readable observation')
            time.sleep(.1); continue
        if o['snapshot']!=last: break
        if time.monotonic()>deadline: raise RuntimeError('No fresh observation after command')
        time.sleep(.1)
    last=o['snapshot']; ui=[i for i in o['ui'] if i['enabled']]; prompt=o['pending_prompt']; board=o['board']; turn=board.get('turn',0)
    shutil.copy2(session/'screen.png',out/f'{step:04d}.png')
    (out/f'{step:04d}.json').write_text(json.dumps(o,ensure_ascii=False,indent=2),encoding='utf-8')
    dialogs=[i for i in ui if 'Dialog' in i['path'] and i['text'].strip()]; choice=None; why='wait'
    text=' '.join(i['text'] for i in ui)
    if any('MatchEnd' in i['path'] for i in ui):
        events.append(dict(snapshot=last,terminal_ui=text))
        (out/'actions.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
        print('VISIBLE_MATCH_TERMINAL',last,flush=True)
        break
    detail=next((i for i in ui if 'DetailClose' in i['path']),None)
    if detail:
        choice=detail; why='close foreground detail'
    elif prompt=='pokemon_action':
        attacks=[i for i in dialogs if i['text'].startswith('招式 /') and '不可用' not in i['text']]
        choice=max(attacks,key=lambda i: int((re.search(r'伤害 (\d+)',i['text']) or ['','0'])[1]),default=None)
        if choice: why='visible available attack'
        else:
            choice=next((i for i in dialogs if i['text'].startswith('特性 /') and '串联装置' in i['text'] and '不可用' not in i['text'] and (turn,'ability') not in used),None)
            if choice: used.add((turn,'ability')); why='visible ability'
            else: choice=next((i for i in dialogs if i['text']=='取消'),None); must_end=True; why='close unavailable attacks'
    elif prompt.startswith('setup_bench_') and dialogs:
        finish=next((i for i in dialogs if i['text']=='完成'),None)
        candidates=[i for i in dialogs if i['text'] not in ['完成','取消','返回','不选择']]
        if (prompt,'bench') not in used and candidates:
            choice=candidates[0]; used.add((prompt,'bench')); why='place visible starting bench'
        else: choice=finish; why='finish starting bench'
    elif dialogs:
        finish=next((i for i in dialogs if i['text'] in ['确认','确定','完成','完成选择','不使用']),None)
        candidates=[i for i in dialogs if i['text'] not in ['确认','确定','完成','完成选择','不使用','取消','返回','清除','不选择'] and 'LibrarySearchSource' not in i['path'] and i['path'] not in chosen]
        # Select actual visible cards before confirming multi-select windows.
        choice=next((i for i in candidates if '雷公V' in i['text']),None)
        if not choice: choice=next(iter(candidates),None)
        if choice: chosen.add(choice['path'])
        else: choice=finish
        if finish: choice=finish
        if not choice: choice=next((i for i in dialogs if i['text'] in ['不选择','取消']),None)
        why='current visible choice'
    elif prompt=='take_prize':
        choice=next((i for i in ui if i['text'].startswith('领取奖赏')),None); why='visible prize slot'
    elif prompt=='send_out':
        key=next((k for k,v in board.get('slots',{}).items() if k.startswith('my_bench_') and not v.get('empty',True)),None)
        if key: choice={'at':o['world_points'][key],'text':key}
        why='visible replacement after knockout'
    elif 'field' in prompt or any('FieldInteraction' in i['path'] for i in ui):
        choice=next((i for i in ui if 'FieldInteraction' in i['path'] and '确认' in i['text']),None)
        if not choice:
            key=next((k for k,v in board.get('slots',{}).items() if k.startswith('my_') and not v.get('empty',True)), 'my_active')
            choice={'at':o['world_points'][key],'text':key}
        why='current field choice'
    elif pause_next:
        pause_next=False; why='wait for card feedback'
    elif board.get('current')==board.get('view') and turn>0 and not prompt and any(i['text'].startswith('结束') for i in ui):
        if selected_basic:
            key=next((k for k,v in board.get('slots',{}).items() if k.startswith('my_bench_') and v.get('empty',True)),None)
            if key: choice={'at':o['world_points'][key],'text':key}
            selected_basic=False; pause_next=True; why='place basic in visible empty bench'
        elif selected_hand:
            choice={'at':o['world_points']['my_active'],'text':'my_active'}; selected_hand=False; pause_next=True; why='attach to active'
        elif must_end:
            choice=next((i for i in ui if i['text'].startswith('结束')),None); must_end=False; why='end turn'
        else:
            energy=next((i for i in ui if 'HandContainer' in i['path'] and '基本雷能量'==i['text']),None)
            basic=next((i for i in ui if 'HandContainer' in i['path'] and i['text'] in ['铁臂膀ex','雷公V','密勒顿ex','梦幻ex','怒鹦哥ex','雷丘V','霓虹鱼V']),None)
            bench_count=sum(not v.get('empty',True) for k,v in board.get('slots',{}).items() if k.startswith('my_bench_'))
            if energy and (turn,'energy') not in used:
                choice=energy; selected_hand=True; used.add((turn,'energy')); why='visible hand energy'
            elif basic and bench_count<5 and (turn,'bench') not in used:
                choice=basic; selected_basic=True; used.add((turn,'bench')); why='select visible basic Pokemon'
            elif (turn,'active') not in used:
                choice={'at':o['world_points']['my_active'],'text':'my_active'}; used.add((turn,'active')); why='inspect active actions'
            else: choice=next((i for i in ui if i['text'].startswith('结束')),None); why='end turn'
    command={'op':'click','at':choice['at']} if choice else {'op':'wait','seconds':1}
    events.append(dict(snapshot=last,turn=turn,prompt=prompt,reason=why,visible_text=choice['text'] if choice else '',command=command))
    (out/'actions.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
    print(step,last,turn,prompt,why,choice['text'][:40] if choice else '',flush=True)
    send(o,command)
else: print('STEP_LIMIT',flush=True)
print('VISIBLE_MATCH_RECORD',out,flush=True)
