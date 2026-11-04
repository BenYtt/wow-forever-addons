-- Manners -- the looks that have a picture on the options window's cards.
--
-- Written by tools/make_look_previews.py; run it again after a look, a texture or
-- the prompt's defaults change (tests/scenarios/theme-picker.lua says when).

local _, ns = ...
ns.Looks.previews = {
	arcane = true,
	forge = true,
	framed = true,
	glass = true,
	leather = true,
	letter = true,
	luxe = true,
	minimal = true,
	ribbon = true,
	toast = true,
}
-- Where each look draws the spell icon in its picture: the rectangle as fractions of
-- the 256 x 64 picture (l and t from its top left), the texcoord crop, and whether it
-- is round, with the mask the look cuts it with. The window lays the live icon there.
ns.Looks.previewIcon = {
	arcane = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	forge = { l = 0.10887, t = 0.25806, r = 0.22984, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	framed = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	glass = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	leather = { l = 0.08304, t = 0.25806, r = 0.20401, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	letter = { l = 0.15581, t = 0.31452, r = 0.24855, b = 0.68548, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Letter\\Letter_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	luxe = { l = 0.125, t = 0.25806, r = 0.24597, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	minimal = { l = 0.09677, t = 0.25806, r = 0.21774, b = 0.74194, round = false, crop = { 0.08, 0.92, 0.08, 0.92 } },
	ribbon = { l = 0.09073, t = 0.28226, r = 0.1996, b = 0.71774, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Ribbon\\Ribbon_Mask", crop = { 0.08, 0.92, 0.08, 0.92 } },
	toast = { l = 0.08554, t = 0.26152, r = 0.20478, b = 0.73848, round = true, mask = "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_IconMask", crop = { 0.08, 0.92, 0.08, 0.92 } },
}
-- Where each look writes its two lines in its picture, and how: the rectangle as
-- fractions of the picture, the justification, the size and the shadow's offsets as
-- fractions of its height, the colour, an outline, and the look's own face (`latin`:
-- drawn only on a client whose alphabet has it). The pictures carry no text: the
-- window writes the name and the reason there live, in the player's language. A
-- reason line the look sets in a tag of its own (`pill`) has the tag's edges, how far
-- it reaches past the words on either side, its caps' width of its height, and its
-- layers, each the look's own file as a three-slice in the look's colour: the window
-- draws it round the live words, as wide as they are.
ns.Looks.previewText = {
	arcane = {
		name = { l = 0.24597, t = 0.29032, r = 0.90323, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.24597, t = 0.54839, r = 0.90323, b = 0.70968, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.9, 0.7375, 0.395, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	forge = {
		name = { l = 0.27016, t = 0.29032, r = 0.90323, b = 0.5, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.27016, t = 0.53226, r = 0.90323, b = 0.69355, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.92, 0.768, 0.444, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	framed = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.74, 0.6695, 0.547, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	glass = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.74, 0.6695, 0.547, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
	leather = {
		name = { l = 0.2282, t = 0.29032, r = 0.82258, b = 0.51613, h = "LEFT", v = "MIDDLE", size = 0.22581, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.14, 0.07, 0.02, 0.95 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.2282, t = 0.54839, r = 0.82258, b = 0.70968, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 1, 0.9056, 0.728, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.14, 0.07, 0.02, 0.9 } } },
	},
	letter = {
		name = { l = 0.30645, t = 0.26029, r = 0.86331, b = 0.4861, h = "LEFT", v = "MIDDLE", size = 0.22581, color = { 0.25882, 0.23529, 0.21961, 1 }, shadow = { x = 0.00968, y = -0.00968, color = { 0.2, 0.105, 0.04, 0.4 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.30645, t = 0.54616, r = 0.86331, b = 0.72358, h = "LEFT", v = "MIDDLE", size = 0.17742, color = { 0.36494, 0.19616, 0.07755, 1 }, font = "Fonts\\MORPHEUS.TTF", latin = true },
	},
	luxe = {
		name = { l = 0.28629, t = 0.25, r = 0.90323, b = 0.45968, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.31653, t = 0.56935, r = 0.87298, b = 0.73065, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 1, 0.857, 0.545, 1 }, pill = { t = 0.52903, b = 0.77097, lead = 0.12097, tail = 0.12097, cap = 0.5, layers = { { file = "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_Pill", color = { 0.2, 0.156, 0.06, 0.9 } }, { file = "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_PillEdge", color = { 1, 0.78, 0.3, 0.5 } } } } },
	},
	minimal = {
		name = { l = 0.25806, t = 0.27419, r = 0.90323, b = 0.48387, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } }, flags = "OUTLINE" },
		reason = { l = 0.25806, t = 0.56452, r = 0.90323, b = 0.72581, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.909, 0.8385, 0.703, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 1 } }, flags = "OUTLINE" },
	},
	ribbon = {
		name = { l = 0.25, t = 0.2879, r = 0.86694, b = 0.51371, h = "LEFT", v = "MIDDLE", size = 0.22581, color = { 1, 0.91765, 0.67843, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 1 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
		reason = { l = 0.25, t = 0.53468, r = 0.86694, b = 0.69597, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 1, 0.88, 0.8, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0.16, 0.02, 0.03, 0.95 } }, font = "Fonts\\MORPHEUS.TTF", latin = true },
	},
	toast = {
		name = { l = 0.25806, t = 0.28968, r = 0.89516, b = 0.49935, h = "LEFT", v = "MIDDLE", size = 0.20968, color = { 1, 1, 1, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.9 } } },
		reason = { l = 0.25806, t = 0.5329, r = 0.89516, b = 0.69419, h = "LEFT", v = "MIDDLE", size = 0.16129, color = { 0.92, 0.768, 0.444, 1 }, shadow = { x = 0.01613, y = -0.01613, color = { 0, 0, 0, 0.8 } } },
	},
}
ns.Looks.previewHash = "a14662f8cdcc87212de599bcd26529be058fc94100b6c343e049963ee1e4fda5"
