--[[
  Herogram card: the picture itself. A dark card with a gold frame, your
  hero as a live 3D model in a glow of your colour, name, level badge,
  professions, stat tiles and your proudest item.

  The card is built in UI units at the size of its format (Data.lua) and
  scaled up to fill the screen when the picture is taken.
]]

local _, ns = ...
local T = ns.T
local D = ns.Data

local C = {}
ns.Card = C

local MEDIA = "Interface\\AddOns\\Herogram\\Media\\"
local unpack = unpack or table.unpack

C.GOLD = { 0.96, 0.8, 0.46 }
C.INK = { 1, 0.96, 0.89 }
C.DIM = { 0.64, 0.6, 0.54 }
C.BG = { 0.075, 0.083, 0.115 }

C.ACCENT_KEYS = { "class", "faction", "gold", "arcane", "fel", "frost" }
C.ACCENT_NAMES = { class = "Class", faction = "Faction", gold = "Gold", arcane = "Arcane", fel = "Fel", frost = "Frost" }
C.COLORS = {
	gold = { 1, 0.74, 0.3 },
	arcane = { 0.66, 0.46, 1 },
	fel = { 0.48, 0.95, 0.28 },
	frost = { 0.36, 0.74, 1 },
	Horde = { 0.92, 0.22, 0.15 },
	Alliance = { 0.26, 0.5, 1 },
}

-- Fallback when the game has no class colour table.
C.CLASS = {
	WARRIOR = { 0.78, 0.61, 0.43 },
	PALADIN = { 0.96, 0.55, 0.73 },
	HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1, 0.96, 0.41 },
	PRIEST = { 1, 1, 1 },
	SHAMAN = { 0, 0.44, 0.87 },
	MAGE = { 0.25, 0.78, 0.92 },
	WARLOCK = { 0.53, 0.53, 0.93 },
	DRUID = { 1, 0.49, 0.04 },
}

function C.ClassColor(classFile)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile or ""]
	if c and type(c.r) == "number" then
		return { c.r, c.g, c.b }
	end
	return C.CLASS[classFile or ""] or C.COLORS.gold
end

function C.Accent(key, data)
	if key == "class" then
		return C.ClassColor(data and data.classFile)
	elseif key == "faction" then
		return C.COLORS[data and data.faction or ""] or C.COLORS.gold
	end
	return C.COLORS[key] or C.COLORS.gold
end

function C.Hex(c)
	return string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function Mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Upper case only for plain Latin text: string.upper breaks other letters.
function C.Caps(s)
	if type(s) ~= "string" or s:find("[\128-\255]") then
		return s
	end
	return s:upper()
end

------------------------------------------------------------------------
-- Frames: our own gold lines, or borders straight from the game. Which
-- game textures a client has is checked at run time; a missing one falls
-- back to ours.
------------------------------------------------------------------------

