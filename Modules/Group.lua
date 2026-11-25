-- Pardona's Buff Reminder – Gruppen-Buffs: Prüfung aller Party-/Raid-Mitglieder (inkl. Spieler selbst).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Detect.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua)

local ADDON_NAME, ns = ...

-- aus Core.lua
local Group = ns.Group
local entries = ns.entries
local knownCache = ns.knownCache
local Print = ns.Print
local IsSecret = ns.IsSecret
local ExpOn = ns.ExpOn
local GroupFeatureOn = ns.GroupFeatureOn
local SpellName = ns.SpellName
-- aus Data.lua
local MANA_CLASSES = ns.MANA_CLASSES
local RANK_INFO = ns.RANK_INFO
-- aus Items.lua
local ItemCount = ns.ItemCount
-- aus Detect.lua
local SpellKnown = ns.SpellKnown
local IsEnabled = ns.IsEnabled
local KnownByName = ns.KnownByName
local BestCast = ns.BestCast
local VariantByKey = ns.VariantByKey
local CastSpellFor = ns.CastSpellFor
local VariantActive = ns.VariantActive
local ScanAuras = ns.ScanAuras
local AuraNameMatch = ns.AuraNameMatch
local CheckMissing = ns.CheckMissing
local InGroupInstance = ns.InGroupInstance
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Gruppen-Buffs: Prüfung aller Party-/Raid-Mitglieder (inkl. Spieler selbst)
-- Nur außerhalb des Kampfes. Ergebnis je Eintrag in groupState; ausgewertet wird
-- gedrosselt (höchstens alle GROUP_THROTTLE Sek.), ohne Event spätestens alle
-- GROUP_POLL Sek. (Reichweite/Sichtbarkeit ändern sich ohne Event).
---------------------------------------------------------------------------
Group.groupState = {}         -- key -> { missing = { { unit, name }, ... }, unknown = bool }
Group.groupDirty, Group.groupLastScan, Group.groupTimerPending = true, 0, false
Group.GROUP_THROTTLE, Group.GROUP_POLL = 0.5, 2

