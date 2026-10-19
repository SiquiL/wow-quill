std = "lua51"
max_line_length = false
self = false
exclude_files = { ".git/**" }

globals = {
	"QuillDB",
	"QuillSettingsLinkMixin",
	"Quill_OnAddonCompartmentClick",
	"Quill_OnAddonCompartmentEnter",
	"Quill_OnAddonCompartmentLeave",
	"SLASH_QUILL1",
	"SlashCmdList",
	"StaticPopupDialogs",
}

read_globals = {
	"ColorPickerFrame",
	"MenuUtil",
	"MinimalSliderWithSteppersMixin",
	-- Lua extensions of the game client
	"date",
	"time",

	-- Game API and FrameXML
	"ChatEdit_InsertLink",
	"ChatFrameUtil",
	"CLOSE",
	"CreateFrame",
	"CreateFromMixins",
	"CreateSettingsButtonInitializer",
	"CreateSettingsListSectionHeaderInitializer",
	"C_Timer",
	"FauxScrollFrame_GetOffset",
	"FauxScrollFrame_OnVerticalScroll",
	"FauxScrollFrame_Update",
	"GameTooltip",
	"GetLocale",
	"GetTime",
	"hooksecurefunc",
	"InCombatLockdown",
	"IsControlKeyDown",
	"IsShiftKeyDown",
	"NO",
	"StaticPopup_Show",
	"STANDARD_TEXT_FONT",
	"Settings",
	"SettingsListElementMixin",
	"SetItemRef",
	"UIParent",
	"UISpecialFrames",
	"YES",
	"UnitGUID",
}
