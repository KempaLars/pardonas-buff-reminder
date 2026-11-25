-- Pardona's Buff Reminder – Einstellungsfenster: Widgets, Dropdowns, Tabs, RefreshConfig, BuildConfig.
-- Eine Datei, damit der Fenster-Frame "config" lokal bleibt (andere Dateien: State.config).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua, Display.lua, Keybind.lua, Menu.lua, Evaluate.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Group = ns.Group
local Style = ns.Style
local Display = ns.Display
local Cfg = ns.Cfg
local Expiry = ns.Expiry
local Conjure = ns.Conjure
local Keybind = ns.Keybind
local Tracking = ns.Tracking
local Demo = ns.Demo
local Elixir = ns.Elixir
local Scroll = ns.Scroll
local Pet = ns.Pet
local Supply = ns.Supply
local Restock = ns.Restock
local reagentEntries = ns.reagentEntries
local knownCache = ns.knownCache
local shownKeys = ns.shownKeys
local muted = ns.muted
local LP = ns.LP
local PARDONA_ID = ns.PARDONA_ID
local Print = ns.Print
local NoteDeferred = ns.NoteDeferred
local ExpOn = ns.ExpOn
local GroupFeatureOn = ns.GroupFeatureOn
-- aus Data.lua
local GENERAL_BUFFS = ns.GENERAL_BUFFS
local GROUP_MODE_ORDER = ns.GROUP_MODE_ORDER
local Sound = ns.Sound
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local CountKeys = ns.CountKeys
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local EntryIcon = ns.EntryIcon
local RefreshKnown = ns.RefreshKnown
local IsEnabled = ns.IsEnabled
local MuteRemaining = ns.MuteRemaining
local InGroupInstance = ns.InGroupInstance
-- aus Display.lua
local ApplyLayout = ns.ApplyLayout
-- aus Keybind.lua
local PlayAlertSound = ns.PlayAlertSound
-- aus Menu.lua
local menu = ns.menu
-- aus Evaluate.lua
local StartTest = ns.StartTest
local Evaluate = ns.Evaluate
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)
local RefreshConfig          -- forward (function RefreshConfig unten)

---------------------------------------------------------------------------
-- Einstellungsfenster
---------------------------------------------------------------------------
local config
Cfg.configRows = {}
Cfg.reagentRows = {}       -- feste Vorrats-Zeilen (Reagenzien, Munition, Seelensplitter, Tierfutter)
Cfg.supplyItemRows = {}    -- Item-ID -> Zeile eines eigenen Vorrats-Items (ausgeblendet nach Entfernen)
-- Felder "Min.", "Kritisch" und "Auffüllen auf" der Vorrats-Zeilen
Cfg.SUPPLY_MIN_X, Cfg.SUPPLY_CRIT_X, Cfg.SUPPLY_REFILL_X = 176, 226, 276

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
            w.cb:SetChecked(Scroll.Enabled(e.scrollType))   -- wirksamer Wert (Wahl oder Klassenvorgabe)
        elseif e.kind == "conjure" or e.kind == "pet" or e.weaponItems then
            w.cb:SetChecked(cdb.buffs[e.key] ~= false)
        else
            w.cb:SetChecked(IsEnabled(e))
        end
        -- Rollen: neutraler Name und Icon der Art (Rang I), keine konkrete Rolle
        if e.kind == "scroll" then
            w.icon:SetTexture(Scroll.TypeIcon(e.scrollType))
            w.name:SetText(Scroll.TypeName(e.scrollType))
        else
            w.icon:SetTexture(EntryIcon(e))
            w.name:SetText(EntryLabel(e))
        end
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
    if Supply.dirty then Cfg.LayoutSupplies() end
    for _, w in ipairs(Cfg.reagentRows) do Cfg.RefreshSupplyRow(w, expReag) end
    for _, w in pairs(Cfg.supplyItemRows) do
        if w.icon:IsShown() then Cfg.RefreshSupplyRow(w, expReag) end
    end
    if config.supplyMax then
        if CountKeys(cdb.supplies) >= Supply.MAX_ITEMS then config.supplyMax:Show() else config.supplyMax:Hide() end
        Cfg.SetEditEnabled(Supply.addBox, expReag)
    end
    config.enabledCB:SetChecked(db.enabled)
    config.instCB:SetChecked(db.instanceOnly)
    config.castCB:SetChecked(db.clickCast)
    local expGroup = ExpOn("expGroup")
    if config.expGroupCB then config.expGroupCB:SetChecked(expGroup) end
    config.expReagCB:SetChecked(expReag)
    local expRestock = ExpOn("expRestock")
    config.restockCB:SetChecked(expRestock)
    Cfg.SetCheckEnabled(config.restockCB, expReag)
    config.restockAboveCB:SetChecked(db.restockAbove == true)
    Cfg.SetCheckEnabled(config.restockAboveCB, expReag and expRestock)
    for i, fs in ipairs(config.supplyCols or {}) do
        local on = expReag and (i < 3 or expRestock)   -- Spalte 3 "Auffüllen auf": nur mit Auffüllen
        fs:SetAlpha(on and 1 or 0.5)
    end
    if config.groupCB then
        config.groupCB:SetChecked(db.groupCheck)
        Cfg.SetCheckEnabled(config.groupCB, expGroup)
        if config.blessCB then
            config.blessCB:SetChecked(ExpOn("expBlessings"))
            Cfg.SetCheckEnabled(config.blessCB, expGroup and not Group.pallyPower)
            config.blessNote:SetText(Group.pallyPower and L.BLESS_PALLYPOWER or "")
        end
        Cfg.SyncDropdown(config.groupModeDD, expGroup)
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
    config.expTrackCB:SetChecked(ExpOn("expTracking"))
    if Cfg.trackSection then Cfg.LayoutTracking() end   -- Liste der Verfolgungen (Client)
    config.expElixirCB:SetChecked(ExpOn("expElixirs"))
    config.expScrollCB:SetChecked(ExpOn("expScrolls"))
    if Elixir.dirty then Cfg.LayoutElixirs() end
    Cfg.LayoutTab("other")      -- Listen ein-/ausklappen (Schalter an/aus)
    Cfg.LayoutTab("supplies")
    Cfg.RefreshPet()
    config.elixirEmpty:SetTextColor(ExpOn("expElixirs") and 0.6 or 0.4, ExpOn("expElixirs") and 0.6 or 0.4, 0.4)
    Cfg.SyncDropdown(config.soundDD, true)
    local scalePct = math.floor(Display.SavedScale() * 100 + 0.5)
    local alphaPct = math.floor(math.max(0.3, math.min(1, tonumber(db.alpha) or 1)) * 100 + 0.5)
    Cfg.SyncSlider(config.scaleSlider, scalePct, L.SIZE:format(scalePct), true)
    Cfg.SyncSlider(config.alphaSlider, alphaPct, L.OPACITY:format(alphaPct), true)
    Cfg.SyncDropdown(config.styleDD, true)
    config.iconsCB:SetChecked(db.iconsOnly)
    Cfg.SetCheckEnabled(config.iconsCB, Style.STYLES[db.style] ~= nil and Style.STYLES[db.style].iconsOnly)
    Cfg.SyncDropdown(config.growDD, true)
    config.keyText:SetText(L.KEY_LINE:format(L.KEY_NAME, Keybind.KeyText() or L.KEY_NONE))
    config.moveBtn:SetText(State.unlocked and L.LOCK or L.MOVE)
