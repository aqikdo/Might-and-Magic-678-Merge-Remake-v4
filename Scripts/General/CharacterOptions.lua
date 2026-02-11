--[[
  角色选项 (Character Options)
  入口在 主界面 -> 控制/选项 -> Extra Settings（与其它设置同一入口），左右翻页可到「Character Options」页。
  可为每个角色（最多 5 人）单独设置：是否关闭攻击、是否关闭射击。设置随存档保存。
  背景图：在文件顶部设置 CharOptBackgroundIcon = "图名"（Icons 里的名字，如 "mapframe"）可指定背景；
        不设或设为 nil 则使用与 Extra Settings 相同的 ExSetScr 背景。
]]

local CharOptScreenId = 94
-- 背景图：nil 或 "" = 使用与 Extra Settings 相同的 ExSetScr；设为 Icons 里的图名（如 "mapframe"）则用该图作背景
local CharOptBackgroundIcon = "ExSetScr2"

const.Screens = const.Screens or {}
const.Screens.CharacterOptions = CharOptScreenId
CustomUI.NewScreen(CharOptScreenId)

-- vars 在进入地图后才存在；未加载存档时用后备表避免 nil 报错
local fallbackCharacterOptions = {}

-- 界面状态与刷新函数放在全局表，供入口按钮在任意调用环境下访问（InterfaceManager 可能包装 Action）
CharOptUI = CharOptUI or { SelSlot = 0, OptTexts = {} }

-- 获取/初始化当前角色选项 (slot 0..4，最多 5 人)
local function GetCharOpt(slot)
	local co = (vars and vars.CharacterOptions) or fallbackCharacterOptions
	co[slot] = co[slot] or {}
	local o = co[slot]
	o.DisableAttack = (o.DisableAttack == true)
	o.DisableShoot = (o.DisableShoot == true)
	return o
end

-- 根据当前队伍索引取选项 (PlayerIndex 0..4 对应 Party[0]..Party[4])
local function GetCharOptByPlayerIndex(pi)
	if pi == nil or pi < 0 or pi >= Party.count then
		return nil
	end
	return GetCharOpt(pi)
end

local function ExitCharOptScreen()
	if CustomUI.ExitExtraSettingsMenu then
		CustomUI.ExitExtraSettingsMenu()
	else
		Game.CurrentScreen = 2
	end
end

