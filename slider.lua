local wibox = require 'wibox'
local dpi = require('beautiful.xresources').apply_dpi
local naughty = require 'naughty'
local awful = require 'awful'
local beautiful = require 'beautiful'
local rubato = require 'lib.rubato'
local color = require 'lib.color'


local function set_x(x) return function(geo, args) return {x=x, y=(args.parent.height - geo.height)/2} end end

--- Create a slider widget
--
--@tparam[opt=color.color {hex='#000000'}] color color_bar color of non-active bar
--@tparam[opt=color.color {hex='#aaaaaa'}] color color_bar_active color of active bar
--@tparam[opt=color.color {hex='#ffffff'}] color color_handle color of handle
--@tparam[opt=dpi(8)] number height_bar height of bar
--@tparam[opt=dpi(15)] number height_handle height of handle
--@tparam[opt=dpi(10)] number lw_margins margins on left and right
local function create_slider(args)
	args = args or {}
	args.color_bar = args.color_bar or color.color {hex='#000000'}
	args.color_bar_active = args.color_bar_active or color.color {hex='#aaaaaa'}
	args.color_handle = args.color_handle or color.color {hex='#ffffff'}
	args.height_bar = args.height_bar or dpi(8)
	args.height_handle = args.height_handle or dpi(15)
	args.lw_margins = args.lw_margins or dpi(10)

	args.forced_height = args.forced_height or nil
	args.forced_width = args.forced_width or nil


	local dim = 0
	local value = 0
	local w = 0

	local bar_start, bar_end, bar_current, height2, hb2, pi2, value_min, value_max
	hb2 = args.height_bar / 2 --know this is correct
	bar_start = args.lw_margins+hb2
	bar_end = w-(bar_start)
	bar_current = value+args.height_bar
	pi2 = math.pi * 2
	value_min = args.lw_margins-hb2
	value_max = w-bar_start-hb2

	local bar = wibox.widget {
		fit = function(_, _, width, height) return width, height end,
		draw = function(_, _, cr, width, height)
			w = width --get the width whenever redrawing just in case
			bar_end = width-(bar_start) --update bar_end which depends on width
			height2 = height/2 --update height2 which depends on height
			value_max = width-bar_start-hb2
			bar_current = value+args.height_bar

			cr:set_line_width(args.height_bar)

			cr:set_source_rgb(args.color_bar.r/255, args.color_bar.g/255, args.color_bar.b/255)
			cr:arc(bar_end, height2, hb2, 0, pi2)
			cr:fill()

			cr:move_to(bar_start, height2)
			cr:line_to(bar_end, height2)
			cr:stroke()

			cr:set_source_rgb(args.color_bar_active.r/255, args.color_bar_active.g/255, args.color_bar_active.b/255)
			cr:arc(bar_start, height2, hb2, 0, pi2)
			cr:arc(bar_current, height2, hb2, 0, pi2)
			cr:fill()

			cr:move_to(bar_start, height2)
			cr:line_to(bar_current, height2)
			cr:stroke()
		end,
		forced_height = args.forced_height,
		forced_width = args.forced_width,
		widget = wibox.widget.make_base_widget
	}


	local handle = wibox.widget {
		fit = function(_, _, height) return height, height end,
		draw = function(_, _, cr, width, height)
			cr:set_source_rgb(args.color_handle.r/255*(1-dim), args.color_handle.g/255*(1-dim), args.color_handle.b/255*(1-dim))
			cr:arc(width / 2, height / 2, args.height_handle / 2, 0, pi2)
			cr:fill()
		end,
		forced_width = args.height_handle + dpi(5),
		forced_height = args.height_handle + dpi(5),
		point = {x=0, y=0}, --initialize point for layout
		widget = wibox.widget.make_base_widget
	}

	local layout = wibox.layout {
		handle,
		layout = wibox.layout.manual
	}

	local widget = wibox.widget {
		bar,
		layout,
		forced_height = args.forced_height,
		forced_width = args.forced_width,
		layout = wibox.layout.stack
	}

	local ended = false

	local timed = rubato.timed {
		intro = 0.1,
		prop_intro = true,
		duration = 0.075,
		pos = value_min,
		subscribed = function(pos, time, dt)
			value = pos
			layout:move(1, set_x(pos))
			bar:emit_signal("widget::redraw_needed")

			widget:emit_signal("slider::moved",
				(pos-value_min)/(value_max - value_min))

			--do started and ended signals
			if time == 0 then ended = false
			elseif time == 0.075 then
				ended = true
				widget:emit_signal("slider::ended")
			elseif ended then
				ended = false
				widget:emit_signal("slider::started")
			end


		end
	}

	local hover_timed = rubato.timed {
		intro = 0.2,
		duration = 0.2,
		prop_intro = true,
		subscribed = function(pos)
			dim = pos
			handle:emit_signal("widget::redraw_needed")
		end
	}

	--TODO: Make hover more robust
	handle:connect_signal("mouse::enter", function() hover_timed.target = 0.2 end)
	handle:connect_signal("mouse::leave", function() hover_timed.target = 0 end)

	local ipos, lpos

	layout:connect_signal("button::press", function(self, x, y, button, _, geo)
		if button ~= 1 then return end

		--reset initial position for later
		ipos = nil

		--initially move it to the target (only one call of max and min is prolly fine)
		timed.target = math.min(math.max(x - args.height_bar, bar_start), bar_end)

		mousegrabber.run(function(mouse)
			--stop (and emit signal) if you release mouse 1
			if not mouse.buttons[1] then
				widget:emit_signal("slider::really_ended")
				return false
			end

			--get initial position
			if not ipos then ipos = mouse.x end

			lpos = x + mouse.x - ipos - args.height_bar

			--short circuit if above or below
			if lpos < value_min then
				timed.target = value_min

			elseif lpos > value_max then
				timed.target = value_max

			else timed.target = lpos end

			return true
		end,"fleur")


	end)

	function widget:set(val)
		timed.target = (value_max - value_min) * val + value_min
	end

	function widget:hard_set(val)
		value = (value_max - value_min) * val + value_min
		timed.pos = value
		layout:move(1, set_x(value))
		bar:emit_signal("widget::redraw_needed")
	end


	return widget
end

return create_slider
