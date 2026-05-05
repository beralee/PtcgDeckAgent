# Deck Recommendation Feed Design

## Goal

Replace the current three-card deck recommendation strip in the deck manager with a single rich recommendation feed card.

The recommendation should answer one primary player question:

> 这套牌为什么值得玩？

It should not feel like homework, a training checklist, or a prompt telling the player what they must practice. The card can still include one small piloting hint, but the center of gravity is deck appeal: play style, interesting decisions, current environment relevance, and who may enjoy it.

This document is a design proposal only. It does not implement the new UI or service client.

## Current Context

`scenes/deck_manager/DeckManager.gd` currently:

- Reads embedded community content from `res://community/data/community-data.json`.
- Extracts `environment_briefing.articles`.
- Sorts articles by source date and player count.
- Keeps at most `MAX_RECOMMENDATION_CARDS = 3`.
- Renders them in `RecommendationSection/RecommendationCards` above the saved deck list.
- Each recommendation card includes title, event metadata, thesis, bullet points, and three actions:
  - `导入这套`
  - `查看解读`
  - `原卡表`

This works as a static bundled recommendation block, but it has two problems:

1. The top area becomes visually dense, especially on mobile.
2. Recommendation content updates require client content updates unless served externally.

## Chosen Direction

Move to a single recommendation card backed by a lightweight cloud function.

The deck manager shows one recommendation at a time. When the player chooses `换一套`, the client asks the server for another recommendation, stores the returned recommendation locally, and updates the visible card.

The service owns recommendation generation, ranking, rotation, and freshness. The client owns display, cache, import, and fallback behavior.

## Reviewed Engineering Decisions

These decisions are intended to keep the change contained to the deck manager recommendation surface and prevent unintended effects in other modules:

1. Do not change `DeckImporter.gd`, `CardDatabase.gd`, or `DeckData.gd` persistence contracts.
2. Do not auto-create, auto-update, or auto-delete player decks from recommendation data.
3. Keep recommendation cache under `user://deck_recommendations/`; never write recommendation state into `res://`.
4. Treat cloud recommendation content as untrusted display data. Escape or render as plain text unless a field is explicitly sanitized.
5. Keep the recommendation cloud function separate from the feedback cloud function.
6. Keep recommendation networking lazy and local to `DeckManager`; battle setup, battle scene, deck editor, replay, tournament, and AI settings should not load this client.
7. Keep the existing manual import path intact. `导入这套` should call the existing `_start_import_from_url()` entry point rather than duplicating import behavior.
8. Network failure must not block deck list rendering, saved deck actions, manual import, image sync, or navigation.

## Product Positioning

The recommendation card is not a "daily drill" panel.

It is closer to a deck magazine card:

- "This deck is fun because..."
- "This deck is worth trying because..."
- "This deck teaches a current environment pattern because..."
- "This deck suits players who like..."

Avoid copy that sounds like obligation:

- Avoid: `今天请练习这套牌的前两回合展开`
- Prefer: `这套牌的爽点在于前两回合就能把进攻节奏摆上桌`

- Avoid: `练习目标`
- Prefer: `为什么值得玩`, `适合谁`, `上手看点`

## Player Experience

### First View

When entering deck manager:

1. Show the cached latest recommendation immediately if available.
2. If no cache exists, show the best embedded fallback recommendation.
3. Optionally refresh from server in the background.
4. Never block the saved deck list on recommendation loading.

### Single Recommendation Card

The card should include:

- Deck name
- A short title or hook
- Source metadata: event, city, date, player count, or "服务器推荐"
- One-sentence play style summary
- 2-3 "why play" bullets
- One "best for" line
- One optional piloting tip
- Actions:
  - `导入这套`
  - `换一套`
  - `查看完整解读`

`原卡表` can be folded into the full detail view or kept as a secondary icon action if there is room. The main card should not look like a button cluster.

### Full Detail

`查看完整解读` opens a HUD-styled modal, not a default Godot dialog.

The detail modal can show:

- Full recommendation title
- Source/event metadata
- Why this deck is currently interesting
- Game plan overview
- Strengths
- Weak spots
- Matchups or environment notes if available
- Card/deck link
- Import action

This preserves depth without overcrowding the first screen.

### Change Recommendation

`换一套` should feel instant when possible:

1. If local cache has another recommendation not currently shown, switch to it immediately.
2. In parallel, ask the server for a fresh recommendation.
3. If server returns a valid new recommendation, append it to cache and display it.
4. If server fails, keep the current card and show a small status line such as:
   - `暂时没刷到新推荐，先看这套。`

Do not replace the card with an error panel unless there is no cached or embedded fallback content.

## Proposed UI Layout

Within the existing deck manager scroll list, replace `RecommendationCards` with one `RecommendationFeedCard`.

Suggested structure:

```text
今日值得一玩的卡组                         [换一套]

猛雷鼓 Ogerpon
高速展开、资源爆发、连续制造大伤害窗口

为什么值得玩
• 前两回合就能形成明确进攻节奏，反馈直接。
• 能量调度和爆发伤害的决策密度高，赢法很有辨识度。
• 适合作为理解当前环境速度线的样本。

适合谁
喜欢主动进攻、快速做大伤害、接受资源取舍的玩家。

上手看点
不要只看这一回合伤害，提前规划下一只攻击手的能量来源。

重庆赛样本 · 64人 · 2026-05-04          [导入这套] [查看完整解读]
```

On mobile, the action row can wrap:

```text
[导入这套] [查看完整解读]
[换一套]
```

## Client Data Model

The client should normalize every recommendation into one stable shape before rendering.

```json
{
  "id": "2026-05-04-raging-bolt-ogrepon",
  "deck_id": 599382,
  "deck_name": "猛雷鼓 Ogerpon",
  "title": "一套节奏直接、爆发明确的进攻型卡组",
  "style_summary": "高速展开、资源爆发、连续制造大伤害窗口。",
  "why_play": [
    "前两回合就能形成明确进攻节奏，反馈直接。",
    "能量调度和爆发伤害的决策密度高，赢法很有辨识度。",
    "适合作为理解当前环境速度线的样本。"
  ],
  "best_for": "喜欢主动进攻、快速做大伤害、接受资源取舍的玩家。",
  "pilot_tip": "不要只看这一回合伤害，提前规划下一只攻击手的能量来源。",
  "source": {
    "label": "重庆赛样本",
    "city": "重庆",
    "date": "2026-05-04",
    "players": 64,
    "url": ""
  },
  "import_url": "https://tcg.mik.moe/decks/list/599382",
  "detail": {
    "sections": [
      {
        "heading": "为什么现在值得试",
        "body": "..."
      }
    ]
  },
  "generated_at": "2026-05-04T00:00:00Z"
}
```

Required fields:

- `id`
- `deck_name`
- `title` or `style_summary`
- `import_url`

Recommended fields:

- `why_play`
- `best_for`
- `pilot_tip`
- `source`
- `detail`

If required fields are missing, the client should reject the server item and keep the existing display.

## Cloud Function Contract

### Endpoint

Use a dedicated endpoint separate from feedback submission.

Proposed endpoint:

```text
http://fc.skillserver.cn/deck-recommendation
```

The exact route can change, but it should not share feedback function logic. Recommendation traffic has different request/response shape, caching behavior, and failure semantics.

### Request

```json
{
  "app_version": "v0.2.1",
  "platform": "Android",
  "mode": "next",
  "current_id": "2026-05-04-raging-bolt-ogrepon",
  "seen_ids": [
    "2026-05-04-raging-bolt-ogrepon",
    "2026-05-03-lost-box"
  ],
  "local_deck_ids": [575716, 578647],
  "locale": "zh-CN"
}
```

Field notes:

- `mode`: initially only `next`; future values can include `refresh` or `by_id`.
- `seen_ids`: helps the service avoid repeating recent cards.
- `local_deck_ids`: optional; helps avoid recommending what the player already imported.
- `locale`: reserved for future text variants.

### Response

```json
{
  "ok": true,
  "recommendation": {
    "id": "2026-05-04-raging-bolt-ogrepon",
    "deck_id": 599382,
    "deck_name": "猛雷鼓 Ogerpon",
    "title": "一套节奏直接、爆发明确的进攻型卡组",
    "style_summary": "高速展开、资源爆发、连续制造大伤害窗口。",
    "why_play": [
      "前两回合就能形成明确进攻节奏，反馈直接。",
      "能量调度和爆发伤害的决策密度高，赢法很有辨识度。"
    ],
    "best_for": "喜欢主动进攻、快速做大伤害、接受资源取舍的玩家。",
    "pilot_tip": "不要只看这一回合伤害，提前规划下一只攻击手的能量来源。",
    "source": {
      "label": "重庆赛样本",
      "city": "重庆",
      "date": "2026-05-04",
      "players": 64
    },
    "import_url": "https://tcg.mik.moe/decks/list/599382",
    "detail": {
      "sections": []
    },
    "generated_at": "2026-05-04T00:00:00Z"
  }
}
```

Failure response:

```json
{
  "ok": false,
  "code": "NO_RECOMMENDATION",
  "message": "暂时没有新的推荐"
}
```

The client should treat non-2xx responses, invalid JSON, `ok: false`, and invalid recommendation shape as recoverable failures.

## Validation And Safety

Recommendation payloads come from a remote service, so the client should validate and normalize before rendering:

- `id`, `deck_name`, and `import_url` are trimmed strings.
- `import_url` must parse as a deck import target accepted by `DeckImporter.parse_deck_id()`.
- `why_play` is capped to 3 visible items.
- `best_for`, `pilot_tip`, `title`, and `style_summary` are capped to UI-safe lengths before display.
- Unknown fields are ignored.
- Detail sections are capped by count and text length.
- Text from the server should be assigned to `Label.text` or escaped before entering any `RichTextLabel` with BBCode enabled.
- External `source.url` links, if supported later, must be `http://` or `https://` and opened only from an explicit player action.

The client should reject a server item if it cannot produce a valid normalized recommendation. Rejection keeps the current card visible and reports a small non-blocking status message.

