--!strict

task.wait(3)
local controllers = script.Parent:WaitForChild("Controllers")

local AFKController = require(controllers:WaitForChild("AFKController"))
local BoardController = require(controllers:WaitForChild("BoardController"))
local CameraShakeController = require(controllers:WaitForChild("CameraShakeController"))
local CmdrController = require(controllers:WaitForChild("CmdrController"))
local DayCycleController = require(controllers:WaitForChild("DayCycleController"))
local DuelController = require(controllers:WaitForChild("DuelController"))
local FavoritePromptController = require(controllers:WaitForChild("FavoritePromptController"))
local GamePassController = require(controllers:WaitForChild("GamePassController"))
local GroupRewardController = require(controllers:WaitForChild("GroupRewardController"))
local HUDController = require(controllers:WaitForChild("HUDController"))
local InventoryController = require(controllers:WaitForChild("InventoryController"))
local LivePickingController = require(controllers:WaitForChild("LivePickingController"))
local LeaderboardController = require(controllers:WaitForChild("LeaderboardController"))
local LeaderboardDummyController = require(controllers:WaitForChild("LeaderboardDummyController"))
local MusicController = require(controllers:WaitForChild("MusicController"))
local NpcAnimationController = require(controllers:WaitForChild("NpcAnimationController"))
local NotificationController = require(controllers:WaitForChild("NotificationController"))
local ResultBoardController = require(controllers:WaitForChild("ResultBoardController"))
local ResultPopupController = require(controllers:WaitForChild("ResultPopupController"))
local RoundTimerController = require(controllers:WaitForChild("RoundTimerController"))
local SettingsController = require(controllers:WaitForChild("SettingsController"))
local RemoveAllChairsController = require(controllers:WaitForChild("RemoveAllChairsController"))
local ShopController = require(controllers:WaitForChild("ShopController"))
local SoundController = require(controllers:WaitForChild("SoundController"))
local TopbarCameraController = require(controllers:WaitForChild("TopbarCameraController"))
local UIEffectsController = require(controllers:WaitForChild("UIEffectsController"))
local VIPSeatController = require(controllers:WaitForChild("VIPSeatController"))
local WinDropController = require(controllers:WaitForChild("WinDropController"))

local function initController(name: string, controller: any, asynchronous: boolean)
	local function run()
		local startedAt = os.clock()
		local ok, problem = xpcall(controller.Init, debug.traceback)
		if not ok then
			warn(`[ColorGame] {name} failed to initialize:\n{problem}`)
			return
		end
		local duration = os.clock() - startedAt
		if duration >= 2 then
			warn(`[ColorGame] {name} initialization took {string.format("%.2f", duration)} seconds`)
		end
	end
	if asynchronous then
		task.spawn(run)
	else
		run()
	end
end

-- Notifications bind first because Board and VIP seat controllers use them.
initController("NotificationController", NotificationController, false)

local independentControllers: { { Name: string, Controller: any } } = {
	{ Name = "AFKController", Controller = AFKController },
	{ Name = "VIPSeatController", Controller = VIPSeatController },
	{ Name = "CameraShakeController", Controller = CameraShakeController },
	{ Name = "CmdrController", Controller = CmdrController },
	{ Name = "DayCycleController", Controller = DayCycleController },
	{ Name = "DuelController", Controller = DuelController },
	{ Name = "FavoritePromptController", Controller = FavoritePromptController },
	{ Name = "NpcAnimationController", Controller = NpcAnimationController },
	{ Name = "SettingsController", Controller = SettingsController },
	{ Name = "BoardController", Controller = BoardController },
	{ Name = "GamePassController", Controller = GamePassController },
	{ Name = "GroupRewardController", Controller = GroupRewardController },
	{ Name = "HUDController", Controller = HUDController },
	{ Name = "RemoveAllChairsController", Controller = RemoveAllChairsController },
	{ Name = "ShopController", Controller = ShopController },
	{ Name = "InventoryController", Controller = InventoryController },
	{ Name = "LivePickingController", Controller = LivePickingController },
	{ Name = "LeaderboardDummyController", Controller = LeaderboardDummyController },
	{ Name = "LeaderboardController", Controller = LeaderboardController },
	{ Name = "ResultBoardController", Controller = ResultBoardController },
	{ Name = "ResultPopupController", Controller = ResultPopupController },
	{ Name = "RoundTimerController", Controller = RoundTimerController },
	{ Name = "SoundController", Controller = SoundController },
	{ Name = "MusicController", Controller = MusicController },
	{ Name = "TopbarCameraController", Controller = TopbarCameraController },
	{ Name = "UIEffectsController", Controller = UIEffectsController },
	{ Name = "WinDropController", Controller = WinDropController },
}

for _, entry in independentControllers do
	initController(entry.Name, entry.Controller, true)
end
