# Full Library Search UI Design

## Goal

Improve card-search interactions so effects that let the player search their own full deck behave closer to real tabletop play: the player can inspect the whole searchable deck, while only legal targets are selectable. This should reuse the visual idea from Hisuian Heavy Ball: show valid choices clearly, keep other known cards visible, and do not silently hide context.

This document is a design and implementation plan only. It does not change card rules by itself.

## Scope

Use this UI for effects that search or choose from the player's own full deck and then shuffle the deck.

Do not use this UI for effects that only reveal the top or bottom N cards. Those effects may reuse the same card-grid component, but they must only show the N cards the rules reveal.

Do not reveal hidden opponent deck contents. Effects that look at the opponent deck must only display the explicitly revealed top or bottom cards.

## Source Of Truth

The scan used `data/bundled_user/cards/*.json` as the default new-install card pool. Current count is 245 card JSON files.

The trigger text was searched from `description`, `abilities[]`, and `attacks[]` for full-deck search phrases such as:

- `选择自己牌库中的`
- `从自己牌库中选择`
- `选择自己牌库中任意`
- `选择自己牌库中最多`

The scan excluded top or bottom N reveal text such as `查看自己牌库上方` and `查看自己牌库下方`.

## Full Deck UI Candidates

### Items

| Key | Card | Search role |
|---|---|---|
| `CSV7C_177` | 友好宝芬 / Buddy-Buddy Poffin | Search up to 2 HP 70 or lower Basic Pokemon to bench |
| `CS6aC_120` | 捕获香氛 / Capturing Aroma | Coin-gated Basic or Evolution Pokemon to hand |
| `CSV6C_115` | 大地容器 / Earthen Vessel | Search up to 2 Basic Energy to hand |
| `CSVH1C_035` | 能量输送 / Energy Search | Search 1 Basic Energy to hand |
| `CSV7C_178` | 高级香氛 / Hyper Aroma | Search up to 3 Stage 1 Pokemon to hand |
| `CSV2C_111` | 鼓励信 / Letter of Encouragement | Search up to 3 Basic Energy to hand |
| `CSV7C_181` | 大师球 / Master Ball | Search 1 Pokemon to hand |
| `CS6bC_122` | 幻象之门 / Mirage Gate | Search up to 2 different-type Basic Energy and attach |
| `CSVH1C_043` | 巢穴球 / Nest Ball | Search 1 Basic Pokemon to bench |
| `CSV8C_176` | 秘密箱 / Secret Box | Search Item, Tool, Supporter, Stadium to hand |
| `CSV6C_116` | 高科技雷达 / Techno Radar | Search up to 2 Future Pokemon to hand |
| `CSV1C_112` | 高级球 / Ultra Ball | Search 1 Pokemon to hand |

### Supporters

| Key | Card | Search role |
|---|---|---|
| `CSV1C_123` | 派帕 / Arven | Search Item and Tool to hand |
| `CSV7C_191` | 暗码迷的解读 / Ciphermaniac's Codebreaking | Search any 2 cards and place on top |
| `CSV8C_191` | 阿克罗玛的执念 / Colress's Tenacity | Search Stadium and Energy to hand |
| `CS5DC_138` | 珠贝 / Irida | Search Water Pokemon and Item to hand |
| `CSV1C_120` | 吉尼亚 / Jacq | Search up to 2 Evolution Pokemon to hand |
| `CSV8C_192` | 阿杏的秘招 / Janine's Secret Art | Search Basic Darkness Energy and attach to Darkness Pokemon |
| `CS6.5C_070` | 阿渡 / Lance | Search up to 3 Dragon Pokemon to hand |
| `CSV7C_194` | 赛吉 / Salvatore | Search evolution card from deck and evolve a Pokemon |

### Stadiums

| Key | Card | Search role |
|---|---|---|
| `CSV2C_127` | 深钵镇 / Artazon | Search non-rulebox Basic Pokemon to bench |
| `CSV1C_126` | 桌台市 / Mesagoza | Heads: search 1 Pokemon to hand |
| `CSV5C_128` | 城镇百货 / Town Store | Search 1 Tool to hand |

### Tools And Tool Attacks

| Key | Card | Search role |
|---|---|---|
| `CS6.5C_066` | 森林封印石 / Forest Seal Stone | VSTAR ability searches any 1 card to hand |
| `CSV5C_119` | 招式学习器 进化 / Technical Machine: Evolution | Attack searches evolutions for up to 2 bench Pokemon |
| `CSV4C_119` | 招式学习器 能量涡轮 / Technical Machine: Turbo Energize | Attack searches up to 2 Basic Energy and attaches to bench |

### Pokemon Abilities

