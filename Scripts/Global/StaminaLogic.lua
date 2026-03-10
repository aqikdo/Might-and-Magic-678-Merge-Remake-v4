--[[
	体力逻辑 (Stamina Logic)
	与 StaminaBar.lua 配合：每个队员独立体力条与体力值（vars.PlayerStamina[slot] / vars.PlayerStaminaMax[slot]）。
	根据各自耐力计算最大体力，疾跑/攻击/射击按队员消耗，自然恢复按队员独立进行。
	使用 MonsterItems.lua 的 Timer 方式定期处理。

	关于 PlayerIndex（如 ArrowProjectile 的 t.PlayerIndex）：
	- 事件里传的 PlayerIndex 来自游戏内存 0x51d822，是 roster ID（花名册序号），
	  即 Party.PlayersArray 的索引，范围 0..PlayersArray.count-1（可能很大，如 36）。
	- 队伍中的顺序是 Party 的 slot：0..4 对应画面上第 1～5 个角色。
	- 对应关系：Party.PlayersIndexes[slot] == roster_id；
	  由 roster id 求队伍位置用 Merge.Functions.GetSlotByIndex(roster_id)。
	- 取玩家：Party.PlayersArray[roster_id] 或 Party[slot]（slot 有效时）。
]]

-- 确保 per-player 表存在
local function EnsurePlayerStaminaTables()
	if not vars.PlayerStamina then
		vars.PlayerStamina = {}
	end
	if not vars.PlayerStaminaMax then
		vars.PlayerStaminaMax = {}
	end
end

-- 根据每个队员耐力计算其最大体力
local function UpdatePartyStaminaMax()
	if not vars then
		return
	end
	EnsurePlayerStaminaTables()
	for slot, pl in Party do
		local endurance = pl:GetEndurance() or 0
		vars.PlayerStaminaMax[slot] = 1000 * (1 + endurance * 0.001)
		if vars.PlayerStamina[slot] then
			vars.PlayerStamina[slot] = math.min(vars.PlayerStamina[slot], vars.PlayerStaminaMax[slot])
		else
			vars.PlayerStamina[slot] = vars.PlayerStaminaMax[slot]
		end
	end
end

-- 每次 CalcStatBonusBySkills 时更新最大体力
function events.CalcStatBonusBySkills()
	UpdatePartyStaminaMax()
end

-- ========== 消耗与恢复参数 ==========
local STAMINA_RESTORE_PER_TICK = 3   -- 自然恢复每 tick 恢复量
local STAMINA_RESTORE_PER_TICK_REST = 50   -- 休息时每 tick 恢复量
local STAMINA_TICK_PERIOD      = const.Minute / 16  -- Timer 间隔：每 1/16 分钟
local STAMINA_PER_RUN_STEP = 20   -- 每次疾跑步伐消耗（每个队员独立扣）
local STAMINA_SHOOT_COST = 100

-- 为指定队员扣减体力（slot 为队伍位置 0..4），供 Damage_Modifier 等调用
function ConsumeStaminaForSlot(slot, amount)
	if not vars or slot == nil then
		return
	end
	EnsurePlayerStaminaTables()
	local cur = vars.PlayerStamina[slot]
	if cur == nil then
		cur = vars.PlayerStaminaMax[slot] or 1000
		vars.PlayerStamina[slot] = cur
	end
	vars.PlayerStamina[slot] = math.max(0, cur - amount)
	Game.NeedRedraw = true
end

-- 为指定队员增加体力
local function RestoreStaminaForSlot(slot, amount)
	if not vars or slot == nil then
		return
	end
	EnsurePlayerStaminaTables()
	local maxVal = vars.PlayerStaminaMax[slot] or 1000
	local cur = vars.PlayerStamina[slot]
	if cur == nil then
		cur = maxVal
		vars.PlayerStamina[slot] = cur
	end
	vars.PlayerStamina[slot] = math.min(maxVal, cur + amount)
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

-- ========== Timer：自然恢复（每个队员独立） ==========
local function StaminaTimer()
	if not vars then
		return
	end
	EnsurePlayerStaminaTables()
	local normalized_speed = (vars.PartyTickMove or 0) / (Spd * (1 + 0.1 * (1 - Spd) ^ 2))
	local restStamina = (vars.LastCastSpell == nil or Game.Time - vars.LastCastSpell >= const.Minute * 5)
	local restoreAmount = restStamina and STAMINA_RESTORE_PER_TICK_REST or STAMINA_RESTORE_PER_TICK
	local minStamina = 10000

	for slot, pl in Party do
		local maxVal = vars.PlayerStaminaMax[slot] or 1000
		local cur = vars.PlayerStamina[slot]
		if cur == nil then
			cur = maxVal
			vars.PlayerStamina[slot] = cur
		end

		-- 疾跑消耗：每个队员独立扣
		if normalized_speed and normalized_speed >= 28 then
			vars.PlayerStamina[slot] = math.max(0, cur - STAMINA_PER_RUN_STEP)
			cur = vars.PlayerStamina[slot]
		end

		-- 自然恢复
		cur = vars.PlayerStamina[slot]
		vars.PlayerStamina[slot] = math.min(maxVal, cur + restoreAmount)

		-- 该队员的体力系数（用于攻击速度等）
		cur = vars.PlayerStamina[slot]
		local ratio = maxVal > 0 and (cur / maxVal) or 0
		
		if cur <= 10 then
			vars.StaminaLowMul = 0.25
		end
		if cur < minStamina then
			minStamina = cur
		end
	end

	-- 队伍整体系数取最低（兼容 ExtraArtifacts / PartyControl 等使用 vars.StaminaLowMul 的地方）
	if minStamina >= 100 then
		vars.StaminaLowMul = 1
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
	if slot ~= nil then
		local sk, mas = SplitSkill(player:GetSkill(const.Skills.Bow))
		if mas >= const.Master then
			ConsumeStaminaForSlot(slot, STAMINA_SHOOT_COST * 2)
		else
			ConsumeStaminaForSlot(slot, STAMINA_SHOOT_COST)
		end
	end
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
