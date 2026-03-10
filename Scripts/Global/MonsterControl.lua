-- Timer functions split from MonsterItems.lua

local ceil, min = math.ceil, math.min

-- 当一只怪被激活后，会“连锁”激活周围此距离内的其他怪（户外或同房间室内）。调小可减少被引到的范围。
local MONSTER_EXPAND_DIST = 500

-- 第二法术冷却：用 mapvars 存储每个怪物的第二法术冷却结束时间，load 后仍可读取
local function UpdateMonsterSpell2ChanceByCooldown()
	if mapvars.Spell2Cooldown == nil then
		mapvars.Spell2Cooldown = {}
	end
	local gameTime = Game.Time
	for i, mon in Map.Monsters do
		if mon.Spell2 ~= 0 and mon.Active and mon.HP > 0 then
			local cooldownEnd = mapvars.Spell2Cooldown[i]
			if cooldownEnd == nil or gameTime >= cooldownEnd then
				mon.Spell2Chance = 100
				mon.SpellChance = 0
			end
		end
	end
end

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

local function GetDist(t, x, y, z)
	local px, py, pz = XYZ(t)
	return math.sqrt((px - x) ^ 2 + (py - y) ^ 2 + (pz - z) ^ 2)
end

local function GetOverallPartyLevel()
	local Ov, Cnt = 0, 1
	for i, v in Party do
		Ov = Ov + v.LevelBase
		Cnt = i + 1
	end
	return ceil(Ov / Cnt)
end

