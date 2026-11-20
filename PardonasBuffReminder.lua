-- Pardona's Buff Reminder – WoW Forever (Interface 16001, Mainline-API)
-- Erinnert an fehlende Klassen- und allgemeine Buffs (auch bei Gruppen-/Raid-Mitgliedern)
-- sowie an knappe Reagenzien.
-- Auswahl per GUI (Pardona-Menü / Einstellungen / /br), Rechtsklick auf Erinnerung = stummschalten,
-- Linksklick auf Erinnerung = Buff auf sich selbst zaubern (abschaltbar);
-- bei Essen/Fläschchen = bestes Item aus den Taschen benutzen, Rechtsklick = Auswahl.

local ADDON_NAME, ns = ...

-- Lua 5.1 erlaubt max. 200 lokale Variablen im Hauptchunk und 60 Upvalues pro Funktion.
-- Zusammengehörige Funktionen/Daten liegen deshalb in diesen Tabellen statt in eigenen locals.
local Items   = {}   -- Essen & Fläschchen: Daten, Taschen-Scan, Auswahl
local Eat     = {}   -- Ess-Countdown
local Group   = {}   -- Gruppen-Buffs
local Style   = {}   -- Stil-Tabelle und Gestaltungs-Helfer
local Display = {}   -- Warnzeilen (Secure Buttons)
local Menu    = {}   -- Rechtsklick-Menü
local Cfg     = {}   -- Einstellungsfenster
local Expiry  = {}   -- Warnung vor Ablauf (experimentell)
local Conjure = {}   -- Klassen-Verbrauchsgüter: Magier-Essen/-Wasser/Manastein, Hexenmeister-Steine (experimentell)
local Keybind = {}   -- Tastenbelegung "Oberste Warnung auslösen" (unsichtbarer Secure Button)
local Variant = {}   -- Variantenmenü per Rechtsklick (experimentell)
local Tracking = {}  -- Minimap-Tracking (z. B. Mineraliensuche)
local Demo = {}      -- versteckter Demo-Modus mit Screenshot-Lauf (nur mit BuffReminderDB.demo)
local Elixir = {}    -- Wunsch-Elixiere pro Charakter (experimentell)

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
-- Die Texte stehen in Locales/*.lua (Schlüssel und englische Texte: Locales/enUS.lua; weitere
-- Sprachen setzt der CurseForge-Packager ein). ns.L[key] = aktive Sprache, sonst enUS, sonst key.
-- Aktiv ist zunächst die Client-Sprache; bei ADDON_LOADED gilt der versteckte Schalter
-- BuffReminderDB.locale (nur gültige Codes mit Texten). Texte daher erst bei Bedarf lesen;
-- was beim Laden gesetzt wird (Tastenbelegung), setzt ADDON_LOADED neu.
local L = ns.L
ns.Locales.Activate(ns.Locales.Client())   -- jetzt sind alle Sprachdateien geladen

---------------------------------------------------------------------------
-- Buff-Datenbank
--   ids       : alle Spell-IDs (alle Ränge + Gruppenvarianten), die als "Buff vorhanden" zählen
--   nameIds   : IDs, deren Name zusätzlich als Treffer zählt (Fallback, falls andere IDs)
--   knownIds  : IDs zur Prüfung "Zauber erlernt" (Standard: ids)
--   level     : Lernstufe (Anzeige + Fallback)
--   talent    : Talentzauber (nur per Zauberbuch erkennbar)
--   levelOnly : erlernt = Stufe erreicht (z. B. Schurkengifte)
--   kind      : "aura" (Standard) | "weapon_mh" | "weapon_oh"
--   defaultOff: standardmäßig nicht ausgewählt (situative Buffs)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Klassen-Verbrauchsgüter (experimentell, Schalter expConsumables)
--   spells    : Zauber-Ränge aufsteigend (Erlernt-Prüfung; Linksklick zaubert den höchsten)
--   rankItems : Item des jeweiligen Rangs (gleicher Index, nil = nicht hinterlegt);
--               nur für Name und Icon der Zeile (Namen immer per C_Item)
--   items     : alle Items, die gezählt werden (nur Taschen)
--   mode      : "sum" = Summe < Schwelle (db.conjureThreshold), "any" = keins in den Taschen
---------------------------------------------------------------------------
Conjure.WATER = { mode = "sum",
    spells    = { 5504, 5505, 5506, 6127, 10138, 10139, 10140, 37420, 27090 },
    rankItems = { 5350, 2288, 2136, 3772, 8077, 8078, 8079, 30703, 22018 },
    items     = { 5350, 2288, 2136, 3772, 8077, 8078, 8079, 30703, 22018 } }
Conjure.FOOD = { mode = "sum",
    spells    = { 587, 597, 990, 6129, 10144, 10145, 28612, 33717 },
    rankItems = { 5349, 1113, 1114, 1487, 8075, 8076, 22895, 22019 },
    items     = { 5349, 1113, 1114, 1487, 8075, 8076, 22895, 22019 } }
Conjure.GEM = { mode = "any",
    spells    = { 759, 3552, 10053, 10054, 27101 },
    rankItems = { 5514, 5513, 8007, 8008, 22044 },
    items     = { 5514, 5513, 8007, 8008, 22044 } }
Conjure.HEALTHSTONE = { mode = "any",
    spells    = { 6201, 6202, 5699, 11729, 11730, 27230 },
    rankItems = { 5512, 5511, 5509, 5510, 9421, 22103 },
    -- je Rang normal + zwei verbesserte Varianten (Talent)
    items     = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011,
                  9421, 19012, 19013, 22103, 22104, 22105 } }
Conjure.SOULSTONE = { mode = "any",
    spells    = { 693, 20752, 20755, 20756, 20757, 27238 },
    rankItems = { 5232, 16892, 16893, 16895, 16896, 22116 },
    items     = { 5232, 16892, 16893, 16895, 16896, 22116 } }

local CLASS_BUFFS = {
    PRIEST = {
        { key = "fortitude", level = 1,
          ids = { 1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161, 21562, 21564, 25392, 48162 },
          nameIds = { 1243, 21562 } },
        { key = "innerfire", level = 12,
          ids = { 588, 7128, 602, 1006, 10951, 10952, 25431, 48040, 48168 }, nameIds = { 588 } },
        { key = "divinespirit", level = 30, talent = true,
          ids = { 14752, 14818, 14819, 27841, 25312, 48073, 27681, 32999, 48074 },
          nameIds = { 14752, 27681 } },
        { key = "shadowprot", level = 30,
          ids = { 976, 10957, 10958, 25433, 48169, 27683, 39374, 48170 }, nameIds = { 976, 27683 } },
        { key = "vampembrace", level = 30, talent = true, defaultOff = true, ids = { 15286 } },
        { key = "shadowform", level = 40, talent = true, defaultOff = true, ids = { 15473 } },
    },
    MAGE = {
        { key = "intellect", level = 1,
          ids = { 1459, 1460, 1461, 10156, 10157, 27126, 42995, 23028, 27127, 43002, 61024, 61316 },
          nameIds = { 1459, 23028, 61024, 61316 } },
        { key = "armor", level = 1, label = "ARMOR",
          ids = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 27124, 43008, 6117, 22782, 22783,
                  27125, 43023, 43024, 30482, 43045, 43046 },
          nameIds = { 168, 7302, 6117, 30482 } },
        -- Klassen-Verbrauchsgüter (kind "conjure"; Zeile in den Optionen erst, wenn erlernt)
        { key = "mage_water", kind = "conjure", level = 4, hideUnknown = true,
          conj = Conjure.WATER, knownIds = Conjure.WATER.spells },
        { key = "mage_food", kind = "conjure", level = 6, hideUnknown = true,
          conj = Conjure.FOOD, knownIds = Conjure.FOOD.spells },
        { key = "mage_gem", kind = "conjure", level = 28, hideUnknown = true,
          conj = Conjure.GEM, knownIds = Conjure.GEM.spells },
    },
    WARLOCK = {
        { key = "armor", level = 1, label = "ARMOR",
          ids = { 687, 696, 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889, 28176, 28189, 47892, 47893 },
          nameIds = { 687, 706, 28176 } },
        { key = "wl_healthstone", kind = "conjure", level = 10, hideUnknown = true,
          conj = Conjure.HEALTHSTONE, knownIds = Conjure.HEALTHSTONE.spells },
        { key = "wl_soulstone", kind = "conjure", level = 18, hideUnknown = true,
          conj = Conjure.SOULSTONE, knownIds = Conjure.SOULSTONE.spells },
    },
    DRUID = {
        { key = "motw", level = 1,
          ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469, 21849, 21850, 26991, 48470 },
          nameIds = { 1126, 21849 } },
        { key = "thorns", level = 6, defaultOff = true,
          ids = { 467, 782, 1075, 8914, 9756, 9910, 26992, 53307 }, nameIds = { 467 } },
    },
    PALADIN = {
        { key = "aura", level = 1, label = "AURA",
          ids = { 465, 10290, 643, 10291, 1032, 10292, 10293, 27149, 48941, 48942,
                  7294, 10298, 10299, 10300, 10301, 27150, 54042, 19746,
                  19876, 19895, 19896, 27151, 48943, 19888, 19897, 19898, 27152, 48945,
                  19891, 19899, 19900, 27153, 48947, 32223 },
          nameIds = { 465, 7294, 19746, 19876, 19888, 19891, 32223 } },
        { key = "seal", level = 1, label = "SEAL",
          -- Siegel des Kreuzfahrers (21082 …): Classic-IDs, im Spiel per /br auras zu bestätigen
          ids = { 21084, 20154, 20375, 20165, 20166, 20164, 31801, 53736, 53720, 31892,
                  21082, 20162, 20305, 20306, 20307, 20308, 27158 },
          nameIds = { 21084, 20154, 20375, 20165, 20166, 20164, 31801, 53736, 53720, 31892, 21082 } },
        { key = "blessing", level = 4, label = "BLESSING",
          ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932,
                  25782, 25916, 27141, 48933, 48934,
                  19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936,
                  25894, 25918, 27143, 48937, 48938, 20217, 25898, 20911, 25899, 27169 },
          nameIds = { 19740, 25782, 19742, 25894, 20217, 25898, 20911, 25899 } },
        { key = "rfury", level = 16, defaultOff = true, ids = { 25780 } },
    },
    SHAMAN = {
        { key = "shield", level = 8, label = "SHIELD",
          ids = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281,
                  52127, 52129, 52131, 52134, 52136, 52138, 24398, 33736, 57960,
                  974, 32593, 32594, 49283, 49284 },
          nameIds = { 324, 52127, 974 } },
        { key = "imbue_mh", kind = "weapon_mh", level = 10, label = "MH_ENCHANT",
          knownIds = { 8017, 8024, 8033, 8232, 51730 }, icon = 8024 },
        { key = "imbue_oh", kind = "weapon_oh", level = 40, label = "OH_ENCHANT",
          knownIds = { 8017, 8024, 8033, 8232, 51730 }, icon = 8033 },
    },
    ROGUE = {
        -- poisonItems: mit expWeaponItems Linksklick = bestes Gift aus den Taschen, Rechtsklick = Auswahl
        { key = "poison_mh", kind = "weapon_mh", level = 20, levelOnly = true, label = "MH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons", poisonItems = true },
        { key = "poison_oh", kind = "weapon_oh", level = 20, levelOnly = true, label = "OH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons", poisonItems = true },
    },
    HUNTER = {
        { key = "aspect", level = 4, label = "ASPECT",
          ids = { 13163, 13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044, 5118, 13159, 13161,
                  20043, 20190, 27045, 49071, 34074, 61846, 61847 },
          nameIds = { 13163, 13165, 5118, 13159, 13161, 20043, 34074, 61846 } },
        { key = "trueshot", level = 40, talent = true, ids = { 19506 } },
    },
    WARRIOR = {
        { key = "shout", level = 1, label = "SHOUT", defaultOff = true,
          ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436, 469, 47439, 47440 },
          nameIds = { 6673, 469 } },
    },
    DEATHKNIGHT = {
        { key = "horn", level = 65, defaultOff = true, ids = { 57330, 57623 }, nameIds = { 57330 } },
    },
}

local GENERAL_BUFFS = {
    -- itemKind: Linksklick benutzt das beste passende Item aus den Taschen (siehe "Essen & Fläschchen")
    -- 1243969 = "Well Fed XP Boost" (WoW Forever)
    { key = "gen_wellfed", general = true, defaultOff = true, itemKind = "food",
      ids = { 19705, 1243969 }, nameIds = { 19705 },
      icon = "Interface\\Icons\\Spell_Misc_Food" },
    { key = "gen_flask", general = true, defaultOff = true, itemKind = "flask", label = "FLASK", nameIds = {},
      ids = { 17626, 17627, 17628, 17629, 28518, 28519, 28520, 28521, 28540,
              53752, 53755, 53758, 53760, 54212, 62380 },
      icon = "Interface\\Icons\\INV_Potion_1" },
    -- Schlafsack-Buff aus WoW Forever: Spell-ID 429959 (wie Season of Discovery, per
    -- /br auras bestätigt). Der Name-Fallback (Groß-/Kleinschreibung, Leerzeichen und
    -- Bindestriche werden ignoriert) bleibt für abweichende IDs erhalten.
    -- excludeIds: Das passive Legacy-Talent "Well Rested" (1225478) heißt fast gleich, ist
    -- aber kein Schlafsack-Buff – Auren mit dieser ID zählen nie als Namenstreffer.
    { key = "gen_wellrested", general = true, defaultOff = true, label = "WELLRESTED",
      ids = { 429959 }, nameIds = { 429959 }, matchNames = { "Well-Rested", "Well Rested" },
      excludeIds = { 1225478 } },
    -- Waffen-Items (experimentell, expWeaponItems): Steine/Öle per Klick; fehlt nur, wenn eine Waffe
    -- im Slot steckt, keine temporäre Verzauberung aktiv ist und ein passendes Item in den Taschen
    -- liegt. Nicht für Schamanen (entfernt beim Login); bei Schurken nur, wenn der Gift-Eintrag
    -- desselben Slots aus ist (poisonEntry, beim Login gesetzt).
    { key = "gen_weapon_mh", general = true, kind = "weapon_mh", weaponItems = true, label = "WEAPON_MH",
      icon = "Interface\\Icons\\INV_Stone_SharpeningStone_01" },
    { key = "gen_weapon_oh", general = true, kind = "weapon_oh", weaponItems = true, label = "WEAPON_OH",
      icon = "Interface\\Icons\\INV_Stone_SharpeningStone_01" },
}

---------------------------------------------------------------------------
-- Klick-Zaubern (Linksklick auf eine Erinnerung zaubert den Buff auf sich)
--   castIds  : Einzelziel-Ränge in aufsteigender Reihenfolge; gezaubert wird
--              der höchste erlernte Rang (keine Gruppenvarianten)
--   variants : "beliebig"-Einträge; gemerkt wird pro Charakter die zuletzt
--              genutzte Variante (Zauber-Event oder eigene aktive Aura)
--     castIds : Einzelziel-Ränge, die gezaubert werden (zählen auch als Aura-IDs)
--     ids     : zusätzliche Aura-IDs der Variante (Gruppen-/Großer-Segen-Versionen)
--   Varianten werden zusätzlich über den Zaubernamen erkannt (Forever kann andere IDs nutzen).
-- Wird beim Login in die Einträge von CLASS_BUFFS übernommen (gleiche Keys).
-- Nicht zauberbar: Schurkengifte und alle allgemeinen Buffs.
---------------------------------------------------------------------------
local SHAMAN_IMBUES = {
    { key = "rockbiter",   castIds = { 8017, 8018, 8019, 10399, 16314, 16315, 16316, 25479, 25485 } },
    { key = "flametongue", castIds = { 8024, 8027, 8030, 16339, 16341, 16342, 25489, 58785, 58789, 58790 } },
    { key = "frostbrand",  castIds = { 8033, 8038, 10456, 16355, 16356, 25500, 58794, 58795, 58796 } },
    { key = "windfury",    castIds = { 8232, 8235, 10486, 16362, 25505, 58801, 58803, 58804 } },
    { key = "earthliving", castIds = { 51730, 51988, 51991, 51992, 51993, 51994 } },
}

local CAST_DATA = {
    PRIEST = {
        fortitude    = { castIds = { 1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161 } },
        innerfire    = { castIds = { 588, 7128, 602, 1006, 10951, 10952, 25431, 48040, 48168 } },
        divinespirit = { castIds = { 14752, 14818, 14819, 27841, 25312, 48073 } },
        shadowprot   = { castIds = { 976, 10957, 10958, 25433, 48169 } },
        vampembrace  = { castIds = { 15286 } },
        shadowform   = { castIds = { 15473 } },
    },
    MAGE = {
        intellect = { castIds = { 1459, 1460, 1461, 10156, 10157, 27126, 42995 } },
        armor = { variants = {
            { key = "frost",  castIds = { 168, 7300, 7301 } },
            { key = "ice",    castIds = { 7302, 7320, 10219, 10220, 27124, 43008 } },
            { key = "mage",   castIds = { 6117, 22782, 22783, 27125, 43023, 43024 } },
            { key = "molten", castIds = { 30482, 43045, 43046 } },
        }, menu = true },
        mage_water = { castIds = Conjure.WATER.spells },
        mage_food  = { castIds = Conjure.FOOD.spells },
        mage_gem   = { castIds = Conjure.GEM.spells },
    },
    WARLOCK = {
        armor = { variants = {
            { key = "demonskin",  castIds = { 687, 696 } },
            { key = "demonarmor", castIds = { 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889 } },
            { key = "felarmor",   castIds = { 28176, 28189, 47892, 47893 } },
        }, menu = true },
        wl_healthstone = { castIds = Conjure.HEALTHSTONE.spells },
        wl_soulstone   = { castIds = Conjure.SOULSTONE.spells },
    },
    DRUID = {
        motw   = { castIds = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469 } },
        thorns = { castIds = { 467, 782, 1075, 8914, 9756, 9910, 26992, 53307 } },
    },
    PALADIN = {
        aura = { variants = {
            { key = "devotion",      castIds = { 465, 10290, 643, 10291, 1032, 10292, 10293, 27149, 48941, 48942 } },
            { key = "retribution",   castIds = { 7294, 10298, 10299, 10300, 10301, 27150, 54042 } },
            { key = "concentration", castIds = { 19746 } },
            { key = "shadowres",     castIds = { 19876, 19895, 19896, 27151, 48943 } },
            { key = "frostres",      castIds = { 19888, 19897, 19898, 27152, 48945 } },
            { key = "fireres",       castIds = { 19891, 19899, 19900, 27153, 48947 } },
            { key = "crusader",      castIds = { 32223 } },
        }, menu = true },
        seal = { variants = {
            { key = "righteousness", castIds = { 21084, 20154 } },
            { key = "command",       castIds = { 20375 } },
            { key = "light",         castIds = { 20165 } },
            { key = "wisdom",        castIds = { 20166 } },
            { key = "justice",       castIds = { 20164 } },
            { key = "vengeance",     castIds = { 31801 } },
            { key = "corruption",    castIds = { 53736 } },
            { key = "martyr",        castIds = { 53720 } },
            { key = "blood",         castIds = { 31892 } },
            { key = "crusader",      castIds = { 21082, 20162, 20305, 20306, 20307, 20308, 27158 } },
        }, menu = true },
        blessing = { variants = {
            { key = "might",
              castIds = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932 },
              ids = { 25782, 25916, 27141, 48933, 48934 } },               -- Großer Segen der Macht
            { key = "wisdom",
              castIds = { 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936 },
              ids = { 25894, 25918, 27143, 48937, 48938 } },               -- Großer Segen der Weisheit
            { key = "kings",     castIds = { 20217 }, ids = { 25898 } },   -- Großer Segen der Könige
            { key = "sanctuary", castIds = { 20911 }, ids = { 25899, 27169 } },   -- Großer Segen des Refugiums
        } },
    },
    SHAMAN = {
        shield = { variants = {
            { key = "lightning", castIds = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281 } },
            { key = "water",     castIds = { 52127, 52129, 52131, 52134, 52136, 52138, 24398, 33736, 57960 } },
            { key = "earth",     castIds = { 974, 32593, 32594, 49283, 49284 } },
        }, menu = true },
        imbue_mh = { variants = SHAMAN_IMBUES, menu = true },
        imbue_oh = { variants = SHAMAN_IMBUES, menu = true },
    },
    HUNTER = {
        aspect = { variants = {
            { key = "monkey",     castIds = { 13163 } },
            { key = "hawk",       castIds = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044 } },
            { key = "cheetah",    castIds = { 5118 } },
            { key = "pack",       castIds = { 13159 } },
            { key = "beast",      castIds = { 13161 } },
            { key = "wild",       castIds = { 20043, 20190, 27045, 49071 } },
            { key = "viper",      castIds = { 34074 } },
            { key = "dragonhawk", castIds = { 61846, 61847 } },
        }, menu = true },
        trueshot = { castIds = { 19506 } },
    },
    WARRIOR = {
        shout = { variants = {
            { key = "battle",     castIds = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436 } },
            { key = "commanding", castIds = { 469, 47439, 47440 } },
        } },
    },
    DEATHKNIGHT = {
        horn = { castIds = { 57330, 57623 } },
    },
}

---------------------------------------------------------------------------
-- Essen & Fläschchen (Linksklick / Auswahl-Popup bei gen_wellfed und gen_flask)
--
-- FOOD: XP-Essen aus WoW Forever, je Kategorie { Item-ID, Kochkunst-Stufe }.
--   Datenquelle: Wowhead "All Cooking Food that Currently Gives XP Buffs" (WoW Forever).
--   ACHTUNG: Die Liste stammt aus der Beta und kann sich bis zum Release noch ändern.
--   Ob ein Item tatsächlich einen XP-Bonus gibt, wird zusätzlich per Tooltip geprüft.
-- Sortierung ("beste Wahl" zuerst):
--   1) XP-Bonus laut Tooltip, 2) Score = Kategorie-Gewicht x Kochkunst-Stufe, 3) Anzahl.
--   Nur Items, deren benötigte Stufe <= Spielerstufe.
---------------------------------------------------------------------------
Items.FOOD = {
    MeleeAP = { { 6290, 1 }, { 787, 50 }, { 4592, 50 }, { 8364, 175 }, { 13927, 225 }, { 13932, 250 },
        { 13934, 275 } },
    SpellDamage = { { 5095, 50 }, { 21072, 80 }, { 21217, 175 }, { 274971, 200 }, { 13931, 250 },
        { 13935, 250 }, { 249869, 200 } },
    Healing = { { 249865, 25 }, { 249866, 100 }, { 249867, 125 }, { 249868, 180 }, { 13933, 275 },
        { 249870, 250 } },
    Stamina = { { 6888, 1 }, { 5472, 10 }, { 263509, 25 }, { 3663, 90 }, { 250080, 75 }, { 5479, 100 },
        { 12213, 175 }, { 3665, 130 }, { 3666, 110 }, { 3729, 175 }, { 12214, 175 }, { 250078, 175 },
        { 6038, 175 }, { 12215, 200 }, { 12218, 225 }, { 17222, 200 }, { 250068, 275 } },
    Strength = { { 2888, 25 }, { 6890, 40 }, { 2681, 50 }, { 724, 50 }, { 3220, 60 }, { 3726, 110 },
        { 2687, 110 }, { 2685, 110 }, { 5480, 110 }, { 250074, 175 }, { 274976, 185 }, { 250065, 225 },
        { 250070, 275 }, { 250071, 275 }, { 20452, 285 } },
    Agility = { { 2680, 25 }, { 2684, 50 }, { 3662, 80 }, { 1017, 100 }, { 3727, 100 }, { 3664, 125 },
        { 12209, 125 }, { 13851, 175 }, { 20074, 150 }, { 12212, 125 }, { 18045, 225 }, { 250072, 275 },
        { 250069, 275 } },
    Intellect = { { 12224, 1 }, { 250079, 25 }, { 263512, 35 }, { 5477, 50 }, { 2682, 85 }, { 2683, 75 },
        { 1082, 100 }, { 250077, 75 }, { 12210, 175 }, { 4457, 175 }, { 12216, 225 }, { 250073, 275 },
        { 250076, 225 }, { 18254, 275 }, { 250066, 275 }, { 250067, 175 }, { 250075, 275 } },
    Spirit = { { 249871, 25 }, { 249872, 100 }, { 249873, 125 }, { 249874, 125 }, { 249875, 200 },
        { 249876, 250 } },
    Crit = { { 13928, 240 }, { 13929, 240 } },
    Armor = { { 286152, 225 } },
    Movement = { { 733, 75 }, { 267341, 275 } },
    Profession = { { 6316, 100 }, { 5476, 50 }, { 4593, 100 }, { 4594, 100 }, { 8957, 100 }, { 13930, 225 },
        { 10841, 100 } },
}

-- Kategorie-Reihenfolge je Klasse; Gewicht nach Position (FOOD_WEIGHTS).
-- Nicht genannte Kampf-Kategorien: FOOD_WEIGHT_OTHER; Movement/Profession fest.
Items.FOOD_PRIORITY = {
    WARRIOR = { "Strength", "MeleeAP", "Agility", "Crit", "Stamina" },
    ROGUE   = { "Agility", "MeleeAP", "Crit", "Strength", "Stamina" },
    HUNTER  = { "Agility", "Crit", "Intellect", "Stamina" },
    PALADIN = { "Strength", "MeleeAP", "Intellect", "Stamina" },
    SHAMAN  = { "MeleeAP", "Strength", "Intellect", "Stamina" },
    DRUID   = { "Agility", "Strength", "Intellect", "Stamina" },
    PRIEST  = { "Spirit", "Intellect", "SpellDamage", "Healing" },
    MAGE    = { "SpellDamage", "Intellect", "Spirit", "Stamina" },
    WARLOCK = { "SpellDamage", "Stamina", "Spirit", "Intellect" },
}
Items.FOOD_WEIGHTS = { 1.0, 0.85, 0.7, 0.55, 0.55 }
Items.FOOD_WEIGHT_OTHER = 0.35
Items.FOOD_WEIGHT_FIXED = { Movement = 0.25, Profession = 0.1 }
-- Heiler: Healing mindestens 0.55
Items.FOOD_HEALING_MIN = { PRIEST = 0.55, PALADIN = 0.55, DRUID = 0.55, SHAMAN = 0.55 }

-- Fläschchen-Fallback (Classic), falls die Item-Klasse nicht ermittelbar ist
Items.FLASK_IDS = { [13506] = true, [13510] = true, [13511] = true, [13512] = true, [13513] = true }

---------------------------------------------------------------------------
-- Waffen-Items (experimentell, Schalter expWeaponItems): Steine, Öle, Gifte
--   Gruppen je Liste in aufsteigender Stufe (höchste Stufe = letzter Index wird bevorzugt);
--   WEAPON_SPECIAL: nur gegen Untote (geweiht/gesegnet) -> niedrigste Stufe der Gruppe
--   Wetzsteine nur für Klingenwaffen, Gewichtssteine nur für stumpfe Waffen, Öle/Gifte für alle;
--   Faustwaffen und unbekannte Unterklassen: nur Öle (bzw. Gifte)
---------------------------------------------------------------------------
Items.WEAPON_ITEMS = {
    sharpen = { 2862, 2863, 2871, 7964, 12404, 18262, 23528, 23529, 23122 },
    weight  = { 3239, 3240, 3241, 7965, 12643, 28420, 28421 },
    wizard  = { 20744, 20746, 20750, 20749, 22522, 23123 },
    mana    = { 20745, 20747, 20748, 22521 },
}
Items.POISON_ITEMS = {
    instant   = { 6947, 6949, 6950, 8926, 8927, 8928, 21927 },
    deadly    = { 2892, 2893, 8984, 8985, 20844, 22053, 22054 },
    wound     = { 10918, 10920, 10921, 10922, 22055 },
    crippling = { 3775, 3776 },
    mind      = { 5237, 6951, 9186 },
}
Items.WEAPON_SPECIAL = { [23122] = true, [23123] = true }
-- Steine, die laut Tooltip auf jede Nahkampfwaffe wirken (Elementar, Geweiht): Klinge und stumpf
Items.ANY_MELEE_STONE = { [18262] = true, [23122] = true }
-- Rangfolge der Gruppen ("stone" = Wetz- oder Gewichtsstein) je Klasse
Items.WEAPON_ORDER_MELEE  = { "stone", "wizard", "mana" }
Items.WEAPON_ORDER = {
    MAGE    = { "wizard", "mana", "stone" }, WARLOCK = { "wizard", "mana", "stone" },
    PRIEST  = { "mana", "wizard", "stone" }, DRUID   = { "mana", "wizard", "stone" },
    PALADIN = { "mana", "wizard", "stone" },
}
Items.POISON_ORDER = { "instant", "deadly", "wound", "crippling", "mind" }
-- Waffen-Unterklassen (Item-Klasse 2)
Items.BLADE_SUB = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true }
Items.BLUNT_SUB = { [4] = true, [5] = true, [10] = true }

-- Item-ID -> { group, tier, poison = bool }
Items.weaponInfo = {}
for _, src in ipairs({ { Items.WEAPON_ITEMS, false }, { Items.POISON_ITEMS, true } }) do
    for group, list in pairs(src[1]) do
        for i, id in ipairs(list) do
            Items.weaponInfo[id] = { group = group, tier = Items.WEAPON_SPECIAL[id] and 0 or i, poison = src[2] }
        end
    end
end

---------------------------------------------------------------------------
-- Reagenzien (Classic-Daten)
--   REAGENT_INFO   : Item-ID -> Standard-Schwelle (Warnung, wenn Anzahl < Schwelle;
--                    0 = aus) und englischer Name (Fallback, bis das Item geladen ist)
--   REAGENT_SPELLS : pro Klasse Zauberlinien; Ränge aufsteigend { Spell-ID, Lernstufe, Item }.
--                    Item nil = dieser Rang verbraucht ein hier nicht geführtes Reagenz.
--   Ein Reagenz wird geprüft, wenn bei mindestens einer Linie der höchste erlernte Rang es
--   verbraucht (z. B. Gebet der Seelenstärke Rang 1 = Heilige Kerze, Rang 2 = Geweihte Kerze).
--   Namens-Fallback: Ist keine ID erlernt, aber der Zaubername bekannt, zählt der höchste
--   Rang, dessen Lernstufe erreicht ist.
---------------------------------------------------------------------------
local REAGENT_INFO = {
    [17028] = { default = 10, name = "Holy Candle" },
    [17029] = { default = 10, name = "Sacred Candle" },
    [17020] = { default = 10, name = "Arcane Powder" },
    [17031] = { default = 5,  name = "Rune of Teleportation" },
    [17032] = { default = 5,  name = "Rune of Portals" },
    [17056] = { default = 10, name = "Light Feather" },
    [17021] = { default = 10, name = "Wild Berries" },
    [17026] = { default = 10, name = "Wild Thornroot" },
    [17034] = { default = 1,  name = "Maple Seed" },
    [17035] = { default = 1,  name = "Stranglethorn Seed" },
    [17036] = { default = 1,  name = "Ashwood Seed" },
    [17037] = { default = 1,  name = "Hornbeam Seed" },
    [17038] = { default = 1,  name = "Ironwood Seed" },
    [21177] = { default = 10, name = "Symbol of Kings" },
    [17033] = { default = 10, name = "Symbol of Divinity" },
    [17030] = { default = 1,  name = "Ankh" },
    [17058] = { default = 10, name = "Fish Oil" },
    [17057] = { default = 10, name = "Shiny Fish Scale" },
    [5140]  = { default = 10, name = "Flash Powder" },
    [5530]  = { default = 5,  name = "Blinding Powder" },
}

-- je Spell-ID eine eigene Linie mit einem Rang (Teleports, Portale), damit der
-- Namens-Fallback für jeden Zielort einzeln greift
local function SingleRankLines(item, list)
    local lines = {}
    for _, v in ipairs(list) do lines[#lines + 1] = { { v[1], v[2], item } } end
    return lines
end

local function Concat(...)
    local out = {}
    for _, t in ipairs({ ... }) do
        for _, v in ipairs(t) do out[#out + 1] = v end
    end
    return out
end

local REAGENT_SPELLS = {
    PRIEST = {
        -- Gebet der Seelenstärke
        { { 21562, 48, 17028 }, { 21564, 60, 17029 }, { 25392, 70, 17029 }, { 48162, 80, nil } },
        -- Gebet der Willenskraft
        { { 27681, 60, 17029 }, { 32999, 70, 17029 }, { 48074, 80, nil } },
        -- Gebet des Schattenschutzes
        { { 27683, 56, 17029 }, { 39374, 70, 17029 }, { 48170, 80, nil } },
        -- Levitieren
        { { 1706, 34, 17056 } },
    },
    MAGE = Concat({
        -- Arkane Brillanz
        { { 23028, 56, 17020 }, { 27127, 70, 17020 }, { 43002, 80, 17020 } },
        -- Langsamer Fall
        { { 130, 12, 17056 } },
    },
    -- Teleport: Sturmwind, Eisenschmiede, Darnassus, Exodar, Orgrimmar, Unterstadt,
    -- Donnerfels, Silbermond, Shattrath (A/H), Theramore, Steinard, Dalaran
    SingleRankLines(17031, { { 3561, 20 }, { 3562, 20 }, { 3565, 20 }, { 32271, 20 }, { 3567, 20 },
        { 3563, 20 }, { 3566, 20 }, { 32272, 20 }, { 33690, 60 }, { 35715, 60 }, { 49359, 60 },
        { 49358, 60 }, { 53140, 71 } }),
    -- Portal: gleiche Reihenfolge
    SingleRankLines(17032, { { 10059, 40 }, { 11416, 40 }, { 11419, 40 }, { 32266, 40 }, { 11417, 40 },
        { 11418, 40 }, { 11420, 40 }, { 32267, 40 }, { 33691, 65 }, { 35717, 65 }, { 49360, 65 },
        { 49361, 65 }, { 53142, 74 } })),
    DRUID = {
        -- Gabe der Wildnis
        { { 21849, 50, 17021 }, { 21850, 60, 17026 }, { 26991, 70, nil }, { 48470, 80, nil } },
        -- Wiedergeburt
        { { 20484, 20, 17034 }, { 20739, 30, 17035 }, { 20742, 40, 17036 }, { 20747, 50, 17037 },
          { 20748, 60, 17038 }, { 26994, 69, nil }, { 48477, 78, nil } },
    },
    PALADIN = {
        -- Große Segen: Macht, Weisheit, Könige, Rettung, Licht, Refugium
        { { 25782, 52, 21177 }, { 25916, 60, 21177 }, { 27141, 70, 21177 }, { 48933, 73, 21177 },
          { 48934, 79, 21177 } },
        { { 25894, 54, 21177 }, { 25918, 60, 21177 }, { 27143, 70, 21177 }, { 48937, 75, 21177 },
          { 48938, 80, 21177 } },
        { { 25898, 60, 21177 } },
        { { 25895, 60, 21177 } },
        { { 25890, 60, 21177 }, { 27145, 70, 21177 } },
        { { 25899, 60, 21177 }, { 27169, 70, 21177 } },
        -- Göttliches Eingreifen
        { { 19752, 30, 17033 } },
    },
    SHAMAN = {
        { { 20608, 30, 17030 } },   -- Reinkarnation
        { { 546, 28, 17058 } },     -- Wasserwandeln
        { { 131, 22, 17057 } },     -- Wasseratmung
    },
    ROGUE = {
        { { 1856, 22, 5140 }, { 1857, 42, 5140 }, { 26889, 70, 5140 } },   -- Verschwinden
        { { 2094, 34, 5530 } },                                              -- Blenden
    },
}

---------------------------------------------------------------------------
-- Gruppen-Buffs (Party/Raid, nur außerhalb des Kampfes)
--   groupIds       : Ränge der Gruppenversion (aufsteigend); Lernstufe und Reagenz je Rang
--                    stammen aus REAGENT_SPELLS (RANK_INFO)
--   groupByVariant : Gruppenversionen stehen je Variante in v.ids (zuletzt genutzte Variante)
--   ownOnly        : nur eigene Auren (sourceUnit == "player") zählen als vorhanden;
--                    mit groupByVariant wird eine noch nicht aktive, passende Variante gewählt
--   manaOnly       : nur Spieler mit Mana-Klasse prüfen (Klasse, nicht aktueller Ressourcentyp)
-- Wird beim Login in die Einträge von CLASS_BUFFS übernommen (gleiche Keys).
---------------------------------------------------------------------------
local GROUP_BUFFS = {
    PRIEST = {
        fortitude    = { groupIds = { 21562, 21564, 25392, 48162 } },   -- Gebet der Seelenstärke
        shadowprot   = { groupIds = { 27683, 39374, 48170 } },          -- Gebet des Schattenschutzes
        divinespirit = { groupIds = { 27681, 32999, 48074 }, manaOnly = true },   -- Gebet der Willenskraft
    },
    MAGE = {
        intellect = { groupIds = { 23028, 27127, 43002 }, manaOnly = true },      -- Arkane Brillanz
    },
    DRUID = {
        motw = { groupIds = { 21849, 21850, 26991, 48470 } },           -- Gabe der Wildnis
    },
    PALADIN = {
        blessing = { groupByVariant = true, ownOnly = true },   -- Große Segen (nur eigener Segen, weicht fremden aus)
    },
}

local GROUP_MODE_ORDER = { "always", "instance", "raid" }

local MANA_CLASSES = {
    DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true, SHAMAN = true, WARLOCK = true,
}

-- Spell-ID -> { level, item } aus REAGENT_SPELLS (Lernstufe und Reagenz je Rang)
local RANK_INFO = {}
for _, lines in pairs(REAGENT_SPELLS) do
    for _, ranks in ipairs(lines) do
        for _, r in ipairs(ranks) do RANK_INFO[r[1]] = { level = r[2], item = r[3] } end
    end
end

local SOUNDS = {
    ping   = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE)          or 3081,
    glocke = (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 12889,
    alarm  = (SOUNDKIT and SOUNDKIT.RAID_WARNING)          or 8959,
}
local SOUND_ORDER = { "ping", "glocke", "alarm", "aus" }

local DEFAULTS = {
    enabled      = true,
    sound        = "ping",
    scale        = 1.0,
    point        = { "CENTER", "UIParent", "CENTER", 0, 140 },
    instanceOnly = true,
    groupCheck   = true,       -- Gruppen-Buffs bei Party-/Raid-Mitgliedern prüfen
    groupMode    = "always",   -- "always" | "instance" (Dungeon & Raid) | "raid"
    cfgTab       = "display",  -- zuletzt gewählter Tab der Einstellungen (Cfg.TAB_ORDER)
    clickCast    = true,   -- Linksklick auf Erinnerung zaubert den Buff
    style        = "pardona",   -- Stil von Warnanzeige und Menü (STYLES)
    iconsOnly    = false,       -- nur bei Stil "compact": nur Icons zeigen
    growUp       = false,       -- Liste wächst vom Anker nach oben (false: nach unten)
    expiryPct    = 10,          -- Warnung vor Ablauf: Restdauer <= x % der Gesamtdauer (5-50)
    expiryAlpha  = 0.5,         -- Warnung vor Ablauf: Zeilen-Transparenz (0.2-1)
    conjureThreshold = 20,      -- Magier: Warnung, wenn gezaubertes Essen/Wasser < x (0 = aus, max. 60)
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

---------------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------------
local db, cdb                 -- account / Charakter
local entries = {}            -- aktive Liste (Klasse + allgemein)
local classEntries = {}
local reagentEntries = {}     -- Reagenzien der eigenen Klasse (auch in entries)
local reagentLines = {}       -- Zauberlinien der eigenen Klasse (REAGENT_SPELLS)
local knownCache = {}
local missing = {}            -- key -> bool (letzter lesbarer Zustand)
local missingSince = {}       -- key -> GetTime(), seit dem der Buff durchgehend fehlt
local MISSING_CONFIRM = 1     -- Sek. durchgehendes Fehlen, bevor gewarnt wird
local shownKeys = {}          -- key -> true, aktuell eingeblendet
local muted = {}              -- key -> Ablaufzeit (GetTime) | math.huge
local ready, unlocked, testUntil = false, false, 0
local Evaluate, RefreshConfig -- forward
local warnCount               -- Anzahl angezeigter Warnungen, -1 = abgeschaltet, nil = unbekannt

-- Gemeinsame Pardona-Bibliothek (Minimap-Button, Einstellungs-Kategorie, Addon-Fach)
local LP = LibStub and LibStub("LibPardona-1.0", true)
local PARDONA_ID = "BuffReminder"

local function Print(msg) print("|cff66ccff" .. L.TITLE .. ":|r " .. msg) end

-- Anzeigename eines Einstellungswerts (z. B. "SOUND_" + "glocke" -> L.SOUND_GLOCKE), sonst der Wert
function Cfg.ValueText(prefix, value)
    local v = tostring(value)
    return ns.Locales.Text(prefix .. v:upper(), v)
end

-- Im Kampf: Hinweis, dass die Änderung erst danach sichtbar wird
local function NoteDeferred()
    if InCombatLockdown() then Print(L.AFTER_COMBAT) end
end

-- Namensvergleich ohne Groß-/Kleinschreibung, Leerzeichen und Bindestriche
local function NormName(n) return (n:lower():gsub("[%s%-]", "")) end

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Kurzstatus im Pardona-Menü/Tooltip/Broker neu anzeigen lassen (gedrosselt)
local statusPending = false
local function RefreshPardonaStatus()
    if not LP or statusPending then return end
    statusPending = true
    C_Timer.After(0.5, function()
        statusPending = false
        LP:RefreshStatus()
    end)
end

-- Addon-Version aus der TOC ("" = nicht lesbar)
local function AddonVersion()
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not fn then return "" end
    local ok, v = pcall(fn, ADDON_NAME, "Version")
    if not ok or type(v) ~= "string" or IsSecret(v) then return "" end
    return v
end

-- Build-Art: "dev" (Platzhalter nicht ersetzt / nicht lesbar), "test" (Beta/Alpha), "release"
local function BuildKind()
    local v = AddonVersion()
    if v == "" or v:find("@project-version@", 1, true) then return "dev", v end
    local lv = v:lower()
    if lv:find("beta", 1, true) or lv:find("alpha", 1, true) then return "test", v end
    return "release", v
end

-- Beta/Alpha oder Entwicklerversion?
local function IsTestBuild()
    return BuildKind() ~= "release"
end

-- Versionshinweis beim Login: nur Beta/Alpha und Entwicklerversion
local function PrintVersionNotice()
    local kind, v = BuildKind()
    if kind == "dev" then
        Print(L.DEV_BUILD)
    elseif kind == "test" then
        Print(L.VERSION_LOADED:format(v))
    end
end

-- Experimentelle Funktionen (account-weit): nil = nicht vom Nutzer gesetzt →
-- in Test-Builds an, in Release-Versionen aus
local function ExpOn(key)
    local v = db and db[key]
    if v == nil then return IsTestBuild() end
    return v and true or false
end

-- Gruppen-Buffs laufen nur, wenn der Experimental-Schalter UND groupCheck aktiv sind
local function GroupFeatureOn()
    return ExpOn("expGroup") and db.groupCheck and true or false
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n and not IsSecret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and n and not IsSecret(n) then return n end
    end
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t and not IsSecret(t) then return t end
    end
    if GetSpellTexture then
        local ok, t = pcall(GetSpellTexture, id)
        if ok and t then return t end
    end
end

---------------------------------------------------------------------------
-- Items (Reagenzien)
---------------------------------------------------------------------------
local function ItemName(item)
    if C_Item and C_Item.GetItemNameByID then
        local ok, n = pcall(C_Item.GetItemNameByID, item)
        if ok and n and not IsSecret(n) then return n end
    end
    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, item)
        if ok and n and not IsSecret(n) then return n end
    end
    -- noch nicht im Cache: Laden anstoßen (GET_ITEM_INFO_RECEIVED aktualisiert die Anzeige)
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
    return REAGENT_INFO[item] and REAGENT_INFO[item].name or tostring(item)
end

local function ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, item)
        if ok and t and not IsSecret(t) then return t end
    end
    if GetItemIcon then
        local ok, t = pcall(GetItemIcon, item)
        if ok and t and not IsSecret(t) then return t end
    end
end

-- Anzahl nur in den Taschen (ohne Bank), nil = nicht lesbar
local function ItemCount(item)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return nil end
    local ok, n = pcall(fn, item, false, false, false, false)
    if not ok or n == nil or IsSecret(n) then return nil end
    return n
end

local function ReagentThreshold(item)
    local v = cdb and cdb.reagents and cdb.reagents[item]
    if v == nil then v = REAGENT_INFO[item] and REAGENT_INFO[item].default or 0 end
    return v
end

---------------------------------------------------------------------------
-- Essen & Fläschchen: Taschen-Inhalt, Auswahl und Sortierung
---------------------------------------------------------------------------
Items.bagCounts = {}      -- Item-ID -> Anzahl in den Taschen (Scan bei BAG_UPDATE_DELAYED)
Items.foodScore = {}      -- Item-ID -> Kategorie-Gewicht x Kochkunst-Stufe (Klasse des Spielers)
Items.foodCat = {}        -- Item-ID -> FOOD-Kategorie mit dem höchsten Score (Anzeige im Menü)
Items.xpCache = {}        -- Item-ID -> true/false: Tooltip nennt XP-Bonus (nur geladene Items)
Items.flaskBySpell = {}   -- Spell-ID des Fläschchen-Effekts -> Item-ID
local flaskEntry          -- Eintrag gen_flask (idSet wird zur Laufzeit ergänzt)
local foodEntry           -- Eintrag gen_wellfed (eatStart = Beginn des Essens, nil = isst nicht)

---------------------------------------------------------------------------
-- Ess-Countdown: Ess-Auren aller FOOD-Items (C_Item.GetItemSpell), unabhängig davon,
-- ob über die Warnung oder direkt aus der Tasche gegessen wird.
---------------------------------------------------------------------------
-- Well Fed kommt laut Item-Tooltip nach "at least 10 seconds" Essen
Eat.EAT_WELLFED_TIME = 10
Eat.eatSpells = {}      -- Spell-ID der Ess-Aura -> true
Eat.eatNames = {}       -- Name der Ess-Aura -> true (die Aura-ID kann vom Item-Spell abweichen)
Eat.eatNorm = {}        -- NormName(Name) -> true
Eat.eatPending = {}     -- Item-ID -> true: Item-Daten noch nicht geladen, Spell folgt
-- Eat.eatAura: zuletzt gefundene Ess-Aura { id, name } (für /br debug)
-- generische Auren, die Essen/Trinken anlegen (WoW Forever: "Food" 433)
Eat.EAT_GENERIC_AURAS = { 433, 430 }   -- Food, Drink

function Eat.AddEatName(name)
    if type(name) ~= "string" or name == "" or IsSecret(name) then return end
    Eat.eatNames[name] = true
    Eat.eatNorm[NormName(name)] = true
end

-- Ess-Aura eines Essens ermitteln und cachen; nicht geladene Items nachfordern
-- (GET_ITEM_INFO_RECEIVED ruft mit loaded = true erneut auf; hat das geladene Item
-- keinen Spell, wird es nicht erneut angefordert – keine Endlosschleife)
function Eat.ResolveEatSpell(item, loaded)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, spellName, spellID = pcall(C_Item.GetItemSpell, item)
    if ok and type(spellID) == "number" and not IsSecret(spellID) then
        Eat.eatSpells[spellID] = true
        Eat.AddEatName(spellName)
        Eat.eatPending[item] = nil
        return
    end
    if loaded then Eat.eatPending[item] = nil; return end
    Eat.eatPending[item] = true
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
end

function Eat.ResolveAllEatSpells()
    for _, id in ipairs(Eat.EAT_GENERIC_AURAS) do Eat.AddEatName(SpellName(id)) end
    for _, list in pairs(Items.FOOD) do
        for _, v in ipairs(list) do Eat.ResolveEatSpell(v[1]) end
    end
end

function Eat.IsEatAura(a)
    if a.id and Eat.eatSpells[a.id] then return true end
    local n = a.name
    if type(n) ~= "string" or IsSecret(n) then return false end
    return Eat.eatNames[n] == true or Eat.eatNorm[NormName(n)] == true
end

-- Startzeit einer aktiven Ess-Aura (expirationTime - duration), nil = isst nicht oder
-- Laufzeit nicht lesbar (Secret) -> normale Anzeige ohne Countdown
function Eat.FindEatStart(scan)
    Eat.eatAura = nil
    if not scan then return nil end
    for _, a in ipairs(scan.list) do
        if Eat.IsEatAura(a) then
            Eat.eatAura = { id = a.id, name = a.name }
            local dur, exp = a.duration, a.expirationTime
            if type(dur) == "number" and type(exp) == "number" and dur > 0 then return exp - dur end
            return nil
        end
    end
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Haupttext während des Essens
function Eat.EatText(e)
    local left = (e.eatStart or 0) + Eat.EAT_WELLFED_TIME - GetTime()
    if left > 0 then return L.EATING:format(math.ceil(left)) end
    return L.EATING_DONE
end

function Items.BuildFoodScores(class)
    local weights = {}
    for cat in pairs(Items.FOOD) do weights[cat] = Items.FOOD_WEIGHT_FIXED[cat] or Items.FOOD_WEIGHT_OTHER end
    for i, cat in ipairs(Items.FOOD_PRIORITY[class] or {}) do
        weights[cat] = Items.FOOD_WEIGHTS[i] or Items.FOOD_WEIGHT_OTHER
    end
    if Items.FOOD_HEALING_MIN[class] then
        weights.Healing = math.max(weights.Healing, Items.FOOD_HEALING_MIN[class])
    end
    Items.class = class   -- auch für die Rangfolge der Waffen-Items
    wipe(Items.foodScore)
    wipe(Items.foodCat)
    for cat, list in pairs(Items.FOOD) do
        for _, v in ipairs(list) do
            local score = weights[cat] * v[2]
            if not Items.foodScore[v[1]] or score > Items.foodScore[v[1]] then
                Items.foodScore[v[1]] = score
                Items.foodCat[v[1]] = cat
            end
        end
    end
end

-- Item-Level und benötigte Stufe (nil, falls das Item noch nicht geladen ist)
function Items.ItemLevels(item)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, name, _, _, ilvl, minLevel = pcall(fn, item)
    if not ok or not name or IsSecret(ilvl) or IsSecret(minLevel) then return nil end
    return ilvl, minLevel
end

-- Zahl aus einer parameterlosen API-Funktion; nil = Funktion fehlt, Fehler oder Secret-Wert
function Items.SafeNumber(fn)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn)
    if ok and type(v) == "number" and not IsSecret(v) then return v end
    return nil
end

-- Maximalstufe des Spielers; nil = nicht ermittelbar
function Items.MaxPlayerLevel()
    local max = Items.SafeNumber(GetMaxLevelForPlayerExpansion) or Items.SafeNumber(GetMaxPlayerLevel)
    if max then return max end
    if type(MAX_PLAYER_LEVEL) == "number" and not IsSecret(MAX_PLAYER_LEVEL) then return MAX_PLAYER_LEVEL end
    return nil
end

-- Zählt Erfahrung für den Spieler? Nicht bei Maximalstufe und nicht bei abgeschalteter
-- Erfahrung (IsXPUserDisabled). Ergebnis in Items.xpOn; neu bewertet bei Login,
-- PLAYER_LEVEL_UP (level = neue Stufe), ENABLE_XP_GAIN und DISABLE_XP_GAIN.
function Items.UpdateXP(level)
    local on = true
    if type(IsXPUserDisabled) == "function" then
        local ok, off = pcall(IsXPUserDisabled)
        if ok and not IsSecret(off) and off then on = false end
    end
    local lvl = level
    if type(lvl) ~= "number" or IsSecret(lvl) then lvl = UnitLevel("player") end
    local max = Items.MaxPlayerLevel()
    if on and max and type(lvl) == "number" and not IsSecret(lvl) and lvl >= max then on = false end
    Items.xpOn = on
end

-- Nennt der Tooltip einen XP-Bonus? (enUS "experience", deDE "Erfahrung")
function Items.HasXPBonus(item)
    if Items.xpCache[item] ~= nil then return Items.xpCache[item] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return false end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, item)
    if not ok or type(data) ~= "table" or IsSecret(data) or type(data.lines) ~= "table" then return false end
    local found = false
    for _, line in ipairs(data.lines) do
        for _, t in ipairs({ line.leftText, line.rightText }) do
            if type(t) == "string" and not IsSecret(t) then
                local s = t:lower()
                if s:find("experience", 1, true) or s:find("erfahrung", 1, true) then found = true end
            end
        end
    end
    -- nur cachen, wenn das Item geladen ist (sonst ist der Tooltip unvollständig)
    if Items.ItemLevels(item) then Items.xpCache[item] = found end
    return found
end

function Items.IsFlaskItem(item)
    if Items.FLASK_IDS[item] then return true end
    local flaskSub = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Flask
    if not flaskSub then return false end
    local consumable = (Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    return ok and classID == consumable and subClassID == flaskSub
end

-- Spell-ID des Fläschchen-Effekts lernen, damit auch neue Fläschchen als aktiv erkannt werden
function Items.LearnFlaskSpell(item)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, _, spellID = pcall(C_Item.GetItemSpell, item)
    if not ok or type(spellID) ~= "number" or IsSecret(spellID) then return end
    Items.flaskBySpell[spellID] = item
    if flaskEntry then flaskEntry.idSet[spellID] = true end
    if db then db.flaskSpells[spellID] = true end
end

-- Taschen 0..NUM_BAG_SLOTS durchgehen (ohne Bank)
function Items.ScanBags()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
    wipe(Items.bagCounts)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and type(slots) == "number" and not IsSecret(slots) then
            for slot = 1, slots do
                local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok and type(info) == "table" and not IsSecret(info) then
                    local id, n = info.itemID, info.stackCount or 1
                    if type(id) == "number" and not IsSecret(id) and not IsSecret(n) then
                        Items.bagCounts[id] = (Items.bagCounts[id] or 0) + n
                    end
                end
            end
        end
    end
    for id in pairs(Items.bagCounts) do
        Items.LearnItem(id)   -- Fläschchen-/Elixier-/Rollen-Zauber lernen
    end
end

-- passende Items aus den Taschen, beste Wahl zuerst: { { id, count, fav, ... }, ... }
-- Favoriten (pro Charakter) stehen immer vorn; untereinander gilt die normale Sortierung.
function Items.ItemChoices(e)
    local list = {}
    local favs = cdb and cdb.favorites or {}
    local kind = Items.KindOf(e)
    if kind == "food" then
        local lvl = UnitLevel("player") or 1
        for id, n in pairs(Items.bagCounts) do
            if Items.foodScore[id] then
                local _, minLevel = Items.ItemLevels(id)
                if not minLevel or minLevel <= lvl then
                    -- XP-Bonus nur, wenn Erfahrung für den Spieler zählt (Abzeichen + Bevorzugung)
                    local xp = Items.xpOn ~= false and Items.HasXPBonus(id) or false
                    list[#list + 1] = { id = id, count = n, xp = xp, score = Items.foodScore[id],
                        cat = Items.foodCat[id], fav = favs[id] == true }
                end
            end
        end
        table.sort(list, function(a, b)
            if a.fav ~= b.fav then return a.fav end
            if a.xp ~= b.xp then return a.xp end
            if a.score ~= b.score then return a.score > b.score end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    elseif kind == "flask" then
        local last = cdb and cdb.lastFlask
        for id, n in pairs(Items.bagCounts) do
            if Items.IsFlaskItem(id) then
                list[#list + 1] = { id = id, count = n, ilvl = Items.ItemLevels(id) or 0, fav = favs[id] == true }
            end
        end
        table.sort(list, function(a, b)
            if a.fav ~= b.fav then return a.fav end
            if (a.id == last) ~= (b.id == last) then return a.id == last end
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    elseif kind == "weapon" or kind == "poison" then
        return Items.WeaponChoices(e, kind)
    elseif kind == "elixir" then
        -- ein Eintrag = ein Elixier
        local cnt = Items.bagCounts[e.item]
        if cnt and cnt > 0 then list[1] = { id = e.item, count = cnt, fav = favs[e.item] == true } end
    end
    return list
end

-- Item-Art eines Eintrags für Linksklick/Menü: "food" | "flask" | "weapon" | "poison" | nil.
-- Waffen-Items und Gifte nur mit aktivem Experimental-Schalter expWeaponItems.
function Items.KindOf(e)
    if e.weaponItems then return ExpOn("expWeaponItems") and "weapon" or nil end
    if e.poisonItems then return ExpOn("expWeaponItems") and "poison" or nil end
    return e.itemKind
end

function Items.WeaponSlot(e)
    return e.kind == "weapon_oh" and 17 or 16
end

-- Unterklasse der Waffe im Slot; nil = keine Waffe / nicht lesbar
function Items.WeaponSubclass(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id or IsSecret(id) then return nil end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, _, classID, subID = pcall(fn, id)
    if not ok or IsSecret(classID) or IsSecret(subID) or classID ~= 2 or type(subID) ~= "number" then return nil end
    return subID
end

-- passt das Item zur Waffe? (Wetzstein: Klinge, Gewichtsstein: stumpf, Elementar/Geweiht:
-- Klinge oder stumpf, Öle/Gifte: alle; Faustwaffen/unbekannt: keine Steine)
function Items.WeaponFits(id, group, sub)
    if Items.ANY_MELEE_STONE[id] then
        return sub ~= nil and (Items.BLADE_SUB[sub] == true or Items.BLUNT_SUB[sub] == true)
    end
    if group == "sharpen" then return sub ~= nil and Items.BLADE_SUB[sub] == true end
    if group == "weight" then return sub ~= nil and Items.BLUNT_SUB[sub] == true end
    return true
end

-- Steine/Öle bzw. Gifte aus den Taschen für den Slot des Eintrags: Favoriten, dann
-- Gruppen-Rangfolge (Klasse bzw. Gifte), dann höchste Stufe, dann Anzahl
function Items.WeaponChoices(e, kind)
    local list, favs = {}, cdb and cdb.favorites or {}
    local sub = Items.WeaponSubclass(Items.WeaponSlot(e))
    local order = kind == "poison" and Items.POISON_ORDER
        or Items.WEAPON_ORDER[Items.class or ""] or Items.WEAPON_ORDER_MELEE
    local rank = {}
    for i, g in ipairs(order) do rank[g] = i end
    local lvl = UnitLevel("player") or 1
    for id, n in pairs(Items.bagCounts) do
        local info = Items.weaponInfo[id]
        if info and info.poison == (kind == "poison") and Items.WeaponFits(id, info.group, sub) then
            local _, minLevel = Items.ItemLevels(id)
            if not minLevel or minLevel <= lvl then
                local g = (info.group == "sharpen" or info.group == "weight") and "stone" or info.group
                list[#list + 1] = { id = id, count = n, fav = favs[id] == true, rank = rank[g] or 99,
                    tier = info.tier, wcat = info.group }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.fav ~= b.fav then return a.fav end
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.tier ~= b.tier then return a.tier > b.tier end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    return list
end

-- Makro: Item benutzen und auf den Waffen-Slot anwenden
function Items.WeaponMacro(id, slot)
    return ("/use item:%d\n/use %d"):format(id, slot)
end

---------------------------------------------------------------------------
-- Verfolgungs-Erinnerung (experimentell, Schalter expTracking): Kräuter-, Mineralien- und
-- Fischsuche über die Minimap-Verfolgung. Erkennung zur Laufzeit über die Verfolgungsliste
-- (C_Minimap bzw. Legacy-API), Zuordnung über Spell-ID, Zaubernamen aus dem Client oder Icon.
-- Namen und Icons kommen immer aus dem Client (SpellName/SpellIcon bzw. Verfolgungsliste).
--   spell    : Spell-ID der Verfolgung
--   textures : zusätzliche bekannte Icons (File-ID oder Pfadteil), falls die Liste keine ID liefert
-- Laufzeit je Typ: index (Platz in der Verfolgungsliste), name, tex (aus der Liste)
---------------------------------------------------------------------------
Tracking.TYPES = {
    minerals = { spell = 2580, textures = { 136025, "spell_nature_earthquake" } },   -- Mineraliensuche
    herbs    = { spell = 2383 },                                                     -- Kräutersuche
    fish     = { spell = 43308 },                                                    -- Fischsuche
}
Tracking.ORDER = { "minerals", "herbs", "fish" }   -- Reihenfolge im Umschalt-Knopf
Tracking.AUTO  = { "minerals", "herbs" }           -- automatische Wahl (Fische nur ausdrücklich)

function Tracking.NumTypesFn()
    return (C_Minimap and C_Minimap.GetNumTrackingTypes) or GetNumTrackingTypes
end

function Tracking.InfoFn()
    return (C_Minimap and C_Minimap.GetTrackingInfo) or GetTrackingInfo
end

function Tracking.SetFn()
    return (C_Minimap and C_Minimap.SetTracking) or SetTracking
end

-- Passt ein Eintrag der Verfolgungsliste (name, tex, spellID) zum Typ t?
function Tracking.Matches(t, name, tex, spellID)
    if spellID ~= nil and spellID == t.spell then return true end
    local sname = SpellName(t.spell)
    if sname and type(name) == "string" and (name == sname or NormName(name) == NormName(sname)) then
        return true
    end
    if tex == nil then return false end
    local lowerTex = type(tex) == "string" and tex:lower() or nil
    for _, x in ipairs(t.textures or {}) do
        if tex == x or (lowerTex and type(x) == "string" and lowerTex:find(x, 1, true)) then return true end
    end
    local own = SpellIcon(t.spell)
    return own ~= nil and tex == own
end

-- Liefert name, tex, active (boolean), spellID; nil bei Fehler oder Secret-Wert
function Tracking.ReadInfo(i)
    local fn = Tracking.InfoFn()
    if not fn then return nil end
    local ok, a, b, c, _, _, f = pcall(fn, i)
    if not ok or a == nil or IsSecret(a) then return nil end
    if type(a) == "table" then
        local name = a.name
        local tex = a.texture or a.textureFileID or a.icon
        local active = a.active
        local spellID = a.spellID or a.spellId
        if IsSecret(name) or IsSecret(active) or IsSecret(spellID) then return nil end
        return name, (not IsSecret(tex)) and tex or nil, active and true or false, spellID
    end
    if IsSecret(c) or IsSecret(f) then return nil end
    return a, (not IsSecret(b)) and b or nil, c and true or false, f
end

-- Typ key in der Verfolgungsliste suchen; liefert idx, active, unavailable
-- (unavailable = Liste nicht lesbar). Merkt index/name/tex am Typ.
function Tracking.Find(key)
    local t = Tracking.TYPES[key]
    if not t then return nil, nil, false end
    local numFn = Tracking.NumTypesFn()
    if not (numFn and Tracking.InfoFn()) then return nil, nil, false end
    local okN, num = pcall(numFn)
    if not okN or type(num) ~= "number" or IsSecret(num) or num <= 0 then return nil, nil, true end
    local hadSecret = false
    for i = 1, num do
        local name, tex, active, spellID = Tracking.ReadInfo(i)
        if active == nil then
            hadSecret = true
        elseif Tracking.Matches(t, name, tex, spellID) then
            t.index = i
            if type(name) == "string" then t.name = name end
            if tex then t.tex = tex end
            return i, active, false
        end
    end
    if not hadSecret then t.index = nil end
    return nil, nil, hadSecret
end

local function EntryLabel(e)
    if e.demoLabel then return e.demoLabel end   -- Demo-Modus: Name aus dem Client (Demo.Entry)
    if e.kind == "reagent" then return ItemName(e.item) end
    if e.kind == "tracking" then return Tracking.Label(e.trackType) end
    if e.kind == "elixir" then return ItemName(e.item) end
    if e.label then   -- Variantengruppen: Grundwort + bekannte Varianten (Variant.GroupLabel)
        return e.variantClass and Variant.GroupLabel(e.variantClass, e.key, e.label) or L[e.label]
    end
    local first = (e.ids or e.knownIds or {})[1]
    return (first and SpellName(first)) or e.key
end

local function EntryIcon(e)
    if e.demoIcon then return e.demoIcon end     -- Demo-Modus
    if e.kind == "reagent" then return ItemIcon(e.item) or FALLBACK_ICON end
    if e.kind == "tracking" then
        local t = Tracking.TYPES[e.trackType or ""]
        return (t and (SpellIcon(t.spell) or t.tex)) or FALLBACK_ICON
    end
    if e.kind == "conjure" then
        return ItemIcon(Conjure.RankItem(e)) or SpellIcon(e.knownIds[1]) or FALLBACK_ICON
    end
    if e.kind == "elixir" then return ItemIcon(e.item) or FALLBACK_ICON end
    if e.weaponItems then
        -- Icon der aktuell besten Wahl aus den Taschen
        local c = Items.KindOf(e) and Items.ItemChoices(e)[1]
        return (c and ItemIcon(c.id)) or e.icon
    end
    if e.general then
        -- a) zuletzt im Spiel gesehenes Aura-Icon, b) Spell-Textur der ersten ID,
        -- c) fest eingetragenes Icon, d) Fallback
        local cached = db and db.iconCache and db.iconCache[e.key]
        if cached then return cached end
        local id = (e.ids or {})[1]
        local tex = id and SpellIcon(id)
        if tex then return tex end
        if type(e.icon) == "string" then return e.icon end
        return FALLBACK_ICON
    end
    if type(e.icon) == "string" then return e.icon end
    local id = e.icon or (e.ids or e.knownIds or {})[1]
    return (id and SpellIcon(id)) or FALLBACK_ICON
end

-- Lookup-Tabellen pro Eintrag aufbauen (nach Login, wenn Spell-Daten da sind)
local function PrepareEntry(e)
    e.idSet = {}
    for _, id in ipairs(e.ids or {}) do e.idSet[id] = true end
    e.names = {}
    local src = e.nameIds or { (e.ids or e.knownIds or {})[1] }
    for _, id in ipairs(src) do
        local n = SpellName(id)
        if n then e.names[#e.names + 1] = n end
    end
    e.normNames = {}
    for _, n in ipairs(e.matchNames or {}) do
        e.names[#e.names + 1] = n
        e.normNames[NormName(n)] = true
    end
    if e.excludeIds then
        e.excludeSet = {}
        for _, id in ipairs(e.excludeIds) do e.excludeSet[id] = true end
    end
end

---------------------------------------------------------------------------
-- Erlernt?
---------------------------------------------------------------------------
local function SpellKnown(id)
    if IsPlayerSpell then
        local ok, r = pcall(IsPlayerSpell, id)
        if ok and r then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and r then return true end
    end
    if IsSpellKnown then
        local ok, r = pcall(IsSpellKnown, id)
        if ok and r then return true end
    end
    return false
end

-- Name einer Verfolgung aus dem Client (Zaubername, sonst Name aus der Verfolgungsliste)
function Tracking.Label(key)
    local t = Tracking.TYPES[key or ""]
    if not t then return L.TRACK_NONE end
    return SpellName(t.spell) or t.name or key
end

-- Verfolgung gelernt? (Zauber bekannt oder in der Verfolgungsliste vorhanden)
function Tracking.Learned(key)
    local t = Tracking.TYPES[key]
    if not t then return false end
    if SpellKnown(t.spell) then return true end
    return (Tracking.Find(key)) ~= nil
end

-- Gewünschte Verfolgung (pro Charakter, cdb.trackWanted): "none" = keine, gesetzt = diese,
-- nil = automatisch die erste gelernte aus Tracking.AUTO (Mineralien, dann Kräuter)
function Tracking.Wanted()
    local w = cdb and cdb.trackWanted
    if w == "none" then return nil end
    if w and Tracking.TYPES[w] then return w end
    for _, k in ipairs(Tracking.AUTO) do
        if Tracking.Learned(k) then return k end
    end
    return nil
end

-- Eintrag auf die gewünschte Verfolgung einstellen (ids/Namen für die Aura-Fallbacks)
function Tracking.Apply(e)
    local key = Tracking.Wanted()
    if e.trackType == key and e.idSet then return end
    e.trackType = key
    local t = Tracking.TYPES[key or ""]
    e.ids = t and { t.spell } or {}
    PrepareEntry(e)
end

-- true = gewünschte Verfolgung gelernt, aber nicht aktiv; false = aktiv / keine gewünscht;
-- nil = nicht lesbar
function Tracking.Missing(e, scan)
    local key = e.trackType
    local t = Tracking.TYPES[key or ""]
    if not t then return false end
    local idx, active, unavailable = Tracking.Find(key)
    if idx then return not active end
    if unavailable then return nil end
    -- ohne Verfolgungsliste: Aura bzw. aktuelle Verfolgungs-Textur (Legacy-Clients)
    if scan then
        if scan.ids[t.spell] then return false end
        for _, n in ipairs(e.names) do
            if scan.names[n] then return false end
        end
    end
    if GetTrackingTexture then
        local ok, curTex = pcall(GetTrackingTexture)
        if ok and curTex and not IsSecret(curTex) and Tracking.Matches(t, nil, curTex, nil) then return false end
    end
    if scan and scan.unreliable then return nil end
    return SpellKnown(t.spell)
end

-- Auswahl im Einstellungs-Knopf: gelernte Verfolgungen + "none"
function Tracking.Choices()
    local list = {}
    for _, k in ipairs(Tracking.ORDER) do
        if Tracking.Learned(k) then list[#list + 1] = k end
    end
    list[#list + 1] = "none"
    return list
end

function Tracking.Cycle()
    local list, cur = Tracking.Choices(), Tracking.Wanted() or "none"
    local idx = 0
    for i, k in ipairs(list) do
        if k == cur then idx = i end
    end
    cdb.trackWanted = list[idx % #list + 1]
end

function Tracking.ButtonText()
    local key = Tracking.Wanted()
    local name = Tracking.Label(key)
    if key and cdb.trackWanted == nil then name = L.TRACK_AUTO:format(name) end
    return L.TRACK:format(name)
end

-- Linksklick bzw. Taste auf einer Verfolgungs-Zeile: Verfolgung einschalten (nur außerhalb des
-- Kampfes; der Button hat dafür keine secure Aktion). true = Klick behandelt.
function Tracking.Activate(btn)
    local a = btn.action
    if not (a and a.trackIndex) then return false end
    if InCombatLockdown() then Print(L.COMBAT); return true end
    local setFn = Tracking.SetFn()
    if setFn then
        pcall(setFn, a.trackIndex, true)
        Evaluate()
    end
    return true
end

local function ComputeKnown(e)
    if e.kind == "tracking" then
        -- gewünschte Verfolgung neu bestimmen; "erlernt" = gewünschte Verfolgung gelernt
        Tracking.Apply(e)
        return e.trackType ~= nil and Tracking.Learned(e.trackType)
    end
    if e.general then return true end
    local lvl = UnitLevel("player") or 1
    if e.levelOnly then return lvl >= (e.level or 1) end
    for _, id in ipairs(e.knownIds or e.ids or {}) do
        if SpellKnown(id) then return true end
    end
    -- Fallback über Namen (falls Forever andere Spell-IDs nutzt)
    if not e.talent and lvl >= (e.level or 1) and C_Spell and C_Spell.GetSpellInfo then
        for _, n in ipairs(e.names or {}) do
            local ok, info = pcall(C_Spell.GetSpellInfo, n)
            if ok and info and not IsSecret(info) then return true end
        end
    end
    return false
end

local RelevantReagents -- forward (braucht KnownByName)

local function RefreshKnown()
    local items = RelevantReagents()
    for _, e in ipairs(entries) do
        if e.kind == "reagent" then
            knownCache[e.key] = items[e.item] == true
        else
            knownCache[e.key] = ComputeKnown(e)
        end
    end
end

local function IsEnabled(e)
    -- Reagenzien: nur mit aktivem Experimental-Schalter (sonst keine Zeile, keine Mengenprüfung)
    if e.kind == "reagent" then return ExpOn("expReagents") and ReagentThreshold(e.item) > 0 end
    -- Klassen-Verbrauchsgüter: nur mit aktivem Experimental-Schalter
    if e.kind == "conjure" and not ExpOn("expConsumables") then return false end
    -- Verfolgungs-Erinnerung: nur mit Experimental-Schalter und gewünschter Verfolgung
    if e.kind == "tracking" then return ExpOn("expTracking") and e.trackType ~= nil end
    -- Wunsch-Elixiere: nur mit Experimental-Schalter und Haken in der Liste (pro Charakter)
    if e.kind == "elixir" then return ExpOn("expElixirs") and cdb.elixirsWanted[e.item] == true end
    -- Waffen-Items: nur mit Experimental-Schalter; Schurke: nur, wenn der Gift-Eintrag aus ist
    if e.weaponItems then
        if not ExpOn("expWeaponItems") then return false end
        if e.poisonEntry and IsEnabled(e.poisonEntry) then return false end
    end
    local v = cdb.buffs[e.key]
    if v == nil then return not e.defaultOff end
    return v
end

local function MuteRemaining(key)
    local t = muted[key]
    if not t then return nil end
    if t == math.huge then return t end
    local left = t - GetTime()
    if left <= 0 then muted[key] = nil; return nil end
    return left
end

---------------------------------------------------------------------------
-- Klick-Zaubern: Zauber bestimmen, zuletzt genutzte Variante merken
---------------------------------------------------------------------------
local function IsWeaponEntry(e) return e.kind == "weapon_mh" or e.kind == "weapon_oh" end

local function KnownByName(n)
    if not n then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, n)
        if ok and info and not IsSecret(info) then return true end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, n)
        if ok and name and not IsSecret(name) then return true end
    end
    return false
end

-- Reagenzien, die der jeweils höchste erlernte Rang einer Zauberlinie verbraucht
function RelevantReagents()
    local items = {}
    local lvl = UnitLevel("player") or 1
    for _, ranks in ipairs(reagentLines) do
        local rank
        for i = #ranks, 1, -1 do
            if SpellKnown(ranks[i][1]) then rank = ranks[i]; break end
        end
        if not rank and KnownByName(SpellName(ranks[1][1])) then
            -- Namens-Fallback: höchster Rang, dessen Lernstufe erreicht ist
            rank = ranks[1]
            for i = #ranks, 1, -1 do
                if lvl >= ranks[i][2] then rank = ranks[i]; break end
            end
        end
        if rank and rank[3] then items[rank[3]] = true end
    end
    return items
end

-- höchster erlernter Rang; Fallback: Zaubername, falls per Name bekannt
local function BestCast(castIds)
    for i = #castIds, 1, -1 do
        if SpellKnown(castIds[i]) then return castIds[i] end
    end
    local n = SpellName(castIds[1])
    if KnownByName(n) then return n end
    return nil
end

-- castIds/variants aus CAST_DATA übernehmen, Lookup-Tabellen der Varianten bauen
local function PrepareCast(e, class)
    local c = CAST_DATA[class] and CAST_DATA[class][e.key]
    if not c then return end
    e.castIds, e.variants = c.castIds, c.variants
    if c.variants then e.variantClass = class end   -- Beschriftung per Variant.GroupLabel
    e.variantMenu = c.menu == true   -- Variantenmenü per Rechtsklick (nicht für die Segen)
    for _, v in ipairs(e.variants or {}) do
        if not v.matchSet then            -- Imbue-Varianten sind zwischen MH/OH geteilt
            v.matchSet, v.nameSet = {}, {}
            for _, list in ipairs({ v.castIds, v.ids or {} }) do
                for _, id in ipairs(list) do
                    v.matchSet[id] = true
                    local n = SpellName(id)
                    if n then v.nameSet[n] = true end
                end
            end
        end
    end
end

local function VariantByKey(e, key)
    if not key then return nil end
    for _, v in ipairs(e.variants) do
        if v.key == key then return v end
    end
end

-- Spell (ID oder Name) für Linksklick, nil = nicht zauberbar
local function CastSpellFor(e)
    if not db.clickCast then return nil end
    if e.castIds then return BestCast(e.castIds) end
    if e.variants then
        local v = VariantByKey(e, cdb.lastVariant[e.key])
        if v then return BestCast(v.castIds) end
    end
    return nil
end

-- Beschriftung einer Variantengruppe: Grundwort aus L + " (" + Kurznamen der Varianten, die der
-- Client kennt (Zaubername von castIds[1] vorhanden), getrennt mit "/" + ")". Ohne bekannte
-- Variante nur das Grundwort (dann kein Cache: Spell-Daten evtl. noch nicht da).
-- Kurznamen: L["VARIANT_<KLASSE>_<GRUPPE>_<VARIANTE>"], Gruppe = Eintrag-Key ohne _mh/_oh
-- (z. B. VARIANT_MAGE_ARMOR_FROST, VARIANT_SHAMAN_IMBUE_WINDFURY).
Variant.labels = {}   -- "<KLASSE>_<GRUPPE>:<Grundwort-Key>" -> Text (Sprache steht ab ADDON_LOADED fest)
function Variant.GroupLabel(class, key, base)
    local group = key:gsub("_[mo]h$", "")
    local prefix = class .. "_" .. group:upper()
    local cacheKey = prefix .. ":" .. base
    if Variant.labels[cacheKey] then return Variant.labels[cacheKey] end
    local c = CAST_DATA[class] and CAST_DATA[class][key]
    local names = {}
    for _, v in ipairs(c and c.variants or {}) do
        if v.castIds and v.castIds[1] and SpellName(v.castIds[1]) ~= nil then
            names[#names + 1] = L["VARIANT_" .. prefix .. "_" .. v.key:upper()]
        end
    end
    if #names == 0 then return L[base] end
    local text = L[base] .. " (" .. table.concat(names, "/") .. ")"
    Variant.labels[cacheKey] = text
    return text
end

-- Beschriftungen der Variantengruppen einmal berechnen (PLAYER_LOGIN, nach PrepareCast)
function Variant.PrepareLabels(list)
    for _, e in ipairs(list) do
        if e.variantClass and e.label then Variant.GroupLabel(e.variantClass, e.key, e.label) end
    end
end

-- Variantenmenü (experimentell, Schalter expVariantMenu): nur für markierte Variantengruppen
-- (CAST_DATA menu = true), mit "Linksklick zaubert Buff" und nicht für Gruppen-Zeilen
function Variant.MenuOn(e)
    return e ~= nil and e.variantMenu == true and not e.groupActive and db.clickCast
        and ExpOn("expVariantMenu") and true or false
end

-- erlernte Varianten in der Reihenfolge von CAST_DATA, je mit dem höchsten erlernten Rang:
-- { { spell = ID/Name, vkey, name, icon, last = zuletzt genutzt }, ... }
function Variant.Choices(e)
    local list, last = {}, cdb.lastVariant[e.key]
    for _, v in ipairs(e.variants or {}) do
        local spell = BestCast(v.castIds)
        if spell then
            local name = (type(spell) == "string" and spell) or SpellName(spell) or SpellName(v.castIds[1]) or v.key
            list[#list + 1] = { spell = spell, vkey = v.key, name = name, last = v.key == last,
                icon = SpellIcon(spell) or SpellIcon(v.castIds[1]) or FALLBACK_ICON }
        end
    end
    return list
end

-- Quelle 1: eigener erfolgreicher Zauber (UNIT_SPELLCAST_SUCCEEDED)
local function RememberFromCast(spellID)
    if spellID == nil or IsSecret(spellID) then return end
    local name = SpellName(spellID)
    for _, e in ipairs(entries) do
        if e.variants then
            for _, v in ipairs(e.variants) do
                if v.matchSet[spellID] or (name and v.nameSet[name]) then
                    -- Waffenverzauberung: der Zauber verrät die Hand nicht. Übernehmen für
                    -- die Hand, die gerade fehlt, sonst nur, solange noch nichts gemerkt ist.
                    if not IsWeaponEntry(e) or missing[e.key] or not cdb.lastVariant[e.key] then
                        cdb.lastVariant[e.key] = v.key
                    end
                    break
                end
            end
        end
    end
end

local function VariantActive(v, own)
    for id in pairs(v.matchSet) do
        if own.ids[id] then return true end
    end
    for n in pairs(v.nameSet) do
        if own.names[n] then return true end
    end
    return false
end

-- Quelle 2: eigene aktive Aura (nur selbst gewirkte, damit fremde Segen/Auren nichts überschreiben)
local function RememberFromAuras(own)
    if not own then return end
    for _, e in ipairs(entries) do
        if e.variants and not IsWeaponEntry(e) then
            local cur, found = cdb.lastVariant[e.key], nil
            for _, v in ipairs(e.variants) do
                if VariantActive(v, own) then
                    if v.key == cur then found = nil; break end   -- gemerkte Variante ist aktiv
                    found = found or v
                end
            end
            if found then cdb.lastVariant[e.key] = found.key end
        end
    end
end

---------------------------------------------------------------------------
-- Klassen-Verbrauchsgüter: Zählen, Name/Icon, Zeilentext
---------------------------------------------------------------------------
function Conjure.Threshold()
    local v = tonumber(db and db.conjureThreshold) or 20
    return math.max(0, math.min(60, math.floor(v)))
end

-- Item des höchsten erlernten Rangs (Name/Icon der Zeile); nichts erlernt -> erster Rang
function Conjure.RankItem(e)
    local c = e.conj
    for i = #c.spells, 1, -1 do
        if SpellKnown(c.spells[i]) then
            for j = i, 1, -1 do
                if c.rankItems[j] then return c.rankItems[j] end
            end
        end
    end
    return c.rankItems[1]
end

function Conjure.Name(e)
    return ItemName(Conjure.RankItem(e))
end

-- true = fehlt/zu wenig, false = genug, nil = Anzahl nicht lesbar; e.count = Summe in den Taschen
function Conjure.Missing(e)
    local n = 0
    for _, id in ipairs(e.conj.items) do
        local c = ItemCount(id)
        if c == nil then return nil end
        n = n + c
    end
    e.count = n
    if e.conj.mode == "sum" then
        local t = Conjure.Threshold()
        return t > 0 and n < t
    end
    return n == 0
end

-- "Gezaubertes Wasser: 5" bzw. "<Name> fehlt" (bei 0 bzw. "beliebiger Stein")
function Conjure.Text(e)
    if e.conj.mode == "sum" and (e.count or 0) > 0 then
        return L.CONJURE_COUNT:format(Conjure.Name(e), e.count)
    end
    return L.MISSING:format(Conjure.Name(e))
end

-- Item-Daten der angezeigten Items vorladen (Namen kommen per GET_ITEM_INFO_RECEIVED / Ticker)
function Conjure.Preload(list)
    for _, e in ipairs(list) do
        if e.kind == "conjure" then
            for _, id in pairs(e.conj.rankItems) do ItemName(id) end
        end
    end
end

---------------------------------------------------------------------------
-- Buff-Erkennung
---------------------------------------------------------------------------
-- liefert idSet, nameSet, unreliable, own, list  (nil = gar nicht lesbar); unit Standard "player"
--   own  = { ids, names } nur der selbst gewirkten Auren (für das Merken der Variante)
--   list = { { id, name, icon }, ... } aller lesbaren Auren (icon nil, falls secret)
local function ScanAuras(unit)
    unit = unit or "player"
    local ids, names, unreliable = {}, {}, false
    local own = { ids = {}, names = {} }
    local list = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok then return nil end
            if aura == nil then break end
            if IsSecret(aura) then
                unreliable = true
            else
                local id, name = aura.spellId, aura.name
                if IsSecret(id) or IsSecret(name) then
                    unreliable = true
                else
                    if id then ids[id] = true end
                    if name then names[name] = true end
                    local src = aura.sourceUnit
                    local isOwn = not IsSecret(src) and src == "player"
                    if isOwn then
                        if id then own.ids[id] = true end
                        if name then own.names[name] = true end
                    end
                    local icon = aura.icon
                    if IsSecret(icon) then icon = nil end
                    -- Laufzeit (für den Ess-Countdown); Secret-Werte -> nil
                    local dur, exp = aura.duration, aura.expirationTime
                    if IsSecret(dur) or IsSecret(exp) then dur, exp = nil, nil end
                    list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp,
                        isOwn = isOwn, secretSrc = IsSecret(src) }
                end
            end
        end
        return ids, names, unreliable, own, list
    elseif UnitBuff then
        for i = 1, 40 do
            local name, icon, _, _, dur, exp, src, _, _, id = UnitBuff(unit, i)
            if not name then break end
            names[name] = true
            if id then ids[id] = true end
            if src == "player" then
                own.names[name] = true
                if id then own.ids[id] = true end
            end
            list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp,
                isOwn = (src == "player"), secretSrc = false }
        end
        return ids, names, false, own, list
    end
    return nil
end

local function HasWeaponIn(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id then return false end
    if slot == 16 then return true end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return true end
    local ok, _, _, _, _, _, classID = pcall(fn, id)
    return ok and classID == 2   -- 2 = Waffe (kein Schild/Nebenhandgegenstand)
end

local function WeaponEnchants()
    if not GetWeaponEnchantInfo then return nil end
    local ok, mh, _, _, _, oh = pcall(GetWeaponEnchantInfo)
    if not ok or IsSecret(mh) or IsSecret(oh) then return nil end
    return mh and true or false, oh and true or false
end

-- Namenstreffer einer einzelnen Aura (exakter Name oder normalisiert);
-- Auren mit ausgeschlossener Spell-ID (excludeIds) zählen nie
local function AuraNameMatch(e, a)
    if not a.name then return false end
    if a.id and e.excludeSet and e.excludeSet[a.id] then return false end
    for _, n in ipairs(e.names) do
        if a.name == n then return true end
    end
    return next(e.normNames) ~= nil and e.normNames[NormName(a.name)] == true
end

-- passende aktive Aura eines Eintrags (für das Icon), nil = keine
local function FindAura(e, scan)
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then return a end
    end
end

-- true = fehlt, false = vorhanden / nicht relevant, nil = unbekannt
local function CheckMissing(e, scan)
    if e.kind == "reagent" then
        local n = ItemCount(e.item)
        if n == nil then return nil end
        e.count = n
        return n < ReagentThreshold(e.item)
    end
    if e.kind == "conjure" then return Conjure.Missing(e) end
    if e.kind == "tracking" then return Tracking.Missing(e, scan) end
    if e.kind == "elixir" then
        local pre = Elixir.Precheck(e)   -- nicht in den Taschen / Buff unbekannt -> keine Warnung
        if pre ~= nil then return pre end
    end
    if e.kind == "weapon_mh" or e.kind == "weapon_oh" then
        local slot = (e.kind == "weapon_mh") and 16 or 17
        if not HasWeaponIn(slot) then return false end
        local mh, oh = WeaponEnchants()
        if mh == nil then return nil end
        local active = (slot == 16) and mh or oh
        if active then return false end
        -- Waffen-Items: nur warnen, wenn ein passendes Item in den Taschen liegt
        if e.weaponItems and #Items.ItemChoices(e) == 0 then return false end
        return true
    end
    if not scan then return nil end
    for id in pairs(e.idSet) do
        if scan.ids[id] then return false end
    end
    if e.excludeSet then
        -- Name-Fallback pro Aura, damit ausgeschlossene IDs nicht per Name treffen
        for _, a in ipairs(scan.list) do
            if AuraNameMatch(e, a) then return false end
        end
    else
        for _, n in ipairs(e.names) do
            if scan.names[n] then return false end
        end
        if next(e.normNames) then
            for n in pairs(scan.names) do
                if e.normNames[NormName(n)] then return false end
            end
        end
    end
    if scan.unreliable then return nil end
    return true
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if UnitInVehicle and UnitInVehicle("player") then return true end
    return false
end

local function InGroupInstance()
    local inInst, t = IsInInstance()
    return inInst and (t == "party" or t == "raid")
end

---------------------------------------------------------------------------
-- Gruppen-Buffs: Prüfung aller Party-/Raid-Mitglieder (inkl. Spieler selbst)
-- Nur außerhalb des Kampfes. Ergebnis je Eintrag in groupState; ausgewertet wird
-- gedrosselt (höchstens alle GROUP_THROTTLE Sek.), ohne Event spätestens alle
-- GROUP_POLL Sek. (Reichweite/Sichtbarkeit ändern sich ohne Event).
---------------------------------------------------------------------------
Group.groupState = {}         -- key -> { missing = { { unit, name }, ... }, unknown = bool }
Group.groupDirty, Group.groupLastScan, Group.groupTimerPending = true, 0, false
Group.GROUP_THROTTLE, Group.GROUP_POLL = 0.5, 2

-- Ja/Nein-Abfrage einer Unit-Funktion; nil = nicht verfügbar oder Secret-Wert
function Group.UnitFlag(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or IsSecret(v) then return nil end
    return v and true or false
end

function Group.GroupModeOk()
    if db.groupMode == "instance" then return InGroupInstance() end
    if db.groupMode == "raid" then
        local inInst, t = IsInInstance()
        return inInst and t == "raid"
    end
    return true
end

-- Segen des Paladins in den Gruppenbuffs: experimentell (expBlessings, zusätzlich zu expGroup)
-- und komplett aus, solange Pally Power geladen ist (Group.pallyPower, nach PLAYER_LOGIN).
-- Der eigene Segen-Eintrag (Klassenbuff auf sich selbst) ist davon unabhängig.
function Group.BlessingsOn()
    return ExpOn("expBlessings") and not Group.pallyPower
end

function Group.SupportsGroup(e)
    if e.groupByVariant then return Group.BlessingsOn() end
    return e.groupIds ~= nil
end

-- Ist ein Addon geladen, dessen Ordnername mit "PallyPower" beginnt? (einmal nach PLAYER_LOGIN)
function Group.DetectPallyPower()
    Group.pallyPower = false
    local api = C_AddOns or {}
    local numFn = api.GetNumAddOns or GetNumAddOns
    local infoFn = api.GetAddOnInfo or GetAddOnInfo
    local loadedFn = api.IsAddOnLoaded or IsAddOnLoaded
    if not (numFn and infoFn and loadedFn) then return end
    local ok, n = pcall(numFn)
    if not ok or type(n) ~= "number" or IsSecret(n) then return end
    for i = 1, n do
        local okI, name = pcall(infoFn, i)
        if okI and type(name) == "string" and not IsSecret(name) and name:sub(1, 10) == "PallyPower" then
            local okL, loaded = pcall(loadedFn, name)
            if okL and loaded and not IsSecret(loaded) then
                Group.pallyPower = true
                return
            end
        end
    end
end

-- Gruppen-Check für einen (erlernten, aktivierten) Eintrag aktiv?
function Group.GroupActive(e)
    return Group.SupportsGroup(e) and GroupFeatureOn() and IsInGroup ~= nil and IsInGroup() and Group.GroupModeOk()
end

function Group.GroupUnits()
    local units = {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        units[1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Prüf- und Zielbarkeit: existiert, online, lebt, sichtbar, in Reichweite.
-- Secret-Werte bei UnitInRange (z. B. WoW 12.0 / Forever) blockieren die Prüfung nicht;
-- es greift dann UnitIsVisible.
function Group.UnitUsable(unit)
    if Group.UnitFlag(UnitExists, unit) ~= true then return false end
    if UnitIsConnected and Group.UnitFlag(UnitIsConnected, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsDeadOrGhost, unit) ~= false then return false end
    if UnitIsVisible and Group.UnitFlag(UnitIsVisible, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsUnit, unit, "player") == true then return true end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if ok and not IsSecret(inRange) and not IsSecret(checked) and checked and not inRange then
            return false
        end
    end
    return true
end

function Group.UnitClassFile(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and class and not IsSecret(class) then return class end
end

function Group.UnitDisplayName(unit)
    local ok, n = pcall(UnitName, unit)
    if ok and n and not IsSecret(n) then return n end
    return "?"
end

function Group.UnitFullName(unit)
    local ok, n, r = pcall(UnitName, unit)
    if not ok or not n or IsSecret(n) then return "?" end
    if type(r) == "string" and r ~= "" and not IsSecret(r) then
        return n .. "-" .. (r:gsub("[%s%-]", ""))
    end
    return n
end

function Group.UnitKey(unit)
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and type(guid) == "string" and guid ~= "" and not IsSecret(guid) then
            return guid
        end
    end
    return Group.UnitFullName(unit)
end

function Group.OwnRealm()
    local fn = GetNormalizedRealmName or GetRealmName
    if not fn then return nil end
    local ok, r = pcall(fn)
    if ok and type(r) == "string" and r ~= "" and not IsSecret(r) then
        return (r:gsub("[%s%-]", ""))
    end
end

Group.BLESSING_ALL = { "kings", "might", "wisdom", "sanctuary" }
Group.BLESSING_BY_CLASS = {
    WARRIOR     = { "kings", "might", "sanctuary" },
    ROGUE       = { "kings", "might", "sanctuary" },
    DEATHKNIGHT = { "kings", "might", "sanctuary" },
    MAGE        = { "kings", "wisdom", "sanctuary" },
    PRIEST      = { "kings", "wisdom", "sanctuary" },
    WARLOCK     = { "kings", "wisdom", "sanctuary" },
}
Group.OUR_POWER = {
    -- Blessing of Might / Greater Blessing of Might (AP)
    [19740] = 20,  [19834] = 35,  [19835] = 55,  [19836] = 85,  [19837] = 115,
    [19838] = 155, [25291] = 185, [27140] = 220, [48931] = 305, [48932] = 550,
    [25782] = 155, [25916] = 185, [27141] = 220, [48933] = 305, [48934] = 550,
    -- Blessing of Wisdom / Greater Blessing of Wisdom (MP5)
    [19742] = 10,  [19850] = 15,  [19852] = 20,  [19853] = 25,  [19854] = 30,
    [25290] = 33,  [27142] = 41,  [48935] = 50,  [48936] = 92,
    [25894] = 30,  [25918] = 33,  [27143] = 41,  [48937] = 50,  [48938] = 92,
}
Group.CONFLICTS = {
    might = {
        spellId = 6673,   -- Battle Shout
        power = { [6673] = 15, [5242] = 35, [6192] = 55, [11549] = 85, [11550] = 130,
                  [11551] = 185, [25289] = 232, [2048] = 305, [47436] = 550 },
    },
    wisdom = {
        spellId = 5677,   -- Mana Spring
        power = { [5677] = 10, [10491] = 15, [10493] = 20, [10494] = 25, [25569] = 34,
                  [58771] = 40, [58773] = 50, [58774] = 91 },
    },
}
Group.bounced = {}   -- "<unitKey>:<variant>" -> { ids = { [id]=true }, expires = GetTime()+120 }

function Group.IsBounced(unitKey, varKey, scan)
    local k = unitKey .. ":" .. varKey
    local b = Group.bounced[k]
    if not b then return false end
    if GetTime() >= b.expires then Group.bounced[k] = nil; return false end
    for id in pairs(b.ids) do
        if not scan.ids[id] then Group.bounced[k] = nil; return false end
    end
    return true
end

function Group.FindAttUnit(att)
    if att.unit and att.unitKey and Group.UnitKey(att.unit) == att.unitKey then
        return att.unit
    end
    if not att.name then return nil end
    local units = Group.GroupUnits()
    for _, u in ipairs(units) do
        if Group.UnitFullName(u) == att.name then return u end
    end
    -- Fallback: arg2 in UNIT_SPELLCAST_SENT kann "<Name>-<OwnRealm>" sein, während UnitName
    -- bei Spielern vom eigenen Realm keinen Realm-Teil liefert
    local short, realm = att.name:match("^([^%-]+)%-(.+)$")
    local ownRealm = Group.OwnRealm()
    if short and ownRealm and realm:gsub("[%s%-]", "") == ownRealm then
        for _, u in ipairs(units) do
            if Group.UnitFullName(u) == short then return u end
        end
    end
    return nil
end

function Group.RecordBounce(att)
    if not att or not att.variant then return end
    local u = Group.FindAttUnit(att)
    if not u then return end
    local ukey = Group.UnitKey(u)
    local ids = {}
    local _, _, _, _, auras = ScanAuras(u)
    for _, a in ipairs(auras or {}) do
        if a.id and not a.isOwn then ids[a.id] = true end
    end
    Group.bounced[ukey .. ":" .. att.variant] = { ids = ids, expires = GetTime() + 120 }
end

function Group.VariantBlocked(v, scan, unitKey)
    if VariantActive(v, scan) then return true end
    if unitKey and Group.IsBounced(unitKey, v.key, scan) then return true end
    local c = Group.CONFLICTS[v.key]
    if c then
        local ourSpell = BestCast(v.castIds)
        local ourPower = (type(ourSpell) == "number" and Group.OUR_POWER[ourSpell]) or 0
        local cname = SpellName(c.spellId)
        for _, a in ipairs(scan.list) do
            local p = a.id and c.power[a.id]
            if p ~= nil then
                if p >= ourPower then return true end
            elseif cname and a.name == cname then
                return true
            end
        end
    end
    return false
end

-- Passende Variante für das Ziel wählen: bevorzugte (lastVariant), falls noch nicht aktiv,
-- nicht durch stärkeren Buff blockiert und für die Klasse sinnvoll, sonst erste freie Variante.
function Group.PickVariant(e, class, scan, unitKey)
    local order = Group.BLESSING_BY_CLASS[class or ""] or Group.BLESSING_ALL
    local allowed = {}
    for _, k in ipairs(order) do allowed[k] = true end
    local function usable(k)
        local v = VariantByKey(e, k)
        return v and BestCast(v.castIds) ~= nil and not Group.VariantBlocked(v, scan, unitKey) and v or nil
    end
    local last = cdb and cdb.lastVariant and cdb.lastVariant[e.key]
    if last and allowed[last] then
        local v = usable(last)
        if v then return v end
    end
    for _, k in ipairs(order) do
        local v = usable(k)
        if v then return v end
    end
    return nil
end

-- Eigene Aura auf unit prüfen (ownOnly); liefert missing (true/false/nil) + gewählte Variante
function Group.CheckOwnEntry(e, class, scan, unitKey)
    if not scan then return nil end
    local secretHit = false
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then
            if a.isOwn then return false end
            if a.secretSrc then secretHit = true end
        end
    end
    if secretHit or scan.unreliable then return nil end
    if e.groupByVariant and e.variants then
        local v = Group.PickVariant(e, class, scan, unitKey)
        if not v then return false end
        return true, v
    end
    return true
end

function Group.ScanGroup()
    wipe(Group.groupState)
    local list = {}
    for _, e in ipairs(entries) do
        if Group.SupportsGroup(e) and knownCache[e.key] and IsEnabled(e) then
            list[#list + 1] = e
            Group.groupState[e.key] = { missing = {}, unknown = false }
        end
    end
    if #list == 0 then return end
    local shortCounts, scanned = {}, {}
    for _, unit in ipairs(Group.GroupUnits()) do
        if Group.UnitUsable(unit) then
            local ids, names, unreliable, _, auras = ScanAuras(unit)
            local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auras } or nil
            local short = Group.UnitDisplayName(unit)
            shortCounts[short] = (shortCounts[short] or 0) + 1
            scanned[#scanned + 1] = {
                unit = unit, scan = scan, class = Group.UnitClassFile(unit),
                short = short, full = Group.UnitFullName(unit), ukey = Group.UnitKey(unit),
            }
        end
    end
    for _, info in ipairs(scanned) do
        local uname = (shortCounts[info.short] or 0) > 1 and info.full or info.short
        for _, e in ipairs(list) do
            if not e.manaOnly or (info.class and MANA_CLASSES[info.class]) then
                local st = Group.groupState[e.key]
                local m, variant
                if e.ownOnly then
                    m, variant = Group.CheckOwnEntry(e, info.class, info.scan, info.ukey)
                else
                    -- Gruppen- und Einzelversion stehen beide in e.idSet / e.names
                    m = CheckMissing(e, info.scan)
                end
                if m == true then
                    st.missing[#st.missing + 1] = {
                        unit = info.unit, unitKey = info.ukey, name = uname,
                        fullName = info.full, variant = variant,
                    }
                elseif m == nil then
                    st.unknown = true
                end
            end
        end
    end
end

-- Auswertung, wenn fällig (nie im Kampf)
function Group.GroupScanIfDue(now)
    if InCombatLockdown() then return end
    if (Group.groupDirty or now - Group.groupLastScan >= Group.GROUP_POLL) and now - Group.groupLastScan >= Group.GROUP_THROTTLE then
        Group.ScanGroup()
        Group.groupLastScan, Group.groupDirty = now, false
    end
end

-- Aura/Roster geändert: neu auswerten, aber höchstens alle GROUP_THROTTLE Sek.
function Group.MarkGroupDirty()
    Group.groupDirty = true
    if Group.groupTimerPending then return end
    Group.groupTimerPending = true
    C_Timer.After(Group.GROUP_THROTTLE, function()
        Group.groupTimerPending = false
        Evaluate()
    end)
end

-- true = jemandem fehlt der Buff, false = alle haben ihn, nil = unbekannt
function Group.GroupMissing(e)
    local st = Group.groupState[e.key]
    if not st then return nil end
    e.groupMissing = st.missing
    if #st.missing > 0 then return true end
    if st.unknown then return nil end
    return false
end

-- höchster erlernter Rang der Gruppenversion + dessen Reagenz; Namens-Fallback wie bei Reagenzien
function Group.GroupSpellFor(e, variant)
    local ids = e.groupIds
    if not ids and e.groupByVariant and e.variants then
        local v = variant or VariantByKey(e, cdb and cdb.lastVariant and cdb.lastVariant[e.key])
        ids = v and v.ids
    end
    if not ids or #ids == 0 then return nil end
    for i = #ids, 1, -1 do
        if SpellKnown(ids[i]) then return ids[i], RANK_INFO[ids[i]] and RANK_INFO[ids[i]].item end
    end
    local n = SpellName(ids[1])
    if KnownByName(n) then
        local lvl, best = UnitLevel("player") or 1, nil
        for i = #ids, 1, -1 do
            local info = RANK_INFO[ids[i]]
            if info and lvl >= info.level then best = info; break end
        end
        return n, best and best.item
    end
end

-- Klick-Aktion einer Gruppen-Zeile, Ziel = erster Spieler ohne Buff (Roster-Reihenfolge):
--   Linksklick      : Gruppenversion; Einzelversion, wenn nicht erlernt oder Reagenz fehlt
--   Strg+Linksklick : Einzelversion
function Group.GroupActionFor(e)
    local target = e.groupMissing and e.groupMissing[1]
    if not target or not db.clickCast then return nil end
    local single = (target.variant and BestCast(target.variant.castIds)) or CastSpellFor(e)
    if not single then return nil end
    local a = {
        unit = target.unit, unitKey = target.unitKey, targetName = target.name,
        targetFullName = target.fullName, ctrlSpell = single, ctrlUnit = target.unit,
    }
    local gspell, item = Group.GroupSpellFor(e, target.variant)
    if gspell and (not item or (ItemCount(item) or 1) > 0) then
        a.spell, a.isGroup = gspell, true
    else
        a.spell = single
    end
    a.spellName = SpellName(a.spell)
    a.variantKey = target.variant and target.variant.key
    return a
end

-- Namen der Spieler ohne Buff: max. 5, dann "+N"
function Group.MissingNames(e)
    local list, out = e.groupMissing or {}, {}
    for i = 1, math.min(5, #list) do out[i] = list[i].name end
    local s = table.concat(out, ", ")
    if #list > 5 then s = s .. " +" .. (#list - 5) end
    return s
end

function Group.PrintDebug(log)
    local function out(msg)
        Print(msg)
        if log then log[#log + 1] = msg end
    end
    local units = Group.GroupUnits()
    out(("group: feature=%s expGroup=%s blessings=%s pallyPower=%s check=%s mode=%s modeOk=%s inGroup=%s members=%d"):format(
        tostring(GroupFeatureOn()), tostring(ExpOn("expGroup")), tostring(ExpOn("expBlessings")),
        tostring(Group.pallyPower), tostring(db and db.groupCheck),
        tostring(db and db.groupMode), tostring(Group.GroupModeOk()),
        tostring(IsInGroup and IsInGroup()), GetNumGroupMembers and GetNumGroupMembers() or 0))
    for _, u in ipairs(units) do
        local ex = Group.UnitFlag(UnitExists, u)
        local co = UnitIsConnected and Group.UnitFlag(UnitIsConnected, u)
        local de = Group.UnitFlag(UnitIsDeadOrGhost, u)
        local vi = UnitIsVisible and Group.UnitFlag(UnitIsVisible, u)
        local irStr = "nil"
        if UnitInRange then
            local ok, ir, ch = pcall(UnitInRange, u)
            irStr = ok and (("%s/%s"):format(IsSecret(ir) and "secret" or tostring(ir),
                IsSecret(ch) and "secret" or tostring(ch))) or "err"
        end
        local ids, _, un, _, auras = ScanAuras(u)
        out(("  %s (%s): usable=%s ex=%s co=%s de=%s vi=%s range=%s scan=%s un=%s auras=%d"):format(
            u, Group.UnitFullName(u), tostring(Group.UnitUsable(u)),
            tostring(ex), tostring(co), tostring(de), tostring(vi), irStr,
            ids and "ok" or "nil", tostring(un), auras and #auras or 0))
        if log and auras and #auras > 0 then
            local list = {}
            for _, a in ipairs(auras) do
                list[#list + 1] = ("%s(%s%s)"):format(tostring(a.name), tostring(a.id),
                    a.isOwn and ",own" or (a.secretSrc and ",sec" or ""))
            end
            log[#log + 1] = "    auras: " .. table.concat(list, ", ")
        end
    end
    for _, e in ipairs(entries) do
        if Group.SupportsGroup(e) then
            local st = Group.groupState[e.key]
            out(("  entry %s: active=%s missing=%d unknown=%s lastVar=%s"):format(
                e.key, tostring(Group.GroupActive(e)),
                st and #st.missing or -1, tostring(st and st.unknown),
                tostring(cdb and cdb.lastVariant and cdb.lastVariant[e.key])))
        end
    end
end

---------------------------------------------------------------------------
-- Warnung vor Ablauf (experimentell, Schalter expExpiry)
-- Für aktive eigene Buffs der aktivierten Einträge: Klassenbuffs, Well Fed, Fläschchen und
-- temporäre Waffenverzauberungen. Gewarnt wird, wenn Restdauer <= expiryPct % der Gesamtdauer.
-- Dauer/Ablaufzeit aus den Aura-Daten; secret, fehlend oder Dauer 0 -> keine Ablaufwarnung.
-- Waffen: GetWeaponEnchantInfo liefert nur die Restzeit; Gesamtdauer = höchste seit dem
-- Erscheinen der Verzauberung gesehene Restzeit pro Slot.
---------------------------------------------------------------------------
Expiry.weapon = {}   -- Slot (16/17) -> { max = Sek., left = Sek. | nil, id = Enchant-ID | nil }

function Expiry.Pct()
    local v = tonumber(db and db.expiryPct) or 10
    return math.max(5, math.min(50, v))
end

function Expiry.Alpha()
    local v = tonumber(db and db.expiryAlpha) or 0.5
    return math.max(0.2, math.min(1, v))
end

-- Welche Einträge können eine Ablauf-Zeile bekommen? (nicht: Reagenzien, Well-Rested)
function Expiry.Eligible(e)
    if e.kind == "reagent" or e.kind == "conjure" or e.kind == "tracking" then return false end
    if e.general then
        return e.itemKind == "food" or e.itemKind == "flask" or e.itemKind == "elixir" or e.itemKind == "scroll"
            or e.weaponItems == true
    end
    return true
end

-- Restzeit eines Slots aktualisieren; Secret-Werte -> unbekannt (keine Warnung)
function Expiry.UpdateSlot(slot, has, ms, id)
    local w = Expiry.weapon[slot]
    if IsSecret(has) or IsSecret(ms) then
        if w then w.left = nil end
        return
    end
    if not has or type(ms) ~= "number" then Expiry.weapon[slot] = nil; return end
    if IsSecret(id) or type(id) ~= "number" then id = nil end
    local left = ms / 1000
    -- neue Verzauberung (andere ID) oder Restzeit gestiegen (neu aufgetragen): neues Maximum
    if not w or (id and w.id and id ~= w.id) or left > w.max then
        w = { max = left, id = id }
        Expiry.weapon[slot] = w
    end
    w.left = left
end

function Expiry.UpdateWeapons()
    if not GetWeaponEnchantInfo then wipe(Expiry.weapon); return end
    local ok, hasMH, mhMs, _, mhId, hasOH, ohMs, _, ohId = pcall(GetWeaponEnchantInfo)
    if not ok then wipe(Expiry.weapon); return end
    Expiry.UpdateSlot(16, hasMH, mhMs, mhId)
    Expiry.UpdateSlot(17, hasOH, ohMs, ohId)
end

-- Restzeit in Sek., wenn der Eintrag bald abläuft; sonst nil
function Expiry.Left(e, scan)
    local frac = Expiry.Pct() / 100
    if IsWeaponEntry(e) then
        local w = Expiry.weapon[e.kind == "weapon_mh" and 16 or 17]
        if not w or not w.left or w.max <= 0 then return nil end
        if w.left > 0 and w.left <= w.max * frac then return w.left end
        return nil
    end
    if not scan then return nil end
    local now, best = GetTime(), nil
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then
            local dur, exp = a.duration, a.expirationTime
            -- ScanAuras setzt Secret-Laufzeiten auf nil
            if type(dur) ~= "number" or type(exp) ~= "number" or dur <= 0 or exp <= 0 then return nil end
            local left = exp - now
            if left > dur * frac then return nil end   -- eine passende Aura hält noch
            if left > 0 and (not best or left > best) then best = left end
        end
    end
    return best
end

function Expiry.FormatLeft(sec)
    sec = math.max(0, math.ceil(sec))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function Expiry.Text(e)
    return L.EXPIRES:format(EntryLabel(e), Expiry.FormatLeft((e.expiryEnd or 0) - GetTime()))
end

---------------------------------------------------------------------------
-- Wunsch-Elixiere pro Charakter (experimentell, Schalter expElixirs)
-- Ob WoW Forever Elixiere nach den Original-Regeln stapelt (verschiedene Werte, mit Fläschchen)
-- oder nach der TBC-Regel (1 Kampf- + 1 Wächterelixier, nicht mit Fläschchen), ist unbestätigt.
-- Deshalb keine festen Plätze: Jedes Elixier, das schon einmal in den Taschen war, steht in der
-- Merkliste (cdb.elixirsSeen); gewünschte (cdb.elixirsWanted[itemID] = true) bekommen eine eigene
-- Warnung, wenn ihr Buff fehlt und das Elixier in den Taschen liegt. Unabhängig vom Fläschchen.
--   Erkennung: Item-Klasse Verbrauchsgut + Unterklasse Elixier (GetItemInfoInstant); Fläschchen
--   bleiben beim Fläschchen-Eintrag.
--   Buff: Zauber des Items (C_Item.GetItemSpell) per Spell-ID, sonst per Name; gelernte
--   Zuordnung in db.elixirSpells[itemID] = spellID (wie flaskSpells).
--   Eintrag: { key = "elixir_<id>", kind = "elixir", itemKind = "elixir", item = id, general = true }
---------------------------------------------------------------------------
Elixir.entries = {}   -- Item-ID -> Eintrag
Elixir.ready = false  -- Einträge erst nach PLAYER_LOGIN anlegen

-- Item-Klasse/Unterklasse eines Items; nil = nicht lesbar
function Items.ClassOf(item)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    if not ok or IsSecret(classID) or IsSecret(subClassID) then return nil end
    return classID, subClassID
end

-- Verbrauchsgut der Unterklasse subKey (Enum.ItemConsumableSubclass, sonst Rückfallwert)?
function Items.IsConsumableSub(item, subKey, fallback)
    local classID, subID = Items.ClassOf(item)
    if classID == nil then return false end
    local consumable = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local sub = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass[subKey]
    if sub == nil then sub = fallback end
    return classID == consumable and subID == sub
end

-- Zauber eines Items (Spell-ID, Name); nil = (noch) nicht ermittelbar -> Laden anstoßen
function Items.ItemSpell(item)
    if not (C_Item and C_Item.GetItemSpell) then return nil end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, item)
    if ok and type(spellID) == "number" and not IsSecret(spellID) then
        if IsSecret(name) or type(name) ~= "string" then name = nil end
        return spellID, name
    end
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
    return nil
end

-- Item aus den Taschen auswerten (Scan und GET_ITEM_INFO_RECEIVED): Fläschchen-, Elixier-,
-- Rollen-Zauber lernen
function Items.LearnItem(id)
    if Items.IsFlaskItem(id) then
        Items.LearnFlaskSpell(id)
    elseif Elixir.IsElixir(id) then
        Elixir.Seen(id)
    end
end

function Elixir.IsElixir(item)
    if Items.IsFlaskItem(item) then return false end
    return Items.IsConsumableSub(item, "Elixir", 2)
end

-- Zauber eines Elixiers in den Eintrag übernehmen (Spell-ID + Name)
function Elixir.AddSpell(e, spellID, name)
    if not spellID then return end
    e.idSet[spellID] = true
    name = name or SpellName(spellID)
    if name then
        for _, n in ipairs(e.names) do if n == name then return end end
        e.names[#e.names + 1] = name
    end
end

-- Elixier in den Taschen gesehen: merken, Zauber lernen, Eintrag sicherstellen
function Elixir.Seen(id)
    if not cdb then return end
    cdb.elixirsSeen[id] = true
    local spellID, name = Items.ItemSpell(id)
    if spellID and db then db.elixirSpells[id] = spellID end
    local e = Elixir.Ensure(id)
    if e and spellID then Elixir.AddSpell(e, spellID, name) end
end

-- Eintrag eines Elixiers (einmal pro Item-ID); nil vor PLAYER_LOGIN
function Elixir.Ensure(id)
    if not Elixir.ready then return nil end
    local e = Elixir.entries[id]
    if e then return e end
    local spellID = db.elixirSpells[id]
    e = { key = "elixir_" .. id, general = true, kind = "elixir", itemKind = "elixir", item = id,
          ids = spellID and { spellID } or {} }
    PrepareEntry(e)
    Elixir.entries[id] = e
    entries[#entries + 1] = e
    knownCache[e.key] = true
    Elixir.dirty = true   -- Einstellungen: Liste neu aufbauen
    return e
end

-- PLAYER_LOGIN: Einträge für alle gemerkten Elixiere
function Elixir.Setup()
    Elixir.ready = true
    for id in pairs(cdb.elixirsSeen) do Elixir.Ensure(id) end
end

-- Einträge sortiert nach Name (Einstellungen)
function Elixir.List()
    local list = {}
    for _, e in pairs(Elixir.entries) do list[#list + 1] = e end
    table.sort(list, function(a, b)
        local na, nb = ItemName(a.item), ItemName(b.item)
        if na ~= nb then return na < nb end
        return a.item < b.item
    end)
    return list
end

-- true = fehlt, false = nicht relevant/vorhanden, nil = unbekannt (Rest in CheckMissing)
function Elixir.Precheck(e)
    if (Items.bagCounts[e.item] or 0) == 0 then return false end
    if next(e.idSet) == nil and #e.names == 0 then
        local spellID, name = Items.ItemSpell(e.item)
        if not spellID then return false end   -- Buff noch unbekannt: lieber nicht warnen
        db.elixirSpells[e.item] = spellID
        Elixir.AddSpell(e, spellID, name)
    end
    return nil
end


---------------------------------------------------------------------------
-- Stile (Warnanzeige + Rechtsklick-Menü)
-- Alle Farben, Größen und Abstände stehen hier; ein neuer Stil = neuer Eintrag in
-- STYLES + Name in STYLE_ORDER + Text STYLE_NAME_<KEY> in Locales/enUS.lua. Farben: { r, g, b [, a] }.
-- Texturen: nur Standard-UI-Elemente (Backdrop-Kanten, WHITE8X8, Highlight).
---------------------------------------------------------------------------
Style.WHITE = "Interface\\Buttons\\WHITE8X8"
Style.ROUND_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
Style.HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

-- Farbe des Statusstreifens links je Zeilenzustand (gemeinsam für alle Stile)
Style.STATUS_COLORS = {
    missing = { 0.9, 0.15, 0.15 },   -- Buff fehlt
    low     = { 1, 0.55, 0.1 },      -- Reagenz knapp
    eating  = { 0.35, 0.8, 0.3 },    -- isst gerade
    expiring = { 1, 0.75, 0.1 },     -- läuft bald ab (Bernstein)
    neutral = { 0.55, 0.55, 0.55 },  -- Verschiebe-Modus
}

Style.STYLE_ORDER = { "pardona", "classic", "compact" }
-- Hinweis: Farben, Rahmen und Schriften von "pardona" überschreibt Style.SyncFromLib (LP.Style);
-- die Werte hier sind der Rückfall (Style.PARDONA_FALLBACK).
Style.STYLES = {
    pardona = {
        -- Warnzeile
        row = { width = 300, height = 42, heightGroup = 56, gap = 3, pad = 6 },
        edge = Style.ROUND_EDGE, edgeSize = 12, inset = 3,          -- abgerundete Ecken
        bgTop = { 0.20, 0.09, 0.30, 0.94 }, bgBottom = { 0.08, 0.03, 0.13, 0.94 },   -- Verlauf
        border = { 0.85, 0.68, 0.25, 1 },                     -- Goldrand
        stripe = 4, status = Style.STATUS_COLORS,
        icon = 30, iconBorder = { 0.85, 0.68, 0.25, 1 },
        titleFont = "GameFontNormal", titleColor = { 1, 0.82, 0.25 },
        hintFont = "GameFontDisableSmall", hintColor = { 0.66, 0.58, 0.76 },
        namesColor = { 0.9, 0.88, 0.95 },
        hints = true,          -- Hinweiszeile in der Zeile (false: nur im Tooltip)
        rightText = false,     -- Kurztext "fehlt" rechtsbündig
        iconsOnly = false,     -- Option "Nur Icons" verfügbar
        -- Rechtsklick-Menü
        menu = {
            width = 300, pad = 10, gap = 8, headerIcon = 28, itemHeight = 30, itemTwoLines = true,
            sectionColor = { 0.85, 0.68, 0.25 }, sepColor = { 0.85, 0.68, 0.25, 0.35 },
            textColor = { 0.95, 0.93, 1 }, subColor = { 0.66, 0.58, 0.76 },
            buttonBg = { 0.28, 0.14, 0.40, 0.9 }, buttonBorder = { 0.85, 0.68, 0.25, 0.8 },
            xpBg = { 0.45, 0.25, 0.65, 1 }, starOff = 0.35,
        },
    },
    classic = {
        row = { width = 300, height = 42, heightGroup = 56, gap = 3, pad = 6 },
        edge = Style.WHITE, edgeSize = 2, inset = 2,                -- kantiger Goldrahmen
        bgTop = { 0.27, 0.21, 0.14, 0.95 }, bgBottom = { 0.17, 0.13, 0.09, 0.95 },  -- Stein/Braun
        border = { 0.78, 0.62, 0.22, 1 },
        stripe = 0, status = Style.STATUS_COLORS,
        icon = 30, iconBorder = { 0, 0, 0, 1 },
        titleFont = "GameFontNormal", titleColor = { 1, 0.82, 0 },   -- WoW-Gelb
        hintFont = "GameFontHighlightSmall", hintColor = { 0.87, 0.80, 0.64 },  -- beige
        namesColor = { 1, 1, 1 },
        hints = true, rightText = false, iconsOnly = false,
        menu = {
            width = 300, pad = 10, gap = 8, headerIcon = 28, itemHeight = 30, itemTwoLines = true,
            sectionColor = { 1, 0.82, 0 }, sepColor = { 0.78, 0.62, 0.22, 0.5 },
            textColor = { 1, 1, 1 }, subColor = { 0.87, 0.80, 0.64 },
            buttonBg = { 0.36, 0.28, 0.18, 0.95 }, buttonBorder = { 0.78, 0.62, 0.22, 1 },
            xpBg = { 0.15, 0.45, 0.15, 1 }, starOff = 0.35,
        },
    },
    compact = {
        row = { width = 220, height = 22, heightGroup = 22, gap = 2, pad = 4 },
        edge = Style.WHITE, edgeSize = 1, inset = 1,
        bgTop = { 0.06, 0.06, 0.08, 0.88 }, bgBottom = nil,   -- schmale dunkle Balken
        border = { 0, 0, 0, 0.9 },
        stripe = 3, status = Style.STATUS_COLORS,
        icon = 16, iconBorder = nil,
        titleFont = "GameFontHighlightSmall", titleColor = { 1, 1, 1 },
        hintFont = "GameFontDisableSmall", hintColor = { 0.6, 0.6, 0.6 },
        namesColor = { 0.8, 0.8, 0.8 },
        hints = false, rightText = true, iconsOnly = true,
        menu = {
            width = 250, pad = 6, gap = 5, headerIcon = 20, itemHeight = 20, itemTwoLines = false,
            sectionColor = { 0.8, 0.8, 0.8 }, sepColor = { 1, 1, 1, 0.12 },
            textColor = { 1, 1, 1 }, subColor = { 0.6, 0.6, 0.6 },
            buttonBg = { 0.14, 0.14, 0.17, 0.95 }, buttonBorder = { 0, 0, 0, 1 },
            xpBg = { 0.25, 0.45, 0.25, 1 }, starOff = 0.3,
        },
    },
}

---------------------------------------------------------------------------
-- Stil "Pardona" aus LibPardona (LP.Style, gemeinsam für alle Pardona-Addons)
-- Farben, Rahmen und Schriften kommen aus der Bibliothek; Größen, namesColor und die
-- Statusfarben bleiben eigene Werte. Style.SyncFromLib läuft bei PLAYER_LOGIN (dann ist die
-- höchste MINOR aktiv; eine spätere Kopie der Bibliothek kann LP.Style ersetzen, daher kein
-- Cache beim Laden der Datei). Fehlt ein Feld oder hat es den falschen Typ, gilt der Rückfall
-- (Style.PARDONA_FALLBACK = bisherige Werte). Rahmenlogik der Bibliothek (LP:ApplyStyle) wird
-- nicht verwendet.
--   Style.LIB_MAP: { BR-Feld, Art, LP.Style-Quelle }; menu.* = Feld in STYLES.pardona.menu
---------------------------------------------------------------------------
Style.LIB_MAP = {
    { "bgTop",             "color", "bgTop" },
    { "bgBottom",          "color", "bgBottom" },
    { "border",            "color", "border" },
    { "iconBorder",        "color", "border" },
    { "edge",              "edge",  "file" },
    { "edgeSize",          "edge",  "size" },
    { "inset",             "edge",  "inset" },
    { "titleFont",         "font",  "title" },
    { "titleColor",        "color", "title" },
    { "hintFont",          "font",  "hint" },
    { "hintColor",         "color", "hint" },
    { "menu.sectionColor", "color", "section" },
    { "menu.sepColor",     "color", "separator" },
    { "menu.textColor",    "color", "text" },
    { "menu.subColor",     "color", "hint" },
    { "menu.buttonBg",     "color", "buttonBg" },
    { "menu.buttonBorder", "color", "buttonBorder" },
    { "menu.xpBg",         "color", "accent" },
}
Style.fontObjects = {}   -- Rolle -> eigenes Font-Objekt (nur bei Schriften als Pfad/Größe/Flags)
-- Style.source: "lib" | "fallback"; Style.libVersion: LP.STYLE_VERSION beim letzten Abgleich

-- Ziel-Tabelle und Schlüssel eines BR-Felds ("menu.xpBg" -> STYLES.pardona.menu, "xpBg")
function Style.Target(st, field)
    local sub, key = field:match("^(%a+)%.(%a+)$")
    if sub then return st[sub], key end
    return st, field
end

-- Rückfall: die bisherigen Werte der gemappten Felder (einmal beim Laden der Datei)
function Style.CopyFallback()
    local st, fb = Style.STYLES.pardona, {}
    for _, m in ipairs(Style.LIB_MAP) do
        local t, key = Style.Target(st, m[1])
        fb[m[1]] = t[key]
    end
    return fb
end

function Style.Index(t, key) return t[key] end

-- t[key] geschützt lesen; Secret-Werte und Fehler gelten als fehlend
function Style.LibField(t, key)
    if type(t) ~= "table" or IsSecret(t) then return nil end
    local ok, v = pcall(Style.Index, t, key)
    if not ok or IsSecret(v) then return nil end
    return v
end

-- Farbe { r, g, b, a } oder { r = , g = , b = , a = } -> { r, g, b, a } (a fehlt = 1); nil = ungültig
function Style.LibColor(c)
    if type(c) ~= "table" or IsSecret(c) then return nil end
    local r, g, b, a = Style.LibField(c, 1), Style.LibField(c, 2), Style.LibField(c, 3), Style.LibField(c, 4)
    if r == nil then
        r, g, b, a = Style.LibField(c, "r"), Style.LibField(c, "g"), Style.LibField(c, "b"), Style.LibField(c, "a")
    end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if a == nil then a = 1 end
    if type(a) ~= "number" then return nil end
    return { r, g, b, a }
end

function Style.IsFontPath(v)
    return type(v) == "string" and (v:find("[\\/]") ~= nil or v:lower():find("%.[ot]tf$") ~= nil)
end

function Style.IsFontObject(v)
    return type(v) == "table" and not IsSecret(v) and type(Style.LibField(v, "GetFont")) == "function"
end

-- eigenes Font-Objekt für eine Schrift als Pfad/Größe/Flags (CreateFont abgesichert)
function Style.MakeFont(role, path, size, flags)
    if type(CreateFont) ~= "function" then return nil end
    local obj = Style.fontObjects[role]
    if not obj then
        local ok, o = pcall(CreateFont, "PardonasBuffReminderFont_" .. role)
        if not ok or not o then return nil end
        obj = o
        Style.fontObjects[role] = obj
    end
    local ok = pcall(obj.SetFont, obj, path, size, type(flags) == "string" and flags or "")
    return ok and obj or nil
end

-- Schrift aus LP.Style.fonts[role] in das BR-Format (Name eines Font-Objekts oder Font-Objekt):
--   "GameFontNormal" | Font-Objekt | { font = Name/Objekt[, color] } |
--   { font = Pfad, size = n, flags = s } | { Pfad, n, s }
function Style.LibFont(v, role)
    if type(v) == "string" and not Style.IsFontPath(v) then return v end
    if Style.IsFontObject(v) then return v end
    if type(v) ~= "table" or IsSecret(v) then return nil end
    local font = Style.LibField(v, "font")
    if type(font) == "string" and not Style.IsFontPath(font) then return font end
    if Style.IsFontObject(font) then return font end
    local path, size, flags = font, Style.LibField(v, "size"), Style.LibField(v, "flags")
    if not Style.IsFontPath(path) then path, size, flags = Style.LibField(v, 1), Style.LibField(v, 2), Style.LibField(v, 3) end
    if Style.IsFontPath(path) and type(size) == "number" and size > 0 then
        return Style.MakeFont(role, path, size, flags)
    end
    return nil
end

-- Wert eines Mapping-Eintrags aus LP.Style; nil = fehlt/ungültig (dann Rückfall)
function Style.LibValue(ls, m)
    local kind, src = m[2], m[3]
    if kind == "color" then return Style.LibColor(Style.LibField(Style.LibField(ls, "colors"), src)) end
    if kind == "font" then return Style.LibFont(Style.LibField(Style.LibField(ls, "fonts"), src), src) end
    local v = Style.LibField(Style.LibField(ls, "edge"), src)
    if src == "file" then return (type(v) == "string" and v ~= "") and v or nil end
    return (type(v) == "number" and v >= 0) and v or nil
end

-- Felder des Stils "Pardona" aus LP.Style übernehmen (Feld für Feld, sonst Rückfall)
function Style.SyncFromLib()
    local st, fb = Style.STYLES.pardona, Style.PARDONA_FALLBACK
    local lp = LibStub and LibStub("LibPardona-1.0", true)
    local ver = Style.LibField(lp, "STYLE_VERSION")
    local ls = type(ver) == "number" and Style.LibField(lp, "Style") or nil
    local used = false
    for _, m in ipairs(Style.LIB_MAP) do
        local v = ls and Style.LibValue(ls, m)
        local t, key = Style.Target(st, m[1])
        if v ~= nil then used = true end
        if v == nil then v = fb[m[1]] end
        t[key] = v
    end
    Style.source = used and "lib" or "fallback"
    Style.libVersion = used and ver or nil
end

Style.PARDONA_FALLBACK = Style.CopyFallback()

-- Zeile für /br debug
function Style.DebugLine()
    if Style.source == "lib" then return ("style: lib (STYLE_VERSION %s)"):format(tostring(Style.libVersion)) end
    return "style: fallback"
end

function Style.CurrentStyle()
    return Style.STYLES[db and db.style] or Style.STYLES.pardona
end

function Style.IconsOnly(st)
    return st.iconsOnly and db ~= nil and db.iconsOnly == true
end

function Style.SetColor(obj, method, c)
    if c then obj[method](obj, c[1], c[2], c[3], c[4] or 1) end
end

-- Hintergrund: Verlauf (bgBottom gesetzt) oder einfarbig
function Style.SetGradientBg(tex, top, bottom)
    if bottom and tex.SetGradient and CreateColor then
        tex:SetColorTexture(1, 1, 1, 1)
        local ok = pcall(tex.SetGradient, tex, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
        if ok then return end
    end
    tex:SetColorTexture(top[1], top[2], top[3], top[4] or 1)
    tex:SetVertexColor(1, 1, 1, 1)   -- evtl. alten Verlauf zurücksetzen
end

-- Rahmen (Backdrop-Kante) + eigener Hintergrund-Texture innerhalb der Kante
function Style.StyleFrame(f, st, bgTex)
    f:SetBackdrop({ edgeFile = st.edge, edgeSize = st.edgeSize })
    Style.SetColor(f, "SetBackdropBorderColor", st.border)
    bgTex:ClearAllPoints()
    bgTex:SetPoint("TOPLEFT", st.inset, -st.inset)
    bgTex:SetPoint("BOTTOMRIGHT", -st.inset, st.inset)
    Style.SetGradientBg(bgTex, st.bgTop, st.bgBottom)
end

-- Schriftobjekt per Name (z. B. "GameFontNormal")
function Style.SetFont(fs, name)
    fs:SetFontObject(_G[name] or name)
end

-- Rand um ein Icon (Texture hinter dem Icon, 1 px größer)
function Style.StyleIconBorder(border, icon, color)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    if color then
        border:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        border:Show()
    else
        border:Hide()
    end
end

-- Favoriten-Stern: Atlas des Spiels (Sammlungen), sonst Text "*"
Style.STAR_ATLASES = { "collections-icon-favorites", "PetJournal-FavoritesIcon" }
-- Style.starAtlas: false = keiner verfügbar, nil = noch nicht geprüft
function Style.StarAtlas()
    if Style.starAtlas ~= nil then return Style.starAtlas or nil end
    Style.starAtlas = false
    if C_Texture and C_Texture.GetAtlasInfo then
        for _, a in ipairs(Style.STAR_ATLASES) do
            local ok, info = pcall(C_Texture.GetAtlasInfo, a)
            if ok and info then Style.starAtlas = a; break end
        end
    end
    return Style.starAtlas or nil
end

-- Stern als Inline-Markup für FontStrings
function Style.StarMarkup(size)
    local a = Style.StarAtlas()
    if a then return ("|A:%s:%d:%d|a"):format(a, size, size) end
    return "*"
end

---------------------------------------------------------------------------
-- Einblendung (Liste fehlender Buffs)
---------------------------------------------------------------------------
-- Kampfsperre: Die Zeilen sind Secure Buttons. Sie und ihr Parent (anchor) werden in
-- InCombatLockdown() weder gezeigt/versteckt, verschoben, umgestaltet noch umattributiert.
-- Änderungen an der Liste werden nach dem Kampf (PLAYER_REGEN_ENABLED) angewendet.
local anchor = CreateFrame("Frame", "BuffReminderAnchor", UIParent)
anchor:SetSize(300, 42)
anchor:SetFrameStrata("HIGH")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:Hide()

-- Pulsieren pro Zeile (Ablauf-Zeilen pulsieren nicht); gestartet wird gemeinsam in ShowRows
function Display.MakePulse(r)
    local g = r:CreateAnimationGroup()
    g:SetLooping("BOUNCE")
    local fade = g:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.55)
    fade:SetDuration(0.9)
    fade:SetSmoothing("IN_OUT")
    return g
end

function Display.SavePoint()
    anchor:StopMovingOrSizing()
    local p, _, rp, x, y = anchor:GetPoint()
    db.point = { p, "UIParent", rp, x, y }
end

local layoutPending = false

local function ApplyLayout()
    if InCombatLockdown() then layoutPending = true; return end
    layoutPending = false
    anchor:ClearAllPoints()
    local p = db.point
    anchor:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    anchor:SetScale(db.scale)
end

local rows = {}
Display.styleGen = 0      -- erhöht bei jedem Stilwechsel; Zeilen mit älterem Stand werden neu gestaltet
Display.stylePending = false

-- Secure Buttons im Mainline-Client lösen je nach CVar ActionButtonUseKeyDown beim
-- Drücken ODER beim Loslassen aus. Daher werden beide Phasen registriert; die secure
-- Aktion läuft genau einmal, und unser Rechtsklick reagiert nur in derselben Phase.
function Display.GetCVarFlag(name)
    if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name) and true or false end
    if GetCVarBool then return GetCVarBool(name) and true or false end
    return false
end

function Display.HasKeyDownCVar()
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar("ActionButtonUseKeyDown") ~= nil end
    if GetCVar then return GetCVar("ActionButtonUseKeyDown") ~= nil end
    return false
end

function Display.IsActionPhase(down)
    return (down and true or false) == Display.GetCVarFlag("ActionButtonUseKeyDown")
end

-- Klick-Aktion einer Zeile setzen (nur außerhalb des Kampfes aufrufen). a = nil oder
--   { spell = ID/Name | item = Item-ID, unit = Ziel (Standard "player"),
--     ctrlSpell, ctrlUnit = Strg+Linksklick (Gruppen-Zeilen), isGroup, targetName }
-- Ohne spell/item tut Linksklick nichts.
function Display.SetRowAction(r, a)
    a = a or {}
    local sig = table.concat({ tostring(a.spell), tostring(a.item), tostring(a.macro), tostring(a.unit),
        tostring(a.ctrlSpell), tostring(a.ctrlUnit), tostring(a.trackIndex) }, "|")
    r.action = a
    r.castSpell, r.useItem = a.spell, a.item
    if r.actionSig == sig then return end
    r.actionSig = sig
    r:SetAttribute("macrotext1", nil)
    if a.spell then
        r:SetAttribute("type1", "spell")
        r:SetAttribute("spell1", a.spell)
        r:SetAttribute("item1", nil)
    elseif a.macro then
        -- Waffen-Items: "/use item:<id>" + "/use <Slot>" (Item auf die Waffe anwenden)
        r:SetAttribute("type1", "macro")
        r:SetAttribute("macrotext1", a.macro)
        r:SetAttribute("spell1", nil)
        r:SetAttribute("item1", nil)
    elseif a.item then
        r:SetAttribute("type1", "item")
        r:SetAttribute("item1", "item:" .. a.item)
        r:SetAttribute("spell1", nil)
    else
        r:SetAttribute("type1", nil)
        r:SetAttribute("spell1", nil)
        r:SetAttribute("item1", nil)
    end
    r:SetAttribute("unit1", a.unit or "player")
    r:SetAttribute("ctrl-type1", a.ctrlSpell and "spell" or nil)
    r:SetAttribute("ctrl-spell1", a.ctrlSpell)
    r:SetAttribute("ctrl-unit1", a.ctrlUnit)
end

-- Zeile im aktuellen Stil gestalten (nur außerhalb des Kampfes). Gruppen-Zeilen haben
-- in Stilen mit Hinweiszeile 3 Textzeilen (Namenszeile), sonst 2; Compact ist einzeilig.
function Display.LayoutRow(r)
    local st = Style.CurrentStyle()
    local rs = st.row
    local iconsOnly = Style.IconsOnly(st)
    local three = r.threeLines and st.hints
    local h = three and rs.heightGroup or rs.height
    r.styleGen = Display.styleGen
    r.layoutThree = r.threeLines
    if iconsOnly then r:SetSize(h + st.stripe, h) else r:SetSize(rs.width, h) end
    Style.StyleFrame(r, st, r.bg)

    r.stripe:ClearAllPoints()
    r.stripe:SetPoint("TOPLEFT", st.inset, -st.inset)
    r.stripe:SetPoint("BOTTOMLEFT", st.inset, st.inset)
    if st.stripe > 0 then r.stripe:SetWidth(st.stripe); r.stripe:Show() else r.stripe:Hide() end

    r.icon:SetSize(st.icon, st.icon)
    r.icon:ClearAllPoints()
    if iconsOnly then
        r.icon:SetPoint("CENTER", st.stripe / 2, 0)
    else
        r.icon:SetPoint("LEFT", st.inset + st.stripe + rs.pad, 0)
    end
    Style.StyleIconBorder(r.iconBorder, r.icon, st.iconBorder)

    Style.SetFont(r.text, st.titleFont)
    Style.SetColor(r.text, "SetTextColor", st.titleColor)
    Style.SetFont(r.hint, st.hintFont)
    Style.SetColor(r.hint, "SetTextColor", st.hintColor)
    Style.SetColor(r.names, "SetTextColor", st.namesColor)
    Style.SetColor(r.right, "SetTextColor", st.status.missing)
    r.text:ClearAllPoints(); r.hint:ClearAllPoints(); r.names:ClearAllPoints(); r.right:ClearAllPoints()

    if iconsOnly then
        r.text:Hide(); r.hint:Hide(); r.names:Hide(); r.right:Hide()
    elseif not st.hints then
        -- einzeilig: Titel links, Kurztext rechts; Hinweise nur im Tooltip
        r.right:SetPoint("RIGHT", -(st.inset + rs.pad), 0)
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
        r.text:Show(); r.right:Show(); r.hint:Hide(); r.names:Hide()
    else
        local top, mid, bottom = 7, 0, -8
        if three then top, mid, bottom = 14, 0, -14 end
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 10, top)
        r.text:SetPoint("RIGHT", -8, top)
        r.names:SetPoint("LEFT", r.icon, "RIGHT", 10, mid)
        r.names:SetPoint("RIGHT", -8, mid)
        r.hint:SetPoint("LEFT", r.icon, "RIGHT", 10, bottom)
        r.hint:SetPoint("RIGHT", -8, bottom)
        r.text:Show(); r.hint:Show(); r.right:Hide()
        if three then r.names:Show() else r.names:Hide() end
    end
end

-- "Nur Icons": so viele Icons je Reihe (≈ Breite einer Compact-Zeile), dann Umbruch
Display.ICONS_PER_LINE = 8

function Display.GrowUp()
    return db ~= nil and db.growUp == true
end

-- Zeile i anordnen (nur außerhalb des Kampfes). Die erste Zeile füllt den Anker aus
-- (Anker = Größe einer Zeile), daher springt die Liste beim Umschalten der Richtung nicht.
--   nach unten: Zeile 1 oben am Anker, weitere darunter
--   nach oben : Zeile 1 unten am Anker, weitere darüber
--   "Nur Icons": Raster mit ICONS_PER_LINE Icons je Reihe von links nach rechts;
--                weitere Reihen darunter bzw. darüber
function Display.PositionRow(i)
    local r = rows[i]
    local st = Style.CurrentStyle()
    local gap, up = st.row.gap, Display.GrowUp()
    r:ClearAllPoints()
    if Style.IconsOnly(st) then
        local per = Display.ICONS_PER_LINE
        local col, line = (i - 1) % per, math.floor((i - 1) / per)
        local h = st.row.height
        local x, y = col * (h + st.stripe + gap), line * (h + gap)
        if up then
            r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", x, y)
        else
            r:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
        end
    elseif i == 1 then
        local p = up and "BOTTOMLEFT" or "TOPLEFT"
        r:SetPoint(p, anchor, p, 0, 0)
    elseif up then
        r:SetPoint("BOTTOMLEFT", rows[i - 1], "TOPLEFT", 0, gap)
    else
        r:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -gap)
    end
end

function Display.SetRowLines(r, three)
    r.threeLines = three
    if r.layoutThree ~= three or r.styleGen ~= Display.styleGen then Display.LayoutRow(r) end
end

function Display.SetRowStatus(r, status)
    local c = Style.CurrentStyle().status[status] or Style.STATUS_COLORS.missing
    r.stripe:SetColorTexture(c[1], c[2], c[3], 1)
end

function Display.GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, anchor, "SecureActionButtonTemplate, BackdropTemplate")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.stripe = r:CreateTexture(nil, "BORDER")
    r.iconBorder = r:CreateTexture(nil, "ARTWORK", nil, -1)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)

    -- Hinweiszeile (klein) unter dem Haupttext
    r.hint = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.hint:SetJustifyH("LEFT")
    r.hint:SetWordWrap(false)

    -- Namenszeile der Gruppen-Zeilen (Spieler ohne Buff), zwischen Haupttext und Hinweis
    r.names = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.names:SetJustifyH("LEFT")
    r.names:SetWordWrap(false)

    -- Kurztext rechts (Compact: "fehlt")
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetJustifyH("RIGHT")

    r.threeLines = false
    r.pulse = Display.MakePulse(r)
    rows[i] = r
    Display.LayoutRow(r)
    Display.PositionRow(i)

    -- Linksklick = secure Aktion (Zauber auf sich selbst), Rechtsklick = Menü
    r:SetAttribute("unit1", "player")
    if Display.HasKeyDownCVar() then
        r:RegisterForClicks("AnyUp", "AnyDown")
    else
        r:RegisterForClicks("AnyUp")
    end
    r:RegisterForDrag("LeftButton")
    r:SetScript("PostClick", function(self, button, down)
        if not Display.IsActionPhase(down) then return end
        if button == "LeftButton" then
            -- Verfolgungs-Zeile: Verfolgung einschalten (nur außerhalb des Kampfes)
            if self.entry and self.entry.kind == "tracking" and not unlocked and Tracking.Activate(self) then
                return
            end
            -- per Linksklick benutztes Fläschchen als "zuletzt benutzt" merken
            if self.useItem and self.entry and self.entry.itemKind == "flask" then
                cdb.lastFlask = self.useItem
            end
            if self.entry and self.entry.ownOnly and self.action and self.action.variantKey then
                Group.lastAttempt = {
                    unit = self.action.unit, unitKey = self.action.unitKey,
                    name = self.action.targetFullName or self.action.targetName,
                    key = self.entry.key, variant = self.action.variantKey, t = GetTime(),
                }
            end
            return
        end
        if button == "RightButton" and self.entry and not unlocked then Display.OpenMuteMenu(self) end
    end)
    r:SetScript("OnDragStart", function()
        if unlocked and not InCombatLockdown() then anchor:StartMoving() end
    end)
    r:SetScript("OnDragStop", function()
        if unlocked and not InCombatLockdown() then Display.SavePoint() end
    end)
    r:SetScript("OnEnter", function(self)
        local st = Style.CurrentStyle()
        if not self.entry then
            -- Verschiebe-Modus: bei "Nur Icons" steht der Text nur im Tooltip
            if Style.IconsOnly(st) and unlocked then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.DRAG, 1, 0.82, 0)
                GameTooltip:Show()
            end
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(EntryLabel(self.entry), 1, 0.82, 0)
        -- Stile ohne Hinweiszeile: Zeilentext/Namen im Tooltip
        if not st.hints or Style.IconsOnly(st) then
            if self.text:GetText() and self.text:GetText() ~= EntryLabel(self.entry) then
                GameTooltip:AddLine(self.text:GetText(), 1, 1, 1)
            end
            if self.entry.groupActive then GameTooltip:AddLine(Group.MissingNames(self.entry), 1, 1, 1) end
            if self.hintText then GameTooltip:AddLine(self.hintText, 0.7, 0.7, 0.7) end
        end
        local a = self.action or {}
        if a.ctrlSpell then
            -- Gruppen-Zeile: Ziel nennen (bei Varianten-Vorschlag auch gewählten Segen)
            local who = a.targetName or "?"
            local label = (self.entry.ownOnly and a.spellName) and (who .. " – " .. a.spellName) or who
            GameTooltip:AddLine((a.isGroup and L.LEFTCLICK_GROUP or L.LEFTCLICK_SINGLE):format(label), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.CTRLCLICK_SINGLE:format(who), 0.8, 0.8, 0.8)
        elseif self.action and self.action.trackIndex then
            GameTooltip:AddLine(L.LEFTCLICK_TRACK, 0.8, 0.8, 0.8)
        elseif self.castSpell then
            GameTooltip:AddLine(L.LEFTCLICK, 0.8, 0.8, 0.8)
        end
        if self.useItem then
            GameTooltip:AddLine(L.LEFTCLICK_USE:format(ItemName(self.useItem)), 0.8, 0.8, 0.8)
            local single = self.entry and self.entry.kind == "elixir"   -- Elixier: kein Auswahlmenü
            GameTooltip:AddLine(single and L.RIGHTCLICK or L.RIGHTCLICK_CHOOSE, 0.8, 0.8, 0.8)
        elseif Variant.MenuOn(self.entry) then
            GameTooltip:AddLine(L.RIGHTCLICK_CHOOSE, 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(L.RIGHTCLICK, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return r
end

function Display.SetRowHint(r, text)
    r.hintText = text
    r.hint:SetText(text or "")
end

-- dragMode: Verschiebe-Modus (eine Zeile "Ziehen zum Verschieben", Linksklick zaubert nicht)
-- expFrom: ab diesem Index sind es Ablauf-Zeilen (Warnung vor Ablauf; nil = keine)
function Display.ShowRows(list, dragMode, expFrom)
    if InCombatLockdown() then return end   -- Secure Frames: nur außerhalb des Kampfes
    local st = Style.CurrentStyle()
    for i, e in ipairs(list) do
        local r = Display.GetRow(i)
        local isExp = not dragMode and expFrom ~= nil and i >= expFrom
        r.expiryRow = isExp
        local alpha = isExp and Expiry.Alpha() or 1
        if r.baseAlpha ~= alpha then r.baseAlpha = alpha; r:SetAlpha(alpha) end   -- nur bei Änderung (Puls)
        r.icon:SetTexture(EntryIcon(e))
        r.right:SetText("")
        if dragMode then
            r.entry = nil
            Display.SetRowAction(r, nil)
            Display.SetRowLines(r, false)
            Display.SetRowStatus(r, "neutral")
            r.text:SetText(L.DRAG)
            Display.SetRowHint(r, nil)
        elseif e.demo then
            r.entry = e
            Demo.FillRow(r, e, st)
        elseif e.groupActive then
            -- Gruppen-Zeile: Anzahl, Namen, Gruppen-/Einzel-Klick auf den ersten Spieler ohne Buff
            r.entry = e
            local a = Group.GroupActionFor(e)
            Display.SetRowAction(r, a)
            Display.SetRowLines(r, true)
            Display.SetRowStatus(r, "missing")
            local label = (e.ownOnly and a and a.spellName) or EntryLabel(e)
            if e.ownOnly and a and a.spell then
                local tex = SpellIcon(a.spell)
                if tex then r.icon:SetTexture(tex) end
            end
            r.text:SetText(L.GROUP_MISSING:format(label, #(e.groupMissing or {})))
            r.names:SetText(Group.MissingNames(e))
            if a then
                Display.SetRowHint(r, a.isGroup and L.HINT_GROUP or L.HINT_SINGLE)
            else
                Display.SetRowHint(r, L.HINT_MUTE)
            end
        else
            r.entry = e
            Display.SetRowLines(r, false)
            local spell = CastSpellFor(e)
            local trackIndex
            -- Essen/Fläschchen/Waffen-Items: Linksklick benutzt die beste Wahl aus den Taschen
            local item, noItem, macro
            local kind = Items.KindOf(e)
            if e.kind == "tracking" and db.clickCast then
                -- Platz in der Verfolgungsliste (SetTracking im PostClick); ohne Liste: Zauber
                -- der Verfolgung als secure Aktion, falls bekannt
                local t = Tracking.TYPES[e.trackType or ""]
                if t and t.index and Tracking.SetFn() then
                    trackIndex = t.index
                elseif t and SpellKnown(t.spell) then
                    spell = t.spell
                end
            elseif not spell and kind and db.clickCast then
                local choices = Items.ItemChoices(e)
                item = choices[1] and choices[1].id
                noItem = item == nil
                if item and (kind == "weapon" or kind == "poison") then
                    macro = Items.WeaponMacro(item, Items.WeaponSlot(e))
                end
            end
            local action = (spell or item) and { spell = spell, item = item, macro = macro }
                or (trackIndex and { trackIndex = trackIndex } or nil)
            Display.SetRowAction(r, action)
            if e.kind == "reagent" then
                Display.SetRowStatus(r, "low")
                r.text:SetText(L.REAGENT_LOW:format(EntryLabel(e), e.count or 0))
            elseif e.kind == "conjure" then
                local n = e.count or 0
                Display.SetRowStatus(r, n > 0 and "low" or "missing")
                if st.rightText then
                    r.text:SetText(Conjure.Name(e))
                    r.right:SetText(n > 0 and tostring(n) or L.SHORT_MISSING)
                else
                    r.text:SetText(Conjure.Text(e))
                end
            elseif isExp then
                -- Ablauf-Zeile: Restzeit zählt über den 1-s-Ticker (Evaluate) weiter
                Display.SetRowStatus(r, "expiring")
                r.text:SetText(Expiry.Text(e))
            elseif e.eatStart then
                Display.SetRowStatus(r, "eating")
                r.text:SetText(Eat.EatText(e))   -- Ess-Countdown (OnUpdate des anchor zählt weiter)
            else
                Display.SetRowStatus(r, "missing")
                if st.rightText then
                    r.text:SetText(EntryLabel(e))
                    r.right:SetText(e.kind == "tracking" and L.SHORT_OFF or L.SHORT_MISSING)
                elseif e.kind == "tracking" then
                    r.text:SetText(L.TRACK_OFF:format(EntryLabel(e)))   -- "Mineraliensuche ist nicht aktiv"
                elseif e.weaponItems then
                    r.text:SetText(EntryLabel(e))   -- "Waffe (Haupthand): Stein/Öl"
                else
                    r.text:SetText(L.MISSING:format(EntryLabel(e)))
                end
            end
            if e.eatStart and not isExp then
                Display.SetRowHint(r, L.HINT_EATING)
            elseif trackIndex then
                Display.SetRowHint(r, L.HINT_TRACK)
            elseif spell then
                Display.SetRowHint(r, Variant.MenuOn(e) and L.HINT_CAST_CHOOSE or L.HINT_CAST)
            elseif item then
                Display.SetRowHint(r, kind == "elixir" and L.HINT_USE or L.HINT_ITEM:format(ItemName(item)))
            elseif noItem then
                Display.SetRowHint(r, L.HINT_NOITEM)
            else
                Display.SetRowHint(r, Variant.MenuOn(e) and L.HINT_CHOOSE or L.HINT_MUTE)
            end
        end
        r:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].pulse:Stop()
        rows[i].entry = nil
        rows[i].expiryRow = nil
        Display.SetRowAction(rows[i], nil)
    end
    Display.SyncPulse(#list)
    Keybind.Update(#list)
    if #list > 0 then
        if not anchor:IsShown() then
            anchor:SetAlpha(1)
            anchor:Show()
        end
    else
        anchor:Hide()
    end
end

-- Pulsieren: alle Nicht-Ablauf-Zeilen gemeinsam (bei neuer pulsierender Zeile alle neu
-- starten, damit sie im Takt bleiben); Ablauf-Zeilen pulsieren nie
function Display.SyncPulse(n)
    local restart = false
    for i = 1, n do
        local r = rows[i]
        if r.expiryRow then
            r.pulse:Stop()
        elseif not r.pulse:IsPlaying() then
            restart = true
        end
    end
    if not restart then return end
    for i = 1, n do
        local r = rows[i]
        if not r.expiryRow then r.pulse:Stop(); r.pulse:Play() end
    end
end

-- Ablauf-Zeilen: nur den Text aktualisieren (auch im Kampf erlaubt: FontStrings sind
-- nicht geschützt; keine Attribute, kein Show/Hide)
function Display.TickExpiry()
    for _, r in ipairs(rows) do
        if r:IsShown() and r.expiryRow and r.entry and r.entry.expiryEnd then
            r.text:SetText(Expiry.Text(r.entry))
        end
    end
end

---------------------------------------------------------------------------
-- Tastenbelegung "Oberste Warnung auslösen" (Bindings.xml: CLICK PardonasBuffReminderKeyButton:LeftButton)
-- Unsichtbarer Secure Button ohne Parent und ohne Maus. Außerhalb des Kampfes übernimmt er bei
-- jeder Änderung der Liste (ShowRows) die Linksklick-Attribute der obersten Zeile am Bildschirm;
-- ohne Warnung werden sie geleert. Im Kampf bleibt die Belegung vom Kampfbeginn, nach dem Kampf
-- zieht Evaluate (PLAYER_REGEN_ENABLED) sie nach. Auch per Makro: /click PardonasBuffReminderKeyButton
---------------------------------------------------------------------------
Keybind.BINDING = "CLICK PardonasBuffReminderKeyButton:LeftButton"
-- Kategorie "Pardona's Addons" steht wörtlich in Bindings.xml (category); darin die Kopfzeile
-- BINDING_HEADER_<header-Token> = "Buff Reminder"
-- Rückfall: Manche Clients zeigen die Kopfzeile (wie unter "Other") als eigenen Eintrag
-- "HEADER_<Token>" an und suchen dessen Text unter BINDING_NAME_HEADER_<Token>
-- Beim Laden und nach dem Sprachwechsel (ADDON_LOADED) gesetzt.
function Keybind.SetNames()
    _G.BINDING_HEADER_PARDONASBUFFREMINDER = L.KEY_HEADER
    _G["BINDING_NAME_HEADER_PARDONASBUFFREMINDER"] = L.KEY_HEADER
    _G["BINDING_NAME_" .. Keybind.BINDING] = L.KEY_NAME
end
Keybind.SetNames()

Keybind.button = CreateFrame("Button", "PardonasBuffReminderKeyButton", nil, "SecureActionButtonTemplate")
Keybind.button:SetSize(1, 1)
Keybind.button:EnableMouse(false)
-- beide Phasen: funktioniert mit beiden Werten von ActionButtonUseKeyDown und mit /click
Keybind.button:RegisterForClicks("AnyUp", "AnyDown")
Keybind.button:SetScript("PostClick", function(self, button, down)
    if button ~= "LeftButton" or not Display.IsActionPhase(down) then return end
    -- per Taste benutztes Fläschchen als "zuletzt benutzt" merken (wie beim Linksklick)
    if self.useItem and self.entry and self.entry.itemKind == "flask" and cdb then cdb.lastFlask = self.useItem end
    -- Verfolgungs-Zeile oben: Verfolgung einschalten wie beim Linksklick
    if self.entry and self.entry.kind == "tracking" then Tracking.Activate(self) end
end)

-- Index der Zeile, die am Bildschirm ganz oben steht (n = Anzahl angezeigter Zeilen):
-- nach unten: Zeile 1; nach oben: die letzte Zeile; "Nur Icons" nach oben: erstes (linkes)
-- Icon der obersten Reihe
function Display.TopRowIndex(n)
    if not Display.GrowUp() then return 1 end
    if Style.IconsOnly(Style.CurrentStyle()) then
        local per = Display.ICONS_PER_LINE
        return math.floor((n - 1) / per) * per + 1
    end
    return n
end

-- Attribute der obersten Warnzeile übernehmen (nur außerhalb des Kampfes)
function Keybind.Update(n)
    if InCombatLockdown() then return end
    local r = n > 0 and rows[Display.TopRowIndex(n)] or nil
    local e = r and r.entry or nil   -- Verschiebe-Modus: keine Aktion
    Keybind.button.entry = e
    Display.SetRowAction(Keybind.button, e and r.action or nil)
end

-- Aktuelle Taste als Text; nil = nicht belegt bzw. nicht lesbar
function Keybind.KeyText()
    if type(GetBindingKey) ~= "function" then return nil end
    local ok, key = pcall(GetBindingKey, Keybind.BINDING)
    if not ok or type(key) ~= "string" or IsSecret(key) or key == "" then return nil end
    if type(GetBindingText) == "function" then
        local ok2, text = pcall(GetBindingText, key)
        if ok2 and type(text) == "string" and not IsSecret(text) and text ~= "" then return text end
    end
    return key
end

-- Ess-Countdown: nur den Text der Zeilen aktualisieren (höchstens alle 0,2 Sek.).
-- FontStrings sind nicht geschützt → auch im Kampf erlaubt; keine Attribute, kein Show/Hide.
Display.EAT_TICK = 0.2
anchor:SetScript("OnUpdate", function(self, el)
    self.eatTick = (self.eatTick or 0) + el
    if self.eatTick < Display.EAT_TICK then return end
    self.eatTick = 0
    for _, r in ipairs(rows) do
        if r:IsShown() and r.entry and r.entry.eatStart then r.text:SetText(Eat.EatText(r.entry)) end
    end
end)

local function PlayAlertSound()
    if db.sound == "aus" then return end
    PlaySound(SOUNDS[db.sound] or SOUNDS.ping, "Master")
end

---------------------------------------------------------------------------
-- Rechtsklick-Menü: ein Fenster mit Kopf, Item-Auswahl (nur Essen/Fläschchen),
-- Stummschalten und Fußzeile.
-- Das Fenster (menu) ist unsicher und funktioniert auch im Kampf. Die Item-Zeilen sind
-- Secure Buttons; sie liegen in einem eigenen Frame (itemPanel, Parent UIParent, NICHT
-- an menu verankert), der über den Item-Abschnitt des Fensters gelegt wird. So wird
-- menu nie geschützt. itemPanel wird nur außerhalb des Kampfes gezeigt, befüllt und
-- versteckt; bei Kampfbeginn schließt CloseItemPanelForCombat beides.
-- Die Favoriten-Sterne sind unsichere Buttons im menu neben den Item-Zeilen.
---------------------------------------------------------------------------
Menu.MAX_ITEM_CHOICES = 10
Menu.STAR_SIZE = 16

local menu = CreateFrame("Frame", "BuffReminderMenu", UIParent, "BackdropTemplate")
menu:SetFrameStrata("DIALOG")
menu:EnableMouse(true)
menu:Hide()
tinsert(UISpecialFrames, "BuffReminderMenu")   -- Esc schließt
menu.bg = menu:CreateTexture(nil, "BACKGROUND")

menu.iconBorder = menu:CreateTexture(nil, "ARTWORK", nil, -1)
menu.icon = menu:CreateTexture(nil, "ARTWORK")
menu.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menu.title:SetJustifyH("LEFT")
menu.title:SetWordWrap(false)
menu.sub = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
menu.sub:SetJustifyH("LEFT")
menu.sub:SetWordWrap(false)

function Menu.MenuText(font)
    local fs = menu:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    return fs
end
menu.itemHead = Menu.MenuText("GameFontNormalSmall")
menu.itemNone = Menu.MenuText("GameFontDisableSmall")
menu.muteHead = Menu.MenuText("GameFontNormalSmall")
menu.seps = {}
for i = 1, 3 do menu.seps[i] = menu:CreateTexture(nil, "ARTWORK") end

-- kleine Schaltfläche im Stil (Rahmen + Hintergrund + Text)
function Menu.MenuButton(text, onClick)
    local b = CreateFrame("Button", nil, menu, "BackdropTemplate")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- { Text-Schlüssel, Dauer }; Beschriftung per Menu.SetTexts (nach dem Sprachwechsel neu)
Menu.MUTE_OPTIONS = {
    { "MUTE_5", 300 }, { "MUTE_15", 900 }, { "MUTE_60", 3600 }, { "MUTE_SESSION", math.huge },
}
menu.muteButtons = {}
for i, opt in ipairs(Menu.MUTE_OPTIONS) do
    menu.muteButtons[i] = Menu.MenuButton("", function()
        if menu.entry and not menu.entry.demo then
            muted[menu.entry.key] = (opt[2] == math.huge) and math.huge or (GetTime() + opt[2])
            NoteDeferred()
            Evaluate()
        end
        menu:Hide()
    end)
end

-- "Anzeige verschieben" (volle Breite unter den Stumm-Knöpfen; nicht im Kampf)
menu.moveBtn = Menu.MenuButton("", function()
    local demo = menu.entry and menu.entry.demo
    menu:Hide()
    if not demo then Cfg.SetMoveMode(true) end
end)

menu.close = CreateFrame("Button", nil, menu)
menu.close:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
menu.close.label = menu.close:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
menu.close.label:SetPoint("CENTER")
menu.close:SetScript("OnClick", function() menu:Hide() end)

-- feste Beschriftungen des Menüs (beim Laden und nach dem Sprachwechsel bei ADDON_LOADED)
function Menu.SetTexts()
    for i, opt in ipairs(Menu.MUTE_OPTIONS) do menu.muteButtons[i].label:SetText(L[opt[1]]) end
    menu.close.label:SetText(L.CLOSE_ESC)
    menu.moveBtn.label:SetText(L.MENU_MOVE)
end
Menu.SetTexts()

-- Item-Zeilen (Secure Buttons: type "item")
local itemPanel = CreateFrame("Frame", "BuffReminderItemMenu", UIParent)
itemPanel:SetFrameStrata("DIALOG")
itemPanel:Hide()
itemPanel.buttons = {}
menu.stars = {}


-- Tooltip einer Menüzeile: Item (itemID) oder Zauber (spellID, Variantenmenü)
function Menu.ShowButtonTooltip(b)
    if not b.itemID and not b.spellID then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    if b.itemID then
        GameTooltip:SetItemByID(b.itemID)
    elseif not (GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, b.spellID)) then
        GameTooltip:SetText(SpellName(b.spellID) or "?", 1, 1, 1)
    end
    GameTooltip:Show()
end

function Menu.GetItemButton(i)
    if itemPanel.buttons[i] then return itemPanel.buttons[i] end
    local b = CreateFrame("Button", nil, itemPanel, "SecureActionButtonTemplate")
    b:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
    b.iconBorder = b:CreateTexture(nil, "ARTWORK", nil, -1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetJustifyH("RIGHT")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.xpBg = b:CreateTexture(nil, "ARTWORK")
    b.xp = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.xp:SetText(L.XP_BADGE)
    b.xpBg:SetPoint("TOPLEFT", b.xp, "TOPLEFT", -3, 2)
    b.xpBg:SetPoint("BOTTOMRIGHT", b.xp, "BOTTOMRIGHT", 3, -2)
    b.info = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.info:SetJustifyH("LEFT")
    b.info:SetWordWrap(false)
    b:SetAttribute("type", "item")
    if Display.HasKeyDownCVar() then
        b:RegisterForClicks("AnyUp", "AnyDown")
    else
        b:RegisterForClicks("AnyUp")
    end
    b:SetScript("PostClick", function(self, _, down)
        if not Display.IsActionPhase(down) then return end
        local e, vkey = menu.entry, self.variantKey
        if e and e.demo then menu:Hide(); return end   -- Demo: keine Aktion, nichts merken
        if e and e.itemKind == "flask" and self.itemID then cdb.lastFlask = self.itemID end
        -- Variantenmenü: gewählte Variante wird zur zuletzt genutzten (Linksklick der Warnung)
        if e and vkey then cdb.lastVariant[e.key] = vkey end
        menu:Hide()   -- schließt auch das itemPanel
        if vkey then Evaluate() end
    end)
    -- Item- bzw. Zauber-Tooltip beim Überfahren. HookScript statt SetScript: ergänzt nur die
    -- Anzeige, die Secure-Klickfunktion des Buttons bleibt unberührt.
    b:HookScript("OnEnter", Menu.ShowButtonTooltip)
    b:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    itemPanel.buttons[i] = b
    return b
end

-- Favoriten-Stern (unsicher, Kind von menu, neben der Item-Zeile): löst nie ein Item aus
function Menu.GetStar(i)
    if menu.stars[i] then return menu.stars[i] end
    local s = CreateFrame("Button", nil, menu)
    s:SetSize(Menu.STAR_SIZE + 4, Menu.STAR_SIZE + 4)
    s.tex = s:CreateTexture(nil, "ARTWORK")
    s.tex:SetSize(Menu.STAR_SIZE, Menu.STAR_SIZE)
    s.tex:SetPoint("CENTER")
    s.text = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s.text:SetPoint("CENTER")
    s:SetScript("OnClick", function(self)
        if not self.itemID or not cdb or (menu.entry and menu.entry.demo) then return end
        cdb.favorites[self.itemID] = (not cdb.favorites[self.itemID]) or nil
        if not InCombatLockdown() then
            Menu.LayoutMenu(menu.entry)   -- Reihenfolge und Markierung neu
            Evaluate()               -- Linksklick der Warnung nimmt ggf. den neuen Favoriten
        end
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    s:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(cdb.favorites[self.itemID] and L.FAV_REMOVE or L.FAV_ADD, 1, 1, 1)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    menu.stars[i] = s
    return s
end

function Menu.SetStar(s, on, st)
    local a = Style.StarAtlas()
    if a then
        s.tex:SetAtlas(a)
        s.tex:SetDesaturated(not on)
        s.tex:SetAlpha(on and 1 or st.menu.starOff)
        s.tex:Show(); s.text:Hide()
    else
        s.text:SetText("*")
        if on then s.text:SetTextColor(1, 0.82, 0) else s.text:SetTextColor(0.5, 0.5, 0.5) end
        s.tex:Hide(); s.text:Show()
    end
end

-- Tooltip ausblenden, falls er zu einem Element des Menüs gehört
function Menu.HideMenuTooltip()
    for _, b in ipairs(itemPanel.buttons) do
        if GameTooltip:IsOwned(b) then GameTooltip:Hide(); return end
    end
    for _, s in ipairs(menu.stars) do
        if GameTooltip:IsOwned(s) then GameTooltip:Hide(); return end
    end
end
itemPanel:SetScript("OnHide", Menu.HideMenuTooltip)

function Menu.HideItemPanel()
    if itemPanel:IsShown() and not InCombatLockdown() then itemPanel:Hide() end
end

-- Kategorie (Essen) bzw. leer (Fläschchen) für die Info-Zeile
function Menu.ItemInfoText(c)
    if c.cat then return ns.Locales.Text("FOOD_CAT_" .. c.cat:upper(), c.cat) end
    if c.wcat then return ns.Locales.Text("WEAPON_CAT_" .. c.wcat:upper(), c.wcat) end
    return ""
end

-- Secure-Aktion einer Item-Zeile: normal "item", Waffen-Items per Makro auf den Slot
function Menu.SetItemButtonAction(b, id, e, kind)
    b:SetAttribute("spell", nil)
    b:SetAttribute("unit", nil)
    if kind == "weapon" or kind == "poison" then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", Items.WeaponMacro(id, Items.WeaponSlot(e)))
        b:SetAttribute("item", nil)
    else
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. id)
        b:SetAttribute("macrotext", nil)
    end
end

-- Secure-Aktion einer Varianten-Zeile: Zauber (höchster erlernter Rang) auf sich selbst
-- Zeile ohne secure Aktion (Demo-Modus)
function Menu.ClearButtonAction(b)
    for _, k in ipairs({ "type", "item", "spell", "macrotext", "unit" }) do b:SetAttribute(k, nil) end
end

function Menu.SetSpellButtonAction(b, spell)
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", spell)
    b:SetAttribute("unit", "player")
    b:SetAttribute("item", nil)
    b:SetAttribute("macrotext", nil)
end

function Menu.ItemHeadText(kind)
    if kind == "flask" then return L.MENU_FLASK end
    if kind == "weapon" then return L.MENU_WEAPON end
    if kind == "poison" then return L.MENU_POISON end
    return L.MENU_FOOD
end

-- Menü für Eintrag e aufbauen und an menu.x/menu.y (UIParent-Koordinaten) anzeigen.
-- Im Kampf nur Kopf + Stummschalten; die Secure-Item-Zeilen werden dann nicht angefasst.
-- Rahmen/Hintergrund/Text einer Menü-Schaltfläche im aktuellen Stil
function Menu.StyleButton(b, ms)
    b:SetBackdrop({ edgeFile = Style.WHITE, edgeSize = 1 })
    Style.SetColor(b, "SetBackdropBorderColor", ms.buttonBorder)
    b.bg:ClearAllPoints()
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    Style.SetColor(b.bg, "SetColorTexture", ms.buttonBg)
    Style.SetColor(b.label, "SetTextColor", ms.textColor)
end

function Menu.LayoutMenu(e)
    if not e then return end
    local st = Style.CurrentStyle()
    local ms = st.menu
    local combat = InCombatLockdown()
    local width, pad = ms.width, ms.pad
    local inner = width - 2 * pad
    menu.entry = e

    Style.StyleFrame(menu, st, menu.bg)

    -- Kopf: Icon, Titel, Unterzeile
    local y = -pad - st.inset
    menu.icon:SetSize(ms.headerIcon, ms.headerIcon)
    menu.icon:ClearAllPoints()
    menu.icon:SetPoint("TOPLEFT", pad, y)
    menu.icon:SetTexture(EntryIcon(e))
    Style.StyleIconBorder(menu.iconBorder, menu.icon, st.iconBorder)
    local textWidth = inner - ms.headerIcon - 8
    Style.SetFont(menu.title, st.titleFont)
    Style.SetColor(menu.title, "SetTextColor", st.titleColor)
    menu.title:ClearAllPoints()
    if ms.itemTwoLines then
        menu.title:SetPoint("TOPLEFT", menu.icon, "TOPRIGHT", 8, -1)
    else
        menu.title:SetPoint("LEFT", menu.icon, "RIGHT", 8, 0)
    end
    menu.title:SetWidth(textWidth)
    menu.title:SetText(EntryLabel(e))
    Style.SetColor(menu.sub, "SetTextColor", ms.subColor)
    menu.sub:ClearAllPoints()
    menu.sub:SetPoint("BOTTOMLEFT", menu.icon, "BOTTOMRIGHT", 8, 1)
    menu.sub:SetWidth(textWidth)

    local kind = Items.KindOf(e)
    -- Elixiere: kein Item-Menü (ein Eintrag = ein Elixier)
    local withItems = kind and kind ~= "elixir" and (db.clickCast or e.demo) and not combat
    -- Variantenmenü (experimentell): erlernte Varianten statt Items; nie im Kampf
    local variants = not combat and not withItems and Variant.MenuOn(e) and Variant.Choices(e) or nil
    -- Demo-Modus: Beispiel-Varianten (Magier-Rüstungen, unabhängig davon, ob gelernt)
    if e.demo and e.demoVariants and not combat then variants = Demo.VariantChoices() end
    local sub
    if combat then
        sub = L.SUB_COMBAT
    elseif e.groupActive then
        sub = Group.MissingNames(e)
    elseif e.kind == "reagent" then
        sub = L.REAGENT_LOW:format(EntryLabel(e), e.count or 0)
    elseif e.kind == "conjure" then
        sub = Conjure.Text(e)
    elseif withItems then
        sub = L.SUB_ITEMS
    elseif variants then
        sub = L.SUB_VARIANT
    else
        sub = L.SUB_MUTE
    end
    menu.sub:SetText(sub)
    if ms.itemTwoLines then menu.sub:Show() else menu.sub:Hide() end
    y = y - ms.headerIcon - ms.gap

    local sepIndex = 0
    local function Separator()
        sepIndex = sepIndex + 1
        local t = menu.seps[sepIndex]
        local c = ms.sepColor
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        t:SetHeight(1)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", pad, y)
        t:SetPoint("TOPRIGHT", -pad, y)
        t:Show()
        y = y - ms.gap
    end
    local function Head(fs, text)
        Style.SetColor(fs, "SetTextColor", ms.sectionColor)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", pad, y)
        fs:SetText(text)
        fs:Show()
        y = y - 16
    end

    -- Item-Auswahl bzw. Varianten (gleiche Secure-Zeilen im itemPanel; Varianten ohne Sterne)
    local n, itemTop = 0, 0
    local rowsWidth = variants and inner or (inner - Menu.STAR_SIZE - 8)
    local h = ms.itemHeight
    if withItems or variants then
        Separator()
        Head(menu.itemHead, variants and L.MENU_VARIANT or Menu.ItemHeadText(kind))
        local choices = variants or (e.demo and Demo.FoodChoices()) or Items.ItemChoices(e)
        n = math.min(#choices, Menu.MAX_ITEM_CHOICES)
        itemTop = y
        if n == 0 then
            menu.itemNone:ClearAllPoints()
            menu.itemNone:SetPoint("TOPLEFT", pad + 4, y)
            menu.itemNone:SetText(variants and L.NO_VARIANT or L.NONE_IN_BAGS)
            menu.itemNone:Show()
            y = y - 18
        else
            menu.itemNone:Hide()
        end
        for i = 1, n do
            local c, b = choices[i], Menu.GetItemButton(i)
            if e.demo then
                -- Demo: Zeile ohne secure Aktion (Tooltip über itemID bzw. spellID)
                b.itemID, b.variantKey = (not variants) and c.id or nil, nil
                b.spellID = variants and c.spell or nil
                Menu.ClearButtonAction(b)
            elseif variants then
                b.itemID, b.variantKey = nil, c.vkey
                b.spellID = type(c.spell) == "number" and c.spell or nil
                Menu.SetSpellButtonAction(b, c.spell)
            else
                b.itemID, b.variantKey, b.spellID = c.id, nil, nil
                Menu.SetItemButtonAction(b, c.id, e, kind)
            end
            b:SetSize(rowsWidth, h)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -(i - 1) * (h + 1))
            local iconSize = h - 6
            b.icon:SetSize(iconSize, iconSize)
            b.icon:ClearAllPoints()
            b.icon:SetPoint("LEFT", 4, 0)
            b.icon:SetTexture(variants and c.icon or (ItemIcon(c.id) or FALLBACK_ICON))
            Style.StyleIconBorder(b.iconBorder, b.icon, st.iconBorder)
            b.count:ClearAllPoints()
            b.count:SetPoint("RIGHT", -4, 0)
            b.count:SetText(variants and "" or c.count)
            -- Zeile 1: Name (+ XP-Abzeichen); Zeile 2: Kategorie + "beste Wahl"
            -- (Varianten: Zeile 2 = "zuletzt genutzt" bei der Variante des Linksklicks)
            local best = i == 1 and not variants
            local info = variants and (c.last and L.LAST_USED or "") or Menu.ItemInfoText(c)
            local nameY = ms.itemTwoLines and 6 or 0
            if variants and info == "" then nameY = 0 end   -- Variante ohne Zeile 2: mittig
            b.name:ClearAllPoints()
            b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, nameY)
            Style.SetColor(b.name, "SetTextColor", ms.textColor)
            local name = variants and c.name or ItemName(c.id)
            if best and not ms.itemTwoLines then name = Style.StarMarkup(12) .. " " .. name end
            if variants and c.last and not ms.itemTwoLines then
                name = name .. " |cff999999(" .. L.LAST_USED .. ")|r"
            end
            b.name:SetText(name)
            local maxName = rowsWidth - iconSize - 50 - (c.xp and 26 or 0)
            local w = (b.name.GetUnboundedStringWidth and b.name:GetUnboundedStringWidth()) or b.name:GetStringWidth()
            b.name:SetWidth(math.max(20, math.min(w + 2, maxName)))
            if c.xp then
                b.xp:ClearAllPoints()
                b.xp:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
                Style.SetColor(b.xpBg, "SetColorTexture", ms.xpBg)
                b.xp:Show(); b.xpBg:Show()
            else
                b.xp:Hide(); b.xpBg:Hide()
            end
            if ms.itemTwoLines and nameY ~= 0 then
                local line = info
                if best then
                    local mark = "|cffffd100" .. Style.StarMarkup(10) .. " " .. L.BEST .. "|r"
                    line = (line ~= "" and (line .. "  ") or "") .. mark
                end
                b.info:ClearAllPoints()
                b.info:SetPoint("LEFT", b.icon, "RIGHT", 6, -7)
                b.info:SetWidth(rowsWidth - iconSize - 50)
                b.info:SetText(line)
                b.info:Show()
            else
                b.info:Hide()
            end
            b:Show()
            -- Auswahl neu befüllt, während die Maus darauf steht: Tooltip nachziehen
            if GameTooltip:IsOwned(b) then Menu.ShowButtonTooltip(b) end

            if not variants then
                local s = Menu.GetStar(i)
                s.itemID = c.id
                Menu.SetStar(s, c.fav == true, st)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", pad + rowsWidth + 4, itemTop - (i - 1) * (h + 1) - (h - Menu.STAR_SIZE - 4) / 2)
                s:Show()
            end
        end
        y = y - n * (h + 1)
    else
        menu.itemHead:Hide()
        menu.itemNone:Hide()
    end
    if not combat then
        for i = n + 1, #itemPanel.buttons do
            local b = itemPanel.buttons[i]
            if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
            b:Hide()
            b.itemID, b.variantKey, b.spellID = nil, nil, nil
            b:SetAttribute("item", nil)
            b:SetAttribute("macrotext", nil)
            b:SetAttribute("spell", nil)
        end
    end
    -- Sterne nur bei Items (Varianten: keine Favoriten)
    for i = (variants and 0 or n) + 1, #menu.stars do menu.stars[i]:Hide() end

    -- Stummschalten: vier Schaltflächen nebeneinander
    Separator()
    Head(menu.muteHead, L.MENU_MUTE)
    local bw = (inner - 3 * 4) / 4
    for i, b in ipairs(menu.muteButtons) do
        b:SetSize(bw, 20)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pad + (i - 1) * (bw + 4), y)
        Menu.StyleButton(b, ms)
    end
    y = y - 20 - ms.gap
    -- darunter: "Anzeige verschieben" (volle Breite; im Kampf nicht gezeigt)
    if combat then
        menu.moveBtn:Hide()
    else
        menu.moveBtn:SetSize(inner, 20)
        menu.moveBtn:ClearAllPoints()
        menu.moveBtn:SetPoint("TOPLEFT", pad, y)
        Menu.StyleButton(menu.moveBtn, ms)
        menu.moveBtn:Show()
        y = y - 20 - ms.gap
    end

    -- Fußzeile
    Separator()
    for i = sepIndex + 1, #menu.seps do menu.seps[i]:Hide() end
    menu.close:SetSize(inner, 16)
    menu.close:ClearAllPoints()
    menu.close:SetPoint("TOPLEFT", pad, y + 2)
    Style.SetColor(menu.close.label, "SetTextColor", ms.subColor)
    y = y - 16

    local height = -y + pad + st.inset
    menu:SetSize(width, height)

    -- Position: am Mauszeiger, innerhalb des Bildschirms. Reicht der Platz unter dem
    -- Mauszeiger nicht, klappt das Fenster nach oben auf (Unterkante knapp unter dem Zeiger).
    local base = menu:GetParent() or UIParent
    local conv = base:GetEffectiveScale() / menu:GetEffectiveScale()
    local sw, sh = base:GetWidth() * conv, base:GetHeight() * conv
    local x = math.max(0, math.min(menu.x or 0, sw - width))
    local top = menu.y or sh
    if top - height < 0 then top = top - 20 + height end
    top = math.min(sh, math.max(top, height))
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", base, "BOTTOMLEFT", x, top)

    if (withItems or variants) and n > 0 then
        itemPanel:ClearAllPoints()
        itemPanel:SetPoint("TOPLEFT", base, "BOTTOMLEFT", x + pad, top + itemTop)
        itemPanel:SetSize(rowsWidth, n * (h + 1))
        itemPanel:SetFrameLevel(menu:GetFrameLevel() + 10)
        itemPanel:Show()
    elseif not combat then
        itemPanel:Hide()
    end
end

-- Menü geschlossen: Item-Zeilen und deren Tooltip ebenfalls schließen
-- (im Kampf ist das itemPanel nie offen, s. CloseItemPanelForCombat)
menu:SetScript("OnHide", function()
    Menu.HideMenuTooltip()
    Menu.HideItemPanel()
end)

-- Schließt sich, wenn die Maus das Fenster 2 Sek. lang verlassen hat
menu:SetScript("OnUpdate", function(self, el)
    if Demo.run or self:IsMouseOver() or (itemPanel:IsShown() and itemPanel:IsMouseOver()) then self.away = 0 else
        self.away = (self.away or 0) + el
        if self.away > 2 then self:Hide() end
    end
end)

-- Rechtsklick auf eine Erinnerung
function Display.OpenMuteMenu(row)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu.x, menu.y = x / s - 10, y / s + 10
    Menu.LayoutMenu(row.entry)
    menu.away = 0
    menu:Show()
end

-- Taschen geändert: offene Item-Auswahl neu aufbauen
function Menu.RefreshItemPanel()
    if Demo.active then return end   -- Demo-Menü nicht mit echten Taschen neu aufbauen
    if not menu:IsShown() or not itemPanel:IsShown() or InCombatLockdown() then return end
    Menu.LayoutMenu(menu.entry)
end

-- Kampfbeginn: Item-Zeilen (Secure Buttons) schließen, solange das noch erlaubt ist
function Menu.CloseItemPanelForCombat()
    if itemPanel:IsShown() then
        itemPanel:Hide()
        menu:Hide()
    end
end

-- Stil anwenden (Warnzeilen + Menü); im Kampf erst nach Kampfende
function Display.ApplyStyle()
    if InCombatLockdown() then Display.stylePending = true; return end
    Display.stylePending = false
    Display.styleGen = Display.styleGen + 1
    for i, r in ipairs(rows) do
        Display.LayoutRow(r)
        Display.PositionRow(i)
    end
    local st = Style.CurrentStyle()
    if Style.IconsOnly(st) then
        anchor:SetSize(st.row.height + st.stripe, st.row.height)
    else
        anchor:SetSize(st.row.width, st.row.height)
    end
    if menu:IsShown() then menu:Hide() end   -- nächstes Öffnen im neuen Stil
end

---------------------------------------------------------------------------
-- Prüflogik
---------------------------------------------------------------------------
function Evaluate()
    if not db or not ready then return end
    if Demo.active then return end   -- Demo-Modus: Anzeige gehört der Demo; Ende wertet neu aus
    -- Im Kampf wird nur der Zustand aktualisiert; die Warnliste (Secure Buttons)
    -- bleibt unverändert und wird bei PLAYER_REGEN_ENABLED neu aufgebaut.
    local combat = InCombatLockdown()
    if layoutPending and not combat then ApplyLayout() end
    if Display.stylePending and not combat then Display.ApplyStyle() end

    if unlocked then
        if not combat then
            Display.ShowRows({ { key = "_drag", label = "DRAG", icon = EntryIcon(entries[1] or {}) } }, true)
        end
        if RefreshConfig then RefreshConfig() end
        return
    end

    if GetTime() < testUntil then
        local list = {}
        for _, e in ipairs(entries) do
            if knownCache[e.key] and IsEnabled(e) then list[#list + 1] = e end
        end
        if #list == 0 and entries[1] then list[1] = entries[1] end
        Display.ShowRows(list)
        return
    end

    local list, newOnes = {}, false
    local expList, expOn = {}, ExpOn("expExpiry")   -- Warnung vor Ablauf: eigene Zeilen nach den fehlenden
    if db.enabled and not Suppressed() then
        if expOn then Expiry.UpdateWeapons() end
        local ids, names, unreliable, own, auraList = ScanAuras()
        local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auraList } or nil
        RememberFromAuras(own)
        if scan then
            -- Icons der allgemeinen Buffs aus dem Spiel merken (account-weit)
            for _, e in ipairs(GENERAL_BUFFS) do
                local a = FindAura(e, scan)
                if a and a.icon then db.iconCache[e.key] = a.icon end
            end
        end
        local instOk = (not db.instanceOnly) or InGroupInstance()
        local now = GetTime()
        -- Gruppen-Buffs: nur außerhalb des Kampfes auswerten (gedrosselt)
        if not combat and GroupFeatureOn() then Group.GroupScanIfDue(now) end
        -- Isst der Spieler gerade? (nil auch bei nicht lesbarer Aura → normale Anzeige)
        if foodEntry then foodEntry.eatStart = Eat.FindEatStart(scan) end

        for _, e in ipairs(entries) do
            local relevant = knownCache[e.key] and IsEnabled(e) and (not e.general or e.everywhere or instOk)
            -- Gruppen-Check aktiv: Gruppen-Zeile ersetzt die Selbst-Zeile (gleicher Key)
            e.groupActive = relevant and Group.GroupActive(e) or false
            if relevant then
                local m
                if e.groupActive then
                    if not combat then m = Group.GroupMissing(e) end   -- im Kampf: Zustand beibehalten
                else
                    m = CheckMissing(e, scan)
                end
                if m ~= nil then missing[e.key] = m end   -- nil: Zustand beibehalten (Kampf/Secret)
                -- Entprellung: nil (unbekannt) lässt missingSince unverändert
                if m == true then
                    if not missingSince[e.key] then
                        missingSince[e.key] = now
                        -- Einmalige Nachprüfung genau nach Ablauf der Entprellung statt erst
                        -- beim nächsten Ticker-Tick; höchstens ein ausstehender Timer.
                        if not Display.confirmTimerPending then
                            Display.confirmTimerPending = true
                            C_Timer.After(MISSING_CONFIRM + 0.05, function()
                                Display.confirmTimerPending = false
                                Evaluate()
                            end)
                        end
                    end
                elseif m == false then
                    missingSince[e.key] = nil
                end
            else
                missing[e.key] = false
                missingSince[e.key] = nil
            end
            -- Angezeigt wird erst nach MISSING_CONFIRM Sek. durchgehendem Fehlen (eine
            -- kurzzeitig leere Aura-Liste, z. B. nach Ladebildschirmen, löst nichts aus).
            -- Bereits angezeigte Warnungen bleiben stehen, solange der Buff fehlt.
            local since = missingSince[e.key]
            local confirmed = shownKeys[e.key] or (since ~= nil and now - since >= MISSING_CONFIRM)
            -- Ess-Countdown: Zeile sofort zeigen, zählt aber nicht als "neu fehlend" (keine
            -- Chatmeldung, kein Ton). Da sie danach in shownKeys steht, bleibt auch die normale
            -- Warnung nach dem Aufstehen (Ess-Aura weg, kein Well Fed) ohne erneute Meldung.
            local eating = e.eatStart ~= nil
            if missing[e.key] and (confirmed or eating) and not MuteRemaining(e.key) then
                list[#list + 1] = e
                if not combat and not shownKeys[e.key] and not eating then
                    newOnes = true
                    if e.kind == "reagent" then
                        Print(L.REAGENT_CHAT:format(EntryLabel(e), e.count or 0))
                    elseif e.kind == "conjure" then
                        Print(L.CONJURE_CHAT:format(Conjure.Text(e)))
                    elseif e.groupActive then
                        Print(L.GROUP_CHAT:format(EntryLabel(e), #(e.groupMissing or {})))
                    else
                        Print(L.CHAT:format(EntryLabel(e)))
                    end
                end
            end
            -- Warnung vor Ablauf: Buff vorhanden, läuft aber bald ab (kein Ton, keine Chatmeldung)
            e.expiryEnd = nil
            if expOn and relevant and missing[e.key] == false and not e.groupActive and not eating
                and Expiry.Eligible(e) and not MuteRemaining(e.key) then
                local left = Expiry.Left(e, scan)
                if left then
                    e.expiryEnd = now + left
                    expList[#expList + 1] = e
                end
            end
        end
    end

    if combat then
        -- Meldung, Ton und Anzeige folgen nach dem Kampf; Restzeit vorhandener Ablauf-Zeilen läuft weiter
        Display.TickExpiry()
        if RefreshConfig then RefreshConfig() end
        return
    end

    wipe(shownKeys)
    for _, e in ipairs(list) do shownKeys[e.key] = true end
    if newOnes then PlayAlertSound() end   -- Ton nur bei neu fehlendem Buff, keine Wiederholung
    local missingCount = #list
    for _, e in ipairs(expList) do list[#list + 1] = e end
    Display.ShowRows(list, false, missingCount + 1)

    -- Kurzstatus für das Pardona-Menü: nur bei Änderung neu anzeigen
    local count = db.enabled and missingCount or -1
    if count ~= warnCount then
        warnCount = count
        RefreshPardonaStatus()
    end

    if RefreshConfig then RefreshConfig() end
end

-- Test-Erinnerung (5 Sek.); im Kampf nicht möglich (Secure Buttons)
local function StartTest()
    if InCombatLockdown() then Print(L.COMBAT); return end
    testUntil = GetTime() + 5
    PlayAlertSound()
    Evaluate()
end

---------------------------------------------------------------------------
-- Einstellungsfenster
---------------------------------------------------------------------------
local config
Cfg.configRows = {}
Cfg.reagentRows = {}

function Cfg.FormatMute(left)
    if left == math.huge then return L.SESSION end
    left = math.ceil(left)
    return ("%d:%02d"):format(math.floor(left / 60), left % 60)
end

-- Detail-Einstellung (de)aktivieren: Häkchen samt Beschriftung
function Cfg.SetCheckEnabled(cb, on)
    if on then cb:Enable() else cb:Disable() end
    if cb.label then
        if on then cb.label:SetTextColor(1, 1, 1) else cb.label:SetTextColor(0.5, 0.5, 0.5) end
        if cb.betaBase then cb.label:SetText(Cfg.BetaText(cb.betaBase, on)) end
    end
end

-- Eingabefeld sperren/freigeben (SetEnabled nicht in jedem Client garantiert → Maus als Fallback)
function Cfg.SetEditEnabled(edit, on)
    if not on and edit:HasFocus() then edit:ClearFocus() end
    if edit.SetEnabled then edit:SetEnabled(on) end
    edit:EnableMouse(on)
    edit:SetAlpha(on and 1 or 0.5)
end

function RefreshConfig()
    if not config or not config:IsVisible() then return end
    Cfg.LayoutClassRows()
    local expCons = ExpOn("expConsumables")
    for _, w in ipairs(Cfg.configRows) do
        local e = w.entry
        local known = knownCache[e.key]
        -- Verbrauchsgüter/Waffen-Items: eigenes Häkchen (Standard an), ausgegraut solange der
        -- Schalter aus ist (Schurke: auch solange der Gift-Eintrag des Slots aktiv ist)
        local gated, gateNote = Cfg.Gate(e, expCons)
        if e.kind == "elixir" then
            w.cb:SetChecked(cdb.elixirsWanted[e.item] == true)
        elseif e.kind == "scroll" then
            w.cb:SetChecked(not cdb.scrollsOff[e.scrollType])
        elseif e.kind == "conjure" or e.weaponItems then
            w.cb:SetChecked(cdb.buffs[e.key] ~= false)
        else
            w.cb:SetChecked(IsEnabled(e))
        end
        w.icon:SetTexture(EntryIcon(e))
        w.name:SetText(EntryLabel(e))
        if known then
            if gated then w.cb:Disable() else w.cb:Enable() end
            w.icon:SetDesaturated(gated)
            if gated then w.name:SetTextColor(0.5, 0.5, 0.5) else w.name:SetTextColor(1, 1, 1) end
            local left = MuteRemaining(e.key)
            if gateNote then
                w.status:SetText(gateNote)
                w.status:SetTextColor(0.6, 0.6, 0.6)
            elseif left then
                w.status:SetText(L.MUTED:format(Cfg.FormatMute(left)))
                w.status:SetTextColor(1, 0.4, 0.3)
            elseif e.kind == "elixir" or e.kind == "scroll" then
                -- Anzahl in den Taschen (Rollen: alle Ränge der Art)
                local cnt = e.kind == "elixir" and (Items.bagCounts[e.item] or 0) or Cfg.ScrollCount(e)
                w.status:SetText(L.IN_BAGS:format(cnt))
                w.status:SetTextColor(0.6, 0.6, 0.6)
            elseif e.general and not e.everywhere and db.instanceOnly and not InGroupInstance() then
                w.status:SetText(L.INSTANCE_HINT)
                w.status:SetTextColor(0.6, 0.6, 0.6)
            else
                w.status:SetText("")
            end
        else
            w.cb:Disable()
            w.icon:SetDesaturated(true)
            w.name:SetTextColor(0.5, 0.5, 0.5)
            local lvl = e.level or 1
            if e.talent then
                w.status:SetText(L.TALENT:format(lvl))
            elseif (UnitLevel("player") or 1) < lvl then
                w.status:SetText(L.FROM_LEVEL:format(lvl))
            else
                w.status:SetText(L.NOT_LEARNED)
            end
            w.status:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    local expReag = ExpOn("expReagents")
    for _, w in ipairs(Cfg.reagentRows) do
        local e = w.entry
        w.icon:SetTexture(EntryIcon(e))
        w.name:SetText(EntryLabel(e))
        if not w.edit:HasFocus() then w.edit:SetText(tostring(ReagentThreshold(e.item))) end
        if knownCache[e.key] then
            w.icon:SetDesaturated(false)
            w.name:SetTextColor(1, 1, 1)
            local left = MuteRemaining(e.key)
            if left then
                w.status:SetText(L.MUTED:format(Cfg.FormatMute(left)))
                w.status:SetTextColor(1, 0.4, 0.3)
            else
                w.status:SetText(L.IN_BAGS:format(ItemCount(e.item) or 0))
                w.status:SetTextColor(0.6, 0.6, 0.6)
            end
        else
            w.icon:SetDesaturated(true)
            w.name:SetTextColor(0.5, 0.5, 0.5)
            w.status:SetText(L.NOT_LEARNED)
            w.status:SetTextColor(0.5, 0.5, 0.5)
        end
        -- Experimental-Schalter aus: Zeile ausgrauen, Eingabe sperren
        Cfg.SetEditEnabled(w.edit, expReag)
        if not expReag then
            w.icon:SetDesaturated(true)
            w.name:SetTextColor(0.5, 0.5, 0.5)
            w.status:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    config.enabledCB:SetChecked(db.enabled)
    config.instCB:SetChecked(db.instanceOnly)
    config.castCB:SetChecked(db.clickCast)
    local expGroup = ExpOn("expGroup")
    if config.expGroupCB then config.expGroupCB:SetChecked(expGroup) end
    config.expReagCB:SetChecked(expReag)
    if config.reagentHint then config.reagentHint:SetAlpha(expReag and 1 or 0.5) end
    if config.groupCB then
        config.groupCB:SetChecked(db.groupCheck)
        Cfg.SetCheckEnabled(config.groupCB, expGroup)
        if config.blessCB then
            config.blessCB:SetChecked(ExpOn("expBlessings"))
            Cfg.SetCheckEnabled(config.blessCB, expGroup and not Group.pallyPower)
            config.blessNote:SetText(Group.pallyPower and L.BLESS_PALLYPOWER or "")
        end
        config.groupModeBtn:SetText(L.GROUP_MODE:format(Cfg.ValueText("GROUP_MODE_", db.groupMode)))
        if expGroup then config.groupModeBtn:Enable() else config.groupModeBtn:Disable() end
    end
    local expExpiry = ExpOn("expExpiry")
    config.expExpiryCB:SetChecked(expExpiry)
    local pct, alpha = Expiry.Pct(), math.floor(Expiry.Alpha() * 100 + 0.5)
    Cfg.SyncSlider(config.expiryPctSlider, pct, L.EXPIRY_PCT:format(pct), expExpiry)
    Cfg.SyncSlider(config.expiryAlphaSlider, alpha, L.EXPIRY_ALPHA:format(alpha), expExpiry)
    config.expConsCB:SetChecked(expCons)
    if config.conjureSlider then
        local t = Conjure.Threshold()
        Cfg.SyncSlider(config.conjureSlider, t, t > 0 and L.CONJURE_THRESHOLD:format(t) or L.CONJURE_OFF, expCons)
    end
    config.expWeaponCB:SetChecked(ExpOn("expWeaponItems"))
    config.expVariantCB:SetChecked(ExpOn("expVariantMenu"))
    local expTrack = ExpOn("expTracking")
    config.expTrackCB:SetChecked(expTrack)
    config.trackBtn:SetText(Tracking.ButtonText())
    config.expElixirCB:SetChecked(ExpOn("expElixirs"))
    if Elixir.dirty then Cfg.LayoutElixirs() end
    config.elixirEmpty:SetTextColor(ExpOn("expElixirs") and 0.6 or 0.4, ExpOn("expElixirs") and 0.6 or 0.4, 0.4)
    if expTrack then config.trackBtn:Enable() else config.trackBtn:Disable() end
    config.soundBtn:SetText(L.SOUND:format(Cfg.ValueText("SOUND_", db.sound)))
    config.styleBtn:SetText(L.STYLE:format(Cfg.ValueText("STYLE_NAME_", db.style)))
    config.iconsCB:SetChecked(db.iconsOnly)
    Cfg.SetCheckEnabled(config.iconsCB, Style.STYLES[db.style] ~= nil and Style.STYLES[db.style].iconsOnly)
    config.growBtn:SetText(L.GROW:format(db.growUp and L.GROW_UP or L.GROW_DOWN))
    config.keyText:SetText(L.KEY_LINE:format(L.KEY_NAME, Keybind.KeyText() or L.KEY_NONE))
    config.moveBtn:SetText(unlocked and L.LOCK or L.MOVE)
end

function Cfg.MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

-- Ausgegraut? (Experimental-Schalter aus bzw. Schurke mit aktivem Gift-Eintrag); 2. Wert = Statushinweis
function Cfg.Gate(e, expCons)
    if e.kind == "elixir" then return not ExpOn("expElixirs"), nil end
    if e.kind == "scroll" then return not ExpOn("expScrolls"), nil end
    if e.kind == "conjure" then return not expCons, nil end
    if e.weaponItems then
        if not ExpOn("expWeaponItems") then return true, nil end
        if e.poisonEntry and IsEnabled(e.poisonEntry) then return true, L.WEAPON_BY_POISON end
    end
    return false, nil
end

-- Eintrag-Zeile an Höhe y setzen (Klassenzeilen werden in RefreshConfig neu angeordnet)
function Cfg.PlaceEntryRow(w, y)
    w.cb:ClearAllPoints()
    w.cb:SetPoint("TOPLEFT", 16, y)
    w.status:ClearAllPoints()
    w.status:SetPoint("RIGHT", w.parent, "TOPLEFT", 424, y - 12)
end

function Cfg.ShowEntryRow(w, show)
    for _, obj in ipairs({ w.cb, w.icon, w.name, w.status }) do
        if show then obj:Show() else obj:Hide() end
    end
end

-- Klassenliste (Tab "Klassenbuffs"): Einträge mit hideUnknown (Verbrauchsgüter) erst zeigen,
-- wenn erlernt; alles darunter (config.below) rückt nach
function Cfg.LayoutClassRows()
    local y = Cfg.classTop
    for _, w in ipairs(Cfg.configRows) do
        if w.classRow then
            local show = not w.entry.hideUnknown or knownCache[w.entry.key] == true
            Cfg.ShowEntryRow(w, show)
            if show then
                Cfg.PlaceEntryRow(w, y)
                y = y - 26
            end
        end
    end
    config.below:ClearAllPoints()
    config.below:SetPoint("TOPLEFT", Cfg.classContent, "TOPLEFT", 0, y)
    config.below:SetSize(Cfg.WIDTH, Cfg.belowHeight)
    Cfg.classContent:SetSize(Cfg.WIDTH, -y + Cfg.belowHeight)
end

function Cfg.MakeEntryRow(parent, e, y)
    local w = { entry = e, parent = parent }
    w.cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    w.cb:SetSize(24, 24)
    w.cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if e.kind == "elixir" then
            cdb.elixirsWanted[e.item] = on or nil        -- Wunsch-Elixier (pro Charakter)
        elseif e.kind == "scroll" then
            cdb.scrollsOff[e.scrollType] = (not on) or nil   -- Rollen-Art aus (pro Charakter)
        else
            cdb.buffs[e.key] = on
        end
        NoteDeferred()
        Evaluate()
    end)
    w.icon = parent:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(20, 20)
    w.icon:SetPoint("LEFT", w.cb, "RIGHT", 4, 0)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    w.name:SetPoint("LEFT", w.icon, "RIGHT", 8, 0)
    w.name:SetJustifyH("LEFT")
    w.status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.status:SetJustifyH("RIGHT")
    Cfg.PlaceEntryRow(w, y)
    Cfg.configRows[#Cfg.configRows + 1] = w
    return w
end

-- Reagenz-Zeile: Icon, Name, Eingabefeld für die Schwelle (0-50), Status
function Cfg.MakeReagentRow(parent, e, y)
    local w = { entry = e }
    w.icon = parent:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(20, 20)
    w.icon:SetPoint("TOPLEFT", 22, y - 2)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    w.name:SetPoint("LEFT", w.icon, "RIGHT", 8, 0)
    w.name:SetWidth(190)
    w.name:SetJustifyH("LEFT")
    w.name:SetWordWrap(false)
    w.edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    w.edit:SetSize(30, 20)
    w.edit:SetPoint("TOPLEFT", 266, y - 2)
    w.edit:SetAutoFocus(false)
    w.edit:SetNumeric(true)
    w.edit:SetMaxLetters(2)
    w.edit:SetJustifyH("CENTER")
    -- Übernehmen bei Enter/Fokusverlust (auf 0-50 begrenzt), ESC verwirft die Eingabe
    w.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    w.edit:SetScript("OnEscapePressed", function(self) self.cancel = true; self:ClearFocus() end)
    w.edit:SetScript("OnEditFocusLost", function(self)
        local n = not self.cancel and tonumber(self:GetText())
        self.cancel = nil
        if n then
            cdb.reagents[e.item] = math.max(0, math.min(50, math.floor(n)))
            NoteDeferred()
            Evaluate()
        end
        self:SetText(tostring(ReagentThreshold(e.item)))
    end)
    w.status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.status:SetPoint("RIGHT", parent, "TOPLEFT", 424, y - 12)
    w.status:SetJustifyH("RIGHT")
    Cfg.reagentRows[#Cfg.reagentRows + 1] = w
end

function Cfg.MakeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

function Cfg.MakeCheck(parent, text, x, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(text)
    cb.label = fs
    cb:SetScript("OnClick", onClick)
    return cb
end

-- Schieberegler mit eigener Beschriftung rechts daneben; onChange(value) nur bei Nutzeränderung
-- (nicht während RefreshConfig die Werte setzt, Cfg.sliderSync)
function Cfg.MakeSlider(parent, name, x, y, minV, maxV, step, onChange)
    local ok, s = pcall(CreateFrame, "Slider", name, parent, "OptionsSliderTemplate")
    if not ok or not s then s = CreateFrame("Slider", name, parent, "BackdropTemplate") end
    if not s:GetThumbTexture() then
        -- ohne Vorlage: einfacher Regler aus Standard-Texturen
        s:SetOrientation("HORIZONTAL")
        if s.SetBackdrop then
            s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 } })
        end
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    -- Beschriftungen der Vorlage ausblenden (eigene Beschriftung s.label)
    for _, k in ipairs({ "Text", "Low", "High" }) do
        local fs = s[k] or _G[name .. k]
        if fs and fs.Hide then fs:Hide() end
    end
    s:SetSize(160, 17)
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.label:SetPoint("LEFT", s, "RIGHT", 12, 0)
    s:SetScript("OnValueChanged", function(_, v)
        if Cfg.sliderSync then return end
        onChange(math.floor(v / step + 0.5) * step)
    end)
    return s
end

-- Regler-Wert setzen, ohne onChange auszulösen; (de)aktivieren samt Beschriftung
function Cfg.SyncSlider(s, value, text, on)
    Cfg.sliderSync = true
    s:SetValue(value)
    Cfg.sliderSync = false
    s.label:SetText(text)
    if on then
        if s.Enable then s:Enable() end
        s:SetAlpha(1)
        s.label:SetTextColor(1, 1, 1)
    else
        if s.Disable then s:Disable() end
        s:SetAlpha(0.5)
        s.label:SetTextColor(0.5, 0.5, 0.5)
    end
end

-- Cfg.configCanvas: Seite unter "Pardona's Addons" in den Einstellungen (nil = eigenes Fenster)

---------------------------------------------------------------------------
-- Einstellungsseite mit Tabs: Tab-Leiste oben, je Tab eine eigene Scrollfläche.
--   Cfg.TAB_ORDER: { Key, Text-Schlüssel }; "group" nur bei Klassen mit Gruppenbuffs
--   Cfg.tabs[key] = { key, button, scroll, content }; Cfg.tabList in Reihenfolge
--   db.cfgTab: zuletzt gewählter Tab (beim Öffnen wieder gezeigt)
-- Tab-Vorlage: erste, die der Client kennt (Cfg.TAB_TEMPLATES, per pcall); sonst normale Knöpfe
-- (gewählter Tab = gesperrt). Funktion und Speicherung der Einstellungen sind unabhängig davon.
---------------------------------------------------------------------------
Cfg.TAB_ORDER = {
    { "display", "TAB_DISPLAY" }, { "class", "TAB_CLASS" }, { "other", "TAB_OTHER" }, { "group", "TAB_GROUP" },
}
Cfg.TAB_TEMPLATES = { "PanelTopTabButtonTemplate", "TabButtonTemplate", "PanelTabButtonTemplate",
    "CharacterFrameTabButtonTemplate" }
Cfg.WIDTH = 440   -- Breite des Inhalts eines Tabs (Status rechtsbündig bei 424)
Cfg.tabs, Cfg.tabList = {}, {}
Cfg.TAB_X, Cfg.TAB_GAP = 8, 0   -- Abstand des ersten Tabs vom Kastenrand, Abstand zwischen Tabs
-- Inhaltskasten unter der Tab-Leiste: erste bekannte Vorlage für eingelassene Kästen, sonst eigener
-- Rand (BackdropTemplate mit Tooltip-Rand; Größe fest über die Anker am Einstellungsrahmen)
Cfg.INSET_TEMPLATES = { "InsetFrameTemplate", "InsetFrameTemplate3", "InsetFrameTemplate2" }

-- Kasten mit Rand und dunklem, nahezu deckendem Hintergrund (Cfg.insetTemplate = genutzte Vorlage)
function Cfg.MakeInset(parent)
    local f
    for _, tpl in ipairs(Cfg.INSET_TEMPLATES) do
        local ok, fr = pcall(CreateFrame, "Frame", nil, parent, tpl)
        if ok and fr and (fr.NineSlice or fr.Bg) then
            f, Cfg.insetTemplate = fr, tpl
            break
        elseif ok and fr then
            fr:Hide()
        end
    end
    if not f then
        Cfg.insetTemplate = "BackdropTemplate"
        f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        if f.SetBackdrop then
            f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        end
    end
    -- über dem Hintergrund der Vorlage, unter ihrem Rand (NineSlice ist ein eigener Frame darüber)
    f.darkBg = f:CreateTexture(nil, "BACKGROUND", nil, 7)
    f.darkBg:SetPoint("TOPLEFT", 3, -3)
    f.darkBg:SetPoint("BOTTOMRIGHT", -3, 3)
    f.darkBg:SetColorTexture(0.04, 0.04, 0.05, 0.88)
    return f
end

-- Breite eines Tab-Knopfs nach Text (maxW = Obergrenze, nil = natürliche Breite)
function Cfg.SizeTab(b, maxW)
    if Cfg.tabTemplate ~= "UIPanelButtonTemplate" and type(PanelTemplates_TabResize) == "function" then
        if pcall(PanelTemplates_TabResize, b, 0, nil, nil, maxW) then return end
    end
    local fs = b:GetFontString()
    local w = (fs and fs:GetStringWidth() or 86) + 24
    if maxW and w > maxW then w = maxW end
    b:SetWidth(w)
end

-- Alle Tabs in eine Reihe: zu breite Tabs schmaler machen (Text wird gekürzt) statt umzubrechen
function Cfg.FitTabs()
    local list, inset = Cfg.tabList, Cfg.inset
    if #list == 0 or not inset then return end
    local avail = (inset:GetWidth() or 0) - 2 * Cfg.TAB_X
    if avail <= 0 then return end
    local total = Cfg.TAB_GAP * (#list - 1)
    for _, t in ipairs(list) do
        Cfg.SizeTab(t.button)
        total = total + t.button:GetWidth()
    end
    if total <= avail then return end
    -- Obergrenze so, dass schmale Tabs bleiben und die breiten sich den Rest teilen
    local maxW = (avail - Cfg.TAB_GAP * (#list - 1)) / #list
    for _ = 1, #list do
        local rest, wide = avail - Cfg.TAB_GAP * (#list - 1), 0
        for _, t in ipairs(list) do
            local w = t.button:GetWidth()
            if w <= maxW then rest = rest - w else wide = wide + 1 end
        end
        if wide == 0 then break end
        local m = math.floor(rest / wide)
        if m <= maxW then maxW = m; break end
        maxW = m
    end
    for _, t in ipairs(list) do
        if t.button:GetWidth() > maxW then Cfg.SizeTab(t.button, maxW) end
    end
end

-- Farben des Kennzeichens "(beta)" (die Texte BETA_TAG/BETA_FOOTER selbst sind ohne Farbcodes)
Cfg.BETA_COLOR, Cfg.BETA_DIM, Cfg.BETA_FOOTER_COLOR = "|cffff9933", "|cff806040", "|cffcc8844"

-- Text eines experimentellen Schalters: "<Text> (beta)", Kennzeichen orange (on == false: gedämpft)
function Cfg.BetaText(text, on)
    return text .. " " .. (on == false and Cfg.BETA_DIM or Cfg.BETA_COLOR) .. L.BETA_TAG .. "|r"
end

-- Häkchen eines experimentellen Schalters (Cfg.SetCheckEnabled dämpft das Kennzeichen mit)
function Cfg.MakeBetaCheck(parent, text, x, y, onClick)
    local cb = Cfg.MakeCheck(parent, Cfg.BetaText(text), x, y, onClick)
    cb.betaBase = text
    return cb
end

-- Fußzeile "(beta) = experimentell …" unten in Tabs mit Beta-Funktionen; Rückgabe: neues y
function Cfg.AddFooter(p, y)
    local fs = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 16, y - 10)
    fs:SetWidth(Cfg.WIDTH - 32)
    fs:SetJustifyH("LEFT")
    fs:SetText(Cfg.BETA_FOOTER_COLOR .. L.BETA_FOOTER .. "|r")
    return y - 40, fs
end

-- Verschiebe-Modus an/aus (Knopf, /br move, /br lock, Rechtsklick-Menü); nicht im Kampf
function Cfg.SetMoveMode(on)
    if InCombatLockdown() then Print(L.COMBAT); return end
    unlocked = on and true or false
    if not unlocked then wipe(shownKeys); Display.ShowRows({}) end
    Evaluate()
    RefreshConfig()
end

-- Scrollfläche mit Inhaltsframe (Breite Cfg.WIDTH); ohne Vorlage Scrollen nur per Mausrad
function Cfg.MakeScroll(parent, name)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    if not ok or not scroll then
        scroll = CreateFrame("ScrollFrame", name, parent)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local v = self:GetVerticalScroll() - delta * 40
            v = math.max(0, math.min(v, self:GetVerticalScrollRange()))
            self:SetVerticalScroll(v)
        end)
    end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(Cfg.WIDTH, 10)
    scroll:SetScrollChild(content)
    return scroll, content
end

-- Tab-Knopf aus der ersten verfügbaren Vorlage (Cfg.tabTemplate = genutzte Vorlage)
function Cfg.MakeTabButton(parent, index, text)
    local name = "BuffReminderConfigTab" .. index
    local b
    for _, tpl in ipairs(Cfg.TAB_TEMPLATES) do
        if Cfg.tabTemplate == nil or Cfg.tabTemplate == tpl then
            local ok, f = pcall(CreateFrame, "Button", name, parent, tpl)
            if ok and f and f.GetFontString and f:GetFontString() then
                b, Cfg.tabTemplate = f, tpl
                break
            elseif ok and f then
                f:Hide()
            end
        end
    end
    if not b then
        Cfg.tabTemplate = "UIPanelButtonTemplate"
        b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        b:SetSize(110, 22)
    end
    b:SetID(index)
    b:SetText(text)
    Cfg.SizeTab(b)
    local w = b:GetWidth()
    if type(w) ~= "number" or w < 40 then b:SetWidth(110) end
    return b
end

-- neuen Tab anlegen; Rückgabe: Inhaltsframe
function Cfg.NewTab(key, textKey)
    local index = #Cfg.tabList + 1
    local t = { key = key }
    t.button = Cfg.MakeTabButton(config, index, L[textKey])
    t.button:ClearAllPoints()
    -- Tabs stehen auf der Oberkante des Kastens (echte Tab-Vorlagen überlappen 2 px, damit der
    -- aktive Tab in den Kasten übergeht); Ebene über dem Kasten
    local real = Cfg.tabTemplate ~= "UIPanelButtonTemplate"
    Cfg.TAB_GAP = real and 0 or 4
    if index == 1 then
        t.button:SetPoint("BOTTOMLEFT", Cfg.inset, "TOPLEFT", Cfg.TAB_X, real and -2 or 2)
    else
        t.button:SetPoint("LEFT", Cfg.tabList[index - 1].button, "RIGHT", Cfg.TAB_GAP, 0)
    end
    t.button:SetFrameLevel(Cfg.inset:GetFrameLevel() + 5)
    t.button:SetScript("OnClick", function() Cfg.SelectTab(key) end)
    t.scroll, t.content = Cfg.MakeScroll(Cfg.inset, "BuffReminderConfigScroll" .. index)
    t.scroll:SetPoint("TOPLEFT", Cfg.inset, "TOPLEFT", 8, -8)
    t.scroll:SetPoint("BOTTOMRIGHT", Cfg.inset, "BOTTOMRIGHT", -28, 8)
    Cfg.tabs[key] = t
    Cfg.tabList[index] = t
    return t.content
end

-- Tab zeigen (unbekannter Key: erster Tab) und merken
function Cfg.SelectTab(key)
    if not Cfg.tabs[key] then key = Cfg.tabList[1] and Cfg.tabList[1].key end
    if not key then return end
    db.cfgTab = key
    local real = Cfg.tabTemplate ~= "UIPanelButtonTemplate"
    for _, t in ipairs(Cfg.tabList) do
        local on = t.key == key
        if on then t.scroll:Show() else t.scroll:Hide() end
        local fn = on and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
        local ok = real and type(fn) == "function" and pcall(fn, t.button)
        if not ok then
            if on then t.button:Disable() else t.button:Enable() end
        end
    end
    RefreshConfig()
end

-- Inhaltshöhe eines Tabs setzen
function Cfg.FinishTab(p, y)
    p:SetSize(Cfg.WIDTH, -y + 10)
end

-- Tab "Anzeige": Knopfreihe, Grundeinstellungen, Stil, Ton, Taste, Warnung vor Ablauf (beta)
function Cfg.BuildDisplayTab()
    local p = Cfg.NewTab("display", "TAB_DISPLAY")
    local y = -8
    config.moveBtn = Cfg.MakeButton(p, L.MOVE, 100)
    config.moveBtn:SetPoint("TOPLEFT", 16, y)
    config.moveBtn:SetScript("OnClick", function() Cfg.SetMoveMode(not unlocked) end)
    local testBtn = Cfg.MakeButton(p, L.TEST, 80)
    testBtn:SetPoint("LEFT", config.moveBtn, "RIGHT", 4, 0)
    testBtn:SetScript("OnClick", StartTest)
    local unmuteBtn = Cfg.MakeButton(p, L.UNMUTE, 140)
    unmuteBtn:SetPoint("LEFT", testBtn, "RIGHT", 4, 0)
    unmuteBtn:SetScript("OnClick", function()
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    end)
    y = y - 36

    config.enabledCB = Cfg.MakeCheck(p, L.ENABLED, 16, y, function(self)
        db.enabled = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 26
    config.castCB = Cfg.MakeCheck(p, L.CLICKCAST, 16, y, function(self)
        db.clickCast = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 32

    -- Stil von Warnanzeige und Rechtsklick-Menü; "Nur Icons" nur bei Compact
    config.styleBtn = Cfg.MakeButton(p, "", 160)
    config.styleBtn:SetPoint("TOPLEFT", 18, y)
    config.styleBtn:SetScript("OnClick", function()
        local idx = 1
        for i, k in ipairs(Style.STYLE_ORDER) do if k == db.style then idx = i end end
        db.style = Style.STYLE_ORDER[idx % #Style.STYLE_ORDER + 1]
        NoteDeferred()
        Display.ApplyStyle()
        Evaluate()
        RefreshConfig()
    end)
    config.iconsCB = Cfg.MakeCheck(p, L.ICONS_ONLY, 190, y + 1, function(self)
        db.iconsOnly = self:GetChecked() and true or false
        NoteDeferred()
        Display.ApplyStyle()
        Evaluate()
    end)
    y = y - 30

    -- Wachstumsrichtung: neue Warnungen unterhalb (Standard) oder oberhalb des Ankers
    config.growBtn = Cfg.MakeButton(p, "", 260)
    config.growBtn:SetPoint("TOPLEFT", 18, y)
    config.growBtn:SetScript("OnClick", function()
        db.growUp = not db.growUp
        NoteDeferred()
        Display.ApplyStyle()   -- ordnet die Zeilen neu an (im Kampf erst danach)
        Evaluate()
        RefreshConfig()
    end)
    y = y - 30

    config.soundBtn = Cfg.MakeButton(p, "", 160)
    config.soundBtn:SetPoint("TOPLEFT", 18, y)
    config.soundBtn:SetScript("OnClick", function()
        local idx = 1
        for i, k in ipairs(SOUND_ORDER) do if k == db.sound then idx = i end end
        db.sound = SOUND_ORDER[idx % #SOUND_ORDER + 1]
        PlayAlertSound()
        RefreshConfig()
    end)
    y = y - 32

    -- Tastenbelegung "Oberste Warnung auslösen": aktuelle Taste + wo sie belegt wird
    config.keyText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    config.keyText:SetPoint("TOPLEFT", 20, y)
    config.keyText:SetJustifyH("LEFT")
    y = y - 14
    local keyWhere = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keyWhere:SetPoint("TOPLEFT", 20, y)
    keyWhere:SetJustifyH("LEFT")
    keyWhere:SetText(L.KEY_WHERE)
    y = y - 26

    -- Warnung vor Ablauf (beta) + Detail-Regler (Schwelle, Transparenz)
    config.expExpiryCB = Cfg.MakeBetaCheck(p, L.EXP_EXPIRY, 16, y, function(self)
        db.expExpiry = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 30
    config.expiryPctSlider = Cfg.MakeSlider(p, "BuffReminderExpiryPct", 40, y, 5, 50, 1, function(v)
        db.expiryPct = v
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    config.expiryAlphaSlider = Cfg.MakeSlider(p, "BuffReminderExpiryAlpha", 40, y, 20, 100, 5, function(v)
        db.expiryAlpha = v / 100
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 24
    Cfg.FinishTab(p, Cfg.AddFooter(p, y))
end

-- Tab "Klassenbuffs": Liste (mit Talent-Hinweisen) + Variantenmenü (beta). Alles unter der Liste
-- liegt in config.below, das Cfg.LayoutClassRows unter die sichtbaren Klassenzeilen rückt.
function Cfg.BuildClassTab()
    local p = Cfg.NewTab("class", "TAB_CLASS")
    Cfg.classContent = p
    local y = -8
    Cfg.MakeHeader(p, L.CLASS_SECTION:format(UnitClass("player") or "?"), y)
    y = y - 22
    if #classEntries == 0 then
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", 20, y)
        fs:SetText(L.NO_CLASS)
        y = y - 20
    end
    Cfg.classTop = y
    for _, e in ipairs(classEntries) do
        Cfg.MakeEntryRow(p, e, y).classRow = true
    end
    local b = CreateFrame("Frame", nil, p)
    config.below = b
    local by = -8
    -- Variantenmenü per Rechtsklick (Aura, Siegel, Aspekt, Rüstung, Schild, Waffenverzauberung)
    config.expVariantCB = Cfg.MakeBetaCheck(b, L.EXP_VARIANTMENU, 16, by, function(self)
        db.expVariantMenu = self:GetChecked() and true or false
        if menu:IsShown() then menu:Hide() end   -- nächstes Öffnen mit/ohne Varianten
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    by = by - 24
    Cfg.belowHeight = -Cfg.AddFooter(b, by) + 10
end

-- Tab "Weitere Buffs": Liste + "Nur in Instanzen", Waffen-Items, Verbrauchsgüter,
-- Reagenzien und Verfolgung (alle beta) mit ihren Detail-Einstellungen
function Cfg.BuildOtherTab()
    local p = Cfg.NewTab("other", "TAB_OTHER")
    local y = -8
    for _, e in ipairs(GENERAL_BUFFS) do
        Cfg.MakeEntryRow(p, e, y)
        y = y - 26
    end
    y = y - 4
    config.instCB = Cfg.MakeCheck(p, L.INSTANCE_ONLY, 16, y, function(self)
        db.instanceOnly = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 32

    -- Steine, Öle, Gifte per Klick
    config.expWeaponCB = Cfg.MakeBetaCheck(p, L.EXP_WEAPONITEMS, 16, y, function(self)
        db.expWeaponItems = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26

    -- Klassen-Verbrauchsgüter (Einträge stehen in der Klassenliste); Schwelle für gezaubertes
    -- Essen/Wasser nur bei Klassen mit solchen Einträgen (Magier)
    config.expConsCB = Cfg.MakeBetaCheck(p, L.EXP_CONSUMABLES, 16, y, function(self)
        db.expConsumables = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    local hasConjureSum = false
    for _, e in ipairs(classEntries) do
        if e.kind == "conjure" and e.conj.mode == "sum" then hasConjureSum = true end
    end
    if hasConjureSum then
        y = y - 4
        config.conjureSlider = Cfg.MakeSlider(p, "BuffReminderConjureThreshold", 40, y, 0, 60, 1, function(v)
            db.conjureThreshold = v
            NoteDeferred()
            Evaluate()
            RefreshConfig()
        end)
        y = y - 28
    end

    -- Reagenzien-Warnung; Schwellenwerte nur für die Reagenzien der eigenen Klasse
    config.expReagCB = Cfg.MakeBetaCheck(p, L.EXP_REAGENTS, 16, y, function(self)
        db.expReagents = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    if #reagentEntries > 0 then
        config.reagentHint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        config.reagentHint:SetPoint("TOPRIGHT", p, "TOPLEFT", 424, y - 2)
        config.reagentHint:SetJustifyH("RIGHT")
        config.reagentHint:SetText(L.REAGENT_HINT)
        y = y - 18
        for _, e in ipairs(reagentEntries) do
            Cfg.MakeReagentRow(p, e, y)
            y = y - 26
        end
    end

    -- Verfolgungs-Erinnerung + Umschalt-Knopf (gelernte Verfolgungen und "keine")
    y = y - 4
    config.expTrackCB = Cfg.MakeBetaCheck(p, L.EXP_TRACKING, 16, y, function(self)
        db.expTracking = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 28
    config.trackBtn = Cfg.MakeButton(p, "", 240)
    config.trackBtn:SetPoint("TOPLEFT", 40, y)
    config.trackBtn:SetScript("OnClick", function()
        Tracking.Cycle()
        RefreshKnown()
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 30

    -- Wunsch-Elixiere: Schalter + Liste aller bekannten Elixiere (Taschen + Merkliste); die Liste
    -- wächst, wenn neue Elixiere in die Taschen kommen (Cfg.LayoutElixirs rückt die Fußzeile nach)
    config.expElixirCB = Cfg.MakeBetaCheck(p, L.EXP_ELIXIRS, 16, y, function(self)
        db.expElixirs = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    Cfg.otherContent, Cfg.elixirTop, Cfg.elixirRows = p, y, {}
    config.elixirEmpty = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    config.elixirEmpty:SetText(L.ELIXIRS_EMPTY)
    local _, footer = Cfg.AddFooter(p, y)
    Cfg.otherFooter = footer
    Cfg.LayoutElixirs()
end

-- Elixier-Liste im Tab "Weitere Buffs" (nach Name) anordnen; Fußzeile und Inhaltshöhe folgen
function Cfg.LayoutElixirs()
    local p = Cfg.otherContent
    if not p then return end
    local y = Cfg.elixirTop
    local list = Elixir.List()
    for _, e in ipairs(list) do
        local w = Cfg.elixirRows[e.key]
        if not w then
            w = Cfg.MakeEntryRow(p, e, y)
            Cfg.elixirRows[e.key] = w
        end
        Cfg.PlaceEntryRow(w, y)
        y = y - 26
    end
    if #list == 0 then
        config.elixirEmpty:ClearAllPoints()
        config.elixirEmpty:SetPoint("TOPLEFT", 44, y - 2)
        config.elixirEmpty:Show()
        y = y - 20
    else
        config.elixirEmpty:Hide()
    end
    Cfg.otherFooter:ClearAllPoints()
    Cfg.otherFooter:SetPoint("TOPLEFT", 16, y - 10)
    Cfg.FinishTab(p, y - 40)
    Elixir.dirty = false
end

-- Anzahl der Rollen einer Art in den Taschen (Rollen folgen in Scroll.Count)
function Cfg.ScrollCount()
    return 0
end

-- Tab "Gruppe" (nur Klassen mit Gruppen-Buffs: Priester, Magier, Druide, Paladin)
function Cfg.BuildGroupTab(hasBlessings)
    local p = Cfg.NewTab("group", "TAB_GROUP")
    local y = -8
    config.expGroupCB = Cfg.MakeBetaCheck(p, L.EXP_GROUP, 16, y, function(self)
        db.expGroup = self:GetChecked() and true or false
        if not GroupFeatureOn() then wipe(Group.groupState) else Group.MarkGroupDirty() end
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    config.groupCB = Cfg.MakeCheck(p, L.GROUP_CHECK, 36, y, function(self)
        db.groupCheck = self:GetChecked() and true or false
        if not GroupFeatureOn() then wipe(Group.groupState) else Group.MarkGroupDirty() end
        NoteDeferred()
        Evaluate()
    end)
    y = y - 30
    config.groupModeBtn = Cfg.MakeButton(p, "", 220)
    config.groupModeBtn:SetPoint("TOPLEFT", 40, y)
    config.groupModeBtn:SetScript("OnClick", function()
        local idx = 1
        for i, k in ipairs(GROUP_MODE_ORDER) do if k == db.groupMode then idx = i end end
        db.groupMode = GROUP_MODE_ORDER[idx % #GROUP_MODE_ORDER + 1]
        Group.MarkGroupDirty()
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 30
    -- Segen des Paladins in den Gruppenbuffs (nur Paladine; aus, solange Pally Power geladen ist)
    if hasBlessings then
        config.blessCB = Cfg.MakeBetaCheck(p, L.EXP_BLESSINGS, 36, y, function(self)
            db.expBlessings = self:GetChecked() and true or false
            wipe(Group.groupState)
            Group.MarkGroupDirty()
            NoteDeferred()
            Evaluate()
            RefreshConfig()
        end)
        y = y - 22
        config.blessNote = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        config.blessNote:SetPoint("TOPLEFT", 64, y)
        config.blessNote:SetJustifyH("LEFT")
        y = y - 16
    end
    Cfg.FinishTab(p, Cfg.AddFooter(p, y))
end

local function BuildConfig()
    if Cfg.configCanvas then
        config = CreateFrame("Frame", "BuffReminderConfig", Cfg.configCanvas)
        config:SetPoint("TOPLEFT", 0, -4)
        config:SetPoint("BOTTOMRIGHT", 0, 4)
    else
        -- Fallback ohne Settings-API: eigenständiges Fenster
        config = CreateFrame("Frame", "BuffReminderConfig", UIParent, "BackdropTemplate")
        config:SetSize(Cfg.WIDTH + 40, 560)
        config:SetFrameStrata("DIALOG")
        config:SetPoint("CENTER")
        config:SetClampedToScreen(true)
        config:SetMovable(true)
        config:EnableMouse(true)
        config:RegisterForDrag("LeftButton")
        config:SetScript("OnDragStart", config.StartMoving)
        config:SetScript("OnDragStop", config.StopMovingOrSizing)
        config:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        tinsert(UISpecialFrames, "BuffReminderConfig")

        local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
    end

    local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.TITLE)

    -- Inhaltskasten über die volle Breite bis unten; darüber die Tab-Leiste
    Cfg.inset = Cfg.MakeInset(config)
    Cfg.inset:SetPoint("TOPLEFT", config, "TOPLEFT", 8, -74)
    Cfg.inset:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -8, 6)

    Cfg.BuildDisplayTab()
    Cfg.BuildClassTab()
    Cfg.BuildOtherTab()
    -- Tab "Gruppe" nur für Klassen mit Gruppen-Buffs
    local hasGroup, hasBlessings = false, false
    for _, e in ipairs(classEntries) do
        if e.groupIds or e.groupByVariant then hasGroup = true end
        if e.groupByVariant then hasBlessings = true end
    end
    if hasGroup then Cfg.BuildGroupTab(hasBlessings) end

    Cfg.LayoutClassRows()
    -- Tab-Breiten an die Seitenbreite anpassen (auch nach dem OnShow der Tab-Vorlagen)
    Cfg.inset:SetScript("OnSizeChanged", function() Cfg.FitTabs() end)
    config:SetScript("OnShow", function()
        Cfg.FitTabs()
        C_Timer.After(0, Cfg.FitTabs)
        RefreshConfig()
    end)
    Cfg.FitTabs()
    Cfg.SelectTab(db.cfgTab)
    if not Cfg.configCanvas then config:Hide() end
end

local function ToggleConfig()
    -- Einstellungsseite unter "Pardona's Addons"; ohne Settings-API eigenes Fenster
    if Cfg.configCanvas then
        LP:OpenSettings(PARDONA_ID)
        return
    end
    if not config then BuildConfig() end
    if config:IsShown() then config:Hide() else config:Show() end
end

---------------------------------------------------------------------------
-- LibPardona: gemeinsamer Minimap-Button, Addon-Fach, Einstellungs-Kategorie
---------------------------------------------------------------------------
-- Kurzstatus; nil im Kampf oder solange der Zustand unbekannt ist
local function PardonaStatus()
    if not db or not ready or warnCount == nil or warnCount < 0 or InCombatLockdown() then return nil end
    if warnCount == 0 then return L.STATUS_OK end
    if warnCount == 1 then return L.STATUS_ONE end
    return L.STATUS_MANY:format(warnCount)
end

-- Erst nach ADDON_LOADED aufrufen (db muss geladen sein)
local function RegisterPardona()
    if not LP then return end
    if type(db.pardona) ~= "table" then db.pardona = {} end
    LP:RegisterAddon(PARDONA_ID, {
        name    = L.TITLE,
        addon   = "PardonasBuffReminder",
        icon    = "Interface\\AddOns\\PardonasBuffReminder\\Textures\\Icon",
        db      = db.pardona,
        onClick = function() ToggleConfig() end,
        status  = PardonaStatus,
        -- einmalig: Position/Sichtbarkeit des früheren eigenen Minimap-Buttons übernehmen
        -- (die alten Felder minimapAngle/minimapHide bleiben in der DB stehen)
        migrate = function(pdb)
            if db.minimapAngle == nil and db.minimapHide == nil then return end
            pdb.minimap = {
                hide  = db.minimapHide == true,
                angle = type(db.minimapAngle) == "number" and db.minimapAngle % 360 or nil,
            }
        end,
    })
end

-- Nach PLAYER_LOGIN aufrufen (Klassen-/Reagenzien-Einträge müssen feststehen);
-- der Inhalt wird erst beim ersten Öffnen gebaut.
local function RegisterPardonaSettings()
    if not LP or config then return end
    local canvas = CreateFrame("Frame", "BuffReminderSettingsCanvas")
    canvas:Hide()
    local category = LP:RegisterSettingsCanvas(PARDONA_ID, canvas, L.SETTINGS_NAME)
    if not category then return end
    Cfg.configCanvas = canvas
    canvas:SetScript("OnShow", function()
        if not config then BuildConfig() end
        RefreshConfig()
    end)
end

-- /br minimap: gemeinsamen Pardona-Button ein-/ausblenden (gilt für alle Pardona-Addons)
local function TogglePardonaMinimap()
    if LP then LP:ToggleMinimap() end
end

---------------------------------------------------------------------------
-- Demo-Modus (versteckt): nur mit BuffReminderDB.demo == true gibt es /br demo und /br demo shot.
-- Beispielzeilen für Bilder (CurseForge/Wago), unabhängig von Klasse, Stufe und Taschen. Sie
-- laufen über den normalen Anzeigeweg (ShowRows -> Demo.FillRow), aber ohne secure Aktion;
-- Evaluate überschreibt die Anzeige nicht, solange Demo.active gilt. Kein Eintrag in Hilfe,
-- README oder Einstellungen; /br reset lässt db.demo stehen.
--   Demo.ROWS : Motive; spell/item liefern Name und Icon (immer aus dem Client),
--               label = L-Schlüssel wie beim echten Eintrag (z. B. MAGE_ARMOR)
--   Demo.FOOD : Beispiel-Items des Essens-Menüs (aus Items.FOOD)
--   Demo.SHOTS: Motive des Screenshot-Laufs (Demo.BuildShots)
---------------------------------------------------------------------------
Demo.GROUP_NAMES = "Thrall, Jaina, Uther"   -- Beispielnamen der Gruppen-Zeile
Demo.ROWS = {
    { key = "class",    spell = 1459, hint = "HINT_CAST" },                                    -- Arkane Intelligenz
    { key = "armor",    spell = 7302, label = "ARMOR", variantOf = "MAGE", hint = "HINT_CAST_CHOOSE", menu = "variant" },
    { key = "food",     spell = 19705, hintItem = 13931, menu = "food" },                      -- Well Fed
    { key = "flask",    item = 13510, label = "FLASK", hintItem = 13510 },                      -- Fläschchen der Titanen
    { key = "weapon",   item = 20749, label = "WEAPON_MH", plain = true, hintItem = 20749 },    -- Brillantes Zauberöl
    { key = "group",    spell = 1243, group = 3, hint = "HINT_GROUP" },                         -- Machtwort: Seelenstärke
    { key = "reagent",  item = 17028, count = 3, hint = "HINT_MUTE" },                          -- Heilige Kerze
    { key = "tracking", spell = 2580, track = true, hint = "HINT_TRACK" },                      -- Mineraliensuche
    { key = "expiry",   spell = 1126, expiry = "1:45", hint = "HINT_CAST" },                    -- Mal der Wildnis
}
Demo.FOOD = {
    { id = 13931, count = 12, cat = "SpellDamage", xp = true, fav = true },
    { id = 18254, count = 4,  cat = "Intellect" },
    { id = 12216, count = 6,  cat = "Intellect" },
    { id = 3729,  count = 9,  cat = "Stamina" },
}
Demo.VARIANT_LAST = "ice"   -- im Variantenmenü als "zuletzt genutzt" markiert
Demo.LOAD_WAIT = 3          -- höchstens so lange auf Item-/Spell-Daten warten (Sek.)
Demo.SHOT_DELAY = 1.5       -- Wartezeit vor jedem Bild (Sek.)
Demo.SHOT_STYLES = {        -- { Stil, Nur Icons, Name im Dateinamen }
    { "pardona", false, "pardona" }, { "classic", false, "classic" },
    { "compact", false, "compact" }, { "compact", true, "compact-icons" },
}
Demo.SHOT_MENUS = { { "list" }, { "food-menu", "food" }, { "variant-menu", "variant" } }
Demo.SETTINGS_TABS = {      -- { Tab-Key (Cfg.TAB_ORDER), Name im Dateinamen }
    { "display", "display" }, { "class", "class-buffs" }, { "other", "other-buffs" }, { "group", "group" },
}

function Demo.BuildShots()
    local list = {}
    for _, s in ipairs(Demo.SHOT_STYLES) do
        for _, m in ipairs(Demo.SHOT_MENUS) do
            list[#list + 1] = { name = s[3] .. "-" .. m[1], style = s[1], icons = s[2], menu = m[2] }
        end
    end
    -- je Tab der Einstellungen ein Bild (settings-group nur, wenn der Tab existiert)
    for _, t in ipairs(Demo.SETTINGS_TABS) do
        list[#list + 1] = { name = "settings-" .. t[2], settings = t[1], ui = true }
    end
    return list
end
Demo.SHOTS = Demo.BuildShots()

-- Eintrag für ein Motiv (Name/Icon aus dem Client; Demo.Show lässt unbekannte Motive aus)
function Demo.Entry(d)
    local label = (d.variantOf and Variant.GroupLabel(d.variantOf, d.key, d.label)) or (d.label and L[d.label]) or (d.spell and SpellName(d.spell)) or (d.item and ItemName(d.item)) or "?"
    local icon = (d.spell and SpellIcon(d.spell)) or (d.item and ItemIcon(d.item)) or FALLBACK_ICON
    return { key = "demo_" .. d.key, demo = d, demoLabel = label, demoIcon = icon,
        itemKind = d.menu == "food" and "food" or nil, demoVariants = d.menu == "variant" }
end

-- Zeile wie die echte Warnung gestalten (aus ShowRows; nur außerhalb des Kampfes)
function Demo.FillRow(r, e, st)
    local d, label = e.demo, e.demoLabel
    Display.SetRowAction(r, nil)
    Display.SetRowLines(r, d.group ~= nil)
    local status, text, right = "missing", L.MISSING:format(label), L.SHORT_MISSING
    if d.group then
        text, right = L.GROUP_MISSING:format(label, d.group), ""
        r.names:SetText(Demo.GROUP_NAMES)
    elseif d.count then
        status, text, right = "low", L.REAGENT_LOW:format(label, d.count), ""
    elseif d.track then
        text, right = L.TRACK_OFF:format(label), L.SHORT_OFF
    elseif d.expiry then
        status, text, right = "expiring", L.EXPIRES:format(label, d.expiry), ""
    elseif d.plain then
        text = label
    end
    if st.rightText and right ~= "" then
        text = label
        r.right:SetText(right)
    end
    Display.SetRowStatus(r, status)
    r.text:SetText(text)
    Display.SetRowHint(r, d.hintItem and L.HINT_ITEM:format(ItemName(d.hintItem)) or L[d.hint])
end

-- Essens-Menü: Beispiel-Items (erstes = beste Wahl mit XP-Abzeichen und Stern)
-- Kennt der Client den Zauber bzw. das Item? (Name und Icon vorhanden; nach dem Vorladen)
function Demo.SpellKnown(id)
    return SpellName(id) ~= nil and SpellIcon(id) ~= nil
end

function Demo.ItemKnown(id)
    return Items.ItemLevels(id) ~= nil and ItemIcon(id) ~= nil
end

-- Motiv zeigbar? Alle Zauber/Items des Motivs müssen dem Client bekannt sein
function Demo.RowKnown(d)
    if d.spell and not Demo.SpellKnown(d.spell) then return false end
    if d.item and not Demo.ItemKnown(d.item) then return false end
    if d.hintItem and not Demo.ItemKnown(d.hintItem) then return false end
    return true
end

-- Essens-Menü: Beispiel-Items (erstes = beste Wahl mit XP-Abzeichen und Stern); unbekannte weglassen
function Demo.FoodChoices()
    local list = {}
    for _, c in ipairs(Demo.FOOD) do
        if Demo.ItemKnown(c.id) then
            list[#list + 1] = { id = c.id, count = c.count, cat = c.cat, xp = c.xp == true, fav = c.fav == true }
        end
    end
    return list
end

-- Variantenmenü: Magier-Rüstungen aus CAST_DATA, unabhängig davon, ob gelernt; nur Zauber,
-- die der Client kennt (z. B. fehlt Molten Armor 30482, TBC, in Forever)
function Demo.VariantChoices()
    local list = {}
    for _, v in ipairs(CAST_DATA.MAGE.armor.variants) do
        local id = v.castIds[1]
        if Demo.SpellKnown(id) then
            list[#list + 1] = { spell = id, vkey = v.key, name = SpellName(id), icon = SpellIcon(id),
                last = v.key == Demo.VARIANT_LAST }
        end
    end
    return list
end

function Demo.Ids()
    local spells, items = {}, {}
    for _, d in ipairs(Demo.ROWS) do
        if d.spell then spells[#spells + 1] = d.spell end
        if d.item then items[#items + 1] = d.item end
        if d.hintItem then items[#items + 1] = d.hintItem end
    end
    for _, c in ipairs(Demo.FOOD) do items[#items + 1] = c.id end
    for _, v in ipairs(CAST_DATA.MAGE.armor.variants) do spells[#spells + 1] = v.castIds[1] end
    return spells, items
end

function Demo.DataReady(spells, items)
    for _, id in ipairs(spells) do
        if not SpellName(id) or not SpellIcon(id) then return false end
    end
    for _, id in ipairs(items) do
        if not Items.ItemLevels(id) or not ItemIcon(id) then return false end
    end
    return true
end

-- Item-/Spell-Daten anfordern; done() sobald alles da ist, spätestens nach LOAD_WAIT Sek.
function Demo.Preload(done)
    local spells, items = Demo.Ids()
    for _, id in ipairs(items) do
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    for _, id in ipairs(spells) do
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
    end
    local t0 = GetTime()
    local function poll()
        if not Demo.active then return end
        if Demo.DataReady(spells, items) or GetTime() - t0 >= Demo.LOAD_WAIT then done(); return end
        C_Timer.After(0.2, poll)
    end
    poll()
end

-- Beispielzeilen zeigen (Ablaufzeilen zuletzt, wie bei echten Warnungen)
function Demo.Show()
    if not Demo.active or InCombatLockdown() then return end
    local list, exp = {}, {}
    for _, d in ipairs(Demo.ROWS) do
        if Demo.RowKnown(d) then   -- Motive ohne Client-Daten auslassen
            local e = Demo.Entry(d)
            if d.expiry then exp[#exp + 1] = e else list[#list + 1] = e end
        end
    end
    local from = #list + 1
    for _, e in ipairs(exp) do list[#list + 1] = e end
    Demo.entries = list
    Display.ShowRows(list, false, from)
    if Demo.run then Demo.StillRows() end
end

-- Screenshot-Lauf: Pulsieren anhalten (volle Deckkraft bzw. Ablauf-Transparenz)
function Demo.StillRows()
    for _, r in ipairs(rows) do
        r.pulse:Stop()
        r:SetAlpha(r.baseAlpha or 1)
    end
end

function Demo.Start(after)
    if InCombatLockdown() then Print(L.COMBAT); return end
    if Demo.active then
        if after then after() end
        return
    end
    Demo.active = true
    if menu:IsShown() then menu:Hide() end
    Print(L.DEMO_ON)
    Demo.Preload(function()
        Demo.Show()
        if after then after() end
    end)
end

-- Demo (und Screenshot-Lauf) beenden, alles zurücksetzen und normal neu auswerten
function Demo.Stop(quiet)
    if not Demo.active and not Demo.run then return end
    Demo.run = nil      -- laufende Timer verfallen
    Demo.active = false
    Demo.Restore()
    if not InCombatLockdown() then
        if menu:IsShown() then menu:Hide() end
        Display.ShowRows({})   -- Beispielzeilen weg, auch falls Evaluate (noch) nichts zeigt
        Evaluate()
    end
    if not quiet then Print(L.DEMO_OFF) end
end

-- Kampfbeginn (PLAYER_REGEN_DISABLED): sofort beenden
function Demo.Abort()
    if not Demo.active and not Demo.run then return end
    Print(L.DEMO_ABORT)
    Demo.Stop(true)
end

function Demo.Command(sub)
    if sub == "off" then
        Demo.Stop()
    elseif sub == "shot" then
        Demo.StartShot()
    elseif Demo.active then
        Demo.Stop()
    else
        Demo.Start()
    end
end

function Demo.GetCVar(name)
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    local ok, v = pcall(C_CVar.GetCVar, name)
    if ok and type(v) == "string" and not IsSecret(v) then return v end
    return nil
end

function Demo.SetCVar(name, v)
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, v) end
end

-- Frame an WorldFrame hängen (sichtbar bei ausgeblendetem Interface); Skalierung so, dass die
-- effektive Größe gleich bleibt. keepPos: Bildschirmposition übernehmen (sonst setzt der
-- Aufrufer die Punkte neu, z. B. LayoutMenu relativ zum Parent).
function Demo.ToWorld(f, keepPos)
    local sv = Demo.saved
    if sv.frames[f] then return end
    local eff = f:GetEffectiveScale()
    local l, t = f:GetLeft(), f:GetTop()
    local strata = f:GetFrameStrata()
    sv.frames[f] = { parent = f:GetParent(), scale = f:GetScale(), strata = strata }
    f:SetParent(WorldFrame)
    f:SetScale(eff / WorldFrame:GetEffectiveScale())
    f:SetFrameStrata(strata)
    if keepPos and l and t then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", WorldFrame, "BOTTOMLEFT", l, t)
    end
end

-- Gemerkten Zustand wiederherstellen (im Kampf erst nach PLAYER_REGEN_ENABLED)
function Demo.Restore()
    local sv = Demo.saved
    if not sv then return end
    if InCombatLockdown() then Demo.restorePending = true; return end
    Demo.saved, Demo.restorePending = nil, false
    if menu:IsShown() then menu:Hide() end
    Menu.HideItemPanel()
    for f, info in pairs(sv.frames) do
        f:SetParent(info.parent)
        f:SetScale(info.scale)
        f:SetFrameStrata(info.strata)
    end
    for name, v in pairs(sv.cvars) do Demo.SetCVar(name, v) end
    db.style, db.iconsOnly = sv.style, sv.iconsOnly
    db.cfgTab = sv.cfgTab                    -- gemerkten Tab der Einstellungen wiederherstellen
    if config then Cfg.SelectTab(sv.cfgTab) end
    ApplyLayout()
    Display.ApplyStyle()
    if sv.uiShown and not UIParent:IsShown() then
        pcall(UIParent.Show, UIParent)
        if not UIParent:IsShown() then Print(L.DEMO_ALTZ) end
    end
end

-- f() nach t Sek., nur solange derselbe Lauf aktiv ist
function Demo.After(t, f)
    local run = Demo.run
    C_Timer.After(t, function()
        if Demo.run == run then f() end
    end)
end

-- Warten, bis cond() gilt (Polling); done() bzw. nach timeout Sek. onTimeout()
function Demo.WaitFor(cond, timeout, done, onTimeout)
    local run, t0 = Demo.run, GetTime()
    local function poll()
        if Demo.run ~= run then return end
        if cond() then done(); return end
        if GetTime() - t0 >= timeout then onTimeout(); return end
        C_Timer.After(0.25, poll)
    end
    poll()
end

function Demo.StopTimeout()
    Print(L.DEMO_TIMEOUT)
    Demo.Stop(true)
end

-- Interface ein-/ausblenden: zuerst selbst (UIParent:Show/Hide per pcall), sonst Hinweis Alt+Z
-- und warten (Abbruch nach 60 Sek.)
function Demo.SetUI(show, cont)
    if show then pcall(UIParent.Show, UIParent) else pcall(UIParent.Hide, UIParent) end
    if UIParent:IsShown() == show then cont(); return end
    Print(L.DEMO_ALTZ)
    Demo.WaitFor(function() return UIParent:IsShown() == show end, 60, cont, Demo.StopTimeout)
end

function Demo.StartShot()
    if InCombatLockdown() then Print(L.COMBAT); return end
    if Demo.run then return end
    Demo.Start(function()
        if Demo.active and not Demo.run then Demo.BeginRun() end
    end)
end

-- Zustand merken, Screenshot-CVars setzen, Anzeige und Menü an WorldFrame hängen, loslegen
function Demo.BeginRun()
    Demo.run = { manual = false }
    local sv = { frames = {}, cvars = {}, style = db.style, iconsOnly = db.iconsOnly, uiShown = UIParent:IsShown(),
        cfgTab = db.cfgTab }
    Demo.saved = sv
    sv.cvars.screenshotFormat = Demo.GetCVar("screenshotFormat")
    sv.cvars.screenshotQuality = Demo.GetCVar("screenshotQuality")
    if sv.cvars.screenshotFormat then Demo.SetCVar("screenshotFormat", "png") end
    if sv.cvars.screenshotQuality then Demo.SetCVar("screenshotQuality", "10") end
    db.demoShots = { started = time(), shots = {} }
    local _, sw, sh = Demo.PixelScale()
    if sw then db.demoShots.screen = { w = sw, h = sh } end   -- physische Pixel (Prüfung im Skript)
    if menu:IsShown() then menu:Hide() end
    Demo.ToWorld(anchor, true)
    Demo.ToWorld(menu)
    Demo.ToWorld(itemPanel)
    Demo.RunShot(1)
end

-- Menü eines Motivs rechts neben der ganzen Anzeige öffnen (x = größtes GetRight aller sichtbaren
-- Zeilen + 12, y = Oberkante der Motiv-Zeile; Koordinaten in Menü-Einheiten). So liegt es bei
-- "Nur Icons" nicht über den folgenden Icons.
function Demo.OpenMenu(which)
    for i, e in ipairs(Demo.entries or {}) do
        local r = rows[i]
        if e.demo.menu == which and r and r:IsShown() then
            local right, top = nil, r:GetTop()
            for _, row in ipairs(rows) do
                local rr = row:IsShown() and row:GetRight()
                if type(rr) == "number" then right = math.max(right or rr, rr) end
            end
            if right and top then
                local k = r:GetEffectiveScale() / menu:GetEffectiveScale()
                menu.x, menu.y = right * k + 12, top * k
            end
            Menu.LayoutMenu(e)
            menu.away = 0
            menu:Show()
            return
        end
    end
end

-- Tab der Einstellungen zeigen und nach oben scrollen; false = Tab gibt es nicht (Bild entfällt)
function Demo.ShowTab(key)
    local t = Cfg.tabs[key]
    if not t then return false end
    Cfg.SelectTab(key)
    t.scroll:SetVerticalScroll(0)
    return true
end

function Demo.RunShot(i)
    if not Demo.run then return end
    local s = Demo.SHOTS[i]
    if not s then Demo.FinishRun(); return end
    local wantUI = s.ui == true
    if UIParent:IsShown() ~= wantUI then
        Demo.SetUI(wantUI, function() Demo.RunShot(i) end)
        return
    end
    if s.settings then
        -- Einstellungsbilder mit sichtbarem Interface, ohne Beispielzeilen, im echten Stil
        -- (Stand vor dem Lauf), damit die Einstellungen den tatsächlichen Stand zeigen
        if menu:IsShown() then menu:Hide() end
        Display.ShowRows({})
        if Demo.saved and (db.style ~= Demo.saved.style or db.iconsOnly ~= Demo.saved.iconsOnly) then
            db.style, db.iconsOnly = Demo.saved.style, Demo.saved.iconsOnly
            Display.ApplyStyle()
        end
        if not (config and config:IsVisible()) then ToggleConfig() end
        Demo.After(0.5, function()
            if not Demo.ShowTab(s.settings) then Demo.RunShot(i + 1); return end
            Demo.After(Demo.SHOT_DELAY, function() Demo.Capture(i) end)
        end)
        return
    end
    db.style, db.iconsOnly = s.style, s.icons
    Display.ApplyStyle()   -- schließt auch ein offenes Menü
    Demo.Show()
    if s.menu then Demo.OpenMenu(s.menu) end
    Demo.After(Demo.SHOT_DELAY, function() Demo.Capture(i) end)
end

-- Bild auslösen und auf SCREENSHOT_SUCCEEDED/FAILED warten (5 Sek.). Kommt kein Ereignis,
-- gilt Screenshot() als blockiert: Hinweis "Druck-Taste" und warten (60 Sek.).
-- Physische Bildschirmgröße und Faktor 768er-Raster -> Pixel; nil = nicht lesbar
function Demo.PixelScale()
    if type(GetPhysicalScreenSize) ~= "function" then return nil end
    local ok, w, h = pcall(GetPhysicalScreenSize)
    if not ok or type(w) ~= "number" or type(h) ~= "number" or IsSecret(w) or IsSecret(h) or h <= 0 then
        return nil
    end
    return h / 768, w, h
end

-- Zuschnitt-Rechteck in Bildschirm-Pixeln (Ursprung oben links) als Vereinigung der sichtbaren
-- Frames: Kante × GetEffectiveScale() = 768er-Raster, × (physische Höhe / 768) = Pixel;
-- y von oben = physische Höhe − top. nil = nicht berechenbar (dann ganzes Bild).
function Demo.CropOf(frames)
    local k, _, sh = Demo.PixelScale()
    if not k then return nil end
    local l, r, t, b
    for _, fr in ipairs(frames) do
        if fr:IsVisible() then
            local fl, frr, ft, fb, sc = fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom(), fr:GetEffectiveScale()
            for _, v in ipairs({ fl or false, frr or false, ft or false, fb or false, sc or false }) do
                if type(v) ~= "number" or IsSecret(v) then return nil end
            end
            fl, frr, ft, fb = fl * sc, frr * sc, ft * sc, fb * sc
            l = l and math.min(l, fl) or fl
            r = r and math.max(r, frr) or frr
            t = t and math.max(t, ft) or ft
            b = b and math.min(b, fb) or fb
        end
    end
    if not l then return nil end
    local function px(v) return math.floor(v * k + 0.5) end
    return { x = px(l), y = math.floor(sh - t * k + 0.5), w = px(r) - px(l), h = px(t) - px(b) }
end

-- Oberster Fenster-Frame über f (letzter Vorfahre vor UIParent bzw. ohne Parent), z. B.
-- SettingsPanel für die Seite unter "Pardona's Addons", BuffReminderConfig ohne Settings-API
function Demo.TopWindow(fr)
    for _ = 1, 30 do
        local p = fr:GetParent()
        if not p or p == UIParent or p == WorldFrame then return fr end
        fr = p
    end
    return fr
end

-- Frames, die ein Bild zeigt: Warnzeilen + offenes Menü bzw. das Einstellungsfenster
function Demo.ShotFrames(s)
    if s.settings then
        return config and { Demo.TopWindow(config) } or {}
    end
    local list = {}
    for _, r in ipairs(rows) do
        if r:IsShown() then list[#list + 1] = r end
    end
    if menu:IsShown() then list[#list + 1] = menu end
    if itemPanel:IsShown() then list[#list + 1] = itemPanel end
    return list
end

function Demo.Capture(i)
    local run, s = Demo.run, Demo.SHOTS[i]
    if not run then return end
    run.result, run.waiting = nil, true
    run.crop = Demo.CropOf(Demo.ShotFrames(s))   -- vor dem Bild, Stand wie auf dem Bild
    if run.manual then
        Print(L.DEMO_PRINT)
    elseif not (type(Screenshot) == "function" and pcall(Screenshot)) then
        run.manual = true
        Print(L.DEMO_PRINT)
    end
    Demo.WaitFor(function() return run.result ~= nil end, run.manual and 60 or 5, function()
        run.waiting = false
        if run.result then
            local list = db.demoShots.shots
            list[#list + 1] = { n = #list + 1, name = s.name, t = time(), crop = run.crop }
        else
            Print(L.DEMO_SHOT_FAIL:format(s.name))
        end
        Demo.RunShot(i + 1)
    end, function()
        run.waiting = false
        if run.manual then Demo.StopTimeout(); return end
        run.manual = true
        Demo.Capture(i)
    end)
end

-- SCREENSHOT_SUCCEEDED / SCREENSHOT_FAILED
function Demo.OnScreenshot(ok)
    local run = Demo.run
    if run and run.waiting and run.result == nil then run.result = ok end
end

function Demo.FinishRun()
    local n = db.demoShots and #db.demoShots.shots or 0
    Demo.Stop(true)
    Print(L.DEMO_DONE:format(n))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function ApplyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then t[k] = type(v) == "table" and { unpack(v) } or v end
    end
end

-- Events nur registrieren, wenn der Client sie kennt (C_EventUtils.IsEventValid), und immer
-- per pcall. unit gesetzt: RegisterUnitEvent. Rückgabe: true = registriert.
local function SafeRegisterEvent(frame, event, unit)
    if C_EventUtils and C_EventUtils.IsEventValid then
        local okValid, valid = pcall(C_EventUtils.IsEventValid, event)
        if not okValid or not valid then return false end
    end
    if unit then return (pcall(frame.RegisterUnitEvent, frame, event, unit)) end
    return (pcall(frame.RegisterEvent, frame, event))
end

local ev = CreateFrame("Frame")
SafeRegisterEvent(ev, "ADDON_LOADED")
SafeRegisterEvent(ev, "PLAYER_LOGIN")
SafeRegisterEvent(ev, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(ev, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(ev, "PLAYER_ALIVE")
SafeRegisterEvent(ev, "PLAYER_UNGHOST")
SafeRegisterEvent(ev, "PLAYER_DEAD")
SafeRegisterEvent(ev, "SPELLS_CHANGED")
SafeRegisterEvent(ev, "PLAYER_LEVEL_UP")
SafeRegisterEvent(ev, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(ev, "ZONE_CHANGED_NEW_AREA")
SafeRegisterEvent(ev, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(ev, "MINIMAP_UPDATE_TRACKING")
SafeRegisterEvent(ev, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(ev, "GET_ITEM_INFO_RECEIVED")
SafeRegisterEvent(ev, "ENABLE_XP_GAIN")
SafeRegisterEvent(ev, "DISABLE_XP_GAIN")
SafeRegisterEvent(ev, "UPDATE_BINDINGS")   -- Tasten-Hinweis in den Einstellungen
SafeRegisterEvent(ev, "SCREENSHOT_SUCCEEDED")   -- Demo-Screenshot-Lauf
SafeRegisterEvent(ev, "SCREENSHOT_FAILED")
-- Ladebildschirm-Events gibt es nicht in jedem Client (IsEventValid filtert sie dann aus)
SafeRegisterEvent(ev, "LOADING_SCREEN_ENABLED")
SafeRegisterEvent(ev, "LOADING_SCREEN_DISABLED")

-- Nach Login/Ladebildschirm liefert die Aura-API kurz unvollständige Daten → 3 Sek. warten.
-- Generationszähler: nur der zuletzt gestartete Timer darf ready = true setzen.
local GRACE_TIME = 3
local graceGen = 0

local function StartGrace()
    ready = false
    wipe(missingSince)
    warnCount = nil   -- Kurzstatus nach der Wartezeit neu melden
    graceGen = graceGen + 1
    local gen = graceGen
    C_Timer.After(GRACE_TIME, function()
        if gen ~= graceGen then return end
        ready = true; Items.ScanBags(); RefreshKnown(); Evaluate()
    end)
end

ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        Demo.OnScreenshot(event == "SCREENSHOT_SUCCEEDED")
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffReminderDB = BuffReminderDB or {}
        BuffReminderCharDB = BuffReminderCharDB or {}
        db, cdb = BuffReminderDB, BuffReminderCharDB
        ApplyDefaults(db, DEFAULTS)
        cdb.buffs = cdb.buffs or {}
        cdb.lastVariant = cdb.lastVariant or {}   -- Eintrag-Key -> zuletzt genutzte Variante
        cdb.reagents = cdb.reagents or {}         -- Reagenz-Item-ID -> Warnschwelle (0 = aus)
        cdb.favorites = cdb.favorites or {}       -- Item-ID -> true: Favorit (Essen/Fläschchen)
        if not Style.STYLES[db.style] then db.style = DEFAULTS.style end
        -- cdb.lastFlask: Item-ID des zuletzt benutzten Fläschchens (nil = keins)
        db.iconCache = db.iconCache or {}         -- allgemeiner Buff -> zuletzt gesehenes Aura-Icon
        db.flaskSpells = db.flaskSpells or {}     -- gelernte Spell-IDs von Fläschchen-Effekten
        db.elixirSpells = db.elixirSpells or {}   -- Elixier-Item-ID -> Spell-ID des Buffs (gelernt)
        cdb.elixirsSeen = cdb.elixirsSeen or {}   -- Elixier-Item-ID -> true: schon in den Taschen gewesen
        cdb.elixirsWanted = cdb.elixirsWanted or {}   -- Elixier-Item-ID -> true: gewünscht (Warnung)
        -- versteckter Sprach-Schalter (nicht in Hilfe/README/Einstellungen; /br reset lässt ihn stehen):
        -- /run BuffReminderDB.locale = "frFR" + /reload; nil = Client-Sprache
        ns.Locales.Activate(db.locale)
        Keybind.SetNames(); Menu.SetTexts()       -- beim Laden gesetzte Texte in der aktiven Sprache
        RegisterPardona()                         -- erst jetzt: SavedVariables sind geladen
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
        PrintVersionNotice()   -- einmal pro Login (nicht bei Ladebildschirmen)
        local _, class = UnitClass("player")
        classEntries = CLASS_BUFFS[class] or {}
        for _, e in ipairs(classEntries) do
            PrepareEntry(e); PrepareCast(e, class); entries[#entries + 1] = e
            local g = GROUP_BUFFS[class] and GROUP_BUFFS[class][e.key]
            if g then e.groupIds, e.manaOnly, e.groupByVariant, e.ownOnly = g.groupIds, g.manaOnly, g.groupByVariant, g.ownOnly end
        end
        Variant.PrepareLabels(classEntries)   -- Beschriftungen der Variantengruppen (Cache)
        Conjure.Preload(classEntries)   -- Namen der Verbrauchsgüter-Items vorladen
        Group.DetectPallyPower()        -- Segen in den Gruppenbuffs aus, solange Pally Power geladen ist
        -- Waffen-Items: nicht für Schamanen (eigene Waffenverzauberungen); Schurke: an den
        -- Gift-Eintrag desselben Slots koppeln
        for i = #GENERAL_BUFFS, 1, -1 do
            local e = GENERAL_BUFFS[i]
            if e.weaponItems then
                if class == "SHAMAN" then
                    table.remove(GENERAL_BUFFS, i)
                else
                    for _, c in ipairs(classEntries) do
                        if c.poisonItems and c.kind == e.kind then e.poisonEntry = c end
                    end
                end
            end
        end
        for _, e in ipairs(GENERAL_BUFFS) do PrepareEntry(e); entries[#entries + 1] = e end
        -- Verfolgungs-Erinnerung (experimentell): eigener Eintrag ohne Zeile in der Buff-Liste der
        -- Einstellungen; gilt überall (nicht nur in Instanzen); Verfolgung wird in RefreshKnown bestimmt
        Tracking.entry = { key = "gen_tracking", general = true, kind = "tracking", everywhere = true, ids = {} }
        PrepareEntry(Tracking.entry)
        entries[#entries + 1] = Tracking.entry
        -- Essen & Fläschchen: Kategorie-Gewichte der Klasse, gelernte Fläschchen-Spells, Taschen
        for _, e in ipairs(GENERAL_BUFFS) do
            if e.itemKind == "flask" then flaskEntry = e end
            if e.itemKind == "food" then foodEntry = e end
        end
        for id in pairs(db.flaskSpells) do flaskEntry.idSet[id] = true end
        Items.BuildFoodScores(class)
        Items.UpdateXP()            -- zählt Erfahrung? (XP-Essen bevorzugen / Abzeichen)
        Eat.ResolveAllEatSpells()   -- Ess-Auren aller FOOD-Items (fehlende werden nachgeladen)
        Elixir.Setup()              -- Einträge der gemerkten Elixiere (neue folgen beim Taschen-Scan)
        Items.ScanBags()
        -- Reagenzien der Klasse (Reihenfolge wie in REAGENT_SPELLS, ohne Doppelte)
        reagentLines = REAGENT_SPELLS[class] or {}
        local seen = {}
        for _, ranks in ipairs(reagentLines) do
            for _, rank in ipairs(ranks) do
                local item = rank[3]
                if item and not seen[item] then
                    seen[item] = true
                    local e = { key = "reagent_" .. item, kind = "reagent", item = item }
                    reagentEntries[#reagentEntries + 1] = e
                    entries[#entries + 1] = e
                    ItemName(item)   -- Item-Daten vorladen
                end
            end
        end
        RefreshKnown()
        Style.SyncFromLib()   -- Stil "Pardona" aus LP.Style (jetzt ist die höchste Lib-MINOR aktiv)
        ApplyLayout()
        Display.ApplyStyle()
        RegisterPardonaSettings()
        -- UNIT_AURA für alle Units; gefiltert auf player / party* / raid* (siehe unten)
        SafeRegisterEvent(self, "UNIT_AURA")
        SafeRegisterEvent(self, "GROUP_ROSTER_UPDATE")
        SafeRegisterEvent(self, "UNIT_INVENTORY_CHANGED", "player")
        SafeRegisterEvent(self, "UNIT_SPELLCAST_SUCCEEDED", "player")
        SafeRegisterEvent(self, "UNIT_SPELLCAST_SENT")
        SafeRegisterEvent(self, "UI_ERROR_MESSAGE")
        C_Timer.NewTicker(1, Evaluate)
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- arg1 = Item-ID; nur eigene Reagenzien interessieren (lokalisierter Name nachgeladen)
        -- bzw. Essen/Fläschchen in den Taschen (Name, Stufe, Tooltip jetzt verfügbar)
        if IsSecret(arg1) then return end
        if Eat.eatPending[arg1] then Eat.ResolveEatSpell(arg1, true) end   -- Ess-Aura jetzt ermittelbar
        if Items.bagCounts[arg1] then
            Items.LearnItem(arg1)
            Menu.RefreshItemPanel()
            Evaluate()
            return
        end
        for _, e in ipairs(reagentEntries) do
            if e.item == arg1 then
                Evaluate()
                if not ready then RefreshConfig() end   -- Evaluate tut vor ready nichts
                return
            end
        end
        return
    end

    if event == "UPDATE_BINDINGS" then
        if RefreshConfig then RefreshConfig() end   -- nur bei sichtbaren Einstellungen
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        Items.ScanBags()
        Menu.RefreshItemPanel()   -- im Kampf nicht offen; Zeilen-Attribute folgen per Evaluate nach dem Kampf
        Evaluate()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        Menu.CloseItemPanelForCombat()
        Demo.Abort()   -- Demo/Screenshot-Lauf sofort beenden (Zurücksetzen ggf. nach dem Kampf)
        RefreshPardonaStatus()   -- im Kampf kein Kurzstatus
        return
    end

    if event == "UNIT_AURA" then
        -- arg1 = Unit. Spieler: sofort auswerten (wie bisher); Gruppen-/Raid-Mitglieder:
        -- gedrosselt (MarkGroupDirty); alle anderen Units (Ziel, Namensplaketten …) ignorieren.
        -- Gruppen-Buffs aus (Experimental-Schalter oder groupCheck): Gruppen-Units ignorieren.
        if arg1 == nil or IsSecret(arg1) then return end
        if arg1 == "player" then
            if GroupFeatureOn() then Group.MarkGroupDirty() end
            Evaluate()
        elseif GroupFeatureOn() and (arg1:find("^party%d") or arg1:find("^raid%d")) then
            Group.MarkGroupDirty()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup or not IsInGroup() then wipe(Group.bounced) end
        if not GroupFeatureOn() then return end
        Group.MarkGroupDirty()
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        -- arg1 = unit, arg2 = target, arg3 = castGUID, arg4 = spellID
        if arg1 ~= "player" or type(arg2) ~= "string" or IsSecret(arg2) or arg4 == nil or IsSecret(arg4) then return end
        local sname = SpellName(arg4)
        for _, e in ipairs(entries) do
            if e.ownOnly and e.variants then
                for _, v in ipairs(e.variants) do
                    if v.matchSet[arg4] or (sname and v.nameSet[sname]) then
                        Group.lastAttempt = {
                            name = arg2,
                            key = e.key, variant = v.key, t = GetTime(),
                        }
                        return
                    end
                end
            end
        end
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        -- arg1 = errorType, arg2 = message ("A more powerful spell is already active" -> Variante merken)
        local att = Group.lastAttempt
        if not att or (GetTime() - att.t) > 2 or type(arg2) ~= "string" or IsSecret(arg2) then return end
        local bouncedMsg = _G["SPELL_FAILED_AURA_BOUNCED"] or _G["ERR_AURA_BOUNCED"]
        if (bouncedMsg and arg2 == bouncedMsg) or arg2:lower():find("more powerful spell", 1, true) then
            Group.RecordBounce(att)
            Group.lastAttempt = nil
            Group.MarkGroupDirty()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- nach dem Kampf: Gruppe sofort neu prüfen, Zeilen/Attribute nachziehen
        if Demo.restorePending then Demo.Restore() end
        if GroupFeatureOn() then Group.groupDirty = true end
        Evaluate()
        RefreshPardonaStatus()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID (kann ein Secret-Wert sein)
        -- Ziel der Gruppen-Zeilen nach jedem Cast neu bestimmen
        if GroupFeatureOn() then Group.MarkGroupDirty() end
        if cdb then
            RememberFromCast(arg3)
            -- Fläschchen-Effekt (auch über Aktionsleiste/Taschen benutzt) -> zuletzt benutzt
            if arg3 ~= nil and not IsSecret(arg3) and Items.flaskBySpell[arg3] then
                cdb.lastFlask = Items.flaskBySpell[arg3]
            end
        end
        Evaluate()
        return
    end

    if event == "LOADING_SCREEN_ENABLED" then
        ready = false
        graceGen = graceGen + 1   -- laufende Grace-Timer verfallen
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
        StartGrace()
        return
    end

    if event == "ENABLE_XP_GAIN" or event == "DISABLE_XP_GAIN" or event == "PLAYER_LEVEL_UP" then
        -- XP-Bonus neu bewerten (arg1 = neue Stufe bei PLAYER_LEVEL_UP); offenes Item-Menü
        -- und Warnzeilen (beste Wahl) folgen
        Items.UpdateXP(event == "PLAYER_LEVEL_UP" and arg1 or nil)
        Menu.RefreshItemPanel()
        if event ~= "PLAYER_LEVEL_UP" then Evaluate(); return end
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
        -- Neu erlernte Zauber werden automatisch aktiv (Standard = an)
        C_Timer.After(0.5, function() RefreshKnown(); Evaluate() end)
        return
    end

    if event == "MINIMAP_UPDATE_TRACKING" then
        RefreshKnown()
        Evaluate()
        RefreshConfig()   -- Umschalt-Knopf "Verfolgen" (nur bei sichtbaren Einstellungen)
        return
    end

    Evaluate()
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_BUFFREMINDER1 = "/br"
SLASH_BUFFREMINDER2 = "/buffreminder"
SlashCmdList.BUFFREMINDER = function(msg)
    if not db then return end
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "config" or cmd == "options" then
        ToggleConfig()
    elseif cmd == "test" then
        StartTest()
    elseif cmd == "move" then
        Cfg.SetMoveMode(true)
    elseif cmd == "lock" then
        Cfg.SetMoveMode(false)
    elseif cmd == "minimap" then
        TogglePardonaMinimap()
    elseif cmd == "unmute" then
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    elseif cmd == "debug" then
        local log = {}
        local function dprint(line) Print(line); log[#log + 1] = line end
        local ids, _, unreliable = ScanAuras()
        dprint(("ready=%s enabled=%s suppressed=%s instanceOnly=%s inInstance=%s scan=%s unreliable=%s"):format(
            tostring(ready), tostring(db.enabled), tostring(Suppressed()), tostring(db.instanceOnly),
            tostring(InGroupInstance()), ids and "ok" or "nil", tostring(unreliable)))
        for _, e in ipairs(entries) do
            dprint(("%s: known=%s enabled=%s missing=%s muted=%s groupActive=%s names=%s"):format(
                EntryLabel(e), tostring(knownCache[e.key]), tostring(IsEnabled(e)),
                tostring(missing[e.key]), tostring(MuteRemaining(e.key) ~= nil),
                tostring(e.groupActive), table.concat(e.names or {}, "/")))
        end
        Group.PrintDebug(log)
        dprint(("eating=%s aura=%s eatSpells=%d eatNames=%d"):format(
            (foodEntry and foodEntry.eatStart) and "yes" or "no",
            Eat.eatAura and ("%s – %s"):format(tostring(Eat.eatAura.name), tostring(Eat.eatAura.id)) or "none",
            CountKeys(Eat.eatSpells), CountKeys(Eat.eatNames)))
        local numFn = Tracking.NumTypesFn()
        local okN, numTrack = false, nil
        if numFn then okN, numTrack = pcall(numFn) end
        dprint(("trackingTypes=%s"):format(okN and tostring(numTrack) or "err"))
        dprint(Style.DebugLine())
        dprint(("locale: %s (client %s, override %s)"):format(ns.Locales.active, ns.Locales.Client(),
            tostring(db.locale)))
        db.lastDebug = log
    elseif cmd == "auras" then
        Print(L.AURAS_HEAD)
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 255 do
                local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                if not ok or a == nil then break end
                if IsSecret(a) or IsSecret(a.name) or IsSecret(a.spellId) then
                    Print("  ? (secret)")
                else
                    Print(("  %s – %s"):format(tostring(a.name), tostring(a.spellId)))
                end
            end
        elseif UnitBuff then
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, id = UnitBuff("player", i)
                if not name then break end
                Print(("  %s – %s"):format(name, tostring(id)))
            end
        end
    elseif cmd == "demo" and db.demo == true then
        Demo.Command((msg or ""):lower():match("^%s*%S+%s+(%S+)"))
    elseif cmd == "reset" then
        if InCombatLockdown() then Print(L.COMBAT); return end
        for k in pairs(DEFAULTS) do db[k] = nil end
        -- Experimental-Schalter: wieder Build-abhängig
        db.expGroup, db.expReagents, db.expExpiry, db.expConsumables, db.expWeaponItems = nil, nil, nil, nil, nil
        db.expVariantMenu, db.expBlessings, db.expTracking = nil, nil, nil
        db.expElixirs, db.expScrolls = nil, nil
        cdb.trackWanted = nil                     -- Verfolgung wieder automatisch
        RefreshKnown()
        ApplyDefaults(db, DEFAULTS)
        wipe(cdb.buffs)
        wipe(cdb.reagents)
        ApplyLayout(); Display.ApplyStyle(); Print(L.RESET); Evaluate()
    else
        for _, k in ipairs({ "HELP_OPEN", "HELP_TEST", "HELP_MOVE", "HELP_LOCK", "HELP_MINIMAP", "HELP_UNMUTE", "HELP_AURAS", "HELP_RESET" }) do
            Print(L[k])
        end
    end
end
