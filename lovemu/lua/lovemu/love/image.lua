local love=love
local lovemu=lovemu

local textures = lovemu.textures
local FILTER = e.GL_NEAREST


love.image={}

function love.image.newImageData(a, b)
	check(a, "string", "number")
	check(b, "number", "nil")

	local w
	local h
	local buffer
	
	if type(a) == "number" and type(b) == "number" then
		w = a
		h = a
	elseif not b and type(a) == "string" then
		w, h, buffer = freeimage.LoadImage(a)
		if w == 0 and h == 0 then
			a = vfs.Read(a, "rb")
			w, h, buffer = freeimage.LoadImage(a)
		end
	end

	local obj = lovemu.NewObject("ImageData")
	
	local tex = Texture(w, h, buffer, {
		mag_filter = FILTER,
		min_filter = FILTER,
	}) 
	
	textures[obj] = tex
	
	obj.getSize = function(s) return #buffer end
	obj.getWidth = function(s) return w end
	obj.getHeight = function(s) return h end
	obj.setFilter = function() end
	
	obj.paste = function(source, dx, dy, sx, sy, sw, sh) end
	obj.encode = function(outfile) end
	obj.getString = function() return buffer end
	obj.setWrap = function()  end
	obj.getWrap = function()  end
	
	
	obj.getPixel = function(s, x,y, r,g,b,a) 
		do return math.random(255), math.random(255), math.random(255), math.random(255) end
		local rr, rg, rb, ra
		tex:Fill(function(_x,_y, i, r,g,b,a) 
			if _x == x and _y == y then 
				rr = r 
				rg = g 
				rb = b 
				ra = a 
				return true
			end
		end, nil, true)
		return rr or 0, rg or 0, rb or 0, ra or 0
	end
	
	obj.setPixel = function(s, x,y, r,g,b,a) 
		tex:Fill(function(_x,_y, i) 
			if _x == x and _y == y then 
				return r,g,b,a
			end
		end, true)
	end
	
	obj.mapPixel = function(s, cb) 
		tex:Fill(function(x,y,i, r,g,b,a) 
			cb(x,y,r,g,b,a) 
		end, false, true)
	end
	
	return obj
end