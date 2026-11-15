--[[
  Herogram data: what the card shows, read from the game, and the pure
  helpers (formats, layouts, professions, time, talents) that the tests
  run outside the game.
]]

local _, ns = ...
local T = ns.T

local D = {}
ns.Data = D

------------------------------------------------------------------------
-- Formats and layouts
------------------------------------------------------------------------

-- Card size in UI units (the card is scaled up for the picture) and the
-- size the crop page exports.
D.FORMATS = {
	{ key = "story", label = "Stories", ratio = "9:16", w = 450, h = 800, out = { 1080, 1920 } },
	{ key = "post", label = "Post", ratio = "4:5", w = 480, h = 600, out = { 1080, 1350 } },
	{ key = "square", label = "Square", ratio = "1:1", w = 520, h = 520, out = { 1080, 1080 } },
	{ key = "wide", label = "Wide", ratio = "16:9", w = 800, h = 450, out = { 1920, 1080 } },
}

function D.Format(key)
	for _, f in ipairs(D.FORMATS) do
		if f.key == key then
			return f
		end
	end
	return D.FORMATS[1]
end

-- Regions of the card, {x, y, w, h} from the top left, y going down.
-- Every format has one info column (col = x and width) under the header
-- text, down to `bottom`. Stories puts the hero in that column between
-- the header and the info; the others give the hero the whole left side
-- (model) and put the header and the info in the right column.
D.LAYOUTS = {
	story = {
		align = "CENTER",
		header = { 30, 44, 390 },
		col = { 30, 390 },
		bottom = 758,
		footer = { 30, 768, 390, 14 },
	},
	post = {
		align = "LEFT",
		header = { 226, 40, 226 },
		model = { 0, 24, 216, 556 },
		col = { 226, 226 },
		bottom = 556,
		footer = { 226, 568, 226, 14 },
	},
	square = {
		align = "LEFT",
		header = { 240, 36, 252 },
		model = { 0, 22, 230, 478 },
		col = { 240, 252 },
		bottom = 478,
		footer = { 240, 488, 252, 14 },
	},
	wide = {
		align = "LEFT",
		header = { 348, 32, 420 },
		model = { 10, 10, 330, 430 },
		col = { 348, 420 },
		bottom = 412,
		footer = { 348, 418, 420, 14 },
	},
}

function D.Layout(key)
	return D.LAYOUTS[key] or D.LAYOUTS.story
end

-- The Talents card: header, hero and the three trees. Stories stacks
-- header, hero and trees; Post and Square put the hero top left with the
-- header beside it and the trees across below; Wide puts the hero on the
-- left and header and trees on the right.
D.TREE_LAYOUTS = {
	story = { align = "CENTER", header = { 30, 44, 390 }, trees = { 26, 398 }, bottom = 756, footer = { 30, 768, 390, 14 } },
	post = { align = "LEFT", header = { 186, 40, 266 }, model = { 0, 18, 176, 236 }, top = 262, trees = { 26, 428 }, bottom = 556, footer = { 32, 568, 416, 14 } },
	square = { align = "LEFT", header = { 196, 36, 296 }, model = { 0, 14, 186, 214 }, top = 234, trees = { 26, 468 }, bottom = 478, footer = { 32, 488, 456, 14 } },
	wide = { align = "LEFT", header = { 286, 32, 486 }, model = { 10, 10, 266, 430 }, trees = { 286, 486 }, bottom = 412, footer = { 286, 418, 486, 14 } },
}
D.TREE_GAP = 10
D.TREE_TITLE = 20
D.TREE_CELL_MAX = 40
D.TREE_CELL_MIN = 13
D.TREE_MODEL_MIN = 170
D.TREE_MODEL_MAX = 300

function D.TreeLayout(key)
	return D.TREE_LAYOUTS[key] or D.TREE_LAYOUTS.story
end

-- Where the trees go: three trees of `tiers` x `cols` icons.
-- Returns { cell, model = {x,y,w,h}, trees = { {x, y, w} x3 }, fits }.
function D.PlanTrees(key, tiers, cols, headerBottom, count)
	local L = D.TreeLayout(key)
	local fmt = D.Format(key)
	tiers, cols, count = math.max(1, tiers or 7), math.max(1, cols or 4), math.max(1, count or 3)
	local x, w = L.trees[1], L.trees[2]
	local tw = (w - D.TREE_GAP * (count - 1)) / count
	local cellW = math.min(D.TREE_CELL_MAX, tw / cols)
	local top = (headerBottom or (L.header[2] + 106)) + 8
	local plan = {}
	local gridTop
	if L.model then
		plan.model = { L.model[1], L.model[2], L.model[3], L.model[4] }
		gridTop = math.max(top, L.top or top)
	else
		-- Stories: the hero takes what the trees leave
		local need = D.TREE_TITLE + tiers * cellW
		local mh = math.min(D.TREE_MODEL_MAX, L.bottom - top - need - 10)
		if mh < D.TREE_MODEL_MIN then
			mh = D.TREE_MODEL_MIN
		end
		local mw = math.min(fmt.w, mh * D.MODEL_ASPECT)
		plan.model = { (fmt.w - mw) / 2, top, mw, mh }
		gridTop = top + mh + 10
	end
	local cellH = (L.bottom - gridTop - D.TREE_TITLE) / tiers
	plan.cell = math.floor(math.min(cellW, cellH) * 10) / 10
	plan.fits = plan.cell >= D.TREE_CELL_MIN
	plan.trees = {}
	for i = 1, count do
		plan.trees[i] = { x = x + (i - 1) * (tw + D.TREE_GAP), y = gridTop, w = tw }
	end
	plan.height = D.TREE_TITLE + tiers * plan.cell
	return plan
end

