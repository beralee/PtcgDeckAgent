# Deck Recommendation Payload Schema

Submit a top-level object with `priority` and `recommendation`.

```json
{
  "priority": 120,
  "recommendation": {
    "id": "2026-05-05-t3151-d584607-iron-thorns",
    "deck_id": 584607,
    "deck_name": "深圳冠军铁荆棘",
    "title": "深圳冠军铁荆棘：用特性封锁抢环境节奏",
    "style_summary": "让铁荆棘ex站在战斗场压住规则宝可梦特性，再用干扰牌拖慢对手展开。",
    "why_play": [
      "它适合体验控制型卡组怎样用节奏差赢下对局。",
      "构筑重点不是爆发伤害，而是让对手每回合都少做一点事。",
      "在特性展开很多的环境里，这类思路很值得理解。"
    ],
    "best_for": "适合喜欢控制、资源压制和环境针对的玩家。",
    "pilot_tip": "先保证铁荆棘ex能持续站场，再考虑用干扰牌扩大领先。",
    "source": {
      "label": "2026城市赛第二赛季 - P9卡牌",
      "city": "深圳",
      "date": "2026-05-03",
      "players": 166,
      "rank": 1,
      "url": "https://tcg.mik.moe/tournaments/3151"
    },
    "import_url": "https://tcg.mik.moe/decks/list/584607",
    "detail": {
      "sections": [
        {
          "heading": "推荐理由与上手看点",
          "body": "这套牌最有意思的地方，是它把胜利条件从“我更快展开”改成“你展开不完整”。上手时不要只看每回合能打多少伤害，而要观察铁荆棘ex站场后，对手依赖特性的检索、补牌和进化节奏被拖慢了多少；当对手少做一两步时，干扰牌和奖赏交换才会真正变成优势。",
          "bullets": [
            "第一局重点观察对手哪些特性被关掉。",
            "不要为了短期伤害放弃持续封锁的位置。"
          ]
        },
        {
          "heading": "当时环境",
          "body": "如果比赛环境里有大量密勒顿、喷火龙大比鸟、洛托姆V、霓虹鱼V等依赖规则宝可梦特性展开的卡组，铁荆棘ex的封锁就可能把对手的第一波节奏压慢。这个判断是基于可见上位构成和卡牌机制的推断，不等于每个对局都会天然优势。"
        }
      ]
    },
    "generated_at": "2026-05-05T00:00:00Z"
  }
}
```

## Required Fields

- `priority`: integer. Higher can be served earlier by the cloud function.
- `recommendation.id`: stable ASCII id. Prefer `YYYY-MM-DD-t<tournamentId>-d<deckId>-<slug>`.
- `recommendation.deck_id`: integer deck id from tcg.mik.moe.
- `recommendation.deck_name`: short Chinese deck name.
- `recommendation.title`: concise article headline.
- `recommendation.style_summary`: one-sentence play pattern summary.
- `recommendation.why_play`: 1 to 3 short Chinese strings. Prefer exactly 3.
- `recommendation.best_for`: one short sentence.
- `recommendation.pilot_tip`: one practical play reminder.
- `recommendation.source`: source metadata.
- `recommendation.import_url`: must be `https://tcg.mik.moe/decks/list/<deck_id>`.
- `recommendation.detail.sections`: 1 to 8 sections.
- `recommendation.generated_at`: ISO timestamp.

## Style Rules

- Explain why this list is worth trying; do not tell the player they must practice it.
- Treat `why_play`, `best_for`, and `pilot_tip` as compact UI summary fields. In `detail.sections`, merge "why worth playing", "why worth reading", and first-game piloting hook into one deeper section such as `推荐理由与上手看点`; do not repeat the same idea as separate sections.
- Keep `deck_id`, recommendation id, and source bookkeeping out of player-facing article copy. Those belong in metadata. Tournament date, city, rank, and player count may appear naturally in prose when useful, but avoid `事实：deck_id 为 ...` or raw fact-dump bullets.
- Separate facts from inference. Tournament placement, player count, card counts, and dates are facts. Matchup explanation is inference unless sourced from the data.
- Include event-environment analysis when data is available. Use top 8/top 16/top 32 composition, same-week category recent plays, and key card text to explain why the selected deck plausibly fit that moment.
- When writing matchup or metagame claims, name the mechanism and the target. Example: Iron Thorns ex suppresses abilities of non-Future rule-box Pokemon while Active, so it can plausibly slow ability-driven setup from Miraidon ex, Charizard ex, Pidgeot ex, Rotom V, or Lumineon V in environments where those decks appear.
- Keep copy readable in the mobile deck manager UI. Avoid very long headings and paragraphs.
- Do not claim a card effect unless it was verified from source data or local card data.
- Do not submit duplicate `id` or duplicate exact `deck_id`.

## Cloud Endpoints

Fetch existing/next recommendation:

```text
POST http://fc.skillserver.cn/decksuggest
```

Insert recommendation:

```text
POST http://fc.skillserver.cn/suggestinsert
```

The insert endpoint is called only after explicit user approval.

Deck center freshness metadata:

```text
POST http://fc.skillserver.cn/deckcentermeta
```

Read requests can omit `action` or send `{ "action": "get" }`. Update requests should use `application/x-www-form-urlencoded` with a single `data` field containing JSON, because the public FaaS gateway treats top-level `action` as a reserved invocation field. The wrapped JSON contains `action=update`, `secret`, `source=ptcg_recommendation_writer`, `latest_revision`, `latest_recommendation_id`, `latest_deck_id`, `latest_title`, and `latest_deck_name`. The secret must come from `PTCG_DECK_CENTER_UPDATE_SECRET` when using `submit_recommendation.py`. This endpoint stores only the latest deck center revision metadata, not the full recommendation article.
