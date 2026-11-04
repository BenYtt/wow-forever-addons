-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "koKR" then
	return
end
local L = ns.L

L["%d %s"] = "%d %s"
L["%d crafts to %d, %s"] = "%d회 제작, %d까지, %s"
L["%d crafts to %d, %s, at %s"] = "%d회 제작, %d까지, %s, 장소: %s"
L["%d more"] = "%d개 더"
L["%d to %d"] = "%d~%d"
L["%d, from %d to %d"] = "%d회, %d에서 %d까지"
L["%dd ago"] = "%d일 전"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): 내장 %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): 내장 %s, 전문가 요구 %d"
L["%s (unlearned)"] = "%s (배우지 않음)"
L["%s is at %s."] = "%s은(는) %s에 있습니다."
L["%s is in %s."] = "%s은(는) %s에 있습니다."
L["%s trainer"] = "%s 기술 전문가"
L["%s until %d"] = "%s (%d까지)"
L["%s, %d"] = "%s, %d"
L["%s, %d/%d"] = "%s, %d/%d"
L["%s, %s, to %d"] = "%s, %s, %d까지"
L["%s, source unknown"] = "%s, 출처 알 수 없음"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] = "%s: 이동 %d, 전문가에서 확인 %d, 틀림 %d."
L["+%d more"] = "+%d개 더"
L["/su skipped lists the recipes you skipped, with their IDs."] =
	"/su skipped: 건너뛴 제조법을 ID와 함께 보여줍니다."
L["/su unskip <recipe ID> shows one again, /su unskip all every one."] =
	"/su unskip <recipe ID>는 하나를, /su unskip all은 모두 다시 보여줍니다."
L["A button above a merchant's window that buys the reagents your tracked routes still need from that merchant. It asks first, with the total cost."] =
	"상인 창 위에 버튼이 생겨, 추적 중인 경로에 아직 필요한 재료를 그 상인에게서 구매합니다. 먼저 총 비용과 함께 확인합니다."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator."] =
	"전문 기술로 채집하는 재료의 비용을 0 대신 판매 시 얻을 금액으로 계산합니다: 5% 수수료를 뺀 경매 가격, 또는 그보다 높으면 상점 판매 가격. 경로와 제조법 행의 비용에 쓰입니다. 경매 가격은 Auctionator가 필요합니다."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"공유 Forever 추적기를 놓은 자리에 유지합니다. 위쪽 손잡이로 더 이상 끌 수 없습니다."
L["Lock the tracker"] = "추적기 잠금"
L["A side tab on the Professions window listing the newest crafted item this character can equip in each slot, under the route tab."] =
	"전문 기술 창의 경로 탭 아래에 있는 측면 탭으로, 이 캐릭터가 각 슬롯에 착용할 수 있는 가장 최신 제작 아이템을 보여줍니다."
L["A side tab on the Professions window with a route to your target skill and its reagents. Tracked professions stay in the objective tracker either way."] =
	"전문 기술 창의 측면 탭으로, 목표 숙련도까지의 경로와 재료를 보여줍니다. 추적 중인 전문 기술은 어느 쪽이든 목표 추적기에 남습니다."
L["AH"] = "경매장"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"각 제조법의 난이도 구간 시작점을 표시합니다. 배우는 데 필요한 숙련도와는 별개입니다."
L["Addon"] = "애드온"
L["Adventure Guide Forever can plan this quest chain."] =
	"Adventure Guide Forever로 이 연계 퀘스트를 계획할 수 있습니다."
L["Also for this slot"] = "이 슬롯의 다른 아이템"
L["Annotate trainer recipes"] = "전문가 제조법에 정보 표시"
L["Another craft makes this recipe, not yours."] =
	"이 제조법은 내 전문 기술이 아닌 다른 기술로 만듭니다."
L["Another crafter"] = "다른 제작자"
L["At the %d cap: no trainer teaches the next rank."] =
	"최대 %d: 다음 단계를 가르치는 전문가가 없습니다."
