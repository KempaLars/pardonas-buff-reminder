-- Pardona's Buff Reminder – Namensraum und Grundlagen: Modultabellen (an ns), Texte (L), dateiübergreifender
-- Zustand (State, db/cdb über ns.OnDB/ns.SetDB) und gemeinsame Helfer (Print, IsSecret, SpellName,
-- SpellIcon, BuildKind, IsTestBuild, ExpOn, GroupFeatureOn, LibPardona-Handle LP).
-- Abhängigkeiten (beim Laden): -

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
local Expiry  = {}   -- Warnung vor Ablauf
local Conjure = {}   -- Klassen-Verbrauchsgüter: Magier-Essen/-Wasser/Manastein, Hexenmeister-Steine
local Keybind = {}   -- Tastenbelegung "Oberste Warnung auslösen" (unsichtbarer Secure Button)
local Variant = {}   -- Variantenmenü per Rechtsklick
local Tracking = {}  -- Minimap-Tracking (z. B. Mineraliensuche)
local Demo = {}      -- versteckter Demo-Modus mit Screenshot-Lauf (nur mit BuffReminderDB.demo)
local Elixir = {}    -- Wunsch-Elixiere pro Charakter
local Scroll = {}    -- Rollen
local Pet = {}       -- Tier-Erinnerung: Jäger-Tier (fehlt/tot/füttern), Hexenmeister-Dämon (experimentell)
local Supply = {}    -- Vorräte: Munition, Seelensplitter, Tierfutter, eigene Items
local Restock = {}   -- Auffüllen beim Händler: Fenster "Auffüllen"
local Ranks = {}     -- Warnung bei niedrigen Zauberrängen (experimentell)

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
-- Dateiübergreifender Zustand
--   State   : veränderliche Werte, die mehrere Dateien lesen oder setzen. Sie stehen als Felder
--             einer gemeinsamen Tabelle (nicht als kopierte locals), damit jede Zuweisung in allen
--             Dateien sichtbar ist: ready, unlocked, warnCount, classEntries, reagentLines,
--             flaskEntry, foodEntry, layoutPending, config.
--   db, cdb : SavedVariables (BuffReminderDB / BuffReminderCharDB). ns.SetDB setzt sie bei
--             ADDON_LOADED; jede Datei, die sie braucht, hält eigene locals und meldet sich mit
--             ns.OnDB(function(newDb, newCdb) ... end) an (Aufruf in Ladereihenfolge).
---------------------------------------------------------------------------
local State = {}
local dbListeners = {}
function ns.OnDB(fn) dbListeners[#dbListeners + 1] = fn end
function ns.SetDB(newDb, newCdb)
    for _, fn in ipairs(dbListeners) do fn(newDb, newCdb) end
end

---------------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------------
local db                      -- account; gesetzt über ns.SetDB (cdb braucht Core nicht)
ns.OnDB(function(newDb) db = newDb end)
local entries = {}            -- aktive Liste (Klasse + allgemein)
State.classEntries = {}       -- Klassen-Einträge (CLASS_BUFFS der eigenen Klasse, bei PLAYER_LOGIN gesetzt)
local reagentEntries = {}     -- Reagenzien der eigenen Klasse (auch in entries)
State.reagentLines = {}       -- Zauberlinien der eigenen Klasse (REAGENT_SPELLS)
local knownCache = {}
local missing = {}            -- key -> bool (letzter lesbarer Zustand)
local missingSince = {}       -- key -> GetTime(), seit dem der Buff durchgehend fehlt
local MISSING_CONFIRM = 1     -- Sek. durchgehendes Fehlen, bevor gewarnt wird
local shownKeys = {}          -- key -> true, aktuell eingeblendet
local muted = {}              -- key -> Ablaufzeit (GetTime) | math.huge
State.ready, State.unlocked = false, false   -- testUntil: Evaluate.lua
-- Evaluate (Evaluate.lua) und RefreshConfig (Config.lua): in früher geladenen Dateien ns.Evaluate/ns.RefreshConfig
State.warnCount = nil         -- Anzahl angezeigter Warnungen, -1 = abgeschaltet, nil = unbekannt

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

-- Freigegebene Schalter (seit 1.5.0): ohne Nutzerwert immer an, abschaltbar wie bisher
Cfg.RELEASED_EXP = {
    expExpiry = true, expConsumables = true, expElixirs = true, expScrolls = true,
    expWeaponItems = true, expVariantMenu = true, expTracking = true, expReagents = true,
    expRestock = true,
}

-- Schalter (account-weit): nil = nicht vom Nutzer gesetzt → freigegebene an, experimentelle
-- (expPet, expGroup, expBlessings, expRanks) in Test-Builds an, in Release-Versionen aus
local function ExpOn(key)
    local v = db and db[key]
    if v == nil then return Cfg.RELEASED_EXP[key] == true or IsTestBuild() end
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

-- Für andere Dateien (ns)
ns.State = State
ns.Items = Items
ns.Eat = Eat
ns.Group = Group
ns.Style = Style
ns.Display = Display
ns.Menu = Menu
ns.Cfg = Cfg
ns.Expiry = Expiry
ns.Conjure = Conjure
ns.Keybind = Keybind
ns.Variant = Variant
ns.Tracking = Tracking
ns.Demo = Demo
ns.Elixir = Elixir
ns.Scroll = Scroll
ns.Pet = Pet
ns.Supply = Supply
ns.Restock = Restock
ns.Ranks = Ranks
ns.entries = entries
ns.reagentEntries = reagentEntries
ns.knownCache = knownCache
ns.missing = missing
ns.missingSince = missingSince
ns.MISSING_CONFIRM = MISSING_CONFIRM
ns.shownKeys = shownKeys
ns.muted = muted
ns.LP = LP
ns.PARDONA_ID = PARDONA_ID
ns.Print = Print
ns.NoteDeferred = NoteDeferred
ns.NormName = NormName
ns.IsSecret = IsSecret
ns.RefreshPardonaStatus = RefreshPardonaStatus
ns.PrintVersionNotice = PrintVersionNotice
ns.ExpOn = ExpOn
ns.GroupFeatureOn = GroupFeatureOn
ns.SpellName = SpellName
ns.SpellIcon = SpellIcon
