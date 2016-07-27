local state = {}
state.__index = state

function state:draw()
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

function state:update(dt)
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

return state