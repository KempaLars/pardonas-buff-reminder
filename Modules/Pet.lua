-- Pardona's Buff Reminder – Tier-Erinnerung: Jäger-Tier (fehlt/tot/füttern), Hexenmeister-Dämon (expPet).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Items = ns.Items
local Group = ns.Group
local Display = ns.Display
local Variant = ns.Variant
local Pet = ns.Pet
local entries = ns.entries
local IsSecret = ns.IsSecret
local SpellName = ns.SpellName
local SpellIcon = ns.SpellIcon
-- aus Data.lua
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemCount = ns.ItemCount
-- aus Detect.lua
local PrepareEntry = ns.PrepareEntry
local SpellKnown = ns.SpellKnown
local ScanAuras = ns.ScanAuras
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Tier-Erinnerung (experimentell, Schalter expPet), Reiter "Tier"
-- Einträge kind = "pet", petType = "missing" | "dead" | "feed" (Jäger) bzw. "demon" (Hexenmeister);
-- Einzelschalter pro Charakter in cdb.buffs (Standard an). Alle Spiel-APIs abgesichert (type-Prüfung,
-- pcall); unlesbare Werte (Fehler, Secret) -> nil = Zustand beibehalten, keine neue Zeile.
--   Jäger : Tier rufen 883, Tier wiederbeleben 982, Tier füttern 6991, Fress-Effekt 1539 (Aura auf "pet")
--           Laune: C_PetInfo.GetPetHappiness() 1 = unglücklich, 2 = zufrieden, 3 = glücklich
--           Futter: Taschen-Items mit C_PetInfo.CanPetEatItem = true, nicht gesperrt; Reihenfolge
--           Tierfutter-Favoriten (cdb.petFavorites), höchste Itemstufe, kleinerer Stapel
--           Füttern: Secure-Aktion "spell" 6991 + target-bag/target-slot (nur per echtem Klick);
--           PreClick sucht außerhalb des Kampfes den Taschenplatz neu (Pet.PreClick).
--   Hexer : Linksklick beschwört cdb.demon (eigene Wahl), sonst cdb.lastDemon (zuletzt beschworen),
--           sonst den Wichtel; ohne Seelensplitter (6265) springt der Wichtel ein.
---------------------------------------------------------------------------
Pet.CALL, Pet.REVIVE, Pet.FEED, Pet.FEED_AURA = 883, 982, 6991, 1539
Pet.SOUL_SHARD, Pet.IMP = 6265, 688
Pet.DEMONS = { 688, 697, 712, 691, 30146 }   -- Wichtel, Leerwandler, Sukkubus, Teufelsjäger, Teufelswache
Pet.DEFS = {
    HUNTER = {
        { key = "pet_missing", kind = "pet", petType = "missing", level = 10, knownIds = { 883 },
          label = "PET_MISSING", icon = 883, petMenu = true },
        { key = "pet_dead", kind = "pet", petType = "dead", level = 10, knownIds = { 883, 982 },
          label = "PET_DEAD", icon = 982 },
        { key = "pet_feed", kind = "pet", petType = "feed", level = 10, knownIds = { 6991 },
          label = "PET_FEED", icon = 6991, itemKind = "petfood" },
    },
    WARLOCK = {
        { key = "pet_demon", kind = "pet", petType = "demon", level = 1, knownIds = Pet.DEMONS,
          label = "PET_DEMON", icon = 688, petMenu = true },
    },
}
Pet.entries = {}      -- Einträge der eigenen Klasse (auch in entries)
Pet.food = { list = {}, total = 0 }   -- letzter Futter-Scan (Pet.ScanFood)
Pet.foodDirty = true  -- Taschen/Tier/Favoriten geändert: beim nächsten Zugriff neu scannen
Pet.waiting = {}      -- Item-ID -> true: Item-Daten angefordert (GET_ITEM_INFO_RECEIVED)

