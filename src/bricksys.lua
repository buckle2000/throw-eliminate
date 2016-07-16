module(..., package.seeall)
local entity = require("entity")

GRID_SIZE = 50
COLORS = {
	{255,0,0},
	{0,255,0},
	{0,0,255}
}

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
	assert(not (item and self:get(x, y)))
	self.data[x+y*self.width+1] = item
end

function brick_world:freeze(brick)
	local b = brick.physics.body
	local x, y = self:get_grid_pos(brick)
	if self:get(x, y) then
		return false  -- there is already a brick there
	else
		b:setType('static')
		brick.bricksys.frozen = {x=x, y=y}
		self:set(brick, x, y)
		x = (x + 0.5) * GRID_SIZE
		y = (y + 0.5) * GRID_SIZE
		b:setPosition(x, y)
		return true, x, y  -- success
	end
end

function brick_world:unfreeze(brick)
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
	for x=0,self.width-1 do
		for y=0,self.height-1 do
			local brick = self:get(x, y)
			if brick then
				love.graphics.circle('line', (x + 0.5) * GRID_SIZE, (y + 0.5) * GRID_SIZE, 10)
			end
		end
	end
end

function brick_world:construct_line(x, y, dx, dy, n)
	rt = {}
	for i=1,n do
		table.insert(rt, self:get(x, y))
		x, y = x+dx, y+dy
	end
	return rt
end

function brick_world:detect_once(x, y)
	self:try_eliminate(x, y,  1,  0, 3)
	self:try_eliminate(x, y,  0,  1, 3)
	self:try_eliminate(x, y, -1,  0, 3)
	self:try_eliminate(x, y,  0, -1, 3)
	self:try_eliminate(x, y,  1,  1, 3)
	self:try_eliminate(x, y,  1, -1, 3)
	self:try_eliminate(x, y, -1,  1, 3)
	self:try_eliminate(x, y, -1, -1, 3)
end

function brick_world:try_eliminate(x, y, dx, dy, n)
	local line = self:construct_line(x, y, dx, dy, n)
	local same = all_same_color(line)
	if same then
		for i,brick in ipairs(line) do
			print(brick)
			local x, y = get_grid_pos(brick)
			entity.destroy_entity(brick)
			self:set(nil, x, y)
			x, y = x+dx, y+dy
		end
	end
	return same
end
function all_same_color(line)
	local color
	for i,brick in ipairs(line) do
		if not brick then
			return false
		end
		if not color then
			color = brick.tag.color
		elseif color ~= brick.tag.color then
			return false
		end
	end
	return true
end

function update_brick(self, dt)
	local b = self.physics.body
	if b:getType() == 'dynamic' then
		if math.pyth(b:getLinearVelocity()) < 0.01 and is_on_ground(b, true) then
			self.update.bricksys = nil
			local success, x, y = brick_world:freeze(self)
			-- if success then
			-- 	brick_world:detect_once(x, y)
			-- end
		end
	end
end

brick_world:reset()
