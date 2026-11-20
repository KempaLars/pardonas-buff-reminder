-- Pardona's Buff Reminder – WoW Forever (Interface 16001, Mainline-API)
-- Erinnert an fehlende Klassen- und allgemeine Buffs (auch bei Gruppen-/Raid-Mitgliedern)
-- sowie an knappe Reagenzien.
-- Auswahl per GUI (Pardona-Menü / Einstellungen / /br), Rechtsklick auf Erinnerung = stummschalten,
-- Linksklick auf Erinnerung = Buff auf sich selbst zaubern (abschaltbar);
-- bei Essen/Fläschchen = bestes Item aus den Taschen benutzen, Rechtsklick = Auswahl.

local ADDON_NAME = ...

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
        STATUS_ONE    = "1 Buff fehlt",
        STATUS_MANY   = "%d Buffs fehlen",
        STATUS_OK     = "Alles aktiv",
        NO_CLASS      = "Keine Klassenbuffs für diese Klasse hinterlegt.",
        RESET         = "Einstellungen zurückgesetzt.",
        SOUNDS        = { ping = "Ping", glocke = "Glocke", alarm = "Alarm", aus = "Aus" },
        HELP          = {
            "/br – Einstellungen öffnen",
            "/br test – Erinnerung testen",
            "/br minimap – gemeinsamen Pardona-Minimap-Button ein/aus",
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
        REAGENT_HINT  = "Warnen unter (0 = aus)",
        REAGENT_LOW   = "%s: %d übrig",
        REAGENT_CHAT  = "|cffffb000Reagenz knapp: %s – nur noch %d!|r",
        IN_BAGS       = "%d in Taschen",
        -- Ess-Countdown
        EATING        = "Isst … %d s",
        EATING_DONE   = "Gleich satt …",
        HINT_EATING   = "Sitzen bleiben",
        -- Versionshinweis beim Login (Beta/Alpha/Entwicklerversion)
        VERSION_LOADED = "Version %s geladen",
        DEV_BUILD      = "Entwicklerversion geladen",
        -- Essen & Fläschchen
        HINT_ITEM     = "Linksklick: %s · Rechtsklick: Auswahl",
        HINT_NOITEM   = "Nicht in der Tasche · Rechtsklick: stumm",
        LEFTCLICK_USE = "Linksklick: %s benutzen",
        RIGHTCLICK_CHOOSE = "Rechtsklick: Auswahl / stummschalten",
        -- Experimentelle Funktionen
        EXP_SECTION   = "Experimentell (Beta) – Nutzung auf eigene Gefahr",
        EXP_NOTE      = "Diese Funktionen sind noch nicht vollständig getestet.",
        EXP_GROUP     = "Gruppen-Buffs",
        EXP_REAGENTS  = "Reagenzien-Warnung",
        EXP_EXPIRY    = "Warnung vor Ablauf",
        EXP_CONSUMABLES = "Klassen-Verbrauchsgüter",
        EXP_WEAPONITEMS = "Steine, Öle, Gifte per Klick",
        -- Warnung vor Ablauf
        EXPIRES       = "%s läuft ab · %s",
        EXPIRY_PCT    = "Schwelle: %d %%",
        EXPIRY_ALPHA  = "Transparenz: %d %%",
        -- Klassen-Verbrauchsgüter
        CONJURE_COUNT = "%s: %d",
        CONJURE_CHAT  = "|cffffb000%s – bitte nachzaubern!|r",
        CONJURE_THRESHOLD = "Essen/Wasser unter: %d",
        CONJURE_OFF   = "Essen/Wasser-Warnung: aus",
        -- Waffen-Items
        WEAPON_MH     = "Waffe (Haupthand): Stein/Öl",
        WEAPON_OH     = "Waffe (Nebenhand): Stein/Öl",
        WEAPON_BY_POISON = "Gift-Eintrag aktiv",
        MENU_WEAPON   = "Steine & Öle in den Taschen",
        MENU_POISON   = "Gifte in den Taschen",
        WEAPON_CATS   = {
            sharpen = "Wetzstein", weight = "Gewichtsstein", wizard = "Zauberöl", mana = "Manaöl",
            instant = "Sofort wirkendes Gift", deadly = "Tödliches Gift", wound = "Wundgift",
            crippling = "Verkrüppelndes Gift", mind = "Gedankenbenebelndes Gift",
        },
        -- Gruppen-Buffs
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
        -- Stile
        STYLE         = "Stil: %s",
        STYLE_NAMES   = { pardona = "Pardona", classic = "Classic", compact = "Compact" },
        ICONS_ONLY    = "Nur Icons",
        SHORT_MISSING = "fehlt",
        -- Wachstumsrichtung der Liste
        GROW          = "Neue Warnungen erscheinen: %s",
        GROW_DOWN     = "unterhalb",
        GROW_UP       = "oberhalb",
        -- Tastenbelegung
        KEY_NAME      = "Oberste Warnung auslösen",
        KEY_LINE      = "Taste „%s“: %s",
        KEY_NONE      = "nicht belegt",
        KEY_WHERE     = "Belegen unter Optionen → Tastaturbelegung → AddOns → Pardona's Buff Reminder",
        -- Rechtsklick-Menü
        MENU_FOOD     = "Essen in den Taschen",
        MENU_FLASK    = "Fläschchen",
        MENU_MUTE     = "Stummschalten",
        MUTE_5        = "5 Min",
        MUTE_15       = "15 Min",
        MUTE_60       = "60 Min",
        MUTE_SESSION  = "Sitzung",
        CLOSE_ESC     = "Schließen (Esc)",
        BEST          = "beste Wahl",
        NONE_IN_BAGS  = "Nichts in den Taschen",
        SUB_ITEMS     = "Item benutzen oder stummschalten",
        SUB_MUTE      = "Erinnerung stummschalten",
        SUB_COMBAT    = "Im Kampf: nur Stummschalten",
        FAV_ADD       = "Als Favorit markieren",
        FAV_REMOVE    = "Favorit entfernen",
        FOOD_CATS     = {
            MeleeAP = "Nahkampf-Angriffskraft", SpellDamage = "Zauberschaden", Healing = "Heilung",
            Stamina = "Ausdauer", Strength = "Stärke", Agility = "Beweglichkeit", Intellect = "Intelligenz",
            Spirit = "Willenskraft", Crit = "Kritische Treffer", Armor = "Rüstung", Movement = "Bewegung",
            Profession = "Beruf",
        },
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
        STATUS_ONE    = "1 buff missing",
        STATUS_MANY   = "%d buffs missing",
        STATUS_OK     = "All active",
        NO_CLASS      = "No class buffs defined for this class.",
        RESET         = "Settings reset.",
        SOUNDS        = { ping = "Ping", glocke = "Bell", alarm = "Alarm", aus = "Off" },
        HELP          = {
            "/br – open settings",
            "/br test – test the reminder",
            "/br minimap – toggle the shared Pardona minimap button",
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
        REAGENT_HINT  = "Warn below (0 = off)",
        REAGENT_LOW   = "%s: %d left",
        REAGENT_CHAT  = "|cffffb000Reagent running low: %s – only %d left!|r",
        IN_BAGS       = "%d in bags",
        EATING        = "Eating … %d s",
        EATING_DONE   = "Almost well fed …",
        HINT_EATING   = "Stay seated",
        VERSION_LOADED = "Version %s loaded",
        DEV_BUILD      = "Development build loaded",
        HINT_ITEM     = "Left-click: %s · Right-click: choose",
        HINT_NOITEM   = "Not in bags · Right-click: mute",
        LEFTCLICK_USE = "Left-click: use %s",
        RIGHTCLICK_CHOOSE = "Right-click: choose / mute",
        EXP_SECTION   = "Experimental (beta) – use at your own risk",
        EXP_NOTE      = "These features are not fully tested yet.",
        EXP_GROUP     = "Group buffs",
        EXP_REAGENTS  = "Low reagent warning",
        EXP_EXPIRY    = "Expiry warning",
        EXP_CONSUMABLES = "Class consumables",
        EXP_WEAPONITEMS = "Stones, oils, poisons by click",
        EXPIRES       = "%s expires · %s",
        EXPIRY_PCT    = "Threshold: %d %%",
        EXPIRY_ALPHA  = "Opacity: %d %%",
        CONJURE_COUNT = "%s: %d",
        CONJURE_CHAT  = "|cffffb000%s – conjure more!|r",
        CONJURE_THRESHOLD = "Food/water below: %d",
        CONJURE_OFF   = "Food/water warning: off",
        WEAPON_MH     = "Main hand: weapon enhancement",
        WEAPON_OH     = "Off hand: weapon enhancement",
        WEAPON_BY_POISON = "poison entry active",
        MENU_WEAPON   = "Stones & oils in your bags",
        MENU_POISON   = "Poisons in your bags",
        WEAPON_CATS   = {
            sharpen = "Sharpening stone", weight = "Weightstone", wizard = "Wizard oil", mana = "Mana oil",
            instant = "Instant poison", deadly = "Deadly poison", wound = "Wound poison",
            crippling = "Crippling poison", mind = "Mind-numbing poison",
        },
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
        STYLE         = "Style: %s",
        STYLE_NAMES   = { pardona = "Pardona", classic = "Classic", compact = "Compact" },
        ICONS_ONLY    = "Icons only",
        SHORT_MISSING = "missing",
        GROW          = "New warnings appear: %s",
        GROW_DOWN     = "below",
        GROW_UP       = "above",
        KEY_NAME      = "Use top warning",
        KEY_LINE      = "Key \"%s\": %s",
        KEY_NONE      = "not bound",
        KEY_WHERE     = "Set it under Options → Keybindings → AddOns → Pardona's Buff Reminder",
        MENU_FOOD     = "Food in your bags",
        MENU_FLASK    = "Flasks",
        MENU_MUTE     = "Mute",
        MUTE_5        = "5 min",
        MUTE_15       = "15 min",
        MUTE_60       = "60 min",
        MUTE_SESSION  = "Session",
        CLOSE_ESC     = "Close (Esc)",
        BEST          = "best choice",
        NONE_IN_BAGS  = "None in your bags",
        SUB_ITEMS     = "Use an item or mute",
        SUB_MUTE      = "Mute this reminder",
        SUB_COMBAT    = "In combat: mute only",
        FAV_ADD       = "Mark as favorite",
        FAV_REMOVE    = "Remove favorite",
        FOOD_CATS     = {
            MeleeAP = "Melee attack power", SpellDamage = "Spell damage", Healing = "Healing",
            Stamina = "Stamina", Strength = "Strength", Agility = "Agility", Intellect = "Intellect",
            Spirit = "Spirit", Crit = "Critical strike", Armor = "Armor", Movement = "Movement",
            Profession = "Profession",
        },
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
        { key = "armor", level = 1, label = "MAGE_ARMOR",
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
        { key = "armor", level = 1, label = "LOCK_ARMOR",
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
        -- poisonItems: mit expWeaponItems Linksklick = bestes Gift aus den Taschen, Rechtsklick = Auswahl
        { key = "poison_mh", kind = "weapon_mh", level = 20, levelOnly = true, label = "MH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons", poisonItems = true },
        { key = "poison_oh", kind = "weapon_oh", level = 20, levelOnly = true, label = "OH_POISON",
          icon = "Interface\\Icons\\Ability_Poisons", poisonItems = true },
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
        } },
        mage_water = { castIds = Conjure.WATER.spells },
        mage_food  = { castIds = Conjure.FOOD.spells },
        mage_gem   = { castIds = Conjure.GEM.spells },
    },
    WARLOCK = {
        armor = { variants = {
            { key = "demonskin",  castIds = { 687, 696 } },
            { key = "demonarmor", castIds = { 706, 1086, 11733, 11734, 11735, 27260, 47793, 47889 } },
            { key = "felarmor",   castIds = { 28176, 28189, 47892, 47893 } },
        } },
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
    instanceOnly = true,
    groupCheck   = true,       -- Gruppen-Buffs bei Party-/Raid-Mitgliedern prüfen
    groupMode    = "always",   -- "always" | "instance" (Dungeon & Raid) | "raid"
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
        if Items.IsFlaskItem(id) then Items.LearnFlaskSpell(id) end
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

local function EntryLabel(e)
    if e.kind == "reagent" then return ItemName(e.item) end
    if e.label then return L[e.label] end
    local first = (e.ids or e.knownIds or {})[1]
    return (first and SpellName(first)) or e.key
end

local function EntryIcon(e)
    if e.kind == "reagent" then return ItemIcon(e.item) or FALLBACK_ICON end
    if e.kind == "conjure" then
        return ItemIcon(Conjure.RankItem(e)) or SpellIcon(e.knownIds[1]) or FALLBACK_ICON
    end
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
    -- Reagenzien: nur mit aktivem Experimental-Schalter (sonst keine Zeile, keine Mengenprüfung)
    if e.kind == "reagent" then return ExpOn("expReagents") and ReagentThreshold(e.item) > 0 end
    -- Klassen-Verbrauchsgüter: nur mit aktivem Experimental-Schalter
    if e.kind == "conjure" and not ExpOn("expConsumables") then return false end
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
    if e.kind == "conjure" then return Conjure.Missing(e) end
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

-- Gruppen-Check für einen (erlernten, aktivierten) Eintrag aktiv?
function Group.GroupActive(e)
    return e.groupIds ~= nil and GroupFeatureOn() and IsInGroup ~= nil and IsInGroup() and Group.GroupModeOk()
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
-- Unbekannte (Secret-)Werte zählen als "nicht prüfbar" → Spieler wird übersprungen.
function Group.UnitUsable(unit)
    if Group.UnitFlag(UnitExists, unit) ~= true then return false end
    if UnitIsConnected and Group.UnitFlag(UnitIsConnected, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsDeadOrGhost, unit) ~= false then return false end
    if UnitIsVisible and Group.UnitFlag(UnitIsVisible, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsUnit, unit, "player") == true then return true end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if not ok or IsSecret(inRange) or IsSecret(checked) then return false end
        if checked and not inRange then return false end
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

function Group.ScanGroup()
    wipe(Group.groupState)
    local list = {}
    for _, e in ipairs(entries) do
        if e.groupIds and knownCache[e.key] and IsEnabled(e) then
            list[#list + 1] = e
            Group.groupState[e.key] = { missing = {}, unknown = false }
        end
    end
    if #list == 0 then return end
    for _, unit in ipairs(Group.GroupUnits()) do
        if Group.UnitUsable(unit) then
            local ids, names, unreliable, _, auras = ScanAuras(unit)
            local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auras } or nil
            local class = Group.UnitClassFile(unit)
            for _, e in ipairs(list) do
                if not e.manaOnly or (class and MANA_CLASSES[class]) then
                    local st = Group.groupState[e.key]
                    -- Gruppen- und Einzelversion stehen beide in e.idSet / e.names
                    local m = CheckMissing(e, scan)
                    if m == true then
                        st.missing[#st.missing + 1] = { unit = unit, name = Group.UnitDisplayName(unit) }
                    elseif m == nil then
                        st.unknown = true
                    end
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
function Group.GroupSpellFor(e)
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
function Group.GroupActionFor(e)
    local target = e.groupMissing and e.groupMissing[1]
    local single = CastSpellFor(e)
    if not target or not single then return nil end
    local a = { unit = target.unit, targetName = target.name, ctrlSpell = single, ctrlUnit = target.unit }
    local gspell, item = Group.GroupSpellFor(e)
    if gspell and (not item or (ItemCount(item) or 1) > 0) then
        a.spell, a.isGroup = gspell, true
    else
        a.spell = single
    end
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
    if e.kind == "reagent" or e.kind == "conjure" then return false end
    if e.general then return e.itemKind == "food" or e.itemKind == "flask" or e.weaponItems == true end
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
-- Stile (Warnanzeige + Rechtsklick-Menü)
-- Alle Farben, Größen und Abstände stehen hier; ein neuer Stil = neuer Eintrag in
-- STYLES + Name in STYLE_ORDER + L.STYLE_NAMES. Farben: { r, g, b [, a] }.
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
        tostring(a.ctrlSpell), tostring(a.ctrlUnit) }, "|")
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
            -- per Linksklick benutztes Fläschchen als "zuletzt benutzt" merken
            if self.useItem and self.entry and self.entry.itemKind == "flask" then
                cdb.lastFlask = self.useItem
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
        elseif e.groupActive then
            -- Gruppen-Zeile: Anzahl, Namen, Gruppen-/Einzel-Klick auf den ersten Spieler ohne Buff
            r.entry = e
            local a = Group.GroupActionFor(e)
            Display.SetRowAction(r, a)
            Display.SetRowLines(r, true)
            Display.SetRowStatus(r, "missing")
            r.text:SetText(L.GROUP_MISSING:format(EntryLabel(e), #(e.groupMissing or {})))
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
            -- Essen/Fläschchen/Waffen-Items: Linksklick benutzt die beste Wahl aus den Taschen
            local item, noItem, macro
            local kind = Items.KindOf(e)
            if not spell and kind and db.clickCast then
                local choices = Items.ItemChoices(e)
                item = choices[1] and choices[1].id
                noItem = item == nil
                if item and (kind == "weapon" or kind == "poison") then
                    macro = Items.WeaponMacro(item, Items.WeaponSlot(e))
                end
            end
            Display.SetRowAction(r, (spell or item) and { spell = spell, item = item, macro = macro } or nil)
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
                    r.right:SetText(L.SHORT_MISSING)
                elseif e.weaponItems then
                    r.text:SetText(EntryLabel(e))   -- "Waffe (Haupthand): Stein/Öl"
                else
                    r.text:SetText(L.MISSING:format(EntryLabel(e)))
                end
            end
            if e.eatStart and not isExp then
                Display.SetRowHint(r, L.HINT_EATING)
            elseif spell then
                Display.SetRowHint(r, L.HINT_CAST)
            elseif item then
                Display.SetRowHint(r, L.HINT_ITEM:format(ItemName(item)))
            elseif noItem then
                Display.SetRowHint(r, L.HINT_NOITEM)
            else
                Display.SetRowHint(r, L.HINT_MUTE)
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
_G.BINDING_HEADER_PARDONASBUFFREMINDER = L.TITLE
_G["BINDING_NAME_" .. Keybind.BINDING] = L.KEY_NAME

Keybind.button = CreateFrame("Button", "PardonasBuffReminderKeyButton", nil, "SecureActionButtonTemplate")
Keybind.button:SetSize(1, 1)
Keybind.button:EnableMouse(false)
-- beide Phasen: funktioniert mit beiden Werten von ActionButtonUseKeyDown und mit /click
Keybind.button:RegisterForClicks("AnyUp", "AnyDown")
Keybind.button:SetScript("PostClick", function(self, button, down)
    if button ~= "LeftButton" or not Display.IsActionPhase(down) then return end
    -- per Taste benutztes Fläschchen als "zuletzt benutzt" merken (wie beim Linksklick)
    if self.useItem and self.entry and self.entry.itemKind == "flask" and cdb then cdb.lastFlask = self.useItem end
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

Menu.MUTE_OPTIONS = {
    { L.MUTE_5, 300 }, { L.MUTE_15, 900 }, { L.MUTE_60, 3600 }, { L.MUTE_SESSION, math.huge },
}
menu.muteButtons = {}
for i, opt in ipairs(Menu.MUTE_OPTIONS) do
    menu.muteButtons[i] = Menu.MenuButton(opt[1], function()
        if menu.entry then
            muted[menu.entry.key] = (opt[2] == math.huge) and math.huge or (GetTime() + opt[2])
            NoteDeferred()
            Evaluate()
        end
        menu:Hide()
    end)
end

menu.close = CreateFrame("Button", nil, menu)
menu.close:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
menu.close.label = menu.close:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
menu.close.label:SetPoint("CENTER")
menu.close.label:SetText(L.CLOSE_ESC)
menu.close:SetScript("OnClick", function() menu:Hide() end)

-- Item-Zeilen (Secure Buttons: type "item")
local itemPanel = CreateFrame("Frame", "BuffReminderItemMenu", UIParent)
itemPanel:SetFrameStrata("DIALOG")
itemPanel:Hide()
itemPanel.buttons = {}
menu.stars = {}


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
    b.xp:SetText("XP")
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
        if menu.entry and menu.entry.itemKind == "flask" then cdb.lastFlask = self.itemID end
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
        if not self.itemID or not cdb then return end
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
    if c.cat then return L.FOOD_CATS[c.cat] or c.cat end
    if c.wcat then return L.WEAPON_CATS[c.wcat] or c.wcat end
    return ""
end

-- Secure-Aktion einer Item-Zeile: normal "item", Waffen-Items per Makro auf den Slot
function Menu.SetItemButtonAction(b, id, e, kind)
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

function Menu.ItemHeadText(kind)
    if kind == "flask" then return L.MENU_FLASK end
    if kind == "weapon" then return L.MENU_WEAPON end
    if kind == "poison" then return L.MENU_POISON end
    return L.MENU_FOOD
end

-- Menü für Eintrag e aufbauen und an menu.x/menu.y (UIParent-Koordinaten) anzeigen.
-- Im Kampf nur Kopf + Stummschalten; die Secure-Item-Zeilen werden dann nicht angefasst.
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
    local withItems = kind and db.clickCast and not combat
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

    -- Item-Auswahl
    local n, itemTop, rowsWidth = 0, 0, inner - Menu.STAR_SIZE - 8
    local h = ms.itemHeight
    if withItems then
        Separator()
        Head(menu.itemHead, Menu.ItemHeadText(kind))
        local choices = Items.ItemChoices(e)
        n = math.min(#choices, Menu.MAX_ITEM_CHOICES)
        itemTop = y
        if n == 0 then
            menu.itemNone:ClearAllPoints()
            menu.itemNone:SetPoint("TOPLEFT", pad + 4, y)
            menu.itemNone:SetText(L.NONE_IN_BAGS)
            menu.itemNone:Show()
            y = y - 18
        else
            menu.itemNone:Hide()
        end
        for i = 1, n do
            local c, b = choices[i], Menu.GetItemButton(i)
            b.itemID = c.id
            Menu.SetItemButtonAction(b, c.id, e, kind)
            b:SetSize(rowsWidth, h)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -(i - 1) * (h + 1))
            local iconSize = h - 6
            b.icon:SetSize(iconSize, iconSize)
            b.icon:ClearAllPoints()
            b.icon:SetPoint("LEFT", 4, 0)
            b.icon:SetTexture(ItemIcon(c.id) or FALLBACK_ICON)
            Style.StyleIconBorder(b.iconBorder, b.icon, st.iconBorder)
            b.count:ClearAllPoints()
            b.count:SetPoint("RIGHT", -4, 0)
            b.count:SetText(c.count)
            -- Zeile 1: Name (+ XP-Abzeichen); Zeile 2: Kategorie + "beste Wahl"
            local best = i == 1
            local info = Menu.ItemInfoText(c)
            local nameY = ms.itemTwoLines and 6 or 0
            b.name:ClearAllPoints()
            b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, nameY)
            Style.SetColor(b.name, "SetTextColor", ms.textColor)
            local name = ItemName(c.id)
            if best and not ms.itemTwoLines then name = Style.StarMarkup(12) .. " " .. name end
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
            if ms.itemTwoLines then
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
            if GameTooltip:IsOwned(b) then GameTooltip:SetItemByID(c.id); GameTooltip:Show() end

            local s = Menu.GetStar(i)
            s.itemID = c.id
            Menu.SetStar(s, cdb.favorites[c.id] == true, st)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", pad + rowsWidth + 4, itemTop - (i - 1) * (h + 1) - (h - Menu.STAR_SIZE - 4) / 2)
            s:Show()
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
            b.itemID = nil
            b:SetAttribute("item", nil)
            b:SetAttribute("macrotext", nil)
        end
    end
    for i = n + 1, #menu.stars do menu.stars[i]:Hide() end

    -- Stummschalten: vier Schaltflächen nebeneinander
    Separator()
    Head(menu.muteHead, L.MENU_MUTE)
    local bw = (inner - 3 * 4) / 4
    for i, b in ipairs(menu.muteButtons) do
        b:SetSize(bw, 20)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pad + (i - 1) * (bw + 4), y)
        b:SetBackdrop({ edgeFile = Style.WHITE, edgeSize = 1 })
        Style.SetColor(b, "SetBackdropBorderColor", ms.buttonBorder)
        b.bg:ClearAllPoints()
        b.bg:SetPoint("TOPLEFT", 1, -1)
        b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        Style.SetColor(b.bg, "SetColorTexture", ms.buttonBg)
        Style.SetColor(b.label, "SetTextColor", ms.textColor)
    end
    y = y - 20 - ms.gap

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
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local x = math.max(0, math.min(menu.x or 0, sw - width))
    local top = menu.y or sh
    if top - height < 0 then top = top - 20 + height end
    top = math.min(sh, math.max(top, height))
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)

    if withItems and n > 0 then
        itemPanel:ClearAllPoints()
        itemPanel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + pad, top + itemTop)
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
    if self:IsMouseOver() or (itemPanel:IsShown() and itemPanel:IsMouseOver()) then self.away = 0 else
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
            local relevant = knownCache[e.key] and IsEnabled(e) and (not e.general or instOk)
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
        if e.kind == "conjure" or e.weaponItems then
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
    config.expGroupCB:SetChecked(expGroup)
    config.expReagCB:SetChecked(expReag)
    if config.reagentHint then config.reagentHint:SetAlpha(expReag and 1 or 0.5) end
    if config.groupCB then
        config.groupCB:SetChecked(db.groupCheck)
        Cfg.SetCheckEnabled(config.groupCB, expGroup)
        config.groupModeBtn:SetText(L.GROUP_MODE:format(L.GROUP_MODES[db.groupMode] or db.groupMode))
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
    config.soundBtn:SetText(L.SOUND:format(L.SOUNDS[db.sound] or db.sound))
    config.styleBtn:SetText(L.STYLE:format(L.STYLE_NAMES[db.style] or db.style))
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

