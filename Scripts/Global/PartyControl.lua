-- Timer functions split from MonsterItems.lua

local function SpellBuffExtraTimer()
	if vars.LloydEffectTime and math.abs(vars.LloydEffectTime - Game.Time) < 10 then
		Party.X = vars.LloydX
		Party.Y = vars.LloydY
		Party.Z = vars.LloydZ
		vars.LloydEffectTime = 0
	end

	if (not vars.MagicRes) or vars.MagicRes < Game.Time then
		if (vars.DarkGraspExpireTime and vars.DarkGraspExpireTime >= Game.Time) or (vars.StunExpireTime and vars.StunExpireTime >= Game.Time) then
			Stp = true
		else
			Stp = false
		end

		Spd = 1
		SpdZ = 1
		if vars.StaminaLowMul then
			Spd = Spd * vars.StaminaLowMul
		end
		if vars.SlowExpireTime and vars.SlowExpireTime >= Game.Time then
			Spd = Spd * 0.4
		end
		if vars.PartySpeedReduceByMonster then
			Spd = Spd * vars.PartySpeedReduceByMonster
		end
		if vars.SwiftPotionBuffTime and vars.SwiftPotionBuffTime >= Game.Time then
			Spd = Spd * 1.2
		end
		if vars.DispelSlowExpireTime and vars.DispelSlowExpireTime >= Game.Time then
			Spd = Spd * 0.1
		end
		for i, v in Party do
			if v.SpellBuffs[const.PlayerBuff.TempAccuracy].ExpireTime > Game.Time then
				Spd = Spd * 1.4
				break
			end
		end

		if Game.Map.Name == "elemw.odm" then
			Spd = Spd * math.max(0.25, (0.99985 ^ (vars.ElemwFatigue or 0)))
			SpdZ = SpdZ * math.max(0.25, (0.99985 ^ (vars.ElemwFatigue or 0)))
		end

		if (vars.StunExpireTime and vars.StunExpireTime >= Game.Time) then
			for _, pl in Party do
				pl.RecoveryDelay = math.max(pl.RecoveryDelay, 10)
			end
		end
	end

	if Game.TurnBased == true then
		Game.TurnBased = false
	end

	if Party.SpellBuffs[const.PartyBuff.Haste].ExpireTime > Game.Time then
		Party.SpellBuffs[const.PartyBuff.Haste].ExpireTime = Game.Time + const.Day
	end

	if Party.SpellBuffs[const.PartyBuff.WizardEye].ExpireTime > Game.Time and (Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime < Game.Time + const.Minute / 30 or Party.SpellBuffs[const.PartyBuff.TorchLight].Power <= 10) then
		Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime = math.max(Party.SpellBuffs[const.PartyBuff.WizardEye].ExpireTime, Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime)
		Party.SpellBuffs[const.PartyBuff.TorchLight].Power = 10
	end

	if Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime > Game.Time + const.Day * 80 then
		local sk = math.round((Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime - Game.Time) / (7257600 * const.Minute / 60))
		Party.SpellBuffs[const.PartyBuff.TorchLight].ExpireTime = Game.Time + const.Minute
		Party.SpellBuffs[const.PartyBuff.TorchLight].Power = math.round(20 - 200 / (sk + 19)) + 1
	end

	for _, pl in Party do
		if pl.Dead ~= 0 or pl.Eradicated ~= 0 then
			pl.HP = math.min(pl.HP, 0)
			pl.SP = 0
		end
		if pl.SpellBuffs[const.PlayerBuff.Hammerhands].ExpireTime > Game.Time then
			pl.SpellBuffs[const.PlayerBuff.Hammerhands].ExpireTime = 0
		end
		if pl.SpellBuffs[const.PlayerBuff.Fate].ExpireTime > Game.Time and pl.SpellBuffs[const.PlayerBuff.Fate].Skill ~= 0 then
			local curHP = math.max(pl.HP, 0)
			local curSP = math.max(pl.SP, 0)
			local FullHP = pl:GetFullHP()
			local FullSP = pl:GetFullSP()
			if pl.Dead ~= 0 or pl.Eradicated ~= 0 then
				curHP = 0
				curSP = 0
				FullHP = 0
				FullSP = 0
			end
			vars.Invincible = Game.Time + pl.SpellBuffs[const.PlayerBuff.Fate].Power * 0.2 * const.Minute / 60
			local RecHP = curHP * 2 + FullHP * (pl.SpellBuffs[const.PlayerBuff.Fate].Power * 0.002)
			local RecSP = curSP * 2 + FullSP * (pl.SpellBuffs[const.PlayerBuff.Fate].Power * 0.002)
			pl.Eradicated = Game.Time
			for i, v in pl.SpellBuffs do
				v.ExpireTime = 0
			end
			pl.HP = 0
			pl.SP = 0
			local cnt = 0
			for i, v in Party do
				if v.Dead == 0 and v.Eradicated == 0 then
					cnt = cnt + 1
				end
			end
			for i, v in Party do
				if v.Dead == 0 and v.Eradicated == 0 then
					v.HP = math.min(v.HP + RecHP / cnt, v:GetFullHP())
					v.SP = math.min(v.SP + RecSP / cnt, v:GetFullSP())
				end
			end
		end
		if pl.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime > Game.Time then
			pl.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime = Game.Time + const.Minute
		end
		if pl.SpellBuffs[const.PlayerBuff.Hammerhands].Skill >= 1 then
			pl.SpellBuffs[const.PlayerBuff.TempEndurance].ExpireTime = Game.Time + const.Minute * 10
		else
			pl.SpellBuffs[const.PlayerBuff.TempEndurance].ExpireTime = 0
		end
		for i, pl in Party do
			if vars.HammerhandDamageType == const.Damage.Fire then
				pl.SpellBuffs[const.PlayerBuff.FireResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.FireResistance].ExpireTime = 0
			end
			if vars.HammerhandDamageType == const.Damage.Air then
				pl.SpellBuffs[const.PlayerBuff.AirResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.AirResistance].ExpireTime = 0
			end
			if vars.HammerhandDamageType == const.Damage.Water then
				pl.SpellBuffs[const.PlayerBuff.WaterResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.WaterResistance].ExpireTime = 0
			end
			if vars.HammerhandDamageType == const.Damage.Earth then
				pl.SpellBuffs[const.PlayerBuff.EarthResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.EarthResistance].ExpireTime = 0
			end
			if vars.HammerhandDamageType == const.Damage.Body then
				pl.SpellBuffs[const.PlayerBuff.BodyResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.BodyResistance].ExpireTime = 0
			end
			if vars.HammerhandDamageType == const.Damage.Mind then
				pl.SpellBuffs[const.PlayerBuff.MindResistance].ExpireTime = Game.Time + const.Minute * 10
			else
				pl.SpellBuffs[const.PlayerBuff.MindResistance].ExpireTime = 0
			end
		end

		if not vars.RecoveryDelayModified then
			vars.RecoveryDelayModified = {[0] = 0, 0, 0, 0, 0}
		end

		if pl.SpellBuffs[const.PlayerBuff.TempAccuracy].ExpireTime > Game.Time and pl.RecoveryDelay > 1 then
			if vars.RecoveryDelayModified[_] == nil or vars.RecoveryDelayModified[_] < pl.RecoveryDelay then
				pl.RecoveryDelay = math.floor(pl.RecoveryDelay / 2)
				vars.RecoveryDelayModified[_] = pl.RecoveryDelay
			else
				vars.RecoveryDelayModified[_] = pl.RecoveryDelay
			end
		end
	end

	for _, pl in Party do
		if pl.SpellBuffs[const.PlayerBuff.Regeneration].ExpireTime > Game.Time and pl.SpellBuffs[const.PlayerBuff.Regeneration].Power == 0 then
			sk = math.round(pl.SpellBuffs[const.PlayerBuff.Regeneration].ExpireTime - Game.Time) / 60 / const.Minute
			mas = pl.SpellBuffs[const.PlayerBuff.Regeneration].Skill
			pl.SpellBuffs[const.PlayerBuff.Regeneration].Power = math.round(sk * (mas + 1) / 5)
			pl.SpellBuffs[const.PlayerBuff.Regeneration].ExpireTime = Game.Time + const.Minute * 10
		end
	end

	if Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime > Game.Time + const.Minute * 10 then
		if vars.ImmolationOn then
			vars.ImmolationOn = nil
			Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime = Game.Time
		else
			vars.ImmolationOn = true
			Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime = Game.Time + const.Minute * 5
			if Party.SpellBuffs[const.PartyBuff.Immolation].Skill <= 2 then
				Party.SpellBuffs[const.PartyBuff.Immolation].Power = math.ceil(Party.SpellBuffs[const.PartyBuff.Immolation].Power * 4)
			elseif Party.SpellBuffs[const.PartyBuff.Immolation].Skill <= 3 then
				Party.SpellBuffs[const.PartyBuff.Immolation].Power = math.ceil(Party.SpellBuffs[const.PartyBuff.Immolation].Power * 5)
			else
				Party.SpellBuffs[const.PartyBuff.Immolation].Power = math.ceil(Party.SpellBuffs[const.PartyBuff.Immolation].Power * 6)
			end
		end
	elseif Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime > Game.Time then
		Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime = Game.Time + const.Minute * 5
	end

	for _, pl in Party do
		if pl.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime > Game.Time and pl.SpellBuffs[const.PlayerBuff.Glamour].Skill ~= 0 then
			sk = (pl.SpellBuffs[const.PlayerBuff.Glamour].Power - 2) * 2
			mas = pl.SpellBuffs[const.PlayerBuff.Glamour].Skill
			power = mas * 5 + sk * 0.5
			for i, Player in Party do
				Player.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime = math.max(Player.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime, pl.SpellBuffs[const.PlayerBuff.Glamour].ExpireTime)
				Player.SpellBuffs[const.PlayerBuff.Glamour].Power = math.max(Player.SpellBuffs[const.PlayerBuff.Glamour].Power, power)
				Player.SpellBuffs[const.PlayerBuff.Glamour].Skill = 0
			end
		end
		if pl.Disease3 ~= 0 and Game.Time - pl.Disease3 > const.Minute * 10 then
			if pl.RecoveryDelay < 50 then
				pl.RecoveryDelay = 50
			end
		end
		if pl.Disease2 ~= 0 and pl.Disease3 == 0 and Game.Time - pl.Disease2 > const.Minute * 10 then
			pl.Disease3 = Game.Time
		end
		if pl.Disease1 ~= 0 and pl.Disease2 == 0 and Game.Time - pl.Disease1 > const.Minute * 10 then
			pl.Disease2 = Game.Time
		end
	end

	if vars.LastCastSpell == nil or Game.Time - vars.LastCastSpell >= const.Minute * 5 then
		vars.EnterCombatTime = Game.Time
		for _, pl in Party do
			pl.SpellBuffs[const.PlayerBuff.PainReflection].ExpireTime = math.min(pl.SpellBuffs[const.PlayerBuff.PainReflection].ExpireTime, Game.Time + const.Minute * 10)
			pl.Weak = 0
		end
		for i, v in Party do
			if v.SpellBuffs[const.PlayerBuff.TempLuck] and v.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime > Game.Time then
				v.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime = v.SpellBuffs[const.PlayerBuff.TempLuck].ExpireTime - 7
			end
		end
	else
		Party.SpellBuffs[const.PartyBuff.ProtectionFromMagic].ExpireTime = 0
	end

	if vars.SouldrinkerAttackCount ~= nil and vars.SouldrinkerAttackCount > 0 then
		local RecoveryAmount = (vars.SouldrinkerAttackCount * 10 + 25) * vars.SouldrinkerAttackCount / 5
		local OriginalRecoveryAmount = (vars.SouldrinkerAttackCount * 7 + 25) * vars.SouldrinkerAttackCount / 5
		vars.SouldrinkerAttackCount = 0
		for i, pl in Party do
			if pl.Dead == 0 and pl.Eradicated == 0 then
				if pl:IsConscious() then
					pl.HP = math.min(pl.HP + RecoveryAmount - OriginalRecoveryAmount, pl:GetFullHP())
				else
					pl.HP = math.min(pl.HP + RecoveryAmount, pl:GetFullHP())
				end
			end
		end
	end
