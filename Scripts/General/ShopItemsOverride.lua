-- 修改商店物品生成，使用和怪物掉落相同的逻辑
local LogId = "ShopItemsOverride"
Log(Merge.Log.Info, "Init started: %s", LogId)
local MT = Merge.Tables
local random, floor, ceil = math.random, math.floor, math.ceil

-- 检查物品是否适合某个商店类型（支持“货架/层”）
-- shelf: 1 = 第一层(前6格), 2 = 第二层(后6格), nil = 不分层
local function IsItemAllowedForHouse(itemId, houseType, shelf)
	local itemTxt = Game.ItemsTxt[itemId]
	if not itemTxt then
		return false
	end

	local equipStat = (itemTxt.EquipStat or -1) + 1
	
	-- 武器店 (houseType == 1): 武器、远程武器、法杖
	if houseType == 1 then
		return equipStat == const.ItemType.Weapon or
			   equipStat == const.ItemType.Weapon2H or
			   equipStat == const.ItemType.Missile or
			   equipStat == const.ItemType.Wand or
			   equipStat == const.ItemType.Sword or
			   equipStat == const.ItemType.Dagger or
			   equipStat == const.ItemType.Axe or
			   equipStat == const.ItemType.Spear or
			   equipStat == const.ItemType.Bow or
			   equipStat == const.ItemType.Mace or
			   equipStat == const.ItemType.Club or
			   equipStat == const.ItemType.Staff
	
	-- 护甲店 (houseType == 2):
	--   第一层：小件（头盔/手套/披风/腰带/靴子/盾）
	--   第二层：护甲本体（皮/链/板/Armor）
	elseif houseType == 2 then
		local isSmall = equipStat == const.ItemType.Shield or
			equipStat == const.ItemType.Helm or
			equipStat == const.ItemType.Belt or
			equipStat == const.ItemType.Cloak or
			equipStat == const.ItemType.Gountlets or
			equipStat == const.ItemType.Boots or
			equipStat == const.ItemType.Shield_ or
			equipStat == const.ItemType.Helm_ or
			equipStat == const.ItemType.Belt_ or
			equipStat == const.ItemType.Cloak_ or
			equipStat == const.ItemType.Gountlets_ or
			equipStat == const.ItemType.Boots_

		local isArmorBody = equipStat == const.ItemType.Armor or
			equipStat == const.ItemType.Armor_ or
			equipStat == const.ItemType.Leather or
			equipStat == const.ItemType.Chain or
			equipStat == const.ItemType.Plate

		if shelf == 1 then
			return isSmall
		elseif shelf == 2 then
			return isArmorBody
		else
			-- 不分层时：护甲店允许全部护甲相关
			return isSmall or isArmorBody
		end
	
	-- 魔法店 (houseType == 3): 戒指、项链、魔杖、卷轴、书
	elseif houseType == 3 then
		return equipStat == const.ItemType.Ring or
			   equipStat == const.ItemType.Amulet or
			   equipStat == const.ItemType.Wand or
			   equipStat == const.ItemType.Scroll or
			   equipStat == const.ItemType.Book or
			   equipStat == const.ItemType.Ring_ or
			   equipStat == const.ItemType.Amulet_ or
			   equipStat == const.ItemType.Wand_ or
			   equipStat == const.ItemType.Scroll_
	
	-- 炼金店 (houseType == 4): 药水、材料
	elseif houseType == 4 then
		return equipStat == const.ItemType.Reagent or
			   equipStat == const.ItemType.Potion or
			   equipStat == const.ItemType.Reagent_ or
			   equipStat == const.ItemType.Potion_
	end
	
	return false
end

