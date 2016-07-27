module("entitysys", package.seeall)
-- Some entity types

function cb_player_grab(self, entity)
	assert(entity.tag.type == 'brick')
	self.tag.hold = {}
	self.tag.hold.entity = entity
	-- not working
	-- local x, y = bricksys.brick_world:get_grid_pos(entity)
	-- if y ~= 0 then
	-- 	local above = bricksys.brick_world:get(x, y-1)
	-- 	if above then
	-- 		bricksys.update_last_hold(above, self)
	-- 	end
	-- end
	if entity.bricksys.frozen then
		local x, y = bricksys.brick_world:get_grid_pos(entity)
		if y ~= 0 then
			local brick_above = bricksys.brick_world:get(x, y-1)
			if brick_above then
				bricksys.update_last_hold(brick_above, self)
			end
		end
		bricksys.brick_world:unfreeze(entity)
	end
	local world_w, world_y = self.physics.body:getPosition()
	entity.physics.body:setPosition(world_w, world_y-40)
	entity.physics.fixture:setSensor(true)
	entity.physics.body:setMassData(0,0,0,0)
	entity.graphics.z = 1
	self.tag.hold.joint = love.physics.newWeldJoint(self.physics.body, entity.physics.body, 0, 0, 0, 0)
end

function cb_player_release(self, cx, cy)
	assert(self.tag.hold)
	local entity = self.tag.hold.entity
	bricksys.update_last_hold(entity, self)
	local b = self.physics.body
	local eb = entity.physics.body
	self.tag.hold.joint:destroy()
	self.tag.hold = nil
	entity.physics.fixture:setSensor(false)
	eb:resetMassData()
	if cy>0 then  -- throw downwards
		local x, y = b:getPosition()
		eb:setPosition(x, y)
		b:setPosition(x, y-30)
	end
	local multiplier = eb:getMass()*300
	do  -- a throw should not be more powerful when aiming diagonally
		local magnitude = math.pyth(cx, cy)
		if magnitude > 1 then
			cx, cy = cx/magnitude, cy/magnitude  -- make total magnitude be 1
		end
	end
	local ix, iy = cx * multiplier, cy * multiplier
	eb:applyLinearImpulse(ix ,iy)
	b:applyLinearImpulse(ix * -0.5, iy * -0.5)
	entity.graphics.z = 0
end

function new_player(x, y, input_func)
	local e = new_entity()
	e.tag.type = 'player'
	e.tag.score = 0
	e.tag.tweened_score = 0.0
	local WIDTH = 40
	attach_graphics_debug(e, WIDTH, WIDTH, {255,255,255})
	attach_physics(e, x, y, 'dynamic', love.physics.newRectangleShape(WIDTH, WIDTH))
	e.physics.fixture:setFriction(0)
	e.physics.body:setFixedRotation(true)
	-- e.graphics.shader = love.graphics.newShader([[
	-- 		uniform float time;
	-- 		vec4 effect(vec4 color_mask, Image texture, vec2 texture_coords, vec2 screen_coords) {
	-- 			vec4 color = texture2D(texture, texture_coords);
	-- 			if (true) {
	-- 				color -= vec4(abs((texture_coords*2)-(1,1,1)), 0., 0.);
	-- 			}
	-- 			return color_mask * color;
	-- 		}
	-- 	]])
	local shader = love.graphics.newShader([[
			uniform float hue;
			uniform vec2 player_pos;
			vec3 rgb2hsv(vec3 c) {
				vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
				vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}
			vec3 hsv2rgb(vec3 c) {
				vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
				screen_coords = screen_coords - player_pos;
				color = Texel(texture, texture_coords);
				vec3 hsv = vec3(mod(hue + screen_coords.x/100 + screen_coords.y/200, 1.0), 1, 1);
				return vec4(hsv2rgb(hsv), color.a);
			}
		]])
	e.graphics.draw = function (self)
			default_draw(self)
			love.graphics.setShader(shader)
			-- draw a pyramid of blocks above player
			local score = math.floor(e.tag.tweened_score)
			local current_layer = 1
			local layers = {}
			while score > current_layer do
				score = score - current_layer
				table.insert(layers, current_layer)
				current_layer = current_layer + 1
			end
			table.insert(layers, score)
			for l=1,#layers do
				local n = layers[l]  -- numbers of blocks in that layer
				love.graphics.push()
				love.graphics.translate(self.transform.x - l*5 - 9, self.transform.y - self.graphics.oy - l*10)
				for i=1,n do
					love.graphics.rectangle('fill', i*10, 0, 8, 8)
				end
				love.graphics.pop()
			end
			love.graphics.setShader()
		end
	add_pre_update(e, new_ctrl_func(input_func, 600, 520, cb_player_grab, cb_player_release), "ctrl")
	local shader_helper = function (self, dt)
			shader:send("hue", (love.timer.getTime()/2)%1)
			shader:send("player_pos", {e.transform.x, e.transform.y})
		end
	add_post_update(e, shader_helper, "shader_helper")
	e.bricksys = {}
	e.bricksys.cb = function (self, award)
			self.tag.score = self.tag.score + award
			new_tween(self, {0.2, self.tag, {tweened_score=self.tag.score}, 'outCirc'}, nil, "score_tweener")
		end
	e.destroy = function (self)
			if self.tag.hold then
				local entity = self.tag.hold.entity
				cb_player_release(self, 0, 0)
				bricksys.update_last_hold(entity, nil)
			end
			return false  -- use default detroy behavior
		end
	return e