-- Where the header text usually ends (level line, name, race and class,
-- guild), for planning before the card is drawn.
function D.HeaderBottom(key)
	local L = D.Layout(key)
	return L.header[2] + (L.align == "CENTER" and 112 or 106)
end

-- How tight the info is drawn: the planner tries each in turn.
D.DENSITY = {
	{ row = 31, tile = 56, gap = 8, block = 16, item = 58 },
	{ row = 27, tile = 50, gap = 7, block = 12, item = 54 },
	{ row = 23, tile = 46, gap = 6, block = 10, item = 50 },
}
D.MODEL_MIN = 230 -- the shortest the hero gets in Stories
D.MODEL_MAX = 400
D.MODEL_ASPECT = 0.8 -- the hero's frame is never wider than this x its height: the camera fits the hero to the width

function D.TileCols(w)
	if w >= 400 then
		return 4
	end
	return w >= 220 and 3 or 2
end

local function BlockHeights(n, w, d)
	local h = {}
	if n.profs > 0 then
		h.profs = n.profs * d.row
	end
	if n.tiles > 0 then
		local cols = D.TileCols(w)
		local rows = math.ceil(n.tiles / cols)
		h.tiles = rows * d.tile + (rows - 1) * d.gap
		h.cols = cols
	end
	if n.item then
		h.item = d.item
	end
	return h
end

-- Puts the blocks of one column top-down; nil when they need more than room.
local function Column(kinds, n, x, y, w, room, d, plan)
	local h = BlockHeights(n, w, d)
	local cy, used = y, 0
	for _, kind in ipairs(kinds) do
		if h[kind] then
			if used > 0 then
				cy = cy + d.block
			end
			if kind == "profs" then
				plan.profs = { x = x, y = cy, w = w, rows = n.profs }
			elseif kind == "tiles" then
				plan.tiles = { x = x, y = cy, w = w, cols = h.cols, count = n.tiles }
			else
				plan.item = { x = x, y = cy, w = w }
			end
			cy = cy + h[kind]
			used = cy - y
		end
	end
	if used > room then
		return nil
	end
	return used
end

local function Try(L, key, n, level, headerBottom)
	local d = D.DENSITY[level]
	local plan = { level = level, d = d }
	local x, w = L.col[1], L.col[2]
	local top = (headerBottom or D.HeaderBottom(key)) + (L.model and 12 or 6)
	if not L.model then
		-- Stories: the hero takes what the info leaves
		local scratch = {}
		local need = Column({ "profs", "tiles", "item" }, n, x, 0, w, math.huge, d, scratch)
		local space = L.bottom - top
		local mh = space - need - (need > 0 and 12 or 0)
		if mh < D.MODEL_MIN then
			return nil
		end
		mh = math.min(mh, D.MODEL_MAX)
		local infoTop = L.bottom - need
		local free = infoTop - top - (need > 0 and 12 or 0) - mh
		local my = top + math.max(0, free / 2)
		local fmt = D.Format(key)
		local mw = math.min(fmt.w, mh * D.MODEL_ASPECT)
		plan.model = { (fmt.w - mw) / 2, my, mw, mh }
		Column({ "profs", "tiles", "item" }, n, x, infoTop, w, need, d, plan)
		return plan
	end
	plan.model = { L.model[1], L.model[2], L.model[3], L.model[4] }
	if not Column({ "profs", "tiles", "item" }, n, x, top, w, L.bottom - top, d, plan) then
		return nil
	end
	return plan
end

