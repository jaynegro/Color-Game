--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ReplicaClient = require(ReplicatedStorage.Modules.Client.ReplicaClient)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local HUDController = {}
local randomizer = Random.new()

local function playCoinSound()
	local sfx = SoundService:FindFirstChild("SFX")
	local source = sfx and sfx:FindFirstChild("CoinObtained")
	if not source or not source:IsA("Sound") then
		return
	end
	local sound = source:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength + 1, 3))
end

local function setAmount(container: Instance, value: number)
	local amount = container:FindFirstChild("Amount", true)
	if not amount or not (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
		return
	end
	amount.Text = tostring(value)
	local shadow = amount:FindFirstChild("Amount2")
	if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
		shadow.Text = amount.Text
	end
end

local function pulseAmount(amount: TextLabel | TextButton)
	local scale = amount:FindFirstChild("CoinAmountScale")
	if not scale or not scale:IsA("UIScale") then
		if scale then
			scale:Destroy()
		end
		scale = Instance.new("UIScale")
		scale.Name = "CoinAmountScale"
		scale.Parent = amount
	end
	local typedScale = scale :: UIScale
	typedScale.Scale = 1
	local originalColor = amount.TextColor3
	local grow = TweenService:Create(typedScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.25,
	})
	TweenService:Create(amount, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(255, 230, 63) }):Play()
	grow:Play()
	grow.Completed:Once(function()
		TweenService:Create(typedScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		TweenService:Create(amount, TweenInfo.new(0.2), { TextColor3 = originalColor }):Play()
	end)
end

local function flyCoin(hud: ScreenGui, coinLabel: GuiObject, template: GuiObject)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local startX = camera.ViewportSize.X * 0.5
	local startY = camera.ViewportSize.Y * 0.55
	if root and root:IsA("BasePart") then
		local screenPosition, visible = camera:WorldToScreenPoint(root.Position + Vector3.new(0, 2, 0))
		if visible then
			startX = screenPosition.X
			startY = screenPosition.Y
		end
	end

	local coin = template:Clone()
	coin.Name = "CoinObtainEffect"
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromOffset(startX, startY)
	coin.Rotation = randomizer:NextNumber(-25, 25)
	coin.Visible = true
	coin.ZIndex = math.max(template.ZIndex, 100)
	coin.Parent = hud

	local scatterPosition = UDim2.fromOffset(
		startX + randomizer:NextNumber(-80, 80),
		startY + randomizer:NextNumber(-70, 35)
	)
	local scatter = TweenService:Create(coin, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = scatterPosition,
	})
	scatter:Play()
	scatter.Completed:Once(function()
		if not coin.Parent or not coinLabel.Parent then
			coin:Destroy()
			return
		end
		local target = coinLabel.AbsolutePosition + coinLabel.AbsoluteSize * 0.5
		local travel = TweenService:Create(coin, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(target.X, target.Y),
			Rotation = 0,
		})
		travel:Play()
		travel.Completed:Once(function()
			playCoinSound()
			coin:Destroy()
		end)
	end)
end

local function playCoinReward(hud: ScreenGui, coinLabel: GuiObject, template: GuiObject, amount: number)
	local count = math.clamp(math.floor(amount), 0, 80)
	for index = 1, count do
		task.delay((index - 1) * 0.025, flyCoin, hud, coinLabel, template)
	end
end

function HUDController.Init()
	local player = Players.LocalPlayer
	local hudInstance = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	assert(hudInstance:IsA("ScreenGui"), "[ColorGame] PlayerGui.HUD must be a ScreenGui")
	local hud = hudInstance
	local top = hud:WaitForChild("Top")
	local winContainer = top:WaitForChild("WinContainer")
	local streakContainer = top:WaitForChild("StreakContainer")
	local coinLabel = hud:WaitForChild("CoinLabel")
	assert(coinLabel:IsA("GuiObject"), "[ColorGame] HUD.CoinLabel must be a GuiObject")
	local coinAmount = coinLabel:WaitForChild("Amount")
	local effectTemplate = coinLabel:WaitForChild("EffectLabel")
	assert(coinAmount:IsA("TextLabel") or coinAmount:IsA("TextButton"), "[ColorGame] CoinLabel.Amount must be text")
	assert(effectTemplate:IsA("GuiObject"), "[ColorGame] CoinLabel.EffectLabel must be a GuiObject")
	effectTemplate.Visible = false
	local lastCoins: number? = nil

	ReplicaClient.OnNew("PlayerData", function(replica)
		if replica.Tags.UserId ~= player.UserId then
			return
		end
		local function render()
			setAmount(winContainer, replica.Data.Wins or 0)
			setAmount(streakContainer, replica.Data.Streak or 0)
			local coins = math.max(0, math.floor(tonumber(replica.Data.Coins) or 0))
			coinAmount.Text = tostring(coins)
			local shadow = coinAmount:FindFirstChild("Amount2")
			if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
				shadow.Text = coinAmount.Text
			end
			if lastCoins ~= nil and coins ~= lastCoins then
				pulseAmount(coinAmount)
			end
			lastCoins = coins
		end
		render()
		replica:OnChange(render)
	end)

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, amount: any)
		if action == "CoinEarned" and type(amount) == "number" and amount > 0 then
			playCoinReward(hud, coinLabel, effectTemplate, amount)
		end
	end)
	ReplicaClient.RequestData()
end

return HUDController
