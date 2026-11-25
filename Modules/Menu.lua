-- Pardona's Buff Reminder – Rechtsklick-Menü (Stummschalten, Item-Auswahl) und Variantenmenü.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua, Display.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Items = ns.Items
local Group = ns.Group
local Style = ns.Style
local Display = ns.Display
local Menu = ns.Menu
local Cfg = ns.Cfg
local Conjure = ns.Conjure
local Variant = ns.Variant
local Demo = ns.Demo
local Scroll = ns.Scroll
local Pet = ns.Pet
local Supply = ns.Supply
local Ranks = ns.Ranks
local muted = ns.muted
local NoteDeferred = ns.NoteDeferred
local SpellName = ns.SpellName
-- aus Data.lua
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local EntryIcon = ns.EntryIcon
-- aus Display.lua
local anchor = ns.anchor
local rows = ns.rows
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

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
menu.rankHead = Menu.MenuText("GameFontNormalSmall")
menu.rankNote = Menu.MenuText("GameFontDisableSmall")
menu.seps = {}
for i = 1, 4 do menu.seps[i] = menu:CreateTexture(nil, "ARTWORK") end

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

-- { Text-Schlüssel, Dauer }; Beschriftung per Menu.SetTexts (nach dem Sprachwechsel neu)
Menu.MUTE_OPTIONS = {
    { "MUTE_5", 300 }, { "MUTE_15", 900 }, { "MUTE_60", 3600 }, { "MUTE_SESSION", math.huge },
}
menu.muteButtons = {}
for i, opt in ipairs(Menu.MUTE_OPTIONS) do
    menu.muteButtons[i] = Menu.MenuButton("", function()
        if menu.entry and not menu.entry.demo then
            muted[menu.entry.key] = (opt[2] == math.huge) and math.huge or (GetTime() + opt[2])
            NoteDeferred()
            ns.Evaluate()
        end
        menu:Hide()
    end)
end

-- Rang-Zeile (Warnung bei niedrigen Zauberrängen): Rang akzeptieren, alle Ränge akzeptieren,
-- auf den Aktionsleisten ersetzen (nur außerhalb des Kampfes). Beschriftung per Menu.LayoutMenu.
menu.rankButtons = {}
for i, fn in ipairs({
    function(e) Ranks.Accept(e, false) end,
    function(e) Ranks.Accept(e, true) end,
    function(e) Ranks.ReplaceOnBars(e) end,
}) do
    local b = Menu.MenuButton("", function()
        local e = menu.entry
        menu:Hide()
        if e and e.kind == "rank" then fn(e) end
    end)
    b.label:SetWordWrap(false)
    b:Hide()
    menu.rankButtons[i] = b
end

-- "Anzeige verschieben" (volle Breite unter den Stumm-Knöpfen; nicht im Kampf)
menu.moveBtn = Menu.MenuButton("", function()
    local demo = menu.entry and menu.entry.demo
    menu:Hide()
    if not demo then Cfg.SetMoveMode(true) end
end)

menu.close = CreateFrame("Button", nil, menu)
menu.close:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
menu.close.label = menu.close:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
menu.close.label:SetPoint("CENTER")
menu.close:SetScript("OnClick", function() menu:Hide() end)

-- feste Beschriftungen des Menüs (beim Laden und nach dem Sprachwechsel bei ADDON_LOADED)
function Menu.SetTexts()
    for i, opt in ipairs(Menu.MUTE_OPTIONS) do menu.muteButtons[i].label:SetText(L[opt[1]]) end
    menu.close.label:SetText(L.CLOSE_ESC)
    menu.moveBtn.label:SetText(L.MENU_MOVE)
end
Menu.SetTexts()

-- Item-Zeilen (Secure Buttons: type "item")
local itemPanel = CreateFrame("Frame", "BuffReminderItemMenu", UIParent)
itemPanel:SetFrameStrata("DIALOG")
itemPanel:Hide()
itemPanel.buttons = {}
menu.stars = {}


