-- Pardona's Buff Reminder – Wunsch-Elixiere pro Charakter (Schalter expElixirs) und Rollen (expScrolls).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Items = ns.Items
local Elixir = ns.Elixir
local Scroll = ns.Scroll
local entries = ns.entries
local knownCache = ns.knownCache
local IsSecret = ns.IsSecret
local SpellName = ns.SpellName
-- aus Data.lua
local CLASS_BUFFS = ns.CLASS_BUFFS
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
-- aus Detect.lua
local PrepareEntry = ns.PrepareEntry
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Wunsch-Elixiere pro Charakter (Schalter expElixirs)
-- Ob WoW Forever Elixiere nach den Original-Regeln stapelt (verschiedene Werte, mit Fläschchen)
-- oder nach der TBC-Regel (1 Kampf- + 1 Wächterelixier, nicht mit Fläschchen), ist unbestätigt.
-- Deshalb keine festen Plätze: Jedes Elixier, das schon einmal in den Taschen war, steht in der
-- Merkliste (cdb.elixirsSeen); gewünschte (cdb.elixirsWanted[itemID] = true) bekommen eine eigene
-- Warnung, wenn ihr Buff fehlt und das Elixier in den Taschen liegt. Unabhängig vom Fläschchen.
--   Erkennung: Item-Klasse Verbrauchsgut + Unterklasse Elixier (GetItemInfoInstant); Fläschchen
--   bleiben beim Fläschchen-Eintrag.
--   Buff: Zauber des Items (C_Item.GetItemSpell) per Spell-ID, sonst per Name; gelernte
--   Zuordnung in db.elixirSpells[itemID] = spellID (wie flaskSpells).
--   Eintrag: { key = "elixir_<id>", kind = "elixir", itemKind = "elixir", item = id, general = true }
---------------------------------------------------------------------------
Elixir.entries = {}   -- Item-ID -> Eintrag
Elixir.ready = false  -- Einträge erst nach PLAYER_LOGIN anlegen

-- Item-Klasse/Unterklasse eines Items; nil = nicht lesbar
function Items.ClassOf(item)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    if not ok or IsSecret(classID) or IsSecret(subClassID) then return nil end
    return classID, subClassID
end

-- Verbrauchsgut der Unterklasse subKey (Enum.ItemConsumableSubclass, sonst Rückfallwert)?
function Items.IsConsumableSub(item, subKey, fallback)
    local classID, subID = Items.ClassOf(item)
    if classID == nil then return false end
    local consumable = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local sub = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass[subKey]
    if sub == nil then sub = fallback end
    return classID == consumable and subID == sub
end

-- Zauber eines Items (Spell-ID, Name); nil = (noch) nicht ermittelbar -> Laden anstoßen
function Items.ItemSpell(item)
    if not (C_Item and C_Item.GetItemSpell) then return nil end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, item)
    if ok and type(spellID) == "number" and not IsSecret(spellID) then
        if IsSecret(name) or type(name) ~= "string" then name = nil end
        return spellID, name
    end
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
    return nil
end

-- Item aus den Taschen auswerten (Scan und GET_ITEM_INFO_RECEIVED): Fläschchen-, Elixier-,
-- Rollen-Zauber lernen
function Items.LearnItem(id)
    if Items.IsFlaskItem(id) then
        Items.LearnFlaskSpell(id)
    elseif Elixir.IsElixir(id) then
        Elixir.Seen(id)
    elseif Scroll.TypeOf(id) then
        Scroll.Learn(id)
    end
end

function Elixir.IsElixir(item)
    if Items.IsFlaskItem(item) then return false end
    return Items.IsConsumableSub(item, "Elixir", 2)
end

