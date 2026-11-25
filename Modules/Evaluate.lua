-- Pardona's Buff Reminder – Prüflogik: Evaluate (welche Warnungen angezeigt werden) und Test-Erinnerung.
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Detect.lua, Display.lua, Keybind.lua; zur Laufzeit: ns.RefreshConfig (Config.lua)

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Eat = ns.Eat
local Group = ns.Group
local Display = ns.Display
local Expiry = ns.Expiry
local Conjure = ns.Conjure
local Demo = ns.Demo
local Pet = ns.Pet
local Supply = ns.Supply
local Ranks = ns.Ranks
local entries = ns.entries
local knownCache = ns.knownCache
local missing = ns.missing
local missingSince = ns.missingSince
local MISSING_CONFIRM = ns.MISSING_CONFIRM
local shownKeys = ns.shownKeys
local Print = ns.Print
local RefreshPardonaStatus = ns.RefreshPardonaStatus
local ExpOn = ns.ExpOn
local GroupFeatureOn = ns.GroupFeatureOn
-- aus Data.lua
local GENERAL_BUFFS = ns.GENERAL_BUFFS
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local EntryIcon = ns.EntryIcon
local IsEnabled = ns.IsEnabled
local MuteRemaining = ns.MuteRemaining
local RememberFromAuras = ns.RememberFromAuras
local ScanAuras = ns.ScanAuras
local FindAura = ns.FindAura
local CheckMissing = ns.CheckMissing
local Suppressed = ns.Suppressed
local InGroupInstance = ns.InGroupInstance
-- aus Display.lua
local ApplyLayout = ns.ApplyLayout
-- aus Keybind.lua
local PlayAlertSound = ns.PlayAlertSound
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db
ns.OnDB(function(newDb) db = newDb end)
-- nur in dieser Datei
local testUntil = 0          -- Test-Erinnerung bis GetTime() (StartTest)
local Evaluate               -- forward (function Evaluate unten)

