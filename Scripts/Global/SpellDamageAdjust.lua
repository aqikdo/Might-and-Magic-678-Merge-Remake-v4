local function GenRandom(maxnum)
	res = 0
	for i = 1,10 do
		res = res + math.random(maxnum)
	end
	return res / 10
end

-- ========== 法术描述中按变量显示伤害 ==========
-- 用法：在 SpellDamageDescriptionFormulas 里为法术 ID 配置伤害公式，
-- 打开法术书时会用当前角色的技能计算并显示在描述中（如：火系等级×4，当前: 200）。
local u4 = mem.u4
local DESC_BUF_SIZE = 256
local SPELL_BOOK_SCREEN = 8  -- const.Screens.SpellBook

-- 配置： [法术ID] = 生成“描述用伤害”的方式
-- 方式一：表 { skill = 技能常量, mult = 倍数 } → 显示为 "技能等级×mult (当前: 数值)"
-- 方式二：函数 function(pl) return 数值 end → 描述中显示 "伤害: 数值"
function GetSpellPower(spellId, sk, mas)
	local cfg = SpellPowerFormulas[spellId]
	if type(cfg) == "function" then
		return cfg(sk, mas)
	end
	return math.ceil(sk * cfg.mult + cfg.add)
end

SpellPowerFormulas = {
	[2]  = { skill = const.Skills.Fire , mult = 1.5, add = 4  }, 	-- FireBolt
	[6]  = { skill = const.Skills.Fire , mult = 1.5, add = 6  }, 	-- Fireball
	[7]  = { skill = const.Skills.Fire , mult = 1.0, add = 3  }, 	-- FireSpike
	[8]  = { skill = const.Skills.Fire , mult = 2.0, add = 2  }, 	-- Immolation
	[9]  = { skill = const.Skills.Fire , mult = 1.0, add = 10 }, 	-- Meteor Shower
	[10] = { skill = const.Skills.Fire , mult = 3.0, add = 8  }, 	-- Inferno
	[11] = { skill = const.Skills.Fire , mult = 6.0, add = 16 }, 	-- Incinerate
	[15] = { skill = const.Skills.Air  , mult = 1.5, add = 4  }, 	-- Sparks
	[18] = { skill = const.Skills.Air  , mult = 2.0, add = 5  }, 	-- LightningBolt
	[20] = { skill = const.Skills.Air  , mult = 3.0, add = 8  }, 	-- implosion (plan: aoe small)
	[22] = { skill = const.Skills.Air  , mult = 1.0, add = 20 }, 	-- Starfall
	[24] = { skill = const.Skills.Water, mult = 1.5, add = 4  }, 	-- PoisonSpray
	[26] = { skill = const.Skills.Water, mult = 1.5, add = 4  }, 	-- IceBolt
	[29] = { skill = const.Skills.Water, mult = 3.0, add = 8  }, 	-- AcidBurst (plan: aoe small, reduce, armor)
	[32] = { skill = const.Skills.Water, mult = 1.5, add = 4  }, 	-- IceBlast CURRENT
	[37] = { skill = const.Skills.Earth, mult =12.0, add = 32 }, 	-- DeadlySwarm
	[39] = { skill = const.Skills.Earth, mult = 6.0, add = 16 }, 	-- Blades
	[41] = { skill = const.Skills.Earth, mult = 3.0, add = 8  }, 	-- RockBlast
	[43] = { skill = const.Skills.Earth, mult =10.0, add = 50 }, 	-- DeathBlossom
	[59] = { skill = const.Skills.Mind , mult = 5.0, add = 12 }, 	-- MindBlast
	[65] = { skill = const.Skills.Mind , mult = 8.0, add = 20 }, 	-- PsychicShock
	[68] = { skill = const.Skills.Body , mult = 2.0, add = 2  }, 	-- Heal
	[70] = { skill = const.Skills.Body , mult = 2.0, add = 5  }, 	-- Disruption ray
	[76] = { skill = const.Skills.Body , mult = 6.0, add = 16 }, 	-- Flying Fist
	[78] = { skill = const.Skills.Light, mult = 1.5, add = 4  }, 	-- LightBolt
	[79] = { skill = const.Skills.Light, mult = 6.0, add = 16 }, 	-- DestroyUndead
	[87] = { skill = const.Skills.Light, mult = 8.0, add = 20 }, 	-- Sunray
	[90] = { skill = const.Skills.Dark , mult = 3.0, add = 8  }, 	-- ToxicCloud
	[93] = { skill = const.Skills.Dark , mult = 3.0, add = 8  }, 	-- Sharpmetal
	[97] = { skill = const.Skills.Dark , mult = 4.5, add = 12 }, 	-- DragonBreath
	[99] = { skill = const.Skills.Dark , mult = 1.0, add = 1  }, 	-- Souldrinker
}


