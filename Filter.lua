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
		maxStack = stackCount or 1,
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

-- Whether `item` (from ns.SlotItem or ns.ItemFromLink) is picked up, why, and what it is
-- worth when the filter priced it.
--   take   true | false
--   reason text for the player, like "Poor: worth 3c, needs 1s"
--   value  copper for one item, or a full stack when stackValue is "full"; or nil
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

-- All The Things: loaded, and offering its lookup to other addons.
function ns.ATTLoaded()
	local att = _G.AllTheThings
	return type(att) == "table" and type(att.GetLinkReference) == "function"
end

-- True when All The Things counts the item as something you still need: not collected itself,
-- or holding or buying things you haven't collected, under your All The Things settings.
function ns.ATTNeeds(link)
	if not link or not ns.ATTLoaded() then return false end
	local ok, group = pcall(_G.AllTheThings.GetLinkReference, link)
	if not ok or type(group) ~= "table" then return false end
	if group.collectible and not group.collected then return true end
	if (group.total or 0) > (group.progress or 0) then return true end
	return (group.costTotal or 0) > 0
end

---------------------------------------------------------------------------
-- Character's professions, for "Always pick up (my professions)" reagents
---------------------------------------------------------------------------

local myProfs
local enteredWorld = (IsLoggedIn and IsLoggedIn()) or false

local function professionName(id)
	local names = ns.PROFESSION_NAMES and GetLocale and ns.PROFESSION_NAMES[GetLocale()]
	return (names and names[id]) or (ns.PROFESSIONS and ns.PROFESSIONS[id])
end

local function readMyProfessions()
	myProfs = {}
	local profs = ns.PROFESSIONS
	if not profs then return end
	local aliases = ns.PROFESSION_ALIASES or {}
	local byName = {}
	for id in pairs(profs) do
		local name = professionName(id)
		if name then byName[name] = id end
	end
	if GetProfessions and GetProfessionInfo then
		for _, index in pairs({ GetProfessions() }) do
			local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
			local id = (skillLine and (profs[skillLine] and skillLine or aliases[skillLine])) or byName[name]
			if id then myProfs[id] = true end
		end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local name, isHeader = GetSkillLineInfo(i)
			if name and not isHeader and byName[name] then
				myProfs[byName[name]] = true
			end
		end
	end
end

local function myProfessions()
	if not myProfs then readMyProfessions() end
	local list = myProfs
	-- Right after login the game may not have told us the character's skills yet; ask again next time
	-- rather than keep an empty list until the player enters the world.
	if not enteredWorld and next(myProfs) == nil then myProfs = nil end
	return list
end

ns.On("PLAYER_ENTERING_WORLD", function()
	enteredWorld = true
	myProfs = nil
	if ns.Fire then ns.Fire("SettingChanged", "professions") end
end)
ns.On("SKILL_LINES_CHANGED", function()
	myProfs = nil
	if ns.Fire then ns.Fire("SettingChanged", "professions") end
end)
ns.On("CHAT_MSG_SKILL", function()
	myProfs = nil
	if ns.Fire then ns.Fire("SettingChanged", "professions") end
end)

-- Sorted list of { id, name } for the character's current professions.
function ns.MyProfessions()
	local out = {}
	for id in pairs(myProfessions()) do
		local name = professionName(id)
		if name then out[#out + 1] = { id = id, name = name } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Returns the name(s) of the character's profession(s) that craft with `itemID`, or nil.
function ns.ReagentForMyProfession(itemID)
	local list = itemID and ns.REAGENT_PROFS and ns.REAGENT_PROFS[itemID]
	if not list then return end
	local mine = myProfessions()
	local skip = ns.db and ns.db.reagentSkip
	local matched
	for _, profID in ipairs(list) do
		if mine[profID] and not (skip and skip[profID]) then
			local name = professionName(profID)
			if name then
				matched = matched or {}
				matched[#matched + 1] = name
			end
		end
	end
	if matched then return table.concat(matched, ", ") end
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
	if item.reagent then
		if db.reagents == "all" or db.reagents == true then
			return true, "crafting reagent"
		elseif db.reagents == "mine" then
			local prof = ns.ReagentForMyProfession(item.itemID)
			if prof then return true, "crafting reagent for " .. prof end
		end
	end
	if db.att and ns.ATTNeeds(item.link) then return true, "All The Things says you need it" end

	local row = ns.QualityRow(item.quality)
	local label = qualityName(item.quality)
	if row.action == "always" then return true, label .. ": always picked up" end
	if row.action == "never" then return false, label .. ": never picked up" end

	-- Without the item's details there's no vendor price or stack size to go on.
	local each, source
	if item.known then each, source = ns.ItemPrice(item, row.price) end
	if not each then
		if db.noPrice == "leave" then return false, label .. ": no price, left behind" end
		return true, label .. ": no price, picked up"
	end

	-- Items that stack are worth a full stack in "full" mode, or one item in "each" mode.
	local asStack = item.stackable and db.stackValue ~= "each"
	local value = asStack and each * item.maxStack or each
	local needed = asStack and row.stack or row.single
	local what = asStack and ("a stack of " .. item.maxStack .. " is worth ") or "worth "
	local suffix = (item.stackable and not asStack) and " each" or ""
	local priceName = ns.PriceLabel(source)
	local text = label .. ": " .. what .. ns.MoneyText(value) .. suffix .. " (" .. priceName .. "), needs " .. ns.MoneyText(needed)
	return value >= needed, text, value, priceName
end

---------------------------------------------------------------------------
-- /puf check
---------------------------------------------------------------------------

local function explain(link)
	local item = ns.ItemFromLink(link, 1)
	local take, reason = ns.Decide(item)
	local verdict = take and "|cff40ff40picked up|r" or "|cffff6060left behind|r"
	ns.Print(link .. " would be " .. verdict .. " (" .. reason .. ").")
	if not ns.char.enabled then ns.Print("The filter is off right now, so everything is picked up.") end
end

-- "/puf check <item link or ID>".
function ns.CheckCommand(rest)
	rest = strtrim(rest or "")
	local _, after = rest:match("^(%d+)%s+(.+)$")
	if after and ns.ItemIDFrom(after) then rest = after end
	local itemID = ns.ItemIDFrom(rest)
	if not itemID then
		ns.Print("put a Shift-clicked item link or an item ID after /puf check, like /puf check [Linen Cloth].")
		return
	end
	local item = Item:CreateFromItemID(itemID)
	if item:IsItemEmpty() then
		ns.Print("the game doesn't know item " .. itemID .. ".")
		return
	end
	item:ContinueOnItemLoad(function()
		explain(rest:match("|c[^|]*|Hitem:[^|]*|h.-|h|r") or item:GetItemLink())
	end)
end
