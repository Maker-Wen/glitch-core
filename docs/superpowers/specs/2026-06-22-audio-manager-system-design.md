# Audio Manager System Design

## Goal

Add a small shared audio system so BGM and battle SFX are controlled from one place. The first version covers the existing AI-generated resources only: menu BGM, battle BGM, and battle attack/impact one-shots.

## Scope

- Add a Godot AutoLoad named `AudioManager`.
- Keep BGM resource-backed and looped through `AudioStreamPlayer`.
- Crossfade when switching between menu and battle BGM.
- Move battle SFX playback into `AudioManager`; `BattleSfxPresenter` keeps only the attack-kind to semantic sound-id mapping.
- Keep missing resources silent. No procedural fallback sounds return.

## Runtime Flow

- UI screens call menu BGM through the shared manager.
- Entering a battle calls battle BGM before the battle scene is added.
- Attack FX animation asks `BattleSfxPresenter` to play action and impact SFX; the presenter delegates to `AudioManager`.
- `AudioManager` caches loaded streams and creates transient one-shot players for SFX.

## Defaults

- Menu and battle BGM use `res://audio/bgm/menu_loop_dark_ambient_01.ogg` and `res://audio/bgm/battle_loop_dark_tactics_01.ogg`.
- Battle SFX use the existing seven files under `res://audio/sfx/battle/`.
- BGM default volume is `-14 dB`.
- SFX default volume is `-12 dB`.
- SFX pitch variation is small and randomized per one-shot.

## Testing

- Verify BGM and SFX resource paths resolve.
- Verify missing BGM/SFX ids fail silently.
- Verify duplicate BGM requests do not restart the current track.
- Verify `BattleSfxPresenter` delegates to the audio manager instead of loading or synthesizing resources itself.
