local play_state = require("states.play_state")

local current_state


function love.run()
	if love.math then
		love.math.setRandomSeed(os.time())
	end
	if love.load then love.load(arg) end
	if love.timer then love.timer.step() end
	local dt = 0
	while true do
		if current_state then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a
					end
				end
				if current_state[name] then
					current_state[name](current_state, a,b,c,d,e,f)
				end
			end
		else
			if not love.quit or not love.quit() then
				return 0
			end
		end
		love.timer.step()
		dt = love.timer.getDelta()
		love.update(dt)
		if love.graphics.isActive() then
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()
			if love.draw then love.draw() end
			love.graphics.present()
		end
		love.timer.sleep(0.001)
	end
end


function love.load(arg)
	collectgarbage('stop')  -- stop gc
	if arg[#arg] == "-debug" then require("mobdebug").start() end  -- start debugger
	math.randomseed(os.time())
	set_state(play_state)
end


function love.draw()
	current_state:draw()
end


function love.update(dt)
	current_state:update(dt)
end


function set_state(state)
	if current_state and current_state.exit then
		current_state:exit()
	end
	if not state.inited then
		if state.init then
			state:init()  -- only called once per game
		end
		state.inited = true
	end
	if state.enter then
		state:enter()
	end
	current_state = state
end
