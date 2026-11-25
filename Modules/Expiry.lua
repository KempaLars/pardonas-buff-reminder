-- Pardona's Buff Reminder – Warnung vor Ablauf (Schalter expExpiry).
-- Abhängigkeiten (beim Laden): Core.lua, Detect.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local Expiry = ns.Expiry
local IsSecret = ns.IsSecret
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local IsWeaponEntry = ns.IsWeaponEntry
local AuraNameMatch = ns.AuraNameMatch
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db
ns.OnDB(function(newDb) db = newDb end)

---------------------------------------------------------------------------
-- Warnung vor Ablauf (Schalter expExpiry)
-- Für aktive eigene Buffs der aktivierten Einträge: Klassenbuffs, Well Fed, Fläschchen und
-- temporäre Waffenverzauberungen. Gewarnt wird, wenn Restdauer <= expiryPct % der Gesamtdauer.
-- Dauer/Ablaufzeit aus den Aura-Daten; secret, fehlend oder Dauer 0 -> keine Ablaufwarnung.
-- Waffen: GetWeaponEnchantInfo liefert nur die Restzeit; Gesamtdauer = höchste seit dem
-- Erscheinen der Verzauberung gesehene Restzeit pro Slot.
-- Gifte haben zusätzlich Ladungen (3./7. Rückgabewert): Gesamtzahl = höchste gesehene Ladungszahl
-- derselben Verzauberung. Gewarnt wird, sobald Restzeit ODER Ladungen <= expiryPct % sind; was
-- zuerst knapp wurde, bestimmt den Zeilentext (Zeit bzw. "x Ladungen"). Ohne Ladungen (Steine,
-- Öle, Schamanen-Waffenbuffs) zählt nur die Zeit.
---------------------------------------------------------------------------
-- Slot (16/17) -> { max = Sek., left = Sek. | nil, id = Enchant-ID | nil, charges = Ladungen | nil,
--                   maxCharges = höchste gesehene Ladungen | nil, lowBy = "time" | "charges" | nil }
Expiry.weapon = {}
Expiry.shownEnd = {} -- Eintrag-Key -> Ende (GetTime) der zuletzt angezeigten Ablauf-Zeile (Evaluate)

function Expiry.Pct()
    local v = tonumber(db and db.expiryPct) or 10
    return math.max(5, math.min(50, v))
end

function Expiry.Alpha()
    local v = tonumber(db and db.expiryAlpha) or 0.5
    return math.max(0.2, math.min(1, v))
end

-- Welche Einträge können eine Ablauf-Zeile bekommen? (nicht: Reagenzien, Well-Rested)
function Expiry.Eligible(e)
    if e.kind == "reagent" or e.kind == "conjure" or e.kind == "tracking" or e.kind == "pet"
        or e.kind == "supply" then
        return false
    end
    if e.general then
        return e.itemKind == "food" or e.itemKind == "flask" or e.itemKind == "elixir" or e.itemKind == "scroll"
            or e.weaponItems == true
    end
    return true
end

-- Restzeit und Ladungen eines Slots aktualisieren; Secret-Werte -> unbekannt (keine Warnung)
function Expiry.UpdateSlot(slot, has, ms, charges, id)
    local w = Expiry.weapon[slot]
    if IsSecret(has) or IsSecret(ms) then
        if w then w.left, w.charges = nil, nil end
        return
    end
    if not has or type(ms) ~= "number" then Expiry.weapon[slot] = nil; return end
    if IsSecret(id) or type(id) ~= "number" then id = nil end
    if IsSecret(charges) or type(charges) ~= "number" then charges = nil end
    local left = ms / 1000
    -- neue Verzauberung (andere ID) oder Restzeit gestiegen (neu aufgetragen): neues Maximum
    -- (auch der Ladungen)
    if not w or (id and w.id and id ~= w.id) or left > w.max then
        w = { max = left, id = id }
        Expiry.weapon[slot] = w
    end
    w.left, w.charges = left, charges
    -- mehr Ladungen als bisher gesehen (neu aufgetragen): neue Gesamtzahl
    if charges and charges > (w.maxCharges or 0) then w.maxCharges = charges end
end

function Expiry.UpdateWeapons()
    if not GetWeaponEnchantInfo then wipe(Expiry.weapon); return end
    local ok, hasMH, mhMs, mhCharges, mhId, hasOH, ohMs, ohCharges, ohId = pcall(GetWeaponEnchantInfo)
    if not ok then wipe(Expiry.weapon); return end
    Expiry.UpdateSlot(16, hasMH, mhMs, mhCharges, mhId)
    Expiry.UpdateSlot(17, hasOH, ohMs, ohCharges, ohId)
end

-- Waffen-Slot knapp? Restzeit (Sek.) oder nil; setzt e.expiryCharges, wenn die Ladungen zuerst
-- knapp wurden (Zeilentext "x Ladungen")
function Expiry.WeaponLeft(e, frac)
    local w = Expiry.weapon[e.kind == "weapon_mh" and 16 or 17]
    if not w or not w.left or w.max <= 0 or w.left <= 0 then return nil end
    local timeLow = w.left <= w.max * frac
    local mc = w.maxCharges
    local chargesLow = w.charges ~= nil and w.charges > 0 and mc ~= nil and mc > 0 and w.charges / mc <= frac
    if not (timeLow or chargesLow) then
        w.lowBy = nil
        return nil
    end
    if not w.lowBy then w.lowBy = timeLow and "time" or "charges" end
    if w.lowBy == "charges" and chargesLow then e.expiryCharges = w.charges end
    return w.left
end

-- Restzeit in Sek., wenn der Eintrag bald abläuft; sonst nil
function Expiry.Left(e, scan)
    local frac = Expiry.Pct() / 100
    e.expiryCharges = nil
    if IsWeaponEntry(e) then return Expiry.WeaponLeft(e, frac) end
    if not scan then return nil end
    local now, best = GetTime(), nil
    for _, a in ipairs(scan.list) do
        if (a.id and e.idSet[a.id]) or AuraNameMatch(e, a) then
            local dur, exp = a.duration, a.expirationTime
            -- ScanAuras setzt Secret-Laufzeiten auf nil
            if type(dur) ~= "number" or type(exp) ~= "number" or dur <= 0 or exp <= 0 then return nil end
            local left = exp - now
            if left > dur * frac then return nil end   -- eine passende Aura hält noch
            if left > 0 and (not best or left > best) then best = left end
        end
    end
    return best
end

function Expiry.FormatLeft(sec)
    sec = math.max(0, math.ceil(sec))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- "Name läuft ab · 1:45" bzw. bei Giften, deren Ladungen zuerst knapp wurden, "… · 12 Ladungen"
function Expiry.Text(e)
    if e.expiryCharges then return L.EXPIRES_CHARGES:format(EntryLabel(e), e.expiryCharges) end
    return L.EXPIRES:format(EntryLabel(e), Expiry.FormatLeft((e.expiryEnd or 0) - GetTime()))
end
