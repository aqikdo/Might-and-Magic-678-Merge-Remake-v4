--[[
	体力逻辑 (Stamina Logic)
	与 StaminaBar.lua 配合：根据耐力计算最大体力，疾跑/攻击消耗，自然恢复。
	使用 MonsterItems.lua 的 Timer 方式定期处理。

	关于 PlayerIndex（如 ArrowProjectile 的 t.PlayerIndex）：
	- 事件里传的 PlayerIndex 来自游戏内存 0x51d822，是 roster ID（花名册序号），
	  即 Party.PlayersArray 的索引，范围 0..PlayersArray.count-1（可能很大，如 36）。
	- 队伍中的顺序是 Party 的 slot：0..4 对应画面上第 1～5 个角色。
	- 对应关系：Party.PlayersIndexes[slot] == roster_id；
	  由 roster id 求队伍位置用 Merge.Functions.GetSlotByIndex(roster_id)。
	- 取玩家：Party.PlayersArray[roster_id] 或 Party[slot]（slot 有效时）。
]]

-- 根据队伍耐力计算最大体力
local function UpdatePartyStaminaMax()
	if not vars then
		return
	end
	local totalEndurance = 0
	for i, pl in Party do
		totalEndurance = totalEndurance + (pl:GetEndurance() or 0)
	end
	vars.PartyStaminaMax = 1000 * (1 + totalEndurance * 0.001)
	if vars.PartyStamina then
		vars.PartyStamina = math.min(vars.PartyStamina, vars.PartyStaminaMax)
	end
end

-- 每次 CalcStatBonusBySkills 时更新最大体力
function events.CalcStatBonusBySkills()
	UpdatePartyStaminaMax()
end

-- ========== 消耗与恢复参数 ==========
local STAMINA_RESTORE_PER_TICK = 1   -- 自然恢复每 tick 恢复量
local STAMINA_RESTORE_PER_TICK_REST = 100   -- 自然恢复每 tick 恢复量
local STAMINA_TICK_PERIOD      = const.Minute / 16  -- Timer 间隔：每 1/16 分钟
local STAMINA_PER_RUN_STEP = 20   -- 每次疾跑步伐消耗
local STAMINA_RESTORE_STOP = 5
local STAMINA_SHOOT_COST = 15

-- 扣减体力（确保不为负）
local function ConsumeStamina(amount)
	vars.PartyStamina = math.max(0, vars.PartyStamina - amount)
	Game.NeedRedraw = true
end

-- 增加体力（不超过上限）
local function RestoreStamina(amount)
	vars.PartyStamina = math.min(vars.PartyStaminaMax, vars.PartyStamina + amount)
	Game.NeedRedraw = true
end

-- ========== 疾跑消耗：StepSound 检测（每步消耗） ==========
-- 疾跑由游戏内部控制：Caps Lock 切换 Always Run，或按住 Shift（Run 键）临时疾跑
-- ExtraEvents.lua 的 StepSound 在每步时触发，t.Run=1 表示疾跑步伐（非行走）

-- function events.StepSound(t)
-- 	-- if t.Run == 1 and vars and vars.PartyStamina then
-- 	ConsumeStamina(STAMINA_PER_RUN_STEP)
-- 	-- end
-- end

local function StaminaLowMulCalc(ratio)
	if ratio <= 0.05 then
		return 0.2
	elseif ratio <= 0.2 then
		return 0.2 * (ratio - 0.05) / 0.15
	else
		return 1
	end
end

-- ========== Timer：自然恢复 ==========
local function StaminaTimer()
	-- Message("Speed: "..tostring(((fast_decay_avg_PartySpeedX or 0) ^ 2 + (fast_decay_avg_PartySpeedY or 0) ^ 2) ^ 0.5))
	-- local speed = ((fast_decay_avg_PartySpeedX or 0) ^ 2 + (fast_decay_avg_PartySpeedY or 0) ^ 2) ^ 0.5
	local speed = vars.PartyTickMove
	if speed and speed >= 28 then
		-- Message("Speed: "..tostring(speed))
		ConsumeStamina(STAMINA_PER_RUN_STEP)
	end
	if vars.PartyStamina == 0 then
		vars.StaminaLowMul = 0.2
	elseif vars.PartyStamina >= 100 then
		vars.StaminaLowMul = 1
	end
	if vars.LastCastSpell == nil or Game.Time - vars.LastCastSpell >= const.Minute * 5 then
		RestoreStamina(STAMINA_RESTORE_PER_TICK_REST)
	else
		RestoreStamina(STAMINA_RESTORE_PER_TICK)
	end
end

local function PartySpeedCalcTimer()
	if not vars.PartyCurX then
		vars.PartyCurX = Party.X
		vars.PartyCurY = Party.Y
	else
		vars.PartyLastX = vars.PartyCurX
		vars.PartyLastY = vars.PartyCurY
		vars.PartyCurX = Party.X
		vars.PartyCurY = Party.Y
		vars.PartyTickMove = math.sqrt((Party.X - vars.PartyLastX) ^ 2 + (Party.Y - vars.PartyLastY) ^ 2)
		if not vars.PartySpeed then
			vars.PartySpeed = vars.PartyTickMove
		else
			vars.PartySpeed = vars.PartySpeed * 0.90 + vars.PartyTickMove * 0.10
		end
	end
end

local function PrintTimer()
	Message("PartySpeed: "..tostring(vars.PartySpeed).." PartyTickMove: "..tostring(vars.PartyTickMove))
end

function events.ArrowProjectile(t)
	-- t.PlayerIndex = roster ID (PlayersArray 索引)，不是队伍顺序 0..4
	local slot = Merge.Functions.GetSlotByIndex(t.PlayerIndex)  -- 队伍位置 0..4，不在队则 nil
	local player = Party.PlayersArray[t.PlayerIndex]             -- 始终可用
	-- Message("roster .. tostring(t.PlayerIndex) .. " slot=" .. tostring(slot) .. " name=" .. (player and player.Name or "?"))
	if vars.CharacterOptions and vars.CharacterOptions[slot] and vars.CharacterOptions[slot].DisableShoot then
		Game.ShowStatusText(string.format("%s takes defense action.", player.Name), 2)
		t.ObjId = 0
		player.AttackRecovery = 80
		return
	end
	ConsumeStamina(STAMINA_SHOOT_COST)
end

-- 进入地图时注册 Timer（与 MonsterItems.lua 相同方式）
function events.AfterLoadMap()
	UpdatePartyStaminaMax()
	Timer(PartySpeedCalcTimer, 5, false)
	-- Timer(PrintTimer, const.Minute, false)
	Timer(StaminaTimer, STAMINA_TICK_PERIOD, false)
end

-- 新游戏 / 读档时更新最大体力
function events.LoadMap(WasInGame)
	if WasInGame then
		UpdatePartyStaminaMax()
	end
end
