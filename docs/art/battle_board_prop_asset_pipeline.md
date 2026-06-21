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

## GPT Asset Prompt Contract

For generated assets, ask for a body-only sprite on a removable flat background:

```text
Use case: game asset.
Asset type: one-cell tactical battle board prop body sprite.
Primary request: <prop description> BODY ONLY, no ground tile, no pedestal,
no floor slab.
Style: polished 2D isometric hand-painted game art, readable at small size,
matching a grim tactical roguelite board.
Composition: full object visible, centered, front-left 3/4 isometric view,
generous padding, bottom contact point near lower center.
Background: perfectly flat solid #00ff00 chroma-key only.
Constraints: only the vertical prop body and tiny attached rubble that is
physically part of the base; no diamond board tile, no square platform, no
thick stone base, no cast shadow, no contact shadow, no floor plane, no cropped
top or bottom, no text, no watermark; do not use #00ff00 in the subject.
```

After removing the chroma key, reject the asset if it still contains a full
diamond tile, square platform, thick slab, or wide detached ground patch. Do not
fix that by lowering `body_crop`; regenerate or repaint the source.

## Profile Resource

Each prop needs a `BattleBoardPropProfile` `.tres` in `art/tiles/profiles/`.
The profile is the source of truth for board placement:

- `body_crop`: visible body area to render from the source PNG.
- `body_anchor_px`: pixel in source art that touches the board cell.
- `board_foot_offset`: board-space offset from cell center to contact point.
- `hp_offset`: board-space anchor for building HP UI.
- `target_height` and `max_draw_width`: gameplay scale limits.
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
godot --headless --path . --script tools/build_battle_atlases.gd
godot --path . --script tools/render_board_prop_preview.gd
```

Review:

- `art/atlases/battle/battle_prop_profile_preview.png`
- `tmp/board_prop_preview.png`

A prop is acceptable when the body sits on the lower diamond face without a
floating pedestal, stays inside one tile's visual footprint, and keeps HP/UI
anchors readable.

The body sprite alone is not expected to make a prop feel grounded. The board
renderer draws a procedural contact system below it: tile-colored local floor
occlusion, tight contact AO, short embedded edge seams, and small rubble chips.
Tune those profile values instead of baking a full tile, slab, or pedestal back
into the body art.

The previous `board_*_body.png` assets are legacy references because they bake
the floor slab into the prop. Current profiles point at `board_*_body_v2.png`
body-only sources.
