-- Pardona's Buff Reminder – Tastenbelegung "Oberste Warnung auslösen" (unsichtbarer Secure Button) und Warnton.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Display.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Eat = ns.Eat
local Style = ns.Style
local Display = ns.Display
local Cfg = ns.Cfg
local Keybind = ns.Keybind
local Tracking = ns.Tracking
local Pet = ns.Pet
local IsSecret = ns.IsSecret
-- aus Data.lua
local Sound = ns.Sound
-- aus Display.lua
local anchor = ns.anchor
local rows = ns.rows
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Tastenbelegung "Oberste Warnung auslösen" (Bindings.xml: CLICK PardonasBuffReminderKeyButton:LeftButton)
-- Unsichtbarer Secure Button ohne Parent und ohne Maus. Außerhalb des Kampfes übernimmt er bei
-- jeder Änderung der Liste (ShowRows) die Linksklick-Attribute der am Bildschirm obersten
-- Fehlt-Zeile mit Aktion (Zauber, Item, Makro, Verfolgung); "isst gerade" wird übergangen. Gibt es
-- keine, nimmt er die oberste Ablauf-Zeile mit Aktion (Buff auffrischen). Sonst oder im
-- Verschiebe-Modus: Attribute leer (Taste tut nichts).
-- Eine eben benutzte Zeile (per Taste oder Linksklick, Keybind.recent) wird 1,5 Sek. übergangen
-- (kein doppelter Item-Verbrauch, solange Taschen/Auren nachziehen); außerhalb des Kampfes zeigt
-- die Taste sofort auf die nächste passende Zeile.
-- Im Kampf bleibt die Belegung vom Kampfbeginn; ein Secure-Wrapper leert sie nach einem Item oder
-- Makro (Einmal-Sperre), Zauber und Verfolgung bleiben wiederholbar. Nach dem Kampf belegen
-- Evaluate und Keybind.Update (PLAYER_REGEN_ENABLED) neu. Auch per Makro: /click PardonasBuffReminderKeyButton
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
Keybind.button:HookScript("PreClick", Pet.PreClick)   -- Tier füttern: Taschenplatz neu ermitteln
Keybind.button:SetScript("PostClick", function(self, button, down)
    if button ~= "LeftButton" or not Display.IsActionPhase(down) then return end
    -- per Taste benutztes Fläschchen als "zuletzt benutzt" merken (wie beim Linksklick)
    if self.useItem and self.entry and self.entry.itemKind == "flask" and cdb then cdb.lastFlask = self.useItem end
    -- Verfolgungs-Zeile oben: Verfolgung einschalten wie beim Linksklick
    if self.entry and self.entry.kind == "tracking" then Tracking.Activate(self) end
    -- benutzte Zeile kurz sperren; außerhalb des Kampfes zeigt die Taste sofort auf die nächste
    Keybind.MarkUsed(self)
end)

Keybind.LOCK_TIME = 1.5   -- Sek., die eine eben benutzte Zeile übergangen wird
Keybind.recent = {}       -- entry.key -> Ablaufzeit (GetTime) der Sperre nach einer Benutzung

-- Benutzung einer Zeile merken (Taste oder Linksklick auf die Warnzeile), nur wenn der Button
-- eine Aktion hatte; außerhalb des Kampfes sofort neu belegen (im Kampf wirkt der Eintrag bei der
-- nächsten Belegung nach dem Kampf)
function Keybind.MarkUsed(btn)
    local e, a = btn.entry, btn.action
    if not (e and e.key and a and (a.spell or a.item or a.macro or a.trackIndex)) then return end
    Keybind.recent[e.key] = GetTime() + Keybind.LOCK_TIME
    if not InCombatLockdown() then Keybind.Update() end
end

-- Zeile gerade gesperrt? Abgelaufene Einträge werden entfernt.
function Keybind.IsRecent(key)
    local t = Keybind.recent[key]
    if not t then return false end
    if GetTime() >= t then Keybind.recent[key] = nil; return false end
    return true
end