-- 读取 House rules.txt（仿照 ItemsModifiers.lua 的方式）
local function ProcessHouseRulesTxt()
	local house_rules = {
		WeaponShopsStandart = {},
		WeaponShopsSpecial = {},
		ArmorShopsStandart = {},
		ArmorShopsSpecial = {},
		MagicShopsStandart = {},
		MagicShopsSpecial = {},
		AlchemistsStandart = {},
		AlchemistsSpecial = {}
	}
	
	local table_file = "Data/Tables/House rules.txt"
	local txt_table = io.open(table_file, "r")
	if not txt_table then
		Log(Merge.Log.Warning, "%s: No House rules.txt found", LogId)
	else
		local current_section = nil
		local iter = txt_table:lines()
		-- 跳过表头
		local header = iter()
		
		for line in iter do
			local words = string.split(line, "\9")
			if #words > 0 and words[1] then
				-- 检查是否是章节标题
				if words[1] == "Weapon shops Standart" then
					current_section = "WeaponShopsStandart"
				elseif words[1] == "Weapon shops Special" then
					current_section = "WeaponShopsSpecial"
				elseif words[1] == "Armor shops Standart" then
					current_section = "ArmorShopsStandart"
				elseif words[1] == "Armor shops Special" then
					current_section = "ArmorShopsSpecial"
				elseif words[1] == "Magic shops Standart" then
					current_section = "MagicShopsStandart"
				elseif words[1] == "Magic shops Special" then
					current_section = "MagicShopsSpecial"
				elseif words[1] == "Alchem shops Standart" then
					current_section = "AlchemistsStandart"
				elseif words[1] == "Alchem shops Special" then
					current_section = "AlchemistsSpecial"
				elseif words[1] == "Index by type" or string.len(words[1]) == 0 then
					-- 跳过表头或空行
				elseif current_section and tonumber(words[1]) then
					-- 解析数据行
					local index = tonumber(words[1])
					local quality = tonumber(words[2]) or 1
					
					if current_section == "WeaponShopsStandart" or current_section == "WeaponShopsSpecial" then
						-- Weapon shops: Index, Quality, Items1-4
						house_rules[current_section][index] = {
							Quality = quality,
							Items = {
								tonumber(words[3]) or 0,
								tonumber(words[4]) or 0,
								tonumber(words[5]) or 0,
								tonumber(words[6]) or 0
							}
						}
					elseif current_section == "ArmorShopsStandart" or current_section == "ArmorShopsSpecial" then
						-- Armor shops: Index, Quality, Items1-4, QualityShelf, Items1-4 (shelf)
						house_rules[current_section][index] = {
							Quality = quality,
							Items = {
								tonumber(words[3]) or 0,
								tonumber(words[4]) or 0,
								tonumber(words[5]) or 0,
								tonumber(words[6]) or 0
							},
							QualityShelf = tonumber(words[7]) or 1,
							ItemsShelf = {
								tonumber(words[8]) or 0,
								tonumber(words[9]) or 0,
								tonumber(words[10]) or 0,
								tonumber(words[11]) or 0
							}
						}
					elseif current_section == "MagicShopsStandart" or current_section == "MagicShopsSpecial" or
						   current_section == "AlchemistsStandart" or current_section == "AlchemistsSpecial" then
						-- Magic/Alchem shops: Index, Quality (只有两列)
						house_rules[current_section][index] = {
							Quality = quality
						}
					end
				end
			end
		end
		io.close(txt_table)
	end
	
	MT.HouseRules = house_rules
end

-- 获取商店等级（使用 House rules 中的 Quality，公式：quality*15-10）
-- house 直接就是 HouseRules 数组的索引（对应 House rules.txt 第一列的 Index by type）
local function GetShopLevel(house, houseType)
	local shopLevel = 1
	
	-- 根据商店类型获取 Quality（house 直接作为索引，仿照 itemlevel 的方式调用）
	local quality = 1
	if houseType == 1 then
		if MT.HouseRules and MT.HouseRules.WeaponShopsStandart[house] then
			quality = MT.HouseRules.WeaponShopsStandart[house].Quality or 1
		end
	elseif houseType == 2 then
		if MT.HouseRules and MT.HouseRules.ArmorShopsStandart[house] then
			-- 使用 QualityShelf（架子的质量）
			quality = MT.HouseRules.ArmorShopsStandart[house].QualityShelf or 1
		end
	elseif houseType == 3 then
		if MT.HouseRules and MT.HouseRules.MagicShopsStandart[house] then
			quality = MT.HouseRules.MagicShopsStandart[house].Quality or 1
		end
	elseif houseType == 4 then
		if MT.HouseRules and MT.HouseRules.AlchemistsStandart[house] then
			quality = MT.HouseRules.AlchemistsStandart[house].Quality or 1
		end
	end
	
	-- 使用公式：quality*15-10
	shopLevel = quality * 15 - 10
	return math.max(shopLevel, 1)  -- 确保至少为1
