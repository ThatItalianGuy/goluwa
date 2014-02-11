-- finihs caret movement port from text iput

local META = {}
META.__index = META

function _G.Markup(a, ...)
	local self = {w = 0, h = 0, chunk = {}}
	setmetatable(self, META)

	if a then
		self:SetTable({a, ...})
	end

	return self
end

class.GetSet(META, "Table", {})
class.GetSet(META, "MaxWidth", 500)
class.GetSet(META, "EditMode", false)
 
function META:SetEditMode(b)
	self.EditMode = b
	self.need_layout = true
end

function META:SetTable(tbl)
	self.Table = tbl
	self.need_layout = true
end

function META:SetMaxWidth(w)
	self.MaxWidth = w
	self.need_layout = true
end

-- these are used by EXT.SetColor, EXT.SetFont etc
local FONT = "markup"
local R, G, B, A = 255, 255, 255, 255
local X, Y = 0, 0

local EXT = {
	Rand = math.randomf,
	FormatPrint = logf,
	GetFrameTime = timer.GetFrameTime,
	GetTime = timer.GetTime,
	LoadString = loadstring,
	CreateConVar = console.CreateVariable,
	GetConVarFloat = function(c) return c:Get() end,

	HSVToColor = function(h,s,v) return HSVToColor(h,s,v):Unpack() end,

	SetMaterial = surface.SetTexture,
	SetColor = function(r,g,b,a)
		R=r G=g B=b A=a or 1

		if R>1 then R=R/255 end
		if G>1 then G=G/255 end
		if B>1 then B=B/255 end
		if A>1 then A=A/255 end

		surface.Color(R,G,B,A)
	end,
	DrawRect = surface.DrawRect,
	DrawText = surface.DrawText,
	SetTextPos = function(x, y) X=x Y=y surface.SetTextPos(x,y) end,
	SetFont = function(str)
		FONT = str
		surface.SetFont(str)
	end,
	GetTextSize = surface.GetTextSize,
	SetAlphaMultiplier = surface.SetAlphaMultiplier,
	GetScreenHeight = function() return select(2, surface.GetScreenSize()) end,
	GetScreenWidth = function() return (surface.GetScreenSize()) end,

	SetCullClockWise = function(b) end,
	FindMaterial = Image,
	CreateMatrix = Matrix44,

	TranslateMatrix = function(m, x, y) m:Translate(x or 0, y or 0, 0) end,
	ScaleMatrix = function(m, x, y) m:Scale(x or 0, y or 0, 1) end,
	RotateMatrix = function(m, a) m:Rotate(a, 0, 0, 1) end,

	PushMatrix = render.PushWorldMatrixEx,
	PopMatrix = render.PopWorldMatrix,
}

-- config start

META.fonts = {
	default = {
		name = "markup_default",
		data = {
			font = "DejaVu Sans",
			size = 14,
			antialias = true,
			outline = false,
			weight = 580,
		} ,
	},

	chatprint = {
		name = "markup_chatprint",
		color = Color(201, 255, 41, 255),
		data = {
			font = "Verdana",
			size = 16,
			weight = 600,
			antialias = true,
			shadow = true,
		},
	},
}

