-- PickUp Filter: what an item is worth
-- Vendor price from the game, auction prices from TSM and Auctionator when they're loaded.

local ADDON_NAME, ns = ...

-- Price sources, in the order the options list them.
ns.SOURCES = {
	{ key = "tsm", name = "TSM" },
	{ key = "auctionator", name = "Auctionator" },
	{ key = "vendor", name = "Vendor price" },
}
ns.SOURCE_NAMES = { none = "Nothing" }
for _, source in ipairs(ns.SOURCES) do ns.SOURCE_NAMES[source.key] = source.name end

-- TSM prices a player can pick.
ns.TSM_SOURCES = {
	{ key = "dbmarket", name = "Market value (recommended)" },
	{ key = "dbminbuyout", name = "Lowest auction right now" },
	{ key = "dbhistorical", name = "Historical price" },
	{ key = "dbregionmarketavg", name = "Region market average" },
}

local function positive(ok, value)
	if ok and type(value) == "number" and value > 0 then return value end
end

function ns.TSMLoaded()
	return TSM_API ~= nil and TSM_API.ToItemString ~= nil and TSM_API.GetCustomPriceValue ~= nil
end

local function auctionatorAPI()
	return Auctionator and Auctionator.API and Auctionator.API.v1
end

function ns.AuctionatorLoaded()
	return auctionatorAPI() ~= nil
end

local function tsmPrice(item)
	if not ns.TSMLoaded() then return end
	local ok, itemString = pcall(TSM_API.ToItemString, item.link)
	if not ok or not itemString then return end
	return positive(pcall(TSM_API.GetCustomPriceValue, ns.db.tsmSource, itemString))
end

local function auctionatorPrice(item)
	local api = auctionatorAPI()
	if not api then return end
	local value
	if api.GetAuctionPriceByItemLink and item.link then
		value = positive(pcall(api.GetAuctionPriceByItemLink, ADDON_NAME, item.link))
	end
	if not value and api.GetAuctionPriceByItemID and item.itemID then
		value = positive(pcall(api.GetAuctionPriceByItemID, ADDON_NAME, item.itemID))
	end
	return value
end

local function vendorPrice(item)
	if item.sellPrice and item.sellPrice > 0 then return item.sellPrice end
end

local GETTERS = { tsm = tsmPrice, auctionator = auctionatorPrice, vendor = vendorPrice }

-- What one of `item` is worth under a price rule ("vendor" | "priority" | "highest"), and which
-- source said so; nil when no source has a price. `item` has link, itemID and sellPrice.
function ns.ItemPrice(item, rule)
	if rule == "vendor" then
		local value = vendorPrice(item)
		if value then return value, "vendor" end
		return
	end
	if rule == "highest" then
		local best, from
		for _, source in ipairs(ns.SOURCES) do
			local value = GETTERS[source.key](item)
			if value and (not best or value > best) then best, from = value, source.key end
		end
		return best, from
	end
	for _, key in ipairs(ns.db.priority) do
		local getter = GETTERS[key]
		local value = getter and getter(item)
		if value then return value, key end
	end
end
