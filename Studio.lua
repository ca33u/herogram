--[[
  Herogram studio: the panel next to the card where you pick the format,
  colour, pose, headline and what to show, and the button that takes
  the picture.

  Taking the picture: the panel hides, the card goes on top of
  everything over a black screen and fills it, the game saves a
  screenshot, and everything goes back. The crop page (Crop.html in the
  addon folder) finds the card on the black and cuts it out at the exact
  size for each social network.

  A small notice offers a card when you reach a new level or a new
  profession rank (75, 150, 225, 300).

  /herogram           open or close
  /herogram toasts    the notice on level up and profession ranks
  /herogram minimap   the minimap button
  /herogram reset     put the hero back as it was
  /herogram debug     what the game says about professions and talents
]]

local ADDON, ns = ...
local T = ns.T
local D = ns.Data
local C = ns.Card

local S = {}
ns.Studio = S

local P = "|cffd9b25cHerogram|r "
local MEDIA = "Interface\\AddOns\\Herogram\\Media\\"
local PANEL_W = 244

S.POSES = {
	{ 0, "Stand" },
	{ 26, "Ready" },
	{ 55, "Battle roar" },
	{ 82, "Flex" },
	{ 113, "Salute" },
	{ 68, "Cheer" },
	{ 69, "Dance" },
	{ 75, "Kneel" },
	{ 52, "Spell" },
}

S.SHOW = {
	{ "guild", "Guild" },
	{ "profs", "Professions" },
	{ "talents", "Talents" },
	{ "played", "Played" },
	{ "steps", "Steps" },
	{ "quests", "Quests done" },
	{ "ilvl", "Item level" },
	{ "pvp", "PvP rank" },
	{ "item", "Best item" },
	{ "gold", "Gold" },
}

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

function S.DB()
	D.Migrate()
	HerogramDB = type(HerogramDB) == "table" and HerogramDB or {}
	local db = HerogramDB
	if not D.Format(db.format) or D.Format(db.format).key ~= db.format then
		db.format = "story"
	end
	db.accent = db.accent or "class"
	db.frame = db.frame or "herogram"
	db.show = type(db.show) == "table" and db.show or {}
	for _, s in ipairs(S.SHOW) do
		if db.show[s[1]] == nil then
			db.show[s[1]] = s[1] ~= "gold"
		end
	end
	db.model = type(db.model) == "table" and db.model or C.ModelDefaults()
	for k, v in pairs(C.ModelDefaults()) do
		if db.model[k] == nil then
			db.model[k] = v
		end
	end
	if db.toasts == nil then
		db.toasts = true
	end
	if db.minimap == nil then
		db.minimap = true
	end
	db.chars = type(db.chars) == "table" and db.chars or {}
	db.hideProfs = type(db.hideProfs) == "table" and db.hideProfs or {}
	return db
end

function S.Me()
	local name = D.Call(UnitName, "player") or "?"
	local realm = D.Call(GetRealmName) or "?"
	return name .. "-" .. realm
end

function S.PoseIndex(anim)
	for i, p in ipairs(S.POSES) do
		if p[1] == anim then
			return i
		end
	end
	return 1
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------

