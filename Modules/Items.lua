-- Pardona's Buff Reminder – Items: Name/Icon/Anzahl, Reagenz-Schwellen; Essen & Fläschchen (Taschen-Scan,
-- Auswahl, Sortierung) und Ess-Countdown.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Eat = ns.Eat
local Scroll = ns.Scroll
local Pet = ns.Pet
local NormName = ns.NormName
local IsSecret = ns.IsSecret
local ExpOn = ns.ExpOn
local SpellName = ns.SpellName
-- aus Data.lua
local REAGENT_INFO = ns.REAGENT_INFO
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Items (Reagenzien)
---------------------------------------------------------------------------
local function ItemName(item)
    if C_Item and C_Item.GetItemNameByID then
        local ok, n = pcall(C_Item.GetItemNameByID, item)
        if ok and n and not IsSecret(n) then return n end
    end
    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, item)
        if ok and n and not IsSecret(n) then return n end
    end
    -- noch nicht im Cache: Laden anstoßen (GET_ITEM_INFO_RECEIVED aktualisiert die Anzeige)
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
    return REAGENT_INFO[item] and REAGENT_INFO[item].name or tostring(item)
end

local function ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, item)
        if ok and t and not IsSecret(t) then return t end
    end
    if GetItemIcon then
        local ok, t = pcall(GetItemIcon, item)
        if ok and t and not IsSecret(t) then return t end
    end
end

-- Anzahl nur in den Taschen (ohne Bank), nil = nicht lesbar
local function ItemCount(item)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return nil end
    local ok, n = pcall(fn, item, false, false, false, false)
    if not ok or n == nil or IsSecret(n) then return nil end
    return n
end

local function ReagentThreshold(item)
    local v = cdb and cdb.reagents and cdb.reagents[item]
    if v == nil then v = REAGENT_INFO[item] and REAGENT_INFO[item].default or 0 end
    return v
end

---------------------------------------------------------------------------
-- Essen & Fläschchen: Taschen-Inhalt, Auswahl und Sortierung
---------------------------------------------------------------------------
Items.bagCounts = {}      -- Item-ID -> Anzahl in den Taschen (Scan bei BAG_UPDATE_DELAYED)
Items.foodScore = {}      -- Item-ID -> Kategorie-Gewicht x Kochkunst-Stufe (Klasse des Spielers)
Items.foodCat = {}        -- Item-ID -> FOOD-Kategorie mit dem höchsten Score (Anzeige im Menü)
Items.xpCache = {}        -- Item-ID -> true/false: Tooltip nennt XP-Bonus (nur geladene Items)
Items.foodWeights = {}    -- FOOD-Kategorie -> Gewicht für die Klasse des Spielers (BuildFoodScores)
Items.foodDetect = {}     -- Item-ID -> false | { score, cat }: Buff-Essen außerhalb von FOOD (DetectFood)
Items.foodPending = {}    -- Item-ID -> true: Daten für DetectFood angefordert, false: angekommen
Items.flaskBySpell = {}   -- Spell-ID des Fläschchen-Effekts -> Item-ID
State.flaskEntry = nil    -- Eintrag gen_flask (idSet wird zur Laufzeit ergänzt)
State.foodEntry = nil     -- Eintrag gen_wellfed (eatStart = Beginn des Essens, nil = isst nicht)

---------------------------------------------------------------------------
-- Ess-Countdown: Ess-Auren aller FOOD-Items (C_Item.GetItemSpell), unabhängig davon,
-- ob über die Warnung oder direkt aus der Tasche gegessen wird.
---------------------------------------------------------------------------
-- Well Fed kommt laut Item-Tooltip nach "at least 10 seconds" Essen
Eat.EAT_WELLFED_TIME = 10
Eat.eatSpells = {}      -- Spell-ID der Ess-Aura -> true
Eat.eatNames = {}       -- Name der Ess-Aura -> true (die Aura-ID kann vom Item-Spell abweichen)
Eat.eatNorm = {}        -- NormName(Name) -> true
Eat.eatPending = {}     -- Item-ID -> true: Item-Daten noch nicht geladen, Spell folgt
-- Eat.eatAura: zuletzt gefundene Ess-Aura { id, name } (für /br debug)
-- generische Auren, die Essen/Trinken anlegen (WoW Forever: "Food" 433)
Eat.EAT_GENERIC_AURAS = { 433, 430 }   -- Food, Drink

