# deckcentermeta cloud function

Small server-side metadata endpoint for the deck center freshness indicator.

The recommendation feed itself continues to use `decksuggest` and `suggestinsert`.
This function stores only a tiny "latest deck recommendation revision" record so
the game client can cheaply check whether the deck center has newer content.

## Endpoint

Recommended public endpoint:

```text
http://fc.skillserver.cn/deckcentermeta
```

## Database

Collection:

```text
ptcg_deck_center_meta
```

Each update appends one record with `meta_key = deck_recommendations`. Reads return
the newest record by `updated_at`. This avoids depending on database-specific
upsert behavior while preserving a useful publish history.

## Read request

No secret is required.

```json
{
  "action": "get"
}
```

The action may be omitted. The response is:

```json
{
  "ok": true,
  "code": "OK",
  "schema_version": 1,
  "channel": "deck_recommendations",
  "latest_revision": "2026-05-23T00:00:00Z:2026-05-23-t3201-d609793-pure-archaludon:609793",
  "latest_recommendation_id": "2026-05-23-t3201-d609793-pure-archaludon",
  "latest_deck_id": 609793,
  "latest_title": "17.0 ...",
  "latest_deck_name": "...",
  "updated_at": 1779617400000,
  "updated_at_iso": "2026-05-24T10:10:00.000Z",
  "source": "ptcg_recommendation_writer"
}
```

When no record exists, `ok` is still true and `code` is `EMPTY`.

## Update request

Set one cloud-function environment variable:

```text
PTCG_DECK_CENTER_UPDATE_SECRET=<long random secret>
```

Then post as `application/x-www-form-urlencoded` with one `data` field that
contains the JSON update payload. The public FaaS gateway treats top-level
`action` as a reserved invocation field, so wrapping the payload avoids that
platform-level auth path.

```text
data={
  "action": "update",
  "secret": "<same secret>",
  "source": "ptcg_recommendation_writer",
  "latest_revision": "2026-05-23T00:00:00Z:2026-05-23-t3201-d609793-pure-archaludon:609793",
  "latest_recommendation_id": "2026-05-23-t3201-d609793-pure-archaludon",
  "latest_deck_id": 609793,
  "latest_title": "17.0 ...",
  "latest_deck_name": "...",
  "generated_at": "2026-05-23T00:00:00Z"
}
```

`latest_revision` can be supplied explicitly. If omitted, the function can also
derive it from `generated_at`, `latest_recommendation_id`, and `latest_deck_id`.
