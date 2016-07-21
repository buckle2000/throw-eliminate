module("bricksys", package.seeall)
require("entitysys")
local tween = require("lib/tween")

GRID_SIZE = 50
TEXTURES = {}
for i=1,6 do
	TEXTURES[i] = love.graphics.newImage('assets/tile_'..i..'.png')
end

brick_world = {}

function brick_world:reset()
	self.data = {}
	self.width = math.floor(love.graphics.getWidth() / GRID_SIZE)
	self.height = math.floor(love.graphics.getHeight() / GRID_SIZE)
end

function brick_world:index2coords(index)
	local x = (index-1) % self.width
	return x, math.floor((index-1) / self.width)
end

function brick_world:get(x, y)
	if x<0 or y<0 or x>=self.width or y>=self.height then
		return nil
	else
		return self.data[x+y*self.width+1]
	end
end

function brick_world:set(item, x, y)
	if item then assert(not self:get(x, y)) end  -- must not overwrite brick data
	self.data[x+y*self.width+1] = item
end

function brick_world:freeze(brick)
	assert(not brick.bricksys.frozen)
	local b = brick.physics.body
	local x, y = self:get_grid_pos(brick)
	if self:get(x, y) then
		return false  -- there is already a brick there
	else
		b:setType('static')
		brick.bricksys.frozen = {x=x, y=y}
		self:set(brick, x, y)
		local world_x = (x + 0.5) * GRID_SIZE
		local world_y = (y + 0.5) * GRID_SIZE
		b:setPosition(world_x, world_y)
		self:try_eliminate(x, y, 3)
		return true, x, y  -- success
	end
end

function brick_world:try_eliminate(start_x, start_y, least_group)
	local group = self:flood_fill(start_x, start_y)
	local latest_touch_player = nil
	local latest_touch_time = 0
	local now = love.timer.getTime()
	if #group >= least_group then  -- eliminate
		local affected = {}
		for i,e in ipairs(group) do
			local time = e.bricksys.last_hold.time
			local subject = e.bricksys.last_hold.subject
			if time > latest_touch_time then
				latest_touch_time = time
				latest_touch_player = subject
			end
			table.insert(affected, {self:get_grid_pos(e)})
			entitysys.destroy_entity(e)
		end
		if latest_touch_player then
			for i,v in ipairs(affected) do
				local x, y = unpack(v)
				if y ~= 0 then
					local above = self:get(x, y-1)
					if above then
						update_last_hold(above, latest_touch_player)
					end
				end
			end
		end
	end
	if latest_touch_player and latest_touch_player.bricksys and latest_touch_player.bricksys.cb then
		latest_touch_player.bricksys.cb(latest_touch_player, #group)
	end
end

function brick_world:unfreeze(brick)
	assert(brick.bricksys.frozen)
	local x, y = self:get_grid_pos(brick)
	brick.bricksys.frozen = nil
	self:set(nil, x, y)
	entitysys.add_pre_update(brick, update_brick, "bricksys")
	brick.physics.body:setType('dynamic')
end

function brick_world:get_grid_pos(brick)
	assert(brick.bricksys)
	local pos = brick.bricksys.frozen
	if pos then
		return pos.x, pos.y
	end
	local x, y = brick.physics.body:getPosition()
	x, y = math.floor(x / GRID_SIZE), math.floor(y / GRID_SIZE)
	return math.limit(x, 0, self.width-1), math.limit(y, 0, self.height-1)
end

function brick_world:update(dt)
	--[[
	Make hovering bricks drop.
	--]]
	for x=0,self.width-1 do
		for y=0,self.height-2 do
			local brick = self:get(x, y)
			if brick then
				local brick_below = self:get(x, y+1)
				if not brick_below then
					self:unfreeze(brick)
				end
			end
		end
	end
end

function brick_world:draw()
	love.graphics.setColor(255,255,255)
	love.graphics.setLineStyle('rough')
	love.graphics.setLineWidth(1)
	for x=0,self.width-1 do
		for y=0,self.height-1 do
			local brick = self:get(x, y)
			if brick then
				love.graphics.rectangle('line', x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)
				-- love.graphics.circle('line', (x + 0.5) * GRID_SIZE, (y + 0.5) * GRID_SIZE, 10)
			end
		end
	end
	-- love.graphics.setColor(255, 255, 255)
end

function brick_world:flood_fill(x, y)
	local color
	do
		local entity = self:get(x, y)
		if entity then
			color = entity.bricksys.type
		else
			return {}
		end
	end
	local result  = {}
	local queue   = {{x, y}}
	local visited = {}
	while #queue > 0 do
		local n = table.remove(queue, 1)
		assert(n)
		local x, y = unpack(n)
		local entity = self:get(x, y)
		if entity and color == entity.bricksys.type then
			local already_visited = false
			for i,v in ipairs(visited) do
				if x==v[1] and y==v[2] then
					already_visited = true
					break
				end
			end
			if not already_visited then
				table.insert(result, entity)
				table.insert(visited, n)
				table.insert(queue, {x+1, y})
				table.insert(queue, {x-1, y})
				table.insert(queue, {x, y+1})
				table.insert(queue, {x, y-1})
			end
		end
	end
	return result
end

function update_last_hold(entity, subject)
	entity.bricksys.last_hold = {
		subject = subject,
		time = love.timer.getTime()
	}
end

function update_brick(self, dt)
	local b = self.physics.body
	if b:getType() == 'dynamic' then
		if math.pyth(b:getLinearVelocity()) < 0.01 and is_on_ground(b, true) then
			local x, y = self.physics.body:getPosition()
			local success, desire_x, desire_y = brick_world:freeze(self)
			if success then
				entitysys.remove_pre_update(self, "bricksys")
				desire_x = (desire_x + 0.5) * GRID_SIZE
				desire_y = (desire_y + 0.5) * GRID_SIZE
				self.graphics.ox, self.graphics.oy = desire_x - x + GRID_SIZE/2, desire_y - y + GRID_SIZE/2
				entitysys.new_tween(self, {0.2, self.graphics, {ox=GRID_SIZE/2, oy=GRID_SIZE/2}, 'outQuart'})  -- make graphics tween
			end
		end
	end
end

brick_world:reset()
