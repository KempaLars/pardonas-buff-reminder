<p align="center">
  <img src="media/logo.svg" alt="Pardona's Buff Reminder logo" width="200">
</p>

# Pardona's Buff Reminder

A lightweight World of Warcraft addon that reminds you when your class buffs, weapon imbues or poisons, or (optionally) general buffs such as food or flasks are missing. Experimental opt-in features add group buff checks, low reagent warnings, warnings for buffs that are about to expire, reminders for mage and warlock conjured items, one-click weapon stones, oils and poisons, a right-click menu to pick a buff variant, Paladin blessings in group buffs and a tracking reminder (herbs, minerals, fish). Missing buffs show up as a pulsing, movable list on screen (growing downwards or upwards) together with a chat message and an optional sound; a keybinding uses the top reminder.

Available on CurseForge and Wago.

**CurseForge:** https://www.curseforge.com/wow/addons/pardonas-buff-reminder

## Compatibility

Built for **WoW Forever** (Interface `16001`).

## Installation

- **CurseForge app:** search for "Pardona's Buff Reminder" and install it.
- **Wago app:** search for "Pardona's Buff Reminder" and install it.
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
- **General buffs (optional, off by default)** – Well Fed (including WoW Forever's "Well Fed XP Boost"), Flask, and Well-Rested (sleeping bag). Gathering tracking (Find Herbs, Find Minerals, Find Fish) is an experimental feature, see [Tracking reminder](#experimental-features-opt-in).
- **Use food and flasks by click** – for the Well Fed and Flask reminders:
  - **Left-click** uses the best matching item from your bags. The hint line shows which one ("Left-click: Smoked Desert Dumplings · Right-click: choose"), or "Not in bags · Right-click: mute" if you have none.
  - **Right-click** opens the reminder menu (see [Right-click menu](#right-click-menu-beta)) with all matching items in your bags.
  - **Favorites (beta)** – click the star next to an item in the menu to mark it as a favorite (saved per character). Left-click on the reminder always uses a favorite if one is in your bags; with several favorites the normal order below decides. Favorites are listed at the top of the menu. Click the star again to remove the favorite.
  - **Food** comes from a fixed list of WoW Forever cooking food that gives an XP buff (based on the beta, so it may still change). Only food you are high enough level for is offered. Best choice first (after favorites): 1) food whose tooltip mentions an experience bonus (only while you can still gain experience – not at max level or with experience gain turned off), 2) score = category weight for your class × cooking skill level, 3) larger stack. Each class has its own category order (e.g. Warrior: Strength, Melee AP, Agility, Crit, Stamina; Priest: Spirit, Intellect, Spell Damage, Healing); categories not listed for your class count less, movement and profession food the least.
  - **Flasks** are any flask in your bags (detected by item type, with a fallback list of the Classic flasks). After favorites, the flask you used last (remembered per character) comes first, then higher item level. The addon also learns each flask's effect so that new flasks count as an active Flask buff.
  - Uses the "Left-click casts buff" option: when it is off, left-click does nothing and right-click only mutes.
