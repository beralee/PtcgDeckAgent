# Dragapult 18.5 expert-play pilot

The new `expert_play_v1` mode uses the exact bundled deck 675701 and 36 authored
open positions across 12 themes. It reuses BattleScene, StateFactory, and real
card effects; the previous 70 fixed-answer puzzles keep their existing admission
and scoring. There is no preset answer or automatic strategic correctness grade
in expert mode.

Entry: Card Training → 多龙 18.5 · 专家共创. Five-question queues interleave
themes, prefer unfinished positions, and retain exposure/retry metadata.
One or two own turns end a segment. The player selects confidence and optionally
adds a reason or alternative route. Each action is saved as a draft; only
submitted records are exported. Android uses the native document picker and
streams JSONL to the selected `content://` URI. Cancellation or failed writes
never claim that a user-accessible file was saved.

Pilot 0.1.1 embeds an optional goal / sequence / tradeoff / changed-condition
template and a collapsible, explicitly illustrative Munkidori example. It never
overwrites an existing note, and an untouched blank template normalizes to an
empty note. Specific resources, targets and timing are encouraged; mistaken
play and after-the-fact corrections remain useful pending-review evidence.

Finished segments freeze their final public checkpoint. Feedback is debounced
to atomic draft storage (0.4 seconds), flushed on focus loss/backgrounding and
recoverable from the browser under the same attempt ID. Drafts are excluded
from exports. Submit/error controls live outside the scrolling content; the
modal accounts for physical IME height converted to viewport coordinates.
Submission applies the IME, releases focus, hides the keyboard, waits for the
native text handoff and rejects duplicate submissions. Existing submitted
records require no migration. Unsaved old-version text cannot be recovered.

The public recorder excludes arbitrary GameAction payloads/descriptions and
hidden opponent zones. Own hand, boards, public zones, public evolution timing
and knockout provenance are retained. Payload hashes detect corruption, not
expert identity or engine legality. All variants share one research split group.

Human input does not yet have a unified immutable current-window/options/Host
commit witness. Records remain `bc_eligible=false`, `teacher_label_qualified=false`
and pending review, including confident demonstrations. They support expert
route review and regression construction, not immediate behavior cloning.

Owner files: `scripts/training/expert/`, `scenes/deck_training/ExpertPlayBrowser.*`,
`data/deck_training/dragapult185_expert.json`, frozen `decks/675701.json`.
`DeckTrainingCatalog`, `DeckTrainingBrowser` and the existing battle setup runtime
route the new mode; old admission and training paths are preserved.

The browser routes input exclusively through the recovered modal while open,
including its blank backdrop, so a note tap cannot launch a covered question.
GameManager's global non-battle button fallback also yields to visible expert
forms; hidden forms do not affect normal input (37 GameManager tests pass).
Recovered JSON numbers are converted back to exact integers for the closed v1
schema, rejecting non-finite, fractional and unsafe-range values. Forge's
strict import validation is not relaxed. Failed candidates/exports are retained.

Tests: `tests/test_deck_expert_play.gd` (13), existing Presentation (16) and PoC
(37). Forge's `tools/audit_expert_play.py` strictly reads exported public records;
its five tests cover pending qualification, hidden fields, malformed feedback,
deduplication and tampering. Evidence is in the adjacent Forge work directory
`work/dragapult-expert-play-20261003/`.

The requested Android pilot has the separate package `com.ptcgdojo.expertplay`,
starts at the expert browser, and freezes card update activation within its
isolated export snapshot. It does not publish an updater release, replace a
ladder strategy, or claim a win-rate gain. Device acceptance and upload receipts
are separate from unit tests. Rollback is to use the existing game and retain
the exported teaching files.

Pilot revision 3 was installed and exported JSONL through Android 16's native
document picker to Download on the x86_64 emulator with ARM64 translation.
The installed APK SHA256 is
`2fa8d3280ed5268516c8fb086c35e6f9fe5f49c38b6d51f63255cd757dfe04ff`.
Two synthetic QA records round-trip through Forge: the preceding revision's
Boss / Phantom Dive two-prize finish and revision 3's Boss / manual hand-in with
editable note. Both remain unqualified pending review. Cold battle prewarming,
popup-aware modal touch routing and native note focus have focused regressions.
The simulator has a hardware keyboard, so Godot suppresses its soft keyboard;
physical ARM phone IME appearance is not yet witnessed. Temporary emulator
keyboard settings were restored. No model or win-rate acceptance is implied.

Follow-up evidence: Forge `work/dragapult-expert-save-20261003/RESULTS.md`.
The 0.1.1 update retains the package and signing identity with versionCode 2;
install over 0.1.0 without uninstalling. Phone keyboard acceptance is reported
separately from headless keyboard-geometry tests and emulator touch input.