-- Tooltip einer Menüzeile: Item (itemID) oder Zauber (spellID, Variantenmenü)
function Menu.ShowButtonTooltip(b)
    if not b.itemID and not b.spellID then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    if b.itemID then
        GameTooltip:SetItemByID(b.itemID)
    elseif not (GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, b.spellID)) then
        GameTooltip:SetText(SpellName(b.spellID) or "?", 1, 1, 1)
    end
    GameTooltip:Show()
end

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
    b.xp:SetText(L.XP_BADGE)
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
        local e, vkey = menu.entry, self.variantKey
        if e and e.demo then menu:Hide(); return end   -- Demo: keine Aktion, nichts merken
        if e and e.itemKind == "flask" and self.itemID then cdb.lastFlask = self.itemID end
        -- Variantenmenü: gewählte Variante wird zur zuletzt genutzten (Linksklick der Warnung);
        -- Tier-Zeilen: Dämon wird zur eigenen Wahl
        if e and vkey then
            if e.kind == "pet" then Pet.Picked(e, vkey) else cdb.lastVariant[e.key] = vkey end
        end
        menu:Hide()   -- schließt auch das itemPanel
        if vkey then ns.Evaluate() end
    end)
    -- Tierfutter: Taschenplatz vor dem Klick neu ermitteln (nur dasselbe Item; sonst leer)
    b:HookScript("PreClick", function(self, button)
        if self.feedItem and button == "LeftButton" and not InCombatLockdown() then
            Pet.Retarget(self, "", self.feedItem, false)
        end
    end)
    -- Item- bzw. Zauber-Tooltip beim Überfahren. HookScript statt SetScript: ergänzt nur die
    -- Anzeige, die Secure-Klickfunktion des Buttons bleibt unberührt.
    b:HookScript("OnEnter", Menu.ShowButtonTooltip)
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
        if not self.itemID or not cdb or (menu.entry and menu.entry.demo) then return end
        local favs = Menu.Favs(menu.entry)
        favs[self.itemID] = (not favs[self.itemID]) or nil
        Pet.foodDirty = true   -- Tierfutter-Reihenfolge hängt an den Favoriten
        if not InCombatLockdown() then
            Menu.LayoutMenu(menu.entry)   -- Reihenfolge und Markierung neu
            ns.Evaluate()               -- Linksklick der Warnung nimmt ggf. den neuen Favoriten
        end
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    s:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Menu.Favs(menu.entry)[self.itemID] and L.FAV_REMOVE or L.FAV_ADD, 1, 1, 1)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    menu.stars[i] = s
    return s
end

-- Favoriten-Tabelle des Menü-Eintrags: Tierfutter getrennt (cdb.petFavorites), sonst cdb.favorites
function Menu.Favs(e)
    if e and Items.KindOf(e) == "petfood" then return cdb.petFavorites end
    return cdb.favorites
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
    if c.locked then return L.SCROLL_LEVEL:format(c.minLevel and tostring(c.minLevel) or "?") end
    if c.cat then return ns.Locales.Text("FOOD_CAT_" .. c.cat:upper(), c.cat) end
    if c.wcat then return ns.Locales.Text("WEAPON_CAT_" .. c.wcat:upper(), c.wcat) end
    return ""
end

-- Secure-Aktion einer Item-Zeile: normal "item", Waffen-Items per Makro auf den Slot, Tierfutter
-- per "Tier füttern" mit Taschenplatz (c = Eintrag aus Pet.Food mit bag/slot)
function Menu.SetItemButtonAction(b, id, e, kind, c)
    b:SetAttribute("spell", nil)
    b:SetAttribute("unit", nil)
    b:SetAttribute("target-bag", nil)
    b:SetAttribute("target-slot", nil)
    b.feedItem = nil
    if kind == "petfood" then
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", Pet.FEED)
        b:SetAttribute("target-bag", c.bag)
        b:SetAttribute("target-slot", c.slot)
        b:SetAttribute("item", nil)
        b:SetAttribute("macrotext", nil)
        b.feedItem = id
    elseif kind == "weapon" or kind == "poison" then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", Items.WeaponMacro(id, Items.WeaponSlot(e)))
        b:SetAttribute("item", nil)
    else
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. id)
        b:SetAttribute("macrotext", nil)
    end
