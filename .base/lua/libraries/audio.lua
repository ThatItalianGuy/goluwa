audio = _G.audio or {}

audio.objects = audio.objects or {}
audio.effect_channels = audio.effect_channels or {}

function audio.Open(name)
	os.setenv("ALSOFT_CONF", lfs.currentdir() .. "\\" .. "al_config.ini")
	audio.Close()

	if not name then
		name = audio.GetAllOutputDevices()[1]
	end

	logf("[audio] opening device %q for sound output", name)

	local device = alc.OpenDevice(name)

	-- needed to provide debugging info for alc
	alc.device = device
	al.debug = true
	alc.debug = true

	local context = alc.CreateContext(device, nil)
	alc.MakeContextCurrent(context)

	audio.device = device
	audio.context = context
end

function audio.Close()
	for k, v in pairs(audio.objects) do
		if v:IsValid() then
			v:Remove()
		end
	end

	table.clear(audio.objects)

	if audio.context then
		alc.DestroyContext(audio.context)
	end

	if audio.device then
		alc.CloseDevice(audio.device)
	end
end

function audio.GetAllOutputDevices()
	local list = ffi.cast("unsigned char *", alc.GetString(nil, e.ALC_ALL_DEVICES_SPECIFIER))

	local devices = {}

	local temp = {}

	for i = 0, 1000 do
		local byte = list[i]

		if byte == 0 then
			table.insert(devices, table.concat(temp))
			temp = {}
		else
			table.insert(temp, string.char(byte))
		end

		if byte == 0 and list[i + 1] == 0 then break end
	end

	return devices
end

function audio.GetAllInputDevices()
	local list = alc.GetString(nil, e.ALC_CAPTURE_DEVICE_SPECIFIER)

	local devices = {}

	local temp = {}

	for i = 0, 1000 do
		local byte = list[i]

		if byte == 0 then
			table.insert(devices, table.concat(temp))
			temp = {}
		else
			table.insert(temp, string.char(byte))
		end

		if byte == 0 and list[i + 1] == 0 then break end
	end

	return devices
end

function audio.GetEffectChannel(i)
	i = i or 1
	audio.effect_channels[i] = audio.effect_channels[i] or audio.CreateAuxiliaryEffectSlot()
	return audio.effect_channels[i]
end

function audio.SetEffect(channel, effect)
	local aux = audio.GetEffectChannel(channel)
	aux:SetEffect(effect)
end

function audio.SetDistanceModel(enum)
	al.DistanceModel(enum)
	audio.distance_model = enum
end

function audio.GetDistanceModel()
	return audio.distance_model
end

local function ADD_LISTENER_FUNCTION(name, func, enum, val, vec, sigh)
	if vec then
		if sigh then
			audio["SetListener" .. name] = function(x, y, z, a, b, c)

				val[0] = x or 0
				val[1] = y or 0
				val[2] = z or 0

				val[3] = a or 0
				val[4] = b or 0
				val[5] = c or 0

				func(enum, val)
			end

			audio["GetListener" .. name] = function()
				return val[0], val[1], val[2], val[3], val[4], val[5]
			end
		else
			audio["SetListener" .. name] = function(x, y, z)

				val[0] = x or 0
				val[1] = y or 0
				val[2] = z or 0

				func(enum, val)
			end

			audio["GetListener" .. name] = function()
				return val[0], val[1], val[2]
			end
		end
	else
		audio["SetListener" .. name] = function(x)

			val[0] = x

			func(enum, val)
		end

		audio["GetListener" .. name] = function()
			return val[0]
		end
	end
end

ADD_LISTENER_FUNCTION("Gain", al.Listenerfv, e.AL_GAIN, ffi.new("float[1]"))
ADD_LISTENER_FUNCTION("Position", al.Listenerfv, e.AL_POSITION, ffi.new("float[3]"), true)
ADD_LISTENER_FUNCTION("Velocity", al.Listenerfv, e.AL_VELOCITY, ffi.new("float[3]"), true)
ADD_LISTENER_FUNCTION("Orientation", al.Listenerfv, e.AL_ORIENTATION, ffi.new("float[6]"), true, true)

