-- Pardona's Buff Reminder – WoW Forever (Interface 16001, Mainline-API)
-- Erinnert an fehlende Klassen- und allgemeine Buffs (auch bei Gruppen-/Raid-Mitgliedern)
-- sowie an knappe Reagenzien.
-- Auswahl per GUI (Minimap-Button / /br), Rechtsklick auf Erinnerung = stummschalten,
-- Linksklick auf Erinnerung = Buff auf sich selbst zaubern (abschaltbar);
-- bei Essen/Fläschchen = bestes Item aus den Taschen benutzen, Rechtsklick = Auswahl.

local ADDON_NAME = ...

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
local L
if GetLocale() == "deDE" then
    L = {
        TITLE         = "Pardona's Buff Reminder",
        MISSING       = "%s fehlt",
        CHAT          = "|cffffb000%s fehlt – bitte nachbuffen!|r",
        CLASS_SECTION = "Klassenbuffs – %s",
        GENERAL       = "Allgemeine Buffs",
        FROM_LEVEL    = "ab Stufe %d",
        TALENT        = "Talent (ab Stufe %d)",
        NOT_LEARNED   = "nicht erlernt",
        MUTED         = "stumm %s",
        SESSION       = "Sitzung",
        MUTE5         = "5 Min. stumm",
        MUTE15        = "15 Min. stumm",
        MUTE60        = "60 Min. stumm",
        MUTESESSION   = "Für diese Sitzung stumm",
        CANCEL        = "Abbrechen",
        RIGHTCLICK    = "Rechtsklick: stummschalten",
        ENABLED       = "Addon aktiv",
        INSTANCE_ONLY = "Allgemeine Buffs nur in Instanzen",
        INSTANCE_HINT = "nur in Instanzen",
        SOUND         = "Ton: %s",
        MOVE          = "Verschieben",
        LOCK          = "Fixieren",
        TEST          = "Test",
        UNMUTE        = "Stumm aufheben",
        UNMUTED       = "Alle Stummschaltungen aufgehoben.",
        DRAG          = "Ziehen zum Verschieben",
        MM_LEFT       = "Linksklick: Einstellungen",
        MM_RIGHT      = "Rechtsklick: Test",
        MM_DRAG       = "Ziehen: Button verschieben",
        NO_CLASS      = "Keine Klassenbuffs für diese Klasse hinterlegt.",
        RESET         = "Einstellungen zurückgesetzt.",
        SOUNDS        = { ping = "Ping", glocke = "Glocke", alarm = "Alarm", aus = "Aus" },
        HELP          = {
            "/br – Einstellungen öffnen",
            "/br test – Erinnerung testen",
            "/br minimap – Minimap-Button ein/aus",
            "/br unmute – alle Stummschaltungen aufheben",
            "/br auras – aktive Buffs mit Namen und Spell-ID auflisten",
            "/br reset – Position und Einstellungen zurücksetzen",
        },
        AURAS_HEAD    = "Aktive Buffs (Name – Spell-ID):",
        -- Sammelbezeichnungen
        ANY_BLESSING  = "Segen (beliebig)",
        ANY_AURA      = "Aura (beliebig)",
        ANY_SEAL      = "Siegel (beliebig)",
        ANY_ASPECT    = "Aspekt (beliebig)",
        MAGE_ARMOR    = "Rüstung (Frost/Eis/Magie/Glühend)",
        LOCK_ARMOR    = "Dämonenhaut / Dämonen- / Teufelsrüstung",
        SHAMAN_SHIELD = "Blitz- / Wasser- / Erdschild",
        MH_ENCHANT    = "Waffenverzauberung Haupthand",
        OH_ENCHANT    = "Waffenverzauberung Nebenhand",
        MH_POISON     = "Gift Haupthand",
        OH_POISON     = "Gift Nebenhand",
        SHOUT         = "Schlachtruf / Befehlsruf",
        FLASK         = "Fläschchen",
        WELLRESTED    = "Well-Rested (Schlafsack)",
        -- Klick-Zaubern
        HINT_CAST     = "Linksklick: zaubern · Rechtsklick: stumm",
        HINT_MUTE     = "Rechtsklick: stumm",
        LEFTCLICK     = "Linksklick: zaubern",
        CLICKCAST     = "Linksklick zaubert Buff",
        COMBAT        = "Im Kampf nicht möglich.",
        AFTER_COMBAT  = "Änderung wird nach dem Kampf angezeigt.",
        -- Reagenzien
        REAGENTS      = "Reagenzien",
        REAGENT_HINT  = "Warnen unter (0 = aus)",
        REAGENT_LOW   = "%s: %d übrig",
        REAGENT_CHAT  = "|cffffb000Reagenz knapp: %s – nur noch %d!|r",
        IN_BAGS       = "%d in Taschen",
        -- Ess-Countdown
        EATING        = "Isst … %d s",
        EATING_DONE   = "Gleich satt …",
        HINT_EATING   = "Sitzen bleiben",
        -- Versionshinweis beim Login (Beta/Alpha/Entwicklerversion)
        VERSION_LOADED = "%s geladen",
        DEV_BUILD      = "Entwicklerversion geladen",
        -- Essen & Fläschchen
        HINT_ITEM     = "Linksklick: %s · Rechtsklick: Auswahl",
        HINT_NOITEM   = "Nicht in der Tasche · Rechtsklick: stumm",
        LEFTCLICK_USE = "Linksklick: %s benutzen",
        RIGHTCLICK_CHOOSE = "Rechtsklick: Auswahl / stummschalten",
        -- Gruppen-Buffs
        GROUP_SECTION = "Gruppen-Buffs",
        GROUP_CHECK   = "Gruppen-Buffs prüfen",
        GROUP_MODE    = "Prüfen in: %s",
        GROUP_MODES   = { always = "Immer", instance = "Nur Dungeon & Raid", raid = "Nur Raid" },
        GROUP_MISSING = "%s fehlt: %d",
        GROUP_CHAT    = "|cffffb000%s fehlt bei %d Spieler(n) – bitte nachbuffen!|r",
        HINT_GROUP    = "Linksklick: Gruppe · Strg+Linksklick: einzeln · Rechtsklick: stumm",
        HINT_SINGLE   = "Linksklick: einzeln · Rechtsklick: stumm",
        LEFTCLICK_GROUP = "Linksklick: Gruppenversion auf %s",
        LEFTCLICK_SINGLE = "Linksklick: Einzelversion auf %s",
        CTRLCLICK_SINGLE = "Strg+Linksklick: Einzelversion auf %s",
    }
