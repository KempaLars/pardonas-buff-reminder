<p align="center">
  <img src="media/logo-400.png" alt="Pardona's Buff Reminder logo" width="200">
</p>

# Pardona's Buff Reminder

A lightweight World of Warcraft addon that reminds you when your class buffs, weapon imbues or poisons, or (optionally) general buffs such as food or flasks are missing, and (beta) when your reagents are running low. Missing buffs show up as a pulsing, movable list on screen together with a chat message and an optional sound.

**CurseForge:** https://www.curseforge.com/wow/addons/pardonas-buff-reminder

## Compatibility

Built for **WoW Forever** (Interface `16001`).

## Installation

- **CurseForge app:** search for "Pardona's Buff Reminder" and install it.
- **Manual:** download the latest release and extract it so that the files end up in
  `World of Warcraft\_forever_\Interface\AddOns\PardonasBuffReminder\`
  (the folder must contain `PardonasBuffReminder.toc` and `PardonasBuffReminder.lua`).

## Features

- **Class buffs** – per-class reminders, only for spells you have actually learned. Spells you have not learned yet are greyed out in the settings with the level they become available.
  - Priest: Power Word: Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Vampiric Embrace, Shadowform
  - Mage: Arcane Intellect, armor (Frost/Ice/Mage/Molten)
  - Warlock: Demon Skin / Demon Armor / Fel Armor
  - Druid: Mark of the Wild, Thorns
  - Paladin: any aura, any seal, any blessing, Righteous Fury
  - Shaman: Lightning / Water / Earth Shield
  - Hunter: any aspect, Trueshot Aura
  - Warrior: Battle / Commanding Shout
  - Death Knight: Horn of Winter
  - Situational buffs (e.g. Thorns, Shadowform, Righteous Fury, shouts) are off by default.
- **Weapon imbues and poisons** – Shaman main-hand/off-hand weapon imbues and Rogue main-hand/off-hand poisons. Off-hand checks only apply when an actual weapon is equipped there.
- **General buffs (optional, off by default)** – Well Fed (including WoW Forever's "Well Fed XP Boost"), Flask, and Well-Rested (sleeping bag).
- **Use food and flasks by click (beta)** – for the Well Fed and Flask reminders:
  - **Left-click** uses the best matching item from your bags. The hint line shows which one ("Left-click: Smoked Desert Dumplings · Right-click: choose"), or "Not in bags · Right-click: mute" if you have none.
  - **Right-click** (out of combat) opens a menu listing all matching items in your bags (icon, name, count) in the same order, with item tooltips; clicking one uses it. Below a separator are the usual mute options. In combat, right-click only shows the mute options.
  - **Food** comes from a fixed list of WoW Forever cooking food that gives an XP buff (based on the beta, so it may still change). Only food you are high enough level for is offered. Best choice first: 1) food whose tooltip mentions an experience bonus, 2) score = category weight for your class × cooking skill level, 3) larger stack. Each class has its own category order (e.g. Warrior: Strength, Melee AP, Agility, Crit, Stamina; Priest: Spirit, Intellect, Spell Damage, Healing); categories not listed for your class count less, movement and profession food the least.
  - **Flasks** are any flask in your bags (detected by item type, with a fallback list of the Classic flasks). The flask you used last (remembered per character) comes first, then higher item level. The addon also learns each flask's effect so that new flasks count as an active Flask buff.
  - Uses the "Left-click casts buff" option: when it is off, left-click does nothing and right-click only mutes.
- **Reagent warnings (beta)** – warns when a reagent in your bags (bank not counted) drops below a threshold, e.g. "Holy Candle: 3 left". A reagent is only checked if you have learned at least one spell that uses it; for ranked spells the highest rank you know decides which reagent counts (e.g. Prayer of Fortitude rank 1 uses Holy Candle, rank 2 uses Sacred Candle; Rebirth uses a different seed per rank).
  - Priest: Holy Candle, Sacred Candle (Prayer of Fortitude / Spirit / Shadow Protection), Light Feather (Levitate)
  - Mage: Arcane Powder (Arcane Brilliance), Rune of Teleportation, Rune of Portals, Light Feather (Slow Fall)
  - Druid: Wild Berries, Wild Thornroot (Gift of the Wild), Maple / Stranglethorn / Ashwood / Hornbeam / Ironwood Seed (Rebirth)
  - Paladin: Symbol of Kings (Greater Blessings), Symbol of Divinity (Divine Intervention)
  - Shaman: Ankh (Reincarnation), Fish Oil (Water Walking), Shiny Fish Scale (Water Breathing)
  - Rogue: Flash Powder (Vanish), Blinding Powder (Blind)
  - The settings window has a "Reagents" section listing your class's reagents, each with a threshold field (0–50, 0 = no warning) and the current count in your bags. Defaults: Ankh and seeds 1, runes and Blinding Powder 5, everything else 10. Thresholds are saved per character.
  - Reagent warnings appear in the normal reminder list with the item's icon and name in your client language. Left-click does nothing; right-click mutes them like buff reminders.
- **Group buffs (beta)** – in a party or raid, the addon also checks your group members (including yourself) for the buffs you can give: Power Word: Fortitude, Shadow Protection, Divine Spirit, Arcane Intellect and Mark of the Wild. A player counts as buffed with either the single-target or the group version (e.g. Prayer of Fortitude). Paladin blessings are not included.
  - Only buffs whose single-target version you have learned are checked. Arcane Intellect and Divine Spirit are only checked on mana classes (Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock).
  - Players who are dead, offline, not visible or out of range are skipped. Only checked out of combat.
  - One line per buff replaces your own reminder for it, e.g. "Fortitude missing: 3". Below it are the names of the players without the buff (up to 5, then "+N"), then the click hints.
  - **Left-click** casts the group version on the first player without the buff, which covers that player's party or raid subgroup. If you have not learned the group version or are out of its reagent (see reagent warnings), the single-target version is cast instead. **Ctrl+Left-click** casts the single-target version on the next player without the buff. After each cast or buff change the target is chosen again. Hint: "Left-click: group · Ctrl+Left-click: single · Right-click: mute".
  - Settings section "Group buffs": "Check group buffs" (on by default) and "Check in: Always / Dungeons & raids only / Raids only" (default Always). Each buff's own on/off checkbox still applies.
- **Instance mode** – general buffs can be limited to dungeons and raids ("General buffs only in instances", on by default).
- **Right-click to mute** – right-click a reminder to mute it for 5, 15 or 60 minutes or for the rest of the session. Mutes can be cleared from the settings window or with `/br unmute`.
- **Left-click to cast** – left-click a reminder to cast the missing buff on yourself (highest rank you have learned; single-target version, never the group version such as Prayer of Fortitude or Gift of the Wild).
  - Directly castable: Priest (Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Vampiric Embrace, Shadowform), Mage (Arcane Intellect), Druid (Mark of the Wild, Thorns), Hunter (Trueshot Aura), Death Knight (Horn of Winter).
  - **"Any" reminders** (Paladin aura/seal/blessing, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues, Warrior shout): the addon remembers per character which variant you used last – either from a spell you cast or from a matching aura you applied yourself – and left-click casts that variant (Greater Blessings are remembered as the matching single-target blessing). Until a variant has been remembered, left-click does nothing.
  - Not castable: Rogue poisons and Well-Rested. Well Fed and Flask use an item instead (see above, beta).
  - Can be turned off in the settings ("Left-click casts buff", on by default).
- **Hint line** – every reminder shows a small grey second line telling you what a click does: "Left-click: cast · Right-click: mute" when click-to-cast is available, "Left-click: <item> · Right-click: choose" for food and flasks (beta), otherwise "Right-click: mute".
- **Combat behaviour** – reminders are secure buttons, so the list (including click targets of group buff lines) cannot change during combat: reminders already shown can still be clicked (cast or mute), but new, removed or muted reminders and option changes are applied when combat ends. Test, Move/Lock and `/br reset` are refused in combat with a short chat message.
- **Sound** – choose Ping, Bell, Alarm or Off. The sound only plays when a buff newly goes missing, not repeatedly.
- **Movable display** – click "Move" in the settings, drag the reminder to the desired position and click "Lock". While moving, left-click does not cast.
- **Minimap button** – left-click opens the settings, right-click shows a test reminder, drag to move the button around the minimap.
- **Smart suppression** – no reminders while dead, on a flight path or in a vehicle.
- **Languages** – German and English, picked automatically from the game client language.

## Slash commands

`/buffreminder` works as an alias for `/br`.

| Command        | Description                                   |
| -------------- | --------------------------------------------- |
| `/br`          | Open or close the settings window             |
| `/br test`     | Show a test reminder for 5 seconds (not in combat) |
| `/br minimap`  | Show or hide the minimap button               |
| `/br unmute`   | Clear all mutes                               |
| `/br auras`    | List your active buffs with name and spell ID |
| `/br reset`    | Reset position and settings (not in combat)   |

## Development

The code is linted with [luacheck](https://github.com/lunarmodules/luacheck). The configuration is in `.luacheckrc` (Lua 5.1, the WoW API globals the addon uses, and the globals it writes). Run it locally from the repository root before committing:

```sh
luacheck .
```

It must report 0 warnings / 0 errors.

On GitHub, the **Lint** workflow (`.github/workflows/lint.yml`) runs luacheck on every push to `main` or `develop` and on every pull request. The release workflow runs the same lint job first; the addon is only packaged and uploaded if lint passes.

**Testing in game:** WoW only picks up new files (e.g. textures such as `Textures/Icon.tga`) after a full restart of the game client – `/reload` is not enough. Changes to existing Lua files are picked up by `/reload`.

## Releasing

Versions are not edited by hand: the version in the TOC is `@project-version@` and is filled in from the Git tag. To publish a new version, push a tag in the format `X.Y.Z`:

```sh
git tag 1.0.1
git push origin 1.0.1
```

The GitHub Actions workflow (`.github/workflows/release.yml`) then runs luacheck and, if it passes, uses the BigWigs packager to build the addon zip, upload it to CurseForge and create a GitHub release. The changelog is generated from the commit messages.

- The file is named `PardonasBuffReminder-X.Y.Z.zip`; the display name on CurseForge is just the version number (e.g. **1.0.3**). The packager replaces spaces, apostrophes and other special characters in the label with `_`, so a label like "Pardona's Buff Reminder 1.0.3" would turn into `Pardona_s_Buff_Reminder_1.0.3`.

- **Requirement:** the repository secret `CF_API_KEY` must contain a CurseForge API token.
- Tags containing `beta` or `alpha` (e.g. `1.1.0-beta1`) are published as beta or alpha releases.

## Repository layout

```
.
├── .github/workflows/
│   ├── lint.yml                    # Lint workflow (luacheck on push to main/develop and pull requests)
│   └── release.yml                 # Release workflow (triggered by version tags, lint first)
├── media/
│   ├── icon-minimap.svg            # Source for the minimap button icon (no ring)
│   ├── icon.svg                    # Source for the round addon list icon
│   ├── logo-400.png                # Logo (PNG, 400 px)
│   └── logo.svg                    # Logo (vector)
├── Textures/
│   ├── Icon.tga                    # Addon list icon (64x64, 32-bit TGA with alpha)
│   └── MinimapIcon.tga             # Minimap button icon, no ring (64x64, 32-bit TGA with alpha)
├── .gitignore
├── .luacheckrc                     # luacheck configuration
├── .pkgmeta                        # Packager configuration
├── PardonasBuffReminder.lua        # Addon code
├── PardonasBuffReminder.toc        # Addon metadata
└── README.md
```

`README.md`, `.luacheckrc` and `media/` are excluded from the packaged addon.
