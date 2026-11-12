--[[
  Herogram: translations. English text is the key; other languages map it.
]]

local _, ns = ...

local L = {
	ruRU = {
		-- formats
		["Stories"] = "Сторис",
		["Post"] = "Пост",
		["Square"] = "Квадрат",
		["Wide"] = "Широкий",
		-- professions
		["Professions"] = "Профессии",
		["Apprentice"] = "Ученик",
		["Journeyman"] = "Подмастерье",
		["Expert"] = "Умелец",
		["Artisan"] = "Мастер",
		-- stats
		["Talents"] = "Таланты",
		["Played"] = "В игре",
		["Quests done"] = "Квестов",
		["Item level"] = "Ур. предметов",
		["average"] = "в среднем",
		["PvP rank"] = "PvP-звание",
		["Gold"] = "Золото",
		["Best item"] = "Лучший предмет",
		["Item level %d"] = "Уровень предмета %d",
		["%dd %dh"] = "%dд %dч",
		["%dh %dm"] = "%dч %dм",
		["%dm"] = "%dм",
		["%dg %ds"] = "%dз %dс",
		["%ds %dc"] = "%dс %dм",
		["Level"] = "Уровень",
		["MAX"] = "МАКС",
		["%d%% to %d"] = "%d%% до %d",
		["Max level"] = "Макс. уровень",
		-- headline
		["Reached level %d"] = "Достиг %d уровня",
		["%s %d"] = "%s %d",
		-- studio
		["Your hero, ready to share"] = "Ваш герой — готов к публикации",
		["Format"] = "Формат",
		["Colour"] = "Цвет",
		["Class"] = "Класс",
		["Faction"] = "Фракция",
		["Arcane"] = "Тайная магия",
		["Fel"] = "Скверна",
		["Frost"] = "Лёд",
		["Pose"] = "Поза",
		["Freeze"] = "Замереть",
		["Headline"] = "Заголовок",
		["e.g. Finally Artisan!"] = "например: Наконец Мастер!",
		["Show"] = "Показать",
		["Guild"] = "Гильдия",
		["Realm"] = "Сервер",
		["Drag the hero to turn, wheel to zoom, right-drag to move."] = "Тяните героя, чтобы повернуть, колесо — приблизить, правая кнопка — сдвинуть.",
		["Reset hero"] = "Сбросить героя",
		["Take the picture"] = "Сделать снимок",
		["Saved to the Screenshots folder."] = "Сохранено в папку Screenshots.",
		["Open this page in your browser to crop it for social media:"] = "Откройте эту страницу в браузере, чтобы обрезать снимок для соцсетей:",
		["The game did not save the picture."] = "Игра не сохранила снимок.",
		-- poses
		["Stand"] = "Стоит",
		["Ready"] = "Наготове",
		["Battle roar"] = "Боевой клич",
		["Flex"] = "Мускулы",
		["Salute"] = "Салют",
		["Cheer"] = "Ликует",
		["Dance"] = "Танец",
		["Kneel"] = "На колене",
		["Spell"] = "Заклинание",
		-- toast
		["Level %d!"] = "Уровень %d!",
		["Make a card"] = "Сделать карточку",
		["Worth sharing."] = "Есть чем похвастаться.",
		-- minimap and slash
		["Left-click: make a card"] = "Левый клик: сделать карточку",
		["Drag: move the button"] = "Перетащить: сдвинуть кнопку",
		["minimap button:"] = "кнопка у миникарты:",
		["cards on level up and profession ranks:"] = "карточки на новый уровень и ранг профессии:",
		["on"] = "вкл",
		["off"] = "выкл",
		["Commands:"] = "Команды:",
		["open or close the card"] = "открыть или закрыть карточку",
		["offer a card on level up and new profession ranks"] = "предлагать карточку на новый уровень и ранг профессии",
		["show or hide the minimap button"] = "показать или скрыть кнопку у миникарты",
		["put the hero back as it was"] = "вернуть героя как было",
		["made with Herogram"] = "сделано в Herogram",
		["Drag an item here to show it instead"] = "Перетащите сюда предмет, чтобы показать его",
		["Right-click: back to automatic"] = "Правый клик: снова автоматически",
		["Or Shift-click an item in your bags while this panel is open."] = "Или Shift-клик по предмету в сумке, пока открыта эта панель.",
		["Auto"] = "Авто",
		["Steps"] = "Шаги",
		["%s all time"] = "всего %s",
		["Frame"] = "Рамка",
		["Stone"] = "Камень",
		["Wood"] = "Дерево",
		["Thin"] = "Тонкая",
		["Did not fit: %s. To show it, %s"] = "Не влезло: %s. Чтобы показать, %s",
		["switch something off."] = "выключите что-нибудь.",
		["switch something off or pick Stories."] = "выключите что-нибудь или выберите «Сторис».",
		["Drop an item here"] = "Перетащите сюда предмет",
		["Your choice · right-click for automatic"] = "Ваш выбор · правый клик — автоматически",
		["Automatic · drop an item to change"] = "Автоматически · перетащите предмет, чтобы сменить",
		["print what the game says about professions and talents"] = "показать, что игра отвечает про профессии и таланты",
	},
}

local active = L[GetLocale and GetLocale() or "enUS"] or {}

function ns.T(s)
	return active[s] or s
end
