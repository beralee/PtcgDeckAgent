# 18.5 commentary match video — 2026-09-29

Requested demonstration: one actual match between bundled deck 675700
(18.5 玛俐的长毛巨魔 雪妖女, local rules AI) and the installed developer
strategy `dev.dragapult-dusknoir` 0.9.1, exact deck 675701. The package hash is
`CF196388C350C2D1D81DE05682F03A09F60D5CB8DFA06C48E3C8EE6E56A4DDB4`.
Its existing installation metadata was copied with the archive to isolated
test user data; normal package integrity and Control distribution admission
checks remained enabled. No production account settings were changed.

Seed 20260929, seat 0 first. The first completed match took 117 decision steps
and 12 engine turns. Seat 1 won by taking all prizes. The author runtime made
74 successful policy decisions, with zero policy errors, engine rejections or
same-window fallbacks. No alternate seed was selected for a better-looking result.

The local capture contains 81 state frames. Each frame was restored through
the replay state restorer (with the scenario serializer's full card data and
discard-key adapter) and its production commentary public projection hash
was compared with the original simulation before rendering. All 81 matched.
This is verified snapshot playback, not a fresh second engine simulation.

The commentary sub-agent received only the positive-list public match
projection and public deck/rules knowledge. Its ten edited excerpts passed
the production response-envelope parser, preparation gate, evidence-ID gate
and session publisher into the actual commentary panel. The renderer injects
an explicit offline transport double; it never constructs a paid API request.
The video identifies this as offline simulated commentary. This demonstrates
the text UI/protocol and grounded writing, not live DeepSeek output or latency.

The game did not contain a Grimmsnarl attack or Dusknoir self-knockout. The
captions describe late Grimmsnarl setup and Dragapult's actual prize route;
they do not manufacture the absent moves. Outcome appears only after terminal
settlement in the edited timeline.

Output: `output/commentary-match-20260929/`.
The final MP4 is 128 seconds, 1600×900, 30 fps, H.264 limited-range yuv420p,
stereo AAC background music, 12 chapters, 30,301,130 bytes. Full FFmpeg decode
passed. Opening, gameplay captions and ending were visually checked; the
final Godot capture log has no errors or warnings. Cloud size and MD5 match
the local file. SHA-256:
`de50a0549d09be1a8340a25f46aa30017e2ca6b54e56df0f9741d0139b67b967`.

The private replay remains under `.tmp/commentary_match_20260929/` locally.
Only the final MP4 was uploaded. The Drive file is
`1jo8rg1I9VgGfQnhJG1HTgbx3-wHMT45G`; sharing permissions were not changed.

Reproduction helpers: `tests/commentary/CommentaryMatchSimulationRunner.gd`,
`tests/commentary/CommentaryMatchVideoRunner.gd`,
`tools/arena3d/encode_commentary_stream.py`, and
`tools/arena3d/finish_commentary_match.py`. Use isolated APPDATA with the exact
installed package and its existing admission metadata. Start the encoder on
localhost port 18739, then the rendered runner with `--fixed-fps 30`; finalize
after both complete. No Python simulation pool or external oracle was used.

Rollback: these are opt-in test/capture helpers and documentation only;
remove the newly added helpers to remove this workflow. No production gameplay,
strategy package, application version, or release was changed by this task.
