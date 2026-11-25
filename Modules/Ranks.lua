-- Pardona's Buff Reminder – Warnung bei niedrigen Zauberrängen (Schalter expRanks, beta): erkennt
-- gewirkte niedrigere Ränge, zeigt sie nach dem Kampf als Zeile, Akzeptieren und Ersetzen auf den Aktionsleisten.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua; zur Laufzeit: ns.Evaluate (Evaluate.lua), ns.RefreshConfig (Config.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Display = ns.Display
local Ranks = ns.Ranks
local Print = ns.Print
local IsSecret = ns.IsSecret
local ExpOn = ns.ExpOn
local SpellName = ns.SpellName
local SpellIcon = ns.SpellIcon
-- aus Data.lua
local FALLBACK_ICON = ns.FALLBACK_ICON
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local cdb
ns.OnDB(function(_, newCdb) cdb = newCdb end)

---------------------------------------------------------------------------
-- Warnung bei niedrigen Zauberrängen
--   Erkennung bei UNIT_SPELLCAST_SUCCEEDED (Spieler, Spell-ID auch im Kampf lesbar): Name der
--   gewirkten ID -> höchster gelernter Rang (C_Spell.GetSpellInfo(Name).spellID). Rangzahlen aus
--   C_Spell.GetSpellSubtext (erste Ziffernfolge, lokalisiert "Rank 3" / "Rang 3"). Niedriger Rang
--   nur, wenn beide Zahlen lesbar sind und der höchste Rang größer ist; alles andere wird ignoriert.
--   Ranks.pending : Zaubername -> { name, id, rank, best, bestRank, count } (nur Sitzung)
--   Ranks.shown   : sichtbar nach dem Kampf (PLAYER_REGEN_ENABLED übernimmt pending); je Eintrag
--                   .entry = Zeilen-Eintrag { key = "rank_<Name>", kind = "rank", rankInfo }
--   cdb.rankAccept[id] = true      : genau dieser Rang akzeptiert
--   cdb.rankAcceptAll[Name] = id   : alle Ränge des Zaubers akzeptiert (ID für Icon/Anzeige)
-- Die Zeile hat keine Secure-Aktion: Linksklick schließt sie über PostClick (wie bei den Vorräten).
---------------------------------------------------------------------------
Ranks.pending = {}
Ranks.shown = {}
Ranks.MAX_SLOTS = 180            -- Aktionsplätze: alle Leisten und Seiten (1-180)
Ranks.TEST = { id = 2050, best = 2053, rank = 1, bestRank = 3 }   -- Geringes Heilen Rang 1 / Rang 3 (Test, Demo)

-- Rangzahl eines Zaubers (erste Ziffernfolge des Rang-Texts); nil = ohne Rang oder nicht lesbar
function Ranks.RankOf(id)
    if not (C_Spell and C_Spell.GetSpellSubtext) then return nil end
    local ok, s = pcall(C_Spell.GetSpellSubtext, id)
    if not ok or type(s) ~= "string" or IsSecret(s) then return nil end
    local n = s:match("%d+")
    return n and tonumber(n) or nil
end

-- Spell-ID des höchsten gelernten Rangs eines Zaubernamens; nil = nicht lesbar
function Ranks.BestId(name)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if not ok or type(info) ~= "table" or IsSecret(info) then return nil end
    local id = info.spellID
    if type(id) ~= "number" or IsSecret(id) then return nil end
    return id
end

-- Akzeptiert? (genau dieser Rang oder alle Ränge des Zaubers)
function Ranks.Accepted(id, name)
    if not cdb then return true end
    return (cdb.rankAccept and cdb.rankAccept[id] == true)
        or (cdb.rankAcceptAll and cdb.rankAcceptAll[name] ~= nil) or false
end

-- UNIT_SPELLCAST_SUCCEEDED (Spieler): niedrigen Rang sammeln; angezeigt wird nach dem Kampf
function Ranks.OnCast(id)
    if not cdb or not ExpOn("expRanks") then return end
    if id == nil or IsSecret(id) or type(id) ~= "number" then return end
    local name = SpellName(id)
    if not name then return end
    local best = Ranks.BestId(name)
    if not best or best == id then return end
    local rank, bestRank = Ranks.RankOf(id), Ranks.RankOf(best)
    if not rank or not bestRank or bestRank <= rank then return end
    if Ranks.Accepted(id, name) then return end
    local p = Ranks.pending[name]
    if p then
        -- anderer oder gleicher niedriger Rang: der zuletzt gewirkte gilt, die Anzahl zählt weiter
        p.id, p.rank, p.best, p.bestRank, p.count = id, rank, best, bestRank, p.count + 1
    else
        Ranks.pending[name] = { name = name, id = id, rank = rank, best = best, bestRank = bestRank, count = 1 }
    end
end

-- PLAYER_REGEN_ENABLED: gesammelte Einträge sichtbar machen (pending leeren). Steht der Zauber
-- schon in der Liste, gilt der zuletzt gewirkte Rang und die Anzahl zählt weiter.
function Ranks.OnCombatEnd()
    if not next(Ranks.pending) then return end
    for name, p in pairs(Ranks.pending) do
        if not Ranks.Accepted(p.id, name) then
            local s = Ranks.shown[name]
            if s then
                s.id, s.rank, s.best, s.bestRank, s.count = p.id, p.rank, p.best, p.bestRank, s.count + p.count
            else
                s = { name = p.name, id = p.id, rank = p.rank, best = p.best, bestRank = p.bestRank, count = p.count }
                s.entry = { key = "rank_" .. name, kind = "rank", rankInfo = s }
                Ranks.shown[name] = s
            end
        end
    end
    wipe(Ranks.pending)
end

-- sichtbare Zeilen-Einträge, nach Zaubername sortiert
function Ranks.Entries()
    local list = {}
    for _, s in pairs(Ranks.shown) do list[#list + 1] = s.entry end
    table.sort(list, function(a, b) return a.rankInfo.name < b.rankInfo.name end)
    return list
end

-- Beispielzeile für /br test (Geringes Heilen: Rang 1 gewirkt, Rang 3 erlernt)
function Ranks.TestEntry()
    local t = Ranks.TEST
    local info = { name = SpellName(t.best) or "Lesser Heal", id = t.id, rank = t.rank, best = t.best,
        bestRank = t.bestRank, count = 1 }
    return { key = "rank_test", kind = "rank", rankInfo = info, test = true }
end

function Ranks.Label(e)
    return e.rankInfo.name
end

function Ranks.Icon(e)
    return SpellIcon(e.rankInfo.best) or SpellIcon(e.rankInfo.id) or FALLBACK_ICON
end

-- "<Name>: Rank 1 used - Rank 3 known (2x)"
function Ranks.Text(e)
    local i = e.rankInfo
    local text = L.RANK_LINE:format(i.name, i.rank, i.bestRank)
    if (i.count or 1) > 1 then text = text .. L.RANK_COUNT:format(i.count) end
    return text
end

-- Warnzeile füllen (aus Display.ShowRows; nur außerhalb des Kampfes): keine Secure-Aktion, der
-- Linksklick läuft über PostClick (Ranks.Dismiss)
function Ranks.FillRow(r, e, st)
    Display.SetRowLines(r, false)
    Display.SetRowAction(r, nil)
    Display.SetRowStatus(r, "missing")
    if st.rightText then
        r.text:SetText(e.rankInfo.name)
        r.right:SetText(L.RANK_N:format(e.rankInfo.rank))
    else
        r.text:SetText(Ranks.Text(e))
    end
    Display.SetRowHint(r, L.HINT_RANK)
end

-- Tooltip-Zeilen der Rang-Zeile (Klick-Hinweise)
function Ranks.AddTooltip()
    GameTooltip:AddLine(L.LEFTCLICK_DISMISS, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.RIGHTCLICK_OPTIONS, 0.8, 0.8, 0.8)
end

-- Zeile schließen; im Kampf verschwindet sie nach dem Kampf. Test-/Demo-Zeilen: nichts.
function Ranks.Dismiss(e)
    if not e or e.test or e.demo or not e.rankInfo then return end
    local name = e.rankInfo.name
    if Ranks.shown[name] == e.rankInfo then Ranks.shown[name] = nil end
    if not InCombatLockdown() then ns.Evaluate() end
end

-- Rechtsklick-Menü: genau diesen Rang bzw. alle Ränge akzeptieren (Zeile verschwindet)
function Ranks.Accept(e, all)
    if not e or e.test or e.demo or not e.rankInfo or not cdb then return end
    local i = e.rankInfo
    if all then
        cdb.rankAcceptAll[i.name] = i.id
        Ranks.pending[i.name] = nil
    else
        cdb.rankAccept[i.id] = true
        local p = Ranks.pending[i.name]
        if p and p.id == i.id then Ranks.pending[i.name] = nil end
    end
    Ranks.Dismiss(e)
    if ns.RefreshConfig then ns.RefreshConfig() end
end

-- Akzeptierten Eintrag entfernen (Einstellungen): kind "rank" = cdb.rankAccept, "all" = cdb.rankAcceptAll
function Ranks.Unaccept(kind, key)
    if not cdb then return end
    if kind == "all" then cdb.rankAcceptAll[key] = nil else cdb.rankAccept[key] = nil end
    if ns.RefreshConfig then ns.RefreshConfig() end
end

-- Liste der akzeptierten Einträge für die Einstellungen, nach Name und Rang sortiert:
-- { kind = "rank" | "all", key, id, name, rank }
function Ranks.AcceptedList()
    local list = {}
    if not cdb then return list end
    for id, on in pairs(cdb.rankAccept or {}) do
        if on == true then
            list[#list + 1] = { kind = "rank", key = id, id = id, name = SpellName(id) or tostring(id),
                rank = Ranks.RankOf(id) }
        end
    end
    for name, id in pairs(cdb.rankAcceptAll or {}) do
        list[#list + 1] = { kind = "all", key = name, id = id, name = name }
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        if a.kind ~= b.kind then return a.kind == "all" end
        return (a.rank or 0) < (b.rank or 0)
    end)
    return list
end

-- Anzahl akzeptierter Einträge (genau ein Rang, alle Ränge)
function Ranks.AcceptedCount()
    local n, all = 0, 0
    for _, on in pairs(cdb and cdb.rankAccept or {}) do if on == true then n = n + 1 end end
    for _ in pairs(cdb and cdb.rankAcceptAll or {}) do all = all + 1 end
    return n, all
end

-- Liegt etwas am Mauszeiger? (nicht lesbar = belegt, dann nichts anfassen)
function Ranks.CursorBusy()
    if type(GetCursorInfo) ~= "function" then return false end
    local ok, kind = pcall(GetCursorInfo)
    if not ok or IsSecret(kind) then return true end
    return kind ~= nil
end

-- Rechtsklick-Menü: alle Aktionsplätze mit genau dieser Spell-ID durch den höchsten Rang ersetzen
-- (nur außerhalb des Kampfes; Makros und andere Aktionen bleiben unberührt). Danach Zeile schließen.
function Ranks.ReplaceOnBars(e)
    if not e or e.test or e.demo or not e.rankInfo then return end
    if InCombatLockdown() then Print(L.COMBAT); return end
    local i = e.rankInfo
    local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
    if type(GetActionInfo) ~= "function" or type(PlaceAction) ~= "function" or type(pickup) ~= "function"
        or type(ClearCursor) ~= "function" then
        Print(L.RANK_NO_API)
        return
    end
    if Ranks.CursorBusy() then Print(L.RANK_CURSOR_BUSY); return end
    local n = 0
    for slot = 1, Ranks.MAX_SLOTS do
        local ok, kind, id = pcall(GetActionInfo, slot)
        if ok and kind == "spell" and not IsSecret(kind) and not IsSecret(id) and id == i.id then
            -- nur ablegen, wenn der höchste Rang wirklich am Mauszeiger hängt
            local picked = pcall(pickup, i.best) and Ranks.CursorBusy()
            if picked and pcall(PlaceAction, slot) then n = n + 1 end
            ClearCursor()              -- verdrängten Rang (bzw. Rest) vom Mauszeiger nehmen
        end
    end
    if n > 0 then
        Print(L.RANK_REPLACED:format(i.name, n))
    else
        Print(L.RANK_NOT_ON_BARS:format(i.name, i.rank))
    end
    Ranks.Dismiss(e)
end

-- Debug-Zeile für /br debug
function Ranks.DebugLine()
    local pending, shown = 0, 0
    for _ in pairs(Ranks.pending) do pending = pending + 1 end
    for _ in pairs(Ranks.shown) do shown = shown + 1 end
    local n, all = Ranks.AcceptedCount()
    return ("ranks: expRanks=%s pending=%d shown=%d accepted=%d acceptedAll=%d"):format(
        tostring(ExpOn("expRanks")), pending, shown, n, all)
end
