--!strict

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local MusicController = {}

local tracks: { Sound } = {}
local randomizer = Random.new()
local started = false

local function shuffledTracks(): { Sound }
	local shuffled = table.clone(tracks)
	for index = #shuffled, 2, -1 do
		local swapIndex = randomizer:NextInteger(1, index)
		shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
	end
	return shuffled
end

local function playTrack(track: Sound)
	track.Looped = false
	track.TimePosition = 0
	local finished = false
	local endedConnection = track.Ended:Connect(function()
		finished = true
	end)
	local stoppedConnection = track.Stopped:Connect(function()
		finished = true
	end)
	track:Play()

	local loadDeadline = os.clock() + 10
	while not finished and track.Parent do
		if not track.IsPlaying and (track.IsLoaded or os.clock() >= loadDeadline) then
			break
		end
		task.wait(0.25)
	end
	endedConnection:Disconnect()
	stoppedConnection:Disconnect()
end

function MusicController.Init()
	if started then
		return
	end
	started = true

	local musicFolder = SoundService:WaitForChild("Music")
	for _, child in musicFolder:GetChildren() do
		if child:IsA("Sound") then
			child:Stop()
			table.insert(tracks, child)
		end
	end
	if #tracks == 0 then
		warn("[ColorGame] SoundService.Music has no music tracks")
		return
	end

	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, tracks)
		while true do
			for _, track in shuffledTracks() do
				playTrack(track)
			end
		end
	end)
end

return MusicController
