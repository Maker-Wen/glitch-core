# Skill Upgrades A Design

## Scope

Skill upgrades are run-level warden upgrades that automatically strengthen active skills in battle. This first pass keeps the existing reward cadence: a warden can receive one upgrade option, and the battle UI/effects read that upgrade without adding a skill tree screen.

## Data

- Reuse `wardens[].upgrades` in `RunState`.
- Add skill upgrade ids to the skill catalog, with warden id, skill id, title, description, tags, and effect metadata.
- During battle setup, pass each alive warden's upgrade ids beside its runtime `UnitDef`.
- During deployment, bind the pending upgrade ids to the spawned battle unit id.

## Battle Behavior

- `WardenSkillCatalog` returns upgraded skill dictionaries when given upgrade ids.
- `BattleEngine` uses the upgraded skill dictionary for availability, cooldowns, targeting range, use limits, and effect numbers.
- Building shields become numeric shield stacks so upgraded ward fire can block more than 1 damage while old calls still add 1 shield by default.

## UI

- HUD skill slots display upgraded descriptions and an `强化` tag.
- Detail text follows the upgraded numbers instead of hardcoded base values.
- Disabled/cooldown behavior remains unchanged.

## Initial Upgrade Set

- Bountyhunter chain strike: +1 push force.
- Bountyhunter guard shoulder: cooldown reduced to 0.
- Bountyhunter execute: max uses 3.
- Graverobber hook rope: range 4.
- Graverobber rift wedge: range 4.
- Graverobber backhand throw: range 3.
- Mage repulsion bolt: no range upgrade because the base skill is unlimited along clear cardinal lines.
- Mage ward fire: shield amount 2.
- Mage sigil: duration 3 rounds.

## Verification

- Unit tests cover catalog modifiers, battle handoff, upgraded effect numbers, upgraded HUD data, and run reward persistence.
- Existing skill, UI, and run flow tests must continue passing.
