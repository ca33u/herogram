-- Herogram logic outside the game: lua tests/core_test.lua
dofile("tests/stubs.lua")
LoadFile("Locale.lua")
LoadFile("Data.lua")
LoadFile("Card.lua")
LoadFile("Studio.lua")
LoadFile("Minimap.lua")
local D, C, S = NS.Data, NS.Card, NS.Studio

-- professions
local profs = D.Professions({
	{ name = "Professions", header = true },
	{ name = "Skinning", rank = 210, max = 225 },
	{ name = "Leatherworking", rank = 187, max = 225 },
	{ name = "Cooking", rank = 290, max = 300 },
	{ name = "Swords", rank = 165, max = 165 },
	{ name = "Leatherworking", rank = 1, max = 75 },
})
Check(#profs == 3, "professions: weapon skills, headers and repeats are left out")
Check(profs[1].key == "skinning" and profs[2].key == "leatherworking" and profs[2].rank == 187, "main professions first, higher rank first")
Check(profs[3].key == "cooking" and profs[3].secondary, "secondary professions come last")
local ru = D.Professions({ { name = "Кожевничество", rank = 1, max = 75 } })
Check(ru[1] and ru[1].key == "leatherworking", "Russian names are recognised")
Check(profs[1].tier == "Expert" and D.Tier(300) == "Artisan" and D.Tier(75) == "Apprentice" and D.Tier(150) == "Journeyman", "tiers by trained rank")
Check(D.Tier(nil) == nil and #D.Professions(nil) == 0, "nothing known: nothing shown")

-- formatting
Check(D.Played(4 * 86400 + 7 * 3600 + 50) == "4d 7h", "played: days and hours")
Check(D.Played(3 * 3600 + 12 * 60) == "3h 12m", "played: hours and minutes")
Check(D.Played(59) == "0m" and D.Played(nil) == nil, "played: under a minute, unknown")
local tal = D.Talents({ { name = "Holy", points = 0 }, { name = "Protection", points = 21 }, { name = "Retribution", points = 5 } })
Check(tal.text == "0/21/5" and tal.spec == "Protection", "talents: points per tree and the main one")
Check(D.Talents({ { name = "Holy", points = 0 } }) == nil and D.Talents({}) == nil, "no talent points: no tile")
local best = D.BestItem({ { name = "a", quality = 1, ilvl = 60 }, { name = "b", quality = 3, ilvl = 30 }, { name = "c", quality = 3, ilvl = 35 }, { name = "d", quality = 2, ilvl = 50 } })
Check(best.name == "c", "best item: highest quality, then item level")
Check(D.BestItem({ { quality = 1, ilvl = 40 } }) == nil, "white items are not worth showing")
Check(D.AverageItemLevel({ { ilvl = 30 }, { ilvl = 35 }, {} }) == 33 and D.AverageItemLevel({}) == nil, "average item level")
Check(D.Money(1234567) == "123g 45s" and D.Money(4521) == "45s 21c", "money")
Check(D.Number(1234567) == "1,234,567" and D.Number(312) == "312", "thousands separator")
Check(D.XPPercent({ level = 33, maxLevel = 60, xp = 31000, xpMax = 50000 }) == 62, "xp percent")
Check(D.XPPercent({ level = 60, maxLevel = 60, xp = 0, xpMax = 1 }) == nil, "max level: no percent")
Check(D.Milestone(220, 226) == 225 and D.Milestone(74, 300) == 300, "profession milestones")
Check(D.Milestone(226, 230) == nil and D.Milestone(nil, 75) == nil and D.Milestone(80, 75) == nil, "no milestone without crossing one")

-- the hero is placed by the camera inside a model frame over the whole card
local l, r, t, b = C.HeroInsets(450, 800, { 90, 170, 270, 340 }, 4)
Check(l == 86 and r == 86 and t == 166 and b == 286, "hero region as view insets of a card-sized model frame")
Check(C.InHero(100, 200, { 90, 170, 270, 340 }) and not C.InHero(20, 200, { 90, 170, 270, 340 }) and not C.InHero(1, 1, nil), "drags start only on the hero")

-- steps
Check(math.abs(D.StepsFor(100, 3) - 120) < 0.1 and math.abs(D.StepsFor(100, 7) - 55.4) < 0.1, "steps per yard: walking and running")
Check(D.Spaced(4210) == "4 210" and D.Spaced(312450) == "312 450" and D.Spaced(7) == "7", "steps with a space every 3 digits")
local st = D.StepsOf({ day = "12 Nov 2026", today = 4210.7, total = 312450.2 }, "12 Nov 2026")
Check(st.today == 4210 and st.total == 312450, "steps of today")
Check(D.StepsOf({ day = "11 Nov 2026", today = 900, total = 5000 }, "12 Nov 2026").today == 0 and D.StepsOf(nil, "x") == nil, "a past day counts as 0 today")
AFKGainsDB = { steps = { day = "12 Nov 2026", today = 1500, total = 9000 } }
Check(D.ReadSteps().today == 1500 and D.ReadSteps().total == 9000, "with AFK Gains its numbers are used")
GetUnitSpeed = function() return 7 end
D.StepStarted()
D.StepTick(1)
D.StepStopped()
Check(D.ReadSteps().today == 1500, "and Herogram does not count on top of it")
AFKGainsDB = nil
HerogramDB = nil
D.StepStarted()
D.StepTick(1)
D.StepStopped()
Check(math.floor(D.ReadSteps().today) == 3 and D.ReadSteps().total == 3, "without AFK Gains Herogram counts itself (7 yd/s running for a second)")
GetUnitSpeed = function() return 0 end
D.StepStarted()
D.StepStopped()
Check(D.ReadSteps().today == 4, "a single tap is one step")
IsMounted = function() return true end
GetUnitSpeed = function() return 7 end
D.StepStarted()
D.StepTick(2)
D.StepStopped()
Check(D.ReadSteps().today == 4, "nothing counts on a mount")
IsMounted, GetUnitSpeed = nil, nil
local tilesNow = D.Stats({ steps = { today = 4210, total = 312450 } }, {})
Check(tilesNow[1].key == "steps" and tilesNow[1].value == "4 210" and tilesNow[1].sub == "312 450 all time", "steps plaque")
Check(#D.Stats({ steps = { today = 1, total = 1 } }, { steps = false }) == 0, "steps can be switched off")
HerogramDB = nil

-- the old name: Herald's settings move over once
HerogramDB, HeraldDB = nil, { format = "wide", chars = { ["Saz-R"] = { bestItem = "item:1" } } }
Check(D.Migrate() and HerogramDB.format == "wide" and HerogramDB.chars["Saz-R"].bestItem == "item:1" and HeraldDB == nil, "Herald settings become Herogram's")
HerogramDB, HeraldDB = { format = "post", chars = {} }, { format = "wide" }
Check(not D.Migrate() and HerogramDB.format == "post" and HeraldDB == nil, "Herogram's own settings are kept")
HerogramDB = nil
Check(SlashCmdList.HEROGRAM and SLASH_HEROGRAM1 == "/herogram" and SLASH_HEROGRAM2 == "/herald", "/herogram, and /herald still works")

-- talents when the tree info gives nothing, honor, reputation
GetSpecialization = function() return 2 end
GetSpecializationInfo = function() return 66, "Protection", "", 236264 end
UnitCharacterPoints = function() return 1 end
local spec = D.SpecTalents(34)
Check(spec.text == "24" and spec.spec == "Protection" and spec.icon == 236264, "talents from the spec and the points left")
UnitCharacterPoints = nil
Check(D.SpecTalents(34).text == "Protection", "only the spec known: the spec is the value")
GetSpecialization, GetSpecializationInfo = nil, nil
Check(D.SpecTalents(34) == nil, "nothing known: no talents plaque")
GetPVPLifetimeStats = function() return 123, 0, 0 end
Check(D.HonorKills() == 123, "honorable kills")
GetPVPLifetimeStats = function() return 0 end
Check(D.HonorKills() == nil, "no kills: no plaque")
GetPVPLifetimeStats = nil
local bf = D.BestFaction({ { name = "Horde", header = true, standing = 8 }, { name = "Orgrimmar", standing = 5, value = 100 }, { name = "Undercity", standing = 6, value = 50 }, { name = "Bilgewater", standing = 6, value = 900 } })
Check(bf.name == "Bilgewater", "best reputation: highest standing, then the most points")
GetNumFactions = function() return 2 end
local FACTIONS = { { "Undercity", "", 6, 0, 0, 3000, false, false, false, false, true }, { "Orgrimmar", "", 5, 0, 0, 100 } }
GetFactionInfo = function(i) return unpack(FACTIONS[i], 1, 11) end
FACTION_STANDING_LABEL6 = "Honored"
local rep = D.BestReputation()
Check(rep.name == "Undercity" and rep.standing == "Honored", "reputation from the faction list")
GetNumFactions, GetFactionInfo = nil, nil

-- an even plaque grid
local even = { talents = { text = "0/21/13", spec = "Protection" }, played = 3600, quests = 300, ilvl = 32, steps = { today = 10, total = 20 }, hk = 55, rep = { name = "Undercity", standing = "Honored" } }
local fill = D.Fillers(even, {}, 1)
Check(#fill == 1 and fill[1].key == "hk" and fill[1].filler, "an empty cell takes the first optional plaque with data")
Check(#D.Fillers(even, { hk = false, rep = false }, 2) == 0, "plaques you switched off are not added")
Check(#D.Fillers({ played = 1 }, {}, 2) == 0, "no data: nothing to add")
C.Render(even, { format = "square", show = {} })
Check(#C.frame.filled == 1 and C.frame.plan.tiles.count == 6, "Square: 5 plaques + 1 added = 2 even rows of 3")
C.Render({ played = 1, quests = 1, ilvl = 1, steps = { today = 1, total = 1 } }, { format = "square", show = {} })
Check(#C.frame.filled == 0 and C.frame.plan.tiles.count == 4, "nothing to add: the last row is stretched instead")

-- the Talents card
local function Inside(r, f)
	return r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= f.w + 0.01 and r[2] + r[4] <= f.h + 0.01
end
local function Overlap(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end
local function TreeStubs()
	local TAL = {}
	for tab = 1, 3 do
		TAL[tab] = {}
		for tier = 1, 7 do
			for col = 1, 3 do
				TAL[tab][#TAL[tab] + 1] = { "T" .. tab .. tier .. col, 1000 + tier, tier, col, (tab == 2 and tier <= 5) and 3 or 0, 5 }
			end
		end
	end
	GetNumTalents = function(tab) return TAL[tab] and #TAL[tab] or 0 end
	GetTalentInfo = function(tab, i) return unpack(TAL[tab][i], 1, 6) end
	GetTalentPrereqs = function(tab, i) if i == 4 then return 1, 1, true end end
end
TreeStubs()
local trees = D.ReadTrees()
Check(#trees == 3 and #trees[1].talents == 21 and trees[1].tiers == 7 and trees[1].cols == 3, "trees: every talent by tier and column")
Check(trees[2].points == 45 and D.MainTree(trees) == 2 and trees[1].talents[4].need[1] == 1, "points per tree, the main tree, prerequisites")
Check(D.MainTree({ { points = 0 } }) == nil, "no points: no main tree")
for _, f in ipairs(D.FORMATS) do
	local TL = D.TreeLayout(f.key)
	local plan = D.PlanTrees(f.key, 7, 4, TL.header[2] + 124)
	local ok = plan.fits and plan.cell >= 20 and Inside(plan.model, f)
	for _, t in ipairs(plan.trees) do
		local r = { t.x, t.y, t.w, plan.height }
		ok = ok and Inside(r, f) and not Overlap(r, plan.model) and t.y + plan.height <= TL.footer[2]
	end
	Check(ok, f.key .. ": three trees of 7 x 4 fit, clear of the hero and the footer (icon " .. plan.cell .. ")")
end
Check(not D.PlanTrees("wide", 40, 4, 150).fits, "a tree too tall to read is reported")
HeraldDB = nil
C.Render({ name = "X", level = 34, class = "Paladin", trees = trees, profs = {} }, { format = "square", card = "talents", show = {} })
local tt = {}
for i = 1, C.frame.pools.font.used do tt[#tt + 1] = tostring(C.frame.pools.font.list[i]._text) end
tt = table.concat(tt, "\n")
Check(C.frame.trees and #C.frame.dropped == 0 and tt:find("Talent", 1, true) == nil and tt:find("3/5", 1, true), "Talents card draws the trees with rank badges")
Check(tt:find("PROTECTION PALADIN", 1, true), "the main tree names the card")
C.Render({ name = "X", level = 34, trees = {}, profs = {} }, { format = "wide", card = "talents", show = {} })
Check(C.frame.dropped[1] and C.frame.dropped[1].key == "talents", "no trees from the game: said on the card and in the panel")
GetNumTalents, GetTalentInfo, GetTalentPrereqs = nil, nil, nil

-- frames from the game
Check(C.FrameStyle("wood").edge and C.FrameStyle("nope").key == "herogram", "frame styles")
Check(C.TextureExists("x") == nil and #C.AvailableFrames() == #C.FRAMES, "without a way to check, every frame is offered")
GetFileIDFromPath = function(path)
	if path:find("Achievement") then return nil end
	return 1234
end
local avail = {}
for _, fr in ipairs(C.AvailableFrames()) do avail[fr.key] = true end
Check(avail.herogram and avail.gold and not avail.wood, "a texture the game lacks is not offered")
C.Render({ name = "X", level = 10, profs = {}, quests = 5 }, { format = "square", frame = "wood", show = {} })
Check(C.frame.style.key == "herogram", "a missing frame falls back to ours")
C.Render({ name = "X", level = 10, profs = {}, quests = 5 }, { format = "square", frame = "gold", show = {} })
Check(C.frame.style.key == "gold" and C.frame.border:IsShown() and C.frame.pools.edge.used == 1, "a game frame: border on the card and on the plaque")
GetFileIDFromPath = nil

-- money, value fonts, hero distance
Check(D.Coins(1234567) == "123g 45s", "coins without the game's icons: plain text")
GetCoinTextureString = function(c) return "C" .. c end
Check(D.Coins(29257) == "C29200" and D.Coins(57) == "C57", "coins with icons: copper dropped when there is gold")
GetCoinTextureString = nil
Check(C.ValueFont("325") == "title" and C.ValueFont("0/21/5") == "title", "numbers in the Warcraft font")
Check(C.ValueFont("3d 13h") == "body" and C.ValueFont("2|TInterface\\MoneyFrame\\UI-GoldIcon:0|t") == "title", "letters in the plain font, coin icons do not count")
Check(D.HeroZoom("story") == 1.25 and D.HeroZoom("wide") == 1.25 and D.HeroZoom("post") == 1.25 and D.HeroZoom("square") == 1.25, "hero 20% smaller than the game's framing in every format")

-- stat tiles
local data = { talents = tal, played = 3600, quests = 1500, ilvl = 33, money = 10000, pvp = nil }
local function Keys(list)
	local out = {}
	for _, t in ipairs(list) do out[#out + 1] = t.key end
	return table.concat(out, ",")
end
Check(Keys(D.Stats(data, {})) == "talents,played,quests,ilvl", "stats: gold is off unless asked, unknown pvp skipped")
Check(Keys(D.Stats(data, { gold = true, played = false })) == "talents,quests,ilvl,gold", "stats follow the switches")
Check(D.Stats({ playedPending = true }, {})[1].value == "…", "played time still on its way")

-- formats and layouts
Check(D.Format("wide").key == "wide" and D.Format("nope").key == "story", "unknown format falls back to stories")
local function Inside(r, f)
	return r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= f.w + 0.01 and r[2] + r[4] <= f.h + 0.01
end
local function Overlap(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end
-- every block of a plan as a rectangle
local function Blocks(plan, n)
	local out, d = {}, plan.d
	if plan.profs then
		out[#out + 1] = { plan.profs.x, plan.profs.y, plan.profs.w, plan.profs.rows * d.row }
	end
	if plan.tiles then
		local rows = math.ceil(plan.tiles.count / plan.tiles.cols)
		out[#out + 1] = { plan.tiles.x, plan.tiles.y, plan.tiles.w, rows * d.tile + (rows - 1) * d.gap }
	end
	if plan.item then
		out[#out + 1] = { plan.item.x, plan.item.y, plan.item.w, d.item }
	end
	return out
end
local FULL = { profs = 4, tiles = 7, item = true }
for _, f in ipairs(D.FORMATS) do
	Check(math.abs(f.w / f.h - f.out[1] / f.out[2]) < 0.01, f.key .. ": card and export have the same shape")
	local L = D.Layout(f.key)
	Check(Inside({ L.header[1], L.header[2], L.header[3], 1 }, f) and Inside(L.footer, f), f.key .. ": header and footer inside the card")
	if L.model then
		Check(L.header[1] >= L.model[1] + L.model[3] and L.col[1] >= L.model[1] + L.model[3], f.key .. ": hero on the left, name and info in the right column")
		Check(L.model[2] <= 30 and L.model[2] + L.model[4] >= f.h - 30, f.key .. ": the hero gets the full height")
	end
	for _, n in ipairs({ FULL, { profs = 0, tiles = 0, item = false }, { profs = 2, tiles = 3, item = false } }) do
		local plan = D.PlanCard(f.key, n, D.HeaderBottom(f.key))
		local label = string.format("%s with %d professions, %d plaques%s", f.key, n.profs, n.tiles, n.item and ", item" or "")
		Check(plan.dropped.profs == 0 and plan.dropped.tiles == 0 and not plan.dropped.item, label .. ": everything fits")
		local m = plan.model
		local ok = Inside(m, f) and m[3] <= m[4] * D.MODEL_ASPECT + 0.01 and m[4] >= 200
		for _, b in ipairs(Blocks(plan, n)) do
			ok = ok and Inside(b, f) and not Overlap(b, m) and b[2] + b[4] <= L.footer[2]
		end
		Check(ok, label .. ": hero frame tall enough, blocks inside, nothing on the hero or the footer")
		Check((plan.profs and plan.profs.rows or 0) == n.profs and (plan.tiles and plan.tiles.count or 0) == n.tiles and (plan.item ~= nil) == n.item, label .. ": all placed")
	end
end
-- Stories with everything gives the hero the rest of the column
local roomy = D.PlanCard("story", { profs = 1, tiles = 0, item = false })
local busy = D.PlanCard("story", FULL)
Check(roomy.model[4] > busy.model[4] and busy.model[4] >= D.MODEL_MIN, "Stories: the hero shrinks to make room, never below the minimum")
-- Wide: plaques under the professions, not beside them
local wide = D.PlanCard("wide", FULL)
Check(wide.tiles.x == wide.profs.x and wide.tiles.y > wide.profs.y, "Wide: plaques under the professions")
-- too much: things are left out from the end, and the plan says so
local over = D.PlanCard("square", { profs = 8, tiles = 6, item = true }, nil)
Check(over.level == #D.DENSITY and over.dropped.item and over.dropped.profs == 0, "too much: tightest density, the item goes first, professions last")
local dense = D.PlanCard("square", { profs = 7, tiles = 6, item = false }, nil)
Check(dense.level > 1 and dense.dropped.tiles == 0 and dense.dropped.profs == 0, "a lot: rows get tighter instead of dropping")
Check(math.abs(D.Fit(450, 800, 1280, 720, 0.96) - 0.864) < 1e-9, "fit: limited by height")
Check(math.abs(D.Fit(800, 450, 1000, 1000, 1) - 1.25) < 1e-9, "fit: limited by width")

-- talent tree info in both shapes
local n1, i1, p1 = D.ReadTalentTab({ 101, "Holy", "desc", 135920, 7, "bg" })
local n2, i2, p2 = D.ReadTalentTab({ "Protection", "icon", 21 })
Check(n1 == "Holy" and i1 == 135920 and p1 == 7 and n2 == "Protection" and p2 == 21, "talent tree info: new and old shapes")
Check(select(3, D.ReadTalentTab({ 101, "Holy", "desc", 1 })) == nil, "talent tree info without a count: counted from the talents")
-- professions from the modern API: kept even with an unknown name, no duplicates
local both = D.Professions({
	{ name = "Leatherworking", rank = 225, max = 300, icon = 1234, known = true },
	{ name = "Jewelcrafting", rank = 40, max = 75, icon = 99, known = true },
	{ name = "Leatherworking", rank = 225, max = 300 },
})
Check(#both == 2 and both[1].icon == 1234 and both[1].spell == nil and both[2].key == "jewelcrafting", "professions from the profession API")

-- the full name (regional unique names: name and surname)
Check(D.PickName("Saz", { "Saz Zy" }, "Realm 2") == "Saz Zy", "name with a surname")
Check(D.PickName("Saz", { "Saz-Zy" }, "Realm 2") == "Saz Zy", "Name-Surname shown with a space")
Check(D.PickName("Saz", { "Saz-CAMWOWAU1Realm2PvP" }, "CAMWOW AU1 Realm 2 PvP") == "Saz", "the realm glued on is not a surname")
Check(D.PickName("Saz", { "Bob Zy", 42 }, "R") == "Saz" and D.PickName(nil, {}) == "?", "foreign or broken answers are ignored")
UnitNameUnmodified = function() return "Saz", "Zy" end
Check(D.FullName() == "Saz Zy", "full name from UnitNameUnmodified")
UnitNameUnmodified = nil
UnitName = function() return "Saz", "Zy" end
Check(D.FullName() == "Saz", "UnitName's second answer is a realm unless unique names are on")
RegionalUniqueNamesEnabled = function() return true end
Check(D.FullName() == "Saz Zy", "with unique names on it is the surname")
RegionalUniqueNamesEnabled = nil
UnitName = function() return "Saz Zy" end

-- reading the game
local events = SKILL_EVENTS
local read = D.ReadProfessions()
Check(#read == 4, "collapsed skill headers are opened to read the professions")
Check(SKILLS[4][3] == false and SKILL_EVENTS == events + 2 and D.readAt, "and closed again afterwards")
local got = D.Collect()
Check(got.name == "Saz Zy" and got.level == 33 and got.classFile == "PALADIN" and got.faction == "Horde", "collect: who you are")
Check(#got.profs == 4 and got.profs[1].name == "Skinning", "collect: professions")
Check(got.talents and got.talents.spec == "Protection", "collect: talents (id, name, ..., points shape)")
Check(got.best and got.best.name == "Blue Sword" and got.ilvl == 34, "collect: best item and average item level")
Check(got.quests == 3 and got.pvp == nil and got.playedPending, "collect: quests, no pvp rank, played time not asked yet")
D.played, D.playedAt = 3600, NOW
NOW = NOW + 600
got = D.Collect()
Check(got.played == 4200 and not got.playedPending, "played time keeps growing during the session")

-- the card
for _, f in ipairs(D.FORMATS) do
	local ok, err = pcall(C.Render, got, { format = f.key, accent = "class", show = {}, headline = "Reached level 33" })
	Check(ok, f.key .. ": card draws" .. (ok and "" or (": " .. tostring(err))))
	if ok then
		Check(C.frame._w == f.w and C.frame._h == f.h, f.key .. ": card has the format's size")
	end
end
C.Render(got, { format = "story", show = {}, hideProfs = { skinning = true } })
local hidden = {}
for i = 1, C.frame.pools.font.used do hidden[#hidden + 1] = C.frame.pools.font.list[i]._text end
hidden = table.concat(hidden, "\n")
Check(not hidden:find("Skinning", 1, true) and hidden:find("Leatherworking", 1, true), "a profession switched off is left off the card")
C.Render(got, { format = "story", accent = "class", show = {}, headline = "Reached level 33" })
local texts = {}
for i = 1, C.frame.pools.font.used do
	texts[#texts + 1] = C.frame.pools.font.list[i]._text
end
local all = table.concat(texts, "\n")
Check(all:find("Saz Zy", 1, true) and all:find("Skinning", 1, true) and all:find("REACHED LEVEL 33", 1, true), "card shows the name, professions and the headline")
Check(C.Caps("Наконец") == "Наконец" and C.Caps("hi") == "HI", "capitals only for Latin text")
local pala = C.Accent("class", { classFile = "PALADIN" })
Check(pala[1] == 0.96 and C.Accent("faction", { faction = "Alliance" })[3] == 1 and C.Accent("gold", {})[1] == 1, "accent colours")
Check(C.Hex({ 1, 0.5, 0 }) == "ffff8000", "hex colour")

-- studio
HerogramDB = nil
local db = S.DB()
Check(db.format == "story" and db.accent == "class" and db.show.gold == false and db.show.profs == true, "settings: defaults")
db.format = "bogus"
Check(S.DB().format == "story", "settings: a broken format is repaired")
Check(S.PoseIndex(69) == 7 and S.PoseIndex(12345) == 1, "pose lookup")
local ok, err = pcall(S.Open, "Hello")
Check(ok, "studio opens" .. (ok and "" or (": " .. tostring(err))))
S.StepPose(-1)
Check(S.DB().model.anim == S.POSES[#S.POSES][1], "pose steps wrap around")
ok, err = pcall(S.Shoot)
Check(ok and S.shooting, "taking a picture starts" .. (ok and "" or (": " .. tostring(err))))
Check(C.frame.shot:IsShown(), "black backdrop is up while shooting")
TIMERS[#TIMERS - 1]() -- the short wait, not the 5 s safety timeout
Check(SHOTS == 1 and S.shooting, "the game is asked for a screenshot, still waiting for it")
ok, err = pcall(S.Finish, true)
Check(ok and not S.shooting and not C.frame.shot:IsShown(), "after the picture everything goes back")
ok = pcall(SlashCmdList.HEROGRAM, "toasts")
Check(ok and S.DB().toasts == false, "/herogram toasts switches the notice off")
SlashCmdList.HEROGRAM("toasts")
local shown = 0
for _, b in ipairs(_G.HerogramStudio.profToggles) do if b:IsShown() then shown = shown + 1 end end
Check(shown == 4, "one switch per profession in the studio")
ok, err = pcall(SlashCmdList.HEROGRAM, "debug")
Check(ok, "/herogram debug prints the raw answers" .. (ok and "" or (": " .. tostring(err))))
-- choosing the card's item
local link = "|cffa335ee|Hitem:12345::::::::34:::::|h[Big Axe]|h|r"
local it = D.ItemFromLink(link)
Check(it and it.id == 12345 and it.name == "Big Axe" and it.quality == 4 and it.pending, "item not cached yet: name and quality from the link, waiting for details")
GetItemInfo = function() return "Big Axe", link, 4, 41, 30, "Weapon", "Axe", 1, "INVTYPE_2HWEAPON", 135000 end
it = D.ItemFromLink(link)
Check(not it.pending and it.icon == 135000 and it.chosen, "item cached: icon and details")
Check(D.ItemFromLink("no link") == nil and D.ItemID("item:77") == 77, "only item links count")
local cleared = 0
ClearCursor = function() cleared = cleared + 1 end
GetCursorInfo = function() return "item", 12345, link end
Check(S.TakeCursorItem() and cleared == 1, "an item dragged in: taken and put back on its place")
Check(HerogramDB.chars[S.Me()].bestItem == link and S.data.best.name == "Big Axe" and S.data.best.chosen, "the chosen item is on the card")
Check(S.data.autoBest and S.data.autoBest.name == "Blue Sword", "the automatic one is still known")
C.Render(S.data, { format = "story", show = { profs = false } })
Check(C.frame.drop:IsShown() and C.frame.itemArea, "the card's item row takes drops")
C.Render(S.data, { format = "story", show = { item = false } })
Check(not C.frame.drop:IsShown(), "no item row: no drop target on the card")
GetCursorInfo = function() return "spell", 1 end
Check(not S.TakeCursorItem() and cleared == 1, "a spell on the cursor is ignored")
S.ClearItem()
Check(HerogramDB.chars[S.Me()].bestItem == nil and S.data.best.name == "Blue Sword", "back to automatic")
IsShiftKeyDown = function() return true end
Check(S.OnModifiedClick(link) and HerogramDB.chars[S.Me()].bestItem == link, "shift-click in the bags while the studio is open")
ChatEdit_GetActiveWindow = function() return {} end
S.ClearItem()
Check(not S.OnModifiedClick(link), "not while a chat box is open: then it is a chat link")
ChatEdit_GetActiveWindow, IsShiftKeyDown, GetCursorInfo, GetItemInfo = nil, nil, nil, nil

-- too much for the card: the panel says what was left out
local many = {}
for i = 1, 14 do many[i] = { key = "p" .. i, name = "Prof" .. i, rank = 100, max = 150 } end
C.Render({ name = "X", level = 10, profs = many, best = { name = "Axe", quality = 3 }, quests = 5, ilvl = 20 }, { format = "square", show = {} })
S.Sync()
local note = _G.HerogramStudio.fitNote:GetText()
Check(#C.frame.dropped > 0 and note:find("Did not fit", 1, true) and note:find("Best item", 1, true), "what did not fit is named in the panel")
S.Refresh()
Check(_G.HerogramStudio.fitNote:GetText() == "", "and the note goes away when it fits")

ok, err = pcall(S.CheckRanks)
Check(ok, "profession ranks are remembered" .. (ok and "" or (": " .. tostring(err))))

Report("core_test")
