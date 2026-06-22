# Run Internal Return Navigation Design

## Context

The hub scene is used both before a Run starts and as a visual backdrop for Run UI. Several active Run screens still route ordinary back actions through `_show_hub()`, which resets the Run to route phase and exposes the main hub.

## Decision

Once a Run has started, ordinary back or continue actions stay inside the Run task flow:

- Mission board is the Run-level task bar.
- Mission detail is the back target for unresolved event, camp, and shop node pages.
- Completed event, camp, shop, failed battle debrief, and reward claim return to the mission board.
- The hub remains available before expedition selection and through explicit hub/status entry points, not through ordinary Run-node back buttons.
- Run result remains the explicit exit point to main menu or a new Run.

## Implementation

Add focused navigation helpers in `game_manager.gd` so empty-node or resolved-node fallbacks inside active Runs prefer `_show_mission_board()` instead of `_show_hub()`. Rename visible Run-internal buttons away from "返回据点" where they no longer leave the Run.

## Verification

Extend `test_main_menu_hub_flow.gd` to cover:

- Mission board has no return-to-hub button during an active Run.
- Mission detail cancellation returns to mission board and clears selected node.
- Event, camp, and shop option resolution returns to mission board.
- Missing current node fallbacks inside active Run return to the mission board.
