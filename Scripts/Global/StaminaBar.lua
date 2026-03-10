--[[
	体力条 (Stamina Bar)
	在游戏主界面左下角为每个队员分别显示独立体力条。
	体力值存储在 vars.PlayerStamina[slot] / vars.PlayerStaminaMax[slot]（slot 为队伍位置 0..4），会随存档保存。
]]

local STAMINA_MAX_DEFAULT = 1000
local STAMINA_BAR_X, STAMINA_BAR_Y = 186, 295
local STAMINA_BAR_W, STAMINA_BAR_H = 45, 5
local STAMINA_BAR_GAP = 10   -- 每条之间的间距
local COLOR_BG = 0x303030
-- 绿(满) → 黄(半) → 红(空)。D3D 顶点色是 BGR 字节序，必须按 BGR 输出否则红色会显示成蓝/黑
local function StaminaColor(ratio)
	ratio = math.max(0, math.min(1, ratio))
	local r, g, b
	if ratio >= 0.8 then
		r = 0x00
		g = 0xFF
		b = 0x00
	elseif ratio >= 0.6 then
		local t = (0.8 - ratio) * 5
		r = math.floor(0x00 + (0xC0 - 0x00) * t)
		g = 0xFF
		b = 0x00
	elseif ratio >= 0.2 then
		local t = (0.6 - ratio) * 2.5
		r = 0xC0
		g = math.floor(0xFF + (0x30 - 0xFF) * t)
		b = 0x00
	else
		r = 0xC0
		g = 0x00
		b = 0x00
	end
	-- 按 BGR 顺序打包（引擎期望 BGR，不是 RGB）
	return r * 0x10000 + g * 0x100 + b
end

-- 初始化体力（新游戏或读档时，为每个队员初始化）
local function InitStamina()
	if not vars then
		return
	end
	if not vars.PlayerStamina then
		vars.PlayerStamina = {}
	end
	if not vars.PlayerStaminaMax then
		vars.PlayerStaminaMax = {}
	end
	-- 旧存档兼容：若存在 PartyStamina/PartyStaminaMax 且尚无按人数据，则按人数均分到每人
	if vars.PartyStamina ~= nil and vars.PartyStaminaMax ~= nil then
		local n = 0
		for _ in Party do
			n = n + 1
		end
		if n > 0 then
			local perMax = math.max(1, math.floor(vars.PartyStaminaMax / n))
			local perCur = math.max(0, math.floor(vars.PartyStamina / n))
			for slot, pl in Party do
				if vars.PlayerStaminaMax[slot] == nil then
					vars.PlayerStaminaMax[slot] = perMax
				end
				if vars.PlayerStamina[slot] == nil then
					vars.PlayerStamina[slot] = perCur
				end
			end
		end
		vars.PartyStamina = nil
		vars.PartyStaminaMax = nil
	end
	for slot, pl in Party do
		if vars.PlayerStaminaMax[slot] == nil or vars.PlayerStaminaMax[slot] <= 0 then
			vars.PlayerStaminaMax[slot] = STAMINA_MAX_DEFAULT
		end
		if vars.PlayerStamina[slot] == nil or vars.PlayerStamina[slot] < 0 then
			vars.PlayerStamina[slot] = vars.PlayerStaminaMax[slot]
		end
		vars.PlayerStamina[slot] = math.min(vars.PlayerStamina[slot], vars.PlayerStaminaMax[slot])
	end
end

function events.NewGameDefaultParty()
	InitStamina()
end

function events.LoadMap(WasInGame)
	-- 进入任何地图时清空缓存，换图后 D3D_Textures 会重建（含坐马车等 LeaveMap 不触发的情况）
	StaminaBarBmpIndex = nil
	if WasInGame then
		InitStamina()
	end
end

-- 换图时清空所有缓存，确保重新绘制时使用新的贴图
function events.LeaveMap()
	StaminaBarBmpIndex = nil
end

