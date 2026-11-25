-- Pardona's Buff Reminder – Stile der Warnanzeige und des Rechtsklick-Menüs, Stil "Pardona" aus LibPardona.
-- Abhängigkeiten (beim Laden): Core.lua

local ADDON_NAME, ns = ...

-- aus Core.lua
local Style = ns.Style
local IsSecret = ns.IsSecret
-- SavedVariables, aktuell gehalten über ns.OnDB (Core.lua)
local db
ns.OnDB(function(newDb) db = newDb end)

---------------------------------------------------------------------------
-- Stile (Warnanzeige + Rechtsklick-Menü)
-- Alle Farben, Größen und Abstände stehen hier; ein neuer Stil = neuer Eintrag in
-- STYLES + Name in STYLE_ORDER + Text STYLE_NAME_<KEY> in Locales/enUS.lua. Farben: { r, g, b [, a] }.
-- Texturen: nur Standard-UI-Elemente (Backdrop-Kanten, WHITE8X8, Highlight).
---------------------------------------------------------------------------
Style.WHITE = "Interface\\Buttons\\WHITE8X8"
Style.ROUND_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
Style.HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

-- Farbe des Statusstreifens links je Zeilenzustand (gemeinsam für alle Stile)
Style.STATUS_COLORS = {
    missing = { 0.9, 0.15, 0.15 },   -- Buff fehlt
    low     = { 1, 0.55, 0.1 },      -- Reagenz knapp
    eating  = { 0.35, 0.8, 0.3 },    -- isst gerade
    expiring = { 1, 0.75, 0.1 },     -- läuft bald ab (Bernstein)
    neutral = { 0.55, 0.55, 0.55 },  -- Verschiebe-Modus
}

Style.STYLE_ORDER = { "pardona", "classic", "compact" }
-- Hinweis: Farben, Rahmen und Schriften von "pardona" überschreibt Style.SyncFromLib (LP.Style);
-- die Werte hier sind der Rückfall (Style.PARDONA_FALLBACK).
Style.STYLES = {
    pardona = {
        -- Warnzeile
        row = { width = 300, height = 42, heightGroup = 56, gap = 3, pad = 6 },
        edge = Style.ROUND_EDGE, edgeSize = 12, inset = 3,          -- abgerundete Ecken
        bgTop = { 0.20, 0.09, 0.30, 0.94 }, bgBottom = { 0.08, 0.03, 0.13, 0.94 },   -- Verlauf
        border = { 0.85, 0.68, 0.25, 1 },                     -- Goldrand
        stripe = 4, status = Style.STATUS_COLORS,
        icon = 30, iconBorder = { 0.85, 0.68, 0.25, 1 },
        titleFont = "GameFontNormal", titleColor = { 1, 0.82, 0.25 },
        hintFont = "GameFontDisableSmall", hintColor = { 0.66, 0.58, 0.76 },
        namesColor = { 0.9, 0.88, 0.95 },
        hints = true,          -- Hinweiszeile in der Zeile (false: nur im Tooltip)
        rightText = false,     -- Kurztext "fehlt" rechtsbündig
        iconsOnly = false,     -- Option "Nur Icons" verfügbar
        -- Rechtsklick-Menü
        menu = {
            width = 300, pad = 10, gap = 8, headerIcon = 28, itemHeight = 30, itemTwoLines = true,
            sectionColor = { 0.85, 0.68, 0.25 }, sepColor = { 0.85, 0.68, 0.25, 0.35 },
            textColor = { 0.95, 0.93, 1 }, subColor = { 0.66, 0.58, 0.76 },
            buttonBg = { 0.28, 0.14, 0.40, 0.9 }, buttonBorder = { 0.85, 0.68, 0.25, 0.8 },
            xpBg = { 0.45, 0.25, 0.65, 1 }, starOff = 0.35,
        },
    },
    classic = {
        row = { width = 300, height = 42, heightGroup = 56, gap = 3, pad = 6 },
        edge = Style.WHITE, edgeSize = 2, inset = 2,                -- kantiger Goldrahmen
        bgTop = { 0.27, 0.21, 0.14, 0.95 }, bgBottom = { 0.17, 0.13, 0.09, 0.95 },  -- Stein/Braun
        border = { 0.78, 0.62, 0.22, 1 },
        stripe = 0, status = Style.STATUS_COLORS,
        icon = 30, iconBorder = { 0, 0, 0, 1 },
        titleFont = "GameFontNormal", titleColor = { 1, 0.82, 0 },   -- WoW-Gelb
        hintFont = "GameFontHighlightSmall", hintColor = { 0.87, 0.80, 0.64 },  -- beige
        namesColor = { 1, 1, 1 },
        hints = true, rightText = false, iconsOnly = false,
        menu = {
            width = 300, pad = 10, gap = 8, headerIcon = 28, itemHeight = 30, itemTwoLines = true,
            sectionColor = { 1, 0.82, 0 }, sepColor = { 0.78, 0.62, 0.22, 0.5 },
            textColor = { 1, 1, 1 }, subColor = { 0.87, 0.80, 0.64 },
            buttonBg = { 0.36, 0.28, 0.18, 0.95 }, buttonBorder = { 0.78, 0.62, 0.22, 1 },
            xpBg = { 0.15, 0.45, 0.15, 1 }, starOff = 0.35,
        },
    },
    compact = {
        row = { width = 220, height = 22, heightGroup = 22, gap = 2, pad = 4 },
        edge = Style.WHITE, edgeSize = 1, inset = 1,
        bgTop = { 0.06, 0.06, 0.08, 0.88 }, bgBottom = nil,   -- schmale dunkle Balken
        border = { 0, 0, 0, 0.9 },
        stripe = 3, status = Style.STATUS_COLORS,
        icon = 16, iconBorder = nil,
        titleFont = "GameFontHighlightSmall", titleColor = { 1, 1, 1 },
        hintFont = "GameFontDisableSmall", hintColor = { 0.6, 0.6, 0.6 },
        namesColor = { 0.8, 0.8, 0.8 },
        hints = false, rightText = true, iconsOnly = true,
        menu = {
            width = 250, pad = 6, gap = 5, headerIcon = 20, itemHeight = 20, itemTwoLines = false,
            sectionColor = { 0.8, 0.8, 0.8 }, sepColor = { 1, 1, 1, 0.12 },
            textColor = { 1, 1, 1 }, subColor = { 0.6, 0.6, 0.6 },
            buttonBg = { 0.14, 0.14, 0.17, 0.95 }, buttonBorder = { 0, 0, 0, 1 },
            xpBg = { 0.25, 0.45, 0.25, 1 }, starOff = 0.3,
        },
    },
}

