--!strict

local AvatarEditorService = game:GetService("AvatarEditorService")

local FavoritePromptController = {}

local PROMPT_DELAY = 60
local initialized = false

function FavoritePromptController.Init()
	if initialized then
		return
	end
	initialized = true

	task.delay(PROMPT_DELAY, function()
		local success, problem = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		if not success then
			warn(`[ColorGame] Could not show favorite prompt: {problem}`)
		end
	end)
end

return FavoritePromptController
