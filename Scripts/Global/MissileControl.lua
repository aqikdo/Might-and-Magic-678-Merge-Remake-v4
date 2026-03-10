-- Timer functions split from MonsterItems.lua

-- Insertion sort by comparator (less(a,b)=true if a before b). Fast for n<=20.
local function SortBy(arr, lo, hi, less)
	for i = lo + 1, hi do
		local v = arr[i]
		local j = i - 1
		while j >= lo and less(v, arr[j]) do
			arr[j + 1] = arr[j]
			j = j - 1
		end
		arr[j + 1] = v
	end
end

local function MissileTimer()
	local FireSpikeList = {}
	local cnt = {}
	local OwnerList = {}
	local OwnerListCount = 0
	local SpellMas = {}
	for i, v in Map.Objects do
		if v.Spell then
			local distx = Party.X - v.X
			local disty = Party.Y - v.Y
			local distz = Party.Z + 50 - v.Z
			local dist = math.sqrt(distx ^ 2 + disty ^ 2 + distz ^ 2)
			if v.Type == 10020 and v.Spell == 33 then
				v.VelocityX = 0
				v.VelocityY = 0
				v.VelocityZ = 0
				v.X = vars.LloydX
				v.Y = vars.LloydY
				v.Z = vars.LloydZ + 100
				if v.Age > 700 and v.MaxAge == 0 then
					v.Age = 500
					v.MaxAge = 1
				end
			elseif v.Type == 1060 then
				if FireSpikeList[v.Owner] == nil then
					cnt[v.Owner] = 1
					FireSpikeList[v.Owner] = {}
					FireSpikeList[v.Owner][cnt[v.Owner]] = v
					OwnerListCount = OwnerListCount + 1
					OwnerList[OwnerListCount] = v.Owner
					SpellMas[v.Owner] = v.SpellMastery
				else
					cnt[v.Owner] = cnt[v.Owner] + 1
					FireSpikeList[v.Owner][cnt[v.Owner]] = v
				end
			elseif v.Type == 12014 and v.Spell == 16 and v.Age < 30000 then
				v.VelocityX = 4000 * (distx / dist)
				v.VelocityY = 4000 * (disty / dist)
				v.VelocityZ = 4000 * (distz / dist)
				if math.sqrt(distx ^ 2 + disty ^ 2 + distz ^ 2) < 200 then
					v.Age = 30000
					Map:RemoveObject(i)
					vars.MonsterAttackTime = Game.Time
					evt.DamagePlayer(evt.Players.Random, const.Damage.Air, v.SpellSkill * math.random(7, 9))
					evt.DamagePlayer(evt.Players.All, const.Damage.Air, v.SpellSkill * 2)
				end
			end
		end
	end
	for j = 1, OwnerListCount do
		local owner = OwnerList[j]
		if cnt[owner] > SpellMas[owner] * 2 + 1 then
			SortBy(FireSpikeList[owner], 1, cnt[owner], function(a, b) return a.Age < b.Age end)
			for i = SpellMas[owner] * 2 + 2, cnt[owner] do
				FireSpikeList[owner][i].Age = 31000
			end
		end
	end
end

function events.AfterLoadMap()
	Timer(MissileTimer, 4, false)
end