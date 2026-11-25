-- Pardona's Buff Reminder – Einträge (Beschriftung, Icon, Lookup-Tabellen), Erlernt-Prüfung, Klick-Zaubern
-- (Zauber/Variante), Zählen der Klassen-Verbrauchsgüter und Buff-Erkennung (Auren, Waffen).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Conjure = ns.Conjure
local Variant = ns.Variant
local Tracking = ns.Tracking
local Elixir = ns.Elixir
local Scroll = ns.Scroll
local Pet = ns.Pet
local Supply = ns.Supply
local entries = ns.entries
local knownCache = ns.knownCache
local missing = ns.missing
local muted = ns.muted
local Print = ns.Print
local NormName = ns.NormName
local IsSecret = ns.IsSecret
local ExpOn = ns.ExpOn
local SpellName = ns.SpellName
local SpellIcon = ns.SpellIcon
-- aus Data.lua
local CAST_DATA = ns.CAST_DATA
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
local ItemCount = ns.ItemCount
local ReagentThreshold = ns.ReagentThreshold
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

local function EntryLabel(e)
    if e.demoLabel then return e.demoLabel end   -- Demo-Modus: Name aus dem Client (Demo.Entry)
    if e.kind == "reagent" then return ItemName(e.item) end
    if e.kind == "tracking" then return Tracking.Label(e) end
    if e.kind == "elixir" then return ItemName(e.item) end
    if e.kind == "scroll" then return Scroll.Label(e) end
    if e.kind == "supply" then return Supply.Label(e) end
    if e.label then   -- Variantengruppen: Grundwort + bekannte Varianten (Variant.GroupLabel)
        return e.variantClass and Variant.GroupLabel(e.variantClass, e.key, e.label) or L[e.label]
    end
    local first = (e.ids or e.knownIds or {})[1]
    return (first and SpellName(first)) or e.key
end

local function EntryIcon(e)
    if e.demoIcon then return e.demoIcon end     -- Demo-Modus
    if e.kind == "reagent" then return ItemIcon(e.item) or FALLBACK_ICON end
    if e.kind == "tracking" then return Tracking.Icon(e) end
    if e.kind == "conjure" then
        return ItemIcon(Conjure.RankItem(e)) or SpellIcon(e.knownIds[1]) or FALLBACK_ICON
    end
    if e.kind == "elixir" then return ItemIcon(e.item) or FALLBACK_ICON end
    if e.kind == "pet" then return Pet.Icon(e) end
    if e.kind == "supply" then return Supply.Icon(e) end
    if e.kind == "scroll" then
        -- Icon der Rolle des Linksklicks, sonst der Rolle I der Art
        local c = Scroll.Choices(e)[1]
        return (c and ItemIcon(c.id)) or Scroll.TypeIcon(e.scrollType)
    end
    if e.weaponItems then
        -- Icon der aktuell besten Wahl aus den Taschen
        local c = Items.KindOf(e) and Items.ItemChoices(e)[1]
        return (c and ItemIcon(c.id)) or e.icon
    end
    if e.general then
        -- a) zuletzt im Spiel gesehenes Aura-Icon, b) Spell-Textur der ersten ID,
        -- c) fest eingetragenes Icon, d) Fallback
        local cached = db and db.iconCache and db.iconCache[e.key]
        if cached then return cached end
        local id = (e.ids or {})[1]
        local tex = id and SpellIcon(id)
        if tex then return tex end
        if type(e.icon) == "string" then return e.icon end
        return FALLBACK_ICON
    end
    if type(e.icon) == "string" then return e.icon end
    local id = e.icon or (e.ids or e.knownIds or {})[1]
    return (id and SpellIcon(id)) or FALLBACK_ICON
end

