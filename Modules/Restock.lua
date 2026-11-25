-- Pardona's Buff Reminder – Auffüllen beim Händler: Fenster "Auffüllen" (Schalter expRestock).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Style = ns.Style
local Menu = ns.Menu
local Demo = ns.Demo
local Supply = ns.Supply
local Restock = ns.Restock
local entries = ns.entries
local knownCache = ns.knownCache
local Print = ns.Print
local IsSecret = ns.IsSecret
local ExpOn = ns.ExpOn
-- aus Data.lua
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
-- aus Detect.lua
local IsEnabled = ns.IsEnabled
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db
ns.OnDB(function(newDb) db = newDb end)

---------------------------------------------------------------------------
-- Auffüllen beim Händler (Schalter expRestock; wirkt nur mit der Vorratswarnung)
--   Zielmenge je Vorrats-Eintrag: Spalte "Auffüllen auf" (Supply.Refill; nicht für Tierfutter).
--   Passend ist ein Eintrag, wenn sein Bestand unter Min. liegt (mit "Auch oberhalb der Mindestmenge
--   auffüllen", db.restockAbove: unter "Auffüllen auf") und der offene Händler genau sein
--   Item verkauft (Munition: angelegte Sorte; Reagenzien, Seelensplitter, eigene Items: Item-ID).
--   Nie angeboten: Waren mit Sonderkosten (Marken/Items), nicht kaufbare oder ausverkaufte Waren.
--   Das Fenster "Auffüllen" (rechts am Händlerfenster, im gewählten Stil) erscheint beim Öffnen
--   eines Händlers, wenn mindestens ein Eintrag passt, und per Linksklick auf eine Vorratszeile,
--   solange ein Händler offen ist. Je Zeile: Häkchen, Icon, Name, Bestand/Ziel, Kaufmenge, Preis.
--   Kaufmenge = Ziel - Bestand, aufgerundet auf die Bündelgröße des Händlers; begrenzt durch den
--   Vorrat des Händlers und den geschätzten freien Taschenplatz (Köcher/Munitionsbeutel/Seelen-
--   beutel nur für passende Items). Gekauft wird nur per Knopf (nie automatisch, nie im Kampf),
--   in Schritten bis zur maximalen Stapelgröße alle Restock.STEP Sek. Keine Bank (zurückgestellt).
--   Schließt der Spieler das Fenster, öffnet es sich bis zum nächsten Händlerbesuch nicht von selbst.
---------------------------------------------------------------------------
Restock.STEP = 0.2            -- Abstand zwischen zwei Käufen (Sek.)
Restock.MAX_TARGET = 9999
Restock.AMMO_TARGET = 1000
Restock.WIDTH, Restock.ROW_H = 420, 22
Restock.unchecked = {}        -- Item-ID -> true: Häkchen abgewählt (bis der Händler schließt)
Restock.EVENTS = { MERCHANT_UPDATE = true, PLAYER_MONEY = true }
-- Demo-Fenster (Screenshots, ohne Händler): { Item-ID, Bestand, Ziel, Bündel, Preis je Bündel }
Restock.DEMO = { { 2515, 200, 1000, 200, 100 }, { 17028, 3, 20, 1, 2500 } }
-- Handwerkswaren (keine Tabelle im Addon): Kristallphiole, Seidenfaden, Starkes Flussmittel
Restock.DEMO_TRADE = { { 8925, 4, 40, 1, 2000 }, { 4291, 2, 20, 1, 500 }, { 3466, 1, 10, 1, 2000 } }
Restock.DEMO_GOLD = 523050
Restock.DEMO_GOLD_LOW = 32540   -- Demo "nogold": weniger als die Summe von DEMO_TRADE (9g 90s)

function Restock.On()
    return ExpOn("expRestock") and ExpOn("expReagents")
end

-- Händler offen und Auffüllen an? (dann öffnet der Linksklick auf eine Vorratszeile das Fenster)
function Restock.Available()
    return Restock.atMerchant == true and Restock.On()
end

-- Zahl, die kein Secret-Wert ist, sonst nil
function Restock.Num(v)
    if type(v) ~= "number" or IsSecret(v) then return nil end
    return v
end

-- Client-Funktion geschützt aufrufen (fehlt sie oder schlägt sie fehl: nil)
function Restock.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local res = { pcall(fn, ...) }
    if not res[1] then return nil end
    return unpack(res, 2, table.maxn(res))
end

-- Ware an Platz i des Händlers; nil = nicht lesbar oder nicht anzubieten
function Restock.MerchantItem(i)
    local id = Restock.Num(Restock.Call(GetMerchantItemID, i))
    if not id then
        local link = Restock.Call(GetMerchantItemLink, i)
        if type(link) == "string" and not IsSecret(link) then id = tonumber(link:match("item:(%d+)")) end
    end
    if not id then return nil end
    local price, bundle, avail, buyable, extended
    local info = C_MerchantFrame and Restock.Call(C_MerchantFrame.GetItemInfo, i)
    if type(info) == "table" and not IsSecret(info) then
        price, bundle = Style.LibField(info, "price"), Style.LibField(info, "stackCount")
        avail, buyable = Style.LibField(info, "numAvailable"), Style.LibField(info, "isPurchasable")
        extended = Style.LibField(info, "hasExtendedCost")
    else
        local _, _, p, q, n, b, _, ext = Restock.Call(GetMerchantItemInfo, i)
        price, bundle, avail, buyable, extended = p, q, n, b, ext
    end
    price, bundle, avail = Restock.Num(price), Restock.Num(bundle), Restock.Num(avail)
    if IsSecret(buyable) or IsSecret(extended) or extended or buyable == false then return nil end
    if not price or price <= 0 or avail == 0 then return nil end   -- avail -1 = unbegrenzt
    bundle = (bundle and bundle >= 1) and math.floor(bundle) or 1
    local maxStack = Restock.Num(Restock.Call(GetMerchantItemMaxStack, i))
    return { index = i, id = id, price = price, bundle = bundle,
        avail = (avail and avail > 0) and avail or nil, maxStack = maxStack and math.floor(maxStack) or bundle }
end

-- Angebot des offenen Händlers: Item-ID -> Ware (erste passende Stelle)
function Restock.ReadMerchant()
    local offers = {}
    local n = Restock.Num(Restock.Call(GetMerchantNumItems)) or 0
    for i = 1, math.min(n, 500) do
        local o = Restock.MerchantItem(i)
        if o and not offers[o.id] then offers[o.id] = o end
    end
    return offers
end

-- Item, das für einen Vorrats-Eintrag gekauft wird (nil: Tierfutter, keine Munition angelegt)
function Restock.ItemOf(e)
    if e.supplyType == "petfood" then return nil end
    if e.supplyType == "ammo" then return Supply.AmmoItem() or nil end
    return e.item
end

-- Passende Einträge beim offenen Händler (Reihenfolge wie in der Vorratsliste). Angeboten wird ein
-- Eintrag unter Min., mit "Auch oberhalb der Mindestmenge auffüllen" (db.restockAbove) jeder unter
-- "Auffüllen auf"; gekauft wird in beiden Fällen bis "Auffüllen auf".
function Restock.Collect()
    local offers, list, seen = Restock.ReadMerchant(), {}, {}
    local above = db.restockAbove == true
    for _, e in ipairs(entries) do
        local id = Supply.IsSupply(e) and knownCache[e.key] and IsEnabled(e) and Restock.ItemOf(e)
        local o = id and not seen[id] and offers[id]
        local count = o and Supply.Count(e)
        local target = count and Supply.Refill(e)
        if count and count < (above and target or Supply.Threshold(e)) then
            seen[id] = true
            local want = math.ceil((target - count) / o.bundle) * o.bundle
            if o.avail then want = math.min(want, o.avail * o.bundle) end
            if want > 0 then
                list[#list + 1] = { id = id, offer = o, count = count, target = target, want = want, qty = want,
                    checked = not Restock.unchecked[id] }
            end
        end
    end
    return list
end

-- Stapelgröße eines Items in der Tasche (Rückfall: größte Kaufmenge beim Händler)
function Restock.StackSize(id, offer)
    local n = Restock.Num(Restock.Call(C_Item and C_Item.GetItemMaxStackSize, id))
    if not n then n = Restock.Num(select(8, Restock.Call(GetItemInfo, id))) end
    return math.max(1, math.floor(n or offer.maxStack or 1))
end

-- Taschenart eines Items (Bitmaske wie bei Taschen; 0 = keine besondere)
function Restock.ItemFamily(id)
    local fn = (C_Item and C_Item.GetItemFamily) or GetItemFamily
    return Restock.Num(Restock.Call(fn, id)) or 0
end

-- Passt ein Item in eine Tasche dieser Art? (0 = normale Tasche, sonst nur passende Items)
function Restock.Fits(bagFamily, itemFamily)
    if bagFamily == 0 then return true end
    if itemFamily == 0 then return false end
    if type(bit) == "table" and type(bit.band) == "function" then return bit.band(bagFamily, itemFamily) ~= 0 end
    return bagFamily == itemFamily
end

-- Freie Plätze je Tasche { free, family }, besondere Taschen zuerst; nil = nicht lesbar
function Restock.FreeBags()
    local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if type(fn) ~= "function" then return nil end
    local bags = {}
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        local ok, n, fam = pcall(fn, bag)
        n = ok and Restock.Num(n)
        if n and n > 0 then
            bags[#bags + 1] = { free = n, family = Restock.Num(fam) or 0 }
        end
    end
    table.sort(bags, function(a, b) return a.family ~= 0 and b.family == 0 end)
    return bags
end

-- Kaufmengen der angehakten Zeilen an den freien Taschenplatz anpassen (Schätzung: angebrochene
-- Stapel + freie Plätze passender Taschen); Restock.bagShort = mindestens eine Zeile gekürzt
function Restock.FitBags(list)
    Restock.bagShort = false
    for _, r in ipairs(list) do r.qty = r.want end
    local bags = Restock.FreeBags()
    if not bags then return end
    for _, r in ipairs(list) do
        if r.checked then
            local stack, fam = Restock.StackSize(r.id, r.offer), Restock.ItemFamily(r.id)
            local rest = r.count % stack
            local partial = rest > 0 and (stack - rest) or 0
            local slots = 0
            for _, b in ipairs(bags) do
                if Restock.Fits(b.family, fam) then slots = slots + b.free end
            end
            local cap = partial + slots * stack
            if r.want > cap then
                r.qty = math.floor(cap / r.offer.bundle) * r.offer.bundle
                Restock.bagShort = true
            end
            local need = math.ceil(math.max(0, r.qty - partial) / stack)
            for _, b in ipairs(bags) do
                if need <= 0 then break end
                if Restock.Fits(b.family, fam) then
                    local take = math.min(need, b.free)
                    b.free, need = b.free - take, need - take
                end
            end
        end
    end
end

function Restock.Cost(r)
    return math.floor(r.offer.price * r.qty / r.offer.bundle + 0.5)
end

-- Eigenes Gold (Kupfer); nil = nicht lesbar
function Restock.Money()
    return Restock.Num(Restock.Call(GetMoney))
end

-- Betrag mit Münz-Symbolen (Client-Funktion), sonst "1g 2s 3c"
function Restock.Coins(copper)
    copper = math.max(0, math.floor(copper + 0.5))
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    local s = Restock.Call(fn, copper)
    if type(s) == "string" and not IsSecret(s) and s ~= "" then return s end
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if sv > 0 then parts[#parts + 1] = sv .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- Fenster (einmal, beim ersten Öffnen)
function Restock.Frame()
    local f = Restock.frame
    if f then return f end
    f = CreateFrame("Frame", "BuffReminderRestock", UIParent, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    tinsert(UISpecialFrames, "BuffReminderRestock")   -- Esc schließt
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetJustifyH("LEFT")
    f.seps = { f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK") }
    f.rows = {}
    f.total = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.total:SetJustifyH("LEFT")
    f.gold = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.gold:SetJustifyH("RIGHT")
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetJustifyH("LEFT")
    f.note:SetTextColor(1, 0.4, 0.3)
    f.buy = CreateFrame("Button", nil, f, "BackdropTemplate")
    f.buy.bg = f.buy:CreateTexture(nil, "BACKGROUND")
    f.buy:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
    f.buy.label = f.buy:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.buy.label:SetPoint("CENTER")
    f.buy:SetScript("OnClick", function() Restock.Buy() end)
    f.close = CreateFrame("Button", nil, f)
    f.close:SetHighlightTexture(Style.HIGHLIGHT, "ADD")
    f.close.label = f.close:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.close.label:SetPoint("CENTER")
    f.close:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnHide", function()
        if Restock.buying then Restock.Finish() end   -- Esc während des Kaufs: Rest verwerfen
        if Restock.atMerchant and not Restock.demo then Restock.dismissed = true end
        Restock.demo = nil
    end)
    Restock.frame = f
    return f
end

-- Zeile i des Fensters (Häkchen, Icon, Name, Bestand/Ziel, Kaufmenge, Preis)
function Restock.Row(i)
    local f = Restock.Frame()
    local w = f.rows[i]
    if w then return w end
    w = {}
    w.cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    w.cb:SetSize(22, 22)
    w.cb:SetScript("OnClick", function(self) Restock.Toggle(self.itemID, self:GetChecked()) end)
    w.icon = f:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(18, 18)
    w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.name:SetJustifyH("LEFT")
    w.name:SetWordWrap(false)
    w.name:SetWidth(120)
    w.have = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.have:SetJustifyH("RIGHT")
    w.qty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.qty:SetJustifyH("RIGHT")
    w.price = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.price:SetJustifyH("RIGHT")
    f.rows[i] = w
    return w
end

function Restock.ShowRow(w, show)
    for _, obj in ipairs({ w.cb, w.icon, w.name, w.have, w.qty, w.price }) do
        if show then obj:Show() else obj:Hide() end
    end
end

-- Häkchen einer Zeile geändert: Mengen, Summe und Knopf neu
function Restock.Toggle(id, on)
    if not id then return end
    if Restock.demo then
        for _, r in ipairs(Restock.list or {}) do
            if r.id == id then r.checked = on and true or false end
        end
        Restock.Show(Restock.list, Restock.pos)
        return
    end
    Restock.unchecked[id] = (not on) or nil
    Restock.Refresh()
end

function Restock.Separator(t, ms, pad, y)
    local c = ms.sepColor
    t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    t:SetHeight(1)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", pad, y)
    t:SetPoint("TOPRIGHT", -pad, y)
end

-- Fenster mit den Zeilen aus list aufbauen und zeigen; pos = { x, y } (Demo: links oben in
-- Parent-Koordinaten), sonst rechts am Händlerfenster
function Restock.Show(list, pos)
    local f = Restock.Frame()
    local st = Style.CurrentStyle()
    local ms = st.menu
    local demo = Restock.demo
    local pad, width = ms.pad + st.inset, Restock.WIDTH
    local inner = width - 2 * pad
    if not demo then Restock.FitBags(list) end
    Restock.list, Restock.pos = list, pos
    Style.StyleFrame(f, st, f.bg)

    local y = -pad
    Style.SetFont(f.title, st.titleFont)
    Style.SetColor(f.title, "SetTextColor", st.titleColor)
    f.title:ClearAllPoints()
    f.title:SetPoint("TOPLEFT", pad, y)
    f.title:SetText(L.RESTOCK_TITLE)
    y = y - 18
    Restock.Separator(f.seps[1], ms, pad, y)
    y = y - ms.gap

    local total = 0
    for i, r in ipairs(list) do
        local w = Restock.Row(i)
        w.cb:ClearAllPoints()
        w.cb:SetPoint("TOPLEFT", pad - 3, y + 1)
        w.cb.itemID = r.id
        w.cb:SetChecked(r.checked)
        w.icon:ClearAllPoints()
        w.icon:SetPoint("TOPLEFT", pad + 22, y - 2)
        w.icon:SetTexture(ItemIcon(r.id) or FALLBACK_ICON)
        w.icon:SetDesaturated(not r.checked)
        w.name:ClearAllPoints()
        w.name:SetPoint("LEFT", w.icon, "RIGHT", 6, 0)
        w.name:SetText(ItemName(r.id))
        w.have:ClearAllPoints()
        w.have:SetPoint("RIGHT", f, "TOPLEFT", pad + 250, y - 11)
        w.have:SetText(("%d / %d"):format(r.count, r.target))
        w.qty:ClearAllPoints()
        w.qty:SetPoint("RIGHT", f, "TOPLEFT", pad + 300, y - 11)
        w.qty:SetText(("×%d"):format(r.qty))
        w.price:ClearAllPoints()
        w.price:SetPoint("RIGHT", f, "TOPLEFT", pad + inner, y - 11)
        local cost = Restock.Cost(r)
        w.price:SetText(r.qty > 0 and Restock.Coins(cost) or "–")
        local c = r.checked and ms.textColor or ms.subColor
        for _, fs in ipairs({ w.name, w.have, w.qty, w.price }) do Style.SetColor(fs, "SetTextColor", c) end
        if r.checked then total = total + cost end
        Restock.ShowRow(w, true)
        y = y - Restock.ROW_H
    end
    for i = #list + 1, #f.rows do Restock.ShowRow(f.rows[i], false) end
    y = y - 4
    Restock.Separator(f.seps[2], ms, pad, y)
    y = y - ms.gap

    -- Summe, eigenes Gold, Hinweise (Kampf, Gold, Taschenplatz)
    local money = demo and (Restock.demoGold or Restock.DEMO_GOLD) or Restock.Money()
    f.total:ClearAllPoints()
    f.total:SetPoint("TOPLEFT", pad, y)
    f.total:SetText(L.RESTOCK_TOTAL:format(Restock.Coins(total)))
    Style.SetColor(f.total, "SetTextColor", ms.textColor)
    f.gold:ClearAllPoints()
    f.gold:SetPoint("TOPRIGHT", -pad, y)
    f.gold:SetText(L.RESTOCK_GOLD:format(money and Restock.Coins(money) or "?"))
    Style.SetColor(f.gold, "SetTextColor", ms.subColor)
    y = y - 16
    local combat = InCombatLockdown()
    local noGold = money ~= nil and total > money
    local notes = {}
    if combat then notes[#notes + 1] = L.COMBAT end
    if noGold then notes[#notes + 1] = L.RESTOCK_NO_GOLD end
    if Restock.bagShort and not demo then notes[#notes + 1] = L.RESTOCK_NO_SPACE end
    if #notes > 0 then
        f.note:ClearAllPoints()
        f.note:SetPoint("TOPLEFT", pad, y)
        f.note:SetText(table.concat(notes, " · "))
        f.note:Show()
        y = y - 16
    else
        f.note:Hide()
    end
    y = y - 4

    -- Knöpfe "Kaufen" und "Schließen (Esc)"
    local canBuy = not combat and not noGold and total > 0 and not Restock.buying
    Restock.canBuy = canBuy and not demo
    f.buy:SetSize(inner, 22)
    f.buy:ClearAllPoints()
    f.buy:SetPoint("TOPLEFT", pad, y)
    Menu.StyleButton(f.buy, ms)
    f.buy.label:SetText(L.RESTOCK_BUY)
    if canBuy then f.buy:Enable() else f.buy:Disable() end
    f.buy:SetAlpha(canBuy and 1 or 0.45)
    y = y - 22 - ms.gap
    f.close:SetSize(inner, 16)
    f.close:ClearAllPoints()
    f.close:SetPoint("TOPLEFT", pad, y + 2)
    f.close.label:SetText(L.CLOSE_ESC)
    Style.SetColor(f.close.label, "SetTextColor", ms.subColor)
    y = y - 16
    f:SetSize(width, -y + pad)

    f:ClearAllPoints()
    local mf = MerchantFrame
    if pos then
        f:SetPoint("TOPLEFT", f:GetParent() or UIParent, "BOTTOMLEFT", pos[1], pos[2])
    elseif type(mf) == "table" and type(mf.IsShown) == "function" and mf:IsShown() then
        f:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:Show()
end

-- Fenster öffnen (auto: beim Öffnen des Händlers; sonst per Linksklick mit Hinweis, wenn nichts passt)
function Restock.Open(auto)
    if not Restock.Available() or Demo.active then return end
    local list = Restock.Collect()
    if #list == 0 then
        if not auto then Print(L.RESTOCK_NONE) end
        return
    end
    if auto and Restock.dismissed then return end   -- selbst geschlossen: erst beim nächsten Besuch
    Restock.demo, Restock.dismissed, Restock.shownVisit = nil, nil, true
    Restock.Show(list)
end

-- Offenes Fenster neu bewerten (Taschen, Gold, Händler, Kampf); nichts mehr offen -> schließen
function Restock.Refresh()
    local f = Restock.frame
    if not (f and f:IsShown()) or Restock.demo or Restock.buying then return end
    if not Restock.Available() then f:Hide(); return end
    local list = Restock.Collect()
    if #list == 0 then f:Hide(); return end
    Restock.Show(list)
end

-- Knopf "Kaufen": genau die angezeigten Mengen, in Schritten bis zur größten Kaufmenge des Händlers
function Restock.Buy()
    if Restock.buying or not Restock.canBuy or Restock.demo or type(BuyMerchantItem) ~= "function" then return end
    if InCombatLockdown() or not Restock.Available() then return end
    local queue = {}
    for _, r in ipairs(Restock.list or {}) do
        if r.checked and r.qty > 0 then
            local o = r.offer
            local per = math.max(o.bundle, math.floor(math.max(o.maxStack, 1) / o.bundle) * o.bundle)
            local left = r.qty
            while left > 0 do
                local n = math.min(per, left)
                queue[#queue + 1] = { row = r, n = n }
                left = left - n
            end
        end
    end
    if #queue == 0 then return end
    Restock.buying = { queue = queue, pos = 1, bought = {}, order = {}, cost = 0 }
    Restock.canBuy = false
    Restock.frame.buy:Disable()
    Restock.frame.buy:SetAlpha(0.45)
    Restock.Step()
end

-- Ein Kaufschritt; Händler zu, Kampf oder geänderte Händlerliste beenden den Kauf
function Restock.Step()
    local b = Restock.buying
    if not b or b.done then return end
    local q = b.queue[b.pos]
    if not q or InCombatLockdown() or not Restock.atMerchant then Restock.Finish(); return end
    local r = q.row
    local o = Restock.MerchantItem(r.offer.index)
    if not o or o.id ~= r.id or o.price ~= r.offer.price or o.bundle ~= r.offer.bundle then
        Restock.Finish()
        return
    end
    if not pcall(BuyMerchantItem, r.offer.index, q.n) then Restock.Finish(); return end
    if not b.bought[r.id] then
        b.bought[r.id] = 0
        b.order[#b.order + 1] = r.id
    end
    b.bought[r.id] = b.bought[r.id] + q.n
    b.cost = b.cost + r.offer.price * q.n / r.offer.bundle
    b.pos = b.pos + 1
    if b.queue[b.pos] then C_Timer.After(Restock.STEP, Restock.Step) else Restock.Finish() end
end

-- Kauf beendet: Ergebnis im Chat; Fenster nach dem Nachziehen der Taschen neu bewerten
function Restock.Finish()
    local b = Restock.buying
    if not b or b.done then return end
    b.done = true
    local parts = {}
    for _, id in ipairs(b.order) do parts[#parts + 1] = ("%s ×%d"):format(ItemName(id), b.bought[id]) end
    if #parts > 0 then Print(L.RESTOCK_BOUGHT:format(table.concat(parts, ", "), Restock.Coins(b.cost))) end
    C_Timer.After(1, function()
        if Restock.buying == b then Restock.buying = nil end
        Restock.Refresh()
    end)
end

-- Beispielfenster (Demo-Modus, ohne Händler); x, y wie beim Rechtsklick-Menü.
-- kind: "vendor" (Standard, DEMO) | "trade" (DEMO_TRADE) | "nogold" (DEMO_TRADE, zu wenig Gold)
function Restock.ShowDemo(x, y, kind)
    local list = {}
    local trade = kind == "trade" or kind == "nogold"
    Restock.demoGold = kind == "nogold" and Restock.DEMO_GOLD_LOW or Restock.DEMO_GOLD
    for _, d in ipairs(trade and Restock.DEMO_TRADE or Restock.DEMO) do
        local want = d[3] - d[2]
        list[#list + 1] = { id = d[1], offer = { price = d[5], bundle = d[4] }, count = d[2], target = d[3],
            want = want, qty = want, checked = true }
    end
    Restock.demo = true
    Restock.Show(list, { x, y })
end

function Restock.HideDemo()
    if Restock.frame and Restock.demo then Restock.frame:Hide() end
end

-- PLAYER_LOGIN: Händler-Aktualisierung und Gold (reg = SafeRegisterEvent)
function Restock.RegisterEvents(frame, reg)
    for event in pairs(Restock.EVENTS) do reg(frame, event) end
end

-- Händler auf/zu (auch per PLAYER_INTERACTION_MANAGER_FRAME_*), Händlerliste, Gold, Taschen, Kampf
function Restock.OnEvent(event, kind)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local t = Enum and Enum.PlayerInteractionType
        if type(t) ~= "table" or t.Merchant == nil or type(kind) ~= "number" or IsSecret(kind) or kind ~= t.Merchant then
            return
        end
        event = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and "MERCHANT_SHOW" or "MERCHANT_CLOSED"
    end
    if event == "MERCHANT_SHOW" then
        if Restock.atMerchant then return end   -- beide Events eines Händlerbesuchs
        Restock.atMerchant, Restock.dismissed, Restock.shownVisit = true, nil, nil
        wipe(Restock.unchecked)
        Restock.Open(true)
    elseif event == "MERCHANT_CLOSED" then
        Restock.atMerchant = false
        if Restock.buying then Restock.Finish() end
        if Restock.frame and Restock.frame:IsShown() and not Restock.demo then Restock.frame:Hide() end
        wipe(Restock.unchecked)
    elseif event == "MERCHANT_UPDATE" and not (Restock.frame and Restock.frame:IsShown()) then
        -- Händlerliste kam erst nach MERCHANT_SHOW: jetzt öffnen – nur, wenn das Fenster bei diesem
        -- Besuch noch nicht offen war (nie wieder öffnen, nachdem es geschlossen wurde)
        if Restock.atMerchant and not Restock.dismissed and not Restock.shownVisit then Restock.Open(true) end
    elseif Supply.EVENTS[event] == nil then
        Restock.Refresh()
    end
end
