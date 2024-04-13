---@diagnostic disable-next-line: undefined-global
local timed = require(RUBATO_DIR.."timed")
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
	gtable.crush(res, args or {}, true)

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
	res.fadeamt = res.fadeamt or 1
	res.orientation = res.orientation or recycler_layout.DOWN

	res.scalex = res.scalex or 0
	res.scaley = res.scaley or 1

	res.inout_const = res.inout_const or function() return timed { duration = 0.2, intro = 0.3, prop_intro = true } end
	res.pos_const = res.pos_const or function() return timed { duration = 0.2, intro = 0.3, prop_intro = true } end

	res.debug = res.debug or fals

	return res
end

--layout superclass functions
function recycler_layout:_place_with_orientation(widget, x, y, w, h, max)
	if self.orientation == self.DOWN then return base.place_widget_at(widget, x, y, w, h)
	elseif self.orientation == self.UP then return base.place_widget_at(widget, x, max-y-h, w, h)
	elseif self.orientation == self.LEFT then return base.place_widget_at(widget, y, x, w, h)
	elseif self.orientation == self.RIGHT then return base.place_widget_at(widget, max-y-w, x, w, h)
	end
end
function recycler_layout:fit(context, width, height)
	--if orientation is down or up then use height of widgets
	--otherwise idk I haven't implemented it yet
	local wdata, widgets, between =
		self._private.wdata,
		self._private.widgets,
		self._private.between

	if self.debug then print(("called fit with w%i h%i"):format(width, height)) end

	local h
	local used = self.pady
	for i, widget in pairs(widgets) do
		_, h = base.fit_widget(self, context, widget, width, math.huge)
		used = used + h + (i ~= #widgets and self.spacing or self.pady)
		if self.debug then print(("#%i h%i sum%i widget %s"):format(i, h, used, widget)) end
	end

	for i, widget in pairs(between) do
		if wdata[widget].inout.pos == 0 then goto continue end

		_, h = base.fit_widget(self, context, widget, width, math.huge)
		used = used + h + (#widgets ~= 0 and self.spacing or self.pady)
		if self.debug then print(("#%i h%i sum%i widget %s"):format(i, h, used, widget)) end

	::continue:: end

	if self.debug then print(("fitting h%i"):format(math.min(used, height))) end

	return width, math.min(used, height)

end
function recycler_layout:layout(context, width, height)

	if self.debug then print(("laying out h%i"):format(height)) end

	local res = {}
	local wdata, widgets, unused, between =
		self._private.wdata,
		self._private.widgets,
		self._private.unused,
		self._private.between

	local data, prevdata, max
	local to_remove = {}

	--animopts are for overrides of animation options on fadein or fadeout if you wanna do that
	--bcause it'd be sooooo coooool this isn't sarcasm it'll look sick
	local base_animopts = {fadedist=self.fadedist, scalex=self.scalex, scaley=self.scaley, fadeamt=self.fadeamt}
	local animopts

	--get maximum height/width for not drawing out of bounds
	if self.orientation == self.DOWN or self.orientation == self.UP then max = height
	elseif self.orientation == self.LEFT or self.orientation == self.RIGHT then max = width
	end

	--draw currently visible widges
	for i, w in pairs(widgets) do

		data, prevdata = wdata[w], wdata[widgets[i-1]]
		data.w, data.h = base.fit_widget(self, context, w, width, math.huge)
		data.y = prevdata and prevdata.y + prevdata.h + self.spacing or self.pady

		--don't draw outside of bounds
		if data.y > max then break end;

		data.pos.target = data.y

		animopts = gtable.crush(base_animopts, data.fadeinopts)
		w.opacity = (1-animopts.fadeamt) + animopts.fadeamt * data.inout.pos
		table.insert(res, self:_place_with_orientation(
			w,
			self.padx - (1-data.inout.pos) * animopts.fadedist * animopts.scalex,
			data.pos.pos - (1-data.inout.pos) * animopts.fadedist * animopts.scaley,
			data.w,
			data.h,
			max))
	end

	for i, w in pairs(between) do

		data = wdata[w]
		data.w, data.h = base.fit_widget(self, context, w, width, math.huge)

		--don't draw outside of bounds
		if data.y > max then break end;


		--check for inout being zero and deletion is done here because I can't ensure
		--that inout's subscribed function gets called if it's immediately added then
		--deleted, resulting in an invisible widet.
		if data.inout.pos == 0 then table.insert(to_remove, i); w.opacity = 0; goto continue end


		animopts = gtable.crush(base_animopts, data.fadeoutopts)
		w.opacity = (1-animopts.fadeamt) + animopts.fadeamt * data.inout.pos
		table.insert(res, self:_place_with_orientation(
			w,
			self.padx - (1-data.inout.pos) * animopts.fadedist * animopts.scalex,
			data.pos.pos - (1-data.inout.pos) * animopts.fadedist * animopts.scaley,
			data.w,
			data.h,
			max))

		::continue::
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
	--if we already have a widget just use that
	if self.debug then print("widget created") end
	if #unused == 0 then w = self._private.const()
	else w = table.remove(unused, #unused) end

	--reset/create wdata
	wdata[w] = { w=0, h=0, y=0, inout = self.inout_const(), pos = self.pos_const() }
	wdata[w].inout:subscribe(function() self:emit_signal("widget::layout_changed") end)
	wdata[w].pos:subscribe(function() self:emit_signal("widget::layout_changed") end)


	--constructor must create a widget with this method
	--this passes in a single variable, ideally something unique
	--if not unique, pass in a table with the value or something
	--to make it identifiable
	w:populate(args)
	self._private.by_args[args] = w
	return w
end

--important functions
function recycler_layout:add_at(pos, args, opts)
	if self.debug then print("addat called") end
	local w = self:_request_widget(args)
	local data, widgets = self._private.wdata[w], self._private.widgets
	local prevdata = self._private.wdata[widgets[pos-1]]

	table.insert(widgets, pos, w)

	data.inout.target = 1
	data.pos.pos = prevdata and prevdata.y + prevdata.h + self.spacing or self.pady
	data.fadeinopts = opts or {}

	self:emit_signal("widget::layout_changed")
	print("after layout changed -------\n")
	return w, pos
end
function recycler_layout:remove_at(pos, w, opts)
	--if pos is nil very bad things happen
	if not pos then return end

	w = w or self._private.widgets[pos]
	local data, widgets, between = self._private.wdata[w], self._private.widgets, self._private.between

	data.inout.target = 0
	data.fadeoutopts = opts or {}

	table.insert(between, table.remove(widgets, pos))

	self:emit_signal("widget::layout_changed")
	return w, pos
end

--shorthand functions
function recycler_layout:add(args, opts) local pos = #self._private.widgets + 1; return self:add_at(pos, args, opts) end
function recycler_layout:remove(w, opts) local pos; for k,v in pairs(self._private.widgets) do if v == w then pos = k end end; return self:remove_at(pos, w, opts) end
function recycler_layout:remove_by_args(args, opts) return self:remove(self:get_by_args(args), opts) end
function recycler_layout:remove_by_id(args, opts) return self:remove(self:get_by_args(args), opts) end
function recycler_layout:get_by_args(args) return self._private.by_args[args] end
function recycler_layout:get_by_id(args) return self._private.by_args[args] end

--return create
return setmetatable(recycler_layout, {__call=function(_,...) return new_layout(...) end})