-- Where everything goes for n = { profs = rows, tiles = count, item = bool }.
-- Each density is tried; if even the tightest is too tall, things are
-- left out from the end (the item, then plaques, then profession rows)
-- and plan.dropped says how many.
function D.PlanCard(key, n, headerBottom)
	local L = D.Layout(key)
	n = { profs = n.profs or 0, tiles = n.tiles or 0, item = n.item and true or false }
	for level = 1, #D.DENSITY do
		local plan = Try(L, key, n, level, headerBottom)
		if plan then
			plan.dropped = { profs = 0, tiles = 0, item = false }
			return plan
		end
	end
	local cut = { profs = n.profs, tiles = n.tiles, item = n.item }
	while true do
		if cut.item then
			cut.item = false
		elseif cut.tiles > 0 then
			cut.tiles = cut.tiles - 1
		elseif cut.profs > 0 then
			cut.profs = cut.profs - 1
		end
		local plan = Try(L, key, cut, #D.DENSITY, headerBottom)
		if plan or (cut.profs == 0 and cut.tiles == 0 and not cut.item) then
			plan = plan or { level = #D.DENSITY, d = D.DENSITY[#D.DENSITY], model = L.model or { 0, 0, 1, 1 } }
			plan.dropped = { profs = n.profs - cut.profs, tiles = n.tiles - cut.tiles, item = n.item and not cut.item }
			return plan
		end
	end
end

-- Scale that fits a card of w x h into an area, leaving a margin (0..1).
function D.Fit(w, h, areaW, areaH, share)
	share = share or 1
	if not (w and h and areaW and areaH) or w <= 0 or h <= 0 then
		return 1
	end
	return math.min(areaW * share / w, areaH * share / h)
end

------------------------------------------------------------------------
-- Professions
------------------------------------------------------------------------

D.SKILL_CAP = 300

-- Names as the game writes them (English and Russian clients), the icon
-- and the apprentice spell (its icon is used first: it always exists).
D.PROFS = {
	{ key = "alchemy", spell = 2259, icon = "Interface\\Icons\\Trade_Alchemy", names = { "Alchemy", "Алхимия" } },
	{ key = "blacksmithing", spell = 2018, icon = "Interface\\Icons\\Trade_BlackSmithing", names = { "Blacksmithing", "Кузнечное дело" } },
	{ key = "enchanting", spell = 7411, icon = "Interface\\Icons\\Trade_Engraving", names = { "Enchanting", "Наложение чар" } },
	{ key = "engineering", spell = 4036, icon = "Interface\\Icons\\Trade_Engineering", names = { "Engineering", "Инженерное дело" } },
	{ key = "herbalism", spell = 2366, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", names = { "Herbalism", "Травничество" } },
	{ key = "leatherworking", spell = 2108, icon = "Interface\\Icons\\Trade_LeatherWorking", names = { "Leatherworking", "Кожевничество" } },
	{ key = "mining", spell = 2575, icon = "Interface\\Icons\\Trade_Mining", names = { "Mining", "Горное дело" } },
	{ key = "skinning", spell = 8613, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", names = { "Skinning", "Снятие шкур" } },
	{ key = "tailoring", spell = 3908, icon = "Interface\\Icons\\Trade_Tailoring", names = { "Tailoring", "Портняжное дело" } },
	{ key = "cooking", spell = 2550, icon = "Interface\\Icons\\INV_Misc_Food_15", names = { "Cooking", "Кулинария" }, secondary = true },
	{ key = "firstaid", spell = 3273, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", names = { "First Aid", "Первая помощь" }, secondary = true },
	{ key = "fishing", spell = 7620, icon = "Interface\\Icons\\Trade_Fishing", names = { "Fishing", "Рыбная ловля" }, secondary = true },
}

local BY_NAME = {}
for _, p in ipairs(D.PROFS) do
	for _, n in ipairs(p.names) do
		BY_NAME[n:lower()] = p
	end
end

-- The rank you are trained up to: Apprentice 75, Journeyman 150,
-- Expert 225, Artisan 300.
function D.Tier(maxRank)
	if type(maxRank) ~= "number" then
		return nil
	end
	if maxRank >= 300 then
		return T("Artisan")
	elseif maxRank >= 225 then
		return T("Expert")
	elseif maxRank >= 150 then
		return T("Journeyman")
	elseif maxRank >= 1 then
		return T("Apprentice")
	end
	return nil
end

-- lines: { {name=, header=, rank=, max=, icon=, known=} }, from the
-- profession API (known = true: it is a profession even if the name is
-- not in our list) and from the skill window. The same profession is
-- kept once. Main professions first, then secondary; higher rank first.
function D.Professions(lines)
	local out, seen = {}, {}
	for _, l in ipairs(lines or {}) do
		local name = type(l.name) == "string" and l.name ~= "" and l.name
		local p = name and not l.header and BY_NAME[name:lower()]
		if name and not l.header and (p or l.known) and type(l.rank) == "number" then
			local key = p and p.key or name:lower()
			if not seen[key] then
				seen[key] = true
				local icon = l.icon
				if type(icon) ~= "number" and type(icon) ~= "string" then
					icon = nil
				end
				out[#out + 1] = {
					key = key,
					name = name,
					rank = l.rank,
					max = l.max,
					tier = D.Tier(l.max),
					icon = icon or (p and p.icon),
					spell = not icon and p and p.spell or nil,
					secondary = (p and p.secondary) or l.secondary or false,
				}
			end
		end
	end
	table.sort(out, function(a, b)
		if a.secondary ~= b.secondary then
			return not a.secondary
		end
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.key < b.key
	end)
	return out
end

------------------------------------------------------------------------
-- Small formatting helpers
------------------------------------------------------------------------

function D.Played(seconds)
	if type(seconds) ~= "number" or seconds < 0 then
		return nil
	end
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if d > 0 then
		return string.format(T("%dd %dh"), d, h)
	elseif h > 0 then
		return string.format(T("%dh %dm"), h, m)
	end
	return string.format(T("%dm"), m)
end

-- tabs: { {name=, points=} } -> { text = "0/21/12", spec = "Protection" }
function D.Talents(tabs)
	if type(tabs) ~= "table" or #tabs == 0 then
		return nil
	end
	local parts, best, total = {}, nil, 0
	for i, t in ipairs(tabs) do
		local p = type(t.points) == "number" and t.points or 0
		parts[i] = tostring(p)
		total = total + p
		if not best or p > best.points then
			best = { name = t.name, points = p, icon = t.icon }
		end
	end
	if total == 0 then
		return nil
	end
	return { text = table.concat(parts, "/"), spec = best.name, icon = best.icon }
end

-- items: { {name=, quality=, ilvl=, icon=} } -> the proudest one
function D.BestItem(items)
	local best
	for _, it in ipairs(items or {}) do
		local q, l = it.quality or 0, it.ilvl or 0
		if q >= 2 and (not best or q > best.quality or (q == best.quality and l > (best.ilvl or 0))) then
			best = it
		end
	end
	return best
end

function D.AverageItemLevel(items)
	local sum, n = 0, 0
	for _, it in ipairs(items or {}) do
		if type(it.ilvl) == "number" and it.ilvl > 0 then
			sum, n = sum + it.ilvl, n + 1
		end
	end
	if n == 0 then
		return nil
	end
	return math.floor(sum / n + 0.5)
end

function D.Money(copper)
	if type(copper) ~= "number" then
		return nil
	end
	local g = math.floor(copper / 10000)
	local s = math.floor(copper % 10000 / 100)
	if g > 0 then
		return string.format(T("%dg %ds"), g, s)
	end
	return string.format(T("%ds %dc"), s, copper % 100)
end

-- Money with the game's coin icons (12 [g] 34 [s]); plain text without them.
function D.Coins(copper)
	if type(copper) ~= "number" then
		return nil
	end
	if type(GetCoinTextureString) == "function" then
		-- copper is left out when there is gold: it is noise on a card
		local shown = copper >= 10000 and copper - copper % 100 or copper
		local ok, s = pcall(GetCoinTextureString, shown)
		if ok and type(s) == "string" and s ~= "" then
			return s
		end
	end
	return D.Money(copper)
end

-- How far the camera stands from the hero in each format: the hero is
-- shown about 20% smaller than the game's own framing so the head, the
-- weapon and the feet are never cut by the edge of the hero's frame.
D.HERO_ZOOM = { story = 1.25, post = 1.25, square = 1.25, wide = 1.25 }

function D.HeroZoom(key)
	return D.HERO_ZOOM[key] or 1
end

-- Item quality from the colour of a link (when the item is not cached yet).
D.QUALITY_BY_COLOR = {
	ff9d9d9d = 0, ffffffff = 1, ff1eff00 = 2, ff0070dd = 3, ffa335ee = 4, ffff8000 = 5, ffe6cc80 = 6,
}

function D.ItemID(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%d+)"))
end

-- An item you chose for the card, from its link. pending = the game has
-- not sent the item's details yet (GET_ITEM_INFO_RECEIVED comes later).
function D.ItemFromLink(link)
	local id = D.ItemID(link)
	if not id then
		return nil
	end
	local name, _, quality, ilvl, _, _, _, _, _, icon = D.Call(GetItemInfo, link)
	local pending = name == nil
	if C_Item and C_Item.GetDetailedItemLevelInfo then
		local l = D.Call(C_Item.GetDetailedItemLevelInfo, link)
		if type(l) == "number" and l > 0 then
			ilvl = l
		end
	end
	if not icon then
		icon = (C_Item and D.Call(C_Item.GetItemIconByID, id)) or D.Call(GetItemIcon, id)
	end
	if type(quality) ~= "number" then
		local color = link:match("|c(%x%x%x%x%x%x%x%x)")
		quality = color and D.QUALITY_BY_COLOR[color:lower()] or 1
	end
	return {
		name = name or link:match("%[(.-)%]"),
		quality = quality,
		ilvl = type(ilvl) == "number" and ilvl > 0 and ilvl or nil,
		icon = icon,
		link = link,
		id = id,
		pending = pending,
		chosen = true,
	}
end

-- "1,234" with a separator for long numbers
function D.Number(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Icons on the stat plaques (the talents plaque uses your main tree's icon).
D.ICONS = {
	talents = "Interface\\Icons\\INV_Misc_Book_11",
	played = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	quests = "Interface\\GossipFrame\\AvailableQuestIcon",
	ilvl = "Interface\\Icons\\INV_Chest_Chain_05",
	pvp = "Interface\\Icons\\INV_BannerPVP_01",
	gold = "Interface\\Icons\\INV_Misc_Coin_01",
}

-- Stat tiles in the order they are shown; only what is known and switched on.
function D.Stats(data, show)
	show = show or {}
	local out = {}
	local function Add(key, label, value, sub, icon)
		if show[key] ~= false and value then
			out[#out + 1] = { key = key, label = label, value = value, sub = sub, icon = icon or D.ICONS[key] }
		end
	end
	Add("talents", T("Talents"), data.talents and data.talents.text, data.talents and data.talents.spec, data.talents and data.talents.icon)
	Add("played", T("Played"), data.played and D.Played(data.played) or (data.playedPending and "…"), nil)
	Add("steps", T("Steps"), data.steps and D.Spaced(data.steps.today), data.steps and string.format(T("%s all time"), D.Spaced(data.steps.total)))
	Add("quests", T("Quests done"), data.quests and D.Number(data.quests), nil)
	Add("ilvl", T("Item level"), data.ilvl and tostring(data.ilvl), T("average"))
	Add("pvp", T("PvP rank"), data.pvp, nil, data.faction == "Alliance" and "Interface\\Icons\\INV_BannerPVP_02" or nil)
	-- off unless switched on (they also fill an empty cell, see D.Fillers)
	if show.hk == true then
		Add("hk", T("Honorable kills"), data.hk and D.Number(data.hk), nil)
	end
	if show.rep == true then
		Add("rep", T("Reputation"), data.rep and data.rep.standing, data.rep and data.rep.name)
	end
	if show.gold == true then
		Add("gold", T("Gold"), data.money and D.Coins(data.money), nil)
	end
	return out
end

-- Plaques that may fill an empty cell in the last row: the optional ones
-- you never switched on or off (show[key] == nil) that have data. Gold is
-- never added by itself.
D.FILLERS = { "hk", "rep" }

function D.Fillers(data, show, need)
	local out = {}
	for _, key in ipairs(D.FILLERS) do
		if #out >= need then
			break
		end
		if show[key] == nil then
			local try = {}
			for k, v in pairs(show) do
				try[k] = v
			end
			try[key] = true
			local t = D.Stats(data, try)
			for _, tile in ipairs(t) do
				if tile.key == key then
					tile.filler = true
					out[#out + 1] = tile
				end
			end
		end
	end
	return out
end

-- Percent of the way to the next level (nil at max level).
function D.XPPercent(data)
	if data.level and data.maxLevel and data.level >= data.maxLevel then
		return nil
	end
	if type(data.xp) ~= "number" or type(data.xpMax) ~= "number" or data.xpMax <= 0 then
		return nil
	end
	return math.floor(data.xp / data.xpMax * 100)
end

-- Profession ranks that are worth a card: every tier, and the cap.
D.MILESTONES = { 75, 150, 225, 300 }

function D.Milestone(old, new)
	if type(old) ~= "number" or type(new) ~= "number" or new <= old then
		return nil
	end
	local hit
	for _, m in ipairs(D.MILESTONES) do
		if old < m and new >= m then
			hit = m
		end
	end
	return hit
end

------------------------------------------------------------------------
-- Reading the game
------------------------------------------------------------------------

local function Secret(v)
	return issecretvalue and issecretvalue(v) or false
end

local unpack = unpack or table.unpack

local function Pack(...)
	return { n = select("#", ...), ... }
end

-- Calls a game function safely: nil when it is missing or fails, and
-- secret values come back as nil.
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local r = Pack(pcall(fn, ...))
	if not r[1] then
		return nil
	end
	for i = 2, r.n do
		if Secret(r[i]) then
			r[i] = nil
		end
	end
	return unpack(r, 2, r.n)
end
D.Call = Call

-- The modern profession API (GetProfessions), when the client has it.
local function ProfessionLines()
	local out = {}
	if not (GetProfessions and GetProfessionInfo) then
		return out
	end
	local idx = Pack(Call(GetProfessions))
	for i = 1, idx.n do
		if type(idx[i]) == "number" then
			local name, icon, rank, max = Call(GetProfessionInfo, idx[i])
			if type(name) == "string" then
				out[#out + 1] = { name = name, icon = icon, rank = rank, max = max, known = true }
			end
		end
	end
	return out
end

-- The skill window. Collapsed headers hide their lines, so they are
-- opened for the read and closed again (from the bottom up, so the
-- indexes above stay right).
D.readAt = nil -- GetTime() of our last read: its SKILL_LINES_CHANGED is ours

local function SkillLines()
	local out = {}
	if not (GetNumSkillLines and GetSkillLineInfo) then
		return out
	end
	local opened = {}
	if ExpandSkillHeader then
		for i = (Call(GetNumSkillLines) or 0), 1, -1 do
			local name, header, expanded = Call(GetSkillLineInfo, i)
			if header and not expanded and type(name) == "string" then
				opened[name] = true
				Call(ExpandSkillHeader, i)
			end
		end
	end
	for i = 1, (Call(GetNumSkillLines) or 0) do
		local name, header, _, rank, _, _, max = Call(GetSkillLineInfo, i)
		out[#out + 1] = { name = name, header = header, rank = rank, max = max }
	end
	if next(opened) and CollapseSkillHeader then
		for i = (Call(GetNumSkillLines) or 0), 1, -1 do
			local name, header = Call(GetSkillLineInfo, i)
			if header and opened[name] then
				Call(CollapseSkillHeader, i)
			end
		end
		D.readAt = Call(GetTime)
	end
	return out
end

function D.ReadProfessions()
	local lines = ProfessionLines()
	for _, l in ipairs(SkillLines()) do
		lines[#lines + 1] = l
	end
	return D.Professions(lines)
end

-- Points spent in one tree, from its talents (when the tree info has no count).
local function TreePoints(tab)
	local sum = 0
	for t = 1, (Call(GetNumTalents, tab) or 0) do
		local r = Pack(Call(GetTalentInfo, tab, t))
		-- name, icon, tier, column, rank, maxRank, ...
		if type(r[5]) == "number" then
			sum = sum + r[5]
		end
	end
	return sum
end

-- Talent trees. GetTalentTabInfo has two shapes:
--   id, name, description, icon, pointsSpent, ...   (newer clients)
--   name, icon, pointsSpent, ...                    (older clients)
function D.ReadTalentTab(r)
	if type(r[1]) == "number" and type(r[2]) == "string" then
		return r[2], r[4], type(r[5]) == "number" and r[5] or nil
	elseif type(r[1]) == "string" then
		return r[1], r[2], type(r[3]) == "number" and r[3] or nil
	end
	return nil
end

-- When the tree info gives nothing: the spec from the specialization API
-- and the points spent from the level and the points left.
function D.SpecTalents(level)
	local name, icon
	local spec = Call(GetSpecialization) or (C_SpecializationInfo and Call(C_SpecializationInfo.GetSpecialization))
	if type(spec) == "number" and spec > 0 then
		local r = Pack(Call(GetSpecializationInfo, spec))
		if r.n < 2 and C_SpecializationInfo then
			r = Pack(Call(C_SpecializationInfo.GetSpecializationInfo, spec))
		end
		name, icon = r[2], r[4]
	end
	local unspent = Call(UnitCharacterPoints, "player")
	local spent = type(unspent) == "number" and type(level) == "number" and math.max(0, level - 9 - unspent) or nil
	if type(name) ~= "string" and not (spent and spent > 0) then
		return nil
	end
	local spec = type(name) == "string" and name or nil
	return {
		text = spent and tostring(spent) or spec,
		spec = spent and spec or nil,
		icon = icon,
	}
end

-- Lifetime honorable kills (nil when none).
function D.HonorKills()
	local hk = Call(GetPVPLifetimeStats)
	if type(hk) == "number" and hk > 0 then
		return hk
	end
	return nil
end

-- The faction you stand best with: { name, standing (text), id }.
function D.BestFaction(list)
	local best
	for _, f in ipairs(list or {}) do
		if not f.header and type(f.standing) == "number" and type(f.name) == "string" then
			if not best or f.standing > best.standing or (f.standing == best.standing and (f.value or 0) > (best.value or 0)) then
				best = f
			end
		end
	end
	return best
end

function D.BestReputation()
	local list = {}
	if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
		for i = 1, (Call(C_Reputation.GetNumFactions) or 0) do
			local f = Call(C_Reputation.GetFactionDataByIndex, i)
			if type(f) == "table" then
				list[#list + 1] = { name = f.name, standing = f.reaction, value = f.currentStanding, header = f.isHeader and not f.isHeaderWithRep }
			end
		end
	elseif GetNumFactions and GetFactionInfo then
		for i = 1, (Call(GetNumFactions) or 0) do
			local name, _, standing, _, _, value, _, _, header, _, hasRep = Call(GetFactionInfo, i)
			list[#list + 1] = { name = name, standing = standing, value = value, header = header and not hasRep }
		end
	end
	local best = D.BestFaction(list)
	if not best then
		return nil
	end
	local label = _G["FACTION_STANDING_LABEL" .. best.standing]
	return { name = best.name, standing = type(label) == "string" and label or tostring(best.standing), id = best.standing }
end

-- The three trees with every talent: name, icon, tier, column, rank,
-- max rank, and the talent it needs (tier, column) when there is one.
function D.ReadTrees()
	local trees = {}
	for i = 1, (Call(GetNumTalentTabs) or 0) do
		local r = Pack(Call(GetTalentTabInfo, i))
		local name, icon, points = D.ReadTalentTab(r)
		local bg
		if type(r[1]) == "number" then
			bg = r[6]
		else
			bg = r[4]
		end
		local tree = { name = name, icon = icon, points = 0, bg = type(bg) == "string" and bg or nil, talents = {}, tiers = 0, cols = 0 }
		for t = 1, (Call(GetNumTalents, i) or 0) do
			local tr = Pack(Call(GetTalentInfo, i, t))
			local tier, col, rank, max = tr[3], tr[4], tr[5], tr[6]
			if type(tier) == "number" and type(col) == "number" then
				local talent = { name = tr[1], icon = tr[2], tier = tier, col = col, rank = type(rank) == "number" and rank or 0, max = type(max) == "number" and max or 1 }
				local pq = Pack(Call(GetTalentPrereqs, i, t))
				if type(pq[1]) == "number" and type(pq[2]) == "number" then
					talent.need = { pq[1], pq[2] }
				end
				tree.talents[#tree.talents + 1] = talent
				tree.points = tree.points + talent.rank
				tree.tiers = math.max(tree.tiers, tier)
				tree.cols = math.max(tree.cols, col)
			end
		end
		if type(points) == "number" and points > tree.points then
			tree.points = points
		end
		if type(name) == "string" then
			trees[#trees + 1] = tree
		end
	end
	return trees
end

-- The tree with the most points (nil when none has any).
function D.MainTree(trees)
	local best
	for i, t in ipairs(trees or {}) do
		if t.points > 0 and (not best or t.points > trees[best].points) then
			best = i
		end
	end
	return best
end

local function TalentTabs()
	local out, total = {}, 0
	for i = 1, (Call(GetNumTalentTabs) or 0) do
		local name, icon, points = D.ReadTalentTab(Pack(Call(GetTalentTabInfo, i)))
		if type(name) == "string" then
			points = points or TreePoints(i)
			total = total + points
			out[#out + 1] = { name = name, icon = icon, points = points }
		end
	end
	if total == 0 then
		-- some clients report 0 in the tree info: count the talents instead
		for i, t in ipairs(out) do
			t.points = TreePoints(i)
		end
	end
	return out
end

-- Raw answers of the game, for /herogram debug.
function D.DebugLines()
	local out = {}
	local function Join(r)
		local parts = {}
		for i = 1, r.n do
			parts[i] = tostring(r[i])
		end
		return table.concat(parts, ", ")
	end
	local function Has(name)
		return type(_G[name]) == "function" and "yes" or "no"
	end
	local function Raw(label, fn, ...)
		if type(fn) == "function" then
			out[#out + 1] = label .. ": " .. Join(Pack(pcall(fn, ...)))
		else
			out[#out + 1] = label .. ": (no such function)"
		end
	end
	Raw("UnitName", UnitName, "player")
	Raw("UnitNameUnmodified", UnitNameUnmodified, "player")
	Raw("UnitFullName", UnitFullName, "player")
	Raw("GetUnitName(player, true)", GetUnitName, "player", true)
	Raw("RegionalUniqueNamesEnabled", RegionalUniqueNamesEnabled)
	Raw("GetRealmName", GetRealmName)
	local guid = Call(UnitGUID, "player")
	Raw("GetPlayerInfoByGUID", GetPlayerInfoByGUID, guid)
	out[#out + 1] = "Herogram shows the name: " .. D.FullName()
	out[#out + 1] = "GetProfessions " .. Has("GetProfessions") .. ", GetNumSkillLines " .. Has("GetNumSkillLines") .. ", GetNumTalentTabs " .. Has("GetNumTalentTabs") .. ", GetTalentInfo " .. Has("GetTalentInfo")
	if GetProfessions then
		local idx = Pack(pcall(GetProfessions))
		out[#out + 1] = "GetProfessions: " .. Join(idx)
		for i = 2, idx.n do
			if type(idx[i]) == "number" and GetProfessionInfo then
				out[#out + 1] = "  GetProfessionInfo(" .. idx[i] .. "): " .. Join(Pack(pcall(GetProfessionInfo, idx[i])))
			end
		end
	end
	if GetNumSkillLines then
		local n = Pack(pcall(GetNumSkillLines))
		out[#out + 1] = "GetNumSkillLines: " .. Join(n)
		for i = 1, math.min(type(n[2]) == "number" and n[2] or 0, 30) do
			local r = Pack(pcall(GetSkillLineInfo, i))
			out[#out + 1] = "  " .. i .. ": " .. Join({ n = math.min(r.n, 8), unpack(r, 1, 8) })
		end
	end
	if GetNumTalentTabs then
		out[#out + 1] = "GetNumTalentTabs: " .. Join(Pack(pcall(GetNumTalentTabs)))
		for i = 1, 3 do
			out[#out + 1] = "  GetTalentTabInfo(" .. i .. "): " .. Join(Pack(pcall(GetTalentTabInfo, i)))
		end
		if GetNumTalents then
			for tab = 1, 3 do
				out[#out + 1] = "  GetNumTalents(" .. tab .. "): " .. Join(Pack(pcall(GetNumTalents, tab)))
				for t = 1, 3 do
					out[#out + 1] = "    GetTalentInfo(" .. tab .. ", " .. t .. "): " .. Join(Pack(pcall(GetTalentInfo, tab, t)))
				end
			end
			if GetTalentPrereqs then
				for t = 1, 8 do
					local r = Pack(pcall(GetTalentPrereqs, 1, t))
					if r.n > 1 then
						out[#out + 1] = "  GetTalentPrereqs(1, " .. t .. "): " .. Join(r)
					end
				end
			end
		end
		local trees = D.ReadTrees()
		local parts = {}
		for _, t in ipairs(trees) do
			parts[#parts + 1] = tostring(t.name) .. " " .. t.points .. " (" .. #t.talents .. " talents, " .. t.tiers .. "x" .. t.cols .. ", bg " .. tostring(t.bg) .. ")"
		end
		out[#out + 1] = "  trees: " .. (#parts > 0 and table.concat(parts, "; ") or "none")
	end
	local function Has2(name)
		return type(_G[name]) == "function" and "yes" or "no"
	end
	out[#out + 1] = "GetSpecialization " .. Has2("GetSpecialization") .. ", UnitCharacterPoints " .. Has2("UnitCharacterPoints") .. ", C_SpecializationInfo " .. (C_SpecializationInfo and "yes" or "no") .. ", C_ClassTalents " .. (C_ClassTalents and "yes" or "no")
	if GetSpecialization then
		out[#out + 1] = "  GetSpecialization: " .. Join(Pack(pcall(GetSpecialization)))
	end
	if UnitCharacterPoints then
		out[#out + 1] = "  UnitCharacterPoints: " .. Join(Pack(pcall(UnitCharacterPoints, "player")))
	end
	out[#out + 1] = "  GetPVPLifetimeStats: " .. (GetPVPLifetimeStats and Join(Pack(pcall(GetPVPLifetimeStats))) or "no")
	local rep = D.BestReputation()
	out[#out + 1] = "  best reputation: " .. (rep and (tostring(rep.name) .. " " .. tostring(rep.standing)) or "none")
	local p = D.ReadProfessions()
	out[#out + 1] = "Herogram reads " .. #p .. " professions; talents: " .. tostring(D.Talents(TalentTabs()) and D.Talents(TalentTabs()).text)
	return out
end

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function Items()
	local out = {}
	for _, slot in ipairs(SLOTS) do
		local link = Call(GetInventoryItemLink, "player", slot)
		if type(link) == "string" then
			local name = link:match("%[(.-)%]")
			local quality = Call(GetInventoryItemQuality, "player", slot)
			local ilvl = C_Item and Call(C_Item.GetDetailedItemLevelInfo, link)
			if type(ilvl) ~= "number" then
				ilvl = select(4, Call(GetItemInfo, link))
			end
			out[#out + 1] = {
				name = name,
				quality = type(quality) == "number" and quality or 1,
				ilvl = type(ilvl) == "number" and ilvl or nil,
				icon = Call(GetInventoryItemTexture, "player", slot),
				slot = slot,
			}
		end
	end
	return out
end

local function QuestCount()
	if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
		local ids = Call(C_QuestLog.GetAllCompletedQuestIDs)
		if type(ids) == "table" then
			return #ids
		end
	end
	local done = Call(GetQuestsCompleted)
	if type(done) == "table" then
		local n = 0
		for _ in pairs(done) do
			n = n + 1
		end
		return n
	end
	return nil
end

local function PvPRank()
	local rank = Call(UnitPVPRank, "player")
	if type(rank) == "number" and rank >= 5 then
		local name = Call(GetPVPRankInfo, rank)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return nil
end

-- The name as the game shows it. With regional unique names (WoW
-- Forever) a character has a surname: UnitNameUnmodified returns
-- "Saz", "Zy" and the game shows "Saz Zy" (Ace3 builds its keys the
-- same way). Other sources are tried too; the longest one that starts
-- with the plain name wins. "Name-Realm" never counts as a surname.
function D.PickName(base, candidates, realm)
	if type(base) ~= "string" or base == "" then
		return "?"
	end
	local realmKey = type(realm) == "string" and realm:gsub("[%s%-]", ""):lower() or nil
	local best = base
	for _, c in ipairs(candidates or {}) do
		if type(c) == "string" and c:sub(1, #base) == base and #c > #base then
			local rest = c:sub(#base + 1):gsub("^[%s%-]+", "")
			if rest ~= "" and rest:gsub("[%s%-]", ""):lower() ~= realmKey then
				local full = base .. " " .. rest
				if #full > #best then
					best = full
				end
			end
		end
	end
	return best
end

function D.FullName()
	local base, second = Call(UnitName, "player")
	if type(base) ~= "string" then
		return "?"
	end
	local list = {}
	local function Pair(a, b)
		if type(a) == "string" and type(b) == "string" and b ~= "" then
			list[#list + 1] = a .. " " .. b
		end
	end
	Pair(Call(UnitNameUnmodified, "player"))
	local unique = RegionalUniqueNamesEnabled and Call(RegionalUniqueNamesEnabled)
	if unique then
		Pair(base, second)
	end
	list[#list + 1] = Call(GetUnitName, "player", true)
	Pair(Call(UnitFullName, "player"))
	return D.PickName(base, list, Call(GetRealmName))
end

------------------------------------------------------------------------
-- Steps: a pedometer like AFK Gains. With AFK Gains installed its own
-- count is shown (AFKGainsDB.steps); without it Herogram counts the same
-- way: steps on foot only (no mount, no flight), 1.2 per yard walking,
-- 0.55 running (faster than 4.5 yd/s), a single tap is one step.
------------------------------------------------------------------------

-- Herogram was called Herald: its settings (HeraldDB) move over once,
-- when Herogram has none of its own yet. tools/migrate-settings.sh puts
-- the old file where the game loads it.
function D.Migrate()
	if type(HeraldDB) ~= "table" then
		return false
	end
	local fresh = type(HerogramDB) ~= "table" or (HerogramDB.format == nil and next(type(HerogramDB.chars) == "table" and HerogramDB.chars or {}) == nil)
	if fresh then
		HerogramDB = HeraldDB
	end
	HeraldDB = nil
	return fresh
end

D.WALK_PER_YARD = 0.9144 / 0.762
D.RUN_PER_YARD = 0.9144 / 1.65
D.RUN_SPEED = 4.5

function D.StepsFor(yards, speed)
	return yards * ((speed or 0) > D.RUN_SPEED and D.RUN_PER_YARD or D.WALK_PER_YARD)
end

-- "4 210"
function D.Spaced(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

function D.Today()
	return date and date("%Y-%m-%d") or "?"
end

-- { today, total } from a step store; today is 0 when the store's day is over.
function D.StepsOf(store, today)
	if type(store) ~= "table" or type(store.total) ~= "number" then
		return nil
	end
	local t = store.day == today and type(store.today) == "number" and store.today or 0
	return { today = math.floor(t), total = math.floor(store.total) }
end

function D.AFKGains()
	return type(AFKGainsDB) == "table" and type(AFKGainsDB.steps) == "table" and AFKGainsDB.steps or nil
end

-- Herogram's own count, per character.
function D.StepStore()
	D.Migrate()
	HerogramDB = type(HerogramDB) == "table" and HerogramDB or {}
	HerogramDB.chars = type(HerogramDB.chars) == "table" and HerogramDB.chars or {}
	local key = (Call(UnitName, "player") or "?") .. "-" .. (Call(GetRealmName) or "?")
	local ch = type(HerogramDB.chars[key]) == "table" and HerogramDB.chars[key] or {}
	HerogramDB.chars[key] = ch
	local s = type(ch.steps) == "table" and ch.steps or { today = 0, total = 0 }
	ch.steps = s
	local today = D.Today()
	if s.day ~= today then
		s.day, s.today = today, 0
	end
	return s
end

function D.ReadSteps()
	local afk = D.AFKGains()
	if afk then
		return D.StepsOf(afk, D.Today())
	end
	return D.StepsOf(D.StepStore(), D.Today())
end

function D.AddSteps(n)
	if not n or n <= 0 then
		return
	end
	local s = D.StepStore()
	s.today = s.today + n
	s.total = (s.total or 0) + n
end

function D.OnFoot()
	return not Call(UnitOnTaxi, "player") and not Call(IsMounted)
end

D.move = nil -- one stretch of movement

function D.StepTick(dt)
	if D.AFKGains() then
		return -- AFK Gains counts
	end
	local speed = Call(GetUnitSpeed, "player")
	if type(speed) ~= "number" or speed <= 0 or not D.OnFoot() then
		return
	end
	local n = D.StepsFor(speed * dt, speed)
	if D.move then
		D.move.steps = D.move.steps + n
	end
	D.AddSteps(n)
end

function D.StepStarted()
	D.move = { steps = 0 }
end

function D.StepStopped()
	local mv = D.move
	D.move = nil
	if mv and mv.steps < 1 and not D.AFKGains() and D.OnFoot() then
		D.AddSteps(1 - mv.steps) -- a single tap is one step
	end
end

if CreateFrame then
	local driver = CreateFrame("Frame")
	local acc = 0
	driver:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + (elapsed or 0)
		if acc < 0.1 then
			return
		end
		local dt = acc
		acc = 0
		D.StepTick(dt)
	end)
	driver:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_STARTED_MOVING" then
			D.StepStarted()
		else
			D.StepStopped()
		end
	end)
	pcall(driver.RegisterEvent, driver, "PLAYER_STARTED_MOVING")
	pcall(driver.RegisterEvent, driver, "PLAYER_STOPPED_MOVING")
end

D.played = nil -- seconds, from TIME_PLAYED_MSG
D.playedAt = nil -- GetTime() when it came

function D.Collect()
	local data = {}
	data.name = D.FullName()
	data.level = Call(UnitLevel, "player") or 1
	data.maxLevel = Call(GetMaxPlayerLevel) or 60
	data.xp = Call(UnitXP, "player")
	data.xpMax = Call(UnitXPMax, "player")
	data.race = Call(UnitRace, "player")
	local className, classFile = Call(UnitClass, "player")
	data.class, data.classFile = className, classFile
	local faction, factionName = Call(UnitFactionGroup, "player")
	data.faction, data.factionName = faction, factionName or faction
	data.guild = Call(GetGuildInfo, "player")
	data.realm = Call(GetRealmName)
	data.profs = D.ReadProfessions()
	data.talents = (data.level or 0) >= 10 and (D.Talents(TalentTabs()) or D.SpecTalents(data.level)) or nil
	data.hk = D.HonorKills()
	data.trees = D.ReadTrees()
	data.rep = D.BestReputation()
	local items = Items()
	data.best = D.BestItem(items)
	data.ilvl = D.AverageItemLevel(items)
	data.quests = QuestCount()
	data.money = Call(GetMoney)
	data.pvp = PvPRank()
	if D.played then
		local now = Call(GetTime)
		local since = (now and D.playedAt) and math.max(0, now - D.playedAt) or 0
		data.steps = D.ReadSteps()
	data.played = D.played + since
	end
	data.playedPending = D.played == nil
	return data
end
