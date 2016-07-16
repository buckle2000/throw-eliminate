module(..., package.seeall)
local bricksys = require("bricksys")

pool = {}  -- entity pool

function reset()
	pool = {}
end

function new_entity()
	local e = {tag={}}
	table.insert(pool, e)
	return e
end

function destroy_entity(e)
	if e then
		detach_bricksys(e)
		detach_physics(e)
		table.popi(pool, e)
	end
end

function attach_transform(e)
	e.transform = e.transform or {
	x = 0,
	y = 0,
	}
end

function attach_physics(e, x, y, body_type, shape, density)
	attach_transform(e)
	x = x or e.transform.x
	y = y or e.transform.y
	e.transform.x = x
	e.transform.y = y
	if e.physics then
		detach_physics(e)
	end
	e.physics = {}
	local p = e.physics
	p.body = love.physics.newBody(phys_world, x, y, body_type)
	p.body:setUserData(e)
	if shape then
		p.shape = shape
		p.fixture = love.physics.newFixture(p.body, p.shape, density)
	end
	return p.fixture
end

function detach_physics(e)
	if e.physics then
		e.physics.body:destroy()
		e.physics = nil
	end
end

function attach_graphics_debug(e, width, height, color, ox, oy)
	--[[
	Create a filled rectangle with given color and size. For debug only.

	width, height   size of the graphic
	color           color of the rectangle  e.g. {0,0,0}
	ox, oy          offset of graphic
	--]]
	attach_transform(e)

	local image_data = love.image.newImageData(width, height)
	for x=0,width-1 do
		for y=0,height-1 do
			image_data:setPixel(x, y, unpack(color))
		end
	end

	e.graphics = e.graphics or {}
	e.graphics.image = love.graphics.newImage(image_data)
	e.graphics.ox = ox or width/2
	e.graphics.oy = oy or height/2
end

function attach_bricksys(e, color)
	assert(e.physics, "A brick must have a physics body.")
	e.tag.type = 'ground'
	e.tag.moveable = true
	e.tag.color = color
	e.bricksys = {}
	e.physics.body:setFixedRotation(true)
	-- e.physics.body:setBullet(true)  -- for some drastic collisions
	e.update = {bricksys=bricksys.update_brick}
end

function detach_bricksys(e)
	if e.bricksys then
		table.popk(bricksys.brick_world.data, e)
	end
end

function new_ctrl_func(input_func, max_v, jump_mag)
	--[[
	Simple movement controller to make a entity jump and walk. Use arrow keys to control. Do not work with physics.

	max_v      Max horizontal velocity
	jump_mag   Magnitude of jump impulse
	--]]
	local last_jump = nil
	local last_dir = 1
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
		if last_jump and love.timer.getTime() - last_jump < 0.1 then  -- player can press jump button before reach the ground
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
			local world_x, world_y = b:getWorldPoint(throw_x * 45, cy * 45)
			local closest_distance = nil
			local result_entity = nil
			local x, y = b:getPosition()

			local function callback(fixture)
				local that_b = fixture:getBody()
				local entity = that_b:getUserData()
				if entity.tag.type == 'ground' then
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
				destroy_entity(result_entity)
			end
		end
	end

	return update
end

function new_input_keyboard(key_up, key_down, key_left, key_right, key_jump, key_grab)
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

function new_player(x, y)
	local e = new_entity()
	local WIDTH = 40
	attach_graphics_debug(e, WIDTH, WIDTH, {255,255,255})
	attach_physics(e, x, y, 'dynamic', love.physics.newRectangleShape(WIDTH, WIDTH)):setFriction(0)
	e.physics.body:setFixedRotation(true)
	local ctrl = new_ctrl_func(new_input_keyboard('up', 'down', 'left', 'right', 'space', 'f'), 600, 500)
	e.update = {ctrl=ctrl}
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
function new_brick(x, y, color)
	local e = new_entity()
	attach_graphics_debug(e, bricksys.GRID_SIZE, bricksys.GRID_SIZE, color)
	attach_physics(e, x, y, 'dynamic', brick_shape):setFriction(0.1)  -- make it slippery
	attach_bricksys(e, color)
	return e
end



-- function new_tilemap(map_data)
-- 	--[[
-- 	Create a new tilemap from a table or a lua file (exported by Tiled).
-- 	--]]
-- 	if type(map_data) == 'string' then
-- 		map_data = require(map_data)
-- 	end

-- 	local e = new_entity()
-- 	local WIDTH = 50
-- 	e.tiles = {}
-- 	for i=1,#map_data.data do
-- 		if map_data.data[i] > 0 then
-- 			local tile_x = (i-1) % map_data.width
-- 			local tile_y = math.floor((i-1) / map_data.width)
-- 			local tile = new_entity()
-- 			attach_graphics_debug(tile, WIDTH, WIDTH, {130,170,255})  -- need faster solution: draw all tiles to a single image
-- 			attach_physics(tile, {tile_x*WIDTH, tile_y*WIDTH, WIDTH, WIDTH})
-- 			e.tiles[i] = tile
-- 		end
-- 	end
-- 	return e
-- end