-- Lookup-Tabellen pro Eintrag aufbauen (nach Login, wenn Spell-Daten da sind)
local function PrepareEntry(e)
    e.idSet = {}
    for _, id in ipairs(e.ids or {}) do e.idSet[id] = true end
    e.names = {}
    local src = e.nameIds or { (e.ids or e.knownIds or {})[1] }
    for _, id in ipairs(src) do
        local n = SpellName(id)
        if n then e.names[#e.names + 1] = n end
    end
    e.normNames = {}
    for _, n in ipairs(e.matchNames or {}) do
        e.names[#e.names + 1] = n
        e.normNames[NormName(n)] = true
    end
    if e.excludeIds then
        e.excludeSet = {}
        for _, id in ipairs(e.excludeIds) do e.excludeSet[id] = true end
    end
end

---------------------------------------------------------------------------
-- Erlernt?
---------------------------------------------------------------------------
local function SpellKnown(id)
    if IsPlayerSpell then
        local ok, r = pcall(IsPlayerSpell, id)
        if ok and r then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and r then return true end
    end
    if IsSpellKnown then
        local ok, r = pcall(IsSpellKnown, id)
        if ok and r then return true end
    end
    return false
end

-- Gewünschte Verfolgung? (pro Charakter, cdb.trackSet = { [Schlüssel] = true }; ohne eigene Wahl
-- die Vorgabe: Mineralien, Kräuter, Schätze an, Fische und alle anderen aus)
function Tracking.Wanted(key)
    local set = cdb and cdb.trackSet
    if set == nil then return Tracking.DEFAULT[key] == true end
    return set[key] == true
end

-- Häkchen in den Einstellungen; die erste eigene Wahl übernimmt die Vorgabe
function Tracking.SetWanted(key, on)
    if cdb.trackSet == nil then
        cdb.trackSet = {}
        for k in pairs(Tracking.DEFAULT) do cdb.trackSet[k] = true end
    end
    cdb.trackSet[key] = on and true or nil
end

-- Übernahme der früheren Einzelwahl (cdb.trackWanted) beim ersten Laden: "none" = keine,
-- eine Art = nur diese, sonst Vorgabe; danach wird cdb.trackWanted entfernt
function Tracking.Migrate()
    local w = cdb.trackWanted
    if w == nil then return end
    if cdb.trackSet == nil then
        if w == "none" then
            cdb.trackSet = {}
        elseif Tracking.TYPES[w] then
            cdb.trackSet = { [w] = true }
        end
    end
    cdb.trackWanted = nil
end

-- Wählbare Verfolgungen für die Einstellungen: abilities (bekannte Arten, soweit gelernt, dann
-- alle weiteren Fähigkeiten der Liste) und minimap (alle übrigen Einträge der Liste)
function Tracking.Options()
    local list = Tracking.Scan()
    local byKey, abilities, minimap = {}, {}, {}
    for _, it in ipairs(list) do byKey[it.key] = it end
    for _, k in ipairs(Tracking.ORDER) do
        local t = Tracking.TYPES[k]
        if byKey[k] then
            abilities[#abilities + 1] = byKey[k]
        elseif SpellKnown(t.spell) then
            abilities[#abilities + 1] = { key = k, name = SpellName(t.spell) or k, tex = SpellIcon(t.spell) }
        end
    end
    for _, it in ipairs(list) do
        if not Tracking.TYPES[it.key] then
            local dst = it.ability and abilities or minimap
            dst[#dst + 1] = it
        end
    end
    return abilities, minimap
end

-- Mindestens eine gewünschte Verfolgung gelernt? (in der Liste bzw. Zauber bekannt)
function Tracking.AnyLearned()
    for _, it in ipairs((Tracking.Scan())) do
        if Tracking.Wanted(it.key) then return true end
    end
    for _, k in ipairs(Tracking.ORDER) do
        if Tracking.Wanted(k) and SpellKnown(Tracking.TYPES[k].spell) then return true end
    end
    return false
end

-- Fehlende gewünschte Verfolgungen bestimmen (e.trackMissing, Reihenfolge der Liste).
-- true = mind. eine fehlt; false = keine; nil = nicht lesbar (Zustand beibehalten).
-- Erlaubt der Client nur eine Verfolgung (Tracking.exclusive): nur wenn keine gewünschte aktiv
-- ist, dann mit der ersten gewünschten.
function Tracking.Missing(e, scan)
    local list, state = Tracking.Scan()
    if state == "none" then return Tracking.LegacyMissing(e, scan) end
    if state ~= "ok" then return nil end
    local off, anyActive = {}, false
    for _, it in ipairs(list) do
        if Tracking.Wanted(it.key) then
            if it.active then
                anyActive = true
            else
                off[#off + 1] = it
            end
        end
    end
    if Tracking.exclusive then
        off = (not anyActive and off[1]) and { off[1] } or {}
    end
    e.trackMissing = off
    return #off > 0
end

-- Ohne Verfolgungsliste (Legacy-Clients, nur eine Verfolgung): Aura bzw. aktuelle
-- Verfolgungs-Textur der gewünschten bekannten Arten; Zeile mit der ersten gelernten
function Tracking.LegacyMissing(e, scan)
    local curTex
    if GetTrackingTexture then
        local ok, tex = pcall(GetTrackingTexture)
        if ok and tex and not IsSecret(tex) then curTex = tex end
    end
    local first
    for _, k in ipairs(Tracking.ORDER) do
        local t = Tracking.TYPES[k]
        if Tracking.Wanted(k) and SpellKnown(t.spell) then
            first = first or t
            local sname = SpellName(t.spell)
            if scan and (scan.ids[t.spell] or (sname and scan.names[sname])) then return false end
            if curTex and Tracking.Matches(t, nil, curTex, nil) then return false end
        end
    end
    if not first then return false end
    if scan and scan.unreliable then return nil end
    e.trackMissing = { { key = "legacy", name = SpellName(first.spell) or "?", tex = SpellIcon(first.spell),
        spell = first.spell } }
    return true
end

-- Zeilentext: Namen der fehlenden Verfolgungen, kommagetrennt
function Tracking.Label(e)
    local names = {}
    for _, it in ipairs(e.trackMissing or {}) do names[#names + 1] = it.name end
    if #names == 0 then return L.EXP_TRACKING end
    return table.concat(names, ", ")
end

-- Icon der ersten fehlenden Verfolgung
function Tracking.Icon(e)
    local it = (e.trackMissing or {})[1]
    return (it and it.tex) or FALLBACK_ICON
end

-- Linksklick bzw. Taste auf einer Verfolgungs-Zeile: alle fehlenden gewünschten Verfolgungen
-- einschalten (nur außerhalb des Kampfes; der Button hat dafür keine secure Aktion).
-- true = Klick behandelt.
function Tracking.Activate(btn)
    local a = btn.action
    if not (a and a.trackIndex) then return false end
    if InCombatLockdown() then Print(L.COMBAT); return true end
    Tracking.EnableMissing()
    ns.Evaluate()
    return true
end

-- Fehlende gewünschte Verfolgungen nacheinander einschalten; nach jedem Setzen neu lesen
-- (Tracking.CheckExclusive). Im Exklusiv-Modus nur die erste, und nur wenn keine aktiv ist.
function Tracking.EnableMissing()
    local setFn = Tracking.SetFn()
    if not setFn then return end
    local list, state = Tracking.Scan()
    if state ~= "ok" then return end
    local todo, anyActive = {}, false
    local watch = { keys = {}, untilT = GetTime() + Tracking.WATCH_TIME }
    for _, it in ipairs(list) do
        if Tracking.Wanted(it.key) then
            if it.active then
                anyActive = true
                watch.keys[it.key] = true
            else
                todo[#todo + 1] = it
            end
        end
    end
    if Tracking.exclusive then
        if anyActive or not todo[1] then return end
        todo = { todo[1] }
    end
    Tracking.watch = watch
    for _, it in ipairs(todo) do
        pcall(setFn, it.index, true)
        if Tracking.CheckExclusive() then break end
    end
end

-- Hat das Einschalten eine eben noch aktive gewünschte Verfolgung wieder ausgeschaltet? Dann
-- erlaubt der Client nur eine gleichzeitig: Merker für die Sitzung, Hinweis einmal im Chat.
-- Läuft direkt nach jedem Setzen und bei MINIMAP_UPDATE_TRACKING (kurz nach einem Klick).
function Tracking.CheckExclusive()
    local w = Tracking.watch
    if Tracking.exclusive then return true end
    if not w then return false end
    if GetTime() > w.untilT then
        Tracking.watch = nil
        return false
    end
    local list, state = Tracking.Scan()
    if state ~= "ok" then return false end
    for _, it in ipairs(list) do
        if Tracking.Wanted(it.key) then
            if it.active then
                w.keys[it.key] = true
            elseif w.keys[it.key] then
                Tracking.exclusive, Tracking.watch = true, nil
                Print(L.TRACK_EXCLUSIVE)
                return true
            end
        end
    end
    return false
end

local function ComputeKnown(e)
    if e.kind == "tracking" then
        -- "erlernt" = mindestens eine gewünschte Verfolgung gelernt
        return Tracking.AnyLearned()
    end
    if e.general then return true end
    if e.kind == "supply" then return true end   -- Vorräte: Einträge gibt es nur für passende Klassen
    local lvl = UnitLevel("player") or 1
    if e.levelOnly then return lvl >= (e.level or 1) end
    for _, id in ipairs(e.knownIds or e.ids or {}) do
        if SpellKnown(id) then return true end
    end
    -- Fallback über Namen (falls Forever andere Spell-IDs nutzt)
    if not e.talent and lvl >= (e.level or 1) and C_Spell and C_Spell.GetSpellInfo then
        for _, n in ipairs(e.names or {}) do
            local ok, info = pcall(C_Spell.GetSpellInfo, n)
            if ok and info and not IsSecret(info) then return true end
        end
    end
    return false
end

local RelevantReagents -- forward (braucht KnownByName)

local function RefreshKnown()
    local items = RelevantReagents()
    for _, e in ipairs(entries) do
        if e.kind == "reagent" then
            knownCache[e.key] = items[e.item] == true
        else
            knownCache[e.key] = ComputeKnown(e)
        end
    end
end

local function IsEnabled(e)
    -- Reagenzien: nur mit aktivem Schalter (sonst keine Zeile, keine Mengenprüfung)
    if e.kind == "reagent" then return ExpOn("expReagents") and ReagentThreshold(e.item) > 0 end
    -- Vorräte (Munition, Seelensplitter, Tierfutter, eigene Items): gleicher Schalter wie Reagenzien
    if e.kind == "supply" then return ExpOn("expReagents") and Supply.Enabled(e) end
    -- Klassen-Verbrauchsgüter: nur mit aktivem Schalter
    if e.kind == "conjure" and not ExpOn("expConsumables") then return false end
    -- Verfolgungs-Erinnerung: nur mit Schalter (gewünschte gelernt: knownCache)
    if e.kind == "tracking" then return ExpOn("expTracking") end
    -- Wunsch-Elixiere: nur mit Schalter und Haken in der Liste (pro Charakter)
    if e.kind == "elixir" then return ExpOn("expElixirs") and cdb.elixirsWanted[e.item] == true end
    -- Rollen: nur mit Schalter; je Art Wahl pro Charakter, sonst Vorgabe der Klasse
    if e.kind == "scroll" then return ExpOn("expScrolls") and Scroll.Enabled(e.scrollType) end
    -- Tier-Erinnerung: nur mit Experimental-Schalter; Einzelschalter (cdb.buffs) wie Klassenbuffs
    if e.kind == "pet" and not ExpOn("expPet") then return false end
    -- Waffen-Items: nur mit Schalter; Schurke: nur, wenn der Gift-Eintrag aus ist
    if e.weaponItems then
        if not ExpOn("expWeaponItems") then return false end
        if e.poisonEntry and IsEnabled(e.poisonEntry) then return false end
    end
    local v = cdb.buffs[e.key]
    if v == nil then return not e.defaultOff end
    return v
end

local function MuteRemaining(key)
    local t = muted[key]
    if not t then return nil end
    if t == math.huge then return t end
    local left = t - GetTime()
    if left <= 0 then muted[key] = nil; return nil end
    return left
end

---------------------------------------------------------------------------
-- Klick-Zaubern: Zauber bestimmen, zuletzt genutzte Variante merken
---------------------------------------------------------------------------
local function IsWeaponEntry(e) return e.kind == "weapon_mh" or e.kind == "weapon_oh" end

local function KnownByName(n)
    if not n then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, n)
        if ok and info and not IsSecret(info) then return true end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, n)
        if ok and name and not IsSecret(name) then return true end
    end
    return false
end

-- Reagenzien, die der jeweils höchste erlernte Rang einer Zauberlinie verbraucht
function RelevantReagents()
    local items = {}
    local lvl = UnitLevel("player") or 1
    for _, ranks in ipairs(State.reagentLines) do
        local rank
        for i = #ranks, 1, -1 do
            if SpellKnown(ranks[i][1]) then rank = ranks[i]; break end
        end
        if not rank and KnownByName(SpellName(ranks[1][1])) then
            -- Namens-Fallback: höchster Rang, dessen Lernstufe erreicht ist
            rank = ranks[1]
            for i = #ranks, 1, -1 do
                if lvl >= ranks[i][2] then rank = ranks[i]; break end
            end
        end
        if rank and rank[3] then items[rank[3]] = true end
    end
    return items
end

-- höchster erlernter Rang; Fallback: Zaubername, falls per Name bekannt
local function BestCast(castIds)
    for i = #castIds, 1, -1 do
        if SpellKnown(castIds[i]) then return castIds[i] end
    end
    local n = SpellName(castIds[1])
    if KnownByName(n) then return n end
    return nil
end

-- castIds/variants aus CAST_DATA übernehmen, Lookup-Tabellen der Varianten bauen
local function PrepareCast(e, class)
    local c = CAST_DATA[class] and CAST_DATA[class][e.key]
    if not c then return end
    e.castIds, e.variants = c.castIds, c.variants
    if c.variants then e.variantClass = class end   -- Beschriftung per Variant.GroupLabel
    e.variantMenu = c.menu == true   -- Variantenmenü per Rechtsklick (nicht für die Segen)
    for _, v in ipairs(e.variants or {}) do
        if not v.matchSet then            -- Imbue-Varianten sind zwischen MH/OH geteilt
            v.matchSet, v.nameSet = {}, {}
            for _, list in ipairs({ v.castIds, v.ids or {} }) do
                for _, id in ipairs(list) do
                    v.matchSet[id] = true
                    local n = SpellName(id)
                    if n then v.nameSet[n] = true end
                end
            end
        end
    end
end

local function VariantByKey(e, key)
    if not key then return nil end
    for _, v in ipairs(e.variants) do
        if v.key == key then return v end
    end
end

-- Spell (ID oder Name) für Linksklick, nil = nicht zauberbar
local function CastSpellFor(e)
    if not db.clickCast then return nil end
    if e.castIds then return BestCast(e.castIds) end
    if e.variants then
        local v = VariantByKey(e, cdb.lastVariant[e.key])
        if v then return BestCast(v.castIds) end
    end
    return nil
end

-- Beschriftung einer Variantengruppe: Grundwort aus L + " (" + Kurznamen der Varianten, die der
-- Client kennt (Zaubername von castIds[1] vorhanden), getrennt mit "/" + ")". Ohne bekannte
-- Variante nur das Grundwort (dann kein Cache: Spell-Daten evtl. noch nicht da).
-- Kurznamen: L["VARIANT_<KLASSE>_<GRUPPE>_<VARIANTE>"], Gruppe = Eintrag-Key ohne _mh/_oh
-- (z. B. VARIANT_MAGE_ARMOR_FROST, VARIANT_SHAMAN_IMBUE_WINDFURY).
Variant.labels = {}   -- "<KLASSE>_<GRUPPE>:<Grundwort-Key>" -> Text (Sprache steht ab ADDON_LOADED fest)
function Variant.GroupLabel(class, key, base)
    local group = key:gsub("_[mo]h$", "")
    local prefix = class .. "_" .. group:upper()
    local cacheKey = prefix .. ":" .. base
    if Variant.labels[cacheKey] then return Variant.labels[cacheKey] end
    local c = CAST_DATA[class] and CAST_DATA[class][key]
    local names = {}
    for _, v in ipairs(c and c.variants or {}) do
        if v.castIds and v.castIds[1] and SpellName(v.castIds[1]) ~= nil then
            names[#names + 1] = L["VARIANT_" .. prefix .. "_" .. v.key:upper()]
        end
    end
    if #names == 0 then return L[base] end
    local text = L[base] .. " (" .. table.concat(names, "/") .. ")"
    Variant.labels[cacheKey] = text
    return text
end

-- Beschriftungen der Variantengruppen einmal berechnen (PLAYER_LOGIN, nach PrepareCast)
function Variant.PrepareLabels(list)
    for _, e in ipairs(list) do
        if e.variantClass and e.label then Variant.GroupLabel(e.variantClass, e.key, e.label) end
    end
end

-- Variantenmenü (Schalter expVariantMenu): nur für markierte Variantengruppen
-- (CAST_DATA menu = true), mit "Linksklick zaubert Buff" und nicht für Gruppen-Zeilen
function Variant.MenuOn(e)
    -- Tier-Zeilen (Tier rufen/wiederbeleben, Dämon): eigener Beta-Schalter expPet
    if e ~= nil and e.kind == "pet" then
        return e.petMenu == true and db.clickCast and ExpOn("expPet") and true or false
    end
    return e ~= nil and e.variantMenu == true and not e.groupActive and db.clickCast
        and ExpOn("expVariantMenu") and true or false
end

-- erlernte Varianten in der Reihenfolge von CAST_DATA, je mit dem höchsten erlernten Rang:
-- { { spell = ID/Name, vkey, name, icon, last = zuletzt genutzt }, ... }
function Variant.Choices(e)
    if e.kind == "pet" then return Pet.MenuChoices(e) end
    local list, last = {}, cdb.lastVariant[e.key]
    for _, v in ipairs(e.variants or {}) do
        local spell = BestCast(v.castIds)
        if spell then
            local name = (type(spell) == "string" and spell) or SpellName(spell) or SpellName(v.castIds[1]) or v.key
            list[#list + 1] = { spell = spell, vkey = v.key, name = name, last = v.key == last,
                icon = SpellIcon(spell) or SpellIcon(v.castIds[1]) or FALLBACK_ICON }
        end
    end
    return list
end

-- Quelle 1: eigener erfolgreicher Zauber (UNIT_SPELLCAST_SUCCEEDED)
local function RememberFromCast(spellID)
    if spellID == nil or IsSecret(spellID) then return end
    local name = SpellName(spellID)
    for _, e in ipairs(entries) do
        if e.variants then
            for _, v in ipairs(e.variants) do
                if v.matchSet[spellID] or (name and v.nameSet[name]) then
                    -- Waffenverzauberung: der Zauber verrät die Hand nicht. Übernehmen für
                    -- die Hand, die gerade fehlt, sonst nur, solange noch nichts gemerkt ist.
                    if not IsWeaponEntry(e) or missing[e.key] or not cdb.lastVariant[e.key] then
                        cdb.lastVariant[e.key] = v.key
                    end
                    break
                end
            end
        end
    end
end

local function VariantActive(v, own)
    for id in pairs(v.matchSet) do
        if own.ids[id] then return true end
    end
    for n in pairs(v.nameSet) do
        if own.names[n] then return true end
    end
    return false
end

-- Quelle 2: eigene aktive Aura (nur selbst gewirkte, damit fremde Segen/Auren nichts überschreiben)
local function RememberFromAuras(own)
    if not own then return end
    for _, e in ipairs(entries) do
        if e.variants and not IsWeaponEntry(e) then
            local cur, found = cdb.lastVariant[e.key], nil
            for _, v in ipairs(e.variants) do
                if VariantActive(v, own) then
                    if v.key == cur then found = nil; break end   -- gemerkte Variante ist aktiv
                    found = found or v
                end
            end
            if found then cdb.lastVariant[e.key] = found.key end
        end
    end
end

---------------------------------------------------------------------------
-- Klassen-Verbrauchsgüter: Zählen, Name/Icon, Zeilentext
---------------------------------------------------------------------------
function Conjure.Threshold()
    local v = tonumber(db and db.conjureThreshold) or 20
    return math.max(0, math.min(60, math.floor(v)))
end

-- Item des höchsten erlernten Rangs (Name/Icon der Zeile); nichts erlernt -> erster Rang
function Conjure.RankItem(e)
    local c = e.conj
    for i = #c.spells, 1, -1 do
        if SpellKnown(c.spells[i]) then
            for j = i, 1, -1 do
                if c.rankItems[j] then return c.rankItems[j] end
            end
        end
    end
    return c.rankItems[1]
end

function Conjure.Name(e)
    return ItemName(Conjure.RankItem(e))
end

-- true = fehlt/zu wenig, false = genug, nil = Anzahl nicht lesbar; e.count = Summe in den Taschen
function Conjure.Missing(e)
    local n = 0
    for _, id in ipairs(e.conj.items) do
        local c = ItemCount(id)
        if c == nil then return nil end
        n = n + c
    end
    e.count = n
    if e.conj.mode == "sum" then
        local t = Conjure.Threshold()
        return t > 0 and n < t
    end
    return n == 0
end

-- "Gezaubertes Wasser: 5" bzw. "<Name> fehlt" (bei 0 bzw. "beliebiger Stein")
function Conjure.Text(e)
    if e.conj.mode == "sum" and (e.count or 0) > 0 then
        return L.CONJURE_COUNT:format(Conjure.Name(e), e.count)
    end
    return L.MISSING:format(Conjure.Name(e))
end

-- Item-Daten der angezeigten Items vorladen (Namen kommen per GET_ITEM_INFO_RECEIVED / Ticker)
function Conjure.Preload(list)
    for _, e in ipairs(list) do
        if e.kind == "conjure" then
            for _, id in pairs(e.conj.rankItems) do ItemName(id) end
        end
    end
end

---------------------------------------------------------------------------
-- Buff-Erkennung
---------------------------------------------------------------------------
-- liefert idSet, nameSet, unreliable, own, list  (nil = gar nicht lesbar); unit Standard "player"
--   own  = { ids, names } nur der selbst gewirkten Auren (für das Merken der Variante)
--   list = { { id, name, icon }, ... } aller lesbaren Auren (icon nil, falls secret)
local function ScanAuras(unit)
    unit = unit or "player"
    local ids, names, unreliable = {}, {}, false
    local own = { ids = {}, names = {} }
    local list = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok then return nil end
            if aura == nil then break end
            if IsSecret(aura) then
                unreliable = true
            else
                local id, name = aura.spellId, aura.name
                if IsSecret(id) or IsSecret(name) then
                    unreliable = true
                else
                    if id then ids[id] = true end
                    if name then names[name] = true end
                    local src = aura.sourceUnit
                    local isOwn = not IsSecret(src) and src == "player"
                    if isOwn then
                        if id then own.ids[id] = true end
                        if name then own.names[name] = true end
                    end
                    local icon = aura.icon
                    if IsSecret(icon) then icon = nil end
                    -- Laufzeit (für den Ess-Countdown); Secret-Werte -> nil
                    local dur, exp = aura.duration, aura.expirationTime
                    if IsSecret(dur) or IsSecret(exp) then dur, exp = nil, nil end
                    list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp,
                        isOwn = isOwn, secretSrc = IsSecret(src), points = Scroll.AuraPoints(aura) }
                end
            end
        end
        return ids, names, unreliable, own, list
    elseif UnitBuff then
        for i = 1, 40 do
            local name, icon, _, _, dur, exp, src, _, _, id = UnitBuff(unit, i)
            if not name then break end
            names[name] = true
            if id then ids[id] = true end
            if src == "player" then
                own.names[name] = true
                if id then own.ids[id] = true end
            end
            list[#list + 1] = { id = id, name = name, icon = icon, duration = dur, expirationTime = exp,
                isOwn = (src == "player"), secretSrc = false }
        end
        return ids, names, false, own, list
    end
    return nil
end

local function HasWeaponIn(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id then return false end
    if slot == 16 then return true end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return true end
    local ok, _, _, _, _, _, classID = pcall(fn, id)
    return ok and classID == 2   -- 2 = Waffe (kein Schild/Nebenhandgegenstand)
end

local function WeaponEnchants()
    if not GetWeaponEnchantInfo then return nil end
    local ok, mh, _, _, _, oh = pcall(GetWeaponEnchantInfo)
    if not ok or IsSecret(mh) or IsSecret(oh) then return nil end
    return mh and true or false, oh and true or false
end

-- Namenstreffer einer einzelnen Aura (exakter Name oder normalisiert);
-- Auren mit ausgeschlossener Spell-ID (excludeIds) zählen nie
local function AuraNameMatch(e, a)
    if not a.name then return false end
    if a.id and e.excludeSet and e.excludeSet[a.id] then return false end
    for _, n in ipairs(e.names) do
        if a.name == n then return true end
    end
    return next(e.normNames) ~= nil and e.normNames[NormName(a.name)] == true
end

-- passende aktive Aura eines Eintrags (für das Icon), nil = keine
local function FindAura(e, scan)
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then return a end
    end
end

-- true = fehlt, false = vorhanden / nicht relevant, nil = unbekannt
local function CheckMissing(e, scan)
    if e.kind == "reagent" then
        local n = ItemCount(e.item)
        if n == nil then return nil end
        e.count = n
        return n < ReagentThreshold(e.item)
    end
    if e.kind == "conjure" then return Conjure.Missing(e) end
    if e.kind == "tracking" then return Tracking.Missing(e, scan) end
    if e.kind == "pet" then return Pet.Missing(e) end
    if e.kind == "supply" then return Supply.Missing(e) end
    if e.kind == "elixir" then
        local pre = Elixir.Precheck(e)   -- nicht in den Taschen / Buff unbekannt -> keine Warnung
        if pre ~= nil then return pre end
    end
    if e.kind == "scroll" then
        local pre = Scroll.Precheck(e, scan)   -- keine Rolle / Wert durch Klassenbuff abgedeckt
        if pre ~= nil then return pre end
    end
    if e.kind == "weapon_mh" or e.kind == "weapon_oh" then
        local slot = (e.kind == "weapon_mh") and 16 or 17
        if not HasWeaponIn(slot) then return false end
        local mh, oh = WeaponEnchants()
        if mh == nil then return nil end
        local active = (slot == 16) and mh or oh
        if active then return false end
        -- Waffen-Items: nur warnen, wenn ein passendes Item in den Taschen liegt
        if e.weaponItems and #Items.ItemChoices(e) == 0 then return false end
        return true
    end
    if not scan then return nil end
    for id in pairs(e.idSet) do
        if scan.ids[id] then return false end
    end
    if e.excludeSet then
        -- Name-Fallback pro Aura, damit ausgeschlossene IDs nicht per Name treffen
        for _, a in ipairs(scan.list) do
            if AuraNameMatch(e, a) then return false end
        end
    else
        for _, n in ipairs(e.names) do
            if scan.names[n] then return false end
        end
        if next(e.normNames) then
            for n in pairs(scan.names) do
                if e.normNames[NormName(n)] then return false end
            end
        end
    end
    if scan.unreliable then return nil end
    return true
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if UnitInVehicle and UnitInVehicle("player") then return true end
    return false
end

local function InGroupInstance()
    local inInst, t = IsInInstance()
    return inInst and (t == "party" or t == "raid")
end

-- Für andere Dateien (ns)
ns.EntryLabel = EntryLabel
ns.EntryIcon = EntryIcon
ns.PrepareEntry = PrepareEntry
ns.SpellKnown = SpellKnown
ns.RefreshKnown = RefreshKnown
ns.IsEnabled = IsEnabled
ns.MuteRemaining = MuteRemaining
ns.IsWeaponEntry = IsWeaponEntry
ns.KnownByName = KnownByName
ns.BestCast = BestCast
ns.PrepareCast = PrepareCast
ns.VariantByKey = VariantByKey
ns.CastSpellFor = CastSpellFor
ns.RememberFromCast = RememberFromCast
ns.VariantActive = VariantActive
ns.RememberFromAuras = RememberFromAuras
ns.ScanAuras = ScanAuras
ns.AuraNameMatch = AuraNameMatch
ns.FindAura = FindAura
ns.CheckMissing = CheckMissing
ns.Suppressed = Suppressed
ns.InGroupInstance = InGroupInstance