-- PLAYER_LOGIN: Einträge der Klasse anlegen
function Pet.Setup(class)
    Pet.class = class
    for _, e in ipairs(Pet.DEFS[class] or {}) do
        PrepareEntry(e)
        Pet.entries[#Pet.entries + 1] = e
        entries[#entries + 1] = e
    end
end

function Pet.HasClass()
    return Pet.DEFS[Pet.class or ""] ~= nil
end

-- Events der Klasse registrieren (reg = SafeRegisterEvent)
function Pet.RegisterEvents(frame, reg)
    if not Pet.HasClass() then return end
    reg(frame, "UNIT_PET", "player")
    if Pet.class == "HUNTER" then
        reg(frame, "UNIT_HAPPINESS", "pet")
        reg(frame, "UNIT_POWER_UPDATE", "pet")
    end
end

-- UNIT_PET, UNIT_HAPPINESS, UNIT_POWER_UPDATE (nur Laune)
function Pet.OnEvent(event, unit, powerType)
    if event == "UNIT_POWER_UPDATE" and (IsSecret(powerType) or powerType ~= "HAPPINESS") then return end
    if event == "UNIT_PET" then Pet.foodDirty = true end
    ns.Evaluate()
end

-- GET_ITEM_INFO_RECEIVED: angeforderte Item-Daten da -> Futter neu bewerten
function Pet.OnItemInfo(id)
    if Pet.waiting[id] then
        Pet.waiting[id] = nil
        Pet.foodDirty = true
    end
end

function Pet.IsDemon(id)
    if type(id) ~= "number" or IsSecret(id) then return false end
    for _, d in ipairs(Pet.DEMONS) do
        if d == id then return true end
    end
    return false
end

-- UNIT_SPELLCAST_SUCCEEDED des Spielers: zuletzt beschworenen Dämon merken
function Pet.RememberCast(spellID)
    if cdb and Pet.class == "WARLOCK" and Pet.IsDemon(spellID) then cdb.lastDemon = spellID end
end

-- Zustand des Begleiters: "none" | "dead" | "alive"; nil = nicht lesbar
function Pet.State()
    local exists = Group.UnitFlag(UnitExists, "pet")
    if exists == nil then return nil end
    if not exists then return "none" end
    local dead = Group.UnitFlag(UnitIsDeadOrGhost, "pet")
    if dead == nil then return nil end
    return dead and "dead" or "alive"
end

function Pet.Mounted()
    return Group.UnitFlag(IsMounted) == true
end

function Pet.Guid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, g = pcall(UnitGUID, "pet")
    if not ok or IsSecret(g) then return nil end
    return g
end

-- Laune 1-3; nil = nicht lesbar
function Pet.Happiness()
    local fn = C_PetInfo and C_PetInfo.GetPetHappiness
    if type(fn) ~= "function" then return nil end
    local ok, h = pcall(fn)
    if not ok or IsSecret(h) or type(h) ~= "number" then return nil end
    return h
end

-- Jägertier? (HasPetUI, 2. Rückgabewert); nil = nicht lesbar
function Pet.IsHunterPet()
    if type(HasPetUI) ~= "function" then return nil end
    local ok, has, hunter = pcall(HasPetUI)
    if not ok or IsSecret(has) or IsSecret(hunter) then return nil end
    return (has and hunter) and true or false
end

-- Fress-Effekt auf dem Tier aktiv?; nil = nicht lesbar
function Pet.IsEating()
    local name = SpellName(Pet.FEED_AURA)
    local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if name and type(fn) == "function" then
        local ok, a = pcall(fn, "pet", name, "HELPFUL")
        if not ok or IsSecret(a) then return nil end
        return a ~= nil
    end
    local ids, names, unreliable = ScanAuras("pet")
    if not ids then return nil end
    if ids[Pet.FEED_AURA] or (name and names[name]) then return true end
    if unreliable then return nil end
    return false
end

-- Zauber auf Abklingzeit (ohne globale Abklingzeit)?; nil = nicht lesbar
function Pet.OnCooldown(spell)
    local fn = C_Spell and C_Spell.GetSpellCooldown
    if type(fn) ~= "function" then return false end
    local ok, cd = pcall(fn, spell)
    if not ok or IsSecret(cd) then return nil end
    if type(cd) ~= "table" then return false end
    local start, dur = cd.startTime, cd.duration
    if IsSecret(start) or IsSecret(dur) then return nil end
    if type(start) ~= "number" or type(dur) ~= "number" then return false end
    return start > 0 and dur > 1.5 and start + dur > GetTime()
end

-- Ernährung des Tiers als Text (Tooltip); nil = nicht lesbar
function Pet.Diet()
    local fn = C_PetInfo and C_PetInfo.GetPetFoodTypes
    if type(fn) ~= "function" then return nil end
    local res = { pcall(fn) }
    if not res[1] then return nil end
    local src = res[2]
    if type(src) ~= "table" or IsSecret(src) then src = { select(2, unpack(res)) } end
    local names = {}
    for _, v in ipairs(src) do
        if type(v) == "string" and not IsSecret(v) and v ~= "" then names[#names + 1] = v end
    end
    if #names == 0 then return nil end
    return table.concat(names, ", ")
end

-- Kann das Tier das Item fressen? Rückgabe: Eintrag { id, count, ilvl } bzw. false; nicht geladene
-- Items werden angefordert und markieren den Scan als unvollständig (f.pending)
function Pet.EdibleInfo(id, canEat, f)
    local ilvl = Items.ItemLevels(id)
    if ilvl == nil then
        f.pending = true
        Pet.waiting[id] = true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    local ok, yes = pcall(canEat, id)
    if not ok or IsSecret(yes) then
        f.pending = true
        return false
    end
    if yes ~= true then return false end
    return { id = id, count = 0, ilvl = type(ilvl) == "number" and ilvl or 0 }
end

function Pet.SortFood(a, b)
    if a.fav ~= b.fav then return a.fav end
    if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
    if a.count ~= b.count then return a.count < b.count end
    return a.id < b.id
end

-- Taschen nach Futter für das aktuelle Tier durchsuchen: je Item Anzahl und kleinster nicht
-- gesperrter Stapel (bag/slot). f.unknown = APIs fehlen, f.pending = Item-Daten fehlen noch
function Pet.ScanFood()
    local f = { list = {}, total = 0, guid = Pet.Guid() }
    Pet.food, Pet.foodDirty = f, false
    local canEat = C_PetInfo and C_PetInfo.CanPetEatItem
    if type(canEat) ~= "function" or not (C_Container and C_Container.GetContainerNumSlots
        and C_Container.GetContainerItemInfo) then
        f.unknown = true
        return f
    end
    local last = (type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" and NUM_TOTAL_EQUIPPED_BAG_SLOTS)
        or NUM_BAG_SLOTS or 4
    local byId, favs = {}, cdb and cdb.petFavorites or {}
    for bag = 0, last do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and type(slots) == "number" and not IsSecret(slots) then
            for slot = 1, slots do
                local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok and type(info) == "table" and not IsSecret(info) then
                    local id, n, locked = info.itemID, info.stackCount or 1, info.isLocked
                    if type(id) == "number" and not IsSecret(id) and type(n) == "number" and not IsSecret(n)
                        and not IsSecret(locked) then
                        local c = byId[id]
                        if c == nil then
                            c = Pet.EdibleInfo(id, canEat, f)
                            byId[id] = c
                        end
                        if c then
                            c.count = c.count + n
                            f.total = f.total + n
                            if not locked and (not c.stack or n < c.stack) then c.bag, c.slot, c.stack = bag, slot, n end
                        end
                    end
                end
            end
        end
    end
    for id, c in pairs(byId) do
        if c and c.bag then
            c.fav = favs[id] == true
            f.list[#f.list + 1] = c
        end
    end
    table.sort(f.list, Pet.SortFood)
    return f
end

-- Futter (zwischengespeichert; neu nach Taschen-, Tier- oder Favoritenwechsel)
function Pet.Food()
    if Pet.foodDirty or Pet.food.guid ~= Pet.Guid() then return Pet.ScanFood() end
    return Pet.food
end

-- Gewünschter Dämon: eigene Wahl (cdb.demon), sonst zuletzt beschworen (cdb.lastDemon), sonst der
-- erste erlernte (Wichtel); jeweils nur erlernte. nil = keiner erlernt
function Pet.WantedDemon()
    for _, id in ipairs({ cdb.demon or false, cdb.lastDemon or false }) do
        if Pet.IsDemon(id) and SpellKnown(id) then return id end
    end
    for _, id in ipairs(Pet.DEMONS) do
        if SpellKnown(id) then return id end
    end
    return nil
end

-- Zauber des Linksklicks; 2. Wert true = Wichtel statt des gewünschten Dämons (kein Seelensplitter)
function Pet.DemonSpell()
    local want = Pet.WantedDemon()
    if want and want ~= Pet.IMP and ItemCount(Pet.SOUL_SHARD) == 0 and SpellKnown(Pet.IMP) then
        return Pet.IMP, true
    end
    return want, false
end

-- true = Zeile zeigen, false = nicht, nil = unbekannt (Zustand beibehalten).
-- Feed: e.noFood = kein passendes Futter (Zeile "Kein Tierfutter" ohne Klick-Aktion)
function Pet.Missing(e)
    local t, s = e.petType, Pet.State()
    if s == nil then return nil end
    if t == "dead" then return s == "dead" end
    if t == "missing" or t == "demon" then
        if t == "missing" and s ~= "none" then return false end
        if t == "demon" and s == "alive" then return false end
        -- beritten: Tier kann ausgeblendet sein; bestehende Warnung bleibt, neue entsteht nicht
        if Pet.Mounted() then return nil end
        return true
    end
    -- Füttern
    e.noFood = nil
    if s ~= "alive" or Pet.IsHunterPet() == false then return false end
    local h = Pet.Happiness()
    if h == nil then return nil end
    if h > ((cdb.petUnhappyOnly == true) and 1 or 2) then return false end
    if InCombatLockdown() or Group.UnitFlag(UnitAffectingCombat, "player")
        or Group.UnitFlag(UnitAffectingCombat, "pet") or Pet.Mounted() then
        return false
    end
    local eating = Pet.IsEating()
    if eating == nil then return nil end
    if eating then return false end
    local cd = Pet.OnCooldown(Pet.FEED)
    if cd == nil then return nil end
    if cd then return false end
    local food = Pet.Food()
    if #food.list == 0 then
        if food.pending or food.unknown then return nil end
        if cdb.petNoFoodWarn == false then return false end
        e.noFood = true
    end
    return true
end

-- Klick-Aktion einer Tier-Zeile (Zeile und Taste "Oberste Warnung"); nil = keine
function Pet.Action(e)
    if not db.clickCast then return nil end
    local t = e.petType
    if t == "missing" then return SpellKnown(Pet.CALL) and { spell = Pet.CALL, noUnit = true } or nil end
    if t == "dead" then return SpellKnown(Pet.REVIVE) and { spell = Pet.REVIVE, noUnit = true } or nil end
    if t == "demon" then
        local id = Pet.DemonSpell()
        return id and { spell = id, noUnit = true } or nil
    end
    if t == "feed" and not e.noFood then
        local c = Pet.Food().list[1]
        if c then
            return { spell = Pet.FEED, noUnit = true, targetBag = c.bag, targetSlot = c.slot, feedItem = c.id }
        end
    end
    return nil
end

function Pet.Text(e)
    if e.petType == "feed" and e.noFood then return L.PET_NOFOOD end
    return L[e.label]
end

function Pet.Icon(e)
    local id = e.icon
    if e.petType == "demon" then id = Pet.DemonSpell() or Pet.IMP end
    return SpellIcon(id) or FALLBACK_ICON
end

-- Warnzeile füllen (aus Display.ShowRows; nur außerhalb des Kampfes)
function Pet.FillRow(r, e)
    local a = Pet.Action(e)
    Display.SetRowLines(r, false)
    Display.SetRowAction(r, a)
    Display.SetRowStatus(r, "missing")
    r.text:SetText(Pet.Text(e))
    local hint
    if e.petType == "feed" then
        hint = a and L.HINT_ITEM:format(ItemName(a.feedItem)) or L.HINT_MUTE
    elseif e.petType == "demon" and a and select(2, Pet.DemonSpell()) then
        hint = L.HINT_DEMON_IMP:format(SpellName(Pet.IMP) or "?")
    elseif a then
        hint = Variant.MenuOn(e) and L.HINT_CAST_CHOOSE or L.HINT_CAST
    else
        hint = Variant.MenuOn(e) and L.HINT_CHOOSE or L.HINT_MUTE
    end
    Display.SetRowHint(r, hint)
end

-- Tooltip-Zeilen einer Tier-Zeile (nach dem Titel)
function Pet.AddTooltip(btn)
    local e, a = btn.entry, btn.action
    if e.petType == "feed" then
        local h = Pet.Happiness()
        if h then GameTooltip:AddLine(L.PET_MOOD:format(ns.Locales.Text("PET_HAPPY_" .. h, "?")), 1, 1, 1) end
        local diet = Pet.Diet()
        if diet then GameTooltip:AddLine(L.PET_DIET:format(diet), 1, 1, 1, true) end
        if a and a.feedItem then GameTooltip:AddLine(L.LEFTCLICK_FEED:format(ItemName(a.feedItem)), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(L.RIGHTCLICK_CHOOSE, 0.8, 0.8, 0.8)
        return
    end
    if a and a.spell then GameTooltip:AddLine(L.LEFTCLICK_SPELL:format(SpellName(a.spell) or "?"), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(Variant.MenuOn(e) and L.RIGHTCLICK_CHOOSE or L.RIGHTCLICK, 0.8, 0.8, 0.8)
end

-- Rechtsklick-Menü (Variantenmenü): Tier rufen / wiederbeleben bzw. erlernte Dämonen
function Pet.MenuChoices(e)
    local ids = e.petType == "demon" and Pet.DEMONS or { Pet.CALL, Pet.REVIVE }
    local cur = e.petType == "demon" and Pet.WantedDemon() or nil
    local list = {}
    for _, id in ipairs(ids) do
        if SpellKnown(id) then
            list[#list + 1] = { spell = id, vkey = tostring(id), name = SpellName(id) or tostring(id),
                icon = SpellIcon(id) or FALLBACK_ICON, last = id == cur }
        end
    end
    return list
end

function Pet.MenuHead(e)
    return e.petType == "demon" and L.PET_DEMON_LABEL or L.MENU_VARIANT
end

-- Auswahl im Menü: Dämon wird zur eigenen Wahl (Tier rufen/wiederbeleben: nur zaubern)
function Pet.Picked(e, vkey)
    if e.petType == "demon" and Pet.IsDemon(tonumber(vkey)) then cdb.demon = tonumber(vkey) end
end

-- Vor dem Klick (nur außerhalb des Kampfes): Taschenplatz des Futters neu ermitteln, damit
-- Sortieren, Verschieben oder Aufbrauchen nie einen alten Platz füttert. suffix "1" = Warnzeile/
-- Taste (gleiches Item, sonst neue erste Wahl), "" = Item-Menü (nur dasselbe Item).
-- Passt nichts mehr: Aktion leeren (der Klick tut nichts).
function Pet.Retarget(btn, suffix, itemID, anyFood)
    Pet.foodDirty = true
    local list, pick = Pet.Food().list, nil
    for _, c in ipairs(list) do
        if c.id == itemID then pick = c; break end
    end
    if not pick and anyFood then pick = list[1] end
    btn.actionSig = nil   -- Display.SetRowAction setzt beim nächsten Mal alle Attribute neu
    if pick then
        btn:SetAttribute("type" .. suffix, "spell")
        btn:SetAttribute("spell" .. suffix, Pet.FEED)
        btn:SetAttribute("target-bag" .. suffix, pick.bag)
        btn:SetAttribute("target-slot" .. suffix, pick.slot)
    else
        for _, k in ipairs({ "type", "spell", "target-bag", "target-slot" }) do btn:SetAttribute(k .. suffix, nil) end
    end
end

-- PreClick von Warnzeile und Taste
function Pet.PreClick(btn, button)
    if button ~= "LeftButton" or InCombatLockdown() then return end
    local a = btn.action
    if a and a.feedItem then Pet.Retarget(btn, "1", a.feedItem, true) end
end

-- Dropdown "Zu beschwörender Dämon": automatisch (zuletzt beschworen) + erlernte Dämonen
function Pet.DemonOptions()
    local list = { { value = "auto", text = L.PET_DEMON_AUTO } }
    for _, id in ipairs(Pet.DEMONS) do
        if SpellKnown(id) then list[#list + 1] = { value = id, text = SpellName(id) or tostring(id) } end
    end
    return list
end

function Pet.DemonText()
    if Pet.IsDemon(cdb.demon) then return SpellName(cdb.demon) or tostring(cdb.demon) end
    local id = Pet.WantedDemon()
    return id and L.TRACK_AUTO:format(SpellName(id) or tostring(id)) or L.PET_DEMON_AUTO
end
