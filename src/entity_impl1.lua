module("entity", package.seeall)
-- Some entity types

local function new_ctrl_func(input_func, max_v, jump_mag, grab_cb, release_cb)
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

local function new_input_keyboard(key_up, key_down, key_left, key_right, key_jump, key_grab)
	local has_jump = false

	function check_input()
		local cx, cy, jump = 0, 0, false
		if love.keyboard.isDown(key_up) then
			cy = cy - 1
		end
		if love.keyboard.isDown(key_jump) then
			if not has_jump then
				has_jump = true
				jump = true
			end
		else
			has_jump = false
		end
		if love.keyboard.isDown(key_down) then
			cy = cy + 1
		end
		if love.keyboard.isDown(key_left) then
			cx = cx - 1
		end
		if love.keyboard.isDown(key_right) then
			cx = cx + 1
		end
		return cx, cy, jump, love.keyboard.isDown(key_grab)
	end
	return check_input
end

function cb_player_grab(self, entity)
	assert(entity.tag.type == 'brick')
	self.tag.hold = {}
	self.tag.hold.entity = entity
	if entity.bricksys.frozen then
		bricksys.brick_world:unfreeze(entity)
	end
	local x, y = self.physics.body:getPosition()
	entity.physics.body:setPosition(x, y-40)
	entity.physics.fixture:setSensor(true)
	entity.physics.body:setMassData(0,0,0,0)
	entity.graphics.z = 1
	self.tag.hold.joint = love.physics.newWeldJoint(self.physics.body, entity.physics.body, 0, 0, 0, 0)
end

function cb_player_release(self, cx, cy)
	assert(self.tag.hold)
	local entity = self.tag.hold.entity
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
	local ix, iy = cx * multiplier, cy * multiplier
	eb:applyLinearImpulse(ix ,iy)
	b:applyLinearImpulse(ix * -0.5, iy * -0.5)
	entity.graphics.z = 0
end

function new_player(x, y)
	local e = new_entity()
	e.tag.type = 'player'
	local WIDTH = 40
	attach_graphics_debug(e, WIDTH, WIDTH, {255,255,255})
	attach_physics(e, x, y, 'dynamic', love.physics.newRectangleShape(WIDTH, WIDTH))
	e.physics.fixture:setFriction(0)
	e.physics.body:setFixedRotation(true)
	local ctrl = new_ctrl_func(new_input_keyboard('up', 'down', 'left', 'right', 'space', 'f'),
			600, 520, cb_player_grab, cb_player_release)
	e.update = {}
	e.update.ctrl = ctrl
	e.update.change_color = function (self, dt)
			self.graphics.color = {math.random(0,255), math.random(0,255), math.random(0,255)}
		end

	return e
end

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
				e.update.fall = function (self, dt)
						e.transform.x = e.transform.x + e.transform.vx * dt
						e.transform.y = e.transform.y + e.transform.vy * dt
						if e.transform.y > love.graphics.getHeight() + bricksys.GRID_SIZE then
							destroy_entity(self)
							return
						end
						self.transform.vy = self.transform.vy + 1500*dt
					end
				return true
			end
			return false
		end
	return e
end