end

-- Secure-Aktion einer Varianten-Zeile: Zauber (höchster erlernter Rang) auf sich selbst
-- Zeile ohne secure Aktion (Demo-Modus)
function Menu.ClearButtonAction(b)
    for _, k in ipairs({ "type", "item", "spell", "macrotext", "unit", "target-bag", "target-slot" }) do
        b:SetAttribute(k, nil)
    end
    b.feedItem = nil
end

-- noUnit: ohne Ziel-Unit (Tier rufen/wiederbeleben, Dämon beschwören)
function Menu.SetSpellButtonAction(b, spell, noUnit)
    Menu.ClearButtonAction(b)
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", spell)
    if not noUnit then b:SetAttribute("unit", "player") end
end

function Menu.ItemHeadText(kind)
    if kind == "flask" then return L.MENU_FLASK end
    if kind == "petfood" then return L.MENU_PETFOOD end
    if kind == "weapon" then return L.MENU_WEAPON end
    if kind == "poison" then return L.MENU_POISON end
    if kind == "scroll" then return L.MENU_SCROLL end
    return L.MENU_FOOD
end

-- Menü für Eintrag e aufbauen und an menu.x/menu.y (UIParent-Koordinaten) anzeigen.
-- Im Kampf nur Kopf + Stummschalten; die Secure-Item-Zeilen werden dann nicht angefasst.
-- Rahmen/Hintergrund/Text einer Menü-Schaltfläche im aktuellen Stil
function Menu.StyleButton(b, ms)
    b:SetBackdrop({ edgeFile = Style.WHITE, edgeSize = 1 })
    Style.SetColor(b, "SetBackdropBorderColor", ms.buttonBorder)
    b.bg:ClearAllPoints()
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    Style.SetColor(b.bg, "SetColorTexture", ms.buttonBg)
    Style.SetColor(b.label, "SetTextColor", ms.textColor)