end

local function ManaRegeneration()
	if vars.LastCastSpell == nil or Game.Time - vars.LastCastSpell >= const.Minute * 5 then
		for i, v in Party do
			if v.Dead == 0 and v.Eradicated == 0 then
				local maxsp = v:GetFullSP()
				local maxhp = v:GetFullHP()
				if vars.BurningExpireTime and vars.BurningExpireTime >= Game.Time then
					v.SP = math.min(v.SP + math.max(1, maxsp * 0.02), maxsp)
				else
					v.SP = math.min(v.SP + math.max(1, maxsp * 0.02), maxsp)
					v.HP = math.min(v.HP + math.max(1, maxhp * 0.02), maxhp)
				end
			end
		end
	end
end

local function SpellOnCostMana()
	if Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime > Game.Time then
		local plid = vars.PlayerCastImmolation
		if plid then
			local pl = Party[plid]
			local maxsp = pl:GetFullSP()
			pl.SP = math.max(pl.SP - maxsp * 0.005 - 10, 0)
			if pl.SP == 0 then
				Party.SpellBuffs[const.PartyBuff.Immolation].ExpireTime = Game.Time
				vars.PlayerCastImmolation = nil
			end
		end
	end
end

local function HealthRegeneration()
	for i, v in Party do
		if v.Dead == 0 and v.Eradicated == 0 then
			local maxhp = v:GetFullHP()
			local sk, mas = SplitSkill(v:GetSkill(const.Skills.Regeneration))
			local regenHP = math.ceil(sk * mas * 0.25)
			if v.SpellBuffs[const.PlayerBuff.Regeneration].ExpireTime > Game.Time then
				regenHP = regenHP + v.SpellBuffs[const.PlayerBuff.Regeneration].Power
			end
			if vars.BurningExpireTime and vars.BurningExpireTime >= Game.Time then
				regenHP = 0
			end
			if v.SpellBuffs[const.PlayerBuff.TempSpeed].ExpireTime > Game.Time then
				regenHP = regenHP - v.SpellBuffs[const.PlayerBuff.TempSpeed].Power
			end
			v.HP = math.min(v.HP + regenHP, maxhp)
		end
	end