function events.GameInitialized2()
	local ESCAPE = const.Keys.ESCAPE
	local bgIcon = (CharOptBackgroundIcon and CharOptBackgroundIcon ~= "") and CharOptBackgroundIcon or "ExSetScr"
	-- 背景图 + 挡底、暂停、ESC 退出，与其它设置页行为一致，避免退出时错乱
	CustomUI.CreateIcon{
		Icon    = bgIcon,
		X       = 0,
		Y       = 0,
		Layer   = 1,
		Screen  = CharOptScreenId,
		DynLoad = true,
		BlockBG = true,
		Condition = function()
			if Keys.IsPressed(ESCAPE) then
				ExitCharOptScreen()
			end
			Game.Paused = true
			return true
		end,
	}

	local SlotNames = {"1", "2", "3", "4", "5"}
	local OptTexts = {}

	-- 选择角色按钮 (1~5)
	for i = 0, 4 do
		local slot = i
		CustomUI.CreateButton{
			IconUp   = "SlChar" .. (i + 1) .. "U",
			IconDown = "SlChar" .. (i + 1) .. "D",
			Screen   = CharOptScreenId,
			Layer    = 1,
			DynLoad  = true,
			X        = 85 + i * 48,
			Y        = 170,
			Action   = function()
				CharOptUI.SelSlot = slot
				if CharOptUI.UpdateOptDisplay then CharOptUI.UpdateOptDisplay() end
				if CharOptUI.UpdateSelName then CharOptUI.UpdateSelName() end
			end,
			Condition = function() return Party.count > slot end,
		}
	end

	-- "CharacterName:" 标签（在角色按钮 1~5 右侧）
	CustomUI.CreateText{
		Text   = "CharacterName:",
		Layer  = 0,
		Screen = CharOptScreenId,
		Width  = 150,
		Height = 12,
		X      = 330,
		Y      = 175,
	}
	-- 当前角色名
	local SelNameText = CustomUI.CreateText{
		Text   = "",
		Layer  = 0,
		Screen = CharOptScreenId,
		Width  = 200,
		Height = 12,
		X      = 400,
		Y      = 175,
	}

	-- stop melee attack：TmblrOn/TmblrOff 开关
	CustomUI.CreateText{
		Text   = "stop melee attack",
		Layer  = 0,
		Screen = CharOptScreenId,
		Width  = 280,
		Height = 12,
		X      = 160,
		Y      = 245,
	}
	CharOptUI.TumblerAttack = CustomUI.CreateButton{
		IconUp   = "TmblrOff",
		IconDown = "TmblrOn",
		Screen   = CharOptScreenId,
		Layer    = 0,
		DynLoad  = true,
		X        = 95,
		Y        = 240,
		Action   = function()
			local o = GetCharOpt(CharOptUI.SelSlot)
			o.DisableAttack = not o.DisableAttack
			local T = CharOptUI.TumblerAttack
			if T then
				T.IUpSrc, T.IDwSrc = T.IDwSrc, T.IUpSrc
				T.IUpPtr, T.IDwPtr = T.IDwPtr, T.IUpPtr
			end
			if CharOptUI.UpdateOptDisplay then CharOptUI.UpdateOptDisplay() end
			Game.PlaySound(25)
		end,
	}

	-- stop ranged attack：TmblrOn/TmblrOff 开关
	CustomUI.CreateText{
		Text   = "stop ranged attack",
		Layer  = 0,
		Screen = CharOptScreenId,
		Width  = 280,
		Height = 12,
		X      = 160,
		Y      = 285,
	}
	CharOptUI.TumblerShoot = CustomUI.CreateButton{
		IconUp   = "TmblrOff",
		IconDown = "TmblrOn",
		Screen   = CharOptScreenId,
		Layer    = 0,
		DynLoad  = true,
		X        = 95,
		Y        = 280,
		Action   = function()
			local o = GetCharOpt(CharOptUI.SelSlot)
			o.DisableShoot = not o.DisableShoot
			local T = CharOptUI.TumblerShoot
			if T then
				T.IUpSrc, T.IDwSrc = T.IDwSrc, T.IUpSrc
				T.IUpPtr, T.IDwPtr = T.IDwPtr, T.IUpPtr
			end
			if CharOptUI.UpdateOptDisplay then CharOptUI.UpdateOptDisplay() end
			Game.PlaySound(25)
		end,
	}

	CharOptUI.OptTexts = OptTexts
	CharOptUI.SelSlot = 0
	CharOptUI.UpdateOptDisplay = function()
		local o = GetCharOpt(CharOptUI.SelSlot)
		local Ta = CharOptUI.TumblerAttack
		if Ta then
			if o.DisableAttack then
				Ta.IUpSrc, Ta.IDwSrc = "TmblrOn", "TmblrOff"
			else
				Ta.IUpSrc, Ta.IDwSrc = "TmblrOff", "TmblrOn"
			end
		end
		local Ts = CharOptUI.TumblerShoot
		if Ts then
			if o.DisableShoot then
				Ts.IUpSrc, Ts.IDwSrc = "TmblrOn", "TmblrOff"
			else
				Ts.IUpSrc, Ts.IDwSrc = "TmblrOff", "TmblrOn"
			end
		end
	end
	CharOptUI.UpdateSelName = function()
		if SelNameText and CharOptUI.SelSlot < Party.count then
			SelNameText.Text = Party[CharOptUI.SelSlot].Name or ("Party " .. (CharOptUI.SelSlot + 1))
		elseif SelNameText then
			SelNameText.Text = ""
		end
	end

	-- 初始化显示
	CharOptUI.UpdateOptDisplay()
	CharOptUI.UpdateSelName()
end

-- 存档/读档
function events.BeforeSaveGame()
	if vars then
		vars.CharacterOptions = vars.CharacterOptions or {}
	end
end

function events.LoadMap(WasInGame)
	if vars and not WasInGame then
		vars.CharacterOptions = vars.CharacterOptions or {}
	end
end

-- 战斗中：根据选项禁止攻击/射击
-- 不同版本动作码可能不同：120 近战攻击, 133 射击 (常见于 MM8)
local ActionAttack = 120
local ActionShoot  = 133

function events.Action(t)
	if Game.CurrentScreen ~= 0 or not vars then
		return
	end
	local pi = Game.CurrentPlayer
	if pi == nil or pi < 0 then
		return
	end
	local opt = GetCharOptByPlayerIndex(pi)
	if not opt then
		return
	end
	if t.Action == ActionAttack and opt.DisableAttack then
		t.Handled = true
		return
	end
	if t.Action == ActionShoot and opt.DisableShoot then
		t.Handled = true
		return
	end
end

-- 默认施法目标已移除；保留空函数供其他脚本调用不报错
function GetDefaultSpellTarget(playerIndex)
	return nil
end
