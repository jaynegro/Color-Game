--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
local SoundController = require(script.Parent.SoundController)

local WinDropController = {}

local dropAsset: Instance
local effectsFolder: Folder

local function setEffectCFrame(effect: Instance, cframe: CFrame)
	if effect:IsA("Model") then
		effect:PivotTo(cframe)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cframe
	end
end

local function prepareEffect(effect: Instance): boolean
	if effect:IsA("BasePart") then
		effect.Anchored = true
		effect.CanCollide = false
		effect.CanTouch = false
		effect.CanQuery = false
	elseif not effect:IsA("Model") then
		return false
	end
	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	return true
end

local function getDicePosition(index: number): Vector3?
	local die = workspace:FindFirstChild(`RoundDice{index}`)
	if not die then
		return nil
	end
	if die:IsA("Model") then
		local body = die:FindFirstChild("BodyMesh", true)
		if body and body:IsA("BasePart") then
			return body.Position
		end
		return die:GetPivot().Position
	elseif die:IsA("BasePart") then
		return die.Position
	end
	return nil
end

local function flyDrop(startPosition: Vector3, winner: Player)
	local character = winner.Character
	local targetPart = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head"))
	if not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	local effect = dropAsset:Clone()
	if not prepareEffect(effect) then
		effect:Destroy()
		return
	end
	effect.Parent = effectsFolder

	local duration = 1
	local startedAt = os.clock()
	local controlPosition = startPosition + Vector3.new(0, 8, 0)
	while effect.Parent do
		local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local targetPosition = targetPart.Position + Vector3.new(0, 2, 0)
		local inverse = 1 - alpha
		local position = inverse * inverse * startPosition
			+ 2 * inverse * alpha * controlPosition
			+ alpha * alpha * targetPosition
		setEffectCFrame(effect, CFrame.new(position) * CFrame.Angles(0, alpha * math.pi * 4, 0))
		if alpha >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if winner == Players.LocalPlayer then
		SoundController.Play("WinReceived")
	end
	effect:Destroy()
end

local function renderDrops(results: any, report: any)
	if type(results) ~= "table" or type(report) ~= "table" or type(report.Winners) ~= "table" then
		return
	end
	for _, winnerInfo in report.Winners do
		if type(winnerInfo) == "table" and type(winnerInfo.UserId) == "number" then
			local winner = Players:GetPlayerByUserId(winnerInfo.UserId)
			if winner then
				local matchingIndices = {}
				if winnerInfo.Choice == "Rainbow" then
					table.insert(matchingIndices, 1)
				else
					for index, result in results do
						if string.lower(tostring(result)) == string.lower(tostring(winnerInfo.Choice)) then
							table.insert(matchingIndices, index)
						end
					end
				end
				for _, index in matchingIndices do
					local startPosition = getDicePosition(index)
					if startPosition then
						task.spawn(flyDrop, startPosition, winner)
					end
				end
			end
		end
	end
end

function WinDropController.Init()
	dropAsset = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Fx"):WaitForChild("Drop")
	effectsFolder = workspace:FindFirstChild("ClientColorGameEffects") :: Folder
	if not effectsFolder then
		effectsFolder = Instance.new("Folder")
		effectsFolder.Name = "ClientColorGameEffects"
		effectsFolder.Parent = workspace
	end

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action ~= "Results" then
			return
		end
		local args = table.pack(...)
		renderDrops(args[2], args[3])
	end)
end

return WinDropController