end

local function FatigueTimer()
	if vars.LastCastSpell and Game.Time - vars.LastCastSpell < const.Minute * 5 and vars.EnterCombatTime and Game.Time - vars.EnterCombatTime > const.Hour * 4 then
		for i, v in Party do
			local maxsp = v:GetFullSP()
			local maxhp = v:GetFullHP()
			if v.Dead == 0 and v.Eradicated == 0 then
				v.SP = math.max(v.SP - math.max(1, maxsp * 0.01), 0)
				v.HP = v.HP - math.max(1, maxhp * 0.01)
			end
		end
	end
end

local function PoisonTimer()
	for i, v in Party do
		if v.Dead == 0 then
			if v.Poison1 ~= 0 then
				v.HP = v.HP - 2
			end
			if v.Poison2 ~= 0 then
				v.HP = v.HP - 10
			end
			if v.Poison3 ~= 0 then
				v.HP = v.HP - 50
			end
		end
	end
end

local function ArmageddonTimer()
	for _, pl in Party do
		if pl.ArmageddonCasts > 0 then
			Sleep(200)
			for i, v in Map.Monsters do
				v.HP = 0
			end
			for i, v in Party do
				v.HP = -1000
				v.ArmageddonCasts = 0
			end
			break
		end
	end
end

local function NegRegen()
	Party.LastRegenerationTime = Game.Time + 100000000
