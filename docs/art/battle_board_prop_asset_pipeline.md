# Battle Board Prop Asset Pipeline

This is the contract for GPT-generated or hand-authored scene props used on the
diamond battle board.

## Source Art

- Put source PNGs under `art/tiles/`.
- Canvas should be 1024 x 1024 with transparent background.
- The image should contain the prop body only. Do not bake a full board tile,
  thick stone side wall, or separate pedestal into the body art.
- `body_crop` must cover the complete visible alpha body. It is not a rescue
  crop for hiding a baked base, platform, or unwanted ground art.
- Small contact rubble, cracks, and shadow are allowed only if they are part of
  the prop body silhouette. Larger ground marks should become a separate
  footprint/decal asset later.
- Leave at least 4 px transparent padding around visible pixels and at least
  64 px horizontal transparent padding for one-cell prop bodies. A prop that
  visually spans almost the full 1024 px canvas width is treated as a baked
  board tile and will fail import.
- Props should be authored as **one-cell board bodies**. At gameplay scale
  protected buildings should be compact ITB-style objectives, around 56-62 px
  wide and about 55-70% of unit token height. `PILLAR` blockers should also stay
  compact, around 74-80 px wide, so they read as obstacles without becoming
  large stone buildings. Low rubble-style `RUIN` can remain wider, near the
  102 px diamond tile width, because its height is low and its role is to mark a
  full ruined cell. A much smaller body reads as a loose decoration sitting on a
  tile instead of as the tile's actual object.
- Current `BUILDING`, `PILLAR`, and `RUIN` bodies are GPT-generated final art
  candidates, then locally chroma-keyed, normalized to a transparent 1024 x 1024
  canvas, and validated by `BattleBoardPropProfile`. The deterministic
  generator is kept only as a blockout/reference path for footprint, camera, and
  alpha-contract checks.

## AI Asset Prompt Contract

The preferred production path for new board props is an AI-generated or
painted body-only sprite on a removable flat background:

```text
Use case: game asset.
Asset type: one-cell tactical battle board prop body sprite.
Primary request: <prop description> BODY ONLY, one-cell footprint, no ground
tile, no pedestal, no floor slab.
Style: polished 2D isometric hand-painted game art, readable at small size,
matching a grim tactical roguelite board. Use neutral charcoal/cool grey stone
for buildings and blockers; do not make the prop the same grey-green hue as the
floor tiles. Green is limited to tiny old moss accents, never the dominant
material color.
Composition: full object visible, centered, front-left dimetric/isometric view
matching the diamond board, broad lower body that visually fills one diamond
cell at gameplay scale, generous padding, bottom contact point near lower
center.
Background: perfectly flat solid #ff00ff chroma-key only.
Constraints: only the vertical prop body and tiny attached rubble that is
physically part of the base; no diamond board tile, no square platform, no
thick stone base, no cast shadow, no contact shadow, no floor plane, no cropped
top or bottom, no text, no watermark; do not use #ff00ff in the subject.
```

After removing the chroma key, reject the asset if it still contains a full
diamond tile, square platform, thick slab, or wide detached ground patch. Do not
fix that by lowering `body_crop`; regenerate or repaint the source.

## Prop-Specific Direction

- `PILLAR` is a compact one-cell blocking obstacle, not a landmark building.
  Use a low broken stone stump, collapsed column base, or chunky masonry blocker
  that stays smaller than unit tokens at gameplay scale.
  Avoid tall obelisks, towers, doors, windows, skull reliefs, glowing runes, or
  anything that reads as a miniature building.
- `PILLAR` art should be visually quieter than the protected building but still
  use the same neutral stone material family. Do not solve board integration by
  tinting it green like the floor; use shared camera, shadows, and footprint
  instead.
- `BUILDING` is a protected board object, not a freestanding venue. It should
  read as a compact stone shrine/core with vertical body mass, smaller than unit
  tokens in gameplay scale, and a small readable HP anchor. Avoid doors, full
  roofs with ground steps, oversized towers, and baked foundations.
- `RUIN` is a low broken wall, rubble strip, or collapsed masonry blocker. It
  should stay visibly lower than `BUILDING`, avoid U-shaped room silhouettes,
  avoid miniature-building semantics, and use the same neutral stone palette and
  camera angle.

## Board-Native Generator

Use this when a blockout or footprint reference is needed before replacing or adding board props:

```bash
godot --path . --script tools/generate_board_native_prop_bodies.gd
```