function MonsterBuffsAdjust_HighFrequency()
	for i, mon in Map.Monsters do
		local spellBuffs = mon.SpellBuffs
		local gameTime = Game.Time
		if mon.Active and mon.HP > 0 then
			--Fear
			local fearBuff = spellBuffs[const.MonsterBuff.Fear]
			if fearBuff.ExpireTime >= gameTime then
				local sk = fearBuff.Skill
				if fearBuff.Power == 0 then
					fearBuff.Power = 1
					fearBuff.ExpireTime = gameTime + sk * const.Minute / 2
				end
			end

			--Charm
			local charmBuff = spellBuffs[const.MonsterBuff.Charm]
			local damagehalvedBuff = spellBuffs[const.MonsterBuff.DamageHalved]
			if charmBuff.ExpireTime >= gameTime + const.Minute * 11 then
				local sk = math.round((charmBuff.ExpireTime - gameTime) / (100000 * const.Minute))
				local mas = charmBuff.Skill
				charmBuff.ExpireTime = 0
				if (mas == 3 and sk <= 6) or (mas == 4 and sk <= 9) then
					damagehalvedBuff.ExpireTime = gameTime + const.Minute * 10
					damagehalvedBuff.Skill = 5
					if mas == 3 then
						damagehalvedBuff.Power = 40
					elseif mas == 4 then
						damagehalvedBuff.Power = 50
					end
				else
					if mon.HP / mon.FullHP <= sk * 0.001 * mas then
						mon.Group = 0
						mon.Ally = 9999
						mon.Hostile = false
						mon.ShowAsHostile = false
						local cnt = 0
						for i, v in Party do
							if v:IsConscious() then
								cnt = cnt + 1
							end
						end
						for i, v in Party do
							if v:IsConscious() then
								evt[i].Add("Exp", mon.Experience / cnt)
							end
						end
					end
				end
			end

			--Enslave -> purge
			local enslaveBuff = spellBuffs[const.MonsterBuff.Enslave]
			local summonedBuff = spellBuffs[const.MonsterBuff.Summoned]
			local slowBuff = spellBuffs[const.MonsterBuff.Slow]
			if enslaveBuff.ExpireTime >= gameTime and enslaveBuff.Power == 0 then
				if summonedBuff.ExpireTime >= gameTime then
					mon.HP = 0
				else
					local Time = 0
					if enslaveBuff.Skill == 3 then
						Time = const.Minute / 6
					elseif enslaveBuff.Skill == 4 then
						Time = const.Minute / 3
					end
					for i, v in spellBuffs do
						v.ExpireTime = 0
						v.Power = 0
						v.Skill = 0
					end
					slowBuff.ExpireTime = gameTime + Time
					slowBuff.Power = 20
				end
			end

			--berserk
			local berserkBuff = spellBuffs[const.MonsterBuff.Berserk]
			local hasteBuff = spellBuffs[const.MonsterBuff.Haste]
			local fateBuff = spellBuffs[const.MonsterBuff.Fate]
			local hammerhandsBuff = spellBuffs[const.MonsterBuff.Hammerhands]
			if berserkBuff.ExpireTime >= gameTime then
				local ExpTime = berserkBuff.ExpireTime
				local Effect = 0
				if berserkBuff.Skill == 2 then
					Effect = 400
				elseif berserkBuff.Skill == 3 then
					Effect = 450
				elseif berserkBuff.Skill == 4 then
					Effect = 500
				end

				berserkBuff.ExpireTime = 0
				hasteBuff.ExpireTime = math.max(ExpTime + const.Day, hasteBuff.ExpireTime)

				fateBuff.ExpireTime = math.max(ExpTime, fateBuff.ExpireTime)
				if fateBuff.Power then
					fateBuff.Power = math.max(fateBuff.Power, Effect)
				else
					fateBuff.Power = Effect
				end

				hammerhandsBuff.ExpireTime = math.max(ExpTime, hammerhandsBuff.ExpireTime)
				if hammerhandsBuff.Power then
					hammerhandsBuff.Power = math.max(hammerhandsBuff.Power, Effect)
				else
					hammerhandsBuff.Power = Effect
				end
			end

			--wander(blind)
			local wanderBuff = spellBuffs[const.MonsterBuff.Wander]
			local meleeonlyBuff = spellBuffs[const.MonsterBuff.MeleeOnly]
			if wanderBuff.ExpireTime >= gameTime and wanderBuff.Power == 0 then
				wanderBuff.ExpireTime = gameTime + const.Minute * 10
				meleeonlyBuff.ExpireTime = 0
				wanderBuff.Power = 5
			end

			if damagehalvedBuff.ExpireTime > gameTime then
				if damagehalvedBuff.Skill <= 4 then
					damagehalvedBuff.ExpireTime = 0
				end
			end

			--shrinking ray(invisible)
			local shrinkingrayBuff = spellBuffs[const.MonsterBuff.ShrinkingRay]
			if shrinkingrayBuff.ExpireTime >= gameTime and shrinkingrayBuff.Power > 10 then
				if Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime >= gameTime and Party.SpellBuffs[const.PartyBuff.TorchLight].Power >= 11 and GetDist(mon, Party.X, Party.Y, Party.Z) <= Party.SpellBuffs[const.PartyBuff.TorchLight].Power * 20 then
					shrinkingrayBuff.ExpireTime = 0
					shrinkingrayBuff.Power = 0
					Game.ShowMonsterBuffAnim(i)
				end
			end
		end
		--paralyzed -> stone
		local paralyzeBuff = spellBuffs[const.MonsterBuff.Paralyze]
		local stonedBuff = spellBuffs[const.MonsterBuff.Stoned]
		if paralyzeBuff.ExpireTime >= gameTime and paralyzeBuff.Power == 0 then
			stonedBuff.ExpireTime = paralyzeBuff.ExpireTime
			paralyzeBuff.ExpireTime = 0
		end
	end
end

