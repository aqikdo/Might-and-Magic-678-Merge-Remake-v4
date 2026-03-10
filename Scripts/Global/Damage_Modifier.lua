--local timelist = {}
--cnt = 0
--function internal.OnTimer()
--	if timelist[math.floor(Game.Time / 128)]~=true then -- 1 real time second
--		Party[0].HP = Party[0].HP - 10
--		timelist[math.floor(Game.Time / 128)] = true
--	end
--end

-- TempLuck  元素攻击冷却
-- TempMight  心灵之火
-- TempSpeed  狂暴
-- TempAccuracy  风行

local const = const
local MF = Merge.Functions

local MonsterSpellDamage=  {[2]  = 1.00, [6]  = 0.40, [11] = 0.50,
							[15] = 0.25, [18] = 1.00,
							[24] = 0.30, [26] = 1.00, [29] = 0.50, [33] = 1.00,
							[37] = 2.50, [39] = 1.00, [41] = 0.40,
							[52] = 0.00, -- must remove original damage of spirit lash
							[59] = 1.00, [62] = 0.15, [65] = 1.00,
							[70] = 1.00, [76] = 1.00,
							[78] = 1.00, [84] = 1.00, [87] = 1.00,
							[90] = 1.50, [93] = 0.25, [97] = 0.50}

local spellDamageType=    {[2] = const.Damage.Fire, [6] = const.Damage.Fire, [11] = const.Damage.Fire,
							[15] = const.Damage.Air, [18] = const.Damage.Air,
							[24] = const.Damage.Water, [26] = const.Damage.Water, [29] = const.Damage.Water, [33] = const.Damage.Water,
							[37] = const.Damage.Earth, [39] = const.Damage.Earth, [41] = const.Damage.Earth,
							[52] = const.Damage.Spirit,
							[59] = const.Damage.Mind, [62] = const.Damage.Fire, [65] = const.Damage.Mind,
							[70] = const.Damage.Body, [76] = const.Damage.Body,
							[78] = const.Damage.Light, [84] = const.Damage.Light, [87] = const.Damage.Light,
							[90] = const.Damage.Dark, [93] = const.Damage.Dark, [97] = const.Damage.Dark}

local LichIncreaseConstant = 1.3
local FireDamageBonus = 1.5
local BodyDamageBonus = 1.2

local const = const

local resistanceMap = {
    [const.Damage.Fire] = {
        playerBuff = const.PlayerBuff.FireResistance,
        partyBuff = const.PartyBuff.FireResistance
    },
    [const.Damage.Water] = {
        playerBuff = const.PlayerBuff.WaterResistance,
        partyBuff = const.PartyBuff.WaterResistance
    },
    [const.Damage.Air] = {
        playerBuff = const.PlayerBuff.AirResistance,
        partyBuff = const.PartyBuff.AirResistance
    },
    [const.Damage.Earth] = {
        playerBuff = const.PlayerBuff.EarthResistance,
        partyBuff = const.PartyBuff.EarthResistance
    },
    [const.Damage.Body] = {
        playerBuff = const.PlayerBuff.BodyResistance,
        partyBuff = const.PartyBuff.BodyResistance
    },
    [const.Damage.Mind] = {
        playerBuff = const.PlayerBuff.MindResistance,
        partyBuff = const.PartyBuff.MindResistance
    }
}

local statBonusMap = {
    [const.Stats.Might] = "MightBonus",
    [const.Stats.Intellect] = "IntellectBonus",
    [const.Stats.Personality] = "PersonalityBonus",
    [const.Stats.Endurance] = "EnduranceBonus",
    [const.Stats.Speed] = "SpeedBonus",
    [const.Stats.Accuracy] = "AccuracyBonus",
    [const.Stats.Luck] = "LuckBonus",
    [const.Stats.FireResistance] = "FireResistanceBonus",
    [const.Stats.AirResistance] = "AirResistanceBonus",
    [const.Stats.WaterResistance] = "WaterResistanceBonus",
    [const.Stats.EarthResistance] = "EarthResistanceBonus",
    [const.Stats.BodyResistance] = "BodyResistanceBonus",
    [const.Stats.MindResistance] = "MindResistanceBonus"
}

local STAMINA_ATTACK_COST = 70
-- local STAMINA_SHOOT_COST = 15
-- 体力消耗改为按队员：由 StaminaLogic 提供的 ConsumeStaminaForSlot(slot, amount) 处理

local function GetDist(x,y)
	return ((x.X-y.X) * (x.X-y.X) + (x.Y-y.Y) * (x.Y-y.Y) + (x.Z-y.Z) * (x.Z-y.Z)) ^ 0.5
end

local function GetPlayerId(Player)
	local tpl = 0
	for i,pl in Party do
		if pl == Player then
			tpl = i
		end
	end
	return tpl
end

local function PrintDamageAdd(dmg)
	dmg = math.floor(dmg)
	if dmg ~= 0 then
		Sleep(1)
		if Game.StatusMessage ~= nil then
			local fl = 0
			local str = ""
			local val = 0
			for i = 1, #Game.StatusMessage do
				local ch = string.sub(Game.StatusMessage,i,i)
				if ch >= '0' and ch <= '9' then
					val = val * 10 + ch - '0'
					if fl ~= 1 then
						fl = fl + 1
					end
				elseif fl == 1 then
					str = str..tostring(math.max(val + dmg,0))
					fl = 2
					str = str..ch 
				else
					str = str..ch 
				end
			end
			if fl == 2 then
				Game.StatusMessage = str
			end
		end
	end
end

local function PrintDamageAdd2(dmg, Lastdeal)
	dmg = math.floor(dmg)
	if dmg ~= 0 then
		Sleep(1)
		if Game.StatusMessage ~= nil then
			local fl = 0
			local str = ""
			local val = 0
			for i = 1, #Game.StatusMessage do
				local ch = string.sub(Game.StatusMessage,i,i)
				if ch >= '0' and ch <= '9' then
					val = val * 10 + ch - '0'
					if fl ~= 1 then
						fl = fl + 1
					end
				elseif fl == 1 then
					if val > dmg then
						return
					end
					str = str..tostring(val + dmg)
					fl = 2
					str = str..ch 
				else
					str = str..ch 
				end
			end
			if fl == 2 then
				Game.StatusMessage = str
			end
		end
	end
end

-- 获取攻击者显示名
local function GetAttackerName(attacker)
	if not attacker then
		return "???"
	end
	if attacker.Name and type(attacker.Name) == "string" then  -- Player
		return attacker.Name
	end
	if attacker.Id and Game.MonstersTxt and Game.MonstersTxt[attacker.Id] then  -- Monster
		return Game.MonstersTxt[attacker.Id].Name or "???"
	end
	return "???"
end

--[[
DamageMonster(mon, dmg, hit_animation, attacker, damageKind)
  mon: 目标怪物 (MapMonster)
  dmg: 原始伤害值
  hit_animation: 是否播放受击动画
  attacker: [可选] 攻击来源，可为 Player 或 Monster，用于 CalcRealDamageM 计算和状态栏显示
  damageKind: [可选] 伤害类型 (const.Damage.*)，与 attacker 一起提供时使用 CalcRealDamageM
]]
local function DamageMonster(mon, dmg, hit_animation, attacker, damageKind, additionalDmg, additionalDamageKind)
	if GetDist(Party, mon) >= 5000 then
		return
	end
	if mon.HP > 0 then
		Sleep(1)
	end
	if mon.HP > 0 then
		-- 若有攻击来源和伤害类型，用 CalcRealDamageM 计算最终伤害
		local BaseDmg = dmg
		local AdditionalDmg = additionalDmg or 0
		if attacker ~= nil and damageKind ~= nil then
			local byPlayer = (attacker.Name and type(attacker.Name) == "string")
			local player = byPlayer and attacker or nil
			BaseDmg = CalcRealDamageM(dmg, damageKind, byPlayer, player, mon)
			BaseDmg = math.max(0, BaseDmg)
		end
		if attacker ~= nil and additionalDmg ~= nil and additionalDamageKind ~= nil then
			local byPlayer = (attacker.Name and type(attacker.Name) == "string")
			local player = byPlayer and attacker or nil
			AdditionalDmg = CalcRealDamageM(additionalDmg, additionalDamageKind, byPlayer, player, mon)
			AdditionalDmg = math.max(0, AdditionalDmg)
		end
		local finalDmg = BaseDmg + AdditionalDmg

		-- 怪物被打后阵营改变
		if not mon.Hostile or not mon.ShowAsHostile then
			mon.Hostile = true
			mon.ShowAsHostile = true
			mon.HostileType = 4
			mon.Active = true
			mon.ShowOnMap = true
		end

		mon.HP = math.max(0, mon.HP - finalDmg)

		-- 显示状态栏：xxx 对 xxx 造成了 xxx 点伤害
		local targetName = (Game.MonstersTxt and Game.MonstersTxt[mon.Id]) and Game.MonstersTxt[mon.Id].Name or "???"
		local attackerName = GetAttackerName(attacker)
		if AdditionalDmg > 0 then
			if additionalDamageKind == const.Damage.Phys then
				Game.ShowStatusText(string.format("%s does %d damage to %s with %d phys damage add.", attackerName, BaseDmg, targetName, AdditionalDmg), 2)
			else
				Game.ShowStatusText(string.format("%s does %d damage to %s with %d magic damage add.", attackerName, BaseDmg, targetName, AdditionalDmg), 2)
			end
		else
			Game.ShowStatusText(string.format("%s does %d damage to %s.", attackerName, finalDmg, targetName), 2)
		end

		if mon.HP == 0 then
			local cnt = 0
			for i,v in Party do
				if v:IsConscious() then
					cnt = cnt + 1
				end
			end
			local exp = mon.Experience / cnt
			for i,v in Party do
				if v:IsConscious() then
					v.Experience = v.Experience + exp * (1 + v:GetLearningTotalSkill() / 100)
				end
			end
		else
			if hit_animation then
				mon:GotHit(4)
			end
		end
	end
end

---------------------------------
--function events.CalcSpellDamage(dmg, spell, skill, mastery, HP)
--	vars.LastCastSpell = Game.Time
--end

---------------------------------

function CalcBowBaseDmg(Player)
	local it = Player:GetActiveItem(const.ItemSlot.Bow)
	if not it then
		return 0
	end
	local sk, mas = SplitSkill(Player:GetSkill(const.Skills.Bow))
	local ac = Player:GetAccuracy()
	if not (it:T().Skill == const.Skills.Bow) then
		return 0
	end
	-- 弓箭原始伤害：物品骰子最小=Mod1DiceCount，最大=Mod1DiceCount*Mod1DiceSides，取平均作为基准
	local txt = it:T()
	local diceCount = (txt.Mod1DiceCount and txt.Mod1DiceCount > 0) and txt.Mod1DiceCount or 1
	local diceSides = (txt.Mod1DiceSides and txt.Mod1DiceSides > 0) and txt.Mod1DiceSides or 1
	local DmgAdd = (txt.Mod2 and txt.Mod2 > 0) and txt.Mod2 or 0
	local baseDmg = diceCount * (diceSides + 1) / 2 + DmgAdd
	local acMul = 1 + ac * 0.01
	local addFromBase = baseDmg * (acMul - 1)
	if mas >= const.Expert then
		return sk * 2 * acMul + addFromBase
	else
		return addFromBase
	end