- **Eating countdown** – while you are eating (started from the reminder or directly from your bags; detected by the food's eating aura by spell ID or name, or by the generic "Food" or "Drink" aura) and are not yet Well Fed, the Well Fed reminder shows "Eating … 7 s", counting down the 10 seconds until the buff appears, then "Almost well fed …", with the hint "Stay seated". This does not trigger a chat message or sound. If you stand up before getting Well Fed, the normal reminder comes back (again without a new chat message or sound).
- **Instance mode** – general buffs can be limited to dungeons and raids ("General buffs only in instances", on by default).
- **Right-click to mute** – right-click a reminder and pick 5, 15 or 60 minutes or the rest of the session in the menu. Mutes can be cleared from the settings or with `/br unmute`.
- **Left-click to cast** – left-click a reminder to cast the missing buff on yourself (highest rank you have learned; single-target version, never the group version such as Prayer of Fortitude or Gift of the Wild).
  - Directly castable: Priest (Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Vampiric Embrace, Shadowform), Mage (Arcane Intellect), Druid (Mark of the Wild, Thorns), Hunter (Trueshot Aura), Death Knight (Horn of Winter).
  - **"Any" reminders** (Paladin aura/seal/blessing, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues, Warrior shout): the addon remembers per character which variant you used last – either from a spell you cast or from a matching aura you applied yourself – and left-click casts that variant (Greater Blessings are remembered as the matching single-target blessing). Until a variant has been remembered, left-click does nothing.
  - Not castable: Rogue poisons and Well-Rested. Well Fed and Flask use an item instead (see above).
  - Can be turned off in the settings ("Left-click casts buff", on by default).
- **Hint line** – in the Pardona and Classic styles, every reminder shows a small second line telling you what a click does: "Left-click: cast · Right-click: mute" when click-to-cast is available, "Left-click: <item> · Right-click: choose" for food and flasks, otherwise "Right-click: mute". With the variant menu (beta) on, reminders with variants show "Left-click: cast · Right-click: choose" (or "Right-click: choose variant / mute" until a variant has been remembered).
  In the Compact style these hints are shown in the tooltip only.
- **Combat behaviour** – reminders are secure buttons, so the list (including click targets of group buff lines) cannot change during combat: reminders already shown can still be clicked (cast or mute), but new, removed or muted reminders and option changes are applied when combat ends. Test, Move/Lock and `/br reset` are refused in combat with a short chat message.
- **Sound** – choose Ping, Bell, Alarm or Off. The sound only plays when a buff newly goes missing, not repeatedly.
- **Movable display** – click "Move" in the settings, drag the reminder to the desired position and click "Lock". While moving, left-click does not cast.
- **Growth direction (beta)** – "New warnings appear: below / above" in the settings (default: below). With "above", the first reminder sits at the saved position and further reminders stack upwards, in every style; Move mode and `/br test` behave the same. Switching does not move the first reminder. With Compact "Icons only", icons are placed left to right, 8 per row; further rows are added below or above. The right-click menu always stays on screen and opens upwards if there is not enough room below the mouse pointer. In combat the new order is applied when combat ends.
- **Styles (beta)** – choose the look of the reminders and the right-click menu in the settings ("Style"). Switching applies immediately (in combat: when combat ends).
  - **Pardona** (default) – dark purple gradient, gold border with rounded corners, colored status stripe on the left (red = missing, orange = low reagent, green = eating), icon with gold frame, golden title, grey-purple hint line.
  - **Classic** – stone/brown background, square gold frame, title in WoW yellow, beige hint line.
  - **Compact** – slim dark bars with a status stripe on the left and "missing" on the right; hints only in the tooltip. The extra option **Icons only** (only available with Compact) shows just the icons side by side; name and hints are in the tooltip.
- **Keybinding (beta)** – one key for the top reminder, see [Keybinding](#keybinding-beta).
- **Pardona's Addons entry point (beta)** – see [below](#pardonas-addons-beta).
- **Smart suppression** – no reminders while dead, on a flight path or in a vehicle.
- **Languages** – German and English, picked automatically from the game client language.

## Right-click menu (beta)

Right-clicking a reminder opens one window in the selected style:

- **Header** – the reminder's icon and title with a short line below (e.g. "Use an item or mute", the players missing a group buff, or the reagent count).
- **Food in your bags / Flasks** (Well Fed and Flask reminders only, with "Left-click casts buff" on) – one line per matching item: item icon, name, an **XP** badge if the food gives an experience bonus (not shown at max level or with experience gain turned off), the food's category (e.g. Spirit), and the count on the right. The line that left-click on the reminder would use is marked "best choice". Click a line to use the item; hovering shows the highlight and the item tooltip. The star on the right of each line marks or unmarks the item as a favorite – it never uses the item. If nothing matching is in your bags, the section says so.
- **Cast a variant** (variant menu (beta) only: Paladin aura and seal, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues) – one line per learned variant with icon and name; a click casts its highest learned rank and makes it the "last used" variant for left-click. The current one is marked "last used". See [Experimental features](#experimental-features-opt-in).
- **Mute** – four buttons side by side: 5 min, 15 min, 60 min, Session.
- **Close (Esc)** – the footer closes the window; Esc closes it as well, and it closes on its own when the mouse has left it for 2 seconds.
- **In combat** only the header and the mute buttons are shown (the item and variant lines are secure buttons and cannot be created or changed in combat). An open window with items or variants closes when combat starts.

## Keybinding (beta)

Under **Options > Keybindings > Pardona's Addons > Buff Reminder > Use top warning** you can bind a key. All Pardona addons share the "Pardona's Addons" section. Pressing the key does the same as a left-click on the reminder at the very top of the screen: cast the buff, eat, drink a flask, imbue the weapon, or the group action of a group buff line. With "New warnings appear: above" that is the last reminder added (the highest one on screen); with Compact "Icons only" it is the leftmost icon of the top row. If no reminder is shown, the key does nothing.

- The key follows the list out of combat. In combat it keeps the action it had when combat started and is updated when combat ends.
- The settings show the current key (or "not bound") below the growth direction option.
- Macro alternative: `/click PardonasBuffReminderKeyButton`. If your client casts on key down ("Cast action keybinds on key down" on) and this macro does nothing, use `/click PardonasBuffReminderKeyButton LeftButton 1` instead.

## Pardona's Addons (beta)

All Pardona addons (Pardona's Buff Reminder, Pardona's ToolTips, …) share one entry point, provided by the embedded library [LibPardona-1.0](https://github.com/KempaLars/lib-pardona). With several Pardona addons installed you still get only one minimap button and one settings category.

- **Settings** – Options → AddOns → **Pardona's Addons** → **Buff Reminder**. The overview page "Pardona's Addons" lists every installed Pardona addon with its version, a short status and an *Open* button, plus a *Show minimap button* checkbox. `/br` opens the Buff Reminder page directly. If the client has no Settings API, `/br` opens the standalone settings window instead.
- **Addon compartment** – the entry "Pardona's Addons" in the addon compartment (next to the minimap, if the client has one) works like the minimap button.
- **Shared minimap button** – one "Pardona" button for all Pardona addons. With only Buff Reminder installed, left-click opens its settings; with several Pardona addons, left-click opens a small menu. Right-click opens the overview, drag moves the button along the minimap edge. The tooltip shows each addon's short status, for Buff Reminder e.g. "2 buffs missing" or "All active" (nothing in combat or while the state is still unknown). `/br minimap` or the overview checkbox shows or hides the button for all Pardona addons. The position and visibility of the old Buff Reminder minimap button are taken over once.
- **Titan Panel and other LibDataBroker displays** – if another addon already loads LibDataBroker-1.1 (e.g. Titan Panel, ChocolateBar), a "Pardona" launcher appears there. It behaves like the minimap button and shows the statuses as text; you can hide the minimap button if you prefer the panel.

## Experimental features (opt-in)

These features are not fully tested yet. They are **off by default in release versions** and can be turned on in the settings, in the section **"Experimental (beta) – use at your own risk"** below the general options. In beta, alpha and development builds they are on by default. Once you tick or untick a checkbox, your choice is kept (account-wide) regardless of the build; `/br reset` returns to the build default.

While a feature is off, it does nothing at all: no group lines, no group scans, no reagent lines and no reagent count checks; your own reminders work as usual. The detail settings below each checkbox are greyed out while it is off. Changes take effect immediately (in combat: when combat ends).

- **Expiry warning (beta)** – warns shortly before one of your active buffs runs out, so you can refresh it in time. Covers your enabled class buffs, Well Fed, flasks and temporary weapon imbues/poisons (main and off hand); not Well-Rested, group buff lines or reagents.
  - A buff counts as expiring when its remaining time is at or below the threshold (default 10 % of its full duration). If the client does not reveal a buff's duration (secret values), has no duration or reports a duration of 0, that buff gets no expiry warning. Weapon imbues only report their remaining time, so the full duration is the highest remaining time seen since the imbue appeared (reset when it disappears or is reapplied).
  - Expiring buffs appear as their own line in the reminder list, after the missing buffs: same style, but semi-transparent (default 50 %), with an amber status stripe and a live countdown, e.g. "Arcane Intellect expires · 2:31". No sound, no chat message, no pulsing.
  - Left-click works like on the missing-buff line (cast the buff, eat, drink a flask, imbue the weapon); right-click opens the same menu and mutes the same reminder. In combat the line is only updated, never changed; a line that would appear in combat shows up when combat ends. "General buffs only in instances" also applies to food and flasks here.
  - Detail settings below the "Expiry warning" checkbox: "Threshold" slider (5–50 %, default 10 %) and "Opacity" slider (20–100 %, default 50 %).
- **Class consumables (beta)** – reminds mages and warlocks to conjure their consumables. Each one is its own entry in the class list of the settings (own checkbox, on by default) and only appears there once you have learned the matching spell.
  - Mage: **conjured water** and **conjured food** – warns when the total of all ranks in your bags drops below the threshold, e.g. "Conjured Crystal Water: 5" (at 0: "… missing"). **Mana gem** – warns when you carry no mana gem of any rank.
  - Warlock: **Healthstone** – warns when you carry no healthstone of any rank (including the improved talent versions). **Soulstone** – warns when you carry no soulstone.
  - Item names come from the game client in your language; the line shows the item of the highest rank you know. Only your bags are counted (not the bank).
  - Left-click casts the highest rank you have learned; right-click opens the normal menu to mute the reminder (no item list). These reminders apply everywhere ("General buffs only in instances" does not affect them) and get no expiry warning.
  - Detail setting below the "Class consumables" checkbox (mages only): "Food/water below" slider (0–60, default 20; 0 turns the food/water warning off).
- **Weapon enhancements: stones, oils, poisons (beta)** – apply sharpening stones, weightstones, wizard oils, mana oils or rogue poisons with one click.
  - Two new general entries, "Main hand: weapon enhancement" and "Off hand: weapon enhancement" (own checkboxes, on by default). Not available for shamans, who use their own imbues. For rogues they only apply while the matching poison entry (main/off-hand poison) is turned off.
  - A line appears only if a weapon is equipped in that slot, it has no temporary enhancement and you carry at least one matching item. "General buffs only in instances" applies like for food and flasks.
  - Matching items: sharpening stones only for edged weapons (axes, polearms, swords, daggers), weightstones only for blunt weapons (maces, staves); Elemental and Consecrated Sharpening Stone work on both. Wizard and mana oils fit every weapon. Fist weapons and unknown weapon types only get oils. Items above your level are skipped.
  - Left-click applies the best item to the slot: favorites first (the same favorites as for food and flasks, per character), then by class: Warrior, Rogue, Hunter, Death Knight: stones before oils; Mage, Warlock: wizard oil, mana oil, stones; Priest, Druid, Paladin: mana oil, wizard oil, stones. Within a group the highest rank comes first; the undead-only Consecrated Sharpening Stone and Blessed Wizard Oil come last. Right-click opens the item menu (icon, name, count, favorite star, "best choice").
  - Rogue poisons: with this feature on, the existing main-hand/off-hand poison reminders work the same way – left-click applies the best poison (or a favorite) from your bags, right-click opens the poison menu. Order: Instant, Deadly, Wound, Crippling, Mind-numbing, highest rank first. Anesthetic Poison is not included.
  - Items are applied with a click macro (`/use item:<id>` followed by `/use 16` or `/use 17`); this is only set up out of combat. Item names and icons come from the game client. The expiry warning covers these enhancements too.
- **Variant menu on right-click (beta)** – for reminders with several equivalent variants, right-click lists every variant you have learned, so you can cast a different one without opening the spellbook.
  - Covers: Paladin aura and seal, Hunter aspect, Mage armor, Warlock armor, Shaman shield and main-hand/off-hand weapon imbue. Not for Paladin blessings (and not for Warrior shouts).
  - One line per learned variant with icon and name; a click casts its highest learned rank. The variant left-click currently uses is marked "last used". No favorites/stars.
  - A variant picked in the menu becomes the "last used" variant, so left-click on the reminder casts it from then on. Left-click is unchanged otherwise.
  - The mute buttons stay in the same menu. Needs "Left-click casts buff". Variant lines are secure buttons: they are only shown out of combat (in combat the menu shows the mute buttons only, as for items).
  - With the feature off, right-click works exactly as before.
- **Tracking reminder (beta)** – warns when your gathering tracking on the minimap is off: Find Herbs, Find Minerals or Find Fish.
  - One wanted tracking per character, chosen with the "Track: …" button below the "Tracking reminder" checkbox (greyed out while the checkbox is off). The button cycles through the trackings you have learned plus "none". Default (automatic): the first learned of Find Minerals, then Find Herbs; Find Fish only when you pick it.
  - The line appears when the wanted tracking is learned but not active, e.g. "Find Minerals is not active" (Compact: "off"). Names and icons come from the game client. Detection: the minimap tracking list, matched by spell ID, then by the client's spell name or icon.
  - Left-click turns the tracking on (out of combat only; in combat you get "Not possible in combat."). Right-click opens the usual menu to mute it. The "Use top warning" key works the same way.
  - Applies everywhere ("General buffs only in instances" does not affect it), but not while dead, on a flight path or in a vehicle. No expiry warning.
- **Low reagent warning** – warns when a reagent in your bags (bank not counted) drops below a threshold, e.g. "Holy Candle: 3 left". A reagent is only checked if you have learned at least one spell that uses it; for ranked spells the highest rank you know decides which reagent counts (e.g. Prayer of Fortitude rank 1 uses Holy Candle, rank 2 uses Sacred Candle; Rebirth uses a different seed per rank).
  - Priest: Holy Candle, Sacred Candle (Prayer of Fortitude / Spirit / Shadow Protection), Light Feather (Levitate)
  - Mage: Arcane Powder (Arcane Brilliance), Rune of Teleportation, Rune of Portals, Light Feather (Slow Fall)
  - Druid: Wild Berries, Wild Thornroot (Gift of the Wild), Maple / Stranglethorn / Ashwood / Hornbeam / Ironwood Seed (Rebirth)
  - Paladin: Symbol of Kings (Greater Blessings), Symbol of Divinity (Divine Intervention)
  - Shaman: Ankh (Reincarnation), Fish Oil (Water Walking), Shiny Fish Scale (Water Breathing)
  - Rogue: Flash Powder (Vanish), Blinding Powder (Blind)
  - Below the "Low reagent warning" checkbox, the settings list your class's reagents, each with a threshold field (0–50, 0 = no warning) and the current count in your bags. Defaults: Ankh and seeds 1, runes and Blinding Powder 5, everything else 10. Thresholds are saved per character.
  - Reagent warnings appear in the normal reminder list with the item's icon and name in your client language. Left-click does nothing; right-click mutes them like buff reminders.
- **Group buffs** – in a party or raid, the addon also checks your group members (including yourself) for the buffs you can give: Power Word: Fortitude, Shadow Protection, Divine Spirit, Arcane Intellect and Mark of the Wild, and (beta, own checkbox) Paladin blessings. A player counts as buffed with either the single-target or the group version (e.g. Prayer of Fortitude) from any caster.
  - **Paladin blessings (beta)** – Might, Wisdom, Kings and Sanctuary. Only your own blessing counts. If a player already has a blessing from another Paladin (or a stronger Battle Shout / Mana Spring), the line suggests another blessing you know that suits the player's class (Kings, Might, Sanctuary for Warrior, Rogue and Death Knight; Kings, Wisdom, Sanctuary for Mage, Priest and Warlock; all four for the rest); players who already have every suitable blessing are skipped. A blessing the game rejects with "A more powerful spell is already active" is not suggested again for that player for 2 minutes or until their buffs change. Left-click casts the Greater Blessing (covers the player's class) or the single blessing; the line shows the suggested blessing's name and icon.
  - Paladin blessings are experimental: they need the "Paladin blessings in group buffs" checkbox (below "Group buffs", greyed out while "Group buffs" is off) and are **completely off while Pally Power is loaded** (any addon whose folder name starts with "PallyPower"; checked once after login). The settings then say "Off while Pally Power is loaded". Your own blessing reminder (blessing on yourself) is not affected, and the variant menu stays off for blessings.
  - Only buffs whose single-target version you have learned are checked. Arcane Intellect and Divine Spirit are only checked on mana classes (Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock).
  - Players who are dead, offline, not visible or out of range are skipped. If the client hides the range (secret value), only visibility counts. Players sharing a short name (e.g. from different realms) are told apart and shown as Name-Realm. Only checked out of combat.
  - One line per buff replaces your own reminder for it, e.g. "Fortitude missing: 3". Below it are the names of the players without the buff (up to 5, then "+N"), then the click hints.
  - **Left-click** casts the group version on the first player without the buff, which covers that player's party or raid subgroup (or class for Greater Blessings, using your last-used blessing variant). If you have not learned the group version or are out of its reagent (see reagent warnings), the single-target version is cast instead. **Ctrl+Left-click** casts the single-target version on the next player without the buff. After each cast or buff change the target is chosen again. Hint: "Left-click: group · Ctrl+Left-click: single · Right-click: mute".
  - Detail settings below the "Group buffs" checkbox (Priest, Mage, Druid and Paladin only): "Check group buffs" (on by default; both checkboxes must be on) and "Check in: Always / Dungeons & raids only / Raids only" (default Always); for Paladins also "Paladin blessings in group buffs". Each buff's own on/off checkbox still applies.

## Slash commands

`/buffreminder` works as an alias for `/br`.

| Command        | Description                                   |
| -------------- | --------------------------------------------- |
| `/br`          | Open the settings (Pardona's Addons → Buff Reminder) |
| `/br test`     | Show a test reminder for 5 seconds (not in combat) |
| `/br minimap`  | Show or hide the shared Pardona minimap button (all Pardona addons) |
| `/br unmute`   | Clear all mutes                               |
| `/br auras`    | List your active buffs with name and spell ID |
| `/br debug`    | Print diagnostic state (reminders, eating detection) |
| `/br reset`    | Reset position and settings (not in combat)   |

## Development

**Libraries:** LibPardona-1.0 is not part of this repository. The packager fetches it into `Libs/lib-pardona` (externals in `.pkgmeta`); `Libs/` is ignored by Git and luacheck. Before testing locally from the repository, run:

```powershell
.\tools\fetch-libs.ps1
```

It copies the library from a sibling checkout `..\lib-pardona` if present (for local library development), otherwise it clones `https://github.com/KempaLars/lib-pardona`. It can be run any number of times; the previous copy is replaced. Changes to the library belong in the lib-pardona repository, never in `Libs/`.

The code is linted with [luacheck](https://github.com/lunarmodules/luacheck). The configuration is in `.luacheckrc` (Lua 5.1, the WoW API globals the addon uses, and the globals it writes). Run it locally from the repository root before committing:

```sh
luacheck .
```

It must report 0 warnings / 0 errors.

On GitHub, the **Lint** workflow (`.github/workflows/lint.yml`) runs luacheck on every push to `main` or `develop` and on every pull request. The release workflow runs the same lint job first; the addon is only packaged and uploaded if lint passes.

**Development build notice:** when the addon runs straight from the repository (the `@project-version@` placeholder in the TOC is not replaced), it prints "Development build loaded" to chat on login.

**Testing in game:** WoW only picks up new files (e.g. textures such as `Textures/Icon.tga`) after a full restart of the game client – `/reload` is not enough. Changes to existing Lua files are picked up by `/reload`.

## Credits

Thanks to zwrss for Paladin blessings in group buffs, the tracking reminder and group fixes (secret UnitInRange, players sharing a short name).

## Releasing

Versions are not edited by hand: the version in the TOC is `@project-version@` and is filled in from the Git tag. To publish a new version, push a tag in the format `X.Y.Z`:

```sh
git tag 1.0.1
git push origin 1.0.1
```

The GitHub Actions workflow (`.github/workflows/release.yml`) then runs luacheck and, if it passes, uses the BigWigs packager to build the addon zip, upload it to CurseForge and Wago and create a GitHub release. The changelog is generated from the commit messages.

- The file is named `PardonasBuffReminder-X.Y.Z.zip`; the display name on CurseForge and Wago is just the version number (e.g. **1.0.3**). The packager replaces spaces, apostrophes and other special characters in the label with `_`, so a label like "Pardona's Buff Reminder 1.0.3" would turn into `Pardona_s_Buff_Reminder_1.0.3`.

- **Requirements:** the repository secret `CF_API_KEY` must contain a CurseForge API token, and the repository secret `WAGO_API_TOKEN` must contain a Wago API token (the packager uploads to Wago in addition to CurseForge; the Wago project ID is set via `## X-Wago-ID` in the TOC).
- Tags containing `beta` or `alpha` (e.g. `1.1.0-beta1`) are published as beta or alpha releases. Beta and alpha versions print a short "Pardona's Buff Reminder: Version 1.1.0-beta1 loaded" line to chat on login; release versions print nothing.

## Repository layout

```
.
├── .github/workflows/
│   ├── lint.yml                    # Lint workflow (luacheck on push to main/develop and pull requests)
│   └── release.yml                 # Release workflow (triggered by version tags, lint first)
├── media/
│   ├── icon-minimap.svg            # Source for the former minimap button icon (no longer used)
│   ├── icon.svg                    # Source for the round addon list icon
│   └── logo.svg                    # Logo (vector, shown at the top of this README)
├── Textures/
│   └── Icon.tga                    # Addon list and Pardona menu icon (64x64, 32-bit TGA with alpha)
├── tools/
│   └── fetch-libs.ps1              # Fetches LibPardona-1.0 into Libs/ for local testing
├── .gitignore                      # Also ignores Libs/ (fetched by the packager or tools/fetch-libs.ps1)
├── .luacheckrc                     # luacheck configuration
├── .pkgmeta                        # Packager configuration
├── Bindings.xml                    # Keybinding "Use top warning" in the "Pardona's Addons" section (loaded automatically, not listed in the TOC)
├── PardonasBuffReminder.lua        # Addon code
├── PardonasBuffReminder.toc        # Addon metadata
└── README.md
```

`README.md`, `.luacheckrc`, `media/` and `tools/` are excluded from the packaged addon. The packaged addon contains `Libs/lib-pardona` (LibPardona-1.0 with LibStub), loaded by the TOC before the addon code.
