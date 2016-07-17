module("bricksys", package.seeall)
require("entity")
local tween = require("lib/tween")

GRID_SIZE = 50
TEXTURES = {}
for i=1,6 do
	TEXTURES[i] = love.graphics.newImage('assets/tile_'..i..'.png')
end
-- debug textures
-- new_image_debug(50, 50, {0,0,255}),
-- new_image_debug(50, 50, {0,255,0}),
-- new_image_debug(50, 50, {132,53,122}),
-- new_image_debug(50, 50, {255,0,0}),
-- new_image_debug(50, 50, {255,255,0}),
-- new_image_debug(50, 50, {6,238,191})

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
		local result = self:flood_fill(x, y)
		if #result >= 3 then  -- eliminate
			for i,v in ipairs(result) do
				entity.destroy_entity(v)
			end
		end
		return true, x, y  -- success
	end
end

function brick_world:unfreeze(brick)
	assert(brick.bricksys.frozen)
	local x, y = self:get_grid_pos(brick)
	brick.bricksys.frozen = nil
	self:set(nil, x, y)
	brick.update.bricksys = update_brick
	brick.physics.body:setType('dynamic')
end

function brick_world:get_grid_pos(brick)
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
	love.graphics.setColor(131, 131, 131)
	for x=0,self.width-1 do
		for y=0,self.height-1 do
			local brick = self:get(x, y)
			if brick then
				love.graphics.circle('line', (x + 0.5) * GRID_SIZE, (y + 0.5) * GRID_SIZE, 10)
			end
		end
	end
	love.graphics.setColor(255, 255, 255)
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
	for i,v in ipairs(result) do
		--print(unpack(v))
	end
	return result
end

function update_brick(self, dt)
	local b = self.physics.body
	if b:getType() == 'dynamic' then
		if math.pyth(b:getLinearVelocity()) < 0.01 and is_on_ground(b, true) then
			self.update.bricksys = nil
			local x, y = self.physics.body:getPosition()
			local desire_x, desire_y = brick_world:get_grid_pos(self)
			desire_x = (desire_x + 0.5) * GRID_SIZE
			desire_y = (desire_y + 0.5) * GRID_SIZE
			self.graphics.ox, self.graphics.oy = desire_x - x + GRID_SIZE/2, desire_y - y + GRID_SIZE/2
			entity.new_tween(self, {0.2, self.graphics, {ox=GRID_SIZE/2, oy=GRID_SIZE/2}, 'outQuart'})  -- make graphics tween
			brick_world:freeze(self)
		end
	end
end

brick_world:reset()