end

---------------------------------

function CalcBowDmgPhysAdd(Player)
	local it = Player:GetActiveItem(const.ItemSlot.MainHand)
	if not it then
		return 0
	end
	local sk, mas = SplitSkill(Player:GetSkill(it:T().Skill))
	return sk * 2
end

---------------------------------

function CalcBowDmgMagicAdd(Player, Magic)
	local sk, mas = SplitSkill(Player:GetSkill(Magic))
	return sk * 2
end

---------------------------------
function events.PlayerAttacked(t,attacker) --队伍被攻击逻辑
	local BolsterMul = Game.BolsterAmount / 100
	vars.LastCastSpell = Game.Time

	-- Dodging
	local dodge_prob = 0
	local it = t.Player:GetActiveItem(const.ItemSlot.Armor)
	local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
	if it and it:T().Skill == const.Skills.Leather then
		local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Leather))
		local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
		if mas4 == const.GM and not(it2 and it2:T().Skill == const.Skills.Shield) then
			dodge_prob = 50
		end
	elseif not it then
		local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
		if mas4 == const.GM and not(it2 and it2:T().Skill == const.Skills.Shield) then
			dodge_prob = 50
		end
	end
	if math.random(1, 100) <= dodge_prob then
		t.Handled = true
		return
	end

	if attacker.Monster then
		local dmgmul = 1
		if attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].ExpireTime > Game.Time and attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power > 10 then
			dmgmul = dmgmul * (attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power - 999) * 2
			attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].ExpireTime = 0
		end
		if attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime > Game.Time then
			if attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Skill >= 5 then
				dmgmul = dmgmul * math.max(0, dmgmul * (1 - attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Power * 0.01))
			end
		end
		if dmgmul ~= 1 then
			vars.MonsterDamageModified = Game.Time + 1
			vars.MonsterDamageMul = dmgmul
		end
		--Message(tostring(attacker.MonsterAction))
		local mattack = attacker.Monster.Attack1
		if attacker.MonsterAction == const.MonsterAction.Attack2 then
			mattack = attacker.Monster.Attack2
		end
		vars.MonsterAttackTime = Game.Time
		vars.StuckDetected = 0 
		if attacker.Monster.SpellBuffs[const.MonsterBuff.Haste].ExpireTime > Game.Time then
			--Message(tostring(attacker.Monster.AttackRecovery))
			attacker.Monster.AttackRecovery = 0
		elseif attacker.Monster.SpellBuffs[const.MonsterBuff.HourOfPower].ExpireTime > Game.Time then
			if attacker.Monster.SpellBuffs[const.MonsterBuff.HourOfPower].Skill == 4 then
				attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery * 0.5)
			else
				attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery * 0.75)
			end
		end
		if attacker.Monster.SpellBuffs[const.MonsterBuff.Slow].ExpireTime > Game.Time then
			--Message(tostring(attacker.Monster.AttackRecovery))
			attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery / 3)
		end
		--[[
		if attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime > Game.Time then
			
			if attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Skill == 5 then
				attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery * 1.2)
			elseif attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Skill == 6 then
				attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery * 1.4)
			end
			
			if attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Skill >= 5 then
				local reduce_pow = attacker.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Power * 0.01
				attacker.Monster.AttackRecovery = math.max(0, attacker.Monster.AttackRecovery * (1 + reduce_pow))
			end
		end
		]]--
		if attacker.Monster.SpellBuffs[const.MonsterBuff.Wander].ExpireTime > Game.Time then
			if math.random(1,100) <= attacker.Monster.SpellBuffs[const.MonsterBuff.Wander].Skill * 5 then
				t.Handled = true
				return
			end
		end
		--Message(tostring(attacker.Monster.AttackRecovery))
		--Message(tostring(attacker.Spell))
		--Message(tostring(attacker.Object.Spell))
		if (not attacker.Object) then
			if t.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime >= Game.Time then
				t.Player.SpellBuffs[const.PlayerBuff.Misform].Power = t.Player.SpellBuffs[const.PlayerBuff.Misform].Power + 1
				if t.Player.SpellBuffs[const.PlayerBuff.Misform].Power == 2 then
					t.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime = Game.Time
				end
				t.Handled = true
				return
			end

			if Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime >= Game.Time and vars.PlayerCastImmolation then
				attacker.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power = math.max(attacker.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power, Party.SpellBuffs[const.PartyBuff.Immolation].Power)
				attacker.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].ExpireTime = Game.Time + const.Minute * 10
				local dmg = CalcRealDamageM(Party.SpellBuffs[const.PartyBuff.Immolation].Power, const.Damage.Fire, true, Party[vars.PlayerCastImmolation], attacker.Monster)
				attacker.Monster.HP = math.max(0, attacker.Monster.HP - dmg)
				attacker.Monster:GotHit(4)
			end

			local it = t.Player:GetActiveItem(const.ItemSlot.MainHand)
			if it and it:T().Skill == const.Skills.Staff then
				local sk, mas = SplitSkill(t.Player:GetSkill(const.Skills.Staff))
				if mas == 4 and (100 + sk * 2) >= math.random(1000) then
					local dmg = CalcRealDamageM(math.random(t.Player:GetMeleeDamageMin(),t.Player:GetMeleeDamageMax()), const.Damage.Phys, true, t.Player, attacker.Monster)
					attacker.Monster.HP = math.max(0, attacker.Monster.HP - dmg)
					attacker.Monster:GotHit(4)
					t.Handled = true
					return
				end
			end

			local dmg = mattack.DamageDiceCount * mattack.DamageDiceSides / 2 + mattack.DamageAdd
			if attacker.Monster.SpellBuffs[const.MonsterBuff.Heroism].ExpireTime > Game.Time then
				dmg = dmg * 1.5
				if attacker.Monster.SpellBuffs[const.MonsterBuff.Heroism].Skill == 4 then
					dmg = dmg * 2
				end
			end
			if attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].ExpireTime > Game.Time and attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power <= 10 then
				dmg = dmg * (1 - (attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power) * 0.1)
			end
			if attacker.Monster.SpellBuffs[const.MonsterBuff.Bless].ExpireTime > Game.Time then
				evt.DamagePlayer(t.PlayerSlot,mattack.Type, dmg)
			else
				dmg = math.random(math.ceil(dmg * 0.75), math.ceil(dmg * 1.25))
				evt.DamagePlayer(t.PlayerSlot,mattack.Type, dmg)
			end
			
			t.Handled = true
		elseif attacker.Object.Spell == 0 then
			if t.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime >= Game.Time then
				t.Player.SpellBuffs[const.PlayerBuff.Misform].Power = t.Player.SpellBuffs[const.PlayerBuff.Misform].Power + 1
				if t.Player.SpellBuffs[const.PlayerBuff.Misform].Power == 2 then
					t.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime = Game.Time
				end
				t.Handled = true
				return
			end
			local dmg = mattack.DamageDiceCount * mattack.DamageDiceSides / 2 + mattack.DamageAdd
			--Message(tostring(dmg).." "..tostring(t.PlayerSlot))
			if attacker.Monster.SpellBuffs[const.MonsterBuff.Heroism].ExpireTime > Game.Time then
				dmg = dmg * 1.5
			end
			if t.Player.SpellBuffs[const.PlayerBuff.Shield].ExpireTime > Game.Time or Party.SpellBuffs[const.PartyBuff.Shield].ExpireTime > Game.Time then
				dmg = dmg * 0.85
			end
			if attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].ExpireTime > Game.Time then
				dmg = dmg * (1 - (attacker.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power) * 0.1)
			end
			if attacker.Monster.SpellBuffs[const.MonsterBuff.Bless].ExpireTime > Game.Time then
				evt.DamagePlayer(t.PlayerSlot, mattack.Type, math.ceil(dmg * 1.5))
			else
				evt.DamagePlayer(t.PlayerSlot, mattack.Type, math.ceil(dmg * (0.9 + math.random() * 0.2)))
			end
			t.Handled = true
		else
			local spellId = attacker.Object.Spell
			local spellSkill, spellmas = SplitSkill(attacker.Object.SpellSkill)
			local baseDmg = (MonsterSpellDamage[spellId] or 0) * spellSkill

			-- 第一步：用 MonsterSpellDamage 计算魔法伤害，随机 0.9~1.1 后对当前玩家造成伤害
			if spellId ~= 41 and baseDmg > 0 then
				local dmg = math.ceil(baseDmg * (0.9 + math.random() * 0.2))
				local dmgType = spellDamageType[spellId] or const.Damage.Fire
				-- Message(tostring(dmg).." "..tostring(dmgType).." "..tostring(spellId).." "..tostring(spellSkill))
				evt.DamagePlayer(t.PlayerSlot, dmgType, dmg)
			end

			-- 第二步：按法术 ID 执行特效（表驱动）
			local spellEffect = {
				[34] = function()
					if attacker.Object.Type == Game.SpellObjId[34] then
						vars.StunExpireTime = Game.Time + 250
					end
				end,
				[2] = function()
					local sk, mas = SplitSkill(spellSkill)
					if mas == 4 then
						local dmgmul = 1
						while math.random(0, 2) == 0 do
							dmgmul = dmgmul * 2
							if dmgmul > 1000 then dmgmul = 1024; break end
						end
						if dmgmul > 1 then
							evt.DamagePlayer(t.PlayerSlot, const.Damage.Fire, (dmgmul - 1) * sk * math.random(3, 5))
						end
					end
				end,
				[11] = function()
					local sk, mas = SplitSkill(spellSkill)
					if mas == 4 then
						vars.BurningExpireTime = Game.Time + const.Minute * 5
						vars.BurningPower = math.max((vars.BurningPower or 0), math.ceil(sk / 4))
					end
				end,
				[18] = function()
					local sk, mas = SplitSkill(spellSkill)
					if mas == 4 then vars.StunExpireTime = Game.Time + 100 end
				end,
				[26] = function()
					vars.SlowExpireTime = math.max((vars.SlowExpireTime or 0), Game.Time + 250)
				end,
				[70] = function()
					if vars.PartyArmorDecrease.ExpireTime < Game.Time then
						vars.PartyArmorDecrease.ExpireTime = Game.Time + 2500
						vars.PartyArmorDecrease.Power = 20
					else
						vars.PartyArmorDecrease.ExpireTime = Game.Time + 2500
						vars.PartyArmorDecrease.Power = vars.PartyArmorDecrease.Power + 20
					end
				end,
			}
			if spellEffect[spellId] then
				spellEffect[spellId]()
			end
			t.Handled = true
		end
		if (not attacker.Object) or attacker.Object.Spell == 0 then
			if attacker.Monster.Bonus > 0 then
				local DoBadThing = false
				if math.random(1,100) <= attacker.Monster.BonusMul * 5 or attacker.Monster.Bonus == const.MonsterBonus.Drainsp then
					DoBadThing = true
				end
				--[[
				if Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].ExpireTime > Game.Time then
					if Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].Power >= attacker.Monster.BonusMul then
						DoBadThing = false
					end
					Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].Power = math.max(0, Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].Power - attacker.Monster.BonusMul)
					if Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].Power == 0 then
						Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].ExpireTime = Game.Time
					end
				end
				]]--
				if DoBadThing == true then
					--t.Player:DoBadThing(attacker.Monster.Bonus, Monster)
					if attacker.Monster.Bonus == const.MonsterBonus.Poison1 then
						evt[t.PlayerSlot].Set("Poison1",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Poison2 then
						evt[t.PlayerSlot].Set("Poison2",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Poison3 then
						evt[t.PlayerSlot].Set("Poison3",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Disease1 then
						evt[t.PlayerSlot].Set("Disease1",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Disease2 then
						evt[t.PlayerSlot].Set("Disease2",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Disease3 then
						evt[t.PlayerSlot].Set("Disease3",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Paralyze then
						evt[t.PlayerSlot].Set("Paralyzed",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Stone then
						evt[t.PlayerSlot].Set("Stoned",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Drainsp then
						t.Player.SP = math.max(0, t.Player.SP - t.Player:GetFullSP() * 0.01 * attacker.Monster.BonusMul)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Afraid then
						evt[t.PlayerSlot].Set("Afraid",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Insane then
						evt[t.PlayerSlot].Set("Insane",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Curse then
						evt[t.PlayerSlot].Set("Cursed",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Weak then
						evt[t.PlayerSlot].Set("Weak",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Dead then
						evt[t.PlayerSlot].Set("Dead",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Errad then
						evt[t.PlayerSlot].Set("Eradicated",1)
					elseif attacker.Monster.Bonus == const.MonsterBonus.Uncon then
						evt[t.PlayerSlot].Set("Unconscious",1)
					end
				end
			end
		end
	elseif (not attacker.Player) and attacker.Object and attacker.Object.Spell ~= 0 then
		if attacker.Object.SpellSkill > 0 then
			attacker.Object.SpellSkill = JoinSkill(999,4)
		end
	end
	
end

---------------------------------

function events.ExitMapAction(t) --��ֹ�ڸ����й�ʱ������ 
	--Stp = false
	--Spd = 1
	if (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) then
		for i = 0, Party.length - 1 do
			Party[i].HP = -1000
		end
	end
end


---------------------------------

function CalcRealDamageM(Damage, DamageKind, ByPlayer, Player, Monster)
	-- if Damage > 0 then
	-- 	Message(tostring(Damage).." "..tostring(DamageKind).." "..tostring(ByPlayer).." "..tostring(Player).." "..tostring(Monster))
	-- end
	-- Player stats and modifiers
	local PlayerGlobalDamageMul = 1
	local PlayerMagicDamageMul = 1
	local PlayerPhysDamageMul = 1
	
	if ByPlayer then
		nt = Player:GetIntellect()
		
		PlayerMagicDamageMul = PlayerMagicDamageMul * (1.0 + nt / 100.0)
		
		if Player.SpellBuffs[const.PlayerBuff.Bless].ExpireTime > Game.Time then
			PlayerGlobalDamageMul = PlayerGlobalDamageMul * 1.05
		end

		if Player.Afraid ~= 0 then
			PlayerGlobalDamageMul = PlayerGlobalDamageMul * 0.6
		end

		if Player.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime > Game.Time then
			PlayerMagicDamageMul = PlayerMagicDamageMul * (1.0 + Player.SpellBuffs[const.PlayerBuff.Glamour].Power / 1000.0)
		end
		if Player.Class >= 108 and Player.Class <= 119 then
			local sk, mas = SplitSkill(Player:GetSkill(const.Skills.Stealing))
			PlayerMagicDamageMul = PlayerMagicDamageMul * (1.0 + (mas * 5 + sk) / 100.0)
		end
		if Player.Face == 20 or Player.Face == 21 then
			PlayerPhysDamageMul = PlayerPhysDamageMul * 1.3
		elseif Player.Face == 26 or Player.Face == 27 then
			PlayerMagicDamageMul = PlayerMagicDamageMul * LichIncreaseConstant
		end
		if Player.SpellBuffs[const.PlayerBuff.TempAccuracy].ExpireTime > Game.Time then
			PlayerPhysDamageMul = PlayerPhysDamageMul * 0.6
		end
	end
	
	-- Monster buffs
	local MonsterGlobalDamageRed = 1
	local MonsterMagicDamageRed = 1
	local MonsterPhysDamageRed = 1
	
	if Monster.SpellBuffs[const.MonsterBuff.DayOfProtection].ExpireTime >= Game.Time then
		MonsterMagicDamageRed = MonsterMagicDamageRed * 0.5
	end
	if Monster.SpellBuffs[const.MonsterBuff.StoneSkin].ExpireTime >= Game.Time then
		MonsterPhysDamageRed = MonsterPhysDamageRed * 0.5
	end
	if Monster.SpellBuffs[const.MonsterBuff.HourOfPower].ExpireTime >= Game.Time then
		local red = (Monster.SpellBuffs[const.MonsterBuff.HourOfPower].Skill == 4) and 0.5 or 0.75
		MonsterGlobalDamageRed = MonsterGlobalDamageRed * red
	end
	if Monster.SpellBuffs[const.MonsterBuff.Shield].ExpireTime >= Game.Time then
		MonsterGlobalDamageRed = MonsterGlobalDamageRed * 0.9
	end
	
	-- Damage calculation
	
	if DamageKind == const.Damage.Phys then
		resistance = math.max(0, Monster.ArmorClass)
		if Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].ExpireTime > Game.Time then
			resistance = resistance - (Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].Skill >= 5 and 
				Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].Skill or 15)
		end
		if Monster.SpellBuffs[const.MonsterBuff.Hammerhands].ExpireTime > Game.Time then
			resistance = resistance - math.min(Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power * 0.002, 1)
		end
		resistance = resistance + Monster.PhysResistance
		
		if Monster.PhysResistance > 10000 then
			return 0
		end

		Damage = Damage * PlayerPhysDamageMul * MonsterPhysDamageRed / (1.0 + resistance / 100.0)
	else
		-- Magic damage types use the same calculation pattern
		local resistanceMap = {
			[const.Damage.Fire] = Monster.FireResistance,
			[const.Damage.Air] = Monster.AirResistance,
			[const.Damage.Water] = Monster.WaterResistance,
			[const.Damage.Earth] = Monster.EarthResistance,
			[const.Damage.Mind] = Monster.MindResistance,
			[const.Damage.Body] = Monster.BodyResistance,
			[const.Damage.Spirit] = Monster.SpiritResistance,
			[const.Damage.Light] = Monster.LightResistance,
			[const.Damage.Dark] = Monster.DarkResistance,
		}
		
		if resistanceMap[DamageKind] then
			resistance = resistanceMap[DamageKind]

			if Monster.SpellBuffs[const.MonsterBuff.Fate].ExpireTime > Game.Time then
				resistance = resistance - math.min(Monster.SpellBuffs[const.MonsterBuff.Fate].Power * 0.002, 1)
			end

			if resistance > 10000 then
				return 0
			end
			Damage = Damage * PlayerMagicDamageMul * MonsterMagicDamageRed / (1.0 + resistance / 100.0)
		end
	end
	
	return math.ceil(Damage * PlayerGlobalDamageMul * MonsterGlobalDamageRed)
end

---------------------------------

local function CalcRealDamage(Player,Damage,DamageKind)
	-- Message(tostring(Damage).." "..tostring(DamageKind))
	if vars.Invincible and vars.Invincible > Game.Time then
		return 0
	end

	-----------Monster Buffs------------

	if vars.MonsterDamageModified and vars.MonsterDamageModified >= Game.Time then
		Damage = Damage * vars.MonsterDamageMul
	end

	-----------Afraid------------

	--if Player.Insane ~= 0 then
	--	Damage = Damage * 3
	--end
	if Player.Afraid ~= 0 then
		Damage = Damage * 1.5
	end

	-----------Armor Special------------

	local it = Player:GetActiveItem(const.ItemSlot.Armor)
	local it2 = Player:GetActiveItem(const.ItemSlot.ExtraHand)
	if it and it:T().Skill == const.Skills.Leather then
		local sk1, mas1 = SplitSkill(Player:GetSkill(const.Skills.Leather))
		if mas1 == const.GM and DamageKind ~= const.Damage.Phys then
			Damage = Damage * 0.67
		end
	elseif it and it:T().Skill == const.Skills.Chain then
		local sk2, mas2 = SplitSkill(Player:GetSkill(const.Skills.Chain))
		if mas2 == const.GM then
			Damage = Damage * 0.67
		end
	elseif it and it:T().Skill == const.Skills.Plate then
		local sk3, mas3 = SplitSkill(Player:GetSkill(const.Skills.Plate))
		if mas3 >= const.Master then
			Damage = Damage * 0.5
			--Message("Detected!")
		end
		if mas3 == const.GM then
			local isrunning = (vars.PartySpeed and vars.PartySpeed >= 28)
			if isrunning then
				Damage = Damage * 0.25
			end
		end
	end

	-----------Stats------------

	local BolsterMul = Game.BolsterAmount / 100
	local ar= Player:GetArmorClass()
	--Message(tostring(ar).." "..tostring(en).." "..tostring(Damage).." "..tostring(DamageKind))
	local res = 0
	local tpl = GetPlayerId(Player)
	if DamageKind <= 5 or DamageKind == 7 or DamageKind == 8 then
		if vars.PlayerResistances then
			if vars.PlayerResistances[tpl] then
				if vars.PlayerResistances[tpl][DamageKind] then
					res = vars.PlayerResistances[tpl][DamageKind]
				end
			end
		end
	--	if Player.Resistances[DamageKind].Custom then
	--		tmp = Player.Resistances[DamageKind].Custom
	--	end
	elseif DamageKind == 6 or DamageKind == 9 or DamageKind == 10 then
		res = Player:GetLuck()
	end

	if Player.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime > Game.Time then
		res = res + Player.SpellBuffs[const.PlayerBuff.Glamour].Power / 10
	end

	--Message(tostring(tmp))
	if DamageKind == const.Damage.Phys then
		if Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime >= Game.Time then
			Player.SpellBuffs[const.PlayerBuff.Misform].Power = Player.SpellBuffs[const.PlayerBuff.Misform].Power + 1
			if Player.SpellBuffs[const.PlayerBuff.Misform].Power == 2 then
				Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime = Game.Time
			end
			return 0
		else
			return math.ceil(Damage / (1.0 + ar / 100.0))
		end
	else
		return math.ceil(Damage / (1.0 + res / 100.0))
	end

end

---------------------------------

function events.MonsterAttacked(t,attacker) --���ﱻ���� 
	if t.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].ExpireTime > Game.Time and t.Monster.SpellBuffs[const.MonsterBuff.ShrinkingRay].Power > 10 then
		if math.random(1,5) >= 2 then
			t.Handled = true
			return
		end
	end
	if attacker.MonsterIndex then
		vars.PlayerAttackTime = Game.Time
		--vars.LastCastSpell = Game.Time
		if t.Monster.Active == true then
			if attacker.Object and attacker.Object.Spell ~= 0 then
				local sk,mas = SplitSkill(attacker.Object.SpellSkill)
				local spell = attacker.Object.Spell
				local dmg = sk * MonsterSpellDamage[spell] * (0.9 + math.random() * 0.2)
				if t.Monster.PhysResistance < 10000 then
					dmg = dmg * (0.99 ^ t.Monster.PhysResistance)
				end
				DamageMonster(t.Monster, dmg, true, attacker.Monster, nil)
			else
				local dmg = attacker.Monster.Attack1.DamageDiceSides * attacker.Monster.Attack1.DamageDiceCount * 0.5 * math.random(40,60) / 50
				if t.Monster.PhysResistance < 10000 then
					dmg = dmg * (0.99 ^ t.Monster.PhysResistance)
				end
				DamageMonster(t.Monster, dmg, true, attacker.Monster, nil)
			end
		else
			if attacker.Monster.Id == 97 or attacker.Monster.Id == 98 or attacker.Monster.Id == 99 or attacker.Monster.Ally == 9999 or attacker.Monster.SpellBuffs[const.MonsterBuff.Enslave].ExpireTime > Game.Time or attacker.Monster.SpellBuffs[const.MonsterBuff.Berserk].ExpireTime > Game.Time then
				attacker.Monster.HP = 0
			end
		end
		if attacker.Monster.Id == 97 or attacker.Monster.Id == 98 or attacker.Monster.Id == 99 or attacker.Monster.Ally == 9999 or attacker.Monster.SpellBuffs[const.MonsterBuff.Enslave].ExpireTime > Game.Time or attacker.Monster.SpellBuffs[const.MonsterBuff.Berserk].ExpireTime > Game.Time then
			if attacker.Monster.ShowHostile ~= true and GetDist(t.Monster,Party) >= 10000 then
				attacker.Monster.HP = 0
			end
		end
		if (t.Monster.SpellBuffs[const.MonsterBuff.Summoned].ExpireTime >= Game.Time and (t.Monster.Id == 97 or t.Monster.Id == 98 or t.Monster.Id == 99)) or (t.Monster.Ally == 9999 and t.Monster.ShowAsHostile == false) then
			vars.MonsterAttackTime = Game.Time
			vars.LastCastSpell = Game.Time
			vars.StuckDetected = 0
		end
		t.Handled = true
	else
		if attacker.PlayerIndex then
			vars.PlayerAttackTime = Game.Time
			vars.LastCastSpell = Game.Time
			if t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].ExpireTime > 0 then
				local tmptime = t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].ExpireTime
				t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].ExpireTime = 0
				Sleep(1)
				if t.Monster.HP > 0 then
					t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].ExpireTime = tmptime
				end
			end
		end
		if attacker.Object and attacker.Player then
			--Message(tostring(attacker.Object.Spell))
			vars.PlayerAttackTime = Game.Time
			vars.LastCastSpell = Game.Time

			-- Deal with Bow
			if attacker.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime < Game.Time then
				--Message(tostring(attacker.Object.Spell))
				if attacker.Object.Spell == 133 then
					t.Handled = true
					-- ConsumeStamina(STAMINA_SHOOT_COST)
					if t.Monster.SpellBuffs[const.MonsterBuff.Shield].ExpireTime > Game.Time and t.Monster.SpellBuffs[const.MonsterBuff.Shield].Skill == 4 then
						if math.random(1,5) >= 2 then
							return
						end
					end
					local baseDmg = math.random(attacker.Player:GetRangedDamageMin(), attacker.Player:GetRangedDamageMax())
					local _, mast = SplitSkill(attacker.Player:GetSkill(const.Skills.Bow))
					local addRaw, addKind = nil, nil
					if mast == const.GM then
						local elemList = {
							{CalcBowDmgPhysAdd(attacker.Player), const.Damage.Phys},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Fire), const.Damage.Fire},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Air), const.Damage.Air},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Water), const.Damage.Water},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Earth), const.Damage.Earth},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Spirit), const.Damage.Spirit},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Mind), const.Damage.Mind},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Body), const.Damage.Body},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Dark), const.Damage.Dark},
							{CalcBowDmgMagicAdd(attacker.Player, const.Skills.Light), const.Damage.Light},
						}
						local maxDmg = 0
						for _, e in ipairs(elemList) do
							local d = CalcRealDamageM(e[1], e[2], true, attacker.Player, t.Monster)
							if d > maxDmg then
								maxDmg = d
								addRaw, addKind = e[1], e[2]
							end
						end
						if maxDmg == 0 then
							addRaw, addKind = nil, nil
						end
					end
					DamageMonster(t.Monster, baseDmg, true, attacker.Player, const.Damage.Phys, addRaw, addKind)
				end
			end
			--Other Spells
			t.Handled = true
			-- 优先使用 SpellDamageAdjust 中的 SpellDamageDescriptionFormulas 计算伤害并调用 DamageMonster
			if SpellPowerFormulas and SpellPowerFormulas[attacker.Object.Spell] then
				local cfg = SpellPowerFormulas[attacker.Object.Spell]
				local rawDmg = getDamageValue(attacker.Player, cfg)
				if rawDmg ~= nil then
					local st = Game.SpellsTxt[attacker.Object.Spell]
					local dmgKind = (st and st.DamageType ~= nil) and st.DamageType or const.Damage.Phys
					DamageMonster(t.Monster, rawDmg, true, attacker.Player, dmgKind)
				end
			end
			-- 使用 SpellDamageAdjust 中的 SpellSpecialEffects 处理特殊法术效果
			if SpellSpecialEffects and SpellSpecialEffects[attacker.Object.Spell] then
				SpellSpecialEffects[attacker.Object.Spell](t, attacker)
			end
			
		end
		if attacker.PlayerIndex and not attacker.Object then
			t.Handled = true
			if vars.CharacterOptions and vars.CharacterOptions[GetPlayerId(attacker.Player)] and vars.CharacterOptions[GetPlayerId(attacker.Player)].DisableAttack then
				Game.ShowStatusText(string.format("%s takes defense action.", attacker.Player.Name), 2)
				attacker.Player.AttackRecovery = 80
				return
			end
			if attacker.Player.SpellBuffs[const.PlayerBuff.Misform].ExpireTime < Game.Time then
				ConsumeStaminaForSlot(GetPlayerId(attacker.Player), STAMINA_ATTACK_COST)
				local it = attacker.Player:GetActiveItem(const.ItemSlot.MainHand)
				local physdmg = math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax())
				if it and it:T().Skill == const.Skills.Dagger then
					local sk,mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Dagger))
					local FireCriticalStreakBonus = 0
					if attacker.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime > Game.Time then
						FireCriticalStreakBonus = 15
					end
					if mas == const.GM and (math.random(1,100) <= sk + FireCriticalStreakBonus or (attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time and vars.HammerhandDamageType == const.Damage.Fire)) then
						if it.Number == 569 then
							physdmg = physdmg * 4.5
						else
							physdmg = physdmg * 3
						end
						--attacker.Player.HP = math.min(attacker.Player:GetFullHP(), attacker.Player.HP + dmg * 0.25)
					end
				elseif it and it:T().Skill == const.Skills.Axe then
					local sk,mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Axe))
					if mas == const.GM then
						if t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].ExpireTime < Game.Time then
							t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].ExpireTime = Game.Time + const.Day
							Game.ShowMonsterBuffAnim(t.MonsterIndex)
						else
							t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].ExpireTime = Game.Time + const.Day
						end
						t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].Skill = 25
						if attacker.Player.Class >= 52 and attacker.Player.Class <= 59 then -- Minotaurs
							local sk,mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Stealing))
							t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].Skill = t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].Skill + (mas * 5 + sk) * 0.5
						end
					end
					-- if it.Number == 1309 then
					-- 	dmg = CalcRealDamageM(math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax()), const.Damage.Phys, true, attacker.Player, t.Monster) + CalcRealDamageM(math.random(3,18), const.Damage.Fire, true, attacker.Player, t.Monster)
					-- 	dmg = math.min(dmg, t.Monster.HP)
					-- 	--Message(tostring(dmg))
					-- 	attacker.Player.HP = math.min(attacker.Player:GetFullHP(), attacker.Player.HP + dmg * 0.4)
					-- 	dmg = 0
					-- end
				elseif it and it:T().Skill == const.Skills.Mace then
					local sk, mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Mace))
					if mas == 3 then
						if 10 >= math.random(1,100) then
							physdmg = physdmg + t.Monster.FullHP * 0.2
						end
					elseif mas == 4 then
						if 10 >= math.random(1,100) then
							for i,v in Map.Monsters do
								if v~=t.Monster and GetDist(t.Monster,v) <= 512 and v.HP > 0 then
									local tmpdmg = v.FullHP * 0.2
									if (attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time and vars.HammerhandDamageType == const.Damage.Earth) then
										tmpdmg = tmpdmg * 2
									end
									DamageMonster(v, tmpdmg, true, attacker.Player, const.Damage.Phys)
								end
							end
							physdmg = physdmg + t.Monster.FullHP * 0.2
						end
					end
				elseif it and it:T().Skill == const.Skills.Staff then
					local sk, mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Staff))
					if mas >= 3 then
						if sk >= math.random(1,1000) and t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime < Game.Time then
							t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime = Game.Time + const.Minute
							t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].Power = 1
						end
						if t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime >= Game.Time then
							physdmg = physdmg * 1.5
						end
					end
				elseif it and it:T().Skill == const.Skills.Spear then
					local sk,mas = SplitSkill(attacker.Player:GetSkill(const.Skills.Spear))
					local function get_line_dist(Party, mon1, mon2, min_error)
						local x1,y1,z1 = XYZ(Party)
						local x2,y2,z2 = XYZ(mon1)
						local x3,y3,z3 = XYZ(mon2)
						local disa = ((x2-x1) ^ 2 + (y2-y1) ^ 2 + (z2-z1) ^ 2) ^ 0.5
						local disb = ((x3-x1) ^ 2 + (y3-y1) ^ 2 + (z3-z1) ^ 2) ^ 0.5
						local disc = ((x3-x2) ^ 2 + (y3-y2) ^ 2 + (z3-z2) ^ 2) ^ 0.5
						local half_p = (disa + disb + disc) / 2
						local AreaS = ((half_p - disa) * (half_p - disb) * (half_p - disc) * half_p) ^ 0.5
						local dish = AreaS * 2 / disa
						if dish < min_error and (disa ^ 2 + disb ^ 2 > disc ^ 2) then
							return (disb ^ 2 - dish ^ 2) ^ 0.5
						else
							return 99999
						end
					end
					if mas >= 2 and mas <= 3 then
						local mindist = 10000
						local mindistmon = nil
						for i,v in Map.Monsters do
							if v ~= t.Monster then
								local tmpdist = get_line_dist(Party, t.Monster, v, 50) 
								if tmpdist < mindist then
									mindist = tmpdist
									mindistmon = v
								end
							end
						end
						if mindist <= 300 then
							DamageMonster(mindistmon, physdmg, true, attacker.Player, const.Damage.Phys)
						end
					elseif mas == 4 then
						local mindist = 10000
						local secmindist = 10000
						local mindistmon = nil
						local secmindistmon = nil
						for i,v in Map.Monsters do
							if v ~= t.Monster then
								local tmpdist = get_line_dist(Party, t.Monster, v, 50) 
								if tmpdist < mindist then
									secmindist = mindist
									secmindistmon = mindistmon
									mindist = tmpdist
									mindistmon = v
								elseif tmpdist < secmindist then
									secmindist = tmpdist
									secmindistmon = v
								end
							end
						end
						if mindist <= 600 then
							if attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time and vars.HammerhandDamageType == const.Damage.Water then
								mindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Power = math.max(mindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Power, 50)
								mindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime = Game.Time + const.Minute * 15
								mindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Skill = 5
							end
							DamageMonster(mindistmon, physdmg, true, attacker.Player, const.Damage.Phys)
						end
						if secmindist <= 600 then
							if attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time and vars.HammerhandDamageType == const.Damage.Water then
								secmindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Power = math.max(secmindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Power, 50)
								secmindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime = Game.Time + const.Minute * 15
								secmindistmon.SpellBuffs[const.MonsterBuff.DamageHalved].Skill = 5
							end
							DamageMonster(secmindistmon, physdmg, true, attacker.Player, const.Damage.Phys)
						end
					end
				elseif (not it) then
					if attacker.Player.Class >= 28 and attacker.Player.Class <= 35 then --Dragon
						--Message(tostring(dmg).." Melee")
						local dmg = physdmg
						physdmg = 0
						DamageMonster(t.Monster, dmg, true, attacker.Player, vars.HammerhandDamageType)
					else
						if attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time then
							--attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = 10
							magic_dmg = physdmg * 0.5
							DamageMonster(t.Monster, magic_dmg, true, attacker.Player, (vars.HammerhandDamageType or const.Damage.Body))
							--attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill - 1
						end
					end
				end
				DamageMonster(t.Monster, physdmg, true, attacker.Player, const.Damage.Phys)
				if it and (it:T().Skill == const.Skills.Sword or it:T().Skill == const.Skills.Dagger or it:T().Skill == const.Skills.Axe or it:T().Skill == const.Skills.Staff or it:T().Skill == const.Skills.Spear or it:T().Skill == const.Skills.Mace) then
					local sk,mas = SplitSkill(attacker.Player:GetSkill(it:T().Skill))
					if mas == const.GM and attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 and attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime < Game.Time then
						--[[
						if it:T().Skill == const.Skills.Staff then
							local dmg1 = CalcRealDamageM(math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax()), (vars.HammerhandDamageType or const.Damage.Body), true, attacker.Player, t.Monster) * (0.1 + attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Power * 0.0025)
							DamageMonster(t.Monster, dmg1, false, attacker.Player, nil)
							attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill - 1
							dmg = dmg + dmg1
						else
							local dmg1 = CalcRealDamageM(math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax()), (vars.HammerhandDamageType or const.Damage.Body), true, attacker.Player, t.Monster) * (0.04 + attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Power * 0.001)
							DamageMonster(t.Monster, dmg1, false, attacker.Player, nil)
							attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill - 1
							dmg = dmg + dmg1
						end
						]]--
						if vars.HammerhandDamageType == const.Damage.Fire then
							--[[
							local mul = 4
							if vars.MeleeDelay and vars.MeleeDelay[attacker.Player:GetIndex()] then
								mul = 1500 / vars.MeleeDelay[attacker.Player:GetIndex()]
							end
							local dmg1 = CalcRealDamageM(math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax()), const.Damage.Phys, true, attacker.Player, t.Monster) * (mul - 1) + dmg * (mul - 1)
							DamageMonster(t.Monster, dmg1, false, attacker.Player, nil)
							attacker.Player.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = 0
							dmg = dmg + dmg1
							]]--
							if t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].ExpireTime < Game.Time then
								t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].ExpireTime = Game.Time + const.Minute * 10
								t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power = 50
							else
								t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power = t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power + 50
							end
							
							attacker.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime = Game.Time + const.Minute * 10
							attacker.Player.SpellBuffs[const.PlayerBuff.TempMight].Power = 0
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 10
						elseif vars.HammerhandDamageType == const.Damage.Water then
							t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Power = math.max(t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Power, 50)
							t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].ExpireTime = Game.Time + const.Minute * 15
							t.Monster.SpellBuffs[const.MonsterBuff.DamageHalved].Skill = 5
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 10
						elseif vars.HammerhandDamageType == const.Damage.Air then
							--vars.AirShotBuffTime = Game.Time + const.Minute * 10
							--vars.AirShotBuffPower = math.max(vars.AirShotBuffPower or 0, 20)
							--if it:T().Skill == const.Skills.Sword then
							--	vars.AirShotBuffPower = math.max(vars.AirShotBuffPower, 40)
							--end
							for i,v in Party do
								v.SpellBuffs[const.PlayerBuff.TempAccuracy].ExpireTime = Game.Time + const.Minute * 10
							end
							if it:T().Skill == const.Skills.Sword then
								CastSpellDirect(125, 7, 3)
								Sleep(5)
								CastSpellDirect(125, 7, 3)
								Sleep(5)
								CastSpellDirect(125, 7, 3)
								Sleep(5)
								CastSpellDirect(125, 7, 3)
								Sleep(5)
								CastSpellDirect(125, 7, 3)
							end
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 30
						elseif vars.HammerhandDamageType == const.Damage.Earth then
							--[[
							t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime = Game.Time + const.Minute * 6
							t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].Power = 1
							if it:T().Skill == const.Skills.Mace then
								for i,v in Map.Monsters do
									if GetDist(t.Monster,v) <= 250 and v ~= t.Monster and v.HP > 0 then
										v.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime = Game.Time + const.Minute
										v.SpellBuffs[const.MonsterBuff.Paralyze].Power = 1
									end
								end
							end
							]]--
							for i,v in Map.Monsters do
								if GetDist(t.Monster,v) <= 512 and v.HP > 0 then
									v.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime = Game.Time + const.Minute * 2
									v.SpellBuffs[const.MonsterBuff.Paralyze].Power = 1
								end
							end
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 20
							
						elseif vars.HammerhandDamageType == const.Damage.Mind then
							t.Monster.SpellBuffs[const.MonsterBuff.MeleeOnly].ExpireTime = Game.Time + const.Minute * 10
							if it:T().Skill == const.Skills.Staff then
								t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].ExpireTime = Game.Time + const.Minute / 64
								t.Monster.SpellBuffs[const.MonsterBuff.Paralyze].Power = 1
								t.Monster.AIState = const.AIState.Stunned
								t.Monster.SpellBuffs[const.MonsterBuff.Fear].ExpireTime = Game.Time + const.Minute * 2
								t.Monster.SpellBuffs[const.MonsterBuff.Fear].Power = 1
							end
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 20
						elseif vars.HammerhandDamageType == const.Damage.Body and attacker.Player.SpellBuffs[const.PlayerBuff.TempSpeed].ExpireTime < Game.Time then
							--[[
							local mul = 4
							if vars.MeleeDelay and vars.MeleeDelay[attacker.Player:GetIndex()] then
								mul = 750 / vars.MeleeDelay[attacker.Player:GetIndex()]
							end
							if it:T().Skill == const.Skills.Axe then
								mul = mul * 1.5
							end
							local dmg1 = CalcRealDamageM(math.random(attacker.Player:GetMeleeDamageMin(),attacker.Player:GetMeleeDamageMax()), const.Damage.Phys, true, attacker.Player, t.Monster) * mul
							DamageMonster(t.Monster, dmg1, false, attacker.Player, nil)
							attacker.Player.HP = math.min(attacker.Player.HP + dmg1, attacker.Player:GetFullHP())
							dmg = dmg + dmg1
							]]--
							local regen_HP = attacker.Player:GetFullHP() - attacker.Player.HP
							attacker.Player.HP = attacker.Player:GetFullHP()
							attacker.Player.SpellBuffs[const.PlayerBuff.TempSpeed].ExpireTime = Game.Time + const.Hour
							attacker.Player.SpellBuffs[const.PlayerBuff.TempSpeed].Power = regen_HP / 60 / 4
							if it:T().Skill == const.Skills.Axe then
								attacker.Player.SpellBuffs[const.PlayerBuff.TempSpeed].Skill = 1
							else
								attacker.Player.SpellBuffs[const.PlayerBuff.TempSpeed].Skill = 0
							end
							attacker.Player.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = Game.Time + const.Minute * 10
						end
						for i,pl in Party do
							local pl_it = pl:GetActiveItem(const.ItemSlot.MainHand)
							if pl_it then
								pl.SpellBuffs[const.PlayerBuff.Hammerhands].Skill = 0
							end
						end
						
					end
				end
				-- PrintDamageAdd(dmg)
			end
		end
	end
	--Sleep(1)
	t.Monster.SpellBuffs[const.MonsterBuff.Stoned].ExpireTime = 0
