-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "ruRU" then
	return
end
local L = ns.L

L["%d %s"] = "%d %s"
L["%d crafts to %d, %s"] = "%d созд. до %d, %s"
L["%d crafts to %d, %s, at %s"] = "%d созд. до %d, %s, у: %s"
L["%d more"] = "еще %d"
L["%d to %d"] = "%d–%d"
L["%d, from %d to %d"] = "%d, с %d до %d"
L["%dd ago"] = "%d дн. назад"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): в аддоне %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): в аддоне %s, учитель требует %d"
L["%s (unlearned)"] = "%s (не изучено)"
L["%s is at %s."] = "%s находится здесь: %s."
L["%s is in %s."] = "%s находится в зоне %s."
L["%s trainer"] = "Учитель (%s)"
L["%s until %d"] = "%s до %d"
L["%s, %d"] = "%s, %d"
L["%s, %d/%d"] = "%s, %d/%d"
L["%s, %s, to %d"] = "%s, %s, до %d"
L["%s, source unknown"] = "%s, источник неизвестен"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] =
	"%s: перемещено %d, подтверждено у учителя %d, неверно %d."
L["+%d more"] = "и еще %d"
L["/su skipped lists the recipes you skipped, with their IDs."] =
	"/su skipped показывает пропущенные рецепты с их ID."
L["/su unskip <recipe ID> shows one again, /su unskip all every one."] =
	"/su unskip <recipe ID> возвращает один рецепт, /su unskip all — все."
L["A button above a merchant's window that buys the reagents your tracked routes still need from that merchant. It asks first, with the total cost."] =
	"Кнопка над окном торговца, которая покупает у него реагенты, еще нужные вашим отслеживаемым маршрутам. Сначала спрашивает подтверждение и показывает общую стоимость."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator."] =
	"Материал, который добывают ваши профессии, стоит столько, сколько принесла бы его продажа, а не ноль: цена на аукционе за вычетом 5% комиссии или цена продажи торговцу, если она выше. Учитывается в маршруте и стоимости в строках рецептов. Для цен аукциона нужен Auctionator."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"Оставляет общий трекер Forever там, где вы его поставили. Ручка сверху больше его не перетаскивает."
L["Lock the tracker"] = "Закрепить трекер"
L["A side tab on the Professions window listing the newest crafted item this character can equip in each slot, under the route tab."] =
	"Боковая вкладка окна профессий под вкладкой маршрута: самый новый созданный предмет, который этот персонаж может надеть, для каждой ячейки."
L["A side tab on the Professions window with a route to your target skill and its reagents. Tracked professions stay in the objective tracker either way."] =
	"Боковая вкладка окна профессий с маршрутом до целевого навыка и реагентами. Отслеживаемые профессии остаются в списке задач в любом случае."
L["AH"] = "Аук."
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"Показывает начало диапазона сложности каждого рецепта. Это не навык, нужный для изучения."
L["Addon"] = "Модификация"
L["Adventure Guide Forever can plan this quest chain."] =
	"Adventure Guide Forever может спланировать эту цепочку заданий."
L["Also for this slot"] = "Еще для этой ячейки"
L["Annotate trainer recipes"] = "Подсказки к рецептам учителя"
L["Another craft makes this recipe, not yours."] =
	"Этот рецепт создает другая профессия, не ваша."
L["Another crafter"] = "Другой ремесленник"
L["At the %d cap: no trainer teaches the next rank."] =
	"Предел %d: ни один учитель не обучает следующему рангу."