---------------------------------------------------------------------------
-- Stil "Pardona" aus LibPardona (LP.Style, gemeinsam für alle Pardona-Addons)
-- Farben, Rahmen und Schriften kommen aus der Bibliothek; Größen, namesColor und die
-- Statusfarben bleiben eigene Werte. Style.SyncFromLib läuft bei PLAYER_LOGIN (dann ist die
-- höchste MINOR aktiv; eine spätere Kopie der Bibliothek kann LP.Style ersetzen, daher kein
-- Cache beim Laden der Datei). Fehlt ein Feld oder hat es den falschen Typ, gilt der Rückfall
-- (Style.PARDONA_FALLBACK = bisherige Werte). Rahmenlogik der Bibliothek (LP:ApplyStyle) wird
-- nicht verwendet.
--   Style.LIB_MAP: { BR-Feld, Art, LP.Style-Quelle }; menu.* = Feld in STYLES.pardona.menu
---------------------------------------------------------------------------
Style.LIB_MAP = {
    { "bgTop",             "color", "bgTop" },
    { "bgBottom",          "color", "bgBottom" },
    { "border",            "color", "border" },
    { "iconBorder",        "color", "border" },
    { "edge",              "edge",  "file" },
    { "edgeSize",          "edge",  "size" },
    { "inset",             "edge",  "inset" },
    { "titleFont",         "font",  "title" },
    { "titleColor",        "color", "title" },
    { "hintFont",          "font",  "hint" },
    { "hintColor",         "color", "hint" },
    { "menu.sectionColor", "color", "section" },
    { "menu.sepColor",     "color", "separator" },
    { "menu.textColor",    "color", "text" },
    { "menu.subColor",     "color", "hint" },
    { "menu.buttonBg",     "color", "buttonBg" },
    { "menu.buttonBorder", "color", "buttonBorder" },
    { "menu.xpBg",         "color", "accent" },
}
Style.fontObjects = {}   -- Rolle -> eigenes Font-Objekt (nur bei Schriften als Pfad/Größe/Flags)
-- Style.source: "lib" | "fallback"; Style.libVersion: LP.STYLE_VERSION beim letzten Abgleich

