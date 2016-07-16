local entity = require("entity")


function love.load(arg)
	print(bricksys.s)
	collectgarbage('stop')  -- stop gc
	if arg[#arg] == "-debug" then require("mobdebug").start() end  -- start debugger
	math.randomseed(os.time())
	reset()
end


function love.draw()
	for i,v in ipairs(entity.pool) do
		if v.graphics then
			love.graphics.draw(v.graphics.image, v.transform.x, v.transform.y, 0, 1, 1, v.graphics.ox, v.graphics.oy)
		end
	end

	bricksys.brick_world:draw()
end


local has_reset = false

function love.update(dt)
	if love.keyboard.isDown('r') then
		if not has_reset then
			has_reset = true
			reset()
		end
	else
		has_reset = false
	end

	if love.keyboard.isDown('s') then
		spawn_brick()
	end
	
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
	for i,v in ipairs(entity.pool) do
		if v.physics then
			v.transform.x, v.transform.y = v.physics.body:getPosition()
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
	for i=1,100 do spawn_brick() end
	collectgarbage()
end


function spawn_brick()
	entity.new_brick(math.random(20,780), math.random(20,580), math.choice(bricksys.COLORS))
end


function set_boundaries()
	local boundaries = entity.new_entity()
	boundaries.tag.type = 'ground'
	entity.attach_physics(boundaries, 0, 0, 'static')
	local b = boundaries.physics.body
	local s
	local width, height = love.graphics.getDimensions()
	s = love.physics.newEdgeShape(0, 0, width, 0) -- ceil
	love.physics.newFixture(b, s)
	s = love.physics.newEdgeShape(0, 0, 0, height) -- left
	love.physics.newFixture(b, s)
	s = love.physics.newEdgeShape(0, height, width, height) -- floor
	love.physics.newFixture(b, s)
	s = love.physics.newEdgeShape(width, 0, width, height) -- right
	love.physics.newFixture(b, s)
end


------ Helper Functions Below ------

function table.popi(t, item)
	for i,v in ipairs(t) do
		if item == v then
			table.remove(t, i)
			return true
		end
	end
	return false
end

function table.popk(t, item)
	for k,v in pairs(t) do
		if item == v then
			t[k] = nil
			return true
		end
	end
	return false
end

function math.round(n)
	return math.floor(n+0.5)
end

function math.choice(list)
	return list[math.random(1, #list)]
end

function math.pyth(a, b)  -- Pythagorean theorem  勾股定理
	return math.sqrt(a*a + b*b)
end

function math.limit(n, lower_bound, upper_bound)
	if n<lower_bound then
		return lower_bound
	elseif n>upper_bound then
		return upper_bound
	else
		return n
	end
end

function is_on_ground(body, require_static, reverse)
	--[[
	Tell if a body is on top of any object.

	require_static   if the 'ground' body must be static
	--]]
	for i,v in ipairs(body:getContactList()) do
		local fixture1, fixture2 = v:getFixtures()
		local normal_x, normal_y = v:getNormal()
		local body1 = fixture1:getBody()
		if body == body1 then
			local body2 = fixture2:getBody()
			if (not require_static or body2:getType() == 'static') and
					body2:getUserData().tag.type == 'ground' and
					math.ldexp(normal_x, 8) < 1 then
				if (reverse and normal_y < 0) or normal_y > 0 then
					return true
				end
			end
		else
			if (not require_static or body1:getType() == 'static') and
					body1:getUserData().tag.type == 'ground' and
					math.ldexp(normal_x, 8) < 1 then
				if (reverse and normal_y > 0) or normal_y < 0 then
					return true
				end
			end
		end
	end
	return false
end
