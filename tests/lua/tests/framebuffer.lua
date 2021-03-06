window.Open()

local fb = render.CreateFrameBuffer(512, 512, {
	attach = e.GL_COLOR_ATTACHMENT1,
	texture_format = {
		internal_format = e.GL_RGB32F,
	}
})

event.AddListener("OnDraw2D", "fb", function()
	
	if true or wait(0.2) then
		fb:Begin()   
			surface.Start(0, 0, 512, 512) 
				fb:Clear()
				
				surface.SetWhiteTexture()
				surface.Color(math.randomf(), math.randomf(), math.randomf())
				surface.DrawRect(math.random(512), math.random(512), 100, 100)
			surface.End()
		fb:End()
	end

	surface.SetTexture(fb:GetTexture())
	surface.Color(1,1,1,1)
	surface.DrawRect(128, 128, 128, 128, timer.clock()*100, 64, 64)
end)    