function Eat.AddEatName(name)
    if type(name) ~= "string" or name == "" or IsSecret(name) then return end
    Eat.eatNames[name] = true
    Eat.eatNorm[NormName(name)] = true
end

-- Ess-Aura eines Essens ermitteln und cachen; nicht geladene Items nachfordern
-- (GET_ITEM_INFO_RECEIVED ruft mit loaded = true erneut auf; hat das geladene Item
-- keinen Spell, wird es nicht erneut angefordert – keine Endlosschleife)
function Eat.ResolveEatSpell(item, loaded)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, spellName, spellID = pcall(C_Item.GetItemSpell, item)
    if ok and type(spellID) == "number" and not IsSecret(spellID) then
        Eat.eatSpells[spellID] = true
        Eat.AddEatName(spellName)
        Eat.eatPending[item] = nil
        return
    end
    if loaded then Eat.eatPending[item] = nil; return end
    Eat.eatPending[item] = true
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
end

function Eat.ResolveAllEatSpells()
    for _, id in ipairs(Eat.EAT_GENERIC_AURAS) do Eat.AddEatName(SpellName(id)) end
    for _, list in pairs(Items.FOOD) do
        for _, v in ipairs(list) do Eat.ResolveEatSpell(v[1]) end
    end
end

function Eat.IsEatAura(a)
    if a.id and Eat.eatSpells[a.id] then return true end
    local n = a.name
    if type(n) ~= "string" or IsSecret(n) then return false end
    return Eat.eatNames[n] == true or Eat.eatNorm[NormName(n)] == true
end

-- Startzeit einer aktiven Ess-Aura (expirationTime - duration), nil = isst nicht oder
-- Laufzeit nicht lesbar (Secret) -> normale Anzeige ohne Countdown
function Eat.FindEatStart(scan)
    Eat.eatAura = nil
    if not scan then return nil end
    for _, a in ipairs(scan.list) do
        if Eat.IsEatAura(a) then
            Eat.eatAura = { id = a.id, name = a.name }
            local dur, exp = a.duration, a.expirationTime
            if type(dur) == "number" and type(exp) == "number" and dur > 0 then return exp - dur end
            return nil
        end
    end
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Haupttext während des Essens
function Eat.EatText(e)
    local left = (e.eatStart or 0) + Eat.EAT_WELLFED_TIME - GetTime()
    if left > 0 then return L.EATING:format(math.ceil(left)) end
    return L.EATING_DONE
end

function Items.BuildFoodScores(class)
    local weights = {}
    for cat in pairs(Items.FOOD) do weights[cat] = Items.FOOD_WEIGHT_FIXED[cat] or Items.FOOD_WEIGHT_OTHER end
    for i, cat in ipairs(Items.FOOD_PRIORITY[class] or {}) do
        weights[cat] = Items.FOOD_WEIGHTS[i] or Items.FOOD_WEIGHT_OTHER
    end
    if Items.FOOD_HEALING_MIN[class] then
        weights.Healing = math.max(weights.Healing, Items.FOOD_HEALING_MIN[class])
    end
    Items.class = class   -- auch für die Rangfolge der Waffen-Items
    Items.foodWeights = weights
    wipe(Items.foodScore)
    wipe(Items.foodCat)
    wipe(Items.foodDetect)
    for cat, list in pairs(Items.FOOD) do
        for _, v in ipairs(list) do
            local score = weights[cat] * v[2]
            if not Items.foodScore[v[1]] or score > Items.foodScore[v[1]] then
                Items.foodScore[v[1]] = score
                Items.foodCat[v[1]] = cat
            end
        end
    end
end

-- Item-Level und benötigte Stufe (nil, falls das Item noch nicht geladen ist)
function Items.ItemLevels(item)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, name, _, _, ilvl, minLevel = pcall(fn, item)
    if not ok or not name or IsSecret(ilvl) or IsSecret(minLevel) then return nil end
    return ilvl, minLevel
end

-- Zahl aus einer parameterlosen API-Funktion; nil = Funktion fehlt, Fehler oder Secret-Wert
function Items.SafeNumber(fn)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn)
    if ok and type(v) == "number" and not IsSecret(v) then return v end
    return nil
end

-- Maximalstufe des Spielers; nil = nicht ermittelbar
function Items.MaxPlayerLevel()
    local max = Items.SafeNumber(GetMaxLevelForPlayerExpansion) or Items.SafeNumber(GetMaxPlayerLevel)
    if max then return max end
    if type(MAX_PLAYER_LEVEL) == "number" and not IsSecret(MAX_PLAYER_LEVEL) then return MAX_PLAYER_LEVEL end
    return nil