end

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
    -- Elixiere: kein Item-Menü (ein Eintrag = ein Elixier)
    local withItems = kind and kind ~= "elixir" and (db.clickCast or e.demo) and not combat
    -- Variantenmenü: erlernte Varianten statt Items; nie im Kampf
    local variants = not combat and not withItems and Variant.MenuOn(e) and Variant.Choices(e) or nil
    -- Demo-Modus: Beispiel-Varianten bzw. Dämonen (unabhängig davon, ob gelernt)
    if e.demo and e.demoVariants and not combat then variants = Demo.MenuVariants(e.demo) end
    local sub
    if combat then
        sub = L.SUB_COMBAT
    elseif e.groupActive then
        sub = Group.MissingNames(e)
    elseif e.kind == "reagent" then
        sub = L.REAGENT_LOW:format(EntryLabel(e), e.count or 0)
    elseif e.kind == "supply" then
        sub = Supply.Text(e)
    elseif e.kind == "rank" then
        sub = Ranks.Text(e)
    elseif e.kind == "conjure" then
        sub = Conjure.Text(e)
    elseif withItems then
        sub = L.SUB_ITEMS
    elseif variants then
        sub = L.SUB_VARIANT
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

    -- Item-Auswahl bzw. Varianten (gleiche Secure-Zeilen im itemPanel; Varianten ohne Sterne)
    local n, itemTop = 0, 0
    local rowsWidth = variants and inner or (inner - Menu.STAR_SIZE - 8)
    local h = ms.itemHeight
    if withItems or variants then
        Separator()
        Head(menu.itemHead, variants and (e.kind == "pet" and Pet.MenuHead(e) or L.MENU_VARIANT)
            or Menu.ItemHeadText(kind))
        -- Rollen: alle der Art, nicht benutzbare gesperrt (c.locked)
        local choices = variants or (e.demo and Demo.ItemChoices(e.demo.menu))
            or (kind == "scroll" and Scroll.MenuChoices(e)) or Items.ItemChoices(e)
        n = math.min(#choices, Menu.MAX_ITEM_CHOICES)
        itemTop = y
        if n == 0 then
            menu.itemNone:ClearAllPoints()
            menu.itemNone:SetPoint("TOPLEFT", pad + 4, y)
            menu.itemNone:SetText(variants and L.NO_VARIANT or L.NONE_IN_BAGS)
            menu.itemNone:Show()
            y = y - 18
        else
            menu.itemNone:Hide()
        end
        for i = 1, n do
            local c, b = choices[i], Menu.GetItemButton(i)
            if e.demo then
                -- Demo: Zeile ohne secure Aktion (Tooltip über itemID bzw. spellID)
                b.itemID, b.variantKey = (not variants) and c.id or nil, nil
                b.spellID = variants and c.spell or nil
                Menu.ClearButtonAction(b)
            elseif variants then
                b.itemID, b.variantKey = nil, c.vkey
                b.spellID = type(c.spell) == "number" and c.spell or nil
                Menu.SetSpellButtonAction(b, c.spell, e.kind == "pet")
            elseif c.locked then
                -- Stufe zu niedrig: ohne secure Aktion, gesperrt (Tooltip bleibt)
                b.itemID, b.variantKey, b.spellID = c.id, nil, nil
                Menu.ClearButtonAction(b)
            else
                b.itemID, b.variantKey, b.spellID = c.id, nil, nil
                Menu.SetItemButtonAction(b, c.id, e, kind, c)
            end
            if c.locked then b:Disable() else b:Enable() end
            b:SetSize(rowsWidth, h)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -(i - 1) * (h + 1))
            local iconSize = h - 6
            b.icon:SetSize(iconSize, iconSize)
            b.icon:ClearAllPoints()
            b.icon:SetPoint("LEFT", 4, 0)
            b.icon:SetTexture(variants and c.icon or (ItemIcon(c.id) or FALLBACK_ICON))
            b.icon:SetDesaturated(c.locked == true)
            Style.StyleIconBorder(b.iconBorder, b.icon, st.iconBorder)
            b.count:ClearAllPoints()
            b.count:SetPoint("RIGHT", -4, 0)
            b.count:SetText(variants and "" or c.count)
            -- Zeile 1: Name (+ XP-Abzeichen); Zeile 2: Kategorie + "beste Wahl"
            -- (Varianten: Zeile 2 = "zuletzt genutzt" bei der Variante des Linksklicks)
            local best = i == 1 and not variants and not c.locked
            local info = variants and (c.last and L.LAST_USED or "") or Menu.ItemInfoText(c)
            local nameY = ms.itemTwoLines and 6 or 0
            if variants and info == "" then nameY = 0 end   -- Variante ohne Zeile 2: mittig
            b.name:ClearAllPoints()
            b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, nameY)
            if c.locked then
                b.name:SetTextColor(0.5, 0.5, 0.5)
            else
                Style.SetColor(b.name, "SetTextColor", ms.textColor)
            end
            local name = variants and c.name or ItemName(c.id)
            if best and not ms.itemTwoLines then name = Style.StarMarkup(12) .. " " .. name end
            if variants and c.last and not ms.itemTwoLines then
                name = name .. " |cff999999(" .. L.LAST_USED .. ")|r"
            end
            if c.locked and not ms.itemTwoLines then name = name .. " |cff999999(" .. info .. ")|r" end
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
            if ms.itemTwoLines and nameY ~= 0 then
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
            if GameTooltip:IsOwned(b) then Menu.ShowButtonTooltip(b) end

            if not variants then
                local s = Menu.GetStar(i)
                s.itemID = c.id
                Menu.SetStar(s, c.fav == true, st)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", pad + rowsWidth + 4, itemTop - (i - 1) * (h + 1) - (h - Menu.STAR_SIZE - 4) / 2)
                s:Show()
            end
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
            b.itemID, b.variantKey, b.spellID = nil, nil, nil
            Menu.ClearButtonAction(b)
        end
    end
    -- Sterne nur bei Items (Varianten: keine Favoriten)
    for i = (variants and 0 or n) + 1, #menu.stars do menu.stars[i]:Hide() end

    -- Rang-Zeile: Akzeptieren / Ersetzen (Ersetzen im Kampf ausgegraut mit Hinweis)
    if e.kind == "rank" and e.rankInfo then
        local info = e.rankInfo
        Separator()
        Head(menu.rankHead, L.MENU_RANK)
        local texts = { L.RANK_ACCEPT:format(info.rank, info.name), L.RANK_ACCEPT_ALL:format(info.name),
            L.RANK_REPLACE:format(info.bestRank) }
        for i, b in ipairs(menu.rankButtons) do
            b:SetSize(inner, 20)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", pad, y)
            Menu.StyleButton(b, ms)
            b.label:SetWidth(inner - 8)
            b.label:SetText(texts[i])
            if i == 3 and combat then
                b:Disable()
                b.label:SetAlpha(0.5)
            else
                b:Enable()
                b.label:SetAlpha(1)
            end
            b:Show()
            y = y - 20 - 4
        end
        if combat then
            menu.rankNote:ClearAllPoints()
            menu.rankNote:SetPoint("TOPLEFT", pad + 4, y)
            menu.rankNote:SetText(L.RANK_REPLACE_COMBAT)
            menu.rankNote:Show()
            y = y - 14
        else
            menu.rankNote:Hide()
        end
        y = y - ms.gap + 4
    else
        menu.rankHead:Hide()
        menu.rankNote:Hide()
        for _, b in ipairs(menu.rankButtons) do b:Hide() end
    end

    -- Stummschalten: vier Schaltflächen nebeneinander
    Separator()
    Head(menu.muteHead, L.MENU_MUTE)
    local bw = (inner - 3 * 4) / 4
    for i, b in ipairs(menu.muteButtons) do
        b:SetSize(bw, 20)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", pad + (i - 1) * (bw + 4), y)
        Menu.StyleButton(b, ms)
    end
    y = y - 20 - ms.gap
    -- darunter: "Anzeige verschieben" (volle Breite; im Kampf nicht gezeigt)
    if combat then
        menu.moveBtn:Hide()
    else
        menu.moveBtn:SetSize(inner, 20)
        menu.moveBtn:ClearAllPoints()
        menu.moveBtn:SetPoint("TOPLEFT", pad, y)
        Menu.StyleButton(menu.moveBtn, ms)
        menu.moveBtn:Show()
        y = y - 20 - ms.gap
    end

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
    local base = menu:GetParent() or UIParent
    local conv = base:GetEffectiveScale() / menu:GetEffectiveScale()
    local sw, sh = base:GetWidth() * conv, base:GetHeight() * conv
    local x = math.max(0, math.min(menu.x or 0, sw - width))
    local top = menu.y or sh
    if top - height < 0 then top = top - 20 + height end
    top = math.min(sh, math.max(top, height))
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", base, "BOTTOMLEFT", x, top)

    if (withItems or variants) and n > 0 then
        itemPanel:ClearAllPoints()
        itemPanel:SetPoint("TOPLEFT", base, "BOTTOMLEFT", x + pad, top + itemTop)
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
    if Demo.run or self:IsMouseOver() or (itemPanel:IsShown() and itemPanel:IsMouseOver()) then self.away = 0 else
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
    if Demo.active then return end   -- Demo-Menü nicht mit echten Taschen neu aufbauen
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

-- Für andere Dateien (ns)
ns.menu = menu
ns.itemPanel = itemPanel
