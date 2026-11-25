-- Pardona's Buff Reminder – Versteckter Demo-Modus mit Screenshot-Lauf (nur mit BuffReminderDB.demo).
-- Abhängigkeiten (beim Laden): Core.lua, Data.lua, Items.lua, Display.lua, Menu.lua, Evaluate.lua, Config.lua

local ADDON_NAME, ns = ...

local L = ns.L
-- aus Core.lua
local State = ns.State
local Items = ns.Items
local Display = ns.Display
local Menu = ns.Menu
local Cfg = ns.Cfg
local Conjure = ns.Conjure
local Variant = ns.Variant
local Tracking = ns.Tracking
local Demo = ns.Demo
local Pet = ns.Pet
local Supply = ns.Supply
local Ranks = ns.Ranks
local Restock = ns.Restock
local Print = ns.Print
local IsSecret = ns.IsSecret
local SpellName = ns.SpellName
local SpellIcon = ns.SpellIcon
-- aus Data.lua
local CLASS_BUFFS = ns.CLASS_BUFFS
local CAST_DATA = ns.CAST_DATA
local FALLBACK_ICON = ns.FALLBACK_ICON
-- aus Items.lua
local ItemName = ns.ItemName
local ItemIcon = ns.ItemIcon
-- aus Display.lua
local anchor = ns.anchor
local ApplyLayout = ns.ApplyLayout
local rows = ns.rows
-- aus Menu.lua
local menu = ns.menu
local itemPanel = ns.itemPanel
-- aus Evaluate.lua
local Evaluate = ns.Evaluate
-- aus Config.lua
local ToggleConfig = ns.ToggleConfig
local RefreshConfig = ns.RefreshConfig
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db, cdb
ns.OnDB(function(newDb, newCdb) db, cdb = newDb, newCdb end)

---------------------------------------------------------------------------
-- Demo-Modus (versteckt): nur mit BuffReminderDB.demo == true gibt es /br demo, /br demo shot und
-- /br demo play. Beispielzeilen für Bilder und Videos (CurseForge/Wago/Webseite), unabhängig von
-- Klasse, Stufe und Taschen. Sie laufen über den normalen Anzeigeweg (ShowRows -> Demo.FillRow),
-- aber ohne secure Aktion; Evaluate überschreibt die Anzeige nicht, solange Demo.active gilt.
-- Kein Eintrag in Hilfe, README, Einstellungen oder CHANGELOG; /br reset lässt db.demo stehen.
--   Demo.ROWS   : Motive; spell/item liefern Name und Icon (immer aus dem Client),
--                 label = L-Schlüssel wie beim echten Eintrag (z. B. ARMOR); Spell-/Item-IDs aus
--                 den Tabellen des Addons (CLASS_BUFFS, CAST_DATA, Conjure, Items, Tracking, Pet)
--   Demo.FOOD / WEAPON / PETFOOD : Beispiel-Items der Item-Menüs
--   Demo.SCENES : Szenen des Screenshot-Laufs mit festen IDs (Demo.BuildShots)
--   Demo.PLAYS  : zeitgesteuerte Abläufe für Videoaufnahmen (/br demo play <ID>)
---------------------------------------------------------------------------
Demo.GROUP_LIST = { "Thrall", "Jaina", "Uther" }            -- Beispielnamen der Gruppen-Zeile
Demo.GROUP_NAMES = table.concat(Demo.GROUP_LIST, ", ")
Demo.POISON_ICON = CLASS_BUFFS.ROGUE[1].icon                -- Gift-Icon wie beim echten Eintrag
Demo.ROWS = {
    { key = "class",    spell = 1459, hint = "HINT_CAST" },                                    -- Arkane Intelligenz
    { key = "armor",    spell = 7302, label = "ARMOR", variantOf = "MAGE", hint = "HINT_CAST_CHOOSE", menu = "variant",
      last = "ice" },
    { key = "food",     spell = 19705, hintItem = 13931, menu = "food" },                      -- Well Fed
    { key = "flask",    item = 13510, label = "FLASK", hintItem = 13510 },                      -- Fläschchen der Titanen
    { key = "weapon",   item = Items.WEAPON_ITEMS.wizard[4], label = "WEAPON_MH", plain = true, -- Brillantes Zauberöl
      hintItem = Items.WEAPON_ITEMS.wizard[4], menu = "weapon" },
    { key = "weaponstone", item = Items.WEAPON_ITEMS.sharpen[5], label = "WEAPON_MH", plain = true,   -- Verdichteter Wetzstein
      hintItem = Items.WEAPON_ITEMS.sharpen[5] },
    { key = "group",    spell = 1243, group = 3, hint = "HINT_GROUP" },                         -- Machtwort: Seelenstärke
    { key = "groupmotw", spell = 1126, group = 3, hint = "HINT_GROUP" },                        -- Mal der Wildnis
    { key = "fort",     spell = 1243, hint = "HINT_CAST" },                                     -- Seelenstärke (einzeln)
    { key = "innerfire", spell = 588, hint = "HINT_CAST" },                                     -- Inneres Feuer
    { key = "reagent",  item = 17028, count = 3, hint = "HINT_SNOOZE" },                          -- Heilige Kerze
    { key = "tracking", spell = Tracking.TYPES.herbs.spell, track = true,                       -- Kräuter- + Schatzsuche
      track2 = Tracking.TYPES.treasure.spell, hint = "HINT_TRACK" },
    { key = "expiry",   spell = 1126, expiry = "1:45", hint = "HINT_CAST" },                    -- Mal der Wildnis
    { key = "poisonmh", label = "MH_POISON", icon = Demo.POISON_ICON, charges = 12,             -- Ablaufzeile mit Ladungen
      hintItem = Items.POISON_ITEMS.instant[6] },
    { key = "poisonoh", label = "OH_POISON", icon = Demo.POISON_ICON, hintItem = Items.POISON_ITEMS.instant[6] },
    { key = "eating",   item = 13931, eating = 12 },                                            -- Essen läuft (Countdown)
    { key = "elixir",   item = 13452, hint = "HINT_USE" },                                      -- Elixier des Mungos
    { key = "scroll",   item = 955, hintItem = 955 },                                           -- Rolle der Intelligenz (Rang I)
    { key = "water",    item = Conjure.WATER.rankItems[7], conjure = true, count = 6, hint = "HINT_CAST" },   -- Herbeigezaubertes Kristallwasser
    { key = "managem",  item = Conjure.GEM.rankItems[4], hint = "HINT_CAST" },                  -- Manarubin
    { key = "aura",     spell = 465, label = "AURA", variantOf = "PALADIN", hint = "HINT_CAST_CHOOSE", menu = "variant",
      last = "devotion" },
    { key = "seal",     spell = 21084, label = "SEAL", variantOf = "PALADIN", hint = "HINT_CAST_CHOOSE" },
    { key = "blessing", spell = 19740, label = "BLESSING", variantOf = "PALADIN", hint = "HINT_CAST_CHOOSE" },
    { key = "shield",   spell = 324, label = "SHIELD", variantOf = "SHAMAN", hint = "HINT_CAST_CHOOSE" },
    { key = "imbue",    spell = 8024, label = "MH_ENCHANT", variantOf = "SHAMAN", cast = "imbue_mh", hint = "HINT_CAST_CHOOSE" },
    { key = "aspect",   spell = 13165, label = "ASPECT", variantOf = "HUNTER", hint = "HINT_CAST_CHOOSE", menu = "variant",
      last = "hawk" },
    { key = "wlarmor",  spell = 706, label = "ARMOR", variantOf = "WARLOCK", cast = "armor", hint = "HINT_CAST_CHOOSE" },
    { key = "petmissing", spell = Pet.CALL, label = "PET_MISSING", plain = true, pet = true, hint = "HINT_CAST_CHOOSE" },
    { key = "petfeed",  spell = Pet.FEED, label = "PET_FEED", plain = true, pet = true, hintItem = 4599,   -- Gepökeltes Schinkensteak
      menu = "petfood" },
    { key = "demon",    spell = 697, label = "PET_DEMON", plain = true, pet = true, hint = "HINT_CAST_CHOOSE",  -- Leerwandler
      menu = "demon" },
    { key = "ammo",     item = 2515, count = 57, hint = "HINT_SNOOZE", menu = "restock" },     -- Scharfer Pfeil
    { key = "supply",   item = 1645, count = 4, hint = "HINT_SNOOZE" },                          -- Mondbeerensaft (eigenes Item knapp)
    -- Kristallphiole (8925): eigenes Item knapp; keine Tabelle im Addon (Handwerkswaren)
    { key = "supplytrade", item = 8925, count = 4, hint = "HINT_RESTOCK_CLICK", menu = "restock" },
    -- niedriger Zauberrang: Geringes Heilen Rang 1 gewirkt, Rang 3 erlernt (Ranks.TEST)
    { key = "lowrank",  spell = Ranks.TEST.best, rank = Ranks.TEST, hint = "HINT_RANK" },
}
-- Motive von /br demo (ohne Lauf)
Demo.DEFAULT_ROWS = { "class", "armor", "food", "flask", "weapon", "group", "reagent", "tracking", "expiry",
    "elixir", "scroll", "petmissing", "petfeed", "demon", "ammo", "supply" }
