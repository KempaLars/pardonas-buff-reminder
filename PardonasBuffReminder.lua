-- Pardona's Buff Reminder – WoW Forever (Interface 16001, Mainline-API)
-- Erinnert an fehlende Klassen- und allgemeine Buffs.
-- Auswahl per GUI (Minimap-Button / /br), Rechtsklick auf Erinnerung = stummschalten,
-- Linksklick auf Erinnerung = Buff auf sich selbst zaubern (abschaltbar).

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
    { key = "gen_wellfed", general = true, defaultOff = true, ids = { 19705 }, nameIds = { 19705 },
      icon = "Interface\\Icons\\Spell_Misc_Food" },
    { key = "gen_flask", general = true, defaultOff = true, label = "FLASK", nameIds = {},
      ids = { 17626, 17627, 17628, 17629, 28518, 28519, 28520, 28521, 28540,
              53752, 53755, 53758, 53760, 54212, 62380 },
      icon = "Interface\\Icons\\INV_Potion_1" },
    -- Schlafsack-Buff aus WoW Forever. Spell-ID unbekannt → Erkennung über den Buffnamen
    -- (Groß-/Kleinschreibung, Leerzeichen und Bindestriche werden ignoriert).
    -- Sobald die ID bekannt ist (/br auras), in ids eintragen.
    { key = "gen_wellrested", general = true, defaultOff = true, label = "WELLRESTED",
      ids = {}, matchNames = { "Well-Rested", "Well Rested" },
      icon = "Interface\\Icons\\Spell_Nature_Sleep" },
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
    clickCast    = true,   -- Linksklick auf Erinnerung zaubert den Buff
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

---------------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------------
local db, cdb                 -- account / Charakter
local entries = {}            -- aktive Liste (Klasse + allgemein)
local classEntries = {}
local knownCache = {}
local missing = {}            -- key -> bool (letzter lesbarer Zustand)
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

local function EntryLabel(e)
    if e.label then return L[e.label] end
    local first = (e.ids or e.knownIds or {})[1]
    return (first and SpellName(first)) or e.key
end

local function EntryIcon(e)
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

local function RefreshKnown()
    for _, e in ipairs(entries) do knownCache[e.key] = ComputeKnown(e) end
end

local function IsEnabled(e)
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
-- liefert idSet, nameSet, unreliable, own  (nil = gar nicht lesbar)
--   own = { ids, names } nur der selbst gewirkten Auren (für das Merken der Variante)
local function ScanAuras()
    local ids, names, unreliable = {}, {}, false
    local own = { ids = {}, names = {} }
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
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
                end
            end
        end
        return ids, names, unreliable, own
    elseif UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, src, _, _, id = UnitBuff("player", i)
            if not name then break end
            names[name] = true
            if id then ids[id] = true end
            if src == "player" then
                own.names[name] = true
                if id then own.ids[id] = true end
            end
        end
        return ids, names, false, own
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

-- true = fehlt, false = vorhanden / nicht relevant, nil = unbekannt
local function CheckMissing(e, scan)
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
    for _, n in ipairs(e.names) do
        if scan.names[n] then return false end
    end
    if next(e.normNames) then
        for n in pairs(scan.names) do
            if e.normNames[NormName(n)] then return false end
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