local function Border(f, r, g, b, a)
	f.edges = f.edges or {}
	local pts = {
		{ "TOPLEFT", "TOPRIGHT", nil, 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
	}
	for i, p in ipairs(pts) do
		local t = f.edges[i]
		if not t then
			t = f:CreateTexture(nil, "BORDER")
			t:SetPoint(p[1])
			t:SetPoint(p[2])
			if p[3] then
				t:SetWidth(p[3])
			else
				t:SetHeight(p[4])
			end
			f.edges[i] = t
		end
		t:SetColorTexture(r, g, b, a)
	end
end

local function Label(parent, text, size, color, kind)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	C.Font(fs, kind or "body", size or 11)
	fs:SetText(text or "")
	color = color or C.INK
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH("LEFT")
	return fs
end

local function Button(parent, text, w, h, onClick, big)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(1, 1, 1, 1)
	b.label = Label(b, text, big and 14 or 10.5, C.INK, big and "title" or "body")
	b.label:SetPoint("CENTER", 0, big and -1 or 0)
	b.label:SetJustifyH("CENTER")
	function b:SetSelected(on)
		self.selected = on
		if big then
			C.Gradient(self.bg, "VERTICAL", { 0.55, 0.36, 0.1, 1 }, { 0.86, 0.66, 0.3, 1 })
			Border(self, 1, 0.86, 0.5, self.hover and 1 or 0.8)
			self.label:SetTextColor(0.13, 0.07, 0.01)
			self.label:SetShadowColor(1, 0.9, 0.6, 0.35)
			self.label:SetShadowOffset(0, -1)
			return
		end
		self.bg:SetColorTexture(1, 1, 1, on and 0.1 or (self.hover and 0.07 or 0.035))
		local g = C.GOLD
		Border(self, g[1], g[2], g[3], on and 0.9 or (self.hover and 0.45 or 0.18))
		local c = on and C.GOLD or C.INK
		self.label:SetTextColor(c[1], c[2], c[3], on and 1 or 0.85)
	end
	b:SetScript("OnEnter", function(self)
		self.hover = true
		self:SetSelected(self.selected)
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(self.tip)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		self:SetSelected(self.selected)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	b:SetSelected(false)
	return b
end

local function Toggle(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 18)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetSize(11, 11)
	b.box:SetPoint("LEFT", 0, 0)
	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetSize(13, 13)
	b.mark:SetPoint("CENTER", b.box)
	b.mark:SetTexture(MEDIA .. "diamond.blp")
	b.frame = CreateFrame("Frame", nil, b)
	b.frame:SetAllPoints(b.box)
	Border(b.frame, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.6)
	b.label = Label(b, text, 10.5, C.INK)
	b.label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
	function b:SetChecked(on)
		self.checked = on
		self.box:SetColorTexture(0, 0, 0, 0.4)
		self.mark:SetShown(on)
		self.mark:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
		self.label:SetAlpha(on and 1 or 0.55)
	end
	b:SetScript("OnClick", onClick)
	return b
end

local function Heading(parent, text, y)
	local fs = Label(parent, C.Caps(text), 9, C.GOLD)
	fs:SetPoint("TOPLEFT", 16, -y)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
	line:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.2)
	return y + 18
end

------------------------------------------------------------------------
-- The panel
------------------------------------------------------------------------

local panel

local function Build()
	if panel then
		return panel
	end
	local db = S.DB()
	local p = CreateFrame("Frame", "HerogramStudio", UIParent)
	panel = p
	p:SetFrameStrata("DIALOG")
	p:SetToplevel(true)
	p:EnableMouse(true)
	p:SetWidth(PANEL_W)
	p:Hide()
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints()
	p.bg:SetColorTexture(1, 1, 1, 1)
	C.Gradient(p.bg, "VERTICAL", { 0.05, 0.05, 0.07, 0.97 }, { 0.1, 0.1, 0.13, 0.97 })
	Border(p, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.45)
	table.insert(UISpecialFrames, "HerogramStudio")

	local inner = PANEL_W - 32
	local y = 16
	local title = Label(p, "Herogram", 26, C.GOLD, "title")
	title:SetPoint("TOPLEFT", 16, -y)
	local sub = Label(p, T("Your hero, ready to share"), 10, C.DIM)
	sub:SetPoint("TOPLEFT", 16, -(y + 30))
	local close = Button(p, "×", 22, 22, function()
		p:Hide()
	end)
	close:SetPoint("TOPRIGHT", -10, -10)
	y = y + 56

	-- format
	y = Heading(p, T("Format"), y)
	p.formats = {}
	local bw = (inner - 8) / 2
	for i, f in ipairs(D.FORMATS) do
		local b = Button(p, T(f.label) .. "  |cff8a8070" .. f.ratio .. "|r", bw, 26, function()
			S.DB().format = f.key
			S.Refresh(true)
		end)
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		b:SetPoint("TOPLEFT", 16 + col * (bw + 8), -(y + row * 32))
		b.key = f.key
		p.formats[#p.formats + 1] = b
	end
	y = y + 64 + 6

	-- colour
	y = Heading(p, T("Colour"), y)
	p.swatches = {}
	local sw = (inner - 5 * 6) / 6
	for i, key in ipairs(C.ACCENT_KEYS) do
		local b = CreateFrame("Button", nil, p)
		b:SetSize(sw, 22)
		b:SetPoint("TOPLEFT", 16 + (i - 1) * (sw + 6), -y)
		b.fill = b:CreateTexture(nil, "ARTWORK")
		b.fill:SetPoint("TOPLEFT", 3, -3)
		b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
		b.key = key
		b:SetScript("OnClick", function()
			S.DB().accent = key
			S.Refresh()
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(T(C.ACCENT_NAMES[key]))
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		p.swatches[#p.swatches + 1] = b
	end
	y = y + 22 + 12

	-- frame: ours, or the borders the game has
	y = Heading(p, T("Frame"), y)
	p.frames = {}
	local fw = (inner - 2 * 6) / 3
	for i, fr in ipairs(C.AvailableFrames()) do
		local b = Button(p, T(fr.label), fw, 22, function()
			S.DB().frame = fr.key
			S.Refresh()
		end)
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		b:SetPoint("TOPLEFT", 16 + col * (fw + 6), -(y + row * 28))
		b.key = fr.key
		p.frames[#p.frames + 1] = b
	end
	y = y + math.ceil(#p.frames / 3) * 28 + 6

	-- pose
	y = Heading(p, T("Pose"), y)
	local prev = Button(p, "<", 24, 24, function()
		S.StepPose(-1)
	end)
	prev:SetPoint("TOPLEFT", 16, -y)
	local nextB = Button(p, ">", 24, 24, function()
		S.StepPose(1)
	end)
	nextB:SetPoint("TOPLEFT", 16 + 24 + 80, -y)
	p.pose = Label(p, "", 11, C.INK)
	p.pose:SetPoint("CENTER", p, "TOPLEFT", 16 + 24 + 40, -(y + 12))
	p.pose:SetJustifyH("CENTER")
	p.pose:SetWidth(78)
	p.freeze = Toggle(p, T("Freeze"), 74, function()
		local m = S.DB().model
		m.paused = not m.paused
		C.ApplyModel()
		S.Sync()
	end)
	p.freeze:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -(y + 3))
	y = y + 24 + 12

	-- headline
	y = Heading(p, T("Headline"), y)
	local eb = CreateFrame("EditBox", nil, p)
	eb:SetSize(inner, 24)
	eb:SetPoint("TOPLEFT", 16, -y)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(48)
	eb:SetTextInsets(8, 8, 0, 0)
	if ChatFontNormal then
		eb:SetFontObject(ChatFontNormal)
	end
	eb.bg = eb:CreateTexture(nil, "BACKGROUND")
	eb.bg:SetAllPoints()
	eb.bg:SetColorTexture(0, 0, 0, 0.45)
	Border(eb, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.3)
	eb.hint = Label(eb, T("e.g. Finally Artisan!"), 10, C.DIM)
	eb.hint:SetPoint("LEFT", 8, 0)
	eb:SetScript("OnEscapePressed", eb.ClearFocus)
	eb:SetScript("OnEnterPressed", eb.ClearFocus)
	eb:SetScript("OnTextChanged", function(self, user)
		self.hint:SetShown(self:GetText() == "")
		if user then
			S.headline = self:GetText()
			S.Refresh()
		end
	end)
	p.headline = eb
	y = y + 24 + 12

	-- what to show
	y = Heading(p, T("Show"), y)
	p.toggles = {}
	local tw = (inner - 8) / 2
	for i, s in ipairs(S.SHOW) do
		local key = s[1]
		local b = Toggle(p, T(s[2]), tw, function()
			local show = S.DB().show
			show[key] = not show[key]
			S.Refresh()
		end)
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		b:SetPoint("TOPLEFT", 16 + col * (tw + 8), -(y + row * 20))
		b.key = key
		p.toggles[#p.toggles + 1] = b
	end
	y = y + math.ceil(#S.SHOW / 2) * 20 + 10

	-- your professions, one switch each (filled in by S.LayoutProfs)
	p.profTop = y
	p.profLabel = Label(p, C.Caps(T("Professions")), 9, C.GOLD)
	p.profLabel:SetPoint("TOPLEFT", 16, -y)
	p.profLine = p:CreateTexture(nil, "ARTWORK")
	p.profLine:SetHeight(1)
	p.profLine:SetPoint("LEFT", p.profLabel, "RIGHT", 8, 0)
	p.profLine:SetPoint("RIGHT", p, "RIGHT", -16, 0)
	p.profLine:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.2)
	p.profToggles = {}

	-- everything below moves down with the number of professions
	local lower = CreateFrame("Frame", nil, p)
	lower:SetSize(PANEL_W, 1)
	p.lower = lower
	local ly = 0

	-- the item on the card: dropped here (or on the card), or automatic
	local il = Label(lower, C.Caps(T("Best item")), 9, C.GOLD)
	il:SetPoint("TOPLEFT", 16, -ly)
	local iline = lower:CreateTexture(nil, "ARTWORK")
	iline:SetHeight(1)
	iline:SetPoint("LEFT", il, "RIGHT", 8, 0)
	iline:SetPoint("RIGHT", lower, "RIGHT", -16, 0)
	iline:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.2)
	ly = ly + 18
	local slot = CreateFrame("Button", nil, lower)
	slot:SetSize(inner, 36)
	slot:SetPoint("TOPLEFT", 16, -ly)
	slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	slot.bg = slot:CreateTexture(nil, "BACKGROUND")
	slot.bg:SetAllPoints()
	slot.bg:SetColorTexture(0, 0, 0, 0.35)
	Border(slot, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.3)
	slot.frame = slot:CreateTexture(nil, "ARTWORK")
	slot.frame:SetSize(30, 30)
	slot.frame:SetPoint("LEFT", 3, 0)
	slot.icon = slot:CreateTexture(nil, "ARTWORK", nil, 2)
	slot.icon:SetSize(28, 28)
	slot.icon:SetPoint("CENTER", slot.frame)
	slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	slot.name = Label(slot, "", 10.5, C.INK)
	slot.name:SetPoint("TOPLEFT", 40, -5)
	slot.name:SetWidth(inner - 92)
	slot.name:SetWordWrap(false)
	slot.sub = Label(slot, "", 8.5, C.DIM)
	slot.sub:SetPoint("TOPLEFT", 40, -20)
	slot.sub:SetWidth(inner - 92)
	slot.sub:SetWordWrap(false)
	slot.auto = Button(slot, T("Auto"), 42, 20, function()
		S.ClearItem()
	end)
	slot.auto:SetPoint("RIGHT", -6, 0)
	slot:SetScript("OnReceiveDrag", function()
		S.TakeCursorItem()
	end)
	slot:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			S.ClearItem()
		else
			S.TakeCursorItem()
		end
	end)
	slot:SetScript("OnEnter", function(self)
		Border(self, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.8)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(T("Drag an item here to show it instead"))
		GameTooltip:AddLine(T("Or Shift-click an item in your bags while this panel is open."), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(T("Right-click: back to automatic"), 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	slot:SetScript("OnLeave", function(self)
		Border(self, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.3)
		GameTooltip:Hide()
	end)
	p.slot = slot
	ly = ly + 36 + 14
	local hint = Label(lower, T("Drag the hero to turn, wheel to zoom, right-drag to move."), 9.5, C.DIM)
	hint:SetPoint("TOPLEFT", 16, -ly)
	hint:SetWidth(inner)
	hint:SetWordWrap(true)
	hint:SetJustifyH("LEFT")
	ly = ly + 28
	local reset = Button(lower, T("Reset hero"), inner, 22, function()
		S.ResetHero()
	end)
	reset:SetPoint("TOPLEFT", 16, -ly)
	ly = ly + 22 + 14

	-- what did not fit on the card (nothing is left out silently)
	p.fitNote = Label(lower, "", 9.5, { 1, 0.55, 0.42 })
	p.fitNote:SetPoint("TOPLEFT", 16, -ly)
	p.fitNote:SetWidth(inner)
	p.fitNote:SetWordWrap(true)
	p.fitNote:SetJustifyH("LEFT")
	ly = ly + 30

	local shoot = Button(lower, T("Take the picture"), inner, 36, function()
		S.Shoot()
	end, true)
	shoot:SetPoint("TOPLEFT", 16, -ly)
	shoot:SetSelected(true)
	p.shoot = shoot
	ly = ly + 36 + 10

	p.status = Label(lower, "", 9.5, C.DIM)
	p.status:SetPoint("TOPLEFT", 16, -ly)
	p.status:SetWidth(inner)
	p.status:SetWordWrap(true)
	p.status:SetJustifyH("LEFT")
	local path = CreateFrame("EditBox", nil, lower)
	path:SetSize(inner, 20)
	path:SetPoint("TOPLEFT", 16, -(ly + 40))
	path:SetAutoFocus(false)
	path:SetTextInsets(6, 6, 0, 0)
	if ChatFontSmall or ChatFontNormal then
		path:SetFontObject(ChatFontSmall or ChatFontNormal)
	end
	path.bg = path:CreateTexture(nil, "BACKGROUND")
	path.bg:SetAllPoints()
	path.bg:SetColorTexture(0, 0, 0, 0.45)
	path:SetScript("OnEscapePressed", path.ClearFocus)
	path:SetScript("OnTextChanged", function(self, user)
		if user then
			self:SetText(S.CropPath())
			self:SetCursorPosition(0)
			self:HighlightText()
		end
	end)
	path:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	path:Hide()
	p.path = path
	p.lowerFull = ly + 70
	p.lowerShort = ly + 6
	S.LayoutProfs({})

	p:SetScript("OnHide", function()
		if not S.shooting then
			if C.frame then
				C.frame:Hide()
			end
			if p.headline then
				p.headline:ClearFocus()
			end
		end
	end)
	return p
end

-- One switch per profession the hero has, with its rank. Moves the rest
-- of the panel down to make room.
function S.LayoutProfs(profs)
	local p = panel
	if not p then
		return
	end
	local inner = PANEL_W - 32
	local h = 0
	for i, prof in ipairs(profs) do
		local b = p.profToggles[i]
		if not b then
			b = Toggle(p, "", inner, function(self)
				local hide = S.DB().hideProfs
				hide[self.key] = not hide[self.key] or nil
				S.Refresh()
			end)
			b.rank = Label(b, "", 10, C.DIM)
			b.rank:SetPoint("RIGHT", b, "RIGHT", 0, 0)
			b.rank:SetJustifyH("RIGHT")
			p.profToggles[i] = b
		end
		b.key = prof.key
		b.label:SetText(prof.name)
		b.rank:SetText(prof.rank .. " / " .. D.SKILL_CAP)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 16, -(p.profTop + 18 + (i - 1) * 20))
		b:SetChecked(not S.DB().hideProfs[prof.key])
		b:Show()
	end
	for i = #profs + 1, #p.profToggles do
		p.profToggles[i]:Hide()
	end
	local any = #profs > 0
	p.profLabel:SetShown(any)
	p.profLine:SetShown(any)
	if any then
		h = 18 + #profs * 20 + 10
	end
	p.lower:ClearAllPoints()
	p.lower:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(p.profTop + h))
	p.shortHeight = p.profTop + h + p.lowerShort
	p.fullHeight = p.profTop + h + p.lowerFull
	p:SetHeight(p.path:IsShown() and p.fullHeight or p.shortHeight)
end

function S.CropPath()
	return "World of Warcraft/_forever_/Interface/AddOns/" .. ADDON .. "/Crop.html"
end

-- Panel controls follow the settings.
function S.Sync()
	if not panel then
		return
	end
	local db = S.DB()
	for _, b in ipairs(panel.formats) do
		b:SetSelected(b.key == db.format)
	end
	for _, b in ipairs(panel.frames) do
		b:SetSelected(b.key == C.FrameStyle(db.frame).key)
	end
	for _, b in ipairs(panel.swatches) do
		local c = C.Accent(b.key, S.data)
		b.fill:SetColorTexture(c[1], c[2], c[3], 1)
		local on = b.key == db.accent
		Border(b, 1, 1, 1, on and 0.95 or 0.12)
	end
	-- what was switched on but did not fit: red in the panel
	local out, names = {}, {}
	for _, d in ipairs(C.frame and C.frame.dropped or {}) do
		out[d.key] = true
		names[#names + 1] = d.label
	end
	local function Mark(b)
		if b.checked and out[b.key] then
			b.label:SetTextColor(1, 0.5, 0.4)
		else
			b.label:SetTextColor(C.INK[1], C.INK[2], C.INK[3])
		end
	end
	for _, b in ipairs(panel.toggles) do
		b:SetChecked(db.show[b.key] and true or false)
		Mark(b)
	end
	if #names > 0 then
		local hint = db.format == "story" and T("switch something off.") or T("switch something off or pick Stories.")
		panel.fitNote:SetText(string.format(T("Did not fit: %s. To show it, %s"), table.concat(names, ", "), hint))
	else
		panel.fitNote:SetText("")
	end
	for _, b in ipairs(panel.profToggles) do
		if b:IsShown() then
			b:SetChecked(not db.hideProfs[b.key])
			Mark(b)
		end
	end
	panel.pose:SetText(T(S.POSES[S.PoseIndex(db.model.anim)][2]))
	panel.freeze:SetChecked(db.model.paused and true or false)
end

------------------------------------------------------------------------
-- Placing the card and the panel
------------------------------------------------------------------------

function S.Place()
	local card = C.frame
	if not (card and panel) then
		return
	end
	local fmt = D.Format(S.DB().format)
	local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
	local k = D.Fit(fmt.w, fmt.h, uw - PANEL_W - 80, uh, 0.86)
	card:SetScale(k)
	card:SetFrameStrata("DIALOG")
	card:ClearAllPoints()
	card:SetPoint("CENTER", UIParent, "CENTER", -(PANEL_W + 24) / 2 / k, 0)
	panel:ClearAllPoints()
	panel:SetScale(math.min(1, uh * 0.94 / panel:GetHeight()))
	panel:SetPoint("LEFT", card, "RIGHT", 24 / k, 0)
end

------------------------------------------------------------------------
-- Open, close, refresh
------------------------------------------------------------------------

function S.Refresh(replace)
	if not (panel and panel:IsShown()) then
		return
	end
	local db = S.DB()
	S.data = S.WithChosenItem(D.Collect())
	C.state = db.model
	C.Render(S.data, { format = db.format, accent = db.accent, show = db.show, headline = S.headline, model = db.model, hideProfs = db.hideProfs, frame = db.frame })
	S.LayoutProfs(S.data.profs or {})
	if replace then
		S.Place()
	end
	C.ApplyModel()
	S.Sync()
end

function S.Open(headline)
	Build()
	local db = S.DB()
	S.headline = headline or S.headline
	panel.headline:SetText(S.headline or "")
	panel.status:SetText("")
	panel.path:Hide()
	S.RequestPlayed()
	S.data = S.WithChosenItem(D.Collect())
	S.LayoutProfs(S.data.profs or {})
	C.state = db.model
	C.Render(S.data, { format = db.format, accent = db.accent, show = db.show, headline = S.headline, hideProfs = db.hideProfs, frame = db.frame })
	panel:Show()
	S.Place()
	C.frame:Show()
	C.LoadModel()
	S.Sync()
	S.SyncItem()
end

------------------------------------------------------------------------
-- The item you choose for the card
------------------------------------------------------------------------

local function CharDB()
	local db = S.DB()
	local me = S.Me()
	db.chars[me] = type(db.chars[me]) == "table" and db.chars[me] or {}
	return db.chars[me]
end

-- The chosen item replaces the automatic one; the automatic one is kept
-- for the panel.
function S.WithChosenItem(data)
	data.autoBest = data.best
	local link = CharDB().bestItem
	local it = link and D.ItemFromLink(link)
	if it then
		data.best = it
		S.waitItem = it.pending and it.id or nil
	end
	return data
end

function S.ChooseItem(link)
	if not D.ItemID(link) then
		return false
	end
	CharDB().bestItem = link
	S.Refresh()
	S.SyncItem()
	return true
end

function S.ClearItem()
	CharDB().bestItem = nil
	S.Refresh()
	S.SyncItem()
end

-- The item on the cursor (dragged from a bag or the character sheet):
-- read it and put it back. The item itself is never used or moved.
function S.TakeCursorItem()
	local kind, id, link = D.Call(GetCursorInfo)
	if kind ~= "item" then
		return false
	end
	if type(link) ~= "string" then
		link = type(id) == "number" and (select(2, D.Call(GetItemInfo, id)) or ("item:" .. id)) or nil
	end
	D.Call(ClearCursor)
	return link and S.ChooseItem(link) or false
end

function S.SyncItem()
	local slot = panel and panel.slot
	if not slot then
		return
	end
	local chosen = CharDB().bestItem
	local it = S.data and S.data.best
	if it then
		slot.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		slot.icon:Show()
		local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[it.quality or 1]
		slot.frame:SetColorTexture(c and c.r or 1, c and c.g or 1, c and c.b or 1, 0.9)
		slot.name:SetText(it.name or "?")
		if c then
			slot.name:SetTextColor(c.r, c.g, c.b)
		end
	else
		slot.icon:Hide()
		slot.frame:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.25)
		slot.name:SetText(T("Drop an item here"))
		slot.name:SetTextColor(C.INK[1], C.INK[2], C.INK[3])
	end
	slot.sub:SetText(chosen and T("Your choice · right-click for automatic") or T("Automatic · drop an item to change"))
	slot.auto:SetShown(chosen and true or false)
end

function S.Close()
	if panel then
		panel:Hide()
	end
end

function S.Toggle()
	if panel and panel:IsShown() then
		S.Close()
	else
		S.Open()
	end
end

function S.StepPose(dir)
	local m = S.DB().model
	local i = S.PoseIndex(m.anim) + dir
	if i < 1 then
		i = #S.POSES
	elseif i > #S.POSES then
		i = 1
	end
	m.anim = S.POSES[i][1]
	m.paused = false
	C.ApplyModel()
	S.Sync()
end

function S.ResetHero()
	local db = S.DB()
	db.model = C.ModelDefaults()
	C.state = db.model
	if C.frame and C.frame:IsShown() then
		C.LoadModel()
	end
	S.Sync()
end

------------------------------------------------------------------------
-- Taking the picture
------------------------------------------------------------------------

local function GetC(name)
	if C_CVar and C_CVar.GetCVar then
		return D.Call(C_CVar.GetCVar, name)
	end
	return D.Call(GetCVar, name)
end

local function SetC(name, value)
	if value == nil then
		return
	end
	if C_CVar and C_CVar.SetCVar then
		D.Call(C_CVar.SetCVar, name, value)
	else
		D.Call(SetCVar, name, value)
	end
end

S.shooting = false

function S.Shoot()
	if S.shooting or not (C.frame and C.frame:IsShown()) then
		return
	end
	if type(Screenshot) ~= "function" then
		return
	end
	S.shooting = true
	local card = C.frame
	local fmt = D.Format(S.DB().format)
	if panel.headline then
		panel.headline:ClearFocus()
	end
	GameTooltip:Hide()
	if ItemRefTooltip then
		ItemRefTooltip:Hide()
	end
	panel:Hide()
	local k = D.Fit(fmt.w, fmt.h, UIParent:GetWidth(), UIParent:GetHeight(), 0.96)
	card:SetFrameStrata("TOOLTIP")
	card:SetScale(k)
	card:ClearAllPoints()
	card:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	card.shot:Show()
	C.ApplyModel()
	S.cvars = { format = GetC("screenshotFormat"), quality = GetC("screenshotQuality") }
	SetC("screenshotFormat", "png")
	SetC("screenshotQuality", "10")
	S.savedAs = GetC("screenshotFormat")
	local token = {}
	S.token = token
	-- let the model draw a few frames at its new size first
	C_Timer.After(0.25, function()
		if S.token ~= token then
			return
		end
		if not pcall(Screenshot) then
			S.Finish(false)
		end
	end)
	C_Timer.After(5, function()
		if S.token == token then
			S.Finish(false)
		end
	end)
end

function S.Finish(ok)
	if not S.shooting then
		return
	end
	S.shooting = false
	S.token = nil
	local card = C.frame
	card.shot:Hide()
	if S.cvars then
		SetC("screenshotFormat", S.cvars.format)
		SetC("screenshotQuality", S.cvars.quality)
		S.cvars = nil
	end
	panel:Show()
	S.Place()
	C.ApplyModel()
	if ok then
		panel.status:SetText(T("Saved to the Screenshots folder.") .. " " .. T("Open this page in your browser to crop it for social media:"))
		panel.path:SetText(S.CropPath())
		panel.path:SetCursorPosition(0)
		panel.path:Show()
		panel:SetHeight(panel.fullHeight)
		print(P .. T("Saved to the Screenshots folder.") .. " " .. T("Open this page in your browser to crop it for social media:") .. " |cffffffff" .. S.CropPath() .. "|r")
	else
		panel.status:SetText("|cffff6050" .. T("The game did not save the picture.") .. "|r")
		panel.path:Hide()
		panel:SetHeight(panel.shortHeight + 30)
	end
	S.Place()
end

------------------------------------------------------------------------
-- Time played, without the two lines in chat
------------------------------------------------------------------------

local muted = {}

function S.RequestPlayed()
	if D.played or S.askedPlayed or type(RequestTimePlayed) ~= "function" then
		return
	end
	S.askedPlayed = true
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf and cf.IsEventRegistered and cf:IsEventRegistered("TIME_PLAYED_MSG") then
			cf:UnregisterEvent("TIME_PLAYED_MSG")
			muted[#muted + 1] = cf
		end
	end
	if not pcall(RequestTimePlayed) then
		S.Unmute()
	end
	C_Timer.After(5, S.Unmute)
end

function S.Unmute()
	for _, cf in ipairs(muted) do
		pcall(cf.RegisterEvent, cf, "TIME_PLAYED_MSG")
	end
	muted = {}
end

------------------------------------------------------------------------
-- The notice: level up and profession ranks
------------------------------------------------------------------------

local toast

local function Toast(title, headline)
	if not S.DB().toasts then
		return
	end
	if not toast then
		toast = CreateFrame("Frame", "HerogramToast", UIParent)
		toast:SetSize(320, 66)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
		toast:SetFrameStrata("HIGH")
		toast.bg = toast:CreateTexture(nil, "BACKGROUND")
		toast.bg:SetAllPoints()
		toast.bg:SetColorTexture(1, 1, 1, 1)
		C.Gradient(toast.bg, "HORIZONTAL", { 0.06, 0.06, 0.08, 0.95 }, { 0.12, 0.1, 0.08, 0.95 })
		Border(toast, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.6)
		toast.icon = toast:CreateTexture(nil, "ARTWORK")
		toast.icon:SetSize(44, 44)
		toast.icon:SetPoint("LEFT", 11, 0)
		toast.icon:SetTexture(MEDIA .. "icon.blp")
		toast.title = Label(toast, "", 19, C.GOLD, "title")
		toast.title:SetPoint("TOPLEFT", 64, -11)
		toast.sub = Label(toast, T("Worth sharing."), 10, C.DIM)
		toast.sub:SetPoint("TOPLEFT", 64, -36)
		toast.go = Button(toast, T("Make a card"), 104, 24, function()
			toast:Hide()
			S.Open(toast.headline)
		end)
		toast.go:SetPoint("RIGHT", -12, -4)
		toast.go:SetSelected(true)
		toast.x = Button(toast, "×", 18, 18, function()
			toast:Hide()
		end)
		toast.x:SetPoint("TOPRIGHT", -4, -4)
	end
	toast.headline = headline
	toast.title:SetText(title)
	toast:Show()
	local token = {}
	toast.token = token
	C_Timer.After(30, function()
		if toast.token == token then
			toast:Hide()
		end
	end)
end
S.Toast = Toast

function S.CheckRanks()
	local db = S.DB()
	local me = S.Me()
	db.chars[me] = type(db.chars[me]) == "table" and db.chars[me] or {}
	local ch = db.chars[me]
	local first = ch.ranks == nil
	ch.ranks = ch.ranks or {}
	for _, p in ipairs(D.ReadProfessions()) do
		local hit = not first and D.Milestone(ch.ranks[p.key], p.rank)
		ch.ranks[p.key] = p.rank
		if hit then
			local text = string.format(T("%s %d"), p.name, hit)
			Toast(text, text)
		end
	end
end

------------------------------------------------------------------------
-- Events and commands
------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a1)
	if event == "PLAYER_LOGIN" then
		S.DB()
		C_Timer.After(3, S.CheckRanks)
	elseif event == "TIME_PLAYED_MSG" then
		if type(a1) == "number" then
			D.played = a1
			D.playedAt = GetTime()
		end
		C_Timer.After(0, S.Unmute)
		S.Refresh()
	elseif event == "PLAYER_LEVEL_UP" then
		local level = tonumber(a1)
		if level then
			Toast(string.format(T("Level %d!"), level), string.format(T("Reached level %d"), level))
		end
	elseif event == "SKILL_LINES_CHANGED" then
		-- opening and closing collapsed headers while reading fires this too
		local now = GetTime()
		if D.readAt and now - D.readAt < 2 then
			return
		end
		if not S.rankQueued then
			S.rankQueued = true
			C_Timer.After(1, function()
				S.rankQueued = false
				S.CheckRanks()
			end)
		end
	elseif event == "SCREENSHOT_SUCCEEDED" then
		S.Finish(true)
	elseif event == "SCREENSHOT_FAILED" then
		S.Finish(false)
	elseif event == "UNIT_MODEL_CHANGED" then
		if a1 == "player" and C.frame and C.frame:IsShown() then
			C.LoadModel()
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		S.Refresh()
		S.SyncItem()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if S.waitItem and a1 == S.waitItem then
			S.waitItem = nil
			S.Refresh()
			S.SyncItem()
		end
	end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "TIME_PLAYED_MSG", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED", "UNIT_MODEL_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
	pcall(ev.RegisterEvent, ev, e)
end

-- The raw answers in a box you can copy from (Cmd+C / Ctrl+C).
local debugBox

function S.ShowDebug(lines)
	print(P .. "debug:")
	for _, line in ipairs(lines) do
		print(line)
	end
	if not debugBox then
		local f = CreateFrame("Frame", "HerogramDebug", UIParent)
		f:SetSize(620, 420)
		f:SetPoint("CENTER")
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:EnableMouse(true)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.bg:SetColorTexture(0.05, 0.05, 0.07, 0.97)
		Border(f, C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.6)
		f.title = Label(f, "Herogram debug: Cmd+C / Ctrl+C", 11, C.GOLD)
		f.title:SetPoint("TOPLEFT", 12, -10)
		local x = Button(f, "×", 22, 22, function()
			f:Hide()
		end)
		x:SetPoint("TOPRIGHT", -8, -8)
		local eb = CreateFrame("EditBox", nil, f)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetPoint("TOPLEFT", 12, -34)
		eb:SetPoint("BOTTOMRIGHT", -12, 12)
		if ChatFontSmall or ChatFontNormal then
			eb:SetFontObject(ChatFontSmall or ChatFontNormal)
		end
		eb:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		f.text = eb
		table.insert(UISpecialFrames, "HerogramDebug")
		debugBox = f
	end
	debugBox.text:SetText(table.concat(lines, "\n"))
	debugBox:Show()
	debugBox.text:SetFocus()
	debugBox.text:HighlightText()
end

local function OnOff(v)
	return v and T("on") or T("off")
end

SLASH_HEROGRAM1 = "/herogram"
SLASH_HEROGRAM2 = "/herald" -- the old name, for now
SlashCmdList.HEROGRAM = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	local db = S.DB()
	if cmd == "toasts" then
		db.toasts = not db.toasts
		print(P .. T("cards on level up and profession ranks:") .. " " .. OnOff(db.toasts))
	elseif cmd == "minimap" then
		if ns.Minimap then
			ns.Minimap.Toggle()
		end
	elseif cmd == "reset" then
		S.ResetHero()
	elseif cmd == "debug" then
		local lines = D.DebugLines()
		for _, fr in ipairs(C.FRAMES) do
			if fr.edge then
				local ok, id = C.TextureExists(fr.edge)
				lines[#lines + 1] = string.format("frame %s: %s (%s) %s", fr.key, ok == nil and "unknown" or ok and "yes" or "MISSING", tostring(id), fr.edge)
			end
		end
		local mo = C.Create().model
		lines[#lines + 1] = "model SetViewInsets: " .. (mo.SetViewInsets and "yes (hero placed by the camera, frame covers the card)" or "NO (frame = hero region, may cut)")
		local ok, id = C.TextureExists(C.PLAQUE_EDGE)
		lines[#lines + 1] = string.format("plaque border: %s (%s)", ok == nil and "unknown" or ok and "yes" or "MISSING", tostring(id))
		S.ShowDebug(lines)
	elseif cmd == "help" then
		print(P .. T("Commands:"))
		print("  /herogram  " .. T("open or close the card"))
		print("  /herogram toasts  " .. T("offer a card on level up and new profession ranks"))
		print("  /herogram minimap  " .. T("show or hide the minimap button"))
		print("  /herogram reset  " .. T("put the hero back as it was"))
		print("  /herogram debug  " .. T("print what the game says about professions and talents"))
	else
		S.Toggle()
	end
end

-- Shift-click an item in your bags while the studio is open (and no chat
-- box is waiting for a link): it becomes the card's item.
function S.OnModifiedClick(link)
	if not (panel and panel:IsShown()) or S.shooting then
		return false
	end
	if not (IsShiftKeyDown and IsShiftKeyDown()) then
		return false
	end
	local chat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if chat or (panel.headline and panel.headline:HasFocus()) then
		return false
	end
	if type(link) == "string" and link:find("|Hitem:") then
		return S.ChooseItem(link)
	end
	return false
end

if type(HandleModifiedItemClick) == "function" and hooksecurefunc then
	hooksecurefunc("HandleModifiedItemClick", function(link)
		S.OnModifiedClick(link)
	end)
end

C.onItemDrop = function()
	S.TakeCursorItem()
end
C.onItemClear = function()
	S.ClearItem()
end

function Herogram_OnAddonCompartmentClick()
	S.Toggle()
end