Demo.FOOD = {
    { id = 13931, count = 12, cat = "SpellDamage", xp = true, fav = true },
    { id = 18254, count = 4,  cat = "Intellect" },
    { id = 12216, count = 6,  cat = "Intellect" },
    { id = 3729,  count = 9,  cat = "Stamina" },
}
-- Steine & Öle (Items.WEAPON_ITEMS): erstes = beste Wahl, Manaöl als Favorit
Demo.WEAPON = {
    { id = Items.WEAPON_ITEMS.wizard[4],  count = 3, wcat = "wizard" },              -- Brillantes Zauberöl
    { id = Items.WEAPON_ITEMS.mana[3],    count = 2, wcat = "mana", fav = true },    -- Brillantes Manaöl
    { id = Items.WEAPON_ITEMS.sharpen[5], count = 8, wcat = "sharpen" },             -- Verdichteter Wetzstein
    { id = Items.WEAPON_ITEMS.weight[5],  count = 5, wcat = "weight" },              -- Verdichteter Gewichtsstein
}
-- Tierfutter: keine Tabelle im Addon (der echte Scan fragt C_PetInfo.CanPetEatItem) – Classic-IDs
Demo.PETFOOD = {
    { id = 4599, count = 14 },              -- Gepökeltes Schinkensteak
    { id = 8952, count = 9, fav = true },   -- Gerösteter Wachtel
    { id = 8953, count = 20 },              -- Frittierte Kochbananen
    { id = 4608, count = 5 },               -- Rohe Schwarze Trüffel
}
-- Eigene Items für das Bild der Vorräte-Einstellungen; keine Tabelle im Addon:
-- Kristallphiole, Seidenfaden, Schwerer Seidenverband
Demo.SUPPLY_ITEMS = { 8925, 4291, 6451 }
Demo.DEMON_COUNT = 4        -- Pet.DEMONS 1-4: Wichtel, Leerwandler, Sukkubus, Teufelsjäger
Demo.DEMON_LAST = 697       -- im Dämonen-Menü als "zuletzt genutzt" markiert
Demo.VARIANT_LAST = "ice"   -- Rückfall für "zuletzt genutzt" im Variantenmenü
Demo.LOAD_WAIT = 5          -- höchstens so lange auf Item-/Spell-Daten warten (Sek.; GET_ITEM_INFO_RECEIVED prüft sofort)
Demo.SHOT_DELAY = 1.5       -- Wartezeit vor jedem Bild (Sek.)
Demo.PLAY_LEAD, Demo.PLAY_TAIL = 3, 2   -- Abläufe: leere Anzeige am Anfang/Ende (Sek.)
Demo.DROPDOWNS = { sound = "soundDD", demon = "demonDD", groupmode = "groupModeDD" }   -- Felder von config

-- Szenen des Screenshot-Laufs. Felder: id, name (Dateiname-Teil), rows (Demo.ROWS-Keys in
-- Reihenfolge), style ("pardona" Standard), icons (Nur Icons), menu ("food" | "variant" | "weapon" |
-- "petfood" | "demon" | "restock"), restock ("vendor" | "trade" | "nogold"), settings (Tab-Key),
-- scroll ("top" | "bottom"), dropdown ("sound" | "demon" | "groupmode"), class (echte Klasse nötig)
Demo.MIXED = { "class", "food", "tracking", "group", "supply" }
Demo.SCENES = {
    { id = "S02", name = "mixed-list", rows = Demo.MIXED },
    { id = "S03", name = "expiry-warning", rows = { "class", "food", "expiry", "poisonmh" } },
    { id = "S04", name = "compact-icons", rows = Demo.MIXED, style = "compact", icons = true },
    { id = "S05", name = "stones-oils-menu", rows = { "weapon" }, menu = "weapon" },
    { id = "S06", name = "elixir-scroll", rows = { "elixir", "scroll" } },
    { id = "S08", name = "restock-trade", rows = { "supplytrade" }, menu = "restock", restock = "trade" },
    { id = "S09", name = "restock-no-gold", rows = { "supplytrade" }, menu = "restock", restock = "nogold" },
    { id = "S10", name = "group-line", rows = { "group" } },
    { id = "S11", name = "tracking-off", rows = { "tracking" } },
    { id = "S12", name = "food-menu", rows = { "class", "food", "flask" }, menu = "food" },
    { id = "S13", name = "eating", rows = { "eating" } },
    { id = "S14", name = "low-rank", rows = { "lowrank" } },
    { id = "C01", name = "druid-group", rows = { "groupmotw" } },
    { id = "C02", name = "hunter-pet-ammo", rows = { "petfeed", "ammo" } },
    { id = "C03", name = "mage-consumables", rows = { "water", "managem", "class" } },
    { id = "C04", name = "paladin-aura-menu", rows = { "aura" }, menu = "variant" },
    { id = "C05", name = "priest-group-candles", rows = { "group", "reagent" } },
    { id = "C06", name = "rogue-poison-charges", rows = { "poisonoh", "poisonmh" } },
    { id = "C07", name = "shaman-shield-imbue", rows = { "shield", "imbue" } },
    { id = "C08", name = "warlock-demon-menu", rows = { "demon" }, menu = "demon" },
    { id = "C09", name = "warrior-food-flask-stone", rows = { "food", "flask", "weaponstone" } },
    { id = "E01", name = "settings-display", settings = "display", scroll = "top" },
    { id = "E02", name = "settings-class-buffs", settings = "class", scroll = "top" },
    { id = "E03", name = "settings-other-top", settings = "other", scroll = "top" },
    { id = "E04", name = "settings-other-bottom", settings = "other", scroll = "bottom" },
    { id = "E05", name = "settings-supplies", settings = "supplies", scroll = "top" },
    { id = "E06", name = "settings-group", settings = "group", scroll = "top" },
    { id = "E07", name = "settings-pet-hunter", settings = "pet", scroll = "top", class = "HUNTER" },
    { id = "E08", name = "settings-pet-warlock", settings = "pet", scroll = "top", class = "WARLOCK" },
    { id = "E09", name = "dropdown-sound", settings = "display", dropdown = "sound" },
    { id = "E10", name = "dropdown-demon", settings = "pet", dropdown = "demon", class = "WARLOCK" },
    { id = "E11", name = "dropdown-check-in", settings = "group", dropdown = "groupmode" },
    { id = "E12", name = "settings-ranks", settings = "ranks", scroll = "top" },
}

