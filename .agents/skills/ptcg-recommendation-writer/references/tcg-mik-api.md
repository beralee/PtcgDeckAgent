# tcg.mik.moe Data Sources

The public pages are React routes, so use the JSON POST APIs below rather than scraping rendered HTML.

Primary pages:

- Deck meta page: `https://tcg.mik.moe/decks`
- Tournament series page: `https://tcg.mik.moe/tournaments/series`
- Tournament detail page: `https://tcg.mik.moe/tournaments/<tournamentId>`
- Decklist page: `https://tcg.mik.moe/decks/list/<deckId>`
- Archetype page: `https://tcg.mik.moe/decks/<variantId>?all=true`

Base URL:

```text
https://tcg.mik.moe
```

Use JSON POST with `Content-Type: application/json`.

## Tournament Endpoints

Get tournament series:

```json
POST /api/v3/tournament/series-list
{"page":1,"pageSize":100}
```

Get tournaments inside a series:

```json
POST /api/v3/tournament/list
{"seriesId":53,"page":1,"pageSize":100}
```

Get one tournament:

```json
POST /api/v3/tournament/detail
{"tournamentId":3151}
```

Known useful fields: `id`, `name`, `type`, `status`, `isTeam`, `location`, `date`, `participantCount`, `regulation`, `regulationMark`, `formatEnd`, `division`.

Get individual ranks:

```json
POST /api/v3/tournament/rank-individual
{"tournamentId":3151,"page":1,"pageSize":8}
```

Rank rows include `rank`, `players`, and `decks`. Deck rows include `deckId`, `variantId`, `variantName`, and `variantIcon`.

Get valid regulation identifiers:

```json
POST /api/v3/tournament/regulation-list
{}
```

This returns values such as `FGH-CSV8C`. Use these exact values for core-card analysis.

## Deck Endpoints

Get one decklist:

```json
POST /api/v3/deck/detail
{"deckId":584607}
```

The response includes `cards`, `deckCode`, and `variant`. Each card includes `cardName`, `cardType`, `setCode`, `cardIndex`, and `count`.

Get archetype/category detail:

```json
POST /api/v3/deck/category-detail
{"id":327}
```

Get recent results for an archetype:

```json
POST /api/v3/deck/category-recent-play
{"id":327,"all":true,"page":1,"pageSize":20}
```

Get common/core card usage for an archetype and regulation:

```json
POST /api/v3/deck/core-card
{"variant":327,"regulation":"FGH-CSV8C","showPopular":true}
```

This returns total sampled lists and card-level `averageUsage` plus count distribution. Use it to compare a tournament list against the common build.

## Optional/Flaky Endpoints

The frontend references these endpoints, but they can return server errors depending on parameters. Treat them as optional enhancements:

```json
POST /api/v3/deck/deck-static-by-date-and-reg
{"topCuts":false,"isVariant":false,"lastWeek":false,"pastWeek":0,"regulation":"Standard","regulationMark":"FGH-CSV8C","hasTeam":false,"onlyTeam":false}
```

```json
POST /api/v3/deck/deck-static-by-tour
{"tournamentId":3151,"topcut":false,"points":0,"isVariant":true}
```

If these fail, rely on series/tournament ranking, category recent plays, and core-card data.

## Current Example To Sanity Check The Flow

As of 2026-05-05, tournament `3151` is `2026城市赛第二赛季 - P9卡牌`, 深圳, 166 participants, Standard, non-team, ended on 2026-05-03.

Top examples from its top 8:

- Rank 1: 铁荆棘, deck `584607`, variant `327`.
- Rank 2: 密勒顿, deck `600806`, variant `276`.
- Rank 4: 阿尔宙斯 黑夜魔灵, deck `600807`, variant `342`.

These are examples only. Each run should still search for the newest suitable event and avoid previously written decklists.