end
---------------------------------
--[[
function events.Regeneration(t) --��Ѫ���� 
	local sk,mas = SplitSkill(t.Player.Skills[const.Skills.Regeneration])
	t.HP =  - math.ceil((0.005 + sk * mas * 0.001) * t.Player:GetFullHP() + mas)
end
]]--
---------------------------------
--[[
function CalcDamageToPlayerWithPerception(Player, Damage, DamageKind)
	local sk, mas = SplitSkill(Player:GetSkill(const.Skills.Perception))
	--Message(tostring(t.Damage))
	if mas >= const.Expert and Player.Dead == 0 and Player.Unconscious == 0 then
		local p = math.max(0.99 ^ (4 * mas * sk), 0.1)
		local cnt = 0
		local tpl
		for i,pl in Party do
			cnt = cnt + 1
			if pl == Player then
				tpl = i
			end
		end
		if tpl == nil then
			return
		end
		if cnt >= 2 then
			local num = math.random(0,cnt-2)
			if num >= tpl then
				num = num + 1
			end
			Party[num].HP = Party[num].HP - CalcRealDamage(Party[num],Damage,DamageKind) * (1 - p)
			Player.HP = Player.HP - CalcRealDamage(Player,Damage,DamageKind) * p
			--t.Result = CalcRealDamage(Player,Damage,DamageKind) * p
		else
			Player.HP = Player.HP - CalcRealDamage(Player,Damage,DamageKind) * p
		end
	else
		--local tmpppp = CalcRealDamage(Player,Damage,DamageKind)
		--Message(tostring(tmpppp).." "..tostring(Damage).." "..tostring(DamageKind))
		Player.HP = Player.HP - CalcRealDamage(Player,Damage,DamageKind)
		--Result = CalcRealDamage(Player,Damage,DamageKind)
	end
end
]]--

