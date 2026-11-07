-- PickUp Filter: profiles
-- A profile is one whole filter: the rules table, prices, other rules and both item lists. Each
-- character uses one, and characters can share one. New characters start on "Default".

local _, ns = ...

local MAX_NAME = 32

-- Profile names, sorted.
function ns.ProfileNames()
	local names = {}
	for name in pairs(ns.global.profiles) do names[#names + 1] = name end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

-- The profile a character goes to when theirs is gone: Default, or the first other one.
-- `leaving` is the profile being deleted, if any.
function ns.FallbackProfile(leaving)
	if leaving ~= ns.DEFAULT_PROFILE and ns.global.profiles[ns.DEFAULT_PROFILE] then return ns.DEFAULT_PROFILE end
	for _, name in ipairs(ns.ProfileNames()) do
		if name ~= leaving then return name end
	end
end

-- Characters using profile `name`, as "Name-Realm", sorted.
function ns.ProfileUsers(name)
	local users = {}
	for key, char in pairs(ns.global.chars) do
		if char.profile == name then users[#users + 1] = key end
	end
	table.sort(users)
	return users
end

-- Why `name` can't be a new profile name, or nil when it can.
function ns.ProfileNameProblem(name)
	if name == "" then return "type a name for the profile." end
	if #name > MAX_NAME then return "profile names can be up to " .. MAX_NAME .. " letters." end
	if ns.global.profiles[name] then return "there's already a profile called " .. name .. "." end
end

-- Switches this character to profile `name`.
function ns.UseProfile(name)
	if not ns.global.profiles[name] then return false end
	ns.char.profile = name
	ns.db = ns.global.profiles[name]
	ns.Fire("ProfileChanged")
	return true
end

-- Makes profile `name`, with the default filter or a copy of profile `from`, and switches to it.
-- Returns why it couldn't, or nil.
function ns.NewProfile(name, from)
	name = strtrim(name or "")
	local problem = ns.ProfileNameProblem(name)
	if problem then return problem end
	local source = from and ns.global.profiles[from]
	ns.global.profiles[name] = source and ns.CleanProfile(ns.Copy(source)) or ns.NewProfileSettings()
	ns.UseProfile(name)
end

-- Renames profile `old` for every character using it. Returns why it couldn't, or nil.
function ns.RenameProfile(old, name)
	name = strtrim(name or "")
	if name == old then return end
	local problem = ns.ProfileNameProblem(name)
	if problem then return problem end
	local profiles = ns.global.profiles
	profiles[name], profiles[old] = profiles[old], nil
	for _, char in pairs(ns.global.chars) do
		if char.profile == old then char.profile = name end
	end
	ns.Fire("ProfileChanged")
end

-- Deletes profile `name`; characters using it go to the fallback profile. The last profile can't go.
-- Returns why it couldn't, or nil.
function ns.DeleteProfile(name)
	local profiles = ns.global.profiles
	if not profiles[name] then return "there's no profile called " .. name .. "." end
	if #ns.ProfileNames() == 1 then return "that's your only profile, so it stays." end
	local fallback = ns.FallbackProfile(name)
	profiles[name] = nil
	for _, char in pairs(ns.global.chars) do
		if char.profile == name then char.profile = fallback end
	end
	ns.db = profiles[ns.char.profile]
	ns.Fire("ProfileChanged")
end

---------------------------------------------------------------------------
-- Dialogs that ask for a name, and for a yes before deleting
---------------------------------------------------------------------------

local function dialogBox(dialog)
	return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

-- What a name dialog does with the typed name. `data` is the profile it's about.
local ACTIONS = {
	new = function(name) return ns.NewProfile(name) end,
	copy = function(name, from) return ns.NewProfile(name, from) end,
	rename = function(name, old) return ns.RenameProfile(old, name) end,
}

local function finish(dialog, data)
	local box = dialogBox(dialog)
	local problem = ACTIONS[data.action](box and box:GetText() or "", data.profile)
	if problem then ns.Print(problem) end
end

StaticPopupDialogs.PICKUPFILTER_PROFILE_NAME = {
	text = "%s",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = MAX_NAME,
	OnShow = function(self, data)
		local box = dialogBox(self)
		if box then
			box:SetText(data and data.start or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
	OnAccept = function(self, data) finish(self, data) end,
	EditBoxOnEnterPressed = function(box, data)
		local dialog = box:GetParent()
		finish(dialog, data or dialog.data)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs.PICKUPFILTER_PROFILE_DELETE = {
	text = "Delete the profile %s? Characters using it go to %s.",
	button1 = DELETE,
	button2 = CANCEL,
	OnAccept = function(_, name)
		local problem = ns.DeleteProfile(name)
		if problem then ns.Print(problem) end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
}

-- Asks for a name, then makes a new profile ("new"), copies `profile` ("copy") or renames it ("rename").
function ns.AskProfileName(action, profile)
	local prompts = {
		new = "Name for the new profile (starts with the default filter):",
		copy = "Name for the copy of " .. (profile or "") .. ":",
		rename = "New name for " .. (profile or "") .. ":",
	}
	local start = action == "rename" and profile or (action == "copy" and profile and profile .. " copy") or ""
	StaticPopup_Show("PICKUPFILTER_PROFILE_NAME", prompts[action], nil,
		{ action = action, profile = profile, start = start })
end

function ns.AskDeleteProfile(name)
	if #ns.ProfileNames() == 1 then
		ns.Print("that's your only profile, so it stays.")
		return
	end
	StaticPopup_Show("PICKUPFILTER_PROFILE_DELETE", name, ns.FallbackProfile(name), name)
end
