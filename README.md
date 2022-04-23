# awesome-widgets

yep it's another awesomeWM thing of mine.

This is just a collection of widgets I made that some other people might
actually like because they're kinda useful. I will probably continue adding to
this as I make more widgets that other people might find useful. I'll also
outline what each of the widgets do.

#animated icons

currently available: hamburger and playpause

These are quite simply animated icons. You call `set(self, pos)` for some pos
from 0-1 and they'll animate to that position. Requires my animation library,
rubato. They're vaugely material-design-esque and they're also pure white with
much of their stuff hardcoded but at least you won't have to do all that manual
cairo animation yourself if you pick these up. At some point I'll make gifs for
these when I actually implement them in my new rice or if I find my old videos
of them.

#slider

This is an improved version of the awesome slider. The handle fades out
slightly when you hover over it, it has as subtle lag to its movement using
rubato, and probably other stuff that I've since forgot but I think I also made
better signals. It's probably worth using if the stock awesome slider didn't
cut it for whatever reason (I think I made it because it wouldn't tell me when
I was hovering over the handle) and while it's not super useful in it's current
state its a good foundation if you wanted to do more complicated
handle-hover-things. It's not particularly well documented but it's pretty
useful regardless

#coolwidget

Okay this one's actually really cool. It takes long widget-chains and turms
them into not-so-long singular widgets, effectively flattening your tables.
This is super nice when making more complex widgets as these tables tend to
stack up fast. Here's two declarations of the same widget, one using coolwidget
and one just using the normal awesome widget system:

default:
```lua
local w = wibox.widget {
	{
		{
			{
				{
					{
						{
							wibox.container.background(wibox.widget.textbox("first"), "#ff0000"),
							right = 5,
							widget = wibox.container.margin
						},
						{
							wibox.container.background(wibox.widget.textbox("second"), "#00ff00"),
							right = 5,
							widget = wibox.container.margin
						},
						wibox.container.background(wibox.widget.textbox("third"), "#0000ff")
					},
					layout = wibox.layout.align.horizontal
				},
				widget = wibox.container.align
			},
			valign = "center",
			widget = wibox.container.place
		},
		widget = wibox.container.margin
		margins = 5
	},
	bg = "#000000",
	widget = wibox.container.background
}
```

mine:
```lua
wibox.widget {
	wibox.container.background(wibox.widget.textbox("first"), "#ff0000"),
	wibox.container.background(wibox.widget.textbox("second"), "#00ff00"),
	wibox.container.background(wibox.widget.textbox("third"), "#0000ff"),
	spacing = 5,
	halign = "left",
	valign = "center",
	bg = "#000000",
	left = 25,
	layout = coolwidget.background.margin.place.align.horizontal.debug
},
```

what it looks like:

![cool widget](./images/example_coolwidget.png)

Only caviats are that you can't have multiple of the same container (since it
wouldn't know which one to apply the property to) and I've only set it up for a
couple container types. Luckily the latter is easily solved, since there's just
a `PROPERTIES` constant which can be easily modified by adding an entry where
the key is the container name and the values are the constants assigned to it.
Other than that you can basically just treat it like a single widget with all
of the properties it would normally have.

Align layouts are also a little different, where I added spacing (not real
spacing, I just did it with a margin layout) and more intuitive expand options
(`default`, `expfirst` where it only has two widgets and expands the first,
`explast`, the opposite of `expfirst`, and `neither`, where it expands neither and
pushes both to the ends of the space)


# TODO:
- [ ] add gifs
- [X] add that super duper ultra cool slider I made
- [ ] do more aniamted widgets
- [ ] make cooler
- [ ] make more customizable and just move all this stuff to bling
- [X] organize the project with folders and stuff
- [ ] use real spacing with `layout` instead of margin layouts for alignplus