function CalcDamageToPlayerWithPerception(Player, Damage, DamageKind)
	--Message(tostring(Player:GetIndex()).." "..tostring(Damage).." "..tostring(DamageKind))
	--if Damage > 2000 then
	--	Message(tostring(Player:GetIndex()).." "..tostring(Damage).." "..tostring(DamageKind))
	--end
	local sk, mas = SplitSkill(Player:GetSkill(const.Skills.Perception))
	--Message(tostring(t.Damage))
	if mas >= const.Expert and Player.Dead == 0 and Player.Unconscious == 0 then
		local p = math.max(1-(0.05+mas*0.01)*sk, 0.1)
		local cnt = 0
		local maxp = 1
		local prob = {}
		local plst = {}
		for i,pl in Party do
			local sk1,mas1 = SplitSkill(pl:GetSkill(const.Skills.Repair))
			if pl ~= Player and mas1 >= const.Expert and pl.Dead == 0 and pl.Unconscious == 0 then
				cnt = cnt + 1
				prob[cnt] = math.min((0.015+mas1*0.0025)*sk1, 0.25)
				plst[cnt] = pl
				maxp = maxp - prob[cnt]
			end
		end
		if cnt >= 1 then
			--Message(tostring(p).." "..tostring(maxp).." "..tostring(cnt).." ["..tostring(prob[1]).." "..tostring(prob[2]).." "..tostring(prob[3]).." "..tostring(prob[4]).."]")
			local sprob = {prob[1]}
			for i = 2,cnt do
				sprob[i] = prob[i] + sprob[i-1]
			end
			for i = 1,cnt do
				sprob[i] = sprob[i] * 30000 / sprob[cnt]
			end
			local respl = math.random(0,29999)
			for i = 1,cnt do
				if sprob[i] > respl then
					respl = plst[i]
					break
				end
			end
			--Message(tostring(p).." "..tostring(maxp).." "..tostring(cnt).." ["..tostring(sprob[1]).." "..tostring(sprob[2]).." "..tostring(sprob[3]).." "..tostring(sprob[4]).."]")	
			local pres = math.max(p,maxp)
			--Message(tostring(pres).." "..tostring(1-pres).." "..respl.Name.." helps "..Player.Name.." to avoid damage!")
			Player.HP = Player.HP - CalcRealDamage(Player, Damage * pres, DamageKind)
			respl.HP = respl.HP - CalcRealDamage(respl, Damage * (1-pres), DamageKind)
		else
			Player.HP = Player.HP - CalcRealDamage(Player,Damage,DamageKind)
		end
	else
		--local tmpppp = CalcRealDamage(Player,Damage,DamageKind)
		--Message(tostring(tmpppp).." "..tostring(Damage).." "..tostring(DamageKind))
		Player.HP = Player.HP - CalcRealDamage(Player,Damage,DamageKind)
		--Result = CalcRealDamage(Player,Damage,DamageKind)
	end
