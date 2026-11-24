-- PickUp Filter: the loot window
-- When loot opens, picks up every slot the filter wants, then closes the window so the rest
-- stays behind (or leaves it open, when the profile says so). The game's own Auto Loot would take everything first, so the filter needs it off;
-- holding the game's Auto Loot key (Shift by default) still has the game take everything.

local _, ns = ...

-- The loot window being worked on, from LOOT_READY to LOOT_CLOSED, or nil.
--   pending        [slot] = true for slots asked for and not picked up yet
--   keepOpen       true once something wanted couldn't be picked up (full bags)
local session

-- Money, currencies, quest items and always-list items go first (priority 2); other items
-- sort by the value of what actually dropped (each * count), including Uncommon+ items.
local function sortOrder(entry)
	local item = entry.item
	if item.kind == "money" or item.kind == "currency" or item.isQuest
		or (item.itemID and ns.db.always[item.itemID]) then
		return 2, math.huge
	end
	if entry.droppedValue ~= nil then return 1, entry.droppedValue end
	if item.known then
		local row = ns.QualityRow(item.quality)
		local each = ns.ItemPrice(item, row and row.price or "best")
		if each then return 1, each * (item.count or 1) end
	end
	return 1, entry.value or 0
end

local UNCACHE_WAIT = 0.15 -- brief wait for uncached loot items before falling back to noPrice

local function reportLeft(left)
	if not ns.db.reportLeft or #left == 0 then return end
	local parts = {}
	for _, entry in ipairs(left) do
		local item = entry.item
		local text = item.link or item.name or "?"
		if (item.count or 1) > 1 then text = text .. " x" .. item.count end
		if entry.value then
			local worth = ns.Money(entry.value)
			if item.stackable then worth = "stack of " .. item.maxStack .. ": " .. worth end
			text = text .. " (" .. worth .. (entry.priceName and ", " .. entry.priceName or "") .. ")"
		end
		parts[#parts + 1] = text
	end
	ns.Print("left behind: " .. table.concat(parts, ", "))
end

local function closeIfDone()
	if session and ns.db.afterLoot == "close" and not session.keepOpen and next(session.pending) == nil then
		CloseLoot()
	end
end

-- Gathering: herbs, ore, fishing, skinning, and things that are opened (chests, lockboxes).
-- A skinned corpse is a creature like a killed one, so skinning is known by the cast that opened
-- the loot. Only gathering casts count: any other cast just before looting (a shot at the next
-- enemy while looting the last one) is still a kill's loot.
local GATHER_CAST_WINDOW = 1 -- seconds between a finished gathering cast and the loot opening
-- One spell of each kind; its other ranks and versions share its name.
local GATHER_SPELLS = {
	8613,    -- Skinning
	2366,    -- Herbalism
	1235236, -- Herb Gathering
	2575,    -- Mining
	7620,    -- Fishing
	3365,    -- Opening
	22810,   -- Opening - No Text
	13262,   -- Disenchant
}
local gatherNames -- [spell name] = true, filled on the first cast
local lastGatherCast = 0

local function spellName(spellID)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
	return (GetSpellInfo(spellID))
end

local function isGatherSpell(spellID)
	-- The game can hide which spell was cast; a hidden one can't be told apart, so it doesn't count.
	if type(spellID) ~= "number" or (issecretvalue and issecretvalue(spellID)) then return false end
	if not gatherNames then
		gatherNames = {}
		for _, id in ipairs(GATHER_SPELLS) do
			local name = spellName(id)
			if name then gatherNames[name] = true end
		end
	end
	local name = spellName(spellID)
	return name ~= nil and gatherNames[name] == true
end

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
	if unit == "player" and isGatherSpell(spellID) then lastGatherCast = GetTime() end
end)

local function hasObjectSource(...)
	for i = 1, select("#", ...), 2 do
		local guid = select(i, ...)
		if type(guid) == "string" and (guid:find("^GameObject") or guid:find("^Item")) then return true end
	end
	return false
end

local function isGathering()
	if IsFishingLoot and IsFishingLoot() then return true end
	if GetTime() - lastGatherCast <= GATHER_CAST_WINDOW then return true end
	if GetLootSourceInfo then
		for slot = 1, GetNumLootItems() do
			-- Loot from an object in the world, or from an item (a lockbox, something disenchanted).
			if hasObjectSource(GetLootSourceInfo(slot)) then return true end
		end
	end
	return false
end