local function GET_BINDER(META, object_name)
	return function(name, type, enum)

		local set = al[object_name .. type]
		local get = al["Get" .. object_name .. type]

		if not enum then
			enum = e[name]
			name = name:gsub("AL_", "")
			name = name:gsub(object_name:upper() .. "_", "")
			name = name:lower()
			name = name:gsub("(_%l)", function(char) return char:upper():sub(2,2) end)
			name = name:sub(1,1):upper() .. name:sub(2)
		end

		local number_type

		if type == "i" or type == "b" then
			number_type = "ALint"
		elseif type == "f" then
			number_type = "ALfloat"
		elseif type == "iv" then
			number_type = "ALint"
			type = "v"
		elseif type == "fv" then
			number_type = "ALfloat"
			type = "v"
		end

		if type == "b" then
			set = al[object_name .. "i"]
			get = al["Get" .. object_name .. "i"]
		end

		if type == "v" then
			local val = ffi.new(number_type .. "[3]", 0, 0, 0)
			META["Set" .. name] = function(self, x, y, z)

				val[0] = x or 0
				val[1] = y or 0
				val[2] = z or 0

				set(self.id, enum, val)
			end

			META["Get" .. name] = function(self)
				get(self.id, enum, val)
				return val[0], val[1], val[2]
			end
		else
			local val = ffi.new(number_type .. "[1]", 0)

			if type == "b" then
				META["Set" .. name] = function(self, bool)

					val[0] = bool and 1 or 0

					set(self.id, enum, val[0])
				end

				META["Get" .. name] = function(self)
					get(self.id, enum, val)
					return val[0] == 1
				end
			else
				META["Set" .. name] = function(self, x)

					val[0] = x

					set(self.id, enum, val[0])
				end

				META["Get" .. name] = function(self)
					get(self.id, enum, val)
					return val[0]
				end
			end
		end
	end
end

local function GEN_TEMPLATE(type, ctor, on_remove)
	local type2 = type:lower()

	local META = utilities.CreateBaseMeta(type2)
	META.__index = META

	local fmt = type2 .. "[%i]"
	function META:__tostring()
		return (fmt):format(self.id)
	end

	local set_fv = al[type.."fv"]
	local set_f = al[type.."f"]
	local temp = ffi.new("float[3]")

	function META:SetParam(key, x, y, z)

		if self.params and self.params[key] then
			local val = x or self.params[key].default

			if self.params[key].min and self.params[key].max then
				val = math.clamp(val, self.params[key].min, self.params[key].max)
			end

			set_f(self.id, self.params[key].enum, val)

			self.params[key].val = val
		elseif y and z then
			temp[0] = x
			temp[1] = y
			temp[2] = z

			set_fv(self.id, key, x, y, z)
		elseif x then
			set_f(self.id, key, x)
		end

	end

	local get_fv = al[type.."Getfv"]
	local temp = ffi.new("float[3]")

	function META:GetParam(key)
		get_fv(self.id, key, temp)

		return temp[0], temp[1], temp[2]
	end

	local key = "Gen" .. type

	local create = function(...)
		local self = setmetatable({}, META)

		self.id = al[key]()

		if ctor then
			ctor(self, ...)
		end

		utilities.SetGCCallback(self)

		-- this kind of wont really make gc of any use
		audio.objects[self] = self

		return self
	end

	audio["Create".. type] = create
	--_G[type] = create

	local delete = al["Delete"..type.."s"]
	local temp = ffi.new("int[1]", 0)
	function META:OnRemove()
		if on_remove then on_remove(self) end

		audio.objects[self] = nil

		temp[0] = self.id
		delete(1, temp)
	end

	return META
end

local function ADD_SET_GET_OBJECT(META, ADD_FUNCTION, name, ...)
	ADD_FUNCTION(name.."ID", ...)

	class.GetSet(META, name, NULL)

	local set = META["Set"..name.."ID"]
	META["Set"..name] = function(self, var, ...)
		set(self, var and var.id or 0, ...)
		self[name] = var
	end
