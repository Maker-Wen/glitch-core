# Battle SFX

Battle audio is resource-backed. `BattleSfxPresenter` looks up these files by semantic sound ID and stays silent when a file is missing. Do not add procedural fallback sounds back into code.

Recommended format: `.ogg`, mono or stereo, 44.1 kHz or 48 kHz, normalized with headroom. Keep attack/impact one-shots short so they do not smear across tactical event playback.

| File | Sound ID | Target Length | Direction |
|---|---|---:|---|
| `attack_ranged_push_01.ogg` | `ranged_push` | 0.35-0.55s | Dark arcane launch, iron scrape, compact outward burst. |
| `attack_ranged_pull_01.ogg` | `ranged_pull` | 0.40-0.65s | Hooked spectral tether, inward suction, low chain tension. |
| `attack_melee_push_01.ogg` | `melee_push` | 0.25-0.45s | Heavy shoulder bash, dull metal shove, short body impact. |
| `attack_melee_bump_01.ogg` | `melee_bump` | 0.20-0.35s | Dry close hit, bone/wood crack, no huge cinematic tail. |
| `impact_pull_01.ogg` | `impact_pull` | 0.25-0.45s | Target caught and dragged, low snap plus sliding grit. |
| `impact_magic_01.ogg` | `impact_magic` | 0.25-0.45s | Arcane hit confirmation, brittle spark, dark energy thud. |
| `impact_hit_01.ogg` | `impact_hit` | 0.20-0.40s | Generic tactical hit, blunt and readable, not comedic. |

Generation prompt template:

```text
short dark fantasy tactical game sound effect, [EVENT DESCRIPTION], punchy one-shot, dry close mix, no music, no melody, no voice, no UI beep, no reverb wash
```

Example:

```text
short dark fantasy tactical game sound effect, heavy melee shove impact with dull iron scrape and bone crack texture, punchy one-shot, dry close mix, no music, no melody, no voice, no UI beep, no reverb wash
```