function MonsterBuffsAdjust_LowFrequency()
	local nomon = 1
	local MinSpeedReduce = 1
	local one_Monsters_prevent_save = false
	local overallpartylevel = GetOverallPartyLevel()
	for i, mon in Map.Monsters do
		local spellBuffs = mon.SpellBuffs
		local gameTime = Game.Time
		if spellBuffs[const.MonsterBuff.Paralyze].ExpireTime >= gameTime or spellBuffs[const.MonsterBuff.Stoned].ExpireTime >= gameTime then
			nomon = 0
		end
		if mon.Active and mon.HP > 0 then
			--Fate
			local fateBuff = spellBuffs[const.MonsterBuff.Fate]
			if fateBuff.ExpireTime >= gameTime then
				fateBuff.ExpireTime = gameTime + const.Hour
			end

			--Hammerhands
			local hammerhandsBuff = spellBuffs[const.MonsterBuff.Hammerhands]
			if hammerhandsBuff.ExpireTime >= gameTime then
				hammerhandsBuff.ExpireTime = gameTime + const.Hour
			end

			local dist = GetDist(mon, Party.X, Party.Y, Party.Z)

			if mon.ShowAsHostile == true then
				if Map:IsOutdoor() and dist <= 25000 * ((mon.Level / overallpartylevel) ^ 2) and Game.UseMonsterBolster == true and (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) then
					Party.SpellBuffs[const.PartyBuff.Invisibility].ExpireTime = 0
					Party.SpellBuffs[const.PartyBuff.Fly].ExpireTime = 0
					Party.SpellBuffs[const.PartyBuff.WaterWalk].ExpireTime = 0
					one_Monsters_prevent_save = true
				end
				if vars.LastCastSpell == nil or gameTime - vars.LastCastSpell >= const.Minute * 5 and Game.UseMonsterBolster == true then
					mon.HP = math.min(mon.FullHP, mon.HP + mon.FullHP * 0.1)
				end
				if dist < 5000 then
					nomon = 0
				end
				mon.HostileType = 4
			end
		end
	end
	if nomon == 1 then
		vars.LastCastSpell = Game.Time - const.Minute * 6
	end
	vars.PartySpeedReduceByMonster = MinSpeedReduce
	Monsters_prevent_save = one_Monsters_prevent_save
	UpdateMonsterSpell2ChanceByCooldown()
end

function MonsterRandomWalk()
	for i, mon in Map.Monsters do
		if mon.Active == true and mon.HP > 0 and mon.VelocityX == 0 and mon.VelocityY == 0 and mon.VelocityZ == 0 and math.random(1, 50) == 1 and mon.Ally ~= 9999 and GetDist(mon, Party.X, Party.Y, Party.Z) <= 800 and mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time then
			mon.SpellBuffs[const.MonsterBuff.Charm].ExpireTime = Game.Time + const.Minute * 2
		end
	end
end

