<p align="center">
  <img src="media/logo.svg" alt="Pardona's Buff Reminder logo" width="200">
</p>

# Pardona's Buff Reminder

A lightweight World of Warcraft addon that reminds you when your class buffs, weapon imbues or poisons, or (optionally) other buffs such as food or flasks are missing. Experimental opt-in features add group buff checks, wanted elixirs and scrolls, low reagent warnings, warnings for buffs that are about to expire, reminders for mage and warlock conjured items, one-click weapon stones, oils and poisons, a right-click menu to pick a buff variant, Paladin blessings in group buffs and a tracking reminder (herbs, minerals, fish). Missing buffs show up as a pulsing, movable list on screen (growing downwards or upwards) together with a chat message and an optional sound; a keybinding rebuffs the most urgent reminder.

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
  - Mage: Arcane Intellect, armor (Frost/Ice/Mage)
  - Warlock: Demon Skin / Demon Armor (Fel Armor if the game has it)
  - Druid: Mark of the Wild, Thorns
  - Paladin: any aura, any seal, any blessing, Righteous Fury
  - Shaman: Lightning Shield (Water / Earth Shield if the game has them)
  - Hunter: any aspect, Trueshot Aura
  - Warrior: Battle Shout (Commanding Shout if the game has it)
  - Death Knight: Horn of Winter (if the game has the class)
  - Situational buffs (e.g. Thorns, Shadowform, Righteous Fury, shouts) are off by default.
  - Reminders that accept several variants are labeled with a base word and their variants, e.g. "Armor (Frost/Ice/Mage)". Variant labels in the game only list variants the game client knows; variants that do not exist in WoW Forever are left out.
  - The addon also knows a few spells from later expansions (e.g. Molten Armor, Fel Armor, Water Shield, Earth Shield, Aspect of the Viper, Seal of Blood/Vengeance/Corruption, Commanding Shout, Horn of Winter). They are only checked, labeled and offered if the game client has them.
- **Weapon imbues and poisons** – Shaman main-hand/off-hand weapon imbues and Rogue main-hand/off-hand poisons. Off-hand checks only apply when an actual weapon is equipped there.
- **Other buffs (optional, off by default)** – Well Fed (including WoW Forever's "Well Fed XP Boost"), Flask, and Well-Rested (sleeping bag). Gathering tracking (Find Herbs, Find Minerals, Find Fish) is an experimental feature, see [Tracking reminder](#experimental-features-opt-in).
- **Use food and flasks by click** – for the Well Fed and Flask reminders:
  - **Left-click** uses the best matching item from your bags. The hint line shows which one ("Left-click: Smoked Desert Dumplings · Right-click: choose"), or "Not in bags · Right-click: mute" if you have none.
  - **Right-click** opens the reminder menu (see [Right-click menu](#right-click-menu-beta)) with all matching items in your bags.
  - **Favorites (beta)** – click the star next to an item in the menu to mark it as a favorite (saved per character). Left-click on the reminder always uses a favorite if one is in your bags; with several favorites the normal order below decides. Favorites are listed at the top of the menu. Click the star again to remove the favorite.
  - **Food** comes from a fixed list of WoW Forever cooking food that gives an XP buff (based on the beta, so it may still change). Only food you are high enough level for is offered. Best choice first (after favorites): 1) food whose tooltip mentions an experience bonus (only while you can still gain experience – not at max level or with experience gain turned off), 2) score = category weight for your class × cooking skill level, 3) larger stack. Each class has its own category order (e.g. Warrior: Strength, Melee AP, Agility, Crit, Stamina; Priest: Spirit, Intellect, Spell Damage, Healing); categories not listed for your class count less, movement and profession food the least.
  - **Flasks** are any flask in your bags (detected by item type, with a fallback list of the Classic flasks). After favorites, the flask you used last (remembered per character) comes first, then higher item level. The addon also learns each flask's effect so that new flasks count as an active Flask buff.
  - Uses the "Left-click casts buff" option: when it is off, left-click does nothing and right-click only mutes.
