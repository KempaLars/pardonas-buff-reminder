-- Pardona's Buff Reminder – Einblendung: Anker und Warnzeilen (Secure Buttons), Layout, Klicks auf Warnungen.
-- Abhängigkeiten (beim Laden): Core.lua, Items.lua, Detect.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Eat = ns.Eat
local Group = ns.Group
local Style = ns.Style
local Display = ns.Display
local Expiry = ns.Expiry
local Conjure = ns.Conjure
local Keybind = ns.Keybind
local Variant = ns.Variant
local Tracking = ns.Tracking
local Demo = ns.Demo
local Pet = ns.Pet
local Supply = ns.Supply
local SpellIcon = ns.SpellIcon
-- aus Items.lua
local ItemName = ns.ItemName
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local EntryIcon = ns.EntryIcon
local SpellKnown = ns.SpellKnown
local CastSpellFor = ns.CastSpellFor
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

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

-- Größe und Deckkraft der Warnliste (Einstellungen, db.scale/db.alpha). Display.neutral (Demo und
-- Screenshot-Lauf): 100 % / 100 %, die Werte des Spielers bleiben gespeichert.
-- db.point wird in Einheiten von db.scale gespeichert; bei anderer wirksamer Größe rechnet
-- ApplyLayout die Abstände um, damit der Ankerpunkt auf dem Bildschirm bleibt.
function Display.SavedScale()
    local s = tonumber(db and db.scale) or 1
    return math.max(0.5, math.min(2, s))
end

function Display.Scale()
    if Display.neutral then return 1 end
    return Display.SavedScale()
end

function Display.Alpha()
    if Display.neutral then return 1 end
    local a = tonumber(db and db.alpha) or 1
    return math.max(0.3, math.min(1, a))
end

-- Neue Größe speichern; Abstände des Ankerpunkts so umrechnen, dass er an seiner Bildschirm-
-- position bleibt (wirksam über ApplyLayout, im Kampf danach)
function Display.SetScale(s)
    local old = Display.SavedScale()
    db.scale = math.max(0.5, math.min(2, s))
    local p, k = db.point, old / db.scale
    if type(p) == "table" and type(p[4]) == "number" and type(p[5]) == "number" then
        p[4], p[5] = p[4] * k, p[5] * k
    end
end

function Display.SavePoint()
    anchor:StopMovingOrSizing()
    local p, _, rp, x, y = anchor:GetPoint()
    local k = Display.Scale() / Display.SavedScale()   -- in Einheiten von db.scale
    db.point = { p, "UIParent", rp, (x or 0) * k, (y or 0) * k }
end

State.layoutPending = false   -- ApplyLayout im Kampf aufgeschoben (Evaluate holt es nach)

-- Position, Größe und Deckkraft der Warnliste; im Kampf erst danach (geschützte Zeilen)
-- Strata der Warnliste: normal HIGH. Im Demo-Modus (ohne Screenshot-Lauf) MEDIUM, damit das
-- Einstellungsfenster (Blizzard-Einstellungen HIGH, eigenes Fenster DIALOG) immer darüber liegt:
-- Bei gleicher Strata HIGH entscheidet sonst die Frame-Ebene, und die Beispielzeilen in der
-- Bildschirmmitte konnten das Fenster überdecken. Der Screenshot-Lauf nutzt HIGH (Demo.BeginRun).
function Display.Strata()
    if Demo.active and not Demo.run then return "MEDIUM" end
    return "HIGH"
end

