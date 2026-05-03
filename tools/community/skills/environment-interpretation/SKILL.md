---
name: environment-interpretation
description: Generate the daily PTCG simplified-Chinese "环境解读" article for the embedded community page. Use when an agent needs to pick a recent high-signal tournament/deck sample, compare it with mainstream meta data, and write a coaching article that helps players choose and practice decks for the current environment.
---

# 环境解读

Use this skill to generate one daily coaching article, not a news digest.

## Output

Produce `environment_briefing` data for `community/data/community-data.json`:

- `name`: `环境解读`
- `title` and `subtitle`: the day's actionable thesis
- `source_signals`: 3-4 compact signals explaining why this sample matters
- `article.hero`: focused deck/tournament/thesis
- `article.sections`: 3-5 coaching sections with concrete bullets
- `article.deck_snapshot`: key cards from the featured list
- `article.links`: original tournament, deck list, and comparison pages

## Selection Rules

Prioritize samples in this order:

1. Recently finished tournaments.
2. Larger player counts.
3. Higher-reference cities or well-known stores.
4. Top-finishing decks with public deck lists.
5. Decks that overperform against dominant meta, especially off-meta or meaningfully adjusted builds.
6. Decks whose construction can be compared against a mainstream archetype.

Ignore ongoing or upcoming tournaments except as calendar context.

## Analysis Workflow

1. Identify the current series and recent finished events from `https://tcg.mik.moe/tournaments/series`.
2. Pick one high-signal event and inspect top placements.
3. Open the chosen deck list and fetch detailed card counts.
4. Pick the nearest mainstream archetype comparison page from `https://tcg.mik.moe/decks`.
5. Compare over-indexed cards, under-indexed cards, engine choices, attackers, stadiums, tools, ACE SPEC, and energy counts.
6. Write a thesis for why this construction may fit the current environment.
7. Mark inference clearly when the matchup reason is inferred from card choices rather than direct match records.
8. End with practice tasks a player can run today.

## Quality Bar

The article should answer:

- What environment problem is this deck trying to solve?
- Which construction choices reveal that plan?
- Why might those choices matter against dominant decks?
- What should a player test before copying the list?

Avoid broad rankings, official news, raw tournament lists, and vague praise. Information is valuable only if it changes how the trainer chooses, builds, or practices a deck today.