end

---------------------------------
function events.CalcDamageToPlayer(t) --��������
	if t.Damage == -12321 then
		t.Result = 0
		return
	end
	--Message(t.Player.Name.." takes "..tostring(t.Damage).." damage")
	t.Result = 0
	if t.Player.SpellBuffs[const.PlayerBuff.PainReflection].ExpireTime >= Game.Time then
		for i,pl in Party do
			pl.SpellBuffs[const.PlayerBuff.PainReflection].Skill = math.max(pl.SpellBuffs[const.PlayerBuff.PainReflection].Skill - 1, 0)
			if pl.SpellBuffs[const.PlayerBuff.PainReflection].Skill == 0 then
				pl.SpellBuffs[const.PlayerBuff.PainReflection].ExpireTime = Game.Time
			end
		end
		local cnt = 0
		for i,pl in Party do
			cnt = cnt + 1
		end
		for _,pl in Party do
			CalcDamageToPlayerWithPerception(pl, t.Damage / cnt * (0.995 ^ (t.Player.SpellBuffs[const.PlayerBuff.PainReflection].Power - 5)), t.DamageKind)
		end
	else
		CalcDamageToPlayerWithPerception(t.Player, t.Damage, t.DamageKind)
	end
--[[
local sk, mas = SplitSkill(t.Player:GetSkill(const.Skills.Perception))
--Message(tostring(t.Damage))
if mas >= const.Expert and t.Player.Dead == 0 and t.Player.Unconscious == 0 then
	local p = math.max(0.99 ^ (4 * mas * sk), 0.2)
	local cnt = 0
	local tpl
	for i,pl in Party do
		cnt = cnt + 1
		if pl == t.Player then
			tpl = i
		end
	end
	if tpl == nil then
		return
	end
	if cnt >= 2 then
		local num = math.random(0,cnt-2)
		if num >= tpl then
			num = num + 1
		end
		Party[num].HP = Party[num].HP - CalcRealDamage(Party[num],t.Damage,t.DamageKind) * (1 - p)
		t.Player.HP = t.Player.HP - CalcRealDamage(t.Player,t.Damage,t.DamageKind) * p
		--t.Result = CalcRealDamage(t.Player,t.Damage,t.DamageKind) * p
	else
		t.Player.HP = t.Player.HP - CalcRealDamage(t.Player,t.Damage,t.DamageKind) * p
	end
else
	--local tmpppp = CalcRealDamage(t.Player,t.Damage,t.DamageKind)
	--Message(tostring(tmpppp).." "..tostring(t.Damage).." "..tostring(t.DamageKind))
	t.Player.HP = t.Player.HP - CalcRealDamage(t.Player,t.Damage,t.DamageKind)
	--t.Result = CalcRealDamage(t.Player,t.Damage,t.DamageKind)
end
]]--
end

