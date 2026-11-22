# Proposal

## Why

The 2026-11-14 art and HUD review (`docs/art-pass/review-2026-11-14/DESIGN_PASS.md`, section 2.4, changes C15 to C18) found that the props and structures read worse than the terrain and the actors around them:

- **The coast cay's watch post has no building (PR3).** The cay's landmark is a patch of shade with three identical sign boards and pick-ups on bare rock. The dead radio and the crossed sticks are drawn as boards too. Art-pass says the post "keeps only its shade", and `test_lean_to.gd` asserts it. `IslandSignData` has no look field.
- **The secret cay's scenery is coloured squares (PR4).** `DecorView` draws each decor cell (embers, smoking stub, drag mark, cut line, post, Platino) as a flat 10×10 `draw_rect`, a placeholder. TASKS.md has two open items for it, including Platino's sprite.
- **The lean-to is a boxy ziggurat (PR2).** It has a ruler-straight eave and a transparent stepped corner that shows a clipped bush. Its shade lies wholly south of the posts and is darkest furthest from the roof.
- **Some icons misread, every palm is the same palm, and outlines follow an unwritten rule (PR6, PR7, PR8).**
  - Nails read like a comb, the tarp like glass, the cooked crab like a yellow bow, and cooked hutía and iguana as thin wisps.
  - Every palm is one sprite at one lean.
  - Actors and pick-ups are rimmed black and structures plum or green-grey, but nothing written says so.
  - The rain catcher shows no tarp, though a tarp is one of its materials.

On 2026-11-14 the owner accepted every recommended option in the review: Q12 (a), an open, ruined garita over the post's shaded patch, and Q15 (a), today's outline rule written down. On 2026-11-15 the owner said "Yes, write it" to this change, after waves 2, 3 and 5 were queued without it.

## What Changes

Seven parts, smallest first, one PR each. All are art and art data. No walkable cell, collision, pick-up, count or simulation value changes.

- **The outline rule, written down (PR8, Q15 (a)).**
  - `docs/ASSETS.md` states the rule: characters, creatures and pick-ups are outlined in black (#000000), and structures in the palette's dark tones.
  - A check pins it.
- **Five icons redrawn (PR6).** Nails, tarp, cooked crab, cooked hutía and cooked iguana are redrawn so that no part is thinner than 3 px, which keeps them from turning into solid outline. The dry-grass sheaf (K71) stays as it is.
- **The rain catcher shows its tarp (PR8).** A tarp funnel is drawn over the barrel in every frame.
- **Palms vary (PR7).** Each palm takes one of 2–3 looks by its cell's hash. The nest height and the perch point stay fixed, and the foot shade is centred.
- **The lean-to reads as a frond shelter (PR2).**
  - The three hand sources are redrawn in the same 64×48 frame: a ragged eave whose frond tips hang 2–4 px, a slight sag in the ridge, and closed top corners.
  - The posts get contact shadows.
  - The hut's shade is darkest at its north edge, under the roof, and fades south.
  - All 12 shaded cells keep their shade.
- **The secret cay's scenery is drawn (PR4).**
  - `DecorArtData` gives each decor id its look, by decor id and terrain.
  - Upright pieces (the post, the smoking stub with a 2-frame wisp, Platino) are y-sorted sprites. Flat pieces (embers, the drag mark, the cut line) are decals.
  - A piece in the shallows gets a waterline foot.
  - Platino is cut from DawnLike with the pack's credit.
  - A decor id with no art still draws its colour square, so new decor stays a data edit.
- **A garita over the watch post, and signs that show what they are (PR3, Q12 (a)).**
  - An open-front ruined garita, about 80×48, is drawn over the coast cay's shaded post block through `shelter_art.tres`. It has low concrete walls, two posts, a sagging rusted tin edge, a dark window hole and a faded red band where a slogan was painted.
  - It has no solid wall and makes nothing solid.
  - `IslandSignData` gains an optional `look`: radio, sticks or slogan. A sign without one draws today's board.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`:
  - "Lean-to over the hut": the coast cay's watch post gets the garita instead of only its shade; the lean-to's look is the redrawn shelter; and the hut's shade is darkest under the roof.
  - New requirements:
    - "A garita over the watch post";
    - "Signs show what they are";
    - "The hidden cay's scenery is drawn";
    - "Outline colour by family";
    - "Item icons read at a glance";
    - "Palms vary";
    - "The rain catcher shows its tarp".

## Impact

- Art tools (`tools/art/`):
  - `structure_sheets.json`, with new hand sources in `fixes/structures/`: the garita, the radio, the sticks, the slogan fragment, the redrawn lean-to, the palm looks, the catcher's tarp and the post shadows;
  - `item_icons.json`, with five redrawn sources in `fixes/items/`;
  - a recipe step for Platino and the decor pieces;
  - the Python tests.
- Rebuilt art: `game/assets/art/structures/` (lean-to, palm looks, rain catcher, garita, sign looks), `items/` (five icons), new `decor/` sheets, `decals/` (the hut shade variant), `shadows/` (post contact shadows if they are shadows), and `CREDITS.md` with the credits screen data for DawnLike's Platino.
- Data:
  - `shelter_art.tres` gains `coast_cay`;
  - `structure_art.tres` gains the sign looks and palm looks;
  - a new `decor_art.tres` (`DecorArtData`);
  - `coast_cay.tres` sets `look` on its four signs.
- Game scripts:
  - `scripts/data/island_sign_data.gd`: the `look` field;
  - `scenes/levels/island_sign.gd`: picks the look;
  - `scripts/art/structure_art_data.gd`: the sign and palm look tables;
  - `scenes/levels/palm.gd`: picks a look by hash;
  - `scenes/art/decor_view.gd`: draws from `DecorArtData`;
  - a new `scenes/art/garita.tscn`;
  - `scenes/art/terrain_view.gd`: the hut shade variant.
- Tests:
  - `test_lean_to.gd`'s `test_the_coast_cay_shaded_cells_get_no_lean_to` is rewritten;
  - new garita, sign look, decor, palm look, icon and outline tests.
  - `test_art_sim_invariance`, `test_draw_order` and `test_he_left_minutes_ago` stay green.
- Docs: `docs/ASSETS.md` (the outline rule and Platino), `TASKS.md` (the two secret-cay art items and Platino).
- No layout cell, collision, pick-up, count, networking or HUD change. The coast cay's outline is coast-cay-reshape's; the garita builds after it.