-- Ja/Nein-Abfrage einer Unit-Funktion; nil = nicht verfügbar oder Secret-Wert
function Group.UnitFlag(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or IsSecret(v) then return nil end
    return v and true or false
end

function Group.GroupModeOk()
    if db.groupMode == "instance" then return InGroupInstance() end
    if db.groupMode == "raid" then
        local inInst, t = IsInInstance()
        return inInst and t == "raid"
    end
    return true
end

-- Segen des Paladins in den Gruppenbuffs: experimentell (expBlessings, zusätzlich zu expGroup)
-- und komplett aus, solange Pally Power geladen ist (Group.pallyPower, nach PLAYER_LOGIN).
-- Der eigene Segen-Eintrag (Klassenbuff auf sich selbst) ist davon unabhängig.
function Group.BlessingsOn()
    return ExpOn("expBlessings") and not Group.pallyPower
end

function Group.SupportsGroup(e)
    if e.groupByVariant then return Group.BlessingsOn() end
    return e.groupIds ~= nil
end

-- Ist ein Addon geladen, dessen Ordnername mit "PallyPower" beginnt? (einmal nach PLAYER_LOGIN)
function Group.DetectPallyPower()
    Group.pallyPower = false
    local api = C_AddOns or {}
    local numFn = api.GetNumAddOns or GetNumAddOns
    local infoFn = api.GetAddOnInfo or GetAddOnInfo
    local loadedFn = api.IsAddOnLoaded or IsAddOnLoaded
    if not (numFn and infoFn and loadedFn) then return end
    local ok, n = pcall(numFn)
    if not ok or type(n) ~= "number" or IsSecret(n) then return end
    for i = 1, n do
        local okI, name = pcall(infoFn, i)
        if okI and type(name) == "string" and not IsSecret(name) and name:sub(1, 10) == "PallyPower" then
            local okL, loaded = pcall(loadedFn, name)
            if okL and loaded and not IsSecret(loaded) then
                Group.pallyPower = true
                return
            end
        end
    end
end

-- Gruppen-Check für einen (erlernten, aktivierten) Eintrag aktiv?
function Group.GroupActive(e)
    return Group.SupportsGroup(e) and GroupFeatureOn() and IsInGroup ~= nil and IsInGroup() and Group.GroupModeOk()
end

function Group.GroupUnits()
    local units = {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        units[1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Prüf- und Zielbarkeit: existiert, online, lebt, sichtbar, in Reichweite.
-- Secret-Werte bei UnitInRange (z. B. WoW 12.0 / Forever) blockieren die Prüfung nicht;
-- es greift dann UnitIsVisible.
function Group.UnitUsable(unit)
    if Group.UnitFlag(UnitExists, unit) ~= true then return false end
    if UnitIsConnected and Group.UnitFlag(UnitIsConnected, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsDeadOrGhost, unit) ~= false then return false end
    if UnitIsVisible and Group.UnitFlag(UnitIsVisible, unit) ~= true then return false end
    if Group.UnitFlag(UnitIsUnit, unit, "player") == true then return true end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if ok and not IsSecret(inRange) and not IsSecret(checked) and checked and not inRange then
            return false
        end
    end
    return true
end

function Group.UnitClassFile(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and class and not IsSecret(class) then return class end
end

function Group.UnitDisplayName(unit)
    local ok, n = pcall(UnitName, unit)
    if ok and n and not IsSecret(n) then return n end
    return "?"
end

function Group.UnitFullName(unit)
    local ok, n, r = pcall(UnitName, unit)
    if not ok or not n or IsSecret(n) then return "?" end
    if type(r) == "string" and r ~= "" and not IsSecret(r) then
        return n .. "-" .. (r:gsub("[%s%-]", ""))
    end
    return n
end

function Group.UnitKey(unit)
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and type(guid) == "string" and guid ~= "" and not IsSecret(guid) then
            return guid
        end
    end
    return Group.UnitFullName(unit)
end

function Group.OwnRealm()
    local fn = GetNormalizedRealmName or GetRealmName
    if not fn then return nil end
    local ok, r = pcall(fn)
    if ok and type(r) == "string" and r ~= "" and not IsSecret(r) then
        return (r:gsub("[%s%-]", ""))
    end
end

Group.BLESSING_ALL = { "kings", "might", "wisdom", "sanctuary" }
Group.BLESSING_BY_CLASS = {
    WARRIOR     = { "kings", "might", "sanctuary" },
    ROGUE       = { "kings", "might", "sanctuary" },
    DEATHKNIGHT = { "kings", "might", "sanctuary" },
    MAGE        = { "kings", "wisdom", "sanctuary" },
    PRIEST      = { "kings", "wisdom", "sanctuary" },
    WARLOCK     = { "kings", "wisdom", "sanctuary" },
}
Group.OUR_POWER = {
    -- Blessing of Might / Greater Blessing of Might (AP)
    [19740] = 20,  [19834] = 35,  [19835] = 55,  [19836] = 85,  [19837] = 115,
    [19838] = 155, [25291] = 185, [27140] = 220, [48931] = 305, [48932] = 550,
    [25782] = 155, [25916] = 185, [27141] = 220, [48933] = 305, [48934] = 550,
    -- Blessing of Wisdom / Greater Blessing of Wisdom (MP5)
    [19742] = 10,  [19850] = 15,  [19852] = 20,  [19853] = 25,  [19854] = 30,
    [25290] = 33,  [27142] = 41,  [48935] = 50,  [48936] = 92,
    [25894] = 30,  [25918] = 33,  [27143] = 41,  [48937] = 50,  [48938] = 92,
}
Group.CONFLICTS = {
    might = {
        spellId = 6673,   -- Battle Shout
        power = { [6673] = 15, [5242] = 35, [6192] = 55, [11549] = 85, [11550] = 130,
                  [11551] = 185, [25289] = 232, [2048] = 305, [47436] = 550 },
    },
    wisdom = {
        spellId = 5677,   -- Mana Spring
        power = { [5677] = 10, [10491] = 15, [10493] = 20, [10494] = 25, [25569] = 34,
                  [58771] = 40, [58773] = 50, [58774] = 91 },
    },
}
Group.bounced = {}   -- "<unitKey>:<variant>" -> { ids = { [id]=true }, expires = GetTime()+120 }

function Group.IsBounced(unitKey, varKey, scan)
    local k = unitKey .. ":" .. varKey
    local b = Group.bounced[k]
    if not b then return false end
    if GetTime() >= b.expires then Group.bounced[k] = nil; return false end
    for id in pairs(b.ids) do
        if not scan.ids[id] then Group.bounced[k] = nil; return false end
    end
    return true
end

function Group.FindAttUnit(att)
    if att.unit and att.unitKey and Group.UnitKey(att.unit) == att.unitKey then
        return att.unit
    end
    if not att.name then return nil end
    local units = Group.GroupUnits()
    for _, u in ipairs(units) do
        if Group.UnitFullName(u) == att.name then return u end
    end
    -- Fallback: arg2 in UNIT_SPELLCAST_SENT kann "<Name>-<OwnRealm>" sein, während UnitName
    -- bei Spielern vom eigenen Realm keinen Realm-Teil liefert
    local short, realm = att.name:match("^([^%-]+)%-(.+)$")
    local ownRealm = Group.OwnRealm()
    if short and ownRealm and realm:gsub("[%s%-]", "") == ownRealm then
        for _, u in ipairs(units) do
            if Group.UnitFullName(u) == short then return u end
        end
    end
    return nil
end

function Group.RecordBounce(att)
    if not att or not att.variant then return end
    local u = Group.FindAttUnit(att)
    if not u then return end
    local ukey = Group.UnitKey(u)
    local ids = {}
    local _, _, _, _, auras = ScanAuras(u)
    for _, a in ipairs(auras or {}) do
        if a.id and not a.isOwn then ids[a.id] = true end
    end
    Group.bounced[ukey .. ":" .. att.variant] = { ids = ids, expires = GetTime() + 120 }
end

function Group.VariantBlocked(v, scan, unitKey)
    if VariantActive(v, scan) then return true end
    if unitKey and Group.IsBounced(unitKey, v.key, scan) then return true end
    local c = Group.CONFLICTS[v.key]
    if c then
        local ourSpell = BestCast(v.castIds)
        local ourPower = (type(ourSpell) == "number" and Group.OUR_POWER[ourSpell]) or 0
        local cname = SpellName(c.spellId)
        for _, a in ipairs(scan.list) do
            local p = a.id and c.power[a.id]
            if p ~= nil then
                if p >= ourPower then return true end
            elseif cname and a.name == cname then
                return true
            end
        end
    end
    return false
end

-- Passende Variante für das Ziel wählen: bevorzugte (lastVariant), falls noch nicht aktiv,
-- nicht durch stärkeren Buff blockiert und für die Klasse sinnvoll, sonst erste freie Variante.
function Group.PickVariant(e, class, scan, unitKey)
    local order = Group.BLESSING_BY_CLASS[class or ""] or Group.BLESSING_ALL
    local allowed = {}
    for _, k in ipairs(order) do allowed[k] = true end
    local function usable(k)
        local v = VariantByKey(e, k)
        return v and BestCast(v.castIds) ~= nil and not Group.VariantBlocked(v, scan, unitKey) and v or nil
    end
    local last = cdb and cdb.lastVariant and cdb.lastVariant[e.key]
    if last and allowed[last] then
        local v = usable(last)
        if v then return v end
    end
    for _, k in ipairs(order) do
        local v = usable(k)
        if v then return v end
    end
    return nil
end

-- Eigene Aura auf unit prüfen (ownOnly); liefert missing (true/false/nil) + gewählte Variante
function Group.CheckOwnEntry(e, class, scan, unitKey)
    if not scan then return nil end
    local secretHit = false
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then
            if a.isOwn then return false end
            if a.secretSrc then secretHit = true end
        end
    end
    if secretHit or scan.unreliable then return nil end
    if e.groupByVariant and e.variants then
        local v = Group.PickVariant(e, class, scan, unitKey)
        if not v then return false end
        return true, v
    end
    return true
end

function Group.ScanGroup()
    wipe(Group.groupState)
    local list = {}
    for _, e in ipairs(entries) do
        if Group.SupportsGroup(e) and knownCache[e.key] and IsEnabled(e) then
            list[#list + 1] = e
            Group.groupState[e.key] = { missing = {}, unknown = false }
        end
    end
    if #list == 0 then return end
    local shortCounts, scanned = {}, {}
    for _, unit in ipairs(Group.GroupUnits()) do
        if Group.UnitUsable(unit) then
            local ids, names, unreliable, _, auras = ScanAuras(unit)
            local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auras } or nil
            local short = Group.UnitDisplayName(unit)
            shortCounts[short] = (shortCounts[short] or 0) + 1
            scanned[#scanned + 1] = {
                unit = unit, scan = scan, class = Group.UnitClassFile(unit),
                short = short, full = Group.UnitFullName(unit), ukey = Group.UnitKey(unit),
            }
        end
    end
    for _, info in ipairs(scanned) do
        local uname = (shortCounts[info.short] or 0) > 1 and info.full or info.short
        for _, e in ipairs(list) do
            if not e.manaOnly or (info.class and MANA_CLASSES[info.class]) then
                local st = Group.groupState[e.key]
                local m, variant
                if e.ownOnly then
                    m, variant = Group.CheckOwnEntry(e, info.class, info.scan, info.ukey)
                else
                    -- Gruppen- und Einzelversion stehen beide in e.idSet / e.names
                    m = CheckMissing(e, info.scan)
                end
                if m == true then
                    st.missing[#st.missing + 1] = {
                        unit = info.unit, unitKey = info.ukey, name = uname,
                        fullName = info.full, variant = variant,
                    }
                elseif m == nil then
                    st.unknown = true
                end
            end
        end
    end
end

-- Auswertung, wenn fällig (nie im Kampf)
function Group.GroupScanIfDue(now)
    if InCombatLockdown() then return end
    if (Group.groupDirty or now - Group.groupLastScan >= Group.GROUP_POLL) and now - Group.groupLastScan >= Group.GROUP_THROTTLE then
        Group.ScanGroup()
        Group.groupLastScan, Group.groupDirty = now, false
    end
end

-- Aura/Roster geändert: neu auswerten, aber höchstens alle GROUP_THROTTLE Sek.
function Group.MarkGroupDirty()
    Group.groupDirty = true
    if Group.groupTimerPending then return end
    Group.groupTimerPending = true
    C_Timer.After(Group.GROUP_THROTTLE, function()
        Group.groupTimerPending = false
        ns.Evaluate()
    end)
end

-- true = jemandem fehlt der Buff, false = alle haben ihn, nil = unbekannt
function Group.GroupMissing(e)
    local st = Group.groupState[e.key]
    if not st then return nil end
    e.groupMissing = st.missing
    if #st.missing > 0 then return true end
    if st.unknown then return nil end
    return false
end

-- höchster erlernter Rang der Gruppenversion + dessen Reagenz; Namens-Fallback wie bei Reagenzien
function Group.GroupSpellFor(e, variant)
    local ids = e.groupIds
    if not ids and e.groupByVariant and e.variants then
        local v = variant or VariantByKey(e, cdb and cdb.lastVariant and cdb.lastVariant[e.key])
        ids = v and v.ids
    end
    if not ids or #ids == 0 then return nil end
    for i = #ids, 1, -1 do
        if SpellKnown(ids[i]) then return ids[i], RANK_INFO[ids[i]] and RANK_INFO[ids[i]].item end
    end
    local n = SpellName(ids[1])
    if KnownByName(n) then
        local lvl, best = UnitLevel("player") or 1, nil
        for i = #ids, 1, -1 do
            local info = RANK_INFO[ids[i]]
            if info and lvl >= info.level then best = info; break end
        end
        return n, best and best.item
    end
end

-- Klick-Aktion einer Gruppen-Zeile, Ziel = erster Spieler ohne Buff (Roster-Reihenfolge):
--   Linksklick      : Gruppenversion; Einzelversion, wenn nicht erlernt oder Reagenz fehlt
--   Strg+Linksklick : Einzelversion
function Group.GroupActionFor(e)
    local target = e.groupMissing and e.groupMissing[1]
    if not target or not db.clickCast then return nil end
    local single = (target.variant and BestCast(target.variant.castIds)) or CastSpellFor(e)
    if not single then return nil end
    local a = {
        unit = target.unit, unitKey = target.unitKey, targetName = target.name,
        targetFullName = target.fullName, ctrlSpell = single, ctrlUnit = target.unit,
    }
    local gspell, item = Group.GroupSpellFor(e, target.variant)
    if gspell and (not item or (ItemCount(item) or 1) > 0) then
        a.spell, a.isGroup = gspell, true
    else
        a.spell = single
    end
    a.spellName = SpellName(a.spell)
    a.variantKey = target.variant and target.variant.key
    return a
end

-- Namen der Spieler ohne Buff: max. 5, dann "+N"
function Group.MissingNames(e)
    local list, out = e.groupMissing or {}, {}
    for i = 1, math.min(5, #list) do out[i] = list[i].name end
    local s = table.concat(out, ", ")
    if #list > 5 then s = s .. " +" .. (#list - 5) end
    return s
end

function Group.PrintDebug(log)
    local function out(msg)
        Print(msg)
        if log then log[#log + 1] = msg end
    end
    local units = Group.GroupUnits()
    out(("group: feature=%s expGroup=%s blessings=%s pallyPower=%s check=%s mode=%s modeOk=%s inGroup=%s members=%d"):format(
        tostring(GroupFeatureOn()), tostring(ExpOn("expGroup")), tostring(ExpOn("expBlessings")),
        tostring(Group.pallyPower), tostring(db and db.groupCheck),
        tostring(db and db.groupMode), tostring(Group.GroupModeOk()),
        tostring(IsInGroup and IsInGroup()), GetNumGroupMembers and GetNumGroupMembers() or 0))
    for _, u in ipairs(units) do
        local ex = Group.UnitFlag(UnitExists, u)
        local co = UnitIsConnected and Group.UnitFlag(UnitIsConnected, u)
        local de = Group.UnitFlag(UnitIsDeadOrGhost, u)
        local vi = UnitIsVisible and Group.UnitFlag(UnitIsVisible, u)
        local irStr = "nil"
        if UnitInRange then
            local ok, ir, ch = pcall(UnitInRange, u)
            irStr = ok and (("%s/%s"):format(IsSecret(ir) and "secret" or tostring(ir),
                IsSecret(ch) and "secret" or tostring(ch))) or "err"
        end
        local ids, _, un, _, auras = ScanAuras(u)
        out(("  %s (%s): usable=%s ex=%s co=%s de=%s vi=%s range=%s scan=%s un=%s auras=%d"):format(
            u, Group.UnitFullName(u), tostring(Group.UnitUsable(u)),
            tostring(ex), tostring(co), tostring(de), tostring(vi), irStr,
            ids and "ok" or "nil", tostring(un), auras and #auras or 0))
        if log and auras and #auras > 0 then
            local list = {}
            for _, a in ipairs(auras) do
                list[#list + 1] = ("%s(%s%s)"):format(tostring(a.name), tostring(a.id),
                    a.isOwn and ",own" or (a.secretSrc and ",sec" or ""))
            end
            log[#log + 1] = "    auras: " .. table.concat(list, ", ")
        end
    end
    for _, e in ipairs(entries) do
        if Group.SupportsGroup(e) then
            local st = Group.groupState[e.key]
            out(("  entry %s: active=%s missing=%d unknown=%s lastVar=%s"):format(
                e.key, tostring(Group.GroupActive(e)),
                st and #st.missing or -1, tostring(st and st.unknown),
                tostring(cdb and cdb.lastVariant and cdb.lastVariant[e.key])))
        end
    end
end