---------------------------------

function events.CalcDamageToMonster(t) --�����������
	--Message(tostring(t.Monster.StartX).." "..tostring(t.Monster.StartY).." "..tostring(t.Monster.StartZ))
	--Message(tostring(t.Result))
	if t.Damage == 0 then
		t.Result = 0
	else
		t.Result = CalcRealDamageM(t.Damage,t.DamageKind,t.ByPlayer,t.Player,t.Monster)
		if t.ByPlayer then
			if t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].Power > 0 then
				t.Player.HP = t.Player.HP - t.Result
			end
			if t.Player.Class >= 100 and t.Player.Class <= 107 then
				local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.VampireAbility))
				t.Player.HP = math.min(t.Player:GetFullHP(), t.Player.HP + t.Result * 0.01 * (mas * 5 + sk))
			--elseif t.Player.Class >= 28 and t.Player.Class <= 35 then -- Dragon
			--	t.Result = math.max(t.Result, 1)
			--	if t.DamageKind == const.Damage.Phys then
			--		t.Result = 1
			--	end
			end
			if t.Player.SpellBuffs[const.PlayerBuff.TempSpeed] and t.DamageKind == const.Damage.Phys then   -- Vampiric Attack
				t.Player.HP = math.min(t.Player:GetFullHP(), t.Player.HP + t.Result * 0.5)
			end
			--evt.DamagePlayer(GetPlayerId(t.Player),t.DamageKind,t.Result * (t.Monster.SpellBuffs[const.MonsterBuff.PainReflection].Power * 0.0005 + 0.25))
		end
	end
end
---------------------------------

function events.CalcStatBonusByMagic(t)
	if t.Stat == const.Stats.MeleeAttack then -- AttackBonus is removed (changed to attack rate)
		t.Result = 0
	end
end

function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.MeleeAttack then -- AttackBonus is removed
		t.Result = 0
	end
end

---------------------------------
--[[
function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.MeleeDamageMin and t.Player.Class >= 28 and t.Player.Class <= 35 then -- DragonMelee
		local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.DragonAbility))
		t.Result = sk + 10
	end
end

function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.MeleeDamageMax and t.Player.Class >= 28 and t.Player.Class <= 35 then -- DragonMelee
		local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.DragonAbility))
		t.Result = sk * 10 + 10
	end
end
]]--
---------------------------------

function events.CalcStatBonusByMagic(t)
	if t.Stat == const.Stats.RangedAttack then  -- AttackBonus is removed
		t.Result = 0
	end
end

function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.RangedAttack then -- AttackBonus is removed
		t.Result = 0	
	end
end


---------------------------------

function events.GetResistance(t) --Resistance

	local resistanceData = resistanceMap[t.Resistance]
	local playerBuffs = t.Player.SpellBuffs
    local partyBuffs = Party.SpellBuffs
    if resistanceData then
        local playerResistance = playerBuffs[resistanceData.playerBuff].Power or 0
        local partyResistance = partyBuffs[resistanceData.partyBuff].Power or 0
        t.Result = t.Result - math.min(playerResistance, partyResistance)
    end
	--[[
	if t.Resistance == const.Damage.Fire then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.FireResistance].Power, Party.SpellBuffs[const.PartyBuff.FireResistance].Power)
	elseif t.Resistance == const.Damage.Water then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.WaterResistance].Power, Party.SpellBuffs[const.PartyBuff.WaterResistance].Power)
	elseif t.Resistance == const.Damage.Air then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.AirResistance].Power, Party.SpellBuffs[const.PartyBuff.AirResistance].Power)
	elseif t.Resistance == const.Damage.Earth then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.EarthResistance].Power, Party.SpellBuffs[const.PartyBuff.EarthResistance].Power)
	elseif t.Resistance == const.Damage.Body then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.BodyResistance].Power, Party.SpellBuffs[const.PartyBuff.BodyResistance].Power) 
	elseif t.Resistance == const.Damage.Mind then
		t.Result = t.Result - math.min(t.Player.SpellBuffs[const.PlayerBuff.MindResistance].Power, Party.SpellBuffs[const.PartyBuff.MindResistance].Power) 
	end
	]]--
	local tpl = GetPlayerId(t.Player)
	if vars.PlayerResistances == nil then
		vars.PlayerResistances = {}
	end
	if vars.PlayerResistances[tpl] == nil then
		vars.PlayerResistances[tpl] = {}
	end
	vars.PlayerResistances[tpl][t.Resistance] = t.Result
	--t.Player.Resistances[t.Resistance].Custom = t.Result
	--Message(tostring(t.Result) .. " " .. tostring(t.Resistance))
end


---------------------------------


