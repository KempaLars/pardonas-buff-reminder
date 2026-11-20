-- Pardona's Buff Reminder – Sprachdaten (Addon-Namespace, keine Globals)
--   Locales.data[code]  : Texte einer Sprache (gefüllt von Locales/<code>.lua)
--   ns.L[key]           : aktive Sprache, sonst enUS, sonst der Schlüssel selbst
--   Locales.Activate()  : aktive Sprache setzen (Rückgabe: tatsächlich genutzter Code)
-- Alle Sprachdateien werden geladen (kein Ausstieg per GetLocale), damit der versteckte
-- Sprach-Schalter BuffReminderDB.locale wirkt. Die Texte setzt der CurseForge-Packager ein;
-- ein ungepackter Stand aus dem Repo enthält nur enUS.

local _, ns = ...

local Locales = { data = {}, active = "enUS" }
ns.Locales = Locales

-- Tabelle einer Sprache (leer anlegen, falls noch nicht vorhanden)
function Locales.New(code)
    local t = Locales.data[code]
    if not t then
        t = {}
        Locales.data[code] = t
    end
    return t
end

-- Hat die Sprache mindestens einen Text?
function Locales.HasData(code)
    local t = type(code) == "string" and Locales.data[code] or nil
    return t ~= nil and next(t) ~= nil
end

-- Code, dessen Texte für "code" genutzt werden (esMX ohne Texte -> esES); nil = keine Texte
function Locales.Resolve(code)
    if Locales.HasData(code) then return code end
    if code == "esMX" and Locales.HasData("esES") then return "esES" end
    return nil
end

-- Sprache des Clients (GetLocale abgesichert)
function Locales.Client()
    local ok, code = false, nil
    if type(GetLocale) == "function" then ok, code = pcall(GetLocale) end
    if ok and type(code) == "string" then return code end
    return "enUS"
end

-- Aktive Sprache setzen: gültiger Code mit Texten, sonst die Client-Sprache, sonst enUS
function Locales.Activate(code)
    Locales.active = Locales.Resolve(code) or Locales.Resolve(Locales.Client()) or "enUS"
    return Locales.active
end

-- Text oder nil/default (ohne Rückfall auf den Schlüssel)
function Locales.Text(key, default)
    local a, en = Locales.data[Locales.active], Locales.data.enUS
    local v = a and a[key]
    if v == nil and en then v = en[key] end
    if v == nil then return default end
    return v
end

ns.L = setmetatable({}, {
    __index = function(_, key) return Locales.Text(key, key) end,
    __newindex = function() end,   -- nur lesen; Texte stehen in Locales/<code>.lua
})

Locales.Activate(Locales.Client())
