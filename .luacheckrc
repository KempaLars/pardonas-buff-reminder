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
    "C_Container",
    "C_CVar",
    "C_Item",
    "C_Spell",
    "C_SpellBook",
    "C_Timer",
    "C_TooltipInfo",
    "C_UnitAuras",
    -- frames and UI objects
    "CreateFrame",
    "Enum",
    "GameTooltip",
    "Minimap",
    "UIParent",
    "SOUNDKIT",
    -- functions
    "GetCursorPosition",
    "GetCVar",
    "GetCVarBool",
    "GetInventoryItemID",
    "GetItemCount",
    "GetItemIcon",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetLocale",
    "GetNumGroupMembers",
    "GetSpellInfo",
    "GetSpellTexture",
    "GetTime",
    "GetWeaponEnchantInfo",
    "InCombatLockdown",
    "IsInGroup",
    "IsInInstance",
    "IsInRaid",
    "IsPlayerSpell",
    "issecretvalue",
    "IsSpellKnown",
    "MouseIsOver",
    "NUM_BAG_SLOTS",
    "PlaySound",
    "tinsert",
    "UnitBuff",
    "UnitClass",
    "UnitExists",
    "UnitInRange",
    "UnitInVehicle",
    "UnitIsConnected",
    "UnitIsDeadOrGhost",
    "UnitIsUnit",
    "UnitIsVisible",
    "UnitLevel",
    "UnitName",
    "UnitOnTaxi",
    "wipe",
}