end

-- Zählt Erfahrung für den Spieler? Nicht bei Maximalstufe und nicht bei abgeschalteter
-- Erfahrung (IsXPUserDisabled). Ergebnis in Items.xpOn; neu bewertet bei Login,
-- PLAYER_LEVEL_UP (level = neue Stufe), ENABLE_XP_GAIN und DISABLE_XP_GAIN.
function Items.UpdateXP(level)
    local on = true
    if type(IsXPUserDisabled) == "function" then
        local ok, off = pcall(IsXPUserDisabled)
        if ok and not IsSecret(off) and off then on = false end
    end
    local lvl = level
    if type(lvl) ~= "number" or IsSecret(lvl) then lvl = UnitLevel("player") end
    local max = Items.MaxPlayerLevel()
    if on and max and type(lvl) == "number" and not IsSecret(lvl) and lvl >= max then on = false end
    Items.xpOn = on
end

-- Tooltip-Texte eines Items in Kleinbuchstaben, ein Eintrag je Zeile (links und rechts).
-- Rückgabe: texts, complete. texts = nil: Tooltip nicht lesbar; complete = false: mindestens
-- ein Text war ein Secret Value (fehlt in texts).
function Items.TooltipTexts(item)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, item)
    if not ok or type(data) ~= "table" or IsSecret(data) then return nil end
    local lines = data.lines
    if type(lines) ~= "table" or IsSecret(lines) then return nil end
    local texts, complete = {}, true
    for i, line in ipairs(lines) do
        local s = ""
        if type(line) == "table" and not IsSecret(line) then
            for k = 1, 2 do
                local t
                if k == 1 then t = line.leftText else t = line.rightText end
                if IsSecret(t) then
                    complete = false
                elseif type(t) == "string" then
                    s = s .. "\n" .. t:lower()
                end
            end
        else
            complete = false
        end
        texts[i] = s
    end
    return texts, complete
end

-- Nennt der Tooltip einen XP-Bonus? (enUS "experience", deDE "Erfahrung")
function Items.HasXPBonus(item)
    if Items.xpCache[item] ~= nil then return Items.xpCache[item] end
    local texts = Items.TooltipTexts(item)
    if not texts then return false end
    local found = false
    for _, s in ipairs(texts) do
        if s:find("experience", 1, true) or s:find("erfahrung", 1, true) then found = true end
    end
    -- nur cachen, wenn das Item geladen ist (sonst ist der Tooltip unvollständig)
    if Items.ItemLevels(item) then Items.xpCache[item] = found end
    return found
end

-- Primärwerte im Tooltip (SPELL_STAT1_NAME .. SPELL_STAT5_NAME) -> FOOD-Kategorie
Items.FOOD_STATS = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
Items.FOOD_WELLFED_SPELL = 19705   -- Well Fed

-- Item-Klasse Consumable / Food & Drink? nil = nicht ermittelbar
function Items.IsFoodDrink(item)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    if not ok or classID == nil or IsSecret(classID) or IsSecret(subClassID) then return nil end
    local consumable = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local sub = Enum and Enum.ItemConsumableSubclass
    local foodSub = (sub and (sub.Fooddrink or sub.FoodDrink)) or 5
    return classID == consumable and subClassID == foodSub
end

-- Item-Daten für DetectFood einmalig anfordern (GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT
-- bewerten neu); kein erneutes Anfordern, falls der Tooltip danach noch nicht lesbar ist
function Items.RequestFoodData(item)
    if Items.foodPending[item] ~= nil then return end
    Items.foodPending[item] = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
end