| Key | Card | Search role |
|---|---|---|
| `CS5aC_107` | 阿尔宙斯VSTAR / Arceus VSTAR | Starbirth searches any 2 cards |
| `CS6aC_113` | 始祖大鸟 / Archeops | Primal Turbo searches up to 2 Special Energy and attaches |
| `CSV5C_075` | 喷火龙ex / Charizard ex | Infernal Reign searches up to 3 Basic Fire Energy and attaches |
| `CSV3C_043` | 古剑豹ex / Chien-Pao ex | Shivery Chill searches up to 2 Basic Water Energy to hand |
| `151C_132` | 百变怪 / Ditto | Transformative Start searches Basic Pokemon replacement |
| `CS5bC_049` | 霓虹鱼V / Lumineon V | Luminous Sign searches Supporter to hand |
| `CSV1C_050` | 密勒顿ex / Miraidon ex | Tandem Unit searches up to 2 Lightning Basic Pokemon to bench |
| `CSV4C_101` | 大比鸟ex / Pidgeot ex | Quick Search searches any 1 card |

### Pokemon Attacks

| Key | Card | Search role |
|---|---|---|
| `CSNC_009` | 阿尔宙斯V / Arceus V | Trinity Charge searches up to 3 Basic Energy and attaches to Pokemon V |
| `CS5aC_107` | 阿尔宙斯VSTAR / Arceus VSTAR | Trinity Nova searches up to 3 Basic Energy and attaches to Pokemon V |
| `CS6aC_083` | 铁哑铃 / Beldum | Magnetic Lift searches any 1 card to deck top |
| `SVP_105` | 索财灵 / Gimmighoul | Call for Family searches Basic Pokemon to bench |
| `CSV7C_123` | 甲贺忍蛙ex / Greninja ex | Shinobi Blade optionally searches any 1 card |
| `CS6bC_117` | 泡沫栗鼠 / Minccino | Call for Family searches up to 2 Basic Pokemon to bench |
| `CSV7C_153` | 密勒顿 / Miraidon | Peak Acceleration searches up to 2 Basic Energy and attaches to Future Pokemon |
| `CSV8C_133` | 够赞狗ex / Okidogi ex | Poisonous Muscle searches up to 2 Basic Darkness Energy and attaches to self |
| `CSNC_003` | 起源帕路奇亚V / Origin Forme Palkia V | Rule the Region searches Stadium to hand |
| `CS5aC_019` | 雷丘V / Raichu V | Fast Charge searches Lightning Energy and attaches to self |

## Explicit Non-Candidates

These cards should not show the full deck because the rules only reveal top or bottom N cards:

| Card | Allowed visibility |
|---|---|
| 电气发生器 / Electric Generator | Top 5 own deck only |
| 能量签 / Energy Loto | Top 7 own deck only |
| 超级球 / Great Ball | Top 7 own deck only |
| 宝可装置3.0 / Pokegear 3.0 | Top 7 own deck only |
| 健行鞋 / Trekking Shoes | Top 1 own deck only |
| 黑暗球 / Dusk Ball | Bottom 7 own deck only |
| 配乐之笛 / Accompanying Flute | Top 5 opponent deck only |
| 花疗环环 / Comfey | Top 2 own deck only |
| 多龙奇 / Drakloak | Top 2 own deck only |
| 金属怪 / Metang | Top 4 own deck only |
| 骑拉帝纳V / Giratina V | Top 4 own deck only |
| 米立龙 / Tatsugiri | Top 6 own deck only |
| 阿克罗玛的实验 / Colress's Experiment | Top 5 own deck only |
| 野贼三姐妹 / Miss Fortune Sisters | Top 5 opponent deck only |

Some draw-only effects, such as Squawkabilly ex, Professor Sada's Vitality, Mela, Blissey ex, Teal Mask Ogerpon ex, and Mew ex, draw from the deck but do not choose from deck contents. They are outside this UI change.

## UX Contract

For own full-deck search effects:

1. Show a card-grid view of the full current deck.
2. Legal choices are enabled and visually marked as selectable.
3. Illegal cards are visible, dimmed, and carry an `不可选` or reason badge.
4. The header states the exact rule filter, such as `选择最多2张基本能量`.
5. The footer shows selected count, minimum, maximum, and whether the effect allows zero selection.
6. Right-click or long-press still opens card detail for both selectable and non-selectable cards.
7. Confirm only becomes available when the current selection satisfies the rule.

For assignment effects, such as Mirage Gate, Archeops, Janine's Secret Art, Technical Machine: Turbo Energize, and Charizard ex:

1. The source panel shows full deck contents with legal source cards enabled.
2. Target selection continues to enforce legal field targets.
3. The assignment summary shows `source -> target` pairs.
4. Illegal source cards remain visible but cannot be assigned.

For top or bottom N effects:

