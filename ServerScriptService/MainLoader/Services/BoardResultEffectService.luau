--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardResultEffectService = {}

local effectsFolder: Folder
local VFX_ACTIVE_DURATION = 1
local CLEANUP_DELAY_AFTER_VFX = 5

local function findColorButton(board: Instance, color: string): BasePart?
	local normalized = string.lower(color)
	for _, descendant in board:GetDescendants() do
		if descendant:IsA("BasePart") and string.lower(descendant.Name) == normalized then
			return descendant
		end
	end
	return nil
end

local function findTemplate(multiplier: number): Instance?
	local baseName = if multiplier == 3 then "Triple" else "Double"
	return effectsFolder:FindFirstChild(`{baseName}Attachment`) or effectsFolder:FindFirstChild(baseName)
end

local function setVfxInstanceEnabled(instance: Instance, enabled: boolean)
	if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")
		or instance:IsA("Light") then
		instance.Enabled = enabled
	end
end

local function setVfxEnabled(root: Instance, enabled: boolean)
	setVfxInstanceEnabled(root, enabled)
	for _, descendant in root:GetDescendants() do
		setVfxInstanceEnabled(descendant, enabled)
	end
end

function BoardResultEffectService.Play(board: Instance, color: string, multiplier: number): (boolean, string)
	multiplier = math.floor(multiplier)
	if multiplier ~= 2 and multiplier ~= 3 then
		return false, "Multiplier must be 2 or 3."
	end
	local colorButton = findColorButton(board, color)
	if not colorButton then
		return false, `Color button {color} was not found on {board:GetFullName()}.`
	end
	local template = findTemplate(multiplier)
	if not template then
		return false, `Assets.Fx.{if multiplier == 3 then "Triple" else "Double"} is missing.`
	end

	local clone = template:Clone()
	clone.Name = if multiplier == 3 then "TripleAttachment" else "DoubleAttachment"
	clone:SetAttribute("ColorGameResultEffect", true)
	setVfxEnabled(clone, false)
	clone.Parent = colorButton

	setVfxEnabled(clone, true)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Sound") then
			descendant:Play()
		end
	end

	task.delay(VFX_ACTIVE_DURATION, function()
		if clone.Parent then
			setVfxEnabled(clone, false)
		end
	end)
	task.delay(VFX_ACTIVE_DURATION + CLEANUP_DELAY_AFTER_VFX, function()
		-- Cleanup starts five seconds after the visual emitters are disabled.
		-- Any longer sound is detached so it can finish naturally.
		if clone.Parent then
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("Sound") and descendant.IsPlaying then
					descendant.Parent = colorButton
					descendant.Ended:Once(function()
						descendant:Destroy()
					end)
				end
			end
		end
		clone:Destroy()
	end)
	return true, `{multiplier}x {color} effect played.`
end

function BoardResultEffectService.Init()
	effectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Fx") :: Folder
	for _, multiplier in { 2, 3 } do
		if not findTemplate(multiplier) then
			warn(`[ColorGame] Missing board result effect asset for {multiplier}x.`)
		end
	end
end

return BoardResultEffectService