function events.CalcStatBonusByMagic(t) -- Attribute, Resistance magic bonus
	local stat = t.Stat
    local result = t.Result
    local player = t.Player
    local dayOfGodsPower = Party.SpellBuffs[const.PartyBuff.DayOfGods].Power
    
    if stat >= const.Stats.Might and stat <= const.Stats.Luck then
        local bonusField = statBonusMap[stat]
        if bonusField then
            result = math.max(0, result / 5 - player[bonusField])

            if stat == const.Stats.Luck and vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
                result = result - math.min(vars.PartyResistanceDecrease.Power, 100)
            end
        end
		if player.Class >= 76 and player.Class <= 83 then  --Ranger Bonus
			local sk, mas = SplitSkill(player:GetSkill(const.Skills.Stealing))
			local incre = mas * 0.25 + sk * 0.01
			
			local weapon_sk = SplitSkill(player.Skills[const.Skills.Axe])
			local bow_sk = SplitSkill(player.Skills[const.Skills.Bow])
			local magic_sk = SplitSkill(player.Skills[const.Skills.Fire])
			
			for j = const.Skills.Air, const.Skills.Dark do
				local tmpsk = SplitSkill(player.Skills[j])
				if tmpsk > magic_sk then
					magic_sk = tmpsk
				end
			end
			
			local armor_sk = SplitSkill(player.Skills[const.Skills.Shield])
			for j = const.Skills.Leather, const.Skills.Plate do
				local tmpsk = SplitSkill(player.Skills[j])
				if tmpsk > armor_sk then
					armor_sk = tmpsk
				end
			end
			
			local min_sk = math.min(weapon_sk, bow_sk, magic_sk, armor_sk)
			result = result + math.floor(min_sk * incre)
		end
	elseif stat == const.Stats.ArmorClass then
		local stoneskinPower = math.min(
            Party.SpellBuffs[const.PartyBuff.Stoneskin].Power,
            player.SpellBuffs[const.PlayerBuff.Stoneskin].Power
        )
        result = math.max(0, result - player.ArmorClassBonus - stoneskinPower)
        
        if vars.PartyArmorDecrease.ExpireTime >= Game.Time then
            result = result - math.min(vars.PartyArmorDecrease.Power, 100)
        end
	elseif stat >= const.Stats.FireResistance and stat <= const.Stats.MindResistance then
        local bonusField = statBonusMap[stat]
        if bonusField then
            result = math.max(0, result / 5 - player[bonusField])
            
            if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
                result = result - math.min(vars.PartyResistanceDecrease.Power, 100)
            end
        end
    end

	t.Result = result
--[[
	if t.Stat == const.Stats.Might then
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.MightBonus)
	elseif t.Stat == const.Stats.Intellect then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.IntellectBonus)
	elseif t.Stat == const.Stats.Personality then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.PersonalityBonus)
	elseif t.Stat == const.Stats.Endurance then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.EnduranceBonus)
	elseif t.Stat == const.Stats.Speed then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.SpeedBonus)
	elseif t.Stat == const.Stats.Accuracy then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.AccuracyBonus)
	elseif t.Stat == const.Stats.Luck then 
		t.Result = math.max(0, (t.Result - Party.SpellBuffs[const.PartyBuff.DayOfGods].Power) / 5 - t.Player.LuckBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.ArmorClass then 
		t.Result = math.max(0, t.Result - t.Player.ArmorClassBonus- math.min(Party.SpellBuffs[const.PartyBuff.Stoneskin].Power, t.Player.SpellBuffs[const.PlayerBuff.Stoneskin].Power))
		if vars.PartyArmorDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyArmorDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.FireResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.FireResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.AirResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.AirResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.WaterResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.WaterResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.EarthResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.EarthResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.BodyResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.BodyResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	elseif t.Stat == const.Stats.MindResistance then 
		t.Result = math.max(0, t.Result / 5 - t.Player.MindResistanceBonus)
		if vars.PartyResistanceDecrease.ExpireTime >= Game.Time then
			t.Result = t.Result - math.min(vars.PartyResistanceDecrease.Power, 100)
		end
	end
	if t.Player.Class >= 76 and t.Player.Class <= 83 and t.Stat >= const.Stats.Might and t.Stat <= const.Stats.Luck then -- Ranger Bonus
			
		local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.Stealing))
		local incre = mas * 0.25 + sk * 0.01
		local weapon_sk, weapon_mas = SplitSkill(t.Player.Skills[const.Skills.Axe])
		local bow_sk, bow_mas = SplitSkill(t.Player.Skills[const.Skills.Bow])
		local magic_sk, magic_mas = SplitSkill(t.Player.Skills[const.Skills.Fire])
		for j=const.Skills.Air,const.Skills.Dark do
			local tmpsk,tmpmas = SplitSkill(t.Player.Skills[j])
			if tmpsk > magic_sk then
				magic_sk = tmpsk
			end
		end
		local armor_sk, armor_mas = SplitSkill(t.Player.Skills[const.Skills.Shield])
		for j=const.Skills.Leather,const.Skills.Plate do
			local tmpsk,tmpmas = SplitSkill(t.Player.Skills[j])
			if tmpsk > armor_sk then
				armor_sk = tmpsk
			end
		end
		local min_sk = math.min(weapon_sk, bow_sk, magic_sk, armor_sk)
		
		t.Result = t.Result + math.floor(min_sk * incre)
	end
]]--
end


---------------------------------



function events.CalcStatBonusBySkills(t)
	if t.Stat == const.Stats.SP then -- SP Bonus
		local nt= t.Player:GetIntellect()
		local pe= t.Player:GetPersonality()
		local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.Meditation))
		local spfactor = Game.Classes.SPFactor[t.Player.Class]
		-- 加上种族 SPFactor 调整（RaceHPSP 里 SPFactor 单位是 0.25，所以 *0.25）
		local raceTbl = MF.GetRaceHPSPTbl and MF.GetRaceHPSPTbl({Race = GetCharRace(t.Player), Class = t.Player.Class})
		if raceTbl and raceTbl.SPFactor then
			spfactor = spfactor + raceTbl.SPFactor * 0.25
		end
		local spbase = Game.Classes.SPBase[t.Player.Class]

		-- Remove original SP bonus by intellect and personality
		local spadj = (CalculateStatAdjustment(nt) + CalculateStatAdjustment(pe)) * spfactor
		t.Result = - spadj
		
		-- -- Adjust Meditation bonus
		t.Result = t.Result + 5 * sk * mas
		
		-- -- Add new SP bonus by ersonality
		t.Result = t.Result + spfactor * t.Player.LevelBase * pe * 0.01 
				 + spbase * 10 * pe * 0.01
				 + spbase * 9
				 + 5 * sk * mas * pe * 0.01
	end
end

---------------------------------

function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.SP then -- SP Bonus
		local pe= t.Player:GetPersonality()
		t.Result = t.Result * 10 * (1 + pe * 0.01)
	end
end

---------------------------------


function events.CalcStatBonusBySkills(t)
	if t.Stat == const.Stats.HP then -- HP Bonus
		local en= t.Player:GetEndurance()
		local sk,mas = SplitSkill(t.Player:GetSkill(const.Skills.Bodybuilding))
		local hpfactor = Game.Classes.HPFactor[t.Player.Class]
		-- 加上种族 HPFactor 调整（RaceHPSP 里 HPFactor 单位是 0.25，所以 *0.25）
		local raceTbl = MF.GetRaceHPSPTbl and MF.GetRaceHPSPTbl({Race = GetCharRace(t.Player), Class = t.Player.Class})
		if raceTbl and raceTbl.HPFactor then
			hpfactor = hpfactor + raceTbl.HPFactor * 0.25
		end
		local hpbase = Game.Classes.HPBase[t.Player.Class]

		-- Remove original HP bonus by endurance
		local hpadj = CalculateStatAdjustment(en) * hpfactor
		t.Result = - hpadj 
		
		-- -- Adjust Bodybuilding bonus
		t.Result = t.Result + hpfactor * sk * mas
		
		-- -- Add new HP bonus by endurance
		t.Result = t.Result + hpfactor * t.Player.LevelBase * en * 0.005 
				 + hpbase * en * 0.005
				 + hpfactor * sk * mas * en * 0.005
	end
end

---------------------------------

function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.HP then -- HP Bonus
		local en= t.Player:GetEndurance()
		t.Result = t.Result * 10 * (1 + en * 0.005)
	end
end

---------------------------------

function events.CalcStatBonusByItems(t)
    -- 如果是抗性属性（10-15对应各种抗性）
    if t.Stat >= 10 and t.Stat <= 15 then
        -- 检查玩家装备中是否有任何抗性bonus
        -- 抗性bonus通常在某个范围内（需要根据实际情况调整）
        local ResistanceBonus = 0
        for i, itemId in t.Player.EquippedItems do
            if itemId > 0 then
                local item = t.Player.Items[itemId]
                if item.Bonus >= 11 and item.Bonus <= 16 and item.Bonus ~= t.Stat + 1 then
                    ResistanceBonus = ResistanceBonus + item.BonusStrength
				elseif item.Bonus >= 12 and item.Bonus <= 16 and item.Bonus == t.Stat + 1 then
					ResistanceBonus = ResistanceBonus - item.BonusStrength
				end
            end
        end
        
        t.Result = t.Result + ResistanceBonus
    end
end

---------------------------------

function events.CalcStatBonusByItems(t)
	if t.Stat >= 10 and t.Stat <= 15 then -- Resistances
		local lu= t.Player:GetBaseLuck()
		local it = t.Player:GetActiveItem(const.ItemSlot.Armor)
		local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
		-- t.Result = t.Result + math.floor(lu * 0.2)
		local baseArmor = 0
		if it then
			local tmpl = it:T()
			baseArmor = (tmpl.Mod1DiceCount or 0) * math.max(1, tmpl.Mod1DiceSides or 1)
		end
		if it and it:T().Skill == const.Skills.Leather then
			local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Leather))
			local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
			t.Result = t.Result + sk1 * 3
			if mas4 == const.GM and not(it2 and it2:T().Skill == const.Skills.Shield) then
				t.Result = t.Result + sk4 * 4
			end
			t.Result = t.Result + math.ceil(baseArmor * 1)
		elseif it and it:T().Skill == const.Skills.Chain then
			local sk2, mas2 = SplitSkill(t.Player:GetSkill(const.Skills.Chain))
			t.Result = t.Result + sk2 * 4
			t.Result = t.Result + math.ceil(baseArmor * 2/3)
		elseif it and it:T().Skill == const.Skills.Plate then
			local sk3, mas3 = SplitSkill(t.Player:GetSkill(const.Skills.Plate))
			t.Result = t.Result + sk3 * 4
			t.Result = t.Result + math.ceil(baseArmor * 1/2)
		else
			local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
			if not(it2 and it2:T().Skill == const.Skills.Shield) then
				t.Result = t.Result + sk4 * 4
			end
		end
		if it2 and it2:T().Skill == const.Skills.Shield then
			local sk, mas = SplitSkill(t.Player:GetSkill(const.Skills.Shield))
			t.Result = t.Result + sk * 3
		end
	end
end

---------------------------------

