local SoundService = game:GetService("SoundService")

-- Reference
local SFXFolder = SoundService:WaitForChild("SFX")

local self = {}

function self.PlaySFX(Name: string)
    local CurrentSFX = SFXFolder:FindFirstChild(Name) :: Sound

    if CurrentSFX then
        CurrentSFX:Play()
    end
end

return self