end

local function InsaneTimer()
	for i, v in Party do
		if v.Dead == 0 and v.Eradicated == 0 and v.Insane ~= 0 then
			local maxhp = v:GetFullHP()
			local dmg = maxhp * 0.02
			v.HP = v.HP - dmg
		end
	end
end

local function BurningTimer()
	for i, v in Party do
		if v.Dead == 0 and v.Eradicated == 0 then
			if vars.BurningExpireTime and vars.BurningExpireTime >= Game.Time then
				evt.DamagePlayer(i, const.Damage.Fire, vars.BurningPower)
			end
		end
	end
end

local function BreakInvisibilityTimer()
	Party.SpellBuffs[const.PartyBuff.Invisibility].ExpireTime = 0
end

function events.AfterLoadMap()
	if Map.IsIndoor() or Map.Name == "elema.odm" or Map.Name == "elemf.odm" or Map.Name == "elemw.odm" then
		Timer(BreakInvisibilityTimer, const.Minute / 2, false)
	end
	Timer(SpellBuffExtraTimer, 1, false)
	Timer(ManaRegeneration, const.Minute / 8, false)
	Timer(SpellOnCostMana, const.Minute / 4, false)
	Timer(HealthRegeneration, const.Minute / 4, false)
	Timer(FatigueTimer, const.Minute / 4, false)
	Timer(PoisonTimer, const.Minute / 8, false)
	Timer(ArmageddonTimer, const.Minute / 8, false)
	Timer(NegRegen, const.Minute * 4, false)
	Timer(InsaneTimer, const.Minute / 8, false)
	Timer(BurningTimer, const.Minute / 4, false)
end
