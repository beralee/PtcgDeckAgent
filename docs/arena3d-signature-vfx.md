# Windows signature presentation

The Windows Grove board has thirteen authored volumetric characters: Dragapult,
Charizard, Munkidori, Ceruledge, Stellar Terapagos, Marnie's Grimmsnarl,
N's Zoroark, Archaludon, Ethan's Ho-Oh, Budew, Cynthia's Garchomp, Raging Bolt
and Stellar Tera Pikachu ex. Miraidon is deliberately outside this collection.
The existing 2D special-animation art, official Pokemon artwork, and official
Scarlet/Violet game screenshots supply silhouette/color/gesture references.
Characters contain real mesh geometry,
with independent head, arm and tail joints, Charizard wing/jaw joints and
independent Dragapult passenger launches. These are articulated mesh parts,
not skinned deforming skeletons. Particle impact textures remain 2D effects.
Existing shared attribute effects remain the fallback for other Pokemon.

`tools/arena3d/build_pokemon_collection.py` reproducibly authors the models in
Blender and exports thirteen GLBs under `assets/arena3d/pokemon/`.
The original build entry delegates to this collection. Geometry combines
section-lofted bodies, fused organic surfaces, beveled armor, individual
feather/hair contours, interlocked chain links and cut-gem facets. The material
and geometric budgets are in `model_manifest.json`.
`ArenaPokemonActor` samples a presentation clock without accumulating joint
rotations. `ArenaPokemonChoreography` gives each species distinct anticipation,
action and recovery poses. `ArenaPokemonPerformance` owns bounded ribbon,
lightning, feather, pollen and illusion effects. These are mesh-part rigs,
not imported game skeletons or baked animation clips. No claim of official
asset fidelity is implied. Gallery shots are an inspection tool, not evidence
that these creatures exist as persistent field combatants.
The editable authoring source and exported GLBs have no player-runtime Python
or Blender dependency.

`ArenaSignatureVfx` receives public display dictionaries and committed slot
coordinates. It cannot execute an engine action. Dragapult's counter flights
use the public damage-counter delta on the same visible card, including excess
damage on a knocked-out target. Munkidori uses the already committed
`counter_transfer` event's caster, source, target and count. Concealed cards,
invalid slots and unsupported species fail closed. `ArenaPokemonCatalog` uses
exact public display identities, keeps Trainer Pokemon separate, and requires
Tera evidence (the known CSV9C_054 printing or the public Tera flag) for Pikachu.
`ArenaFrame.is_tera` is public card metadata, not hidden state.

The original thirteen synthetic stereo sound cues were generated offline by
`tools/arena3d/build_signature_audio.py`; no official Pokemon cries are sampled.
That initial version used a 1.95-second clock. The fourteen-character species
revision now uses individual timelines; see
[`arena3d-pokemon-personality.md`](arena3d-pokemon-personality.md) for the current
timing, Gardevoir ability, reference sources and validation. All cues pitch/rate
scale with fast mode. They
obey the world sound switch and are destroyed with their actor. Generic attack
audio is used only by the shared fallback, avoiding doubled signature impacts.
`vfx/dragon-breath-v2.png` was generated with the built-in imagegen tool: one
horizontal tapered orange/amber dragon-fire jet, narrow ignition on the left,
turbulent end on the right, genuine transparent RGBA, no scene/text/checkerboard.
Its prompt and alpha verification are saved with local refinement evidence.

`ArenaMotionDirector` owns the presentation clock. The next turn's draw waits
until an attack finishes; disabling motion or resizing cancels the sequence,
releases the input gate and restores masked hand cards. Fast mode scales both
the signature and its pacing. Camera movement is restricted to noncompact
boards and always resets. Card HUD elements that intersect the spirit are
temporarily suppressed. No engine, AI policy or version-number change is needed.

Run the focused integration gate:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_arena_signature_vfx.gd
```

Also run `AICounterUI`, `ArenaHandEventBridge`, `ArenaPresentationIntegration`,
`ArenaPlatformAdaptation`, `BattleReadyVfx`, the attack VFX suites, and the
standalone 3D projection/cleanup/field tests. The same focused suite must pass
with the Windows renderer enabled.

The opt-in `--arena-acceptance --arena-3d --arena-signature-showcase` route adds
thirteen rotating model inspections and slow action previews, interleaved with
four staged initial boards through
real attack/ability resolution and a real
Viewport click on the final prize. Its visible caption identifies it as a
staged demonstration. It is not an independently played full-match replay.
The ordinary game entry remains unchanged. Android and Web retain their 2D
path and existing export exclusions. New GLBs are inside the already excluded
`assets/arena3d/**` tree and are dynamically loaded only by the 3D renderer.

For model changes, also run `ArenaPokemonModels` and rerun the signature suite
with a Windows renderer, plus projection, cleanup, readability and platform
checks. Model acceptance checks actual geometry, named articulation, independent
passenger/wing/jaw motion and repeatable animation sampling. Recording evidence
for the initial mesh upgrade belongs under `.tmp/arena-models-20260929/`; the
thirteen-character refinement uses `.tmp/arena-refinement-20260929/`.

Rollback can remove the signature calls from the presenter/director and the
signature child in `ArenaWorld`; shared attribute effects remain available.
Local screenshots, recordings, test reports and pre-change files belong under
the ignored `.tmp/arena-signature-20260929/` evidence directory.
