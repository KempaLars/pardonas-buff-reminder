# Changelog – Pardona's Buff Reminder

What changed for players in each version. Handbook: https://pardonas-addons.de/buff-reminder/ (English) · https://pardonas-addons.de/de/buff-reminder/ (Deutsch)

Features marked (beta) are experimental: on in beta versions, off by default in releases. You can switch them on in the settings at any time.

## Unreleased
No changes yet.

## 1.5.0-beta4 – 2026-11-23
### Added
- Restock at vendors: open a vendor who sells one of your low supplies and a window offers to refill them up to your "Refill to" amount. Nothing is bought without your click (beta)
- "Also restock above the minimum": get everything below "Refill to" offered at every vendor visit (beta)
### Changed
- The expiry warning also watches poison charges, not only the remaining time (beta)

## 1.5.0-beta3 – 2026-11-23
### Fixed
- Buff food was missing from the food menu: any food that gives Well Fed is now recognized, not only food from the built-in list (same fix as 1.4.1)

## 1.5.0-beta2 – 2026-11-23
### Added
- Pet tab for Hunters and Warlocks: pet missing, pet dead and feed pet reminders with one-click feeding, demon reminder for Warlocks (beta)
- Supplies: ammunition, soul shards, pet food and up to 20 items of your own, each with a minimum and a critical amount (beta)
- Left-click a supply warning outside of towns to be reminded at the next inn, city, vendor or bank (beta)
- Low ammunition during a fight shows a red warning (beta)
- Several trackings at once, including Find Treasure for Dwarves and minimap trackings like flight masters (beta)

## 1.5.0-beta1 – 2026-11-22
### Added
- Quick actions in the Pardona minimap menu: move or lock the display, test, unmute all
- Size and opacity of the reminder list
- More sounds with a preview, plus sounds from LibSharedMedia
- `/br debug` now also lists your Pardona addons and their versions – handy when you report a bug
### Changed
- Style, sound, growth direction and group check are now picked from a drop-down list
- The "Use top warning" key handles the topmost missing buff first, then refreshes buffs that are about to expire. It no longer uses the same item twice by accident. In combat, the game only lets it use an item once per fight
- Expiry warnings now stay as faint as you set them, also when you change the list's opacity
### Fixed
- An expired buff turns into a missing reminder right away, without a short gap
- Expiry lines no longer jump to full opacity

## 1.4.1 – 2026-11-23
### Fixed
- Buff food such as Tasty Lion Steak was missing from the food menu: any food that gives Well Fed is now recognized

## 1.4.0 – 2026-11-22
### Added
- Settings split into tabs: Display, Class Buffs, Other Buffs, Supplies and Group
- Keybinding "Use top warning" (Options › Keybindings › Pardona's Addons)
- New warnings can appear above instead of below
- `/br move`, `/br lock` and "Move display" in the right-click menu
- Translations: French, Spanish, Russian, Portuguese (Brazil) and Italian, next to English and German
- Variant menu on right-click: pick your aura, seal, blessing, aspect, armor, shield or weapon imbue (beta)
- Paladin blessings in group buffs, off while Pally Power is loaded (beta)
- Tracking reminder for Find Minerals, Find Herbs and Find Fish (beta)
- Elixirs you want to keep active, per character (beta)
- Scroll reminders that skip stats a class buff already gives (beta)
### Changed
- Names of auras, armors, aspects and other variants now appear in your game language
- No XP badge on food at max level or with experience turned off
### Fixed
- Group buffs mixed up players with the same short name (thanks to zwrss)
- Error messages from the group buff check in WoW Forever (thanks to zwrss)

## 1.3.0 – 2026-11-20
### Added
- Now also on Wago
- Expiry warning: a faint line shortly before a buff runs out (beta)
- Mages: conjured food, water and mana gem; Warlocks: healthstone and soulstone (beta)
- Sharpening stones, weightstones, oils and rogue poisons by click (beta)

## 1.2.0 – 2026-11-18
### Added
- Three styles: Pardona, Classic and Compact (optionally icons only)
- One right-click menu to choose items and mute reminders, with favorites
- Shared Pardona minimap button and settings entry for all Pardona addons
### Changed
- Missing buffs show up faster

## 1.1.0 – 2026-11-17
### Added
- Left-click a food or flask reminder to eat or drink the best item from your bags; right-click to choose (beta)
- Countdown on the Well Fed reminder while you eat
- Item tooltips in the food and flask menu
- Group buffs: check your party or raid and cast the group version with one click (beta)
- Low reagent warnings (beta)
- Beta versions show their version number in chat when you log in

## 1.0.7 – 2026-11-17
### Fixed
- Error when opening the mute menu

## 1.0.6 – 2026-11-15
### Changed
- Cleaner minimap button without the ring

## 1.0.5 – 2026-11-15
### Fixed
- No more false missing-buff warnings right after a loading screen

## 1.0.4 – 2026-11-15
### Fixed
- The addon icon was upside down

## 1.0.3 – 2026-11-15
### Changed
- Well-Rested is detected reliably; general buffs use the game's own icons

## 1.0.2 – 2026-11-15
### Changed
- The addon logo is now the minimap and addon list icon
### Fixed
- Minimap button layout in WoW Forever

## 1.0.1 – 2026-11-15
### Added
- Left-click a reminder to cast the buff; a hint line under each reminder tells you what a click does
