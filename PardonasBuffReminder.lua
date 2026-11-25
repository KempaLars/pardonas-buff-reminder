-- Pardona's Buff Reminder – WoW Forever (Interface 16001, Mainline-API)
-- Erinnert an fehlende Klassen- und allgemeine Buffs (auch bei Gruppen-/Raid-Mitgliedern)
-- sowie an knappe Reagenzien.
-- Auswahl per GUI (Pardona-Menü / Einstellungen / /br), Rechtsklick auf Erinnerung = stummschalten,
-- Linksklick auf Erinnerung = Buff auf sich selbst zaubern (abschaltbar);
-- bei Essen/Fläschchen = bestes Item aus den Taschen benutzen, Rechtsklick = Auswahl.
--
-- Diese Datei wird zuletzt geladen: Events, Initialisierung (ADDON_LOADED, PLAYER_LOGIN)
-- und Slash-Befehle. Alle übrigen Teile stehen in Modules/*.lua (Reihenfolge: TOC).

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Eat = ns.Eat
local Group = ns.Group
local Style = ns.Style
local Display = ns.Display
local Menu = ns.Menu
local Cfg = ns.Cfg
local Conjure = ns.Conjure
local Keybind = ns.Keybind
local Variant = ns.Variant
local Tracking = ns.Tracking
local Demo = ns.Demo
local Elixir = ns.Elixir
local Scroll = ns.Scroll
local Pet = ns.Pet
local Supply = ns.Supply
local Ranks = ns.Ranks
local Restock = ns.Restock
local entries = ns.entries
local reagentEntries = ns.reagentEntries
local knownCache = ns.knownCache
local missing = ns.missing
local missingSince = ns.missingSince
local muted = ns.muted
local Print = ns.Print
local NoteDeferred = ns.NoteDeferred
local IsSecret = ns.IsSecret
local RefreshPardonaStatus = ns.RefreshPardonaStatus
local PrintVersionNotice = ns.PrintVersionNotice
local GroupFeatureOn = ns.GroupFeatureOn
local SpellName = ns.SpellName
-- aus Data.lua
local CLASS_BUFFS = ns.CLASS_BUFFS
local GENERAL_BUFFS = ns.GENERAL_BUFFS
local REAGENT_SPELLS = ns.REAGENT_SPELLS
local GROUP_BUFFS = ns.GROUP_BUFFS
local DEFAULTS = ns.DEFAULTS
-- aus Items.lua
local ItemName = ns.ItemName
local CountKeys = ns.CountKeys
-- aus Detect.lua
local EntryLabel = ns.EntryLabel
local PrepareEntry = ns.PrepareEntry
local RefreshKnown = ns.RefreshKnown
local IsEnabled = ns.IsEnabled
local MuteRemaining = ns.MuteRemaining
local PrepareCast = ns.PrepareCast
local RememberFromCast = ns.RememberFromCast
local ScanAuras = ns.ScanAuras
local Suppressed = ns.Suppressed
local InGroupInstance = ns.InGroupInstance
-- aus Display.lua
local ApplyLayout = ns.ApplyLayout
-- aus Evaluate.lua
local StartTest = ns.StartTest
local Evaluate = ns.Evaluate
-- aus Config.lua
local ToggleConfig = ns.ToggleConfig
local RefreshConfig = ns.RefreshConfig
-- aus Pardona.lua
local RegisterPardona = ns.RegisterPardona
local RegisterPardonaSettings = ns.RegisterPardonaSettings
local TogglePardonaMinimap = ns.TogglePardonaMinimap
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)


---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function ApplyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then t[k] = type(v) == "table" and { unpack(v) } or v end
    end
end

-- Events nur registrieren, wenn der Client sie kennt (C_EventUtils.IsEventValid), und immer
-- per pcall. unit gesetzt: RegisterUnitEvent. Rückgabe: true = registriert.
local function SafeRegisterEvent(frame, event, unit)
    if C_EventUtils and C_EventUtils.IsEventValid then
        local okValid, valid = pcall(C_EventUtils.IsEventValid, event)
        if not okValid or not valid then return false end
    end
    if unit then return (pcall(frame.RegisterUnitEvent, frame, event, unit)) end
    return (pcall(frame.RegisterEvent, frame, event))
end

local ev = CreateFrame("Frame")
SafeRegisterEvent(ev, "ADDON_LOADED")
SafeRegisterEvent(ev, "PLAYER_LOGIN")
SafeRegisterEvent(ev, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(ev, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(ev, "PLAYER_ALIVE")
SafeRegisterEvent(ev, "PLAYER_UNGHOST")
SafeRegisterEvent(ev, "PLAYER_DEAD")
SafeRegisterEvent(ev, "SPELLS_CHANGED")
SafeRegisterEvent(ev, "PLAYER_LEVEL_UP")
SafeRegisterEvent(ev, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(ev, "ZONE_CHANGED_NEW_AREA")
SafeRegisterEvent(ev, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(ev, "MINIMAP_UPDATE_TRACKING")
SafeRegisterEvent(ev, "SKILL_LINES_CHANGED")   -- Verfolgungsliste (z. B. neuer Beruf)
SafeRegisterEvent(ev, "PLAYER_REGEN_DISABLED")
SafeRegisterEvent(ev, "GET_ITEM_INFO_RECEIVED")
SafeRegisterEvent(ev, "ITEM_DATA_LOAD_RESULT")   -- Item-Daten für die Essens-Erkennung
SafeRegisterEvent(ev, "ENABLE_XP_GAIN")
SafeRegisterEvent(ev, "DISABLE_XP_GAIN")
SafeRegisterEvent(ev, "UPDATE_BINDINGS")   -- Tasten-Hinweis in den Einstellungen
SafeRegisterEvent(ev, "SCREENSHOT_SUCCEEDED")   -- Demo-Screenshot-Lauf
SafeRegisterEvent(ev, "SCREENSHOT_FAILED")
-- Ladebildschirm-Events gibt es nicht in jedem Client (IsEventValid filtert sie dann aus)
SafeRegisterEvent(ev, "LOADING_SCREEN_ENABLED")
SafeRegisterEvent(ev, "LOADING_SCREEN_DISABLED")

-- Nach Login/Ladebildschirm liefert die Aura-API kurz unvollständige Daten → 3 Sek. warten.
-- Generationszähler: nur der zuletzt gestartete Timer darf ready = true setzen.
local GRACE_TIME = 3
local graceGen = 0

local function StartGrace()
    State.ready = false
    wipe(missingSince)
    State.warnCount = nil   -- Kurzstatus nach der Wartezeit neu melden
    graceGen = graceGen + 1
    local gen = graceGen
    C_Timer.After(GRACE_TIME, function()
        if gen ~= graceGen then return end
        State.ready = true; Items.ScanBags(); RefreshKnown(); Evaluate()
    end)
end

ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        Demo.OnScreenshot(event == "SCREENSHOT_SUCCEEDED")
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffReminderDB = BuffReminderDB or {}
        BuffReminderCharDB = BuffReminderCharDB or {}
        ns.SetDB(BuffReminderDB, BuffReminderCharDB)   -- setzt db/cdb in allen Dateien
        ApplyDefaults(db, DEFAULTS)
        cdb.buffs = cdb.buffs or {}
        cdb.lastVariant = cdb.lastVariant or {}   -- Eintrag-Key -> zuletzt genutzte Variante
        cdb.reagents = cdb.reagents or {}         -- Reagenz-Item-ID -> Warnschwelle (0 = aus)
        cdb.favorites = cdb.favorites or {}       -- Item-ID -> true: Favorit (Essen/Fläschchen)
        cdb.petFavorites = cdb.petFavorites or {} -- Item-ID -> true: Tierfutter-Favorit (getrennt)
        cdb.supplies = cdb.supplies or {}         -- eigene Vorrats-Items: Item-ID -> Mindestmenge
        cdb.supplySnooze = cdb.supplySnooze or {}     -- Vorrat-Key -> true: bis zur nächsten Stadt zurückgestellt
        cdb.supplyCritical = cdb.supplyCritical or {} -- Vorrat-Key -> kritische Grenze
        cdb.supplyRefill = cdb.supplyRefill or {}     -- Vorrat-Key -> Zielmenge "Auffüllen auf"
        cdb.rankAccept = cdb.rankAccept or {}         -- Spell-ID -> true: genau dieser Rang akzeptiert
        cdb.rankAcceptAll = cdb.rankAcceptAll or {}   -- Zaubername -> Spell-ID: alle Ränge akzeptiert
        Tracking.Migrate()                        -- frühere Einzelwahl -> cdb.trackSet
        if not Style.STYLES[db.style] then db.style = DEFAULTS.style end
        -- cdb.lastFlask: Item-ID des zuletzt benutzten Fläschchens (nil = keins)
        db.iconCache = db.iconCache or {}         -- allgemeiner Buff -> zuletzt gesehenes Aura-Icon
        db.flaskSpells = db.flaskSpells or {}     -- gelernte Spell-IDs von Fläschchen-Effekten
        db.elixirSpells = db.elixirSpells or {}   -- Elixier-Item-ID -> Spell-ID des Buffs (gelernt)
        cdb.elixirsSeen = cdb.elixirsSeen or {}   -- Elixier-Item-ID -> true: schon in den Taschen gewesen
        cdb.elixirsWanted = cdb.elixirsWanted or {}   -- Elixier-Item-ID -> true: gewünscht (Warnung)
        cdb.scrolls = cdb.scrolls or {}           -- Rollen-Art -> true/false (ausdrücklich), nil = Klassenvorgabe
        Scroll.MigrateOff()                       -- altes cdb.scrollsOff übernehmen und entfernen
        if not Cfg.ValidTab(db.cfgTab) then db.cfgTab = "display" end   -- gemerkter Tab ungültig
        -- versteckter Sprach-Schalter (nicht in Hilfe/README/Einstellungen; /br reset lässt ihn stehen):
        -- /run BuffReminderDB.locale = "frFR" + /reload; nil = Client-Sprache
        ns.Locales.Activate(db.locale)
        Keybind.SetNames(); Menu.SetTexts()       -- beim Laden gesetzte Texte in der aktiven Sprache
        RegisterPardona()                         -- erst jetzt: SavedVariables sind geladen
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
        PrintVersionNotice()   -- einmal pro Login (nicht bei Ladebildschirmen)
        local _, class = UnitClass("player")
        State.classEntries = CLASS_BUFFS[class] or {}
        for _, e in ipairs(State.classEntries) do
            PrepareEntry(e); PrepareCast(e, class); entries[#entries + 1] = e
            local g = GROUP_BUFFS[class] and GROUP_BUFFS[class][e.key]
            if g then e.groupIds, e.manaOnly, e.groupByVariant, e.ownOnly = g.groupIds, g.manaOnly, g.groupByVariant, g.ownOnly end
        end
        Variant.PrepareLabels(State.classEntries)   -- Beschriftungen der Variantengruppen (Cache)
        Conjure.Preload(State.classEntries)   -- Namen der Verbrauchsgüter-Items vorladen
        Group.DetectPallyPower()        -- Segen in den Gruppenbuffs aus, solange Pally Power geladen ist
        -- Waffen-Items: nicht für Schamanen (eigene Waffenverzauberungen); Schurke: an den
        -- Gift-Eintrag desselben Slots koppeln
        for i = #GENERAL_BUFFS, 1, -1 do
            local e = GENERAL_BUFFS[i]
            if e.weaponItems then
                if class == "SHAMAN" then
                    table.remove(GENERAL_BUFFS, i)
                else
                    for _, c in ipairs(State.classEntries) do
                        if c.poisonItems and c.kind == e.kind then e.poisonEntry = c end
                    end
                end
            end
        end
        for _, e in ipairs(GENERAL_BUFFS) do PrepareEntry(e); entries[#entries + 1] = e end
        -- Verfolgungs-Erinnerung: eigener Eintrag ohne Zeile in der Buff-Liste der
        -- Einstellungen; gilt überall (nicht nur in Instanzen); Verfolgung wird in RefreshKnown bestimmt
        Tracking.entry = { key = "gen_tracking", general = true, kind = "tracking", everywhere = true, ids = {} }
        PrepareEntry(Tracking.entry)
        entries[#entries + 1] = Tracking.entry
        -- Essen & Fläschchen: Kategorie-Gewichte der Klasse, gelernte Fläschchen-Spells, Taschen
        for _, e in ipairs(GENERAL_BUFFS) do
            if e.itemKind == "flask" then State.flaskEntry = e end
            if e.itemKind == "food" then State.foodEntry = e end
        end
        for id in pairs(db.flaskSpells) do State.flaskEntry.idSet[id] = true end
        Items.BuildFoodScores(class)
        Items.UpdateXP()            -- zählt Erfahrung? (XP-Essen bevorzugen / Abzeichen)
        Eat.ResolveAllEatSpells()   -- Ess-Auren aller FOOD-Items (fehlende werden nachgeladen)
        Elixir.Setup()              -- Einträge der gemerkten Elixiere (neue folgen beim Taschen-Scan)
        Scroll.Setup(class)         -- sechs Rollen-Einträge (Agility … Protection)
        Pet.Setup(class)            -- Tier-Erinnerung (Jäger, Hexenmeister)
        Items.ScanBags()
        -- Reagenzien der Klasse (Reihenfolge wie in REAGENT_SPELLS, ohne Doppelte)
        State.reagentLines = REAGENT_SPELLS[class] or {}
        local seen = {}
        for _, ranks in ipairs(State.reagentLines) do
            for _, rank in ipairs(ranks) do
                local item = rank[3]
                if item and not seen[item] then
                    seen[item] = true
                    local e = { key = "reagent_" .. item, kind = "reagent", item = item }
                    reagentEntries[#reagentEntries + 1] = e
                    entries[#entries + 1] = e
                    ItemName(item)   -- Item-Daten vorladen
                end
            end
        end
        Supply.Setup(class)   -- Vorräte: Munition, Seelensplitter, Tierfutter, eigene Items
        RefreshKnown()
        Style.SyncFromLib()   -- Stil "Pardona" aus LP.Style (jetzt ist die höchste Lib-MINOR aktiv)
        ApplyLayout()
        Display.ApplyStyle()
        RegisterPardonaSettings()
        -- UNIT_AURA für alle Units; gefiltert auf player / party* / raid* (siehe unten)
        SafeRegisterEvent(self, "UNIT_AURA")
        SafeRegisterEvent(self, "GROUP_ROSTER_UPDATE")
        SafeRegisterEvent(self, "UNIT_INVENTORY_CHANGED", "player")
        SafeRegisterEvent(self, "UNIT_SPELLCAST_SUCCEEDED", "player")
        SafeRegisterEvent(self, "UNIT_SPELLCAST_SENT")
        SafeRegisterEvent(self, "UI_ERROR_MESSAGE")
        Pet.RegisterEvents(self, SafeRegisterEvent)   -- Tier: UNIT_PET, Laune (nur Jäger)
        Supply.RegisterEvents(self, SafeRegisterEvent)   -- Vorräte: Ruhebereich, Händler, Bank
        Restock.RegisterEvents(self, SafeRegisterEvent)  -- Auffüllen: Händlerliste, Gold
        C_Timer.NewTicker(1, Evaluate)
        return
    end

    if event == "ITEM_DATA_LOAD_RESULT" then
        -- arg1 = Item-ID: Daten eines noch unbekannten Essens geladen -> Auswahl neu bewerten
        if IsSecret(arg1) or Items.foodPending[arg1] ~= true then return end
        Items.foodPending[arg1] = false
        Menu.RefreshItemPanel()
        Evaluate()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- arg1 = Item-ID; nur eigene Reagenzien interessieren (lokalisierter Name nachgeladen)
        -- bzw. Essen/Fläschchen in den Taschen (Name, Stufe, Tooltip jetzt verfügbar)
        if IsSecret(arg1) then return end
        if Demo.active then Demo.OnItemInfo(arg1) end   -- Demo: Vorladen fertig? Motive ergänzen
        Pet.OnItemInfo(arg1)   -- Tierfutter: angeforderte Item-Daten da
        if Eat.eatPending[arg1] then Eat.ResolveEatSpell(arg1, true) end   -- Ess-Aura jetzt ermittelbar
        if Items.foodPending[arg1] then Items.foodPending[arg1] = false end   -- DetectFood prüft neu
        if Items.bagCounts[arg1] then
            Items.LearnItem(arg1)
            Menu.RefreshItemPanel()
            Evaluate()
            return
        end
        if Supply.OnItemInfo(arg1) then return end   -- eigene Vorrats-Items, Seelensplitter
        for _, e in ipairs(reagentEntries) do
            if e.item == arg1 then
                Evaluate()
                if not State.ready then RefreshConfig() end   -- Evaluate tut vor ready nichts
                return
            end
        end
        return
    end

    if Supply.EVENTS[event] then
        Supply.OnEvent(event, arg1)
        Restock.OnEvent(event, arg1)   -- vor Evaluate: Hinweis der Vorratszeilen ("Linksklick: auffüllen")
        Evaluate()
        return
    end

    if Restock.EVENTS[event] then
        Restock.OnEvent(event, arg1)   -- Händlerliste, Gold
        return
    end

    if event == "UNIT_PET" or event == "UNIT_HAPPINESS" or event == "UNIT_POWER_UPDATE" then
        Pet.OnEvent(event, arg1, arg2)
        return
    end

    if event == "UPDATE_BINDINGS" then
        if RefreshConfig then RefreshConfig() end   -- nur bei sichtbaren Einstellungen
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        Items.ScanBags()
        Menu.RefreshItemPanel()   -- im Kampf nicht offen; Zeilen-Attribute folgen per Evaluate nach dem Kampf
        Evaluate()
        Restock.OnEvent(event)    -- Fenster "Auffüllen": Bestände neu
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        Menu.CloseItemPanelForCombat()
        Restock.OnEvent(event)   -- Fenster "Auffüllen": Knopf grau, Hinweis
        Demo.Abort()   -- Demo/Screenshot-Lauf sofort beenden (Zurücksetzen ggf. nach dem Kampf)
        RefreshPardonaStatus()   -- im Kampf kein Kurzstatus
        return
    end

    if event == "UNIT_AURA" then
        -- arg1 = Unit. Spieler: sofort auswerten (wie bisher); Gruppen-/Raid-Mitglieder:
        -- gedrosselt (MarkGroupDirty); alle anderen Units (Ziel, Namensplaketten …) ignorieren.
        -- Gruppen-Buffs aus (Experimental-Schalter oder groupCheck): Gruppen-Units ignorieren.
        if arg1 == nil or IsSecret(arg1) then return end
        if arg1 == "player" then
            if GroupFeatureOn() then Group.MarkGroupDirty() end
            Evaluate()
        elseif GroupFeatureOn() and (arg1:find("^party%d") or arg1:find("^raid%d")) then
            Group.MarkGroupDirty()
        elseif arg1 == "pet" and Pet.HasClass() then
            Evaluate()   -- Tier: Fress-Effekt, Tod
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup or not IsInGroup() then wipe(Group.bounced) end
        if not GroupFeatureOn() then return end
        Group.MarkGroupDirty()
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        -- arg1 = unit, arg2 = target, arg3 = castGUID, arg4 = spellID
        if arg1 ~= "player" or type(arg2) ~= "string" or IsSecret(arg2) or arg4 == nil or IsSecret(arg4) then return end
        local sname = SpellName(arg4)
        for _, e in ipairs(entries) do
            if e.ownOnly and e.variants then
                for _, v in ipairs(e.variants) do
                    if v.matchSet[arg4] or (sname and v.nameSet[sname]) then
                        Group.lastAttempt = {
                            name = arg2,
                            key = e.key, variant = v.key, t = GetTime(),
                        }
                        return
                    end
                end
            end
        end
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        -- arg1 = errorType, arg2 = message ("A more powerful spell is already active" -> Variante merken)
        local att = Group.lastAttempt
        if not att or (GetTime() - att.t) > 2 or type(arg2) ~= "string" or IsSecret(arg2) then return end
        local bouncedMsg = _G["SPELL_FAILED_AURA_BOUNCED"] or _G["ERR_AURA_BOUNCED"]
        if (bouncedMsg and arg2 == bouncedMsg) or arg2:lower():find("more powerful spell", 1, true) then
            Group.RecordBounce(att)
            Group.lastAttempt = nil
            Group.MarkGroupDirty()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- nach dem Kampf: Gruppe sofort neu prüfen, Zeilen/Attribute nachziehen
        if Demo.restorePending then Demo.Restore() end
        if GroupFeatureOn() then Group.groupDirty = true end
        Ranks.OnCombatEnd()   -- niedrige Zauberränge aus dem Kampf (und davor) jetzt anzeigen
        Evaluate()
        Keybind.Update()   -- Taste neu belegen (Einmal-Sperre aus dem Kampf aufheben)
        Restock.OnEvent(event)   -- Fenster "Auffüllen": Knopf wieder frei
        RefreshPardonaStatus()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID (kann ein Secret-Wert sein)
        -- Ziel der Gruppen-Zeilen nach jedem Cast neu bestimmen
        if GroupFeatureOn() then Group.MarkGroupDirty() end
        if cdb then
            RememberFromCast(arg3)
            Pet.RememberCast(arg3)   -- Hexenmeister: zuletzt beschworener Dämon
            Ranks.OnCast(arg3)       -- niedriger Zauberrang? (angezeigt nach dem Kampf)
            -- Fläschchen-Effekt (auch über Aktionsleiste/Taschen benutzt) -> zuletzt benutzt
            if arg3 ~= nil and not IsSecret(arg3) and Items.flaskBySpell[arg3] then
                cdb.lastFlask = Items.flaskBySpell[arg3]
            end
        end
        Evaluate()
        return
    end

    if event == "LOADING_SCREEN_ENABLED" then
        State.ready = false
        graceGen = graceGen + 1   -- laufende Grace-Timer verfallen
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
        StartGrace()
        return
    end

    if event == "ENABLE_XP_GAIN" or event == "DISABLE_XP_GAIN" or event == "PLAYER_LEVEL_UP" then
        -- XP-Bonus neu bewerten (arg1 = neue Stufe bei PLAYER_LEVEL_UP); offenes Item-Menü
        -- und Warnzeilen (beste Wahl) folgen
        Items.UpdateXP(event == "PLAYER_LEVEL_UP" and arg1 or nil)
        if event == "PLAYER_LEVEL_UP" then Scroll.OnLevelUp(arg1) end   -- Rollen: benutzbare Ränge
        Menu.RefreshItemPanel()
        if event ~= "PLAYER_LEVEL_UP" then Evaluate(); return end
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
        -- Neu erlernte Zauber werden automatisch aktiv (Standard = an)
        C_Timer.After(0.5, function() RefreshKnown(); Evaluate(); RefreshConfig() end)
        return
    end

    if event == "MINIMAP_UPDATE_TRACKING" or event == "SKILL_LINES_CHANGED" then
        Tracking.CheckExclusive()   -- kurz nach einem Klick: hat Einschalten eine andere ausgeschaltet?
        RefreshKnown()
        Evaluate()
        RefreshConfig()   -- Verfolgungsliste in den Einstellungen (nur bei sichtbaren Einstellungen)
        return
    end

    Evaluate()
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_BUFFREMINDER1 = "/br"
SLASH_BUFFREMINDER2 = "/buffreminder"
SlashCmdList.BUFFREMINDER = function(msg)
    if not db then return end
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "config" or cmd == "options" then
        ToggleConfig()
    elseif cmd == "test" then
        StartTest()
    elseif cmd == "move" then
        Cfg.SetMoveMode(true)
    elseif cmd == "lock" then
        Cfg.SetMoveMode(false)
    elseif cmd == "minimap" then
        TogglePardonaMinimap()
    elseif cmd == "unmute" then
        wipe(muted); Print(L.UNMUTED); NoteDeferred(); Evaluate()
    elseif cmd == "debug" then
        local log = {}
        local function dprint(line) Print(line); log[#log + 1] = line end
        local ids, _, unreliable = ScanAuras()
        dprint(("ready=%s enabled=%s suppressed=%s instanceOnly=%s inInstance=%s scan=%s unreliable=%s"):format(
            tostring(State.ready), tostring(db.enabled), tostring(Suppressed()), tostring(db.instanceOnly),
            tostring(InGroupInstance()), ids and "ok" or "nil", tostring(unreliable)))
        for _, e in ipairs(entries) do
            dprint(("%s: known=%s enabled=%s missing=%s muted=%s groupActive=%s names=%s"):format(
                EntryLabel(e), tostring(knownCache[e.key]), tostring(IsEnabled(e)),
                tostring(missing[e.key]), tostring(MuteRemaining(e.key) ~= nil),
                tostring(e.groupActive), table.concat(e.names or {}, "/")))
        end
        Group.PrintDebug(log)
        dprint(("eating=%s aura=%s eatSpells=%d eatNames=%d"):format(
            (State.foodEntry and State.foodEntry.eatStart) and "yes" or "no",
            Eat.eatAura and ("%s – %s"):format(tostring(Eat.eatAura.name), tostring(Eat.eatAura.id)) or "none",
            CountKeys(Eat.eatSpells), CountKeys(Eat.eatNames)))
        local numFn = Tracking.NumTypesFn()
        local okN, numTrack = false, nil
        if numFn then okN, numTrack = pcall(numFn) end
        dprint(("trackingTypes=%s"):format(okN and tostring(numTrack) or "err"))
        dprint(Style.DebugLine())
        dprint(Ranks.DebugLine())
        dprint(("locale: %s (client %s, override %s)"):format(ns.Locales.active, ns.Locales.Client(),
            tostring(db.locale)))
        for _, line in ipairs(Cfg.LibDiagLines()) do dprint(line) end
        db.lastDebug = log
    elseif cmd == "auras" then
        Print(L.AURAS_HEAD)
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 255 do
                local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                if not ok or a == nil then break end
                if IsSecret(a) or IsSecret(a.name) or IsSecret(a.spellId) then
                    Print("  ? (secret)")
                else
                    Print(("  %s – %s"):format(tostring(a.name), tostring(a.spellId)))
                end
            end
        elseif UnitBuff then
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, id = UnitBuff("player", i)
                if not name then break end
                Print(("  %s – %s"):format(name, tostring(id)))
            end
        end
    elseif cmd == "demo" and db.demo == true then
        Demo.Command((msg or ""):lower():match("^%s*%S+%s+(%S+)%s*(%S*)"))
    elseif cmd == "reset" then
        if InCombatLockdown() then Print(L.COMBAT); return end
        for k in pairs(DEFAULTS) do db[k] = nil end
        -- Schalter: wieder Vorgabe (freigegebene an, experimentelle Build-abhängig)
        db.expGroup, db.expReagents, db.expExpiry, db.expConsumables, db.expWeaponItems = nil, nil, nil, nil, nil
        db.expVariantMenu, db.expBlessings, db.expTracking = nil, nil, nil
        db.expElixirs, db.expScrolls, db.expPet, db.expRestock, db.expRanks = nil, nil, nil, nil, nil
        cdb.trackSet = nil                        -- Verfolgungen wieder Vorgabe
        cdb.petUnhappyOnly, cdb.petNoFoodWarn, cdb.demon = nil, nil, nil   -- Tier: Vorgaben
        cdb.ammoMin, cdb.shardMin, cdb.petFoodMin = nil, nil, nil   -- Vorräte: Standard-Mindestmengen
        wipe(cdb.supplyCritical)                  -- Vorräte: kritische Grenzen wieder Standard
        wipe(cdb.supplyRefill)                    -- Vorräte: Zielmengen "Auffüllen auf" wieder Standard
        RefreshKnown()
        ApplyDefaults(db, DEFAULTS)
        wipe(cdb.buffs)
        wipe(cdb.reagents)
        wipe(cdb.scrolls)                         -- Rollen-Arten wieder nach Klassenvorgabe
        ApplyLayout(); Display.ApplyStyle(); Print(L.RESET); Evaluate()
    else
        for _, k in ipairs({ "HELP_OPEN", "HELP_TEST", "HELP_MOVE", "HELP_LOCK", "HELP_MINIMAP", "HELP_UNMUTE", "HELP_AURAS", "HELP_RESET" }) do
            Print(L[k])
        end
    end
end