-- Buff-Essen außerhalb von Items.FOOD: Food & Drink, dessen Tooltip "Well Fed" (Client-Sprache)
-- nennt. Kategorie = Primärwert im Tooltip mit dem höchsten Gewicht der Klasse (keiner erkannt:
-- FOOD_WEIGHT_OTHER, keine Kategorie). Score = Gewicht x (Itemstufe x 5, begrenzt auf 1-300)
-- als Näherung für die Kochkunst-Stufe. Rückgabe/Cache (Items.foodDetect):
-- false = kein Buff-Essen, { score, cat } = Buff-Essen, nil = noch unbekannt (später erneut).
function Items.DetectFood(item)
    local known = Items.foodDetect[item]
    if known ~= nil then return known end
    local isFood = Items.IsFoodDrink(item)
    if isFood == false then
        Items.foodDetect[item] = false
        return false
    end
    local ilvl = Items.ItemLevels(item)
    local texts, complete = Items.TooltipTexts(item)
    if isFood == nil or type(ilvl) ~= "number" or not texts then
        Items.RequestFoodData(item)
        return nil
    end
    local wellFed = (SpellName(Items.FOOD_WELLFED_SPELL) or "well fed"):lower()
    local found, weight, cat = false, nil, nil
    for i, s in ipairs(texts) do
        if s:find(wellFed, 1, true) then found = true end
        if i > 1 then   -- Zeile 1 = Item-Name
            for n, c in ipairs(Items.FOOD_STATS) do
                local stat = _G["SPELL_STAT" .. n .. "_NAME"]
                if type(stat) == "string" and not IsSecret(stat) and stat ~= ""
                    and s:find(stat:lower(), 1, true) then
                    local w = Items.foodWeights[c] or Items.FOOD_WEIGHT_OTHER
                    if not weight or w > weight then weight, cat = w, c end
                end
            end
        end
    end
    if not found then
        if not complete then return nil end   -- Secret-Text: noch unbekannt
        Items.foodDetect[item] = false
        return false
    end
    local res = { score = (weight or Items.FOOD_WEIGHT_OTHER) * math.min(300, math.max(1, ilvl * 5)), cat = cat }
    if complete then Items.foodDetect[item] = res end   -- unvollständig: später erneut lesen
    return res
end

