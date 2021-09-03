local wibox = require 'wibox'
local rubato = require 'lib.rubato'
local awful = require 'awful'

--helper object to update values should hight ever change
local function create_point_maker()
	local self = {}
	self.height = 0

	local margin_x = 0.23
	local margin_y = 0.21
	local margin_yf = 0.15
	local width = 0.18

	--top slope, bottom slope, bottom y-int, top y-int
	local tm, bm, bb, tb

	--bottom left final, top left final, middle right, top middle final, bottom middle final
	local blf, tlf, mf, tmf, bmf

	function self:set_height(height)
		if height == self.height then return end --short circuit
		self.height = height

		blf = {x=margin_x*height, y=(1-margin_yf)*height}
		tlf = {x=margin_x*height, y=margin_yf*height}

		--middle, not slope
		mf = {x=(1-margin_x)*height, y=height/2}

		tm = (tlf.y-mf.y)/(tlf.x-mf.x)
		bm = (blf.y-mf.y)/(blf.x-mf.x)
		tb = tlf.y-tlf.x*tm
		bb = blf.y-blf.x*bm

		--middle, not slope
		tmf = {x=(margin_x+width)*height, y=tm*(margin_x+width)*height+tb}
		bmf = {x=(margin_x+width)*height, y=bm*(margin_x+width)*height+bb}

		--points look like this
		--p1-p2  p5-p6
		--|   |  |   |
		--p4_p3  p8_p7
		self.p1 = {x=margin_x*height, y=margin_y*height}
		self.p2 = {x=(margin_x+width)*height, y=margin_y*height}
		self.p3 = {x=(margin_x+width)*height, y=(1-margin_y)*height}
		self.p4 = {x=margin_x*height, y=(1-margin_y)*height}

		self.p5 = {x=(1-margin_x-width)*height, y=margin_y*height}
		self.p6 = {x=(1-margin_x)*height, y=margin_y*height}
		self.p7 = {x=(1-margin_x)*height, y=(1-margin_y)*height}
		self.p8 = {x=(1-margin_x-width)*height, y=(1-margin_y)*height}

		self.p1d = {y=self.p1.y-tlf.y}
		self.p2d = {y=self.p2.y-tmf.y}
		self.p3d = {y=self.p4.y-bmf.y}
		self.p4d = {y=self.p3.y-blf.y}

		self.p5d = {x=self.p5.x-tmf.x, y=self.p5.y-tmf.y} --x moves
		self.p6d = {y=self.p6.y-mf.y}
		self.p7d = {y=self.p7.y-mf.y}
		self.p8d = {x=self.p8.x-bmf.x, y=self.p7.y-bmf.y} --x moves

	end

	return self
end

--pm is point maker
local function get_draw(pos, pm)
	return function(_, _, cr, _, height)
		pm:set_height(height)

		cr:set_source_rgb(1.0, 1.0, 1.0)

		if pos == 1 then
			cr:move_to(pm.p1.x, pm.p1.y-pm.p1d.y)
			cr:line_to(pm.p6.x, pm.p6.y-pm.p6d.y)
			cr:line_to(pm.p4.x, pm.p4.y-pm.p4d.y)
			cr:fill()
			return
		end

		cr:move_to(pm.p1.x, pm.p1.y-pm.p1d.y*pos)
		cr:line_to(pm.p2.x, pm.p2.y-pm.p2d.y*pos)
		cr:line_to(pm.p3.x, pm.p3.y-pm.p3d.y*pos)
		cr:line_to(pm.p4.x, pm.p4.y-pm.p4d.y*pos)
		cr:fill()

		cr:move_to(pm.p5.x-pm.p5d.x*pos, pm.p5.y-pm.p5d.y*pos)
		cr:line_to(pm.p6.x, pm.p6.y-pm.p6d.y*pos)
		cr:line_to(pm.p7.x, pm.p7.y-pm.p7d.y*pos)
		cr:line_to(pm.p8.x-pm.p8d.x*pos, pm.p8.y-pm.p8d.y*pos)
		cr:fill()
	end
end

local function playpause(args)
	args = args or {}

	local point_maker = create_point_maker()
	local timed --early init of interpolator
	local target = 0

	local widget = wibox.widget {
		draw = get_draw(0, point_maker),
		fit = function(_, _, _, height) return height, height end,
		buttons = awful.button({}, 1, function()
			target = (target + 1) % 2
			timed.target = target
		end),
		widget = wibox.widget.make_base_widget,
		forced_width = args.forced_width,
		forced_height = args.forced_height,
	}

	timed = rubato.timed {
		duration = 0.125,
		intro = 0.2,
		prop_intro = true,
		subscribed = function(pos)
			widget.draw = get_draw(pos, point_maker)
			widget:emit_signal("widget::redraw_needed")
		end
	}

	return widget
end

return playpause