-- Klassenliste: Einträge mit hideUnknown (Verbrauchsgüter) erst zeigen, wenn erlernt; alles
-- darunter (config.below) rückt nach
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
    config.below:SetPoint("TOPLEFT", config, "TOPLEFT", 0, y)
    config.below:SetSize(440, Cfg.belowHeight)
    config:SetSize(440, -y + Cfg.belowHeight)
end

function Cfg.MakeEntryRow(parent, e, y)
    local w = { entry = e, parent = parent }
    w.cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    w.cb:SetSize(24, 24)
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

-- Inhalt der Einstellungsseite in einem Scrollbereich (Höhe hängt von Klasse/Reagenzien ab)
function Cfg.CreateCanvasContent()
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "BuffReminderConfigScroll", Cfg.configCanvas, "UIPanelScrollFrameTemplate")
    if not ok then
        -- ohne Vorlage: Scrollen nur per Mausrad
        scroll = CreateFrame("ScrollFrame", "BuffReminderConfigScroll", Cfg.configCanvas)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local v = self:GetVerticalScroll() - delta * 40
            v = math.max(0, math.min(v, self:GetVerticalScrollRange()))
            self:SetVerticalScroll(v)
        end)
    end
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", "BuffReminderConfig", scroll)
    scroll:SetScrollChild(content)
    return content