do -- tags
	META.tags = {}

	do -- base

		META.tags.hsv =
		{
			arguments = {0, 1, 1},

			draw = function(markup, self, x,y, h, s, v)
				local r,g,b = EXT.HSVToColor(h, s, v)
				EXT.SetColor(r, g, b, 255)
			end,
		}

		META.tags.color =
		{
			arguments = {255, 255, 255, 255},

			draw = function(markup, self, x,y, r,g,b,a)
				EXT.SetColor(r, g, b, a)
			end,
		}

		META.tags.physics =
		{
			arguments = {1, 0, 0, 0, 0.99, 0.1},

			pre = function(markup, self, gx, gy, vx, vy, drag, rand_mult)
				local part = {}

				part =
				{
					pos = {x = 0, y = 0},
					vel = {x = vx, y = vy},
					siz = 10,
					rand_mult = rand_mult,
					drag = drag,
				}

				self.part = part
			end,

			draw = function(markup, self, x,y, gravity_y, gravity_x, vx, vy, drag, rand_mult)
				local delta = EXT.GetFrameTime() * 5

				local part = self.part

				local cx = x
				local cy = y - 10

				local W, H = markup.MaxWidth/2, EXT.GetScreenHeight()

				W = W - cx
				H = H - cy

				-- random velocity for some variation
				part.vel.y = part.vel.y + gravity_y + (EXT.Rand(-1,1) * rand_mult)
				part.vel.x = part.vel.x + gravity_x + (EXT.Rand(-1,1) * rand_mult)

				-- velocity
				part.pos.x = part.pos.x + (part.vel.x * delta)
				part.pos.y = part.pos.y + (part.vel.y * delta)

				-- friction
				part.vel.x = part.vel.x * part.drag
				part.vel.y = part.vel.y * part.drag

				-- collision
				if part.pos.x - part.siz < -cx then
					part.pos.x = -cx + part.siz
					part.vel.x = part.vel.x * -part.drag
				end

				if part.pos.x + part.siz > W then
					part.pos.x = W - part.siz
					part.vel.x = part.vel.x * -part.drag
				end

				if part.pos.y - part.siz < -cy then
					part.pos.y = -cy + part.siz
					part.vel.y = part.vel.y * -part.drag
				end

				if part.pos.y + part.siz > H then
					part.pos.y = H - part.siz
					part.vel.y = part.vel.y * -part.drag
				end

				local mat = EXT.CreateMatrix()

				EXT.TranslateMatrix(mat, part.pos.x, part.pos.y)

				EXT.PushMatrix(mat)
			end,

			post = function()
				EXT.PopMatrix()
			end,
		}

		META.tags.font =
		{
			arguments = {"markup_default"},

			draw = function(markup, self, x,y, font)
				EXT.SetFont(font)
			end,

			pre = function(markup, self, font)
				EXT.SetFont(font)
			end,
		}

		META.tags.texture =
		{
			arguments = {"error", {default = 1, min = 1, max = 4}},

			pre = function(markup, self, path)
				self.mat = EXT.FindMaterial(path)
			end,

			get_size = function(markup, self, path, size_mult)
				return 8 * size_mult, 8 * size_mult
			end,

			draw = function(markup, self, x,y,a, path)
				EXT.SetMaterial(self.mat)
				EXT.DrawRect(x, y, self.w, self.h)
			end,
		}

	end

	do -- matrix by !cake
		local function detM2x2 (m11, m12, m21, m22)
			return m11 * m22 - m12 * m21
		end

		local function mulM2x2V2 (m11, m12, m21, m22, v1, v2)
			return v1 * m11 + v2 * m12, v1 * m21 + v2 * m22
		end

		local function normalizeV2(x, y)
			local length = math.sqrt(x * x + y * y)
			return x / length, y / length
		end

		local function scaleV2(v1, v2, k)
			return v1 * k, v2 * k
		end

		local function eigenvector2(l, a, d)
			-- (a - ?) u1 + d u2 = 0
			if a - l == 0 then return 1, 0 end
			if     d == 0 then return 0, 1 end

			return normalizeV2(-d / (a - l), 1)
		end

		local function orthonormalM2x2ToVMatrix(m11, m12, m21, m22, mat)
			local det = detM2x2(m11, m12, m21, m22)

			if det < 0 then
				EXT.ScaleMatrix(mat, 1, -1)
			end

			local angle = math.atan2 (m21, m11)
			EXT.RotateMatrix(mat, math.deg(angle))

			return mat
		end

		META.tags.translate =
		{
			arguments = {0, 0},

			draw = function(markup, self, x, y, dx, dy)
				local mat = EXT.CreateMatrix()
				EXT.TranslateMatrix(mat, dx, dy)

				EXT.PushMatrix(mat)
			end,

			post = function()
				EXT.PopMatrix()
			end,
		}

		META.tags.scale =
		{
			arguments = {1, nil},

			draw = function(markup, self, x, y, scaleX, scaleY)
				local mat = EXT.CreateMatrix()

				scaleY = scaleY or scaleX
				self.matrixDeterminant = scaleX * scaleY

				if math.abs (self.matrixDeterminant) > 10 then
					scaleX, scaleY = normalizeV2(scaleX, scaleY)
					scaleX, scaleY = scaleV2(scaleX, scaleY, 10)
				end

				local centerY = y - self.message_height / 2

				EXT.TranslateMatrix(mat, x, centerY)
					EXT.ScaleMatrix(mat, scaleX, scaleY)

					if scaleX < 0 then
						EXT.TranslateMatrix(mat, -self.message_width, 0)
					end
				EXT.TranslateMatrix(mat, -x, -centerY)

				EXT.PushMatrix(mat)

				EXT.SetCullClockWise(self.matrixDeterminant < 0)
			end,

			post = function(markup, self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end

				EXT.PopMatrix()
			end,
		}

		META.tags.rotate =
		{
			arguments = {0},

			draw = function(markup, self, x, y, angleInDegrees)
				local mat = EXT.CreateMatrix()

				local centerX = x + self.message_width / 2
				local centerY = y - self.message_height / 2

				EXT.TranslateMatrix(mat, centerX, centerY)
					EXT.RotateMatrix(mat, angleInDegrees)
				EXT.TranslateMatrix(mat, -centerX, -centerY)

				EXT.PushMatrix(mat)
			end,

			post = function()
				EXT.PopMatrix()
			end,
		}

		META.tags.matrixez =
		{
			arguments = {0,0,1,1,0},

			draw = function(markup, self, x, y, X, Y, scaleX, scaleY, angleInDegrees)
				local mat = EXT.CreateMatrix()

				self.matrixDeterminant = scaleX * scaleY

				if math.abs (self.matrixDeterminant) > 10 then
					scaleX, scaleY = normalizeV2(scaleX, scaleY)
					scaleX, scaleY = scaleV2(scaleX, scaleY, 10)
				end

				local centerX = self.message_width / 2
				local centerY = y - self.message_height / 2

				EXT.TranslateMatrix(mat, x, centerY)
					EXT.TranslateMatrix(mat, X,Y)
					EXT.ScaleMatrix(mat, scaleX, scaleY)
					if scaleX < 0 then
						EXT.TranslateMatrix(mat, -self.message_width, 0)
					end
					if angleInDegrees ~= 0 then
						EXT.TranslateMatrix(mat, centerX)
							EXT.RotateMatrix(mat, angleInDegrees)
						EXT.TranslateMatrix(mat, -centerX)
					end
				EXT.TranslateMatrix(mat, x, -centerY)

				EXT.PushMatrix(mat)

				EXT.SetCullClockWise(self.matrixDeterminant < 0)
			end,

			post = function(markup, self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end

				EXT.PopMatrix()
			end,
		}

		META.tags.matrix =
		{
			arguments = {1, 0, 0, 1, 0, 0},

			draw = function(markup, self, x, y, a11, a12, a21, a22, dx, dy)
				-- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

				-- A = Q1 ? Q2

				-- B = transpose (A) * A
				local b11 = a11 * a11 + a21 * a21
				local b12 = a11 * a12 + a21 * a22
				local b21 = a12 * a11 + a22 * a21
				local b22 = a12 * a12 + a22 * a22
				local trB  = b11 + b22
				local detB = detM2x2(b11, b12, b21, b22)

				-- Finding eigenvalues of B...
				-- det (B - ?I) = 0
				-- | a - ?        b | = 0
				-- |     c    d - ? |
				--
				-- (a - ?) (d - ?) - bc = 0
				-- ?� + (-a - d) ? + ad - bc = 0
				--
				--     a + d � sqrt ((a + d)� - 4 (ad - bc))
				-- ? = -------------------------------------
				--                      2

				-- This is never negative
				local sqrtInside = trB * trB - 4 * detB
				local eigenvalue1 = 0.5 * (trB + math.sqrt(sqrtInside))
				local eigenvalue2 = 0.5 * (trB - math.sqrt(sqrtInside))

				-- (B - ?I) u = 0
				--
				-- [ a - ?        b ] [ u1 ] = [ 0 ]
				-- [     c    d - ? ] [ u2 ]   [ 0 ]
				--
				-- (a - ?) u1 +      b  u2 = 0
				local q211, q221 = eigenvector2(eigenvalue1, b11, b12)
				local q212, q222 = eigenvector2(eigenvalue2, b11, b12)

				if eigenvalue1 == eigenvalue2 then
					-- Make up an eigenvector
					q212, q222 = q221, -q211
				end

				-- Those will never be negative as well #yolo
				local scaleX = math.sqrt (eigenvalue1)
				local scaleY = math.sqrt (eigenvalue2)

				local detQ2 = q211 * q222 - q212 * q221
				local q111, q121 = mulM2x2V2(a11, a12, a21, a22, q211, q221)
				local q112, q122 = mulM2x2V2(a11, a12, a21, a22, q212, q222)
				q111, q121 = scaleV2(q111, q121, (scaleX ~= 0) and (1 / scaleX) or 0)

				if scaleY == 0 then
					q112, q122 = q121, -q111
				else
					-- DOES THIS WORK LOL
					q112, q122 = scaleV2(q112, q122, (scaleY ~= 0) and (1 / scaleY) or 0)
				end

				-- transpose Q2
				q212, q221 = q221, q212

				-- End of Cthulhu summoning

				self.matrixDeterminant = detM2x2(a11, a12, a21, a22)

				local mat = EXT.CreateMatrix()

				local center = Vector(x, y)
				EXT.TranslateMatrix(mat, x, y)
					EXT.TranslateMatrix(mat, dx, dy)

					orthonormalM2x2ToVMatrix(q211, q212, q221, q222, mat)
					EXT.ScaleMatrix(mat, scaleX, scaleY)
					orthonormalM2x2ToVMatrix(q111, q112, q121, q122, mat)
				EXT.TranslateMatrix(mat, -x, -y)

				EXT.PushMatrix(mat)

				EXT.SetCullClockWise(self.matrixDeterminant < 0)
			end,

			post = function(markup, self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end

				EXT.PopMatrix()
			end,
		}
	end
end

-- internal

local time_speed = 1
local time_offset = 0
local panic = false

local function call_tag_func(self, chunk, name, ...)
	if not chunk.val.tag then return end

	if chunk.type == "custom" then

		local func = chunk.val.tag and chunk.val.tag[name]

		if func then
			local sigh = {self, chunk, ...}
			for k,v in pairs(chunk.val.args) do
				if type(v) == "function" then
					local ok, val = pcall(v, chunk.exp_env)
					if ok and val then
						v = val
					else
						v = chunk.val.tag.arguments[k]
						if type(v) == "table" then
							v = v.default
						end
					end
				end
				table.insert(sigh, v)
			end

			local args = {pcall(func, unpack(sigh))}

			if not args[1] then
				logf("tag error %s", args[2])
			else
				return select(2, unpack(args))
			end
		end
	end
end

local function parse_tag_arguments(self, str)
	str = str .. ","
	local out =  {}
	local expressions = {}

	str = str:gsub("(%[.-%]),", function(expression)
		local id =  "__" .. expression .. "__"
		expressions[id] = expression:sub(2, -2)
		return id .. ","
	end)

	for arg in str:gmatch("(.-),") do
		if expressions[arg]	 then
			local ok, func = expression.Compile(expressions[arg])
			if func then
				table.insert(out, func)
			else
				logf("markup expression error: %s", func)
				table.insert(out, 0)
			end
		else
			table.insert(out, arg)
		end
	end

	return out
end

local function parse_tags(self, str)
	local chunks = {}
	local found = false

	local in_tag = false
	local current_string = {}
	local current_tag = {}

	for i, char in pairs(utf8.totable(str)) do
		if char == "<" then

			-- if we've been parsing a string add it
			if current_string then
				table.insert(chunks, table.concat(current_string, ""))
			end

			-- stat a new tag
			current_tag = {}
			in_tag = true
		elseif char == ">" and in_tag then
			-- maybe the string was "sdasd :> sdsadasd <color123>..."
			if current_tag then
				local tag_str = table.concat(current_tag, "") .. ">"
				local tag, args = tag_str:match("<(.-)[?=](.+)>")

				local info = self.tags[tag]

				if info then
					local args = parse_tag_arguments(self, args or "")

					for i = 1, #info.arguments do
						local arg = args[i]
						local default = info.arguments[i]
						local t = type(default)

						if t == "number" then
							local num = tonumber(arg)

							if not num and type(arg) == "function" then
								num = arg
							end

							args[i] = num or default
						elseif t == "string" then
							if not arg or arg == "" then
								arg = default
							end

							args[i] = arg
						elseif t == "table" then
							if default.min or default.max or default.default then
								local num = tonumber(arg)

								if num then
									if default.min and default.max then
										args[i] = math.min(math.max(num, default.min), default.max)
									elseif default.min then
										args[i] = math.min(num, default.min)
									elseif default.max then
										args[i] = math.max(num, default.max)
									end
								else
									if type(arg) == "function" then
										if default.min and default.max then
											args[i] = function(...) return math.min(math.max(arg(...) or default.default, default.min), default.max) end
										elseif default.min then
											args[i] = function(...) return math.min(arg(...) or default.default, default.min) end
										elseif default.max then
											args[i] = function(...) return math.max(arg(...) or default.default, default.max) end
										end
									else
										args[i] = default.default
									end
								end
							end
						end
					end

					found = true

					local tag = {tag = info, type = tag, args = args}
					table.insert(chunks, tag)
				end
			end

			current_string = {}
			in_tag = false
		end

		if in_tag then
			table.insert(current_tag, char)
		elseif char ~= ">" then
			table.insert(current_string, char)
		end
	end

	if found then
		table.insert(chunks, table.concat(current_string, ""))
	else
		chunks = {str}
	end

	return chunks
end

function META:Invalidate()
	EXT.SetFont(self.fonts.default.name)

	-- normalize everything into a consistent markup table
	-- strings are also parsed
	-- go through every argument
	-- markup:SetTable({Color(1,1,1), "asdasd", {"asdasd"}, ...})
	local temp = {}

	for i, var in ipairs(self.Table) do
		local t = typex(var)

		if t == "color" then
			table.insert(temp, {type = "color", val = var})
		elseif t == "string" then
			-- solve strings such as
			-- <color=1,2,3>
			-- this markup does not have a pop variant (there's no need for "</color>")
			for i, var in ipairs(parse_tags(self, var)) do
				if type(var) == "string"  then
					-- don't insert empty strings
					if var ~= "" then
						table.insert(temp, {type = "string", val = var})
					end
				else
					-- if this is a string tag just put color and font as if they were var args for better performance
					if var.type == "font" then
						table.insert(temp, {type = "font", val = var.args[1]})
						
					elseif var.type == "color" then
						table.insert(temp, {type = "color", val = Color(unpack(var.args))})
					else
						table.insert(temp, {type = "custom", val = var})
					end
				end
			end
		elseif t == "table" and val.type and val.cal then
			table.insert(temp, val)
		elseif t ~= "cdata" then
			logf("tried to parse unknown type %q", t)
		end
	end




	-- solve white space and punctation
	local temp2 = {}

	for i, chunk in ipairs(temp) do
		if chunk.type == "string" and chunk.val:find("[%p%s]") then
			local str = ""
			
			for i, char in ipairs(utf8.totable(chunk.val)) do
				if char:find("%s") then
					if str ~= "" then
						table.insert(temp2, {type = "string", val = str})
						str = ""
					end
					
					if char == "\n" then
						table.insert(temp2, {type = "newline"})
					else
						table.insert(temp2, {type = "string", val = char, whitespace = true})
					end
				else
					str = str .. char
				end
			end

			if str ~= "" then
				table.insert(temp2, {type = "string", val = str})
			end			
			
		else
			table.insert(temp2, chunk)
		end
	end




	-- get the size of each object
	local temp = {}

	for i, chunk in ipairs(temp2) do
		if chunk.type == "font" then
			-- set the font so GetTextSize will be correct
			EXT.SetFont(chunk.val)
		elseif chunk.type == "string" then
			local w, h = EXT.GetTextSize(chunk.val)
			
			chunk.w = w
			chunk.h = h
		elseif chunk.type == "custom" then
			local w, h = call_tag_func(self, chunk, "get_size")

			chunk.w = w
			chunk.h = h

			call_tag_func(self, chunk, "pre")
		end

		-- for consistency everything should have x y w h
		chunk.x = chunk.x or 0
		chunk.y = chunk.y or 0
		chunk.w = chunk.w or 0
		chunk.h = chunk.h or 0

		table.insert(temp, chunk)
	end




	-- solve max width
	local temp2 = {}

	local current_x = 0
	local current_y = 0

	local chunk_height = 0 -- the height to advance y in

	for i, chunk in ipairs(temp) do				
		-- is the previous line a newline?
		local newline = temp[i - 1] and temp[i - 1].type == "newline"

		-- figure out the tallest chunk before going to a new line
		if chunk.h > chunk_height then
			chunk_height = chunk.h
		end

		-- is this a new line or are we going to exceed the maximum width?
		if newline or current_x + chunk.w >= self.MaxWidth then		
		
			-- if this is whitespace just get rid of it and pretend it wasn't there
			-- this causes issues with newlines
			--[[if chunk.whitespace then
				current_x = current_x - chunk.w
				goto continue
			end]]
		
			-- reset the width
			current_x = 0
			
			-- advance y with the height of the tallest chunk
			current_y = current_y + chunk_height
		end
		
		chunk.x = current_x
		chunk.y = current_y

		current_x = current_x + chunk.w

		table.insert(temp2, chunk)
		
		::continue::
	end

	-- solve max width once more but for every letter
	-- note: slow and useless?
	local temp = {}

	for i, chunk in ipairs(temp2) do
		local split = false

		if chunk.type == "font" then
			-- set the font so GetTextSize will be correct
			EXT.SetFont(chunk.val)
		elseif chunk.type == "string" then
		
			-- if x+w exceeds maxwidth split!
			if chunk.x + chunk.w >= self.MaxWidth then

				-- start from the chunk's y
				local current_x = chunk.x 
				local current_y = chunk.y
				local chunk_height = 0 -- the height to advance y in
				
				local str = ""

				for i, char in ipairs(utf8.totable(chunk.val)) do		
					local w, h = surface.GetTextSize(char)
					
					if h > chunk_height then
						chunk_height = h
					end
					
					str = str .. char
					current_x = current_x + w  
					
					if current_x + w > self.MaxWidth then
						table.insert(temp, {type = "string", val = str, x = 0, y = current_y, w = current_x, h = chunk_height})
						current_y = current_y + chunk_height
						
						current_x = 0
						chunk_height = 0 
						split = true	
						str = ""
					end
					
					
				end

				if split then
					table.insert(temp, {type = "string", val = str, x = 0, y = current_y, w = current_x, h = chunk_height})
				end
			end

		end
 
		if not split then
			table.insert(temp, chunk)
		end
	end

	
	-- one extra step..
	-- this should be in a while loop
	-- but i choose not for performance reasons
	local temp2 = {}

	local current_x = 0
	local current_y = 0

	local chunk_height = 0 -- the height to advance y in

	for i, chunk in ipairs(temp) do	
				
		-- is the previous line a newline?
		local newline = temp[i - 1] and temp[i - 1].type == "newline"
		
		if newline and chunk.type == "string" and not chunk.whitespace then

			-- figure out the tallest chunk before going to a new line
			if chunk.h > chunk_height then
				chunk_height = chunk.h
			end

			-- is this a new line or are we going to exceed the maximum width?
			if newline or current_x + chunk.w >= self.MaxWidth then		
				-- reset the width
				current_x = 0
				
				-- advance y with the height of the tallest chunk
				current_y = current_y + chunk_height
				current_y = chunk.y
			end

			chunk.x = current_x
			chunk.y = current_y

			current_x = current_x + chunk.w

		end
		
		table.insert(temp2, chunk)
	end
	
	local chunks = temp2

	-- this is for expressions to be use d like line.i+time()
	for i, chunk in ipairs(chunks) do
		chunk.exp_env = {
			i = i,
			w = chunk.w,
			h = chunk.h,
			x = chunk.x,
			y = chunk.y,
			rand = math.random()
		}
	end
	
	do -- store some extra info
		local line = 0
		local width = 0
		local height = 0
		local last_y 
		
		local font = "default"
		local color = Color(1,1,1,1)
		
		local function build_chars(chunk)
			if not chunk.chars then
				EXT.SetFont(chunk.font)
				chunk.chars = {}
				local width = 0
				for i, char in ipairs(utf8.totable(chunk.val)) do
					local char_width, char_height = surface.GetTextSize(char)
					local x = chunk.x + width
					local y = chunk.y
					
					chunk.chars[i] = {
						x = x, 
						y = chunk.y, 
						w = char_width,  
						h = char_height,
						right = x + char_width,
						top = y + char_height,
						char = char,
						i  = i,
						chunk = chunk,
					}
					width = width + char_width
				end
			end
		end
		
		for _, chunk in ipairs(chunks) do
			
			if chunk.type == "font" then
				font = chunk.val
			elseif chunk.type == "color" then
				color = chunk.val
			elseif chunk.type == "string" then
				chunk.font = font
				chunk.color = color
			end
		
			local w = chunk.x + chunk.w
			if w > width then
				width = w
			end
			
			local h = chunk.y + chunk.h
			if w > height then
				height = h
			end
			
			if chunk.y ~= last_y then
				line =  line + 1
				last_y = chunk.y
			end
			
			chunk.line = line
			chunk.build_chars = build_chars
		end
		
		self.lines = line
		self.width = width
		self.height = height
	end
	
	do -- align the y axis properly
		local h = 0
		
		for _, chunk in ipairs(chunks) do
			if chunk.line == 1 then
				if chunk.h > h then
					h = chunk.h
				end
			else
				break
			end
		end
				
		for _, chunk in ipairs(chunks) do
			chunk.y = chunk.y - chunk.h + h
			
			-- mouse testing
			chunk.right = chunk.x + chunk.w
			chunk.top = chunk.y + chunk.h			
		end
	end

	-- build linked list (mainly for matrices)
	local prev = nil	
	for _, chunk in ipairs(chunks) do
		if prev then
			prev.next = chunk
		end
		prev = chunk
	end

	for i, chunk in ipairs(chunks) do
		local w = 0
		local h = 0
		local node = chunk.next
		while node do
			w = w + node.w
			h = math.max (h, node.h)
			node = node.next
		end

		chunk.message_width = w
		chunk.message_height = h
	end
	
	self.chars = nil	
	
	if self.EditMode then		
		self.chars = {}
		self.lines = {}
		
		local line = 1
		local line_pos = 1
		local line_str = {}
		
		for i, chunk in ipairs(chunks) do	
			if chunk.type == "string" then
				chunk:build_chars()
				
				for i2, char in pairs(chunk.chars) do
					table.insert(self.chars, {
						chunk = chunk, 
						i = i, 
						str = char.char, 
						data = char, 
						y = line, 
						x = line_pos,
					})
					
					line_pos = line_pos + 1
					
					table.insert(line_str, char.char)
				end
				
				table.insert(self.lines, table.concat(line_str, ""))
				
			elseif chunk.type == "newline" then
				table.insert(self.chars, {chunk = chunk, i = i, str = "\n", data = chunk, y = line, x = line_pos})
				line = line + 1
				line_pos = 0
			end
		end
	end
	
	self.chunks = chunks
end

function META:GetSelectedString(skip_tags)

	local out = {}

	local START = self.select_start
	local END = self.select_end

	if START and END then
		if self.EditMode then
			for i = START.i, END.i do
				local char = self.chars[i]
				local data = char.data
				table.insert(out, char.str) 
			end
		else		
			local last_font  
			local last_color
				
			for i, chunk in ipairs(self.chunks) do
				if i >= START.i and i <= END.i then
					if chunk.type == "string" then
						-- this will ensure a clean output
						-- but maybe this should be cleaned in the invalidate function instead?
						if last_font ~= chunk.font then
							table.insert(out, ("<font=%s>"):format(chunk.font))
							last_font = chunk.font
						end
						
						if last_color ~= chunk.color then
							table.insert(out, ("<color=%s,%s,%s,%s>"):format(math.round(chunk.color.r, 2), math.round(chunk.color.g, 2), math.round(chunk.color.b, 2), math.round(chunk.color.a, 2)))
							last_color = chunk.color
						end
					
						if START.char and END.char and START.i == END.i then
							for i, char in ipairs(START.char.chunk.chars) do
								if i >= START.char.i and i <= END.char.i then
									table.insert(out, char.char)
								end
							end
							break
						else		
							if i == START.i then
								if START.char then
									for i, char in ipairs(START.char.chunk.chars) do
										if i >= START.char.i then
											table.insert(out, char.char)
										end
									end
								end
							elseif i == END.i then	
								if END.char then
									for i, char in ipairs(END.char.chunk.chars) do
										if i < END.char.i then
											table.insert(out, char.char)
										end
									end
								end
							elseif i > START.i and i < END.i and START.i ~= END.i then
								table.insert(out, chunk.val)
							end
						end
					elseif chunk.type == "newline" then
						table.insert(out, "\n")
					elseif chunk.type == "custom" then
						if chunk.val.type == "texture" then
							table.insert(out, ("<texture=%s>"):format(chunk.val.args[1]))
						end
					end
				end
			end
		end
	end
	
	return table.concat(out, "")
end
 
function META:CaretFromPixels(x, y)
	-- todo: 
	-- select closest to middle of char
	-- select closest char when going out of bounds
		
	local w, h = surface.GetScreenSize()
	
	if self.EditMode then
				
		for i, char in ipairs(self.chars) do
			local data = char.data
			
			if 
				x > data.x and y > data.y and
				x < data.right and y < data.top
			then
				return {
					x = data.x,
					y = data.y,
					h = data.h,
					i = i,
					char = char,
				}
			end
		end
		
	else
	
		local chunk = self.chunks[#self.chunks]
		
		for i, chunk in ipairs(self.chunks) do	
			if chunk.x > w then break end
			if chunk.y > h then break end
		
			if 
				x > chunk.x and y > chunk.y and
				x < chunk.right and y < chunk.top
			then			
				if chunk.type == "string" then
					
					chunk:build_chars()
					
					for _, char in ipairs(chunk.chars) do
						if 
							x > char.x and y > char.y and
							x < char.right and y < char.top
						then
							return {
								x = char.x,
								y = char.y,
								h = char.h,
								i = i,
								char = char,
							}
						end
					end
				else
					return {
						x = chunk.x,
						y = chunk.y,
						h = chunk.h,
						i = i
					}
				end
			end
		end	
	end
end

function META:OnMouseInput(button, press, x, y)	
	if press then
		self.select_start = self:CaretFromPixels(x, y)
		self.select_end = nil
		self.is_selecting = true
	else
		self.is_selecting = false
	end
end

do -- caret movement
	local is_caret_move = {
		up = true,
		down = true,
		left = true,
		right = true,
		
		home = true,
		["end"] = true,
	}
	
	
	function META:DeleteSelection()
		if self.select_start and self.select_end then
			local start_pos = self:GetSubPosFromPos(self.select_start)
			local end_pos = self:GetSubPosFromPos(self.select_end)
			
			if start_pos > end_pos then
				local temp = end_pos
				end_pos = start_pos
				start_pos = temp
				
				self.caret_pos = self.select_end
			else
				self.caret_pos = self.select_start
			end

			self.Text = self.Text:usub(1, start_pos) .. self.Text:usub(end_pos + 1)

			self.select_start = nil
			self.select_end = nil
			
			self:InvalidateText()

			return true
		end

		return false
	end

	function META:GetSubPosFromPos(x, y)

		if x == math.huge and y == math.huge then
			return #self.chars
		end

		if x == 0 and y == 0 then
			return 0
		end

		for sub_pos, char in pairs(self.chars) do
			if char.x == x and char.y == y then
				return sub_pos
			end
		end

		return 0
	end

	function META:InsertString(str, skip_move)
		local sub_pos = self:GetSubPosFromPos(self.CaretPos)

		self:DeleteSelection()

		if #self.Text == 0 then
			self.Text = self.Text .. str
		elseif sub_pos == #self.Text then
			self.Text = self.Text .. str
		else
			self.Text = self.Text:usub(1, sub_pos) .. str .. self.Text:usub(sub_pos + 1)
		end

		self:InvalidateText()

		if not skip_move then
			self.CaretPos.x = self.CaretPos.x + str:ulength()
			self.CaretPos.y = self.CaretPos.y + str:count("\n")
			self.real_x = self.CaretPos.x
			self:SetCaretPos(self.CaretPos)
		end		
	end
	
	function META:OnKeyInput(button, press)

		if not self.selected_line or not self.selected_char then
			self:SelectPos(Vec2(0, 0))
		end

		if is_caret_move[key] then
			self.shift_selecting = input.IsKeyDown("left_shift")
			self:StartSelect(self.CaretPos:Copy())
		end

		if press then
			local line = self.selected_line.str
			local sub_pos = self:GetSubPosFromPos(self.CaretPos)
			local ctrl_down = input.IsKeyDown("left_control") or input.IsKeyDown("right_control")

			do -- special characters
				if key == "tab" then
					if input.IsKeyDown("left_shift") then 
						if self.select_end and self.select_start and self.select_start.y ~= self.select_end.y then
							self.select_start.x = 0
							self.select_end.x = math.huge
							
							local select_start = self.select_start
							local select_end = self.select_end

							local str = self:GetSelection()
							self.pause_invalidate = true
							self:DeleteSelection()
							self.pause_invalidate = false
							
							str = str:gsub("^\t", "")
							local str, count = str:gsub("\n\t\t", "\n\t")
							if count == 0 then
								str = str:gsub("\n\t", "\n") 
							end 
							self:InsertString(str)
												 
							self.select_start = select_start
							self.select_end = select_end
							self.mouse_selecting = false
						else
							if self.Text:usub(sub_pos, sub_pos) == "\t" then
								self:OnKeyInput("backspace", true)
							end
						end
					else
						if self.select_end and self.select_start and self.select_start.y ~= self.select_end.y then
							self.select_start.x = 0
							self.select_end.x = math.huge
							
							local select_start = self.select_start
							local select_end = self.select_end
												
							local str = self:GetSelection()
							self.pause_invalidate = true
							self:DeleteSelection()
							self.pause_invalidate = false
							str = "\t" .. str:gsub("\n", "\n\t")
							self:InsertString(str)
												
							self.select_start = select_start
							self.select_end = select_end
							self.mouse_selecting = false
						else
							self:OnCharInput("\t")
						end
					end
				elseif key == "enter" then
					if self.MultiLine then
						local space = line:match("^(%s+)") or ""

						self:InsertString("\n" .. space, true)
						self.CaretPos.x = #space
						self.real_x = #space
						self.CaretPos.y = self.CaretPos.y + 1
					elseif self.OnEnter then
						self:OnEnter(self.Text)
					end
				end
			end

			do -- clipboard
				if key == "c" and ctrl_down then
					system.SetClipboard(self:GetSelection())
				elseif key == "x" and ctrl_down then
					system.SetClipboard(self:GetSelection())
					self:DeleteSelection()
				elseif key == "v" and ctrl_down then
					local str = system.GetClipboard()

					str = str:gsub("\r", "\n")
					str = str:gsub("\n\n", "\n")

					if #str > 0 then
						self:InsertString(str)
					end
				end
			end

			do -- deletion
				if key == "backspace" then
					local prev_line = self.markup.data[self.selected_line.pos - 1] or ""

					if not self:DeleteSelection() then
						if ctrl_down then
							local pos = self.CaretPos:Copy()
							
							self:StartSelect(pos)
							pos = pos:Copy()
							pos.x = self:FindNearestFromCaret("left") 
							self:EndSelect(pos)
							self:DeleteSelection() 
							
							if pos.x <= 0 then
								self.CaretPos.y = self.CaretPos.y - 1
								local line = self.lines[self.CaretPos.y] or ""
								self.CaretPos.x = #line
								local sub_pos = self:GetSubPosFromPos(self.CaretPos)
								self.Text = self.Text:usub(1, sub_pos) .. self.Text:usub(sub_pos + 2)
							end
							
							self.real_x = self.CaretPos.x - 1
						else 
							if self.CaretPos.x <= 0 then
								self.CaretPos.y = self.CaretPos.y - 1
								local line = self.lines[self.CaretPos.y] or ""
								self.CaretPos.x = line:ulength() + 1
							end
							self.Text = self.Text:usub(1, sub_pos - 1) .. self.Text:usub(sub_pos + 1)
							self.CaretPos.x = self.CaretPos.x - 1
						end					
					end

					self:InvalidateText()
				elseif key == "delete" then

					if not self:DeleteSelection() then				
						if ctrl_down then 
							local pos = self.CaretPos:Copy() 
							
							self:StartSelect(pos)
							pos = pos:Copy()
							pos.x = self:FindNearestFromCaret("right")
							self:EndSelect(pos) 
							self:DeleteSelection()
													
							if pos.x > #line then
								local start_pos, end_pos = self.Text:usub(sub_pos + 2):find("%s*") 
								if end_pos then
									self.Text = self.Text:usub(1, sub_pos) .. self.Text:usub(sub_pos + 2 + end_pos)
								end
								self.real_x = 0
							end
						else
							self.Text = self.Text:usub(1, sub_pos) .. self.Text:usub(sub_pos + 2)
						end
					end

					self:InvalidateText()
				end
			end

			do -- caret movement
				if key == "right" then
					if ctrl_down then
						self.CaretPos.x = self:FindNearestFromCaret("right")
					else
						self.CaretPos.x = self.CaretPos.x + 1
					end

					self.real_x = self.CaretPos.x
				elseif key == "left" then
					if ctrl_down then
						self.CaretPos.x = self:FindNearestFromCaret("left")
						
						if self.CaretPos.x <= 0 then
							self.CaretPos.y = self.CaretPos.y - 1
							local line = self.lines[self.CaretPos.y] or ""
							self.CaretPos.x = #line
						end
					else
						self.CaretPos.x = self.CaretPos.x - 1
					end

					self.real_x = self.CaretPos.x
				end

				if key == "up" then
					self.CaretPos.y = self.CaretPos.y - 1
					self.CaretPos.x = self.real_x
				elseif key == "down" then
					self.CaretPos.y = self.CaretPos.y + 1
					self.CaretPos.x = self.real_x
				end

				if key == "home" then
					local pos = (select(2, line:find("^%s+(.)")) or 1) - 1

					if self.CaretPos.x == pos then
						pos = 0
					end

					self.CaretPos.x = pos
					self.real_x = self.CaretPos.x
				elseif key == "end" then
					-- this should be #line if you compare to
					-- scintillia but in a way it makes sense to have it like this
					self.CaretPos.x = #line
					self.real_x = self.CaretPos.x
				end

				local x = self.CaretPos.x

				self:SetCaretPos(self.CaretPos)

				-- if we're at the end of the line, got to the next
				if x ~= self.CaretPos.x and #self.lines > 1 then
					if key == "right" then					
						-- if ctrl is down find the next space
						if ctrl_down then
							local line = self.lines[self.CaretPos.y+1] or ""
							self.CaretPos.x = (select(2, line:find("%s-%S", 0)) or 1) - 1
						else				
							self.CaretPos.x = 0
						end
						self.CaretPos.y = self.CaretPos.y + 1
						self:SetCaretPos(self.CaretPos)
					elseif key == "left" then
						self.CaretPos.x = math.huge
						self.CaretPos.y = self.CaretPos.y - 1
						self:SetCaretPos(self.CaretPos)
					end
				end
			end
			
			if is_caret_move[key] then
				if not input.IsKeyDown("left_shift") then
					self:Unselect()
				end
			end
			
			do -- other shortcuts
				if  ctrl_down then
					if key == "a" then
						self:Unselect()
						self:SetCaretPos(Vec2(0,0))
						self:StartSelect(Vec2(0,0))
						self:EndSelect(Vec2(math.huge, math.huge))
					else
						local ok = false
						self.history_index = self.history_index or 0
						
						if key == "z" then
							self.history_index = math.clamp(self.history_index + 1, 1, #self.history)
							ok = true
						elseif key == "y" then
							self.history_index = math.clamp(self.history_index - 1, 1, #self.history)
							ok = true
						end
						
						if ok then			
							local data = self.history[self.history_index]
							
							if data then 
								self.suppress_history = true
								self:SetText(data.str)
								self.suppress_history = nil
								self:InvalidateText()
								self:SetCaretPos(data.pos)
							end
						end
					end
				end
			end
			
			self:SetCaretPos(self.CaretPos)
					
			if self.OnUnhandledKey then
				self:OnUnhandledKey(key)	
			end
		end
	end
end

do -- drawing

	function META:Draw()
		if self.need_layout then
			self:Invalidate()
			self.need_layout = false
		end

		-- reset font and color for every line
		EXT.SetFont(self.fonts.default.name)
		EXT.SetColor(255, 255, 255, 255)
		EXT.SetColor(255, 255, 255, 255)

		local w, h = surface.GetScreenSize()
			
		for i, chunk in ipairs(self.chunks) do

			if chunk.x > w then break end
			if chunk.y > h then break end
			
			if chunk.type == "font" then
				EXT.SetFont(chunk.val)
			elseif chunk.type == "string" then
				EXT.SetTextPos(chunk.x, chunk.y)
				EXT.DrawText(chunk.val)			
			elseif chunk.type == "color" then
				local c = chunk.val
				
				EXT.SetColor(c.r, c.g, c.b, c.a)
			elseif chunk.type == "custom" and not chunk.stop then
				chunk.started = true
				call_tag_func(self, chunk, "draw", chunk.x, chunk.y)
			end
		end

		for _, chunk in ipairs(self.chunks) do
			if chunk.x > w then break end
			if chunk.y > h then break end
			
			if chunk.type == "custom" then
				if not chunk.stop and chunk.started and chunk.val.tag and chunk.val.tag.post then
					chunk.started = false
					call_tag_func(self, chunk, "post")
				end
			end
		end
		
		self:DrawSelection()
	end

	function META:DrawSelection()

		if self.is_selecting then
			local caret = self:CaretFromPixels(window.GetMousePos():Unpack())
			if caret then
				self.select_end = caret
			end
		end
					
		local START = self.select_start
		local END = self.select_end
			
		if START and END then
		
			if START.i == END.i and not self.is_selecting then 
				self.select_end = nil 
			return end
			
			surface.SetWhiteTexture()
			surface.Color(1, 1, 1, 0.5)
			
			if self.EditMode then	
				for i = START.i, END.i do
					local char = self.chars[i]
					local data = char.data
					surface.DrawRect(data.x, data.y, data.w, data.h)
				end
			else			
				for i, chunk in ipairs(self.chunks) do
					if START.char and END.char and START.i == END.i then
						for i, char in ipairs(START.char.chunk.chars) do
							if i >= START.char.i and i <= END.char.i then
								surface.DrawRect(char.x, char.y, char.w, char.h)
							end
						end
						break
					else		
						if i == START.i then
							if START.char then
								for i, char in ipairs(START.char.chunk.chars) do
									if i >= START.char.i then
										surface.DrawRect(char.x, char.y, char.w, char.h)
									end
								end
							else
								surface.DrawRect(chunk.x, chunk.y, chunk.w, chunk.h)
							end
						elseif i == END.i then	
							if END.char then
								for i, char in ipairs(END.char.chunk.chars) do
									if i < END.char.i then
										surface.DrawRect(char.x, char.y, char.w, char.h)
									end
								end
							else
								surface.DrawRect(chunk.x, chunk.y, chunk.w, chunk.h)
							end
						elseif i > START.i and i <= END.i and START.i ~= END.i then
							surface.DrawRect(chunk.x, chunk.y, chunk.w, chunk.h)
						end
					end
				end
			end
		end
			
		if self.caret_pos then
			surface.Color(1,1,1,timer.GetTime()%0.5 > 0.25 and 1 or 0)
			surface.DrawRect(self.caret_pos.x, self.caret_pos.y, 2, self.caret_pos.h)
		end
	end

end


include("tests/markup.lua")  