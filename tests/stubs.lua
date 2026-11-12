-- Minimal WoW API stand-ins for running Herogram outside the game.
unpack = unpack or table.unpack
local total, fails = 0, 0
function Check(cond, msg)
	total = total + 1
	if cond then
		print("ok    " .. msg)
	else
		fails = fails + 1
		print("FAIL  " .. msg)
	end
end
function Report(name)
	print(string.format("%s: %d checks, %d failed", name, total, fails))
	os.exit(fails == 0 and 0 or 1)
end

local function Obj(extra)
	local o = extra or {}
	local scripts = {}
	o.SetScript = function(self, k, fn) scripts[k] = fn end
	o.GetScript = function(self, k) return scripts[k] end
	o.IsShown = function(self) return self._shown or false end
	o.IsVisible = o.IsShown
	o.Show = function(self) self._shown = true; if scripts.OnShow then scripts.OnShow(self) end end
	o.Hide = function(self) self._shown = false; if scripts.OnHide then scripts.OnHide(self) end end
	o.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
	o.SetText = function(self, t) self._text = t end
	o.GetText = function(self) return self._text or "" end
	o.SetFont = function(self, file, size) self._size = size; return true end
	o.GetFont = function(self) return "font", self._size or 12 end
	-- width grows with the text and the font size, like in the game
	o.GetStringWidth = function(self)
		local plain = (self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		return #plain * (self._size or 12) * 0.55
	end
	o.GetStringHeight = function(self) return (self._size or 12) * 1.2 end
	o.SetSize = function(self, w, h) self._w, self._h = w, h end
	o.SetWidth = function(self, w) self._w = w end
	o.SetHeight = function(self, h) self._h = h end
	o.GetWidth = function(self) return self._w or 1280 end
	o.GetHeight = function(self) return self._h or 720 end
	o.GetFrameLevel = function() return 1 end
	o.GetEffectiveScale = function() return 1 end
	o.GetChecked = function() return false end
	o.IsEventRegistered = function() return false end
	o.CreateTexture = function() return Obj() end
	o.CreateFontString = function() return Obj() end
	-- methods (Capitalized) are no-ops; plain fields stay nil like in the game
	return setmetatable(o, { __index = function(_, k)
		if type(k) == "string" and k:match("^%u") then
			return function() end
		end
	end })
end
StubObj = Obj
FRAMES = {}
function CreateFrame(kind, name)
	local f = Obj()
	f._kind = kind
	if name then _G[name] = f end
	FRAMES[#FRAMES + 1] = f
	return f
end
UIParent = Obj()
UIParent._w, UIParent._h = 1280, 720
Minimap = Obj()
GameTooltip = Obj()
UISpecialFrames = {}
SlashCmdList = {}
NOW = 1000
function GetTime() return NOW end
function GetLocale() return "enUS" end
function GetCursorPosition() return 0, 0 end
function hooksecurefunc(t, k, fn)
	local old = t[k]
	t[k] = function(...) local a, b, c = old(...); fn(...); return a, b, c end
end
TIMERS = {}
C_Timer = { After = function(_, fn) TIMERS[#TIMERS + 1] = fn end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- A level 33 undead paladin
function UnitName() return "Saz Zy" end
function UnitLevel() return 33 end
function GetMaxPlayerLevel() return 60 end
function UnitXP() return 31000 end
function UnitXPMax() return 50000 end
function UnitRace() return "Undead", "Scourge" end
function UnitClass() return "Paladin", "PALADIN" end
function UnitFactionGroup() return "Horde", "Horde" end
function GetGuildInfo() return "addicted", "Member", 2 end
function GetRealmName() return "Realm 2 PvP" end
-- The skill window: a collapsed header hides its lines, like in the game.
SKILLS = {
	{ "Professions", true, true },
	{ "Leatherworking", nil, nil, 187, 0, 0, 225 },
	{ "Skinning", nil, nil, 210, 0, 0, 225 },
	{ "Secondary Skills", true, false },
	{ "First Aid", nil, nil, 150, 0, 0, 150 },
	{ "Cooking", nil, nil, 80, 0, 0, 150 },
	{ "Weapon Skills", true, true },
	{ "Swords", nil, nil, 165, 0, 0, 165 },
}
SKILL_EVENTS = 0
local function Visible()
	local out, open = {}, true
	for _, row in ipairs(SKILLS) do
		if row[2] then
			out[#out + 1] = row
			open = row[3]
		elseif open then
			out[#out + 1] = row
		end
	end
	return out
end
function GetNumSkillLines() return #Visible() end
function GetSkillLineInfo(i) local r = Visible()[i]; if r then return unpack(r, 1, 7) end end
function ExpandSkillHeader(i) local r = Visible()[i]; if r and r[2] then r[3] = true; SKILL_EVENTS = SKILL_EVENTS + 1 end end
function CollapseSkillHeader(i) local r = Visible()[i]; if r and r[2] then r[3] = false; SKILL_EVENTS = SKILL_EVENTS + 1 end end
function GetNumTalentTabs() return 3 end
local TABS = { { "Holy", 0 }, { "Protection", 21 }, { "Retribution", 5 } }
function GetTalentTabInfo(i) return i, TABS[i][1], "", 0, TABS[i][2] end
local GEAR = {
	[1] = { "|cff1eff00|Hitem:1|h[Green Helm]|h|r", 2, 30 },
	[5] = { "|cff0070dd|Hitem:2|h[Blue Chest]|h|r", 3, 34 },
	[16] = { "|cff0070dd|Hitem:3|h[Blue Sword]|h|r", 3, 38 },
}
function GetInventoryItemLink(_, slot) return GEAR[slot] and GEAR[slot][1] end
function GetInventoryItemQuality(_, slot) return GEAR[slot] and GEAR[slot][2] end
function GetInventoryItemTexture() return 134400 end
C_Item = { GetDetailedItemLevelInfo = function(link)
	for _, g in pairs(GEAR) do if g[1] == link then return g[3] end end
end }
C_QuestLog = { GetAllCompletedQuestIDs = function() return { 1, 2, 3 } end }
function GetMoney() return 1234567 end
function UnitPVPRank() return 0 end
function GetSpellTexture() return 136000 end
function date(f) return "12 Nov 2026" end
SHOTS = 0
function Screenshot() SHOTS = SHOTS + 1 end

-- Loads one addon file with the shared namespace.
NS = {}
function LoadFile(path)
	local chunk = assert(loadfile(path))
	chunk("Herogram", NS)
end
