"""Build authored commentary briefs; never modifies decks, AI support or seeds.

New deck IDs require explicit coverage. Runtime selects profiles by PUBLIC
printing evidence, never by the selected player's private deck ID.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# id | public anchors | opening | engine | prizes | sustain | risks
ROWS = """
dragapult|多龙巴鲁托ex,多龙奇,多龙梅西亚|保住多条进化线，建立多龙奇抽滤|正面攻击与备战伤害指示物形成跨回合收割|比较正面击倒与备战同时取奖窗口|保留下一只进化体与异色附能路线|二阶进化被截断、断能；放置指示物不是攻击伤害
charizard|喷火龙ex|铺小火龙并准备二阶进化与检索|进化附能启动攻击；输出受对方取奖进度影响|关注对方取奖后反击门槛与后排双奖目标|下一条进化线与回收维持续攻|前期进化线被抢杀、能力封锁；不同属性喷火龙须看具体文本
gardevoir|沙奈朵ex,奇鲁莉安,拉鲁拉丝|保护进化线并发展抽滤、弃能|从弃牌区附超能量，同时管理自身伤害指示物|单奖攻击手与双奖核心分工，承伤换输出|保留弃牌能量、回收与替补进化|能力封锁、附能承伤上限、备战核心被拉出击倒
raging_bolt|猛雷鼓ex|尽快铺攻击手与附能组件|全场可弃能量转为输出；碧草厄诡椪是常见搭配|按击倒门槛投入能量，争取连续双奖击倒|计算下回合重新补能条件|断能、加速手被拉出；未见常见组件不能说本局必有
miraidon|密勒顿ex|检索基础雷宝可梦铺场并安排加速顺序|多种雷属性基础攻击手轮换|公开铁臂膀且满足费用时才讨论额外取奖路线|手填、加速和换位保证下一只接力|辅助双奖目标过多；高速铺场不等于能量足够
regidrago|雷吉铎拉戈VSTAR,雷吉铎拉戈V|准备进化、能量与弃牌区龙属性素材|复制弃牌区龙宝可梦招式，VSTAR力量是一次性资源|按局面选择爆发、备战压制或减伤|保护下只进化体与后续附能|素材未入弃牌、V阶段被抢杀；复制条件依具体文本
lugia|洛奇亚VSTAR,洛奇亚V,始祖大鸟|始祖大鸟入弃牌后准备VSTAR启动|召唤始祖大鸟提供特殊能量加速|根据属性与奖赏交换选择攻击手|特殊能量种类与始祖大鸟存活决定续攻|VSTAR启动前受干扰、特殊能量破坏、缩备战
gholdengo|赛富豪ex,索财灵|铺多个索财灵，建立抽牌引擎|手牌能量转为伤害，回收把弃能变成下轮输出|按门槛投入能量，避免无意义过量弃能|能量回收与抽牌保障连续攻击|手牌干扰、进化断档；未知手牌不能精算输出
palkia|起源帕路奇亚VSTAR,起源帕路奇亚V|铺场与水能弃牌，准备VSTAR加速|双方备战规模影响输出，VSTAR附能支持水系接力|比较正面攻击与辅助攻击的取奖价值|一次性附能分配照顾后续攻击手|缩备战、V阶段被抓、过早耗尽VSTAR力量
arceus|阿尔宙斯VSTAR,阿尔宙斯V|形成可攻击的阿尔宙斯并铺接力V|攻击附能推进后续主攻，VSTAR检索补组件|启动回合换取后续稳定取奖|接力主攻的进化与能量优先|先手节奏被打断、特殊能量被移除
giratina|骑拉帝纳VSTAR,骑拉帝纳V|准备进化、异色能量，确认是否有放逐组件|高伤害伴随能量消耗，部分招式要求放逐门槛|权衡爆发与一次性VSTAR击倒资源|留足下一击能量与换位|看到骑拉不代表放逐体系；未满足门槛不能使用效果
dialga|起源帝牙卢卡VSTAR,起源帝牙卢卡V|铺进化与钢能加速组件|积累能量并规划额外回合时机|额外回合串联击倒，必须实际满足招式费用|主攻存活与加速核心保护|启动慢、后排引擎被抓、能量过度集中
archaludon|铝钢桥龙ex,铝钢龙|钢能入弃牌并建立进化线路|进化附能使新攻击手接入战线|高HP与防守招式改善奖赏交换|回收与再次进化恢复附能循环|能力封锁、一击击倒；钢铁防线变体须核对基础卡招式
lost_box|花疗环环,古月鸟,勾魂眼|逐步积累放逐区并保留关键资源|不同放逐数量解锁攻击与加速|单奖交换与后期多目标收割结合|规划切换、能量和不可放逐的关键卡|前期引擎受压；放逐区不同于弃牌区
future|铁头壳ex|发展未来加速攻击与辅助|未来加成和多属性攻击手配合|铁臂膀等额外取奖改变路线需确有公开卡|轮换攻击手并维持附能|辅助双奖暴露、加速被切断
ancient|轰鸣月,古代的活力|用远古组件展开并积累弃牌资源|远古弃牌与攻击条件联动|单奖攻击手与双奖目标交换|回收与附能维持连续单奖进攻|资源不足、手牌干扰；轰鸣月不同于轰鸣月ex
roaring_moon|轰鸣月ex|尽快发展恶能加速与可用换位手段|强制昏厥招式附带自伤，另一招与竞技场联动|强制击倒大型目标时计算自身被收割代价|下一只攻击手与补能同步准备|自伤后被补刀；直接昏厥不同于攻击伤害
poison|猛恶菇,毛崖蟹,桃歹郎|组织中毒来源、换位与攻击手|特殊状态既可能增伤也可能造成检查阶段伤害|攻击加中毒跨越门槛，须区分结算时点|保持中毒来源与换位解状态手段|状态解除、能力封锁；中毒不是攻击伤害
conkeldurr|修建老匠|完成二阶进化并准备特殊状态|特殊状态满足招式免附能条件|单奖高输出换大型双奖目标|下一条进化线与可控特殊状态|进化慢、状态被解除，混乱影响招式成功
slowking|呆呆王|准备进化、附能与牌库顶控制|弃置顶牌若是合格非规则宝可梦则复制招式|工具箱改变对局，但未知顶牌只能条件化解释|维持顶牌控制与合格素材|顶牌失败、素材不符；绝不能读取真实牌库顶
terapagos|太乐巴戈斯ex,爆炸头水牛|发展备战规模与太晶辅助|备战数量、防守与能量路线共同支撑攻击|扩展备战收益与双奖辅助暴露并存|维持场地、换位、能量与后续攻击手|场地替换缩备战、辅助被抓
tera_box|猫头夜鹰,旋转洛托姆|建立太晶与猫头夜鹰检索循环|检索和换位支持多种太晶攻击手|按已公开的属性和招式选取奖方案|回收进化组件并维持能量分布|场地或能力依赖；未露出的攻击手不能预设
festival|虫甲圣,裹蜜虫,啃果虫|建立祭典场地与检索引擎|场地和祭典宝可梦能力联动|单奖连击与多目标奖赏价值一起考虑|保护检索核心并备份场地|场地被拆、能力封锁、后排被同时收掉
iron_thorns|铁荆棘ex|优先让前台铁荆棘具备持续攻击的能量|战斗场特性压制部分规则宝可梦特性|拖慢启动制造攻击节奏差|换位与能量分配维持前台压制|未来等豁免、拉走前台；不是所有特性都失效
walls|岩殿居蟹,奇麒麟ex,厄诡椪 础石面具ex,谜拟丘|根据公开攻击来源选择防守宝可梦|不同墙的免疫对象不同，须核对标记和文本|拖延与交换争取取奖，不能只看伤害|治疗、换位与不同墙接替|穿透效果、指示物、直接昏厥；伤害免疫不是效果免疫
snorlax|卡比兽|把适合限制的目标留在对方前台|限制撤退并消耗换位，可能以耗尽牌库获胜|控制优势不能只用奖赏领先衡量|保留控制资源与自身牌库循环|仍有换位或攻击出路时不能宣称锁死
pidgeot_control|大比鸟ex|完成二阶检索引擎并确认公开威胁|定向检索支持控制、回复或攻击|实际公开组件决定路线，见大比鸟不等于控制套牌|保持核心、回收与替补|能力封锁、核心被直接击倒
blissey|幸福蛋ex,吉利蛋|发展进化、能量与防守|能量移动支持轮换和回复|高HP与回复增加对方取奖所需回合|可转移能量、治疗和替补攻击手|一击击倒、指示物压制、移动能力被封锁
gouging_fire|破空焰ex|高费用攻击需要尽快附能|攻击限制要求换位或替补解除节奏瓶颈|主动进攻同时安排下回合攻击者|换位和能量接力同等重要|卡前台、换位耗尽、辅助双奖被抓
darkrai|达克莱伊VSTAR,达克莱伊V|发展恶能量与弃牌道具|全场能量支撑输出，VSTAR回收一次性资源|铺能增伤与辅助目标暴露需权衡|持续附恶能并回收关键道具以保持输出|能力封锁、辅助被抓；不能臆测手牌
chien_pao|古剑豹ex,戟脊龙|保护凉脊龙完成二阶引擎|检索水能、自由附能和弃能攻击形成循环|按门槛分配能量，兼顾备战攻击|回收水能与保护戟脊龙|引擎被击倒、能力封锁、回收断链
ceruledge|苍炎刃鬼ex,炭小侍|发展进化并通过抽滤弃能|通过公开弃牌区的能量积累提高招式输出|低攻击投入争取高伤害奖赏交换|保证必要附能与下条进化线|弃能未成型、进化断档；只使用公开弃牌数量
joltik|电电虫|电电充能布置草雷能量|启动攻击牺牲直接伤害换能量|评估启动单奖被击倒后的接力收益|能量去向、换位与后续攻击手|启动被截断、能量分配失误；不预设未公开攻击手
regis|雷吉奇卡斯,雷吉艾斯,雷吉洛克,雷吉斯奇鲁,雷吉艾勒奇,雷吉铎拉戈|建立神柱组件与弃牌能量|组件齐全才形成附能循环|单奖多攻击手按属性与招式交换|复原被击倒组件并维护能量|缺组件、缩备战、能力封锁；单张龙柱不等于完整神柱体系
n_zoroark|N的索罗亚克ex,N的索罗亚|铺N进化线并发展抽滤|交易改善手牌，复制备战N宝可梦招式|根据公开复制目标选输出、补刀或干扰|保护复制来源和下一只索罗亚克|来源被清除、进化断档；不能任意复制所有招式
blaziken|火焰鸡ex,火焰鸡|完成二阶并准备弃牌能量|ex的附能支持接力；普通版本按文本分别理解|主攻或辅助角色依据实际变体|保护附能核心与替补进化|二阶资源拥挤、能力封锁、攻击后限制
flareon|火伊布ex,伊布ex|准备进化和首轮攻击附能|燃烧充能给自身或其他攻击手铺路|爆发后攻击限制要求轮换|多属性能量、换位与接力攻击手|进化被截断、前台受限、异色能量不足
froslass|雪妖女,愿增猿|建立持续指示物与转移组件|检查阶段累积指示物，转移把负担化为压力|延迟收割多个目标，兼顾己方承伤|维持组件并安排检查前后站位|无特性目标、能力封锁、己方先被收掉；不是直接攻击伤害
marnie|玛俐的长毛巨魔ex,玛俐的诈唬魔,玛俐的捣蛋小妖|发展进化并准备进化附能|庞克泵感给玛俐宝可梦附恶能，暗影子弹压制前后排|正面交换与后排补刀，辅助需见到才确认|下一条进化与基本恶能资源|二阶压制、能力封锁；暗影子弹后排是伤害不是指示物
toedscruel|陆地水母ex,原野水母,陆地水母|发展草系进化、铺场与附能|ex与普通版本功能不同，区分攻击、防护和回收限制|备战附能输出收益与核心暴露并存|保留草能供给和下一条替补进化线路|核心被抓、进化断档；不能合并不同卡文特性
hop|赫普的苍响ex|发展赫普辅助与钢能路线|低费前后排攻击和高费爆发切换|铺伤再收割，辅助增伤须实际在场|换位、能量与替补攻击手|英勇之刃下回合限制、辅助被击倒
ethan_hooh|阿响的凤王ex|发展阿响宝可梦并给后排附能|金色火焰从手牌附能，攻击回复支持持久战|比较进攻与多目标回复价值|手牌火能和换位保护能量|高费用、手牌干扰；不假设手中一定有火能
ethan_typhlosion|阿响的火暴兽,阿响的火岩鼠,阿响的火球鼠|建立二阶并使用阿响的冒险展开|弃牌区阿响的冒险数量提高搭档爆破输出|单奖主攻追求有利奖赏交换|支持者和替补进化保障续攻|进化断档；只使用公开弃牌数量
cynthia|竹兰的烈咬陆鲨ex,竹兰的尖牙陆鲨,竹兰的圆陆鲨|铺进化线，低费招式改善手牌|螺旋俯冲补牌，龙之爆破弃能换爆发|持续压制与爆发击倒之间选择|爆发后重新附能并备替补|弃能空档、二阶启动受压、手牌干扰
rocket_mewtwo|火箭队的超梦ex|先建立足够火箭队宝可梦和附能|达到场上数量条件才可攻击，后排弃能可增伤|高输出与后排能量成本一同计算|维持数量与能量再生组件|减员导致无法攻击、后排引擎被抓
yanmega|远古巨蜓ex,蜻蜻蜓|进化后准备从备战进入前台|换位触发自身附能，攻击后给后排转能|进攻同时建立下一轮攻击者|换位、手填与接力位置|进前台时机错误、换位耗尽、接力被抓
mamoswine|象牙猪ex,长毛猪,小山猪|多条二阶线路分配检索与进化资源|检索宝可梦稳定进化，后排二阶数量增伤|增伤同时管理暴露的后排|保护场上检索核心以及为其供能的组件|启动慢、后排二阶被清除、能力封锁
dusknoir|黑夜魔灵,彷徨夜灵,夜巡灵|准备额外进化线并关注目标门槛|主动昏厥换伤害指示物，付出奖赏与组件|自损奖赏与多目标击倒一起计算|一次性进化组件依赖回收|送出奖赏可能直接输；指示物不是攻击伤害
banette|诅咒娃娃ex,怨影娃娃|完成进化和限制道具的攻击条件|道具限制拖慢对方，为其他引擎争取时间|看关键行动受限程度而非只看伤害|根据节奏轮换限制攻击与其他主攻手|支持者和能力仍能展开，不是完全封锁
"""

GROUPS = {
 'regis':'1700001','archaludon':'1700002 1750001 800017280',
 'palkia terapagos tera_box':'1700003','palkia gholdengo':'1700004 575479',
 'charizard dusknoir':'1700005 575716 800025404','raging_bolt':'1700006 575718 620761 800018509',
 'miraidon':'1700007 1750003 575720 599947',
 'dragapult dusknoir':'1700008 1750002 575723 587205 675701 800015734 800018506',
 'dragapult charizard':'1700009 579502 18000230','poison terapagos':'1700010 620880',
 'regidrago':'1700011 575653 581056','roaring_moon':'1700012','slowking':'1750005 675834',
 'n_zoroark':'18000072 675899 800018502','n_zoroark pidgeot_control':'18000081',
 'n_zoroark toedscruel':'18000098','charizard':'18000320 620909',
 'blaziken pidgeot_control':'18000393','festival':'18000405 602769',
 'walls':'18000519 800015927 800052301','terapagos tera_box':'18000612',
 'blaziken froslass':'18000625','flareon pidgeot_control tera_box':'18000663',
 'dialga':'561444','arceus giratina':'569061','future':'572568','lost_box':'575620 594959',
 'lugia':'575657 609431','palkia dusknoir':'577861',
 'gardevoir':'578647 610080 675703 800017097 800018497 800018498 800030002',
 'iron_thorns':'579577','dragapult banette':'580445','blissey walls':'581614',
 'gouging_fire':'582754','darkrai':'591117','chien_pao':'593260','snorlax':'594635',
 'charizard arceus dragapult':'594978','ceruledge':'606452 610403 800017413',
 'dragapult iron_thorns toedscruel':'606676','conkeldurr poison':'607805',
 'joltik':'607807 800018817','ancient':'608194','gholdengo':'620753 800016834 800017070',
 'marnie':'646600 800018501','marnie froslass':'675700',
 'flareon tera_box':'675892 800017643','tera_box':'675893 800015934',
 'mamoswine blaziken':'800017047','blissey':'800017098','dragapult gholdengo':'800017405',
 'hop':'800017407','froslass':'800017631','gardevoir festival':'800018105',
 'roaring_moon poison':'800018334','pidgeot_control':'800018359',
 'dragapult':'800018499 800030001','toedscruel':'800018500','ethan_hooh':'800018539',
 'cynthia':'800018543','walls iron_thorns':'800018714','ethan_typhlosion':'800018880',
 'blaziken dragapult':'800019125','walls n_zoroark':'800021836',
 'rocket_mewtwo':'800026575','yanmega':'800033475',
}

def build():
    profiles = {}
    for row in ROWS.strip().splitlines():
        key, anchors, opening, engine, prizes, sustain, risks = row.split('|')
        profiles[key] = dict(anchors=anchors.split(','), opening=opening, engine=engine,
                             prizes=prizes, sustain=sustain, risks=risks, printings=[])
    for path in sorted((ROOT/'data/bundled_user/cards').glob('*.json')):
        card = json.loads(path.read_text(encoding='utf-8-sig'))
        for profile in profiles.values():
            if card.get('name') in profile['anchors'] or card.get('name_zh') in profile['anchors']:
                profile['printings'].append(path.stem)
    coverage = {}
    for keys, ids in GROUPS.items():
        for deck_id in ids.split():
            assert deck_id not in coverage, f'duplicate deck: {deck_id}'
            coverage[deck_id] = keys.split()
    actual = {}
    for path in sorted((ROOT/'data/bundled_user/decks').glob('*.json')):
        deck = json.loads(path.read_text(encoding='utf-8-sig'))
        actual[str(deck['id'])] = deck
    assert actual.keys() == coverage.keys(), f'Unreviewed: {actual.keys()-coverage.keys()}, stale: {coverage.keys()-actual.keys()}'
    # Name matching is only a candidate discovery step. Bind each profile ONLY
    # to printings actually audited in explicitly mapped decks. E.g. dragon
    # Miraidon ex and non-Block Snorlax must not inherit the lightning/control guide.
    used_printings = {key: set() for key in profiles}
    for deck_id, keys in coverage.items():
        uids = {f"{c['set_code']}_{c['card_index']}" for c in actual[deck_id]['cards']}
        for key in keys:
            used_printings[key].update(uids.intersection(profiles[key]['printings']))
    for key, profile in profiles.items():
        profile['printings'] = sorted(used_printings[key])
    for deck_id, keys in coverage.items():
        uids = {f"{c['set_code']}_{c['card_index']}" for c in actual[deck_id]['cards']}
        for key in keys:
            assert uids.intersection(profiles[key]['printings']), f'{deck_id} has no anchor for {key}'
    output = dict(schema=1, revision='2026-09-29.1', perspective='public_observer',
                  source='Bundled exact card texts; authored mechanism briefs, not metagame rankings.',
                  profiles=profiles, deck_coverage=coverage)
    target = ROOT/'data/commentary/deck_knowledge.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{len(actual)} decks, {len(profiles)} mechanism profiles; exact printing coverage checked')

if __name__ == '__main__':
    build()
