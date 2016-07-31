require("utils")
require("entitysys")

local state = setmetatable({}, require("states.base_state"))

function state:enter()
	self:reset()
end

function state:reset()
	self.keyboard_player = nil
	self.joystick_players = {}
	entitysys.reset()  -- refresh pool
	bricksys.brick_world:reset()
	phys_world = love.physics.newWorld(0, 1000)  -- physics world
	set_boundaries()
	for i=1,3 do for c=1,#bricksys.TEXTURES do spawn_brick(c) end end
	collectgarbage()
end

function state:keypressed(key)
	if key == 'r' then
		self:reset()
	elseif key == 's' then
		-- spawn_brick()
		for i=1,3 do for c=1,6 do spawn_brick(c) end end
	else
		local player_inactive = not self.keyboard_player or self.keyboard_player.destroyed
		if key == 'escape' and not player_inactive then
			entitysys.destroy_entity(self.keyboard_player)
		elseif player_inactive then
			if key == 'up' or key == 'down' or key == 'left' or key == 'right' then
				self.keyboard_player = entitysys.new_player(400, -20, new_input_keyboard('up', 'down', 'left', 'right', 'space', 'f'))
			end
		end
	end
end

function state:joystickadded(joystick)
	assert(joystick:isGamepad(), "This game does not support gamepad with strange layout currently.")
	local player = entitysys.new_player(400, -20, new_input_gamepad(joystick, "leftx", "lefty", "b", "a"))
	self.joystick_players[joystick] = player
end

function state:joystickremoved(joystick)
	entitysys.destroy_entity(self.joystick_players[joystick])
	self.joystick_players[joystick] = nil
end

function spawn_brick(choice)
	local choice = choice or math.random(1, #bricksys.TEXTURES)
	entitysys.new_brick(math.random(25, 775), math.random(-50, 0), choice, bricksys.TEXTURES[choice])
end

function set_boundaries()
	local boundaries = entitysys.new_entity()
	boundaries.tag.type = 'boundary'
	boundaries.tag.ground = true
	entitysys.attach_physics(boundaries, 0, 0, 'static')
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

function new_input_keyboard(key_up, key_down, key_left, key_right, key_jump, key_grab)
	local has_jump = new_flip_flop()

	function check_input()
		local cx, cy, jump = 0, 0, has_jump(love.keyboard.isDown(key_jump))
		if love.keyboard.isDown(key_up) then
			cy = cy - 1
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

function new_input_gamepad(joystick, x_axis, y_axis, btn_jump, btn_grab)
	local has_jump = new_flip_flop()
	local has_grab = new_flip_flop()
	local grab = false

	function check_input()
		local jump = has_jump(joystick:isGamepadDown(btn_jump))
		local toggle_grab = has_grab(joystick:isGamepadDown(btn_grab))
		grab = grab ~= toggle_grab
		return joystick:getGamepadAxis(x_axis), joystick:getGamepadAxis(y_axis), jump, grab
	end
	return check_input
end

return state