end

function Cfg.MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

-- Ausgegraut? (Schalter aus bzw. Schurke mit aktivem Gift-Eintrag); 2. Wert = Statushinweis
function Cfg.Gate(e, expCons)
    if e.kind == "elixir" then return not ExpOn("expElixirs"), nil end
    if e.kind == "scroll" then return not ExpOn("expScrolls"), nil end
    if e.kind == "conjure" then return not expCons, nil end
    if e.kind == "pet" then return not ExpOn("expPet"), nil end
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
            cdb.scrolls[e.scrollType] = on   -- ausdrückliche Wahl (pro Charakter)
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

-- Zahlenfeld einer Vorrats-Zeile: Übernehmen bei Enter/Fokusverlust (set begrenzt), ESC verwirft
function Cfg.MakeSupplyEdit(parent, e, letters, get, set)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(40, 20)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(letters)
    edit:SetJustifyH("CENTER")
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self.cancel = true; self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function(self)
        local n = not self.cancel and tonumber(self:GetText())
        self.cancel = nil
        -- entfernte eigene Items nicht mehr speichern
        if n and (e.kind == "reagent" or Supply.items[e.item] or e.supplyType ~= "item") then
            set(n)
            NoteDeferred()
            Evaluate()
            RefreshConfig()   -- kritische Grenze folgt einer kleineren Mindestmenge
        end
        self:SetText(tostring(get()))
    end)
    return edit
end