-- 自定义贴图名：若在 LOD 里加入了名为 "StaminaBar" 的 BMP，会优先使用
local STAMINA_BAR_BMP_NAME = "StaminaBar"
local StaminaBarBmpIndex = nil  -- 缓存按名称加载的贴图索引

-- 获取绘制用的贴图索引：优先用 LOD 里名为 STAMINA_BAR_BMP_NAME 的 BMP，否则用第一个有效纹理
local function GetStaminaBarTextureIndex()
	-- if StaminaBarBmpIndex ~= nil and StaminaBarBmpIndex > 0 then
	-- 	local tex = Game.BitmapsLod.D3D_Textures[StaminaBarBmpIndex]
	-- 	if tex and tex ~= 0 then
	-- 		return StaminaBarBmpIndex
	-- 	end
	-- end
	-- 尝试按名称加载（你可在 Data/00 patch.bitmaps.lod 里加入自己的 BMP，详见 Data/如何添加自定义BMP到游戏.md）
	-- if StaminaBarBmpIndex == nil then
	local ok, idx = pcall(function()
		local i = Game.BitmapsLod:LoadBitmap(STAMINA_BAR_BMP_NAME)
		if i and i > 0 and Game.BitmapsLod.Bitmaps[i] then
			Game.BitmapsLod.Bitmaps[i]:LoadBitmapPalette()
			return i
		end
		return nil
	end)
	StaminaBarBmpIndex = (ok and idx) and idx or false
	-- end
	if StaminaBarBmpIndex and StaminaBarBmpIndex > 0 then
		return StaminaBarBmpIndex
	end
	return nil
end

-- 在主游戏画面绘制每个队员的体力条（仅 D3D 模式）
local function DrawStaminaBar()
	if not Game.IsD3D then
		return
	end
	if Game.CurrentScreen ~= 0 then  -- const.Screens.Game
		return
	end
	InitStamina()
	local idx = GetStaminaBarTextureIndex()
	if not idx then
		return
	end
	local slotCount = 0
	for slot, pl in Party do
		slotCount = slotCount + 1
		local cur = math.max(0, vars.PlayerStamina[slot] or 0)
		local maxVal = math.max(1, vars.PlayerStaminaMax[slot] or STAMINA_MAX_DEFAULT)
		local ratio = cur / maxVal
		local column = slotCount - 1
		local y1, y2 = STAMINA_BAR_Y, STAMINA_BAR_Y + STAMINA_BAR_H
		local x1 = STAMINA_BAR_X + column * (STAMINA_BAR_W + STAMINA_BAR_GAP)
		local x2 = x1 + STAMINA_BAR_W
		-- 背景条（整条深色）
		pcall(DrawScreenEffectD3D, idx, 0, 0, 1, 1, x1, y1, x2, y2, COLOR_BG)
		-- 当前体力（按比例填色：绿→黄→红，BGR）
		local fillW = STAMINA_BAR_W * ratio
		if fillW >= 1 then
			local fillColor = StaminaColor(ratio)
			pcall(DrawScreenEffectD3D, idx, 0, 0, 1, 1, x1, y1, x1 + fillW, y2, fillColor)
		end
	end
end

function events.PostRender()
	DrawStaminaBar()
end

-- 可选：行走时缓慢消耗体力，休息时恢复（取消下面注释即可启用）

-- local STAMINA_DECAY_PER_MIN = 10
-- local STAMINA_RESTORE_PER_TICK = 5
-- function events.Tick()
-- 	InitStamina()
-- 	if Game.CurrentScreen == 0 then
-- 		vars.PartyStamina = math.max(0, vars.PartyStamina - STAMINA_DECAY_PER_MIN / 120)
-- 	elseif Game.CurrentScreen == 5 then
-- 		vars.PartyStamina = math.min(vars.PartyStaminaMax, vars.PartyStamina + STAMINA_RESTORE_PER_TICK / 120)
-- 	end
-- end

