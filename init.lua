DIR = (...):match("(.-)[^%.]+$").."awesome-widgets."

return {
	hamburger = require(DIR.."hamburger"),
	playpause = require(DIR.."playpause")
}