-- Vorrats-Zeile (Reagenzien, Munition, Seelensplitter, Tierfutter, eigene Items): Icon, Name,
-- Felder "Min." (Grenzen: Supply.Range), "Kritisch" (Supply.Critical) und "Auffüllen auf"
-- (Supply.Refill; nicht bei Tierfutter), Anzahl in den Taschen.
--   opts.check : Häkchen vorn (Tierfutter: eigener Schalter, cdb.buffs[e.key], Standard aus)
--   opts.remove: Knopf zum Entfernen (eigene Items)
-- list: Cfg.reagentRows (feste Zeilen) oder nil (eigene Items, Cfg.supplyItemRows)
function Cfg.MakeSupplyRow(parent, e, y, opts)
    local w = { entry = e, parent = parent, check = opts.check, removable = opts.remove }
    if opts.check then
        w.cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        w.cb:SetSize(24, 24)
        w.cb:SetScript("OnClick", function(self)
            cdb.buffs[e.key] = self:GetChecked() and true or false
            NoteDeferred()
            Evaluate()
        end)
    end
    w.icon = parent:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(20, 20)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    w.name:SetPoint("LEFT", w.icon, "RIGHT", 8, 0)
    w.name:SetWidth(opts.check and 98 or 120)
    w.name:SetJustifyH("LEFT")
    w.name:SetWordWrap(false)
    local _, hi = Supply.Range(e)
    w.edit = Cfg.MakeSupplyEdit(parent, e, #tostring(hi), function() return Supply.Threshold(e) end,
        function(n) Supply.SetThreshold(e, n) end)
    w.crit = Cfg.MakeSupplyEdit(parent, e, #tostring(hi), function() return Supply.Critical(e) end,
        function(n) Supply.SetCritical(e, n) end)
    if e.supplyType ~= "petfood" then
        w.refill = Cfg.MakeSupplyEdit(parent, e, #tostring(Restock.MAX_TARGET), function() return Supply.Refill(e) end,
            function(n) Supply.SetRefill(e, n) end)
    end
    w.status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.status:SetJustifyH("RIGHT")
    if opts.remove then
        w.remove = Cfg.MakeButton(parent, "x", 22)
        w.remove:SetScript("OnClick", function() Supply.RemoveItem(e.item) end)
        w.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.SUPPLY_REMOVE, 1, 1, 1)
            GameTooltip:Show()
        end)
        w.remove:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end
    Cfg.PlaceSupplyRow(w, y)
    if not opts.remove then Cfg.reagentRows[#Cfg.reagentRows + 1] = w end
    return w
end

-- Zeile an Höhe y setzen (eigene Items werden bei jeder Änderung der Liste neu angeordnet)
function Cfg.PlaceSupplyRow(w, y)
    local p = w.parent
    if w.cb then
        w.cb:ClearAllPoints()
        w.cb:SetPoint("TOPLEFT", 16, y)
    end
    w.icon:ClearAllPoints()
    w.icon:SetPoint("TOPLEFT", w.check and 44 or 22, y - 2)
    w.edit:ClearAllPoints()
    w.edit:SetPoint("TOPLEFT", Cfg.SUPPLY_MIN_X, y - 2)
    w.crit:ClearAllPoints()
    w.crit:SetPoint("TOPLEFT", Cfg.SUPPLY_CRIT_X, y - 2)
    if w.refill then
        w.refill:ClearAllPoints()
        w.refill:SetPoint("TOPLEFT", Cfg.SUPPLY_REFILL_X, y - 2)
    end
    w.status:ClearAllPoints()
    w.status:SetPoint("RIGHT", p, "TOPLEFT", w.removable and 396 or 424, y - 12)
    if w.remove then
        w.remove:ClearAllPoints()
        w.remove:SetPoint("TOPLEFT", 402, y - 1)
    end
end

function Cfg.ShowSupplyRow(w, show)
    for _, obj in ipairs({ w.cb or false, w.icon, w.name, w.edit, w.crit, w.refill or false, w.status, w.remove or false }) do
        if obj then
            if show then obj:Show() else obj:Hide() end
        end
    end
end

-- Zeile in RefreshConfig: Name, Icon, Mindestmenge, Anzahl bzw. Stummschaltung; ausgegraut, solange
-- der Schalter aus ist (Tierfutter: auch, solange sein Häkchen aus ist)
function Cfg.RefreshSupplyRow(w, expReag)
    local e = w.entry
    w.icon:SetTexture(EntryIcon(e))
    w.name:SetText(EntryLabel(e))
    if not w.edit:HasFocus() then w.edit:SetText(tostring(Supply.Threshold(e))) end
    if not w.crit:HasFocus() then w.crit:SetText(tostring(Supply.Critical(e))) end
    if w.refill then
        if not w.refill:HasFocus() then w.refill:SetText(tostring(Supply.Refill(e))) end
        Cfg.SetEditEnabled(w.refill, expReag and ExpOn("expRestock"))   -- nur mit "Auffüllen beim Händler"
    end
    local active = expReag
    if w.cb then
        w.cb:SetChecked(cdb.buffs[e.key] == true)
        if expReag then w.cb:Enable() else w.cb:Disable() end
        active = expReag and cdb.buffs[e.key] == true
    end
    local known = knownCache[e.key] ~= false
    local left = MuteRemaining(e.key)
    if not known then
        w.status:SetText(L.NOT_LEARNED)
    elseif left then
        w.status:SetText(L.MUTED:format(Cfg.FormatMute(left)))
    elseif e.supplyType == "ammo" and Supply.AmmoItem() == false then
        w.status:SetText(L.SUPPLY_NOAMMO)
    else
        local n = Supply.Count(e)
        w.status:SetText(n and L.IN_BAGS:format(n) or "")
    end
    local lit = known and active
    w.icon:SetDesaturated(not lit)
    if lit then w.name:SetTextColor(1, 1, 1) else w.name:SetTextColor(0.5, 0.5, 0.5) end
    if lit and left then
        w.status:SetTextColor(1, 0.4, 0.3)
    elseif lit then
        w.status:SetTextColor(0.6, 0.6, 0.6)
    else
        w.status:SetTextColor(0.5, 0.5, 0.5)
    end
    Cfg.SetEditEnabled(w.edit, expReag)
    Cfg.SetEditEnabled(w.crit, expReag)
    if w.remove then
        if expReag then w.remove:Enable() else w.remove:Disable() end
    end
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

---------------------------------------------------------------------------
-- Auswahllisten (Dropdowns) mit Beschriftung links. Vorlage: moderne Blizzard-Dropdowns
-- (WowStyle1DropdownTemplate mit SetupMenu), sonst UIDropDownMenuTemplate, sonst ein
-- Durchklick-Knopf; alles per pcall. spec:
--   label   : Text links
--   width   : Breite der Auswahl
--   options : function() -> { { value = v, text = "…" } | { title = "…" } (Trennzeile), ... }
--   get     : function() -> aktueller Wert (Markierung)
--   set     : function(value) – speichert und wendet an (RefreshConfig folgt automatisch)
--   text    : optional function() -> angezeigter Text (sonst Text der gewählten Option)
-- Cfg.SyncDropdown (aus RefreshConfig) setzt Text und Aktiv-Zustand.
---------------------------------------------------------------------------
Cfg.DROPDOWN_LABEL_W = 140
Cfg.dropdownCount = 0

function Cfg.MakeDropdown(parent, x, y, spec)
    local dd = { spec = spec }
    dd.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dd.label:SetPoint("TOPLEFT", x, y - 7)
    dd.label:SetWidth((spec.labelWidth or Cfg.DROPDOWN_LABEL_W) - 8)
    dd.label:SetJustifyH("LEFT")
    dd.label:SetWordWrap(false)
    dd.label:SetText(spec.label)
    local bx = x + (spec.labelWidth or Cfg.DROPDOWN_LABEL_W)
    local ok, f = false, nil
    if type(MenuUtil) == "table" then
        ok, f = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    end
    if ok and f and type(f.SetupMenu) == "function"
        and pcall(f.SetupMenu, f, function(_, root) Cfg.FillModernMenu(dd, root) end) then
        dd.kind, dd.frame = "modern", f
        f:SetPoint("TOPLEFT", bx, y)
        f:SetWidth(spec.width)
        Cfg.dropdownTemplate = Cfg.dropdownTemplate or "WowStyle1DropdownTemplate"
        return dd
    elseif ok and f then
        f:Hide()
    end
    Cfg.dropdownCount = Cfg.dropdownCount + 1
    ok, f = pcall(CreateFrame, "Frame", "BuffReminderDropdown" .. Cfg.dropdownCount, parent, "UIDropDownMenuTemplate")
    if ok and f and type(UIDropDownMenu_Initialize) == "function"
        and pcall(UIDropDownMenu_Initialize, f, function(_, level) Cfg.FillLegacyMenu(dd, level) end) then
        dd.kind, dd.frame = "legacy", f
        f:SetPoint("TOPLEFT", bx - 16, y + 2)   -- die Vorlage hat links 16 px Rand
        if type(UIDropDownMenu_SetWidth) == "function" then pcall(UIDropDownMenu_SetWidth, f, spec.width) end
        Cfg.dropdownTemplate = Cfg.dropdownTemplate or "UIDropDownMenuTemplate"
        return dd
    elseif ok and f then
        f:Hide()
    end
    dd.kind = "button"
    dd.frame = Cfg.MakeButton(parent, "", spec.width)
    dd.frame:SetPoint("TOPLEFT", bx, y)
    dd.frame:SetScript("OnClick", function() Cfg.CycleDropdown(dd) end)
    Cfg.dropdownTemplate = Cfg.dropdownTemplate or "UIPanelButtonTemplate"
    return dd
end

function Cfg.PickDropdown(dd, value)
    dd.spec.set(value)
    RefreshConfig()
end

function Cfg.FillModernMenu(dd, root)
    for _, o in ipairs(dd.spec.options()) do
        if o.title then
            if root.CreateDivider then root:CreateDivider() end
            if root.CreateTitle then root:CreateTitle(o.title) end
        else
            root:CreateRadio(o.text, function(v) return dd.spec.get() == v end,
                function(v) Cfg.PickDropdown(dd, v) end, o.value)
        end
    end
end

function Cfg.FillLegacyMenu(dd, level)
    if type(UIDropDownMenu_CreateInfo) ~= "function" or type(UIDropDownMenu_AddButton) ~= "function" then return end
    for _, o in ipairs(dd.spec.options()) do
        local info = UIDropDownMenu_CreateInfo()
        if o.title then
            info.text, info.isTitle, info.notCheckable = o.title, true, true
        else
            info.text, info.value = o.text, o.value
            info.checked = dd.spec.get() == o.value
            info.func = function(btn)
                Cfg.PickDropdown(dd, btn.value)
                if type(CloseDropDownMenus) == "function" then CloseDropDownMenus() end
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

-- Rückfall ohne Dropdown-Vorlage: nächste Option (Trennzeilen übersprungen)
function Cfg.CycleDropdown(dd)
    local list, cur, idx = {}, dd.spec.get(), 0
    for _, o in ipairs(dd.spec.options()) do
        if not o.title then list[#list + 1] = o.value end
    end
    if #list == 0 then return end
    for i, v in ipairs(list) do if v == cur then idx = i end end
    Cfg.PickDropdown(dd, list[idx % #list + 1])
end

-- Text der gewählten Option (sonst der Wert selbst)
function Cfg.DropdownText(dd)
    if dd.spec.text then return dd.spec.text() end
    local cur = dd.spec.get()
    for _, o in ipairs(dd.spec.options()) do
        if not o.title and o.value == cur then return o.text end
    end
    return tostring(cur)
end

-- Angezeigten Text und Aktiv-Zustand setzen (RefreshConfig)
function Cfg.SyncDropdown(dd, enabled)
    if not dd then return end
    local text, f = Cfg.DropdownText(dd), dd.frame
    if dd.kind == "modern" then
        if f.GenerateMenu then pcall(f.GenerateMenu, f) end
        if f.OverrideText then
            pcall(f.OverrideText, f, text)
        elseif f.Text and f.Text.SetText then
            f.Text:SetText(text)
        end
        if f.SetEnabled then pcall(f.SetEnabled, f, enabled) end
    elseif dd.kind == "legacy" then
        if type(UIDropDownMenu_SetText) == "function" then pcall(UIDropDownMenu_SetText, f, text) end
        local fn = enabled and UIDropDownMenu_EnableDropDown or UIDropDownMenu_DisableDropDown
        if type(fn) == "function" then pcall(fn, f) end
    else
        f:SetText(text)
        if enabled then f:Enable() else f:Disable() end
    end
    if enabled then dd.label:SetTextColor(1, 1, 1) else dd.label:SetTextColor(0.5, 0.5, 0.5) end
end

-- Cfg.configCanvas: Seite unter "Pardona's Addons" in den Einstellungen (nil = eigenes Fenster)

---------------------------------------------------------------------------
-- Einstellungsseite mit Tabs: Tab-Leiste oben, je Tab eine eigene Scrollfläche.
--   Cfg.TAB_ORDER: { Key, Text-Schlüssel }; "group" nur bei Klassen mit Gruppenbuffs; "pet" wird
--   immer gebaut, ist aber nur für Jäger/Hexenmeister und im Demo-Modus sichtbar (Cfg.TabShown)
--   Cfg.tabs[key] = { key, button, scroll, content }; Cfg.tabList in Reihenfolge
--   db.cfgTab: zuletzt gewählter Tab (beim Öffnen wieder gezeigt)
-- Tab-Vorlage: erste, die der Client kennt (Cfg.TAB_TEMPLATES, per pcall); sonst normale Knöpfe
-- (gewählter Tab = gesperrt). Funktion und Speicherung der Einstellungen sind unabhängig davon.
---------------------------------------------------------------------------
Cfg.TAB_ORDER = {
    { "display", "TAB_DISPLAY" }, { "class", "TAB_CLASS" }, { "pet", "TAB_PET" }, { "other", "TAB_OTHER" },
    { "supplies", "TAB_SUPPLIES" }, { "group", "TAB_GROUP" },
}

-- Tab sichtbar? Reiter "Tier" nur für Jäger/Hexenmeister, im Demo-Modus/Screenshot-Lauf immer
function Cfg.TabShown(key)
    if key == "pet" then return Pet.HasClass() or Demo.active == true or Demo.run ~= nil end
    return true
end

-- sichtbare Tabs in Reihenfolge
function Cfg.ShownTabs()
    local list = {}
    for _, t in ipairs(Cfg.tabList) do
        if Cfg.TabShown(t.key) then list[#list + 1] = t end
    end
    return list
end

-- Tab-Knöpfe der sichtbaren Tabs nebeneinander auf die Oberkante des Kastens setzen, Breiten
-- anpassen und den gemerkten Tab zeigen (Aufbau, Demo an/aus)
function Cfg.UpdateTabs()
    if not config then return end
    local real = Cfg.tabTemplate ~= "UIPanelButtonTemplate"
    local prev
    for _, t in ipairs(Cfg.tabList) do
        t.button:ClearAllPoints()
        if Cfg.TabShown(t.key) then
            if prev then
                t.button:SetPoint("LEFT", prev.button, "RIGHT", Cfg.TAB_GAP, 0)
            else
                t.button:SetPoint("BOTTOMLEFT", Cfg.inset, "TOPLEFT", Cfg.TAB_X, real and -2 or 2)
            end
            t.button:Show()
            prev = t
        else
            t.button:Hide()
            t.scroll:Hide()
        end
    end
    Cfg.FitTabs()
    Cfg.SelectTab(db.cfgTab)
end

-- Gibt es den Tab-Key (Cfg.TAB_ORDER)? Ungültige gemerkte Werte setzt ADDON_LOADED auf "display"
function Cfg.ValidTab(key)
    for _, t in ipairs(Cfg.TAB_ORDER) do
        if t[1] == key then return true end
    end
    return false
end
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
    local list, inset = Cfg.ShownTabs(), Cfg.inset
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

-- Fußzeile "(beta) = experimentell …" unten in Tabs mit Beta-Funktionen (Tier, Gruppe); Rückgabe: neues y
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
    State.unlocked = on and true or false
    if not State.unlocked then wipe(shownKeys); Display.ShowRows({}) end
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
    if not Cfg.tabs[key] or not Cfg.TabShown(key) then key = Cfg.tabList[1] and Cfg.tabList[1].key end
    if not key then return end
    db.cfgTab = key
    local real = Cfg.tabTemplate ~= "UIPanelButtonTemplate"
    for _, t in ipairs(Cfg.ShownTabs()) do
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

-- Tab "Anzeige": Knopfreihe, Grundeinstellungen, Stil, Ton, Taste, Warnung vor Ablauf
function Cfg.BuildDisplayTab()
    local p = Cfg.NewTab("display", "TAB_DISPLAY")
    local y = -8
    config.moveBtn = Cfg.MakeButton(p, L.MOVE, 100)
    config.moveBtn:SetPoint("TOPLEFT", 16, y)
    config.moveBtn:SetScript("OnClick", function() Cfg.SetMoveMode(not State.unlocked) end)
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
    config.styleDD = Cfg.MakeDropdown(p, 20, y, {
        label = L.STYLE_LABEL, width = 130,
        options = function()
            local list = {}
            for _, k in ipairs(Style.STYLE_ORDER) do
                list[#list + 1] = { value = k, text = Cfg.ValueText("STYLE_NAME_", k) }
            end
            return list
        end,
        get = function() return db.style end,
        set = function(v)
            db.style = v
            NoteDeferred()
            Display.ApplyStyle()
            Evaluate()
        end,
    })
    config.iconsCB = Cfg.MakeCheck(p, L.ICONS_ONLY, 300, y - 1, function(self)
        db.iconsOnly = self:GetChecked() and true or false
        NoteDeferred()
        Display.ApplyStyle()
        Evaluate()
    end)
    y = y - 32

    -- Wachstumsrichtung: neue Warnungen unterhalb (Standard) oder oberhalb des Ankers
    config.growDD = Cfg.MakeDropdown(p, 20, y, {
        label = L.GROW_LABEL, width = 130,
        options = function()
            return { { value = "down", text = L.GROW_DOWN }, { value = "up", text = L.GROW_UP } }
        end,
        get = function() return db.growUp and "up" or "down" end,
        set = function(v)
            db.growUp = v == "up"
            NoteDeferred()
            Display.ApplyStyle()   -- ordnet die Zeilen neu an (im Kampf erst danach)
            Evaluate()
        end,
    })
    y = y - 32

    -- Ton bei neuer Warnung; Auswahl spielt ihn einmal zur Probe
    config.soundDD = Cfg.MakeDropdown(p, 20, y, {
        label = L.SOUND_LABEL, width = 180,
        options = Sound.Options,
        get = function() return db.sound end,
        set = function(v)
            db.sound = v
            PlayAlertSound()   -- Vorhören
        end,
        text = function() return Sound.Label(db.sound) end,
    })
    y = y - 38

    -- Größe und Deckkraft der Warnliste (im Kampf erst danach; Menüs bleiben unverändert)
    config.scaleSlider = Cfg.MakeSlider(p, "BuffReminderScale", 24, y, 50, 200, 5, function(v)
        Display.SetScale(v / 100)
        NoteDeferred()
        ApplyLayout()
        RefreshConfig()
    end)
    y = y - 26
    config.alphaSlider = Cfg.MakeSlider(p, "BuffReminderAlpha", 24, y, 30, 100, 5, function(v)
        db.alpha = v / 100
        NoteDeferred()
        ApplyLayout()
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
    y = y - 26

    -- Warnung vor Ablauf + Detail-Regler (Schwelle, Transparenz)
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
        Display.ApplyRowAlpha()   -- sichtbare Ablauf-Zeilen sofort
        Evaluate()
        RefreshConfig()
    end)
    y = y - 24
    Cfg.FinishTab(p, y)
end

-- Tab "Klassenbuffs": Liste (mit Talent-Hinweisen) + Variantenmenü. Alles unter der Liste
-- liegt in config.below, das Cfg.LayoutClassRows unter die sichtbaren Klassenzeilen rückt.
function Cfg.BuildClassTab()
    local p = Cfg.NewTab("class", "TAB_CLASS")
    Cfg.classContent = p
    local y = -8
    Cfg.MakeHeader(p, L.CLASS_SECTION:format(UnitClass("player") or "?"), y)
    y = y - 22
    if #State.classEntries == 0 then
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", 20, y)
        fs:SetText(L.NO_CLASS)
        y = y - 20
    end
    Cfg.classTop = y
    for _, e in ipairs(State.classEntries) do
        Cfg.MakeEntryRow(p, e, y).classRow = true
    end
    local b = CreateFrame("Frame", nil, p)
    config.below = b
    local by = -8
    -- Variantenmenü per Rechtsklick (Aura, Siegel, Aspekt, Rüstung, Schild, Waffenverzauberung)
    config.expVariantCB = Cfg.MakeCheck(b, L.EXP_VARIANTMENU, 16, by, function(self)
        db.expVariantMenu = self:GetChecked() and true or false
        if menu:IsShown() then menu:Hide() end   -- nächstes Öffnen mit/ohne Varianten
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    by = by - 24
    Cfg.belowHeight = -by + 10
end

-- Tab "Tier" (Jäger/Hexenmeister; im Demo-Modus für alle sichtbar): Beta-Schalter, darunter die
-- Einzelschalter der eigenen Klasse (eingeklappt, solange der Schalter aus ist)
function Cfg.BuildPetTab()
    Cfg.NewTab("pet", "TAB_PET")
    local f = Cfg.NewSection("pet", 24)
    config.expPetCB = Cfg.MakeBetaCheck(f, L.EXP_PET, 16, 0, function(self)
        db.expPet = self:GetChecked() and true or false
        if menu:IsShown() then menu:Hide() end   -- nächstes Öffnen mit/ohne Tier-Auswahl
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    local function on() return ExpOn("expPet") end
    if #Pet.entries == 0 then
        f = Cfg.NewSection("pet", 20)
        local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 44, -2)
        note:SetText(L.PET_CLASS_ONLY)
    end
    for _, e in ipairs(Pet.entries) do
        f = Cfg.NewSection("pet", 26, on)
        Cfg.MakeEntryRow(f, e, 0)
        if e.petType == "feed" then
            -- Füttern: nur bei "unglücklich"; Warnung, wenn kein passendes Futter dabei ist
            f = Cfg.NewSection("pet", 48, on)
            config.petUnhappyCB = Cfg.MakeCheck(f, L.PET_UNHAPPY_ONLY, 44, 0, function(self)
                cdb.petUnhappyOnly = self:GetChecked() and true or false
                NoteDeferred()
                Evaluate()
            end)
            config.petNoFoodCB = Cfg.MakeCheck(f, L.PET_NOFOOD_WARN, 44, -24, function(self)
                cdb.petNoFoodWarn = self:GetChecked() and true or false
                NoteDeferred()
                Evaluate()
            end)
        elseif e.petType == "demon" then
            -- Dämon des Linksklicks (wie Rechtsklick auf die Warnung); "automatisch" = zuletzt beschworen
            f = Cfg.NewSection("pet", 34, on)
            config.demonDD = Cfg.MakeDropdown(f, 44, -2, {
                label = L.PET_DEMON_LABEL, width = 180, labelWidth = 116,
                options = Pet.DemonOptions,
                get = function() return Pet.IsDemon(cdb.demon) and cdb.demon or "auto" end,
                set = function(v)
                    cdb.demon = Pet.IsDemon(v) and v or nil
                    NoteDeferred()
                    Evaluate()
                end,
                text = Pet.DemonText,
            })
        end
    end
    Cfg.FooterSection("pet")
    Cfg.LayoutTab("pet")
end

-- Tab "Tier" in RefreshConfig: Schalter und Detail-Einstellungen
function Cfg.RefreshPet()
    if not config.expPetCB then return end
    local on = ExpOn("expPet")
    config.expPetCB:SetChecked(on)
    if config.petUnhappyCB then
        config.petUnhappyCB:SetChecked(cdb.petUnhappyOnly == true)
        config.petNoFoodCB:SetChecked(cdb.petNoFoodWarn ~= false)
    end
    if config.demonDD then Cfg.SyncDropdown(config.demonDD, on) end
    Cfg.LayoutTab("pet")
end

-- Abschnitte der Tabs "Weitere Buffs" und "Vorräte": je Abschnitt ein eigener Frame (Kinder mit
-- Koordinaten relativ zum Abschnitt, y = 0 oben). Cfg.LayoutTab ordnet die sichtbaren Abschnitte
-- untereinander an (einheitlicher Abstand Cfg.SECTION_GAP); Listen unter einem Schalter
-- (Elixiere, Rollen, Reagenzien) sind eingeklappt, solange der Schalter aus ist (visible()).
Cfg.sections = {}      -- Tab-Key -> { { frame, visible = function | nil }, ... }
Cfg.SECTION_GAP = 6

function Cfg.NewSection(tabKey, height, visible)
    local f = CreateFrame("Frame", nil, Cfg.tabs[tabKey].content)
    f:SetSize(Cfg.WIDTH, height)
    local list = Cfg.sections[tabKey]
    if not list then
        list = {}
        Cfg.sections[tabKey] = list
    end
    list[#list + 1] = { frame = f, visible = visible }
    return f
end

function Cfg.LayoutTab(tabKey)
    local t, list = Cfg.tabs[tabKey], Cfg.sections[tabKey]
    if not (t and list) then return end
    local y = -8
    for _, s in ipairs(list) do
        if s.visible == nil or s.visible() then
            s.frame:ClearAllPoints()
            s.frame:SetPoint("TOPLEFT", t.content, "TOPLEFT", 0, y)
            s.frame:Show()
            y = y - s.frame:GetHeight() - Cfg.SECTION_GAP
        else
            s.frame:Hide()
        end
    end
    Cfg.FinishTab(t.content, y)
end

-- Fußzeile "(beta) = …" als letzter Abschnitt eines Tabs
function Cfg.FooterSection(tabKey)
    Cfg.AddFooter(Cfg.NewSection(tabKey, 30), 10)
end

-- Rollen-Art als Zelle der zweispaltigen Liste (col 1/2, row 1-3): Haken, Icon, Name, Anzahl.
-- Der Name wird bei Platzmangel gekürzt; der volle Name steht im Tooltip. Zeile in
-- Cfg.configRows, damit RefreshConfig Haken, Icon, Name und Anzahl setzt.
Cfg.SCROLL_COL_X, Cfg.SCROLL_COL_W, Cfg.SCROLL_ROW_H = { 16, 228 }, 204, 24

function Cfg.MakeScrollCell(parent, e, col, row)
    local x, y = Cfg.SCROLL_COL_X[col], -(row - 1) * Cfg.SCROLL_ROW_H
    local w = { entry = e, parent = parent }
    w.cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    w.cb:SetSize(24, 24)
    w.cb:SetPoint("TOPLEFT", x, y)
    w.cb:SetScript("OnClick", function(self)
        cdb.scrolls[e.scrollType] = self:GetChecked() and true or false   -- ausdrückliche Wahl
        NoteDeferred()
        Evaluate()
    end)
    w.icon = parent:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(18, 18)
    w.icon:SetPoint("LEFT", w.cb, "RIGHT", 2, 0)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.status:SetPoint("RIGHT", parent, "TOPLEFT", x + Cfg.SCROLL_COL_W, y - 12)
    w.status:SetJustifyH("RIGHT")
    w.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.name:SetPoint("LEFT", w.icon, "RIGHT", 6, 0)
    w.name:SetPoint("RIGHT", w.status, "LEFT", -6, 0)
    w.name:SetJustifyH("LEFT")
    w.name:SetWordWrap(false)
    -- Tooltip mit dem vollen Namen über Icon und Name
    w.hover = CreateFrame("Frame", nil, parent)
    w.hover:SetPoint("TOPLEFT", w.icon, "TOPLEFT")
    w.hover:SetPoint("BOTTOMRIGHT", w.name, "BOTTOMRIGHT")
    w.hover:EnableMouse(true)
    w.hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(w.name:GetText() or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    w.hover:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    Cfg.configRows[#Cfg.configRows + 1] = w
    return w
end

-- Tab "Weitere Buffs" (Buffs aktiv halten): allgemeine Buffs, "Nur in Instanzen" mit Hinweis,
-- Steine/Öle/Gifte, Elixiere mit Liste, Rollen mit Liste, Verfolgung
function Cfg.BuildOtherTab()
    Cfg.NewTab("other", "TAB_OTHER")
    local f = Cfg.NewSection("other", 26 * #GENERAL_BUFFS)
    for i, e in ipairs(GENERAL_BUFFS) do
        Cfg.MakeEntryRow(f, e, -(i - 1) * 26)
    end

    -- "Weitere Buffs nur in Instanzen" + Satz darunter, wofür es gilt
    f = Cfg.NewSection("other", 40)
    config.instCB = Cfg.MakeCheck(f, L.INSTANCE_ONLY, 16, 0, function(self)
        db.instanceOnly = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
    end)
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 44, -24)
    note:SetWidth(Cfg.WIDTH - 60)
    note:SetJustifyH("LEFT")
    note:SetText(L.INSTANCE_ONLY_NOTE)

    -- Steine, Öle, Gifte per Klick
    f = Cfg.NewSection("other", 24)
    config.expWeaponCB = Cfg.MakeCheck(f, L.EXP_WEAPONITEMS, 16, 0, function(self)
        db.expWeaponItems = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)

    -- Wunsch-Elixiere: Schalter + Liste aller bekannten Elixiere (Taschen + Merkliste); die Liste
    -- wächst, wenn neue Elixiere in die Taschen kommen (Cfg.LayoutElixirs)
    f = Cfg.NewSection("other", 24)
    config.expElixirCB = Cfg.MakeCheck(f, L.EXP_ELIXIRS, 16, 0, function(self)
        db.expElixirs = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    Cfg.elixirSection = Cfg.NewSection("other", 20, function() return ExpOn("expElixirs") end)
    Cfg.elixirRows = {}
    config.elixirEmpty = Cfg.elixirSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    config.elixirEmpty:SetText(L.ELIXIRS_EMPTY)

    -- Rollen: Schalter + sechs Arten in zwei Spalten (Vorgabe pro Klasse; neutraler Name der Art)
    f = Cfg.NewSection("other", 24)
    config.expScrollCB = Cfg.MakeCheck(f, L.EXP_SCROLLS, 16, 0, function(self)
        db.expScrolls = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    f = Cfg.NewSection("other", 3 * Cfg.SCROLL_ROW_H, function() return ExpOn("expScrolls") end)
    for i, t in ipairs(Scroll.ORDER) do
        Cfg.MakeScrollCell(f, Scroll.entries[t], i <= 3 and 1 or 2, (i - 1) % 3 + 1)
    end

    -- Verfolgungs-Erinnerung: Schalter + Häkchen je Verfolgung in zwei Spalten, Gruppen
    -- "Fähigkeiten" und "Minimap" (Cfg.LayoutTracking; eingeklappt, solange der Schalter aus ist)
    f = Cfg.NewSection("other", 24)
    config.expTrackCB = Cfg.MakeCheck(f, L.EXP_TRACKING, 16, 0, function(self)
        db.expTracking = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    Cfg.trackSection = Cfg.NewSection("other", 20, function() return ExpOn("expTracking") end)
    Cfg.trackCells, Cfg.trackHeads = {}, {}
    config.trackEmpty = Cfg.trackSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    config.trackEmpty:SetPoint("TOPLEFT", 44, -2)
    config.trackEmpty:SetText(L.TRACK_EMPTY)
    Cfg.LayoutElixirs()   -- ordnet auch den Tab an
end

-- Zelle der Verfolgungsliste (Haken, Icon, Name; voller Name im Tooltip), Inhalt per
-- Cfg.PlaceTrackCell
function Cfg.MakeTrackCell(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(Cfg.SCROLL_COL_W, Cfg.SCROLL_ROW_H)
    w.cb = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
    w.cb:SetSize(24, 24)
    w.cb:SetPoint("TOPLEFT", 0, 0)
    w.cb:SetScript("OnClick", function(self)
        Tracking.SetWanted(w.key, self:GetChecked())
        RefreshKnown()
        NoteDeferred()
        Evaluate()
    end)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(18, 18)
    w.icon:SetPoint("LEFT", w.cb, "RIGHT", 2, 0)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.name = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.name:SetPoint("LEFT", w.icon, "RIGHT", 6, 0)
    w.name:SetPoint("RIGHT", w, "RIGHT", -4, 0)
    w.name:SetJustifyH("LEFT")
    w.name:SetWordWrap(false)
    w.hover = CreateFrame("Frame", nil, w)
    w.hover:SetPoint("TOPLEFT", w.icon, "TOPLEFT")
    w.hover:SetPoint("BOTTOMRIGHT", w.name, "BOTTOMRIGHT")
    w.hover:EnableMouse(true)
    w.hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(w.name:GetText() or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    w.hover:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return w
end

function Cfg.PlaceTrackCell(w, it, x, y)
    w.key = it.key
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", x, y)
    w.cb:SetChecked(Tracking.Wanted(it.key))
    w.icon:SetTexture(it.tex or FALLBACK_ICON)
    w.name:SetText(it.name or it.key)
    w:Show()
end

-- Verfolgungsliste neu aufbauen (beim Öffnen des Reiters und bei Änderungen der Liste, über
-- RefreshConfig): je Gruppe eine Überschrift und die Zellen spaltenweise in zwei Spalten
function Cfg.LayoutTracking()
    local f = Cfg.trackSection
    if not f then return end
    local abilities, minimap = Tracking.Options()
    local used, y = 0, 0
    for g, items in ipairs({ abilities, minimap }) do
        local head = Cfg.trackHeads[g]
        if not head then
            head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            head:SetText(g == 1 and L.TRACK_ABILITIES or L.TRACK_MINIMAP)
            Cfg.trackHeads[g] = head
        end
        if #items > 0 then
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 20, y - 2)
            head:Show()
            y = y - 18
            local perCol = math.ceil(#items / 2)
            for i, it in ipairs(items) do
                used = used + 1
                local w = Cfg.trackCells[used] or Cfg.MakeTrackCell(f)
                Cfg.trackCells[used] = w
                local col, row = (i <= perCol) and 1 or 2, (i <= perCol) and i or i - perCol
                Cfg.PlaceTrackCell(w, it, Cfg.SCROLL_COL_X[col], y - (row - 1) * Cfg.SCROLL_ROW_H)
            end
            y = y - perCol * Cfg.SCROLL_ROW_H - 4
        else
            head:Hide()
        end
    end
    for i = used + 1, #Cfg.trackCells do Cfg.trackCells[i]:Hide() end
    if used == 0 then
        config.trackEmpty:Show()
        y = -18
    else
        config.trackEmpty:Hide()
    end
    f:SetHeight(-y)
end

-- Elixier-Liste (nach Name) im eigenen Abschnitt anordnen; Abschnittshöhe und Tab folgen
function Cfg.LayoutElixirs()
    local f = Cfg.elixirSection
    if not f then return end
    local y = 0
    local list = Elixir.List()
    for _, e in ipairs(list) do
        local w = Cfg.elixirRows[e.key]
        if not w then
            w = Cfg.MakeEntryRow(f, e, y)
            Cfg.elixirRows[e.key] = w
        end
        Cfg.PlaceEntryRow(w, y)
        y = y - 26
    end
    if #list == 0 then
        config.elixirEmpty:ClearAllPoints()
        config.elixirEmpty:SetPoint("TOPLEFT", 44, y - 2)
        config.elixirEmpty:Show()
        y = y - 18
    else
        config.elixirEmpty:Hide()
    end
    f:SetHeight(-y)
    Elixir.dirty = false
    Cfg.LayoutTab("other")
end

-- Tab "Vorräte" (genug dabeihaben): Klassen-Verbrauchsgüter, Reagenzien-Warnung mit Liste,
-- Hinweis auf spätere Erweiterungen
function Cfg.BuildSuppliesTab()
    Cfg.NewTab("supplies", "TAB_SUPPLIES")
    -- Klassen-Verbrauchsgüter (Einträge stehen in der Klassenliste); Schwelle für gezaubertes
    -- Essen/Wasser nur bei Klassen mit solchen Einträgen (Magier; bleibt ausgegraut sichtbar)
    local hasConjureSum = false
    for _, e in ipairs(State.classEntries) do
        if e.kind == "conjure" and e.conj.mode == "sum" then hasConjureSum = true end
    end
    local f = Cfg.NewSection("supplies", hasConjureSum and 52 or 24)
    config.expConsCB = Cfg.MakeCheck(f, L.EXP_CONSUMABLES, 16, 0, function(self)
        db.expConsumables = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        RefreshConfig()
    end)
    if hasConjureSum then
        config.conjureSlider = Cfg.MakeSlider(f, "BuffReminderConjureThreshold", 40, -30, 0, 60, 1, function(v)
            db.conjureThreshold = v
            NoteDeferred()
            Evaluate()
            RefreshConfig()
        end)
    end

    -- Vorratswarnung (intern weiter expReagents): gemeinsame Liste aus Reagenzien der Klasse,
    -- Munition, Seelensplitter und Tierfutter; darunter eigene Items mit Feld "Item hinzufügen".
    -- Beides eingeklappt, solange der Schalter aus ist.
    f = Cfg.NewSection("supplies", 102)
    config.expReagCB = Cfg.MakeCheck(f, L.EXP_SUPPLIES, 16, 0, function(self)
        db.expReagents = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()
        Restock.Refresh()
        RefreshConfig()
    end)
    -- Auffüllen beim Händler (eigener Schalter; nur wirksam mit der Vorratswarnung)
    config.restockCB = Cfg.MakeCheck(f, L.EXP_RESTOCK, 40, -24, function(self)
        db.expRestock = self:GetChecked() and true or false
        NoteDeferred()
        Evaluate()   -- Hinweis der Vorratszeilen beim Händler
        Restock.Refresh()
        RefreshConfig()
    end)
    -- Auch oberhalb der Mindestmenge auffüllen (account-weit, Standard aus): angeboten wird dann
    -- alles unter "Auffüllen auf" statt nur unter Min.
    config.restockAboveCB = Cfg.MakeCheck(f, L.RESTOCK_ABOVE, 64, -48, function(self)
        db.restockAbove = self:GetChecked() and true or false
        Restock.Refresh()
        RefreshConfig()
    end)
    config.restockAboveCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.RESTOCK_ABOVE, 1, 1, 1)
        GameTooltip:AddLine(L.RESTOCK_ABOVE_TIP, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    config.restockAboveCB:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    -- Hinweis: Linksklick auf eine Vorratswarnung = bis zur nächsten Stadt zurückstellen
    local snoozeNote = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    snoozeNote:SetPoint("TOPLEFT", 44, -76)
    snoozeNote:SetWidth(Cfg.WIDTH - 60)
    snoozeNote:SetJustifyH("LEFT")
    snoozeNote:SetText(L.SUPPLY_SNOOZE_NOTE)
    local function on() return ExpOn("expReagents") end
    local fixed = #reagentEntries + #Supply.classEntries
    f = Cfg.NewSection("supplies", 18 + 26 * fixed, on)
    -- Spaltenköpfe über den Feldern "Min.", "Kritisch" (0 = aus) und "Auffüllen auf"
    config.supplyCols = {}
    for i, spec in ipairs({ { Cfg.SUPPLY_MIN_X, L.SUPPLY_COL_MIN }, { Cfg.SUPPLY_CRIT_X, L.SUPPLY_COL_CRIT },
        { Cfg.SUPPLY_REFILL_X, L.SUPPLY_COL_REFILL } }) do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOP", f, "TOPLEFT", spec[1] + 17, -2)
        fs:SetText(spec[2])
        config.supplyCols[i] = fs
    end
    local y = -18
    for _, e in ipairs(reagentEntries) do
        Cfg.MakeSupplyRow(f, e, y, {})
        y = y - 26
    end
    for _, e in ipairs(Supply.classEntries) do
        Cfg.MakeSupplyRow(f, e, y, { check = e.supplyType == "petfood" })
        y = y - 26
    end

    -- eigene Items (Liste nach Name; Cfg.LayoutSupplies ordnet sie samt Eingabefeld an)
    f = Cfg.NewSection("supplies", 80, on)
    Cfg.supplySection = f
    local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", 22, 0)
    head:SetText(L.SUPPLY_OWN)
    config.supplyEmpty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    config.supplyEmpty:SetText(L.SUPPLY_EMPTY)
    config.supplyAddLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    config.supplyAddLabel:SetText(L.SUPPLY_ADD)
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize(150, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    -- Enter: Item-ID oder Item-Link aus dem Feld übernehmen; Esc: Feld verlassen
    box:SetScript("OnEnterPressed", function(self)
        local text = self:GetText() or ""
        local id = tonumber(text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
        if id then Supply.AddItem(id) end
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    -- Item auf das Feld ziehen
    box:SetScript("OnReceiveDrag", Supply.OnDrop)
    box:SetScript("OnMouseUp", Supply.OnDrop)
    Supply.addBox = box
    Supply.HookLinks()   -- Shift-Klick auf Items (nur wirksam, solange das Feld den Fokus hat)
    config.supplyAddHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    config.supplyAddHint:SetWidth(Cfg.WIDTH - 60)
    config.supplyAddHint:SetJustifyH("LEFT")
    config.supplyAddHint:SetText(L.SUPPLY_ADD_HINT:format(Supply.MAX_ITEMS))
    config.supplyMax = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    config.supplyMax:SetTextColor(1, 0.4, 0.3)
    config.supplyMax:SetText(L.SUPPLY_MAX:format(Supply.MAX_ITEMS))

    -- Hinweis: gezählt werden nur die Taschen
    f = Cfg.NewSection("supplies", 22, on)
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 22, -4)
    note:SetWidth(Cfg.WIDTH - 40)
    note:SetJustifyH("LEFT")
    note:SetText(L.SUPPLY_BAGS_ONLY)
    Cfg.LayoutSupplies()
    Cfg.LayoutTab("supplies")
end

-- Eigene Vorrats-Items (nach Name) im eigenen Abschnitt anordnen, darunter das Feld "Item
-- hinzufügen" mit Hinweis; Abschnittshöhe und Tab folgen
function Cfg.LayoutSupplies()
    local f = Cfg.supplySection
    if not f then return end
    local y = -18
    local list = Supply.List()
    local shown = {}
    for _, e in ipairs(list) do
        local w = Cfg.supplyItemRows[e.item]
        if not w then
            w = Cfg.MakeSupplyRow(f, e, y, { remove = true })
            Cfg.supplyItemRows[e.item] = w
        end
        w.entry = e
        Cfg.PlaceSupplyRow(w, y)
        Cfg.ShowSupplyRow(w, true)
        shown[e.item] = true
        y = y - 26
    end
    for id, w in pairs(Cfg.supplyItemRows) do
        if not shown[id] then Cfg.ShowSupplyRow(w, false) end
    end
    if #list == 0 then
        config.supplyEmpty:ClearAllPoints()
        config.supplyEmpty:SetPoint("TOPLEFT", 44, y - 2)
        config.supplyEmpty:Show()
        y = y - 18
    else
        config.supplyEmpty:Hide()
    end
    y = y - 4
    config.supplyAddLabel:ClearAllPoints()
    config.supplyAddLabel:SetPoint("TOPLEFT", 22, y - 5)
    Supply.addBox:ClearAllPoints()
    Supply.addBox:SetPoint("TOPLEFT", 140, y)
    config.supplyMax:ClearAllPoints()
    config.supplyMax:SetPoint("LEFT", Supply.addBox, "RIGHT", 8, 0)
    y = y - 24
    config.supplyAddHint:ClearAllPoints()
    config.supplyAddHint:SetPoint("TOPLEFT", 22, y)
    y = y - 16
    f:SetHeight(-y)
    Supply.dirty = false
    Cfg.LayoutTab("supplies")
end

-- Anzahl der Rollen einer Art in den Taschen
function Cfg.ScrollCount(e)
    return Scroll.Count(e)
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
    config.groupModeDD = Cfg.MakeDropdown(p, 44, y, {
        label = L.GROUP_MODE_LABEL, width = 180, labelWidth = 116,
        options = function()
            local list = {}
            for _, k in ipairs(GROUP_MODE_ORDER) do
                list[#list + 1] = { value = k, text = Cfg.ValueText("GROUP_MODE_", k) }
            end
            return list
        end,
        get = function() return db.groupMode end,
        set = function(v)
            db.groupMode = v
            Group.MarkGroupDirty()
            NoteDeferred()
            Evaluate()
        end,
    })
    y = y - 34
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
    State.config = config   -- für Pardona.lua und Demo.lua (dort State.config)

    local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.TITLE)

    -- Inhaltskasten über die volle Breite bis unten; darüber die Tab-Leiste
    Cfg.inset = Cfg.MakeInset(config)
    Cfg.inset:SetPoint("TOPLEFT", config, "TOPLEFT", 8, -74)
    Cfg.inset:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -8, 6)

    Cfg.BuildDisplayTab()
    Cfg.BuildClassTab()
    Cfg.BuildPetTab()
    Cfg.BuildOtherTab()
    Cfg.BuildSuppliesTab()
    -- Tab "Gruppe" nur für Klassen mit Gruppen-Buffs
    local hasGroup, hasBlessings = false, false
    for _, e in ipairs(State.classEntries) do
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
    Cfg.UpdateTabs()   -- sichtbare Tabs anordnen, Breiten anpassen, gemerkten Tab zeigen
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

-- Für andere Dateien (ns)
ns.BuildConfig = BuildConfig
ns.ToggleConfig = ToggleConfig
ns.RefreshConfig = RefreshConfig