- **Eating countdown** – while you are eating (started from the reminder or directly from your bags; detected by the food's eating aura by spell ID or name, or by the generic "Food" or "Drink" aura) and are not yet Well Fed, the Well Fed reminder shows "Eating … 7 s", counting down the 10 seconds until the buff appears, then "Almost well fed …", with the hint "Stay seated". This does not trigger a chat message or sound. If you stand up before getting Well Fed, the normal reminder comes back (again without a new chat message or sound).
- **Instance mode** – other buffs can be limited to dungeons and raids ("Other buffs only in instances", on by default).
- **Right-click to mute** – right-click a reminder and pick 5, 15 or 60 minutes or the rest of the session in the menu. Mutes can be cleared from the settings or with `/br unmute`.
- **Left-click to cast** – left-click a reminder to cast the missing buff on yourself (highest rank you have learned; single-target version, never the group version such as Prayer of Fortitude or Gift of the Wild).
  - Directly castable: Priest (Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Vampiric Embrace, Shadowform), Mage (Arcane Intellect), Druid (Mark of the Wild, Thorns), Hunter (Trueshot Aura), Death Knight (Horn of Winter).
  - **"Any" reminders** (Paladin aura/seal/blessing, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues, Warrior shout): the addon remembers per character which variant you used last – either from a spell you cast or from a matching aura you applied yourself – and left-click casts that variant (Greater Blessings are remembered as the matching single-target blessing). Until a variant has been remembered, left-click does nothing.
  - Not castable: Rogue poisons and Well-Rested. Well Fed and Flask use an item instead (see above).
  - Can be turned off in the settings ("Left-click casts buff", on by default).
- **Hint line** – in the Pardona and Classic styles, every reminder shows a small second line telling you what a click does: "Left-click: cast · Right-click: mute" when click-to-cast is available, "Left-click: <item> · Right-click: choose" for food and flasks, otherwise "Right-click: mute". With the variant menu (beta) on, reminders with variants show "Left-click: cast · Right-click: choose" (or "Right-click: choose variant / mute" until a variant has been remembered).
  In the Compact style these hints are shown in the tooltip only.
- **Combat behaviour** – reminders are secure buttons, so the list (including click targets of group buff lines) cannot change during combat: reminders already shown can still be clicked (cast or mute), but new, removed or muted reminders and option changes are applied when combat ends. Test, Move/Lock and `/br reset` are refused in combat with a short chat message.
- **Sound** – chosen from a dropdown in the settings (Display tab); a sound plays once as a preview when you pick it. The sound only plays when a buff newly goes missing, not repeatedly, on the "Master" channel.
  - Built-in: Ping, Bell, Alarm, Ready check, Quest complete, Map ping, Coins, Group invite, Alarm clock, Boss emote, and Off. Each Blizzard sound is only listed if the game client knows its sound kit (`SOUNDKIT` constant, checked when the list opens); Ping, Bell and Alarm always work (fixed fallback IDs).
  - **LibSharedMedia** – if another addon loads LibSharedMedia-3.0, its sounds are listed below a "LibSharedMedia" separator and saved by name. If such a sound is no longer available later (e.g. the providing addon is disabled), Bell plays instead, without an error.
- **Size and opacity** – "Size" (50–200 %, default 100 %) and "Opacity" (30–100 %, default 100 %) sliders on the Display tab. They apply to the whole reminder list in every style (including Compact "Icons only"), in test and move mode; the list keeps its anchor point when resized. The pulsing stays visible relative to the chosen opacity. Right-click menus keep their normal size. Changes made in combat are applied when combat ends.
- **Movable display** – click "Move" in the settings (Display tab), "Move display" in the right-click menu of any reminder, or type `/br move`; drag the reminder to the desired position and click "Lock" or type `/br lock`. While moving, left-click does not cast. Not possible in combat.
- **Growth direction (beta)** – "New warnings appear: below / above" in the settings (default: below). With "above", the first reminder sits at the saved position and further reminders stack upwards, in every style; Move mode and `/br test` behave the same. Switching does not move the first reminder. With Compact "Icons only", icons are placed left to right, 8 per row; further rows are added below or above. The right-click menu always stays on screen and opens upwards if there is not enough room below the mouse pointer. In combat the new order is applied when combat ends.
- **Styles (beta)** – choose the look of the reminders and the right-click menu in the settings ("Style"). Switching applies immediately (in combat: when combat ends).
  - **Pardona** (default) – dark purple gradient, gold border with rounded corners, colored status stripe on the left (red = missing, orange = low reagent, green = eating), icon with gold frame, golden title, grey-purple hint line. Its colors, border and fonts come from the shared library LibPardona-1.0 (shared with all Pardona addons); if the library does not provide them, the addon uses its own built-in values.
  - **Classic** – stone/brown background, square gold frame, title in WoW yellow, beige hint line.
  - **Compact** – slim dark bars with a status stripe on the left and "missing" on the right; hints only in the tooltip. The extra option **Icons only** (only available with Compact) shows just the icons side by side; name and hints are in the tooltip.
- **Keybinding (beta)** – one key that rebuffs the most urgent reminder, see [Keybinding](#keybinding-beta).
- **Pardona's Addons entry point (beta)** – see [below](#pardonas-addons-beta).
- **Smart suppression** – no reminders while dead, on a flight path or in a vehicle.
- **Languages** – English and German, picked automatically from the game client language; more languages through CurseForge, see [Localization](#localization).

## Settings

The settings page (Options → AddOns → Pardona's Addons → Buff Reminder, or `/br`) is split into five tabs (Display, Class Buffs, Other Buffs, Supplies, Group) that sit on a dark inset panel in one row; with long translations the tab labels are shortened instead of wrapping. Each tab scrolls on its own. `/br` opens the tab you used last (an unknown saved tab falls back to Display). The tabs are split by purpose: **Other Buffs** holds everything that should be *kept active* as a buff, **Supplies** holds everything you should *carry enough of*. Choices with several values (style, growth direction, sound, tracking, group check) are dropdowns with the label on the left; they use the modern Blizzard dropdown when the client has it, otherwise the classic dropdown, otherwise a button that cycles through the values.

- **Display** – buttons Move/Lock, Test and Unmute all; Addon enabled; Left-click casts buff; dropdowns for Style (with the Icons only checkbox next to it), "New warnings appear" (below/above) and Sound; Size and Opacity sliders; the keybinding (current key and where to set it); Expiry warning (beta) with its threshold and relative opacity sliders.
- **Class Buffs** – your class's buffs with on/off checkboxes (spells not learned yet are greyed out with the level or talent they need); Variant menu on right-click (beta).
- **Other Buffs** (keep active), in this order:
  1. Well Fed, Flask, Well-Rested and the main-hand/off-hand weapon enhancements.
  2. "Other buffs only in instances", with a line below: it also applies to stones, oils, poisons, elixirs and scrolls, but not to the tracking reminder.
  3. Stones, oils, poisons by click (beta).
  4. Elixirs (beta) with the list of known elixirs (tick the ones you want).
  5. Scrolls (beta) with the six scroll types in two columns of three (checkbox, icon, name, count; long names are shortened, the full name is in the tooltip).
  6. Tracking reminder (beta) with the "Track" dropdown.
- **Supplies** (carry enough): Class consumables (beta) with the food/water threshold; Low reagent warning (beta) with the reagent list and thresholds; a note that ammunition, soul shards and minimum amounts for any item are coming in a later version.
- **Group** (only for classes with group buffs: Priest, Mage, Druid, Paladin) – Group buffs (beta), Check group buffs, "Check in" dropdown; for Paladins also Paladin blessings in group buffs (beta) with the Pally Power note.

Experimental switches carry an orange "(beta)" tag in their tab (muted while a parent switch is off). Lists below a switch (elixirs, scrolls, reagents) are collapsed while the switch is off and the rest of the tab moves up; simple detail settings (expiry sliders, food/water threshold, "Track" dropdown, group settings) stay visible but greyed out. A footer in each tab with such switches explains: "(beta) = experimental: on in beta builds, off by default in releases".

## Right-click menu (beta)

Right-clicking a reminder opens one window in the selected style:

- **Header** – the reminder's icon and title with a short line below (e.g. "Use an item or mute", the players missing a group buff, or the reagent count).
- **Food in your bags / Flasks** (Well Fed and Flask reminders only, with "Left-click casts buff" on) – one line per matching item: item icon, name, an **XP** badge if the food gives an experience bonus (not shown at max level or with experience gain turned off), the food's category (e.g. Spirit), and the count on the right. The line that left-click on the reminder would use is marked "best choice". Click a line to use the item; hovering shows the highlight and the item tooltip. The star on the right of each line marks or unmarks the item as a favorite – it never uses the item. If nothing matching is in your bags, the section says so.
- **Cast a variant** (variant menu (beta) only: Paladin aura and seal, Hunter aspect, Mage and Warlock armor, Shaman shield and weapon imbues) – one line per learned variant with icon and name; a click casts its highest learned rank and makes it the "last used" variant for left-click. The current one is marked "last used". See [Experimental features](#experimental-features-opt-in).
- **Mute** – four buttons side by side: 5 min, 15 min, 60 min, Session.
- **Move display** – a full-width button below the mute buttons: closes the menu and turns on move mode (same as "Move" in the settings or `/br move`). Not shown in combat.
- **Close (Esc)** – the footer closes the window; Esc closes it as well, and it closes on its own when the mouse has left it for 2 seconds.
- **In combat** only the header and the mute buttons are shown (no "Move display" either) (the item and variant lines are secure buttons and cannot be created or changed in combat). An open window with items or variants closes when combat starts.

## Keybinding (beta)

Under **Options > Keybindings > Pardona's Addons > Buff Reminder > Use top warning** you can bind a key. All Pardona addons share the "Pardona's Addons" section. Pressing the key does the same as a left-click on the topmost **missing** reminder on screen: cast the buff, eat, drink a flask, read a scroll, imbue the weapon, turn on tracking, or the group action of a group buff line. If nothing is missing, it refreshes the topmost buff that is about to expire (expiry warning). The "eating" line and reminders without a click action (e.g. reagent warnings) are skipped. "Topmost" follows the screen: with "New warnings appear: above" the list grows upwards, so the most recently added reminder is checked first; with Compact "Icons only" the top row is checked left to right. If there is nothing to do, the key does nothing (also in move mode).

- A reminder you just used (by key or by click) is skipped for 1.5 seconds, so an item is not used twice while bags and buffs update; the key moves on to the next reminder right away.
- In combat the key keeps the action it had when combat started. Items – food, flasks, elixirs, scrolls and weapon items – work only once per combat, spells can be used repeatedly. When combat ends, the key follows the list again.
- The settings (Display tab) show the current key (or "not bound") and where to set it.
- Macro alternative: `/click PardonasBuffReminderKeyButton`. If your client casts on key down ("Cast action keybinds on key down" on) and this macro does nothing, use `/click PardonasBuffReminderKeyButton LeftButton 1` instead.

## Pardona's Addons (beta)

All Pardona addons (Pardona's Buff Reminder, Pardona's ToolTips, …) share one entry point, provided by the embedded library [LibPardona-1.0](https://github.com/KempaLars/lib-pardona). With several Pardona addons installed you still get only one minimap button and one settings category.

- **Settings** – Options → AddOns → **Pardona's Addons** → **Buff Reminder**. The overview page "Pardona's Addons" lists every installed Pardona addon with its version, a short status and an *Open* button, plus a *Show minimap button* checkbox. `/br` opens the Buff Reminder page directly. If the client has no Settings API, `/br` opens the standalone settings window instead.
- **Addon compartment** – the entry "Pardona's Addons" in the addon compartment (next to the minimap, if the client has one) works like the minimap button.
- **Shared minimap button** – one "Pardona" button for all Pardona addons. With only Buff Reminder installed, left-click opens its settings; with several Pardona addons, left-click opens a small menu. Right-click opens the overview, drag moves the button along the minimap edge. The tooltip shows each addon's short status, for Buff Reminder e.g. "2 buffs missing" or "All active" (nothing in combat or while the state is still unknown). `/br minimap` or the overview checkbox shows or hides the button for all Pardona addons. The position and visibility of the old Buff Reminder minimap button are taken over once.
- **Menu entries** – with LibPardona MINOR 6 or newer, Buff Reminder adds three entries to the Pardona menu (below its row; with only Buff Reminder installed, left-click on the Pardona button opens this menu): "Move display" / "Lock display" (depending on move mode), "Test" (both greyed out in combat, tooltip "Not in combat") and "Unmute all" (greyed out while nothing is muted). They do the same as `/br move`, `/br lock`, `/br test` and `/br unmute`. Older library copies ignore the entries.
- **Titan Panel and other LibDataBroker displays** – if another addon already loads LibDataBroker-1.1 (e.g. Titan Panel, ChocolateBar), a "Pardona" launcher appears there. It behaves like the minimap button and shows the statuses as text; you can hide the minimap button if you prefer the panel.

## Experimental features (opt-in)

These features are not fully tested yet. They are **off by default in release versions** and can be turned on in the settings. Each switch sits in the tab it belongs to (see [Settings](#settings)) and is marked "(beta)": Expiry warning on the Display tab, Variant menu on the Class Buffs tab, Stones/oils/poisons, Elixirs, Scrolls and Tracking reminder on the Other Buffs tab, Class consumables and Low reagent warning on the Supplies tab, Group buffs and Paladin blessings on the Group tab. In beta, alpha and development builds they are on by default. Once you tick or untick a checkbox, your choice is kept (account-wide) regardless of the build; `/br reset` returns to the build default.

While a feature is off, it does nothing at all: no group lines, no group scans, no reagent lines and no reagent count checks; your own reminders work as usual. The detail settings below each checkbox are greyed out while it is off. Changes take effect immediately (in combat: when combat ends).

- **Expiry warning (beta)** – warns shortly before one of your active buffs runs out, so you can refresh it in time. Covers your enabled class buffs, Well Fed, flasks, wanted elixirs and scrolls (beta) and temporary weapon imbues/poisons (main and off hand); not Well-Rested, group buff lines or reagents.
  - A buff counts as expiring when its remaining time is at or below the threshold (default 10 % of its full duration). If the client does not reveal a buff's duration (secret values), has no duration or reports a duration of 0, that buff gets no expiry warning. Weapon imbues only report their remaining time, so the full duration is the highest remaining time seen since the imbue appeared (reset when it disappears or is reapplied).
  - Expiring buffs appear as their own line in the reminder list, after the missing buffs: same style, but semi-transparent (default 50 %), with an amber status stripe and a live countdown, e.g. "Arcane Intellect expires · 2:31". No sound, no chat message, no pulsing. When the buff runs out, the expiry warning turns into a missing reminder right away (with the usual chat message and sound).
  - Left-click works like on the missing-buff line (cast the buff, eat, drink a flask, imbue the weapon); right-click opens the same menu and mutes the same reminder. In combat the line is only updated, never changed; a line that would appear in combat shows up when combat ends. "Other buffs only in instances" also applies to food and flasks here.
  - Detail settings below the "Expiry warning" checkbox: "Threshold" slider (5–50 %, default 10 %) and "Opacity (relative)" slider (20–100 %, default 50 %). The opacity is relative to the list opacity: an expiring line shows at list opacity × this value (e.g. 80 % × 50 % = 40 %).
- **Class consumables (beta)** – reminds mages and warlocks to conjure their consumables. Each one is its own entry in the class list of the settings (own checkbox, on by default) and only appears there once you have learned the matching spell.
  - Mage: **conjured water** and **conjured food** – warns when the total of all ranks in your bags drops below the threshold, e.g. "Conjured Crystal Water: 5" (at 0: "… missing"). **Mana gem** – warns when you carry no mana gem of any rank.
  - Warlock: **Healthstone** – warns when you carry no healthstone of any rank (including the improved talent versions). **Soulstone** – warns when you carry no soulstone.
  - Item names come from the game client in your language; the line shows the item of the highest rank you know. Only your bags are counted (not the bank).
  - Left-click casts the highest rank you have learned; right-click opens the normal menu to mute the reminder (no item list). These reminders apply everywhere ("Other buffs only in instances" does not affect them) and get no expiry warning.
  - Detail setting below the "Class consumables" checkbox (mages only): "Food/water below" slider (0–60, default 20; 0 turns the food/water warning off).
- **Weapon enhancements: stones, oils, poisons (beta)** – apply sharpening stones, weightstones, wizard oils, mana oils or rogue poisons with one click.
  - Two new entries under other buffs, "Main hand: weapon enhancement" and "Off hand: weapon enhancement" (own checkboxes, on by default). Not available for shamans, who use their own imbues. For rogues they only apply while the matching poison entry (main/off-hand poison) is turned off.
  - A line appears only if a weapon is equipped in that slot, it has no temporary enhancement and you carry at least one matching item. "Other buffs only in instances" applies like for food and flasks.
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
  - One wanted tracking per character, chosen in the "Track" dropdown below the "Tracking reminder" checkbox (greyed out while the checkbox is off). It lists the trackings you have learned plus "none"; until you pick one, the automatic choice is shown with "(automatic)". Default (automatic): the first learned of Find Minerals, then Find Herbs; Find Fish only when you pick it.
  - The line appears when the wanted tracking is learned but not active, e.g. "Find Minerals is not active" (Compact: "off"). Names and icons come from the game client. Detection: the minimap tracking list, matched by spell ID, then by the client's spell name or icon.
  - Left-click turns the tracking on (out of combat only; in combat you get "Not possible in combat."). Right-click opens the usual menu to mute it. The "Use top warning" key works the same way.
  - Applies everywhere ("Other buffs only in instances" does not affect it), but not while dead, on a flight path or in a vehicle. No expiry warning.
- **Elixirs (beta)** – reminds you of the elixirs you want on this character.
  - **Stacking rules:** it is not confirmed whether WoW Forever uses the original rules (elixirs for different stats stack, flasks and elixirs work together) or the later rule (one battle and one guardian elixir, no elixirs with a flask). The addon therefore has no fixed battle/guardian slots. You pick the elixirs you want per character, and elixir reminders are independent of the flask reminder.
  - Every elixir that has been in your bags is remembered per character and listed below the "Elixirs" checkbox on the Other Buffs tab: checkbox, icon, name (from the game client) and the count in your bags. Ticked = wanted. Until an elixir has been in your bags, the list says "Elixirs you carry appear here.".
  - Elixirs are recognized by item type (consumable, subtype elixir); flasks stay with the Flask reminder. The buff is the elixir's item spell, matched by spell ID, then by name; the mapping is remembered account-wide.
  - Each wanted elixir gets its own line when its buff is missing **and** the elixir is in your bags, e.g. "Elixir of the Mongoose missing". Left-click uses it; right-click opens the usual menu (mute, move display) – there is no item list, since one line is one elixir.
  - "Other buffs only in instances", the expiry warning, sound, chat message, mute and the "Use top warning" key work as for food and flasks.
- **Scrolls (beta)** – reminds you to read a scroll you carry: Agility, Strength, Intellect, Spirit, Stamina and Protection.
  - Scrolls are recognized by item ID (ranks I–IV); other scrolls by item type (consumable, subtype scroll) when their item spell belongs to one of the six types.
  - **Usable ranks only:** a scroll counts only if its required level (from the game's item data, loaded on demand) is at or below your level. Left-click, "best choice" and the reminder use the best usable scroll: favorites first, then the highest usable rank. If only scrolls above your level are in your bags, there is no reminder. Your level is re-checked on level-up.
  - One line per type when a usable scroll of that type is in your bags and its buff (any rank) is missing. The line is labeled with the scroll left-click would use, e.g. "Scroll of Intellect missing" when you only carry rank I.
  - **Class buffs with values:** Intellect, Spirit and Stamina are skipped only while a class buff gives **at least as much** of the stat as the scroll left-click would use: Arcane Intellect / Arcane Brilliance, Divine Spirit / Prayer of Spirit, Power Word: Fortitude / Prayer of Fortitude (any caster). Example: Power Word: Fortitude rank 1 (+3 Stamina) is active and Scroll of Stamina IV (+16) is in your bags → the Stamina scroll reminder appears; with Fortitude rank 4 (+32) it does not. The class buff's value comes from the aura data when the client reveals it, otherwise from the original values (Fortitude 3/8/20/32/43/54, Prayer of Fortitude 43/54, Arcane Intellect 2/7/15/22/31, Arcane Brilliance 31, Divine Spirit 17/23/33/40, Prayer of Spirit 40); scroll values: Stamina and Intellect 4/8/12/16, Spirit 3/7/11/15. If a value cannot be determined, the reminder stays off (better none than a wrong one).
  - Left-click reads the best usable scroll; right-click opens the item menu with **all** scrolls of that type in your bags (favorites, "best choice", mute, move display). Scrolls above your level are greyed out, marked "Requires level N" and cannot be clicked.
  - Below the "Scrolls" checkbox (Other Buffs tab), one checkbox per type in two columns, labeled neutrally with the stat name from the game client (e.g. "Scroll: Intellect"), the rank I scroll's icon and the count of all ranks in your bags.
  - **Default per class** (saved per character once you tick or untick a type; `/br reset` returns to the class default):

    | Class | Scroll types on by default |
    |---|---|
    | Warrior, Rogue, Death Knight | Agility, Strength, Stamina, Protection |
    | Hunter | Agility, Intellect, Stamina, Protection |
    | Paladin, Shaman | Strength, Agility, Intellect, Stamina, Protection |
    | Druid | all six |
    | Priest, Mage, Warlock | Intellect, Spirit, Stamina, Protection |

    Types you had turned off in an earlier beta stay off.
  - "Other buffs only in instances" and the expiry warning apply as for food and flasks.
- **Low reagent warning** – warns when a reagent in your bags (bank not counted) drops below a threshold, e.g. "Holy Candle: 3 left". A reagent is only checked if you have learned at least one spell that uses it; for ranked spells the highest rank you know decides which reagent counts (e.g. Prayer of Fortitude rank 1 uses Holy Candle, rank 2 uses Sacred Candle; Rebirth uses a different seed per rank).
  - Priest: Holy Candle, Sacred Candle (Prayer of Fortitude / Spirit / Shadow Protection), Light Feather (Levitate)
  - Mage: Arcane Powder (Arcane Brilliance), Rune of Teleportation, Rune of Portals, Light Feather (Slow Fall)
  - Druid: Wild Berries, Wild Thornroot (Gift of the Wild), Maple / Stranglethorn / Ashwood / Hornbeam / Ironwood Seed (Rebirth)
  - Paladin: Symbol of Kings (Greater Blessings), Symbol of Divinity (Divine Intervention)
  - Shaman: Ankh (Reincarnation), Fish Oil (Water Walking), Shiny Fish Scale (Water Breathing)
  - Rogue: Flash Powder (Vanish), Blinding Powder (Blind)
  - Below the "Low reagent warning" checkbox, the settings list your class's reagents, each with a threshold field (0–50, 0 = no warning) and the current count in your bags. Defaults: Ankh and seeds 1, runes and Blinding Powder 5, everything else 10. Thresholds are saved per character.
  - Reagent warnings appear in the normal reminder list with the item's icon and name in your client language. Left-click does nothing; right-click mutes them like buff reminders.
- **Group buffs** – in a party or raid, the addon also checks your group members (including yourself) for the buffs you can give: Power Word: Fortitude, Shadow Protection, Divine Spirit, Arcane Intellect and Mark of the Wild, and (beta, own checkbox) Paladin blessings. A player counts as buffed with either the single-target or the group version (e.g. Prayer of Fortitude) from any caster. Exception: Paladin blessings only count when they are your own (see below).
  - **Paladin blessings (beta)** – Might, Wisdom, Kings and Sanctuary. Only your own blessing counts. The line suggests, and left-click casts, your last-used blessing if it suits the player's class and is not blocked; otherwise the first suitable, unblocked blessing you know from the class list (Kings, Might, Sanctuary for Warrior, Rogue and Death Knight; Kings, Wisdom, Sanctuary for Mage, Priest and Warlock; all four for the rest). A blessing is blocked for a player who already has it from another Paladin, who has an equal or stronger Battle Shout (blocks Might) or Mana Spring (blocks Wisdom), or when the game recently rejected it: a blessing rejected with "A more powerful spell is already active" is not suggested again for that player for 2 minutes or until their buffs change. Players for whom every suitable blessing is blocked are skipped. Left-click casts the Greater Blessing (covers the player's class) or the single blessing; the line shows the suggested blessing's name and icon.
  - Paladin blessings are experimental: they need the "Paladin blessings in group buffs" checkbox (below "Group buffs", greyed out while "Group buffs" is off) and are **completely off while Pally Power is loaded** (any addon whose folder name starts with "PallyPower"; checked once after login). Meant for groups without Pally Power; for coordinated blessing assignments use Pally Power. The settings then say "Off while Pally Power is loaded". Your own blessing reminder (blessing on yourself) is not affected, and the variant menu stays off for blessings.
  - Only buffs whose single-target version you have learned are checked. Arcane Intellect and Divine Spirit are only checked on mana classes (Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock).
  - Players who are dead, offline, not visible or out of range are skipped. If the client hides the range (secret value), only visibility counts. Players sharing a short name (e.g. from different realms) are told apart and shown as Name-Realm. Only checked out of combat.
  - One line per buff replaces your own reminder for it, e.g. "Fortitude missing: 3". Below it are the names of the players without the buff (up to 5, then "+N"), then the click hints.
  - **Left-click** casts the group version on the first player without the buff, which covers that player's party or raid subgroup (or class for Greater Blessings; which blessing is cast: see Paladin blessings above). If you have not learned the group version or are out of its reagent (see reagent warnings), the single-target version is cast instead. **Ctrl+Left-click** casts the single-target version on the next player without the buff. After each cast or buff change the target is chosen again. Hint: "Left-click: group · Ctrl+Left-click: single · Right-click: mute".
  - Detail settings below the "Group buffs" checkbox (Priest, Mage, Druid and Paladin only): "Check group buffs" (on by default; both checkboxes must be on) and the "Check in" dropdown (Always / Dungeons & raids only / Raids only) (default Always); for Paladins also "Paladin blessings in group buffs". Each buff's own on/off checkbox still applies.

## Localization

The addon's texts are translated on CurseForge: https://legacy.curseforge.com/wow/addons/pardonas-buff-reminder/localization

- **English** is the base language; every text exists in English.
- **German** is complete.
- **Initial translation, corrections welcome** (from the next beta on):
  - French (frFR)
  - Spanish (esES; Mexican Spanish, esMX, uses the Spanish texts)
  - Russian (ruRU)
  - Brazilian Portuguese (ptBR)
  - Italian (itIT)
- Texts that are not translated yet appear in English.
- Help with translations is welcome – log in on CurseForge and edit the phrases on the localization page.

Spell, item and tracking names as well as standard game texts come from the game client and are always in the client's language.

## Slash commands

`/buffreminder` works as an alias for `/br`.

| Command        | Description                                   |
| -------------- | --------------------------------------------- |
| `/br`          | Open the settings (Pardona's Addons → Buff Reminder) |
| `/br test`     | Show a test reminder for 5 seconds (not in combat) |
| `/br move`     | Unlock the display to move it (not in combat) |
| `/br lock`     | Lock the display again (not in combat)        |
| `/br minimap`  | Show or hide the shared Pardona minimap button (all Pardona addons) |
| `/br unmute`   | Clear all mutes                               |
| `/br auras`    | List your active buffs with name and spell ID |
| `/br debug`    | Print diagnostic state (reminders, eating detection, group, style, locale) and the LibPardona diagnostics: active library copy (MINOR, from which addon, style/menu/diagnostics versions), the copy bundled with Buff Reminder and the library MINOR of each Pardona addon. With a library older than MINOR 6: "Lib diagnostics: not available (Lib < 6)" |
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

**Localization:** all texts are looked up through `L` (`ns.L` in the addon namespace, no globals).

- `Locales/Locales.lua` creates the language tables (`ns.Locales`) and the lookup: active language, otherwise English, otherwise the key itself. Spanish (Mexico) falls back to Spanish (Spain) while it has no texts of its own.
- `Locales/enUS.lua` holds every phrase key and the English text as `L["KEY"] = "text"` lines. Keys are stable, upper case and use only `A-Z`, `0-9` and `_`.
- `Locales/deDE.lua`, `frFR.lua`, `esES.lua`, `esMX.lua`, `ruRU.lua`, `ptBR.lua` and `itIT.lua` contain only a `--@localization(...)@` token. The packager replaces it with the translations from CurseForge, so a build straight from the repository shows English only, whatever the client language.
- All language files are loaded; the TOC lists them before the libraries and the addon code.

When you add or change a text:

1. Edit `Locales/enUS.lua` (new keys get a new line; keep existing keys).
2. Run `.\tools\export-locale-import.ps1`. It regenerates `tools/locale-import/enUS.txt` and checks the other files in `tools/locale-import` (e.g. `deDE.txt`): keys that are not in enUS are reported as warnings, missing keys are listed.
3. Import `tools/locale-import/enUS.txt` on the CurseForge localization page (format: Lua additive table). Update `deDE.txt` (and the other language files where possible) and import them for their languages as well.

Visible texts for the Latin-script languages use only characters from Windows-1252.

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
├── Locales/
│   ├── Locales.lua                 # Language tables and lookup (ns.L), loaded first
│   ├── enUS.lua                    # All phrase keys with the English texts (base language)
│   └── deDE.lua, frFR.lua, …       # One file per language with the CurseForge localization token
├── tools/
│   ├── locale-import/
│   │   ├── enUS.txt                # English phrases for the CurseForge import (generated from Locales/enUS.lua)
│   │   ├── deDE.txt                # German phrases for the CurseForge import
│   │   └── frFR.txt, esES.txt, …       # Initial translations (frFR, esES, ruRU, ptBR, itIT) for the import
│   ├── export-locale-import.ps1    # Regenerates enUS.txt and checks the other import files
│   └── fetch-libs.ps1              # Fetches LibPardona-1.0 into Libs/ for local testing
├── .gitignore                      # Also ignores Libs/ (fetched by the packager or tools/fetch-libs.ps1)
├── .luacheckrc                     # luacheck configuration
├── .pkgmeta                        # Packager configuration
├── Bindings.xml                    # Keybinding "Use top warning" in the "Pardona's Addons" section (loaded automatically, not listed in the TOC)
├── PardonasBuffReminder.lua        # Addon code
├── PardonasBuffReminder.toc        # Addon metadata
└── README.md
```

`README.md`, `.luacheckrc`, `media/` and `tools/` are excluded from the packaged addon. The packaged addon contains `Locales/` (with the translations inserted by the packager) and `Libs/lib-pardona` (LibPardona-1.0 with LibStub), both loaded by the TOC before the addon code.
