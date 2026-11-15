-- luacheck configuration for Pardona's Buff Reminder (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = false
-- WoW callbacks receive parameters (self, event, button, ...) that are often unused
unused_args = false
exclude_files = { ".release" }

-- Globals the addon writes
globals = {
    "BuffReminderDB",
    "BuffReminderCharDB",
    "SLASH_BUFFREMINDER1",
    "SLASH_BUFFREMINDER2",
    "SlashCmdList",
    "UISpecialFrames",
}

-- WoW API functions and objects the addon reads
read_globals = {
    -- namespaces
    "C_CVar",
    "C_Item",
    "C_Spell",
    "C_SpellBook",
    "C_Timer",
    "C_UnitAuras",
    -- frames and UI objects
    "CreateFrame",
    "GameTooltip",
    "Minimap",
    "UIParent",
    "SOUNDKIT",
    -- functions
    "GetCursorPosition",
    "GetCVar",
    "GetCVarBool",
    "GetInventoryItemID",
    "GetItemInfoInstant",
    "GetLocale",
    "GetSpellInfo",
    "GetSpellTexture",
    "GetTime",
    "GetWeaponEnchantInfo",
    "InCombatLockdown",
    "IsInInstance",
    "IsPlayerSpell",
    "issecretvalue",
    "IsSpellKnown",
    "MouseIsOver",
    "PlaySound",
    "tinsert",
    "UnitBuff",
    "UnitClass",
    "UnitInVehicle",
    "UnitIsDeadOrGhost",
    "UnitLevel",
    "UnitOnTaxi",
    "wipe",
}
