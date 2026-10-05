# Two card backs for the local 3D game

- **Self: international blue** — `official-international.jpg`, unchanged 660 × 921 official asset, downloaded 2026-09-19: https://tcg.pokemon.com/assets/img/global/tcg-card-back-2x.jpg
- **Opponent: current Japanese gold border** — `japanese-gold-source.png`, unchanged 630 × 861 reference atlas, retrieved 2026-09-20 from https://sleevenocardbehind.com/wp-content/uploads/2024/10/New-Japanese-Pokemon-Card-Back@3x.png (article: https://sleevenocardbehind.com/every-pokemon-card-back-and-where-it-came-from/). This larger scan was visually compared against the official Japanese how-to illustration: https://www.pokemon-card.com/assets/images/howtoplay/modal-2/anchor-1-modal-1-img-1.png on https://www.pokemon-card.com/howtoplay/. It is a reference-site scan of the official design, **not a file downloaded from the official site**.

`ArenaCardBacks.gd` samples the gold card's 474 × 663 region at (78, 99), excluding the reference page background, shadow and surrounding layout. The source atlas remains unchanged; no generative reconstruction, resampling or recoloring is used. Both images fill the exact same face/body outline at each card size, with rounded geometry masking the outer corners.

Assignment is relative to the current viewer, including hot-seat view changes. Physical decks, prizes, concealed field cards, draw/prize/tool/trainer flights and the legacy reveal owner share this assignment. Front-facing public discard/lost cards retain their actual art. No hidden card identity is read to choose a back.

These designs are Pokémon copyrighted artwork; no new redistribution or commercial-use license is asserted. They are included for the user's local project. Prior SVGs remain for the legacy 2D view and rollback.