L["At the cursor"] = "У курсора"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot установлен, но не работает: включите его в списке модификаций или обновите, если он устарел."
L["Attach to quest tracker"] = "Прикрепить к списку заданий"
L["Auction house"] = "Аукционный дом"
L["Auction price if higher"] = "Цена аукциона, если выше"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator еще не видел эти реагенты: просканируйте им аукцион, чтобы узнать цены."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	"Сканирование Auctionator при открытии аукциона выключено: включите его в Auctionator, «Basic Options»."
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "Спина"
L["Beside the Professions window"] = "Рядом с окном профессий"
L["Buy"] = "Купить"
L["Buy %d %s"] = "Купить %d %s"
L["Buy %s for %s?"] = "Купить %s за %s?"
L["Buy and read %s at %d"] = "Купить и прочитать %s на %d"
L["Buy and read %s at %d (level %d)"] = "Купить и прочитать %s на %d (уровень %d)"
L["Buy reagents"] = "Купить реагенты"
L["Buy reagents at the auction house"] = "Купить реагенты на аукционе"
L["Buy tracked reagents  %s"] = "Купить отслеживаемые реагенты  %s"
L["Can learn it"] = "Можно изучить"
L["Cancel"] = "Отмена"
L["Cheapest skill-up"] = "Самый дешевый рост навыка"
L["Chest"] = "Грудь"
L["Click for a waypoint to %s."] = "Щелкните, чтобы поставить точку маршрута: %s."
L["Click for a waypoint."] = "Щелкните, чтобы поставить точку маршрута."
L["Click to craft %d."] = "Щелкните, чтобы создать %d."
L["Click to open the recipe."] = "Щелкните, чтобы открыть рецепт."
L["Click to show a recipe again."] = "Щелкните, чтобы вернуть рецепт."
L["Close"] = "Закрыть"
L["Complete %s at %d"] = "Выполнить %s на %d"
L["Complete %s at %d (level %d)"] = "Выполнить %s на %d (уровень %d)"
L["Complete %s first: you're at your cap."] =
	"Сначала выполните %s: вы достигли предела."
L["Copy link"] = "Копировать ссылку"
L["Copy the address, then open it in your browser."] =
	"Скопируйте адрес и откройте его в браузере."
L["Cost"] = "Стоимость"
L["Count what crafts sell for"] = "Учитывать цену продажи созданного"
L["Craft %d %s"] = "Создать %d %s"
L["Craft %d of %d× %s"] = "Создать %d из %d× %s"
L["Craft %d× %s"] = "Создать %d× %s"
L["Craft %s"] = "Создать %s"
L["Craft next"] = "Создать следующее"
L["Crafted gear"] = "Созданное снаряжение"
L["Crafts"] = "Созданий"
L["Crafts %d now."] = "Создает %d сейчас."
L["Don't count it"] = "Не учитывать"
L["Don't suggest this again"] = "Больше не предлагать"
L["Drag to move"] = "Перетащите, чтобы переместить"
L["Dropped by"] = "Добыча с"
L["Each"] = "За шт."
L["Each click puts the next one in the search box; press Search."] =
	"Каждый щелчок вставляет следующий в поле поиска; нажмите «Поиск»."
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"Включите Shortest Path Forever для пеших маршрутов и расписания кораблей."
L["Every recipe that uses it"] = "Все рецепты, где он нужен"
L["Fee"] = "Плата"
L["Fee %s, requires %s (%d)"] = "Плата %s, требуется: %s (%d)"
L["Feet"] = "Ступни"
L["Finger"] = "Палец"
L["First used at"] = "Впервые нужен на"
L["Forever addons"] = "Модификации Forever"
L["Forever tracker"] = "Отслеживание Forever"
L["Gather %d %s"] = "Добыть %d %s"
L["Gathering skill on nodes"] = "Навык сбора на месторождениях"
L["Hands"] = "Кисти рук"
L["Have (bags and bank)"] = "Есть (сумки и банк)"
L["Head"] = "Голова"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"Подсказки трав и рудных жил показывают нужный навык и его цвет для вашего (только английский клиент). Для свежуемых трупов показывается ?, пока правило снятия шкур не подтверждено на Forever."
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"Установите AtlasLoot, чтобы видеть рецепты от торговцев, заданий и добычи."
L["Install Questie and AtlasLoot to see where recipes, vendors and trainers are."] =
	"Установите Questie и AtlasLoot, чтобы видеть, где рецепты, торговцы и учителя."
