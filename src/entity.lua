module("entity", package.seeall)
require("bricksys")
require("entity_impl1")  -- extended definition
local tween = require("lib/tween")

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
		if e.destroy then
			if e:destroy() then return end  -- return true means stop default behavior
		end
		detach_bricksys(e)
		detach_physics(e)
		table.popi(pool, e)
		e.destroyed = true  -- for some reasons I don't know
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
	density = density or 1
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
		p.fixture = love.physics.newFixture(p.body, shape, density)
		p.density = density
	end
	return p.fixture
end

function detach_physics(e)
	if e.physics then
		e.physics.body:destroy()
		e.physics = nil
	end
end

function attach_graphics(e, drawable, ox, oy)
	attach_transform(e)
	e.graphics = e.graphics or {}
	e.graphics.image = drawable
	e.graphics.ox = ox
	e.graphics.oy = oy
end

function attach_graphics_debug(e, width, height, color, ox, oy)
	--[[
	Create a filled rectangle with given color and size. For debug only.

	width, height   size of the graphic
	color           color of the rectangle  e.g. {0,0,0}
	ox, oy          offset of graphic
	--]]
	local image = new_image_debug(width, height, color)
	attach_graphics(e, image, ox or width/2, oy or height/2)
end

function attach_bricksys(e, color)
	assert(e.physics, "A brick must have a physics body.")
	e.tag.type = 'brick'
	e.tag.ground = true
	e.tag.moveable = true
	e.tag.color = color
	e.bricksys = {}
	e.physics.body:setFixedRotation(true)
	e.physics.body:setBullet(true)  -- for some drastic collisions
	e.update = {bricksys=bricksys.update_brick}
end

function detach_bricksys(e)
	if e.bricksys then
		table.popk(bricksys.brick_world.data, e)
	end
end

function new_tween(e, args, cb_complete)
	local tween_func = tween.new(unpack(args))
	e.update.tween = function (self, dt)
			local complete = tween_func:update(dt)
			if complete then
				self.update.tween = nil
				if cb_complete then
					cb_complete(self)
				end
			end
		end
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

