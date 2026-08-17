--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local SoundController = {}

local sfxFolder: Instance
local timerGeneration = 0
local randomizer = Random.new()

local function getSounds(name: string): { Sound }
	local sounds = {}
	for _, child in sfxFolder:GetChildren() do
		if child:IsA("Sound") and child.Name == name then
			table.insert(sounds, child)
		end
	end
	return sounds
end

local function playLocal(name: string)
	local sounds = getSounds(name)
	if #sounds == 0 then
		warn(`[ColorGame] Missing SoundService.SFX.{name}`)
		return
	end
	local sound = sounds[randomizer:NextInteger(1, #sounds)]:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength + 1, 5))
end

function SoundController.Play(name: string)
	playLocal(name)
end

local function startClock(state: string, endsAt: number)
	timerGeneration += 1
	local generation = timerGeneration
	if state ~= "Picking" then
		return
	end

	task.spawn(function()
		local lastSecond: number? = nil
		while generation == timerGeneration do
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			if remaining ~= lastSecond then
				lastSecond = remaining
				if remaining >= 1 and remaining <= 5 then
					playLocal("Timer")
				end
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function SoundController.Init()
	sfxFolder = SoundService:WaitForChild("SFX")
	local stateFolder = ReplicatedStorage:WaitForChild("ColorGameState")
	local function syncClock()
		startClock(
			stateFolder:GetAttribute("State") or "",
			stateFolder:GetAttribute("EndsAt") or 0
		)
	end
	stateFolder:GetAttributeChangedSignal("State"):Connect(syncClock)
	stateFolder:GetAttributeChangedSignal("EndsAt"):Connect(syncClock)
	syncClock()

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		local args = table.pack(...)
		if action == "PlaySFX" and type(args[1]) == "string" then
			playLocal(args[1])
		elseif action == "PurchaseSuccess" then
			playLocal(if args[1] == "GamePass" then "Gamepass_Purchase" else "Product_Purchase")
		elseif action == "Results" then
			playLocal("Result")
		end
	end)
end

return SoundController
