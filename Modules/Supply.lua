-- Pardona's Buff Reminder – Vorräte (Vorratswarnung): Munition, Seelensplitter, Tierfutter, eigene Items;
-- Zurückstellen bis zur nächsten Stadt und kritische Grenze.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua), ns.RefreshConfig (Config.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Display = ns.Display
local Pet = ns.Pet
local Supply = ns.Supply
local Restock = ns.Restock
local entries = ns.entries
local knownCache = ns.knownCache
local missing = ns.missing
local missingSince = ns.missingSince
local shownKeys = ns.shownKeys
local muted = ns.muted
local Print = ns.Print
local NoteDeferred = ns.NoteDeferred
local IsSecret = ns.IsSecret
local SpellIcon = ns.SpellIcon
-- aus Data.lua
local Sound = ns.Sound
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
local ItemCount = ns.ItemCount
local ReagentThreshold = ns.ReagentThreshold
local CountKeys = ns.CountKeys
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local PrepareEntry = ns.PrepareEntry
local IsEnabled = ns.IsEnabled
local MuteRemaining = ns.MuteRemaining
local CheckMissing = ns.CheckMissing
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Vorräte (Schalter expReagents – sichtbar "Vorratswarnung"), Reiter "Vorräte"
-- Eine gemeinsame Liste mit den Reagenzien der Klasse (kind "reagent", Schwellen cdb.reagents) und
-- Einträgen kind = "supply", supplyType:
--   "ammo"    : Jäger; angelegte Munition (Ammo-Slot), Summe aller Stapel dieser Sorte in den Taschen;
--               Mindestmenge cdb.ammoMin (Standard 200, 0-2000); keine Munition angelegt -> eigene Zeile
--   "shards"  : Hexenmeister; Seelensplitter (6265), cdb.shardMin (Standard 5, 0-50)
--   "petfood" : Jäger; Summe aller Items, die das Tier fressen kann (Pet.Food), cdb.petFoodMin
--               (Standard 20, 0-200); eigener Schalter cdb.buffs.supply_petfood (Standard aus)
--   "item"    : eigene Items pro Charakter, cdb.supplies[itemID] = Mindestmenge (1-999, Standard 10),
--               höchstens Supply.MAX_ITEMS
-- Gezählt werden nur die Taschen. Keine Klick-Aktion (die Taste "Oberste Warnung" übergeht sie).
---------------------------------------------------------------------------
Supply.MAX_ITEMS, Supply.ITEM_DEFAULT = 20, 10
Supply.DEFS = {
    HUNTER = {
        { key = "supply_ammo", supplyType = "ammo", field = "ammoMin", def = 200, max = 2000 },
        { key = "supply_petfood", supplyType = "petfood", field = "petFoodMin", def = 20, max = 200,
          defaultOff = true },
    },
    WARLOCK = {
        { key = "supply_shards", supplyType = "shards", item = Pet.SOUL_SHARD, field = "shardMin", def = 5, max = 50 },
    },
}
Supply.AMMO_ICON = "Interface\\Icons\\INV_Ammo_Arrow_01"
Supply.items = {}     -- Item-ID -> Eintrag (eigene Items)
Supply.classEntries = {}   -- Munition/Seelensplitter/Tierfutter der eigenen Klasse

-- PLAYER_LOGIN: Einträge der Klasse und der eigenen Items anlegen
function Supply.Setup(class)
    for _, d in ipairs(Supply.DEFS[class] or {}) do
        local e = { kind = "supply" }
        for k, v in pairs(d) do e[k] = v end
        PrepareEntry(e)
        Supply.classEntries[#Supply.classEntries + 1] = e
        if e.supplyType == "ammo" then Supply.ammoEntry = e end
        entries[#entries + 1] = e
        if e.item then ItemName(e.item) end   -- Item-Daten vorladen
    end
    Supply.ready = true
    for id in pairs(cdb.supplies) do Supply.Ensure(id) end
end

-- Eintrag eines eigenen Items (einmal pro Item-ID); nil vor PLAYER_LOGIN
function Supply.Ensure(id)
    if not Supply.ready then return nil end
    local e = Supply.items[id]
    if e then return e end
    e = { key = "supply_item_" .. id, kind = "supply", supplyType = "item", item = id }
    PrepareEntry(e)
    Supply.items[id] = e
    entries[#entries + 1] = e
    knownCache[e.key] = true
    ItemName(id)   -- Name/Icon nachladen (GET_ITEM_INFO_RECEIVED)
    Supply.dirty = true   -- Einstellungen: Liste neu aufbauen
    return e
end

-- Ein Item gilt als gültig, wenn der Client es kennt (GetItemInfoInstant)
function Supply.ValidItem(id)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(fn) ~= "function" then return true end
    local ok, v = pcall(fn, id)
    return ok and v ~= nil
end

-- Eigenes Item hinzufügen (Feld "Item hinzufügen": Shift-Klick, Ziehen, Item-ID + Enter)
function Supply.AddItem(id)
    if type(id) ~= "number" or IsSecret(id) or id <= 0 or not cdb then return end
    id = math.floor(id)
    -- Shift-Klick kann mehrere Hooks auslösen: dasselbe Item kurz hintereinander nur einmal
    local now = GetTime()
    if Supply.lastAdd and Supply.lastAdd.id == id and now - Supply.lastAdd.t < 0.5 then return end
    Supply.lastAdd = { id = id, t = now }
    if cdb.supplies[id] then Print(L.SUPPLY_EXISTS:format(ItemName(id))); return end
    if CountKeys(cdb.supplies) >= Supply.MAX_ITEMS then Print(L.SUPPLY_MAX:format(Supply.MAX_ITEMS)); return end
    if not Supply.ValidItem(id) then Print(L.SUPPLY_INVALID:format(tostring(id))); return end
    cdb.supplies[id] = Supply.ITEM_DEFAULT
    Supply.Ensure(id)
    Print(L.SUPPLY_ADDED:format(ItemName(id)))
    NoteDeferred()
    ns.Evaluate()
    ns.RefreshConfig()
end

-- Eigenes Item entfernen (Knopf in der Liste)
function Supply.RemoveItem(id)
    local e = Supply.items[id]
    cdb.supplies[id] = nil
    if not e then return end
    Supply.items[id] = nil
    for i = #entries, 1, -1 do
        if entries[i] == e then table.remove(entries, i) end
    end
    missing[e.key], missingSince[e.key], muted[e.key], knownCache[e.key] = nil, nil, nil, nil
    Supply.dirty = true
    NoteDeferred()
    ns.Evaluate()
    ns.RefreshConfig()
end

-- Eigene Items sortiert nach Name (Einstellungen)
function Supply.List()
    local list = {}
    for _, e in pairs(Supply.items) do list[#list + 1] = e end
    table.sort(list, function(a, b)
        local na, nb = ItemName(a.item), ItemName(b.item)
        if na ~= nb then return na < nb end
        return a.item < b.item
    end)
    return list
end

-- Item-Link aus Shift-Klick (Taschen, Bank, Chat): nur wenn das Feld "Item hinzufügen" den Fokus hat
function Supply.OnLink(link)
    local box = Supply.addBox
    if not (box and box:IsVisible() and box:HasFocus()) then return end
    if type(link) ~= "string" or IsSecret(link) then return end
    local id = tonumber(link:match("item:(%d+)"))
    if id then
        Supply.AddItem(id)
        box:SetText("")
    end
end

-- Shift-Klick auf Items abfangen (einmal, beim Aufbau der Einstellungen); nur vorhandene Funktionen
function Supply.HookLinks()
    if Supply.hooked or type(hooksecurefunc) ~= "function" then return end
    Supply.hooked = true
    if type(ChatEdit_InsertLink) == "function" then pcall(hooksecurefunc, "ChatEdit_InsertLink", Supply.OnLink) end
    if type(HandleModifiedItemClick) == "function" then
        pcall(hooksecurefunc, "HandleModifiedItemClick", Supply.OnLink)
    end
end

-- Item auf das Feld gezogen (OnReceiveDrag/OnMouseUp): Item vom Mauszeiger übernehmen
function Supply.OnDrop()
    if type(GetCursorInfo) ~= "function" then return end
    local ok, kind, id = pcall(GetCursorInfo)
    if not ok or IsSecret(kind) or kind ~= "item" or IsSecret(id) or type(id) ~= "number" then return end
    Supply.AddItem(id)
    if type(ClearCursor) == "function" then pcall(ClearCursor) end
end

-- Ammo-Slot (GetInventorySlotInfo "AmmoSlot", Rückfall 0)
function Supply.AmmoSlot()
    if Supply.ammoSlot then return Supply.ammoSlot end
    local slot = 0
    if type(GetInventorySlotInfo) == "function" then
        local ok, s = pcall(GetInventorySlotInfo, "AmmoSlot")
        if ok and type(s) == "number" and not IsSecret(s) then slot = s end
    end
    Supply.ammoSlot = slot
    return slot
end

-- Angelegte Munition: Item-ID, false = keine angelegt, nil = nicht lesbar
function Supply.AmmoItem()
    if type(GetInventoryItemID) ~= "function" then return nil end
    local ok, id = pcall(GetInventoryItemID, "player", Supply.AmmoSlot())
    if not ok or IsSecret(id) then return nil end
    if type(id) ~= "number" then return false end
    return id
end

-- Mindestmenge und Grenzen (min, max, Ziffern) eines Vorrats-Eintrags (auch Reagenzien)
function Supply.Range(e)
    if e.kind == "reagent" then return 0, 50 end
    if e.supplyType == "item" then return 1, 999 end
    return 0, e.max
end

function Supply.Threshold(e)
    if e.kind == "reagent" then return ReagentThreshold(e.item) end
    local v
    if e.supplyType == "item" then v = cdb.supplies[e.item] or Supply.ITEM_DEFAULT else v = cdb[e.field] or e.def end
    local lo, hi = Supply.Range(e)
    return math.max(lo, math.min(hi, math.floor(tonumber(v) or e.def or Supply.ITEM_DEFAULT)))
end

function Supply.SetThreshold(e, n)
    local lo, hi = Supply.Range(e)
    n = math.max(lo, math.min(hi, math.floor(n)))
    if e.kind == "reagent" then
        cdb.reagents[e.item] = n
    elseif e.supplyType == "item" then
        cdb.supplies[e.item] = n
    else
        cdb[e.field] = n
    end
end

-- Aktiv? (Schwelle > 0; Tierfutter zusätzlich eigener Schalter, Standard aus)
function Supply.Enabled(e)
    if e.supplyType == "petfood" and cdb.buffs[e.key] ~= true then return false end
    return Supply.Threshold(e) > 0
end

-- Anzahl in den Taschen; nil = nicht lesbar (Tierfutter: kein Jägertier da / Daten fehlen noch)
function Supply.Count(e)
    if e.kind == "reagent" then return ItemCount(e.item) end
    local t = e.supplyType
    if t == "ammo" then
        local id = Supply.AmmoItem()
        if not id then return nil end
        return ItemCount(id)
    end
    if t == "petfood" then
        if Pet.Guid() == nil or Pet.IsHunterPet() ~= true then return nil end
        local f = Pet.Food()
        if f.unknown or (f.pending and f.total == 0) then return nil end
        return f.total
    end
    return ItemCount(e.item)
end

-- true = zu wenig (bzw. keine Munition angelegt), false = genug, nil = nicht lesbar
function Supply.Missing(e)
    e.noAmmo = nil
    if e.supplyType == "ammo" then
        local id = Supply.AmmoItem()
        if id == nil then return nil end
        if id == false then
            e.noAmmo, e.count = true, 0
            return true
        end
    end
    local n = Supply.Count(e)
    if n == nil then return nil end
    e.count = n
    return n < Supply.Threshold(e)
end

function Supply.Label(e)
    local t = e.supplyType
    if t == "ammo" then
        local id = Supply.AmmoItem()
        return id and ItemName(id) or L.SUPPLY_AMMO
    end
    if t == "petfood" then return L.SUPPLY_PETFOOD end
    return ItemName(e.item)
end

function Supply.Icon(e)
    local t = e.supplyType
    if t == "ammo" then
        local id = Supply.AmmoItem()
        return (id and ItemIcon(id)) or Supply.AMMO_ICON
    end
    if t == "petfood" then return SpellIcon(Pet.FEED) or FALLBACK_ICON end
    return ItemIcon(e.item) or FALLBACK_ICON
end

-- Zeilentext ("Name: 3 übrig" bzw. "Keine Munition angelegt")
function Supply.Text(e)
    if e.noAmmo then return L.SUPPLY_NOAMMO end
    return L.REAGENT_LOW:format(Supply.Label(e), e.count or 0)
end

function Supply.ChatText(e)
    if e.noAmmo then return L.ALERT_CHAT:format(L.SUPPLY_NOAMMO) end
    return L.SUPPLY_CHAT:format(Supply.Label(e), e.count or 0)
end

---------------------------------------------------------------------------
-- Vorräte mit Ortsbezug ("bis zur nächsten Stadt") und kritischer Grenze
--   Linksklick auf eine Vorratszeile (Reagenz oder Vorrat) außerhalb eines Ruhebereichs stellt den
--   Eintrag zurück: cdb.supplySnooze[key] = true (pro Charakter). Die Zeile verschwindet (im Kampf
--   erst danach). Aufgehoben für alle Einträge im Ruhebereich (IsResting), bei offenem Händler oder
--   offener Bank; wieder erscheinende Einträge meldet eine gemeinsame Chatzeile (Supply.Unsnooze),
--   ohne Einzelmeldung und Ton (Supply.returning). Im Ruhebereich / bei Händler oder Bank tut der
--   Linksklick (noch) nichts.
--   Kritische Grenze pro Eintrag (cdb.supplyCritical[key]; Standard Munition 50, Seelensplitter 1,
--   sonst 0 = aus; immer < Mindestmenge): darunter gilt die Zurückstellung nicht.
--   Munition im Kampf: sichtbare Zeile zählt live mit (Display.TickSupplies); fällt sie unter die
--   kritische Grenze, einmal eine rote Meldung in der Bildschirmmitte + Warnton (Supply.AmmoAlert).
---------------------------------------------------------------------------
Supply.returning = {}   -- Key -> true: kommt nach Aufheben der Zurückstellung wieder (keine Einzelmeldung)
Supply.EVENTS = {
    PLAYER_UPDATE_RESTING = true, MERCHANT_SHOW = true, MERCHANT_CLOSED = true,
    BANKFRAME_OPENED = true, BANKFRAME_CLOSED = true,
    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = true, PLAYER_INTERACTION_MANAGER_FRAME_HIDE = true,
}

function Supply.IsSupply(e)
    return e ~= nil and (e.kind == "reagent" or e.kind == "supply")
end

function Supply.Resting()
    if type(IsResting) ~= "function" then return false end
    local ok, r = pcall(IsResting)
    return ok and not IsSecret(r) and r == true
end

-- Ruhebereich oder Händler/Bank offen: hier wird aufgefüllt statt zurückgestellt
function Supply.InTown()
    return Supply.atVendor == true or Supply.Resting()
end

function Supply.CriticalDefault(e)
    if e.supplyType == "ammo" then return 50 end
    if e.supplyType == "shards" then return 1 end
    return 0
end

-- Kritische Grenze (0 = aus), höchstens Mindestmenge - 1
function Supply.Critical(e)
    local v = cdb and cdb.supplyCritical[e.key]
    if v == nil then v = Supply.CriticalDefault(e) end
    v = math.floor(tonumber(v) or 0)
    return math.max(0, math.min(v, Supply.Threshold(e) - 1))
end

function Supply.SetCritical(e, n)
    cdb.supplyCritical[e.key] = math.max(0, math.min(math.floor(n), Supply.Threshold(e) - 1))
end

-- Zielmenge "Auffüllen auf" (Fenster "Auffüllen"; nicht für Tierfutter): cdb.supplyRefill[key],
-- Standard doppelte Mindestmenge (Munition Restock.AMMO_TARGET); mindestens Min., höchstens
-- Restock.MAX_TARGET
function Supply.RefillDefault(e)
    if e.supplyType == "ammo" then return Restock.AMMO_TARGET end
    return Supply.Threshold(e) * 2
end

function Supply.Refill(e)
    local v = cdb and cdb.supplyRefill[e.key]
    if v == nil then v = Supply.RefillDefault(e) end
    v = math.floor(tonumber(v) or 0)
    return math.max(Supply.Threshold(e), math.min(Restock.MAX_TARGET, v))
end

function Supply.SetRefill(e, n)
    cdb.supplyRefill[e.key] = math.max(Supply.Threshold(e), math.min(Restock.MAX_TARGET, math.floor(n)))
end

function Supply.BelowCritical(e)
    local c = Supply.Critical(e)
    return c > 0 and (e.count or 0) < c
end

-- Zeile ausblenden? (zurückgestellt und nicht unter der kritischen Grenze)
function Supply.Hidden(e)
    return Supply.IsSupply(e) and cdb.supplySnooze[e.key] == true and not Supply.BelowCritical(e)
end

-- Neue Zeile ohne Chatzeile und Ton? (zurückgestellt bzw. gerade aus der Zurückstellung zurück)
function Supply.Quiet(e)
    if not Supply.IsSupply(e) then return false end
    if Supply.returning[e.key] then
        Supply.returning[e.key] = nil
        return true
    end
    return cdb.supplySnooze[e.key] == true
end

-- Linksklick (PostClick, Aktionsphase): Händler offen und Auffüllen an -> Fenster "Auffüllen";
-- sonst außerhalb der Stadt zurückstellen; in der Stadt nichts
function Supply.OnClick(e)
    if Restock.Available() then Restock.Open(false); return end
    if Supply.InTown() then return end
    cdb.supplySnooze[e.key] = true
    if not InCombatLockdown() then ns.Evaluate() end   -- im Kampf wirkt es nach dem Kampf
end

-- Zurückstellung für alle aufheben; wieder fällige Einträge in einer Chatzeile melden
function Supply.Unsnooze()
    if not (State.ready and cdb and next(cdb.supplySnooze)) then return end
    local parts = {}
    for _, e in ipairs(entries) do
        if cdb.supplySnooze[e.key] and Supply.IsSupply(e) and not shownKeys[e.key] and knownCache[e.key]
            and IsEnabled(e) and not MuteRemaining(e.key) and CheckMissing(e) == true then
            Supply.returning[e.key] = true
            parts[#parts + 1] = e.noAmmo and L.SUPPLY_NOAMMO
                or ("%s %d/%d"):format(EntryLabel(e), e.count or 0, Supply.Threshold(e))
        end
    end
    wipe(cdb.supplySnooze)
    if #parts > 0 then Print(L.SUPPLY_BACK:format(table.concat(parts, ", "))) end
end

-- PLAYER_LOGIN: Ruhebereich-, Händler- und Bank-Events (reg = SafeRegisterEvent)
function Supply.RegisterEvents(frame, reg)
    for event in pairs(Supply.EVENTS) do reg(frame, event) end
end

-- Ruhebereich betreten/verlassen, Händler/Bank geöffnet/geschlossen (danach Evaluate)
function Supply.OnEvent(event, kind)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local t = Enum and Enum.PlayerInteractionType
        if type(t) ~= "table" or type(kind) ~= "number" or IsSecret(kind)
            or (kind ~= t.Merchant and kind ~= t.Banker) then
            return
        end
        event = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and "MERCHANT_SHOW" or "MERCHANT_CLOSED"
    end
    if event == "MERCHANT_SHOW" or event == "BANKFRAME_OPENED" then
        Supply.atVendor = true
        Supply.Unsnooze()
    elseif event == "MERCHANT_CLOSED" or event == "BANKFRAME_CLOSED" then
        Supply.atVendor = false
    elseif Supply.Resting() then
        Supply.Unsnooze()
    end
end

-- Was der Linksklick gerade tut (Tooltip)
function Supply.ClickText()
    if Restock.Available() then return L.LEFTCLICK_RESTOCK end
    return Supply.InTown() and L.SUPPLY_RESTOCK or L.LEFTCLICK_SNOOZE
end

-- Text der Zeile (auch im Kampf: nur FontStrings)
function Supply.SetRowText(r, e, st)
    if st.rightText and not e.noAmmo then
        r.text:SetText(Supply.Label(e))
        r.right:SetText(tostring(e.count or 0))
    else
        r.text:SetText(Supply.Text(e))
    end
end

-- Warnzeile füllen (aus Display.ShowRows; nur außerhalb des Kampfes): keine Secure-Aktion, der
-- Linksklick läuft über PostClick (Supply.OnClick)
function Supply.FillRow(r, e, st)
    Display.SetRowLines(r, false)
    Display.SetRowAction(r, nil)
    Display.SetRowStatus(r, e.noAmmo and "missing" or "low")
    Supply.SetRowText(r, e, st)
    local hint = Supply.InTown() and L.HINT_RESTOCK or L.HINT_SNOOZE
    if Restock.Available() then hint = L.HINT_RESTOCK_CLICK end
    Display.SetRowHint(r, hint)
end

-- Munition unter der kritischen Grenze: im Kampf einmal rote Meldung + Warnton; erst wieder,
-- nachdem die Menge zwischendurch darüber lag. Außerhalb des Kampfes nur der Zustand.
function Supply.AmmoAlert(combat)
    local e = Supply.ammoEntry
    if not e or not knownCache[e.key] or not IsEnabled(e) or MuteRemaining(e.key) or e.count == nil then return end
    local crit = Supply.Critical(e)
    if not (crit > 0 and e.count < crit) then
        Supply.ammoAlerted = false
        return
    end
    if Supply.ammoAlerted then return end
    Supply.ammoAlerted = true
    if not combat then return end
    local text = L.SUPPLY_AMMO_CRITICAL:format(Supply.Label(e), e.count)
    local f = UIErrorsFrame
    if not (type(f) == "table" and type(f.AddMessage) == "function" and pcall(f.AddMessage, f, text, 1, 0.1, 0.1)) then
        Print(text)
    end
    Sound.Play(db.sound)
end

-- GET_ITEM_INFO_RECEIVED: Name/Icon eines eigenen Items bzw. der Munition nachgeladen
function Supply.OnItemInfo(id)
    if not (Supply.items[id] or id == Pet.SOUL_SHARD) then return false end
    ns.Evaluate()
    if not State.ready then ns.RefreshConfig() end   -- Evaluate tut vor ready nichts
    return true
end