end

do  -- new_brick
	local v1 = (bricksys.GRID_SIZE-1) / 2  -- the -1 here leave space for non-frozen bricks to sleep
	local v2 = (bricksys.GRID_SIZE-1) * 0.28
	local brick_shape = love.physics.newPolygonShape(
			-v1, -v2, -v2, -v1,
			 v2, -v1,  v1, -v2,
			 v1,  v2,  v2,  v1,
			-v2,  v1, -v1,  v2
		)  -- an octagon
	function new_brick(x, y, type, image)
		local e = new_entity()
		attach_graphics(e, image, bricksys.GRID_SIZE/2, bricksys.GRID_SIZE/2)
		attach_physics(e, x, y, 'dynamic', brick_shape)
		e.physics.fixture:setFriction(0.1)  -- make it slippery
		-- e.physics.fixture:setRestitution(0.1)
		attach_bricksys(e, type)
		e.destroy = function (self)
				if self.bricksys then
					detach_bricksys(e)
					detach_physics(e)
					e.transform.vx = math.randomf(-200, 200)
					e.transform.vy = math.randomf(-400,-350)
					e.graphics.z = -1
					local fall_auto = function (self, dt)
							e.transform.x = e.transform.x + e.transform.vx * dt
							e.transform.y = e.transform.y + e.transform.vy * dt
							if e.transform.y > love.graphics.getHeight() + bricksys.GRID_SIZE then
								remove_pre_update(self, "fall")
								destroy_entity(self)
								return
							end
							self.transform.vy = self.transform.vy + 1500*dt
						end
					add_pre_update(e, fall_auto, "fall")
					return true
				end
				return false
			end
		return e
	end
end

function new_ctrl_func(input_func, max_v, jump_mag, grab_cb, release_cb)
	--[[
	Simple movement controller to make a entity jump and walk. Use arrow keys to control. Do not work with physics.

	max_v        Max horizontal velocity
	jump_mag     Magnitude of jump impulse
	grab_cb      The callback(grabbed_entity) when grab a thing
	release_cb   The callback(stick_x, stick_y) when grab key is released
	--]]
	local last_jump = nil
	local last_dir = 1
	local has_grab = false
	local function update(self, dt)
		local cx, cy, jump, grab = input_func()
		local throw_x
		if cx == 0 and cy == 0 then
				throw_x = last_dir
		else
			throw_x = cx
			if cx > 0 then
				last_dir = 1
			elseif cx < 0 then
				last_dir = -1
			end
		end
		local b = self.physics.body
		local current_v, _ = b:getLinearVelocity()
		local desired_v = cx * max_v * 0.1 + current_v * 0.9
		local change_v = desired_v - current_v
		local impulse_x = b:getMass() * change_v
		local impulse_y
		local on_ground = false
		if jump then
			last_jump = love.timer.getTime()
		end
		-- player can press jump button before reach the ground
		if last_jump and love.timer.getTime() - last_jump < 0.25 then
			on_ground = is_on_ground(b)
		end
		if on_ground then
			last_jump = nil
			impulse_y = -jump_mag * b:getMass()
		else
			impulse_y = 0
		end
		b:applyLinearImpulse(impulse_x, impulse_y)
		if grab then
			if not has_grab then
				local world_x, world_y = b:getWorldPoint(throw_x * 45, cy * 45)
				local closest_distance = nil
				local result_entity = nil
				local x, y = b:getPosition()

				local function callback(fixture)
					local that_b = fixture:getBody()
					local entity = that_b:getUserData()
					if entity.tag.type == 'brick' then
						local that_x, that_y = that_b:getPosition()
						local current_distance = math.pyth(x-that_x, y-that_y)
						if not closest_distance or current_distance < closest_distance then
							closest_distance = current_distance
							result_entity = entity
						end
					end
					return true  -- search till the last one
				end

				phys_world:queryBoundingBox(world_x-5, world_y-5, world_x+5, world_y+5, callback)
				if result_entity and result_entity.tag.moveable then
					has_grab = true
					if grab_cb then
						grab_cb(self, result_entity)
					end
				end
			end
		else
			if has_grab then
				if release_cb then
					if cx == 0 and cy == 0 then
						throw_x = last_dir*0.5
					end
					release_cb(self, throw_x, cy)
				end
				has_grab = false
			end
		end
	end

	return update
end