L["Install Questie to see vendors, quests and trainers, with waypoints to them."] =
	"Установите Questie, чтобы видеть торговцев, задания и учителей с точками маршрута."
L["Installed, turned off"] = "Установлено, отключено"
L["Its trainer should teach these at your skill now:"] =
	"Учитель уже должен обучить вас этому при вашем навыке:"
L["Kept in the Auctionator list '%s'."] = "Сохранено в списке Auctionator «%s»."
L["Latest Auctionator prices."] = "Последние цены Auctionator."
L["Latest Auctionator prices: rescan to update old prices."] =
	"Последние цены Auctionator: просканируйте снова, чтобы обновить старые."
L["Learn a crafting profession to plan a route."] =
	"Изучите ремесленную профессию, чтобы спланировать маршрут."
L["Legs"] = "Ноги"
L["Level %d"] = "Уровень %d"
L["Level %d %s"] = "Уровень %d, %s"
L["Levelling route"] = "Маршрут прокачки"
L["Made at"] = "Создается у"
L["Main hand"] = "Правая рука"
L["Missing reagents for this step."] = "Для этого шага не хватает реагентов."
L["Money on recipe rows"] = "Деньги в строках рецептов"
L["Nearest trainer"] = "Ближайший учитель"
L["Nearest vendor"] = "Ближайший торговец"
L["Neck"] = "Шея"
L["Need %d more %s"] = "Нужно еще %d %s"
L["Need a %s in your bags."] = "Нужен предмет в сумках: %s."
L["Needs %s %d"] = "Требуется %s %d"
L["Net per craft"] = "Итого за создание"
L["Next to the recipe"] = "Рядом с рецептом"
L["No crafted gear for your level and class yet."] =
	"Пока нет созданного снаряжения для вашего уровня и класса."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"Пока нет снаряжения, которое вы можете создать. Отметьте флажок выше, чтобы видеть то, что вы создать не можете."
L["No skill data for this recipe yet."] =
	"Для этого рецепта пока нет данных о навыке."
L["No trainer teaches this rank: a book does."] =
	"Этому рангу обучает не учитель, а книга."
L["No trainer teaches this rank: a quest does."] =
	"Этому рангу обучает не учитель, а задание."
L["Not in this route: you chose Not this recipe."] =
	"Не в маршруте: вы выбрали «Не этот рецепт»."
L["Not installed"] = "Не установлено"
L["Not this recipe"] = "Не этот рецепт"
L["Nothing on this route is yours to gather, so the switch changes nothing for it."] =
	"На этом маршруте вы ничего не добываете сами, поэтому переключатель здесь ничего не меняет."
L["Nothing priced you know skills up past %d."] =
	"Ничто известное вам с ценой не повышает навык выше %d."
L["Nothing to buy for this route."] = "Для этого маршрута покупать нечего."
L["Nothing to craft on this route."] = "На этом маршруте создавать нечего."
L["Nothing you know skills up past %d."] =
	"Ничто известное вам не повышает навык выше %d."
L["Off hand"] = "Левая рука"
L["On"] = "Вкл."
L["On %s"] = "На %s"
L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs nothing."] =
	"Вкл.: реагент, который вы могли бы добыть, оценивается по цене торговца или аукциона. Выкл.: добыча ничего не стоит."
L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs what it would sell for."] =
	"Вкл.: реагент, который вы могли бы добыть, оценивается по цене торговца или аукциона. Выкл.: добыча стоит столько, сколько принесла бы продажа."
L["One line in chat the first time a new version loads."] =
	"Одна строка в чате при первой загрузке новой версии."
L["Open"] = "Открыть"
L["Open %s to craft from here."] = "Откройте %s, чтобы создавать отсюда."
L["Open recipe"] = "Открыть рецепт"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"Пороги оранжевого, желтого, зеленого и серого цвета при наведении на рецепт."
L["Per craft"] = "За создание"
L["Per skill-up"] = "За очко навыка"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"За единицу навыка — стоимость одного очка навыка. За создание — сколько стоит или приносит одно создание, в том числе для рецептов, которые больше не повышают навык."
L["Picks quests for your level and plans them into one journey."] =
	"Подбирает задания по вашему уровню и объединяет их в один маршрут."