## Local Cache

Suggested cache path:

```text
user://deck_recommendations/cache.json
```

Suggested shape:

```json
{
  "schema_version": 1,
  "current_id": "2026-05-04-raging-bolt-ogrepon",
  "items": [
    {
      "id": "2026-05-04-raging-bolt-ogrepon",
      "deck_name": "猛雷鼓 Ogerpon"
    }
  ],
  "updated_at": 1777850000
}
```

Cache rules:

- Keep the most recent 10 valid recommendations.
- De-duplicate by `id`.
- Persist server items only after successful validation.
- On `换一套`, prefer an unseen cached item before waiting on network.
- Do not automatically import or overwrite player decks from cache.

## Fallback Strategy

Display priority:

1. Current valid cached recommendation.
2. Another valid cached recommendation.
3. Embedded recommendation converted from `community-data.json`.
4. Empty lightweight placeholder with `稍后再试`.

Embedded fallback should use the same normalized model as server data. This lets the UI renderer stay simple and keeps old static content useful.

## Proposed Client Components

### `DeckRecommendationClient.gd`

Responsibilities:

- POST to the recommendation cloud function.
- Timeout after about 10-12 seconds.
- Emit `recommendation_received(recommendation: Dictionary)`.
- Emit `request_failed(message: String)`.

This mirrors the lightweight pattern already used by `FeedbackClient.gd`, but keeps the endpoint and response validation separate.

### `DeckRecommendationStore.gd`

Responsibilities:

- Load and save `user://deck_recommendations/cache.json`.
- Normalize server and embedded recommendations.
- Validate required fields.
- Track current id.
- Return next cached item.

This keeps file I/O out of `DeckManager.gd`.

### `DeckManager.gd`

Responsibilities:

- Render one recommendation card.
- Wire `导入这套` to the existing `_start_import_from_url`.
- Wire `查看完整解读` to a HUD detail modal.
- Wire `换一套` to store + client orchestration.
- Keep existing saved deck list behavior unchanged.

Request orchestration rules:

- At most one recommendation request should be active at a time.
- Disable only the `换一套` button while a request is in progress.
- If the player navigates away, late responses should be ignored.
- If a cached next item is shown immediately, a later server success may replace it only if the returned item is valid.
- A failed server response must not clear the current recommendation.

## Implementation Phases

### Phase 1: Local UI Refactor

- Convert embedded recommendations into the new normalized model.
- Replace the three-card row with a single rich card.
- Keep all content local.
- Update `tests/test_deck_manager.gd` to expect one recommendation card.

This gives a visible product improvement before the service exists.

### Phase 2: Cache Store

- Add cache read/write.
- Persist the current displayed recommendation.
- Support cycling cached items.
- Add tests for cache validation, de-duplication, and fallback ordering.

### Phase 3: Cloud Function Client

- Add `DeckRecommendationClient.gd`.
- Add request/response normalization.
- Wire `换一套` to cached item first, then network.
- Handle timeout and failure without blanking the card.

### Phase 4: Service Content Maturity

- Let the server-side agent produce daily recommendation records.
- Include stable ids and import URLs.
- Keep old records available so clients can rotate without requiring daily connectivity.
- Optionally add tags later, such as `进攻`, `控制`, `新手友好`, `高操作上限`.

## Testing Plan

Extend or update `tests/test_deck_manager.gd`:

- The recommendation section renders one feed card, not three compact cards.
- The card includes `为什么值得玩` copy or equivalent normalized fields.
- `导入这套` still calls the existing import path.
- Embedded fallback normalizes into the new model.
- Invalid server recommendation does not replace the current card.
- Cache de-duplicates by id and keeps a bounded number of items.
- `换一套` shows cached next item before relying on network.

Add focused tests for any new scripts:

- `DeckRecommendationStore.gd`
  - validate required fields
  - load missing cache
  - save and reload
  - de-duplicate
  - next item selection
- `DeckRecommendationClient.gd`
  - response parse success
  - `ok: false` failure
  - malformed JSON failure
  - timeout or request failure mapping

## Risks And Decisions

### Risk: One card may still become too dense

Mitigation: Keep first-screen text curated:

- Max 3 `why_play` bullets.
- Max 1 `best_for`.
- Max 1 `pilot_tip`.
- Move long matchup analysis into detail modal.

### Risk: Server content quality varies

Mitigation: Client validates shape, not quality. Server-side generation should use a template that forces concise, player-facing fields.

### Risk: Network failure makes the feature feel broken

Mitigation: Always keep cache and embedded fallback. `换一套` should never clear the current recommendation before a replacement is ready.

### Risk: Recommendation repeats too often

Mitigation: Send `seen_ids`, keep local recent ids, and let the server avoid repeating when possible.

### Decision: Import remains user initiated

The recommendation module should never automatically create or overwrite a local deck. It only recommends and then calls the existing import flow after the player presses `导入这套`.

### Decision: Service returns content, not engine data

The server should return recommendation metadata and a deck import URL. The client should continue using the existing `DeckImporter` for actual deck acquisition. This avoids coupling the service to internal `DeckData` persistence details.
