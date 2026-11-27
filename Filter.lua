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
	local appearanceID, sourceID = transmog.GetItemInfo(link)
	if not sourceID then return false end
	if transmog.PlayerHasTransmogItemModifiedAppearance(sourceID) then return false end
	local info = transmog.GetAppearanceInfoBySource(sourceID)
	if info then return not info.appearanceIsCollected end
	local visualID = appearanceID
	if transmog.GetSourceInfo then
		local sourceInfo = transmog.GetSourceInfo(sourceID)
		if sourceInfo then
			if sourceInfo.isCollected then return false end
			if not visualID or visualID == 0 then visualID = sourceInfo.visualID end
		end
	end
	if visualID and visualID ~= 0 and transmog.GetAllAppearanceSources then
		for _, id in ipairs(transmog.GetAllAppearanceSources(visualID) or {}) do
			if transmog.PlayerHasTransmogItemModifiedAppearance(id) then return false end
		end
	end
	return true
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

-- True when the character has profession `id` (SkillLine ID).
function ns.HasProfession(id)
	return id ~= nil and myProfessions()[id] == true
end

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

---------------------------------------------------------------------------
-- Active quest objectives, for non-quest items needed to finish a quest
---------------------------------------------------------------------------

local questItems

local function objectiveItemName(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	local name = text:gsub("%s*:%s*%d+/%d+%s*$", "")
	name = name:gsub("%s*%(%d+/%d+%)%s*$", "")
	name = name:gsub("^%d+/%d+%s+", "")
	name = name:gsub("%s+%d+/%d+$", "")
	name = strtrim(name):lower()
	if name ~= "" then return name end
end

local function readQuestItems()
	questItems = {}
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo
		and C_QuestLog.GetQuestObjectives) then return end
	local count = C_QuestLog.GetNumQuestLogEntries()
	for index = 1, count do
		local info = C_QuestLog.GetInfo(index)
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID ~= 0 then
			local objectives = C_QuestLog.GetQuestObjectives(info.questID)
			for _, obj in ipairs(objectives or {}) do
				if obj.type == "item" then
					local req = tonumber(obj.numRequired) or 0
					local ful = tonumber(obj.numFulfilled) or 0
					local key = objectiveItemName(obj.text)
					if key then
						local needed = req > 0 and req or 1
						local unfinished = not obj.finished and (req == 0 or ful < req)
						local prev = questItems[key]
						if prev then
							prev.quests = prev.quests + 1
							prev.required = prev.required + needed
							if ful > prev.fulfilled then prev.fulfilled = ful end
							if unfinished then prev.anyUnfinished = true end
						else
							questItems[key] = {
								title = info.title or "quest",
								quests = 1,
								required = needed,
								fulfilled = ful,
								anyUnfinished = unfinished,
							}
						end
					end
				end
			end
		end
	end
end

ns.On("QUEST_LOG_UPDATE", function() questItems = nil end)
ns.On("BAG_UPDATE_DELAYED", function() questItems = nil end)
ns.On("PLAYER_ENTERING_WORLD", function() questItems = nil end)

-- If active quests still need item `name` (with optional `itemID` for bag count), returns
-- (label, remaining, fulfilled, required, questCount).
function ns.NeededForQuest(name, itemID)
	if type(name) ~= "string" or name == "" then return end
	if issecretvalue and issecretvalue(name) then return end
	if not questItems then readQuestItems() end
	local entry = questItems[strtrim(name):lower()]
	if not entry then return end
	if entry.quests == 1 and not entry.anyUnfinished then return end
	local have = entry.fulfilled
	if itemID and C_Item and C_Item.GetItemCount then
		have = math.max(have, C_Item.GetItemCount(itemID) or 0)
	end
	local remaining = entry.required - have
	if remaining > 0 then
		local label = entry.quests > 1 and (entry.quests .. " quests") or entry.title
		return label, remaining, have, entry.required, entry.quests
	end
end

function ns.Decide(item, questTaken)
	local db = ns.db
	if item.kind == "money" then return true, "money" end
	if item.kind == "none" then return false, "nothing to pick up" end
	if item.kind == "currency" then
		if db.currency == "never" then return false, "currencies are left behind" end
		return true, "currency"
	end

	if item.itemID and db.always[item.itemID] then return true, "on your always list" end
	if item.itemID and db.never[item.itemID] then return false, "on your never list" end
	if db.quest == "always" then
		if item.isQuest then return true, "quest item" end
		if item.name then
			local label, remaining, fulfilled, required, quests = ns.NeededForQuest(item.name, item.itemID)
			if label then
				local key = strtrim(item.name):lower()
				local taken = questTaken and questTaken[key] or 0
				if remaining > taken then
					if questTaken then questTaken[key] = taken + (item.count or 1) end
					local progress = required > 0 and (" (" .. fulfilled .. "/" .. required .. ")") or ""
					local prefix = (quests and quests > 1) and "needed for " or "needed for quest: "
					return true, prefix .. label .. progress
				end
			end
		end
	end
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