function events.CalcStatBonusByMagic(t)
	if t.Stat >= 10 and t.Stat <= 13 then -- Resistances
		local it = t.Player:GetActiveItem(const.ItemSlot.Armor)
		if it and it:T().Skill == const.Skills.Leather then
			--local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Leather))
			local sk1, mas1 = SplitSkill(t.Player.Skills[const.Skills.Leather])  --Bug Fixed
			if mas1 == const.GM then
				t.Result = t.Result - sk1
			end
		end
	end
end

---------------------------------

function events.CalcStatBonusBySkills(t)
	if t.Stat == const.Stats.ArmorClass then -- ArmorClass

		local it = t.Player:GetActiveItem(const.ItemSlot.Armor)
		local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
		if it and it:T().Skill == const.Skills.Leather then
			local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Leather))
			local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
			--t.Result = t.Result + sk1
			if mas1 >= const.Master then
				t.Result = t.Result + sk1 * 2
			end
			if mas4 == const.GM and not(it2 and it2:T().Skill == const.Skills.Shield) then
				t.Result = t.Result + sk4
			end
		elseif it and it:T().Skill == const.Skills.Chain then
			local sk2, mas2 = SplitSkill(t.Player:GetSkill(const.Skills.Chain))
			t.Result = t.Result + sk2 * 2
			if mas2 >= const.Master then
				t.Result = t.Result + sk2 * 2
			end
		elseif it and it:T().Skill == const.Skills.Plate then
			local sk3, mas3 = SplitSkill(t.Player:GetSkill(const.Skills.Plate))
			t.Result = t.Result + sk3 * 4
		else
			local sk4, mas4 = SplitSkill(t.Player:GetSkill(const.Skills.Dodging))
			if not(it2 and it2:T().Skill == const.Skills.Shield) then
				--t.Result = t.Result + sk4
				if mas4 == const.Expert then
					t.Result = t.Result + sk4
				end
			end
		end
		if it2 and it2:T().Skill == const.Skills.Shield then
			local sk, mas = SplitSkill(t.Player:GetSkill(const.Skills.Shield))
			t.Result = t.Result + sk * 2
		end

		local aradj = CalculateStatAdjustment(t.Player:GetSpeed())
		t.Result = t.Result - aradj
	end
end

---------------------------------

function CalcDmgByAM(sk,mas)
	if mas <= 2 then
		return sk * mas 
	elseif mas >= 3 then
		return sk * 2
	else
		return 0
	end
end

---------------------------------


local meleeSkills = {
    [const.Skills.Sword]   = {skmul=1.5, expertMult=1.05, masterMult=nil, gmSub=nil,  masterSub=nil,  expertAdd=nil, masterAdd=nil},
    [const.Skills.Dagger]  = {skmul=1.2, expertMult=nil,  masterMult=1.25, gmSub=true, masterSub=nil,  expertAdd=nil, masterAdd=nil},
    [const.Skills.Axe]     = {skmul=1.8, expertMult=nil,  masterMult=1.2,  gmSub=nil,  masterSub=true, expertAdd=0.1, masterAdd=nil},
    [const.Skills.Staff]   = {skmul=1.5, expertMult=nil,  masterMult=nil,  gmSub=nil,  masterSub=nil,  expertAdd=nil, masterAdd=nil, staff=true},
    [const.Skills.Spear]   = {skmul=1.5, expertMult=nil,  masterMult=nil,  gmSub=nil,  masterSub=nil,  expertAdd=nil, masterAdd=nil, spear=true},
    [const.Skills.Mace]    = {skmul=1.5, expertMult=nil,  masterMult=nil,  gmSub=nil,  masterSub=nil,  expertAdd=nil, masterAdd=nil},
	[const.Skills.Unarmed] = {skmul=1.2, expertMult=nil,  masterMult=nil,  gmSub=nil,  masterSub=nil,  expertAdd=nil, masterAdd=nil, unarmed=true},
}

local function isMeleeSkill(skill)
    return meleeSkills[skill] ~= nil
end

local function getDoubleweaponBonus(t, sk1, mas1)
    local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
	if it2 then
		local skillId = it2:T().Skill
		if (skillId == const.Skills.Sword or skillId == const.Skills.Dagger) then
			local sk2, mas2 = SplitSkill(t.Player:GetSkill(it2:T().Skill))
			local params = meleeSkills[skillId]
			local result = sk2*params.skmul
			if params.expertMult and mas2 >= const.Expert then
				result = result * params.expertMult
			end
			if params.masterMult and mas2 >= const.Master then
				result = result * params.masterMult
			end
			return result + sk1 * mas1
		end
	end
    return 0
end

function events.CalcStatBonusBySkills(t)
    -- Unify skill boosting for all party members
    for _, pl in Party do
        local maxsk = 0
        for i, learn in EnumAvailableSkills(pl.Class) do
            if isMeleeSkill(i) then
                local skill = SplitSkill(pl.Skills[i])
                maxsk = math.max(maxsk, skill)
            end
        end
        for i, learn in EnumAvailableSkills(pl.Class) do
            if isMeleeSkill(i) then
                local skill, mastery = SplitSkill(pl.Skills[i])
                if mastery == 0 then mastery = 1 end
                pl.Skills[i] = JoinSkill(maxsk, mastery)
            end
        end
    end

    if t.Stat ~= const.Stats.MeleeDamageBase then return end

    local mainIt = t.Player:GetActiveItem(const.ItemSlot.MainHand)
    local class = t.Player.Class

    -- Unarmed (no weapon in hand)
    if not mainIt then
        -- Only non-dragon classes
        if class < 28 or class > 35 then
            local sk, mas = SplitSkill(t.Player:GetSkill(const.Skills.Unarmed))
            local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Armsmaster))
			local params = meleeSkills[const.Skills.Unarmed]
            if mas == const.GM then
                t.Result = t.Result + sk
            end
            t.Result = t.Result + math.max(0, sk*params.skmul)
            local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
            if not it2 and mas == const.GM then
                -- twohandMight bonus removed
            else
                t.Result = t.Result + getDoubleweaponBonus(t, sk1, mas1)
            end
            if t.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime > Game.Time then
                t.Result = t.Result * FireDamageBonus
            end
            if t.Player.SpellBuffs[const.PlayerBuff.TempSpeed].ExpireTime > Game.Time and t.Player.SpellBuffs[const.PlayerBuff.TempSpeed].Skill == 1 then
                t.Result = t.Result * BodyDamageBonus
            end
        else
            t.Result = 0
        end
        return
    end

    local skillId = mainIt:T().Skill
    if not isMeleeSkill(skillId) then return end

    local params = meleeSkills[skillId]
    local sk, mas = SplitSkill(t.Player:GetSkill(skillId))
    local sk1, mas1 = SplitSkill(t.Player:GetSkill(const.Skills.Armsmaster))

    -- Base calculation
	local result = sk*params.skmul

	-- Staff special: add Unarmed GM bonus
    if params.staff then
        local sk2, mas2 = SplitSkill(t.Player:GetSkill(const.Skills.Unarmed))
        if mas == const.GM and mas2 == const.GM then
            result = result + sk2 * 1
        end
    end

    -- Dagger GM penalty
    if params.gmSub and mas >= const.GM then
        result = result - sk
    end
    -- Axe Master penalty
    if params.masterSub and mas >= const.Master then
        result = result - sk
    end
    -- Axe Expert bonus (might removed)
    -- if params.expertAdd and mas >= const.Expert then
    --     result = result + mi*params.expertAdd
    -- end

    -- Multipliers
    if params.expertMult and mas >= const.Expert then
        result = result * params.expertMult
    end
    if params.masterMult and mas >= const.Master then
        result = result * params.masterMult
    end

	local Armsmaster_bonus = CalcDmgByAM(sk1,mas1) 

    -- two hand weapon handling (might removed)
    if params.twohandMight and mainIt:T().EquipStat == 1 then
        -- twohandMight bonus removed
    elseif params.spear then
        local it2 = t.Player:GetActiveItem(const.ItemSlot.ExtraHand)
        if not it2 then
            -- twohandMight bonus removed
        else
            result = result + getDoubleweaponBonus(t, sk1, mas1)
        end
    else
        result = result + getDoubleweaponBonus(t, sk1, mas1)
    end

	result = result + Armsmaster_bonus

    -- Buffs
    if t.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime > Game.Time then
        result = result * FireDamageBonus
    end
    if t.Player.SpellBuffs[const.PlayerBuff.TempSpeed].ExpireTime > Game.Time and t.Player.SpellBuffs[const.PlayerBuff.TempSpeed].Skill == 1 then
        result = result * BodyDamageBonus
    end

	local might = t.Player:GetMight()
	local might_mul = (100.0 + might) / 100.0
    t.Result = result * might_mul
end

-------------------------------------------------------------------------------
function events.CalcStatBonusByItems(t)
	if t.Stat == const.Stats.MeleeDamageBase then
		if t.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime > Game.Time then
			t.Result = t.Result * FireDamageBonus
		end
	end
	if t.Stat == const.Stats.MeleeDamageMin or t.Stat == const.Stats.MeleeDamageMax then
		local might = t.Player:GetMight()
		local might_mul = (100.0 + might) / 100.0
		t.Result = t.Result * might_mul
		
		-- Apply expertMult and masterMult based on weapon skill
		local mainIt = t.Player:GetActiveItem(const.ItemSlot.MainHand)
		if mainIt and isMeleeSkill(mainIt:T().Skill) then
			local skillId = mainIt:T().Skill
			local params = meleeSkills[skillId]
			local sk, mas = SplitSkill(t.Player:GetSkill(skillId))
			
			if params.expertMult and mas >= const.Expert then
				t.Result = t.Result * params.expertMult
			end
			if params.masterMult and mas >= const.Master then
				t.Result = t.Result * params.masterMult
			end
		end
		
		-- Subtract might adjustment value
		if CalculateStatAdjustment then
			local mi = t.Player:GetMight()
			local miadj = CalculateStatAdjustment(mi)
			t.Result = t.Result - miadj
		end
	end
end

-------------------------------------------------------------------------------
function events.CalcStatBonusByMagic(t)
	if t.Stat == const.Stats.MeleeDamageBase then
		if t.Player.SpellBuffs[const.PlayerBuff.TempMight].ExpireTime > Game.Time then
			t.Result = t.Result * FireDamageBonus
		end
	end
end

-------------------------------------------------------------------------------
function events.CalcStatBonusBySkills(t)
	if t.Stat == const.Stats.RangedDamageBase then
		t.Result = CalcBowBaseDmg(t.Player)
	end
end

-------------------------------------------------------------------------------
function events.CanSaveGame(t)
	if Game.UseMonsterBolster == true and ((vars.LastCastSpell ~= nil and Game.Time - vars.LastCastSpell < const.Minute * 5) or Monsters_prevent_save == true) then
		t.Result = false
		Game.ShowStatusText("You cannot save in combat.")
	end
end

--[[
function events.DoBadThingToPlayer(t)
	t.Allow = false
end
]]--