-- PickUp Filter: whether one loot slot is picked up, and why
-- Rules, first match wins: the player's item lists, money, quest items, currencies, then the
-- rules table row for the item's quality.

local _, ns = ...

-- What the filter needs to know about an item, from its link. `count` is how many dropped.
-- `known` is false while the game hasn't loaded the item's details yet (no stack size, vendor price).
function ns.ItemFromLink(link, count)
	local itemID = ns.ItemIDFrom(link)
	local name, _, quality, _, _, _, _, stackCount, _, _, sellPrice, _, _, _, _, _, isCraftingReagent =
		C_Item.GetItemInfo(link)
	return {
		kind = "item",
		link = link,
		itemID = itemID,
		name = name,
		quality = quality,
		count = count or 1,
		stackable = (stackCount or 1) > 1,
		sellPrice = sellPrice,
		reagent = isCraftingReagent,
		known = name ~= nil,
	}
end

-- What's in loot slot `slot`, as ns.ItemFromLink describes it, plus kind "money" / "currency" / "none".
function ns.SlotItem(slot)
	local _, name, quantity, currencyID, quality, locked, isQuestItem, questID, _, isCoin = GetLootSlotInfo(slot)
	local slotType = GetLootSlotType(slot)
	if isCoin or slotType == Enum.LootSlotType.Money then
		return { kind = "money", name = name, locked = locked }
	end
	if currencyID or slotType == Enum.LootSlotType.Currency then
		return { kind = "currency", name = name, count = quantity, locked = locked }
	end
	local link = GetLootSlotLink(slot)
	if slotType ~= Enum.LootSlotType.Item or not link then
		return { kind = "none", name = name }
	end
	local item = ns.ItemFromLink(link, quantity)
	item.quality = item.quality or quality
	item.name = item.name or name
	item.isQuest = isQuestItem or (questID ~= nil and questID ~= 0)
	item.locked = locked
	return item
end

local function qualityName(quality)
	local row = ns.QUALITIES[math.min(math.max(quality or 1, 0), ns.TOP_QUALITY) + 1]
	return row and row.name or "Common"
end

-- Whether `item` (from ns.SlotItem or ns.ItemFromLink) is picked up, why, and what the whole drop is
-- worth when the filter priced it.
--   take   true | false
--   reason text for the player, like "Poor: worth 3c, needs 1s"
--   value  copper for the whole drop, or nil
-- True when the item has an appearance the account hasn't collected yet.
function ns.UncollectedAppearance(link)
	local transmog = C_TransmogCollection
	if not link or not transmog then return false end
	local _, sourceID = transmog.GetItemInfo(link)
	if not sourceID then return false end
	local info = transmog.GetAppearanceInfoBySource(sourceID)
	if info then return not info.appearanceIsCollected end
	return not transmog.PlayerHasTransmogItemModifiedAppearance(sourceID)
end

function ns.Decide(item)
	local db = ns.db
	if item.kind == "money" then return true, "money" end
	if item.kind == "none" then return false, "nothing to pick up" end
	if item.kind == "currency" then
		if db.currency == "never" then return false, "currencies are left behind" end
		return true, "currency"
	end

	if item.itemID and db.always[item.itemID] then return true, "on your always list" end
	if item.itemID and db.never[item.itemID] then return false, "on your never list" end
	if item.isQuest and db.quest == "always" then return true, "quest item" end
	if db.appearances and ns.UncollectedAppearance(item.link) then
		return true, "appearance you haven't collected"
	end
	if db.reagents and item.reagent then return true, "crafting reagent" end

	local row = ns.QualityRow(item.quality)
	local label = qualityName(item.quality)
	if row.action == "always" then return true, label .. ": always picked up" end
	if row.action == "never" then return false, label .. ": never picked up" end

	-- Without the item's details there's no vendor price or stack size to go on.
	local each = item.known and ns.ItemPrice(item, row.price)
	if not each then
		if db.noPrice == "leave" then return false, label .. ": no price, left behind" end
		return true, label .. ": no price, picked up"
	end

	local count = item.count or 1
	local value = each * count
	local needed = item.stackable and row.stack or row.single
	local what = item.stackable and (count > 1 and "the drop of " .. count .. " is worth " or "the drop is worth ")
		or "worth "
	local text = label .. ": " .. what .. ns.MoneyText(value) .. ", needs " .. ns.MoneyText(needed)
	return value >= needed, text, value
end

---------------------------------------------------------------------------
-- /puf check
---------------------------------------------------------------------------

local function explain(link, count)
	local item = ns.ItemFromLink(link, count)
	local take, reason = ns.Decide(item)
	local verdict = take and "|cff40ff40picked up|r" or "|cffff6060left behind|r"
	local shown = count > 1 and (count .. " x " .. link) or link
	ns.Print(shown .. " would be " .. verdict .. " (" .. reason .. ").")
	if not ns.char.enabled then ns.Print("The filter is off right now, so everything is picked up.") end
end

-- "/puf check [count] <item link or ID>".
function ns.CheckCommand(rest)
	rest = strtrim(rest or "")
	local count, after = rest:match("^(%d+)%s+(.+)$")
	if count and ns.ItemIDFrom(after) then
		rest = after
	else
		count = nil
	end
	count = math.max(1, tonumber(count) or 1)
	local itemID = ns.ItemIDFrom(rest)
	if not itemID then
		ns.Print("put a Shift-clicked item link or an item ID after /puf check, like /puf check 20 [Linen Cloth].")
		return
	end
	local item = Item:CreateFromItemID(itemID)
	if item:IsItemEmpty() then
		ns.Print("the game doesn't know item " .. itemID .. ".")
		return
	end
	item:ContinueOnItemLoad(function()
		explain(rest:match("|c[^|]*|Hitem:[^|]*|h.-|h|r") or item:GetItemLink(), count)
	end)
end