SpellSpecialEffects = {
	[39] = function(t, attacker)
		t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved].ExpireTime = Game.Time + const.Day
	end,
	[59] = function(t, attacker)
		local sk, mas = attacker.Object.SpellSkill, attacker.Object.SpellMastery
		if mas >= 4 then
			for _, mon in Map.Monsters do
				if mon ~= t.Monster and GetDist(t.Monster, mon) <= 250 and mon.HP > 0 then
					local dmg = getDamageValue(attacker.Player, SpellPowerFormulas[59])
					DamageMonster(mon, dmg, true, attacker.Player, nil)
				end
			end
		end
	end,
	[26] = function(t, attacker)
		if t.Monster.WaterResistance < 1000 then
			t.Monster.SpellBuffs[const.MonsterBuff.Slow].Power = math.max(t.Monster.SpellBuffs[const.MonsterBuff.Slow].Power, 2)
			t.Monster.SpellBuffs[const.MonsterBuff.Slow].Skill = math.max(t.Monster.SpellBuffs[const.MonsterBuff.Slow].Skill, 1)
			t.Monster.SpellBuffs[const.MonsterBuff.Slow].ExpireTime = Game.Time + const.Minute * 10
		end
	end,
	[70] = function(t, attacker)
		if t.Monster.BodyResistance < 1000 then
			t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power = math.max(t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].Power, attacker.Object.SpellSkill * (4 + attacker.Object.SpellMastery) * 0.5)
			t.Monster.SpellBuffs[const.MonsterBuff.Hammerhands].ExpireTime = Game.Time + const.Minute * attacker.Object.SpellSkill
		end
	end,
	[52] = function(t, attacker)
		local sk, mas = attacker.Object.SpellSkill, attacker.Object.SpellMastery
		if t.Monster.SpiritResistance < 1000 then
			local minhp = t.Monster.FullHP * (0.95 - mas * 0.05)
			if t.Monster.HP > minhp then
				local dmg = math.min(t.Monster.HP - minhp, t.Monster.FullHP * (0.02 + sk * 0.0005))
				t.Monster.HP = t.Monster.HP - dmg
				PrintDamageAdd(dmg)
			end
		end
	end,
	[84] = function(t, attacker)
		local sk, mas = attacker.Object.SpellSkill, attacker.Object.SpellMastery
		t.Monster.SpellBuffs[const.MonsterBuff.Fate].ExpireTime = Game.Time + const.Day
		if t.Monster.SpellBuffs[const.MonsterBuff.Fate].Power then
			t.Monster.SpellBuffs[const.MonsterBuff.Fate].Power = t.Monster.SpellBuffs[const.MonsterBuff.Fate].Power + math.floor(sk * 1.25 + 50)
		else
			t.Monster.SpellBuffs[const.MonsterBuff.Fate].Power = math.floor(sk * 1.25 + 50)
		end
		Game.ShowMonsterBuffAnim(t.MonsterIndex)
		t.Handled = true
	end,
	[const.Spells.Souldrinker] = function(t, attacker)
		if vars.SouldrinkerAttackCount == nil then
			vars.SouldrinkerAttackCount = 0
		end
		vars.SouldrinkerAttackCount = vars.SouldrinkerAttackCount + 1
	end,
	[const.Spells.ShootDragon] = function(t, attacker)
		local sk, mas = SplitSkill(attacker.Player:GetSkill(const.Skills.DragonAbility))
		local dmgmin = sk + 10
		local dmgmax = sk * 10 + 10
		local dmg = math.random(dmgmin, dmgmax)
		if dmg == 0 then
			t.Handled = true
		else
			DamageMonster(t.Monster, dmg, false, attacker.Player, nil)
		end
	end,
	[111] = function(t, attacker)  -- lifedrain bug: 111 instead of 113
		local sk, mas = SplitSkill(attacker.Player:GetSkill(const.Skills.VampireAbility))
		local oridmg = attacker.Player:GetFullHP() * 0.05 * (mas + 1)
		local dmg = CalcRealDamageM(oridmg, const.Damage.Body, true, attacker.Player, t.Monster)
		DamageMonster(t.Monster, dmg, false, attacker.Player, nil)
		local regen = math.round(oridmg / 200)
		for _, pl in Party do
			pl.SpellBuffs[const.PlayerBuff.Regeneration].Power = regen
			pl.SpellBuffs[const.PlayerBuff.Regeneration].ExpireTime = Game.Time + const.Minute * 10
		end
		PrintDamageAdd(dmg)
	end,
}