This generator intentionally favors tactical readability over illustration
detail: chunky planar forms, strong silhouettes, low texture noise, neutral
charcoal stone, and small warm functional accents. It avoids the previous failure
mode where props were tinted green to match the floor and then read as raised
floor tiles rather than buildings.

Use generated output as a blockout/reference for an AI or hand-painted pass. In
that pass, preserve the same silhouette, camera, bottom anchor, 1024 x 1024
transparent canvas, and one-cell draw width. Do not treat the procedural output
as final-quality art unless the task explicitly calls for placeholder assets.

## Profile Resource

Each prop needs a `BattleBoardPropProfile` `.tres` in `art/tiles/profiles/`.
The profile is the source of truth for board placement:

- `body_crop`: visible body area to render from the source PNG.
- `body_anchor_px`: pixel in source art that touches the board cell.
- `board_foot_offset`: board-space offset from cell center to contact point.
- `hp_offset`: board-space anchor for building HP UI.
- `target_height` and `max_draw_width`: gameplay scale limits.
- `min_draw_width`: minimum gameplay width. Use it to enforce the one-cell
  footprint contract so new art cannot accidentally import as a half-cell prop.
- `foundation_scale`, `foundation_offset`, `floor_occlusion_strength`, and
  `contact_shadow_strength`: procedural footprint/foundation settings that make
  the prop read as growing out of the board cell instead of floating above it.
- `footprint_scale`, `sort_bias`, `tint`: board presentation settings.
- `min_horizontal_margin` and `max_alpha_width_ratio`: import guards that reject
  likely baked-tile/pedestal source art.

The renderer does not guess placement from raw alpha. New props must pass the
profile validation in `tools/build_battle_atlases.gd`.

## Import And Review

Run:

```bash
godot --path . --script tools/generate_board_native_prop_bodies.gd
godot --headless --path . --script tools/build_battle_atlases.gd
godot --headless --path . --import
godot --path . --script tools/render_board_prop_anchor_preview.gd
godot --path . --script tools/render_board_prop_preview.gd
```

Review:

- `art/atlases/battle/battle_prop_profile_preview.png`
- `tmp/board_prop_anchor_preview.png`
- `tmp/board_prop_preview.png`

A prop is acceptable when the body sits on the lower diamond face without a
floating pedestal, visually fills one tile's footprint rather than becoming a
small object on top of it, and keeps HP/UI anchors readable. In the anchor
preview, the red foot cross should sit at the lower diamond point, the cyan
sprite bounds should be close to one tile wide, and the orange foundation guide
should cover the tile's contact area.

The body sprite alone is not expected to make a prop feel grounded. The board
renderer draws a procedural contact system below it: tile-colored local floor
occlusion, tight contact AO, short embedded edge seams, and small rubble chips.
Tune those profile values instead of baking a full tile, slab, or pedestal back
into the body art.

For the current board art direction, judge the screenshot rather than the source
PNG alone:

- `BUILDING`, `PILLAR`, and `RUIN` should share one dimetric camera and
  left-top light source.
- They should not share the floor tile's dominant green cast. Integration comes
  from scale, light direction, and contact shadows; material separation comes
  from a neutral charcoal/cool grey stone palette.
- The visible base must be narrow, attached rubble only; a full diamond or
  rectangular platform belongs in the renderer, not in the sprite.
- Contact should come from `foundation_scale`, `foundation_offset`,
  `floor_occlusion_strength`, and `contact_shadow_strength` in the profile.
- If a new asset looks like it is floating, first check `body_anchor_px` and
  `board_foot_offset` in `tmp/board_prop_anchor_preview.png`, then tune profile
  contact values. If it looks like a tiny object on a floor tile, increase or
  regenerate the source so it passes the one-cell `min_draw_width` contract. If
  it contains part of the board, regenerate or repaint the source art.

The previous `board_*_body.png` assets are legacy references because they bake
the floor slab into the prop. Current profiles point at `board_*_body_v2.png`
body-only sources.

## Current Generated Set

The current `board_*_body_v2.png` sources are GPT-image-2 outputs selected from
`tmp/imagegen/board_props_gpt_repaint/`, then processed through local
chroma-key removal and profile validation.

- `board_building_body_v2.png`: compact protected charcoal-stone objective
  block with a broad one-cell base and small amber functional slit.
- `board_pillar_body_v2.png`: squat broken stone blocker with no door/window
  semantics. It fills a cell while staying visually secondary to the building.
- `board_ruin_body_v2.png`: low broken wall blocker used as the ruined-object
  read. It remains clearly lower than the intact building and avoids becoming a
  full ruined house.