else
    L = {
        TITLE         = "Pardona's Buff Reminder",
        MISSING       = "%s missing",
        CHAT          = "|cffffb000%s is missing – rebuff!|r",
        CLASS_SECTION = "Class buffs – %s",
        GENERAL       = "General buffs",
        FROM_LEVEL    = "from level %d",
        TALENT        = "Talent (level %d+)",
        NOT_LEARNED   = "not learned",
        MUTED         = "muted %s",
        SESSION       = "session",
        MUTE5         = "Mute 5 min",
        MUTE15        = "Mute 15 min",
        MUTE60        = "Mute 60 min",
        MUTESESSION   = "Mute for the session",
        CANCEL        = "Cancel",
        RIGHTCLICK    = "Right-click: mute",
        ENABLED       = "Addon enabled",
        INSTANCE_ONLY = "General buffs only in instances",
        INSTANCE_HINT = "instances only",
        SOUND         = "Sound: %s",
        MOVE          = "Move",
        LOCK          = "Lock",
        TEST          = "Test",
        UNMUTE        = "Unmute all",
        UNMUTED       = "All mutes cleared.",
        DRAG          = "Drag to move",
        MM_LEFT       = "Left-click: settings",
        MM_RIGHT      = "Right-click: test",
        MM_DRAG       = "Drag: move button",
        NO_CLASS      = "No class buffs defined for this class.",
        RESET         = "Settings reset.",
        SOUNDS        = { ping = "Ping", glocke = "Bell", alarm = "Alarm", aus = "Off" },
        HELP          = {
            "/br – open settings",
            "/br test – test the reminder",
            "/br minimap – toggle minimap button",
            "/br unmute – clear all mutes",
            "/br auras – list active buffs with name and spell ID",
            "/br reset – reset position and settings",
        },
        AURAS_HEAD    = "Active buffs (name – spell ID):",
        ANY_BLESSING  = "Blessing (any)",
        ANY_AURA      = "Aura (any)",
        ANY_SEAL      = "Seal (any)",
        ANY_ASPECT    = "Aspect (any)",
        MAGE_ARMOR    = "Armor (Frost/Ice/Mage/Molten)",
        LOCK_ARMOR    = "Demon Skin / Demon / Fel Armor",
        SHAMAN_SHIELD = "Lightning / Water / Earth Shield",
        MH_ENCHANT    = "Main-hand weapon imbue",
        OH_ENCHANT    = "Off-hand weapon imbue",
        MH_POISON     = "Main-hand poison",
        OH_POISON     = "Off-hand poison",
        SHOUT         = "Battle / Commanding Shout",
        FLASK         = "Flask",
        WELLRESTED    = "Well-Rested (sleeping bag)",
        HINT_CAST     = "Left-click: cast · Right-click: mute",
        HINT_MUTE     = "Right-click: mute",
        LEFTCLICK     = "Left-click: cast",
        CLICKCAST     = "Left-click casts buff",
        COMBAT        = "Not possible in combat.",
        AFTER_COMBAT  = "Change will be shown after combat.",
        REAGENTS      = "Reagents",
        REAGENT_HINT  = "Warn below (0 = off)",
        REAGENT_LOW   = "%s: %d left",
        REAGENT_CHAT  = "|cffffb000Reagent running low: %s – only %d left!|r",
        IN_BAGS       = "%d in bags",
        EATING        = "Eating … %d s",
        EATING_DONE   = "Almost well fed …",
        HINT_EATING   = "Stay seated",
        VERSION_LOADED = "%s loaded",
        DEV_BUILD      = "Development build loaded",
        HINT_ITEM     = "Left-click: %s · Right-click: choose",
        HINT_NOITEM   = "Not in bags · Right-click: mute",
        LEFTCLICK_USE = "Left-click: use %s",
        RIGHTCLICK_CHOOSE = "Right-click: choose / mute",
        GROUP_SECTION = "Group buffs",
        GROUP_CHECK   = "Check group buffs",
        GROUP_MODE    = "Check in: %s",
        GROUP_MODES   = { always = "Always", instance = "Dungeons & raids only", raid = "Raids only" },
        GROUP_MISSING = "%s missing: %d",
        GROUP_CHAT    = "|cffffb000%s is missing on %d player(s) – rebuff!|r",
        HINT_GROUP    = "Left-click: group · Ctrl+Left-click: single · Right-click: mute",
        HINT_SINGLE   = "Left-click: single · Right-click: mute",
        LEFTCLICK_GROUP = "Left-click: group version on %s",
        LEFTCLICK_SINGLE = "Left-click: single version on %s",
        CTRLCLICK_SINGLE = "Ctrl+Left-click: single version on %s",
    }
