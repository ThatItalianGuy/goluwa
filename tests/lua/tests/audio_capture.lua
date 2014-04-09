debug.LogLibrary("al", {"GenBuffers", "GenSources", "GetError"}, true)
debug.LogLibrary("alc", {"GenBuffers", "GenSources", "GetError"}, true)

local mic_out = utilities.RemoveOldObject(audio.CreateSource())

local mic_in = audio.CreateAudioCapture()
mic_in:Start()  
mic_in:FeedSource(mic_out)

function mic_in:OnBufferData(data, size)
	for i = 0, size - 1 do
		-- ??
	end
end

mic_out:Play()

timer.Delay(0.1, function()

debug.LogLibrary("al")
debug.LogLibrary("alc")
 
end) 