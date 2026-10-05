---
name: ptcg-recommendation-writer
description: Use when researching current Chinese PTCG tournament results, metagame context, matchup implications, and decklists to produce one fresh in-game deck recommendation article, validate it against the client payload schema, and submit it to the recommendation cloud function only after explicit user approval.
---

# PTCG Recommendation Writer

## Purpose

Generate one in-game deck recommendation article from current PTCG tournament, metagame, matchup, and deck data. The output must be a server-ready recommendation payload for the deck manager module, with enough explanation to tell players why the deck is worth trying, not a practice assignment or generic hype copy.

Use this skill when the user asks for a new recommended deck article, daily deck recommendation content, or a cloud-function-ready recommendation entry.

## Required References

Read these before drafting:

- `references/tcg-mik-api.md`: tcg.mik.moe pages and JSON POST endpoints.
- `references/recommendation-schema.md`: server/client payload shape, field limits, and article style requirements.

Use the scripts when helpful:

- `scripts/fetch_existing_recommendations.py`: collect already published recommendation ids/deck ids from the server rotation.
- `scripts/validate_recommendation.py`: validate a payload before showing it to the user.
- `scripts/submit_recommendation.py`: submit only after the user explicitly approves.

## Workflow

### 1. Check Existing Recommendations

Fetch existing server recommendations first:

```powershell
python .agents\skills\ptcg-recommendation-writer\scripts\fetch_existing_recommendations.py
```

Record existing `recommendation.id`, `deck_id`, and source tournament if present. Do not write another article for the same exact decklist. Avoid writing a near-duplicate article for the same archetype and same event unless the angle is clearly different.

### 2. Gather Current Competitive Context

Use `https://tcg.mik.moe/decks` and the API equivalents in `references/tcg-mik-api.md` for the metagame view, deck categories, recent plays, and core card usage.

Use `https://tcg.mik.moe/tournaments/series` and the tournament APIs to find recent completed events. Prioritize tournaments with:

- `regulation == "Standard"`.
- `isTeam == false`.
- `status == "ended"`.
- larger `participantCount`.
- more recent dates.
- major cities or strong scenes such as 上海, 北京, 广州, 深圳, 杭州, 成都, 武汉, 南京, 苏州, 重庆.

When there are not many completed events in the active release window, team tournaments may be used as secondary sources if a list is clearly worth recommending. In that case, prefer standout individual decklists from the team event, clearly disclose that the source is a team tournament, and avoid overstating the result as a normal individual-event metagame signal.

Inspect the top 8 of the strongest candidate events. When the event is large enough, also inspect the top 16 or top 32 to understand the field around the top cut. A top 8 deck is worth considering when it either overperforms relative to its meta share, uses a distinctive tech package, or represents a familiar deck with a clearer learning hook.

Build a concise event-environment note before selecting the article angle:

- Count the visible archetypes in top 8/top 16/top 32 when available, and compare with same-week category recent plays.
- Identify common engines and pressure points in the field, such as rule-box ability setup, Stage 2 evolution engines, energy acceleration, hand refresh, prize-race decks, or control decks.
- Fetch card details for the selected deck's key disruptive cards and the opposing engines it likely targets.
- Separate facts from inference. Facts include ranking, player count, card text, card counts, and visible archetype counts. Inference explains why those facts may matter in the metagame.

Example inference style: after confirming Iron Thorns ex text, it is reasonable to write that while Iron Thorns ex stays Active, it can shut off abilities on non-Future rule-box Pokemon. Therefore, in a field with Miraidon, Charizard/Pidgeot, Rotom V, Lumineon V, or other ability-driven setup engines, Iron Thorns likely wins time by making those decks spend extra turns or cards to develop. Phrase this as "likely" or "from this we can infer", not as guaranteed matchup truth.

#### 17.0 / CSV9C New-Set Requests

When the user asks for the 17.0, new-generation, or CSV9C recommendation cycle:

- Treat CSV9C as the new-card pool for this release window.
- Unless the user gives a different date window, only use completed tournaments with `status == "ended"` and an event/end date on or after `2026-05-16`. Do not use ongoing or upcoming events even if they are dated later.
- Prefer decks built around CSV9C cards, or established archetypes whose CSV9C cards materially change the plan, matchup spread, or sequencing.
- If completed individual events are sparse, team-event standout lists can be considered under the team-tournament caution above.
- Do not pick a deck only because it is new if the local game cannot import or play it cleanly.

### 3. Select One Article Candidate

Prefer one of these angles:

- Small-meta deck wins or top-cuts a large event.
- Familiar archetype has an unusual package that changes matchups or sequencing.
- Deck construction differs from the common category build in a way that is explainable from the event context.
- The deck is useful for the game because it teaches a different play pattern, not because it is the newest or strongest by default.

For the selected decklist, fetch:

- tournament detail and top 8 rank row.
- deck detail by `deckId`.
- category detail by `variantId`.
- category recent plays for the archetype.
- core card usage for the current regulation when available.

Compare the selected list against the archetype baseline. Highlight actual differences from the data: card counts, ACE SPEC choice, supporter package, stadium/tool counts, energy split, unusual Pokemon line, or matchup-targeted inclusions. Also explain how those differences interact with the event environment. If an inference is not directly in the source data, label it as an inference.

For 17.0/CSV9C candidates, explicitly list the CSV9C cards in the strongest candidate lists before choosing the article deck. If a more novel candidate depends on cards that are missing locally or likely unimplemented, either choose a compatible implemented candidate or warn the user before asking for submission approval.

### 4. Draft The Recommendation

Write concise Chinese copy for in-game reading:

