if not AWESOME_WIDGETS_DIR then AWESOME_WIDGETS_DIR = (...):match("(.-)[^%.]+$").."awesome-widgets." end

return {
	hamburger = require(AWESOME_WIDGETS_DIR.."icons.hamburger"),
	playpause = require(AWESOME_WIDGETS_DIR.."icons.playpause"),
	slider = require(AWESOME_WIDGETS_DIR.."slider"),
	coolwidget = require(AWESOME_WIDGETS_DIR.."coolwidget"),
}