-- Ziel-Tabelle und Schlüssel eines BR-Felds ("menu.xpBg" -> STYLES.pardona.menu, "xpBg")
function Style.Target(st, field)
    local sub, key = field:match("^(%a+)%.(%a+)$")
    if sub then return st[sub], key end
    return st, field
end

-- Rückfall: die bisherigen Werte der gemappten Felder (einmal beim Laden der Datei)
function Style.CopyFallback()
    local st, fb = Style.STYLES.pardona, {}
    for _, m in ipairs(Style.LIB_MAP) do
        local t, key = Style.Target(st, m[1])
        fb[m[1]] = t[key]
    end
    return fb
end

function Style.Index(t, key) return t[key] end

-- t[key] geschützt lesen; Secret-Werte und Fehler gelten als fehlend
function Style.LibField(t, key)
    if type(t) ~= "table" or IsSecret(t) then return nil end
    local ok, v = pcall(Style.Index, t, key)
    if not ok or IsSecret(v) then return nil end
    return v
end

-- Farbe { r, g, b, a } oder { r = , g = , b = , a = } -> { r, g, b, a } (a fehlt = 1); nil = ungültig
function Style.LibColor(c)
    if type(c) ~= "table" or IsSecret(c) then return nil end
    local r, g, b, a = Style.LibField(c, 1), Style.LibField(c, 2), Style.LibField(c, 3), Style.LibField(c, 4)
    if r == nil then
        r, g, b, a = Style.LibField(c, "r"), Style.LibField(c, "g"), Style.LibField(c, "b"), Style.LibField(c, "a")
    end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if a == nil then a = 1 end
    if type(a) ~= "number" then return nil end
    return { r, g, b, a }
end

function Style.IsFontPath(v)
    return type(v) == "string" and (v:find("[\\/]") ~= nil or v:lower():find("%.[ot]tf$") ~= nil)
end

function Style.IsFontObject(v)
    return type(v) == "table" and not IsSecret(v) and type(Style.LibField(v, "GetFont")) == "function"
end

-- eigenes Font-Objekt für eine Schrift als Pfad/Größe/Flags (CreateFont abgesichert)
function Style.MakeFont(role, path, size, flags)
    if type(CreateFont) ~= "function" then return nil end
    local obj = Style.fontObjects[role]
    if not obj then
        local ok, o = pcall(CreateFont, "PardonasBuffReminderFont_" .. role)
        if not ok or not o then return nil end
        obj = o
        Style.fontObjects[role] = obj
    end
    local ok = pcall(obj.SetFont, obj, path, size, type(flags) == "string" and flags or "")
    return ok and obj or nil
end

-- Schrift aus LP.Style.fonts[role] in das BR-Format (Name eines Font-Objekts oder Font-Objekt):
--   "GameFontNormal" | Font-Objekt | { font = Name/Objekt[, color] } |
--   { font = Pfad, size = n, flags = s } | { Pfad, n, s }
function Style.LibFont(v, role)
    if type(v) == "string" and not Style.IsFontPath(v) then return v end
    if Style.IsFontObject(v) then return v end
    if type(v) ~= "table" or IsSecret(v) then return nil end
    local font = Style.LibField(v, "font")
    if type(font) == "string" and not Style.IsFontPath(font) then return font end
    if Style.IsFontObject(font) then return font end
    local path, size, flags = font, Style.LibField(v, "size"), Style.LibField(v, "flags")
    if not Style.IsFontPath(path) then path, size, flags = Style.LibField(v, 1), Style.LibField(v, 2), Style.LibField(v, 3) end
    if Style.IsFontPath(path) and type(size) == "number" and size > 0 then
        return Style.MakeFont(role, path, size, flags)
    end
    return nil
end

-- Wert eines Mapping-Eintrags aus LP.Style; nil = fehlt/ungültig (dann Rückfall)
function Style.LibValue(ls, m)
    local kind, src = m[2], m[3]
    if kind == "color" then return Style.LibColor(Style.LibField(Style.LibField(ls, "colors"), src)) end
    if kind == "font" then return Style.LibFont(Style.LibField(Style.LibField(ls, "fonts"), src), src) end
    local v = Style.LibField(Style.LibField(ls, "edge"), src)
    if src == "file" then return (type(v) == "string" and v ~= "") and v or nil end
    return (type(v) == "number" and v >= 0) and v or nil
