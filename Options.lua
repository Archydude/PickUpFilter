-- PickUp Filter: options
-- Esc > Options > AddOns > PickUp Filter, or /puf. One page: the game's Auto Loot, the rules
-- table (one row per item quality), prices, the other rules and the two item lists.

local _, ns = ...

local WIDTH = 620          -- the page's content
local ROW_HEIGHT = 30      -- rules table rows
local LIST_ROW_HEIGHT = 22 -- item list rows

local category
local content
local refreshers = {} -- functions that bring one control up to date with the settings

local function refreshAll()
	for _, refresh in ipairs(refreshers) do refresh() end
end

-- The game doesn't let addons open its settings during combat, so a request then waits for the fight to end.
local openAfterCombat = false

function ns.OpenOptions()
	if not category then return end
	if InCombatLockdown() then
		if not openAfterCombat then
			openAfterCombat = true
			ns.Print("the options open when you leave combat.")
		end
		return
	end
	Settings.OpenToCategory(category:GetID())
end

ns.On("PLAYER_REGEN_ENABLED", function()
	if openAfterCombat then
		openAfterCombat = false
		ns.OpenOptions()
	end
end)

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local function tooltip(frame, title, text)
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function text(parent, font, value, width)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	if value then fs:SetText(value) end
	return fs
end

local function heading(value, y)
	local fs = text(content, "GameFontNormalLarge", value)
	fs:SetPoint("TOPLEFT", 16, y)
	return fs
end

local function checkbox(label, help, get, set)
	local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	local fs = text(check, "GameFontHighlight", label)
	fs:SetPoint("LEFT", check, "RIGHT", 4, 1)
	check:SetHitRectInsets(0, -fs:GetStringWidth() - 8, 0, 0)
	check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	tooltip(check, label, help)
	table.insert(refreshers, function() check:SetChecked(get()) end)
	return check
end

-- `choices` is a list of { value, text }, or a function returning one.
local function dropdown(parent, width, choices, get, set)
	local menu = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	menu:SetWidth(width)
	if menu.Text then menu.Text:SetFontObject("GameFontHighlight") end
	menu:SetupMenu(function(_, root)
		for _, choice in ipairs(type(choices) == "function" and choices() or choices) do
			root:CreateRadio(choice[2], function() return get() == choice[1] end, function()
				set(choice[1])
				refreshAll()
			end)
		end
	end)
	table.insert(refreshers, function() menu:GenerateMenu() end)
	return menu
end

