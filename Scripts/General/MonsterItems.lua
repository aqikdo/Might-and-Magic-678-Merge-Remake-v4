local random, floor, ceil = math.random, math.floor, math.ceil
local MT = Merge.Tables
local MonsterItems = {
[20] = 1004,
[21] = 1004,
[24] = 1006,
[64] = 1006,
[74] = 1016,
[75] = 1006,
[81] = 207,
[92] = 202,
[95] = 1009,
[150] = 1004,
[167] = 1016,
[168] = 1016,
[172] = 1006,
[186] = 1009
}

function events.MonsterKilled(mon)
	--[[
	if mon.Ally == 9999 then -- no drop from reanimated monsters
		return
	end
	]]--
	local monKind = ceil(mon.Id/3)
	local Mul = mon.Id - monKind*3 + 3
	local ItemId = MonsterItems[monKind]
	if ItemId and random(20) + Mul*2 > 13 then
		evt.SummonObject(ItemId, mon.X, mon.Y, mon.Z + 100, 100)
	end
end

local ItemProb = {0,1,1,1,1,3,3,3,3,4,4,
				  4,4,5,5,5,5,6,6,6,6,
				  6,6,6,6,6,7,7,7,7,7,
				  7,7,7,7,8,8,8,8,8,8,
				  8,8,8,9,9,9,9,9,9,9,
				  9,9,10,10,10,10,10,10,10,10,
				  11,11,11,11,11,11,11,11,11,11,
				  11,11,11,11,11,11,11,11,11,11,
				  11,11,11,11,11,11,11,11,11,11,
				  11,11,12,12,12,12,12,12,12,12}

-- const.ItemType 包含关系：TreasureItemType 对应的可接受物品类型集合
-- Weapon(1)=所有武器和弓；Misc(22)=卷轴、书、宝石、戒指、amulet、腰带、鞋子、王冠(Helm)
local ItemTypeIncludes = {
	[1]  = { [1]=true, [2]=true, [3]=true, [23]=true, [24]=true, [25]=true, [26]=true, [27]=true, [28]=true, [29]=true, [30]=true },  -- Weapon
	[22] = { [6]=true, [7]=true, [10]=true, [11]=true, [12]=true, [16]=true, [17]=true, [22]=true, [46]=true, [47]=true },  -- Misc: helm,belt,boots,ring,amulet,scroll,book,misc,gems
}
local function ItemTypeMatches(wantType, itemType)
	if wantType == 0 then
		return true
	end
	local set = ItemTypeIncludes[wantType]
	if set then
		return set[itemType] == true
	end
	return itemType == wantType
end

function events.PickCorpse(t)
	local mon = t.Monster
	if mon.Ally == 9999 then -- no drop from reanimated monsters
		return
	end
	local DropItemLevelmin = math.max(mon.Level - 3, 1)
	local DropItemLevelmax = math.min(mon.Level + 3, 100)
	local gaveItem = false
	local itemName = nil
	if math.random() <= 0.5 then
		local wantType = (mon.TreasureItemType or 0)  -- 0 = Any (const.ItemType.Any)
		
		-- 从 ItemsExtra 中查找等级在范围内且符合 TreasureItemType（含包含关系）的物品
		local candidateItems = {}
		if MT.ItemsExtra and Game.ItemsTxt then
			for itemId, itemExtra in pairs(MT.ItemsExtra) do
				if itemExtra.Level and itemExtra.Level >= DropItemLevelmin and itemExtra.Level <= DropItemLevelmax then
					if not itemExtra.QuestItem then
						local itemType = (Game.ItemsTxt[itemId] and Game.ItemsTxt[itemId].EquipStat and (Game.ItemsTxt[itemId].EquipStat + 1)) or 0
						if ItemTypeMatches(wantType, itemType) then
							table.insert(candidateItems, itemId)
						end
					end
				end
			end
		end
		
		if #candidateItems > 0 then
			local selectedItemId = candidateItems[math.random(1, #candidateItems)]
			evt.GiveItem(1, 0, selectedItemId)
			gaveItem = true
			itemName = Game.ItemsTxt[selectedItemId] and Game.ItemsTxt[selectedItemId].Name or ("item #" .. selectedItemId)
			-- 有 (mon.Level + 50)/100 的概率具有附魔
			local enchantChance = (mon.Level + 50) / 100
			local minStrength = math.max(1, math.ceil(DropItemLevelmin / 4))
			local maxStrength = math.min(25, math.ceil(DropItemLevelmax / 4))
			local strength = math.random(minStrength, maxStrength)
			local isspecial = (math.random() <= 0.2)
			local bonus = math.random(1, 13)
			if isspecial then
				bonus = math.random(30, 34)
			end
			if math.random() <= enchantChance then
				Mouse.Item.Bonus = bonus
				Mouse.Item.BonusStrength = strength
			end
		end
	end
	
	-- 按 TreasureDiceCount、TreasureDiceSides 投骰给队伍加钱
	local gold = math.random(DropItemLevelmin * 5, DropItemLevelmax * 5)
	evt.Add("Gold", gold)
	
	-- 状态栏：You found [xxx gold] [and xxx item]
	local parts = {}
	if gold > 0 then
		table.insert(parts, tostring(gold) .. " gold")
	end
	if itemName then
		table.insert(parts, itemName)
	end
	if #parts > 0 then
		Game.ShowStatusText("You found " .. table.concat(parts, " and "), 2)
	end
	
	if Game.UseMonsterBolster == true then
		mon.AIState = const.AIState.Removed
	end
end

-- Timer functions moved to Scripts/Global/MonsterControl.lua, PartyControl.lua, MissileControl.lua

-- Make additional special effect: when monster dies, spawn other monsters.
local FieldsToCopy = {"Hostile", "Ally", "NoFlee", "HostileType", "Group", "MoveType"}

local function SummonWithDelay(Count, Source, Delay, SummonId)

	local f = function()
		local StartTime = Game.Time
		while Game.Time < StartTime + Delay do
			Sleep(25,25)
		end

		for i = 1, Count do
			local NewMon = SummonMonster(SummonId, random(Source.X-100, Source.X+100), random(Source.Y-100, Source.Y+100), Source.Z + random(50,150), true)
			if NewMon then
				NewMon.Direction = random(0,2047)
				NewMon.LookAngle = random(100,400)
				NewMon.Velocity  = 10000
				NewMon.VelocityY = random(1000,2000)
				for k,v in pairs(FieldsToCopy) do
					NewMon[k] = Source[k]
				end
			end
			Source.SpecialA = Source.SpecialA + 1
		end

		Source.GraphicState = -1
		Source.AIState = const.AIState.Removed
	end

	coroutine.resume(coroutine.create(f))

end

function events.MonsterKilled(mon)

	if mon.Special == 4 then

		local SummonId = mon.SpecialD

		if SummonId == 0 then
			local WeakMonId = ceil(mon.Id/3)*3-2
			if mon.Id ~= WeakMonId then
				SummonId = mon.Id - 1
			else
				SummonId = mon.Id
			end
		end

		-- don't allow to summon same monsters as killed one.
		if SummonId == mon.Id then
			return
		end

		local count = (mon.SpecialC == 0 and 2 or mon.SpecialC) - mon.SpecialA
		SummonWithDelay(count, mon, const.Minute/6, SummonId)

	end
end

function events.DeathMap()
	vars.ElemwFatigue = nil
end