local function processLoot(current, allowDefer)
	if session ~= current then return end
	local takeAll = not ns.char.enabled or (ns.db.gathering and isGathering())

	-- If any "value"-ruled item isn't cached yet, request its info and retry once briefly
	-- instead of immediately falling back to db.noPrice.
	if allowDefer and not takeAll then
		local waiting = false
		for slot = 1, GetNumLootItems() do
			local item = ns.SlotItem(slot)
			if item.kind == "item" and not item.locked and not item.known and item.itemID then
				local row = ns.QualityRow(item.quality)
				if row and row.action == "value" then
					C_Item.RequestLoadItemDataByID(item.itemID)
					waiting = true
				end
			end
		end
		if waiting then
			C_Timer.After(UNCACHE_WAIT, function() processLoot(current, false) end)
			return
		end
	end

	local take, left = {}, {}
	for slot = 1, GetNumLootItems() do
		local item = ns.SlotItem(slot)
		if item.kind ~= "none" and not item.locked then
			local wanted, value, priceName
			if takeAll then
				wanted = true
			else
				wanted, _, value, priceName = ns.Decide(item)
			end
			local droppedValue
			if value and item.stackable and (item.maxStack or 1) > 0 then
				droppedValue = (value / item.maxStack) * (item.count or 1)
			elseif value then
				droppedValue = value * (item.count or 1)
			end
			local entry = { slot = slot, item = item, value = value, droppedValue = droppedValue, priceName = priceName }
			table.insert(wanted and take or left, entry)
		end
	end

	if ns.db.valuableFirst then
		for _, entry in ipairs(take) do entry.prio, entry.sortVal = sortOrder(entry) end
		table.sort(take, function(a, b)
			if a.prio ~= b.prio then return a.prio > b.prio end
			if a.sortVal ~= b.sortVal then return a.sortVal > b.sortVal end
			return a.slot < b.slot
		end)
	end

	for _, entry in ipairs(take) do current.pending[entry.slot] = true end
	for _, entry in ipairs(take) do LootSlot(entry.slot) end
	reportLeft(left)

	-- Nothing wanted: close once the window has opened, so the corpse keeps the rest.
	if #take == 0 and #left > 0 then C_Timer.After(0, closeIfDone) end
end

ns.On("LOOT_READY", function(autoLoot)
	-- The game is picking up everything itself: its Auto Loot is on, or its Auto Loot key is held.
	if autoLoot or session then return end
	session = { pending = {} }
	processLoot(session, true)
end)

ns.On("LOOT_SLOT_CLEARED", function(slot)
	if not session or not session.pending[slot] then return end
	session.pending[slot] = nil
	closeIfDone()
end)

-- Full bags, or as many of an item as you can carry: what's wanted stays in the loot window.
ns.On("UI_ERROR_MESSAGE", function(_, message)
	if not session or session.keepOpen or next(session.pending) == nil then return end
	if message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT then
		session.keepOpen = true
		ns.Print("couldn't pick up everything you wanted (" .. message .. "), so the loot window stays open.")
	end
end)

ns.On("LOOT_CLOSED", function()
	session = nil
end)

---------------------------------------------------------------------------
-- The game's Auto Loot setting
---------------------------------------------------------------------------

function ns.GameAutoLootOn()
	return GetCVarBool("autoLootDefault")
end

function ns.TurnOffGameAutoLoot()
	SetCVar("autoLootDefault", "0")
	ns.Fire("SettingChanged", "gameAutoLoot")
	ns.Print("the game's Auto Loot is off; PickUp Filter picks up your loot now. Hold Shift while looting to take everything.")
end

StaticPopupDialogs.PICKUPFILTER_AUTOLOOT = {
	text = "PickUp Filter picks up your loot itself and leaves the junk behind. The game's own Auto Loot takes everything first, so it has to be off.\n\nTurn off the game's Auto Loot?",
	button1 = "Turn it off",
	button2 = "Not now",
	OnAccept = function() ns.TurnOffGameAutoLoot() end,
	OnCancel = function()
		ns.Print("the game's Auto Loot is still on, so nothing is filtered. You can turn it off in /puf.")
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

ns.On("PLAYER_LOGIN", function()
	if ns.char.enabled and ns.GameAutoLootOn() and not ns.global.autoLootAsked then
		ns.global.autoLootAsked = true
		StaticPopup_Show("PICKUPFILTER_AUTOLOOT")
	end
end)

ns.On("CVAR_UPDATE", function(name)
	if name == "autoLootDefault" or name == "AUTO_LOOT_DEFAULT_TEXT" then
		ns.Fire("SettingChanged", "gameAutoLoot")
	end
end)