-- Szenen eines Laufs: nil = alle, "settings" = nur E-Szenen, sonst genau die Szene mit dieser ID
function Demo.BuildShots(filter)
    local list = {}
    for _, s in ipairs(Demo.SCENES) do
        if filter == nil or (filter:upper() == "SETTINGS" and s.settings ~= nil) or s.id == filter:upper() then
            list[#list + 1] = s
        end
    end
    return list
end
Demo.SHOTS = Demo.BuildShots()

-- Abläufe für Videos: Liste von Schritten { t = Sek. nach dem vorigen Schritt, rows = Motive (neu
-- zeigen; {} = leer, schließt das Menü), over = Key -> Felder, die das Motiv ersetzen (ohne rows: die
-- zuletzt gezeigten Motive neu), menu = Menü an der Motiv-Zeile öffnen }. Davor PLAY_LEAD, danach
-- PLAY_TAIL Sek. leere Anzeige.
Demo.PLAY_ORDER = { "D05", "D06", "D10", "D12" }
Demo.PLAYS = {}

-- D05 Klassen-Montage: 5 Abschnitte je 4 s, dazwischen 0,5 s leer
function Demo.PLAYS.D05()
    local steps = {}
    for i, sec in ipairs({ { { "aura", "seal", "blessing" }, true }, { { "armor" }, true },
        { { "shield", "imbue" } }, { { "aspect" }, true }, { { "wlarmor" } } }) do
        steps[#steps + 1] = { t = i == 1 and 0 or 0.5, rows = sec[1] }
        if sec[2] then
            steps[#steps + 1] = { t = 1.5, menu = "variant" }
            steps[#steps + 1] = { t = 2.5, rows = {} }
        else
            steps[#steps + 1] = { t = 4, rows = {} }
        end
    end
    return steps
end

-- D06 Ablaufwarnung: Inneres Feuer zählt herunter und wird zur fehlenden Zeile; dann Gift-Ladungen
function Demo.PLAYS.D06()
    local keys = { "fort", "food", "innerfire" }
    local steps = { { t = 0, rows = keys, over = { innerfire = { expiry = "0:08" } } } }
    for s = 7, 1, -1 do
        steps[#steps + 1] = { t = 1, over = { innerfire = { expiry = ("0:%02d"):format(s) } } }
    end
    steps[#steps + 1] = { t = 1, rows = keys }   -- 0:00: ohne Lücke "Inneres Feuer fehlt"
    steps[#steps + 1] = { t = 2, rows = {} }
    steps[#steps + 1] = { t = 1, rows = { "poisonoh", "poisonmh" }, over = { poisonmh = { charges = 15 } } }
    for c = 14, 8, -1 do
        steps[#steps + 1] = { t = 0.8, over = { poisonmh = { charges = c } } }
    end
    steps[#steps + 1] = { t = 2, rows = {} }
    return steps
end

-- D10 Tier und Dämon: Zeile, dann Menü, dann leer
function Demo.PLAYS.D10()
    return {
        { t = 0, rows = { "petfeed" } }, { t = 2, menu = "petfood" }, { t = 4, rows = {} },
        { t = 2, rows = { "demon" } }, { t = 2, menu = "demon" }, { t = 4, rows = {} },
    }
end

-- D12 Gruppe: Anzahl und Namen nehmen ab, dann verschwindet die Zeile
function Demo.PLAYS.D12()
    local g = Demo.GROUP_LIST
    local function over(n)
        local names = {}
        for i = #g - n + 1, #g do names[#names + 1] = g[i] end
        return { group = { group = n, names = table.concat(names, ", ") } }
    end
    return {
        { t = 0, rows = { "group" }, over = over(3) }, { t = 3, over = over(2) }, { t = 1.5, over = over(1) },
        { t = 1.5, rows = {} },
    }
end

-- Motiv zu einem Key (nil = unbekannt)
function Demo.Row(key)
    if not Demo.rowIndex then
        Demo.rowIndex = {}
        for _, d in ipairs(Demo.ROWS) do Demo.rowIndex[d.key] = d end
    end
    return Demo.rowIndex[key]
end

-- Kopie eines Motivs mit ersetzten Feldern (Abläufe)
function Demo.Merge(d, o)
    local c = {}
    for k, v in pairs(d) do c[k] = v end
    for k, v in pairs(o) do c[k] = v end
    return c
end

-- Eintrag für ein Motiv (Name/Icon aus dem Client; Demo.Show lässt unbekannte Motive aus)
Demo.ITEM_MENUS = { food = "food", weapon = "weapon", petfood = "petfood" }
function Demo.Entry(d)
    local label = (d.variantOf and Variant.GroupLabel(d.variantOf, d.cast or d.key, d.label)) or (d.label and L[d.label])
        or (d.spell and SpellName(d.spell)) or (d.item and ItemName(d.item)) or "?"
    local icon = d.icon or (d.spell and SpellIcon(d.spell)) or (d.item and ItemIcon(d.item)) or FALLBACK_ICON
    if d.track2 then label = label .. ", " .. (SpellName(d.track2) or "?") end   -- Verfolgung: zwei Namen
    local demon = d.menu == "demon"
    -- Rang-Zeile: kind/rankInfo wie beim echten Eintrag (Rechtsklick-Menü mit Rang-Knöpfen ohne Wirkung)
    local rankInfo = d.rank and { name = label, id = d.rank.id, rank = d.rank.rank, best = d.rank.best,
        bestRank = d.rank.bestRank, count = 1 } or nil
    -- Dämonen-Menü: kind/petType wie beim echten Eintrag (Überschrift "Zu beschwörender Dämon")
    return { key = "demo_" .. d.key, demo = d, demoLabel = label, demoIcon = icon,
        itemKind = Demo.ITEM_MENUS[d.menu], demoVariants = d.menu == "variant" or demon,
        kind = (demon and "pet") or (rankInfo and "rank") or nil, petType = demon and "demon" or nil,
        rankInfo = rankInfo }
end

-- Zeile wie die echte Warnung gestalten (aus ShowRows; nur außerhalb des Kampfes)
function Demo.FillRow(r, e, st)
    local d, label = e.demo, e.demoLabel
    Display.SetRowAction(r, nil)
    Display.SetRowLines(r, d.group ~= nil)
    local status, text, right = "missing", L.MISSING:format(label), L.SHORT_MISSING
    local hint = d.hintItem and L.HINT_ITEM:format(ItemName(d.hintItem)) or L[d.hint]
    if d.group then
        text, right = L.GROUP_MISSING:format(label, d.group), ""
        r.names:SetText(d.names or Demo.GROUP_NAMES)
    elseif d.eating then
        status, text, right, hint = "eating", L.EATING:format(d.eating), "", L.HINT_EATING
    elseif d.conjure and d.count then
        status, text, right = "low", L.CONJURE_COUNT:format(label, d.count), tostring(d.count)
    elseif d.count then
        status, text, right = "low", L.REAGENT_LOW:format(label, d.count), ""
    elseif d.track then
        text, right = L.TRACK_OFF:format(label), L.SHORT_OFF
    elseif d.charges then
        status, text, right = "expiring", L.EXPIRES_CHARGES:format(label, d.charges), ""
    elseif d.expiry then
        status, text, right = "expiring", L.EXPIRES:format(label, d.expiry), ""
    elseif d.rank then
        text, right = L.RANK_LINE:format(label, d.rank.rank, d.rank.bestRank), L.RANK_N:format(d.rank.rank)
    elseif d.plain then
        text = label
        if d.pet then right = "" end   -- Tier-Zeilen: Text sagt schon alles ("Tier fehlt", "Tier füttern")
    end
    if st.rightText and right ~= "" then
        text = label
        r.right:SetText(right)
    end
    Display.SetRowStatus(r, status)
    r.text:SetText(text)
    Display.SetRowHint(r, hint)
end

-- Kennt der Client den Zauber bzw. das Item? (Name und Icon vorhanden; nach dem Vorladen)
function Demo.SpellKnown(id)
    return SpellName(id) ~= nil and SpellIcon(id) ~= nil
end

function Demo.ItemKnown(id)
    return Items.ItemLevels(id) ~= nil and ItemIcon(id) ~= nil
end

-- Motiv zeigbar? Alle Zauber/Items des Motivs müssen dem Client bekannt sein
function Demo.RowKnown(d)
    if d.spell and not Demo.SpellKnown(d.spell) then return false end
    if d.item and not Demo.ItemKnown(d.item) then return false end
    if d.hintItem and not Demo.ItemKnown(d.hintItem) then return false end
    return true
end

-- Item-Menüs (Essen, Steine & Öle, Tierfutter): Beispiel-Items, erstes = beste Wahl; unbekannte weglassen
function Demo.ItemChoices(which)
    local src = (which == "weapon" and Demo.WEAPON) or (which == "petfood" and Demo.PETFOOD) or Demo.FOOD
    local list = {}
    for _, c in ipairs(src) do
        if Demo.ItemKnown(c.id) then
            list[#list + 1] = { id = c.id, count = c.count, cat = c.cat, wcat = c.wcat, xp = c.xp == true,
                fav = c.fav == true }
        end
    end
    return list
end

-- Variantenmenü einer Klassengruppe aus CAST_DATA (z. B. "PALADIN", "aura"), unabhängig davon, ob
-- gelernt; nur Zauber, die der Client kennt (z. B. fehlt Molten Armor 30482, TBC, in Forever)
function Demo.VariantChoices(class, group, last)
    local list = {}
    local c = CAST_DATA[class] and CAST_DATA[class][group]
    for _, v in ipairs(c and c.variants or {}) do
        local id = v.castIds[1]
        if Demo.SpellKnown(id) then
            list[#list + 1] = { spell = id, vkey = v.key, name = SpellName(id), icon = SpellIcon(id),
                last = v.key == (last or Demo.VARIANT_LAST) }
        end
    end
    return list
end

-- Dämonen-Menü: Wichtel, Leerwandler, Sukkubus, Teufelsjäger (Pet.DEMONS)
function Demo.DemonChoices()
    local list = {}
    for i = 1, Demo.DEMON_COUNT do
        local id = Pet.DEMONS[i]
        if id and Demo.SpellKnown(id) then
            list[#list + 1] = { spell = id, vkey = tostring(id), name = SpellName(id), icon = SpellIcon(id),
                last = id == Demo.DEMON_LAST }
        end
    end
    return list
end

-- Varianten des Menüs zu einem Motiv (Menu.LayoutMenu)
function Demo.MenuVariants(d)
    if d.menu == "demon" then return Demo.DemonChoices() end
    return Demo.VariantChoices(d.variantOf or "MAGE", d.cast or d.key, d.last)
end

function Demo.Ids()
    local spells, items = {}, {}
    for _, d in ipairs(Demo.ROWS) do
        if d.spell then spells[#spells + 1] = d.spell end
        if d.track2 then spells[#spells + 1] = d.track2 end
        if d.item then items[#items + 1] = d.item end
        if d.hintItem then items[#items + 1] = d.hintItem end
        local c = d.variantOf and CAST_DATA[d.variantOf] and CAST_DATA[d.variantOf][d.cast or d.key]
        for _, v in ipairs(c and c.variants or {}) do spells[#spells + 1] = v.castIds[1] end
    end
    for _, src in ipairs({ Demo.FOOD, Demo.WEAPON, Demo.PETFOOD }) do
        for _, c in ipairs(src) do items[#items + 1] = c.id end
    end
    for _, src in ipairs({ Restock.DEMO, Restock.DEMO_TRADE }) do
        for _, r in ipairs(src) do items[#items + 1] = r[1] end
    end
    for _, id in ipairs(Demo.SUPPLY_ITEMS) do items[#items + 1] = id end
    for i = 1, Demo.DEMON_COUNT do spells[#spells + 1] = Pet.DEMONS[i] end
    return spells, items
end

function Demo.DataReady(spells, items)
    for _, id in ipairs(spells) do
        if not SpellName(id) or not SpellIcon(id) then return false end
    end
    for _, id in ipairs(items) do
        if not Items.ItemLevels(id) or not ItemIcon(id) then return false end
    end
    return true
end

-- Item-/Spell-Daten anfordern; done() sobald alles da ist, spätestens nach LOAD_WAIT Sek.
-- Geprüft wird alle 0,2 Sek. und bei jedem GET_ITEM_INFO_RECEIVED (Demo.OnItemInfo).
function Demo.Preload(done)
    local spells, items = Demo.Ids()
    for _, id in ipairs(items) do
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    for _, id in ipairs(spells) do
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
    end
    local t0 = GetTime()
    -- true = fertig (done ist gelaufen oder Demo beendet)
    local function check()
        if not Demo.active or Demo.loadCheck ~= check then return true end
        if Demo.DataReady(spells, items) or GetTime() - t0 >= Demo.LOAD_WAIT then
            Demo.loadCheck = nil
            done()
            return true
        end
        return false
    end
    Demo.loadCheck = check
    local function poll()
        if not check() then C_Timer.After(0.2, poll) end
    end
    poll()
end

-- GET_ITEM_INFO_RECEIVED im Demo-Modus: Vorladen sofort prüfen; danach nachgeladene Motive
-- ergänzen (nicht während eines Laufs, der zeigt die Zeilen je Bild bzw. Schritt neu)
function Demo.OnItemInfo(id)
    if Demo.loadCheck then
        Demo.loadCheck()
    elseif Demo.active and not Demo.run and not InCombatLockdown() then
        local _, items = Demo.Ids()
        for _, item in ipairs(items) do
            if item == id then Demo.Show(); return end
        end
    end
end

-- Beispielzeilen zeigen (Ablaufzeilen zuletzt, wie bei echten Warnungen). keys: Demo.ROWS-Keys
-- (nil = DEFAULT_ROWS), over: Key -> ersetzte Felder. Rückgabe: Anzahl gezeigter Zeilen.
function Demo.Show(keys, over)
    if not Demo.active or InCombatLockdown() then return 0 end
    local list, exp = {}, {}
    for _, key in ipairs(keys or Demo.DEFAULT_ROWS) do
        local d = Demo.Row(key)
        if d and over and over[key] then d = Demo.Merge(d, over[key]) end
        if d and Demo.RowKnown(d) then   -- Motive ohne Client-Daten auslassen
            local e = Demo.Entry(d)
            if d.expiry or d.charges then exp[#exp + 1] = e else list[#list + 1] = e end
        end
    end
    local from = #list + 1
    for _, e in ipairs(exp) do list[#list + 1] = e end
    Demo.entries = list
    Display.ShowRows(list, false, from)
    if Demo.run and not Demo.run.play then Demo.StillRows() end
    return #list
end

-- Screenshot-Lauf: Pulsieren anhalten (volle Deckkraft bzw. Ablauf-Transparenz)
function Demo.StillRows()
    for _, r in ipairs(rows) do
        r.pulse:Stop()
        r:SetAlpha(r.baseAlpha or 1)
    end
end

-- play: Ablauf für Videos (echte Größe/Deckkraft, keine Beispielzeilen zu Beginn)
function Demo.Start(after, play)
    if InCombatLockdown() then Print(L.COMBAT); return end
    if Demo.active then
        if after then after() end
        return
    end
    Demo.active = true
    Display.neutral = not play or nil   -- Demo und Bilder mit 100 % Größe und Deckkraft (Werte bleiben gespeichert)
    Cfg.UpdateTabs()         -- Reiter "Tier" in der Demo immer sichtbar
    ApplyLayout()
    if menu:IsShown() then menu:Hide() end
    Print(L.DEMO_ON)
    Demo.Preload(function()
        if play then Display.ShowRows({}) else Demo.Show() end
        if after then after() end
    end)
end

-- Demo (und Screenshot-Lauf bzw. Ablauf) beenden, alles zurücksetzen und normal neu auswerten
function Demo.Stop(quiet)
    if not Demo.active and not Demo.run then return end
    Demo.run = nil      -- laufende Timer verfallen
    Demo.active = false
    Demo.loadCheck = nil
    Demo.CloseDropdown()
    Restock.HideDemo()       -- Beispielfenster "Auffüllen" (nicht geschützt, auch im Kampf)
    Display.neutral = nil    -- Größe und Deckkraft des Spielers wieder anwenden
    Demo.Restore()
    Cfg.UpdateTabs()         -- Reiter "Tier" wieder nur für Jäger/Hexenmeister
    ApplyLayout()            -- im Kampf erst danach (layoutPending)
    if not InCombatLockdown() then
        if menu:IsShown() then menu:Hide() end
        Display.ShowRows({})   -- Beispielzeilen weg, auch falls Evaluate (noch) nichts zeigt
        Evaluate()
    end
    if not quiet then Print(L.DEMO_OFF) end
end

-- Kampfbeginn (PLAYER_REGEN_DISABLED): sofort beenden
function Demo.Abort()
    if not Demo.active and not Demo.run then return end
    Print(L.DEMO_ABORT)
    Demo.Stop(true)
end

-- /br demo [off | shot [settings | <ID>] | play [<ID> | stop] | restock]
function Demo.Command(sub, arg)
    arg = arg and arg ~= "" and arg:upper() or nil
    if sub == "off" then
        Demo.Stop()
    elseif sub == "shot" then
        Demo.StartShot(arg)
    elseif sub == "play" then
        if arg == "STOP" then
            Demo.Stop()
        elseif arg then
            Demo.Play(arg)
        else
            Print(L.DEMO_PLAY_LIST:format(table.concat(Demo.PLAY_ORDER, ", ")))
        end
    elseif sub == "restock" then
        -- Beispielfenster "Auffüllen" (zwei Zeilen, ohne Händler); erneut = schließen
        if Restock.demo and Restock.frame:IsShown() then
            Restock.HideDemo()
        else
            Demo.Start(function() Demo.OpenMenu("restock") end)
        end
    elseif Demo.active then
        Demo.Stop()
    else
        Demo.Start()
    end
end

function Demo.GetCVar(name)
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    local ok, v = pcall(C_CVar.GetCVar, name)
    if ok and type(v) == "string" and not IsSecret(v) then return v end
    return nil
end

function Demo.SetCVar(name, v)
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, v) end
end

-- Frame an WorldFrame hängen (sichtbar bei ausgeblendetem Interface); Skalierung so, dass die
-- effektive Größe gleich bleibt. keepPos: Bildschirmposition übernehmen (sonst setzt der
-- Aufrufer die Punkte neu, z. B. LayoutMenu relativ zum Parent).
function Demo.ToWorld(f, keepPos)
    local sv = Demo.saved
    if sv.frames[f] then return end
    local eff = f:GetEffectiveScale()
    local l, t = f:GetLeft(), f:GetTop()
    local strata = f:GetFrameStrata()
    sv.frames[f] = { parent = f:GetParent(), scale = f:GetScale(), strata = strata }
    f:SetParent(WorldFrame)
    f:SetScale(eff / WorldFrame:GetEffectiveScale())
    f:SetFrameStrata(strata)
    if keepPos and l and t then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", WorldFrame, "BOTTOMLEFT", l, t)
    end
end

-- flache Kopie bzw. Inhalt von src nach dst (dst vorher geleert)
function Demo.Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

function Demo.Refill(dst, src)
    wipe(dst)
    for k, v in pairs(src) do dst[k] = v end
end

-- Bild der Vorräte-Einstellungen: Beispiel-Items in die eigenen Items (einmal je Lauf). Vorher
-- cdb.supplies samt Min/Kritisch/Auffüllen/Zurückstellung sichern (Demo.RestoreSupplies).
function Demo.InjectSupplies()
    local sv = Demo.saved
    if not sv or sv.supplies or not Supply.ready then return end
    sv.supplies = { list = Demo.Copy(cdb.supplies), crit = Demo.Copy(cdb.supplyCritical),
        refill = Demo.Copy(cdb.supplyRefill), snooze = Demo.Copy(cdb.supplySnooze), added = {} }
    for _, id in ipairs(Demo.SUPPLY_ITEMS) do
        if not cdb.supplies[id] then
            cdb.supplies[id] = Supply.ITEM_DEFAULT
            sv.supplies.added[#sv.supplies.added + 1] = id
            Supply.Ensure(id)
        end
    end
    Supply.dirty = true
end

-- Gesicherte Vorräte exakt wiederherstellen (hinzugefügte Einträge entfernen, Tabellen zurück)
function Demo.RestoreSupplies(s)
    for _, id in ipairs(s.added) do Supply.RemoveItem(id) end
    Demo.Refill(cdb.supplies, s.list)
    Demo.Refill(cdb.supplyCritical, s.crit)
    Demo.Refill(cdb.supplyRefill, s.refill)
    Demo.Refill(cdb.supplySnooze, s.snooze)
    Supply.dirty = true
    if RefreshConfig then RefreshConfig() end
end

-- Gemerkten Zustand wiederherstellen (im Kampf erst nach PLAYER_REGEN_ENABLED)
function Demo.Restore()
    local sv = Demo.saved
    if not sv then return end
    if InCombatLockdown() then Demo.restorePending = true; return end
    Demo.saved, Demo.restorePending = nil, false
    Demo.CloseDropdown()
    if menu:IsShown() then menu:Hide() end
    Menu.HideItemPanel()
    for f, info in pairs(sv.frames) do
        f:SetParent(info.parent)
        f:SetScale(info.scale)
        f:SetFrameStrata(info.strata)
    end
    for name, v in pairs(sv.cvars) do Demo.SetCVar(name, v) end
    if sv.supplies then Demo.RestoreSupplies(sv.supplies) end
    db.style, db.iconsOnly = sv.style, sv.iconsOnly
    db.cfgTab = sv.cfgTab                    -- gemerkten Tab der Einstellungen wiederherstellen
    if State.config then Cfg.SelectTab(sv.cfgTab) end
    ApplyLayout()
    Display.ApplyStyle()
    if sv.uiShown and not UIParent:IsShown() then
        pcall(UIParent.Show, UIParent)
        if not UIParent:IsShown() then Print(L.DEMO_ALTZ) end
    end
end

-- f() nach t Sek., nur solange derselbe Lauf aktiv ist
function Demo.After(t, f)
    local run = Demo.run
    C_Timer.After(t, function()
        if Demo.run == run then f() end
    end)
end

-- Warten, bis cond() gilt (Polling); done() bzw. nach timeout Sek. onTimeout()
function Demo.WaitFor(cond, timeout, done, onTimeout)
    local run, t0 = Demo.run, GetTime()
    local function poll()
        if Demo.run ~= run then return end
        if cond() then done(); return end
        if GetTime() - t0 >= timeout then onTimeout(); return end
        C_Timer.After(0.25, poll)
    end
    poll()
end

function Demo.StopTimeout()
    Print(L.DEMO_TIMEOUT)
    Demo.Stop(true)
end

-- Interface ein-/ausblenden: zuerst selbst (UIParent:Show/Hide per pcall), sonst Hinweis Alt+Z
-- und warten (Abbruch nach 60 Sek.)
function Demo.SetUI(show, cont)
    if show then pcall(UIParent.Show, UIParent) else pcall(UIParent.Hide, UIParent) end
    if UIParent:IsShown() == show then cont(); return end
    Print(L.DEMO_ALTZ)
    Demo.WaitFor(function() return UIParent:IsShown() == show end, 60, cont, Demo.StopTimeout)
end

-- /br demo shot [settings | <ID>]
function Demo.StartShot(filter)
    if InCombatLockdown() then Print(L.COMBAT); return end
    if Demo.run then Print(L.DEMO_BUSY); return end
    local shots = Demo.BuildShots(filter)
    if #shots == 0 then Print(L.DEMO_UNKNOWN_ID:format(filter or "?")); return end
    Demo.Start(function()
        if Demo.active and not Demo.run then Demo.BeginRun(shots) end
    end)
end

-- Zustand merken, Screenshot-CVars setzen, Anzeige und Menü an WorldFrame hängen, loslegen
function Demo.BeginRun(shots)
    Demo.run = { manual = false, shots = shots }
    local sv = { frames = {}, cvars = {}, style = db.style, iconsOnly = db.iconsOnly, uiShown = UIParent:IsShown(),
        cfgTab = db.cfgTab }
    Demo.saved = sv
    sv.cvars.screenshotFormat = Demo.GetCVar("screenshotFormat")
    sv.cvars.screenshotQuality = Demo.GetCVar("screenshotQuality")
    if sv.cvars.screenshotFormat then Demo.SetCVar("screenshotFormat", "png") end
    if sv.cvars.screenshotQuality then Demo.SetCVar("screenshotQuality", "10") end
    db.demoShots = { started = time(), shots = {} }
    local _, sw, sh = Demo.PixelScale()
    if sw then db.demoShots.screen = { w = sw, h = sh } end   -- physische Pixel (Prüfung im Skript)
    anchor:SetFrameStrata("HIGH")   -- Screenshot-Lauf wie bisher (Demo-Modus selbst: MEDIUM)
    if menu:IsShown() then menu:Hide() end
    Demo.ToWorld(anchor, true)
    Demo.ToWorld(menu)
    Demo.ToWorld(itemPanel)
    Demo.ToWorld(Restock.Frame())
    Demo.RunShot(1)
end

-- /br demo play <ID>: Ablauf für Videos mit den echten Einstellungen (Größe, Deckkraft, Position,
-- Stil); die Anzeige bleibt am Interface. Kampfbeginn bricht ab (Demo.Abort).
function Demo.Play(id)
    if InCombatLockdown() then Print(L.COMBAT); return end
    if Demo.run and not Demo.run.play then Print(L.DEMO_BUSY); return end
    local build = Demo.PLAYS[id]
    if not build then Print(L.DEMO_UNKNOWN_ID:format(id)); return end
    Demo.Start(function()
        if not Demo.active or (Demo.run and not Demo.run.play) then return end
        Demo.run = { play = id }   -- alte Timer (vorheriger Ablauf) verfallen
        if Display.neutral then
            Display.neutral = nil
            ApplyLayout()
        end
        Restock.HideDemo()
        if menu:IsShown() then menu:Hide() end
        Display.ShowRows({})
        Demo.playRows = {}
        Demo.PlayStep(build(), 1, Demo.PLAY_LEAD)
    end, true)
end

-- Schritt i eines Ablaufs nach lead + t Sek.; nach dem letzten PLAY_TAIL Sek. leer, dann Ende
function Demo.PlayStep(steps, i, lead)
    local s = steps[i]
    if not s then
        Demo.After(Demo.PLAY_TAIL, function()
            local id = Demo.run.play
            Demo.Stop(true)
            Print(L.DEMO_PLAY_DONE:format(id))
        end)
        return
    end
    Demo.After((lead or 0) + (s.t or 0), function()
        if s.rows or s.over then
            if s.rows and menu:IsShown() then menu:Hide() end
            Demo.playRows = s.rows or Demo.playRows
            Demo.Show(Demo.playRows, s.over)
        end
        if s.menu then Demo.OpenMenu(s.menu) end
        Demo.PlayStep(steps, i + 1)
    end)
end

-- Menü eines Motivs rechts neben der ganzen Anzeige öffnen (x = größtes GetRight aller sichtbaren
-- Zeilen + 12, y = Oberkante der Motiv-Zeile; Koordinaten in Menü-Einheiten). So liegt es bei
-- "Nur Icons" nicht über den folgenden Icons. restock: "vendor" | "trade" | "nogold".
function Demo.OpenMenu(which, restock)
    for i, e in ipairs(Demo.entries or {}) do
        local r = rows[i]
        if e.demo.menu == which and r and r:IsShown() then
            local right, top = nil, r:GetTop()
            for _, row in ipairs(rows) do
                local rr = row:IsShown() and row:GetRight()
                if type(rr) == "number" then right = math.max(right or rr, rr) end
            end
            if right and top then
                local k = r:GetEffectiveScale() / menu:GetEffectiveScale()
                menu.x, menu.y = right * k + 12, top * k
            end
            -- Fenster "Auffüllen" (Beispiel ohne Händler) an derselben Stelle wie das Menü
            if which == "restock" then Restock.ShowDemo(menu.x, menu.y, restock); return end
            Menu.LayoutMenu(e)
            menu.away = 0
            menu:Show()
            return
        end
    end
end

-- Tab der Einstellungen zeigen und nach oben scrollen; false = Tab gibt es nicht (Bild entfällt).
-- Tab-Wechsel (samt RefreshConfig) und Scrollen laufen per pcall: Ein Fehler darin hat früher den
-- Timer-Callback und damit den ganzen Lauf stumm beendet (Bilder ab "settings-other-buffs" fehlten,
-- kein Zurücksetzen). Jetzt: Fehler im Chat melden, Bild trotzdem aufnehmen.
function Demo.ShowTab(key)
    local t = Cfg.tabs[key]
    if not t or not Cfg.TabShown(key) then return false end
    local ok, err = pcall(Cfg.SelectTab, key)
    if not ok then Print(L.DEMO_TAB_ERROR:format(key, tostring(err))) end
    ok, err = pcall(t.scroll.SetVerticalScroll, t.scroll, 0)
    if not ok then Print(L.DEMO_TAB_ERROR:format(key, tostring(err))) end
    return true
end

-- ganz nach unten scrollen (nach dem Aufbau des Tabs)
function Demo.ScrollBottom(key)
    local sc = Cfg.tabs[key].scroll
    if sc.UpdateScrollChildRect then sc:UpdateScrollChildRect() end
    local range = sc:GetVerticalScrollRange()
    if type(range) == "number" and not IsSecret(range) and range > 0 then sc:SetVerticalScroll(range) end
end

-- Auswahlliste in den sichtbaren Bereich scrollen (mit Platz für die aufgeklappte Liste darunter)
function Demo.ScrollIntoView(key, f)
    local t = Cfg.tabs[key]
    local ct, ft, h = t.content:GetTop(), f:GetTop(), t.scroll:GetHeight()
    local range, cur = t.scroll:GetVerticalScrollRange(), t.scroll:GetVerticalScroll()
    for _, v in ipairs({ ct or false, ft or false, h or false, range or false, cur or false }) do
        if type(v) ~= "number" or IsSecret(v) then return end
    end
    local offset = ct - ft
    if offset >= cur and offset - cur <= h - 200 then return end
    t.scroll:SetVerticalScroll(math.max(0, math.min(range, offset - 40)))
end

-- Frame der offenen modernen Auswahlliste (DropdownButton.menu bzw. Menü-Manager); nil = unbekannt
function Demo.ModernMenuFrame(f)
    local m = f.menu
    if type(m) ~= "table" then
        local api = _G["Menu"]   -- Blizzard-Menü (das Addon hat eine eigene lokale Tabelle Menu)
        if type(api) == "table" and type(api.GetManager) == "function" then
            local ok, mgr = pcall(api.GetManager)
            if ok and type(mgr) == "table" and type(mgr.GetOpenMenu) == "function" then
                local ok2, open = pcall(mgr.GetOpenMenu, mgr)
                if ok2 then m = open end
            end
        end
    end
    return m
end

-- Auswahlliste der Szene aufklappen (neues Dropdown: OpenMenu, altes: ToggleDropDownMenu; per
-- pcall). Merkt den Frame der Liste für den Zuschnitt; false = nicht gelungen.
function Demo.OpenDropdown(s)
    Demo.CloseDropdown()
    local dd = State.config and State.config[Demo.DROPDOWNS[s.dropdown] or ""]
    local f = dd and dd.frame
    local ok, list = false, nil
    if f then
        pcall(Demo.ScrollIntoView, s.settings, f)
        if dd.kind == "modern" and type(f.OpenMenu) == "function" then
            ok = pcall(f.OpenMenu, f)
            if ok then list = Demo.ModernMenuFrame(f) end
        elseif dd.kind == "legacy" and type(_G["ToggleDropDownMenu"]) == "function" then
            ok = pcall(_G["ToggleDropDownMenu"], 1, nil, f)
            if ok then list = _G["DropDownList1"] end
        end
    end
    if ok then Demo.ddOpen = dd end
    if type(list) == "table" and type(list.IsVisible) == "function" and type(list.GetLeft) == "function" then
        Demo.ddList = list
    end
    return ok
end

function Demo.CloseDropdown()
    local dd = Demo.ddOpen
    Demo.ddOpen, Demo.ddList = nil, nil
    if not dd then return end
    if dd.kind == "modern" and type(dd.frame.CloseMenu) == "function" then
        pcall(dd.frame.CloseMenu, dd.frame)
    elseif type(CloseDropDownMenus) == "function" then
        pcall(CloseDropDownMenus)
    end
end

-- Szene geht beim aktuellen Charakter nicht: Chatzeile, weiter mit der nächsten
function Demo.Skip(i, s, reason)
    Print(L.DEMO_SKIPPED:format(s.id, reason))
    Demo.RunShot(i + 1)
end

-- Einstellungsbild: Fenster öffnen, Tab zeigen, ggf. nach unten scrollen bzw. Liste aufklappen
function Demo.RunSettingsShot(i, s)
    -- mit sichtbarem Interface, ohne Beispielzeilen, im echten Stil (Stand vor dem Lauf), damit
    -- die Einstellungen den tatsächlichen Stand zeigen
    if menu:IsShown() then menu:Hide() end
    Restock.HideDemo()
    Display.ShowRows({})
    if Demo.saved and (db.style ~= Demo.saved.style or db.iconsOnly ~= Demo.saved.iconsOnly) then
        db.style, db.iconsOnly = Demo.saved.style, Demo.saved.iconsOnly
        Display.ApplyStyle()
    end
    if s.settings == "supplies" then Demo.InjectSupplies() end
    if not (State.config and State.config:IsVisible()) then ToggleConfig() end
    Demo.After(0.5, function()
        if not Demo.ShowTab(s.settings) then Demo.Skip(i, s, L.DEMO_SKIP_TAB:format(s.settings)); return end
        if not (s.scroll == "bottom" or s.dropdown) then
            Demo.After(Demo.SHOT_DELAY, function() Demo.Capture(i) end)
            return
        end
        Demo.After(0.3, function()
            if s.scroll == "bottom" then
                local ok, err = pcall(Demo.ScrollBottom, s.settings)
                if not ok then Print(L.DEMO_TAB_ERROR:format(s.settings, tostring(err))) end
            end
            if s.dropdown and not Demo.OpenDropdown(s) then Print(L.DEMO_DROPDOWN_FAIL:format(s.id)) end
            Demo.After(Demo.SHOT_DELAY, function() Demo.Capture(i) end)
        end)
    end)
end

function Demo.RunShot(i)
    if not Demo.run then return end
    local s = Demo.run.shots[i]
    if not s then Demo.FinishRun(); return end
    Demo.CloseDropdown()
    if s.class and Pet.class ~= s.class then Demo.Skip(i, s, L.DEMO_SKIP_CLASS:format(s.class)); return end
    local wantUI = s.settings ~= nil
    if UIParent:IsShown() ~= wantUI then
        Demo.SetUI(wantUI, function() Demo.RunShot(i) end)
        return
    end
    if s.settings then Demo.RunSettingsShot(i, s); return end
    db.style, db.iconsOnly = s.style or "pardona", s.icons == true
    Display.ApplyStyle()   -- schließt auch ein offenes Menü
    Restock.HideDemo()     -- Beispielfenster "Auffüllen" nur im eigenen Motiv
    if Demo.Show(s.rows) == 0 then Demo.Skip(i, s, L.DEMO_SKIP_DATA); return end
    if s.menu then Demo.OpenMenu(s.menu, s.restock) end
    Demo.After(Demo.SHOT_DELAY, function() Demo.Capture(i) end)
end

-- Physische Bildschirmgröße und Faktor 768er-Raster -> Pixel; nil = nicht lesbar
function Demo.PixelScale()
    if type(GetPhysicalScreenSize) ~= "function" then return nil end
    local ok, w, h = pcall(GetPhysicalScreenSize)
    if not ok or type(w) ~= "number" or type(h) ~= "number" or IsSecret(w) or IsSecret(h) or h <= 0 then
        return nil
    end
    return h / 768, w, h
end

-- Zuschnitt-Rechteck in Bildschirm-Pixeln (Ursprung oben links) als Vereinigung der sichtbaren
-- Frames: Kante × GetEffectiveScale() = 768er-Raster, × (physische Höhe / 768) = Pixel;
-- y von oben = physische Höhe − top. nil = nicht berechenbar (dann ganzes Bild).
function Demo.CropOf(frames)
    local k, _, sh = Demo.PixelScale()
    if not k then return nil end
    local l, r, t, b
    for _, fr in ipairs(frames) do
        if fr:IsVisible() then
            local fl, frr, ft, fb, sc = fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom(), fr:GetEffectiveScale()
            for _, v in ipairs({ fl or false, frr or false, ft or false, fb or false, sc or false }) do
                if type(v) ~= "number" or IsSecret(v) then return nil end
            end
            fl, frr, ft, fb = fl * sc, frr * sc, ft * sc, fb * sc
            l = l and math.min(l, fl) or fl
            r = r and math.max(r, frr) or frr
            t = t and math.max(t, ft) or ft
            b = b and math.min(b, fb) or fb
        end
    end
    if not l then return nil end
    local function px(v) return math.floor(v * k + 0.5) end
    return { x = px(l), y = math.floor(sh - t * k + 0.5), w = px(r) - px(l), h = px(t) - px(b) }
end

-- Oberster Fenster-Frame über f (letzter Vorfahre vor UIParent bzw. ohne Parent), z. B.
-- SettingsPanel für die Seite unter "Pardona's Addons", BuffReminderConfig ohne Settings-API
function Demo.TopWindow(fr)
    for _ = 1, 30 do
        local p = fr:GetParent()
        if not p or p == UIParent or p == WorldFrame then return fr end
        fr = p
    end
    return fr
end

-- Frames, die ein Bild zeigt: Warnzeilen + offenes Menü bzw. das Einstellungsfenster (+ offene Liste)
function Demo.ShotFrames(s)
    if s.settings then
        local list = State.config and { Demo.TopWindow(State.config) } or {}
        if Demo.ddList then list[#list + 1] = Demo.ddList end
        return list
    end
    local list = {}
    for _, r in ipairs(rows) do
        if r:IsShown() then list[#list + 1] = r end
    end
    if menu:IsShown() then list[#list + 1] = menu end
    if Restock.frame and Restock.frame:IsShown() then list[#list + 1] = Restock.frame end
    if itemPanel:IsShown() then list[#list + 1] = itemPanel end
    return list
end

-- Bild auslösen und auf SCREENSHOT_SUCCEEDED/FAILED warten (5 Sek.). Kommt kein Ereignis,
-- gilt Screenshot() als blockiert: Hinweis "Druck-Taste" und warten (60 Sek.).
function Demo.Capture(i)
    local run = Demo.run
    if not run then return end
    local s = run.shots[i]
    run.result, run.waiting = nil, true
    -- Zuschnitt vor dem Bild (Stand wie auf dem Bild); Fehler -> ganzes Bild statt Abbruch des Laufs
    local okCrop, crop = pcall(function() return Demo.CropOf(Demo.ShotFrames(s)) end)
    run.crop = okCrop and crop or nil
    if run.manual then
        Print(L.DEMO_PRINT)
    elseif not (type(Screenshot) == "function" and pcall(Screenshot)) then
        run.manual = true
        Print(L.DEMO_PRINT)
    end
    Demo.WaitFor(function() return run.result ~= nil end, run.manual and 60 or 5, function()
        run.waiting = false
        if run.result then
            local list = db.demoShots.shots
            list[#list + 1] = { n = #list + 1, id = s.id, name = s.name, t = time(), crop = run.crop }
        else
            Print(L.DEMO_SHOT_FAIL:format(s.id .. "-" .. s.name))
        end
        Demo.RunShot(i + 1)
    end, function()
        run.waiting = false
        if run.manual then Demo.StopTimeout(); return end
        run.manual = true
        Demo.Capture(i)
    end)
end

-- SCREENSHOT_SUCCEEDED / SCREENSHOT_FAILED
function Demo.OnScreenshot(ok)
    local run = Demo.run
    if run and run.waiting and run.result == nil then run.result = ok end
end

function Demo.FinishRun()
    local n = db.demoShots and #db.demoShots.shots or 0
    Demo.Stop(true)
    Print(L.DEMO_DONE:format(n))
end