---------------------------------------------------------------------------
-- Prüflogik
---------------------------------------------------------------------------
function Evaluate()
    if not db or not State.ready then return end
    if Demo.active then return end   -- Demo-Modus: Anzeige gehört der Demo; Ende wertet neu aus
    -- Vorräte: im Ruhebereich Zurückstellungen aufheben (Händler/Bank: per Event)
    if Supply.Resting() then Supply.Unsnooze() end
    -- Im Kampf wird nur der Zustand aktualisiert; die Warnliste (Secure Buttons)
    -- bleibt unverändert und wird bei PLAYER_REGEN_ENABLED neu aufgebaut.
    local combat = InCombatLockdown()
    if State.layoutPending and not combat then ApplyLayout() end
    if Display.stylePending and not combat then Display.ApplyStyle() end

    if State.unlocked then
        if not combat then
            Display.ShowRows({ { key = "_drag", label = "DRAG", icon = EntryIcon(entries[1] or {}) } }, true)
        end
        if ns.RefreshConfig then ns.RefreshConfig() end
        return
    end

    if GetTime() < testUntil then
        local list = {}
        for _, e in ipairs(entries) do
            if knownCache[e.key] and IsEnabled(e) then list[#list + 1] = e end
        end
        if #list == 0 and entries[1] then list[1] = entries[1] end
        if ExpOn("expRanks") then list[#list + 1] = Ranks.TestEntry() end   -- Beispiel-Rangzeile
        Display.ShowRows(list)
        return
    end

    local list, newOnes = {}, false
    local expList, expOn = {}, ExpOn("expExpiry")   -- Warnung vor Ablauf: eigene Zeilen nach den fehlenden
    if db.enabled and not Suppressed() then
        if expOn then Expiry.UpdateWeapons() end
        local ids, names, unreliable, own, auraList = ScanAuras()
        local scan = ids and { ids = ids, names = names, unreliable = unreliable, list = auraList } or nil
        RememberFromAuras(own)
        if scan then
            -- Icons der allgemeinen Buffs aus dem Spiel merken (account-weit)
            for _, e in ipairs(GENERAL_BUFFS) do
                local a = FindAura(e, scan)
                if a and a.icon then db.iconCache[e.key] = a.icon end
            end
        end
        local instOk = (not db.instanceOnly) or InGroupInstance()
        local now = GetTime()
        -- Gruppen-Buffs: nur außerhalb des Kampfes auswerten (gedrosselt)
        if not combat and GroupFeatureOn() then Group.GroupScanIfDue(now) end
        -- Isst der Spieler gerade? (nil auch bei nicht lesbarer Aura → normale Anzeige)
        if State.foodEntry then State.foodEntry.eatStart = Eat.FindEatStart(scan) end

        for _, e in ipairs(entries) do
            local relevant = knownCache[e.key] and IsEnabled(e) and (not e.general or e.everywhere or instOk)
            -- Gruppen-Check aktiv: Gruppen-Zeile ersetzt die Selbst-Zeile (gleicher Key)
            e.groupActive = relevant and Group.GroupActive(e) or false
            if relevant then
                local m
                if e.groupActive then
                    if not combat then m = Group.GroupMissing(e) end   -- im Kampf: Zustand beibehalten
                else
                    m = CheckMissing(e, scan)
                end
                if m ~= nil then missing[e.key] = m end   -- nil: Zustand beibehalten (Kampf/Secret)
                -- Entprellung: nil (unbekannt) lässt missingSince unverändert
                if m == true then
                    if not missingSince[e.key] then
                        missingSince[e.key] = now
                        -- Einmalige Nachprüfung genau nach Ablauf der Entprellung statt erst
                        -- beim nächsten Ticker-Tick; höchstens ein ausstehender Timer.
                        if not Display.confirmTimerPending then
                            Display.confirmTimerPending = true
                            C_Timer.After(MISSING_CONFIRM + 0.05, function()
                                Display.confirmTimerPending = false
                                Evaluate()
                            end)
                        end
                    end
                elseif m == false then
                    missingSince[e.key] = nil
                    Supply.returning[e.key] = nil
                end
            else
                missing[e.key] = false
                missingSince[e.key] = nil
            end
            -- Angezeigt wird erst nach MISSING_CONFIRM Sek. durchgehendem Fehlen (eine
            -- kurzzeitig leere Aura-Liste, z. B. nach Ladebildschirmen, löst nichts aus).
            -- Bereits angezeigte Warnungen bleiben stehen, solange der Buff fehlt.
            -- Ausnahme: War der Buff als Ablauf-Zeile angezeigt (Expiry.shownEnd) und ist seine
            -- Restzeit so gut wie vorbei (höchstens 2 Sek. vor dem angezeigten Ende), gilt das Fehlen
            -- sofort als bestätigt: die Ablauf-Zeile wird ohne Lücke zur Fehlt-Zeile. Ein vorzeitiges
            -- Verschwinden (z. B. leere Aura-Liste nach Ladebildschirm) bleibt entprellt.
            local since = missingSince[e.key]
            local shownEnd = Expiry.shownEnd[e.key]
            local confirmed = shownKeys[e.key] or (since ~= nil and now - since >= MISSING_CONFIRM)
                or (shownEnd ~= nil and now >= shownEnd - 2)
            -- Ess-Countdown: Zeile sofort zeigen, zählt aber nicht als "neu fehlend" (keine
            -- Chatmeldung, kein Ton). Da sie danach in shownKeys steht, bleibt auch die normale
            -- Warnung nach dem Aufstehen (Ess-Aura weg, kein Well Fed) ohne erneute Meldung.
            local eating = e.eatStart ~= nil
            -- Vorräte: zurückgestellte Einträge (nicht kritisch) bis zur nächsten Stadt ausblenden;
            -- zurückgestellte bzw. gerade zurückgekehrte ohne Chatzeile und Ton (Supply.Quiet)
            if missing[e.key] and (confirmed or eating) and not MuteRemaining(e.key) and not Supply.Hidden(e) then
                list[#list + 1] = e
                if not combat and not shownKeys[e.key] and not eating and not Supply.Quiet(e) then
                    newOnes = true
                    if e.kind == "reagent" then
                        Print(L.REAGENT_CHAT:format(EntryLabel(e), e.count or 0))
                    elseif e.kind == "conjure" then
                        Print(L.CONJURE_CHAT:format(Conjure.Text(e)))
                    elseif e.kind == "pet" then
                        Print(L.ALERT_CHAT:format(Pet.Text(e)))
                    elseif e.kind == "supply" then
                        Print(Supply.ChatText(e))
                    elseif e.kind == "tracking" then
                        Print(L.ALERT_CHAT:format(L.TRACK_OFF:format(EntryLabel(e))))
                    elseif e.groupActive then
                        Print(L.GROUP_CHAT:format(EntryLabel(e), #(e.groupMissing or {})))
                    else
                        Print(L.CHAT:format(EntryLabel(e)))
                    end
                end
            end
            -- Warnung vor Ablauf: Buff vorhanden, läuft aber bald ab (kein Ton, keine Chatmeldung)
            e.expiryEnd, e.expiryCharges = nil, nil
            if expOn and relevant and missing[e.key] == false and not e.groupActive and not eating
                and Expiry.Eligible(e) and not MuteRemaining(e.key) then
                local left = Expiry.Left(e, scan)
                if left then
                    e.expiryEnd = now + left
                    expList[#expList + 1] = e
                end
            end
        end
        Supply.AmmoAlert(combat)   -- Munition unter der kritischen Grenze: im Kampf rote Meldung + Ton
        -- Niedrige Zauberränge: sichtbar erst nach dem Kampf (Ranks.OnCombatEnd); gelten nicht als
        -- "weitere Buffs" ("Nur in Instanzen" wirkt nicht), neue Zeilen mit Chatzeile und Ton
        if ExpOn("expRanks") then
            for _, e in ipairs(Ranks.Entries()) do
                if not MuteRemaining(e.key) then
                    list[#list + 1] = e
                    if not combat and not shownKeys[e.key] then
                        newOnes = true
                        Print(L.ALERT_CHAT:format(Ranks.Text(e)))
                    end
                end
            end
        end
    end

    if combat then
        -- Meldung, Ton und Anzeige folgen nach dem Kampf; Restzeit vorhandener Ablauf-Zeilen läuft weiter
        Display.TickExpiry()
        Display.TickSupplies()   -- Munition: sichtbare Zeile zählt live mit
        if ns.RefreshConfig then ns.RefreshConfig() end
        return
    end

    wipe(shownKeys)
    for _, e in ipairs(list) do shownKeys[e.key] = true end
    -- Ablauf-Zeilen dieser Anzeige mit ihrem Ende (sofortige Bestätigung beim Ablauf, s. o.)
    wipe(Expiry.shownEnd)
    for _, e in ipairs(expList) do Expiry.shownEnd[e.key] = e.expiryEnd end
    if newOnes then PlayAlertSound() end   -- Ton nur bei neu fehlendem Buff, keine Wiederholung
    local missingCount = #list
    for _, e in ipairs(expList) do list[#list + 1] = e end
    Display.ShowRows(list, false, missingCount + 1)

    -- Kurzstatus für das Pardona-Menü: nur bei Änderung neu anzeigen
    local count = db.enabled and missingCount or -1
    if count ~= State.warnCount then
        State.warnCount = count
        RefreshPardonaStatus()
    end

    if ns.RefreshConfig then ns.RefreshConfig() end
end

-- Test-Erinnerung (5 Sek.); im Kampf nicht möglich (Secure Buttons)
local function StartTest()
    if InCombatLockdown() then Print(L.COMBAT); return end
    testUntil = GetTime() + 5
    PlayAlertSound()
    Evaluate()
end

-- Für andere Dateien (ns)
ns.StartTest = StartTest
ns.Evaluate = Evaluate
