local love=love
local lovemu=lovemu
love.timer={}

local lovemu=lovemu
local ceil=math.ceil

function love.timer.getDelta()
	return render.delta or 0
end

function love.timer.getFPS()
	return ceil(1/render.delta or 0)
end

function love.timer.getMicroTime()
	return timer.clock()
end

function love.timer.getTime()
	if lovemu.version=="0.8.0" then
		return ceil(timer.clock())
	else
		return timer.clock()
	end
end