end

-- 根据等级从 ItemsExtra 中查找并生成物品（和怪物掉落逻辑一致）
-- shelf: 见 IsItemAllowedForHouse
local function GenerateItemByLevel(shopLevel, houseType, shelf)
	local DropItemLevelmin = math.max(shopLevel - 10, 1)
	local DropItemLevelmax = math.min(shopLevel + 10, 100)
	
	-- 从 ItemsExtra 中查找等级在 DropItemLevelmin 和 DropItemLevelmax 之间的物品
	local candidateItems = {}
	if MT.ItemsExtra then
		for itemId, itemExtra in pairs(MT.ItemsExtra) do
			if itemExtra.Level and itemExtra.Level >= DropItemLevelmin and itemExtra.Level <= DropItemLevelmax then
				-- 排除任务物品，并且检查物品是否适合该商店类型
				if not itemExtra.QuestItem and IsItemAllowedForHouse(itemId, houseType, shelf) then
					table.insert(candidateItems, itemId)
				end
			end
		end
	end
	
	-- 如果找到了匹配的物品，随机选择一个
	if #candidateItems > 0 then
		local selectedItemId = candidateItems[random(1, #candidateItems)]
		return selectedItemId
	end
	
	-- 如果没有找到匹配的物品，返回 nil（保持原物品）
	return nil
end

-- 应用附魔（和怪物掉落逻辑一致）
local function ApplyEnchantment(item, shopLevel)
	-- 有 shopLevel/100 的概率具有附魔（如果 shopLevel > 100，则总是有附魔）
	local enchantChance = shopLevel / 100
	if random() <= enchantChance then
		-- 设置附魔：Bonus 为 1-11 之间的随机值
		item.Bonus = random(1, 11)
		-- BonusStrength 为 DropItemLevelmin/4 到 DropItemLevelmax/4 之间的随机值
		local DropItemLevelmin = math.max(shopLevel - 10, 1)
		local DropItemLevelmax = math.min(shopLevel + 10, 100)
		local minStrength = math.ceil(DropItemLevelmin / 4)
		local maxStrength = math.ceil(DropItemLevelmax / 4)
		item.BonusStrength = random(minStrength, maxStrength)
	end
end

-- 商店物品生成后，使用和怪物掉落相同的逻辑
function events.ShopItemsGenerated(t)
	local house = t.House
	local houseType = Game.Houses[house].Type
	local shopLevel = GetShopLevel(house, houseType)
	local modifiedCount = 0
	
	if houseType == 1 then
	
		-- 修改普通商店物品 (每个商店有12个槽位)
		if Game.ShopItems[house] then
			-- Message(tostring(house))
			for slot = 0, 11 do
				local item = Game.ShopItems[house][slot]
				if item and item.Number > 0 then
					local shelf = nil
					if houseType == 2 or houseType == 3 then
						shelf = (slot < 6) and 1 or 2
					end
					local newItemId = GenerateItemByLevel(shopLevel, houseType, shelf)
					if newItemId then
						item.Number = newItemId
						item.Identified = 1  -- 设置为已鉴定
						ApplyEnchantment(item, shopLevel)
						modifiedCount = modifiedCount + 1
					end
				end
			end
		end
		
		-- 修改特殊商店物品 (每个商店有12个槽位)
		if Game.ShopSpecialItems[house] then
			for slot = 0, 11 do
				local item = Game.ShopSpecialItems[house][slot]
				if item and item.Number > 0 then
					local shelf = nil
					if houseType == 2 or houseType == 3 then
						shelf = (slot < 6) and 1 or 2
					end
					local newItemId = GenerateItemByLevel(shopLevel + 15, houseType, shelf)
					if newItemId then
						item.Number = newItemId
						item.Identified = 1  -- 设置为已鉴定
						ApplyEnchantment(item, shopLevel)
						modifiedCount = modifiedCount + 1
					end
				end
			end
		end
	end
	
	Log(Merge.Log.Info, "%s: Modified %d shop items for house %d (level %d)", LogId, modifiedCount, house, shopLevel)
end

function events.GameInitialized2()
	ProcessHouseRulesTxt()
end

Log(Merge.Log.Info, "Init finished: %s", LogId)