-- Einmal-Sperre im Kampf: Secure-Wrapper um OnClick. Der Post-Body leert in der Aktionsphase
-- type1/item1/macrotext1, wenn "pbr-oneshot" gesetzt ist (Item oder Makro). Die Aktionsphase steht
-- in "pbr-keydown" (CVar ActionButtonUseKeyDown; GetCVar gibt es im Restricted-Code nicht).
-- Beide Attribute setzt Keybind.Update außerhalb des Kampfes. Fehlen Wrapper-API oder Vorlage:
-- Taste wie bisher, nur ohne Einmal-Sperre.
Keybind.ONESHOT_PRE = [[ return button, "pbr" ]]
Keybind.ONESHOT_POST = [[
    if button == "LeftButton" and self:GetAttribute("pbr-oneshot")
        and ((down and true or false) == (self:GetAttribute("pbr-keydown") and true or false)) then
        self:SetAttribute("type1", nil)
        self:SetAttribute("item1", nil)
        self:SetAttribute("macrotext1", nil)
        self:SetAttribute("pbr-oneshot", nil)
    end
]]
function Keybind.SetupOneShot()
    if type(SecureHandlerWrapScript) ~= "function" then return end
    local ok, header = pcall(CreateFrame, "Frame", nil, nil, "SecureHandlerBaseTemplate")
    if not ok or not header then return end
    Keybind.wrapped = pcall(SecureHandlerWrapScript, Keybind.button, "OnClick", header,
        Keybind.ONESHOT_PRE, Keybind.ONESHOT_POST) and true or false
end
Keybind.SetupOneShot()

