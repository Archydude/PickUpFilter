-- PickUp Filter: the loot window
-- When loot opens, picks up every slot the filter wants, then closes the window so the rest
-- stays behind. The game's own Auto Loot would take everything first, so the filter needs it off;
-- holding the game's Auto Loot key (Shift by default) still has the game take everything.

local _, ns = ...

-- The loot window being worked on, from LOOT_READY to LOOT_CLOSED, or nil.
--   pending        [slot] = true for slots asked for and not picked up yet
--   keepOpen       true once something wanted couldn't be picked up (full bags)
local session

local function sortKey(entry)
	-- Money, currencies and items picked up by a rule rather than a price go first, then by value.
	return entry.value or math.huge
end

local function reportLeft(left)
	if not ns.db.reportLeft or #left == 0 then return end
	local parts = {}
	for _, entry in ipairs(left) do
		local item = entry.item
		local text = item.link or item.name or "?"
		if (item.count or 1) > 1 then text = text .. " x" .. item.count end
		if entry.value then text = text .. " (" .. ns.Money(entry.value) .. ")" end
		parts[#parts + 1] = text
	end
	ns.Print("left behind: " .. table.concat(parts, ", "))
end

local function closeIfDone()
	if session and not session.keepOpen and next(session.pending) == nil then
		CloseLoot()
	end
end

ns.On("LOOT_READY", function(autoLoot)
	-- The game is picking up everything itself: its Auto Loot is on, or its Auto Loot key is held.
	if autoLoot or session then return end
	session = { pending = {} }

	local take, left = {}, {}
	for slot = 1, GetNumLootItems() do
		local item = ns.SlotItem(slot)
		if item.kind ~= "none" and not item.locked then
			local wanted, value
			if ns.char.enabled then
				wanted, _, value = ns.Decide(item)
			else
				wanted = true
			end
			local entry = { slot = slot, item = item, value = value }
			table.insert(wanted and take or left, entry)
		end
	end

	if ns.db.valuableFirst then
		table.sort(take, function(a, b)
			local ka, kb = sortKey(a), sortKey(b)
			if ka ~= kb then return ka > kb end
			return a.slot < b.slot
		end)
	end

	for _, entry in ipairs(take) do session.pending[entry.slot] = true end
	for _, entry in ipairs(take) do LootSlot(entry.slot) end
	reportLeft(left)

	-- Nothing wanted: close once the window has opened, so the corpse keeps the rest.
	if #take == 0 and #left > 0 then C_Timer.After(0, closeIfDone) end
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