1. Reuse the same card-grid visual if useful.
2. Only show the revealed N cards.
3. Never include unviewed deck cards in the interaction payload or replay snapshot.

## Implementation Design

### Reviewed Engineering Decisions

These decisions are part of the reviewed design and should be treated as implementation constraints:

1. Keep the existing execution contract unchanged: `items` remains the list of legal selectable choices consumed by rules, AI, headless, and effect execution.
2. Full-deck visibility must be opt-in through explicit helper metadata or an allowlisted effect migration. Do not infer it centrally from generic text such as `source_zone = "deck"`, because top-N, bottom-N, opponent-reveal, and deck-top placement effects have different visibility rules.
3. Prefer the existing dialog adapter path: `card_items` or equivalent visible cards plus `card_indices` where disabled visible cards map to `-1`, with `card_disabled_badge` for the HUD badge. Add new keys only when this adapter is not expressive enough.
4. AI and headless bridges must ignore visible-only disabled cards and continue resolving only from legal `items`, `source_items`, and `target_items`.
5. Replay and audit payloads may record own-deck full-search visible identities for debugging, but must never record or expose unrevealed opponent deck cards.
6. Full-deck card order should default to current deck order for tabletop inspection. UI filters may provide display-only grouping, but must not mutate the underlying execution order or imply extra shuffle behavior.
7. Effects that place cards on top of the deck, such as Ciphermaniac's Codebreaking and Beldum, must preserve their ordering semantics and must not inherit shuffle-after-search behavior from generic full-deck search helpers.

### Shared Interaction Shape

Add or standardize a deck-search step shape that can be consumed by `BattleDialogController`:

```gdscript
{
	"id": "nest_ball_target",
	"title": "选择1张基础宝可梦放于备战区",
	"items": selectable_cards,
	"labels": selectable_labels,
	"visible_items": full_deck_cards,
	"visible_labels": full_deck_labels,
	"selectable_indices": [0, 4, 9],
	"source_zone": "deck",
	"visible_scope": "own_full_deck",
	"card_disabled_badge": "不可选",
	"min_select": 1,
	"max_select": 1
}
```

The exact key names can be adjusted during implementation, but the distinction must remain:

- `visible_items`: every card the player is allowed to inspect.
- `items`: legal selectable cards passed to execution.
- `selectable_indices`: mapping from visible cards to legal `items` entries, or equivalent `card_indices` mapping.

The current dialog implementation already supports `card_indices` with negative disabled entries and `card_disabled_badge`, so the low-risk path is to adapt full-deck search steps into that existing mechanism.

### Batch Layer

Most UI work should be shared:

1. Add a helper in `BaseEffect` or a small interaction helper to build full-deck search steps.
2. Extend `BattleDialogController._populate_card_dialog_cards()` to support full visible deck lists and disabled cards if current `card_indices` is not enough.
3. Keep `EffectProcessor`, `GameStateMachine`, and rule legality unchanged.
4. Keep AI and Headless resolvers selecting from legal `items`, not from the visible disabled cards.
5. Add replay/audit serialization for both visible and selectable counts.

The helper should expose two modes:

1. `own_full_deck_search`: visible scope is the player's full current deck, selectable cards are legal targets only, and the effect may shuffle or preserve order according to its own rule text.
2. `limited_reveal_search`: visible scope is only the rule-revealed top or bottom N cards, with no access to the rest of the deck.

Do not add a generic "deck search means full deck" fallback. New or migrated effects must choose one of the explicit modes above.

### Card Migration Strategy

Migrate in batches by effect class, not one card at a time:

1. Generic search-to-hand effects: Ultra Ball, Master Ball, Energy Search, Earthen Vessel, Lance, Jacq, Irida, Arven, Forest Seal Stone, Pidgeot ex.
2. Search-to-bench effects: Nest Ball, Buddy-Buddy Poffin, Artazon, Miraidon ex, Ditto, Minccino, Gimmighoul.
3. Search-and-attach effects: Mirage Gate, Archeops, Charizard ex, Janine's Secret Art, TM Turbo Energize, Raichu V, Miraidon, Arceus V/VSTAR.
4. Search-and-evolve effects: Salvatore, TM Evolution.
5. Special order effects: Ciphermaniac's Codebreaking, Beldum.

## Batch Impact

### Broad Shared Impact

These changes affect multiple cards at once:

| Area | Impact |
|---|---|
| `BattleDialogController` card-grid display | Full-deck visible cards, disabled cards, selection badges, mobile scroll behavior |
| `BattleScene` effect interaction flow | Passing enriched step data through `_show_dialog()` and replay snapshots |
| `BaseEffect` interaction helpers | Standard full-deck search step construction |
| AI and Headless interaction bridge | Must ignore non-selectable visible cards |
| Tests and scenario snapshots | Need assert visible card count vs selectable card count |