L["At the cursor"] = "커서 위치"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot가 설치되었지만 실행 중이 아닙니다: 애드온 목록에서 켜거나, 오래된 버전이면 업데이트하세요."
L["Attach to quest tracker"] = "퀘스트 추적기에 붙이기"
L["Auction house"] = "경매장"
L["Auction price if higher"] = "더 높으면 경매 가격"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator가 아직 이 재료들을 보지 못했습니다: 경매장을 검색해 가격을 확인하세요."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	'경매장을 열 때 Auctionator 검색이 꺼져 있습니다: Auctionator의 "Basic Options"에서 켜세요.'
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "등"
L["Beside the Professions window"] = "전문 기술 창 옆"
L["Buy"] = "구매"
L["Buy %d %s"] = "%d개 구매: %s"
L["Buy %s for %s?"] = "%s을(를) %s에 구매하시겠습니까?"
L["Buy and read %s at %d"] = "%s 구매 후 읽기 (%d)"
L["Buy and read %s at %d (level %d)"] = "%s 구매 후 읽기 (%d, 레벨 %d)"
L["Buy reagents"] = "재료 구매"
L["Buy reagents at the auction house"] = "경매장에서 재료 구매"
L["Buy tracked reagents  %s"] = "추적 재료 구매  %s"
L["Can learn it"] = "배울 수 있음"
L["Cancel"] = "취소"
L["Cheapest skill-up"] = "가장 저렴한 숙련도 상승"
L["Chest"] = "가슴"
L["Click for a waypoint to %s."] = "클릭하면 %s(으)로 웨이포인트를 설정합니다."
L["Click for a waypoint."] = "클릭하면 웨이포인트를 설정합니다."
L["Click to craft %d."] = "클릭하면 %d개 제작합니다."
L["Click to open the recipe."] = "클릭하면 제조법을 엽니다."
L["Click to show a recipe again."] = "클릭하면 제조법을 다시 표시합니다."
L["Close"] = "닫기"
L["Complete %s at %d"] = "%s 완료 (%d)"
L["Complete %s at %d (level %d)"] = "%s 완료 (%d, 레벨 %d)"
L["Complete %s first: you're at your cap."] = "먼저 %s을(를) 완료하세요: 숙련도가 최대입니다."
L["Copy link"] = "링크 복사"
L["Copy the address, then open it in your browser."] = "주소를 복사한 후 브라우저에서 여십시오."
L["Cost"] = "비용"
L["Count what crafts sell for"] = "제작품 판매 가격 반영"
L["Craft %d %s"] = "%d개 제작: %s"
L["Craft %d of %d× %s"] = "제작 %d / %d× %s"
L["Craft %d× %s"] = "제작 %d× %s"
L["Craft %s"] = "%s 제작"
L["Craft next"] = "다음 제작"
L["Crafted gear"] = "제작 장비"
L["Crafts"] = "제작 횟수"
L["Crafts %d now."] = "지금 %d개 제작합니다."
L["Don't count it"] = "반영 안 함"
L["Don't suggest this again"] = "다시 제안하지 않기"
L["Drag to move"] = "끌어서 이동"
L["Dropped by"] = "획득처"
L["Each"] = "개당"
L["Each click puts the next one in the search box; press Search."] =
	"클릭할 때마다 다음 재료가 검색창에 들어갑니다. 검색을 누르세요."
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"도보 경로와 배 시간을 보려면 Shortest Path Forever를 켜세요."
L["Every recipe that uses it"] = "이 재료를 쓰는 모든 제조법"
L["Fee"] = "수수료"
L["Fee %s, requires %s (%d)"] = "수수료 %s, 요구 사항: %s (%d)"
L["Feet"] = "발"
L["Finger"] = "손가락"
L["First used at"] = "처음 쓰이는 숙련도"
L["Forever addons"] = "Forever 애드온"
L["Forever tracker"] = "Forever 추적기"
L["Gather %d %s"] = "%d개 채집: %s"
L["Gathering skill on nodes"] = "채집물의 채집 숙련도"
L["Hands"] = "손"
L["Have (bags and bank)"] = "보유 (가방과 은행)"
L["Head"] = "머리"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"약초와 광맥 툴팁에 필요한 숙련도와 내 숙련도 기준 색상을 표시합니다 (영어 클라이언트 전용). 무두질 가능한 시체는 Forever에서 무두질 규칙이 확인될 때까지 ?로 표시됩니다."
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"상인, 퀘스트, 전리품으로 얻을 제조법을 보려면 AtlasLoot를 설치하세요."
L["Install Questie and AtlasLoot to see where recipes, vendors and trainers are."] =
	"제조법, 상인, 전문가의 위치를 보려면 Questie와 AtlasLoot를 설치하세요."
