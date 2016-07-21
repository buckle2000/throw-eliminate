module("entitysys", package.seeall)
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

function add_pre_update(e, func, custom_name)
	custom_name = custom_name or func
	e.update = e.update or {}
	e.update.pre = e.update.pre or {}
	e.update.pre[custom_name] = func
end

function add_post_update(e, func, custom_name)
	custom_name = custom_name or func
	e.update = e.update or {}
	e.update.post = e.update.post or {}
	e.update.post[custom_name] = func
end

function remove_pre_update(e, name)
	if e.update and e.update.pre then
		e.update.pre[name] = nil
		if next(e.update.pre) == nil then
			e.update.pre = nil
			if next(e.update) == nil then
				e.update = nil
			end
		end
	end
end

function remove_post_update(e, name)
	if e.update and e.update.post then
		e.update.post[name] = nil
		if next(e.update.post) == nil then
			e.update.post = nil
			if next(e.update) == nil then
				e.update = nil
			end
		end
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
	p.body:setBullet(true)  -- for some drastic collisions

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

function attach_graphics(e, texture, ox, oy, z)
	attach_transform(e)
	e.graphics = e.graphics or {}
	e.graphics.texture = texture
	e.graphics.ox = ox
	e.graphics.oy = oy
	e.graphics.z = z or 0
end

function attach_graphics_debug(e, width, height, color, ox, oy)
	--[[
	Create a filled rectangle with given color and size. For debug only.

	width, height   size of the graphic
	color           color of the rectangle  e.g. {0,0,0}
	ox, oy          offset of graphic
	--]]
	local texture = new_image_debug(width, height, color)
	attach_graphics(e, texture, ox or width/2, oy or height/2)
end

function attach_bricksys(e, type)
	assert(type, "A brick must have a type (maybe 'any').")
	assert(e.physics, "A brick must have a physics body.")
	e.tag.type = 'brick'
	e.tag.ground = true
	e.tag.moveable = true
	e.bricksys = {}
	e.bricksys.type = type
	bricksys.update_last_hold(e, nil)
	e.physics.body:setFixedRotation(true)
	e.physics.body:setBullet(true)  -- for some drastic collisions
	add_pre_update(e, bricksys.update_brick, "bricksys")
end

function detach_bricksys(e)
	remove_pre_update(e, "bricksys")
	if e.bricksys then
		e.bricksys = nil
		table.popk(bricksys.brick_world.data, e)
	end
end

function new_tween(e, args, cb_complete, custom_name)
	custom_name = custom_name or "generic"
	local tween_func = tween.new(unpack(args))
	local wrapped = function (self, dt)
			local complete = tween_func:update(dt)
			if complete then
				remove_pre_update(e, custom_name)
				if cb_complete then
					cb_complete(self)
				end
			end
		end
	add_pre_update(e, wrapped, custom_name)
end

