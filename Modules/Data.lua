-- Pardona's Buff Reminder – Statische Daten: Buff-Datenbank (Klasse/allgemein), Klassen-Verbrauchsgüter,
-- Klick-Zaubern, Essen & Fläschchen, Waffen-Items, Reagenzien, Gruppen-Buffs, Töne, Standardwerte.
-- Abhängigkeiten (beim Laden): Core.lua

local ADDON_NAME, ns = ...

-- aus Core.lua
local Items = ns.Items
local Conjure = ns.Conjure

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
-- Klassen-Verbrauchsgüter (Schalter expConsumables)
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
    -- Waffen-Items (Schalter expWeaponItems): Steine/Öle per Klick; fehlt nur, wenn eine Waffe
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
--   Anderes Buff-Essen (Tooltip nennt "Well Fed") zählt ebenfalls (Items.DetectFood).
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
-- Waffen-Items (Schalter expWeaponItems): Steine, Öle, Gifte
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

-- Töne für neue Warnungen (db.sound): Blizzard-Töne über SOUNDKIT-Konstanten (nur angeboten,
-- wenn der Client die Konstante kennt; die drei alten haben eine feste ID als Rückfall),
-- "aus" = kein Ton, "lsm:<Name>" = Ton aus LibSharedMedia-3.0 (falls ein anderes Addon die Lib
-- lädt). Fehlt ein gespeicherter Ton, klingt Bell. Abgespielt wird über den Kanal "Master".
--   { Key (Text SOUND_<KEY>), SOUNDKIT-Name, Rückfall-ID }
local Sound = {}
Sound.BUILTIN = {
    { "ping", "TELL_MESSAGE", 3081 },
    { "glocke", "ALARM_CLOCK_WARNING_3", 12889 },
    { "alarm", "RAID_WARNING", 8959 },
    { "readycheck", "READY_CHECK" },
    { "quest", "IG_QUEST_LIST_COMPLETE" },
    { "mapping", "MAP_PING" },
    { "coins", "LOOT_WINDOW_COIN_SOUND" },
    { "invite", "IG_PLAYER_INVITE" },
    { "clock", "ALARM_CLOCK_WARNING_2" },
    { "bossemote", "RAID_BOSS_EMOTE_WARNING" },
}
Sound.FALLBACK = "glocke"
Sound.LSM_PREFIX = "lsm:"

local DEFAULTS = {
    enabled      = true,
    sound        = "ping",
    scale        = 1.0,        -- Größe der Warnliste (0.5-2); Position (point) in Einheiten dieser Größe
    alpha        = 1.0,        -- Deckkraft der Warnliste (0.3-1)
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
    restockAbove = false,       -- Auffüllen beim Händler: auch über Min. anbieten (alles unter "Auffüllen auf")
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Für andere Dateien (ns)
ns.CLASS_BUFFS = CLASS_BUFFS
ns.GENERAL_BUFFS = GENERAL_BUFFS
ns.CAST_DATA = CAST_DATA
ns.REAGENT_INFO = REAGENT_INFO
ns.REAGENT_SPELLS = REAGENT_SPELLS
ns.GROUP_BUFFS = GROUP_BUFFS
ns.GROUP_MODE_ORDER = GROUP_MODE_ORDER
ns.MANA_CLASSES = MANA_CLASSES
ns.RANK_INFO = RANK_INFO
ns.Sound = Sound
ns.DEFAULTS = DEFAULTS
ns.FALLBACK_ICON = FALLBACK_ICON