L["Install Questie to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 Questie를 설치하세요."
L["Installed, turned off"] = "설치됨, 사용 안 함"
L["Its trainer should teach these at your skill now:"] =
	"지금 숙련도로 전문가에게 다음을 배울 수 있어야 합니다:"
L["Kept in the Auctionator list '%s'."] = "Auctionator 목록 '%s'에 저장되었습니다."
L["Latest Auctionator prices."] = "최신 Auctionator 가격."
L["Latest Auctionator prices: rescan to update old prices."] =
	"최신 Auctionator 가격: 오래된 가격은 다시 검색해 갱신하세요."
L["Learn a crafting profession to plan a route."] = "경로를 계획하려면 제작 전문 기술을 배우세요."
L["Legs"] = "다리"
L["Level %d"] = "레벨 %d"
L["Level %d %s"] = "레벨 %d %s"
L["Levelling route"] = "숙련도 경로"
L["Made at"] = "제작 장소"
L["Main hand"] = "주장비"
L["Missing reagents for this step."] = "이 단계에 필요한 재료가 부족합니다."
L["Money on recipe rows"] = "제조법 줄의 금액"
L["Nearest trainer"] = "가장 가까운 전문가"
L["Nearest vendor"] = "가장 가까운 상인"
L["Neck"] = "목"
L["Need %d more %s"] = "%d개 더 필요: %s"
L["Need a %s in your bags."] = "가방에 %s이(가) 필요합니다."
L["Needs %s %d"] = "%s %d 필요"
L["Net per craft"] = "제작당 순비용"
L["Next to the recipe"] = "제조법 옆"
L["No crafted gear for your level and class yet."] = "아직 레벨과 직업에 맞는 제작 장비가 없습니다."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"아직 만들 수 있는 장비가 없습니다. 만들 수 없는 장비를 보려면 위의 상자를 선택하세요."
L["No skill data for this recipe yet."] = "이 제조법의 숙련도 정보가 아직 없습니다."
L["No trainer teaches this rank: a book does."] = "이 단계는 전문가가 아닌 책으로 배웁니다."
L["No trainer teaches this rank: a quest does."] = "이 단계는 전문가가 아닌 퀘스트로 배웁니다."
L["Not in this route: you chose Not this recipe."] =
	'경로에서 제외됨: "이 제조법 제외"를 선택했습니다.'
L["Not installed"] = "설치 안 됨"
L["Not this recipe"] = "이 제조법 제외"
L["Nothing on this route is yours to gather, so the switch changes nothing for it."] =
	"이 경로에는 직접 채집할 재료가 없어, 이 설정은 아무것도 바꾸지 않습니다."
L["Nothing priced you know skills up past %d."] =
	"아는 제조법 중 가격이 있는 것으로는 %d 이상 숙련도가 오르지 않습니다."
L["Nothing to buy for this route."] = "이 경로에 구매할 것이 없습니다."
L["Nothing to craft on this route."] = "이 경로에 제작할 것이 없습니다."
L["Nothing you know skills up past %d."] = "아는 제조법으로는 %d 이상 숙련도가 오르지 않습니다."
L["Off hand"] = "보조장비"
L["On"] = "켬"
L["On %s"] = "%s에서"
L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs nothing."] =
	"켜면 채집할 수 있는 재료도 상인이나 경매장 가격으로 계산합니다. 끄면 채집 비용은 0입니다."
L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs what it would sell for."] =
	"켜면 채집할 수 있는 재료도 상인이나 경매장 가격으로 계산합니다. 끄면 채집 비용은 판매 가격입니다."
L["One line in chat the first time a new version loads."] =
	"새 버전을 처음 불러올 때 대화창에 한 줄 표시합니다."
L["Open"] = "열기"
L["Open %s to craft from here."] = "여기서 제작하려면 %s을(를) 여세요."
L["Open recipe"] = "제조법 열기"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"제조법에 마우스를 올리면 주황, 노랑, 초록, 회색 구간을 표시합니다."
L["Per craft"] = "제작당"
L["Per skill-up"] = "숙련도 1당"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"숙련도당은 숙련도 1점을 올리는 비용입니다. 제작당은 한 번 제작할 때 드는 비용이나 수익이며, 더 이상 숙련도가 오르지 않는 제조법에도 표시됩니다."
L["Picks quests for your level and plans them into one journey."] =
	"레벨에 맞는 퀘스트를 골라 하나의 여정으로 계획합니다."
L["Plans the cheapest route to your next profession rank."] =
	"다음 전문 기술 등급까지 가장 저렴한 경로를 계획합니다."
L["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."] =
	"어디든 가장 빠른 길을 계획해 안내하며, 배와 비행선 시간을 실시간으로 보여줍니다."
L["Price"] = "가격"
L["Price %s, requires %s (%d)"] = "가격 %s, 요구 사항: %s (%d)"
L["Prices"] = "가격"
L["Profession reagents"] = "전문 기술 재료"
L["Profit per craft"] = "제작당 이익"
L["Profit per skill-up"] = "숙련도 1당 이익"
L["Quest"] = "퀘스트"
L["Quest automation, rare alerts and merchant handling for the default UI."] =
	"기본 UI용 퀘스트 자동화, 희귀 몬스터 알림, 상인 거래 처리."
L["Quest giver"] = "퀘스트 NPC"
L["Quest, requires %s (%d)"] = "퀘스트, 요구 사항: %s (%d)"
L["Raises your skill cap to %d."] = "최대 숙련도를 %d(으)로 올립니다."
L["Ranged"] = "원거리 장비"
L["Read %s at %d"] = "%s 읽기 (%d)"
L["Read %s at %d (level %d)"] = "%s 읽기 (%d, 레벨 %d)"
L["Read %s first: you're at your cap."] = "먼저 %s을(를) 읽으세요: 숙련도가 최대입니다."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free unless you value them under Prices, and auction prices need Auctionator."] =
	"재료 비용을 숙련도 상승 확률로 나눈 값을 제조법 행과 툴팁에 표시합니다. 흔한 상점 재료는 처음부터 가격이 있고 방문한 상인에서 갱신됩니다. 채집하는 재료는 가격 설정에서 값을 매기지 않으면 무료이며, 경매 가격은 Auctionator가 필요합니다."
L["Reagent tooltips"] = "재료 툴팁"
L["Reagents"] = "재료"
L["Reagents  (have / need)"] = "재료  (보유 / 필요)"
L["Reagents for"] = "재료:"
L["Reagents in hand"] = "재료 준비됨"
L["Reagents still needed"] = "아직 필요한 재료"
L["Recipe rows"] = "제조법 행"
L["Recipe tooltip position"] = "제조법 툴팁 위치"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"계속 올리는 데 쓸 수 있는 상인, 퀘스트, 전리품 제조법:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"기술 전문가 제조법에 요구 숙련도, 숙련도 상승 확률, 비용을 표시하고, 경로상 다음에 배우기 좋은 것을 알려줍니다."
L["Requires"] = "요구 사항"
L["Route"] = "경로"
L["Route and trainer"] = "경로와 전문가"
L["Route incomplete: %d recipes left out, their reagents not priced yet."] =
	"경로 미완성: 제조법 %d개 제외됨, 재료 가격이 아직 없습니다."
L["Route needs"] = "경로 필요량"
L["Route: %d/%d · %s to %d"] = "경로: %d/%d · %s → %d"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"재료 가격을 알려면 Auctionator로 경매장을 검색하거나 상인을 방문하세요."
L["Scroll"] = "제조법"
L["Search"] = "검색"
L["Search reagents at the auction house"] = "경매장에서 재료 검색"
L["Sells for"] = "판매 가격"
L["Sells for x%g"] = "판매 가격 x%g"
L["Set waypoint"] = "웨이포인트 설정"
L["Shift-click to link the scroll."] = "Shift-클릭으로 제조법을 링크합니다."
L["Shift: used in %d of your recipes"] = "Shift: 내 제조법 %d개에 사용"
L["Shoulder"] = "어깨"
L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."] =
	"제 다른 Forever 애드온이 도움이 될 만한 곳에 조용히 한 줄을 표시합니다. 설치하지 않은 애드온만 해당됩니다."
L["Show again: %s"] = "다시 표시: %s"
L["Show cost per skill-up"] = "숙련도 1당 비용 표시"
L["Show gear I cannot make yet"] = "아직 만들 수 없는 장비도 표시"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"목표 추적기에 전문 기술 경로를 표시합니다. 숨겨도 추적 중인 전문 기술과 목표는 유지됩니다."
L["Show skill on recipe rows"] = "제조법 행에 숙련도 표시"
L["Show skill range start on rows"] = "행에 구간 시작점 표시"
L["Show the buy button at merchants"] = "상인에서 구매 버튼 표시"
L["Show the crafted gear tab"] = "제작 장비 탭 표시"
L["Show the levelling route tab"] = "숙련도 경로 탭 표시"
L["Show thresholds tooltip"] = "구간 툴팁 표시"
L["Show tracked professions"] = "추적 중인 전문 기술 표시"
L["Shows the Legacy challenges you can advance in each zone."] =
	"각 지역에서 진행할 수 있는 유산 도전을 보여줍니다."
L["Skill  %d/%d     Target"] = "숙련도  %d/%d     목표"
L["Skill points a craft"] = "제작당 숙련도"
L["Skill range start"] = "구간 시작점"
L["Skill range starts at %d"] = "구간 시작: %d"
L["Skill-up chance"] = "숙련도 상승 확률"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"각 제조법 오른쪽에 숙련도 상승 확률과 숙련도 1당 비용을 표시합니다."
L["Skill-up chance: %d%%"] = "숙련도 상승 확률: %d%%"
L["SkillUp report"] = "SkillUp 보고서"
L["Skipped (%d)"] = "건너뜀 (%d)"
L["Skipped (%d):"] = "건너뜀 (%d):"
L["Sold by"] = "판매처"
L["Sort by"] = "정렬 기준"
L["Sort recipes"] = "제조법 정렬"
L["Sort recipes in one list, learned first, then unlearned. Default restores categories."] =
	'제조법을 한 목록으로 정렬합니다. 배운 것 먼저, 그다음 배우지 않은 것. "기본"은 분류를 되돌립니다.'
L["Source"] = "출처"
L["Source unknown"] = "출처 알 수 없음"
L["Stop tracking"] = "추적 해제"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, are after the 5% cut, and may not sell."] =
	"제작 아이템의 판매 가격을 비용에서 뺍니다. 경매 가격은 Auctionator가 필요하고, 5% 수수료를 뺀 값이며, 팔리지 않을 수도 있습니다."
L["Suggest my other Forever addons"] = "제 다른 Forever 애드온 추천"
L["Taught by %s trainers."] = "%s 기술 전문가가 가르칩니다."
L["The place this recipe is taught isn't known yet."] =
	"이 제조법을 배우는 곳은 아직 알려지지 않았습니다."
L["The rest comes from a vendor or your gathering."] = "나머지는 상인이나 채집으로 얻습니다."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"경로는 %d개로 10번 중 9번은 %d에 도달한다고 봅니다. 운이 나쁘면 더 필요합니다."
L["The source of this recipe isn't known."] = "이 제조법의 출처는 알려지지 않았습니다."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."] =
	"텍스트가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사한 뒤 버그 보고서에 붙여 넣으세요."
L["The tracker is locked. Turn off Lock the tracker to move it."] =
	"추적기가 잠겨 있습니다. 추적기 잠금을 끄면 이동할 수 있습니다."
L["These reagents have no vendor price. Auction prices need Auctionator."] =
	"이 재료들은 상점 가격이 없습니다. 경매 가격은 Auctionator가 필요합니다."
L["This addon"] = "이 애드온"
L["To buy"] = "구매할 금액"
L["Tool"] = "도구"
L["Tooltips and sorting"] = "툴팁과 정렬"
L["Total %s"] = "합계 %s"
L["Track"] = "추적"
L["Tracked routes (Shift for all)"] = "추적 중인 경로 (Shift: 전체)"
L["Train %s"] = "%s 배우기"
L["Train %s at %d"] = "%s 배우기 (%d)"
L["Train %s at %d (level %d)"] = "%s 배우기 (%d, 레벨 %d)"
L["Train %s first."] = "먼저 %s을(를) 배우세요."
L["Train %s first: you're at your cap."] = "먼저 %s을(를) 배우세요: 숙련도가 최대입니다."
L["Trinket"] = "장신구"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"끄면 공유 Forever 추적기를 화면 어디로든 끌 수 있습니다."
L["Update Questie to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 Questie를 업데이트하세요."
L["Used in"] = "사용처"
L["Value gathered materials at what they'd sell for"] = "채집한 재료를 판매 가격으로 계산"
L["Vendor"] = "상인"
L["Vendor reagents"] = "상점 재료"
L["Vendor sell price"] = "상점 판매 가격"
L["Visit a vendor to price reagents. Auction prices need Auctionator."] =
	"재료 가격을 알려면 상인을 방문하세요. 경매 가격은 Auctionator가 필요합니다."
L["Waist"] = "허리"
L["Waypoint to a trainer"] = "전문가로 웨이포인트"
L["Waypoint to a vendor: %s"] = "상인으로 웨이포인트: %s"
L["Waypoint to the quest giver: %s"] = "퀘스트 NPC로 웨이포인트: %s"
L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."] =
	"아이템에 마우스를 올렸을 때 전문 기술 정보를 표시하는 방식: 추적 중인 경로의 필요량 (Shift를 누르면 그 재료를 쓰는 모든 제조법), 해당 제조법 전체와 색상, 또는 표시 안 함."
L["What's new after an update"] = "업데이트 후 새로운 점"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"제조법에 마우스를 올렸을 때 툴팁이 나타나는 위치입니다. 창 옆에 두면 재료를 가리지 않습니다."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"경매장이 열려 있으면 전문 기술 창에서 선택한 제조법의 재료를 검색할 수 있습니다: 가방과 은행을 뺀 뒤 선택한 제작 횟수에 아직 필요한 만큼입니다. Auctionator 구매 목록이 수량을 담고, 없으면 클릭할 때마다 다음 재료가 검색창에 들어갑니다."
L["With Shortest Path Forever, a click leads you there."] =
	"Shortest Path Forever가 있으면 클릭 한 번으로 그곳까지 안내합니다."
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"Shortest Path Forever가 있으면 이동 시간 기준으로 가장 가까운 곳을 골라 안내합니다."
L["World drop"] = "무작위 전리품"
L["Wrist"] = "손목"
L["You have it, requires %s (%d)"] = "보유 중, 요구 사항: %s (%d)"
L["You have this book: read it."] = "이 책을 가지고 있습니다: 읽으세요."
L["You know it"] = "배움"
L["You: %d"] = "나: %d"
L["Your bags allow %d of the route's %d."] = "가방 공간: %d개 가능 (경로 필요량 %d개)."
L["Your bags and bank have enough."] = "가방과 은행에 충분히 있습니다."
L["can't identify the profession %s (%s); please report it."] =
	"전문 기술 %s (%s)을(를) 식별할 수 없습니다. 제보해 주세요."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"추적 재료를 목표 추적기에 추가하지 못했습니다. 제보해 주세요."
L["crafts"] = "회 제작분"
L["drop"] = "전리품"
L["every skipped recipe is back in the route."] = "건너뛴 제조법이 모두 경로에 돌아왔습니다."
L["files are missing: restart the game (not /reload) after updating."] =
	"파일이 없습니다: 업데이트 후 게임을 다시 시작하세요 (/reload 아님)."
L["for %s"] = "%s용"
L["gather"] = "채집"
L["green"] = "초록"
L["grey"] = "회색"
L["item %d"] = "아이템 %d"
L["level %d"] = "레벨 %d"
L["makes %d %s"] = "%d개 생산: %s"
L["no price"] = "가격 없음"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	'건너뛴 제조법이 없습니다: 경로 페이지에서 단계를 오른쪽 클릭하고 "이 제조법 제외"를 선택하세요.'
L["no trainer requirements to check."] = "확인할 전문가 요구 사항이 없습니다."
L["none"] = "없음"
L["not enough money for every missing reagent here."] = "여기서 부족한 재료를 모두 살 돈이 없습니다."
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"여기서 검색할 것이 없습니다: 부족한 것은 상인이나 채집으로 얻습니다."
L["open a profession first."] = "먼저 전문 기술 창을 여세요."
L["open the auction house's Buy tab, then search again."] = "경매장의 구매 탭을 연 뒤 다시 검색하세요."
L["orange"] = "주황"
L["over 3 weeks ago"] = "3주 이상 전"
L["profession %d"] = "전문 기술 %d"
L["quest"] = "퀘스트"
L["recipe %d"] = "제조법 %d"
L["route set to %s, %s."] = "%s(으)로 경로 설정, %s."
L["searching for %s: you need %d more."] = "%s 검색 중: %d개 더 필요합니다."
L["sorting failed and has been turned off: %s"] = "정렬에 실패하여 꺼졌습니다: %s"
L["the %s book"] = "%s 책"
L["the %s quest"] = "%s 퀘스트"
L["the objective tracker isn't available, so tracked reagents can't be shown."] =
	"목표 추적기를 쓸 수 없어 추적 재료를 표시할 수 없습니다."
L["the reagent names are still loading; search again in a moment."] =
	"재료 이름을 불러오는 중입니다. 잠시 후 다시 검색하세요."
L["today"] = "오늘"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"추적 중이지만 목표 추적기 항목이 붙어 있지 않습니다. 제보해 주세요."
L["unknown age"] = "시점 알 수 없음"
L["unknown location"] = "위치 알 수 없음"
L["updated to %s. %s"] = "%s(으)로 업데이트됨. %s"
L["vendor"] = "상인"
L["waypoint set to %s, %s."] = "%s(으)로 웨이포인트 설정, %s."
L["world drop"] = "무작위 전리품"
L["yellow"] = "노랑"
L["you gather it (%s)"] = "직접 채집 (%s)"
L["you gather it (%s), valued at its AH price"] = "직접 채집 (%s), 경매장 가격으로 계산"
L["you gather it (%s), valued at its vendor sell price"] = "직접 채집 (%s), 상점 판매 가격으로 계산"
L["your bags and bank already hold the reagents for that many."] =
	"가방과 은행에 그만큼의 재료가 이미 있습니다."
L["No step yet: learn or train a %s recipe that skills up."] =
	"아직 단계가 없습니다: 숙련도가 오르는 %s 제조법을 배우거나 익히세요."
L["Show thresholds bar on the recipe"] = "제조법에 숙련도 기준 막대 표시" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"주황, 노랑, 초록, 회색 기준과 현재 숙련도 위치를 전문 기술 창의 제조법 아래에 표시합니다. 재료를 가리면 끄세요." -- mt
L["%s (%s to %d)"] = "%s (%s %d까지)" -- mt
L["Buying for %s"] = "%s을(를) 위해 구매" -- mt
L["  %d items have no price yet"] = "  %d개 아이템은 아직 가격이 없습니다"
L["%d x %s - %s each"] = "%d x %s - 개당 %s"
L["%d x %s - price unknown"] = "%d x %s - 가격 없음"
L["%s to %d"] = "%s, %d까지"
L[", "] = ", "
L[", price seen %d days ago"] = ", %d일 전 확인한 가격"
L["/su export - show the trainer requirements this character has seen, to paste into a report"] =
	"/su export - 이 캐릭터가 확인한 전문가 요구 조건을 표시합니다. 보고서에 붙여 넣을 수 있습니다."
L["/su issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/su issue - GitHub 이슈 링크가 준비된 상태로 버그를 신고하거나 기능을 요청합니다."
L["/su report - show a report to copy into a bug report"] =
	"/su report - 버그 보고서에 복사할 보고서를 표시합니다."
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] =
	"구매 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["Bug"] = "버그"
L["Bug: "] = "버그: "
L["Copy issue link"] = "이슈 링크 복사"
L["Copy list"] = "목록 복사"
L["Copy report"] = "보고서 복사"
L["Feature request"] = "기능 요청"
L["Feature request: "] = "기능 요청: "
L["Gather"] = "채집"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "필요 %d, 보유 %d, 부족 %d  %s  개당 %s  %s"
L["No tracked profession"] = "추적 중인 전문 기술 없음"
L["Nothing is missing from the shopping list."] = "구매 목록에서 빠진 것이 없습니다."
L["Nothing to buy"] = "구매할 것 없음"
L["Plan buy trip"] = "구매 경로 계획"
L["Report a bug or request a feature"] = "버그 신고 또는 기능 요청"
L["Shopping list"] = "구매 목록"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever가 전체 경로를 계획할 수 없습니다. 첫 상인으로 웨이포인트를 설정합니다."
L["Shortest Path Forever is needed to plan this trip."] =
	"이 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["SkillUp Forever shopping list"] = "SkillUp Forever 구매 목록"
L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."] =
	"링크가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사한 뒤 브라우저에 붙여 넣으십시오. GitHub에서 내용이 채워진 이슈가 열립니다."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"텍스트가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사하십시오."
L["Title"] = "제목"
L["Total for priced items: "] = "가격이 있는 아이템 합계: "
L["Unknown"] = "알 수 없음"
L["What happened, or what you would like"] = "무슨 일이 있었는지 또는 원하는 점"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"아직 확인한 전문가 요구 조건이 없습니다. 전문 기술 전문가를 연 뒤 다시 시도하십시오."
L["on %s"] = "%s 보유"
L["price unknown"] = "가격 없음"
L["Unpin recipe"] = "제조법 고정 해제" -- mt
L["Pin for skill-ups"] = "숙련도 상승에 고정" -- mt
L["Right-click to pin or skip this recipe."] =
	"오른쪽 클릭으로 이 제조법을 고정하거나 제외합니다." -- mt
L["Unpin: %s"] = "고정 해제: %s" -- mt
L["Pinned for skill-ups."] = "숙련도 상승에 고정됨." -- mt
L["Skill range unknown."] = "숙련도 범위를 알 수 없습니다." -- mt
L["Already grey: no skill-ups."] = "이미 회색: 숙련도가 오르지 않습니다." -- mt
L["Requires skill %d."] = "숙련도 %d 필요." -- mt
L["Learn this recipe first."] = "먼저 이 제조법을 배우세요." -- mt
L["Reagents not priced yet."] = "아직 재료 가격이 없습니다." -- mt
L["Outside this route or a newer pin takes priority."] =
	"경로 밖이거나 최근 고정한 제조법이 우선합니다." -- mt
L["Pinned: %s"] = "고정: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"숙련도 범위가 겹치면 최근 고정한 제조법이 우선합니다." -- mt
L["Pinned (%d)"] = "고정됨 (%d)" -- mt

L["%d. %s (you): %d"] = "%d. %s (나): %d"
L["%d. %s: %d"] = "%d. %s: %d"
L["Distinct recipes observed learned on this character"] =
	"이 캐릭터가 배운 것으로 관찰된 고유 제조법"
L["Guild and group totals are player-reported, not verified."] =
	"길드 및 파티 합계는 플레이어가 직접 보고하며 검증되지 않았습니다."
L["No guild or group member has reported yet."] = "아직 보고한 길드원이나 파티원이 없습니다."
L["Sharing is on. Use /su share off to stop sharing."] =
	"공유가 켜져 있습니다. /su share off로 끌 수 있습니다."
L["Sharing is off. Other players are hidden; your own history is kept."] =
	"공유가 꺼져 있습니다. 다른 플레이어는 숨겨지며 내 기록은 유지됩니다."
L["/su leaderboard - rank distinct recipes observed learned; also /su stats"] =
	"/su leaderboard - 배운 것으로 관찰된 고유 제조법 순위; /su stats도 가능"
L["/su share on|off - control sharing with guild and group"] =
	"/su share on|off - 길드 및 파티와의 공유 설정"
L["Share observed recipe totals with guild and group"] = "관찰한 제조법 합계를 길드 및 파티와 공유"
L["On by default. Turn off to stop sending and receiving totals and hide other players. Local observations stay."] =
	"기본적으로 켜져 있습니다. 끄면 합계 송수신이 중단되고 다른 플레이어가 숨겨집니다. 로컬 관찰 기록은 유지됩니다."

L["Shift-clicking a recipe in the route reliably links it in chat."] =
	"경로의 제작법을 Shift-클릭하면 채팅에 안정적으로 링크됩니다." -- mt