local function button(parent, label, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetText(label)
	b:SetSize(width, 24)
	b:SetScript("OnClick", onClick)
	return b
end

-- A box that shows and takes an amount like "1g 20s 5c". `default()` is the amount an emptied box goes back to.
local function moneyBox(parent, get, set, default)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(86, 20)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlight")
	-- Text set before the box is laid out can sit scrolled out of view, so the cursor goes back to
	-- the start, and the box fills itself again the first time it's drawn.
	local function show()
		box:SetText(ns.MoneyText(get()))
		box:SetCursorPosition(0)
	end
	box:HookScript("OnShow", function(self)
		if not self:HasFocus() then show() end
	end)
	-- An emptied box goes back to the default filter's amount.
	local function apply()
		local typed = strtrim(box:GetText())
		local copper = typed == "" and default() or ns.ParseMoney(typed)
		if copper then set(copper) end
		show()
	end
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		show()
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", apply)
	tooltip(box, "Amount", "Type it like 1g 20s 5c, 50s or 25c, then press Enter. Clear the box to go back to the default ("
		.. ns.MoneyText(default()) .. ").")
	table.insert(refreshers, function()
		if not box:HasFocus() then show() end
	end)
	return box
end

---------------------------------------------------------------------------
-- The game's Auto Loot
---------------------------------------------------------------------------

local function buildStatus(y)
	local status = text(content, "GameFontHighlight", nil, WIDTH - 200)
	status:SetPoint("TOPLEFT", 20, y)
	local turnOff = button(content, "Turn off game Auto Loot", 180, function() ns.TurnOffGameAutoLoot() end)
	turnOff:SetPoint("TOPRIGHT", content, "TOPLEFT", WIDTH, y + 4)
	tooltip(turnOff, "Turn off the game's Auto Loot",
		"The game's own Auto Loot picks up everything before PickUp Filter can look at it. "
			.. "With it off, loot as usual: PickUp Filter picks up what passes your rules. Hold Shift while looting to take everything.")
	table.insert(refreshers, function()
		if ns.GameAutoLootOn() then
			status:SetText("|cffff6060The game's Auto Loot is on, so it picks up everything and nothing is filtered.|r")
			turnOff:Show()
		else
			status:SetText("|cff40ff40Ready.|r Loot as usual and only what passes your rules is picked up. Hold Shift while looting to take everything.")
			turnOff:Hide()
		end
	end)
	return y - 40
end

---------------------------------------------------------------------------
-- Rules by quality
---------------------------------------------------------------------------

local ACTIONS = {
	{ "value", "Check value" },
	{ "always", "Always pick up" },
	{ "never", "Never pick up" },
}

local PRICE_RULES = {
	{ "vendor", "Vendor price" },
	{ "priority", "Priority order" },
	{ "highest", "Highest price" },
}

local COLUMNS = { quality = 20, action = 140, price = 280, single = 425, stack = 525 }

local function qualityText(quality)
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	local name = ns.QUALITIES[quality + 1].name
	return color and (color.hex .. name .. "|r") or name
end

local function buildRulesTable(y)
	heading("Rules by quality", y)
	y = y - 28
	local headers = {
		{ "quality", "Quality" }, { "action", "Action" }, { "price", "Price" },
		{ "single", "Single item" }, { "stack", "Whole stack" },
	}
	for _, h in ipairs(headers) do
		local fs = text(content, "GameFontNormal", h[2])
		fs:SetPoint("TOPLEFT", COLUMNS[h[1]], y)
	end
	y = y - 20

	for _, q in ipairs(ns.QUALITIES) do
		local quality = q.id
		local function rule() return ns.db.quality[quality] end
		local name = text(content, "GameFontHighlight", qualityText(quality), 125)
		name:SetPoint("TOPLEFT", COLUMNS.quality, y - 6)

		local action = dropdown(content, 130, ACTIONS, function() return rule().action end,
			function(v) rule().action = v end)
		action:SetPoint("TOPLEFT", COLUMNS.action, y)

		local price = dropdown(content, 130, PRICE_RULES, function() return rule().price end,
			function(v) rule().price = v end)
		price:SetPoint("TOPLEFT", COLUMNS.price, y)

		local defaults = ns.DefaultQualityRules()[quality]
		local single = moneyBox(content, function() return rule().single end, function(v) rule().single = v end,
			function() return defaults.single end)
		single:SetPoint("TOPLEFT", COLUMNS.single + 6, y - 2)
		local stack = moneyBox(content, function() return rule().stack end, function(v) rule().stack = v end,
			function() return defaults.stack end)
		stack:SetPoint("TOPLEFT", COLUMNS.stack + 6, y - 2)

		table.insert(refreshers, function()
			local checks = rule().action == "value"
			price:SetEnabled(checks)
			for _, box in ipairs({ single, stack }) do
				box:SetEnabled(checks)
				box:SetTextColor(checks and 1 or 0.5, checks and 1 or 0.5, checks and 1 or 0.5)
			end
		end)
		y = y - ROW_HEIGHT
	end

	local reset = button(content, "Reset to default filter", 180, function()
		ns.db.quality = ns.DefaultQualityRules()
		refreshAll()
		ns.Print("rules table set back to the default filter.")
	end)
	reset:SetPoint("TOPLEFT", COLUMNS.quality, y - 4)
	tooltip(reset, "Reset to default filter",
		"Poor items: picked up when the vendor pays at least 1s, or 5s for a full stack. Common items: the same amounts, by the priority order. Uncommon and better: always picked up. "
			.. "Your item lists and the other rules stay as they are.")
	y = y - 36

	local help = text(content, "GameFontHighlight",
		"|cffffd100Check value|r picks up an item when it's worth at least the amount. |cffffd100Single item|r is for items that don't stack. "
			.. "|cffffd100Whole stack|r is for items that stack, valued as a full stack however many dropped: one cloth worth 30c in stacks of 20 is worth 6s.",
		WIDTH - 30)
	help:SetPoint("TOPLEFT", COLUMNS.quality, y)
	return y - help:GetStringHeight() - 24
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------

local function priorityChoices()
	local list = {}
	for _, source in ipairs(ns.SOURCES) do list[#list + 1] = { source.key, source.name } end
	list[#list + 1] = { "none", "Nothing" }
	return list
end

-- Puts `key` at `index` of the priority order. A source already at another place swaps with
-- what was here, so each one is listed once.
local function setPriority(index, key)
	local order = ns.db.priority
	if key ~= "none" then
		for i = 1, #order do
			if i ~= index and order[i] == key then order[i] = order[index] end
		end
	end
	order[index] = key
end

local function addonState(name, loaded)
	return name .. (loaded and ": |cff40ff40loaded|r" or ": |cff808080not loaded|r")
end

local function buildPrices(y)
	heading("Prices", y)
	y = y - 30
	local label = text(content, "GameFontHighlight", "Priority order")
	label:SetPoint("TOPLEFT", COLUMNS.quality, y - 6)
	local x = COLUMNS.action
	for index = 1, 3 do
		local menu = dropdown(content, 130, priorityChoices, function() return ns.db.priority[index] end,
			function(v) setPriority(index, v) end)
		menu:SetPoint("TOPLEFT", x, y)
		if index < 3 then
			local arrow = text(content, "GameFontHighlight", "then")
			arrow:SetPoint("LEFT", menu, "RIGHT", 6, 0)
		end
		x = x + 170
	end
	y = y - 34

	local tsmLabel = text(content, "GameFontHighlight", "TSM price")
	tsmLabel:SetPoint("TOPLEFT", COLUMNS.quality, y - 6)
	local tsmChoices = {}
	for _, source in ipairs(ns.TSM_SOURCES) do tsmChoices[#tsmChoices + 1] = { source.key, source.name } end
	local tsm = dropdown(content, 220, tsmChoices, function() return ns.db.tsmSource end,
		function(v) ns.db.tsmSource = v end)
	tsm:SetPoint("TOPLEFT", COLUMNS.action, y)
	local loaded = text(content, "GameFontHighlight")
	loaded:SetPoint("LEFT", tsm, "RIGHT", 16, 0)
	table.insert(refreshers, function()
		loaded:SetText(addonState("TSM", ns.TSMLoaded()) .. "    " .. addonState("Auctionator", ns.AuctionatorLoaded()))
	end)
	y = y - 36

	local help = text(content, "GameFontHighlight",
		"|cffffd100Priority order|r uses the first of these with a price for the item. |cffffd100Highest price|r uses the highest of all three. "
			.. "|cffffd100Vendor price|r is what a vendor pays. TSM and Auctionator count only while they're loaded.",
		WIDTH - 30)
	help:SetPoint("TOPLEFT", COLUMNS.quality, y)
	return y - help:GetStringHeight() - 24
end

---------------------------------------------------------------------------
-- Other rules
---------------------------------------------------------------------------

local function choiceRow(y, label, help, choices, key)
	local fs = text(content, "GameFontHighlight", label)
	fs:SetPoint("TOPLEFT", COLUMNS.quality, y - 6)
	local menu = dropdown(content, 200, choices, function() return ns.db[key] end, function(v) ns.db[key] = v end)
	menu:SetPoint("TOPLEFT", COLUMNS.price - 100, y)
	tooltip(menu, label, help)
	return y - 32
end

local function buildOtherRules(y)
	heading("Other rules", y)
	y = y - 30
	y = choiceRow(y, "Quest items",
		"Always pick up quest items, or treat them like any other item of their quality.",
		{ { "always", "Always pick up" }, { "rules", "Follow the quality rules" } }, "quest")
	y = choiceRow(y, "Currencies", "Currencies that drop, like badges and tokens.",
		{ { "always", "Always pick up" }, { "never", "Leave behind" } }, "currency")
	y = choiceRow(y, "Items with no price",
		"Items under Check value that no price source has a price for. Picking them up means nothing rare goes missing just because nobody has sold one yet.",
		{ { "loot", "Pick up" }, { "leave", "Leave behind" } }, "noPrice")
	y = choiceRow(y, "Loot window afterwards",
		"Once what you want is picked up: close the loot window so the rest stays on the corpse, or leave it open so you can still take something yourself.",
		{ { "close", "Close it" }, { "open", "Leave it open" } }, "afterLoot")
	local money = text(content, "GameFontHighlight", "Money is always picked up.")
	money:SetPoint("TOPLEFT", COLUMNS.quality, y - 4)
	y = y - 26

	local gather = checkbox("Take everything when gathering",
		"Herbs, ore, fishing and skinning are picked up whole, without the rules. So are chests, lockboxes and other things you open.",
		function() return ns.db.gathering end, function(v) ns.db.gathering = v end)
	gather:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local looks = checkbox("Always pick up appearances you haven't collected",
		"Gear with an appearance missing from your collection is picked up whatever its quality or price.",
		function() return ns.db.appearances end, function(v) ns.db.appearances = v end)
	looks:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local reagents = checkbox("Always pick up crafting reagents",
		"Anything a profession can craft with is picked up whatever its quality or price, like cloth, herbs and leather.",
		function() return ns.db.reagents end, function(v) ns.db.reagents = v end)
	reagents:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local att = checkbox("Always pick up what All The Things says you need",
		"Items All The Things counts as missing from your collection, or needed for something you haven't collected yet, are picked up whatever their quality or price. Follows your All The Things settings. Needs All The Things.",
		function() return ns.db.att end, function(v) ns.db.att = v end)
	att:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local first = checkbox("Most valuable first",
		"Picks up the most valuable items first, so when your bags fill up, what's left behind is the cheap stuff.",
		function() return ns.db.valuableFirst end, function(v) ns.db.valuableFirst = v end)
	first:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local report = checkbox("Say what was left behind",
		"After looting, a chat line lists what was left behind and what it was worth.",
		function() return ns.db.reportLeft end, function(v) ns.db.reportLeft = v end)
	report:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	y = y - 28
	local minimap = checkbox("Show minimap button", "Same as /puf minimap.",
		function() return not ns.global.minimap.hide end, function(v) ns.SetMinimapShown(v) end)
	minimap:SetPoint("TOPLEFT", COLUMNS.quality - 4, y)
	return y - 44
end

---------------------------------------------------------------------------
-- Item lists
---------------------------------------------------------------------------

local listBoxes = {} -- the two add boxes, for Shift-clicked links

---------------------------------------------------------------------------
-- Item search: items whose names match what's typed in a list box, from your bags first, then from
-- the whole game
---------------------------------------------------------------------------

local VISIBLE_MATCHES = 8 -- rows shown at once; the mouse wheel and Up/Down scroll through the rest
local MAX_MATCHES = 200   -- matches kept for scrolling
local MATCH_HEIGHT = 22

-- The item name in a link, without the brackets and any icon inside them.
local function nameFromLink(link)
	local name = link and link:match("|h%[(.-)%]|h")
	return name and name:gsub("|A.-|a", ""):gsub("^%s+", "")
end

-- Items in your bags whose names contain `typed` (any case), names that start with it first, each
-- item once, without the ones in `skip` ([itemID] = true).
local function searchBags(typed, skip)
	typed = typed:lower()
	local found, seen = {}, {}
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, lastBag do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id and not seen[id] and not skip[id] then
				seen[id] = true
				local name = nameFromLink(info.hyperlink) or C_Item.GetItemInfo(id)
				local at = name and name:lower():find(typed, 1, true)
				if at then
					found[#found + 1] = { itemID = id, name = name, icon = info.iconFileID, quality = info.quality,
						starts = at == 1 }
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.starts ~= b.starts then return a.starts end
		return a.name < b.name
	end)
	return found
end

-- Every item in the game (Data\Items.lua), read into lists the first time it's searched.
local allItems

local function loadAllItems()
	if allItems then return allItems end
	allItems = { ids = {}, qualities = {}, names = {}, lower = {}, index = {} }
	local count = 0
	for id, quality, name in (ns.ITEM_NAMES or ""):gmatch("(%d+)\t(%d+)\t([^\n]+)\n") do
		count = count + 1
		allItems.ids[count] = tonumber(id)
		allItems.qualities[count] = tonumber(quality)
		allItems.names[count] = name
		allItems.lower[count] = name:lower()
		allItems.index[tonumber(id)] = count
	end
	ns.ITEM_NAMES = nil -- the lists hold it now
	return allItems
end

-- How many letters to type before the whole game is searched, not just your bags.
local MIN_ALL_ITEMS = 2

-- Items anywhere in the game whose names contain `typed`, names that start with it first, up to `limit`,
-- without the ones in `skip` or `seen` ([itemID] = true).
local function searchAllItems(typed, skip, seen, limit)
	local items = loadAllItems()
	typed = typed:lower()
	local found = {}
	for index = 1, #items.ids do
		local id = items.ids[index]
		local at = not skip[id] and not seen[id] and items.lower[index]:find(typed, 1, true)
		if at then found[#found + 1] = { index = index, starts = at == 1 } end
	end
	table.sort(found, function(a, b)
		if a.starts ~= b.starts then return a.starts end
		return items.names[a.index] < items.names[b.index]
	end)
	local matches = {}
	for n = 1, math.min(limit, #found) do
		local index = found[n].index
		local id = items.ids[index]
		-- Icon and the game's own name are looked up once the row is drawn (see drawSearch).
		matches[n] = { itemID = id, name = items.names[index], quality = items.qualities[index], fromGame = true }
	end
	return matches
end

-- One list of matches, shared by both boxes, drawn over the options window (the page's own scroll
-- area would cut it off).
--   matches   every match, bags first; offset is how many are scrolled past; selected is a match index
local search = { rows = {}, matches = {}, selected = 1, offset = 0 }
local drawSearch

-- Scrolls so the first shown match is `offset` (kept in range), then redraws.
local function scrollTo(offset)
	search.offset = math.max(0, math.min(offset, #search.matches - VISIBLE_MATCHES))
	drawSearch()
end

local function searchFrame()
	if search.frame then return search.frame end
	local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta) scrollTo(search.offset - delta) end)
	-- A bar on the right showing where in the list you are, when there's more than fits.
	f.track = f:CreateTexture(nil, "ARTWORK")
	f.track:SetColorTexture(1, 1, 1, 0.08)
	f.track:SetWidth(4)
	f.track:SetPoint("TOPRIGHT", -6, -6)
	f.thumb = f:CreateTexture(nil, "OVERLAY")
	f.thumb:SetColorTexture(1, 0.82, 0, 0.7)
	f.thumb:SetWidth(4)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	f:Hide()
	search.frame = f
	return f
end

local function hideSearch()
	if search.frame then search.frame:Hide() end
	search.box, search.matches = nil, {}
end

local function pick(match)
	local box = search.box
	ns.SetListed(match.itemID, box.listKey)
	box:SetText("")
	hideSearch()
	box:ClearFocus()
end

local function matchRow(index)
	if search.rows[index] then return search.rows[index] end
	local f = searchFrame()
	local r = CreateFrame("Button", nil, f)
	r:SetSize(260, MATCH_HEIGHT)
	r:SetPoint("TOPLEFT", 6, -6 - (index - 1) * MATCH_HEIGHT)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r.selected = r:CreateTexture(nil, "BACKGROUND")
	r.selected:SetAllPoints()
	r.selected:SetColorTexture(1, 1, 1, 0.12)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", 2, 0)
	r.name = text(r, "GameFontHighlight", nil, 230)
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetWordWrap(false)
	r:SetScript("OnClick", function(self) pick(search.matches[self.index]) end)
	r:SetScript("OnMouseWheel", function(_, delta) scrollTo(search.offset - delta) end)
	r:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(search.matches[self.index].itemID)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	search.rows[index] = r
	return r
end

function drawSearch()
	local f = searchFrame()
	local shown = math.min(VISIBLE_MATCHES, #search.matches)
	for row = 1, shown do
		local index = search.offset + row
		local match = search.matches[index]
		if match.fromGame then
			-- The game's own name when it has the item already, so it's in the player's language.
			match.name = C_Item.GetItemNameByID(match.itemID) or match.name
			match.icon = C_Item.GetItemIconByID(match.itemID)
			match.fromGame = nil
		end
		local r = matchRow(row)
		r.index = index
		r.icon:SetTexture(match.icon)
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[match.quality]
		r.name:SetText((color and color.hex or "") .. match.name .. "|r")
		r.selected:SetShown(index == search.selected)
		r:Show()
	end
	for row = shown + 1, #search.rows do search.rows[row]:Hide() end
	local listHeight = shown * MATCH_HEIGHT
	local more = #search.matches > VISIBLE_MATCHES
	f.track:SetShown(more)
	f.thumb:SetShown(more)
	if more then
		f.track:SetHeight(listHeight)
		local thumbHeight = math.max(12, listHeight * VISIBLE_MATCHES / #search.matches)
		local room = listHeight - thumbHeight
		f.thumb:SetHeight(thumbHeight)
		f.thumb:ClearAllPoints()
		f.thumb:SetPoint("TOPRIGHT", -6, -6 - room * search.offset / (#search.matches - VISIBLE_MATCHES))
	end
	f:SetSize(more and 280 or 272, 12 + listHeight)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", search.box, "BOTTOMLEFT", -6, -2)
	f:Show()
end

-- Brings the matches up to date with what's typed in `box`. IDs and links don't search.
local function updateSearch(box)
	local typed = strtrim(box:GetText())
	if typed == "" or ns.ItemIDFrom(typed) or typed:find("|H", 1, true) then
		if search.box == box then hideSearch() end
		return
	end
	local skip = ns.db[box.listKey]
	local found = searchBags(typed, skip)
	for index = MAX_MATCHES + 1, #found do found[index] = nil end
	if #found < MAX_MATCHES and #typed >= MIN_ALL_ITEMS then
		local seen = {}
		for _, match in ipairs(found) do seen[match.itemID] = true end
		for _, match in ipairs(searchAllItems(typed, skip, seen, MAX_MATCHES - #found)) do
			found[#found + 1] = match
		end
	end
	if #found == 0 then
		if search.box == box then hideSearch() end
		return
	end
	search.box, search.matches, search.selected, search.offset = box, found, 1, 0
	drawSearch()
end

local function moveSelection(box, step)
	if search.box ~= box or #search.matches == 0 then return end
	search.selected = (search.selected - 1 + step) % #search.matches + 1
	-- Keep the selected match in view.
	if search.selected <= search.offset then
		scrollTo(search.selected - 1)
	elseif search.selected > search.offset + VISIBLE_MATCHES then
		scrollTo(search.selected - VISIBLE_MATCHES)
	else
		drawSearch()
	end
end

local LIST_TITLES = { always = "Always pick up", never = "Never pick up" }
local OTHER_LIST = { always = "never", never = "always" }
local LIST_HELP = {
	always = "Items picked up whatever they're worth.",
	never = "Items left behind whatever they're worth, quest items included.",
}
local ADD_HELP = "Type part of an item's name and pick it from the list (your bags first, then the whole game), or type an item ID, Shift-click an item, or drag one here from your bags."

local function listCount(key)
	local n = 0
	for _ in pairs(ns.db[key]) do n = n + 1 end
	return n
end

local function itemsText(n)
	return n == 1 and "1 item" or n .. " items"
end

-- An item's name and quality: the game's own when it has the item, otherwise from the list of every
-- item. No name when neither has it yet.
local function itemInfo(id)
	local name, _, quality = C_Item.GetItemInfo(id)
	if name then return name, quality end
	local items = loadAllItems()
	local index = items.index[id]
	if index then return items.names[index], items.qualities[index] end
end

-- A box that adds items to the list named by `box.listKey`: pick a match for a typed name, or type an
-- item ID, Shift-click an item into it, or drag one onto it.
local function addBox(parent, key)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(200, 20)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlight")
	box.listKey = key
	listBoxes[#listBoxes + 1] = box
	local function add()
		local typed = strtrim(box:GetText())
		local id = ns.ItemIDFrom(typed)
		if id then
			ns.SetListed(id, box.listKey)
			box:SetText("")
		elseif search.box == box and search.matches[search.selected] then
			pick(search.matches[search.selected])
			return
		elseif typed ~= "" then
			ns.Print("no item is called that. Type an item ID or Shift-click the item instead.")
		end
		hideSearch()
		box:ClearFocus()
	end
	box:SetScript("OnEnterPressed", add)
	box:SetScript("OnEscapePressed", function(self)
		hideSearch()
		self:ClearFocus()
	end)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then updateSearch(self) end
	end)
	box:SetScript("OnArrowPressed", function(self, arrow)
		if arrow == "DOWN" then moveSelection(self, 1) elseif arrow == "UP" then moveSelection(self, -1) end
	end)
	box:SetScript("OnEditFocusLost", function(self)
		-- A click on a match takes the focus first; the click still has to land.
		if search.box == self and not (search.frame and search.frame:IsMouseOver()) then hideSearch() end
	end)
	-- An item dragged from the bags onto the box.
	box:SetScript("OnReceiveDrag", function(self)
		local kind, itemID = GetCursorInfo()
		if kind == "item" and itemID then
			ClearCursor()
			ns.SetListed(itemID, self.listKey)
		end
		self:ClearFocus()
	end)
	box:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Add to " .. LIST_TITLES[self.listKey], 1, 1, 1)
		GameTooltip:AddLine(LIST_HELP[self.listKey], nil, nil, nil, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(ADD_HELP, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	box:HookScript("OnLeave", function() GameTooltip:Hide() end)
	local addButton = button(parent, "Add", 60, add)
	addButton:SetPoint("LEFT", box, "RIGHT", 6, 0)
	return box
end

---------------------------------------------------------------------------
-- The item list window: one list at a time, any size, with a filter
---------------------------------------------------------------------------

local WINDOW_NAME = "PickUpFilterListWindow"
local listWindow

local function sortedItems(key, filter)
	local rows, total = {}, 0
	filter = filter and filter ~= "" and filter:lower() or nil
	local items = loadAllItems()
	for id in pairs(ns.db[key]) do
		total = total + 1
		-- The item list's name first: asking the game about every item could mean a server request each.
		local index = items.index[id]
		local name = index and items.names[index] or itemInfo(id) or ("Item " .. id)
		if not filter or name:lower():find(filter, 1, true) or tostring(id):find(filter, 1, true) then
			rows[#rows + 1] = { id = id, sortName = name:lower() }
		end
	end
	table.sort(rows, function(a, b)
		if a.sortName ~= b.sortName then return a.sortName < b.sortName end
		return a.id < b.id
	end)
	return rows, total
end

local refreshWindow

local function drawListRow(row, data)
	if not row.icon then
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("LEFT", 4, 0)
		row.name = text(row, "GameFontHighlight")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", -56, 0)
		row.name:SetWordWrap(false)
		row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
		row.remove:SetSize(22, 22)
		row.remove:SetPoint("RIGHT", -2, 0)
		row.remove:SetScript("OnClick", function(self) ns.SetListed(self:GetParent().itemID, nil) end)
		tooltip(row.remove, "Remove", "Takes the item off this list.")
		-- Moves the item to the other list: the game's page arrow, pointing the way the other list
		-- sits on the options page (Always on the left, Never on the right). drawListRow picks the way.
		local switch = CreateFrame("Button", nil, row)
		switch:SetSize(26, 26)
		switch:SetPoint("RIGHT", row.remove, "LEFT", 0, 0)
		switch:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
		switch:SetScript("OnClick", function(self)
			local id, other = self:GetParent().itemID, OTHER_LIST[listWindow.key]
			ns.SetListed(id, other)
			ns.Print(ns.ItemLabel(id) .. " moved to " .. LIST_TITLES[other] .. ".")
		end)
		switch:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Move to " .. LIST_TITLES[OTHER_LIST[listWindow.key]], 1, 1, 1)
			GameTooltip:Show()
		end)
		switch:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.switch = switch
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:AddLine("Item ID " .. self.itemID, 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	local id = data.id
	row.itemID = id
	local page = listWindow.key == "always" and "NextPage" or "PrevPage"
	if row.switch.page ~= page then
		row.switch.page = page
		row.switch:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "-Up")
		row.switch:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "-Down")
	end
	row.icon:SetTexture(C_Item.GetItemIconByID(id))
	local name, quality = itemInfo(id)
	if name then
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		row.name:SetText((color and color.hex or "") .. name .. "|r |cff808080(" .. id .. ")|r")
	else
		row.name:SetText("Item " .. id)
		local item = Item:CreateFromItemID(id)
		if not item:IsItemEmpty() then
			-- Many names can arrive at once; one redraw covers them all.
			item:ContinueOnItemLoad(function()
				if listWindow.redrawPending then return end
				listWindow.redrawPending = true
				C_Timer.After(0.2, function()
					listWindow.redrawPending = nil
					refreshWindow()
				end)
			end)
		end
	end
end

StaticPopupDialogs.PICKUPFILTER_CLEAR_LIST = {
	text = "Take all %s items off %s?",
	button1 = "Remove all",
	button2 = CANCEL,
	OnAccept = function(_, key)
		wipe(ns.db[key])
		ns.Fire("ListsChanged")
	end,
	showAlert = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function buildListWindow()
	local w = CreateFrame("Frame", WINDOW_NAME, UIParent, "BasicFrameTemplateWithInset")
	w:SetSize(420, 520)
	w:SetPoint("CENTER")
	w:SetFrameStrata("DIALOG")
	w:SetToplevel(true)
	w:SetMovable(true)
	w:EnableMouse(true)
	w:RegisterForDrag("LeftButton")
	w:SetScript("OnDragStart", w.StartMoving)
	w:SetScript("OnDragStop", w.StopMovingOrSizing)
	w:SetClampedToScreen(true)
	tinsert(UISpecialFrames, WINDOW_NAME)
	w:Hide()

	local title = text(w, "GameFontHighlight", ns.TITLE .. ": item lists")
	title:SetPoint("TOP", 0, -5)

	-- One button per list; the one shown stays lit.
	w.tabs = {}
	for index, key in ipairs({ "always", "never" }) do
		local tab = button(w, "", 190, function() ns.OpenItemList(key) end)
		tab:SetPoint("TOPLEFT", 14 + (index - 1) * 198, -32)
		w.tabs[key] = tab
	end

	w.add = addBox(w, "always")
	w.add:SetPoint("TOPLEFT", 22, -70)

	-- Narrows what's shown, by name or item ID.
	local ok, filter = pcall(CreateFrame, "EditBox", nil, w, "SearchBoxTemplate")
	if not (ok and filter) then
		filter = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
	end
	if filter.Instructions then
		filter.Instructions:SetText("Find in this list")
		filter.Instructions:SetFontObject("GameFontDisable")
	end
	filter:SetFontObject("GameFontHighlight")
	filter:SetSize(200, 20)
	filter:SetPoint("TOPLEFT", 22, -100)
	filter:SetAutoFocus(false)
	filter:HookScript("OnTextChanged", function() refreshWindow() end)
	filter:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	w.filter = filter

	w.count = text(w, "GameFontHighlight")
	w.count:SetPoint("LEFT", filter, "RIGHT", 14, 0)

	local scrollBox = CreateFrame("Frame", nil, w, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 12, -130)
	scrollBox:SetPoint("BOTTOMRIGHT", -28, 44)
	local scrollBar = CreateFrame("EventFrame", nil, w, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(LIST_ROW_HEIGHT)
	view:SetElementInitializer("Button", drawListRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	w.scrollBox = scrollBox

	w.empty = text(w, "GameFontDisable")
	w.empty:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", 6, -4)

	w.clear = button(w, "Remove all", 110, function()
		local count = listCount(w.key)
		if count > 0 then
			StaticPopup_Show("PICKUPFILTER_CLEAR_LIST", count, LIST_TITLES[w.key], w.key)
		end
	end)
	w.clear:SetPoint("BOTTOMLEFT", 14, 12)

	local done = button(w, "Close", 90, function() w:Hide() end)
	done:SetPoint("BOTTOMRIGHT", -14, 12)

	w:SetScript("OnHide", function()
		if search.box == w.add then hideSearch() end
	end)
	listWindow = w
	return w
end

function refreshWindow()
	local w = listWindow
	if not (w and w:IsShown()) then return end
	for key, tab in pairs(w.tabs) do
		tab:SetText(LIST_TITLES[key] .. " (" .. listCount(key) .. ")")
		if key == w.key then tab:LockHighlight() else tab:UnlockHighlight() end
	end
	local rows, total = sortedItems(w.key, w.filter:GetText())
	w.scrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	w.count:SetText(#rows == total and itemsText(total) or (#rows .. " of " .. itemsText(total)))
	w.empty:SetText(total == 0 and "Nothing here yet." or "No items match.")
	w.empty:SetShown(#rows == 0)
	w.clear:SetEnabled(total > 0)
end

-- Opens the item list window on one list ("always" or "never").
function ns.OpenItemList(key)
	local w = listWindow or buildListWindow()
	if w.key ~= key then
		w.key = key
		w.add.listKey = key
		w.add:SetText("")
		w.filter:SetText("")
		if search.box == w.add then hideSearch() end
	end
	w:Show()
	w:Raise()
	refreshWindow()
end

---------------------------------------------------------------------------
-- Item lists on the options page: a box to add, how many are on the list, and a button to open it
---------------------------------------------------------------------------

local function buildList(x, y, key)
	local fs = text(content, "GameFontNormal", LIST_TITLES[key])
	fs:SetPoint("TOPLEFT", x, y)
	y = y - 22

	local box = addBox(content, key)
	box:SetPoint("TOPLEFT", x + 6, y)
	y = y - 30

	local count = text(content, "GameFontHighlight")
	count:SetPoint("TOPLEFT", x + 4, y - 5)
	local open = button(content, "Open list", 100, function() ns.OpenItemList(key) end)
	open:SetPoint("TOPLEFT", x + 166, y)
	tooltip(open, LIST_TITLES[key], "Shows every item on this list, to find, add and remove them.")
	table.insert(refreshers, function()
		local n = listCount(key)
		count:SetText(n == 0 and "|cff808080Nothing here yet.|r" or itemsText(n))
	end)
	return y - 30
end

local function buildLists(y)
	heading("Item lists", y)
	y = y - 26
	local help = text(content, "GameFontHighlight",
		"These win over every other rule. Type part of an item's name and pick it from the list (Up and Down choose, Enter adds), type an item ID, Shift-click an item into a box, or drag one from your bags onto it.",
		WIDTH - 30)
	help:SetPoint("TOPLEFT", COLUMNS.quality, y)
	y = y - help:GetStringHeight() - 14
	buildList(COLUMNS.quality, y, "always")
	local bottom = buildList(COLUMNS.quality + 310, y, "never")
	return function() return bottom end
end

-- A Shift-clicked item goes into whichever list box is being typed in.
local function onInsertLink(link)
	for _, box in ipairs(listBoxes) do
		if box:HasFocus() and link then
			box:SetText(link)
			return
		end
	end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

local function buildProfiles(y)
	heading("Profile", y)
	y = y - 30
	local label = text(content, "GameFontHighlight", "This character uses")
	label:SetPoint("TOPLEFT", COLUMNS.quality, y - 6)

	local function names()
		local list = {}
		for _, name in ipairs(ns.ProfileNames()) do list[#list + 1] = { name, name } end
		return list
	end
	local menu = dropdown(content, 150, names, function() return ns.char.profile end,
		function(name) ns.UseProfile(name) end)
	menu:SetPoint("TOPLEFT", COLUMNS.action + 30, y)
	tooltip(menu, "Profile",
		"A profile is a whole filter: the rules table, prices, other rules and both item lists. Characters can share one, and new characters start on Default.")

	local x = COLUMNS.action + 190
	local buttons = {
		{ "New", 56, "New profile", "Makes a new profile with the default filter and switches this character to it.",
			function() ns.AskProfileName("new") end },
		{ "Copy", 56, "Copy profile", "Makes a copy of this profile under a new name and switches this character to it.",
			function() ns.AskProfileName("copy", ns.char.profile) end },
		{ "Rename", 70, "Rename profile", "Renames this profile for every character using it.",
			function() ns.AskProfileName("rename", ns.char.profile) end },
		{ "Delete", 64, "Delete profile", "Deletes this profile, after asking. Characters using it switch to Default, or to another profile when this one is Default.",
			function() ns.AskDeleteProfile(ns.char.profile) end },
	}
	local deleteButton
	for _, b in ipairs(buttons) do
		local made = button(content, b[1], b[2], b[5])
		made:SetPoint("TOPLEFT", x, y - 1)
		tooltip(made, b[3], b[4])
		x = x + b[2] + 4
		deleteButton = made
	end
	y = y - 30

	local users = text(content, "GameFontDisable", nil, WIDTH - 30)
	users:SetPoint("TOPLEFT", COLUMNS.quality, y)
	table.insert(refreshers, function()
		deleteButton:SetEnabled(#ns.ProfileNames() > 1)
		local others = {}
		for _, key in ipairs(ns.ProfileUsers(ns.char.profile)) do
			if key ~= ns.CHAR_KEY then others[#others + 1] = key end
		end
		users:SetText(#others > 0 and ("Also used by " .. table.concat(others, ", ") .. ".")
			or "No other character uses this profile.")
	end)
	return y - 34
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function build()
	local panel = CreateFrame("Frame")
	panel.name = ns.TITLE

	local scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -22, 4)
	local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	bar:SetHideIfUnscrollable(true)
	scroll:EnableMouseWheel(true)

	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH + 20, 1)
	scroll:SetScrollChild(content)

	local title = text(content, "GameFontNormalHuge", ns.TITLE)
	title:SetPoint("TOPLEFT", 16, -16)
	local sub = text(content, "GameFontHighlight", "Auto loot that leaves the junk behind.")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local y = -70
	y = buildStatus(y)
	local enabled = checkbox("Filter loot",
		"When off, PickUp Filter picks up everything, like the game's Auto Loot. Same as /puf on and /puf off.",
		function() return ns.char.enabled end, function(v) ns.SetEnabled(v) end)
	enabled:SetPoint("TOPLEFT", 16, y)
	y = y - 44

	y = buildProfiles(y)
	y = buildRulesTable(y)
	y = buildPrices(y)
	y = buildOtherRules(y)
	local listsBottom = buildLists(y)

	table.insert(refreshers, function()
		content:SetHeight(-listsBottom() + 24)
	end)

	panel:SetScript("OnShow", refreshAll)
	panel:SetScript("OnHide", hideSearch)
	category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
	Settings.RegisterAddOnCategory(category)
end

ns.Listen("Loaded", function()
	build()
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
	elseif ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
	end
end)

ns.Listen("ListsChanged", function()
	if content and content:IsVisible() then refreshAll() end
	refreshWindow()
end)

ns.Listen("SettingChanged", function()
	if content and content:IsVisible() then refreshAll() end
end)

ns.Listen("ProfileChanged", function()
	hideSearch()
	if content and content:IsVisible() then refreshAll() end
	refreshWindow()
end)
