--!strict

local Config = require(script.Config)
local MonetizationConfig = require(script.MonetizationConfig)
local DataManager = require(script.Services.DataManager)
local DiceService = require(script.Services.DiceService)
local LeaderboardService = require(script.Services.LeaderboardService)
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
TableService.Init(Config, NetworkService, DataManager, DiceService.GetAvailableColors())
MonetizationService.Init(MonetizationConfig, DataManager, TableService, NetworkService)
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
