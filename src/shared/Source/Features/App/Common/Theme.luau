-- Shared look of the chunky game UI: fonts, palette and button color sets.
-- Every color set has a face (top -> bottom gradient), a darker lip under the face and an outline.
local Theme = {}

Theme.Font = Enum.Font.FredokaOne

-- Sizes in the components are authored in pixels for a 1080p screen and scaled by useUiScale.
Theme.ReferenceHeight = 1080

Theme.Text = Color3.fromRGB(255, 255, 255)
Theme.TextMuted = Color3.fromRGB(196, 202, 220)

Theme.Panel = {
	Face = Color3.fromRGB(38, 41, 52),
	FaceBottom = Color3.fromRGB(26, 28, 36),
	Inner = Color3.fromRGB(74, 80, 100),
	Outline = Color3.fromRGB(12, 13, 18),
}

Theme.Badge = {
	Face = Color3.fromRGB(235, 52, 52),
	Outline = Color3.fromRGB(110, 10, 10),
}

export type ColorSet = {
	Top: Color3,
	Bottom: Color3,
	Lip: Color3,
	Outline: Color3,
	TextStroke: Color3,
}

local function colorSet(top: Color3, bottom: Color3, lip: Color3, outline: Color3): ColorSet
	return { Top = top, Bottom = bottom, Lip = lip, Outline = outline, TextStroke = outline }
end

Theme.Colors = {
	Red = colorSet(Color3.fromRGB(255, 92, 72), Color3.fromRGB(214, 40, 40), Color3.fromRGB(140, 18, 24), Color3.fromRGB(70, 8, 10)),
	Blue = colorSet(Color3.fromRGB(70, 175, 255), Color3.fromRGB(28, 104, 230), Color3.fromRGB(16, 60, 150), Color3.fromRGB(8, 28, 80)),
	Purple = colorSet(Color3.fromRGB(176, 110, 255), Color3.fromRGB(118, 52, 222), Color3.fromRGB(72, 26, 150), Color3.fromRGB(36, 10, 80)),
	Gray = colorSet(Color3.fromRGB(172, 180, 196), Color3.fromRGB(104, 112, 130), Color3.fromRGB(62, 68, 82), Color3.fromRGB(26, 28, 36)),
	Gold = colorSet(Color3.fromRGB(255, 214, 64), Color3.fromRGB(245, 150, 20), Color3.fromRGB(176, 90, 6), Color3.fromRGB(90, 40, 0)),
	Green = colorSet(Color3.fromRGB(150, 236, 60), Color3.fromRGB(70, 180, 24), Color3.fromRGB(36, 116, 12), Color3.fromRGB(16, 58, 4)),
	Pink = colorSet(Color3.fromRGB(255, 120, 236), Color3.fromRGB(214, 50, 200), Color3.fromRGB(140, 20, 130), Color3.fromRGB(70, 6, 66)),
	Dark = colorSet(Color3.fromRGB(46, 50, 62), Color3.fromRGB(28, 30, 38), Color3.fromRGB(16, 17, 22), Color3.fromRGB(8, 8, 12)),
}

return Theme