end

local function BuildConfig()
    if Cfg.configCanvas then
        config = Cfg.CreateCanvasContent()
    else
        -- Fallback ohne Settings-API: eigenständiges Fenster
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

        local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
    end

    local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText(L.TITLE)

    local y = -48
    local className = UnitClass("player")
    Cfg.MakeHeader(config, L.CLASS_SECTION:format(className or "?"), y)
    y = y - 22
    if #classEntries == 0 then
        local fs = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", 20, y)
        fs:SetText(L.NO_CLASS)
        y = y - 20
    end
    Cfg.classTop = y
    for _, e in ipairs(classEntries) do
        Cfg.MakeEntryRow(config, e, y).classRow = true
    end

    -- Alles unterhalb der Klassenliste liegt in einem eigenen Frame (p), den
    -- Cfg.LayoutClassRows unter die sichtbaren Klassenzeilen rückt
    local p = CreateFrame("Frame", nil, config)
    config.below = p
    y = 0
    y = y - 10
    Cfg.MakeHeader(p, L.GENERAL, y)
    y = y - 22
    for _, e in ipairs(GENERAL_BUFFS) do
        Cfg.MakeEntryRow(p, e, y)
        y = y - 26
    end

    y = y - 12
    config.enabledCB = Cfg.MakeCheck(p, L.ENABLED, 16, y, function(self)
        db.enabled = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    config.instCB = Cfg.MakeCheck(p, L.INSTANCE_ONLY, 160, y, function(self)
        db.instanceOnly = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 26
    config.castCB = Cfg.MakeCheck(p, L.CLICKCAST, 16, y, function(self)
        db.clickCast = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    y = y - 30

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

    -- Tastenbelegung "Oberste Warnung auslösen": aktuelle Taste + wo sie belegt wird
    config.keyText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    config.keyText:SetPoint("TOPLEFT", 20, y)
    config.keyText:SetJustifyH("LEFT")
    y = y - 14
    local keyWhere = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keyWhere:SetPoint("TOPLEFT", 20, y)
    keyWhere:SetJustifyH("LEFT")
    keyWhere:SetText(L.KEY_WHERE)
    y = y - 24

    -- Experimentelle Funktionen: klar abgesetzter Abschnitt; Detail-Einstellungen direkt
    -- unter dem jeweiligen Schalter, ausgegraut solange dieser aus ist
    local sep = p:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 0.5, 0, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, y)
    sep:SetPoint("TOPRIGHT", p, "TOPLEFT", 424, y)
    y = y - 8
    local expHead = Cfg.MakeHeader(p, L.EXP_SECTION, y)
    expHead:SetTextColor(1, 0.5, 0)
    y = y - 16
    local expNote = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    expNote:SetPoint("TOPLEFT", 16, y)
    expNote:SetText(L.EXP_NOTE)
    y = y - 20

    -- Gruppen-Buffs
    config.expGroupCB = Cfg.MakeCheck(p, L.EXP_GROUP, 16, y, function(self)
        db.expGroup = self:GetChecked() and true or false
        if not GroupFeatureOn() then wipe(Group.groupState) else Group.MarkGroupDirty() end
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    -- Detail-Einstellungen nur für Klassen mit Gruppen-Buffs (Priester, Magier, Druide)
    local hasGroup = false
    for _, e in ipairs(classEntries) do
        if e.groupIds then hasGroup = true end
    end
    if hasGroup then
        config.groupCB = Cfg.MakeCheck(p, L.GROUP_CHECK, 36, y, function(self)
            db.groupCheck = self:GetChecked() and true or false
            if not GroupFeatureOn() then wipe(Group.groupState) else Group.MarkGroupDirty() end
            NoteDeferred()
            Evaluate()
        end)
        config.groupModeBtn = Cfg.MakeButton(p, "", 200)
        config.groupModeBtn:SetPoint("TOPRIGHT", p, "TOPLEFT", 424, y)
        config.groupModeBtn:SetScript("OnClick", function()
            local idx = 1
            for i, k in ipairs(GROUP_MODE_ORDER) do if k == db.groupMode then idx = i end end
            db.groupMode = GROUP_MODE_ORDER[idx % #GROUP_MODE_ORDER + 1]
            Group.MarkGroupDirty()
            NoteDeferred()
            Evaluate()
            RefreshConfig()
        end)
        y = y - 26
    end

    -- Reagenzien-Warnung
    y = y - 4
    config.expReagCB = Cfg.MakeCheck(p, L.EXP_REAGENTS, 16, y, function(self)
        db.expReagents = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    -- Schwellenwerte: nur die Reagenzien der eigenen Klasse
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

    -- Warnung vor Ablauf + Detail-Regler (Schwelle, Transparenz)
    y = y - 4
    config.expExpiryCB = Cfg.MakeCheck(p, L.EXP_EXPIRY, 16, y, function(self)
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
    y = y - 28

    -- Klassen-Verbrauchsgüter (Einträge stehen in der Klassenliste); Schwelle für gezaubertes
    -- Essen/Wasser nur bei Klassen mit solchen Einträgen (Magier)
    config.expConsCB = Cfg.MakeCheck(p, L.EXP_CONSUMABLES, 16, y, function(self)
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
    -- Steine, Öle, Gifte (Funktion folgt in einer späteren Version)
    config.expWeaponCB = Cfg.MakeCheck(p, L.EXP_WEAPONITEMS, 16, y, function(self)
        db.expWeaponItems = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    y = y - 26
    y = y - 10

    config.soundBtn = Cfg.MakeButton(p, "", 100)
    config.soundBtn:SetPoint("TOPLEFT", 18, y)
    config.soundBtn:SetScript("OnClick", function()
        local idx = 1
        for i, k in ipairs(SOUND_ORDER) do if k == db.sound then idx = i end end
        db.sound = SOUND_ORDER[idx % #SOUND_ORDER + 1]
        PlayAlertSound()
        RefreshConfig()
    end)

    config.moveBtn = Cfg.MakeButton(p, L.MOVE, 90)
    config.moveBtn:SetPoint("LEFT", config.soundBtn, "RIGHT", 4, 0)
    config.moveBtn:SetScript("OnClick", function()
        if InCombatLockdown() then Print(L.COMBAT); return end
        unlocked = not unlocked
        if not unlocked then wipe(shownKeys); Display.ShowRows({}) end
        Evaluate()
    end)

    local testBtn = Cfg.MakeButton(p, L.TEST, 60)
    testBtn:SetPoint("LEFT", config.moveBtn, "RIGHT", 4, 0)
    testBtn:SetScript("OnClick", StartTest)

    local unmuteBtn = Cfg.MakeButton(p, L.UNMUTE, 110)
    unmuteBtn:SetPoint("LEFT", testBtn, "RIGHT", 4, 0)
    unmuteBtn:SetScript("OnClick", function()
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    end)

    Cfg.belowHeight = -y + 44
    Cfg.LayoutClassRows()
    config:SetScript("OnShow", RefreshConfig)
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
    local category = LP:RegisterSettingsCanvas(PARDONA_ID, canvas, "Buff Reminder")
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
SafeRegisterEvent(ev, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(ev, "GET_ITEM_INFO_RECEIVED")
SafeRegisterEvent(ev, "ENABLE_XP_GAIN")
SafeRegisterEvent(ev, "DISABLE_XP_GAIN")
SafeRegisterEvent(ev, "UPDATE_BINDINGS")   -- Tasten-Hinweis in den Einstellungen
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
        cdb.favorites = cdb.favorites or {}       -- Item-ID -> true: Favorit (Essen/Fläschchen)
        if not Style.STYLES[db.style] then db.style = DEFAULTS.style end
        -- cdb.lastFlask: Item-ID des zuletzt benutzten Fläschchens (nil = keins)
        db.iconCache = db.iconCache or {}         -- allgemeiner Buff -> zuletzt gesehenes Aura-Icon
        db.flaskSpells = db.flaskSpells or {}     -- gelernte Spell-IDs von Fläschchen-Effekten
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
            if g then e.groupIds, e.manaOnly = g.groupIds, g.manaOnly end
        end
        Conjure.Preload(classEntries)   -- Namen der Verbrauchsgüter-Items vorladen
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
        -- Essen & Fläschchen: Kategorie-Gewichte der Klasse, gelernte Fläschchen-Spells, Taschen
        for _, e in ipairs(GENERAL_BUFFS) do
            if e.itemKind == "flask" then flaskEntry = e end
            if e.itemKind == "food" then foodEntry = e end
        end
        for id in pairs(db.flaskSpells) do flaskEntry.idSet[id] = true end
        Items.BuildFoodScores(class)
        Items.UpdateXP()            -- zählt Erfahrung? (XP-Essen bevorzugen / Abzeichen)
        Eat.ResolveAllEatSpells()   -- Ess-Auren aller FOOD-Items (fehlende werden nachgeladen)
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
        ApplyLayout()
        Display.ApplyStyle()
        RegisterPardonaSettings()
        -- UNIT_AURA für alle Units; gefiltert auf player / party* / raid* (siehe unten)
        SafeRegisterEvent(self, "UNIT_AURA")
        SafeRegisterEvent(self, "GROUP_ROSTER_UPDATE")
        SafeRegisterEvent(self, "UNIT_INVENTORY_CHANGED", "player")
        SafeRegisterEvent(self, "UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.NewTicker(1, Evaluate)
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- arg1 = Item-ID; nur eigene Reagenzien interessieren (lokalisierter Name nachgeladen)
        -- bzw. Essen/Fläschchen in den Taschen (Name, Stufe, Tooltip jetzt verfügbar)
        if IsSecret(arg1) then return end
        if Eat.eatPending[arg1] then Eat.ResolveEatSpell(arg1, true) end   -- Ess-Aura jetzt ermittelbar
        if Items.bagCounts[arg1] then
            if Items.IsFlaskItem(arg1) then Items.LearnFlaskSpell(arg1) end
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
        if not GroupFeatureOn() then return end
        Group.MarkGroupDirty()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- nach dem Kampf: Gruppe sofort neu prüfen, Zeilen/Attribute nachziehen
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
        TogglePardonaMinimap()
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
            Eat.eatAura and ("%s – %s"):format(tostring(Eat.eatAura.name), tostring(Eat.eatAura.id)) or "none",
            CountKeys(Eat.eatSpells), CountKeys(Eat.eatNames)))
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
        -- Experimental-Schalter: wieder Build-abhängig
        db.expGroup, db.expReagents, db.expExpiry, db.expConsumables, db.expWeaponItems = nil, nil, nil, nil, nil
        ApplyDefaults(db, DEFAULTS)
        wipe(cdb.buffs)
        wipe(cdb.reagents)
        ApplyLayout(); Display.ApplyStyle(); Print(L.RESET); Evaluate()
    else
        for _, line in ipairs(L.HELP) do Print(line) end
    end
end