end

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
        { key = "armor", level = 1, label = "MAGE_ARMOR",
          ids = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 27124, 43008, 6117, 22782, 22783,
                  27125, 43023, 43024, 30482, 43045, 43046 },
          nameIds = { 168, 7302, 6117, 30482 } },
    },
    WARLOCK = {
        { key = "armor", level = 1, label = "LOCK_ARMOR",
          ids = { 687, 696, 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889, 28176, 28189, 47892, 47893 },
          nameIds = { 687, 706, 28176 } },
    },
    DRUID = {
        { key = "motw", level = 1,
          ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469, 21849, 21850, 26991, 48470 },
          nameIds = { 1126, 21849 } },
        { key = "thorns", level = 6, defaultOff = true,
          ids = { 467, 782, 1075, 8914, 9756, 9910, 26992, 53307 }, nameIds = { 467 } },
    },
    PALADIN = {
        { key = "aura", level = 1, label = "ANY_AURA",
          ids = { 465, 10290, 643, 10291, 1032, 10292, 10293, 27149, 48941, 48942,
                  7294, 10298, 10299, 10300, 10301, 27150, 54042, 19746,
                  19876, 19895, 19896, 27151, 48943, 19888, 19897, 19898, 27152, 48945,
                  19891, 19899, 19900, 27153, 48947, 32223 },
          nameIds = { 465, 7294, 19746, 19876, 19888, 19891, 32223 } },
        { key = "seal", level = 1, label = "ANY_SEAL",
          ids = { 21084, 20154, 20375, 20165, 20166, 20164, 31801, 53736, 53720, 31892 },
          nameIds = { 21084, 20154, 20375, 20165, 20166, 20164, 31801, 53736, 53720, 31892 } },
        { key = "blessing", level = 4, label = "ANY_BLESSING",
          ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932,
                  25782, 25916, 27141, 48933, 48934,
                  19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936,
                  25894, 25918, 27143, 48937, 48938, 20217, 25898, 20911, 25899 },
          nameIds = { 19740, 25782, 19742, 25894, 20217, 25898, 20911, 25899 } },
        { key = "rfury", level = 16, defaultOff = true, ids = { 25780 } },
    },
    SHAMAN = {
        { key = "shield", level = 8, label = "SHAMAN_SHIELD",
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
        { key = "poison_mh", kind = "weapon_mh", level = 20, levelOnly = true, label = "MH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons" },
        { key = "poison_oh", kind = "weapon_oh", level = 20, levelOnly = true, label = "OH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons" },
    },
    HUNTER = {
        { key = "aspect", level = 4, label = "ANY_ASPECT",
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
        } },
    },
    WARLOCK = {
        armor = { variants = {
            { key = "demonskin",  castIds = { 687, 696 } },
            { key = "demonarmor", castIds = { 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889 } },
            { key = "felarmor",   castIds = { 28176, 28189, 47892, 47893 } },
        } },
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
        } },
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
        } },
        blessing = { variants = {
            { key = "might",
              castIds = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932 },
              ids = { 25782, 25916, 27141, 48933, 48934 } },               -- Großer Segen der Macht
            { key = "wisdom",
              castIds = { 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936 },
              ids = { 25894, 25918, 27143, 48937, 48938 } },               -- Großer Segen der Weisheit
            { key = "kings",     castIds = { 20217 }, ids = { 25898 } },   -- Großer Segen der Könige
            { key = "sanctuary", castIds = { 20911 }, ids = { 25899 } },   -- Großer Segen des Refugiums
        } },
    },
    SHAMAN = {
        shield = { variants = {
            { key = "lightning", castIds = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281 } },
            { key = "water",     castIds = { 52127, 52129, 52131, 52134, 52136, 52138, 24398, 33736, 57960 } },
            { key = "earth",     castIds = { 974, 32593, 32594, 49283, 49284 } },
        } },
        imbue_mh = { variants = SHAMAN_IMBUES },
        imbue_oh = { variants = SHAMAN_IMBUES },
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
        } },
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
local FOOD = {
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
local FOOD_PRIORITY = {
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
local FOOD_WEIGHTS = { 1.0, 0.85, 0.7, 0.55, 0.55 }
local FOOD_WEIGHT_OTHER = 0.35
local FOOD_WEIGHT_FIXED = { Movement = 0.25, Profession = 0.1 }
-- Heiler: Healing mindestens 0.55
local FOOD_HEALING_MIN = { PRIEST = 0.55, PALADIN = 0.55, DRUID = 0.55, SHAMAN = 0.55 }

-- Fläschchen-Fallback (Classic), falls die Item-Klasse nicht ermittelbar ist
local FLASK_IDS = { [13506] = true, [13510] = true, [13511] = true, [13512] = true, [13513] = true }

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
--   groupIds : Ränge der Gruppenversion (aufsteigend); Lernstufe und Reagenz je Rang
--              stammen aus REAGENT_SPELLS (RANK_INFO)
--   manaOnly : nur Spieler mit Mana-Klasse prüfen (Klasse, nicht aktueller Ressourcentyp)
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
    minimapAngle = 200,
    minimapHide  = false,
    instanceOnly = true,
    groupCheck   = true,       -- Gruppen-Buffs bei Party-/Raid-Mitgliedern prüfen
    groupMode    = "always",   -- "always" | "instance" (Dungeon & Raid) | "raid"
    clickCast    = true,   -- Linksklick auf Erinnerung zaubert den Buff
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
local MISSING_CONFIRM = 2     -- Sek. durchgehendes Fehlen, bevor gewarnt wird
local shownKeys = {}          -- key -> true, aktuell eingeblendet
local muted = {}              -- key -> Ablaufzeit (GetTime) | math.huge
local ready, unlocked, testUntil = false, false, 0
local Evaluate, RefreshConfig -- forward

local function Print(msg) print("|cff66ccff" .. L.TITLE .. ":|r " .. msg) end

-- Im Kampf: Hinweis, dass die Änderung erst danach sichtbar wird
local function NoteDeferred()
    if InCombatLockdown() then Print(L.AFTER_COMBAT) end
end

-- Namensvergleich ohne Groß-/Kleinschreibung, Leerzeichen und Bindestriche
local function NormName(n) return (n:lower():gsub("[%s%-]", "")) end

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Addon-Version aus der TOC ("" = nicht lesbar)
local function AddonVersion()
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not fn then return "" end
    local ok, v = pcall(fn, ADDON_NAME, "Version")
    if not ok or type(v) ~= "string" or IsSecret(v) then return "" end
    return v
end

-- Versionshinweis beim Login: nur Beta/Alpha und Entwicklerversion (Platzhalter nicht ersetzt)
local function PrintVersionNotice()
    local v = AddonVersion()
    if v == "" or v:find("@project-version@", 1, true) then
        Print(L.DEV_BUILD)
    else
        local lv = v:lower()
        if lv:find("beta", 1, true) or lv:find("alpha", 1, true) then
            Print(L.VERSION_LOADED:format(L.TITLE .. " " .. v))
        end
    end
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
local bagCounts = {}      -- Item-ID -> Anzahl in den Taschen (Scan bei BAG_UPDATE_DELAYED)
local foodScore = {}      -- Item-ID -> Kategorie-Gewicht x Kochkunst-Stufe (Klasse des Spielers)
local xpCache = {}        -- Item-ID -> true/false: Tooltip nennt XP-Bonus (nur geladene Items)
local flaskBySpell = {}   -- Spell-ID des Fläschchen-Effekts -> Item-ID
local flaskEntry          -- Eintrag gen_flask (idSet wird zur Laufzeit ergänzt)
local foodEntry           -- Eintrag gen_wellfed (eatStart = Beginn des Essens, nil = isst nicht)

---------------------------------------------------------------------------
-- Ess-Countdown: Ess-Auren aller FOOD-Items (C_Item.GetItemSpell), unabhängig davon,
-- ob über die Warnung oder direkt aus der Tasche gegessen wird.
---------------------------------------------------------------------------
-- Well Fed kommt laut Item-Tooltip nach "at least 10 seconds" Essen
local EAT_WELLFED_TIME = 10
local eatSpells = {}      -- Spell-ID der Ess-Aura -> true
local eatNames = {}       -- Name der Ess-Aura -> true (die Aura-ID kann vom Item-Spell abweichen)
local eatNorm = {}        -- NormName(Name) -> true
local eatPending = {}     -- Item-ID -> true: Item-Daten noch nicht geladen, Spell folgt
local eatAura             -- zuletzt gefundene Ess-Aura { id, name } (für /br debug)
-- generische Auren, die Essen/Trinken anlegen (WoW Forever: "Food" 433)
local EAT_GENERIC_AURAS = { 433, 430 }   -- Food, Drink

local function AddEatName(name)
    if type(name) ~= "string" or name == "" or IsSecret(name) then return end
    eatNames[name] = true
    eatNorm[NormName(name)] = true
end

-- Ess-Aura eines Essens ermitteln und cachen; nicht geladene Items nachfordern
-- (GET_ITEM_INFO_RECEIVED ruft mit loaded = true erneut auf; hat das geladene Item
-- keinen Spell, wird es nicht erneut angefordert – keine Endlosschleife)
local function ResolveEatSpell(item, loaded)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, spellName, spellID = pcall(C_Item.GetItemSpell, item)
    if ok and type(spellID) == "number" and not IsSecret(spellID) then
        eatSpells[spellID] = true
        AddEatName(spellName)
        eatPending[item] = nil
        return
    end
    if loaded then eatPending[item] = nil; return end
    eatPending[item] = true
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
end

local function ResolveAllEatSpells()
    for _, id in ipairs(EAT_GENERIC_AURAS) do AddEatName(SpellName(id)) end
    for _, list in pairs(FOOD) do
        for _, v in ipairs(list) do ResolveEatSpell(v[1]) end
    end
end

local function IsEatAura(a)
    if a.id and eatSpells[a.id] then return true end
    local n = a.name
    if type(n) ~= "string" or IsSecret(n) then return false end
    return eatNames[n] == true or eatNorm[NormName(n)] == true
end

-- Startzeit einer aktiven Ess-Aura (expirationTime - duration), nil = isst nicht oder
-- Laufzeit nicht lesbar (Secret) -> normale Anzeige ohne Countdown
local function FindEatStart(scan)
    eatAura = nil
    if not scan then return nil end
    for _, a in ipairs(scan.list) do
        if IsEatAura(a) then
            eatAura = { id = a.id, name = a.name }
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
local function EatText(e)
    local left = (e.eatStart or 0) + EAT_WELLFED_TIME - GetTime()
    if left > 0 then return L.EATING:format(math.ceil(left)) end
    return L.EATING_DONE
end

local function BuildFoodScores(class)
    local weights = {}
    for cat in pairs(FOOD) do weights[cat] = FOOD_WEIGHT_FIXED[cat] or FOOD_WEIGHT_OTHER end
    for i, cat in ipairs(FOOD_PRIORITY[class] or {}) do
        weights[cat] = FOOD_WEIGHTS[i] or FOOD_WEIGHT_OTHER
    end
    if FOOD_HEALING_MIN[class] then
        weights.Healing = math.max(weights.Healing, FOOD_HEALING_MIN[class])
    end
    wipe(foodScore)
    for cat, list in pairs(FOOD) do
        for _, v in ipairs(list) do
            local score = weights[cat] * v[2]
            if not foodScore[v[1]] or score > foodScore[v[1]] then foodScore[v[1]] = score end
        end
    end
end

-- Item-Level und benötigte Stufe (nil, falls das Item noch nicht geladen ist)
local function ItemLevels(item)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, name, _, _, ilvl, minLevel = pcall(fn, item)
    if not ok or not name or IsSecret(ilvl) or IsSecret(minLevel) then return nil end
    return ilvl, minLevel
end

-- Nennt der Tooltip einen XP-Bonus? (enUS "experience", deDE "Erfahrung")
local function HasXPBonus(item)
    if xpCache[item] ~= nil then return xpCache[item] end
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
    if ItemLevels(item) then xpCache[item] = found end
    return found
end

local function IsFlaskItem(item)
    if FLASK_IDS[item] then return true end
    local flaskSub = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Flask
    if not flaskSub then return false end
    local consumable = (Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    return ok and classID == consumable and subClassID == flaskSub
end

-- Spell-ID des Fläschchen-Effekts lernen, damit auch neue Fläschchen als aktiv erkannt werden
local function LearnFlaskSpell(item)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, _, spellID = pcall(C_Item.GetItemSpell, item)
    if not ok or type(spellID) ~= "number" or IsSecret(spellID) then return end
    flaskBySpell[spellID] = item
    if flaskEntry then flaskEntry.idSet[spellID] = true end
    if db then db.flaskSpells[spellID] = true end
end

-- Taschen 0..NUM_BAG_SLOTS durchgehen (ohne Bank)
local function ScanBags()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
    wipe(bagCounts)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and type(slots) == "number" and not IsSecret(slots) then
            for slot = 1, slots do
                local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok and type(info) == "table" and not IsSecret(info) then
                    local id, n = info.itemID, info.stackCount or 1
                    if type(id) == "number" and not IsSecret(id) and not IsSecret(n) then
                        bagCounts[id] = (bagCounts[id] or 0) + n
                    end
                end
            end
        end
    end
    for id in pairs(bagCounts) do
        if IsFlaskItem(id) then LearnFlaskSpell(id) end
    end
end

-- passende Items aus den Taschen, beste Wahl zuerst: { { id, count }, ... }
local function ItemChoices(e)
    local list = {}
    if e.itemKind == "food" then
        local lvl = UnitLevel("player") or 1
        for id, n in pairs(bagCounts) do
            if foodScore[id] then
                local _, minLevel = ItemLevels(id)
                if not minLevel or minLevel <= lvl then
                    list[#list + 1] = { id = id, count = n, xp = HasXPBonus(id), score = foodScore[id] }
                end
            end
        end
        table.sort(list, function(a, b)
            if a.xp ~= b.xp then return a.xp end
            if a.score ~= b.score then return a.score > b.score end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    elseif e.itemKind == "flask" then
        local last = cdb and cdb.lastFlask
        for id, n in pairs(bagCounts) do
            if IsFlaskItem(id) then
                list[#list + 1] = { id = id, count = n, ilvl = ItemLevels(id) or 0 }
            end
        end
        table.sort(list, function(a, b)
            if (a.id == last) ~= (b.id == last) then return a.id == last end
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    end
    return list
end

local function EntryLabel(e)
    if e.kind == "reagent" then return ItemName(e.item) end
    if e.label then return L[e.label] end
    local first = (e.ids or e.knownIds or {})[1]
    return (first and SpellName(first)) or e.key
end

local function EntryIcon(e)
    if e.kind == "reagent" then return ItemIcon(e.item) or FALLBACK_ICON end
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

local function ComputeKnown(e)
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
    if e.kind == "reagent" then return ReagentThreshold(e.item) > 0 end
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
                    if not IsSecret(src) and src == "player" then
                        if id then own.ids[id] = true end
                        if name then own.names[name] = true end
                    end
                    local icon = aura.icon
                    if IsSecret(icon) then icon = nil end
                    -- Laufzeit (für den Ess-Countdown); Secret-Werte -> nil
                    local dur, exp = aura.duration, aura.expirationTime
                    if IsSecret(dur) or IsSecret(exp) then dur, exp = nil, nil end
                    list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp }
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
            list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp }
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
    if e.kind == "weapon_mh" or e.kind == "weapon_oh" then
        local slot = (e.kind == "weapon_mh") and 16 or 17
        if not HasWeaponIn(slot) then return false end
        local mh, oh = WeaponEnchants()
        if mh == nil then return nil end
        if slot == 16 then return not mh end
        return not oh
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
local groupState = {}         -- key -> { missing = { { unit, name }, ... }, unknown = bool }
local groupDirty, groupLastScan, groupTimerPending = true, 0, false
local GROUP_THROTTLE, GROUP_POLL = 0.5, 2

-- Ja/Nein-Abfrage einer Unit-Funktion; nil = nicht verfügbar oder Secret-Wert
local function UnitFlag(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or IsSecret(v) then return nil end
    return v and true or false
end

local function GroupModeOk()
    if db.groupMode == "instance" then return InGroupInstance() end
    if db.groupMode == "raid" then
        local inInst, t = IsInInstance()
        return inInst and t == "raid"
    end
    return true
end

-- Gruppen-Check für einen (erlernten, aktivierten) Eintrag aktiv?
local function GroupActive(e)
    return e.groupIds ~= nil and db.groupCheck and IsInGroup ~= nil and IsInGroup() and GroupModeOk()
end

local function GroupUnits()
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
-- Unbekannte (Secret-)Werte zählen als "nicht prüfbar" → Spieler wird übersprungen.
local function UnitUsable(unit)
    if UnitFlag(UnitExists, unit) ~= true then return false end
    if UnitIsConnected and UnitFlag(UnitIsConnected, unit) ~= true then return false end
    if UnitFlag(UnitIsDeadOrGhost, unit) ~= false then return false end
    if UnitIsVisible and UnitFlag(UnitIsVisible, unit) ~= true then return false end
    if UnitFlag(UnitIsUnit, unit, "player") == true then return true end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if not ok or IsSecret(inRange) or IsSecret(checked) then return false end
        if checked and not inRange then return false end
    end
    return true
end

local function UnitClassFile(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and class and not IsSecret(class) then return class end
end

local function UnitDisplayName(unit)
    local ok, n = pcall(UnitName, unit)
    if ok and n and not IsSecret(n) then return n end
    return "?"
end

local function ScanGroup()
    wipe(groupState)
    local list = {}
    for _, e in ipairs(entries) do
        if e.groupIds and knownCache[e.key] and IsEnabled(e) then
            list[#list + 1] = e
            groupState[e.key] = { missing = {}, unknown = false }
        end
    end
    if #list == 0 then return end
    for _, unit in ipairs(GroupUnits()) do
        if UnitUsable(unit) then
            local ids, names, unreliable, _, auras = ScanAuras(unit)
            local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auras } or nil
            local class = UnitClassFile(unit)
            for _, e in ipairs(list) do
                if not e.manaOnly or (class and MANA_CLASSES[class]) then
                    local st = groupState[e.key]
                    -- Gruppen- und Einzelversion stehen beide in e.idSet / e.names
                    local m = CheckMissing(e, scan)
                    if m == true then
                        st.missing[#st.missing + 1] = { unit = unit, name = UnitDisplayName(unit) }
                    elseif m == nil then
                        st.unknown = true
                    end
                end
            end
        end
    end
end

-- Auswertung, wenn fällig (nie im Kampf)
local function GroupScanIfDue(now)
    if InCombatLockdown() then return end
    if (groupDirty or now - groupLastScan >= GROUP_POLL) and now - groupLastScan >= GROUP_THROTTLE then
        ScanGroup()
        groupLastScan, groupDirty = now, false
    end
end

-- Aura/Roster geändert: neu auswerten, aber höchstens alle GROUP_THROTTLE Sek.
local function MarkGroupDirty()
    groupDirty = true
    if groupTimerPending then return end
    groupTimerPending = true
    C_Timer.After(GROUP_THROTTLE, function()
        groupTimerPending = false
        Evaluate()
    end)
end

-- true = jemandem fehlt der Buff, false = alle haben ihn, nil = unbekannt
local function GroupMissing(e)
    local st = groupState[e.key]
    if not st then return nil end
    e.groupMissing = st.missing
    if #st.missing > 0 then return true end
    if st.unknown then return nil end
    return false
end

-- höchster erlernter Rang der Gruppenversion + dessen Reagenz; Namens-Fallback wie bei Reagenzien
local function GroupSpellFor(e)
    local ids = e.groupIds
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
local function GroupActionFor(e)
    local target = e.groupMissing and e.groupMissing[1]
    local single = CastSpellFor(e)
    if not target or not single then return nil end
    local a = { unit = target.unit, targetName = target.name, ctrlSpell = single, ctrlUnit = target.unit }
    local gspell, item = GroupSpellFor(e)
    if gspell and (not item or (ItemCount(item) or 1) > 0) then
        a.spell, a.isGroup = gspell, true
    else
        a.spell = single
    end
    return a
end

-- Namen der Spieler ohne Buff: max. 5, dann "+N"
local function MissingNames(e)
    local list, out = e.groupMissing or {}, {}
    for i = 1, math.min(5, #list) do out[i] = list[i].name end
    local s = table.concat(out, ", ")
    if #list > 5 then s = s .. " +" .. (#list - 5) end
    return s
end

---------------------------------------------------------------------------
-- Einblendung (Liste fehlender Buffs)
---------------------------------------------------------------------------
-- Kampfsperre: Die Zeilen sind Secure Buttons. Sie und ihr Parent (anchor) werden in
-- InCombatLockdown() weder gezeigt/versteckt, verschoben noch umattributiert.
-- Änderungen an der Liste werden nach dem Kampf (PLAYER_REGEN_ENABLED) angewendet.
local ROW_HEIGHT = 42

local anchor = CreateFrame("Frame", "BuffReminderAnchor", UIParent)
anchor:SetSize(300, ROW_HEIGHT)
anchor:SetFrameStrata("HIGH")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:Hide()

local pulse = anchor:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.55)
fade:SetDuration(0.9)
fade:SetSmoothing("IN_OUT")

local function SavePoint()
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
local OpenMuteMenu -- forward

-- Secure Buttons im Mainline-Client lösen je nach CVar ActionButtonUseKeyDown beim
-- Drücken ODER beim Loslassen aus. Daher werden beide Phasen registriert; die secure
-- Aktion läuft genau einmal, und unser Rechtsklick reagiert nur in derselben Phase.
local function GetCVarFlag(name)
    if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name) and true or false end
    if GetCVarBool then return GetCVarBool(name) and true or false end
    return false
end

local function HasKeyDownCVar()
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar("ActionButtonUseKeyDown") ~= nil end
    if GetCVar then return GetCVar("ActionButtonUseKeyDown") ~= nil end
    return false
end

local function IsActionPhase(down)
    return (down and true or false) == GetCVarFlag("ActionButtonUseKeyDown")
end

-- Klick-Aktion einer Zeile setzen (nur außerhalb des Kampfes aufrufen). a = nil oder
--   { spell = ID/Name | item = Item-ID, unit = Ziel (Standard "player"),
--     ctrlSpell, ctrlUnit = Strg+Linksklick (Gruppen-Zeilen), isGroup, targetName }
-- Ohne spell/item tut Linksklick nichts.
local function SetRowAction(r, a)
    a = a or {}
    local sig = table.concat({ tostring(a.spell), tostring(a.item), tostring(a.unit),
        tostring(a.ctrlSpell), tostring(a.ctrlUnit) }, "|")
    r.action = a
    r.castSpell, r.useItem = a.spell, a.item
    if r.actionSig == sig then return end
    r.actionSig = sig
    if a.spell then
        r:SetAttribute("type1", "spell")
        r:SetAttribute("spell1", a.spell)
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

-- Zeilenhöhe: 2 Textzeilen (Standard) oder 3 (Gruppen-Zeile mit Namenszeile)
local ROW_HEIGHT_GROUP = 56

local function SetRowLines(r, three)
    if r.threeLines == three then return end
    r.threeLines = three
    local top, mid, bottom = 7, 0, -8
    if three then top, mid, bottom = 14, 0, -14 end
    r:SetHeight(three and ROW_HEIGHT_GROUP or ROW_HEIGHT)
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 10, top)
    r.text:SetPoint("RIGHT", -8, top)
    r.names:SetPoint("LEFT", r.icon, "RIGHT", 10, mid)
    r.names:SetPoint("RIGHT", -8, mid)
    r.hint:SetPoint("LEFT", r.icon, "RIGHT", 10, bottom)
    r.hint:SetPoint("RIGHT", -8, bottom)
    if three then r.names:Show() else r.names:Hide() end
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, anchor, "SecureActionButtonTemplate, BackdropTemplate")
    r:SetSize(300, ROW_HEIGHT)
    r:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    r:SetBackdropColor(0.08, 0.04, 0, 0.75)
    r:SetBackdropBorderColor(1, 0.7, 0.1, 0.9)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 10, 7)
    r.text:SetPoint("RIGHT", -8, 7)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.text:SetTextColor(1, 0.8, 0.2)

    -- Hinweiszeile (klein, grau) unter dem Haupttext
    r.hint = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.hint:SetPoint("LEFT", r.icon, "RIGHT", 10, -8)
    r.hint:SetPoint("RIGHT", -8, -8)
    r.hint:SetJustifyH("LEFT")
    r.hint:SetWordWrap(false)

    -- Namenszeile der Gruppen-Zeilen (Spieler ohne Buff), zwischen Haupttext und Hinweis
    r.names = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.names:SetJustifyH("LEFT")
    r.names:SetWordWrap(false)
    r.names:Hide()
    r.threeLines = false

    if i == 1 then
        r:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    else
        r:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -3)
    end

    -- Linksklick = secure Aktion (Zauber auf sich selbst), Rechtsklick = Stumm-Menü
    r:SetAttribute("unit1", "player")
    if HasKeyDownCVar() then
        r:RegisterForClicks("AnyUp", "AnyDown")
    else
        r:RegisterForClicks("AnyUp")
    end
    r:RegisterForDrag("LeftButton")
    r:SetScript("PostClick", function(self, button, down)
        if not IsActionPhase(down) then return end
        if button == "LeftButton" then
            -- per Linksklick benutztes Fläschchen als "zuletzt benutzt" merken
            if self.useItem and self.entry and self.entry.itemKind == "flask" then
                cdb.lastFlask = self.useItem
            end
            return
        end
        if button == "RightButton" and self.entry and not unlocked then OpenMuteMenu(self) end
    end)
    r:SetScript("OnDragStart", function()
        if unlocked and not InCombatLockdown() then anchor:StartMoving() end
    end)
    r:SetScript("OnDragStop", function()
        if unlocked and not InCombatLockdown() then SavePoint() end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(EntryLabel(self.entry), 1, 0.82, 0)
        local a = self.action or {}
        if a.ctrlSpell then
            -- Gruppen-Zeile: Ziel nennen
            local who = a.targetName or "?"
            GameTooltip:AddLine((a.isGroup and L.LEFTCLICK_GROUP or L.LEFTCLICK_SINGLE):format(who), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.CTRLCLICK_SINGLE:format(who), 0.8, 0.8, 0.8)
        elseif self.castSpell then
            GameTooltip:AddLine(L.LEFTCLICK, 0.8, 0.8, 0.8)
        end
        if self.useItem then
            GameTooltip:AddLine(L.LEFTCLICK_USE:format(ItemName(self.useItem)), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.RIGHTCLICK_CHOOSE, 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(L.RIGHTCLICK, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rows[i] = r
    return r
end

-- dragMode: Verschiebe-Modus (eine Zeile "Ziehen zum Verschieben", Linksklick zaubert nicht)
local function ShowRows(list, dragMode)
    if InCombatLockdown() then return end   -- Secure Frames: nur außerhalb des Kampfes
    for i, e in ipairs(list) do
        local r = GetRow(i)
        r.icon:SetTexture(EntryIcon(e))
        if dragMode then
            r.entry = nil
            SetRowAction(r, nil)
            SetRowLines(r, false)
            r.text:SetText(L.DRAG)
            r.hint:SetText("")
        elseif e.groupActive then
            -- Gruppen-Zeile: Anzahl, Namen, Gruppen-/Einzel-Klick auf den ersten Spieler ohne Buff
            r.entry = e
            local a = GroupActionFor(e)
            SetRowAction(r, a)
            SetRowLines(r, true)
            r.text:SetText(L.GROUP_MISSING:format(EntryLabel(e), #(e.groupMissing or {})))
            r.names:SetText(MissingNames(e))
            if a then
                r.hint:SetText(a.isGroup and L.HINT_GROUP or L.HINT_SINGLE)
            else
                r.hint:SetText(L.HINT_MUTE)
            end
        else
            r.entry = e
            SetRowLines(r, false)
            local spell = CastSpellFor(e)
            -- Essen/Fläschchen: Linksklick benutzt die beste Wahl aus den Taschen
            local item, noItem
            if not spell and e.itemKind and db.clickCast then
                local choices = ItemChoices(e)
                item = choices[1] and choices[1].id
                noItem = item == nil
            end
            SetRowAction(r, (spell or item) and { spell = spell, item = item } or nil)
            if e.kind == "reagent" then
                r.text:SetText(L.REAGENT_LOW:format(EntryLabel(e), e.count or 0))
            elseif e.eatStart then
                r.text:SetText(EatText(e))   -- Ess-Countdown (OnUpdate des anchor zählt weiter)
            else
                r.text:SetText(L.MISSING:format(EntryLabel(e)))
            end
            if e.eatStart then
                r.hint:SetText(L.HINT_EATING)
            elseif spell then
                r.hint:SetText(L.HINT_CAST)
            elseif item then
                r.hint:SetText(L.HINT_ITEM:format(ItemName(item)))
            elseif noItem then
                r.hint:SetText(L.HINT_NOITEM)
            else
                r.hint:SetText(L.HINT_MUTE)
            end
        end
        r:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
        SetRowAction(rows[i], nil)
    end
    if #list > 0 then
        if not anchor:IsShown() then
            anchor:SetAlpha(1)
            anchor:Show()
            pulse:Play()
        end
    else
        pulse:Stop()
        anchor:Hide()
    end
end

-- Ess-Countdown: nur den Text der Zeilen aktualisieren (höchstens alle 0,2 Sek.).
-- FontStrings sind nicht geschützt → auch im Kampf erlaubt; keine Attribute, kein Show/Hide.
local EAT_TICK = 0.2
anchor:SetScript("OnUpdate", function(self, el)
    self.eatTick = (self.eatTick or 0) + el
    if self.eatTick < EAT_TICK then return end
    self.eatTick = 0
    for _, r in ipairs(rows) do
        if r:IsShown() and r.entry and r.entry.eatStart then r.text:SetText(EatText(r.entry)) end
    end
end)

local function PlayAlertSound()
    if db.sound == "aus" then return end
    PlaySound(SOUNDS[db.sound] or SOUNDS.ping, "Master")
end

---------------------------------------------------------------------------
-- Rechtsklick-Menü (Stummschalten, bei Essen/Fläschchen mit Item-Auswahl darüber)
-- Die Item-Auswahl (itemPanel) enthält Secure Buttons und ist daher ein eigener
-- Frame: Sie wird nur außerhalb des Kampfes gezeigt, befüllt und versteckt. Das
-- Stumm-Menü (menu) ist unsicher und funktioniert auch im Kampf; mit Item-Auswahl
-- hängt es ohne Titel unter dem itemPanel.
---------------------------------------------------------------------------
local MENU_WIDTH = 230
local MENU_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local menu = CreateFrame("Frame", "BuffReminderMuteMenu", UIParent, "BackdropTemplate")
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:Hide()
menu:SetBackdrop(MENU_BACKDROP)
menu:SetBackdropColor(0, 0, 0, 0.92)
tinsert(UISpecialFrames, "BuffReminderMuteMenu")   -- ESC schließt

menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menu.title:SetPoint("TOPLEFT", 10, -9)
menu.title:SetPoint("RIGHT", -10, 0)
menu.title:SetJustifyH("LEFT")

local MENU_OPTIONS = {
    { L.MUTE5, 300 }, { L.MUTE15, 900 }, { L.MUTE60, 3600 },
    { L.MUTESESSION, math.huge }, { L.CANCEL, nil },
}
menu.buttons = {}
for i, opt in ipairs(MENU_OPTIONS) do
    local b = CreateFrame("Button", nil, menu)
    b:SetSize(MENU_WIDTH - 12, 18)
    menu.buttons[i] = b
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetText(opt[1])
    if not opt[2] then fs:SetTextColor(0.7, 0.7, 0.7) end
    b:SetScript("OnClick", function()
        if opt[2] and menu.key then
            muted[menu.key] = (opt[2] == math.huge) and math.huge or (GetTime() + opt[2])
            NoteDeferred()
            Evaluate()
        end
        menu:Hide()
    end)
end

-- mit Titel (eigenständig) oder ohne (unter der Item-Auswahl)
local function LayoutMenu(withTitle)
    local top = withTitle and -26 or -8
    for i, b in ipairs(menu.buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 6, top - (i - 1) * 19)
    end
    if withTitle then menu.title:Show() else menu.title:Hide() end
    menu:SetSize(MENU_WIDTH, -top + #MENU_OPTIONS * 19 + 8)
end
LayoutMenu(true)

-- Item-Auswahl (Secure Buttons: type "item")
local MAX_ITEM_CHOICES = 12
local itemPanel = CreateFrame("Frame", "BuffReminderItemMenu", UIParent, "BackdropTemplate")
itemPanel:SetFrameStrata("DIALOG")
itemPanel:SetClampedToScreen(true)
itemPanel:EnableMouse(true)
itemPanel:Hide()
itemPanel:SetBackdrop(MENU_BACKDROP)
itemPanel:SetBackdropColor(0, 0, 0, 0.92)
itemPanel.buttons = {}

itemPanel.title = itemPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
itemPanel.title:SetPoint("TOPLEFT", 10, -9)
itemPanel.title:SetPoint("RIGHT", -10, 0)
itemPanel.title:SetJustifyH("LEFT")

-- Trenner zu den Stumm-Optionen
itemPanel.sep = itemPanel:CreateTexture(nil, "ARTWORK")
itemPanel.sep:SetColorTexture(1, 0.8, 0.2, 0.35)
itemPanel.sep:SetHeight(1)
itemPanel.sep:SetPoint("BOTTOMLEFT", 10, 6)
itemPanel.sep:SetPoint("BOTTOMRIGHT", -10, 6)

local function GetItemButton(i)
    if itemPanel.buttons[i] then return itemPanel.buttons[i] end
    local b = CreateFrame("Button", nil, itemPanel, "SecureActionButtonTemplate")
    b:SetSize(MENU_WIDTH - 12, 20)
    b:SetPoint("TOPLEFT", 6, -26 - (i - 1) * 21)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("RIGHT", -6, 0)
    b.count:SetJustifyH("RIGHT")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", b.count, "LEFT", -6, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetAttribute("type", "item")
    if HasKeyDownCVar() then
        b:RegisterForClicks("AnyUp", "AnyDown")
    else
        b:RegisterForClicks("AnyUp")
    end
    b:SetScript("PostClick", function(self, _, down)
        if not IsActionPhase(down) then return end
        if itemPanel.entry and itemPanel.entry.itemKind == "flask" then cdb.lastFlask = self.itemID end
        menu:Hide()   -- schließt auch das itemPanel
    end)
    -- Item-Tooltip beim Überfahren. HookScript statt SetScript: ergänzt nur die Anzeige,
    -- die Secure-Klickfunktion des Buttons bleibt unberührt.
    b:HookScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    itemPanel.buttons[i] = b
    return b
end

-- Tooltip ausblenden, falls er zu einem Button der Item-Auswahl gehört
local function HideItemTooltip()
    for _, b in ipairs(itemPanel.buttons) do
        if GameTooltip:IsOwned(b) then GameTooltip:Hide(); return end
    end
end
itemPanel:SetScript("OnHide", HideItemTooltip)

-- Item-Auswahl befüllen (nur außerhalb des Kampfes); false = nichts anzuzeigen
local function FillItemPanel(e, choices)
    if InCombatLockdown() then return false end
    local n = math.min(#choices, MAX_ITEM_CHOICES)
    if n == 0 then return false end
    itemPanel.entry = e
    itemPanel.title:SetText(EntryLabel(e))
    for i = 1, n do
        local c, b = choices[i], GetItemButton(i)
        b.itemID = c.id
        b:SetAttribute("item", "item:" .. c.id)
        b.icon:SetTexture(ItemIcon(c.id) or FALLBACK_ICON)
        b.name:SetText(ItemName(c.id))
        b.count:SetText(c.count)
        b:Show()
        -- Auswahl neu befüllt, während die Maus darauf steht: Tooltip nachziehen
        if GameTooltip:IsOwned(b) then GameTooltip:SetItemByID(c.id); GameTooltip:Show() end
    end
    for i = n + 1, #itemPanel.buttons do
        local b = itemPanel.buttons[i]
        if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
        b:Hide()
        b.itemID = nil
        b:SetAttribute("item", nil)
    end
    itemPanel:SetSize(MENU_WIDTH, 26 + n * 21 + 10)
    return true
end

local function HideItemPanel()
    if itemPanel:IsShown() and not InCombatLockdown() then itemPanel:Hide() end
end

-- Menü geschlossen: Item-Auswahl und deren Tooltip ebenfalls schließen
-- (im Kampf ist die Item-Auswahl nie offen, s. CloseItemPanelForCombat)
menu:SetScript("OnHide", function()
    HideItemTooltip()
    HideItemPanel()
end)

-- Schließt sich, wenn die Maus Menü und Item-Auswahl 2 Sek. lang verlassen hat
menu:SetScript("OnUpdate", function(self, el)
    if MouseIsOver(self) or (itemPanel:IsShown() and MouseIsOver(itemPanel)) then self.away = 0 else
        self.away = (self.away or 0) + el
        if self.away > 2 then self:Hide() end
    end
end)

-- Rechtsklick auf eine Erinnerung. Essen/Fläschchen (außerhalb des Kampfes und mit
-- "Linksklick zaubert Buff"): passende Items oben, darunter die Stumm-Optionen.
function OpenMuteMenu(row)
    local e = row.entry
    menu.key = e.key
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    local withItems = e.itemKind and db.clickCast and not InCombatLockdown()
        and FillItemPanel(e, ItemChoices(e))
    menu:ClearAllPoints()
    if withItems then
        itemPanel:ClearAllPoints()
        itemPanel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 10, y / s + 10)
        itemPanel:Show()
        LayoutMenu(false)
        menu:SetPoint("TOPLEFT", itemPanel, "BOTTOMLEFT", 0, 3)
    else
        HideItemPanel()
        LayoutMenu(true)
        menu.title:SetText(EntryLabel(e))
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 10, y / s + 10)
    end
    menu.away = 0
    menu:Show()
end

-- Taschen geändert: offene Item-Auswahl neu befüllen (oder schließen, wenn leer)
local function RefreshItemPanel()
    if not itemPanel:IsShown() or InCombatLockdown() then return end
    if not FillItemPanel(itemPanel.entry, ItemChoices(itemPanel.entry)) then menu:Hide() end
end

-- Kampfbeginn: Item-Auswahl (Secure Buttons) schließen, solange das noch erlaubt ist
local function CloseItemPanelForCombat()
    if itemPanel:IsShown() then
        itemPanel:Hide()
        menu:Hide()
    end
end

---------------------------------------------------------------------------
-- Prüflogik
---------------------------------------------------------------------------
function Evaluate()
    if not db or not ready then return end
    -- Im Kampf wird nur der Zustand aktualisiert; die Warnliste (Secure Buttons)
    -- bleibt unverändert und wird bei PLAYER_REGEN_ENABLED neu aufgebaut.
    local combat = InCombatLockdown()
    if layoutPending and not combat then ApplyLayout() end

    if unlocked then
        if not combat then
            ShowRows({ { key = "_drag", label = "DRAG", icon = EntryIcon(entries[1] or {}) } }, true)
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
        ShowRows(list)
        return
    end

    local list, newOnes = {}, false
    if db.enabled and not Suppressed() then
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
        if not combat and db.groupCheck then GroupScanIfDue(now) end
        -- Isst der Spieler gerade? (nil auch bei nicht lesbarer Aura → normale Anzeige)
        if foodEntry then foodEntry.eatStart = FindEatStart(scan) end

        for _, e in ipairs(entries) do
            local relevant = knownCache[e.key] and IsEnabled(e) and (not e.general or instOk)
            -- Gruppen-Check aktiv: Gruppen-Zeile ersetzt die Selbst-Zeile (gleicher Key)
            e.groupActive = relevant and GroupActive(e) or false
            if relevant then
                local m
                if e.groupActive then
                    if not combat then m = GroupMissing(e) end   -- im Kampf: Zustand beibehalten
                else
                    m = CheckMissing(e, scan)
                end
                if m ~= nil then missing[e.key] = m end   -- nil: Zustand beibehalten (Kampf/Secret)
                -- Entprellung: nil (unbekannt) lässt missingSince unverändert
                if m == true then
                    missingSince[e.key] = missingSince[e.key] or now
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
                    elseif e.groupActive then
                        Print(L.GROUP_CHAT:format(EntryLabel(e), #(e.groupMissing or {})))
                    else
                        Print(L.CHAT:format(EntryLabel(e)))
                    end
                end
            end
        end
    end

    if combat then
        -- Meldung, Ton und Anzeige folgen nach dem Kampf
        if RefreshConfig then RefreshConfig() end
        return
    end

    wipe(shownKeys)
    for _, e in ipairs(list) do shownKeys[e.key] = true end
    if newOnes then PlayAlertSound() end   -- Ton nur bei neu fehlendem Buff, keine Wiederholung
    ShowRows(list)

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
local configRows = {}
local reagentRows = {}

local function FormatMute(left)
    if left == math.huge then return L.SESSION end
    left = math.ceil(left)
    return ("%d:%02d"):format(math.floor(left / 60), left % 60)
end

function RefreshConfig()
    if not config or not config:IsShown() then return end
    for _, w in ipairs(configRows) do
        local e = w.entry
        local known = knownCache[e.key]
        w.cb:SetChecked(IsEnabled(e))
        w.icon:SetTexture(EntryIcon(e))
        w.name:SetText(EntryLabel(e))
        if known then
            w.cb:Enable()
            w.icon:SetDesaturated(false)
            w.name:SetTextColor(1, 1, 1)
            local left = MuteRemaining(e.key)
            if left then
                w.status:SetText(L.MUTED:format(FormatMute(left)))
                w.status:SetTextColor(1, 0.4, 0.3)
            elseif e.general and db.instanceOnly and not InGroupInstance() then
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
    for _, w in ipairs(reagentRows) do
        local e = w.entry
        w.icon:SetTexture(EntryIcon(e))
        w.name:SetText(EntryLabel(e))
        if not w.edit:HasFocus() then w.edit:SetText(tostring(ReagentThreshold(e.item))) end
        if knownCache[e.key] then
            w.icon:SetDesaturated(false)
            w.name:SetTextColor(1, 1, 1)
            local left = MuteRemaining(e.key)
            if left then
                w.status:SetText(L.MUTED:format(FormatMute(left)))
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
    end
    config.enabledCB:SetChecked(db.enabled)
    config.instCB:SetChecked(db.instanceOnly)
    config.castCB:SetChecked(db.clickCast)
    if config.groupCB then
        config.groupCB:SetChecked(db.groupCheck)
        config.groupModeBtn:SetText(L.GROUP_MODE:format(L.GROUP_MODES[db.groupMode] or db.groupMode))
    end
    config.soundBtn:SetText(L.SOUND:format(L.SOUNDS[db.sound] or db.sound))
    config.moveBtn:SetText(unlocked and L.LOCK or L.MOVE)
end

local function MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

local function MakeEntryRow(parent, e, y)
    local w = { entry = e }
    w.cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    w.cb:SetSize(24, 24)
    w.cb:SetPoint("TOPLEFT", 16, y)
    w.cb:SetScript("OnClick", function(self)
        cdb.buffs[e.key] = self:GetChecked() and true or false
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
    w.status:SetPoint("RIGHT", parent, "TOPLEFT", 424, y - 12)
    w.status:SetJustifyH("RIGHT")
    configRows[#configRows + 1] = w
end

-- Reagenz-Zeile: Icon, Name, Eingabefeld für die Schwelle (0-50), Status
local function MakeReagentRow(parent, e, y)
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
    reagentRows[#reagentRows + 1] = w
end

local function MakeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

local function MakeCheck(parent, text, x, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(text)
    cb:SetScript("OnClick", onClick)
    return cb
end

local function BuildConfig()
    config = CreateFrame("Frame", "BuffReminderConfig", UIParent, "BackdropTemplate")
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

    local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText(L.TITLE)

    local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local y = -48
    local className = UnitClass("player")
    MakeHeader(config, L.CLASS_SECTION:format(className or "?"), y)
    y = y - 22
    if #classEntries == 0 then
        local fs = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", 20, y)
        fs:SetText(L.NO_CLASS)
        y = y - 20
    end
    for _, e in ipairs(classEntries) do
        MakeEntryRow(config, e, y)
        y = y - 26
    end

    y = y - 10
    MakeHeader(config, L.GENERAL, y)
    y = y - 22
    for _, e in ipairs(GENERAL_BUFFS) do
        MakeEntryRow(config, e, y)
        y = y - 26
    end

    -- Gruppen-Buffs: nur für Klassen mit Gruppen-Buffs (Priester, Magier, Druide)
    local hasGroup = false
    for _, e in ipairs(classEntries) do
        if e.groupIds then hasGroup = true end
    end
    if hasGroup then
        y = y - 10
        MakeHeader(config, L.GROUP_SECTION, y)
        y = y - 22
        config.groupCB = MakeCheck(config, L.GROUP_CHECK, 16, y, function(self)
            db.groupCheck = self:GetChecked() and true or false
            MarkGroupDirty()
            NoteDeferred()
            Evaluate()
        end)
        config.groupModeBtn = MakeButton(config, "", 200)
        config.groupModeBtn:SetPoint("TOPRIGHT", config, "TOPLEFT", 424, y)
        config.groupModeBtn:SetScript("OnClick", function()
            local idx = 1
            for i, k in ipairs(GROUP_MODE_ORDER) do if k == db.groupMode then idx = i end end
            db.groupMode = GROUP_MODE_ORDER[idx % #GROUP_MODE_ORDER + 1]
            MarkGroupDirty()
            NoteDeferred()
            Evaluate()
            RefreshConfig()
        end)
        y = y - 26
    end

    -- Reagenzien: nur die der eigenen Klasse; Abschnitt entfällt ohne Reagenzien
    if #reagentEntries > 0 then
        y = y - 10
        MakeHeader(config, L.REAGENTS, y)
        local hint = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPRIGHT", config, "TOPLEFT", 424, y - 2)
        hint:SetJustifyH("RIGHT")
        hint:SetText(L.REAGENT_HINT)
        y = y - 22
        for _, e in ipairs(reagentEntries) do
            MakeReagentRow(config, e, y)
            y = y - 26
        end
    end

    y = y - 12
    config.enabledCB = MakeCheck(config, L.ENABLED, 16, y, function(self)
        db.enabled = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    config.instCB = MakeCheck(config, L.INSTANCE_ONLY, 160, y, function(self)
        db.instanceOnly = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 26
    config.castCB = MakeCheck(config, L.CLICKCAST, 16, y, function(self)
        db.clickCast = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 32

    config.soundBtn = MakeButton(config, "", 100)
    config.soundBtn:SetPoint("TOPLEFT", 18, y)
    config.soundBtn:SetScript("OnClick", function()
        local idx = 1
        for i, k in ipairs(SOUND_ORDER) do if k == db.sound then idx = i end end
        db.sound = SOUND_ORDER[idx % #SOUND_ORDER + 1]
        PlayAlertSound()
        RefreshConfig()
    end)

    config.moveBtn = MakeButton(config, L.MOVE, 90)
    config.moveBtn:SetPoint("LEFT", config.soundBtn, "RIGHT", 4, 0)
    config.moveBtn:SetScript("OnClick", function()
        if InCombatLockdown() then Print(L.COMBAT); return end
        unlocked = not unlocked
        if not unlocked then wipe(shownKeys); ShowRows({}) end
        Evaluate()
    end)

    local testBtn = MakeButton(config, L.TEST, 60)
    testBtn:SetPoint("LEFT", config.moveBtn, "RIGHT", 4, 0)
    testBtn:SetScript("OnClick", StartTest)

    local unmuteBtn = MakeButton(config, L.UNMUTE, 110)
    unmuteBtn:SetPoint("LEFT", testBtn, "RIGHT", 4, 0)
    unmuteBtn:SetScript("OnClick", function()
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    end)

    config:SetSize(440, -y + 44)
    config:SetScript("OnShow", RefreshConfig)
    config:Hide()
end

local function ToggleConfig()
    if not config then BuildConfig() end
    if config:IsShown() then config:Hide() else config:Show() end
end

---------------------------------------------------------------------------
-- Minimap-Button
---------------------------------------------------------------------------
local mm = CreateFrame("Button", "BuffReminderMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Maße wie im Mainline-Client üblich (Vorbild: LibDBIcon). Die Rahmen-Textur ist so
-- gezeichnet, dass ihr Ring bei 50x50 und TOPLEFT mittig um den 31x31-Button liegt.
local MM_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function RoundMask(tex)
    local mask = mm:CreateMaskTexture()
    mask:SetTexture(MM_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)   -- folgt der Textur (auch beim Klick-Versatz)
    tex:AddMaskTexture(mask)
end

local mmBg = mm:CreateTexture(nil, "BACKGROUND")
mmBg:SetSize(24, 24)
mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mmBg:SetPoint("CENTER", mm, "CENTER")
RoundMask(mmBg)

-- Logo ist bereits rund mit transparenten Ecken → kein TexCoord-Zuschnitt
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(18, 18)
mmIcon:SetPoint("CENTER", mm, "CENTER")
mmIcon:SetTexture("Interface\\AddOns\\PardonasBuffReminder\\Textures\\MinimapIcon")
RoundMask(mmIcon)

local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(50, 50)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT")

-- Klick-Feedback wie bei Standard-Minimap-Buttons: Icon versetzt und abgedunkelt
local function MinimapIconPressed(pressed)
    mmIcon:ClearAllPoints()
    if pressed then
        mmIcon:SetPoint("CENTER", mm, "CENTER", 1, -1)
        mmIcon:SetVertexColor(0.75, 0.75, 0.75)
    else
        mmIcon:SetPoint("CENTER", mm, "CENTER")
        mmIcon:SetVertexColor(1, 1, 1)
    end
end
mm:SetScript("OnMouseDown", function() MinimapIconPressed(true) end)
mm:SetScript("OnMouseUp", function() MinimapIconPressed(false) end)
mm:SetScript("OnHide", function() MinimapIconPressed(false) end)

-- Abstand Button-Mitte zur Minimap-Mitte: Radius + 5 setzt den Button mittig auf den
-- Rand der Mainline-Minimap (LibDBIcon Mainline); +10 stammt aus Classic-Clients.
local MM_RADIUS_OFFSET = 5

local function UpdateMinimapPos()
    local a = math.rad(db.minimapAngle)
    local r = (Minimap:GetWidth() / 2) + MM_RADIUS_OFFSET
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    if db.minimapHide then mm:Hide() else mm:Show() end
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        db.minimapAngle = math.deg(math.atan2(py / s - my, px / s - mx))
        UpdateMinimapPos()
    end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        StartTest()
    else
        ToggleConfig()
    end
end)
mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(L.MM_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MM_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MM_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
mm:Hide()

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function ApplyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then t[k] = type(v) == "table" and { unpack(v) } or v end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ALIVE")
ev:RegisterEvent("PLAYER_UNGHOST")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- Ladebildschirm-Events gibt es nicht in jedem Client → Registrierung absichern
pcall(ev.RegisterEvent, ev, "LOADING_SCREEN_ENABLED")
pcall(ev.RegisterEvent, ev, "LOADING_SCREEN_DISABLED")

-- Nach Login/Ladebildschirm liefert die Aura-API kurz unvollständige Daten → 3 Sek. warten.
-- Generationszähler: nur der zuletzt gestartete Timer darf ready = true setzen.
local GRACE_TIME = 3
local graceGen = 0

local function StartGrace()
    ready = false
    wipe(missingSince)
    graceGen = graceGen + 1
    local gen = graceGen
    C_Timer.After(GRACE_TIME, function()
        if gen ~= graceGen then return end
        ready = true; ScanBags(); RefreshKnown(); Evaluate()
    end)
end

ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffReminderDB = BuffReminderDB or {}
        BuffReminderCharDB = BuffReminderCharDB or {}
        db, cdb = BuffReminderDB, BuffReminderCharDB
        ApplyDefaults(db, DEFAULTS)
        cdb.buffs = cdb.buffs or {}
        cdb.lastVariant = cdb.lastVariant or {}   -- Eintrag-Key -> zuletzt genutzte Variante
        cdb.reagents = cdb.reagents or {}         -- Reagenz-Item-ID -> Warnschwelle (0 = aus)
        -- cdb.lastFlask: Item-ID des zuletzt benutzten Fläschchens (nil = keins)
        db.iconCache = db.iconCache or {}         -- allgemeiner Buff -> zuletzt gesehenes Aura-Icon
        db.flaskSpells = db.flaskSpells or {}     -- gelernte Spell-IDs von Fläschchen-Effekten
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
            if g then e.groupIds, e.manaOnly = g.groupIds, g.manaOnly end
        end
        for _, e in ipairs(GENERAL_BUFFS) do PrepareEntry(e); entries[#entries + 1] = e end
        -- Essen & Fläschchen: Kategorie-Gewichte der Klasse, gelernte Fläschchen-Spells, Taschen
        for _, e in ipairs(GENERAL_BUFFS) do
            if e.itemKind == "flask" then flaskEntry = e end
            if e.itemKind == "food" then foodEntry = e end
        end
        for id in pairs(db.flaskSpells) do flaskEntry.idSet[id] = true end
        BuildFoodScores(class)
        ResolveAllEatSpells()   -- Ess-Auren aller FOOD-Items (fehlende werden nachgeladen)
        ScanBags()
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
        ApplyLayout()
        UpdateMinimapPos()
        -- UNIT_AURA für alle Units; gefiltert auf player / party* / raid* (siehe unten)
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.NewTicker(1, Evaluate)
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- arg1 = Item-ID; nur eigene Reagenzien interessieren (lokalisierter Name nachgeladen)
        -- bzw. Essen/Fläschchen in den Taschen (Name, Stufe, Tooltip jetzt verfügbar)
        if IsSecret(arg1) then return end
        if eatPending[arg1] then ResolveEatSpell(arg1, true) end   -- Ess-Aura jetzt ermittelbar
        if bagCounts[arg1] then
            if IsFlaskItem(arg1) then LearnFlaskSpell(arg1) end
            RefreshItemPanel()
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

    if event == "BAG_UPDATE_DELAYED" then
        ScanBags()
        RefreshItemPanel()   -- im Kampf nicht offen; Zeilen-Attribute folgen per Evaluate nach dem Kampf
        Evaluate()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        CloseItemPanelForCombat()
        return
    end

    if event == "UNIT_AURA" then
        -- arg1 = Unit. Spieler: sofort auswerten (wie bisher); Gruppen-/Raid-Mitglieder:
        -- gedrosselt (MarkGroupDirty); alle anderen Units (Ziel, Namensplaketten …) ignorieren.
        if arg1 == nil or IsSecret(arg1) then return end
        if arg1 == "player" then
            MarkGroupDirty()
            Evaluate()
        elseif arg1:find("^party%d") or arg1:find("^raid%d") then
            MarkGroupDirty()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        MarkGroupDirty()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- nach dem Kampf: Gruppe sofort neu prüfen, Zeilen/Attribute nachziehen
        groupDirty = true
        Evaluate()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID (kann ein Secret-Wert sein)
        MarkGroupDirty()   -- Ziel der Gruppen-Zeilen nach jedem Cast neu bestimmen
        if cdb then
            RememberFromCast(arg3)
            -- Fläschchen-Effekt (auch über Aktionsleiste/Taschen benutzt) -> zuletzt benutzt
            if arg3 ~= nil and not IsSecret(arg3) and flaskBySpell[arg3] then
                cdb.lastFlask = flaskBySpell[arg3]
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

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
        -- Neu erlernte Zauber werden automatisch aktiv (Standard = an)
        C_Timer.After(0.5, function() RefreshKnown(); Evaluate() end)
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
    elseif cmd == "minimap" then
        db.minimapHide = not db.minimapHide
        UpdateMinimapPos()
    elseif cmd == "unmute" then
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    elseif cmd == "debug" then
        local ids, _, unreliable = ScanAuras()
        Print(("ready=%s enabled=%s suppressed=%s instanceOnly=%s inInstance=%s scan=%s unreliable=%s"):format(
            tostring(ready), tostring(db.enabled), tostring(Suppressed()), tostring(db.instanceOnly),
            tostring(InGroupInstance()), ids and "ok" or "nil", tostring(unreliable)))
        for _, e in ipairs(entries) do
            Print(("%s: known=%s enabled=%s missing=%s muted=%s names=%s"):format(
                EntryLabel(e), tostring(knownCache[e.key]), tostring(IsEnabled(e)),
                tostring(missing[e.key]), tostring(MuteRemaining(e.key) ~= nil),
                table.concat(e.names or {}, "/")))
        end
        Print(("eating=%s aura=%s eatSpells=%d eatNames=%d"):format(
            (foodEntry and foodEntry.eatStart) and "yes" or "no",
            eatAura and ("%s – %s"):format(tostring(eatAura.name), tostring(eatAura.id)) or "none",
            CountKeys(eatSpells), CountKeys(eatNames)))
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
    elseif cmd == "reset" then
        if InCombatLockdown() then Print(L.COMBAT); return end
        for k in pairs(DEFAULTS) do db[k] = nil end
        ApplyDefaults(db, DEFAULTS)
        wipe(cdb.buffs)
        wipe(cdb.reagents)
        ApplyLayout(); UpdateMinimapPos(); Print(L.RESET); Evaluate()
    else
        for _, line in ipairs(L.HELP) do Print(line) end
    end
end
