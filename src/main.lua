require("util")
require("entity")

function love.load(arg)
	collectgarbage('stop')  -- stop gc
	if arg[#arg] == "-debug" then require("mobdebug").start() end  -- start debugger
	math.randomseed(os.time())
	reset()
end


function love.draw()
	for i,e in ipairs(filter_sort(entity.pool, function (e) return e.graphics end, function (e) return e.graphics.z end)) do
		if e.graphics.color then
			love.graphics.setColor(e.graphics.color)
		else
			love.graphics.setColor(255, 255, 255)  -- restore
		end
		love.graphics.draw(e.graphics.image, e.transform.x, e.transform.y, 0, 1, 1, e.graphics.ox, e.graphics.oy)
	end
	bricksys.brick_world:draw()
end


local reset_ff = new_flip_flop()
local spawn_ff = new_flip_flop()
function love.update(dt)
	if love.keyboard.isDown('m') then spawn_brick() end
	if reset_ff(love.keyboard.isDown('r')) then reset() end
	if spawn_ff(love.keyboard.isDown('s')) then spawn_brick() end
	
	bricksys.brick_world:update(dt)

	-- call update handlers
	for i,e in ipairs(entity.pool) do
		if e.update then
			for k,func in pairs(e.update) do
				func(e, dt)
			end
		end
	end

	phys_world:update(dt)

	-- set entity's position the same as physics body
	for i,e in ipairs(entity.pool) do
		if e.physics then
			e.transform.x, e.transform.y = e.physics.body:getPosition()
		end
	end
	love.window.setTitle('FPS: '..love.timer.getFPS())
end


function reset()
	entity.reset()  -- refresh pool
	bricksys.brick_world:reset()
	phys_world = love.physics.newWorld(0, 1000)  -- physics world
	set_boundaries()
	local player = entity.new_player(400, 20)
	for i=1,10 do spawn_brick() end
	collectgarbage()
end


------ Helper Functions Below ------

function is_on_ground(body, require_static, reverse)
	--[[
	Tell if a body is on top of any object.

	require_static   if the 'ground' body must be static
	--]]
	for i,contact in ipairs(body:getContactList()) do
		if contact:isTouching() then
			local fixture1, fixture2 = contact:getFixtures()
			local normal_x, normal_y = contact:getNormal()
			local body1 = fixture1:getBody()
			if body == body1 and math.ldexp(normal_x, 8) < 1 then
				local body2 = fixture2:getBody()
				if (not require_static or body2:getType() == 'static') and
						body2:getUserData().tag.ground then
					if (reverse and normal_y < 0) or normal_y > 0 then
						return true
					end
				end
			else
				if (not require_static or body1:getType() == 'static') and
						body1:getUserData().tag.ground then
					if (reverse and normal_y > 0) or normal_y < 0 then
						return true
					end
				end
			end
		end
	end
	return false
end

function spawn_brick()
	local choice = math.random(1, #bricksys.TEXTURES)
	entity.new_brick(math.random(25, 775), math.random(-50, 0), choice, bricksys.TEXTURES[choice])
end

function set_boundaries()
	local boundaries = entity.new_entity()
	boundaries.tag.type = 'boundary'
	boundaries.tag.ground = true
	entity.attach_physics(boundaries, 0, 0, 'static')
	local b = boundaries.physics.body
	local s
	local width, height = love.graphics.getDimensions()
	s = love.physics.newEdgeShape(0, -100, width, -100) -- ceiling
	love.physics.newFixture(b, s)
	s = love.physics.newEdgeShape(0, -100, 0, height) -- left wall
	love.physics.newFixture(b, s):setRestitution(0.1)
	s = love.physics.newEdgeShape(0, height, width, height) -- floor
	love.physics.newFixture(b, s)
	s = love.physics.newEdgeShape(width, -100, width, height) -- right wall
	love.physics.newFixture(b, s):setRestitution(0.1)
end
