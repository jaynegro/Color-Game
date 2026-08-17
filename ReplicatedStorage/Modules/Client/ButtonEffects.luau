--!strict

local TweenService = game:GetService("TweenService")

local ButtonEffects = {}

local HOVER_SCALE = 1.04
local PRESSED_SCALE = 0.94
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tweenScale(scale: UIScale, value: number)
	TweenService:Create(scale, TWEEN_INFO, { Scale = value }):Play()
end

function ButtonEffects.Bind(button: GuiButton, callback: () -> ())
	button.AutoButtonColor = false

	local scale = button:FindFirstChild("ButtonEffectScale")
	if not scale or not scale:IsA("UIScale") then
		if scale then
			scale:Destroy()
		end
		scale = Instance.new("UIScale")
		scale.Name = "ButtonEffectScale"
		scale.Parent = button
	end

	local typedScale = scale :: UIScale
	local hovering = false

	button.MouseEnter:Connect(function()
		hovering = true
		tweenScale(typedScale, HOVER_SCALE)
	end)

	button.MouseLeave:Connect(function()
		hovering = false
		tweenScale(typedScale, 1)
	end)

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenScale(typedScale, PRESSED_SCALE)
		end
	end)

	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenScale(typedScale, if hovering then HOVER_SCALE else 1)
		end
	end)

	return button.Activated:Connect(callback)
end

return ButtonEffects