-- Linksklick-Zauber einer Zeile setzen (nur außerhalb des Kampfes aufrufen)
local function SetRowSpell(r, spell)
    if r.castSpell == spell then return end
    r.castSpell = spell
    r:SetAttribute("type1", spell and "spell" or nil)
    r:SetAttribute("spell1", spell)
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
        if button ~= "RightButton" or not IsActionPhase(down) then return end
        if self.entry and not unlocked then OpenMuteMenu(self) end
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
        if self.castSpell then GameTooltip:AddLine(L.LEFTCLICK, 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(L.RIGHTCLICK, 0.8, 0.8, 0.8)
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
            SetRowSpell(r, nil)
            r.text:SetText(L.DRAG)
            r.hint:SetText("")
        else
            r.entry = e
            local spell = CastSpellFor(e)
            SetRowSpell(r, spell)
            r.text:SetText(L.MISSING:format(EntryLabel(e)))
            r.hint:SetText(spell and L.HINT_CAST or L.HINT_MUTE)
        end
        r:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
        SetRowSpell(rows[i], nil)
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

local function PlayAlertSound()
    if db.sound == "aus" then return end
    PlaySound(SOUNDS[db.sound] or SOUNDS.ping, "Master")
end

---------------------------------------------------------------------------
-- Rechtsklick-Menü (Stummschalten)
---------------------------------------------------------------------------
local menu = CreateFrame("Frame", "BuffReminderMuteMenu", UIParent, "BackdropTemplate")
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:Hide()
menu:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
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
for i, opt in ipairs(MENU_OPTIONS) do
    local b = CreateFrame("Button", nil, menu)
    b:SetSize(180, 18)
    b:SetPoint("TOPLEFT", 6, -26 - (i - 1) * 19)
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
menu:SetSize(192, 26 + #MENU_OPTIONS * 19 + 8)

-- Schließt sich, wenn die Maus das Menü 2 Sek. lang verlassen hat
menu:SetScript("OnUpdate", function(self, el)
    if MouseIsOver(self) then self.away = 0 else
        self.away = (self.away or 0) + el
        if self.away > 2 then self:Hide() end
    end
end)

function OpenMuteMenu(row)
    menu.key = row.entry.key
    menu.title:SetText(EntryLabel(row.entry))
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 10, y / s + 10)
    menu.away = 0
    menu:Show()
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
        local ids, names, unreliable, own = ScanAuras()
        local scan = ids and { ids = ids, names = names, unreliable = unreliable } or nil
        RememberFromAuras(own)
        local instOk = (not db.instanceOnly) or InGroupInstance()

        for _, e in ipairs(entries) do
            local relevant = knownCache[e.key] and IsEnabled(e) and (not e.general or instOk)
            if relevant then
                local m = CheckMissing(e, scan)
                if m ~= nil then missing[e.key] = m end   -- nil: Zustand beibehalten (Kampf/Secret)
            else
                missing[e.key] = false
            end
            if missing[e.key] and not MuteRemaining(e.key) then
                list[#list + 1] = e
                if not combat and not shownKeys[e.key] then
                    newOnes = true
                    Print(L.CHAT:format(EntryLabel(e)))
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
    config.enabledCB:SetChecked(db.enabled)
    config.instCB:SetChecked(db.instanceOnly)
    config.castCB:SetChecked(db.clickCast)
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

local mmBg = mm:CreateTexture(nil, "BACKGROUND")
mmBg:SetSize(20, 20)
mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mmBg:SetPoint("TOPLEFT", 7, -5)

local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(18, 18)
mmIcon:SetPoint("TOPLEFT", 7, -6)
mmIcon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
mmIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetPoint("TOPLEFT")

local function UpdateMinimapPos()
    local a = math.rad(db.minimapAngle)
    local r = (Minimap:GetWidth() / 2) + 10
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

ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffReminderDB = BuffReminderDB or {}
        BuffReminderCharDB = BuffReminderCharDB or {}
        db, cdb = BuffReminderDB, BuffReminderCharDB
        ApplyDefaults(db, DEFAULTS)
        cdb.buffs = cdb.buffs or {}
        cdb.lastVariant = cdb.lastVariant or {}   -- Eintrag-Key -> zuletzt genutzte Variante
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        classEntries = CLASS_BUFFS[class] or {}
        for _, e in ipairs(classEntries) do
            PrepareEntry(e); PrepareCast(e, class); entries[#entries + 1] = e
        end
        for _, e in ipairs(GENERAL_BUFFS) do PrepareEntry(e); entries[#entries + 1] = e end
        RefreshKnown()
        ApplyLayout()
        UpdateMinimapPos()
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.NewTicker(1, Evaluate)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID (kann ein Secret-Wert sein)
        if cdb then RememberFromCast(arg3) end
        Evaluate()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ready = false
        C_Timer.After(3, function() ready = true; RefreshKnown(); Evaluate() end)
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
        ApplyLayout(); UpdateMinimapPos(); Print(L.RESET); Evaluate()
    else
        for _, line in ipairs(L.HELP) do Print(line) end
    end
end
