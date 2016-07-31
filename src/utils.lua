-- some function "hacks"

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

function table.populate(t, extern)
	assert(extern)
	for k,v in pairs(extern) do
		t[k] = v
	end
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

function math.randomf(lower_bound, upper_bound)
	return lower_bound + math.random() * (upper_bound - lower_bound)
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


------ Helper Functions Below ------

function new_image_debug(width, height, fill_color)
	local image_data = love.image.newImageData(width, height)
	for x=0,width-1 do
		for y=0,height-1 do
			image_data:setPixel(x, y, unpack(fill_color))
		end
	end
	return love.graphics.newImage(image_data)
end

function new_flip_flop()
	local last_state = false
	function step(state)
		if state then
			if not last_state then
				last_state = true
				return true
			end
		else
			last_state = false
		end
		return false
	end
	return step
end

function filter_sort(t, pred, key)
	r = {}
	for i,v in ipairs(t) do
		if pred(v) then
			local index = #r + 1
			while index > 1 and key(r[index-1]) > key(v) do
				index = index - 1
			end
			table.insert(r, index, v)
		end
	end
	return r
end

function default_draw(e)
	love.graphics.draw(e.graphics.texture, e.transform.x, e.transform.y, 0, 1, 1, e.graphics.ox, e.graphics.oy)
end

function is_on_ground(body, require_static, reverse)
	--[[
	Tell if a body is on top of any object.

	require_static   if the 'ground' body must be static
	--]]
	for i,contact in ipairs(body:getContactList()) do
		if contact:isTouching() then
			local fixture1, fixture2 = contact:getFixtures()
			local normal_x, normal_y = contact:getNormal()
			local body1 = fixture1:getBody()
			if body == body1 and math.ldexp(normal_x, 8) < 1 then
				local body2 = fixture2:getBody()
				if (not require_static or body2:getType() == 'static') and
						body2:getUserData().tag.ground then
					if (reverse and normal_y < 0) or normal_y > 0 then
						return true
					end
				end
			else
				if (not require_static or body1:getType() == 'static') and
						body1:getUserData().tag.ground then
					if (reverse and normal_y > 0) or normal_y < 0 then
						return true
					end
				end
			end
		end
	end
	return false
end
