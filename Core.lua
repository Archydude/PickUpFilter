-- PickUp Filter
-- Auto loot that leaves junk behind: each item is picked up or left by its quality, its price
-- and the player's own lists of item IDs.
--
-- Files, in load order (see the .toc):
--   Core.lua      namespace, saved settings, money text, slash command
--   Prices.lua    what an item is worth: vendor, TSM, Auctionator
--   Filter.lua    whether one loot slot is picked up, and why
--   Looter.lua    the loot window: picking up, closing, the game's Auto Loot setting
--   Options.lua   Esc > Options > AddOns > PickUp Filter
--   Minimap.lua   minimap button and addon compartment entry

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.TITLE = "PickUp Filter"
ns.ICON = "Interface\\Icons\\INV_Misc_Bag_10"
ns.PREFIX = "|cff33ff99PickUp Filter:|r "

function ns.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. text)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- Item qualities with a row in the rules table. The last row covers Legendary and everything above
-- it (Artifact, Heirloom, WoW Token).
ns.QUALITIES = {
	{ id = 0, name = "Poor" },
	{ id = 1, name = "Common" },
	{ id = 2, name = "Uncommon" },
	{ id = 3, name = "Rare" },
	{ id = 4, name = "Epic" },
	{ id = 5, name = "Legendary and up" },
}
ns.TOP_QUALITY = 5

-- The rules table's row for an item quality.
function ns.QualityRow(quality)
	quality = math.min(math.max(quality or 1, 0), ns.TOP_QUALITY)
	return ns.db.quality[quality]
end

local SILVER = 100

-- One row of the rules table:
--   action  "always" | "never" | "value" (picked up when worth at least the threshold)
--   price   "vendor" | "priority" | "highest", for "value"
--   single  copper a non-stackable item has to be worth
--   stack   copper the whole drop of a stackable item has to be worth
local function row(action, price)
	return { action = action, price = price, single = SILVER, stack = SILVER }
end

-- The default filter. "Reset to default filter" puts the rules table back to this.
function ns.DefaultQualityRules()
	return {
		[0] = row("value", "vendor"),
		[1] = row("value", "priority"),
		[2] = row("always", "priority"),
		[3] = row("always", "priority"),
		[4] = row("always", "priority"),
		[5] = row("always", "priority"),
	}
end

-- A profile: one whole filter. Characters each use one profile, and several can share one.
ns.DEFAULTS = {
	quality = ns.DefaultQualityRules(),
	priority = { "tsm", "auctionator", "vendor" }, -- price sources tried in order, "none" skips
	tsmSource = "dbmarket",
	quest = "always",        -- "always" | "rules": quest items
	currency = "always",     -- "always" | "never"
	noPrice = "loot",        -- "loot" | "leave": items the price rule finds no price for
	valuableFirst = true,    -- pick up the most valuable items first
	reportLeft = false,      -- chat line listing what was left behind
	afterLoot = "close",     -- "close" | "open": the loot window once what's wanted is picked up
	always = {},             -- [itemID] = true: always picked up
	never = {},              -- [itemID] = true: always left behind
}

-- Each character's own settings.
local CHAR_DEFAULTS = {
	profile = "Default",
	enabled = true,          -- off: everything is picked up, like the game's Auto Loot
}

-- Settings for the whole account.
local GLOBAL_DEFAULTS = {
	profiles = {},           -- [name] = a profile
	chars = {},              -- ["Name-Realm"] = the character's settings
	minimap = { hide = false, minimapPos = 290 },
	autoLootAsked = false,   -- asked once whether to turn off the game's Auto Loot
}

ns.DEFAULT_PROFILE = "Default"

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
ns.Copy = copy

-- Fills in whatever `db` is missing from `defaults`, one level of tables deep for the rules rows.
local function fill(db, defaults)
	for key, value in pairs(defaults) do
		if db[key] == nil then
			db[key] = copy(value)
		elseif type(value) == "table" and type(db[key]) == "table" and next(value) ~= nil
			and key ~= "priority" then
			fill(db[key], value)
		end
	end
end

