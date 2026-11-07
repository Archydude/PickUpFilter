-- PickUp Filter: minimap button (LibDBIcon, so minimap button collectors pick it up) and addon
-- compartment entry. Click for options, right-click to turn the filter on or off.

local _, ns = ...

local NAME = "PickUpFilter" -- the button's name with LibDBIcon
local LDBIcon = LibStub("LibDBIcon-1.0")
local registered = false

local function fillTooltip(tooltip)
	tooltip:SetText(ns.TITLE)
	if ns.GameAutoLootOn() then
		tooltip:AddLine("The game's Auto Loot is on, so nothing is filtered.", 1, 0.38, 0.38, true)
	elseif ns.char.enabled then
		tooltip:AddLine("Filtering loot", 0.25, 1, 0.25)
	else
		tooltip:AddLine("Off: picking up everything", 1, 0.82, 0)
	end
	tooltip:AddDoubleLine("Profile", ns.char.profile, 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	tooltip:AddLine("Click for options, right-click to turn the filter on or off", 0.6, 0.6, 0.6)
end

local function onClick(mouseButton)
	if mouseButton == "RightButton" then
		ns.SetEnabled(not ns.char.enabled)
	else
		ns.OpenOptions()
	end
end

-- Shows or hides the minimap button, from the options or /puf minimap.
function ns.SetMinimapShown(shown)
	ns.global.minimap.hide = not shown
	if registered then
		if shown then LDBIcon:Show(NAME) else LDBIcon:Hide(NAME) end
	end
	ns.Fire("SettingChanged", "minimap")
end

ns.On("PLAYER_LOGIN", function()
	local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, {
		type = "launcher",
		label = ns.TITLE,
		icon = ns.ICON,
		OnClick = function(_, mouseButton) onClick(mouseButton) end,
		OnTooltipShow = fillTooltip,
	})
	LDBIcon:Register(NAME, launcher, ns.global.minimap)
	registered = true
end)

-- Addon compartment (the addon menu on the minimap), named in the .toc.
function PickUpFilter_OnAddonCompartmentClick(_, mouseButton)
	onClick(mouseButton)
end

function PickUpFilter_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	fillTooltip(GameTooltip)
	GameTooltip:Show()
end

function PickUpFilter_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