L["Plans the cheapest route to your next profession rank."] =
	"Прокладывает самый дешевый путь к следующему рангу профессии."
L["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."] =
	"Прокладывает самый быстрый путь куда угодно и ведет вас туда, с расписанием кораблей и дирижаблей в реальном времени."
L["Price"] = "Цена"
L["Price %s, requires %s (%d)"] = "Цена %s, требуется: %s (%d)"
L["Prices"] = "Цены"
L["Profession reagents"] = "Реагенты профессий"
L["Profit per craft"] = "Прибыль за создание"
L["Profit per skill-up"] = "Прибыль за очко навыка"
L["Quest"] = "Задание"
L["Quest automation, rare alerts and merchant handling for the default UI."] =
	"Автоматизация заданий, оповещения о редких противниках и работа с торговцами для стандартного интерфейса."
L["Quest giver"] = "Выдает задание"
L["Quest, requires %s (%d)"] = "Задание, требуется: %s (%d)"
L["Raises your skill cap to %d."] = "Повышает предел навыка до %d."
L["Ranged"] = "Дальний бой"
L["Read %s at %d"] = "Прочитать %s на %d"
L["Read %s at %d (level %d)"] = "Прочитать %s на %d (уровень %d)"
L["Read %s first: you're at your cap."] =
	"Сначала прочитайте %s: вы достигли предела."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free unless you value them under Prices, and auction prices need Auctionator."] =
	"Стоимость реагентов, деленная на шанс повышения навыка, в строках рецептов и в подсказке. Обычные реагенты торговцев имеют цену сразу и обновляются у посещенных торговцев; добываемые вами реагенты бесплатны, если не задать им цену в разделе «Цены»; для цен аукциона нужен Auctionator."
L["Reagent tooltips"] = "Подсказки реагентов"
L["Reagents"] = "Реагенты"
L["Reagents  (have / need)"] = "Реагенты  (есть / нужно)"
L["Reagents for"] = "Реагенты для"
L["Reagents in hand"] = "Реагенты собраны"
L["Reagents still needed"] = "Еще нужны реагенты"
L["Recipe rows"] = "Строки рецептов"
L["Recipe tooltip position"] = "Положение подсказки рецепта"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"Рецепты от торговцев, заданий и добычи, с которыми можно продолжить:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"Требуемый навык, шанс повышения и стоимость в рецептах учителей профессий, а также какой изучить следующим для вашего маршрута."
L["Requires"] = "Требуется"
L["Route"] = "Маршрут"
L["Route and trainer"] = "Маршрут и учитель"
L["Route incomplete: %d recipes left out, their reagents not priced yet."] =
	"Маршрут неполный: пропущено рецептов: %d, у их реагентов еще нет цен."
L["Route needs"] = "Нужно маршруту"
L["Route: %d/%d · %s to %d"] = "Маршрут: %d/%d · %s до %d"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"Просканируйте аукцион с Auctionator или посетите торговца, чтобы узнать цены реагентов."
L["Scroll"] = "Рецепт"
L["Search"] = "Поиск"
L["Search reagents at the auction house"] = "Искать реагенты на аукционе"
L["Sells for"] = "Продается за"
L["Sells for x%g"] = "Продается за x%g"
L["Set waypoint"] = "Поставить точку маршрута"
L["Shift-click to link the scroll."] = "SHIFT+щелчок — ссылка на рецепт."
L["Shift: used in %d of your recipes"] = "SHIFT: используется в ваших рецептах: %d"
L["Shoulder"] = "Плечо"
L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."] =
	"Показывать неприметную строку там, где помогла бы другая моя модификация Forever. Только для тех, что у вас не установлены."