C.FRAMES = {
	{ key = "herogram", label = "Herogram" },
	{ key = "gold", label = "Gold", edge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", size = 32, inset = 6, plaque = { 1, 0.82, 0.4 } },
	{ key = "stone", label = "Stone", edge = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 32, inset = 6, plaque = { 0.75, 0.75, 0.75 } },
	{ key = "wood", label = "Wood", edge = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder", size = 64, inset = 4, plaque = { 0.85, 0.65, 0.4 } },
	{ key = "thin", label = "Thin", edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 16, inset = 8, color = { 0.96, 0.8, 0.46 }, plaque = { 0.96, 0.8, 0.46 } },
}
C.PLAQUE_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

function C.FrameStyle(key)
	for _, fr in ipairs(C.FRAMES) do
		if fr.key == key then
			return fr
		end
	end
	return C.FRAMES[1]
end

-- Is this texture file in the game? nil when the client cannot say.
function C.TextureExists(path)
	if type(path) ~= "string" then
		return false
	end
	if type(GetFileIDFromPath) == "function" then
		local id = D.Call(GetFileIDFromPath, path)
		return id ~= nil and id ~= 0, id
	end
	return nil
end

-- The frame styles this client can draw (ours always).
function C.AvailableFrames()
	local out = {}
	for _, fr in ipairs(C.FRAMES) do
		if not fr.edge or C.TextureExists(fr.edge) ~= false then
			out[#out + 1] = fr
		end
	end
	return out
end

------------------------------------------------------------------------
-- Fonts: a font family per size, so Cyrillic names still show in a
-- Latin client (and the other way round).
------------------------------------------------------------------------

local FILES = {
	title = { roman = "Fonts\\MORPHEUS.TTF", russian = "Fonts\\MORPHEUS_CYR.TTF" },
	body = { roman = "Fonts\\FRIZQT__.TTF", russian = "Fonts\\FRIZQT___CYR.TTF" },
}
local families = {}

local function Family(kind, size, flags)
	local key = kind .. ":" .. size .. ":" .. (flags or "")
	if families[key] ~= nil then
		return families[key]
	end
	local fam = false
	if CreateFontFamily then
		local files = FILES[kind]
		local fl = flags or ""
		local name = ("HerogramFont_" .. kind .. "_" .. size .. "_" .. fl):gsub("[^%w_]", "")
		local ok, obj = pcall(CreateFontFamily, name, {
			{ alphabet = "roman", file = files.roman, height = size, flags = fl },
			{ alphabet = "korean", file = "Fonts\\2002.TTF", height = size, flags = fl },
			{ alphabet = "simplifiedchinese", file = "Fonts\\ARKai_T.ttf", height = size, flags = fl },
			{ alphabet = "traditionalchinese", file = "Fonts\\blei00d.TTF", height = size, flags = fl },
			{ alphabet = "russian", file = files.russian, height = size, flags = fl },
		})
		if ok and obj then
			fam = obj
		end
	end
	families[key] = fam
	return fam
end

function C.Font(fs, kind, size, flags)
	size = math.max(6, math.floor(size + 0.5))
	local fam = Family(kind, size, flags)
	if fam then
		fs:SetFontObject(fam)
		return
	end
	local file = FILES[kind].roman
	if not fs:SetFont(file, size, flags or "") then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags or "")
	end
end

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------

local function Gradient(tex, orient, from, to)
	-- from = bottom / left, to = top / right; {r, g, b, a}
	if tex.SetGradient and CreateColor then
		local ok = pcall(tex.SetGradient, tex, orient, CreateColor(from[1], from[2], from[3], from[4]), CreateColor(to[1], to[2], to[3], to[4]))
		if ok then
			return
		end
	end
	if tex.SetGradientAlpha then
		pcall(tex.SetGradientAlpha, tex, orient, from[1], from[2], from[3], from[4], to[1], to[2], to[3], to[4])
	end
end
C.Gradient = Gradient

local function Pool(card, kind)
	local p = card.pools[kind]
	p.used = p.used + 1
	local o = p.list[p.used]
	if not o then
		if kind == "font" then
			o = card.top:CreateFontString(nil, "OVERLAY")
		else
			o = card.top:CreateTexture(nil, "ARTWORK")
		end
		p.list[p.used] = o
	end
	o:ClearAllPoints()
	o:SetAlpha(1)
	o:Show()
	if kind == "font" then
		o:SetWordWrap(false)
		o:SetJustifyH("LEFT")
		o:SetJustifyV("TOP")
		o:SetShadowOffset(0, 0)
		o:SetWidth(0)
	else
		o:SetTexCoord(0, 1, 0, 1)
		o:SetVertexColor(1, 1, 1, 1)
		o:SetBlendMode("BLEND")
		o:SetDrawLayer("ARTWORK", 0)
	end
	return o
end

-- A line of text at (x, y) from the card's top left.
-- anchor: "LEFT" (x is the left edge), "CENTER" (x is the middle),
-- "RIGHT" (x is the right edge). maxW shrinks the font until it fits.
local function Text(card, s, kind, size, color, x, y, anchor, maxW, alpha)
	local fs = Pool(card, "font")
	C.Font(fs, kind, size)
	fs:SetText(s or "")
	if maxW then
		local sz = size
		while sz > 7 and (fs:GetStringWidth() or 0) > maxW do
			sz = sz - 1
			C.Font(fs, kind, sz)
		end
	end
	fs:SetTextColor(color[1], color[2], color[3], alpha or 1)
	anchor = anchor or "LEFT"
	local point = anchor == "CENTER" and "TOP" or anchor == "RIGHT" and "TOPRIGHT" or "TOPLEFT"
	fs:SetJustifyH(anchor)
	fs:SetPoint(point, card, "TOPLEFT", x, -y)
	return fs
end
C.Text = Text

local function Tex(card, x, y, w, h, color, alpha, file, layer, sub)
	local t = Pool(card, "tex")
	if file then
		t:SetTexture(file)
		t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	else
		t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	end
	t:SetDrawLayer(layer or "ARTWORK", sub or 0)
	t:SetSize(w, h)
	t:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	return t
end
C.Tex = Tex

local function Width(fs)
	return fs and fs:GetStringWidth() or 0
end

-- A horizontal line that fades out at one or both ends.
local function Line(card, x, y, w, color, alpha, fade)
	if w <= 1 then
		return
	end
	local a = alpha or 0.4
	if fade == "both" then
		local l = Tex(card, x, y, w / 2, 1, { 1, 1, 1 }, 1)
		Gradient(l, "HORIZONTAL", { color[1], color[2], color[3], 0 }, { color[1], color[2], color[3], a })
		local r = Tex(card, x + w / 2, y, w / 2, 1, { 1, 1, 1 }, 1)
		Gradient(r, "HORIZONTAL", { color[1], color[2], color[3], a }, { color[1], color[2], color[3], 0 })
	else
		local t = Tex(card, x, y, w, 1, { 1, 1, 1 }, 1)
		local from, to = { color[1], color[2], color[3], a }, { color[1], color[2], color[3], 0 }
		if fade == "left" then
			from, to = to, from
		end
		Gradient(t, "HORIZONTAL", from, to)
	end
end

-- Small capitals title with a line running to the right edge.
local function Section(card, label, x, y, w)
	local fs = Text(card, C.Caps(label), "body", 9, C.GOLD, x, y, "LEFT", w, 0.9)
	Line(card, x + Width(fs) + 8, y + 5, w - Width(fs) - 8, C.GOLD, 0.35, "right")
	return 20
end

------------------------------------------------------------------------
-- The frame
------------------------------------------------------------------------

function C.Create()
	if C.frame then
		return C.frame
	end
	local f = CreateFrame("Frame", "HerogramCard", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetSize(450, 800)
	f:SetPoint("CENTER")
	f:Hide()
	f.pools = { font = { list = {}, used = 0 }, tex = { list = {}, used = 0 }, edge = { list = {}, used = 0 } }

	-- black backdrop over the whole screen while the picture is taken
	f.shot = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.shot:SetColorTexture(0, 0, 0, 1)
	f.shot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
	f.shot:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 100, -100)
	f.shot:Hide()

	f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	f.bg:SetAllPoints()
	f.tint = f:CreateTexture(nil, "BACKGROUND", nil, -6)
	f.tint:SetAllPoints()
	f.tint:SetColorTexture(1, 1, 1, 1)
	f.grain = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	f.grain:SetAllPoints()
	f.grain:SetTexture(MEDIA .. "grain.blp", "REPEAT", "REPEAT")
	if f.grain.SetHorizTile then
		f.grain:SetHorizTile(true)
		f.grain:SetVertTile(true)
	end
	f.grain:SetBlendMode("ADD")

	f.glow = f:CreateTexture(nil, "BORDER", nil, 1)
	f.glow:SetTexture(MEDIA .. "glow.blp")
	f.glow:SetBlendMode("ADD")
	f.core = f:CreateTexture(nil, "BORDER", nil, 2)
	f.core:SetTexture(MEDIA .. "glow.blp")
	f.core:SetBlendMode("ADD")
	f.shadow = f:CreateTexture(nil, "BORDER", nil, 3)
	f.shadow:SetTexture(MEDIA .. "glow.blp")
	f.vignette = f:CreateTexture(nil, "BORDER", nil, 5)
	f.vignette:SetTexture(MEDIA .. "vignette.blp")
	f.vignette:SetAllPoints()

	f.model = CreateFrame("PlayerModel", "HerogramCardModel", f)
	f.model:SetFrameLevel(f:GetFrameLevel() + 2)

	f.top = CreateFrame("Frame", nil, f)
	f.top:SetAllPoints()
	f.top:SetFrameLevel(f:GetFrameLevel() + 6)

	-- a border from the game, when one is chosen
	f.border = CreateFrame("Frame", nil, f.top, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.border:SetFrameLevel(f.top:GetFrameLevel() + 1)
	f.border:Hide()

	-- the best item row takes an item dragged from your bags
	f.drop = CreateFrame("Button", nil, f.top)
	f.drop:SetFrameLevel(f.top:GetFrameLevel() + 2)
	f.drop:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.drop.glow = f.drop:CreateTexture(nil, "BACKGROUND")
	f.drop.glow:SetAllPoints()
	f.drop.glow:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.12)
	f.drop.glow:Hide()
	f.drop:SetScript("OnReceiveDrag", function()
		if C.onItemDrop then
			C.onItemDrop()
		end
	end)
	f.drop:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if C.onItemClear then
				C.onItemClear()
			end
		elseif C.onItemDrop then
			C.onItemDrop()
		end
	end)
	f.drop:SetScript("OnEnter", function(self)
		if C.shooting then
			return
		end
		self.glow:Show()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(T("Drag an item here to show it instead"))
		GameTooltip:AddLine(T("Right-click: back to automatic"), 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	f.drop:SetScript("OnLeave", function(self)
		self.glow:Hide()
		GameTooltip:Hide()
	end)
	f.drop:Hide()

	C.frame = f
	C.HookModel(f.model)
	return f
end

------------------------------------------------------------------------
-- The hero
------------------------------------------------------------------------

C.state = nil -- the model settings table being edited (from the saved settings)

function C.ModelDefaults()
	return { facing = -0.45, zoom = 1, x = 0, z = 0, anim = 0, paused = false }
end

-- The hero's region as view insets of a model frame that covers the card
-- (less `border` on each side): left, right, top, bottom.
C.MODEL_BORDER = 4

function C.HeroInsets(W, H, m, border)
	border = border or 0
	return m[1] - border, W - border - (m[1] + m[3]), m[2] - border, H - border - (m[2] + m[4])
end

-- Is a point (card units, from the top left) on the hero's region?
function C.InHero(x, y, m)
	return m and x >= m[1] and x <= m[1] + m[3] and y >= m[2] and y <= m[2] + m[4] or false
end

-- The cursor in card units from the card's top left.
function C.CursorOnCard(f)
	local x, y = GetCursorPosition()
	local s = f:GetEffectiveScale()
	local left, top = f:GetLeft(), f:GetTop()
	if not (x and y and s and s > 0 and left and top) then
		return nil
	end
	return x / s - left, top - y / s
end

function C.ApplyModel()
	local f = C.frame
	local m = C.state
	if not (f and m) then
		return
	end
	local mo = f.model
	pcall(mo.SetPortraitZoom, mo, 0)
	if f.insets and mo.SetViewInsets then
		pcall(mo.SetViewInsets, mo, unpack(f.insets))
	end
	-- the format's own distance (the hero smaller where the card is short)
	-- times the zoom you set with the wheel
	pcall(mo.SetCamDistanceScale, mo, (m.zoom or 1) * (f.baseZoom or 1))
	pcall(mo.SetPosition, mo, 0, m.x or 0, m.z or 0)
	pcall(mo.SetFacing, mo, m.facing or 0)
	if mo.animID ~= m.anim then
		mo.animID = m.anim
		pcall(mo.SetAnimation, mo, m.anim or 0)
	end
	if mo.SetPaused then
		pcall(mo.SetPaused, mo, m.paused and true or false)
	end
end

function C.LoadModel()
	local mo = C.frame and C.frame.model
	if not mo then
		return
	end
	mo.animID = nil
	pcall(mo.SetUnit, mo, "player")
	C.ApplyModel()
end

function C.HookModel(mo)
	mo:EnableMouse(true)
	if mo.EnableMouseWheel then
		mo:EnableMouseWheel(true)
	end
	pcall(mo.SetScript, mo, "OnModelLoaded", function()
		mo.animID = nil
		C.ApplyModel()
	end)
	local function Drag(self)
		local m = C.state
		if not (m and self.button) then
			return
		end
		local x, y = GetCursorPosition()
		local s = self:GetEffectiveScale()
		if not (x and s and s > 0) then
			return
		end
		local dx, dy = (x - self.cx) / s, (y - self.cy) / s
		self.cx, self.cy = x, y
		if self.button == "LeftButton" then
			m.facing = (m.facing or 0) + dx * 0.014
		else
			local k = 0.006 * (m.zoom or 1)
			m.x = math.max(-2, math.min(2, (m.x or 0) + dx * k))
			m.z = math.max(-2, math.min(2, (m.z or 0) + dy * k))
		end
		C.ApplyModel()
	end
	mo:SetScript("OnMouseDown", function(self, button)
		-- the model covers the whole card: only the hero's own region turns it
		local f = C.frame
		if f and f.insets then
			local cx, cy = C.CursorOnCard(f)
			if not (cx and C.InHero(cx, cy, f.hero)) then
				return
			end
		end
		self.button = button
		self.cx, self.cy = GetCursorPosition()
		self:SetScript("OnUpdate", Drag)
	end)
	mo:SetScript("OnMouseUp", function(self)
		self.button = nil
		self:SetScript("OnUpdate", nil)
	end)
	mo:SetScript("OnMouseWheel", function(_, delta)
		local f = C.frame
		if f and f.insets then
			local cx, cy = C.CursorOnCard(f)
			if not (cx and C.InHero(cx, cy, f.hero)) then
				return
			end
		end
		local m = C.state
		if m then
			m.zoom = math.max(0.45, math.min(2.2, (m.zoom or 1) - delta * 0.08))
			C.ApplyModel()
		end
	end)
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------

local function Frame(card, w, h)
	local g = C.GOLD
	local cs, ci = 48, 9 -- corner size and inset
	local edge = ci + cs * 3 / 64 -- where the corner's outer line sits
	local th = 1.2
	-- straight lines between the corners
	Tex(card, ci + cs, edge - th / 2, w - 2 * (ci + cs), th, g, 0.55)
	Tex(card, ci + cs, h - edge - th / 2, w - 2 * (ci + cs), th, g, 0.55)
	Tex(card, edge - th / 2, ci + cs, th, h - 2 * (ci + cs), g, 0.55)
	Tex(card, w - edge - th / 2, ci + cs, th, h - 2 * (ci + cs), g, 0.55)
	local corners = {
		{ ci, ci, 0, 1, 0, 1 },
		{ w - ci - cs, ci, 1, 0, 0, 1 },
		{ ci, h - ci - cs, 0, 1, 1, 0 },
		{ w - ci - cs, h - ci - cs, 1, 0, 1, 0 },
	}
	for _, c in ipairs(corners) do
		local t = Tex(card, c[1], c[2], cs, cs, g, 0.95, MEDIA .. "corner.blp", "OVERLAY", 1)
		t:SetTexCoord(c[3], c[4], c[5], c[6])
	end
	-- diamonds in the middle of the top and bottom lines
	Tex(card, w / 2 - 7, edge - 7, 14, 14, g, 0.95, MEDIA .. "diamond.blp", "OVERLAY", 2)
	Tex(card, w / 2 - 7, h - edge - 7, 14, 14, g, 0.95, MEDIA .. "diamond.blp", "OVERLAY", 2)
end

local function Header(card, data, opts, L, accent)
	local x, y, w = L.header[1], L.header[2], L.header[3]
	local center = L.align == "CENTER"
	local ax = center and x + w / 2 or x
	local anchor = center and "CENTER" or "LEFT"
	local show = opts.show or {}
	local cy = y
	-- the level, in gold small capitals, where a realm line would be
	Text(card, C.LevelLine(data), "body", 10, C.GOLD, ax, cy, anchor, w, 0.95)
	cy = cy + 17
	local nameSize = center and 50 or 44
	local name = Text(card, data.name, "title", nameSize, C.INK, ax, cy, anchor, w)
	name:SetShadowColor(0, 0, 0, 0.85)
	name:SetShadowOffset(1, -2)
	local _, used = name:GetFont()
	cy = cy + (used or nameSize) * 1.08
	local cc = C.ClassColor(data.classFile)
	local sub = (data.race and (data.race .. " ") or "") .. "|c" .. C.Hex(cc) .. (data.class or "") .. "|r"
	Text(card, sub, "body", 15, C.INK, ax, cy, anchor, w, 0.92)
	cy = cy + 22
	if show.guild ~= false and data.guild then
		Text(card, "<" .. data.guild .. ">", "body", 12, C.DIM, ax, cy, anchor, w)
		cy = cy + 19
	end
	local headline = opts.headline
	if type(headline) == "string" and headline:find("%S") then
		cy = cy + 4
		local fs = Text(card, C.Caps(headline), "body", 12, accent, ax, cy, anchor, w - 60)
		fs:SetShadowColor(0, 0, 0, 0.8)
		fs:SetShadowOffset(1, -1)
		local tw = Width(fs)
		if center then
			local side = math.min(70, (w - tw) / 2 - 16)
			Line(card, ax - tw / 2 - 12 - side, cy + 6, side, accent, 0.8, "left")
			Line(card, ax + tw / 2 + 12, cy + 6, side, accent, 0.8, "right")
		else
			Tex(card, x, cy - 1, 12, 12, accent, 1, MEDIA .. "diamond.blp", "OVERLAY", 2)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", card, "TOPLEFT", x + 18, -cy)
			Line(card, x + 18 + tw + 10, cy + 6, math.min(90, w - tw - 28), accent, 0.8, "right")
		end
		cy = cy + 18
	end
	return cy
end

-- "LEVEL 34  ·  25%", or "LEVEL 60" at the cap
function C.LevelLine(data)
	local line = C.Caps(T("Level")) .. " " .. tostring(data.level or 1)
	local pct = D.XPPercent(data)
	if pct then
		line = line .. "  ·  " .. pct .. "%"
	end
	return line
end

-- The professions to show, in order, without the ones switched off.
function C.ProfList(data, hidden)
	local list = {}
	for _, p in ipairs(data.profs or {}) do
		if not (hidden and hidden[p.key]) then
			list[#list + 1] = p
		end
	end
	return list
end

local function Professions(card, list, b, d)
	local accent = card.accent
	local x, y, w = b.x, b.y, b.w
	local rowH = d.row
	local is = rowH - 5
	local fsz = rowH >= 27 and 12 or 11
	local light = Mix(accent, { 1, 1, 1 }, 0.35)
	for i = 1, b.rows do
		local p = list[i]
		local ry = y + (i - 1) * rowH
		Tex(card, x, ry, is, is, C.GOLD, 0.75)
		local icon = Tex(card, x + 1, ry + 1, is - 2, is - 2, { 1, 1, 1 }, 1, nil, "ARTWORK", 2)
		local tex = p.spell and (D.Call(GetSpellTexture, p.spell) or (C_Spell and D.Call(C_Spell.GetSpellTexture, p.spell)))
		icon:SetTexture(tex or p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local tx = x + is + 8
		local value = Text(card, tostring(p.rank) .. "|cff" .. C.Hex(C.DIM):sub(3) .. " / " .. D.SKILL_CAP .. "|r", "body", fsz, C.INK, x + w, ry + 1, "RIGHT")
		local name = Text(card, p.name, "body", fsz, C.INK, tx, ry + 1, "LEFT", w - (tx - x) - Width(value) - 8)
		if p.tier then
			local room = w - (tx - x) - Width(name) - Width(value) - 16
			local tier = Text(card, p.tier, "body", 9, C.DIM, tx + Width(name) + 6, ry + 3, "LEFT")
			if Width(tier) > room then
				tier:Hide()
			end
		end
		local bw = w - (tx - x)
		local by = ry + math.max(15, rowH - 12)
		Tex(card, tx, by, bw, 4, { 1, 1, 1 }, 0.08)
		local fill = Tex(card, tx, by, math.max(2, bw * math.min(1, p.rank / D.SKILL_CAP)), 4, { 1, 1, 1 }, 1, nil, "ARTWORK", 3)
		Gradient(fill, "HORIZONTAL", { accent[1] * 0.7, accent[2] * 0.7, accent[3] * 0.7, 1 }, { light[1], light[2], light[3], 1 })
	end
end

local function Stats(card, tiles, b, d)
	local cols, gap, th = b.cols, d.gap, d.tile
	local tw = (b.w - gap * (cols - 1)) / cols
	for i = 1, b.count do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		C.Plaque(card, tiles[i], b.x + col * (tw + gap), b.y + row * (th + gap), tw, th)
	end
end

function C.ValueFont(value)
	local plain = tostring(value or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if plain:find("%a") or plain:find("[\128-\255]") then
		return "body", 16
	end
	return "title", 20
end

-- A small game border around a plaque (pooled frames: a border is a frame).
local function Edge(card, x, y, w, h, color)
	local p = card.pools.edge
	p.used = p.used + 1
	local e = p.list[p.used]
	if not e then
		e = CreateFrame("Frame", nil, card.top, BackdropTemplateMixin and "BackdropTemplate" or nil)
		e:SetFrameLevel(card.top:GetFrameLevel() + 1)
		if e.SetBackdrop then
			e:SetBackdrop({ edgeFile = C.PLAQUE_EDGE, edgeSize = 12 })
		end
		p.list[p.used] = e
	end
	e:ClearAllPoints()
	e:SetPoint("TOPLEFT", card, "TOPLEFT", x - 3, -(y - 3))
	e:SetSize(w + 6, h + 6)
	if e.SetBackdropBorderColor then
		e:SetBackdropBorderColor(color[1], color[2], color[3], 1)
	end
	e:Show()
	return e
end

-- A stat as a Warcraft plaque: dark stone, a thin gold frame with small
-- corner ornaments (or a small game border), a small-caps label and the value.
function C.Plaque(card, t, tx, ty, tw, th)
	local g = C.GOLD
	local stone = Tex(card, tx, ty, tw, th, { 1, 1, 1 }, 1, nil, "ARTWORK", 0)
	Gradient(stone, "VERTICAL", { 0.045, 0.042, 0.04, 0.96 }, { 0.15, 0.135, 0.115, 0.96 })
	-- a soft light along the top edge
	local sheen = Tex(card, tx, ty, tw, th * 0.45, { 1, 1, 1 }, 1, nil, "ARTWORK", 1)
	Gradient(sheen, "VERTICAL", { 1, 0.86, 0.6, 0 }, { 1, 0.86, 0.6, 0.07 })
	if card.style and card.style.edge then
		Edge(card, tx, ty, tw, th, card.style.plaque or g)
		C.PlaqueText(card, t, tx, ty, tw, th)
		return
	end
	-- frame
	Tex(card, tx, ty, tw, 1, g, 0.55, nil, "ARTWORK", 2)
	Tex(card, tx, ty + th - 1, tw, 1, g, 0.55, nil, "ARTWORK", 2)
	Tex(card, tx, ty, 1, th, g, 0.55, nil, "ARTWORK", 2)
	Tex(card, tx + tw - 1, ty, 1, th, g, 0.55, nil, "ARTWORK", 2)
	local cs = 13
	local corners = {
		{ tx - 2, ty - 2, 0, 1, 0, 1 },
		{ tx + tw - cs + 2, ty - 2, 1, 0, 0, 1 },
		{ tx - 2, ty + th - cs + 2, 0, 1, 1, 0 },
		{ tx + tw - cs + 2, ty + th - cs + 2, 1, 0, 1, 0 },
	}
	for _, c in ipairs(corners) do
		local o = Tex(card, c[1], c[2], cs, cs, g, 1, MEDIA .. "corner.blp", "ARTWORK", 3)
		o:SetTexCoord(c[3], c[4], c[5], c[6])
	end
	C.PlaqueText(card, t, tx, ty, tw, th)
end

function C.PlaqueText(card, t, tx, ty, tw, th)
	local g = C.GOLD
	local lx = tx + 12
	local lw = tw - 18
	Text(card, C.Caps(t.label), "body", 7.5, g, lx, ty + 8, "LEFT", lw, 0.9)
	-- the Warcraft font draws lower-case letters as odd capitals (3d -> 3∂),
	-- so values with letters use the plain font
	local kind, size = C.ValueFont(t.value)
	local v = Text(card, t.value, kind, size, C.INK, lx, ty + (kind == "title" and 18 or 20), "LEFT", lw)
	v:SetShadowColor(0, 0, 0, 0.8)
	v:SetShadowOffset(1, -1)
	if t.sub and th >= 50 then
		Text(card, t.sub, "body", 8, C.DIM, lx, ty + th - 15, "LEFT", lw)
	end
end

local function QualityColor(q)
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
		local c = ITEM_QUALITY_COLORS[q]
		return { c.r, c.g, c.b }
	elseif C_Item and C_Item.GetItemQualityColor then
		local r, g, b = D.Call(C_Item.GetItemQualityColor, q)
		if r then
			return { r, g, b }
		end
	end
	return { 1, 1, 1 }
end

local function Item(card, it, b, d)
	local x, y, w = b.x, b.y, b.w
	Section(card, T("Best item"), x, y, w)
	local q = it.quality or 1
	if q < 0 then
		q = 1
	end
	local qc = QualityColor(q)
	local is = d.item - 24
	local iy = y + 22
	card.itemArea = { x - 4, iy - 4, w + 8, is + 8 }
	Tex(card, x, iy, is, is, qc, 0.9)
	local icon = Tex(card, x + 1, iy + 1, is - 2, is - 2, { 1, 1, 1 }, 1, nil, "ARTWORK", 2)
	icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Text(card, it.name or "?", "body", 13, qc, x + is + 10, iy + 2, "LEFT", w - is - 10)
	if it.ilvl then
		Text(card, string.format(T("Item level %d"), it.ilvl), "body", 9, C.DIM, x + is + 10, iy + is - 13, "LEFT", w - is - 10)
	end
end

function C.PlaceDrop(f)
	local a = f.itemArea
	if not a then
		f.drop:Hide()
		return
	end
	f.drop:ClearAllPoints()
	f.drop:SetPoint("TOPLEFT", f, "TOPLEFT", a[1], -a[2])
	f.drop:SetSize(a[3], a[4])
	f.drop.glow:Hide()
	f.drop:Show()
end

local function Footer(card, L)
	local x, y, w = L.footer[1], L.footer[2], L.footer[3]
	local when
	if date then
		local loc = GetLocale and GetLocale() or "enUS"
		when = loc == "ruRU" and date("%d.%m.%Y") or date("%d %b %Y")
	end
	if when then
		Text(card, when, "body", 9, C.DIM, x, y, "LEFT", nil, 0.75)
	end
	local mark = Text(card, T("made with Herogram"), "body", 9, C.DIM, x + w, y, "RIGHT", nil, 0.6)
	Tex(card, x + w - Width(mark) - 15, y + 1, 9, 9, C.GOLD, 0.6, MEDIA .. "diamond.blp", "OVERLAY", 1)
end

-- Draws the whole card. opts: format, accent, show, headline, model,
-- hideProfs (profession key -> true to leave it off).
function C.Render(data, opts)
	local f = C.Create()
	local fmt = D.Format(opts.format)
	local L = D.Layout(fmt.key)
	local W, H = fmt.w, fmt.h
	f:SetSize(W, H)
	f.pools.font.used, f.pools.tex.used, f.pools.edge.used = 0, 0, 0
	f.itemArea = nil
	local accent = C.Accent(opts.accent, data)
	f.accent = accent

	f.bg:SetColorTexture(C.BG[1], C.BG[2], C.BG[3], 1)
	Gradient(f.tint, "VERTICAL", { accent[1], accent[2], accent[3], 0 }, { accent[1], accent[2], accent[3], 0.16 })
	f.grain:SetTexCoord(0, W / 96, 0, H / 96)
	f.grain:SetVertexColor(1, 1, 1, 0.035)

	-- the frame: a game border if chosen and present, else ours
	local style = C.FrameStyle(opts.frame)
	if style.edge and C.TextureExists(style.edge) == false then
		style = C.FRAMES[1]
	end
	f.style = style
	if style.edge and f.border.SetBackdrop then
		f.border:ClearAllPoints()
		f.border:SetPoint("TOPLEFT", f, "TOPLEFT", style.inset, -style.inset)
		f.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -style.inset, style.inset)
		f.border:SetBackdrop({ edgeFile = style.edge, edgeSize = style.size })
		local c = style.color or { 1, 1, 1 }
		f.border:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		f.border:Show()
	else
		f.border:Hide()
		f.style = C.FRAMES[1]
		Frame(f, W, H)
	end
	local headerBottom = Header(f, data, opts, L, accent)

	-- what is switched on, and where it all goes
	local show = opts.show or {}
	local profs = show.profs ~= false and C.ProfList(data, opts.hideProfs) or {}
	local tiles = D.Stats(data, show)
	local item = show.item ~= false and data.best or nil
	local plan = D.PlanCard(fmt.key, { profs = #profs, tiles = #tiles, item = item ~= nil }, headerBottom)
	f.plan = plan
	local left = {}
	for i = #profs - plan.dropped.profs + 1, #profs do
		left[#left + 1] = { key = profs[i].key, label = profs[i].name, prof = true }
	end
	for i = #tiles - plan.dropped.tiles + 1, #tiles do
		left[#left + 1] = { key = tiles[i].key, label = tiles[i].label }
	end
	if plan.dropped.item then
		left[#left + 1] = { key = "item", label = T("Best item") }
	end
	f.dropped = left

	local m = plan.model
	local mx, my = m[1] + m[3] / 2, m[2] + m[4] * 0.46
	local g = math.max(m[3], m[4]) * 1.15
	f.glow:ClearAllPoints()
	f.glow:SetSize(g, g)
	f.glow:SetPoint("CENTER", f, "TOPLEFT", mx, -my)
	f.glow:SetVertexColor(accent[1], accent[2], accent[3], 0.6)
	local c = Mix(accent, { 1, 1, 1 }, 0.45)
	f.core:ClearAllPoints()
	f.core:SetSize(g * 0.42, g * 0.42)
	f.core:SetPoint("CENTER", f, "TOPLEFT", mx, -my)
	f.core:SetVertexColor(c[1], c[2], c[3], 0.22)
	f.shadow:ClearAllPoints()
	f.shadow:SetSize(m[3] * 0.62, 34)
	f.shadow:SetPoint("CENTER", f, "TOPLEFT", mx, -(m[2] + m[4] - 24))
	f.shadow:SetVertexColor(0, 0, 0, 0.75)

	f.baseZoom = D.HeroZoom(fmt.key)
	-- The model frame covers the whole card, so no frame edge inside the
	-- card can cut the hero; the camera puts the hero in its region
	-- (view insets). Clients without view insets get the region itself.
	f.hero = m
	f.model:ClearAllPoints()
	if f.model.SetViewInsets then
		local b = C.MODEL_BORDER
		f.model:SetPoint("TOPLEFT", f, "TOPLEFT", b, -b)
		f.model:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -b, b)
		f.insets = { C.HeroInsets(W, H, m, b) }
	else
		f.model:SetPoint("TOPLEFT", f, "TOPLEFT", m[1], -m[2])
		f.model:SetSize(m[3], m[4])
		f.insets = nil
	end

	if plan.profs then
		Professions(f, profs, plan.profs, plan.d)
	end
	if plan.tiles then
		Stats(f, tiles, plan.tiles, plan.d)
	end
	if plan.item then
		Item(f, item, plan.item, plan.d)
	end
	Footer(f, L)

	C.PlaceDrop(f)
	for _, kind in ipairs({ "font", "tex", "edge" }) do
		local p = f.pools[kind]
		for i = p.used + 1, #p.list do
			p.list[i]:Hide()
		end
	end
	return f
end