-- Indizes der angezeigten Zeilen (n) in Bildschirmreihenfolge von oben nach unten, in einer
-- Reihe von links nach rechts: nach unten wachsend 1..n; nach oben n..1; "Nur Icons" in Reihen
-- zu ICONS_PER_LINE (nach oben: die letzte Reihe steht oben)
function Display.ScreenOrder(n)
    local list = {}
    local up = Display.GrowUp()
    if Style.IconsOnly(Style.CurrentStyle()) then
        local per = Display.ICONS_PER_LINE
        local lines = math.ceil(n / per)
        for k = 1, lines do
            local line = up and (lines - k + 1) or k
            for i = (line - 1) * per + 1, math.min(line * per, n) do list[#list + 1] = i end
        end
    elseif up then
        for i = n, 1, -1 do list[#list + 1] = i end
    else
        for i = 1, n do list[#list + 1] = i end
    end
    return list
end

-- Zeile für die Taste: zuerst die oberste Fehlt-Zeile mit Aktion (nicht "isst gerade", nicht eben
-- benutzt); gibt es keine, die oberste Ablauf-Zeile mit Aktion (nicht eben benutzt); sonst nil
function Keybind.PickRow(n)
    if State.unlocked then return nil end   -- Verschiebe-Modus
    local order = Display.ScreenOrder(n)
    for pass = 1, 2 do
        local wantExpiry = pass == 2
        for _, i in ipairs(order) do
            local r = rows[i]
            local e, a = r and r.entry, r and r.action
            if e and r:IsShown() and (r.expiryRow and true or false) == wantExpiry
                and (wantExpiry or not e.eatStart) and not Keybind.IsRecent(e.key) and a
                and (a.spell or a.item or a.macro or a.trackIndex) then
                return r
            end
        end
    end
    return nil
end

-- Attribute der gewählten Zeile übernehmen (nur außerhalb des Kampfes; n = Anzahl angezeigter
-- Zeilen, nil = zuletzt bekannte). Eben benutzte Zeilen (Keybind.recent) werden übergangen.
function Keybind.Update(n)
    if n then Keybind.lastN = n end
    if InCombatLockdown() then return end
    local b = Keybind.button
    local r = Keybind.PickRow(Keybind.lastN or 0)
    local a = r and r.action or nil
    b.entry = r and r.entry or nil
    b.actionSig = nil   -- neu setzen, auch wenn der Wrapper die Attribute im Kampf geleert hat
    Display.SetRowAction(b, a)
    -- Einmal-Sperre bei Item-Verbrauch: Item, Makro oder Zauber auf ein Taschen-Item (Tier füttern)
    b:SetAttribute("pbr-oneshot", (a and ((not a.spell and (a.item or a.macro)) or a.targetBag ~= nil)) and true or nil)
    b:SetAttribute("pbr-keydown", Display.GetCVarFlag("ActionButtonUseKeyDown") and true or false)
    Keybind.Retry()
end

-- Neue Belegung, sobald die früheste Zeilen-Sperre abläuft (ein Timer; im Kampf übernimmt
-- PLAYER_REGEN_ENABLED)
function Keybind.Retry()
    if Keybind.retryPending then return end
    local first
    for key in pairs(Keybind.recent) do
        if Keybind.IsRecent(key) then
            local t = Keybind.recent[key]
            if not first or t < first then first = t end
        end
    end
    if not first then return end
    Keybind.retryPending = true
    C_Timer.After(math.max(0.05, first - GetTime() + 0.05), function()
        Keybind.retryPending = false
        if not InCombatLockdown() then Keybind.Update() end
    end)
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

-- Sound-Kit-ID eines eingebauten Tons; nil = Client kennt die Konstante nicht (und kein Rückfall)
function Sound.KitId(key)
    for _, def in ipairs(Sound.BUILTIN) do
        if def[1] == key then
            local id = type(SOUNDKIT) == "table" and SOUNDKIT[def[2]] or nil
            if type(id) == "number" and not IsSecret(id) then return id end
            return def[3]
        end
    end
    return nil
end

-- LibSharedMedia-3.0, falls ein anderes Addon sie geladen hat (nie eingebettet)
function Sound.LSM()
    if not LibStub then return nil end
    local ok, lsm = pcall(LibStub.GetLibrary, LibStub, "LibSharedMedia-3.0", true)
    return ok and lsm or nil
end

-- Pfad eines LibSharedMedia-Tons; nil = nicht (mehr) vorhanden
function Sound.LSMPath(name)
    local lsm = Sound.LSM()
    if not lsm then return nil end
    local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true)
    if ok and (type(path) == "string" or type(path) == "number") then return path end
    return nil
end

-- Auswahl für das Dropdown: verfügbare Blizzard-Töne, "Aus", dann LibSharedMedia-Töne
function Sound.Options()
    local list = {}
    for _, def in ipairs(Sound.BUILTIN) do
        if Sound.KitId(def[1]) then list[#list + 1] = { value = def[1], text = Cfg.ValueText("SOUND_", def[1]) } end
    end
    list[#list + 1] = { value = "aus", text = L.SOUND_AUS }
    local lsm = Sound.LSM()
    local ok, names = false, nil
    if lsm then ok, names = pcall(lsm.List, lsm, "sound") end
    if ok and type(names) == "table" then
        local extra = {}
        for _, n in ipairs(names) do
            if type(n) == "string" and n ~= "None" then extra[#extra + 1] = n end
        end
        if #extra > 0 then
            list[#list + 1] = { title = "LibSharedMedia" }
            for _, n in ipairs(extra) do list[#list + 1] = { value = Sound.LSM_PREFIX .. n, text = n } end
        end
    end
    return list
end

-- Angezeigter Name eines gespeicherten Tons
function Sound.Label(key)
    key = tostring(key)
    if key:sub(1, #Sound.LSM_PREFIX) == Sound.LSM_PREFIX then return key:sub(#Sound.LSM_PREFIX + 1) end
    return Cfg.ValueText("SOUND_", key)
end

-- Ton abspielen (Kanal "Master"); fehlender Ton -> Bell, nie ein Fehler
function Sound.Play(key)
    if key == "aus" then return end
    key = tostring(key)
    if key:sub(1, #Sound.LSM_PREFIX) == Sound.LSM_PREFIX then
        local path = Sound.LSMPath(key:sub(#Sound.LSM_PREFIX + 1))
        if path and type(PlaySoundFile) == "function" and pcall(PlaySoundFile, path, "Master") then return end
        key = Sound.FALLBACK
    end
    local id = Sound.KitId(key) or Sound.KitId(Sound.FALLBACK)
    if id and type(PlaySound) == "function" then pcall(PlaySound, id, "Master") end
end

local function PlayAlertSound()
    Sound.Play(db.sound)
end

-- Für andere Dateien (ns)
ns.PlayAlertSound = PlayAlertSound
