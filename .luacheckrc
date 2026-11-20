-- luacheck configuration for Pardona's Buff Reminder (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = false
-- WoW callbacks receive parameters (self, event, button, ...) that are often unused
unused_args = false
exclude_files = { ".release", "Libs" }

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
    "C_EventUtils",
    "C_AddOns",
    "C_CVar",
    "C_Item",
    "C_Spell",
    "C_Texture",
    "C_SpellBook",
    "C_Timer",
    "C_TooltipInfo",
    "C_UnitAuras",
    -- frames and UI objects
    "CreateColor",
    "CreateFrame",
    "Enum",
    "GameTooltip",
    "LibStub",
    "UIParent",
    "SOUNDKIT",
    -- functions
    "GetAddOnMetadata",
    "GetCursorPosition",
    "GetCVar",
    "GetCVarBool",
    "GetInventoryItemID",
    "GetItemCount",
    "GetItemIcon",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetLocale",
    "GetMaxLevelForPlayerExpansion",
    "GetMaxPlayerLevel",
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
    "IsXPUserDisabled",
    "MAX_PLAYER_LEVEL",
    "issecretvalue",
    "IsSpellKnown",
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
    "time",
    "UnitOnTaxi",
    "wipe",
}
