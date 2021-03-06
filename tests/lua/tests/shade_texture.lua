local tex = Texture(64,64):Fill(function() 
	return math.random(255), math.random(255), math.random(255), math.random(255) 
end)

function blur(dir)
tex:Shade([[
	out vec4 out_color;
	
	void main()
	{
		//this will be our RGBA sum
		vec4 sum = vec4(0.0);

		//the amount to blur, i.e. how far off center to sample from 
		//1.0 -> blur by one pixel
		//2.0 -> blur by two pixels, etc.
		float blur = radius/resolution; 

		//the direction of our blur
		//(1.0, 0.0) -> x-axis blur
		//(0.0, 1.0) -> y-axis blur
		float hstep = dir.x;
		float vstep = dir.y;

		//apply blurring, using a 9-tap filter with predefined gaussian weights

		sum += texture2D(self, vec2(uv.x - 4.0*blur*hstep, uv.y - 4.0*blur*vstep)) * 0.0162162162;
		sum += texture2D(self, vec2(uv.x - 3.0*blur*hstep, uv.y - 3.0*blur*vstep)) * 0.0540540541;
		sum += texture2D(self, vec2(uv.x - 2.0*blur*hstep, uv.y - 2.0*blur*vstep)) * 0.1216216216;
		sum += texture2D(self, vec2(uv.x - 1.0*blur*hstep, uv.y - 1.0*blur*vstep)) * 0.1945945946;

		sum += texture2D(self, vec2(uv.x, uv.y)) * 0.2270270270;

		sum += texture2D(self, vec2(uv.x + 1.0*blur*hstep, uv.y + 1.0*blur*vstep)) * 0.1945945946;
		sum += texture2D(self, vec2(uv.x + 2.0*blur*hstep, uv.y + 2.0*blur*vstep)) * 0.1216216216;
		sum += texture2D(self, vec2(uv.x + 3.0*blur*hstep, uv.y + 3.0*blur*vstep)) * 0.0540540541;
		sum += texture2D(self, vec2(uv.x + 4.0*blur*hstep, uv.y + 4.0*blur*vstep)) * 0.0162162162;

		out_color = sum;
	}
]], { 
	radius = 1, 
	resolution = Vec2(render.GetScreenSize()),
	dir = dir,
})  
end

blur(Vec2(0,20))   
-- blur(Vec2(20,0)) -- todo: this just makes it black for some reason
    
event.AddListener("OnDraw2D", "lol", function()
	if not tex:IsValid() then return end

	surface.Color(1,1,1,1)
	surface.SetTexture(tex)

	surface.DrawRect(90, 50, 100, 100)
end)  