L["Show again: %s"] = "Снова показан: %s"
L["Show cost per skill-up"] = "Показывать стоимость за очко навыка"
L["Show gear I cannot make yet"] =
	"Показывать снаряжение, которое я пока не могу создать"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"Показывать маршруты профессий в списке задач. Скрытие сохраняет отслеживаемые профессии и цели."
L["Show skill on recipe rows"] = "Навык в строках рецептов"
L["Show skill range start on rows"] = "Начало диапазона в строках"
L["Show the buy button at merchants"] = "Кнопка покупки у торговцев"
L["Show the crafted gear tab"] = "Вкладка созданного снаряжения"
L["Show the levelling route tab"] = "Вкладка маршрута прокачки"
L["Show thresholds tooltip"] = "Подсказка с порогами"
L["Show tracked professions"] = "Показывать отслеживаемые профессии"
L["Shows the Legacy challenges you can advance in each zone."] =
	"Показывает старинные испытания, которые можно продвинуть в каждой зоне."
L["Skill  %d/%d     Target"] = "Навык  %d/%d     Цель"
L["Skill points a craft"] = "Очков навыка за создание"
L["Skill range start"] = "Начало диапазона"
L["Skill range starts at %d"] = "Диапазон начинается с %d"
L["Skill-up chance"] = "Шанс повышения навыка"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"Шанс повышения навыка и стоимость за очко справа от каждого рецепта."
L["Skill-up chance: %d%%"] = "Шанс повышения навыка: %d%%"
L["SkillUp report"] = "Отчет SkillUp"
L["Skipped (%d)"] = "Пропущено (%d)"
L["Skipped (%d):"] = "Пропущено (%d):"
L["Sold by"] = "Продает"
L["Sort by"] = "Сортировка"
L["Sort recipes"] = "Сортировка рецептов"
L["Sort recipes in one list, learned first, then unlearned. Default restores categories."] =
	"Сортирует рецепты одним списком: сначала изученные, затем неизученные. «По умолчанию» возвращает категории."
L["Source"] = "Источник"
L["Source unknown"] = "Источник неизвестен"
L["Stop tracking"] = "Не отслеживать"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, are after the 5% cut, and may not sell."] =
	"Вычитает из стоимости цену продажи созданного предмета. Для цен аукциона нужен Auctionator, они указаны за вычетом 5% комиссии, и предмет может не продаться."
L["Suggest my other Forever addons"] = "Предлагать другие мои модификации Forever"
L["Taught by %s trainers."] = "Обучают учителя (%s)."
L["The place this recipe is taught isn't known yet."] =
	"Где обучают этому рецепту, пока неизвестно."
L["The rest comes from a vendor or your gathering."] =
	"Остальное — от торговца или из вашей добычи."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"Маршрут рассчитывает на %d, чтобы достичь %d в 9 случаях из 10; при меньшей удаче понадобится больше."
L["The source of this recipe isn't known."] = "Источник этого рецепта неизвестен."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."] =
	"Текст выделен. Нажмите Ctrl+C (Cmd+C на Mac), чтобы скопировать его, и вставьте в сообщение об ошибке."
L["The tracker is locked. Turn off Lock the tracker to move it."] =
	"Трекер закреплён. Отключите «Закрепить трекер», чтобы переместить его."
L["These reagents have no vendor price. Auction prices need Auctionator."] =
	"У этих реагентов нет цены у торговца. Для цен аукциона нужен Auctionator."
L["This addon"] = "Эта модификация"
L["To buy"] = "К покупке"
L["Tool"] = "Инструмент"
L["Tooltips and sorting"] = "Подсказки и сортировка"
L["Total %s"] = "Всего %s"
L["Track"] = "Отслеживать"
L["Tracked routes (Shift for all)"] = "Отслеживаемые маршруты (SHIFT — все)"
L["Train %s"] = "Изучить %s"
L["Train %s at %d"] = "Изучить %s на %d"
L["Train %s at %d (level %d)"] = "Изучить %s на %d (уровень %d)"
L["Train %s first."] = "Сначала изучите %s."
L["Train %s first: you're at your cap."] = "Сначала изучите %s: вы достигли предела."
L["Trinket"] = "Аксессуар"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"Выключите, чтобы перетаскивать общее окно отслеживания Forever в любое место экрана."
L["Update Questie to see vendors, quests and trainers, with waypoints to them."] =
	"Обновите Questie, чтобы видеть торговцев, задания и учителей с точками маршрута."
