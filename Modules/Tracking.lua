-- Pardona's Buff Reminder – Verfolgungs-Erinnerung (Minimap-Tracking, Schalter expTracking).
-- Abhängigkeiten (beim Laden): Core.lua

local ADDON_NAME, ns = ...

-- aus Core.lua
local Tracking = ns.Tracking
local NormName = ns.NormName
local IsSecret = ns.IsSecret
local SpellName = ns.SpellName
local SpellIcon = ns.SpellIcon

---------------------------------------------------------------------------
-- Verfolgungs-Erinnerung (Schalter expTracking): mehrere gewünschte Verfolgungen
-- gleichzeitig (pro Charakter, cdb.trackSet). Erkennung zur Laufzeit über die Verfolgungsliste
-- (C_Minimap bzw. Legacy-API). Bekannte Arten (Mineralien, Kräuter, Fische, Schätze) über
-- Spell-ID, Zaubernamen aus dem Client oder Icon; alle übrigen Einträge der Liste (Fähigkeiten wie
-- Jäger-Verfolgungen, Minimap-Verfolgungen wie Flugmeister) sind ebenfalls wählbar.
-- Namen und Icons kommen immer aus dem Client (SpellName/SpellIcon bzw. Verfolgungsliste).
--   spell    : Spell-ID der Verfolgung
--   textures : zusätzliche bekannte Icons (File-ID oder Pfadteil), falls die Liste keine ID liefert
-- Laufzeit je Art: index (Platz in der Verfolgungsliste), name, tex (aus der Liste)
---------------------------------------------------------------------------
Tracking.TYPES = {
    minerals = { spell = 2580, textures = { 136025, "spell_nature_earthquake" } },   -- Mineraliensuche
    herbs    = { spell = 2383 },                                                     -- Kräutersuche
    fish     = { spell = 43308 },                                                    -- Fischsuche
    treasure = { spell = 2481 },                                                     -- Schatzsuche (Zwerge)
}
Tracking.ORDER   = { "minerals", "herbs", "fish", "treasure" }        -- Reihenfolge in den Einstellungen
Tracking.DEFAULT = { minerals = true, herbs = true, treasure = true }  -- Vorgabe ohne eigene Wahl
Tracking.list = {}            -- letzter Stand der Verfolgungsliste (Tracking.Scan)
Tracking.exclusive = false    -- Sitzung: der Client erlaubt nur eine Verfolgung gleichzeitig
Tracking.watch = nil          -- nach einem Klick: { keys = { [Schlüssel] = true }, untilT } (Exklusivität)
Tracking.WATCH_TIME = 3       -- Sek., die nach einem Klick auf ausgeschaltete Verfolgungen geachtet wird

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

-- Liefert name, tex, active (boolean), spellID, kind ("spell"/…); nil bei Fehler oder Secret-Wert
function Tracking.ReadInfo(i)
    local fn = Tracking.InfoFn()
    if not fn then return nil end
    local ok, a, b, c, d, _, f = pcall(fn, i)
    if not ok or a == nil or IsSecret(a) then return nil end
    if type(a) == "table" then
        local name = a.name
        local tex = a.texture or a.textureFileID or a.icon
        local active = a.active
        local spellID = a.spellID or a.spellId
        local kind = a.type
        if IsSecret(name) or IsSecret(active) or IsSecret(spellID) then return nil end
        return name, (not IsSecret(tex)) and tex or nil, active and true or false, spellID,
            (not IsSecret(kind)) and kind or nil
    end
    if IsSecret(c) or IsSecret(f) then return nil end
    return a, (not IsSecret(b)) and b or nil, c and true or false, f, (not IsSecret(d)) and d or nil
end

-- Stabiler Schlüssel eines Listeneintrags: bekannte Art (minerals/herbs/fish/treasure), sonst
-- "s:<spellID>", "t:<Icon>" oder "n:<Name>"
function Tracking.KeyOf(name, tex, spellID)
    for _, k in ipairs(Tracking.ORDER) do
        if Tracking.Matches(Tracking.TYPES[k], name, tex, spellID) then return k end
    end
    if spellID ~= nil then return "s:" .. tostring(spellID) end
    if tex ~= nil then return "t:" .. tostring(tex) end
    if type(name) == "string" and name ~= "" then return "n:" .. name end
    return nil
end

-- Verfolgungsliste des Clients lesen. Liefert list, state:
--   list  : { { key, index, name, tex, active, spell, ability }, ... } (nur lesbare Einträge)
--   state : "ok"; "secret" = Anzahl oder mind. ein Eintrag nicht lesbar; "none" = keine API
-- Merkt index/name/tex an den bekannten Arten.
function Tracking.Scan()
    local numFn = Tracking.NumTypesFn()
    if not (numFn and Tracking.InfoFn()) then return {}, "none" end
    local okN, num = pcall(numFn)
    if not okN or type(num) ~= "number" or IsSecret(num) or num <= 0 then return {}, "secret" end
    local list, state, seen = {}, "ok", {}
    for i = 1, num do
        local name, tex, active, spellID, kind = Tracking.ReadInfo(i)
        local key = active ~= nil and Tracking.KeyOf(name, tex, spellID) or nil
        if active == nil then
            state = "secret"
        elseif key and not seen[key] then
            seen[key] = true
            local t = Tracking.TYPES[key]
            if type(name) ~= "string" or name == "" then name = nil end
            if t then
                t.index, t.name, t.tex = i, name or t.name, tex or t.tex
            end
            list[#list + 1] = {
                key = key, index = i, active = active,
                name = (t and SpellName(t.spell)) or name or key,
                tex = tex or (t and SpellIcon(t.spell)) or (spellID and SpellIcon(spellID)),
                spell = spellID or (t and t.spell),
                ability = t ~= nil or spellID ~= nil or kind == "spell",
            }
        end
    end
    Tracking.list = list
    return list, state
end
