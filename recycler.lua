local wibox = require "wibox"
local rubato = require "lib.rubato"

--[[
recycler = recycler()
recycler:add(notif)
recycler:remove(1)


possible animation styles:
dissapear
slide up

constructor function must be able to:
return a widget
widget must have method "populate" which gives it values



]]


local function create(constructor, args)
	local obj = {}
	obj.invisible = {}
	obj.visible = {}
	obj.by_args = {}

	args = args or {}
	local spacing = args.spacing or 15

	--keeps track of stuff for each widget
	--specifically, their timed objects and the function to redraw them both
	local wdata = {}

	obj.layout = wibox.layout.manual()

	---@diagnostic disable-next-line: redefined-local
	local function request_widget(args)
		local w
		if #obj.invisible == 0 then
			w = constructor()

			--override draw method to get width and height
			w._draw = w.draw;
			function w:draw(ctx, cr, width, height, ...)
				self.width, self.height = width, height
				self._draw(self, ctx, cr, width, height, ...)
			end

			wdata[w] = {
				redraw = function() obj.layout:move_widget(w, {x=0, y=wdata[w].pos.pos + 8 * wdata[w].inout.pos}); w.opacity = wdata[w].inout.pos end,
				inout = rubato.timed {duration=0.2, intro=0.1, pos=0},
				pos = rubato.timed {duration=0.2, intro=0.1, pos=0},
			}
			--we subscribe the functions seperately because they depend on eachother so the timeds must be instantiated first
			--rubato calls the subscribed funcitons as soon as they're subscribed so we have to delay subscribing them
			wdata[w].inout:subscribe(function(_, time) wdata[w].redraw(); if time == 0.3 then obj.invisible[#obj.invisible+1] = w end end)
			wdata[w].pos:subscribe(function() wdata[w].redraw() end)

			obj.layout:add_at(w, {x=0, y=0})

		else w = table.remove(obj.invisible, #obj.invisible) end
		--constructor must create a widget with this method
		--this passes in all the args necessary
		w:populate(args)
		obj.by_args[args] = w
		return w
	end

	--get the position of something based off all the elements before it
	--memoize past values so it's not n^2 because that would be icky
	local positions = setmetatable({}, {__mode="kv"})
	local function get_pos_at_index(index)
		local total
		if not positions[index-1] then
			total = (index - 1) * spacing
			for i=1, index-1 do total = total + (obj.visible[i].height or 0) end
		else total = positions[index-1] + spacing + (obj.visible[index-1].height or 0) end
		positions[index] = total
		return total
	end

	--update indices of tables
	local function reorder() for i, w in pairs(obj.visible) do wdata[w].pos.target = get_pos_at_index(i) end end

	--they look weird because it looks cooler actually
	--returns the widget and the position of that widget
	function obj:add(...)
		local w = request_widget(...); --get widget
		--TEST("adding"..tostring(...).."at index"..(#obj.visible+1))
		obj.visible[#obj.visible+1] = w --add widget to visible
		wdata[w].inout.target = 1 --appear it

		reorder(); return w, #obj.visible
	end
	function obj:add_at(pos, ...)
		local w = request_widget(...);
		table.insert(obj.visible, pos, w)
		wdata[w].inout.target = 1

		reorder(); return w, pos
	end
	--we don't actually remove from the list here that's done in inout's subscribed 
	--function so that it can fully animate out before it gets used again
	function obj:remove(w)
		wdata[w].inout.target = 0
		local pos; for k,v in pairs(obj.visible) do if v == w then pos = k; table.remove(obj.visible, pos) end end

		reorder(); return w, pos
	end
	function obj:remove_at(pos)
		local w = wdata[obj.visible[pos]]; w.inout.target = 0
		table.remove(obj.visible, pos)

		reorder() return w, pos
	end
	function obj:get_by_args(args) return obj.by_args[args] end

	return obj
end

local base = require "wibox.widget.base"
local gtable = require "gears.table"

local recycler_layout = {
	--orientation constants
	DOWN = 0,
	UP = 1,
	LEFT = 2,
	RIGHT = 3,
}

local function new_layout(constructor, args)
	local res = base.make_widget(nil, nil, {enable_properties = true})
	gtable.crush(res, recycler_layout, true)
	gtable.crush(res, args, true)

	--properties
	res._private.widgets = {} --visible widgets
	res._private.unused = {} --unused widgets TODO: make weak and attatch wdata to widgets more closely
	res._private.between = {} --widgets fading out
	res._private.wdata = {} --timers and data for each widget
	res._private.by_args = {} --key: widget value: widget args
	res._private.const = constructor --widget constructor

	--arguments
	res.padx = res.padx or 8
	res.pady = res.pady or 8
	res.spacing = res.spacing or res.padx

	res.fadedist = res.fadedist or res.spacing / 2 --distance it travels when fading in or out
	res.orientation = res.orientation or recycler_layout.DOWN

	res.scalex = res.scalex or 0
	res.scaley = res.scaley or 1

	res.inout_const = res.inout_const or function() return rubato.timed { duration = 0.2, intro = 0.3, prop_intro = true } end
	res.pos_const = res.pos_const or function() return rubato.timed { duration = 0.2, intro = 0.3, prop_intro = true } end

	return res
end

--layout superclass functions
function recycler_layout:fit(_, width, height) return width, height end
function recycler_layout:_place_with_orientation(widget, x, y, w, h, bigh, bigw)
	if self.orientation == self.DOWN then return base.place_widget_at(widget, x, y, w, h)
	elseif self.orientation == self.UP then return base.place_widget_at(widget, x, bigh-y, w, h)
	elseif self.orientation == self.LEFT then return base.place_widget_at(widget, y, x, w, h)
	elseif self.orientation == self.RIGHT then return base.place_widget_at(widget, bigw-y, x, w, h)
	end
end
function recycler_layout:layout(context, width, height)
	local res = {}
	local wdata, widgets, unused, between =
		self._private.wdata,
		self._private.widgets,
		self._private.unused,
		self._private.between

	local data, prevdata
	local to_remove = {}

	--draw currently visible widges
	for i, w in pairs(widgets) do

		data, prevdata = wdata[w], wdata[widgets[i-1]]
		data.w, data.h = base.fit_widget(self, context, w, width, height)
		data.y = prevdata and prevdata.y + prevdata.h + self.spacing or self.pady

		data.pos.target = data.y
		w.opacity = data.inout.pos

		table.insert(res, self:_place_with_orientation(
			w,
			self.padx - (1-data.inout.pos) * self.fadedist * self.scalex,
			data.pos.pos - (1-data.inout.pos) * self.fadedist * self.scaley,
			data.w,
			data.h,
			width,
			height))
	end

	for i, w in pairs(between) do

		data = wdata[w]
		data.w, data.h = base.fit_widget(self, context, w, width, height)

		w.opacity = data.inout.pos

		--check for inout being zero and deletion is done here because I can't ensure
		--that inout's subscribed function gets called if it's immediately added then
		--deleted, resulting in an invisible widet.
		if data.inout.pos == 0 then table.insert(to_remove, i) end

		table.insert(res, self:_place_with_orientation(
			w,
			self.padx - (1-data.inout.pos) * self.fadedist * self.scalex,
			data.pos.pos - (1-data.inout.pos) * self.fadedist * self.scaley,
			data.w,
			data.h,
			width,
			height))
	end

	--remove widgets to be removed
	for i=1,#to_remove do table.insert(unused, table.remove(between, to_remove[i]-i+1)) end

	return res
end

function recycler_layout:set_children(...)
	for i=#self._private.widgets,1,-1 do self:remove_at(i) end
	for _,args in pairs {...} do self:add(args) end
end
function recycler_layout:get_children() return self._private.widgets end

--hidden functions
function recycler_layout:_request_widget(args)
	local w
	local unused, wdata = self._private.unused, self._private.wdata

	--if we don't have a widget available create a new one
	if #unused == 0 then
		w = self._private.const()

		wdata[w] = { w=0, h=0, y=0, inout = self.inout_const(), pos = self.pos_const() }
		wdata[w].inout:subscribe(function() self:emit_signal("widget::layout_changed") end)
		wdata[w].pos:subscribe(function() self:emit_signal("widget::layout_changed") end)

	--if we already have a widget just use that
	else w = table.remove(unused, #unused) end

	--constructor must create a widget with this method
	--this passes in a single variable, ideally something unique
	--if not unique, pass in a table with the value or something
	--to make it identifiable
	w:populate(args)
	self._private.by_args[args] = w
	return w
end

--important functions
function recycler_layout:add_at(pos, args)
	local w = self:_request_widget(args)
	local data, widgets = self._private.wdata[w], self._private.widgets
	local prevdata = self._private.wdata[widgets[pos-1]]

	table.insert(widgets, pos, w)

	data.inout.target = 1
	data.pos.pos = prevdata and prevdata.y + prevdata.h + self.spacing or self.pady

	self:emit_signal("widget::layout_changed")
	return w, pos
end
function recycler_layout:remove_at(pos, w)
	local w = w or self._private.widgets[pos]
	local data, widgets, between = self._private.wdata[w], self._private.widgets, self._private.between

	data.inout.target = 0

	table.insert(between, table.remove(widgets, pos))

	self:emit_signal("widget::layout_changed")
	return w, pos
end

--shorthand functions
function recycler_layout:add(args) local pos = #self._private.widgets + 1; return self:add_at(pos, args) end
function recycler_layout:remove(w) local pos; for k,v in pairs(self._private.widgets) do if v == w then pos = k end end; return self:remove_at(pos, w) end
function recycler_layout:remove_by_args(args) return self:remove(self:get_by_args(args)) end
function recycler_layout:get_by_args(args) return self._private.by_args[args] end

--return create
return setmetatable(recycler_layout, {__call=function(_,...) return new_layout(...) end})