function SummonMonsterAdjust()
	local cnt = 0
	local WispList = {}
	local cnt2 = 0
	local AnimateList = {}
	for i, mon in Map.Monsters do
		local TxtMon = Game.MonstersTxt[mon.Id]
		if mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime >= Game.Time then
			if mon.Id == 97 or mon.Id == 98 or mon.Id == 99 then
				cnt = cnt + 1
				WispList[cnt] = mon
				if vars.PlayerAttackTime > vars.MonsterAttackTime + const.Minute * 4 and vars.MonsterGetCloseTime > vars.MonsterAttackTime + const.Minute * 4 then
					if mon.AttackRecovery < 50 then
						mon.AttackRecovery = 50
					end
				end
			end
			local HPrate = mon.HP / mon.FullHP
			local splv = (mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime - Game.Time) / const.Minute / 5
			if mon.SpellBuffs[const.MonsterBuff.Summoned].Skill >= 3 then
				splv = splv / 3
			end
			mon.FullHP = math.min(math.max(1, 50 * splv), 30000)
			mon.HP = math.max(0, math.ceil(mon.FullHP * HPrate))
			if mon.FullHP == 1 then
				mon.HP = 0
			end
			mon.Attack1.DamageAdd = Game.BolsterAmount * 0.6
			mon.Attack1.DamageDiceSides = math.sqrt(splv * 20)
			mon.Attack1.DamageDiceCount = math.sqrt(splv * 20)
			mon.Attack2Chance = 0
			mon.Spell = 0
			mon.Spell2 = 0
			mon.MoveSpeed = 0
			mon.Velocity = mon.MoveSpeed
		end

		if mon.Ally == 9999 and mon.HP > 0 and (mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime == nil or mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time) then
			if mon.Id == 97 or mon.Id == 98 or mon.Id == 99 then
				mon.HP = 0
			else
				local sk, mas = SplitSkill(TxtMon.SpellSkill)
				mon.FullHP = ceil(min(TxtMon.FullHP * (1 + mon.Elite / 2), 30000) * ReanimateHP[1])
				if mon.HP > mon.FullHP then
					mon.HP = mon.FullHP
				end
				SetAttackMaxDamage2(mon, mon.Attack1, math.ceil(TxtMon.Attack1.DamageDiceSides) * TxtMon.Attack1.DamageDiceCount * (1 + mon.Elite) * (MonsterEliteDamage[mon.NameId] or 1) * ReanimateDmg[1] * DamageMulByBoost[mon.BoostType])
				SetAttackMaxDamage2(mon, mon.Attack2, math.ceil(TxtMon.Attack2.DamageDiceSides) * TxtMon.Attack2.DamageDiceCount * (1 + mon.Elite) * (MonsterEliteDamage[mon.NameId] or 1) * ReanimateDmg[1] * DamageMulByBoost[mon.BoostType])
				mon.SpellSkill = JoinSkill(math.min(math.max(1, sk * (1 + mon.Elite) * (MonsterEliteDamage[mon.NameId] or 1) * MagicMulByBoost[mon.BoostType]) * ReanimateDmg[1], 1000), mas)
				sk, mas = SplitSkill(TxtMon.Spell2Skill)
				mon.Spell2Skill = JoinSkill(math.min(math.max(1, sk * (1 + mon.Elite) * (MonsterEliteDamage[mon.NameId] or 1) * MagicMulByBoost[mon.BoostType]) * ReanimateDmg[1], 1000), mas)
				if vars.LastCastSpell == nil or Game.Time - vars.LastCastSpell >= const.Minute * 5 then
					mon.HP = mon.FullHP
				end
				if mon.ReanimateTime == 0 or mon.ReanimateTime == nil then
					mon.ReanimateTime = Game.Time
				end
				mon.MoveSpeed = TxtMon.MoveSpeed * ReanimateSpeed[1]
				mon.Velocity = mon.MoveSpeed
				cnt2 = cnt2 + 1
				AnimateList[cnt2] = mon
				mon.Experience = 0
				if vars.PlayerAttackTime > vars.MonsterAttackTime + const.Minute * 4 and vars.MonsterGetCloseTime > vars.MonsterAttackTime + const.Minute * 4 then
					if mon.AttackRecovery < 50 then
						mon.AttackRecovery = 50
					end
				end
			end
		end
		if mon.HP <= 0 then
			mon.ReanimateTime = 0
		end
	end
	if cnt >= 5 then
		SortBy(WispList, 1, cnt, function(a, b) return a.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < b.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime end)
		for i = 1, cnt - 4 do
			WispList[i].HP = 0
		end
	end
	if cnt2 >= 3 then
		SortBy(AnimateList, 1, cnt2, function(a, b) return a.ReanimateTime < b.ReanimateTime end)
		for i = 1, cnt2 - 2 do
			AnimateList[i].HP = 0
		end
	end
end