L["Used in"] = "Используется в"
L["Value gathered materials at what they'd sell for"] =
	"Оценивать добытые материалы по цене продажи"
L["Vendor"] = "Торговец"
L["Vendor reagents"] = "Реагенты торговцев"
L["Vendor sell price"] = "Цена продажи торговцу"
L["Visit a vendor to price reagents. Auction prices need Auctionator."] =
	"Посетите торговца, чтобы узнать цены реагентов. Для цен аукциона нужен Auctionator."
L["Waist"] = "Пояс"
L["Waypoint to a trainer"] = "Точка маршрута к учителю"
L["Waypoint to a vendor: %s"] = "Точка маршрута к торговцу: %s"
L["Waypoint to the quest giver: %s"] = "Точка маршрута к тому, кто дает задание: %s"
L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."] =
	"Что показывает подсказка предмета о ваших профессиях: сколько его нужно отслеживаемым маршрутам (удерживайте SHIFT, чтобы видеть все рецепты с ним), все такие рецепты и их цвет, или ничего."
L["What's new after an update"] = "Что нового после обновления"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"Где появляется подсказка при наведении на рецепт. Рядом с окном она не закрывает реагенты."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"Пока открыт аукцион, окно профессий предлагает поиск реагентов выбранного рецепта: столько, сколько еще нужно для выбранного числа созданий с учетом сумок и банка. Список покупок Auctionator передает количество; без него каждый щелчок вставляет следующий реагент в поле поиска."
L["With Shortest Path Forever, a click leads you there."] =
	"С Shortest Path Forever щелчок приведет вас туда."
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"С Shortest Path Forever выбирается ближайший по времени пути, и вас ведут туда."
L["World drop"] = "Случайная добыча"
L["Wrist"] = "Запястья"
L["You have it, requires %s (%d)"] = "Есть, требуется: %s (%d)"
L["You have this book: read it."] = "У вас есть эта книга: прочитайте ее."
L["You know it"] = "Изучено"
L["You: %d"] = "Вы: %d"
L["Your bags allow %d of the route's %d."] =
	"В сумках хватает места на %d из %d для маршрута."
L["Your bags and bank have enough."] = "В сумках и банке достаточно."
L["can't identify the profession %s (%s); please report it."] =
	"не удалось определить профессию %s (%s); пожалуйста, сообщите об этом."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"не удалось добавить отслеживаемые реагенты в список задач; пожалуйста, сообщите об этом."
L["crafts"] = "созданий"
L["drop"] = "добыча"
L["every skipped recipe is back in the route."] =
	"все пропущенные рецепты возвращены в маршрут."
L["files are missing: restart the game (not /reload) after updating."] =
	"не хватает файлов: перезапустите игру (не /reload) после обновления."
L["for %s"] = "для %s"
L["gather"] = "добыча"
L["green"] = "зеленый"
L["grey"] = "серый"
L["item %d"] = "предмет %d"
L["level %d"] = "уровень %d"
L["makes %d %s"] = "создает %d %s"
L["no price"] = "нет цены"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	"пропущенных рецептов нет: щелкните правой кнопкой по шагу на странице маршрута и выберите «Не этот рецепт»."
L["no trainer requirements to check."] = "нет требований учителей для проверки."
L["none"] = "нет"
L["not enough money for every missing reagent here."] =
	"не хватает денег на все недостающие здесь реагенты."
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"здесь искать нечего: недостающее — от торговца или из вашей добычи."
L["open a profession first."] = "сначала откройте профессию."
L["open the auction house's Buy tab, then search again."] =
	"откройте вкладку «Купить» на аукционе и повторите поиск."