function Items.IsFlaskItem(item)
    if Items.FLASK_IDS[item] then return true end
    local flaskSub = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Flask
    if not flaskSub then return false end
    local consumable = (Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    return ok and classID == consumable and subClassID == flaskSub
end

-- Spell-ID des Fläschchen-Effekts lernen, damit auch neue Fläschchen als aktiv erkannt werden
function Items.LearnFlaskSpell(item)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local ok, _, spellID = pcall(C_Item.GetItemSpell, item)
    if not ok or type(spellID) ~= "number" or IsSecret(spellID) then return end
    Items.flaskBySpell[spellID] = item
    if State.flaskEntry then State.flaskEntry.idSet[spellID] = true end
    if db then db.flaskSpells[spellID] = true end
end

-- Taschen 0..NUM_BAG_SLOTS durchgehen (ohne Bank)
function Items.ScanBags()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
    wipe(Items.bagCounts)
    Pet.foodDirty = true   -- Tierfutter beim nächsten Zugriff neu scannen
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and type(slots) == "number" and not IsSecret(slots) then
            for slot = 1, slots do
                local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if ok and type(info) == "table" and not IsSecret(info) then
                    local id, n = info.itemID, info.stackCount or 1
                    if type(id) == "number" and not IsSecret(id) and not IsSecret(n) then
                        Items.bagCounts[id] = (Items.bagCounts[id] or 0) + n
                    end
                end
            end
        end
    end
    for id in pairs(Items.bagCounts) do
        Items.LearnItem(id)   -- Fläschchen-/Elixier-/Rollen-Zauber lernen
    end
end

-- passende Items aus den Taschen, beste Wahl zuerst: { { id, count, fav, ... }, ... }
-- Favoriten (pro Charakter) stehen immer vorn; untereinander gilt die normale Sortierung.
function Items.ItemChoices(e)
    local list = {}
    local favs = cdb and cdb.favorites or {}
    local kind = Items.KindOf(e)
    if kind == "food" then
        local lvl = UnitLevel("player") or 1
        for id, n in pairs(Items.bagCounts) do
            local score, cat = Items.foodScore[id], Items.foodCat[id]
            if not score then
                local d = Items.DetectFood(id)   -- anderes Buff-Essen (Tooltip nennt "Well Fed")
                if d then score, cat = d.score, d.cat end
            end
            if score then
                local _, minLevel = Items.ItemLevels(id)
                if not minLevel or minLevel <= lvl then
                    -- XP-Bonus nur, wenn Erfahrung für den Spieler zählt (Abzeichen + Bevorzugung)
                    local xp = Items.xpOn ~= false and Items.HasXPBonus(id) or false
                    list[#list + 1] = { id = id, count = n, xp = xp, score = score,
                        cat = cat, fav = favs[id] == true }
                end
            end
        end
        table.sort(list, function(a, b)
            if a.fav ~= b.fav then return a.fav end
            if a.xp ~= b.xp then return a.xp end
            if a.score ~= b.score then return a.score > b.score end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    elseif kind == "flask" then
        local last = cdb and cdb.lastFlask
        for id, n in pairs(Items.bagCounts) do
            if Items.IsFlaskItem(id) then
                list[#list + 1] = { id = id, count = n, ilvl = Items.ItemLevels(id) or 0, fav = favs[id] == true }
            end
        end
        table.sort(list, function(a, b)
            if a.fav ~= b.fav then return a.fav end
            if (a.id == last) ~= (b.id == last) then return a.id == last end
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    elseif kind == "weapon" or kind == "poison" then
        return Items.WeaponChoices(e, kind)
    elseif kind == "scroll" then
        return Scroll.Choices(e)
    elseif kind == "petfood" then
        return Pet.Food().list   -- Tierfutter (eigene Favoriten, eigene Sortierung)
    elseif kind == "elixir" then
        -- ein Eintrag = ein Elixier
        local cnt = Items.bagCounts[e.item]
        if cnt and cnt > 0 then list[1] = { id = e.item, count = cnt, fav = favs[e.item] == true } end
    end
    return list
end

-- Item-Art eines Eintrags für Linksklick/Menü: "food" | "flask" | "weapon" | "poison" | nil.
-- Waffen-Items und Gifte nur mit aktivem Schalter expWeaponItems.
function Items.KindOf(e)
    if e.weaponItems then return ExpOn("expWeaponItems") and "weapon" or nil end
    if e.poisonItems then return ExpOn("expWeaponItems") and "poison" or nil end
    return e.itemKind
end

function Items.WeaponSlot(e)
    return e.kind == "weapon_oh" and 17 or 16
end

-- Unterklasse der Waffe im Slot; nil = keine Waffe / nicht lesbar
function Items.WeaponSubclass(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id or IsSecret(id) then return nil end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, _, classID, subID = pcall(fn, id)
    if not ok or IsSecret(classID) or IsSecret(subID) or classID ~= 2 or type(subID) ~= "number" then return nil end
    return subID
end

-- passt das Item zur Waffe? (Wetzstein: Klinge, Gewichtsstein: stumpf, Elementar/Geweiht:
-- Klinge oder stumpf, Öle/Gifte: alle; Faustwaffen/unbekannt: keine Steine)
function Items.WeaponFits(id, group, sub)
    if Items.ANY_MELEE_STONE[id] then
        return sub ~= nil and (Items.BLADE_SUB[sub] == true or Items.BLUNT_SUB[sub] == true)
    end
    if group == "sharpen" then return sub ~= nil and Items.BLADE_SUB[sub] == true end
    if group == "weight" then return sub ~= nil and Items.BLUNT_SUB[sub] == true end
    return true
end

-- Steine/Öle bzw. Gifte aus den Taschen für den Slot des Eintrags: Favoriten, dann
-- Gruppen-Rangfolge (Klasse bzw. Gifte), dann höchste Stufe, dann Anzahl
function Items.WeaponChoices(e, kind)
    local list, favs = {}, cdb and cdb.favorites or {}
    local sub = Items.WeaponSubclass(Items.WeaponSlot(e))
    local order = kind == "poison" and Items.POISON_ORDER
        or Items.WEAPON_ORDER[Items.class or ""] or Items.WEAPON_ORDER_MELEE
    local rank = {}
    for i, g in ipairs(order) do rank[g] = i end
    local lvl = UnitLevel("player") or 1
    for id, n in pairs(Items.bagCounts) do
        local info = Items.weaponInfo[id]
        if info and info.poison == (kind == "poison") and Items.WeaponFits(id, info.group, sub) then
            local _, minLevel = Items.ItemLevels(id)
            if not minLevel or minLevel <= lvl then
                local g = (info.group == "sharpen" or info.group == "weight") and "stone" or info.group
                list[#list + 1] = { id = id, count = n, fav = favs[id] == true, rank = rank[g] or 99,
                    tier = info.tier, wcat = info.group }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.fav ~= b.fav then return a.fav end
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.tier ~= b.tier then return a.tier > b.tier end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    return list
end

-- Makro: Item benutzen und auf den Waffen-Slot anwenden
function Items.WeaponMacro(id, slot)
    return ("/use item:%d\n/use %d"):format(id, slot)
end

-- Für andere Dateien (ns)
ns.ItemName = ItemName
ns.ItemIcon = ItemIcon
ns.ItemCount = ItemCount
ns.ReagentThreshold = ReagentThreshold
ns.CountKeys = CountKeys