-- Zauber eines Elixiers in den Eintrag übernehmen (Spell-ID + Name)
function Elixir.AddSpell(e, spellID, name)
    if not spellID then return end
    e.idSet[spellID] = true
    name = name or SpellName(spellID)
    if name then
        for _, n in ipairs(e.names) do if n == name then return end end
        e.names[#e.names + 1] = name
    end
end

-- Elixier in den Taschen gesehen: merken, Zauber lernen, Eintrag sicherstellen
function Elixir.Seen(id)
    if not cdb then return end
    cdb.elixirsSeen[id] = true
    local spellID, name = Items.ItemSpell(id)
    if spellID and db then db.elixirSpells[id] = spellID end
    local e = Elixir.Ensure(id)
    if e and spellID then Elixir.AddSpell(e, spellID, name) end
end

-- Eintrag eines Elixiers (einmal pro Item-ID); nil vor PLAYER_LOGIN
function Elixir.Ensure(id)
    if not Elixir.ready then return nil end
    local e = Elixir.entries[id]
    if e then return e end
    local spellID = db.elixirSpells[id]
    e = { key = "elixir_" .. id, general = true, kind = "elixir", itemKind = "elixir", item = id,
          ids = spellID and { spellID } or {} }
    PrepareEntry(e)
    Elixir.entries[id] = e
    entries[#entries + 1] = e
    knownCache[e.key] = true
    Elixir.dirty = true   -- Einstellungen: Liste neu aufbauen
    return e
end

-- PLAYER_LOGIN: Einträge für alle gemerkten Elixiere
function Elixir.Setup()
    Elixir.ready = true
    for id in pairs(cdb.elixirsSeen) do Elixir.Ensure(id) end
end

-- Einträge sortiert nach Name (Einstellungen)
function Elixir.List()
    local list = {}
    for _, e in pairs(Elixir.entries) do list[#list + 1] = e end
    table.sort(list, function(a, b)
        local na, nb = ItemName(a.item), ItemName(b.item)
        if na ~= nb then return na < nb end
        return a.item < b.item
    end)
    return list
end

---------------------------------------------------------------------------
-- Rollen (Schalter expScrolls): je Art eine Warnung, wenn eine benutzbare Rolle
-- dieser Art in den Taschen liegt, ihr Buff (irgendein Rang) fehlt und kein aktiver Klassenbuff
-- schon mindestens so viel vom Wert gibt (Intelligenz, Willenskraft, Ausdauer).
-- Benutzbar = Mindeststufe (Item-Daten) bekannt und <= Stufe des Spielers.
-- Linksklick: beste benutzbare Rolle (Favoriten, dann höchster Rang); Rechtsklick: Item-Menü mit
-- allen Rollen der Art (zu hohe Stufe: ausgegraut, nicht klickbar).
-- An/aus pro Charakter: cdb.scrolls[art] = true/false nur nach ausdrücklicher Wahl,
-- nil = Vorgabe der Klasse (Scroll.CLASS_DEFAULTS; unbekannte Klasse und Druide: alle Arten).
--   items  : Rollen I-IV (Item-IDs, aufsteigend); Rückfall: Verbrauchsgut/Rolle, deren Zauber
--            (ID oder Name) zu einer Art gehört
--   spells : Buffs der Ränge I-IV (Classic-IDs; zusätzlich die Item-Zauber aus dem Client)
--   stat   : globaler Wertname des Clients für "Rolle: <Wert>" (Rückfall L["SCROLL_STAT_<ART>"])
--   values : Wert der Ränge I-IV (Original-Werte; nur Arten mit cover)
--   cover  : Klassenbuff, der den Wert ebenfalls liefert (Eintrag in CLASS_BUFFS, alle Ränge)
---------------------------------------------------------------------------
Scroll.ORDER = { "agility", "strength", "intellect", "spirit", "stamina", "protection" }
Scroll.TYPES = {
    agility    = { items = { 3012, 1477, 4425, 10309 }, spells = { 8115, 8116, 8117, 12174 },
                   stat = "SPELL_STAT2_NAME" },
    strength   = { items = { 954, 2289, 4426, 10310 },  spells = { 8118, 8119, 8120, 12179 },
                   stat = "SPELL_STAT1_NAME" },
    intellect  = { items = { 955, 2290, 4419, 10308 },  spells = { 8096, 8097, 8098, 12176 },
                   stat = "SPELL_STAT4_NAME", values = { 4, 8, 12, 16 }, cover = { "MAGE", "intellect" } },
    spirit     = { items = { 1181, 1712, 4424, 10306 }, spells = { 8112, 8113, 8114, 12177 },
                   stat = "SPELL_STAT5_NAME", values = { 3, 7, 11, 15 }, cover = { "PRIEST", "divinespirit" } },
    stamina    = { items = { 1180, 1711, 4422, 10307 }, spells = { 8099, 8100, 8101, 12178 },
                   stat = "SPELL_STAT3_NAME", values = { 4, 8, 12, 16 }, cover = { "PRIEST", "fortitude" } },
    protection = { items = { 3013, 1478, 4421, 10305 }, spells = { 8091, 8094, 8095, 12175 },
                   stat = "ARMOR" },
}
-- Vorgabe pro Klasse (Klassen-Token); fehlende Klasse = alle Arten
Scroll.CLASS_DEFAULTS = {
    WARRIOR     = { "agility", "strength", "stamina", "protection" },
    ROGUE       = { "agility", "strength", "stamina", "protection" },
    DEATHKNIGHT = { "agility", "strength", "stamina", "protection" },
    HUNTER      = { "agility", "intellect", "stamina", "protection" },
    PALADIN     = { "strength", "agility", "intellect", "stamina", "protection" },
    SHAMAN      = { "strength", "agility", "intellect", "stamina", "protection" },
    PRIEST      = { "intellect", "spirit", "stamina", "protection" },
    MAGE        = { "intellect", "spirit", "stamina", "protection" },
    WARLOCK     = { "intellect", "spirit", "stamina", "protection" },
}
-- Original-Werte der abdeckenden Klassenbuffs (Spell-ID -> Wert), falls die Aura keinen lesbaren
-- Wert (points) liefert. Nicht aufgeführte Ränge (TBC/WotLK) = Wert unbekannt -> keine Warnung.
Scroll.COVER_VALUES = {
    -- Power Word: Fortitude R1-R6, Prayer of Fortitude R1-R2 (Ausdauer)
    [1243] = 3, [1244] = 8, [1245] = 20, [2791] = 32, [10937] = 43, [10938] = 54,
    [21562] = 43, [21564] = 54,
    -- Arcane Intellect R1-R5, Arcane Brilliance R1 (Intelligenz)
    [1459] = 2, [1460] = 7, [1461] = 15, [10156] = 22, [10157] = 31, [23028] = 31,
    -- Divine Spirit R1-R4, Prayer of Spirit R1 (Willenskraft)
    [14752] = 17, [14818] = 23, [14819] = 33, [27841] = 40, [27681] = 40,
}
Scroll.byItem = {}     -- Item-ID -> { type, rank } (feste IDs + per Rückfall erkannte)
Scroll.bySpell = {}    -- Spell-ID -> Art
Scroll.byName = {}     -- Zaubername -> Art
Scroll.valueBySpell = {}   -- Spell-ID des Rollen-Buffs -> Wert (Arten mit values)
Scroll.defaultSets = {}    -- Klassen-Token -> { [art] = true }
Scroll.entries = {}    -- Art -> Eintrag
-- Nachschlagetabellen der festen IDs (Funktion statt Schleife im Haupt-Chunk: keine weiteren locals)
function Scroll.Init()
    for t, def in pairs(Scroll.TYPES) do
        for i, id in ipairs(def.items) do Scroll.byItem[id] = { type = t, rank = i } end
        for i, id in ipairs(def.spells) do
            Scroll.bySpell[id] = t
            if def.values then Scroll.valueBySpell[id] = def.values[i] end
        end
    end
    for class, list in pairs(Scroll.CLASS_DEFAULTS) do
        local set = {}
        for _, t in ipairs(list) do set[t] = true end
        Scroll.defaultSets[class] = set
    end
end
Scroll.Init()

-- Art an? Ausdrückliche Wahl (cdb.scrolls), sonst Vorgabe der Klasse
function Scroll.Enabled(t)
    local v = cdb and cdb.scrolls and cdb.scrolls[t]
    if v ~= nil then return v == true end
    local set = Scroll.defaultSets[Scroll.class or ""]
    return set == nil or set[t] == true
end

-- Einmalig beim Laden: altes cdb.scrollsOff[art] = true -> cdb.scrolls[art] = false
function Scroll.MigrateOff()
    if type(cdb.scrollsOff) == "table" then
        for t, off in pairs(cdb.scrollsOff) do
            if off == true and cdb.scrolls[t] == nil then cdb.scrolls[t] = false end
        end
    end
    cdb.scrollsOff = nil
end

-- Stufe des Spielers; PLAYER_LEVEL_UP liefert die neue Stufe, bevor UnitLevel sie kennt
function Scroll.PlayerLevel()
    local ok, lvl = pcall(UnitLevel, "player")
    if not ok or type(lvl) ~= "number" or IsSecret(lvl) then lvl = nil end
    local up = Scroll.levelUp
    if up and (not lvl or up > lvl) then lvl = up end
    return lvl
end

function Scroll.OnLevelUp(level)
    if type(level) == "number" and not IsSecret(level) then Scroll.levelUp = level end
end

-- Mindeststufe einer Rolle; nil = Item-Daten (noch) nicht geladen -> Laden anstoßen
-- (GET_ITEM_INFO_RECEIVED wertet neu aus)
function Scroll.MinLevel(id)
    local _, minLevel = Items.ItemLevels(id)
    if type(minLevel) == "number" then return minLevel end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return nil
end

-- Wert einer Rolle (nur Arten mit values): Rang aus der festen Liste, sonst über den Item-Zauber
function Scroll.ItemValue(t, id, rank)
    local def = Scroll.TYPES[t]
    if not (def and def.values) then return nil end
    if rank and rank > 0 then return def.values[rank] end
    local spellID = Items.ItemSpell(id)
    return spellID and Scroll.valueBySpell[spellID] or nil
end

-- Art einer Rolle; nil = keine Rolle. Rückfall über Item-Klasse + Zauber (gecacht)
function Scroll.TypeOf(id)
    local info = Scroll.byItem[id]
    if info then return info.type, info.rank end
    if info == false then return nil end
    if not Items.IsConsumableSub(id, "Scroll", 4) then return nil end
    local spellID, name = Items.ItemSpell(id)
    if not spellID then return nil end   -- später erneut (Item-Daten folgen)
    local t = Scroll.bySpell[spellID] or (name and Scroll.byName[name])
    Scroll.byItem[id] = t and { type = t, rank = 0 } or false
    return t, 0
end

-- Zauber einer Rolle aus dem Client übernehmen (falls Forever andere IDs nutzt)
function Scroll.Learn(id)
    local t = Scroll.TypeOf(id)
    local e = t and Scroll.entries[t]
    if not e then return end
    local spellID, name = Items.ItemSpell(id)
    if spellID then
        Scroll.bySpell[spellID] = t
        Elixir.AddSpell(e, spellID, name)
    end
end

-- PLAYER_LOGIN: sechs Einträge (Reihenfolge Scroll.ORDER) + Klassenbuffs, die Werte abdecken
function Scroll.Setup(class)
    Scroll.class = class   -- Vorgabe der Arten (Scroll.Enabled)
    for _, t in ipairs(Scroll.ORDER) do
        local def = Scroll.TYPES[t]
        local e = { key = "scroll_" .. t, general = true, kind = "scroll", itemKind = "scroll",
                    scrollType = t, ids = def.spells, nameIds = { def.spells[#def.spells] } }
        PrepareEntry(e)
        for _, n in ipairs(e.names) do Scroll.byName[n] = t end
        e.coverSet, e.coverNames = {}, {}
        if def.cover then
            for _, c in ipairs(CLASS_BUFFS[def.cover[1]] or {}) do
                if c.key == def.cover[2] then
                    for _, id in ipairs(c.ids or {}) do e.coverSet[id] = true end
                    for _, id in ipairs(c.nameIds or {}) do
                        local n = SpellName(id)
                        if n then e.coverNames[n] = true end
                    end
                end
            end
        end
        Scroll.entries[t] = e
        entries[#entries + 1] = e
        ItemName(def.items[1])   -- Rolle I vorladen (Icon der Art in den Einstellungen)
    end
end

-- Alle Rollen der Art des Eintrags aus den Taschen; c.usable = Mindeststufe bekannt und erreicht
function Scroll.InBags(e)
    local list, favs = {}, cdb and cdb.favorites or {}
    local lvl = Scroll.PlayerLevel()
    for id, n in pairs(Items.bagCounts) do
        local t, rank = Scroll.TypeOf(id)
        if t == e.scrollType then
            local minLevel = Scroll.MinLevel(id)
            list[#list + 1] = { id = id, count = n, rank = rank or 0, fav = favs[id] == true,
                minLevel = minLevel, usable = minLevel ~= nil and (lvl == nil or minLevel <= lvl),
                value = Scroll.ItemValue(t, id, rank) }
        end
    end
    return list
end

-- Reihenfolge: benutzbare vor gesperrten; benutzbare nach Favorit, dann höchstem Rang;
-- gesperrte nach Rang aufsteigend (nächster erreichbarer zuerst); dann Anzahl, ID
function Scroll.SortChoices(a, b)
    if a.usable ~= b.usable then return a.usable end
    if a.usable and a.fav ~= b.fav then return a.fav end
    if a.rank ~= b.rank then
        if a.usable then return a.rank > b.rank end
        return a.rank < b.rank
    end
    if a.count ~= b.count then return a.count > b.count end
    return a.id < b.id
end

-- Benutzbare Rollen der Art (Linksklick, "beste Wahl", Warnung): erste = beste Wahl
function Scroll.Choices(e)
    local list = {}
    for _, c in ipairs(Scroll.InBags(e)) do
        if c.usable then list[#list + 1] = c end
    end
    table.sort(list, Scroll.SortChoices)
    return list
end

-- Rechtsklick-Menü: alle Rollen der Art; c.locked = Stufe zu niedrig (ausgegraut, nicht klickbar)
function Scroll.MenuChoices(e)
    local list = Scroll.InBags(e)
    for _, c in ipairs(list) do c.locked = not c.usable end
    table.sort(list, Scroll.SortChoices)
    return list
end

-- Anzahl der Rollen einer Art in den Taschen (alle Ränge, auch nicht benutzbare)
function Scroll.Count(e)
    local n = 0
    for _, c in ipairs(Scroll.InBags(e)) do n = n + c.count end
    return n
end

-- Neutraler Name der Art, z. B. "Scroll: Intellect" (Wertname aus dem Client, sonst eigener Text)
function Scroll.TypeName(t)
    local def = Scroll.TYPES[t]
    local stat = def and _G[def.stat]
    if type(stat) ~= "string" or IsSecret(stat) or stat == "" then
        stat = L["SCROLL_STAT_" .. tostring(t):upper()]
    end
    return L.SCROLL_TYPE:format(stat)
end

-- Icon der Art: Rolle des Rangs I
function Scroll.TypeIcon(t)
    local def = Scroll.TYPES[t]
    return (def and ItemIcon(def.items[1])) or FALLBACK_ICON
end

-- Beschriftung der Warnung: Rolle, die der Linksklick benutzt; ohne sie der neutrale Name
function Scroll.Label(e)
    local c = Scroll.Choices(e)[1]
    if c then return ItemName(c.id) end
    return Scroll.TypeName(e.scrollType)
end

-- Wert aus den Aura-Daten (points[1]); nil = nicht vorhanden oder Secret
function Scroll.ReadPoints(aura)
    local pts = aura.points
    if type(pts) ~= "table" or IsSecret(pts) then return nil end
    return pts[1]
end

function Scroll.AuraPoints(aura)
    local ok, v = pcall(Scroll.ReadPoints, aura)
    if ok and type(v) == "number" and not IsSecret(v) and v > 0 then return v end
    return nil
end

-- Stärkster aktiver Klassenbuff, der den Wert der Art ebenfalls gibt: nil = keiner aktiv,
-- false = aktiv, aber Wert nicht bestimmbar. Wert: Aura (points), sonst Scroll.COVER_VALUES.
function Scroll.CoverValue(e, scan)
    local best
    for _, a in ipairs(scan.list) do
        if (a.id and e.coverSet[a.id]) or (a.name and e.coverNames[a.name]) then
            local v = a.points or (a.id and Scroll.COVER_VALUES[a.id])
            if type(v) ~= "number" then return false end
            if not best or v > best then best = v end
        end
    end
    return best
end

-- false = keine benutzbare Rolle in den Taschen oder ein Klassenbuff gibt schon mindestens so viel
-- wie die Rolle des Linksklicks (Wert unbestimmbar: lieber keine Warnung); nil = weiter prüfen
-- (eigener Buff der Art, irgendein Rang, in CheckMissing)
function Scroll.Precheck(e, scan)
    local best = Scroll.Choices(e)[1]
    if not best then return false end
    if not scan then return nil end
    local cover = Scroll.CoverValue(e, scan)
    if cover == false then return false end
    if cover and (type(best.value) ~= "number" or cover >= best.value) then return false end
    return nil
end

-- true = fehlt, false = nicht relevant/vorhanden, nil = unbekannt (Rest in CheckMissing)
function Elixir.Precheck(e)
    if (Items.bagCounts[e.item] or 0) == 0 then return false end
    if next(e.idSet) == nil and #e.names == 0 then
        local spellID, name = Items.ItemSpell(e.item)
        if not spellID then return false end   -- Buff noch unbekannt: lieber nicht warnen
        db.elixirSpells[e.item] = spellID
        Elixir.AddSpell(e, spellID, name)
    end
    return nil
end