- `title`: one clear reason to care about this exact list. For 17.0/CSV9C release-window articles, start the title with `17.0` so trainers can find new-set recommendations quickly.
- `style_summary`: how it plays in one sentence.
- `why_play`: exactly 2 or 3 short summary bullets for the card-flow UI. Keep these compact; do not repeat them as separate article sections.
- `best_for`: who will enjoy it, written as a short UI summary.
- `pilot_tip`: one practical first-game reminder, written as a short UI summary.
- Player-facing article copy should not show raw ids or source bookkeeping. Keep `deck_id`, recommendation id, and exact source metadata in payload fields; mention date, city, rank, or player count only when they naturally support the argument.
- `detail.sections`: 2 to 4 sections. The first section should merge "why it is worth playing", "why it is worth reading", and "what to notice on first try" into one deeper paragraph section, preferably titled `推荐理由与上手看点`. Do not split those ideas into separate `为什么值得玩`, `为什么值得看`, and `上手看点` sections.

Always include one section equivalent to "当时环境" or "它为什么能在这个环境成立" when data is available. This section should connect the selected deck's mechanism to the visible field. For example, for Iron Thorns, discuss how ability suppression can plausibly slow Miraidon setup and Charizard/Pidgeot evolution turns if those archetypes are visible or prominent in the same-week environment.

Avoid claims like "必练", "无脑强", or "环境答案" unless the data truly supports them. Do not invent card effects from memory; use card names/counts from fetched deck data and keep strategic interpretation cautious.

### 5. Check Local Game Compatibility

Before asking for approval, compare the selected deck detail against the local game bundle:

- Look for each card record under `data/bundled_user/cards`, using the source set code and card index naming convention such as `<setCode>_<cardIndex>.json`.
- Pay special attention to CSV9C cards and other key effect cards that the article angle depends on.
- Check enough local implementation metadata, such as effect ids, scripts, registries, or tests, to avoid presenting an unimplemented card as fully playable.
- In the approval summary, disclose missing local card records, unsupported effects, or uncertainty. If any selected deck card is missing locally or likely unimplemented, remind the user before submission and wait for explicit approval of that risk.

### 6. Validate And Ask For Approval

Save the payload as JSON and validate it:

```powershell
python .agents\skills\ptcg-recommendation-writer\scripts\validate_recommendation.py path\to\payload.json
```

#### Mandatory UTF-8 Chinese Payload Guard

Chinese recommendation payloads are fragile on Windows when generated through PowerShell here-strings, inline `python -c`, piped stdin, or any command path that may use the console code page. Do not create or rewrite Chinese JSON payloads through those paths.

Use one of these safe methods instead:

- edit the JSON file directly with `apply_patch`;
- use an existing repo script that reads and writes files with explicit `encoding="utf-8"`;
- create or update a small checked-in helper script with `apply_patch`, then run that script.

Before showing the payload or submitting it, verify the file still contains real Chinese text and no replacement question marks in player-facing fields:

```powershell
python .agents\skills\ptcg-recommendation-writer\scripts\validate_recommendation.py path\to\payload.json
Select-String -LiteralPath path\to\payload.json -Pattern '?' -SimpleMatch
```

The second command must produce no matches for these recommendation payloads. If it prints any line, stop and rebuild the payload from a UTF-8 source before asking for approval. The validator passing is not enough, because schema validation does not detect Chinese text already converted to `?`.

Show the user the chosen tournament, decklist link, article angle, and validated JSON summary. Ask for explicit approval before submitting. Do not call the cloud function on assumed approval.

### 7. Submit After Approval

Only after the user approves, run:

```powershell
python .agents\skills\ptcg-recommendation-writer\scripts\submit_recommendation.py path\to\payload.json
```

The submit script updates the deck center freshness metadata after a successful insert by calling `http://fc.skillserver.cn/deckcentermeta` with a small form-encoded update request. Set `PTCG_DECK_CENTER_UPDATE_SECRET` in the shell before submitting, or keep the secret in local ignored file `.agents/skills/ptcg-recommendation-writer/scripts/deck_center_secret.local`. If the metadata update must be mandatory for the current publishing task, add `--require-deck-center-update`; otherwise a failed metadata update is reported separately without making the already accepted recommendation insert look failed.

After submission, fetch the recommendation rotation again. Confirm whether the new id is visible. If the server accepts the insert but it is not returned first, report that the server sorting/priority may be controlling display order.

When fetching the rotation after submission, inspect the returned records for every submitted id. If any player-facing field such as `deck_name`, `title`, `source.label`, `source.city`, `style_summary`, `why_play`, `best_for`, `pilot_tip`, or `detail.sections` contains ASCII `?` where Chinese should appear, treat the submission as failed: fix the local UTF-8 payload, ask the user to remove the bad server record if needed, and resubmit only the corrected payload.

## Completion Criteria

- The recommendation is based on a real tournament/decklist source.
- The exact decklist has not already been written.
- The article explains why the deck is worth playing, what makes this list different, and why it plausibly fit the tournament environment without repeating the same point across multiple shallow sections.
- For 17.0/CSV9C requests, the source event is completed and falls on or after the required release-window date unless the user explicitly overrides it.
- The selected deck has been checked against `data/bundled_user/cards`, and missing or unimplemented cards have been disclosed before approval.
- For 17.0/CSV9C articles, the title starts with `17.0`.
- The payload passes `validate_recommendation.py`.
- The payload file has been checked for accidental ASCII `?` replacement in Chinese player-facing fields before submission.
- Cloud submission happens only after explicit user approval.
- Successful cloud submission also refreshes deck center metadata unless `--skip-deck-center-update` is used.
- The post-submit recommendation rotation has been fetched and the submitted records are confirmed visible with intact Chinese text, not `?` replacement.