local function ApplyLayout()
    if InCombatLockdown() then State.layoutPending = true; return end
    State.layoutPending = false
    local s = Display.Scale()
    local k = Display.SavedScale() / s
    anchor:ClearAllPoints()
    local p = db.point
    anchor:SetPoint(p[1], UIParent, p[3], p[4] * k, p[5] * k)
    anchor:SetScale(s)
    anchor:SetAlpha(Display.Alpha())
    anchor:SetFrameStrata(Display.Strata())
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
--     ctrlSpell, ctrlUnit = Strg+Linksklick (Gruppen-Zeilen), isGroup, targetName,
--     noUnit = ohne Ziel-Unit (Tier-Zauber), targetBag/targetSlot = Item als Ziel des Zaubers
--     (Tier füttern; feedItem = Item-ID, Pet.PreClick sucht den Platz vor dem Klick neu) }
-- Ohne spell/item tut Linksklick nichts.
function Display.SetRowAction(r, a)
    a = a or {}
    local sig = table.concat({ tostring(a.spell), tostring(a.item), tostring(a.macro), tostring(a.unit),
        tostring(a.ctrlSpell), tostring(a.ctrlUnit), tostring(a.trackIndex), tostring(a.noUnit),
        tostring(a.targetBag), tostring(a.targetSlot) }, "|")
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
    if a.noUnit then
        r:SetAttribute("unit1", nil)
    else
        r:SetAttribute("unit1", a.unit or "player")
    end
    -- Tier füttern: Taschenplatz als Ziel des Zaubers (Bag 0 = Rucksack, daher kein "or nil"-Kurzschluss)
    if a.spell and a.targetBag ~= nil and a.targetSlot ~= nil then
        r:SetAttribute("target-bag1", a.targetBag)
        r:SetAttribute("target-slot1", a.targetSlot)
    else
        r:SetAttribute("target-bag1", nil)
        r:SetAttribute("target-slot1", nil)
    end
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
    r:HookScript("PreClick", Pet.PreClick)   -- Tier füttern: Taschenplatz vor dem Klick neu ermitteln
    r:SetScript("PostClick", function(self, button, down)
        if not Display.IsActionPhase(down) then return end
        if button == "LeftButton" then
            -- benutzte Zeile für die Taste kurz sperren (auch im Kampf merken; nicht beim Verschieben)
            if not State.unlocked then Keybind.MarkUsed(self) end
            -- Vorratszeile: bis zur nächsten Stadt zurückstellen (keine Secure-Aktion)
            if Supply.IsSupply(self.entry) and not State.unlocked then
                Supply.OnClick(self.entry)
                return
            end
            -- Verfolgungs-Zeile: Verfolgung einschalten (nur außerhalb des Kampfes)
            if self.entry and self.entry.kind == "tracking" and not State.unlocked and Tracking.Activate(self) then
                return
            end
            -- per Linksklick benutztes Fläschchen als "zuletzt benutzt" merken
            if self.useItem and self.entry and self.entry.itemKind == "flask" then
                cdb.lastFlask = self.useItem
            end
            if self.entry and self.entry.ownOnly and self.action and self.action.variantKey then
                Group.lastAttempt = {
                    unit = self.action.unit, unitKey = self.action.unitKey,
                    name = self.action.targetFullName or self.action.targetName,
                    key = self.entry.key, variant = self.action.variantKey, t = GetTime(),
                }
            end
            return
        end
        if button == "RightButton" and self.entry and not State.unlocked then Display.OpenMuteMenu(self) end
    end)
    r:SetScript("OnDragStart", function()
        if State.unlocked and not InCombatLockdown() then anchor:StartMoving() end
    end)
    r:SetScript("OnDragStop", function()
        if State.unlocked and not InCombatLockdown() then Display.SavePoint() end
    end)
    r:SetScript("OnEnter", function(self)
        local st = Style.CurrentStyle()
        if not self.entry then
            -- Verschiebe-Modus: bei "Nur Icons" steht der Text nur im Tooltip
            if Style.IconsOnly(st) and State.unlocked then
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
        if self.entry.kind == "pet" then
            Pet.AddTooltip(self)   -- Laune, Ernährung, Klick-Hinweise
            GameTooltip:Show()
            return
        end
        if Supply.IsSupply(self.entry) then
            GameTooltip:AddLine(Supply.ClickText(), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.RIGHTCLICK, 0.8, 0.8, 0.8)
            GameTooltip:Show()
            return
        end
        local a = self.action or {}
        if a.ctrlSpell then
            -- Gruppen-Zeile: Ziel nennen (bei Varianten-Vorschlag auch gewählten Segen)
            local who = a.targetName or "?"
            local label = (self.entry.ownOnly and a.spellName) and (who .. " – " .. a.spellName) or who
            GameTooltip:AddLine((a.isGroup and L.LEFTCLICK_GROUP or L.LEFTCLICK_SINGLE):format(label), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.CTRLCLICK_SINGLE:format(who), 0.8, 0.8, 0.8)
        elseif self.action and self.action.trackIndex then
            GameTooltip:AddLine(L.LEFTCLICK_TRACK, 0.8, 0.8, 0.8)
        elseif self.castSpell then
            GameTooltip:AddLine(L.LEFTCLICK, 0.8, 0.8, 0.8)
        end
        if self.useItem then
            GameTooltip:AddLine(L.LEFTCLICK_USE:format(ItemName(self.useItem)), 0.8, 0.8, 0.8)
            local single = self.entry and self.entry.kind == "elixir"   -- Elixier: kein Auswahlmenü
            GameTooltip:AddLine(single and L.RIGHTCLICK or L.RIGHTCLICK_CHOOSE, 0.8, 0.8, 0.8)
        elseif Variant.MenuOn(self.entry) then
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
        -- Deckkraft der Zeile (Ablauf-Zeile: Ablauf-Faktor, wirkt mit der Deckkraft der Anzeige
        -- multipliziert). Stop() setzt die Alpha-Animation auf ihren Startwert 1 zurück: Ablauf-
        -- Zeilen daher zuerst anhalten, dann die Deckkraft setzen; pulsierende Zeilen nicht anfassen.
        local alpha = isExp and Expiry.Alpha() or 1
        r.baseAlpha = alpha
        if isExp then r.pulse:Stop() end
        if isExp or not r.pulse:IsPlaying() then r:SetAlpha(alpha) end
        r.icon:SetTexture(EntryIcon(e))
        r.right:SetText("")
        if dragMode then
            r.entry = nil
            Display.SetRowAction(r, nil)
            Display.SetRowLines(r, false)
            Display.SetRowStatus(r, "neutral")
            r.text:SetText(L.DRAG)
            Display.SetRowHint(r, nil)
        elseif e.demo then
            r.entry = e
            Demo.FillRow(r, e, st)
        elseif e.kind == "pet" then
            r.entry = e
            Pet.FillRow(r, e)
        elseif Supply.IsSupply(e) then
            r.entry = e
            Supply.FillRow(r, e, st)
        elseif e.groupActive then
            -- Gruppen-Zeile: Anzahl, Namen, Gruppen-/Einzel-Klick auf den ersten Spieler ohne Buff
            r.entry = e
            local a = Group.GroupActionFor(e)
            Display.SetRowAction(r, a)
            Display.SetRowLines(r, true)
            Display.SetRowStatus(r, "missing")
            local label = (e.ownOnly and a and a.spellName) or EntryLabel(e)
            if e.ownOnly and a and a.spell then
                local tex = SpellIcon(a.spell)
                if tex then r.icon:SetTexture(tex) end
            end
            r.text:SetText(L.GROUP_MISSING:format(label, #(e.groupMissing or {})))
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
            local trackIndex
            -- Essen/Fläschchen/Waffen-Items: Linksklick benutzt die beste Wahl aus den Taschen
            local item, noItem, macro
            local kind = Items.KindOf(e)
            if e.kind == "tracking" and db.clickCast then
                -- Platz der ersten fehlenden Verfolgung (SetTracking aller fehlenden im PostClick);
                -- ohne Liste: Zauber der Verfolgung als secure Aktion, falls bekannt
                local t = (e.trackMissing or {})[1]
                if t and t.index and Tracking.SetFn() then
                    trackIndex = t.index
                elseif t and t.spell and SpellKnown(t.spell) then
                    spell = t.spell
                end
            elseif not spell and kind and db.clickCast then
                local choices = Items.ItemChoices(e)
                item = choices[1] and choices[1].id
                noItem = item == nil
                if item and (kind == "weapon" or kind == "poison") then
                    macro = Items.WeaponMacro(item, Items.WeaponSlot(e))
                end
            end
            local action = (spell or item) and { spell = spell, item = item, macro = macro }
                or (trackIndex and { trackIndex = trackIndex } or nil)
            Display.SetRowAction(r, action)
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
                    r.right:SetText(e.kind == "tracking" and L.SHORT_OFF or L.SHORT_MISSING)
                elseif e.kind == "tracking" then
                    r.text:SetText(L.TRACK_OFF:format(EntryLabel(e)))   -- "Verfolgung aus: Mineraliensuche, Schatzsuche"
                elseif e.weaponItems then
                    r.text:SetText(EntryLabel(e))   -- "Waffe (Haupthand): Stein/Öl"
                else
                    r.text:SetText(L.MISSING:format(EntryLabel(e)))
                end
            end
            if e.eatStart and not isExp then
                Display.SetRowHint(r, L.HINT_EATING)
            elseif trackIndex then
                Display.SetRowHint(r, L.HINT_TRACK)
            elseif spell then
                Display.SetRowHint(r, Variant.MenuOn(e) and L.HINT_CAST_CHOOSE or L.HINT_CAST)
            elseif item then
                Display.SetRowHint(r, kind == "elixir" and L.HINT_USE or L.HINT_ITEM:format(ItemName(item)))
            elseif noItem then
                Display.SetRowHint(r, L.HINT_NOITEM)
            else
                Display.SetRowHint(r, Variant.MenuOn(e) and L.HINT_CHOOSE or L.HINT_MUTE)
            end
        end
        r:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].pulse:Stop()
        rows[i]:SetAlpha(rows[i].baseAlpha or 1)   -- nach Stop() neu setzen (Animation setzt auf 1)
        rows[i].entry = nil
        rows[i].expiryRow = nil
        Display.SetRowAction(rows[i], nil)
    end
    Display.SyncPulse(#list)
    Keybind.Update(#list)
    if #list > 0 then
        if not anchor:IsShown() then
            anchor:SetAlpha(Display.Alpha())   -- Ablauf-Zeilen und Pulsieren wirken relativ dazu
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
            r:SetAlpha(r.baseAlpha or 1)   -- nach Stop() neu setzen (Animation setzt auf 1)
        elseif not r.pulse:IsPlaying() then
            restart = true
        end
    end
    if not restart then return end
    for i = 1, n do
        local r = rows[i]
        if not r.expiryRow then
            r.pulse:Stop()
            r:SetAlpha(r.baseAlpha or 1)
            r.pulse:Play()
        end
    end
end

-- Deckkraft der sichtbaren Ablauf-Zeilen sofort neu setzen (Regler "Deckkraft (relativ)");
-- SetAlpha ist nicht geschützt, wirkt also auch im Kampf
function Display.ApplyRowAlpha()
    for _, r in ipairs(rows) do
        if r:IsShown() and r.expiryRow then
            r.baseAlpha = Expiry.Alpha()
            r.pulse:Stop()
            r:SetAlpha(r.baseAlpha)
        end
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

-- Munition im Kampf: Text der sichtbaren Munitionszeile live aktualisieren (nur FontStrings;
-- höchstens alle 0,2 Sek.; die Anzahl setzt Evaluate über CheckMissing)
function Display.TickSupplies()
    local now = GetTime()
    if Display.supplyTick and now - Display.supplyTick < 0.2 then return end
    Display.supplyTick = now
    local st = Style.CurrentStyle()
    for _, r in ipairs(rows) do
        local e = r:IsShown() and r.entry
        if e and e.supplyType == "ammo" then Supply.SetRowText(r, e, st) end
    end
end

-- Für andere Dateien (ns)
ns.anchor = anchor
ns.ApplyLayout = ApplyLayout
ns.rows = rows
