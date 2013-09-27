event.AddListener("RenderContextInitialized", "fly_camera", function()
	local cam_pos = Vec3(0, 0, -10)
	local cam_ang = Ang3(0, 0, 0)

	event.AddListener("OnUpdate", "fly_camera", function(dt)
		cam_ang:Normalize()
		local speed = dt * 10

		local delta = window.GetMouseDelta() * dt / 2
		cam_ang.p = cam_ang.p + delta.y
		cam_ang.y = cam_ang.y + delta.x
		cam_ang.p = math.clamp(cam_ang.p, -math.pi/2, math.pi/2)

		if input.IsKeyDown("left_shift") then
			speed = speed * 8
		elseif input.IsKeyDown("left_control") then
			speed = speed / 4
		end

		if input.IsKeyDown("space") then
			cam_pos = cam_pos - Vec3(0, speed, 0)
		end

		local offset = cam_ang:GetUp() * speed
		offset.x = -offset.x;
		offset.y = -offset.y

		if input.IsKeyDown("w") then

			cam_pos = cam_pos + offset
		elseif input.IsKeyDown("s") then
			cam_pos = cam_pos - offset
		end

		offset = cam_ang:GetRight() * speed
		offset.z = -offset.z

		if input.IsKeyDown("a") then
			cam_pos = cam_pos + offset
		elseif input.IsKeyDown("d") then
			cam_pos = cam_pos - offset
		end

		speed = dt * 5
		
		render.SetCam(cam_pos, cam_ang:GetDeg(), 90)
	end)
end)