end

-- Felder des Stils "Pardona" aus LP.Style übernehmen (Feld für Feld, sonst Rückfall)
function Style.SyncFromLib()
    local st, fb = Style.STYLES.pardona, Style.PARDONA_FALLBACK
    local lp = LibStub and LibStub("LibPardona-1.0", true)
    local ver = Style.LibField(lp, "STYLE_VERSION")
    local ls = type(ver) == "number" and Style.LibField(lp, "Style") or nil
    local used = false
    for _, m in ipairs(Style.LIB_MAP) do
        local v = ls and Style.LibValue(ls, m)
        local t, key = Style.Target(st, m[1])
        if v ~= nil then used = true end
        if v == nil then v = fb[m[1]] end
        t[key] = v
    end
    Style.source = used and "lib" or "fallback"
    Style.libVersion = used and ver or nil
end

Style.PARDONA_FALLBACK = Style.CopyFallback()

-- Zeile für /br debug
function Style.DebugLine()
    if Style.source == "lib" then return ("style: lib (STYLE_VERSION %s)"):format(tostring(Style.libVersion)) end
    return "style: fallback"
end

function Style.CurrentStyle()
    return Style.STYLES[db and db.style] or Style.STYLES.pardona
end

function Style.IconsOnly(st)
    return st.iconsOnly and db ~= nil and db.iconsOnly == true
end

function Style.SetColor(obj, method, c)
    if c then obj[method](obj, c[1], c[2], c[3], c[4] or 1) end
end

-- Hintergrund: Verlauf (bgBottom gesetzt) oder einfarbig
function Style.SetGradientBg(tex, top, bottom)
    if bottom and tex.SetGradient and CreateColor then
        tex:SetColorTexture(1, 1, 1, 1)
        local ok = pcall(tex.SetGradient, tex, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
        if ok then return end
    end
    tex:SetColorTexture(top[1], top[2], top[3], top[4] or 1)
    tex:SetVertexColor(1, 1, 1, 1)   -- evtl. alten Verlauf zurücksetzen
end

-- Rahmen (Backdrop-Kante) + eigener Hintergrund-Texture innerhalb der Kante
function Style.StyleFrame(f, st, bgTex)
    f:SetBackdrop({ edgeFile = st.edge, edgeSize = st.edgeSize })
    Style.SetColor(f, "SetBackdropBorderColor", st.border)
    bgTex:ClearAllPoints()
    bgTex:SetPoint("TOPLEFT", st.inset, -st.inset)
    bgTex:SetPoint("BOTTOMRIGHT", -st.inset, st.inset)
    Style.SetGradientBg(bgTex, st.bgTop, st.bgBottom)
end

-- Schriftobjekt per Name (z. B. "GameFontNormal")
function Style.SetFont(fs, name)
    fs:SetFontObject(_G[name] or name)
end

-- Rand um ein Icon (Texture hinter dem Icon, 1 px größer)
function Style.StyleIconBorder(border, icon, color)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    if color then
        border:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        border:Show()
    else
        border:Hide()
    end
end

-- Favoriten-Stern: Atlas des Spiels (Sammlungen), sonst Text "*"
Style.STAR_ATLASES = { "collections-icon-favorites", "PetJournal-FavoritesIcon" }
-- Style.starAtlas: false = keiner verfügbar, nil = noch nicht geprüft
function Style.StarAtlas()
    if Style.starAtlas ~= nil then return Style.starAtlas or nil end
    Style.starAtlas = false
    if C_Texture and C_Texture.GetAtlasInfo then
        for _, a in ipairs(Style.STAR_ATLASES) do
            local ok, info = pcall(C_Texture.GetAtlasInfo, a)
            if ok and info then Style.starAtlas = a; break end
        end
    end
    return Style.starAtlas or nil
end

-- Stern als Inline-Markup für FontStrings
function Style.StarMarkup(size)
    local a = Style.StarAtlas()
    if a then return ("|A:%s:%d:%d|a"):format(a, size, size) end
    return "*"
end
