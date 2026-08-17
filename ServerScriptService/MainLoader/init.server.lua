--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = ReplicatedStorage.Modules.Shared.Config
local Config = require(SharedConfig.Config)
local MonetizationConfig = require(SharedConfig.MonetizationConfig)
local BoardResultEffectService = require(script.Services.BoardResultEffectService)
local CmdrService = require(script.Services.CmdrService)
local DataManager = require(script.Services.DataManager)
local DiceService = require(script.Services.DiceService)
local DuelService = require(script.Services.DuelService)
local GroupRewardService = require(script.Services.GroupRewardService)
local LeaderboardService = require(script.Services.LeaderboardService)
local InventoryService = require(script.Services.InventoryService)
local MonetizationService = require(script.Services.MonetizationService)
local NetworkService = require(script.Services.NetworkService)
local OverheadService = require(script.Services.OverheadService)
local PusherService = require(script.Services.PusherService)
local RagdollTriggerService = require(script.Services.RagdollTriggerService)
local RoundDisplayService = require(script.Services.RoundDisplayService)
local RoundService = require(script.Services.RoundService)
local TableService = require(script.Services.TableService)

NetworkService.Init()
DataManager.Init(Config)
LeaderboardService.Init(Config, NetworkService, DataManager)
OverheadService.Init(DataManager)
DiceService.Init(Config)
PusherService.Init(Config)
BoardResultEffectService.Init()
TableService.Init(Config, NetworkService, DataManager, DiceService.GetAvailableColors())
DuelService.Init(Config, NetworkService, DataManager, TableService)
TableService.SetDuelService(DuelService)
MonetizationService.Init(MonetizationConfig, DataManager, TableService, NetworkService)
InventoryService.Init(NetworkService, DataManager, MonetizationService)
GroupRewardService.Init(Config, NetworkService, InventoryService)
CmdrService.Init(script.Commands)
RoundDisplayService.Init()
RoundService.Init(
	Config,
	NetworkService,
	DiceService,
	TableService,
	RoundDisplayService,
	PusherService,
	RagdollTriggerService
)
RoundService.Start()