end

do -- source
	local META = GEN_TEMPLATE("Source", function(self, var, ...)

		self.effects = {}

		if type(var) == "cdata" then
			local buffer = audio.CreateBuffer()
			buffer:SetData(var, ...)
			self:SetBuffer(buffer)
		elseif type(var) == "string" then
			vfs.ReadAsync(var, function(data)
				local data, length, info = audio.Decode(data)

				if data then
					local buffer = audio.CreateBuffer()
					buffer:SetFormat(info.channels == 1 and e.AL_FORMAT_MONO16 or e.AL_FORMAT_STEREO16)
					buffer:SetSampleRate(info.samplerate)
					buffer:SetData(data, length)

					self:SetBuffer(buffer)

					self.decode_info = info
					self.ready = true

					-- in case it's instantly loaded and OnLoad is defined the same frame
					timer.Delay(0, function() if self.OnLoad then self:OnLoad(info) end end)
				end
			end, 20)
		end
	end,
	function(self)
		for i,v in pairs(self.effects) do
			if v.slot:IsValid() then
				v.slot:Remove()
			end
		end
	end
	)

	function META:Play()
		al.SourcePlay(self.id)
	end

	function META:Pause()
		al.SourcePause(self.id)
	end

	function META:Stop()
		al.SourceStop(self.id)
	end

	function META:Rewind()
		al.SourceRewind(self.id)
	end

	do -- length stuff
		function META:Seek(offset, type)
			if type~="samples" then
				offset = offset * self:GetBuffer():GetSampleRate()
			end

			self:SetSampleOffset(offset)
		end

		function META:Tell(type)
			if type=="samples" then
				return self:GetSampleOffset()
			else
				return self:GetSampleOffset() / self:GetBuffer():GetSampleRate()
			end
		end

		function META:GetLength()
			return select(2, self:GetBuffer():GetData())
		end

		function META:GetDuration()
			return tonumber(select(2, self:GetBuffer():GetData())) / self:GetBuffer():GetSampleRate()
		end
	end

	do
		local buffers = ffi.new("ALuint[1]")
		local pushed = {}

		function META:PushBuffer(buffer)
			buffers[0] = buffer.id
			pushed[buffer.id] = buffer
			al.SourceQueueBuffers(self.id, 1, buffers)
		end

		local buffers = ffi.new("ALuint[1]")

		function META:PopBuffer()
			al.SourceUnqueueBuffers(self.id, 1, buffers)
			return pushed[buffers[0]] or NULL
		end
	end

	do
		-- http://wiki.delphigl.com/index.php/alGetSource

		local ADD_FUNCTION = GET_BINDER(META, "Source")

		ADD_FUNCTION("AL_SAMPLE_OFFSET", "i")
		ADD_FUNCTION("AL_GAIN", "f")
		ADD_FUNCTION("AL_LOOPING", "b")
		ADD_FUNCTION("AL_MAX_GAIN", "f")
		ADD_FUNCTION("AL_MAX_DISTANCE", "f")
		ADD_FUNCTION("AL_REFERENCE_DISTANCE", "f")
		ADD_FUNCTION("AL_ROLLOFF_FACTOR", "f")
		ADD_FUNCTION("AL_PITCH", "f")
		ADD_FUNCTION("AL_SOURCE_RELATIVE", "b")
		ADD_FUNCTION("AL_SOURCE_STATE", "i")
		ADD_FUNCTION("AL_SOURCE_TYPE", "i")
		ADD_FUNCTION("AL_VELOCITY", "fv")
		ADD_FUNCTION("AL_DIRECTION", "fv")
		ADD_FUNCTION("AL_POSITION", "fv")
		ADD_FUNCTION("AL_BYTE_OFFSET", "i")

		ADD_SET_GET_OBJECT(META, ADD_FUNCTION, "AuxiliaryEffectSlot", "iv", e.AL_AUXILIARY_SEND_FILTER)
		ADD_SET_GET_OBJECT(META, ADD_FUNCTION, "Buffer", "i", e.AL_BUFFER)
		ADD_SET_GET_OBJECT(META, ADD_FUNCTION, "Filter", "i", e.AL_DIRECT_FILTER)
	end

	function META:SetChannel(channel, ...)
		self:SetAuxiliaryEffectSlot(audio.GetEffectChannel(channel), ...)
	end

	function META:AddEffect(effect, id)
		id = id or effect

		self:RemoveEffect(id)

		local slot = audio.CreateAuxiliaryEffectSlot()
		slot:SetEffect(effect)

		table.insert(self.effects, {id = id, slot = slot, effect = effect})

		self:SetAuxiliaryEffectSlot(slot, #self.effects)
	end

	function META:RemoveEffect(id)
		for i,v in pairs(self.effects) do
			if v.id == id then
				v.slot:Remove()
				self:SetAuxiliaryEffectSlot(nil, i)
				table.remove(self.effects, i)
				break
			end
		end
	end
end

do -- buffer
	local META = GEN_TEMPLATE("Buffer", function(self, data, size)
		if data and size then
			self:SetData(data, size)
		end
	end)

	class.GetSet(META, "Format", e.AL_FORMAT_MONO16)
	class.GetSet(META, "SampleRate", 44100)

	do
		-- http://wiki.delphigl.com/index.php/alGetBuffer

		local ADD_FUNCTION = GET_BINDER(META, "Buffer")

		ADD_FUNCTION("AL_BITS", "iv")
		ADD_FUNCTION("AL_CHANNELS", "i")
		ADD_FUNCTION("AL_FREQUENCY", "i")
		ADD_FUNCTION("AL_SIZE", "i")

	end

	function META:SetData(data, size)
		al.BufferData(self.id, self.Format, data, size, self.SampleRate)

		self.buffer_data = {data, size}
	end

	function META:GetData()
		if self.buffer_data then
			return unpack(self.buffer_data)
		end

		return nil, 0
	end
end

do -- effect
	local available = al.GetAvailableEffects()

	local META = GEN_TEMPLATE("Effect", function(self, var, override_params)
		if available[var] then
			self:SetType(available[var].enum)
			self.params = table.copy(available[var].params)
			if override_params then
				for k,v in pairs(override_params) do self:SetParam(k, v) end
			else
				for k,v in pairs(self.params) do v.val = v.default end
			end
		else
			self:SetType(var)
		end
	end)

	do
		local ADD_FUNCTION = GET_BINDER(META, "Effect")
		ADD_FUNCTION("Type", "i", e.AL_EFFECT_TYPE)
	end

	function META:BindToChannel(channel)
		audio.SetEffect(channel, self)
	end

	function META:UnbindFromChannel()
		audio.SetEffect(channel, self)
	end

	function META:GetParams()
		return self.params
	end
end

do -- filter
	local available = al.GetAvailableFilters()

	local META = GEN_TEMPLATE("Filter", function(self, var, override_params)
		if available[var] then
			self:SetType(available[var].enum)
			self.params = table.copy(available[var].params)
			if override_params then
				for k,v in pairs(override_params) do self:SetParam(k, v) end
			else
				for k,v in pairs(self.params) do v.val = v.default end
			end		else
			self:SetType(var)
		end
	end)

	do
		local ADD_FUNCTION = GET_BINDER(META, "Filter")
		ADD_FUNCTION("Type", "i", e.AL_FILTER_TYPE)
	end
end

do -- auxiliary effect slot
	local META = GEN_TEMPLATE("AuxiliaryEffectSlot", function(self, effect)
		if typex(effect) == "effect" then
			self:SetEffect(effect)
		end
	end)

	do
		local ADD_FUNCTION = GET_BINDER(META, "AuxiliaryEffectSlot")

		ADD_FUNCTION("AL_EFFECTSLOT_GAIN", "f")
		ADD_SET_GET_OBJECT(META, ADD_FUNCTION, "Effect", "i", e.AL_EFFECTSLOT_EFFECT)
	end

	function META:GetParams()
		return self.params
	end
end

_G.Sound = audio.CreateSource

do -- microphone
	local META = utilities.CreateBaseMeta("audio_capture")
	META.__index = META

	function META:Start(func)
		alc.CaptureStart(self.id)
	end
	
	function META:Stop()
		alc.CaptureStop(self.id)
		self.stopped = true
	end

	function META:FeedSource(source)
	
		source:SetLooping(false)

		-- fill it with some silence first so we can pop safely (???)
		source:PushBuffer(audio.CreateBuffer(ffi.new("ALshort[4]"), 4))
		
		timer.Thinker(function()
			if not self:IsValid() or self.stopped then return true end

			if self:IsFull() then
				local buffer = source:PopBuffer()
					if buffer:IsValid() then
						local data, size = self:Read()

						if self.OnBufferData then
							local a, b = self:OnBufferData(data, size)

							if a and b then
								data = a
								size = b
							end
						end

						buffer:SetData(data, size)
					source:PushBuffer(buffer)
				end
			end
		end)
	end

	local val = ffi.new("ALint[1]")

	function META:GetCapturedSamples()
		alc.GetIntegerv(self.id, e.ALC_CAPTURE_SAMPLES, 1, val)
		return val[0]
	end

	function META:IsFull()
		return self:GetCapturedSamples() >= self.buffer_size
	end

	function META:Read()
		local size = self:GetCapturedSamples()
		local buffer = ffi.new("ALshort[?]", size)

		alc.CaptureSamples(id, buffer, size)

		return buffer, size
	end

	function META:OnRemove()
		alc.CaptureCloseDevice(self.id)
	end

	function audio.CreateAudioCapture(name, sample_rate, format, buffer_size)
		sample_rate = sample_rate or 44100
		format = format or e.AL_FORMAT_MONO16
		buffer_size = buffer_size or 4096

		if not name then
			name = audio.GetAllInputDevices()[1]
		end

		logf("[audio] opening device %q for input", name)

		local self = setmetatable({}, META)

		utilities.SetGCCallback(self)

		self.buffer_size = buffer_size

		self.id = alc.CaptureOpenDevice(name, sample_rate, format, buffer_size)
		
		audio.objects[self] = self

		return self
	end

end

function audio.Decode(data, length)

	if type(length) == "number" and type(data) == "cdata" then
		data = ffi.string(data, length)
	end

	-- use a dummy file so we can read from memory...
	local  name = os.tmpname()
	local file = assert(io.open(name, "wb"))
	file:write(data)
	file:close()

	local info = ffi.new("SF_INFO[1]")
	local file = soundfile.Open(name, e.SFM_READ, info)
	info = info[0]

	local err = ffi.string(soundfile.StringError(file))

	if err ~= "No Error." then
		return false, err
	end

	local typename
	local extension
	local subname

	do
		local data = ffi.new("SF_FORMAT_INFO[1]")
		data[0].format = info.format
		soundfile.Command(nil, e.SFC_GET_FORMAT_INFO, data, ffi.sizeof("SF_FORMAT_INFO"))

		typename = ffi.string(data[0].name)
		extension = ffi.string(data[0].extension)

		data[0].format = bit.band(info.format , e.SF_FORMAT_SUBMASK)
		soundfile.Command(nil, e.SFC_GET_FORMAT_INFO, data, ffi.sizeof("SF_FORMAT_INFO"))
		subname = ffi.string(data[0].name)
	end

	local info = {
		frames = tonumber(info.frames),
		channels = info.channels,
		format = format,
		sections = info.sections,
		seekable = info.seekable ~= 0,
		subname = subname,
		extension = extension,
		typename = typename,
		samplerate = info.samplerate,
		buffer_length = info.frames * info.channels * ffi.sizeof("ALshort"),
	}

	local buffer = ffi.new("ALshort[?]", info.buffer_length)
	-- just read everything
	-- maybe have a callback later using coroutines
	soundfile.ReadShort(file, buffer, info.buffer_length)

	soundfile.Close(file)

	os.remove(name)

	return buffer, info.buffer_length, info
end

audio.Open()