L["orange"] = "оранжевый"
L["over 3 weeks ago"] = "более 3 недель назад"
L["profession %d"] = "профессия %d"
L["quest"] = "задание"
L["recipe %d"] = "рецепт %d"
L["route set to %s, %s."] = "маршрут проложен: %s, %s."
L["searching for %s: you need %d more."] = "поиск: %s; нужно еще %d."
L["sorting failed and has been turned off: %s"] = "сортировка не удалась и выключена: %s"
L["the %s book"] = "книга «%s»"
L["the %s quest"] = "задание «%s»"
L["the objective tracker isn't available, so tracked reagents can't be shown."] =
	"список задач недоступен, поэтому отслеживаемые реагенты не показать."
L["the reagent names are still loading; search again in a moment."] =
	"названия реагентов еще загружаются; повторите поиск чуть позже."
L["today"] = "сегодня"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"отслеживается, но раздел в списке задач не прикреплен; пожалуйста, сообщите об этом."
L["unknown age"] = "возраст неизвестен"
L["unknown location"] = "место неизвестно"
L["updated to %s. %s"] = "обновлено до %s. %s"
L["vendor"] = "торговец"
L["waypoint set to %s, %s."] = "точка маршрута поставлена: %s, %s."
L["world drop"] = "случайная добыча"
L["yellow"] = "желтый"
L["you gather it (%s)"] = "вы добываете это (%s)"
L["you gather it (%s), valued at its AH price"] = "вы добываете это (%s), по цене аукциона"
L["you gather it (%s), valued at its vendor sell price"] =
	"вы добываете это (%s), по цене продажи торговцу"
L["your bags and bank already hold the reagents for that many."] =
	"в сумках и банке уже есть реагенты на это количество."
L["No step yet: learn or train a %s recipe that skills up."] =
	"Пока нет шага: изучите или освойте рецепт (%s), повышающий навык."
L["Show thresholds bar on the recipe"] = "Показывать полосу порогов на рецепте" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"Оранжевый, жёлтый, зелёный и серый пороги и ваше место на них, под рецептом в окне профессий. Отключите, если она закрывает реагенты." -- mt
L["%s (%s to %d)"] = "%s (%s до %d)" -- mt
L["Buying for %s"] = "Покупка для %s" -- mt
L["  %d items have no price yet"] = "  %d предметов пока без цены"
L["%d x %s - %s each"] = "%d x %s - %s за штуку"
L["%d x %s - price unknown"] = "%d x %s - цена неизвестна"
L["%s to %d"] = "%s до %d"
L[", "] = ", "
L[", price seen %d days ago"] = ", цена замечена %d дн. назад"
L["/su export - show the trainer requirements this character has seen, to paste into a report"] =
	"/su export - показать требования учителя, которые видел этот персонаж, чтобы вставить их в отчет"
L["/su issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/su issue - сообщить об ошибке или попросить новую возможность с готовой ссылкой на issue GitHub"
L["/su report - show a report to copy into a bug report"] =
	"/su report - показать отчет, чтобы скопировать его в сообщение об ошибке"
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] =
	"Для поездки за покупками нужен Shortest Path Forever."
L["Bug"] = "Ошибка"
L["Bug: "] = "Ошибка: "
L["Copy issue link"] = "Копировать ссылку на issue"
L["Copy list"] = "Копировать список"
L["Copy report"] = "Копировать отчет"
L["Feature request"] = "Пожелание"
L["Feature request: "] = "Пожелание: "
L["Gather"] = "Добыча"
L["Need %d, have %d, missing %d  %s  %s each  %s"] =
	"Нужно %d, есть %d, не хватает %d  %s  %s за штуку  %s"
