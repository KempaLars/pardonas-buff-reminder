<p align="center">
  <img src="media/logo-400.png" alt="Pardona's Buff Reminder logo" width="200">
</p>

# Pardona's Buff Reminder

A lightweight World of Warcraft addon that reminds you when your class buffs, weapon imbues or poisons, or (optionally) general buffs such as food or flasks are missing. Missing buffs show up as a pulsing, movable list on screen together with a chat message and an optional sound.

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
- **General buffs (optional, off by default)** – Well Fed, Flask, and Well-Rested (sleeping bag).
- **Instance mode** – general buffs can be limited to dungeons and raids ("General buffs only in instances", on by default).
- **Right-click to mute** – right-click a reminder to mute it for 5, 15 or 60 minutes or for the rest of the session. Mutes can be cleared from the settings window or with `/br unmute`.
- **Left-click to cast** – left-click a reminder to cast the missing buff on yourself (highest rank you have learned; single-target version, never the group version such as Prayer of Fortitude or Gift of the Wild).
  - Directly castable: Priest (Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Vampiric Embrace, Shadowform), Mage (Arcane Intellect), Druid (Mark of the Wild, Thorns), Hunter (Trueshot Aura), Death Knight (Horn of Winter).
  - **"Any" reminders** (Paladin aura/seal/blessing, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues, Warrior shout): the addon remembers per character which variant you used last – either from a spell you cast or from a matching aura you applied yourself – and left-click casts that variant (Greater Blessings are remembered as the matching single-target blessing). Until a variant has been remembered, left-click does nothing.
  - Not castable: Rogue poisons and all general buffs (Well Fed, Flask, Well-Rested).
  - Can be turned off in the settings ("Left-click casts buff", on by default).
- **Hint line** – every reminder shows a small grey second line telling you what a click does: "Left-click: cast · Right-click: mute" when click-to-cast is available, otherwise "Right-click: mute".
- **Combat behaviour** – reminders are secure buttons, so the list cannot change during combat: reminders already shown can still be clicked (cast or mute), but new, removed or muted reminders and option changes are applied when combat ends. Test, Move/Lock and `/br reset` are refused in combat with a short chat message.
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

## Releasing

Versions are not edited by hand: the version in the TOC is `@project-version@` and is filled in from the Git tag. To publish a new version, push a tag in the format `X.Y.Z`:

```sh
git tag 1.0.1
git push origin 1.0.1
```

The GitHub Actions workflow (`.github/workflows/release.yml`) then uses the BigWigs packager to build the addon zip, upload it to CurseForge and create a GitHub release. The changelog is generated from the commit messages.

- **Requirement:** the repository secret `CF_API_KEY` must contain a CurseForge API token.
- Tags containing `beta` or `alpha` (e.g. `1.1.0-beta1`) are published as beta or alpha releases.

## Repository layout

```
.
├── .github/workflows/release.yml   # Release workflow (triggered by version tags)
├── media/
│   ├── logo-400.png                # Logo (PNG, 400 px)
│   └── logo.svg                    # Logo (vector)
├── .gitignore
├── .pkgmeta                        # Packager configuration
├── PardonasBuffReminder.lua        # Addon code
├── PardonasBuffReminder.toc        # Addon metadata
└── README.md
```

`README.md` and `media/` are excluded from the packaged addon.
