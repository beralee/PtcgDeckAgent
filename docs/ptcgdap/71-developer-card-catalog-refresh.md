# Developer card catalog refresh

2026-09-20 damage-planner follow-up: the earlier catalog refresh left the
independent public damage registry at 797 printings. The existing generator
now supplies all 1,011; its original 797 card entries are unchanged. Anniversary
Unown on the opposing Bench previously rejected a Marnie damage plan with
`unknown_damage_card_uid`. The catalog coverage/source-drift regression and
the known/unknown/hidden/reordered-window cases now pass. Run
`python tools/ptcgdap/build_public_damage_capability_registry.py --check` when
changing card sources or effect handlers; regenerate with that script without
`--check` after review. This metadata refresh does not add dynamic attack
capabilities or grant production, device or full-game parity authority.

The isolated Godot verification then replayed the two previously failing
Marnie matchups at the original seed in both seats: four complete games,
310 policy windows, both sides free of policy errors, invalid selections and
fallbacks, and every public trace verified. The exact runtime/source hashes
are recorded in `../../evidence/ptcgdap/damage_registry_catalog_refresh_20260920.json`.
This closes the registry omission for those witnessed games, not strategy
strength or general card-rule parity.

The bundled card JSON set is the denominator for the developer catalog. A new
card is not delivered to developers until the actual effect registration,
runtime attestation, generated contracts and qualification agree on that set.

From the public game root, run:

```powershell
python tools/ptcgdap/refresh_developer_card_catalog.py --refresh --godot <Godot-console-executable>
python tools/ptcgdap/refresh_developer_card_catalog.py
```

Refresh runs the real engine attestation, the contract generator, performance
measurement, five Python UCIS/live-witness suites, card/engine/Host functional
suites, and four focused interaction/UI/Headless/card suites. It generates the
qualification receipt only after all commands succeed. The second command is
read-only and rejects stale card sets, source bytes, generated contracts or
qualification. Logs are retained under `.tmp/developer-card-catalog` by default.

On 2026-09-19 the refreshed set contains 1,011 card printings and 888 effects;
1,010 printings / 887 effects are declared usable and the existing unregistered
dynamic ability remains explicitly unsupported. Both anniversary sets are
included. This is UCIS interaction qualification, not official full-rule parity
or a claim that an independently deployed server already contains this set.

The expanded required UI suite exposed repeated compilation of an already
preloaded effect through `EffectRegistry`'s `CACHE_MODE_IGNORE`. Creating a
processor while the Munkidori effect was executing invalidated typed property
bindings. Reusing the resource identity fixes the original UI reproduction;
the weak cache and per-processor effect instances remain separate.

Forge's `tools/refresh_card_catalog.py --source <public-game-root>` consumes this
checked receipt and distributes every source JSON with the matching contracts.
Its delivery check rejects a missing file, byte drift, or UID/effect mismatch.
Server operators must independently test their exact packaged runtime and
publish its matching supported-card snapshot. No operator code or deployment
evidence belongs in this public repository.

The 2026-09-20 refresh also includes Snorunt `CSV6C_032`. Its previously unregistered attack now deals 10 damage, plus 30 only when the opposing Active Pokémon is Fighting type. The focused engine fixture checks both seats, Water payment, and a Fighting Bench negative case.
