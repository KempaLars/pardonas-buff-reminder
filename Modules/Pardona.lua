-- Pardona's Buff Reminder – LibPardona-Anbindung: Minimap-Button, Addon-Fach, Einstellungs-Kategorie, Kurzstatus.
-- Abhängigkeiten (beim Laden): Core.lua, Evaluate.lua, Config.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Cfg = ns.Cfg
local muted = ns.muted
local LP = ns.LP
local PARDONA_ID = ns.PARDONA_ID
local Print = ns.Print
local NoteDeferred = ns.NoteDeferred
-- aus Evaluate.lua
local StartTest = ns.StartTest
local Evaluate = ns.Evaluate
-- aus Config.lua
local BuildConfig = ns.BuildConfig
local ToggleConfig = ns.ToggleConfig
local RefreshConfig = ns.RefreshConfig
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db
ns.OnDB(function(newDb) db = newDb end)

---------------------------------------------------------------------------
-- LibPardona: gemeinsamer Minimap-Button, Addon-Fach, Einstellungs-Kategorie
---------------------------------------------------------------------------
-- Kurzstatus; nil im Kampf oder solange der Zustand unbekannt ist
local function PardonaStatus()
    if not db or not State.ready or State.warnCount == nil or State.warnCount < 0 or InCombatLockdown() then return nil end
    if State.warnCount == 0 then return L.STATUS_OK end
    if State.warnCount == 1 then return L.STATUS_ONE end
    return L.STATUS_MANY:format(State.warnCount)
end

-- /br debug: Diagnose der LibPardona (LP:GetDiagnostics, MINOR >= 6): aktive Kopie, Stil-/Menü-
-- Versionen und die von Buff Reminder mitgebrachte Kopie. Ältere Libs: Hinweiszeile.
function Cfg.LibDiagLines()
    if not (LP and type(LP.GetDiagnostics) == "function") then
        return { "Lib diagnostics: not available (Lib < 6)" }
    end
    local ok, diag = pcall(LP.GetDiagnostics, LP)
    if not ok or type(diag) ~= "table" then return { "Lib diagnostics: error (" .. tostring(diag) .. ")" } end
    local lines = {
        ("lib: active MINOR %s (from %s), style %s, menu %s, diagnostics %s"):format(tostring(diag.minor),
            tostring(diag.from), tostring(diag.styleVersion or "-"), tostring(diag.menuVersion or "-"),
            tostring(diag.diagnosticsVersion or "-")),
    }
    local own
    for _, c in ipairs(type(diag.copies) == "table" and diag.copies or {}) do
        if type(c) == "table" and c.addon == ADDON_NAME and (not own or (tonumber(c.minor) or 0) > own) then
            own = tonumber(c.minor)
        end
    end
    lines[#lines + 1] = ("lib: bundled with %s: %s"):format(ADDON_NAME, own and ("MINOR " .. own) or "not recorded (< 6)")
    for _, a in ipairs(type(diag.addons) == "table" and diag.addons or {}) do
        if type(a) == "table" then
            lines[#lines + 1] = ("lib: addon %s %s – Lib %s"):format(tostring(a.name), tostring(a.version),
                a.libMinor and tostring(a.libMinor) or "< 6")
        end
    end
    return lines
end

-- Ist mindestens eine Warnung stummgeschaltet (noch nicht abgelaufen)?
function Cfg.AnyMuted()
    local now = GetTime()
    for _, untilT in pairs(muted) do
        if untilT > now then return true end
    end
    return false
end

-- Einträge im Pardona-Menü (info.menu; bei jedem Öffnen neu ausgewertet): Anzeige verschieben/
-- sperren, Test, Stummschaltungen aufheben. Gleiches Verhalten wie /br move, lock, test, unmute.
function Cfg.PardonaMenu()
    local combatTip = function() return InCombatLockdown() and L.MENU_NOT_IN_COMBAT or nil end
    return {
        {
            text = function() return State.unlocked and L.MENU_LOCK or L.MENU_MOVE end,
            disabled = function() return InCombatLockdown() end,
            tooltip = combatTip,
            onClick = function() Cfg.SetMoveMode(not State.unlocked) end,
        },
        {
            text = L.TEST,
            disabled = function() return InCombatLockdown() end,
            tooltip = combatTip,
            onClick = function() StartTest() end,
        },
        {
            text = L.UNMUTE,
            disabled = function() return not Cfg.AnyMuted() end,
            onClick = function() wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate() end,
        },
    }
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
        -- Schnellaktionen im Pardona-Menü (nur Libs mit Menüeinträgen, MINOR >= 6)
        menu    = LP.MENU_VERSION and Cfg.PardonaMenu or nil,
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
    if not LP or State.config then return end
    local canvas = CreateFrame("Frame", "BuffReminderSettingsCanvas")
    canvas:Hide()
    local category = LP:RegisterSettingsCanvas(PARDONA_ID, canvas, L.SETTINGS_NAME)
    if not category then return end
    Cfg.configCanvas = canvas
    canvas:SetScript("OnShow", function()
        if not State.config then BuildConfig() end
        RefreshConfig()
    end)
end

-- /br minimap: gemeinsamen Pardona-Button ein-/ausblenden (gilt für alle Pardona-Addons)
local function TogglePardonaMinimap()
    if LP then LP:ToggleMinimap() end
end

-- Für andere Dateien (ns)
ns.RegisterPardona = RegisterPardona
ns.RegisterPardonaSettings = RegisterPardonaSettings
ns.TogglePardonaMinimap = TogglePardonaMinimap
