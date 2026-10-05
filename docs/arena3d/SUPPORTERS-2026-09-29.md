# Windows G/H/I/J supporter presentation

Eighteen supporter identities have distinct short stage motifs in the Grove
board. The roster is grounded in this worktree's bundled-deck usage (not a live
tournament ranking), with I-mark Lillie/Brock and J-mark Judge included. Exact
sample printings and identity aliases are in `ArenaSupporterCatalog.gd`.

The real card illustration remains a camera-facing card. Ribbons, rings,
crystals, scanner panels, portals and the Judge balance are actual procedural
3D geometry, accompanied by local light, bounded motes and small camera motion.
This is not a collection of rigged human models. Cards have distinct choreography
and motifs rather than only different colors. Original stereo sound cues are
reproducible with `tools/arena3d/build_supporter_audio.py`.

`ArenaSupporterCue` is a trusted scene adapter. It accepts only a successful
`PLAY_TRAINER` and the matching last card in that player's public discard pile.
Names in a hand or a disrupted `not_played` event never authorize an appearance.
The renderer receives a positive display allow-list, no engine/scene object,
hidden hand identities, deck order, prizes, persistent option indexes or choices.
Boss paths use stable public before/after identities; energy paths use committed
public field deltas. Abstract geometric motifs do not display hidden search
results or claim future prize awards.

`ArenaMotionDirector.start_supporter` holds the copied board and input for a
2.1-second cue (1.17 seconds in fast mode). The existing anonymous hand return /
draw queue resumes afterward. Unsupported printings keep their ordinary trainer
presentation. Motion/sound preferences are respected; resize cancellation uses
the existing motion owner. Camera focus is separate from Pokemon signatures,
suppressed on compact boards and reset on completion or cancellation. Card HUD
labels beneath the illustration are suppressed only during the cue.

All new audio assets are under `assets/arena3d/`; current non-Windows 2D
export exclusions still apply. No card rules, policies, client version number,
2D Boss choreography or private/cloud service is modified. This is presentation
integration; it makes no new strategy, CABT parity or release-promotion claim.

## Validation and video

Focused suite: `tests/test_arena_supporter_vfx.gd`. It covers the real selected
Boss switch, real local Iono hand-reset/fast-mode pacing, all eighteen authored
prints/art/audio/cleanup, concealed and unplayed rejection and the public
allow-list, and returning an earlier Bench card while later slots compact. The initial failing test recorded the absence of the new 3D cue;
its fixture was then corrected to use Boss's existing interaction dictionary.

Local evidence lives in `.tmp/arena-supporters-20260929/`: baseline files,
structured tests, rendered stills, capture and encoding logs. Run the focused
suite through `scripts/tools/run_test_matrix.py`; renderer verification can use
`tests/CliTestRunner.gd` without `--headless` and with the same suite-script flag.
Existing signature, hand bridge, presentation isolation, platform, 2D Boss and
attack suites remain separate regression gates.

Final local result: 6/6 supporter tests with the Windows OpenGL renderer,
67/67 related Godot regressions, 8/8 2D-export tests, and both standalone
projection/cleanup probes passed. The final renderer log has no script/runtime
errors. The MP4 has 18 named chapters, 54 seconds, 1600×900 at 30 fps, and stereo
AAC; FFmpeg decoded the full output successfully. Art/geometry are also inspected
in all eighteen chapter stills and a real live Boss play with the normal HUD.

`scripts/tools/ArenaSupporterShowcase.gd` is an opt-in 54-second visual fixture.
It uses the same runtime renderer, with each 2.1-second cue slowed to 0.78x in a
three-second segment. It does not fabricate game-action logs or claim to be a
full replay. Use `--write-movie` for in-engine video/audio capture and
`tools/arena3d/finish_supporter_showcase.py` for caption/chapter export.

Rollback: remove the supporter call from `ArenaBattlePresenter._on_action`,
the supporter director entry, world child/focus and HUD suppression hook. The
ordinary trainer flight and existing 2D/3D Pokemon effects remain their owners.
Pre-change copies of these four files are retained in the local evidence folder;
do not restore them over unrelated later edits.
