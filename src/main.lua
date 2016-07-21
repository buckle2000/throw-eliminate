require("util")
require("entitysys")


function love.load(arg)
	collectgarbage('stop')  -- stop gc
	if arg[#arg] == "-debug" then require("mobdebug").start() end  -- start debugger
	math.randomseed(os.time())
	reset()
end


function love.draw()
	love.graphics.reset()
	love.graphics.translate(1, 1)
	love.graphics.print('development build\nv1', 0, 0)
	for i,e in ipairs(filter_sort(entitysys.pool, function (e) return e.graphics end, function (e) return e.graphics.z end)) do
		local shader = e.graphics.shader
		if shader then
			love.graphics.setShader(shader)
		end
		-- TODO shader support
		if e.graphics.draw then
			e.graphics.draw(e)
		else
			default_draw(e)
		end
		if shader then
			love.graphics.setShader()
		end
	end
	bricksys.brick_world:draw()
end


function love.update(dt)
	-- call pre-process update handlers
	for i,e in ipairs(entitysys.pool) do
		assert(not e.destroyed, "Destroyed entity "..tostring(e.tag.name).." should no longer be stored in the object pool.")
		if e.update and e.update.pre then
			for k,func in pairs(e.update.pre) do
				func(e, dt)
			end
		end
	end
	if love.keyboard.isDown('m') then spawn_brick() end
	bricksys.brick_world:update(dt)
	phys_world:update(dt)
	-- set entity's position the same as physics body
	for i,e in ipairs(entitysys.pool) do
		if e.physics then
			e.transform.x, e.transform.y = e.physics.body:getPosition()
		end
	end
	-- call post-process update handlers
	for i,e in ipairs(entitysys.pool) do
		assert(not e.destroyed, "Destroyed entity "..tostring(e.tag.name).." should no longer be stored in the object pool.")
		if e.update and e.update.post then
			for k,func in pairs(e.update.post) do
				func(e, dt)
			end
		end
	end
end


local keyboard_player
function love.keypressed(key)
	if key == 'r' then
		reset()
	elseif key == 's' then
		-- spawn_brick()
		for i=1,3 do for c=1,6 do spawn_brick(c) end end
	else
		local player_inactive = not keyboard_player or keyboard_player.destroyed
		if key == 'escape' and not player_inactive then
			entitysys.destroy_entity(keyboard_player)
		elseif player_inactive then
			if key == 'up' or
					key == 'down' or
					key == 'left' or
					key == 'right' then
				keyboard_player = entitysys.new_player(400, -20, new_input_keyboard('up', 'down', 'left', 'right', 'space', 'f'))
			end
		end
	end
end


local joystick_players = {}
function love.joystickadded(joystick)
	local player = entitysys.new_player(400, -20)
	joystick_players[joystick] = player
end

function love.joystickremoved(joystick)
	entitysys.destroy_entity(joystick_players[joystick])
	joystick_players[joystick] = nil
end


function reset()
	keyboard_player = nil
	entitysys.reset()  -- refresh pool
	bricksys.brick_world:reset()
	phys_world = love.physics.newWorld(0, 1000)  -- physics world
	set_boundaries()
	for i=1,3 do for c=1,6 do spawn_brick(c) end end
	collectgarbage()
end


function default_draw(e)
	love.graphics.draw(e.graphics.texture, e.transform.x, e.transform.y, 0, 1, 1, e.graphics.ox, e.graphics.oy)
end
