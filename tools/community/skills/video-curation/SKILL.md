---
name: video-curation
description: Curate recent Bilibili play-focused PTCG videos from a configurable whitelist for the embedded community page. Use when an agent needs to fetch, classify, filter, and summarize videos for "打牌视频推荐" while excluding pack opening, price, giveaway, and sales-oriented content.
---

# 打牌视频推荐

Use this skill to generate the `video_recommendations` block for the community page.

## Sources

Read whitelist configuration from `tools/community/creators.json`.

Initial whitelist:

- PTCG狗哥
- 月海513

The whitelist must stay extensible by creator name, UID, space URL, default role, include keywords, exclude keywords, and optional seed videos.

## Inclusion Rules

Only include videos that are all of the following:

- Published within the last 30 days.
- From a whitelisted creator.
- About playing, building, practicing, or preparing for PTCG.
- Useful for current or near-current environment understanding.

Allowed categories:

- `环境讲解`
- `卡组教学`
- `对局复盘`
- `赛事备战`

Exclude videos about pack opening, ripping packs, box opening, card prices, market movement, giveaways, lucky bags, buying/selling cards, or strong shopping guidance.

## Summary Workflow

For each accepted video:

1. Classify it into one allowed category.
2. Preserve title, creator, published date, and original Bilibili link.
3. Write 2-3 short Chinese sentences explaining what the trainer can learn.
4. Focus on deck choice, construction logic, matchup thinking, or practice value.
5. Sort newest first.

If no videos qualify, return an empty list with an explicit empty state. Do not fill the page with stale videos just to avoid emptiness.

## Output Shape

`video_recommendations` should contain:

- `title`: `打牌视频推荐`
- `window_days`: `30`
- `items`: accepted video cards
- `empty_state`: concise reason when no current videos qualify

Each item should contain `title`, `creator`, `category`, `published_at`, `summary`, `why_watch`, and `url`.