L["No tracked profession"] = "Нет отслеживаемых профессий"
L["Nothing is missing from the shopping list."] = "В списке покупок все есть."
L["Nothing to buy"] = "Нечего покупать"
L["Plan buy trip"] = "Спланировать покупки"
L["Report a bug or request a feature"] =
	"Сообщить об ошибке или попросить новую возможность"
L["Shopping list"] = "Список покупок"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever не может спланировать весь путь; ставится точка маршрута к первому торговцу."
L["Shortest Path Forever is needed to plan this trip."] =
	"Для планирования этого пути нужен Shortest Path Forever."
L["SkillUp Forever shopping list"] = "Список покупок SkillUp Forever"
L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."] =
	"Ссылка выделена. Нажмите Ctrl+C (Cmd+C на Mac) и вставьте ее в браузере; GitHub откроет заполненное issue."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"Текст выделен. Нажмите Ctrl+C (Cmd+C на Mac), чтобы скопировать его."
L["Title"] = "Название"
L["Total for priced items: "] = "Всего по предметам с ценой: "
L["Unknown"] = "Неизвестно"
L["What happened, or what you would like"] = "Что случилось или что вы хотите"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"требования учителя пока не видны: откройте учителя профессии и повторите попытку."
L["on %s"] = "у %s"
L["price unknown"] = "цена неизвестна"
L["Unpin recipe"] = "Открепить рецепт" -- mt
L["Pin for skill-ups"] = "Закрепить для повышения навыка" -- mt
L["Right-click to pin or skip this recipe."] =
	"Щёлкните правой кнопкой, чтобы закрепить или пропустить рецепт." -- mt
L["Unpin: %s"] = "Открепить: %s" -- mt
L["Pinned for skill-ups."] = "Закреплён для повышения навыка." -- mt
L["Skill range unknown."] = "Диапазон навыка неизвестен." -- mt
L["Already grey: no skill-ups."] = "Уже серый: навык не повышается." -- mt
L["Requires skill %d."] = "Требуется навык %d." -- mt
L["Learn this recipe first."] = "Сначала изучите этот рецепт." -- mt
L["Reagents not priced yet."] = "Цены на реагенты ещё неизвестны." -- mt
L["Outside this route or a newer pin takes priority."] =
	"Вне этого маршрута или более новый закреплённый рецепт имеет приоритет." -- mt
L["Pinned: %s"] = "Закреплён: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"При пересечении диапазонов приоритет у рецепта, закреплённого последним." -- mt
L["Pinned (%d)"] = "Закреплено (%d)" -- mt

L["%d. %s (you): %d"] = "%d. %s (вы): %d"
L["%d. %s: %d"] = "%d. %s: %d"
L["Distinct recipes observed learned on this character"] =
	"Различные рецепты, замеченные как изученные этим персонажем"
L["Guild and group totals are player-reported, not verified."] =
	"Итоги гильдии и группы сообщают сами игроки; они не проверены."
L["No guild or group member has reported yet."] =
	"Никто из гильдии или группы ещё не сообщил данные."
L["Sharing is on. Use /su share off to stop sharing."] =
	"Обмен включён. Команда /su share off отключает его."
L["Sharing is off. Other players are hidden; your own history is kept."] =
	"Обмен отключён. Другие игроки скрыты; ваша история сохранена."
L["/su leaderboard - rank distinct recipes observed learned; also /su stats"] =
	"/su leaderboard - рейтинг различных рецептов, замеченных как изученные; также /su stats"
L["/su share on|off - control sharing with guild and group"] =
	"/su share on|off - управление обменом с гильдией и группой"
L["Share observed recipe totals with guild and group"] =
	"Делиться итогами наблюдений рецептов с гильдией и группой"
L["On by default. Turn off to stop sending and receiving totals and hide other players. Local observations stay."] =
	"По умолчанию включено. Отключите, чтобы прекратить отправку и приём итогов и скрыть других игроков. Локальные наблюдения сохраняются."

L["Shift-clicking a recipe in the route reliably links it in chat."] =
	"Shift-щелчок по рецепту в маршруте надёжно вставляет ссылку в чат." -- mt
