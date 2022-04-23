---@diagnostic disable: empty-block, unused-function
local wibox = require "wibox"
local base = require "wibox.widget.base"

-- must be something they have a setter for
-- as in set_propname must exist
local PROPERTIES = {
	margin = { "left", "right", "top", "bottom", "margins" },
	constraint = { "width", "height", "strategy" },
	background = { "bg", "shape" },
	place = { "valign", "halign" }
}

--helper table function
local function index(table, value)
	for k,v in pairs(table) do if v == value then return k end end
	return false
end

-- literally just contains a widget
-- that's literally it
local function simple_container()
	local w = wibox.widget.base.make_widget()
	function w:fit(context, width, height)
		if not self._private.widget then return 0, 0 end
		return base.fit_widget(self, context, self._private.widget, width, height)
	end
	function w:layout(_, width, height)
		if not self._private.widget then return end
		return { base.place_widget_at(self._private.widget, 0, 0, width, height) }
	end
	function w:set_children(widgets) self._private.widget = widgets[1] end
	function w:get_children() return { self._private.widget } end
	return w
end

-- literally just transparent
-- emulates its child exactly
local function passthrough_container()
	local w = wibox.widget.base.make_widget(nil, nil, {enable_properties=true})
	function w:set_children(widgets) w._private.widget = widgets[1] end
	function w:get_children() return { w._private.widget } end

	function w:fit(...) return w._private.widget:fit(...) end
	function w:layout(...) return w._private.widget:layout(...) end
	function w:before_draw_children(...) if w._private.widget.before_draw_children then w._private.widget:before_draw_children(...) end end
	function w:after_draw_children(...) if w._private.widget.after_draw_children then w._private.widget:after_draw_children(...) end end
	return w
end

-- align layout but better becuase it also has margins and uses expand
local function alignplus(orientation)
	--private properties
	--not put in _private so as to not mess with weird widget.base stuff
	local expand = "default"
	local spacing = 0
	local widgets = {}
	--direction for padding, saved as to not have to do multiple times
	local margin_direction = orientation == "horizontal" and "left" or "bottom"

	--create the widget
	local w = wibox.layout.align[orientation]()

	--these margins act as containers for the first and second widgets and are
	--used for emulating spacing
	local margin1, margin2 =  wibox.container.margin(), wibox.container.margin()
	w:set_children { margin1, margin2 }

	--save the existing metatable for modification
	local mt = getmetatable(w)
	setmetatable(w, {})

	--getters and setters for properties
	function w:set_expand(value)
		expand = value
		w:set_children()
	end
	function w:set_spacing(value)
		spacing = value
		if expand == "default" then
			margin1[margin_direction] = spacing
			margin2[margin_direction] = spacing
		elseif expand == "expfirst" then
			margin1[margin_direction] = 0
			margin2[margin_direction] = spacing
		elseif expand == "explast" or expand == "neither" then
			margin1[margin_direction] = spacing
			margin2[margin_direction] = 0
		end
	end
	function w:get_expand() return expand end
	function w:get_spacing() return spacing end

	--save old __index and __newindex as fallbacks
	local ___index = mt.__index
	local ___newindex = mt.___newindex
	--do accessors
	function mt:__index(key)
		if key == "spacing" then return w:get_spacing()
		elseif key == "expand" then return w:get_expand()
		else return ___index(self, key) end
	end
	function mt:__newindex(key, value)
		if key == "spacing" then w:set_spacing(value)
		elseif key == "expand" then w:set_expand(value)
		else ___newindex(self, key, value) end
	end

	--override set_children and get_children to account for margins
	function w:set_children(value)
		widgets = value or {}
		if expand == "default" then
			margin1:set_children { widgets[1] }
			margin2:set_children { widgets[2] }
			w:set_third(widgets[3])
		elseif expand == "expfirst" then
			margin1:set_children { nil }
			margin2:set_children { widgets[1] }
			w:set_third(widgets[2])
		elseif expand == "explast" then
			margin1:set_children { widgets[1] }
			margin2:set_children { widgets[2] }
			w:set_third(nil)
		elseif expand == "neither" then
			margin1:set_children { widgets[1] }
			margin2:set_children { nil }
			w:set_third(widgets[2])
		end
		w:set_spacing(spacing)
		if not margin1:get_children()[1] then margin1[margin_direction] = 0 end
		if not margin2:get_children()[1] then margin2[margin_direction] = 0 end
	end
	function w:get_children() return widgets end

	--rewrite metatble
	setmetatable(w, mt)

	return w
end

--- Cool widget
--
-- args is a list of strings, all but the last 1-2 being container names
-- and the last 1-2 determining layout type and orientation. It maps
-- properties set to its designated container with the PROPERTIES constant
local function create(args)
	---@diagnostic disable-next-line: unused-local
	local debug; if args[#args] == "debug" then debug = true; table.remove(args, #args) end

	--parts is where we save all the containers
	local parts = {}

	--determine the main type of the widget
	--the only "special" main types are "align" and "container"
	local main
	if args[#args] == "container" then main = simple_container()
	elseif args[#args-1] == "align" then main = alignplus(args[#args])
	else main = wibox.layout[args[#args-1]][args[#args]]() end

	--remove tail
	if args[#args] ~= "container" then table.remove(args, #args) end
	table.remove(args, #args)

	--creates this base widget
	local w = passthrough_container()

	--populates w and parts
	--does so by iterating through args and adding each widget
	--to the widget before it, except for the first one which
	--gets added to w
	for i=1,#args do
		local c = wibox.container[args[i]]()
		parts[args[i]] = c

		if i == 1 then w:set_children { c }
		else parts[args[i-1]]:set_children { c } end
	end

	--finally, add in main to the last widget
	if #args > 0 then parts[args[#args]]:set_children { main }
	else w:set_children { main } end

	--do all the metatable stuff
	local mt = getmetatable(w)
	setmetatable(w, {})
	local ___index = mt.__index
	local ___newindex = mt.__newindex
	function mt:__index(key)
		--autogenerate setters
		if key:match("set_") then
			for k, v in pairs(PROPERTIES) do if index(v, key:sub(5)) then return function(_, value) rawget(parts[k], key)(parts[k], value) end end end
			return nil --if it's not in there just return nothing
		end

		--if it's expand or spacing we forward it to main
		if key == "expand" or key == "spacing" then return rawget(main, "get_"..key)(main) end

		--check if it's in properties anywhere
		for k, v in pairs(PROPERTIES) do if index(v, key) then return rawget(parts[k], "get_"..key)(parts[k]) end end

		--otherwise pass to widget.base
		return ___index(self, key)
	end
	function mt:__newindex(key, value)
		--if it's expand or spacing we forward it to main
		if key == "expand" or key == "spacing" then return rawget(main, "set_"..key)(main, value) end

		--check for property and setter
		for k, v in pairs(PROPERTIES) do if index(v, key:gsub("set_", "")) then return rawget(parts[k], "set_"..key)(parts[k], value) end end

		--otherwise pass to widget.base
		return ___newindex(self, key, value)
	end

	--do the last bit of api stuff
	function w:set_children(widgets) main:set_children(widgets) end
	function w:get_children() return main:get_children() end

	setmetatable(w, mt)

	return w
end


local function get_containers_recursive(args)
	local mt = {}
	function mt:__index(key)
		local new = {}
		for k,v in pairs(args) do new[k]=v end
		table.insert(new, key)
		return get_containers_recursive(new)
	end
	function mt:__call() return create(args) end
	return setmetatable({is_widget=false}, mt)
end

return get_containers_recursive {}