-- Fills in a profile and drops what it no longer has.
function ns.CleanProfile(profile)
	fill(profile, ns.DEFAULTS)
	for key in pairs(profile) do
		if ns.DEFAULTS[key] == nil then profile[key] = nil end
	end
	if type(profile.priority) ~= "table" or #profile.priority ~= 3 then profile.priority = copy(ns.DEFAULTS.priority) end
	return profile
end

function ns.NewProfileSettings()
	return copy(ns.DEFAULTS)
end

local function load()
	-- This character, as "Name-Realm".
	ns.CHAR_KEY = UnitName("player") .. "-" .. GetRealmName()
	local saved = type(PickUpFilterDB) == "table" and PickUpFilterDB or {}
	PickUpFilterDB = saved
	-- Settings from before profiles become the Default profile.
	if saved.profiles == nil and saved.quality ~= nil then
		local old = {}
		for key in pairs(ns.DEFAULTS) do old[key], saved[key] = saved[key], nil end
		saved.profiles = { [ns.DEFAULT_PROFILE] = old }
		saved.chars = { [ns.CHAR_KEY] = { enabled = saved.enabled ~= false } }
	end
	fill(saved, GLOBAL_DEFAULTS)
	for key in pairs(saved) do
		if GLOBAL_DEFAULTS[key] == nil then saved[key] = nil end
	end
	for _, profile in pairs(saved.profiles) do ns.CleanProfile(profile) end
	if not next(saved.profiles) then saved.profiles[ns.DEFAULT_PROFILE] = ns.NewProfileSettings() end

	saved.chars[ns.CHAR_KEY] = saved.chars[ns.CHAR_KEY] or {}
	local char = saved.chars[ns.CHAR_KEY]
	fill(char, CHAR_DEFAULTS)
	ns.global, ns.char = saved, char
	if not saved.profiles[char.profile] then char.profile = ns.FallbackProfile() end
	ns.db = saved.profiles[char.profile]
end

---------------------------------------------------------------------------
-- Money text
---------------------------------------------------------------------------

-- Copper as coin icons, for chat and tooltips.
function ns.Money(copper)
	copper = math.floor((copper or 0) + 0.5)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	return GetMoneyString(copper)
end

-- Copper as "1g 20s 5c", the way the threshold boxes show and read it.
function ns.MoneyText(copper)
	copper = math.max(0, math.floor((copper or 0) + 0.5))
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if gold > 0 then parts[#parts + 1] = gold .. "g" end
	if silver > 0 then parts[#parts + 1] = silver .. "s" end
	if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
	return table.concat(parts, " ")
end

local COIN = { g = 10000, s = 100, c = 1 }

-- Reads "1g 20s 5c", "50s", "1.5g" or a bare number (copper) back into copper; nil when it isn't money.
function ns.ParseMoney(text)
	text = strtrim((text or ""):lower())
	if text == "" then return end
	if text:match("^%d+$") then return tonumber(text) end
	local total, rest = 0, text:gsub("%s+", "")
	while rest ~= "" do
		local amount, coin, after = rest:match("^(%d+%.?%d*)([gsc])(.*)$")
		if not amount then return end
		total = total + tonumber(amount) * COIN[coin]
		rest = after
	end
	return math.floor(total + 0.5)
end

---------------------------------------------------------------------------
-- Item IDs from what the player types
---------------------------------------------------------------------------

-- The item ID in a typed ID or an item link, or nil.
function ns.ItemIDFrom(text)
	text = text or ""
	local fromLink = text:match("|Hitem:(%d+)")
	if fromLink then return tonumber(fromLink) end
	local id = strtrim(text):match("^(%d+)$")
	return id and tonumber(id)
end

-- "[Linen Cloth]" as a link when the game knows the item, or "item 2589" until it does.
function ns.ItemLabel(itemID)
	local name, link = C_Item.GetItemInfo(itemID)
	return link or name or ("item " .. itemID)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	for _, handler in ipairs(handlers[event]) do handler(...) end
end)

-- Runs `handler(...)` on every `event`.
function ns.On(event, handler)
	if not handlers[event] then
		handlers[event] = {}
		events:RegisterEvent(event)
	end
	table.insert(handlers[event], handler)
end

local listeners = {}

-- Runs `handler(...)` whenever the addon calls ns.Fire(name, ...).
function ns.Listen(name, handler)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], handler)
end