local function ActiveMonTimer()
	-- Party.SpellBuffs[const.PartyBuff.Invisibility].ExpireTime = 0
	-- local MonList = Game.GetMonstersInSight()
	-- local mon, mon1
	local lim = Map.Monsters.count
	-- for k, v in pairs(MonList) do
	-- 	if v < lim then
	-- 		mon = Map.Monsters[v]
	-- 		mon.Active = true
	-- 		mon.ShowOnMap = true
	-- 		if mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time then
	-- 			mon.ShowAsHostile = true
	-- 		end
	-- 	end
	-- end
	for v, i in Map.Monsters do
		if v < lim then
			mon = Map.Monsters[v]
			if Game.MonstersTxt[mon.Id].HostileType == 4 then
				if mon.ShowAsHostile == true and mon.Hostile == true and mon.HP > 0 and GetDist(mon, Party.X, Party.Y, Party.Z) <= 512 then
					if vars.LastCastSpell then
						vars.LastCastSpell = math.max(Game.Time - const.Minute * 4, vars.LastCastSpell)
					else
						vars.LastCastSpell = Game.Time - const.Minute * 4
					end
					vars.MonsterGetCloseTime = Game.Time
				end

				if mapvars.expand[v] == nil then
					mon.AIState = const.AIState.Removed
				elseif mapvars.expand[v] ~= nil and mapvars.expand[v] ~= true and mapvars.expand[v]  < Game.Time - const.Minute * 1 then
					mapvars.expand[v] = nil
				end

				if GetDist(mon, Party.X, Party.Y, Party.Z) <= 5000 and Pathfinder.TraceSight(mon, Party) then
					if mapvars.expand[v] == nil and (vars.LastCastSpell == nil or vars.LastCastSpell < Game.Time - const.Minute * 5.5 or vars.LastCastSpell >= Game.Time - const.Minute * 5) then
						mon.Active = true
						mon.AIState = const.AIState.Active
						mon.ShowOnMap = true
						vars.LastCastSpell = Game.Time
						
						if mon.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time then
							mon.ShowAsHostile = true
						end
						mapvars.expand[v] = true
						for tv, ti in Map.Monsters do
							if Map.IsOutdoor() then
								if tv < lim and GetDist(Map.Monsters[tv], mon.X, mon.Y, mon.Z) < MONSTER_EXPAND_DIST then
									mon1 = Map.Monsters[tv]
									mon1.AIState = const.AIState.Active
									mon1.Active = true
									mon1.ShowOnMap = true
									if mon1.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time then
										mon1.ShowAsHostile = true
									end
									mapvars.expand[tv] = true
								end
							else
								if tv < lim and GetDist(Map.Monsters[tv], mon.X, mon.Y, mon.Z) < MONSTER_EXPAND_DIST and Map.RoomFromPoint(mon.X, mon.Y, mon.Z) == Map.RoomFromPoint(Map.Monsters[tv].X, Map.Monsters[tv].Y, Map.Monsters[tv].Z) then
									mon1 = Map.Monsters[tv]
									mon1.AIState = const.AIState.Active
									mon1.Active = true
									mon1.ShowOnMap = true
									if mon1.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime < Game.Time then
										mon1.ShowAsHostile = true
									end
									mapvars.expand[tv] = true
								end
							end
						end
					-- elseif mon.HP > 0 and mon.ShowAsHostile == true then
					-- 	vars.LastCastSpell = Game.Time
					end
				elseif mon.HP > 0 and (vars.LastCastSpell == nil or vars.LastCastSpell < Game.Time - const.Minute * 5) then
					mon.HP = mon.FullHP
					mon.X = mon.StartX
					mon.Y = mon.StartY
					mon.Z = mon.StartZ
					mon.AIState = const.AIState.Removed
					mapvars.expand[v] = Game.Time
				end
			end
		end
	end
end

function events.AfterLoadMap()
	if vars.MonsterGetCloseTime == nil then
		vars.MonsterGetCloseTime = 0
	end
	if vars.MonsterAttackTime == nil then
		vars.MonsterAttackTime = Game.Time
	end
	if vars.PlayerAttackTime == nil then
		vars.PlayerAttackTime = Game.Time
	end
	if mapvars.Spell2Cooldown == nil then
		mapvars.Spell2Cooldown = {}
	end
	Timer(ActiveMonTimer, const.Minute / 4, false)
	Timer(SummonMonsterAdjust, const.Minute / 8, false)
	Timer(MonsterBuffsAdjust_HighFrequency, 4, false)
	Timer(MonsterBuffsAdjust_LowFrequency, const.Minute / 4, false)
	Timer(MonsterRandomWalk, const.Minute / 4, false)
end