### Card-Specific Or Deck-Specific Risk

| Deck or archetype | Cards affected | Risk |
|---|---|---|
| Miraidon | Miraidon ex, Nest Ball, Electric Generator as non-candidate | Need keep Tandem Unit full-deck visible but Electric Generator top 5 only |
| Lugia Archeops | Archeops, Capturing Aroma, Ultra Ball | Archeops is assignment from full deck; Capturing Aroma has coin branch filters |
| Charizard | Charizard ex, Pidgeot ex, Arven, Forest Seal Stone, TM Evolution, Buddy-Buddy Poffin | Multiple search categories and evolution routes; high regression risk |
| Gardevoir | Buddy-Buddy Poffin, Ultra Ball, Jacq, TM Evolution, Salvatore | Evolution-line filtering must remain exact |
| Raging Bolt and Roaring Moon | Nest Ball, Earthen Vessel, Secret Box, Janine's Secret Art | Must not let full-deck display alter energy or discard costs |
| Chien-Pao | Chien-Pao ex, Irida, Superior search-like cards if added later | Ability is full-deck energy search; top/bottom effects still separate |
| Arceus Giratina | Arceus V/VSTAR, Forest Seal Stone, Giratina V as non-candidate | Starbirth full deck, Abyss Seeking top 4 only |
| Lost Box | Mirage Gate, Colress's Experiment as non-candidate, Comfey as non-candidate | Full-deck Mirage Gate vs top-card Lost Zone effects must stay distinct |

## Test Plan

### Shared UI Tests

Add tests that construct a full-deck search step with 10 cards and 3 legal candidates:

1. Card dialog renders 10 cards.
2. Only 3 cards are clickable/selectable.
3. Disabled cards show the disabled badge.
4. Confirm returns only legal selected cards.
5. Right-click detail works for disabled cards.

### Effect Tests

For each migrated effect class, add at least one behavior test:

1. Full deck size is represented in the interaction data.
2. Selectable count matches card rules.
3. Executing with a legal selection produces the old expected result.
4. Attempting to execute with an illegal visible card falls back or no-ops according to existing safety policy.

### Non-Leakage Tests

Add negative tests for top or bottom N effects:

1. Electric Generator shows 5 cards, not full deck.
2. Dusk Ball shows bottom 7 cards, not full deck.
3. Miss Fortune Sisters and Accompanying Flute show only opponent revealed top cards, not opponent full deck.

### Regression Tests

Run focused UI tests first, then functional test suite. If `BattleDialogController` or `BattleScene` changes, run the full functional group before calling the UI migration complete.

## Rollout Plan

### Phase 1: Shared UI Contract

Implement full-deck visible card support in one shared card dialog path. Use a synthetic test step to validate enabled and disabled cards before touching specific effects.

### Phase 2: Item And Supporter Search

Migrate the high-frequency Trainer effects first: Nest Ball, Ultra Ball, Earthen Vessel, Buddy-Buddy Poffin, Arven, Irida, Jacq, Lance, Forest Seal Stone.

### Phase 3: Pokemon Ability And Attack Search

Migrate Miraidon ex, Pidgeot ex, Archeops, Charizard ex, Chien-Pao ex, Arceus V/VSTAR, Raichu V, and the search-to-bench attacks.

### Phase 4: Assignment And Evolution Routes

Migrate Mirage Gate, Janine's Secret Art, TM Turbo Energize, TM Evolution, Salvatore, Ciphermaniac's Codebreaking, and Beldum. This phase needs the most careful target-pair validation.

### Phase 5: Audit Guard

Add an audit test or helper that scans full-deck search cards and fails if a migrated effect only exposes legal candidates without `visible_items` or equivalent full-deck visibility metadata.

## Acceptance Criteria

1. All 43 full-deck candidates either use the shared full-library UI or are explicitly documented as deferred.
2. Top or bottom N cards never reveal the full deck.
3. Opponent hidden deck contents are never exposed beyond rules text.
4. AI and Headless behavior is unchanged except for richer prompt/audit metadata.
5. Existing effect behavior tests continue to pass.
6. Mobile usability is preserved by using the HUD scroll container style and wide touch-friendly scrollbars.

## Open Implementation Decisions

1. Quick filters such as `可选`, `宝可梦`, `能量`, and `训练家` are useful for large deck views, but they are optional UI polish and should not block the first safe rollout.
2. Replay snapshots should record visible own-deck identities only when the interaction is explicitly marked `visible_scope = "own_full_deck"` or equivalent. If replay size becomes a problem, move card identities behind a debug or audit flag while keeping visible/selectable counts in normal replay data.
3. Assignment effects need a shared source-to-target HUD treatment after the basic full-deck grid is stable. Do not migrate the hardest assignment effects before the simple one-panel search effects pass tests.