function ns.Fire(name, ...)
	for _, handler in ipairs(listeners[name] or {}) do handler(...) end
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON_NAME then return end
	load()
	ns.Fire("Loaded")
end)

---------------------------------------------------------------------------
-- Item lists
---------------------------------------------------------------------------

-- Puts an item on the "always" or "never" list (taking it off the other one), or on neither
-- when `list` is nil.
function ns.SetListed(itemID, list)
	ns.db.always[itemID] = (list == "always") or nil
	ns.db.never[itemID] = (list == "never") or nil
	ns.Fire("ListsChanged")
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function help()
	ns.Print("commands:")
	print("  /puf - options")
	print("  /puf on | off - filter loot, or pick up everything")
	print("  /puf always <item> - always pick up this item (item ID or Shift-clicked link)")
	print("  /puf never <item> - never pick up this item")
	print("  /puf remove <item> - take an item off both lists")
	print("  /puf list - show both lists")
	print("  /puf check [count] <item> - what the filter would do with it, and why")
	print("  /puf profile - show the profiles, and which one this character uses")
	print("  /puf profile <name> - switch this character to that profile")
	print("  /puf minimap - show or hide the minimap button")
end

local function profileCommand(rest)
	if rest == "" then
		ns.Print("this character uses the profile " .. ns.char.profile .. ". Profiles: "
			.. table.concat(ns.ProfileNames(), ", ") .. ".")
		return
	end
	for _, name in ipairs(ns.ProfileNames()) do
		if name:lower() == rest:lower() then
			ns.UseProfile(name)
			ns.Print("this character uses the profile " .. name .. " now.")
			return
		end
	end
	ns.Print("there's no profile called " .. rest .. ". Make one in /puf.")
end

local function printList(title, list)
	local ids = {}
	for id in pairs(list) do ids[#ids + 1] = id end
	table.sort(ids)
	if #ids == 0 then
		ns.Print(title .. ": none")
		return
	end
	ns.Print(title .. ":")
	for _, id in ipairs(ids) do print("  " .. ns.ItemLabel(id) .. " (" .. id .. ")") end
end

local function listCommand(command, rest)
	local id = ns.ItemIDFrom(rest)
	if not id then
		ns.Print("put an item ID or a Shift-clicked item link after /puf " .. command .. ".")
		return
	end
	if command == "remove" then
		if not (ns.db.always[id] or ns.db.never[id]) then
			ns.Print(ns.ItemLabel(id) .. " isn't on either list.")
			return
		end
		ns.SetListed(id, nil)
		ns.Print(ns.ItemLabel(id) .. " is off the lists; its quality rule decides again.")
	else
		ns.SetListed(id, command)
		ns.Print(ns.ItemLabel(id) .. (command == "always" and " is always picked up." or " is never picked up."))
	end
end

SLASH_PICKUPFILTER1 = "/puf"
SLASH_PICKUPFILTER2 = "/pickupfilter"
SlashCmdList.PICKUPFILTER = function(msg)
	msg = strtrim(msg or "")
	local command, rest = msg:match("^(%S*)%s*(.-)$")
	command = command:lower()
	if command == "" or command == "options" or command == "config" then
		ns.OpenOptions()
	elseif command == "on" or command == "off" then
		ns.SetEnabled(command == "on")
	elseif command == "always" or command == "never" or command == "remove" then
		listCommand(command, rest)
	elseif command == "list" then
		printList("Always picked up", ns.db.always)
		printList("Never picked up", ns.db.never)
	elseif command == "check" then
		ns.CheckCommand(rest)
	elseif command == "profile" or command == "profiles" then
		profileCommand(rest)
	elseif command == "minimap" then
		ns.SetMinimapShown(ns.global.minimap.hide)
		ns.Print(ns.global.minimap.hide and "minimap button hidden." or "minimap button shown.")
	else
		help()
	end
end

-- Turns the filter on or off, from the slash command, the options or the minimap button.
function ns.SetEnabled(on)
	ns.char.enabled = on
	ns.Fire("SettingChanged", "enabled")
	ns.Print(on and "filtering loot." or "off: picking up everything.")
end