local originalDescPtrs = {}
local customDescBuffers = {}
local lastInSpellBook = false

function getDamageValue(pl, cfg)
	if type(cfg) == "function" then
		local sk, mas = SplitSkill(pl.Skills[cfg.skill])
		local ok, v = pcall(cfg, pl)
		return ok and v and tonumber(v) or nil
	end
	if type(cfg) == "table" and cfg.skill and cfg.mult and cfg.add and pl and pl.Skills then
		local sk, mas = SplitSkill(pl.Skills[cfg.skill])
		return math.ceil(sk * cfg.mult + cfg.add)
	end
	return nil
end

function events.CalcSpellDamage(t)
	-- 其他法术：保持原有逻辑
	t.Result = 0
	-- if t.Spell == 43 then
	-- 	t.Result = (t.Skill * 20 + 200) * (t.Mastery - 2)
	-- elseif t.Spell == 10 then
	-- 	t.Result = t.Skill * (t.Mastery + 1)
	-- elseif t.Spell == 52 then
	-- 	t.Result = -12321
	-- elseif t.Spell == 15 then
	-- 	t.Result = t.Skill * 2
	-- elseif t.Spell == 111 then
	-- 	--Message(tostring(t.HP))
	-- 	--t.Result = 14 + t.Mastery * 4 + t.Skill * GenRandom(14 + t.Mastery * 4) + t.HP * 0.001 * t.Mastery
	-- 	t.Result = -12321
	-- elseif t.Spell == const.Spells.ShootDragon then
	-- 	t.Result = -12321
	-- elseif t.Spell == const.Spells.Souldrinker then
	-- 	t.Result = t.Skill * 10 + 25
	-- end
end

local function updateSpellBookDescriptions()
	local inSpellBook = (Game.CurrentScreen == SPELL_BOOK_SCREEN)
	if inSpellBook then
		-- Game.SpellsTxt[2].Description = Game.SpellsTxt[2].Description:gsub("%$(.-)%$", tostring(dmg))
		local plIndex = math.max(0, Game.CurrentPlayer or 0)
		local pl = Party and Party[plIndex]
		for spellId, cfg in pairs(SpellPowerFormulas) do
			local dmg = getDamageValue(pl, cfg)
			if vars.OriginalDescription == nil then
				vars.OriginalDescription = {}
			end
			if vars.OriginalDescription[spellId] == nil then
				vars.OriginalDescription[spellId] = Game.SpellsTxt[spellId].Description
			else
				Game.SpellsTxt[spellId].Description = vars.OriginalDescription[spellId]:gsub("%$(.-)%$", tostring(dmg))
			end
		end
	end
end

-- 用 PostRender 代替 Timer：每帧绘制时都会触发，与游戏时间是否暂停无关（法术书界面仍会渲染）
function events.PostRender()
	updateSpellBookDescriptions()
end