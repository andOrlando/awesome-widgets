local gtable = require "gears.table"
local base = require "wibox.widget.base"
local rubato = require "lib.rubato"
local color = require "lib.color"

local slider = {}

local function new_widget(args)
	local res = base.make_widget(nil, nil, {enable_properties = true})
    gtable.crush(res, slider, true)
	gtable.crush(res, args or {}, true)

	res.color_bar = res.color_bar or color.color {hex="#000000"}
	res.color_bar_active = res.color_bar_active or color.color {hex="#aaaaaa"}
	res.color_handle = res.color_handle or color.color {hex="#ffffff"}
	res.height_bar = res.height_bar or 8
	res.height_handle = res.height_handle or 15
	res.lw_margins = res.lw_margins or 10

	res.forced_height = res.forced_height or nil
	res.forced_width = res.forced_width or nil

	res._private.pos_timed = rubato.timed {}

	res._private.cached = {}
	function make_vars()
		res._private.cached.hb2 = res.height_bar / 2
		res._private.cached.bar_start = res.lw_margins+res._private.cached.hb2
		res._private.cached.pi2 = math.pi * 2
		res._private.cached.value_min = res.lw_margins-res._private.cached.hb2
	end






	--wibox.widget {} compatibility
	local mt = getmetatable(res)
	setmetatable(res, {})
	local ___index = mt.__index
	local ___newindex = mt.___newindex
	function mt:__index(key)
		--autogenerate getters and setters
		if key:match("set_") and args[key:sub(5)] then return function(_, v) args[key:sub(5)] = v; make_vars() end end
		if key:match("get_") and args[key:sub(5)] then return function() return args[key:sub(5)] end end

		--otherwise pass to widget.base
		return ___index(self, key)
	end
	function mt:__newindex(key, value)
		if args[key] then args[key] = value; return end
		return ___newindex(self, key, value)
	end
	setmetatable(res, mt)

	return res
end

function slider:draw(_, _, cr, width, height)
	local c = self._private.cached
	local t = self._private.pos_timed
	c.bar_end = width - c.bar_start
	c.height2 = height / 2
	c.value_max = width - c.bar_start - c.hb2
	c.effwidth = c.value_max - c.value_min
	c.bar_current = t.pos * c.effwidth + self.height_bar

	cr:set_line_width(self.height_bar)
	cr:set_source_rgb(self.color_bar.r/255, self.color_bar.g/255, self.color_bar.b/255)

	--draw end circle
	cr:arc(c.bar_end, c.height2, c.hb2, 0, c.pi2)
	cr:fill()

	--draw entire inactive background
	cr:move_to(c.bar_start, c.height2)
	cr:line_to(c.bar_end, c.height2)
	cr:stroke()

	cr:set_source_rgb(self.color_bar_active.r/255, self.color_bar_active.g/255, self.color_bar_active.b/255)

	--draw start and current circle
	cr:arc(c.bar_start, c.height2, c.hb2, 0, c.pi2)
	cr:arc(c.bar_current, c.height2, c.hb2, 0, c.pi2)
	cr:fill()

	--draw active background
	cr:move_to(c.bar_start, c.height2)
	cr:line_to(c.bar_current, c.height2)
	cr:stroke()

	--draw current circle

end
function slider:fit(_, _, width, height) return width, height end


return setmetatable(slider, {__call=function(_,...) return new_widget(...) end})
