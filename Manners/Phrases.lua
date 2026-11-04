-- Manners -- the "In character" phrase set.
--
-- The other sets are a list of lines the player can read and edit in the phrase
-- box. This one is chosen at the moment of the click instead, from lines written
-- for the player's own people and side, and for why the buff is going out:
-- thanking somebody who buffed you first, answering somebody who asked, or
-- offering it unasked. A dwarf says something a dwarf would say.
--
-- And it listens to the moment, which is where the best lines come from: the
-- speaker's class, the spell going out, the spell they gave you when this is a
-- thank-you (and what that spell does), how often the two of you have traded
-- this session, whether this is a city, the wilds, a dungeon or a battlefield,
-- the hour (and whether it is the speaker's people's hour), and the class of
-- the person being helped. Each of those is a pool of lines below; a pool
-- joins the draw only when the moment is known to be its moment, and anything
-- the client will not say (a secret, a missing function, a throw) simply
-- leaves its pool out. See RP.Pick for how the pools are weighed against each
-- other, and for the short memory that keeps a line from being heard twice in
-- a row.
--
-- It is active while "In character" is the chosen set and the box still holds
-- the examples it put there; editing the box makes the lines the player's own,
-- as editing any set does. Speech.lua's ns.PickPhrase and ns.PhraseSetText ask this
-- file, and do exactly what they did before whenever it is not the chosen set,
-- or not loaded at all.
--
-- Somebody else's race is asked for one thing, whether they are kin, and their
-- class for one more, which lines about helping their class apply; on this
-- client both are often secrets, and then neither is used.
--
-- Adding lines: every line is a whole L["..."] literal in the pool it belongs
-- to, in the shape the tables below already have. A pool may hold any number;
-- more lines add variety, not airtime (see RP.SPREAD). {name} is their short
-- name and {buff} the spell going out; {gift} is for RP.TRADE and RP.GIFT
-- alone, the only pools that join when somebody has given you something.

local _, ns = ...

local RP = {}
ns.InCharacter = RP

-- Read through a proxy that remembers each translation's English key, because
-- the box keeps whatever language it was filled in: a player who picks the set
-- before the lines are translated has English examples saved, and they must
-- still count as untouched once a later release translates them. The proxy
-- only forwards: every key reaching it is written below as a whole L["..."]
-- literal, which is what the translation audit collects.
--
-- A line reworded in English may be translated as it was, and then the new
-- and the old English are one text. The pools are read before RP.LEGACY, so
-- ENGLISH_NOW keeps the first key read, for the pools as they are, and
-- ENGLISH the last, for the pools before the rewording (RP.BEFORE) and what
-- RP.LEGACY holds.
local ENGLISH, ENGLISH_NOW = {}, {}
local L = setmetatable({}, {
	__index = function(_, key)
		local translated = ns.L
		local text = translated[key]
		ENGLISH[text] = key
		if ENGLISH_NOW[text] == nil then ENGLISH_NOW[text] = key end
		return text
	end,
})

-- UnitRace's second return, the untranslated file name, to the people whose
-- lines it speaks. Allied races share their parent people's voice: a Mag'har
-- says Lok'tar as readily as any orc. The Haranir, new with Midnight, have
-- had lines of their own since 1.7.2, written from what Blizzard has published
-- of them (warcraft.wiki.gg's Haranir and Harandar pages and the quests they
-- cite); a race missing here speaks with its faction's voice and the general
-- lines, which is better than guessing at a culture. The file name is the
-- client's ChrRaces.ClientFileString, not the race's name: "Scourge" for the
-- Forsaken, "EarthenDwarf" for the Earthen, and "Harronir" for the Haranir
-- (wago.tools ChrRaces 86 and 91; Blizzard's own glue screens say HARRONIR).
RP.FAMILY = {
	Dwarf = "dwarf", DarkIronDwarf = "dwarf", EarthenDwarf = "dwarf",
	Human = "human", KulTiran = "human",
	NightElf = "nightelf",
	VoidElf = "voidelf",
	Gnome = "gnome", Mechagnome = "gnome",
	Draenei = "draenei", LightforgedDraenei = "draenei",
	Worgen = "worgen",
	Orc = "orc", MagharOrc = "orc",
	Scourge = "forsaken",
	Tauren = "tauren", HighmountainTauren = "tauren",
	Troll = "troll", ZandalariTroll = "troll",
	BloodElf = "bloodelf",
	Nightborne = "nightborne",
	Goblin = "goblin",
	Vulpera = "vulpera",
	Pandaren = "pandaren",
	Dracthyr = "dracthyr",
	Harronir = "haranir",
}

-- Each people's lines by what the moment is: "thanks" for returning a favour,
-- "asked" for answering a request, "offer" for a buff nobody asked for, "group"
-- for somebody in your own party -- no road, no stranger, no "well met" to a
-- person you have fought beside for an hour -- and "kin" for somebody of the
-- same people. A people with the hour in its bones (the night elves' night,
-- the pandaren's breakfast) has "night" or "morning" lines too, heard next to
-- everybody's at that hour (RP.TIME). A people with a city of its own in
-- RP.HOME may have "city" lines, said there in place of anybody's (RP.PLACE),
-- and "outsider" lines, by moment, about how other peoples take to it, which
-- join that moment's lines for somebody who is not kin, away from home. A kin
-- line joins whichever of the others is being said, so it greets nobody:
-- "well met" is wrong to somebody who just buffed you. No line says "buff"
-- either -- the set is in character, and {buff} is the spell's own name.
--
-- The first few lines of a pool are the phrase box's examples (RP.Examples
-- says how many of which), and a box players have saved is recognised by
-- them: reword or reorder those and every box saved with them reads as the
-- player's own lines, and In character stops. Add new lines after them, and
-- a reworded example goes into RP.LEGACY.reworded as it read before.
-- RP.LEGACY also keeps the lines beta.9 saved, which have been rewritten since.
RP.RACE = {
	dwarf = {
		thanks = {
			L["Thank ye kindly, {name}! First round's on me when we're back at the forge."],
			L["Much obliged, {name}. Ye've a friend in the mountain now."],
			L["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."],
			L["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."],
			L["Paid back already, {name}. Quicker than I've ever settled a bar tab."],
			L["I'll tell this at the Thunderbrew like ye saved me life, {name}. Thank ye!"],
			L["Grand, {name}! I'd carve ye a statue, but this is quicker."],
			L["The Titans made us of stone, {name}, but that still touched me. Thank ye."],
			L["Thank ye, {name}. Back at ye, before me pride notices I needed it."],
			L["Thank ye, {name}. Muradin said a debt left unpaid rusts. Here, before it does."],
			L["Thank ye, {name}. Even me ram looked impressed, and he hates everybody."],
			L["The Explorers' League'll ask where ye dug up such manners, {name}. Thanks!"],
			L["Thank ye, {name}. Warmed me right down to me boots, that did."],
			L["Mined half o' Khaz Modan, {name}. Never struck a vein that rich. Yer cut."],
			L["Like a Kharanos hearth in a Dun Morogh blizzard, that, {name}. Thank ye."],
			L["Came back to ye like a Wildhammer's stormhammer, {name}. Less painful, mind."],
			L["Come to Ironforge, {name}. Me mam'll feed ye till ye can't stand. Thank ye!"],
			L["Checked it fer gunpowder out o' habit, {name}. Clean as a whistle. Here's yers!"],
			L["Thank ye, {name}. Ye'll be the talk o' the Great Forge tonight."],
			L["Not even Magni could've done that kinder, {name}. Louder, aye. Thank ye."],
			L["Thank ye, {name}. I'd offer me beard as surety, but I'm terrible fond of it."],
			L["Back at ye, {name}, quick as a ram goin' downhill. Stoppin' is the hard part."],
			L["Ye'd make a fine honorary dwarf, {name}. We'll work on yer singin'."],
			L["Thank ye, {name}. If ye ever need a tunnel dug, I'm yer dwarf."],
			L["Keep yer powder dry and yer friends closer, me da said. Here, {name}."],
		},
		asked = {
			L["Aye, {name}, ye only had to ask. Hold still now, like a good anvil."],
			L["Say no more, {name}. Stone and steel, here it comes."],
			L["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."],
			L["Right, {name}. Brace yerself; I do everything like I'm swingin' a hammer."],
			L["Aye, {name}, and a story about it ye didn't ask fer. Where to begin..."],
			L["One {buff}, pulled fresh like a proper pint, {name}."],
			L["Done, {name}. Dwarven work: over-built, under-priced and guaranteed."],
			L["Easy, {name}. Last time I helped a gnome, it cost me both eyebrows."],
			L["Aye, {name}. Mountain kings never refuse. I'm more a foothill, but same rule."],
			L["Tempered and quenched, {name}. Mind, it's still hot."],
			L["Done afore ye finished, {name}. Dwarves hear 'please' through solid rock."],
			L["Aye, {name}. In Dun Morogh ye help quick, or ye both freeze standin' there."],
			L["Aye, {name}. Ye'll feel it in yer boots first. That's how ye know it's dwarven."],
			L["Aye, {name}. Say no, and ye'd ask a gnome, and then I'd feel responsible."],
			L["Course, {name}. A dwarf who won't help is no dwarf. Just a short, grumpy rock."],
			L["Mountaineer's promise, {name}: done right, done once. Mostly."],
			L["Fer you, {name}? Easy as findin' ale in Ironforge."],
			L["Ask a Bronzebeard, {name}, and ye get it with both hands. Here."],
			L["Aye, {name}. Stand on that rock there. Good rock, that. Granite."],
			L["Aye, {name}. In the mines, ye shout and somebody comes runnin'. Here I am."],
		},
		offer = {
			L["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."],
			L["Off ye go, {name}, steady as the mountain."],
			L["Here, {name}. Ale's for after; this is for before."],
			L["Magni'd melt down his crown fer a friend, {name}. This is the cheaper option."],
			L["A dwarf's got yer back, {name}. Well, yer knees. Close enough."],
			L["If a trogg bothers ye, {name}, tell it a dwarf sent ye. Then run."],
			L["If it wears off, {name}, give it a good thump. That's how we fix everything."],
			L["Take this, {name}. I'd give ye some stubbornness too, but I'm usin' all mine."],
			L["Mind the wendigos, {name}: big, hairy and grumpy. Like me, but hungrier."],
			L["Take this, {name}. Me grandad fought three wars with a pickaxe and this."],
			L["Dwarven make, {name}. Drop it off Thandol Span and it'd still work. Don't."],
			L["Stonewrought Dam holds back a whole loch, {name}. This'll hold ye together."],
			L["Won't keep yer boots dry in the Wetlands, {name}. Nothin' does. The rest, aye."],
			L["Old miner's rule, {name}: never go down a hole without a lamp, a mate and this."],
			L["Brann Bronzebeard went explorin' with less, {name}, and wrote three books."],
			L["Mountaineers swear by it, {name}. Ye'll climb no better, but land softer."],
			L["Ironforge's gates have never fallen, {name}. Neither should ye. Take this."],
			L["Me cousins down Blackrock way would've set it alight first, {name}. Fer luck."],
			L["Off to Uldaman, {name}? Touch nothin' with runes on it. Trust a dwarf on that."],
			L["Fer the road, {name}. It's no keg o' Thunderbrew, but it travels better."],
			L["A gift from under the mountain, {name}. Mind yer head on the way out."],
			L["A rifleman needs dry powder and a good mate, {name}. I'm the mate. Here."],
			L["If yer road passes Grim Batol, {name}, keep walkin'. And take this."],
			L["From one explorer to another, {name}. The League'll want yer notes after."],
			L["If ye ride a gryphon, {name}, hold on with yer knees and yer prayers. Here."],
			L["A dwarf never lets a friend walk into the dark unready, {name}. Take this."],
		},
		kin = {
			L["Stone and hammer keep ye, cousin {name}!"],
			L["Three Hammers, one round, cousin {name}!"],
			L["Yer cousin's cousin married mine, {name}, I'd wager. It's a small mountain."],
			L["Two dwarves together, {name}. Pity whatever's standin' in our way."],
			L["Bronzebeard, Wildhammer, Dark Iron, Earthen, {name}: one family, nobody agrees."],
			L["Between the pair of us, {name}, we could out-stubborn a mountain."],
			L["Me grandmother'd climb out of her tomb if I did any less fer kin, {name}."],
			L["The Titans carved us both from the same rock, {name}. Explains the headaches."],
			L["Kin's kin, {name}, far from the mountain or under it."],
		},
		group = {
			L["Stand behind me, {name}. Aye, I know. Crouch a bit."],
			L["Right, {name}: I take the front, ye take the loot, and we argue after."],
			L["If I start singin', {name}, the fight's gone well. Or very badly."],
			L["Dwarves never leave a mate behind, {name}. Nor a keg, come to that."],
			L["Beards out, {name}! Them without beards, look fierce. It's nearly as good."],
			L["Knocked on the nearest rock, {name}. Solid. No cave-ins fer us today."],
			L["No fires near me pack, {name}. It's mostly gunpowder. And a sandwich."],
			L["Dwarves don't retreat, {name}. Our legs aren't built fer it."],
			L["Stay close, {name}. If it goes dark, follow the cursin'. That'll be me."],
			L["Dwarves always know which way is down, {name}. Up's yer problem."],
			L["Anythin' made o' stone, {name}, let me talk to it first. Might be a cousin."],
			L["If the ceilin' creaks, {name}, I'll tell ye. If I go quiet, run."],
			L["Shields up, {name}. I'll hold the line. Mountains don't move, and neither do I."],
			L["Watch fer troggs, {name}. Ugly, angry, and they go fer the ankles. My ankles."],
			L["Mind the low beams, {name}. Says the only one here who never has to."],
			L["I've a hammer, a grudge and a good breakfast in me, {name}. We'll be fine."],
			L["Ironforge was carved by folk who never quit halfway, {name}. Neither do we."],
			L["Keep up, {name}! Short legs, but we never stop movin'. That's the secret."],
		},
		morning = {
			L["Mornin', {name}! Too early for ale. Almost. Have this first."],
			L["Up with the forge fires, {name}! A dwarf's day starts with a hammer and this."],
			L["Early, {name}? Nonsense. The mine's been open two hours. Here."],
			L["Mornin', {name}. Me eyes are still abed. The rest o' me's ready."],
			L["Mornin', {name}. Porridge, a pipe and this. The other two are mine."],
			L["The rams had me up at dawn, {name}. Headbutted the door till I came out. Here."],
			L["Mornin', {name}. Ears still ringin' from last night's singin'. Here."],
		},
	},
	human = {
		thanks = {
			L["My thanks, {name}. Let me return the kindness before a bard gets it wrong."],
			L["Kindly done, {name}. Let no one say we forget a friend."],
			L["Thank you, {name}. I'd knight you, but apparently I 'need permission'."],
			L["Repaid on the spot, {name}. In Stormwind that'd take three forms and a stamp."],
			L["Thanks, {name}. Prompter than Stormwind ever paid its stonemasons."],
			L["Much obliged, {name}. Mother said always return a kindness. And the dish."],
			L["Thank you, {name}. In Elwynn, no kindness goes home unanswered."],
			L["You shame me, {name}; I should have thought of it first. Allow me."],
			L["Heartier than Westfall Stew, {name}, and I've wept over that stew. Thank you."],
			L["Thank you, {name}. I'll tell Marshal Dughan. He won't care, but I'll tell him."],
			L["Job's done, {name}! My grandad built half of Stormwind saying that. Thanks."],
			L["Lakeshire will finish its bridge before I forget this, {name}. So, never."],
			L["Kul Tirans say a kindness goes back on the next tide, {name}. There it goes."],
			L["Thank you, {name}. Northshire's brothers would call that the Light at work."],
			L["Not since Mum packed my lunches, {name}, have I felt so looked after. Thanks."],
			L["Into my memoirs, {name}. Chapter nine: 'Everyone Was Lovely'. Thank you."],
			L["I'll toast you at the Pig and Whistle, {name}. Then the pig. Then the whistle."],
			L["Thanks, {name}. My next horse gets your name. He'll be a very good horse."],
			L["I owe you a pint at the Lion's Pride, {name}. This will tide you over."],
			L["Much obliged, {name}. In Elwynn that's neighbourly. Out here, it's heroic."],
			L["Thanks, {name}. We humans don't live long enough to leave a kindness waiting."],
			L["Thanks, {name}. If the Stockade held folk for kindness, you'd be in for life."],
			L["By the Light, {name}, that was good of you. Uther would have liked you."],
			L["Darkshire could use folk like you, {name}. Darkshire could use anyone, mind."],
		},
		asked = {
			L["Of course, {name}. Hold still and look heroic; it helps the bards."],
			L["Right away, {name}. Keep your shield high."],
			L["More work? Gladly, {name}. It beats the lumber mill."],
			L["Of course, {name}. Humans excel at helping and overpromising. This is helping."],
			L["Certainly, {name}. Westfall farm manners: you help first and ask why later."],
			L["Hold still, {name}, like a statue in the Valley of Heroes. You'd fit right in."],
			L["Right away, {name}. The Light helps those who ask. So do I, and I'm quicker."],
			L["Sailors' rule, {name}: somebody calls for help, you row. Here."],
			L["Of course, {name}. Stand up straight; my old sergeant is watching, somewhere."],
			L["Of course, {name}. A polite request is rarer than a quiet night in Duskwood."],
			L["Right away, {name}. I'll play the Archbishop; you pretend to be impressed."],
			L["Stormwind rose from rubble, {name}. I can manage one {buff}."],
			L["Of course, {name}. Last one I did was a Westfall scarecrow. Long story."],
			L["Aye, {name}. Kul Tiran terms: a handshake, and I spare you the shanty."],
			L["Right away, {name}. Bolvar says the realm runs on small kindnesses."],
			L["Gladly, {name}. Elwynn folk never turn away a neighbour, armour and all."],
			L["Of course, {name}. The Light provides. Today it's using me as the courier."],
			L["Of course, {name}. Stormwind raised me on the Light, porridge and saying yes."],
			L["Right away, {name}. At Northshire we answered before the second bell."],
		},
		offer = {
			L["The road ahead is long, {name}. This won't shorten it, but it'll help."],
			L["Fair winds and following seas, {name}."],
			L["Take this, {name}. Elves have centuries to be generous; I've got fifty years."],
			L["A little something, {name}. Don't tell the guards; they'll all want one."],
			L["Here, {name}. If a kobold asks, you don't have a candle."],
			L["For you, {name}. A human gift: well meant, hastily made, surprisingly sturdy."],
			L["Mind the murlocs, {name}. Take this; I've seen what they do to a picnic."],
			L["Every road needs a hero, {name}. Today it's me, apparently. Take this."],
			L["Stay out of Duskwood after dark, {name}. It's always dark. Take this."],
			L["Redridge gnolls take anything not nailed down, {name}. This is nailed down."],
			L["If you meet Hogger, {name}, take this and a friend. Mostly the friend."],
			L["The Light and a good pair of boots, {name}. Now you've got one of them."],
			L["Every hero in Stormwind began with a kindness and a borrowed sword, {name}."],
			L["Here, {name}. The Defias can't steal this one. They've tried everything else."],
			L["Uther blessed strangers on the road, {name}. I've less hammer, same idea."],
			L["Take this, {name}. Goldshire custom: no traveller leaves empty-handed."],
			L["The wolves in Elwynn look friendly, {name}. They are not. Take this."],
			L["Lothar held the line with less, {name}. Granted, he had a very big sword."],
			L["Westfall farmers share even in a bad year, {name}. They're all bad years now."],
			L["Redridge, Duskwood, Westfall, {name}: every road out of Elwynn gets worse."],
			L["Take this, {name}. The guards can't be everywhere. Out here, they're nowhere."],
			L["Bound for Hillsbrad, {name}? Southshore's still ours. Barely. Take this."],
			L["Stromgarde still stands, {name}, mostly out of stubbornness. So will you. Here."],
			L["A Stormwind welcome, {name}: a smile, a blessing and the way to the inn."],
			L["The Argent Dawn says the Light is for all who'll carry it, {name}. Carry some."],
		},
		-- Stormwind and Kul Tiras are both this family, and both Arathor's.
		kin = {
			L["Arathor's children stand together, {name}."],
			L["A fellow human, {name}! Quick, let's found a kingdom before lunch."],
			L["Stormwind or Boralus, {name}, we'll both complain about the weather."],
			L["Human to human, {name}: no, I don't know why everything happens to us either."],
			L["Short lives, long to-do lists, {name}. We humans must help each other along."],
			L["Stormwind stone or Kul Tiran oak, {name}, we outlast everyone's expectations."],
			L["Humans stick together, {name}. Everyone else is taller, older or furrier."],
			L["Our lot built half the world on bread, stubbornness and bad luck, {name}."],
			L["Don't tell the dwarves, {name}, but it was us humans who invented the tavern."],
		},
		group = {
			L["Keep close, {name}. Humans have always won by outnumbering things."],
			L["Stay in formation, {name}. We haven't got one, but stay in it anyway."],
			L["I'll draw up a plan, {name}, and then we can all ignore it together."],
			L["Every hero in the songs had friends, {name}. Nobody sings about them. I will."],
			L["Shields up, {name}. Stormwind taught me to march; nobody taught me to stop."],
			L["If this goes badly, {name}, we regroup at the nearest inn. Human tactics."],
			L["I've made us a flag, {name}. It's a handkerchief on a stick, but it's ours."],
			L["Keep a torch lit, {name}. Humans can't see in the dark, and we hate it."],
			L["Watch my back, {name}; I'll watch yours. The Light has the rest. Better view."],
			L["Humans always rise to the occasion, {name}. Usually after tripping over it."],
			L["Do this well, {name}. Some elf will be telling the story for a thousand years."],
			L["Farmers, sailors, bakers, {name}: every army Stormwind ever raised. Onward!"],
			L["Form up, {name}. One steady line beats a crowd of brave fools. Lothar said so."],
			L["We'll make Stormwind proud, {name}. Or give the town criers something to shout."],
			L["Light keep us, {name}. And if it's busy, I've packed bandages."],
			L["Everyone goes home, {name}. I promised somebody's mother. Probably yours."],
			L["We look like a proper Stormwind patrol now, {name}. Shinier, even."],
			L["Stay sharp, {name}. Lordaeron learned the hard way: never trust the bread."],
		},
	},
	nightelf = {
		thanks = {
			L["Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing."],
			L["Thank you, {name}. Elune smiles on the generous."],
			L["Thank you, {name}. Even the wisps glow brighter, and they're hard to impress."],
			L["Elune saw that, {name}. She sees everything, so I had best return it."],
			L["Thank you, {name}. Kindness planted, kindness grown. Here."],
			L["Thank you, {name}. The Ancients will hear of this. They're dreadful gossips."],
			L["Thank you, {name}. I'll tell the Sentinels to stop aiming at you."],
			L["My people never hurry, {name}. For you, an exception."],
			L["Ande'thoras-ethil, {name}. May your troubles be diminished, as mine just were."],
			L["We gave up immortality at Hyjal, {name}. Kindness has been worth double since."],
			L["My ears have gone a shade darker, {name}. Kaldorei blush there first."],
			L["Azshara's court never gave a thing away, {name}. You've outdone a queen."],
			L["The owls turned their heads for that, {name}. All the way round. High praise."],
			L["I outlived the Sundering, {name}. I'll not outlive a debt to you. Here."],
			L["All those centuries of memories, {name}, and this one goes near the front."],
			L["I'll tell the moon about you tonight, {name}. She likes a good story."],
			L["In Darnassus they'd sing of that, {name}. Quietly, for about a century."],
			L["Thank you, {name}. A Sentinel settles a debt of honour by moonset. So do I."],
			L["Shan'do Stormrage would approve, {name}. He'll tell you himself, when he wakes."],
			L["The Cenarion Circle preaches balance, {name}. You've just tipped it my way."],
			L["Better than a moonwell, {name}. Don't tell the priestesses I said so."],
			L["Even Fandral would smile at that, {name}, and his face has forgotten how."],
			L["Thank you, {name}. I'd send a hippogryph with my thanks, but they bite."],
			L["That warms me like moonlight, {name}. Not very warm, I admit. Still, thank you."],
		},
		asked = {
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Of course, {name}. Elune's blessings are meant to be shared."],
			L["At last, {name}! I've waited ten thousand years for someone to ask."],
			L["No riddle, no omen from Elune, {name}. Just a plain yes, for once."],
			L["Of course, {name}. Ask in Darnassian next time and I'll add a bow."],
			L["Elune already said yes, {name}. I'm merely catching up."],
			L["Of course, {name}. Stand still and pretend you're a tree. It helps."],
			L["Step into the light, {name}. The last kaldorei I did this for Shadowmelded."],
			L["Certainly, {name}. Ask a kaldorei anything, except how old we are."],
			L["In Darnassus, {name}, this takes a moonwell and a priestess. Out here, just me."],
			L["The last army to ask me for help was fighting demons, {name}. You're politer."],
			L["Gladly, {name}. Consider it on loan from Elune. She's never once collected."],
			L["One moment, {name}. My hair is older than most kingdoms, and it tangles."],
			L["Darnassian has nine words for 'yes', {name}. I'll spare you eight of them."],
			L["Of course, {name}. The Sentinels would want a password. I'll accept 'please'."],
			L["Of course, {name}. I'll be swift. Swift for a kaldorei, that is. Do sit down."],
			L["Gladly, {name}. The Sentinels taught me to answer a call before it echoes."],
			L["Be still, {name}. What's done in haste is undone by nightfall, the druids say."],
			L["Gladly, {name}. Elune asks little of us: kindness, patience and good aim."],
			L["Of course, {name}. The forest gave me plenty. It would sulk if I didn't share."],
		},
		offer = {
			L["Elune-adore, {name}. Walk softly; the trees are light sleepers."],
			L["May the forest shelter you, {name}, wherever you roam."],
			L["A gift from the shadows, {name}. No, don't look. You won't find me."],
			L["Elune lights your path, {name}. I'm merely holding the lantern."],
			L["The owls pointed you out, {name}. They have strong opinions. Here."],
			L["Tyrande would insist, {name}, and nobody argues with Tyrande."],
			L["Take this, {name}. The last one went to a hippogryph. It was less grateful."],
			L["Mind the wildlife, {name}. Half of it is a druid, and all of it is watching."],
			L["Walk with Elune, {name}. If she's busy, walk with this."],
			L["Mind the satyrs, {name}. They were Highborne once. You can tell by the sneer."],
			L["The trees spoke well of you, {name}. I thought I'd add my word."],
			L["Most furbolgs are friendly, {name}. This is for the other ones."],
			L["Moonwell water would be better, {name}, but it travels badly. This doesn't."],
			L["A gift from Teldrassil, {name}. It's a long way down; I nearly dropped it."],
			L["I'd stay to chat, {name}, but kaldorei chats run to the next full moon. Here."],
			L["Bandu thoribas, {name}: prepare to fight. There. Now you're prepared."],
			L["From the kaldorei, the moon and a very old tree, {name}. Mostly from me."],
			L["Ashenvale remembers every axe, {name}. Carry this, and leave yours sheathed."],
			L["The Sentinels will know you're a friend, {name}. Probably. Wave a lot."],
			L["May the moon guide you, {name}, and this keep you until it rises."],
			L["Moonglade welcomes all who come in peace, {name}. So does this."],
			L["Darkshore is beautiful, {name}, and full of things that bite. Take this."],
			L["My people learned the hard way not to hoard magic, {name}. So, here."],
			L["Felwood was a forest like any other once, {name}. Stay well; it didn't."],
			L["Bound for Stonetalon, {name}? Mind the goblins' saws. The trees certainly do."],
			L["If you meet an Ancient, {name}, bow. They notice, and they never forget."],
		},
		kin = {
			L["Ishnu-alah, {name}. Elune keeps her children close."],
			L["Of course I saw you, {name}. It takes a kaldorei to spot a kaldorei."],
			L["Kaldorei to kaldorei, {name}: we gave up eternity, not each other."],
			L["A kaldorei never leaves kin in the dark, {name}. Unless it's for cover."],
			L["Two kaldorei, {name}, and still no helmet made that fits either pair of ears."],
			L["Sentinel, druid or simply stubborn, {name}? I'm all three on a good night."],
			L["Between us, {name}, twenty thousand years of telling everyone 'we tried that'."],
			L["Let's Shadowmeld together sometime, {name}, and see who notices."],
			L["Our shan'do sleeps in the Dream, {name}. Let's make his waking worth it."],
			L["Our people are thin on the ground, {name}, and very thick in the trees."],
		},
		group = {
			L["Quick one, {name}? By kaldorei reckoning we'll be done before we start."],
			L["I'll be the one you can't see, {name}. That's not a mistake; that's the plan."],
			L["Elune watches the whole party, {name}. I'm just the one who waves at her."],
			L["Ten thousand years of companions, {name}. You lot rank rather high."],
			L["Stay close, {name}. We misplaced half a continent once. Not you, though."],
			L["If I fall, {name}, don't fret. I'll float about as a wisp, looking wise."],
			L["I fought beside Neltharion once, {name}. You're already a better ally."],
			L["Follow me, {name}. I know these paths. They were a forest last time, mind."],
			L["Should we fail, {name}, I'll remember you fondly for several thousand years."],
			L["I've watched heroes charge in blind for millennia, {name}. Let's try eyes open."],
			L["I'll take first watch, {name}. And second. A kaldorei barely notices a night."],
			L["Keep your voices low, {name}. The forest listens, and it has a long memory."],
			L["We held back the Legion with fewer than this, {name}. We'll be fine."],
			L["A Sentinel never looses an arrow she'd want back, {name}. Choose your moments."],
			L["Dark in there, {name}? Follow me. The night is where my people live."],
			L["Moving out, {name}. Silent as owls if we can, silent as dwarves if we can't."],
			L["I'll watch the shadows, {name}. Nothing moves in them without my say."],
		},
		night = {
			L["The moon's up, {name}. For a kaldorei, this is the middle of the morning."],
			L["Everyone sensible is asleep, {name}. Elune and I prefer it this way."],
			L["Elune's light is on you, {name}. Here's a second layer."],
			L["Dark at last, {name}. Now I see perfectly and everything else has to guess."],
			L["Same stars I saw ten thousand years ago, {name}. They've aged better than me."],
			L["Moonrise, {name}. Every kaldorei just woke up a little, and got a little smug."],
		},
		morning = {
			L["Morning, {name}. My people slept through these for millennia. I'm adapting."],
			L["Dawn, {name}. Elune's gone to bed, so I'm covering for her."],
			L["The sun's up, {name}, and so, reluctantly, am I."],
			L["Too bright, {name}. I'll squint through this one; Elune forgives squinting."],
			L["Daybreak, {name}: the one hour a night elf is easy to spot. Quick, take this."],
			L["Up early, {name}? I'm up late. Let's meet in the middle, with this."],
		},
	},
	voidelf = {
		thanks = {
			L["The shadows remember kindness, {name}. So do I."],
			L["My thanks, {name}. The ren'dorei do not forget a kindness."],
			L["Thank you, {name}. The voices approve of you, which is frankly alarming."],
			L["Thank you, {name}. Few give gifts to someone who glows this ominously."],
			L["Kindness is rare in the Void, {name}. I'll return yours before it notices."],
			L["Silvermoon threw us out, {name}. People like you make it hard to mind."],
			L["Returned in full, {name}. It may be slightly purple. That's normal."],
			L["The Void only takes, {name}. I, however, give back."],
			L["Thank you, {name}. The whispers went quiet. That's how I know it was sincere."],
			L["Thank you, {name}. I'd smile, but people say it's unsettling. So: imagine one."],
			L["Returned, {name}: cold hands, warm intentions. That's us in a sentence."],
			L["Returned, {name}. You may hear it twice; my spells echo now."],
			L["The Void offered me forbidden knowledge, {name}. Yours was the nicer gift."],
			L["Alleria says the Void can be mastered, {name}. Kindness, I find, is easier."],
			L["Much obliged, {name}. Most people give us a wide berth. You gave me this."],
			L["Thank you, {name}. My shadow bowed as well. It never does. You've impressed it."],
		},
		asked = {
			L["As you wish, {name}. The shadows answer kindly today."],
			L["Consider it done, {name}. The Void obeys us, not the other way round."],
			L["Certainly, {name}. The whispers said no, so it's an easy yes."],
			L["Of course, {name}. One {buff}, lightly seasoned with the Void."],
			L["Of course, {name}. Hold still; the shadows are shy with strangers."],
			L["Gladly, {name}. Ren'dorei manners: the Void waits its turn."],
			L["Asked so nicely, {name}? Then you'll have my best."],
			L["Of course, {name}. Stand in the light, please; the Void gets ideas in corners."],
			L["Of course, {name}. The Void asked why. I said 'manners'. It's still puzzled."],
			L["Gladly, {name}. Nobody asks us for anything but 'please stop whispering'."],
			L["Happy to, {name}. Just let me finish arguing with myself. There. I won."],
			L["Certainly, {name}. I could rift over there first, but that feels showy."],
			L["Asking questions got us exiled, {name}. Answering one is quite safe, I'm told."],
			L["Of course, {name}. A slight chill and a faint chorus are both perfectly normal."],
		},
		offer = {
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
			L["Walk carefully in the dark places, {name}."],
			L["A little something from the Telogrus Rift, {name}. It's cleaner than it sounds."],
			L["Take this, {name}. Any tentacles you see are purely decorative."],
			L["The shadows asked after you, {name}. I told them to mind their manners."],
			L["Here, {name}. We walked into the Void so you wouldn't have to."],
			L["I checked your shadow, {name}. Nothing lurking. Take this anyway."],
			L["Umbric sends his regards, {name}. He doesn't, but he would."],
			L["Take this, {name}. It may whisper a compliment. Pretend you didn't hear."],
			L["Here, {name}. Looks sinister, works beautifully. Rather like me."],
			L["Take this, {name}. The Void had worse in mind for you. I intercepted."],
			L["If the dark whispers at you today, {name}, pay it no mind. Take this."],
			L["Here, {name}. We ren'dorei don't often get to be the nice surprise."],
			L["I left Quel'Thalas with only a knack for the dark, {name}. Here's the knack."],
			L["Here, {name}. Don't thank the shadows; they'll only want something. Thank me."],
			L["I owe a kindness for every ominous look I've given, {name}. I'm badly behind."],
		},
		kin = {
			L["We ren'dorei look after our own, {name}."],
			L["Silvermoon's loss, {name}. We're doing splendidly without it."],
			L["Your whispers and mine should really meet sometime, {name}."],
			L["Two ren'dorei in one place, {name}. Quick, look brooding. It's expected."],
			L["Nobody else understands the hair, {name}. It was blond once. I think."],
			L["Telogrus felt like home in the end, {name}. A very draughty, very dark home."],
			L["Ren'dorei to ren'dorei, {name}: what's yours whispering? Mine's on about soup."],
		},
		group = {
			L["Stay close, {name}. The whispers are much quieter in company."],
			L["If the shadows start giving orders, {name}, ignore them. I usually do."],
			L["Keep an eye on my shadow, {name}. It wanders off when there's a fight."],
			L["If I start glowing purple, {name}, carry on. It only means I'm keen."],
			L["We ren'dorei make fine companions, {name}. We bring our own dark to hide in."],
			L["If I seem to talk to nobody, {name}, I'm fine. If nobody talks back, worry."],
			L["I'll open a rift if it goes wrong, {name}. Only for me, sadly. But I'll wave."],
			L["Try to enjoy this, {name}. We ren'dorei rarely get invited anywhere twice."],
			L["Keep the lanterns lit, {name}. I don't need them; the shadows behave better."],
			L["Keep an eye on the corners, {name}. I'll keep an eye on what's in them."],
			L["The Void promised me power, {name}. It never mentioned company this good."],
			L["If you hear whispers mid-fight, {name}, they're cheering. For us, I think."],
			L["Should anything eldritch turn up, {name}, let me talk to it. I speak a little."],
		},
		night = {
			L["Night suits the ren'dorei, {name}. We match the decor."],
			L["The shadows are longest now, {name}, and in a very generous mood."],
			L["Late, {name}? The whispers love a late hour. Lately, so do I."],
			L["Midnight, {name}. The one hour my shadow and I agree on anything."],
			L["Stars out, {name}. I've seen what's between them, and I prefer the stars."],
		},
	},
	gnome = {
		thanks = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Reciprocity engaged! Much obliged, {name}."],
			L["By my calculations, {name}, you're owed exactly one {buff}."],
			L["Thanks, {name}! I'd build you a thank-you machine, but it'd explode."],
			L["Thank you, {name}! Gnomeregan's finest couldn't have timed that better."],
			L["You're too kind, {name}! Returning the favour took only four schematics."],
			L["Drat, {name}! I was going to invent gratitude, but you beat me to it."],
			L["Oh, {name}, how kind! My heart's doing that whirring thing again."],
			L["Noted in my lab journal, {name}, page four hundred: 'people are lovely'."],
			L["Splendid, {name}! Returning it at once, before I'm tempted to improve it."],
			L["Thanks, {name}! Kindness is a reversible reaction. I checked. Here's yours."],
			L["My mechanostrider would salute you, {name}, but it only knows falling over."],
			L["My transporter would've sent this to Gadgetzan, {name}. Hand-delivered instead!"],
			L["Oh, thank you, {name}! I haven't felt this good since before the troggs."],
			L["I'll name my next invention after you, {name}! It's a very small cannon."],
			L["Thanks, {name}! Ironforge has been good to us gnomes, and so have you."],
			L["You're on my list of favourite people, {name}! It's short. Mostly clockwork."],
			L["Thanks, {name}! A gift with no gears in it. I didn't know they made those."],
			L["Thank you, {name}! I'd pay you back with interest, but my abacus is in pieces."],
			L["When we retake Gnomeregan, {name}, you get a window seat. We'll add windows."],
			L["Exactly what I needed, {name}, and I didn't even have to build it. Thanks!"],
			L["The tall folk rarely notice us gnomes, {name}. You did. Thank you!"],
			L["Tinker Town will hear all about you, {name}. Loudly, over the machinery."],
			L["It worked first time, {name}! Nothing I make works first time. Marvellous!"],
		},
		asked = {
			L["Request received, {name}! Processing... done!"],
			L["One upgrade, coming right up, {name}! Stand still for calibration."],
			L["Of course, {name}! I built a machine for this. It's in pieces, so: by hand."],
			L["Certainly, {name}! Stand on the X. There's no X. Stand anywhere."],
			L["Right away, {name}! Goggles on. Not for you, I just like them."],
			L["{buff}, {name}? Simple in theory and practice. Suspicious!"],
			L["Happy to, {name}! Keep hands, feet and eyebrows well clear."],
			L["Right away, {name}! Stand back three paces. Four. Five. There, perfect."],
			L["Happy to, {name}! It beats sorting springs by size. Though that's fun too."],
			L["Excellent request, {name}! No moving parts. I'll try to add some next time."],
			L["Standard model or deluxe, {name}? They're the same. Deluxe sounds nicer."],
			L["Coming up, {name}! Fresh off the workbench, still warm, only slightly smoking."],
			L["Approved, {name}! Stamped, signed and filed under 'obviously'."],
			L["Of course, {name}! A twist of the gyromatic micro-adjustor... there!"],
			L["Gnomes never refuse a problem, {name}. Occasionally we cause them. Here!"],
			L["Right away, {name}! Tested on three volunteers and one very brave squirrel."],
			L["Happy to, {name}! Measure twice, zap once. Gnome proverb. Well, my proverb."],
			L["Of course, {name}! The High Tinker says help where you can. I can, so here!"],
			L["On it, {name}! I'll need a ladder. No? Just this, then."],
			L["Delighted, {name}! It's nice to fix something that doesn't fight back."],
		},
		offer = {
			L["Hold still, {name}, this is perfectly safe. Probably!"],
			L["Science says you need this, {name}. Who am I to argue?"],
			L["A small upgrade for you, {name}. No cogs required."],
			L["Take it, {name}, I've a spare. I've three spares of everything."],
			L["Try this, {name}! Version one had legs. Version two is much better."],
			L["The High Tinker says share our genius, {name}. Here's a sample!"],
			L["Gnomeregan Forever, {name}! This lasts rather less, but it's free."],
			L["I'm small, {name}, but my gifts come full-sized. Here!"],
			L["Don't worry, {name}! It worked on the chicken, and the chicken's thrilled."],
			L["Field notes say it works on everyone, {name}. Let's make it unanimous!"],
			L["One size fits all, {name}, gnome to tauren. I measured. The tauren was patient."],
			L["Take this, {name}! Unlike my Net-o-Matic, it never lands on me."],
			L["The Gnomish Army Knife does twelve things badly, {name}. This does one well."],
			L["Guarantee void if exposed to troggs, dragonfire or enthusiasm, {name}. Enjoy!"],
			L["Nothing up my sleeves, {name}! Well, a spanner and two fuses. Nothing sinister."],
			L["Here, {name}! It's small, but so is a keystone, and look what those hold up."],
			L["I'd explain how it works, {name}, but that takes three days and a chalkboard."],
			L["If you hear ticking, {name}, that's my pocket watch. Almost certainly."],
			L["A dash of arcane, a pinch of science, {name}, and no troggs involved. Here!"],
			L["Ironforge took us gnomes in when we needed it, {name}. I'm passing it along."],
			L["Here, {name}! It doesn't whistle, spin or catch fire. I'm working on all three."],
			L["Here, {name}! Unwrapped, sorry. The wrapping machine wrapped itself again."],
			L["My mechanostrider wanted to give you something, {name}. It lacks the hands."],
			L["Off on an adventure, {name}? Take this, and bring me back anything that ticks."],
			L["Reliable as the Deeprun Tram, {name}. That's a compliment, I promise. Here!"],
			L["For you, {name}! One part magic to two parts confidence. Mostly confidence."],
		},
		kin = {
			L["For Gnomeregan, {name}! Always nice to talk to somebody at eye level."],
			L["A fellow gnome, {name}! I'll hold the schematic; you hold the bucket."],
			L["Flesh or cogs, {name}, we're all gnomes. Some of us just need oiling."],
			L["One gnome to another, {name}: you did turn the reactor off, didn't you?"],
			L["Two gnomes, {name}! Stacked up, we're very nearly a night elf."],
			L["You check my sums, {name}, I check yours, and we're both quietly offended."],
			L["You still owe me a sprocket, {name}. Every gnome owes me a sprocket."],
			L["One day, {name}, we'll walk back into Gnomeregan together. With the lights on."],
			L["Between gnomes, {name}: we both know it'll explode, and we both want to watch."],
			L["Shall we build something huge, {name}? Just to see the tall folk's faces?"],
		},
		group = {
			L["Party-wide calibration complete, {name}! Nobody touch anything shiny."],
			L["I've run the numbers, {name}: with you here, we win. I rounded up."],
			L["If I shout 'duck', {name}, don't look for a duck. That went badly last time."],
			L["Formation, {name}: tall folk at the front, me somewhere safe and clever."],
			L["Everyone gets one, {name}! Standardised parts are the secret of a good machine."],
			L["My plan, {name}: step one, survive. Step two is still in development."],
			L["Don't panic, {name}. Whatever goes wrong, I'll have a gadget for it. Next week."],
			L["If I vanish, {name}, check under the nearest boot. Politely, please."],
			L["When this is over, {name}, I want samples. Of everything. The big one first."],
			L["Every explosion today, {name}, is on purpose. I'll decide which ones later."],
			L["Clipboard ready, {name}! Today I'm writing down everyone's heroics."],
			L["If we get separated, {name}, follow the smoke. It'll be me."],
			L["Everyone keep their fingers, {name}. I've counted. I'll count again after."],
			L["Ready, {name}? Spare gears, spare fuses, spare plan. Possibly two."],
			L["Leave the traps to me, {name}. I've built most of them. Not these. But similar."],
			L["Before we go in, {name}: has anyone seen my wrench? It's mildly important."],
			L["For Gnomeregan, {name}! And for everywhere else, while we're at it."],
			L["If I get carried off, {name}, please retrieve my notes first. Then me."],
			L["This is an experiment, {name}. Hypothesis: we win. Let's go and test it."],
		},
		morning = {
			L["Morning, {name}! Up since three. The toaster needed a new engine."],
			L["Good morning, {name}! The coffee's brewing itself. It learned how. Worrying."],
			L["Early start, {name}! Best ideas come before breakfast. So do the explosions."],
			L["Morning, {name}! Tinker Town's been clanking since dawn, and so have I. Here!"],
			L["Up early, {name}? I dreamt of a better sprocket and couldn't wait. Here!"],
			L["Morning, {name}! The sun's a bit dim today. I've been meaning to fix that."],
		},
	},
	draenei = {
		thanks = {
			L["The Light rewards kindness, {name}. I'm simply its fastest courier."],
			L["Archenon poros, {name}. Your gift is returned."],
			L["Thanks, {name}. I'd offer a lift in the Exodar, but you've seen how it lands."],
			L["A gift freely given, {name}. The naaru hum a little louder. Returned."],
			L["Kindly done, {name}. On Argus we'd have carved that in crystal. Here."],
			L["Across a dozen worlds, {name}, kindness is the one tongue I never had to learn."],
			L["What a kindness, {name}. It almost makes up for the Legion. Almost."],
			L["Thank you, {name}. I'd say it in Draenei, but that takes eleven minutes."],
			L["Thank you, {name}. My people call that a debt of honour. Here."],
			L["Sargeras once offered my people gifts, {name}. We ran. Yours, I'll keep."],
			L["Thank you, {name}. I've fled demons across the stars, but never from a debt."],
			L["Thank you, {name}. I'll add you to my prayers. The list goes back to Argus."],
			L["The Legion took a world from us, {name}. Folk like you keep giving bits back."],
			L["You gave first, {name}. A prophet would call it an omen. I call it manners."],
			L["With the Light's compliments, {name}. It asked me to add 'nicely done'."],
		},
		asked = {
			L["Of course, {name}. The naaru guide your steps; this puts a spring in them."],
			L["Gladly, {name}. The Light answers those who ask."],
			L["Velen foresaw you asking, {name}. I foresaw saying yes."],
			L["The Light is not rationed, {name}. Take as much as you like."],
			L["Of course, {name}. I've outrun the Burning Legion; I can manage this."],
			L["At once, {name}. Hooves planted, crystals humming, here it comes."],
			L["Gladly, {name}. I followed a talking crystal across the stars. This is easy."],
			L["Certainly, {name}. Velen taught us patience. Luckily, this takes none."],
			L["Gladly, {name}. The naaru never say no. They say 'hmmm', but it means yes."],
			L["On the Exodar this took three crystals and a prayer, {name}. Here: the prayer."],
			L["Of course, {name}. I only refuse demons, and they so rarely say please."],
			L["Gladly, {name}. We were refugees long enough to know what asking costs."],
			L["Of course, {name}. My people crossed the stars looking for friends. Found one."],
			L["Ask a draenei, {name}: one yes, one blessing, possibly a history lesson."],
		},
		offer = {
			L["The Light is with you, {name}. Go in peace, or at least go prepared."],
			L["Walk in the Light, {name}. May it shelter you always."],
			L["Take this, {name}. My people always travel Light."],
			L["Take this, {name}. The Legion is always coming. I'd know."],
			L["I'm out of miracles today, {name}. Will {buff} do?"],
			L["For the road, {name}. Mine has been twenty-five thousand years long."],
			L["Blessed by a naaru, {name}. Well, I stood near one. It still counts."],
			L["Take this, {name}. It glows a bit. Everything we own does."],
			L["Here, {name}. We draenei pack for the end of the world. We've had the practice."],
			L["Take this, {name}. The crystals only hum like that for friends."],
			L["The naaru shine on all, {name}. Here is your share."],
			L["A stranger shared bread with me on Azuremyst, {name}. I'm still paying it back."],
			L["Velen sees a thousand futures, {name}. I see one: you, better prepared. Here."],
			L["Don't drink from the streams on Bloodmyst, {name}. Do take this."],
			L["Eredar magic from before the fall, {name}. We only kept the good kind. Here."],
		},
		kin = {
			L["Archenon poros, {name}! The children of Argus look after one another."],
			L["Home is wherever two draenei meet, {name}. Today, it's here."],
			L["We crossed the stars on the same ship, {name}. That still means something."],
			L["Tails up, {name}. Argus would be proud of what we've made of exile."],
			L["Two draenei, {name}, and between us nearly fifty thousand years of worrying."],
			L["Horns, hooves and hope, {name}. The Legion never found a cure for any of them."],
			L["Children of Velen, {name}: exiled, hopeful and dreadfully polite."],
			L["Third world's the charm, {name}. We draenei are owed one that stays put."],
		},
		group = {
			L["Stay near, {name}. I lost a world once; I'm keeping hold of this party."],
			L["Twenty-five thousand years on the run, {name}. Walking with friends is nicer."],
			L["The naaru would call this a fellowship, {name}. I call it good luck."],
			L["I've watched worlds end, {name}. Whatever's ahead of us hardly worries me."],
			L["Stay together, {name}. The Light finds us easier when we're all in one place."],
			L["Stay close, {name}. We draenei are very good at leaving places in a hurry."],
			L["We draenei take the long view, {name}. This fight will be a footnote."],
			L["Let me go first, {name}. Anything watching will see a very tall optimist."],
			L["We draenei follow prophets, {name}. Today I'll settle for following you."],
			L["The Exodar carried thousands, {name}, and this little party still feels safer."],
			L["Shoulder to shoulder, {name}. Mine's a bit higher, but the principle holds."],
			L["A short prayer for the party, {name}. The long one would take an age."],
		},
	},
	worgen = {
		thanks = {
			L["Much obliged, {name}. Gilneas never forgets a kindness, and nor does my nose."],
			L["Thank you, {name}. You have my gratitude, and my best howl."],
			L["Thank you, {name}. If worgen had tails, mine would be wagging."],
			L["You've made a friend for life, {name}. Loyalty is rather our thing."],
			L["The beast in me wants to growl, {name}. The Gilnean in me insists on thanks."],
			L["Thank you, {name}. I'd offer a hand, but mine have claws now."],
			L["We walled ourselves off for years, {name}. You make that look silly."],
			L["Obliged, {name}. You've earned a spot by the fire. The good spot."],
			L["Thank you, {name}. Gilneas had a word for folk like you: neighbour."],
			L["Returned, {name}, with a stiff upper lip. The lower one shows teeth; ignore it."],
			L["Thank you, {name}. I'd tip my hat, but it doesn't fit over the ears these days."],
			L["Thank you, {name}. Most folk just scratch my ears and hope for the best."],
			L["Returned, {name}. A Gilnean pays debts; a worgen pays them at a sprint."],
			L["My mother would have had you round for tea, {name}. Thank you."],
		},
		asked = {
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Right you are, {name}. Stand steady now."],
			L["Right away, {name}. Stay, now. I've always wanted to say that."],
			L["Gladly, {name}. Rain or shine, and in Gilneas it's rain."],
			L["Certainly, {name}. Mind the claws."],
			L["Say no more, {name}. These ears heard you before you'd decided to ask."],
			L["Of course, {name}. You asked nicer than the last fellow who threw me a stick."],
			L["Glad to, {name}. Few people ask a seven-foot wolf for favours. I love it."],
			L["Certainly, {name}. I'll stay in this form. The other one causes a scene."],
			L["Straight to business without tea, {name}? How un-Gilnean."],
			L["Of course, {name}. In Gilneas, nobody had to ask twice."],
			L["Of course, {name}. It would be rude to keep you waiting."],
			L["Of course, {name}. Anything but a bath."],
		},
		offer = {
			L["Stay off the moors after dark, {name}. Take this."],
			L["Keep your wits about you, {name}. Something is always hunting."],
			L["I'd have brought this sooner, {name}, but I stopped to chase something."],
			L["For you, {name}. No, I don't want a treat. Well. Perhaps a small one."],
			L["Gilneans always offer, {name}. The claws are just part of the outfit."],
			L["An old Gilnean remedy, {name}. Good for colds, gloom and most curses. Not mine."],
			L["Run with this, {name}. Trust me, I know about running."],
			L["Brought you this, {name}. Don't make a fuss over it."],
			L["Here, {name}. Gilnean roads were never safe alone, and nor are these."],
			L["For you, {name}. Not everything that prowls was as well raised as I was."],
			L["From a Gilnean of good family, {name}. The fur is new; the manners are old."],
			L["Someone did this for me in Duskhaven once, {name}. I never forgot."],
			L["Liam would have cried 'For Gilneas!', {name}. I'll just say: for you."],
			L["Tal'doren's druids taught me to leash the beast, {name}. It lets me do this."],
			L["Be careful out there, {name}. Take it from someone who was bitten once."],
			L["Here, {name}. In Gilneas we'd have sent it with a jar of preserves."],
			L["Take this, {name}. I'd offer my coat, but it's attached."],
			L["Here, {name}. Chin up, hackles down. Words to live by."],
		},
		kin = {
			L["The curse binds us, {name}, but Gilneas binds us tighter."],
			L["No need to explain the ears to you, {name}."],
			L["Fur, fog and rain, {name}. Only a Gilnean understands all three."],
			L["Pack looks after pack, {name}. Always has."],
			L["Do you shed this badly too, {name}? Between us we could knit a third worgen."],
			L["Two worgen, {name}. Somewhere, a cat's having a very bad day."],
			L["Honestly, {name}, do you ever forget which form you left home in?"],
			L["Gilnean to Gilnean, {name}: the finest-mannered wolves in all Azeroth."],
		},
		group = {
			L["Pack rules, {name}: nobody wanders off, and nobody mentions the fleas."],
			L["A pack again, {name}. I hadn't known how much I'd missed one."],
			L["I'll catch the scent of trouble first, {name}. It's the one perk of the curse."],
			L["If I howl, {name}, it's a battle cry. Howl back if you like."],
			L["Lead on, {name}. I'll trot. It's undignified, but it's much quicker."],
			L["If I stop and stare at a wall, {name}, something's behind it. Or it's a wall."],
			L["Years on the Greymane Wall, {name}. Holding a line with you is a holiday."],
			L["After this, {name}, a proper cup of tea. Before this, a proper mauling."],
			L["If I limp back, {name}, don't fuss. Worgen mend quickly."],
			L["When we rest, {name}, I'll take first watch. I hear everything anyway."],
			L["Stay together, {name}. Being a lone wolf is overrated."],
		},
		night = {
			L["Night again, {name}. I'm at my best and my worst. This is the best part."],
			L["Look at that moon, {name}. Gilneas taught us not to trust it."],
			L["Gilneas at night was fog and footsteps, {name}. These days I'm the footsteps."],
			L["Curfew in Gilneas was sundown, {name}. For good reason, as it turned out."],
			L["Something out there keeps rustling, {name}. Stay close; I'll look."],
			L["Past dark, {name}: ears up, nose working, manners on. Two out of three will do."],
		},
		morning = {
			L["Morning, {name}. I'd have been up sooner, but the rug by the fire was so warm."],
			L["Smells like rain this morning, {name}. Everything in Gilneas smelled like rain."],
			L["Up already, {name}? I've been prowling since first light."],
			L["Morning, {name}. Tea, toast, a shave. The shave takes rather longer now."],
			L["Morning, {name}. The birds woke me, so I woke the birds. It seemed only fair."],
			L["Morning, {name}. The fog's lifting, which it never did in Gilneas."],
		},
	},
	orc = {
		thanks = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["You give freely, {name}. I return the favour."],
			L["Orcs keep their thanks short, {name}. Thanks."],
			L["Orcs return every blow twice, {name}. The kind ones too."],
			L["You helped me, I help you, {name}. That is the old way."],
			L["In the old days I'd have repaid you with a boar, {name}. This keeps better."],
			L["Owing somebody itches worse than Durotar sand, {name}. There. Itch gone."],
			L["Strong stuff, {name}. I could wrestle a kodo now. So can you."],
			L["Ambushed by kindness, {name}. No orc trains for that. Returned in full."],
			L["Honour is a debt, {name}, and orcs pay on the spot."],
			L["An orc remembers a kindness like a scar, {name}: fondly, and for good."],
			L["I'd give you my axe, {name}, but we're not that close yet. Take this."],
			L["Thanks, {name}. My wolf growled at you. That's how he says it."],
			L["I've had gifts from shamans and chieftains, {name}. None came so freely."],
			L["We once took strength from demons, {name}. Yours comes on far better terms."],
			L["The spirits saw that, {name}. They'll remember it, and so will I."],
			L["I'll carve that on my axe handle, {name}. Next to the notches. Thank you."],
			L["Kindness unasked is rare as rain in Durotar, {name}. Returned."],
			L["In my clan, {name}, a gift is answered with a bigger one. Here."],
			L["A Frostwolf never counts what a friend gives, {name}. Only what he gives back."],
			L["The camps taught us who our friends are, {name}. You're one. Here."],
			L["Thanks, {name}. Thrall says the Horde's strength is its friends. You count."],
			L["Good. Strong. Kind. Three things I respect, {name}. Have this."],
			L["Grom would have roared his thanks, {name}. I'll spare your ears and send this."],
		},
		asked = {
			-- Dabu: the grunt's "I obey", not the peon's "zug zug".
			L["Dabu, {name}. It is done."],
			L["Hold still, {name}. Strength for the fight ahead."],
			L["Ask an orc for help and you get it, {name}. Ask for subtlety and you wait."],
			L["Help, yes. Hugging, no. Hold still, {name}."],
			L["You want {buff}? You have {buff}, {name}. Next."],
			L["Don't flinch, {name}. My helping face looks exactly like my fighting face."],
			L["Short question, short answer, {name}: yes."],
			L["Done, {name}. I was a peon once; I never refuse honest work."],
			L["A challenge, {name}? Ah, a request. I accept either way."],
			L["Yes, {name}. I was sharpening my axe, but it'll keep. It always keeps."],
			L["In the Valley of Honor this would cost you a duel, {name}. For you, a nod."],
			L["Now, {name}? Now. Orcs never learned the word 'later'."],
			L["One {buff}, {name}. Orc style: fast, direct, a bit too hard."],
			L["Stand still, {name}. I aim this like a throwing axe, and I rarely miss."],
			L["Lok'tar, {name}. It means 'victory'. Today it also means 'yes'."],
			L["Done, {name}. If you need anything carried, hit or shouted at, ask again."],
			L["You ask straight, {name}. I answer straight. Here."],
			L["The shamans say the spirits help those who stand still, {name}. Stand still."],
			L["A good request, {name}: clear, brave and short. Like a good battle plan."],
			L["Done, {name}. Thrall says help freely. I say help quickly. Both right."],
		},
		offer = {
			L["Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts."],
			L["Blood and thunder, {name}! Go and earn your glory."],
			L["Among orcs, {name}, making you stronger is how we say we like you."],
			L["An orc giving gifts unasked? Tell no one, {name}. It ruins the image."],
			L["The Warchief wants us diplomatic, {name}. This is my diplomacy."],
			L["Go hit something for me, {name}. Or set it on fire. Orcs aren't fussy."],
			L["Don't thank me, {name}. Just win, and do it loudly."],
			L["I'd make a speech, {name}, but it's mostly shouting. Just take it."],
			L["An orc at your back, {name}, even when I'm not there. Take this."],
			L["'Strike first,' Grom always said, {name}. So: here, before you could ask."],
			L["Take it, {name}. A grunt who walks past a comrade gets a talking-to. From me."],
			L["Frostwolves share the hunt, {name}. I caught nothing today, so share this."],
			L["Walk the Durotar way, {name}: head up, sun on your neck, scorpid underfoot."],
			L["Here, {name}. The spirits favour the generous."],
			L["Orcs give two things freely, {name}: advice and this. Skip the advice."],
			L["The Barrens don't end, {name}. They just get more zhevra. Take this."],
			L["Strength for your arm, {name}. The honour, I see, you brought yourself."],
			L["My wolf wanted you to have his bone, {name}. I talked him down to this."],
			L["Any grunt in Razor Hill would do the same, {name}. Most would shout first."],
			L["For the fight ahead, {name}. There's always one. Orcs plan for it."],
			L["We were slaves once, {name}. Now we choose whom we help. Today, it's you."],
			L["Go, {name}, and let your enemies hear you coming. Or don't. Surprise works too."],
			L["A gift from Durotar, {name}. Like the land: rough, warm and short on shade."],
			L["The elements are fickle, {name}. I am not. Take this."],
			L["Strength, {name}. Not the kind you lift. The kind you keep."],
			L["Nobody crosses the Barrens alone if an orc can help it, {name}. Here."],
		},
		kin = {
			L["Throm-ka, {name}! The blood of the clans runs strong in you."],
			L["An orc, {name}! Finally, somebody who shouts at my volume."],
			L["Frostwolf, Warsong or Blackrock, {name}, we all argue like family."],
			L["Between orcs no words are needed, {name}. Good. I was out of them."],
			L["Grunt or shaman, {name}, it's the same stubborn blood."],
			L["Two orcs, {name}, and nobody's shouted yet. The shamans will call it an omen."],
			L["Our clans probably feuded once, {name}. Everybody's did. Let's call it settled."],
			L["Between orcs, {name}, 'victory or death' is just how we say 'see you later'."],
			L["Your tusks and mine have seen worse days, {name}. This is a better one."],
		},
		group = {
			L["The plan, {name}: we hit it. Questions? No? Good plan."],
			L["A true warband, {name}. Loud, angry, and all on the same side for once."],
			L["Stay with the warband, {name}. Strength in numbers. And in axes."],
			L["If you fall, {name}, I carry you out. Complaining the whole way, but I carry."],
			L["Fight well, {name}, and tonight you share our fire. And our boasting."],
			L["Nobody runs, {name}. Walking briskly away is allowed. Barely."],
			L["I'll go first, {name}. I have the thickest skull here, and I'm proud of it."],
			L["When the war drums start, {name}, charge. We have no drums. I'll hum."],
			L["Watch my back, {name}. The front I can see; that's the part I hit."],
			L["One clan today, {name}: the Clan of Whoever Showed Up. Finest there is."],
			L["Anything big comes through that door, {name}, it's mine. Anything bigger, ours."],
			L["Scars are stories, {name}. Let's all come out of this with short ones."],
			L["Old chieftains had war councils, {name}. We have me pointing at things."],
			L["If I charge early, {name}, it isn't impatience. It's tradition."],
			L["Form up, {name}! Shamans in the middle, fools at the front. I'm at the front."],
			L["Tonight we feast, {name}. First, we earn it."],
			L["If I fall, {name}, sing about it loudly in Orgrimmar. Lie a little."],
			L["Strength and honour, {name}. And if we run low on honour, more strength."],
		},
	},
	forsaken = {
		thanks = {
			L["Thank you, {name}. It would warm my heart, if it still beat."],
			-- Not "from the living": Forsaken buff each other all the time.
			L["Such warmth, for one so cold? Returned in full, {name}."],
			L["Thank you, {name}. I'd blush, but the blood stopped reaching my face."],
			L["My undying gratitude, {name}. For once, the phrase is accurate."],
			L["Most kind, {name}. You've lifted me from 'deceased' to 'mildly deceased'."],
			L["I felt that, {name}, and I don't feel much these days. Here, feel this."],
			L["Thank you, {name}. That's the first colour I've seen all week."],
			L["Thank you, {name}. Kindness above ground; I'd almost forgotten it happens."],
			L["Too kind, {name}. Returned, with a little grave chill on it."],
			L["The last gift I got was the plague, {name}. Yours is a big improvement."],
			L["Thank you, {name}. Nothing this fresh has touched me since Lordaeron fell."],
			L["Sylvanas says we repay every debt, {name}. She rarely means the nice ones."],
			L["My posture's improved, {name}. It's been slumping since the Third War. Thanks."],
			L["Repaid at once, {name}. We Forsaken never carry debts. They rot."],
			L["Thank you, {name}. I've an eternity to remember this, and I intend to."],
			L["Thank you, {name}. I'll keep this somewhere safe. My ribcage has room."],
			L["Thank you, {name}. Once I'd have baked you a pie for that."],
			L["I'll mention you to the Dark Lady, {name}. She won't care, but I will."],
			L["Kindness returned, {name}. Even the flies around me look impressed."],
			L["In all my years with the Scourge, nobody once said this, {name}. Thank you."],
			L["I'll drink to you tonight, {name}. It all leaks out, but it's the thought."],
			L["The Dark Lady says trust no gift, {name}. I'll risk it, and send one back."],
			L["Thank you, {name}. You've made my list of reasons to keep going. It's short."],
			L["Thank you, {name}. No contract, no fine print. Varimathras should take notes."],
			L["Grave dirt and gratitude, {name}: all I own. You'll prefer the gratitude."],
			L["Thank you, {name}. Eternity drags; this was the best bit of the decade."],
			L["Faranell would want notes on that reaction, {name}. I'll just return it."],
			L["Thank you, {name}. Lordaeron had manners once. Glad somebody kept them."],
			L["Even the Deathguard would nod at that, {name}, and they nod at nothing."],
			L["I'd have Lordaeron's bells rung for you, {name}, but they only do funerals now."],
			L["Thank you, {name}. Next time I'm in Brill, I'll name a pumpkin after you."],
			L["Thank you, {name}. My afterlife had rather let itself go. You've tidied it up."],
			L["Most of the living wouldn't have bothered, {name}. I'll resent them, not you."],
			L["Better than anything I've pulled out of Undercity's sewers, {name}. Thanks."],
			L["Thank you, {name}. One tip in return: never drink what an apothecary hands you."],
			L["Arthas took everything I had, {name}. You've given a little back. Thank you."],
			L["Thank you, {name}. Catching kindness beats catching the plague. I've done both."],
		},
		asked = {
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["You need only ask, {name}. The dead are patient."],
			L["Ask the dead for a favour, {name}. We rarely have other plans."],
			L["Certainly, {name}. Stand clear; I'd hate to drop anything on you."],
			L["A moment, {name}. Rigor mortis is hard on the casting hand."],
			L["Nice to be asked for something, {name}, besides the way to the graveyard."],
			L["Gladly, {name}. It takes my mind off the smell. Mine, I mean."],
			L["Certainly, {name}. Hold still. My aim drifts when my eye does."],
			L["In Undercity nobody says please, {name}. Mostly they gurgle. Here you are."],
			L["Just {buff}, {name}? The apothecaries always want a sample too."],
			L["I always rise when called, {name}. Unfortunate history. Here you are."],
			L["Anything for you, {name}. Within reason, and what's left of mine."],
			L["Of course, {name}. I'd say 'over my dead body', but that's been tried."],
			L["Right away, {name}. The dead don't dawdle. We shamble with purpose."],
			L["Of course, {name}. Free will is a gift. I spend mine on things like this."],
			L["At once, {name}. I've had far worse requests from the Apothecarium."],
			L["Of course, {name}. After a winter in the Plaguelands, this counts as a holiday."],
			L["{buff}, {name}? With the Dark Lady's compliments."],
			L["Of course, {name}. I don't sleep or eat, so I may as well be useful."],
			L["Glad to, {name}. The Scourge used my hands for worse."],
			L["Certainly, {name}. The apothecaries taught me a steady hand. Mostly on rats."],
			L["The Dark Lady said serve the Horde, {name}. She never said sulk about it."],
			L["Right away, {name}. In Deathknell they woke me with far ruder requests."],
			L["Silverpine's worgen never ask this nicely, {name}. You're a pleasant change."],
		},
		offer = {
			L["Stay among the living a little longer, {name}."],
			L["Take this, {name}. The grave can wait."],
			L["I was a physician in Lordaeron, {name}. Old habits die harder than I did."],
			L["No charge, {name}. The apothecaries would have made you sign something."],
			L["A gift from the grave, {name}. Don't worry, I washed it."],
			L["I've seen where heroes end up, {name}. I live there. Take this."],
			L["Take this, {name}. I learned the hard way you can't take it with you."],
			L["Take this, {name}. It's the only thing I own that isn't slightly damp."],
			L["Hold on to yourself, {name}. Trust me, the pieces are hard to find later."],
			L["Take this, {name}. The Plaguelands are full of people who didn't."],
			L["A small kindness, {name}. Tirisfal could use more of them."],
			L["Tirisfal fog gets into everything, {name}. So does this, but pleasantly."],
			L["Here, {name}. Kept cool for you, like everything I carry."],
			L["I've outlived everyone I knew, {name}. I'd rather not outlive you. Take this."],
			L["Pardon me, {name}. I'm told I lurk. I'm trying to lurk helpfully."],
			L["Out of my own pocket, {name}. The dead don't need much."],
			L["I've already had the worst day there is, {name}. Let's spare you yours."],
			L["Wind's off the Plaguelands, {name}. Take this, and breathe through your mouth."],
			L["The crows have been watching you, {name}. Let's disappoint them."],
			L["Here, {name}. Tirisfal grows nothing but pumpkins and grudges. This is neither."],
			L["Take this, {name}. The only thing in Undercity that needn't be boiled first."],
			L["Eternity is long, {name}, and I've spent a fair bit of it practising this."],
			L["For the road, {name}. Undercity-made, so do keep it away from open flame."],
			L["Take this, {name}. It's odourless, which I'm told makes it my best feature."],
			L["Forsaken are famously patient, {name}. I just couldn't wait to give you this."],
			L["No strings attached, {name}. I cut mine when the Lich King lost his grip."],
			L["Fresh from Tirisfal, {name}. Well, fresh for Tirisfal."],
			L["Take this, {name}. The Bulwark taught me to look out for the living."],
			L["Passing Pyrewood, {name}? Take this. The village has a bad habit after dark."],
			L["The Scarlets would call this unholy, {name}. From me, they'd say it of bread."],
		},
		kin = {
			L["We Forsaken must look after each other, {name}."],
			L["Between us corpses, {name}, you're remarkably well preserved."],
			L["Lose a finger, {name}, and I've a spare. Forsaken share."],
			L["Is your jaw clicking too, {name}, or is that just me?"],
			L["Victory for Sylvanas, {name}. A small one this time, but it's ours."],
			L["Brill or Deathknell, {name}? We all woke up somewhere. I got the damp crypt."],
			L["When the Scourge comes calling, {name}, we won't be home. Not ever again."],
			L["The Bulwark still holds, {name}, and so do we. Held together, but holding."],
			L["Lordaeron raised us twice, {name}: once as children, once as Forsaken."],
			L["Somewhere in Northrend, {name}, the Lich King is sulking about us. Good."],
			L["The Dark Lady needs us whole, {name}. Near enough will do."],
			L["You smell of Tirisfal, {name}. From one of us, that's a compliment."],
			L["We've both got forever, {name}. Let's not spend it all waiting for the lift."],
			L["One Forsaken to another, {name}: the sewer shortcut is not a shortcut."],
			L["If the Deathguard ask, {name}, we're on patrol. A very, very slow patrol."],
			L["Our kind don't get many kindnesses, {name}. Let's keep them in the family."],
			L["Same grave dirt, same Dark Lady, {name}. That's family."],
			L["Keep the faith, {name}. In each other, I mean. It answers more often."],
			L["The dead look after the dead, {name}. The living could learn a thing or two."],
			L["We've both seen the inside of a grave, {name}. Dreadful service. No view."],
		},
		group = {
			L["Stay alive, {name}. Undercity's housing list is already very long."],
			L["If I fall down, {name}, give it a minute. Old habit."],
			L["I'll take the front, {name}. What's the worst that could happen? Again?"],
			L["Keep upwind of me, {name}. It's better for morale."],
			L["The last party I joined, {name}, I woke up in a crypt. Let's improve on that."],
			L["Anything that bites, {name}, point it at me. There's nothing left worth eating."],
			L["Heal the others first, {name}. I run on spite and embalming fluid."],
			L["If this goes badly, {name}, don't worry. I've died before; it passes."],
			L["I've fought the Scourge from both sides, {name}. This side's better company."],
			L["Stay close, {name}. I'm the one who won't scream at the ghouls. Old neighbours."],
			L["I've walked the Plaguelands at night, {name}. This is a stroll by comparison."],
			L["The corpse at the back is me, {name}. Please don't bury it."],
			L["Stay together, {name}. It's easier than putting somebody back together."],
			L["Don't wait for me, {name}. I shamble, but I shamble forever. I'll catch up."],
			L["Keep the torches clear of me, {name}. I'm old, dry and very flammable."],
			L["Don't check me for a pulse after, {name}. It only worries people."],
			L["Mind the green puddles, {name}. I've seen what they do. I'm what they do."],
			L["Lordaeron fell with me in it, {name}. This won't be worse."],
			L["Stick together, {name}. The apothecaries pay well for strays."],
			L["If this ends underwater, {name}, don't mind me. Breathing's optional now."],
			L["The Dark Lady trusts no one, {name}. I've made an exception for this party."],
			L["When we win, {name}, drinks at the Gallows' End in Brill. My treat. Your risk."],
			L["Don't mind the flies, {name}. They're with me."],
			L["I'll watch the rear, {name}. Nothing sneaks up on someone who can't blink."],
		},
		night = {
			L["The dead keep terrible hours, {name}. Nice to have company for once."],
			L["Midnight, {name}: the best hour to be up and about when you shouldn't be."],
			L["The living are all asleep, {name}. We Forsaken call this the quiet shift."],
			L["Late, {name}? In Undercity, this is lunchtime."],
			L["This is the hour the Scourge used to walk, {name}. Now it's ours."],
			L["Night, {name}. The one time nobody can tell I'm pale."],
			L["Dark as the Undercity, {name}. Finally, some proper lighting."],
			L["Fog, moonlight and a hint of mildew, {name}. Proper Tirisfal weather."],
			L["The banshees start singing about now, {name}. Relax. They're only practising."],
			L["Stars over Tirisfal, {name}. The one thing up there that never rotted."],
			L["Past midnight, {name}. The graveyards are quiet. The good ones, anyway."],
			L["An owl just saw me and left, {name}. They're sensible birds."],
		},
		morning = {
			L["Morning already, {name}? I've been up all night. And all of last decade."],
			L["The sun's up, {name}. I'll stand in the shade, if you don't mind. Things peel."],
			L["Early start, {name}. Of all things, I miss yawning."],
			L["Sunrise, {name}. My least favourite colour."],
			L["Dawn over Tirisfal, {name}: grey, then slightly less grey. Glorious."],
			L["Morning, {name}. The Gallows' End porridge moved again. Have this instead."],
			L["The roosters in Brill still crow, {name}. Nobody's had the heart to tell them."],
			L["Morning, {name}. The Deathguard change shifts now. They just turn round."],
		},
		-- Said in Undercity alone (RP.HOME), in place of anybody's lines for a
		-- city, which were written with Stormwind's warm beds in mind.
		city = {
			L["Take the lift slowly, {name}. The last man who rushed it is still coming down."],
			L["Undercity has it all, {name}: a bank, an inn, and opinions in the sewers."],
			L["Even the rats bow to the Dark Lady here, {name}. Take this before one asks."],
			L["Mind the canal, {name}. It's green for a reason, and the reason isn't moss."],
			L["Undercity's lovely this time of year, {name}. It's always this time of year."],
			L["We moved into Lordaeron's cellar, {name}, and kept the good silver."],
			L["The Royal Quarter's that way, {name}. Bow low; the banshees keep score."],
			L["The bat handler swears they're friendly, {name}. Take this before you test it."],
			L["Magic Quarter's that way, {name}. The glowing puddles aren't for drinking."],
			L["The throne room's just upstairs, {name}. Nobody sits in it. Bad memories."],
		},
		-- Lines about how the living take to a Forsaken, which would be nonsense
		-- to another one: RP.Pick adds them to the moment's own pool only for
		-- somebody who is not kin, and never at home, where nearly everybody is.
		outsider = {
			thanks = {
				L["Most folk greet a Forsaken with holy water, {name}. You're a welcome change."],
				L["Few stop for a Forsaken, {name}. You did, and I noticed. Thank you."],
			},
			asked = {
				L["Contrary to rumour, {name}, not everything a Forsaken hands out is a plague."],
				L["Forsaken can't be charmed, {name}, they say. Asking nicely works, though."],
			},
			offer = {
				L["Take this instead of small talk, {name}. Mine tends to unsettle people."],
				L["They say the Forsaken have no friends, {name}. I'm recruiting."],
				L["Take this, {name}. If anyone asks, the Forsaken were perfectly charming."],
				L["Stay alive, {name}. I've tried the alternative, and I can't recommend it."],
			},
		},
	},
	tauren = {
		thanks = {
			L["The Earth Mother saw your kindness, {name}. She nudged me. Quite hard."],
			L["Thank you, {name}. May the winds guide you."],
			L["Thank you, {name}. I'm deeply moved, and it takes a lot to move a tauren."],
			L["It's a long way up to a tauren's heart, {name}. You found it."],
			L["I felt that from horn to hoof, {name}. Returned, hoof to horn."],
			L["A gift given is a seed planted, {name}. Here is the harvest."],
			L["That deserves a feast, {name}. The feast can wait; {buff} can't."],
			L["Thank you, {name}. Should you ever need a wall to hide behind, I'm free."],
			L["Thank you, {name}. My grandmother said kindness comes back on the wind."],
			L["Returned faster than a wind rider, {name}, and with much less screeching."],
			L["Returned, {name}. The quilboar never learned to give back, and look at them."],
			L["Thank you, {name}. My ancestors are all nodding. It's a great deal of nodding."],
			L["In Mulgore we return a gift before the grass under it grows back, {name}."],
			L["Thank you, {name}. I'll name my next kodo calf after you. They're lovely."],
			L["Kindness is rarer than shade in the Barrens, {name}. Here's some back."],
			L["I'll carve this on a totem, {name}. Tauren carve slowly; expect it by spring."],
			L["Bloodhoof Village will hear of this at supper, {name}. Thank you."],
			L["Cairne taught us to honour every kindness, {name}, and so I do."],
			L["Thank you, {name}. Hamuul says the land repays those who tend it. So do I."],
			L["In Thunder Bluff we'd beat a drum for that, {name}. Imagine it. Thank you."],
			L["The Earth Mother gives without counting, {name}. You've been listening to her."],
			L["Thank you, {name}. My heart's as full as a kodo after the spring grass."],
			L["The elders on Elder Rise would approve, {name}. Slowly, after a long talk."],
			L["If you pass through Mulgore, {name}, ask for me. Everyone knows the big one."],
		},
		asked = {
			L["Of course, {name}. Stand tall and be at peace. I'll handle the tall part."],
			L["Ask and it is given, {name}. The herd shares what it has."],
			L["Of course, {name}. Stand back a pace; I do this with my whole body."],
			L["Gladly, {name}. Mind the tail."],
			L["The Earth Mother gives freely, {name}, and so do her largest children."],
			L["Gladly, {name}. Tauren are slow to anger and quick to help."],
			L["Refuse you, {name}? My ancestors would never let me hear the end of it."],
			L["Of course, {name}. A tauren says yes the way the plains grow grass: easily."],
			L["Of course, {name}. One moment; my hands are big and the spell is small."],
			L["After a season herding kodo, {name}, a polite request is a holiday. Here."],
			L["The Earth Mother says share, {name}. My stomach says lunch. She outranks it."],
			L["Of course, {name}. Stand still as a totem; this won't take long."],
			L["Spirits of the plains, lend me your strength. Here, {name}."],
			L["Magatha would want a favour for it, {name}. Baine would just say yes. So: yes."],
			L["Hold still, {name}. I've practised on kodo, and they're far less polite."],
			L["Of course, {name}. A shu'halo never refuses a traveller. Or a second helping."],
			L["Of course, {name}. The plains taught me patience; the kodo taught me to share."],
			L["Gladly, {name}. Ancestors, steady my hand. Not my hooves; they're fine."],
			L["Always, {name}. Cairne never refuses a friend, and he's taller than me."],
			L["Ask anything, {name}. A tauren has strength to spare and time to listen."],
		},
		offer = {
			L["Walk with the Earth Mother, {name}. She's everywhere, so you can't get lost."],
			L["May An'she light your path, {name}."],
			L["You looked like you could use a friend, {name}. I'm a very big one."],
			L["Take this, {name}. The Earth Mother would scold me if I walked past."],
			L["Tread lightly, {name}. Take it from someone who never has."],
			L["The wind said you'd pass this way, {name}. The wind is a terrible gossip."],
			L["Take this, {name}. I'd lend you my kodo too, but he's less generous than me."],
			L["The shu'halo say carry what you can for others, {name}. I can carry a lot."],
			L["Take this, {name}. If the centaur trouble you, say Thunder Bluff sends regards."],
			L["Here, {name}. Plainstriders run from me for no reason at all. You needn't."],
			L["For you, {name}. Visit Mulgore sometime. The grass is soft and nobody hurries."],
			L["Here, {name}. Grandmother blessed travellers and fed them. I'm out of bread."],
			L["The spirits asked me to mind you, {name}. I said yes before they'd finished."],
			L["Here, {name}. Kodo share the watering hole; I can share this."],
			L["Here, {name}. Tauren leave the world a little better, and a little trampled."],
			L["The Earth Mother would offer you a nap, {name}. I offer this."],
			L["Druids call it a blessing, hunters luck, {name}. Tauren call it manners."],
			L["Take this, {name}. If a harpy screeches at you, screech back. They hate that."],
			L["Here, {name}. A tauren blessing: sturdy, slow to fade, smells faintly of sage."],
			L["Here, {name}. The Venture Company would charge you for this. I won't."],
			L["From the high mesas of Thunder Bluff, {name}, where even the wind is friendly."],
			L["The ancestors watch the roads, {name}. I just help them out a little."],
			L["A gift should be heavy with meaning and light to carry, {name}. This is both."],
			L["The Earth Mother made the world wide so we'd meet people like you, {name}."],
			L["Hunt with respect and the land feeds you, {name}. That's my wisdom. Here."],
			L["Here, {name}. Not every tauren would share. The Grimtotem certainly wouldn't."],
		},
		kin = {
			L["The Earth Mother watches over us both, {name}."],
			L["Somebody warn the doorframes, {name}. There are two of us now."],
			L["Plains or peaks, {name}, a shu'halo heart is a big one."],
			L["Horns and helmets, {name}. Only another tauren knows the pain."],
			L["Rain on fur takes a week to dry, {name}. Only another tauren ever believes me."],
			L["Between tauren, {name}: Thunder Bluff's lifts were built by somebody smaller."],
			L["Our ancestors watch us both, {name}. Let's give them something nice to see."],
			L["From Mulgore to Feralas, {name}, the herd always finds itself."],
		},
		group = {
			L["Get behind me, {name}. There's room back there for the whole party."],
			L["The herd moves together, {name}. Mind my hooves; the herd has learned to."],
			L["Low ceilings ahead, {name}? I'll be the first to find out. Take this."],
			L["I'm slow to anger, {name}, but I hold a grudge for the whole party."],
			L["Need a wall to hide behind, {name}? I'm most of one. Come on."],
			L["When I war stomp, {name}, everybody sit down. It saves you falling over."],
			L["Everyone fed? Everyone blessed? Good, {name}. Tauren never lead a hungry herd."],
			L["Tauren don't swim, {name}, we wade. If it's deep, you're riding on me."],
			L["Stay close, {name}. My ancestors walk with us. They're quieter than you lot."],
			L["If I fall, {name}, don't try to carry me. Drag me. Fondly."],
			L["We move like a stampede, {name}: all together, and sorry about the flowers."],
			L["Nobody walks alone at the rear, {name}. That's where I'll be, looming kindly."],
			L["Tell me when to charge, {name}. Tauren are slow to start, and slower to stop."],
			L["Nobody wander, {name}. The last party that did in the Barrens is still walking."],
			L["Stand close, {name}. A herd is strongest when nobody wanders off to graze."],
			L["Watch the ground, {name}. Quilboar dig traps, and I find them all hoof first."],
			L["Into the fight with a calm heart, {name}. The rage can come later, if it must."],
			L["May the Earth Mother keep this herd, {name}, every last stubborn calf of it."],
		},
		morning = {
			L["An'she rises, {name}, and so do we. Slower, in my case."],
			L["The sun is An'she's eye, {name}. He's watching, so let's look busy."],
			L["Morning, {name}. The kodo are up, the grass is wet, and this is yours."],
			L["Morning, {name}. I've greeted the sun, the wind and two plainstriders. Now you."],
			L["Morning, {name}. Dew on the grass, dew on my fur. I'll be damp till noon."],
			L["Early, {name}. That mist over Mulgore at dawn? Mostly kodo breath."],
		},
		night = {
			L["Mu'sha keeps the night watch, {name}. I'll tell her to keep an eye on you."],
			L["The moon's out, {name}. Mu'sha sees you, and she approves. I asked."],
			L["Late, {name}. The kodo are asleep, and they snore like thunder. Take this."],
			L["Stars out, {name}. Each one's an ancestor, they say. That one's winking at you."],
			L["Late, {name}. Mulgore is so quiet at night you can hear the grass argue."],
			L["Quiet now, {name}. At this hour, even my hooves try to tiptoe."],
		},
	},
	troll = {
		thanks = {
			L["Ya too kind, {name}! This one's from me."],
			L["Thanks, mon! Da spirits smile on ya, {name}."],
			L["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."],
			L["Death's gonna be real disappointed, {name}. Thanks, mon."],
			L["Fine work, {name}. Almost as fine as me. Almost."],
			L["A troll can grow back a hand, {name}. Can't grow back honour. Here."],
			L["Ya just made a troll smile, {name}, and we got a lot of teeth."],
			L["Da loa keep a tally, {name}. You're on the good side of it."],
			L["Beat me to it, {name}! Darkspear hate bein' second. Now we're even."],
			L["I owe ya now, {name}, and trolls only like owin' da loa. Settled."],
			L["I'll tell all of Sen'jin 'bout ya, {name}. Makes a change from crabs."],
			L["My hair just stood up taller, {name}. Didn't know it could. Thanks, mon."],
			L["The spirits say give it back, {name}. They nag, but they're right."],
			L["Mojo for mojo, {name}: oldest trade in the jungle."],
			L["Vol'jin said repay kindness quick, {name}. He said a lot. Dat one stuck."],
			L["That deserves a dance, {name}. Lucky ya: {buff} instead."],
			L["Jungle rule, {name}: what ya give comes back, often with teeth. Not this one."],
			L["A gift for a troll, {name}? We never forget a kindness."],
			L["Old Sen'jin said a gift is a promise, {name}. I keep mine. Here."],
			L["Back on the Echo Isles that earned a feast, {name}. Here's the short version."],
			L["That one's goin' in the stories by the fire, {name}. Ya get a good part."],
			L["Nice, {name}. Darkspear pay back quick. We got places to be. Mostly the beach."],
			L["Stranglethorn gives nothin' for free, {name}. Nice to see somebody does."],
			L["Zalazane would've kept that for himself, {name}. Good thing ya ain't him."],
		},
		asked = {
			L["Sure thing, {name}. Hold still; mojo hates a movin' target."],
			L["No trouble, {name}. Da loa like ya."],
			L["Stay away from da voodoo, {name}. Except this one. This one's fine."],
			L["Close ya eyes, {name}. Mojo gets shy when people watch."],
			L["Ya don't gotta ask twice, {name}. Ya barely gotta ask once."],
			L["Sure, {name}. A troll is mostly swagger. The rest is this."],
			L["Ya asked polite, {name}. Polite gets the good stuff."],
			L["Ya came to the right troll, {name}. The wrong one's over there, fishin'."],
			L["Yes, {name}. The loa owe me a favour, and I'm spendin' it on you."],
			L["Got a pouch full of mojo, {name}. Don't touch the other pouch."],
			L["Anything for ya, {name}. Not my hair, though. Hair is sacred."],
			L["Troll magic, {name}, served hot. Blow on it first."],
			L["Right away, {name}. A Zandalari priest would make a week of this."],
			L["Easy one, {name}. Hard one's gettin' a raptor to sit still."],
			L["Troll rule, {name}: never make a friend beg or a raptor wait. Here."],
			L["Don't wiggle, {name}. Last one who did got the spell and a new haircut."],
			L["No problem, {name}. Darkspear always got time for a friend. And a nap."],
			L["Sure, {name}. Hold still, like a fisherman at Sen'jin waitin' on a bite."],
			L["Yes, {name}. Vol'jin says never turn away a friend, and he's usually right."],
			L["Sure thing, {name}. I'll hum a little. Witch doctors say it helps."],
		},
		offer = {
			L["Da loa watch over ya, {name}. They're real nosy that way."],
			L["Stay sharp, {name}. Take this with ya."],
			L["Ya look like somebody who appreciate quality, {name}. Here: quality."],
			L["Here, {name}. Walk like ya own the jungle. I do."],
			L["Everybody need mojo, {name}. I make so much I gotta give it away."],
			L["A little somethin' for ya, {name}. Don't ask where da loa got it."],
			L["Go on, {name}. Whatever tries to eat ya now gets indigestion."],
			L["Ya look dangerous now, {name}. Almost as dangerous as a troll."],
			L["No charge, {name}. Ya don't owe the loa a thing. Probably."],
			L["Raptors got bigger teeth than me, {name}. Now they got a problem."],
			L["Troll hospitality, {name}: ya get mojo, ya get a smile, ya don't get my fish."],
			L["Walk with mojo, {name}. Everybody else is just walkin'."],
			L["Free mojo, {name}! Quick, before the witch doctor finds out."],
			L["The loa said give this to the next good soul, {name}. That's you."],
			L["Here, {name}. Hakkar never shared. Look what happened to him."],
			L["Jungle's got two kinds of folk, {name}: ready, and lunch. You're ready."],
			L["Easy, {name}. This one tickles. Don't laugh; it gets offended."],
			L["Take this, {name}. Darkspear never send a friend off empty-handed."],
			L["Darkspear know what it is to need a friend far from home, {name}. Here."],
			L["Watch for the Bloodscalps, {name}. Same tusks as me, worse manners. Take this."],
			L["Walk easy, {name}. Life's long if ya don't rush it, and short if ya do."],
			L["My granny was a witch doctor, {name}. Share, she said, and look scary doin' it."],
			L["From Sen'jin Village, {name}. Smells a bit like fish. Works fine, though."],
			L["Stay loose, {name}. Tense folk trip on roots. Take this, and relax."],
			L["The spirits whisper ya name, {name}. Well, somebody's. Close enough."],
		},
		kin = {
			L["We look after our own, {name}. Always, mon."],
			L["Da rest of Azeroth stand up straight, {name}. We got more style."],
			L["Ya tusks look sharp, {name}. Mine too, obviously."],
			L["Every troll's family, {name}. Even the ones who still owe me gold."],
			L["One day we take the Echo Isles back from Zalazane, {name}. Together."],
			L["Two trolls, {name}. Da room just got taller and a lot more relaxed."],
			L["The loa got their eyes on both of us now, {name}. Behave."],
			L["Troll to troll, {name}: only we know how hard it is to buy boots."],
			L["Our ancestors had empires, {name}. We got each other. Fair trade, I say."],
		},
		group = {
			L["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."],
			L["Crew's got style, {name}. Now it's got mojo too."],
			L["We go in together, {name}, we come out together. That's the plan, mon."],
			L["Nobody fallin' today, {name}. Death can wait for the next group."],
			L["Keep ya head down, {name}. I keep mine up. Somebody gotta look good."],
			L["Raptor formation, {name}: fast, loud, and nobody look back."],
			L["If a big snake shows up, {name}, don't run. Stand behind me."],
			L["Need more mojo, {name}? Just shout. Not too loud; the loa are nappin'."],
			L["They'll tell this one at Sen'jin, {name}. Let's give it a happy endin'."],
			L["My tusks are sharp, {name}, but they can't be everywhere. Stay near."],
			L["Nobody panic, {name}. Panic is bad mojo. Swagger is good mojo."],
			L["See an idol with glowin' eyes, {name}? Don't touch it. Trust me."],
			L["Everybody stay loose, {name}. Fights go better when ya smilin'. Mostly."],
			L["Darkspear fight together or not at all, {name}. Together makes more stories."],
			L["Ready, {name}? Any Gurubashi, let me talk first. Then you hit 'em."],
			L["Watch for traps, {name}. Trolls built half the old temples. We love surprises."],
			L["The loa are watchin' this group, {name}. Let's give 'em a good show."],
			L["I got ya back, {name}. Trolls got long arms for a reason."],
		},
		night = {
			L["Night's the best time for mojo, {name}. Nobody sees where it's from."],
			L["The jungle wakes at night, {name}. So do I. This one's fresh."],
			L["High moon, {name}, restless spirits. This keeps 'em off ya."],
			L["Hir'eek the bat loa keeps late hours too, {name}. This is from us both."],
			L["This late, {name}, only trolls and trouble are up. I'm the nice one."],
			L["Stars out, {name}. Each one a loa, Granny said. That's a lot of watchers."],
		},
	},
	bloodelf = {
		thanks = {
			L["Such courtesy does you credit, {name}. Nearly as much as it does me."],
			L["How gracious, {name}. Allow me to return the favour."],
			L["Thank you, {name}. I haven't felt this radiant since... well, this morning."],
			L["Kind of you, {name}. We sin'dorei never turn down free magic. Ask anyone."],
			L["Exquisite, {name}. I would know; I only accept the exquisite."],
			L["Lovely, {name}. I'll be insufferable about this all day. More than usual."],
			L["Thank you, {name}. It even goes with my gold trim. You have an eye."],
			L["Returned in kind, {name}. A prettier kind, admittedly. I can't help it."],
			L["Thank you, {name}. Visit Silvermoon; I'll show you all of it but Murder Row."],
			L["Returned, {name}. Unlike Kael'thas, I give things back."],
			L["Thank you, {name}. I felt that to the tips of my ears, and that's a long way."],
			L["Thank you, {name}. That was so kind my eyes nearly changed colour again."],
			L["A gift, unasked? Farstriders would call that an ambush. A lovely one, {name}."],
			L["Better than a mana crystal, {name}, and I've given those up. Mostly. Thank you."],
			L["Quick of you, {name}. Elves live for centuries, and you still beat me to it."],
			L["Charming, {name}. The sun favours the generous, and so do I."],
			L["Thank you, {name}. I'll mention you at court. Well, at a very exclusive picnic."],
			L["Thank you, {name}. Courtesy is rare outside Silvermoon. Yours shines."],
			L["Unasked kindness, {name}! Somebody tell Rommath; he'll want to study it."],
		},
		asked = {
			L["Naturally, {name}. Only the finest for you."],
			L["For you, {name}? Of course. The sun gives freely."],
			L["Patience, {name}. Radiance can't be rushed, only admired."],
			L["Of course, {name}. {buff}, delivered with impeccable posture."],
			L["You asked nicely, {name}. In Silvermoon that counts for everything."],
			L["One moment, {name}. I never cast anything without checking my hair."],
			L["At once, {name}. Keeping someone waiting is so terribly unfashionable."],
			L["Certainly, {name}. Stand back a step; my sleeves are enchanted and very wide."],
			L["Magisters would bill you, {name}. Blood Knights would lecture. I merely glow."],
			L["At once, {name}. If it goes well, tell everyone. If not, blame the robe."],
			L["At once, {name}. The dragonhawk can wait; it's used to waiting while I dress."],
			L["Gladly, {name}. We once took the Light from a naaru. Asking is so much nicer."],
			L["Three centuries of casting, {name}, and you're the first to say please."],
			L["Gladly, {name}. Silvermoon's brooms sweep themselves, so my hands are free."],
			L["Of course, {name}. I keep my other spells for the rude."],
		},
		offer = {
			L["Anar'alah belore, {name}. May the sun guide you, and light your good side."],
			L["Shorel'aran, {name}. Fight with elegance."],
			L["Take this, {name}. Whatever happens out there is merely a setback."],
			L["Everyone deserves to shine, {name}. Only a little less than me, of course."],
			L["The sun is with you, {name}. I simply held the door for it."],
			L["Go on, {name}, take it. The Sunwell's back; we can afford to be generous."],
			L["For you, {name}: {buff}, lightly scented with Silvermoon."],
			L["Here, {name}. Hand-cast in Silvermoon, so do try not to scuff it."],
			L["A little Sunwell for you, {name}. It's been through a lot; treat it kindly."],
			L["Be prepared, {name}. We weren't, once, and now we have a scar for a road."],
			L["Here, {name}. I only give to the worthy. How convenient that you walked by."],
			L["Take this, {name}. It's been in my family for moments."],
			L["We sin'dorei have lost much, {name}. Never our generosity. Or our cheekbones."],
			L["Take this, {name}. Should a mana wyrm follow you, it's only jealous."],
			L["Seven thousand years to perfect generosity, {name}. We started last week."],
			L["Take this, {name}. It came through the Undercity orb, so it's slightly dizzy."],
			L["For you, {name}. It matches everything. I checked, obviously."],
			L["If a ghoul stops you, {name}, say Silvermoon's still standing. They hate that."],
		},
		kin = {
			L["The Sunwell shines for us both, {name}."],
			L["Two sin'dorei in one place, {name}. The day just got twice as elegant."],
			L["You too, {name}? Two sin'dorei, one mirror. We'll have to take turns."],
			L["Like the phoenix, {name}: we keep rising, and we look good doing it."],
			L["Between sin'dorei, {name}: yes, the Horde is loud. Yes, we're used to it now."],
			L["Sin'dorei to sin'dorei, {name}: we never speak of the green eyes. Agreed?"],
			L["Magister or Farstrider, {name}, the sun rises for us all."],
			L["We both remember Quel'Thalas before the Scourge, {name}. Let's earn the after."],
		},
		group = {
			L["Do keep pace, {name}. We have a reputation for arriving beautifully."],
			L["Stand where the light is good, {name}. If we must fight, we'll look splendid."],
			L["A party at last, {name}. I did dress for one."],
			L["The sun shines on all of us, {name}. Mostly on me, but it shares."],
			L["One for you, {name}, and one for the party's image, which I've taken on myself."],
			L["If I fall, {name}, arrange me attractively. The rest I leave to the priest."],
			L["Nobody touch the enchanted relics, {name}. Well, I may. I've had training."],
			L["Every expedition needs a ranger, {name}. I'm not one, but I have the boots."],
			L["We fight together, {name}, then tell it beautifully. I'll handle the telling."],
			L["Whoever mends us is to be thanked, {name}. Me, admired. Carry on."],
			L["If this goes badly, {name}, we blame the Scourge. It's traditional."],
			L["Mana potions are for emergencies, {name}. I've had eleven emergencies today."],
			L["We walked out of the ashes once, {name}. We'll walk out of whatever's ahead."],
		},
		morning = {
			L["The sun has risen, {name}, and so have I. We coordinate."],
			L["Dawn over Quel'Thalas is lovelier, {name}, but this will do. Just."],
			L["Morning light, {name}. The most flattering hour. For both of us, naturally."],
			L["Breakfast in Eversong is fruit, tea and arcane, {name}. Skip to the arcane."],
			L["Dawn, {name}. Red and gold across the sky. Somebody's been copying us."],
			L["Morning, {name}. Only Silvermoon's arcane guardians are up this early. And me."],
		},
	},
	nightborne = {
		thanks = {
			L["Your generosity is noted, {name}. In triplicate. Suramar remembers its friends."],
			L["Most gracious, {name}. Allow me to repay you in kind."],
			L["Thank you, {name}. Ten thousand years under a dome; I'm still practising that."],
			L["A gift with no favour owed? The court would faint. Thank you, {name}."],
			L["Returned, {name}. We keep careful accounts of kindness. And of slights."],
			L["I'll mention you to First Arcanist Thalyssra, {name}. Favourably, even."],
			L["Most kind, {name}. In Suramar we'd hold a banquet. Consider it held."],
			L["I'd send a formal letter of thanks, {name}, but this seemed quicker."],
			L["In Elisande's court a gift hid a knife, {name}. Yours hides none. Thank you."],
			L["Thank you, {name}. My manasaber approves of you, and she approves of no one."],
			L["Exquisite, {name}. Once I'd have said 'adequate'. The world has humbled me."],
			L["You fed a mind that once went hungry, {name}. We never forget those who do."],
			L["Centuries of court etiquette, {name}, and 'thank you' still says it best."],
			L["Thank you, {name}. You're invited to the next masquerade. Masks mandatory."],
			L["Thank you, {name}. Oculeth would open a portal to say so. I'll simply cast."],
		},
		asked = {
			L["Of course, {name}. A little arcane polish, just for you."],
			L["A reasonable request, {name}. Granted."],
			L["Certainly, {name}. The short version; the long one takes a lunar cycle."],
			L["A request, how refreshing. The court only ever made demands. Here, {name}."],
			L["Done, {name}, and free. Elisande would have charged you a favour for it."],
			L["There, {name}. No need to bow. A small nod would be lovely, though."],
			L["Of course, {name}. I've perfected this since before most cities had walls."],
			L["Granted, {name}. I'd ask a favour back, but I'm trying to be less Suramar."],
			L["Certainly, {name}. Forgive the flourish. We can't cast plainly; we've tried."],
			L["At once, {name}. Elisande once stopped time. I only need a second."],
			L["Of course, {name}. The ley lines here are shallow, but I'll make do."],
			L["Very well, {name}. Stand in the moonlight. Or by that lamp. Lamps will do."],
			L["Naturally, {name}. Suramar had a spell for everything. I remember several."],
		},
		offer = {
			L["Take this, {name}. Arcane gifts are wasted on the idle."],
			-- Suramar's arcana, not the Nightwell: they were weaned off it.
			L["A spark of Suramar's arcana for you, {name}. Use it wisely."],
			L["I've gone without magic once, {name}. I don't recommend it. Take this."],
			L["The world outside the dome is so large, {name}. And so under-enchanted. Here."],
			L["Arcwine is traditional, {name}, but {buff} travels better."],
			L["Do take this, {name}. It's rude to refuse Suramar's hospitality. Very rude."],
			L["Here, {name}. I'm told this is how outsiders say hello. Charming custom."],
			L["Take this, {name}. Magic hoarded is magic spoiled, as Suramar learned."],
			L["Once, I'd have made you bow for this, {name}. We've all grown."],
			L["The Kirin Tor do this too, {name}, bless them. Quite nicely, for newcomers."],
			L["A gift from under the dome, {name}. Kept fresh for a very, very long time."],
			L["Enjoy this, {name}. I used to cast it on nobility. You're an improvement."],
			L["I packed for the outside world like a gala, {name}. Four capes. Take this."],
			L["Here, {name}. Suramar work: overdesigned, overdecorated, and flawless."],
			L["Here, {name}. In Suramar this came with a string quartet. Do hum something."],
		},
		kin = {
			L["Suramar's children shine together again, {name}."],
			L["Shal'dorei, {name}! You packed arcwine? Outsider wine is just... grapes."],
			L["Suramar's own, {name}. Try not to be too impressed by the rest of the world."],
			L["We survived the Legion and the withering, {name}. The rest is small talk."],
			L["Our tailors made it out of Suramar too, {name}. Thank the stars."],
			L["We both remember going hungry, {name}. Never again, for either of us."],
			L["Out from under the dome, {name}. Is the sky still this big for you too?"],
			L["Two shal'dorei in one place, {name}. The locals will assume it's a gala."],
		},
		group = {
			L["An expedition, {name}! In Suramar this needed six permits and a masquerade."],
			L["The dome kept us safe, {name}. Now we must make do with one another. Gladly."],
			L["Arcane for everyone, {name}. The court would call it waste. I call it company."],
			L["Do follow my lead, {name}. I've had ten thousand years of walking in step."],
			L["In a party one shares one's magic, {name}. How novel. I rather like it."],
			L["An outing is like a masquerade, {name}: smile, keep moving, watch for knives."],
			L["Stay in the light of my spells, {name}. It's the most flattering in the party."],
			L["After Elisande's court, {name}, this outing is a holiday. Nobody plots."],
			L["Lost? Follow the one who glows, {name}. That's me. It's always me."],
			L["If I start lecturing on ley lines, {name}, do interrupt. Politely."],
			L["I watched my people wither, {name}. I won't watch friends fade. Nobody falls."],
			L["Tell me if I'm being grand, {name}. I lose track. It's the millennia."],
		},
		night = {
			L["Night at last, {name}. Add a few thousand lanterns and it's nearly Suramar."],
			L["Under the dome it was always night, {name}. I feel quite at home."],
			L["The stars are out, {name}. We had better ones in Suramar. These will do."],
			L["Nightborne, {name}, and here's the night. At last I'm dressed for the hour."],
			L["At this hour, {name}, Suramar was only just getting dressed for dinner."],
		},
		morning = {
			L["Daylight, {name}. Ten thousand years under a dome, and it still startles me."],
			L["An early hour, {name}. The court never rose before noon. I'm reforming."],
			L["Morning, {name}. The sun here is so very... unenchanted. Take this instead."],
			L["Morning, {name}. We warded Suramar against every threat but the sun."],
			L["Dawn, {name}: when the court's gossip went to bed. Here's mine: you look well."],
		},
	},
	goblin = {
		thanks = {
			L["A favour for a favour, {name}! Pleasure doing business."],
			L["Thanks, {name}! Consider your account settled in full."],
			L["Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass."],
			L["Thanks, {name}! I checked it for fine print. There wasn't any. Weird!"],
			L["Returned with interest, {name}. Minus the interest. Don't get used to it."],
			L["Much obliged, {name}! You've just been upgraded to preferred customer."],
			L["I'd name a rocket after you, {name}, but my rockets never last long. Thanks!"],
			L["I'd have charged fifty gold for that, {name}. Let's call us even."],
			L["Thanks, {name}! Quick hands. You'd do well in Booty Bay."],
			L["A deal where both sides profit, {name}! I'd heard of those. Never seen one."],
			L["First free gift since Kezan blew up, {name}. Returning it before I price it."],
			L["Thanks, {name}! I appraised it at priceless. Here's one appraised the same."],
			L["Kindness in, kindness out, {name}. Best returns since the kaja'mite boom."],
			L["Even trade, {name}? My accountant just fainted. He does that around fair deals."],
			L["Thanks, {name}! I'd shake on it, but I count my fingers after. Habit, not you."],
			L["Thanks, {name}! Gadgetzan could use a few more like you."],
		},
		asked = {
			L["You got it, {name}! Time is money, friend!"],
			L["Deal, {name}! I'll put it on your tab. Kidding!"],
			L["Right away, {name}! Satisfaction guaranteed or your {buff} back."],
			L["{buff}, {name}! Tips optional. Encouraged. Optional."],
			L["Fast, cheap or good, {name}? Today you get all three. Don't spread it around."],
			L["Sure thing, {name}! No explosions this time, I promise. Mostly promise."],
			L["For you, {name}? No charge. Put that in writing and I'll deny it."],
			L["Sure, {name}! Quote's zero gold. Lowest I've ever quoted. It stings a little."],
			L["Coming up, {name}! Full warranty included. Valid until it wears off."],
			L["Sure, {name}! I'd tinker with it, but you look in a hurry."],
			L["Easy, {name}. Steamwheedle rule: keep customers alive. They pay longer."],
			L["Gadgetzan's got the water trade, {name}. I've got this. Better margins."],
			L["Kezan standard, {name}: fast, loud, and done before you read the terms."],
			L["On it, {name}! Goblins never keep a customer waiting. Unless it pays."],
		},
		offer = {
			L["This one's on the house, {name}. Don't tell the Trade Prince."],
			L["Top-shelf stuff, zero fees, {name}. Today only!"],
			L["Free sample, {name}! If you like it, you know where to find me."],
			L["Here, {name}. If anything explodes near you today, that was unrelated."],
			L["Goodwill's an asset, {name}. Here's some {buff} for my books."],
			L["Take this, {name}. Safety first! Or third. It's on the list somewhere."],
			L["Cast in record time, {name}! The record's mine. I set it just now."],
			L["Kaja'Cola gives you ideas, {name}. This does the rest. Take it!"],
			L["Here, {name}. Go make your fortune. I'll want a cut."],
			L["Zeppelin's late again, {name}, so I've time to be generous."],
			L["Here, {name}. Patent pending. Try it out and tell your rich friends."],
			L["Consider this an investment, {name}. In you. I expect heroic returns."],
			L["Take it, {name}! My last shipment sank off Kezan, so everything's clearance."],
			L["The Venture Company charges for this, {name}. I'm the competition. Here."],
			L["Every goblin has a soft spot, {name}. Mine's small and guarded. You found it."],
			L["Take this, {name}. It's the only thing I own with no lien on it."],
			L["You'll be rich someday, {name}. I can tell. Remember who gave you this."],
		},
		kin = {
			L["Anything for a fellow entrepreneur, {name}!"],
			L["Kezan's finest, together again, {name}. Keep a hand on your coin purse."],
			L["Fellow goblin, {name}? Then you know this is a very, very rare discount."],
			L["Goblins look after goblins, {name}. It's cheaper than hiring guards."],
			L["Kezan's gone, {name}, but the greed made it out. Look at us."],
			L["Between goblins, {name}, this never happened. I have a reputation."],
			L["Bilgewater or Steamwheedle, {name}, we always float to the top. Like oil."],
			L["Remember the volcano, {name}? We sold tickets to it. Proud times."],
		},
		group = {
			L["Group rate, {name}! Everybody here gets it half off. Of free."],
			L["Nobody dies on my contract, {name}. The paperwork's a nightmare."],
			L["We split the take even, {name}. I'll do the maths. Trust me."],
			L["There, {name}. Everyone's stronger, and everyone owes me. Invoices later."],
			L["Stick together, {name}. Mercenaries cost gold; friends only cost this."],
			L["Everybody's covered, {name}. Not insured, mind. Covered. Different price."],
			L["I read the risk report on this outing, {name}. Short read. It just says 'no'."],
			L["Nobody touches the big red lever, {name}. There's always a big red lever."],
			L["If this goes south, {name}, I've got a rocket. Seats one. I'm working on it."],
			L["We're a company now, {name}. I'm treasurer. The vote was unanimous. Mine."],
			L["Stay alive, {name}. Nobody's found a way to sell resurrections yet. I'm trying."],
			L["Stay close, {name}. I've already sold the story of this trip. Make it good."],
		},
		morning = {
			L["Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds."],
			L["Morning, {name}! Markets open in an hour. Until then, I'm feeling generous."],
			L["Up early, {name}? Smart. Time is money, and it's cheapest in the morning."],
			L["Dawn, {name}. Rich goblins sleep in. I'm not rich yet."],
			L["Fresh day, fresh ledger, {name}. You're the first entry. The good column."],
		},
	},
	vulpera = {
		thanks = {
			L["Thank you, {name}! The caravan always repays a kindness. Usually in string."],
			L["How kind, {name}! You're on the caravan's good list now."],
			L["Oh, I'll keep this, {name}! I keep everything. Here's one for you."],
			L["Thanks, {name}! Here's yours back. Well, a new one. Hardly used."],
			L["My ears just went straight up, {name}. That means I'm very pleased."],
			L["By tonight's campfire, {name}, this story will have a sandworm in it. Thanks!"],
			L["I'd gift-wrap yours, {name}, but all my wrapping is somebody's old map."],
			L["The alpacas saw that, {name}. They'll tell everyone how nice you are. Thanks!"],
			L["Thank you, {name}! I'd give you my best button, but this is better. Slightly."],
			L["Ooh, a present, {name}! I'll trade you one of mine."],
			L["Thanks, {name}! That goes in the good pouch. Not the rock pouch. The good one."],
			L["In Vol'dun that would've cost a whole waterskin, {name}. Thank you!"],
			L["Thanks, {name}! Your name goes on the wagon. Between the alpaca and the dent."],
			L["Kindness is the one thing the desert never buried, {name}. Thank you."],
			L["Rakera says repay quick, {name}, before you forget which pocket it's in. Here!"],
			L["Nobody's given me anything I didn't dig up first, {name}. Thank you!"],
		},
		asked = {
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Coming right up, {name}! Caravan service, no waiting."],
			L["Sure, {name}! Let me dig it out... rope, rocks, a nice rock... here it is!"],
			L["Hold on, {name}! Tail's in the way, one moment... there!"],
			L["One {buff}, {name}! Only slightly sandy."],
			L["Ask a vulpera and you'll get something, {name}. Usually odd. Not today!"],
			L["Yours, {name}! Vulpera love giving things. Almost as much as finding them."],
			L["Here, {name}! Patched it up myself. Holds better than it looks."],
			L["Sure, {name}! Stand upwind. Sandstorm last week; I'm still shedding it."],
			L["YES! Sorry, {name}, too loud? The desert's very big. You have to shout in it."],
			L["Of course, {name}. Caravan rule: nobody asks twice for water or for help."],
			L["On it, {name}! Small spell, big fox, bigger ears. Wait. Other way round."],
			L["For you, {name}? Easy! Caravan folk never say no to a neighbour."],
		},
		offer = {
			L["Every traveller needs something for the road, {name}. I checked: not a rock."],
			L["Keep this, {name}. The desert is long and the water is short."],
			L["Found this lying around, {name}. Kidding! It's fresh. Take it!"],
			L["Here, {name}. Best thing in my pack, and I've got a lot of pack."],
			L["In the dunes you share your shade and your spells, {name}. Here."],
			L["Some {buff} for you, {name}. I'd haggle, but you look busy."],
			L["A gift from the whole caravan, {name}! They'll never know."],
			L["For the road, {name}. Roads are the best part. Roads, and snacks."],
			L["Here, {name}! I swapped a hat for a thing, and the thing for this. Good trade!"],
			L["Nobody walks past anybody in the dunes, {name}. Bad luck, and rude. Here."],
			L["My nose says trouble's ahead of you, {name}. Take this. My nose is never wrong."],
			L["Too many spells in my pack, {name}. They jingle. Take one, please."],
			L["If you find anything shiny later, {name}, you know where my ears are. Here!"],
			L["Wait, {name}! You nearly left without this. Deserts eat people who do that."],
			L["Stew's not ready yet, {name}, so this is the starter."],
		},
		kin = {
			L["A fellow wanderer! The caravan is never far, {name}."],
			L["Ears up, {name}! Always nice to share a spell with a fellow fox."],
			L["One vulpera to another, {name}: I've three spare spoons if you need one."],
			L["Vol'dun raised us both, {name}. Sand in the fur, luck in the pack."],
			L["Ears to ears, {name}: between us we've heard everything said in this place."],
			L["Remember the caravan fires, {name}? Everybody sang badly. It was perfect."],
			L["Vol'dun's far behind us, {name}. Half of it followed us here in our fur."],
		},
		group = {
			L["Caravan rules, {name}: stay together, share the water, nobody sells the alpaca."],
			L["Anything shiny in there, {name}, I saw it first. Caravan law."],
			L["One for the party, {name}! A caravan's only as fast as its slowest alpaca."],
			L["Keep your pack shut, {name}. I don't mean to take things. They follow me."],
			L["Lost in a city, {name}, never in a cave. Caves are just houses with no rent."],
			L["I'm small, {name}, so I'll check the tiny tunnels. You lot take the big ones."],
			L["Shout if you need anything, {name}. I've probably got it. It's probably dented."],
			L["I'll take the back, {name}. Nobody gets left behind in a caravan."],
			L["A caravan with no wagon, {name}! Very fast. Very light. Nowhere to nap."],
			L["Scouted ahead, {name}. By nose. Smells of danger and very old cheese."],
			L["Everybody fed? Everybody watered? Good. Now this, {name}. Caravan order."],
		},
		night = {
			L["We vulpera travel by night, {name}. Cool sand, sleepy scorpids."],
			L["Desert nights get cold, {name}. Here, something warm-ish."],
			L["Stars out, {name}. Every one's a signpost if you know how to read it. I don't."],
			L["Good hour for foxes, {name}. The ears work best when everything's quiet."],
			L["Past dark and I'm just waking up, {name}. In the dunes, noon's for napping."],
			L["I'll curl up in my tail later, {name}. Best blanket I own. First, this."],
		},
	},
	pandaren = {
		thanks = {
			L["A kindness returned is a kindness doubled, {name}."],
			L["Thank you, {name}. You have restored my balance."],
			L["Somewhere, a Sha just went hungry. Thank you, {name}."],
			L["Thank you, {name}. Aysa would bow, Ji would cheer. I will do both, badly."],
			L["Thank you, {name}. I will think of you at my next meal, and the one after."],
			L["Chen always said: never refuse a gift. Or a drink. Thank you, {name}."],
			L["I was about to nap, {name}, but this is better. Slightly. Thank you."],
			L["A hozen would have thrown something, {name}. I was raised better. Thank you."],
			L["That was very pandaren of you, {name}. All that's missing is a dumpling."],
			L["At Halfhill that earns a prize turnip, {name}. I left mine at home. Thank you."],
			L["Grandmother kept a jar of kindnesses, {name}. Yours goes in; this comes out."],
			L["Thank you, {name}. In the Jade Forest my door is open, and my pantry more so."],
			L["You move like the Shado-Pan, {name}. I never saw that coming. Thank you."],
			L["Like rain on a rice paddy, {name}. The paddy never says thank you. I do."],
			L["Thank you, {name}. Li Li would put this in her travel journal. With drawings."],
			L["Thank you, {name}. The August Celestials are busy, so I thank you for all four."],
			L["Stormstout ale knocks a pandaren flat, {name}. So did that. Thank you."],
			L["Now we are even, {name}. A pandaren never lets a kindness go cold."],
		},
		asked = {
			L["Of course, {name}. Patience, and it is done. Patience is the slow part."],
			L["With pleasure, {name}. A kind deed is never wasted."],
			L["At once, {name}. Quick for a pandaren, which is not saying much."],
			L["Master Shang Xi said: help whoever asks, {name}. I listened."],
			L["A Tushui master would make you meditate first, {name}. I will skip that part."],
			L["Anything for you, {name}. Except the last dumpling. Let us not be silly."],
			L["One {buff}, {name}, brewed strong. The recipe stays a secret."],
			L["Stand like a crane, {name}: one leg, calm face. Two legs is also fine."],
			L["We never refuse a request, {name}. Or a second helping."],
			L["The last to ask me for help, {name}, was an island-sized turtle. You're easier."],
			L["Pandaren help like we cook, {name}: slowly, generously, and far too much of it."],
			L["Certainly, {name}. Let me put down my bowl. ...There. That was the hard part."],
			L["Yes, {name}. Grandfather said never make guests ask twice. He said it twice."],
			L["Hold still, {name}. I am calm, you are calm, the spell is calm. Nobody panic."],
		},
		offer = {
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
			L["Balance in all things, {name}. Now go with a light heart."],
			L["Take this, {name}. A grummle would sell it to you for a luckydo."],
			L["The jinyu say the waters foretold this, {name}. They say that a lot."],
			L["The Huojin say act first. The Tushui say think first. I say: here, {name}."],
			L["A pandaren stood up to give you this, {name}. Treasure it."],
			L["Fight like a monk, {name}: calm, quick, and then a long lunch."],
			L["Go gently, {name}. The turtle got where it was going and never hurried once."],
			L["A hug would be forward, {name}. This is next best, and less furry."],
			L["If a fight finds you, {name}, roll away. Rolling is very underrated."],
			L["For you, {name}. It is warm, round and full of good intentions. Like me."],
			L["Take this, {name}. My kite is stuck in a tree, so I have time for good deeds."],
			L["I carried this from Pandaria, {name}. Also a keg. The keg is mine."],
			L["The virmen stole my carrots, {name}, but this they will never get. Here."],
			L["On the Wandering Isle, {name}, strangers get soup. This travels better."],
			L["Pandaren look soft, {name}. So does a sack of rice, until it lands on you."],
			L["Chi-Ji says there is always hope, {name}. I say there is always a spare. Here."],
		},
		kin = {
			L["We must share a brew when the road allows, {name}!"],
			L["Shen-zin Su would be proud of us both, {name}. Or asleep. Hard to tell."],
			L["Two pandaren together, {name}. Somewhere, an innkeeper just felt a chill."],
			L["Liu Lang would approve, {name}: two of us, both a long way from home."],
			L["Tushui or Huojin, {name}, we both left the turtle, and we both miss the food."],
			L["One pandaren to another, {name}: the brews out here are thin. Share mine later."],
			L["We both smell of rice wine and road dust, {name}. The smell of home."],
			L["Pandaren look after pandaren, {name}. Mostly by feeding them. This comes first."],
		},
		group = {
			L["A fight, then a meal, {name}. That is the correct order. Never the reverse."],
			L["Stay together, {name}, like dumplings in a steamer. Warm, and ready."],
			L["We move as one, {name}. Slowly, perhaps, but as one."],
			L["Balance, {name}: one fights, one heals, and one carries the snacks. Me."],
			L["If we fall, {name}, we fall together, and then we nap. Let us not."],
			L["Stay behind me, {name}. I am soft, but I am very wide."],
			L["If we win, {name}, I will cook. If we lose, I will also cook, but sadly."],
			L["Everyone breathe, {name}. In, and out. Now hit things, calmly."],
			L["Keep up, {name}. I am in a hurry. It happens to pandaren about once a decade."],
			L["A party is like a brew, {name}: odd ingredients, wonderful together. Mostly."],
			L["If I fall, {name}, roll me somewhere safe. Carrying me is not an option."],
			L["Pandaren fight like water, {name}: calm, patient, and then suddenly everywhere."],
		},
		morning = {
			L["Up before the tea, {name}? Brave. Here, instead of the tea."],
			L["Morning, {name}. First this, then breakfast, then more breakfast."],
			L["A new day, {name}, and nobody has spilled anything yet. Let us begin gently."],
			L["Halfhill's farmers have been up for hours, {name}. I have been up for minutes."],
			L["Morning mist, {name}. It looked just like home. Then a kobold walked by."],
			L["Good morning, {name}. My stomach woke first and has been giving orders since."],
		},
		night = {
			L["Past my first nap, {name}, and before my second. Quickly, while I'm awake."],
			L["Late, {name}. The brewmasters are asleep. The brews, I suspect, are not."],
			L["Midnight snack time, {name}. This is the appetiser."],
			L["Dark already, {name}? Back home, Grandfather's stories would just be starting."],
			L["The moon is round and full tonight, {name}. We have a great deal in common."],
		},
	},
	dracthyr = {
		thanks = {
			L["Your kindness is noted, {name}. Dragons do not forget."],
			L["Thank you, {name}. Returned on swift wings."],
			L["Wings, fire and scales, {name}, and still you thought I needed help. Touching."],
			L["I would bow, {name}, but last time my wings cleared a table. Thank you."],
			L["That goes straight into my hoard, {name}. Kind deeds are the only gold I keep."],
			L["I was made to be a weapon, {name}. I much prefer this part. Thank you."],
			L["Thank you, {name}. Wrathion would have made a speech of it. I will not."],
			L["Returned with a little fire in it, {name}. Only a little. I am practising."],
			L["A mortal gift, {name}: small, brief and kind. I am learning to like all three."],
			L["Thank you, {name}. Mortal customs are new to me. Do I pay you? No? Then this."],
			L["Thank you, {name}. I have scales where most have feelings. That got through."],
			L["You're on my list of favourite mortals, {name}. It was empty until today."],
			L["The red in me is grateful, {name}. The black in me is suspicious. The red wins."],
			L["Thank you, {name}. Dragons are not used to receiving. I find I like it."],
			L["A dragon's thanks comes with a roar, {name}. I will spare the neighbours."],
		},
		asked = {
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Granted, {name}. A dragon keeps its word."],
			L["Certainly, {name}. Stand clear of the tail."],
			L["Of course, {name}. Is this still how it is done? I was asleep for a while."],
			L["Gladly, {name}. All five dragonflights are in me, and all five say yes."],
			L["Right away, {name}. Dragon-sized help, in a conveniently smaller form."],
			L["Of course, {name}. Neltharion only gave orders. A request is much nicer."],
			L["Right away, {name}. Stand back a little; I am still learning how big I am."],
			L["Certainly, {name}. Claws are not ideal for spellwork, but I manage."],
			L["Of course, {name}. Dragons usually demand tribute. I'm waiving it, this once."],
			L["Of course, {name}. Please don't scream. Mortals often do. It's the horns."],
			L["My breath is fire, {name}, so we will do this the other way."],
			L["Gladly, {name}. Mortals so rarely ask a dragon for anything but mercy."],
			L["A small magic, {name}, but I cast it with enormous dignity."],
		},
		offer = {
			L["Take this, {name}. Even a dragon needs allies. Especially one this size."],
			L["A gift from the Dragon Isles, {name}. Fly well."],
			L["Alexstrasza says every life is precious, {name}. I am starting with yours."],
			L["I slept through ten thousand years of good deeds, {name}. Catching up now."],
			L["Tell them a dragon did this, {name}. It sounds far grander than it was."],
			L["Scalecommander's orders, {name}. I am not a Scalecommander, but still."],
			L["Take this, {name}. Ancient dragon magic, only slightly out of date."],
			L["A dragon giving, {name}, not taking. I am trying something new."],
			L["In visage form I look harmless, {name}. So did Lady Prestor. I really am."],
			L["A gift from above, {name}. I landed specially. It took two tries."],
			L["Here, {name}. Every dragon should guard something. I have chosen you, for now."],
			L["Take this, {name}. It's from five dragonflights, so it clashes with everything."],
			L["I'd fly you there myself, {name}, but dracthyr carry no riders. Take this."],
			L["Dragons gifted the world at its dawn, {name}. Mine is smaller, and later."],
			L["A little essence for you, {name}. It is what I'm made of, so handle it gently."],
			L["Take this, {name}. It will feel warm. Most things do, after I touch them."],
		},
		kin = {
			L["The Forbidden Reach feels far behind us now, {name}."],
			L["Two dracthyr in one place, {name}. Mind the wings; there is not room for four."],
			L["Remember when the whole world was new to us, {name}? It still is, mostly."],
			L["In visage form nobody can tell, {name}. Between us: we look better in scales."],
			L["Made for war, {name}, and look at us: sharing. Somebody's plans went wrong."],
			L["Visage or scales, {name}, I would know one of us anywhere. It is the posture."],
			L["Mortals always ask us the same thing, {name}: will we fly them. Still no."],
			L["Between two dracthyr, {name}: the horns never get any easier with hats."],
		},
		group = {
			L["Tell me when to breathe fire, {name}. And, please, when not to."],
			L["I woke in a cave full of strangers, {name}. This is far better company."],
			L["Neltharion made us to fight alone, {name}. We have improved on him."],
			L["Stay clear of my tail, {name}. It hasn't yet learned whose side it's on."],
			L["A flight of our own, {name}. So this is what the dragons meant."],
			L["If I say 'take cover', {name}, I mean behind my wings. They are good for that."],
			L["Stand beside me, {name}, never in front. I cannot aim my breath politely."],
			L["Leave the big ones to me, {name}. Well, the ones smaller than me. That is most."],
			L["Stay close, {name}. I can glide us all down from anywhere. Up is your problem."],
			L["Keep moving, {name}. A dragon in a hurry is grand. One waiting is just big."],
			L["Tell me the plan slowly, {name}. I was made for battles, not for plans."],
			L["Mortals live so briefly, {name}. Let us not make today any shorter."],
		},
	},
	haranir = {
		thanks = {
			L["Thank you, {name}. Where I come from, a kindness is tended like a root."],
			L["Hagar sent me to see the goddess's work, {name}. You're some of her best."],
			L["Kindness echoes, {name}, and I grew up in a cavern. Here it comes back to you."],
			L["My Legacy Stone showed who I'd stand beside, {name}. It forgot you. Thank you."],
			L["We read lives in a root's rings, {name}. Yours just grew a kind one."],
			L["The Shul'ka gave up everything to guard us, {name}. I can give this much."],
			L["The world is more than Harandar, the Song said, {name}. Thanks for proving it."],
			L["Thank you, {name}. Orweyna said outsiders had much to teach us. I'm learning."],
			L["Our oaths forbid speaking to outsiders, {name}. I'll risk a thank you."],
			L["My people lived up here once, {name}. Thanks to you, I can see why."],
			L["We're raised on dedication and humility, {name}, so I'll just say thank you."],
			L["Back home I'd dance for that, {name}. Up here people stare, so: thank you."],
			L["Thank you, {name}. You've left me glowing like a moth back in Harandar."],
			L["Har'mara is the Village of Balance, {name}. I'd hate to go home lopsided."],
			L["If Aln'hara can hear anything where she is, {name}, I hope she heard that."],
		},
		asked = {
			L["Of course, {name}. Protect, tend and serve, my people say. This is the serving."],
			L["Of course, {name}. I answered the goddess's call. Yours is far easier to hear."],
			L["Of course, {name}. Dalnir would call this a distraction. Dalnir isn't here."],
			L["Of course, {name}. The roots never ask for anything. It's nice to be asked."],
			L["Gladly, {name}. Back home I'd have had to pretend I never saw you."],
			L["Of course, {name}. Mind the quills; they're friendlier than they look."],
			L["Gladly, {name}. Don't stand still too long; in Harandar you'd sprout mushrooms."],
			L["Of course, {name}. I was raised to do exactly as I was told. For once, I will."],
			L["No alndust in this one, {name}. Nothing will come to life and bite you."],
			L["Of course, {name}. Half the names up here are new to me. Yours I'll keep."],
			L["{buff}, {name}, grown under the World Trees and picked fresh."],
			L["Of course, {name}. Hagar is handling things at home; I'll handle them up here."],
			L["At my initiation I was asked who I really am, {name}. Someone who says yes."],
		},
		offer = {
			L["Take this, {name}, from a long way below. The roots send their regards."],
			L["Take this, {name}, and may Aln'hara be with you."],
			L["The sky has no ceiling, {name}. Anything could fall on you. Take this."],
			L["Follow the visions, Hagar said, {name}. Today they pointed at you. Take this."],
			L["My people would have watched you from the brush, {name}. I'd rather do this."],
			L["Harandar stayed out of the world's wars, {name}. You weren't so lucky. Here."],
			L["The Zur'ashar paint every tale worth telling, {name}. Make yours a long one."],
			L["Go carefully, {name}. The goddess's world is a garden, and gardens have thorns."],
			L["We tend roots in Harandar, {name}. You look as if you could use some tending."],
			L["My ancestors grew restless and sought a purpose, {name}. I've found mine. Here."],
			L["Har'mara lives at peace with its neighbours, {name}. I'd like that to spread."],
			L["The first outsiders I met were fighting off a saptor, {name}. Best take this."],
			L["My people have kept hope alive for ages on very little, {name}. Have some."],
			L["I'm still learning what to say to strangers, {name}. This seemed safest."],
			L["My people live beside a wound that never heals, {name}. Come back without one."],
		},
		kin = {
			L["Two haranir out in the world, {name}. No wonder the elders are up in arms."],
			L["Did the Song call you up as well, {name}? It never says where it's going."],
			L["Keep to the brush, they told us, {name}. We are both very bad at it."],
			L["Harandar's roots run under all of this, {name}. We're never far from home."],
			L["We're both out here looking for the goddess, {name}. Two pairs of eyes, then."],
			L["We were both told to give up childish adventures, {name}. Look at us now."],
			L["Nobody up here speaks Hara'ni, {name}. We could say anything."],
			L["The outsiders keep asking where we're from, {name}. I just point down."],
		},
		group = {
			L["Stay close, {name}. A haranir needs something to guard, and today it's you."],
			L["We once mastered every beast on our mountain, {name}. These won't take long."],
			L["Word from Harandar, {name}: the haranir are ready to join the fight."],
			L["My people's oldest shame is fighting each other, {name}. Let's fight together."],
			L["Mind your step, {name}. Where I'm from, the floor is mostly somebody's roots."],
			L["If anything crawls up from below, {name}, leave it to me. I know the type."],
			L["Dangerous, {name}? My ancestors walked into the deep with no idea what waited."],
			L["Do not fear the dark, {name}. Orweyna's words, and I keep them close."],
			L["I'll take the ledges, {name}. Clawed feet were made for this."],
			L["The goddess's world is worth fighting for, {name}. Even this bit of it."],
			L["I've cleared weeds, mud skippers and invasive fungi, {name}. Nothing scares me."],
			L["The Zur'ashar won't paint this fight, {name}. Let's win it anyway."],
		},
	},
}

-- For kin of a people with no kin lines of their own (a race the addon does
-- not know).
RP.KIN = {
	L["It is good to see one of our own, {name}."],
	L["Our people are few, {name}. That makes each of us count."],
}

-- Faction pride without a word about the other side. "Neutral" is a pandaren
-- on the Wandering Isle or a dracthyr before choosing, and anybody whose
-- faction the client would not say. A group member hears a side's group
-- lines, and its offers (said to a stranger on a road) only while it has
-- none.
RP.FACTION = {
	Alliance = {
		thanks = {
			L["Thank you, {name}. The Alliance looks after its own, and today that's me."],
			L["Kindness answered, {name}. For the Alliance!"],
			L["Stormwind has a statue for every hero, {name}. I'm putting in a word for yours."],
			L["The Alliance way, {name}: you help me, I help you, a dwarf buys the drinks."],
			L["Bolvar would bow, Magni would hug, {name}. I'll just return it."],
			L["If the Alliance gave medals for manners, {name}, you'd need a second tabard."],
			L["Returned in full, {name}. An ally who gives first is worth a whole garrison."],
			L["Thank you, {name}. I'll mention you in my letter home. Mother reads them aloud."],
			L["Thank you, {name}. Even the Stormwind guards would smile at that."],
			L["The Alliance at its finest, {name}: nobody asked, somebody helped. Thanks."],
			L["I'll tell everyone on the Deeprun Tram, {name}. It's a long tram. Thank you."],
			L["Most gallant, {name}. If I had a lion on my tabard, it would be purring."],
			L["Our kings bicker, {name}, but their people get on splendidly. Thank you."],
			L["The Alliance was forged by folk keeping their word, {name}. Here's mine."],
		},
		asked = {
			L["Of course, {name}. Allies help each other. It's practically in the name."],
			L["At once, {name}. The Alliance does not leave a friend wanting."],
			L["Of course, {name}. It's in the Alliance charter. Somewhere near the back."],
			L["By order of the Alliance, {name}: one {buff}, effective at once."],
			L["Anything for an ally, {name}. Within reason. This is well within reason."],
			L["Right away, {name}. SI:7 knew you would ask. I only just found out."],
			L["Straight away, {name}. The Alliance marches on requests like yours. And bread."],
			L["Yes, {name}. From Stormwind to Ironforge, 'please' opens every gate."],
			L["Right away, {name}. I've worn the blue all day hoping somebody would ask."],
			L["Hold still, {name}. I learned this faster than the Alliance anthem."],
			L["Of course, {name}. Armies win wars; small favours win allies. Here's one."],
		},
		offer = {
			L["For the Alliance, {name}! Stay strong out there. Stronger, now."],
			L["Onward, {name}. The Alliance is with you."],
			L["Take this, {name}. Had a gnome made it, it would come with twelve levers."],
			L["Compliments of the Alliance, {name}. We've done these since the Second War."],
			L["Chin up, {name}. Somewhere in Stormwind, a bard is writing about this."],
			L["Every ally counts, {name}. Today, you count double."],
			L["Anduin would want me to share, {name}, and I'd hate to disappoint him."],
			L["Take this, {name}. Stormwind's walls can't follow you, so this will have to."],
			L["Here, {name}. The gryphons get you there; this gets you back."],
			L["Alliance rule, {name}: keep your word, your walls, your friends. Here, friend."],
			L["Every ally deserves a lion at their back, {name}. I'm the nearest lion."],
			L["A gift from the Alliance, {name}. Signed, sealed and hand-delivered."],
			L["The Alliance never forgets the brave, {name}. Give it something to remember."],
		},
		group = {
			L["Together we stand, {name}. For the Alliance!"],
			L["Right, {name}: shields up, heads down, and nobody charges before the plan does."],
			L["The finest company the Alliance ever fielded, {name}. Or at least the nearest."],
			L["Together, {name}, we're practically a regiment. A small, well-dressed regiment."],
			L["Watch each other's backs, {name}. The Alliance was built by people who did."],
			L["Shields together, {name}. The Alliance never won anything in single file."],
			L["If this goes in the history books, {name}, let's be a chapter, not a footnote."],
			L["Whoever carries the banner, {name}, gets painted looking noble. Volunteers?"],
			L["Dwarven nerve, elven patience, human stubbornness, {name}: the Alliance recipe."],
			L["Keep the lion roaring, {name}. Softly, mind. We're sneaking."],
		},
	},
	Horde = {
		thanks = {
			L["Strength and honour, {name}. And kindness, it turns out. Repaid in full."],
			L["The Horde takes care of its own, {name}."],
			L["Strength given, strength returned, {name}. That's all of Horde diplomacy."],
			L["I'd carve your name on Orgrimmar's gates, {name}, but they're full. Thanks."],
			L["A goblin would've sent you an invoice, {name}. I'm sending this instead."],
			L["You did not have to do that, {name}. That is why the Horde remembers it."],
			L["In the Horde we do not say thank you twice, {name}. So: once, and meant."],
			L["In the Horde a debt is carried like an axe, {name}: openly, and not for long."],
			L["The gate grunts will hear of you, {name}. They'll grunt. It means respect."],
			L["The Horde keeps two lists, {name}: grudges and favours. Yours is the short one."],
			L["Honour says repay you, {name}. Manners say smile. I'm working on the smile."],
			L["That landed softer than any zeppelin I've ridden, {name}. Thank you."],
			L["Thanks, {name}, in Orcish, Taur-ahe, Zandali and Gutterspeak. Pick one."],
			L["Thrall taught the Horde honour, {name}. Nobody had to teach you. Thank you."],
			L["You gave first, {name}. In the Horde that earns first cut of the roast. Here."],
			L["The Warchief can't thank everyone himself, {name}. He's delegated it to me."],
		},
		asked = {
			L["Consider it done, {name}. For the Horde, and for anyone who asks nicely."],
			L["You only had to ask, {name}. The Horde answers."],
			L["The Horde usually helps with axes, {name}. Today, {buff}."],
			L["Done, {name}. No speeches. The Horde has plenty of those already."],
			L["You asked, {name}. In Orgrimmar, that counts as a formal treaty."],
			L["Asking is no weakness, {name}. Refusing an ally would be."],
			L["No need to bang a war drum, {name}. You asked; it's done."],
			L["Of course, {name}. In the Horde, 'please' outranks everyone but the Warchief."],
			L["In Orgrimmar we'd have argued about it first, {name}. Tradition. Here."],
			L["Consider it requisitioned, {name}. The quartermaster needn't hear about it."],
			L["Done, {name}. If anyone asks, I scowled the whole time. I've a reputation."],
			L["Of course, {name}. Horde hospitality: rough edges, full helpings."],
			L["The Horde came together because somebody always said yes, {name}. Yes."],
		},
		offer = {
			L["For the Horde, {name}! Go with strength. I've just handed you some."],
			L["Go with honour, {name}. Victory awaits."],
			L["Go and do something worth a song, {name}. Loud songs. The Horde likes loud."],
			L["Walk tall, {name}. The Horde always made room for those the world turned away."],
			L["Take this, {name}, and a word of Horde wisdom: hit first, apologise never."],
			L["Victory or death, {name}. I'd prefer victory, so take this."],
			L["Blood and thunder, {name}! Go and be the thunder."],
			L["For the Horde, {name}, and for you. The Horde's big; you're closer."],
			L["Here, {name}. Stronger together, they say, and I've just done my half."],
			L["Carry this, {name}. It weighs less than a Horde banner and flies just as proud."],
			L["Here, {name}. The Horde feeds its own, arms its own, and now enchants them."],
			L["Take this, {name}. Whatever's out there is about to meet the Horde."],
			L["Here, {name}. Wherever you're headed, arrive looking like the Horde sent you."],
			L["The Crossroads never turned a traveller away, {name}. It overcharged a few."],
			L["The Horde raises you tough, {name}. This is for the days tough isn't enough."],
			L["Take this, {name}. A Horde gift: no ribbon, no speech, no refunds."],
			L["Stand tall, {name}. Taller than that. The Horde has tauren to keep up with."],
		},
		group = {
			L["Our strength is each other, {name}. For the Horde!"],
			L["Forward, {name}. The Horde advances together. Retreats... never, officially."],
			L["Together we're a war band, {name}. Apart, we're just loud."],
			L["Shoulder to shoulder, {name}. Whoever charges first buys the grog."],
			L["Nobody gets left behind, {name}. I've counted us twice."],
			L["Rule of the warband, {name}: nobody eats until everybody's back."],
			L["Drums up, {name}. If we can't be quiet, we'll be terrifying."],
			L["The Horde never won a thing alone, {name}. Let's not start now."],
			L["We fight like the Horde, {name}: all at once, and nobody waits for the signal."],
			L["Right, {name}. Spoils shared, blame shared, glory to the loudest."],
			L["Look at us, {name}. The Warchief would be proud. Mildly. From a distance."],
			L["Tusks, horns, long ears and bare bone, {name}. Finest warband going."],
			L["The war stories get bigger after, {name}. Let's give them a head start."],
		},
	},
	Neutral = {
		thanks = {
			L["Thank you, {name}. Good hearts turn up on every side, and apparently here."],
			L["Thank you, {name}. No side, no title, just kindness. Legends start like this."],
			L["Thank you, {name}. Kindness has no faction, which is handy, since I have none."],
			L["Thank you, {name}. Whichever side gets you is getting a bargain."],
			L["Whoever claims me in the end, {name}, I'll remember you first. Thank you."],
			L["Strictly neutral, {name}, but gratitude doesn't count. Thank you."],
			L["Thank you, {name}. I carry no banner, so both hands are free to return this."],
			L["The Steamwheedle stay neutral for gold, {name}. I do it for moments like this."],
			L["Neither side has taught me their thanks yet, {name}, so here's the plain kind."],
			L["Thank you, {name}. I stand between two great banners, and still you noticed me."],
			L["Two sides at war, {name}, and us being lovely right in the middle. Thank you."],
		},
		asked = {
			L["Gladly, {name}, whatever banner you fly. I don't even own a banner."],
			L["Certainly, {name}. I help everyone. It's the one thing I've decided."],
			L["Everyone asks me which side I'm on, {name}. Much nicer to be asked for help."],
			L["Of course, {name}. No war council to ask; just me, and I say yes."],
			L["Here you are, {name}. No oath, no colours, no fee."],
			L["I can't pick a side yet, {name}, but I can pick a good cause. This is one."],
			L["At once, {name}. I have no side to be on, so for now I am entirely on yours."],
			L["Of course, {name}. Nobody pays me to take sides, so I take requests instead."],
			L["Neutral does not mean unwilling, {name}. It means I help first and argue never."],
		},
		offer = {
			L["Friends can come from any side, {name}. Or, like me, from none in particular."],
			L["Soon they'll hand us tabards, {name}. Until then, we look after each other."],
			L["I haven't chosen a side yet, {name}, so I'm being kind to both. Take this."],
			L["A gift with no strings, {name}. I don't even have a faction to tie them to."],
			L["Go on, {name}. Two whole factions are waiting to argue over us."],
			L["No quartermaster yet, {name}, so nobody's counting. Have plenty."],
			L["Take this, {name}. Neutral ground travels with me; you're standing on some."],
			L["The Argent Dawn helps whoever needs it, {name}. I'm learning from the best."],
			L["Booty Bay's rule: no fighting on the docks, {name}. Mine: no refusing a gift."],
			L["The one thing both factions agree on, {name}. They just don't know it yet."],
			L["This goes with any tabard, {name}. I made sure by giving it no colours at all."],
			L["For you, {name}. Neither Orgrimmar nor Stormwind sent it. It works anyway."],
			L["Here, {name}. I belong to no nation yet, so I practise belonging to everyone."],
		},
		group = {
			L["Side by side, {name}, whatever comes."],
			L["No flag over this party, {name}, just us. That's plenty."],
			L["One day we'll pick sides, {name}. Today we pick fights, together."],
			L["Whatever side the rest of the world is on, {name}, I'm on this party's."],
			L["Neutral in the war, {name}, but very partial to this group."],
			L["They call us a neutral party, {name}. Nobody said it had to be a quiet one."],
			L["Whatever we fight today, {name}, it's nothing personal. Just very thorough."],
			L["One side in this party, {name}: ours. Smallest faction on Azeroth. The best."],
			L["No orders from any capital, {name}. We choose our road. Let's choose quickly."],
			L["No war to win today, {name}, just this one fight. Much more manageable."],
		},
	},
}

-- Anybody's, in character without belonging to one people: they keep a race
-- from repeating itself, and they are all an unknown race has.
RP.GENERAL = {
	thanks = {
		L["One good turn deserves another, {name}."],
		L["Have some {buff} in return, {name}."],
		L["Kindness should go both ways, {name}. Thank you."],
		L["You went first, {name}, so I'll go second and we'll call it friendship."],
		L["I'd write you a song, {name}, but {buff} is less off-key."],
		L["A gift for a gift, {name}. At this rate we'll be unstoppable by supper."],
		L["All square, {name}. Unless you'd like to make it best of three."],
		L["You started it, {name}. I'm only finishing it."],
		L["That was kind, {name}. The day just got noticeably better. Here's my half."],
		L["I was about to do that for you, {name}. Honestly. Here's proof."],
		L["Thank you, {name}. I'll sleep better tonight, and I sleep in a ditch."],
		L["Two good things today, {name}: your kindness, and the chance to return it."],
		L["You had me in your debt for all of three seconds, {name}. There."],
		L["Gratitude is best served quickly, {name}. Here it is, still warm."],
		L["Well, {name}, now I have to be a better person all day. Thanks for that."],
		L["Returned with a bow, {name}. A figurative one. My back isn't what it was."],
		L["Thank you, {name}. Somebody had to go first, and I'm glad it was you."],
		L["Thank you, {name}. You've rescued a day I'd written off at breakfast."],
	},
	asked = {
		L["You asked, {name}, and here it is."],
		L["{buff}, coming right up, {name}."],
		L["Gladly, {name}. One moment."],
		L["Asked and answered, {name}. Next question?"],
		L["Say the word and it's yours, {name}. You said several. Here."],
		L["For you, {name}? Gladly. I was hoping someone would ask."],
		L["Of course, {name}. Easiest yes I'll say all day."],
		L["Right away, {name}. Finally, a question I know the answer to."],
		L["Of course, {name}. Nicely asked, gladly given."],
		L["Hold still, {name}. It works best on people who aren't fidgeting. So, nobody."],
		L["Here you are, {name}. I'd make you wait for effect, but that seems rude."],
		L["Yes, {name}. I'd have said it sooner if you'd asked sooner."],
		L["Say no more, {name}. Done before you finished asking."],
		L["There, {name}. Next time, don't ask; just stand near me looking hopeful."],
		L["Coming up, {name}. This is the one part of my day that goes to plan."],
		L["Asking nicely works, {name}. Tell everyone. The world could use the news."],
		L["At once, {name}. Stay put, or this lands on your shadow instead."],
	},
	offer = {
		L["Safe travels, {name}. {buff} packs lighter than a sword."],
		L["A small blessing for the road, {name}."],
		L["Go well, {name}, and come back in one piece."],
		L["No reason, {name}. It just felt like a {buff} sort of day."],
		L["Don't mind me, {name}. Just passing, with a spare {buff}."],
		L["Consider it a gift, {name}. I'd wrap it, but it glows through the paper."],
		L["Here, {name}. Pass it on when you meet someone who needs it."],
		L["Whatever brings you here, {name}, may it go better than planned."],
		L["Just being neighbourly, {name}. Very, very temporary neighbours."],
		L["You looked about to do something brave, {name}. Here, for that."],
		L["No need to stop, {name}. It works while you walk."],
		L["Nothing asked, nothing owed, {name}. Nothing to do but go and be splendid."],
		L["Call it a wager, {name}, that you'll do something worthwhile with it."],
		L["A gift from a passing stranger, {name}. The best kind, the old stories say."],
		L["It's rude to pass someone without a greeting, {name}. This is mine."],
		L["Same road as me, {name}? Then take this for the journey."],
		L["If today goes well, {name}, remember me. If it goes badly, I was never here."],
		L["Hold still a moment, {name}. There. Best-prepared person in sight."],
	},
	group = {
		L["Everyone ready? You are now, {name}."],
		L["A little something for the party, {name}."],
		L["Stay close, {name}. We go further together."],
		L["House rules, {name}: nobody dies, nobody sulks, everybody eats after."],
		L["There, {name}. Now if this goes badly, it won't be my fault."],
		L["All set, {name}. I'd give a speech, but we'd be here all day."],
		L["Look after that, {name}. It's the only one I brought for you."],
		L["Now we look the part, {name}. Let's go and be it."],
		L["Fresh {buff} all round, {name}. The rest is luck and elbows."],
		L["If anyone has a plan, {name}, now's the time. No? Wonderful. Onward."],
		L["One each, {name}. Don't swap; they're fitted."],
		L["Whoever starts the fight, {name}, has to tell the story afterwards."],
		L["Good friends, sharp steel, {buff}. What else is there, {name}?"],
		L["Stay where I can see you, {name}. I can't help what I can't find."],
		L["If this ends up a legend, {name}, I want a line in it. Just the one."],
		L["Brace yourselves, {name}. And each other, if it comes to that."],
		L["Chin up, {name}. Whatever's ahead has never met this lot before."],
		L["Do try to stay in one piece, {name}. I'm only equipped for small repairs."],
		L["Well, {name}, we look ready. Let's go before we find out otherwise."],
		L["If we get lost, {name}, we're exploring. Nobody ever scolded an explorer."],
	},
}

---------------------------------------------------------------------------
-- the moment
--
-- Every pool below is somewhere a line can only be said in one kind of
-- moment. Each joins the draw in RP.Pick only when that moment is known to be
-- this one, and every line in them works whichever of the four moments it is
-- (thanks, asked, offer, group) unless its pool says otherwise.
---------------------------------------------------------------------------

-- A class's line that is about one of its spells, by the line, to that
-- spell's buff key: said only while that spell is the one going out (RP.Pick).
-- The warlock's lines were written when Unending Breath was a warlock's only
-- buff, and four are about water; on Mists a warlock hands out Dark Intent
-- (Buffs.lua: Automatic never casts Unending Breath there). Marked where they
-- stand rather than moved, since a pool's first lines are the box's examples.
RP.ABOUT = {}
local function About(key, text)
	RP.ABOUT[text] = key
	return text
end

-- The speaker's class (UnitClass's second return), by moment as the peoples'
-- lines are; a group member hears the offers when there are no group lines.
-- A class with no lines of its own simply has none here.
RP.CLASS = {
	MAGE = {
		thanks = {
			L["Thank you, {name}. I'd conjure a gift in return, but it would only be water."],
			L["Much obliged, {name}. I'll write it up properly later. Several pages."],
			L["Thank you, {name}. They never taught gratitude at Dalaran. I'm self-taught."],
			L["Kind of you, {name}. Everyone assumes mages need no help. We do."],
			L["Thank you, {name}. I nearly Counterspelled that on reflex. So glad I didn't."],
			L["Even a frost mage would thaw at that, {name}. Thank you."],
			L["Thank you, {name}. Noted in my spellbook, between Frost Nova and lunch."],
			L["Repaid at once, {name}, before I pass a bookshop. I've lost weeks that way."],
			L["Twenty years in the library, {name}, and no book mentioned people like you."],
			L["Arcane theory says nothing comes free, {name}. Theory was wrong. Thank you."],
		},
		asked = {
			L["Of course, {name}. And yes, I suppose you'll want water as well."],
			L["As requested, {name}. I'll find my page again later."],
			L["At once, {name}. Carefully, too; I've blinked into two walls today."],
			L["Gladly, {name}. Knowledge should be shared. The Kirin Tor say so, reluctantly."],
			L["Certainly, {name}. I'll cast it slowly. The hand movements are the best part."],
			L["Of course, {name}. Think of it as homework, and I've done it for you."],
			L["Of course, {name}. Antonidas taught me this. He also taught me to duck."],
			L["At once, {name}. Arcane, not fire. I did check."],
			L["Certainly, {name}. It's this or a lecture on ley lines, and you've been kind."],
			L["You asked a mage, {name}. The spell is instant; the explanation is not."],
			L["I've cast this a thousand times, {name}. Nine hundred and ninety went well."],
			L["Certainly, {name}. Stand still. Fidgeters have been known to end up woolly."],
		},
		offer = {
			L["Here, {name}. I had a spare thought and nowhere to put it."],
			L["Take this, {name}. I'd add bread, but conjured bread tastes of nothing."],
			L["{buff} for you, {name}. No charge, unlike the portals."],
			L["Here, {name}. Most folk I point at turn into sheep. Today's your lucky day."],
			L["Nothing on fire, nothing frozen, {name}. I'm branching out."],
			L["For you, {name}. I was practising, and you happened to be the nearest head."],
			L["Here, {name}. Freshly cast, and hardly crackling at all."],
			L["Kings once hired Dalaran for this, {name}. You get it for nothing."],
			L["Take this, {name}. It wears off, unlike my last experiment."],
			L["For you, {name}: everything I learned in Dalaran, minus the essays."],
			L["Here, {name}. Arcane magic is best shared, before it gets ideas of its own."],
			L["Evocation takes an age, {name}, so I spend my mana where it counts. Here."],
			L["Here, {name}. A mage who walks past without helping is just a very tall hat."],
		},
		group = {
			L["Now that you're clever, {name}, stand between me and the angry things."],
			L["For the record, {name}, I only blink away when it's tactically sound."],
			L["Water's on me after, {name}. Please don't ask for it mid-fight."],
			L["Minds sharpened, {name}. I'll handle the fire, the frost and the panicking."],
			L["Right, {name}: if I say 'Frost Nova', run. If I say 'run', also run."],
			L["Pyroblast takes a while, {name}. Whatever interrupts it, I take personally."],
			L["If I ice-block, {name}, I'm not frozen with fear. I'm frozen on purpose."],
			L["Portals home are on me after, {name}. Getting there alive is on all of us."],
			L["Anything you'd rather not fight, {name}, point at it. It'll be wool by teatime."],
			L["I'll drop a Blizzard on them, {name}. You're welcome to watch, from outside it."],
			L["Keep them off me, {name}, and I'll keep them on fire."],
			L["If I go quiet, {name}, it's Evocation, not sulking. Usually."],
			L["If this goes badly, {name}, I've a teleport home. I'd never use it. Probably."],
		},
	},
	PRIEST = {
		thanks = {
			L["How thoughtful, {name}. The Light keeps accounts; I settle mine early."],
			L["Thank you, {name}. I'll put in a good word with the Light. It owes me several."],
			L["Thank you, {name}. A small miracle, and I didn't even have to pray for it."],
			L["Thank you, {name}. My faith in people is restored. It was only resting."],
			L["Thank you, {name}. You're in tonight's prayers. Near the top."],
			L["Healers are rarely on this end of it, {name}. I'd forgotten how nice it is."],
			L["Thank you, {name}. You've saved me a prayer, and I'm always one short."],
			L["Thank you, {name}. I'd give a sermon on generosity, but you've just given it."],
			L["Thank you, {name}. I'll light a candle for you. Two. I'm feeling reckless."],
			L["Even my shadowy side is smiling, {name}. It has no face, so take my word."],
		},
		asked = {
			L["Of course, {name}. The Light keeps no hours, and neither, sadly, do I."],
			L["Straight away, {name}. Most prayers take longer; you've found a shortcut."],
			L["Certainly, {name}. The Light shines on those who ask. I just aim it."],
			L["With pleasure, {name}. Faith moves mountains; I'm starting smaller."],
			L["Of course, {name}. Confessions are extra, and I'd rather not hear them."],
			L["Of course, {name}. Nobody who asks goes without. The Light's rule, and mine."],
			L["Certainly, {name}. A warm glow means the Light. A cold one, tell me at once."],
			L["Of course, {name}. I'll pray it lasts. I'm told I have an in."],
			L["Certainly, {name}. I heal, I smite, I do funerals. This is the cheerful bit."],
		},
		offer = {
			L["Bless you, {name}. No, you didn't sneeze; I'm simply thorough."],
			L["Here, {name}. Think of it as a prayer that arrived early."],
			L["The Light asked me to pass this along, {name}. I'm paraphrasing."],
			L["Take this, {name}. It saves us both an awkward resurrection later."],
			L["Freely given, {name}. Faith costs nothing. The robes, sadly, did."],
			L["Here, {name}. Think of me as a small, walking temple. No steps to climb."],
			L["A blessing for a stranger, {name}. The Light insists there's no such thing."],
			L["Take this, {name}. No collection plate follows. Look: empty hands."],
			L["Here, {name}. I'd preach, but you look like somebody with somewhere to be."],
			L["Small mercies are my speciality, {name}. Here's one."],
			L["Here, {name}. I'd float over properly, but levitating in public draws a crowd."],
		},
		group = {
			L["Your turn, {name}. Now, I beg you all: make my job boring."],
			L["Everyone stay near me, {name}. The Light has a limited range."],
			L["There, {name}. If anyone falls, I'll be very disappointed, then fix it."],
			L["Done, {name}. I'll be at the back, praying loudly."],
			L["If I scream, {name}, it's a spell, and everything runs. Please don't join in."],
			L["If I Fade, {name}, I haven't gone. I've just become deeply uninteresting."],
			L["One shield each, {name}. After that, souls need a lie-down. Pace yourselves."],
			L["Let's all come back from this the usual way, {name}: walking."],
			L["I'll keep you alive, {name}. You keep me from having to say 'I told you so'."],
			L["I prayed over this group, {name}. The Light said 'good luck'. I'll take it."],
		},
	},
	DRUID = {
		thanks = {
			L["Thank you, {name}. I'd offer you berries, but I ate them all."],
			L["Thanks, {name}. Like rain in a dry season."],
			L["Much obliged, {name}. My cat form wants to bring you a rabbit. I've said no."],
			L["Thank you, {name}. I'll plant a tree in your honour. Give it a century."],
			L["Thank you, {name}. May your road stay green and your water sweet."],
			L["Kindly done, {name}. I felt that right down to my roots."],
			L["Nature returns everything eventually, {name}. I'm quicker. Thank you."],
			L["Barkskin keeps most things out, {name}. Kindness got straight through. Thanks."],
			L["Thank you, {name}. As a bear this would be a hug. Be glad I'm in this shape."],
		},
		asked = {
			L["Certainly, {name}. Give me a moment to remember which shape has hands."],
			L["Of course, {name}. Hold still, like an oak. Oaks are wonderful at it."],
			L["Gladly, {name}. The wild shares everything. Well, not the bears."],
			L["Right away, {name}. The wild's had a good season; it can spare this."],
			L["Of course, {name}. Nature doesn't take requests, but I do."],
			L["Gladly, {name}. Ask a tree and you'll wait a year. Ask a druid and it's now."],
			L["Of course, {name}. The balance tips a little your way. Don't tell the balance."],
			L["I'd have run over, {name}, but as a cheetah, and you'd have screamed. Here."],
			L["Of course, {name}. The wild is kind to all who ask. Midges excepted."],
		},
		offer = {
			L["Fresh from the Emerald Dream, {name}. Sorry if I yawn."],
			L["Take this, {name}. Nature provides, and I'm its errand runner today."],
			L["The wild calls you friend now, {name}. Handy, since most of it has teeth."],
			L["I'd have picked you flowers, {name}, but this keeps better."],
			L["Here, {name}. Cenarius would want you to have it. I'm nearly sure."],
			L["Here, {name}. For cold nights, sharp claws and long roads."],
			L["Take this, {name}. The wild has been watching you, and it's decided you'll do."],
			L["There, {name}. Walk lightly, and the forest will walk with you."],
			L["For you, {name}. The Moonglade sends its regards. It sends very few."],
			L["Nature is cruel, lovely and damp, {name}. This helps with two of those."],
			L["I tie strangers up in roots most days, {name}. This is the nicer part."],
		},
		group = {
			L["Ready, {name}? Now, whatever happens, nobody startle the bear."],
			L["There, {name}. I'll be the cat, the bear or, if we must swim, the seal."],
			L["I've one rebirth in me, {name}. Please, nobody make me choose."],
			L["Close ranks, {name}. The forest is watching, and it's rooting for us."],
			L["I'll heal or I'll maul, {name}. Tell me which before it's urgent."],
			L["I've one Innervate, {name}. Whoever looks most desperate gets it. No acting."],
			L["If I start glowing and hooting, {name}, that's moonkin. It's a serious form."],
			L["If it gets crowded, {name}, I'll call a Hurricane. Hold on to your hats."],
			L["We move like a herd, {name}. A mixed herd. One of us is sometimes a bear."],
		},
	},
	PALADIN = {
		thanks = {
			L["Kindness, {name}? My favourite virtue. Just ahead of polishing."],
			L["For that, {name}, my best blessing. Not the second best. The best."],
			L["Virtue rewarded on the spot, {name}! I do love it when that happens."],
			L["Thank you, {name}. My oath says to repay kindness. I'd do it anyway."],
			L["I'll judge you favourably, {name}. I judge most things harshly. Thank you."],
			L["Thank you, {name}. My aura just brightened. It does that when I'm touched."],
			L["A kindness, {name}! I'll have it engraved on my shield, beside the dents."],
			L["Much obliged, {name}. My warhorse sends thanks as well. He's more reserved."],
			L["I swore to protect the good, {name}. You've just gone to the top of the list."],
		},
		asked = {
			L["By the Light, {name}, of course! I've been hoping somebody would ask."],
			L["You have my blessing, {name}, in every sense."],
			L["Certainly, {name}. Kneel if you like. I won't insist. I'll be delighted."],
			L["Gladly, {name}. I never run short of blessings. Mana, now and then."],
			L["Certainly, {name}. Hold still. My aim is righteous; my gauntlets are clumsy."],
			L["Gladly, {name}. Helping is the oath. Shining while I do it is a bonus."],
			L["Of course, {name}. Stand fast, chin up, and look deserving. There. You do."],
			L["Of course, {name}. You'd be amazed how rarely anyone asks the tin can for help."],
			L["Of course, {name}. A moment while I pick the blessing. I do have favourites."],
		},
		offer = {
			L["The Light asks nothing in return, {name}. I, however, accept thanks."],
			L["Go with the Light, {name}. I'll be right behind you, clanking."],
			L["The blessing's free, {name}. You've been spared the sermon. This time."],
			L["There, {name}. It won't last forever, so be heroic while it does."],
			L["Stand tall, {name}. The Light walks with you, and it has excellent posture."],
			L["Take this, {name}. I'd give you my hammer too, but it's very attached to me."],
			L["Blessings are for handing out, {name}. Hoarding them is frowned upon. By me."],
			L["Justice for the wicked, blessings for the rest, {name}. You're the rest."],
			L["Take this, {name}. My libram says to share. It says a lot; this bit I like."],
			L["Chivalry isn't dead, {name}. It's in heavy armour, and it brought you this."],
			L["Wear it with pride, {name}. Pride's a sin, but only in large amounts."],
		},
		group = {
			L["You're blessed, {name}. Keep behind my shield and we'll do fine."],
			L["Stand fast, {name}. We have the Light, and I have a very large hammer."],
			L["One blessing each, {name}. The Light is generous, but it insists on turns."],
			L["Splendid, {name}. Now, nobody look directly at me. I'm rather bright today."],
			L["Stay inside my aura, {name}. It's warmer than it looks."],
			L["If I stun something, {name}, hit it while it's thinking things over."],
			L["The glowing ground is mine, {name}. Stand in it freely; it only bites them."],
			L["I'll judge them, {name}, and you sentence them. A very efficient court."],
			L["If I shout 'for the Light', {name}, it means charge. Or pray. Usually both."],
			L["Armour polished, hammer blessed, {name}, and my horse is sulking. We're ready."],
			L["I've called on Righteous Fury, {name}. Let them come to me."],
		},
	},
	WARLOCK = {
		thanks = {
			L["How kind, {name}. My imp says thank you too. He's lying, but I'm not."],
			L["Thank you, {name}. It's been ages since anyone gave me something uncursed."],
			L["Thank you, {name}. I'll repay you with something I didn't find in a crypt."],
			L["Most gracious, {name}. I've asked the voidwalker to stop looming at you."],
			L["Thank you, {name}. Most folk cross the road when they see me."],
			L["No blood, no bargain, no binding, {name}? What a strange way to trade. Thanks."],
			L["Thank you, {name}. Should anything haunt you, send it my way."],
			L["How thoughtful, {name}. Everything I'm given, I return. Except souls. Here."],
		},
		asked = {
			L["Of course, {name}. No soul required. This time."],
			L["You asked a warlock for help, {name}. Bold. I like you already."],
			L["Of course, {name}. The imp offered to help, and I said no, for all our sakes."],
			L["Certainly, {name}. Of all my spells, this is the one I can do at parties."],
			L["Gladly, {name}. A good deed on my record; the Shadow Council would be appalled."],
			L["Of course, {name}. Please don't read the book I'm holding. For your own sake."],
			L["Certainly, {name}. Feel watched? That's only the Eye of Kilrogg. Hold still."],
			L["Of course, {name}. I only curse people who don't ask nicely. You're quite safe."],
			L["Yes, {name}, it's the one without screaming. Hold still."],
			About("breath", L["Of course, {name}. Going somewhere wet? I won't ask. Warlocks never ask."]),
		},
		offer = {
			L["Here, {name}. Don't ask where it came from. Really, don't."],
			About("breath", L["Fall in a lake someday, {name}, and you'll think of me fondly."]),
			About("breath", L["Breathe easy, {name}. I'd hate to lose you to anything as dull as water."]),
			L["Here, {name}. You'll want a soulstone too, but that's a bigger conversation."],
			L["Take this, {name}. It's the only spell of mine the priests approve of."],
			L["Take this, {name}. My mother still thinks I'm a mage. Let's keep it that way."],
			L["Here, {name}. It isn't green, it doesn't whisper, and it won't follow you home."],
			L["Here, {name}. Dark magic, used for good. Do tell my old tutor; he'll hate it."],
			L["Here, {name}. I keep the darker spells for people who've earned them."],
			L["Here, {name}. I'm not all curses and fear. Mostly, but not all."],
			L["My grimoire has a chapter on kindness, {name}. It's short, but I've read it."],
		},
		group = {
			L["Everyone ready, {name}? Souls intact? Good. Let's keep it that way."],
			L["Stay close, {name}. The voidwalker takes the hits; I take the credit."],
			About("breath", L["Swim all you like, {name}. If anyone drifts off, I'll summon them back."]),
			L["Do pet the felhunter, {name}. Just take your spells off first."],
			L["If I fear something, {name}, don't chase it. It comes back. Angrier."],
			L["I trade blood for mana, {name}. It looks worse than it is."],
			L["Healthstones after, {name}. For a crisis, mind, not as a snack."],
			L["Keep clear when I cast Hellfire, {name}. I burn too. That's the tragic part."],
			L["My imp is on fire, {name}, and he's on our side. Please stop dousing him."],
			L["If something green falls from the sky, {name}, that's mine. Cheer."],
		},
	},
	WARRIOR = {
		thanks = {
			L["Thank you, {name}! Sorry, was that loud? I only have the one volume."],
			L["Much obliged, {name}. No spells to give back, but I do a very sincere shout."],
			L["Thanks, {name}. Now I'm twice as angry. In the good way."],
			L["Thanks, {name}. You've earned a place right behind me. Safest spot there is."],
			L["Thank you, {name}. Kindness makes me soft. Luckily I've plenty of armour."],
			L["Thank you, {name}. My armourer thanks you too. I paid for his house."],
			L["Thanks, {name}. I'd bandage something for you, but you look annoyingly fine."],
			L["Thank you, {name}. I switched to my grateful stance for that. It's rarely used."],
			L["You've given me magic, {name}. No idea where to keep it. I'll wear it. Thanks."],
			L["Owing folk makes me restless, {name}, and restless makes me charge things."],
		},
		asked = {
			L["You want a shout, {name}? I was going to shout anyway."],
			L["Of course, {name}. A fighter who asks for courage already has some."],
			L["Right away, {name}. Square your shoulders. There, that's half of it."],
			L["Happily, {name}! Go hit something for me."],
			L["Right, {name}. Deep breath. Not you. Me."],
			L["Happy to, {name}. First request today that didn't involve lifting something."],
			L["Coming up, {name}. Plant your feet. This one has a kick to it."],
			L["Of course, {name}. Most folk only ask me to stop. This is a nice change."],
			L["Of course, {name}. Took me years to learn. Years of yelling at trees, mostly."],
		},
		offer = {
			L["Consider yourself shouted at, {name}. Affectionately."],
			L["No incense, no prayers, {name}. Just me, shouting encouragingly."],
			L["Chin up, {name}! If anything bothers you, I'll charge it."],
			L["There, {name}! Anything that doesn't feel braver now wasn't listening."],
			L["Here, {name}, some courage. Spend it freely; I've plenty more."],
			L["Here, {name}. Something sharper than a whetstone: morale."],
			L["Take this, {name}. Warriors don't carry spells, so we carry each other."],
			L["Here, {name}. You look about to walk into something big. Walk in harder."],
			L["Here, {name}. No magic in it. Just a warrior believing in you, very firmly."],
			L["Take this, {name}. It's loud, it's free, and I mean it."],
			L["Here, {name}. Tell whatever you fight that a warrior vouched for you."],
			L["That one was for you, {name}. The next one's for whatever's in your way."],
		},
		group = {
			L["Listen up, {name}! That's it. That was the whole speech."],
			L["Where's the danger, {name}? Never mind, I'll find it. Face first."],
			L["Right, {name}! I go first, I shout loudest, and nobody touches the healer."],
			L["Everybody angrier? Good. Onward, {name}, and mind my backswing."],
			L["I need to be hit before I'm any use, {name}. Nobody panic when it happens."],
			L["Bandages are in my pack, {name}. I tied the knots, so they're very secure."],
			L["Right, {name}: I take the hits, you take the credit, and we split the repairs."],
			L["If I go red and quiet, {name}, that's Berserker Rage. Red and loud, all's well."],
			L["My shield's seen worse than this, {name}. So has my face. Onward."],
		},
	},
	DEATHKNIGHT = {
		thanks = {
			L["The living rarely lend me much, {name}. I'll be prompt, in case it catches on."],
			L["Thank you, {name}. I owe you one fight at your side, on a day of your choosing."],
			L["The skulls came with the armour, {name}. The gratitude is all my own."],
			L["My one healing spell only mends the dead, {name}. Do stay healthy. Thank you."],
			L["Your kindness is safe with me, {name}. Very little else is. Thank you."],
			L["I've stood at the runeforge all night for less than that, {name}. Thank you."],
			L["The Ebon Blade answers courtesy in kind, {name}, and insults with the blade."],
			L["Tonight's watch will pass quicker for that, {name}, and I keep a great many."],
			L["Thank you, {name}. Ride with me a while, if your horse will stand next to mine."],
			L["Thank you, {name}. I'll have the dead salute you. Badly, but with feeling."],
		},
		asked = {
			L["Very well, {name}. Stand fast; the horn is loud, and the cold follows it."],
			L["Of course, {name}. Most of what I do is quick or final. This is the quick kind."],
			L["You have my horn and my word, {name}. One is louder; the other lasts longer."],
			L["Of course, {name}. Mind the runeblade. It doesn't know you yet."],
			L["Gladly, {name}. I'd far rather sound a horn for a friend than a dirge."],
			L["At once, {name}. A knight who makes an ally wait isn't worth their runes."],
			L["Yes, {name}. Step into view; this helm was made for glaring, not for looking."],
			L["The Ebon Blade serves the living now, {name}. Even the impatient ones."],
			L["Of course, {name}. Pay no mind to the frost on your boots. It brushes off."],
			L["The paladins at Light's Hope ask far more stiffly, {name}. They still get it."],
		},
		offer = {
			L["Hear that, {name}? Winter, on your side for once."],
			L["The horn sounds for you, {name}. It used to sound only for the Scourge."],
			L["Advice from a death knight, {name}: never fight fair, and never fight alone."],
			L["Acherus floats over the Plaguelands, {name}. It's good to come down and help."],
			L["The road's dark, {name}. I should know; I'm usually the darkest thing on it."],
			L["You looked a little short of an army, {name}. A horn is the next best thing."],
			L["Here, {name}. My ghoul wanted to say hello. I've spared you that."],
			L["Take this, {name}. Cold, loud and well meant, like most of my order."],
			L["Whatever waits out there, {name}, I've likely killed its cousin. Take this."],
			L["Take this and keep moving, {name}. Trouble tends to follow death knights about."],
		},
		group = {
			L["If I raise an army, {name}, be civil to it. They didn't ask to be here either."],
			L["Walk where I walk, {name}. The frost will hold us up over any lake."],
			L["If I look hurt, {name}, let me hit something. That's how death knights mend."],
			L["My ghoul goes in first, {name}. He won't mind. He's long past minding."],
			L["Keep up, {name}. The dead don't tire, and I forget the living do."],
			L["Don't fall, {name}. I can bring you back, but it's an unsettling way to wake."],
			L["Leave the fevers to me, {name}. They spread on their own. I like to supervise."],
			L["The horn has sounded, {name}. Whatever heard it knows we're coming."],
			L["Whatever we kill today, {name}, stays dead. I'll see to that personally."],
			L["Pick a target, {name}, and I'll pick the same one. It shortens the arguments."],
		},
	},
	MONK = {
		thanks = {
			L["Take a gift with both hands, my master said, {name}. And return it with both."],
			L["Thank you, {name}. I feel light enough to run up a waterfall. I may try."],
			L["I meditated on generosity for years, {name}. You skipped to the end. Thank you."],
			L["I came out into the world to find good people, {name}. That's one. Thank you."],
			L["The masters at the Peak of Serenity would bow to that, {name}. So do I."],
			L["Kindly done, {name}. The next brigand who jumps me gets one kick fewer."],
			L["A kindness is like a strike, {name}: it's all in the timing. Yours was perfect."],
			L["Thank you, {name}. These hands were trained to strike. Today they get to give."],
			L["Thank you, {name}. Answered the monk's way: no wasted motion, no wasted words."],
			L["Gratitude makes even a monk clumsy, {name}. Forgive the elbows. Thank you."],
		},
		asked = {
			L["Of course, {name}. My master took a year to teach me this. I'll take a moment."],
			L["One of the old legacies, {name}, handed down to me and now to you."],
			L["Nothing calms the mind like being useful, {name}. You've done me a favour."],
			L["Of course, {name}. My hands know this one by heart. I just tell them who."],
			L["At once, {name}. The fist is for foes; the open palm is for friends."],
			L["A moment, {name}. I'm mid-form, and it's bad luck to stop on the left foot."],
			L["Gladly, {name}. I was only standing still to see what it felt like."],
			L["At once, {name}. If you blinked, you missed it. That's fine; it's on you now."],
			L["Of course, {name}. It costs me a breath and a moment, and I've plenty of both."],
			L["Of course, {name}. Ask me every day, if you like. Monks love a routine."],
		},
		offer = {
			L["I passed you twice on my morning run, {name}. The third time, I stopped. Here."],
			L["Your stance says you've had a long day, {name}. Monks notice these things."],
			L["A monk gives before being asked, {name}. It saves us both the bowing."],
			L["Take this, {name}. My master said one kind act before every meal. I'm hungry."],
			L["Kindness is the hardest stance to hold, {name}. I'm practising. Here."],
			L["I practised patience by not giving you this, {name}. I lasted three heartbeats."],
			L["Be gentle out there, {name}. Unless a hozen starts it. Then be quick."],
			L["A calm mind finds the road, {name}. This should keep you steady on it."],
			L["The Last Emperor left Pandaria a legacy, {name}. I'm leaving you a small one."],
			L["For you, {name}. No lesson attached. My masters would be appalled."],
		},
		group = {
			L["Stay light on your feet, {name}. A heavy step is an easy target."],
			L["If they surround us, {name}, I'll spin. Stand back; I'm not tidy about it."],
			L["Fight from your centre, {name}. If you can't find yours, borrow mine."],
			L["If one of them freezes mid-swing, {name}, that's my doing. Leave it till last."],
			L["You go high, {name}, and I'll go low. Nobody guards both at once."],
			L["Ready, {name}? Loose shoulders, soft knees, firm intentions."],
			L["Any weapon I take off them, {name}, stays taken. They held it badly."],
			L["Leave the runners to me, {name}. Nothing outruns a monk with a grudge."],
			L["If I end a fight with one touch, {name}, don't ask how. It took me years."],
			L["Mind your temper, {name}. Anger opens a door, and the Sha walk in."],
		},
	},
	EVOKER = {
		thanks = {
			L["That was well cast, {name}. I would know. Thank you."],
			L["I have studied fire, time and the Dream, {name}. You still surprised me."],
			L["Dragons give big gifts slowly, {name}. Yours was small and quick. I prefer it."],
			L["I'll dip a wing to you when I next fly over, {name}. Watch for it."],
			L["I've known dragons with worse manners, {name}, and some of them were Aspects."],
			L["Thank you, {name}. I answer in kind, with magic older than your kingdoms."],
			L["Thank you, {name}. I'm delighted. You can tell by the faint smoke."],
			L["Generous, {name}, and not a trace of showing off. I must learn that part."],
			L["Thank you, {name}. Returned at once. My aim is perfect; my patience is not."],
			L["Thank you, {name}. I shall cite you, should I ever write a treatise on manners."],
		},
		asked = {
			L["Gladly, {name}. Help from a dragon once took a quest. Things have improved."],
			L["Hold still, {name}. Or hover, if you are able. No? Standing will do."],
			L["Watch closely, {name}. My casting is said to be a joy to watch. Mostly by me."],
			L["It would be my pleasure, {name}. Truly. I don't say 'truly' lightly."],
			L["Of course, {name}. Magic this old ought to be spent kindly, and you qualify."],
			L["Of course, {name}. Ask again tomorrow; I'll have improved it overnight."],
			L["You need only ask, {name}. I am curious how it will look on you."],
			L["Certainly, {name}. Think of something calm. Not dragons."],
			L["On the Forbidden Reach we practised on rocks, {name}. You are an improvement."],
			L["Of course, {name}. You're standing exactly where I'd have put you. Well done."],
		},
		offer = {
			L["Take this, {name}. I meant to explain the spell first. Too late now."],
			L["For you, {name}. Unasked, unearned and entirely deserved. Draconic logic."],
			L["I spotted you from afar, {name}. Evokers have sharp eyes and little restraint."],
			L["Evokers study for years to cast this well, {name}. You need only stand there."],
			L["You'll be glad of this soon, {name}. Don't ask how I know. Bronze business."],
			L["I could be flying right now, {name}, and instead I'm helping you. Do take note."],
			L["Here, {name}. Old magic, new caster. We're both doing rather well."],
			L["Not my grandest spell, {name}, but the one I'd most like to be known for."],
			L["I have read about heroes, {name}. You look like the early chapters."],
			L["Magic can't stay up in the sky, {name}. Sooner or later it lands on somebody."],
		},
		group = {
			L["If I seize you and fly, {name}, it is a rescue, not an abduction. Hold on."],
			L["I fight from a little way back, {name}. Not from caution. The view is better."],
			L["Leave their spellcasters to me, {name}. Their technique offends me."],
			L["Hold the line, {name}. I'll be the bright thing over your shoulder."],
			L["Dragons fight in three dimensions, {name}. Our enemies rarely think to look up."],
			L["I've made you all a little more than you were, {name}. The rest is up to you."],
			L["If I take a long breath, {name}, do not startle me. It is still growing."],
			L["Fight well, {name}. I am taking notes on how mortals do it. So far: loudly."],
			L["Time is on our side, {name}. I have checked with it personally."],
			L["Do try to keep up, {name}. I'm not showing off. Flying is simply quicker."],
		},
	},
	SHAMAN = {
		thanks = {
			L["Rain, fire and a rockslide this week, {name}. That was the first gentle thing."],
			L["The fifth element is spirit, {name}, and yours is a generous one. Thank you."],
			L["Thank you, {name}. The rain can wash everything off me today but that."],
			L["Earth is patient and fire is not, {name}. My thanks takes after fire."],
			L["Most days I speak for the elements, {name}. Today's thanks are my own."],
			L["Thank you, {name}. The elements answer need, not rank. So, it seems, do you."],
			L["The Earthen Ring mends the world a crack at a time, {name}. You've mended one."],
			L["Water carves canyons by never giving up, {name}. I'll repay you the same way."],
			L["Lightning is quick, {name}, but never thoughtful. You were both. Thank you."],
			L["Thank you, {name}. The ground felt steadier under me for that."],
		},
		asked = {
			L["Of course, {name}. I'll ask the sky. It rarely says no to me."],
			L["Feet on the earth, eyes on the sky, {name}. The rest is between them and me."],
			L["Gladly, {name}. Thunder takes a moment to arrive. I don't."],
			L["Gladly, {name}. A shaman who won't share the storm has no business calling it."],
			L["Of course, {name}. Lightning can be gentle. It just prefers not to be."],
			L["Of course, {name}. Let me apologise to the wind for borrowing it. There."],
			L["Gladly, {name}. Calling the wind is easy. Steering it is the trick."],
			L["We serve the elements and they serve the world, {name}. You're in it."],
			L["Gladly, {name}. Mind your hair; the air gets lively."],
			L["Of course, {name}. You'll smell of rain for an hour. Everyone I help does."],
		},
		offer = {
			L["The sky has a little fury to spare, {name}. Take some."],
			L["Take this, {name}. The storm doesn't know you yet, but I've introduced you."],
			L["A storm at your back for once, {name}, instead of in your face."],
			L["Here, {name}. I don't hand storms to just anyone. You've the shoulders for it."],
			L["Rain for the crops, storm for the fight, {name}. You look more like a fight."],
			L["Here, {name}. If you hear thunder later, it isn't weather. It's encouragement."],
			L["From four elements and one shaman, {name}. The shaman did the walking."],
			L["Walk well, {name}. The earth holds up everybody, but it likes you. I asked."],
			L["I'd give you fair weather, {name}, but the sky only lends me the stormy kind."],
			L["Here, {name}. Thank the next clean stream you drink from. It's listening."],
		},
		group = {
			L["If I fall, {name}, wait a moment. The spirits sometimes send me back."],
			L["Earth below, sky above, {name}, and us between. Let's keep that order."],
			L["If I call up an elemental, {name}, be polite. They hold grudges for an age."],
			L["Let them bunch together, {name}. Lightning loves a crowd."],
			L["When I call the storm into your blood, {name}, you'll know it. Make it count."],
			L["The wind has picked our side today, {name}. It doesn't always."],
			L["The elements favour the polite, {name}. Say something nice about the rain."],
			L["We're a small storm, {name}. Small storms still knock down fences."],
			L["Don't kick the totems, {name}. They have feelings. Well, the fire one does."],
			L["A river in the way, {name}? Don't go round. I'll have us walking on it."],
		},
	},
}

-- About the spell going out, whichever moment it is, by the entry's buff key
-- (Buffs.lua). A spell with no lines here simply has none.
RP.SPELL = {
	intellect = {
		L["A sharper mind for you, {name}. Mine cost me an eyebrow in Dalaran."],
		L["A clearer head for you, {name}. What you fill it with is your own affair."],
		L["Thoughts humming, {name}? Normal. If they hum back, come and find me."],
		L["A little arcane for your thoughts, {name}. Keep the change."],
		L["Brilliance, bottled, {name}. The Kirin Tor would charge you for the bottle."],
		-- On retail it goes to warriors and rogues too: a line for whoever.
		L["Sharper wits, {name}. Spend them on spells, locks or riddles; I won't judge."],
		L["On loan from the Violet Citadel, {name}. Late returns are fined in sheep."],
		L["Clever enough to spot the trap now, {name}. Avoiding it is a separate spell."],
		L["There, {name}. Wiser already: look, you're standing further from me."],
		L["The one spell of mine that's never set anything alight, {name}. Enjoy."],
		L["A gnome's instructions make sense now, {name}. Still don't follow them."],
	},
	fortitude = {
		L["Fortitude, {name}: a priest's polite way of saying 'stand in front'."],
		L["Every bit of stamina is one less panicked prayer from me, {name}."],
		L["Tougher already, {name}. Please don't take that as a dare."],
		L["There are other Power Words, {name}. 'Shield', and in emergencies, 'Run'."],
		L["Sturdier now, {name}. Falls, bears and bad decisions all hurt a bit less."],
		L["{buff}, {name}. Three words where 'be tougher' would do."],
		L["A little more of you to go round, {name}. Spend it slowly."],
		L["Harder to knock down now, {name}. The ground will miss you."],
		L["Stubbornness, really, {name}. Dwarves are born with it; the rest of us pray."],
		L["The only armour that never needs repairing, {name}. The smiths hate it."],
	},
	spirit = {
		L["Consider your spirits lifted, {name}. Divinely, as it happens."],
		L["Like a good night's sleep, {name}, without all the lying down."],
		L["A second helping of spirit, {name}. The Light always insists on seconds."],
		L["Keep your spirit where it is, {name}. Loose ones wander off."],
		L["Cheer up, {name}. That's not advice this time; it's a spell."],
		L["Recover faster, {name}, from long fights and longer walks."],
		L["A deep breath's worth of calm, {name}, without having to take one."],
		L["The Light's own second wind, {name}. Don't waste it on arguments."],
	},
	shadow = {
		L["Proof against shadow, {name}. I know its tricks; I've borrowed a few."],
		L["Should the Void call, {name}, you can now pretend you're out."],
		L["For when the dark gets personal, {name}. It usually does."],
		L["The shadows will have to knock first now, {name}."],
		L["The dark still bites, {name}, but now it has to chew."],
		L["A lining against the dark, {name}. Like a cloak, only on the inside."],
		L["Curses slide right off you now, {name}. The cultists will take it personally."],
		L["Priests study the Shadow to guard against it, {name}. Mostly."],
		L["For crypts, cults and Scholomance, {name}. The dark gets chatty in all three."],
		L["It won't keep off gloom, {name}. For that you want company. Here I am."],
	},
	motw = {
		L["Marked by the wild, {name}. The deer will tip their antlers as you pass."],
		L["You may smell faintly of moss, {name}. That's how you know it's working."],
		L["Mark of the Wild, {name}. The wolves will still bite, but they'll feel bad."],
		L["The wild's own seal of approval, {name}. The squirrels were consulted."],
		L["A little of the wild in you now, {name}. Resist the urge to howl."],
		L["Hide, claw and a thick coat, {name}. The wild packs light but thorough."],
		L["Cenarius signs every one of these, {name}. Well, a tree does, on his behalf."],
		L["The forest's own armour, {name}. It doesn't clank, and it smells of rain."],
		L["A tougher hide in seconds, {name}. The oaks took centuries and are furious."],
		L["It's a loan from the wild, {name}. Try not to bring it back chewed."],
	},
	thorns = {
		L["Anything that bites you now gets a mouthful, {name}."],
		L["Let the boar charge, {name}. It'll leave with regrets and splinters."],
		L["Like a rose, {name}: lovely to look at, a mistake to grab."],
		L["Thorns, {name}. I grew them myself, so do be polite to them."],
		L["A hedge you can wear, {name}. Neatly trimmed; I'm not a barbarian."],
		L["Nature never turns the other cheek, {name}. It grows spikes on it."],
		L["Raptors learn slowly, {name}. This teaches them one bite at a time."],
		L["Prickly on the outside, {name}. What's inside is your own business."],
		L["Mind your cloak, {name}. Wool and brambles never did get along."],
	},
	kings = {
		L["Blessing of Kings, {name}. No crown, no throne, no taxes owed."],
		L["Long may you reign, {name}. For the next while, anyway."],
		L["A little more of everything, {name}. Kings never did settle for less."],
		L["A king's blessing, {name}. Worn by better heads than mine, and some worse."],
		L["Every strength a little higher, {name}. Kings like to hedge their bets."],
		L["Crown not included, {name}. Everything else is, a little."],
		L["All of you, only more so, {name}. Wear it well."],
		L["A blessing fit for royalty, {name}. You'll have to do your own waving."],
		L["Stronger, cleverer, hardier, {name}. Kings had advisers for that; you have me."],
		L["Royal treatment, {name}, minus the courtiers and the poisoned wine."],
	},
	might = {
		L["Might doesn't make right, {name}, but it does help the argument."],
		L["A firmer swing for you, {name}. The Light loves a good follow-through."],
		L["Stronger arms, {name}. Kindly point them at something that deserves it."],
		L["Blessing of Might, {name}. It'll surprise you. It'll surprise them far more."],
		L["Swing away, {name}. The Light will take the credit if it goes well."],
		L["Hit harder, {name}. Them, I mean. Not me. Never the paladin."],
		L["More weight behind every swing, {name}. The Light calls it conviction."],
		L["Doors, crates and ogres will all give way easier now, {name}."],
		L["Your weapon will feel lighter, {name}. It isn't. You're just holier."],
		L["The Light's own elbow grease, {name}. Put it somewhere useful."],
	},
	wisdom = {
		L["Wisdom for you, {name}. I kept a little back for myself. Very little."],
		L["Wisdom for your mana, {name}. The other kind still comes from bad decisions."],
		L["Your mana creeps back on its own now, {name}, like a cat that's forgiven you."],
		L["Fewer sips between fights, {name}. The innkeepers will be heartbroken."],
		L["Drink less, cast more, {name}. The Light's own budget advice."],
		L["Blessing of Wisdom, {name}: the one blessing that pays for itself."],
		L["A steadier well to draw from, {name}. Draw deep."],
		L["Wisdom usually comes with age, {name}. This comes with a paladin. Quicker."],
		L["May you know when to fight and when to sit down, {name}."],
		L["A wise blessing for a wise choice, {name}: keeping a paladin around."],
	},
	salvation = {
		L["A blessing of quiet, {name}. Monsters will forget whose fault it was."],
		L["Blessing of Salvation, {name}. You are now somebody else's problem."],
		L["Saved, {name}. Not your soul, mind. Just your hide."],
		L["Hit hard, {name}. If anything turns round, look innocent. The Light will."],
		L["The monsters will find you forgettable now, {name}. Today, that's a compliment."],
		L["Go on, hit it, {name}. It'll blame whoever's wearing the most plate."],
		L["The art of being in the fight, {name}, and out of the argument."],
		L["The Light's kindest alibi, {name}. Use it often."],
	},
	light = {
		L["The Light will find you easier now, {name}. Try not to squint."],
		L["Holy Light lands harder on you now, {name}. Please don't make me prove it."],
		L["You'll heal easier, {name}. The Light appreciates a willing patient."],
		L["Blessing of Light, {name}. Saving you is simpler now. Not that you'll need it."],
		L["The Light knows the way to you now, {name}. Let's keep its visits social."],
		L["A blessing that makes my job easier, {name}. Generous and lazy all at once."],
		L["Holy Light fits you better now, {name}, like a well-cut tabard."],
		L["Mending you just got cheaper, {name}. Not that I'd ever send a bill."],
	},
	sanctuary = {
		L["Block a blow now, {name}, and the Light hits back for you. It's petty."],
		L["Every blow lands softer now, {name}. Complaints go to the Light."],
		L["All the shelter of a temple, {name}, and none of the roof repairs."],
		L["Claim sanctuary, {name}. It's easier when you bring your own."],
		L["Every blow is a little less rude now, {name}. The Light teaches manners."],
		L["Nobody can evict you from this sanctuary, {name}. I checked the deeds."],
		L["An ogre's club lands like a pillow now, {name}. A heavy, angry pillow."],
	},
	battleshout = {
		L["Instructions, {name}: hit things harder. There is no page two."],
		L["Your sword arm is sorted, {name}. For the rest of you, see a priest."],
		L["Battle Shout, {name}. Not a spell, really. A strongly worded suggestion."],
		L["RAAAGH! That one was for you, {name}. Everyone else just overheard."],
		L["Priests pray, mages study, {name}. I clear my throat."],
		L["Words matter, {name}. Mostly the loud ones."],
		L["The shout lasts a few minutes, {name}. The ringing in your ears, rather longer."],
		L["There were words in that shout once, {name}. They slowed it down."],
	},
	breath = {
		L["A little breath from the damned, {name}. They weren't using it."],
		L["Unending Breath, {name}. The fish will have so many questions."],
		L["Stay down as long as you like, {name}. The air's on me."],
		L["Swim deep, {name}. If a murloc asks, you're only visiting."],
		L["Air from a place where air isn't strictly air, {name}. Breathe it anyway."],
		L["The Vile Reef awaits, {name}. Try not to find out how it earned the name."],
		L["Dropped something in a lake, {name}? Now's your chance."],
		L["No gills, {name}. I read the small print; gills were extra."],
	},
	commandingshout = {
		L["An order, {name}: stay standing. Your bones heard it, even if you didn't."],
		L["Grit is a habit, {name}. I've lent you a few years of mine."],
		L["I command, you endure, {name}. The shortest chain of command in any army."],
		L["Officers give orders from the back, {name}. Mine come from the front, loudly."],
		L["A good shout can hold a line together, {name}. A line of one is easy."],
		L["I learned this drilling recruits, {name}. They hated me, and they all lived."],
		L["One shout's for hitting, {name}. This one's for being hit and not minding."],
		L["Most fights go to whoever lasts longest, {name}. Today, that's you."],
	},
	hornofwinter = {
		L["This horn once sounded for a worse master, {name}. It much prefers you."],
		L["I can't runeforge your weapon, {name}, but the horn comes close."],
		L["All Northrend's cold in a single note, {name}. Swing while it's still ringing."],
		L["I'd play something cheerful, {name}, but this horn only knows the one note."],
		L["Winter took me once, {name}. Now it comes when I call."],
		L["The Ebon Blade charges when this sounds, {name}. Today you charge with us."],
		L["Cold enough to wake the dead, {name}. I would know."],
		L["No warm words from me, {name}. Cold ones carry further."],
	},
	emperor = {
		L["Shaohao cast out his doubt and fear, {name}. What he kept, I pass to you."],
		L["Shoulders down and jaw loose, {name}. Now it can settle in properly."],
		L["An open palm for friends, {name}. The fist is kept for everyone else."],
		L["I swept temple steps for a year to learn this, {name}. The steps stayed dusty."],
		L["Strength, grace and a clear head, {name}. Pandaria's emperors had all three."],
		L["A gift from a land that hid in the mists, {name}. Use it out in the open."],
		L["Harmony is hard to find, {name}. Hold on to this bit of it."],
		L["Nothing in it you didn't have already, {name}. I've only woken it up."],
	},
	whitetiger = {
		L["Strength is better shown than talked about, {name}. So I'll say no more."],
		L["Strike where the guard is thin, {name}. The Tiger's eyes will show you where."],
		L["Xuen never strikes by halves, {name}. Now neither do you."],
		L["You don't get the stripes, {name}. Only the nerve that goes with them."],
		L["I trained in Kun-Lai's snow for this, {name}. Your feet stay warm, at least."],
		L["The Tiger's blessing isn't gentle, {name}, but it's on your side."],
		L["Fierce, not angry, {name}. Xuen taught me the difference. Now it's yours."],
		L["Wait, watch, then pounce, {name}. Tigers rarely need a second try."],
	},
	darkintent = {
		L["Dark Intent, {name}. A grim name for a kind act. Warlocks name things badly."],
		L["Thank the demon who taught me this, {name}. On second thoughts, don't."],
		L["You'll feel no different, {name}. Your enemies will. That's rather the point."],
		L["A little fel, well filtered, {name}. You'll barely smell the sulphur."],
		L["A spark of the Nether rides with you now, {name}. I've trained it to sit."],
		L["Don't feel guilty about the power, {name}. I've done the guilty part already."],
		L["Darkness suits you, {name}. I mean that kindly."],
		L["I'd wish you luck, {name}, but warlocks prefer to arrange it."],
	},
	skyfury = {
		L["The sky lends you its temper, {name}. Strike once, and the storm follows it in."],
		L["The earth keeps you steady, {name}. Now the sky wants a turn."],
		L["The storm rides with you now, {name}. Do warn it before you go indoors."],
		L["If your hair stands on end, {name}, that's the storm agreeing with me."],
		L["I asked the sky to stand behind you, {name}. It's very tall and easily annoyed."],
		L["Lightning never strikes twice, they say, {name}. They've never met a shaman."],
		L["I listen to the wind, {name}. Today it only wanted to talk about you."],
		L["Thunder in your arms, {name}. Let the next fool who blocks your way hear it."],
	},
	bronze = {
		L["A few borrowed moments from the bronze, {name}. Nozdormu keeps careful count."],
		L["Time won't wait for you, {name}, but for the next while it'll dawdle."],
		L["Not all help arrives in time, {name}. This kind brings its own."],
		L["Should you need to slip away, {name}, time will cover for you."],
		L["Bronze magic, {name}. You'll arrive a breath before you're needed."],
		L["Time is a river, {name}. I've found you a quicker current."],
		L["Time heals all wounds, {name}. I'd rather it helped you dodge them."],
		L["The bronze say I learned this tomorrow, {name}. I've stopped arguing with them."],
	},
	sourceofmagic = {
		L["My spare magic is yours now, {name}. Every spell I overcharge spills your way."],
		L["Only one of you gets this, {name}. I chose. Try to look modest about it."],
		L["I'd give you my patience as well, {name}, but I've barely enough for me."],
		L["We're linked for the hour, {name}. Don't worry, it only runs one way."],
		L["I've seen how hard you work, {name}. Let me carry a little of it."],
		L["My magic runs hot, {name}. By the time it reaches you, it's cooled nicely."],
		L["Cast freely, {name}. Your mana is partly my concern now."],
		L["If you run dry, {name}, it means I've been idle. Do say so."],
	},
}

-- Thanks only, and only when the spell they gave you is known: {gift} is
-- theirs, {buff} is yours. Left out when the two are the same spell.
RP.TRADE = {
	L["Folk will think we're duelling, {name}. Thanks for the {gift}."],
	L["{gift} for {buff}. No auctioneer's cut, {name}."],
	L["Beaten to it, {name}! Your {gift} was quicker than my manners."],
	L["{gift} in, {buff} out. Finest economy in all Azeroth."],
	L["{gift}, for me? All I have is this, {name}, but it's heartfelt."],
	L["Your {gift} fits perfectly, {name}. Did you measure me?"],
	L["A treaty in spells, {name}: {gift} for {buff}."],
	L["{gift}! I feel taller already. Have some {buff}."],
	L["I was about to ask for {gift}, {name}. You read my mind."],
	L["Your {gift} still fizzes, {name}. Here's some fizz back."],
	L["Such a kind {gift}, {name}. I'll tell the whole inn. Twice."],
	L["You cast {gift} first, {name}? My mother would despair of me."],
	L["I'll remember your {gift} fondly, {name}. Until it wears off."],
	L["{gift} for {buff}, free. Somewhere, a goblin weeps."],
	L["Your {gift}, my {buff}. We'll be unbearable now."],
	L["Thanks for the {gift}, {name}. I'll earn it before it fades."],
	L["For {gift} I'd hand you both moons, {name}. This'll have to do."],
	L["You brought {gift}, I brought {buff}. Now it's a party."],
	L["{gift} means 'good luck'. {buff} means 'you too'."],
	L["Your {gift} came first; my {buff} tries twice as hard."],
	L["If anyone asks, {buff} came before {gift}. Deal?"],
	L["{gift} made my day; {buff} should make your hour."],
	L["Saved my {buff} for someone worthy. Then came {gift}."],
	L["Your {gift} went to my head; my {buff} goes to yours."],
	L["{gift} on me, {buff} on you. We wear each other's work."],
	L["{gift} and {buff} fade. Kindness lasts. Well, longer."],
	L["You shared {gift}; I share {buff}. Ale's next."],
	L["{gift} caught me empty-handed. Not any more: {buff}."],
	L["{gift}, best thing all day. {buff}, my bid for second."],
	L["{gift} deserves a statue. I'm no sculptor, so: {buff}."],
	L["{gift} for {buff}? Keep this up and we'll draw a queue."],
	L["{gift} was kind. {buff} is kind back, and competitive."],
	L["{gift} came like good news. {buff}, by return post."],
	L["{gift}, meet {buff}. Do get along, you two."],
	L["Trade you {buff} for {gift}? Ah, you've already paid."],
	L["{gift} and {buff}. The inn will say we rehearsed."],
}

-- Thanks only, like RP.TRADE, and about what the spell they gave you does
-- rather than its name: Arcane Intellect makes you clever, Thorns prickly, a
-- shout loud. By that spell's buff key (Buffs.lua), found from the debt's
-- spell id; heard next to the trade lines and more often than them, since
-- what a spell does is the part of the moment only this favour has. The
-- trade lines stay the most varied, and the same priest will give you
-- Fortitude all evening.
RP.GIFT = {
	intellect = {
		L["{gift}! I just had three clever thoughts, {name}. This was one."],
		L["With {gift}, {name}, I finally understand my own notes. Thanks."],
		L["Cleverer already, {name}. Clever enough to know I owe you one. Here."],
		L["Your {gift} found me the word for this, {name}: 'thanks'."],
		L["{gift}! I understood a goblin contract, {name}. I'm appalled."],
		L["Thank you, {name}. My thoughts are lining up politely."],
		L["I'll use your {gift} for more than arguing, {name}. Probably."],
		L["Thank you, {name}. My next spell gets three extra syllables, just to show off."],
	},
	fortitude = {
		L["{gift}, {name}? I'll stand at the front for once. Briefly."],
		L["Knees, elbows and pride, {name}: all fortified. Thank you."],
		L["Hit me now, {name}. Actually, don't. But thank you; I'd survive it."],
		L["Nigh unbreakable now, {name}. Let's never test the 'nigh'. Thank you."],
		L["{gift}! My healer owes you a letter, {name}. I owe you this."],
		L["Every bruise I don't get today, {name}, I owe to your {gift}."],
		L["I could lose an argument with an ogre now and live, {name}. Thank you."],
		L["Thank you, {name}. I feel like a castle wall. A grateful one."],
		L["Thank you, {name}. The next boar to charge me is in for a long afternoon."],
	},
	spirit = {
		L["{gift}! I feel ten years younger, {name}. Thank you."],
		L["I feel twice as calm and half as grumpy, {name}. Thank you."],
		L["Your {gift} nearly made me sing, {name}. Take this. It's kinder."],
		L["{gift}, {name}? I've forgiven three people already. Thank you."],
		L["I was on fumes, {name}. Your {gift} was a hot meal and a hearth."],
		L["I've stopped counting mana between fights, {name}. Thank you."],
		L["My spirit's topped up, {name}, and the rest of me is grateful too."],
	},
	shadow = {
		L["Shadow-proof, thanks to you, {name}. The whispers are furious."],
		L["Nothing dark gets in now, {name}. Here's something bright going the other way."],
		L["{gift}! Shadowfang Keep can keep its shadows, {name}. Thank you."],
		L["The next shadow bolt's in for a letdown, {name}. Thank you."],
		L["On your {gift} I'll brave Duskwood tonight, {name}. Or tomorrow."],
	},
	motw = {
		L["{gift}! A squirrel just nodded at me, {name}. Here's yours."],
		L["Tougher hide, sharper senses, {name}. I may have to fight the urge to forage."],
		L["I feel all wild and leafy, {name}. Thank you. Sorry if I shed bark."],
		L["Thicker skin from your {gift}, {name}. Arrows and insults both."],
		L["{gift}! A bird tried to nest on me, {name}. Thanks, I think."],
		L["Thanks for the {gift}, {name}. The woods feel like home now."],
		L["Thank you, {name}. I've an urge to stand in the rain and grow. I'll resist."],
		L["Every bramble in the Barrens will think twice now, {name}. Thank you."],
		L["Thank you, {name}. Rain, cold and wolves: let them all try."],
	},
	thorns = {
		L["{gift}, {name}! Nobody's hugging me today. Have this instead."],
		L["Prickly now, thanks to you, {name}. More than usual, I mean."],
		L["Your {gift}, {name}! Let the next kobold try for my candle."],
		L["{gift}! I'm a thicket with opinions now, {name}. Thank you."],
		L["Thank you, {name}. The next thing that bites me will need a moment to reflect."],
	},
	kings = {
		L["{gift} from you, {name}? I'll try not to found a dynasty."],
		L["A little better at everything, {name}. Is this how kings feel? No wonder."],
		L["Your {gift}! My first decree, {name}: thank you."],
		L["{gift} on a commoner, {name}? I'll try to look regal."],
		L["With your {gift} I could rule a small kingdom, {name}. Westfall."],
		L["Thank you, {name}. Every bit of me is grateful, and they rarely agree."],
	},
	might = {
		L["Stronger arms already, {name}. I'll try not to hug anyone. Thank you."],
		L["With {gift} I could lift a kodo, {name}. I won't, but thank you."],
		L["Your {gift} has my arms very confident, {name}. Thank you."],
		L["{gift}! Opened a jar I've fought since Stranglethorn, {name}."],
		L["Thank you, {name}. My next swing is dedicated to you. So is the dent."],
	},
	wisdom = {
		L["{gift} from you, {name}, and my first wise act is this."],
		L["Wiser already, {name}. Wise enough to know a kindness when I see one."],
		L["My mana thanks you for {gift}, {name}. It's the shy one of us."],
		L["Your {gift} refills me faster than I spend, {name}. Nearly."],
		L["Your {gift}, {name}: mana back, and an urge to give advice."],
	},
	salvation = {
		L["{gift}! The monsters forgot me at once, {name}. I won't."],
		L["Nothing wants to fight me now, {name}. It's lovely. Thank you."],
		L["{gift}! Nothing's glared at me in minutes, {name}. Thank you."],
		L["{gift}! A mouse at a dragon's feast, {name}: unseen, well fed."],
		L["Thanks to {gift} I'm just a rumour in a fight, {name}."],
	},
	light = {
		L["The Light finds me easier now, {name}. I'll try to deserve it."],
		L["Easier to heal now, {name}. Whoever patches me up thanks you too."],
		L["With your {gift}, {name}, mending feels like coming home."],
		L["{gift}! The Light and I are on first-name terms now, {name}."],
		L["With {gift} the Light hears me first, {name}. No need to shout."],
	},
	sanctuary = {
		L["Blows land softer on me now, {name}. My bruises thank you, and so do I."],
		L["Every hit gentler, thanks to you, {name}. I'll make sure they notice."],
		L["Your {gift} softens every blow, {name}. I'm upholstered."],
		L["{gift}! Now the Light takes every hit personally, {name}."],
		L["With your {gift} I'm half fortress, half chapel, {name}."],
	},
	battleshout = {
		L["You shouted at me, {name}, and I've never felt so encouraged. Here."],
		L["My ears are ringing, {name}, and my arms feel twice as strong. Thank you!"],
		L["{gift}, {name}! I felt that in my teeth. In a good way."],
		L["I'll answer your {gift} quietly, {name}. Somebody should."],
		L["Your {gift} nearly had me charging a wall, {name}. Here, calmly."],
		L["All Azeroth heard your {gift}, {name}. Thank you for my share."],
		L["That shout put iron in my spine, {name}. Thank you."],
		L["I didn't catch the words, {name}, but my arms did. Thank you!"],
		L["Thank you, {name}. I'll hit the next thing twice as hard and blame you."],
	},
	breath = {
		L["I can breathe underwater, {name}! I may never need to, but thank you."],
		L["Lungs like a murloc, thanks to you, {name}. I'll try not to gurgle."],
		L["With {gift} I'll raid every sunken wreck, {name}. Half's yours."],
		L["I won't ask where {gift} gets its air, {name}. Just: thanks."],
		L["With {gift} I'll cross Lordamere Lake, {name}. Underneath."],
	},
	-- The favours Manners never offers (Buffs.lua, favourOnly), which are in
	-- no buff: RP.GiftKey finds these by the spell's own id.
	soulstone = {
		L["If I fall, {name}, I'll be back to thank you properly."],
		L["A spare life in my pocket, {name}. I'll try not to spend it. Thank you."],
		L["Thank you, {name}. Death can knock now; I've a key to the back door."],
		L["Dying's only a delay with your {gift}, {name}. Thank you."],
		L["Thank you, {name}. If the worst happens, I'll get up and say it twice."],
	},
	fearward = {
		L["Let the next thing roar at me, {name}. I'm not running this time. Thank you."],
		L["{gift}! One fright, already dealt with, {name}. Thank you."],
		L["Thank you, {name}. The next scream I hear won't be mine."],
		L["No running in circles for me, {name}. Not the first time, anyway. Thank you."],
		L["Brave on credit, thanks to you, {name}. I'll spend it wisely."],
	},
	waterwalking = {
		L["Thank you, {name}. Lakes, rivers, puddles: all floors now."],
		L["{gift}! The short way across it is, {name}. Dry boots and all."],
		L["Walking on water, {name}. Folk will start a religion. Thank you."],
		L["The murlocs will be furious, {name}. Thank you for the shortcut."],
		L["Thank you, {name}. I'll be across before it fades. Probably."],
	},
	detectinvis = {
		L["{gift}! Whatever hid round here, {name}, hides no more."],
		L["I can see what's hiding now, {name}. Some of it should stay hidden. Thanks."],
		L["Thank you, {name}. Every lurker around just lost their only trick."],
		L["Thank you, {name}. Now I can see what your imp gets up to."],
		L["My eyes see more than my wits can handle, {name}. Thank you."],
	},
	commandingshout = {
		L["I'll be the last one standing, {name}, just to hear you shout again."],
		L["You ordered me to live, {name}. I mean to follow it to the letter. Thanks."],
		L["Thank you, {name}. Every sinew I have just closed ranks."],
		L["Never been shouted into good health before, {name}. Thank you."],
		L["Yes, Sergeant {name}! Your shout brings out the recruit in me. Thank you."],
		L["{gift}! That voice could turn a stampede, {name}. Thanks."],
	},
	hornofwinter = {
		L["That horn froze my breath and fired my arms, {name}. Thank you."],
		L["Most folk hear that horn from the wrong end of a battle, {name}. Thank you."],
		L["I heard your horn and swung harder, {name}. Nobody had to tell me twice."],
		L["Thank you, {name}. I'll be humming that note for the rest of the day."],
		L["Thanks to you, {name}, I'll never grumble about winter again."],
		L["{gift}! I won't ask what the horn's made of, {name}. Thank you."],
	},
	emperor = {
		L["An emperor's legacy, {name}. I'll try to leave it no worse than I found it."],
		L["Like a month of training before breakfast, {name}. Thank you."],
		L["Thank you, {name}. I feel calm enough to brew tea in a thunderstorm."],
		L["Thank you, {name}. I bowed without thinking. Is that part of it?"],
		L["{gift}! Pandaria's finest, {name}. Don't tell the brewmasters."],
		L["Stronger, quicker and steadier at once, {name}. My teachers never managed that."],
	},
	whitetiger = {
		L["{gift}, {name}! Even my mistakes will look deliberate now."],
		L["I feel a tiger pacing in my chest, {name}. It wants to hunt. Thank you."],
		L["Thank you, {name}. I'll be very polite to cats from now on."],
		L["I could out-stare a tiger now, {name}. Not Xuen. A small one."],
		L["Every strike I throw now has claws in it, {name}. Thank you."],
		L["I'd thank Xuen as well, {name}, but he answers thanks with a sparring match."],
	},
	darkintent = {
		L["{gift}! I feel sharper and slightly sinister, {name}. Thanks."],
		L["Dark but generous, {name}, like a good stout. Thank you."],
		L["Thank you, {name}. If I start cackling in a fight, you'll know why."],
		L["Bound to a warlock for the hour, {name}. My family would faint. Thank you."],
		L["Like borrowing a sharp knife from a stranger in an alley, {name}. Thanks."],
		L["More dangerous today and worse sleep tonight, {name}. A fair trade. Thanks."],
	},
	skyfury = {
		L["Thank you, {name}. Now I know why shamans always look so windswept."],
		L["{gift}! Swift as the wind, {name}, and as hard to argue with."],
		L["Your {gift} has me crackling, {name}. Shake hands carefully."],
		L["My weapon keeps hitting things twice, {name}. Thank you, and thank the storm."],
		L["The sky's on my side now, {name}. I'll try not to stand on any hilltops."],
		L["I'm half thunderstorm now, {name}. Thank you, and sorry about the rain."],
	},
	bronze = {
		L["{gift}! A step ahead of everything, {name}, myself included."],
		L["Thank you, {name}. I'll be out of trouble before trouble notices."],
		L["Thank you, {name}. I can feel the sands shifting in my favour."],
		L["Thank you, {name}. Even my running away will look dignified now."],
		L["Haven't I thanked you already, {name}? Time's gone odd. Thanks again."],
		L["Thank you, {name}. Nozdormu won't miss the moments; he has all of them."],
	},
	sourceofmagic = {
		L["Thank you, {name}. Your magic and mine get on surprisingly well."],
		L["Of everyone here, {name}, you chose me? I'm flattered and refreshed."],
		L["{gift}! I'll be the last one here to run dry, {name}. Thank you."],
		L["I could cast till sundown now, {name}. Please keep breathing fire."],
		L["Thank you, {name}. Everyone I help today owes you a little too."],
		L["Your leftovers beat my best, {name}. Most humbling. Thank you."],
	},
}

-- How often the two of you have traded this session (RP.Familiar): "again"
-- for the second or third time, "regular" for the fourth and on.
RP.HISTORY = {
	again = {
		L["We have to stop meeting like this, {name}. Actually, no, we don't."],
		L["Again, {name}? Splendid. I've been practising since last time."],
		L["You again, {name}? People will start saying we're friends."],
		L["Same face, same spell, {name}. I do love a tradition."],
		L["Another round, {name}? I'm keeping score, and we're both winning."],
		L["Ah, {name}! My favourite repeat customer."],
		L["Our paths keep crossing, {name}. I think the road is dropping hints."],
		L["Once more, {name}. Do stop me if you've heard this one."],
		L["I kept some aside, {name}, in case you came back. Good instinct, mine."],
		L["Back already, {name}? The day's improving."],
		L["Again, {name}? At this rate I'll have to learn your middle name."],
		L["Once is kindness, twice is a habit, {name}. I've never broken a habit yet."],
		L["An encore, {name}, for my most faithful audience."],
		L["One more of these, {name}, and we'll have to draw up a guild charter."],
		L["I'll remember your face now, {name}, and I'm terrible with faces."],
		L["Us again, {name}. The world must be running out of other people."],
		L["Last time went so well, {name}, I've changed nothing."],
		L["Good to see someone I know, {name}. They're rarer than you'd think."],
		L["Oh, it's you, {name}. Good. I hate giving these to strangers."],
	},
	regular = {
		L["{name}, at this point we should just share a reagent pouch."],
		L["Same time tomorrow, {name}? I'll bring {buff}. You bring you."],
		L["I've lost count, {name}, and I've decided that's a compliment."],
		L["Keep this up, {name}, and the bards will write a very dull song about us."],
		L["I could do this one in my sleep by now, {name}. I may have."],
		L["The usual, {name}? Of course the usual."],
		L["We ought to have a secret handshake by now, {name}. Next time, perhaps."],
		L["By now, {name}, I think we've built a small economy between us."],
		L["Old friends by now, {name}. Well, old acquaintances with excellent timing."],
		L["Let the record show: {name} and I, undefeated at being prepared."],
		L["My spellbook opens to your page on its own now, {name}."],
		L["If you stopped turning up, {name}, I'd report you missing to the guards."],
		L["We keep this up, {name}, and one of us owes the other a drink."],
		L["We're a local landmark now, {name}. Travellers give directions by us."],
		L["Regular as the tides, {name}, and twice as welcome."],
		L["I'd trust you with my last potion, {name}. That's saying something."],
		L["Next time, {name}, we share a fire and you tell me where you're bound."],
		L["I'd miss this if it stopped, {name}. So let's not stop."],
		L["There's nobody I'd rather keep running into, {name}."],
		L["You always turn up at the right moment, {name}."],
	},
}

-- Where this is (RP.Place): "city" is resting, in a city or an inn; "wild" is
-- outdoors; "instance" is a dungeon or a raid; "battle" is a battleground or
-- an arena, where the lines keep to pride and say nothing of the other side.
-- A scenario is none of them. A people's own city has its own lines
-- (RP.RACE's "city"), said there in place of these.
RP.PLACE = {
	city = {
		L["Safe walls, warm beds, and now {buff}. You're spoiled, {name}."],
		L["The guards have it covered, {name}, but I like to be thorough."],
		L["Careful, {name}. Look this capable in town and folk will ask you favours."],
		L["Not a monster for miles, {name}. Still, one never knows about the cooking."],
		L["For the crowds, {name}. In town, they're the real danger."],
		L["Rest easy, {name}. I'll count that my good deed and go find a pint."],
		L["Even in town, {name}, a dragon has been known to drop in. Better safe."],
		L["Best do it in here, {name}. Out there, nobody stands still long enough."],
		L["Mind the pickpockets, {name}. This is the one thing on you they can't lift."],
		L["City rules, {name}: no blades drawn, no spells thrown. This one's allowed."],
		L["Nothing to fight here but stray cats, {name}. Take this anyway."],
		L["For the walk to the bank, {name}. It's always further than it looks."],
		L["Enjoy a warm hearth while you can, {name}. The road's never far."],
		L["The watch has the walls, {name}. I'll see to you."],
		L["For the stairs, {name}. Whoever built this place never met a short way up."],
		L["Everything else in town has a price, {name}. This slipped past the merchants."],
		L["Buy nothing from anyone who calls you 'friend', {name}. Except me."],
	},
	wild = {
		L["Out here everything wants to eat you, {name}. Now it'll need a bigger fork."],
		L["No guards for miles, {name}, and the boars know it. Take this."],
		L["Nobody out here but us and the wildlife, {name}. Let's be the tougher half."],
		L["If a bear asks, {name}, you were like this when I found you."],
		L["The wolves have been eyeing you, {name}. This should give them pause."],
		L["Wild country, {name}. Best not to meet it armed with good intentions alone."],
		L["Map, canteen, {buff}. Now you can get lost properly, {name}."],
		L["Camp's a long way off, {name}. Consider this a roof you can carry."],
		L["Out past the last farm, {name}, you're on your own. Nearly."],
		L["Nearest inn's a day's walk, {name}. The nearest thing with teeth is closer."],
		L["Two hills and a swamp to the next town, {name}. The swamp has opinions."],
		L["Camp carefully, {name}. Every nice clearing has an owner, and it has claws."],
		L["Fresh air, open sky, {name}. Enjoy it while nothing's chasing you."],
		L["Something's following you, {name}. Probably a boar. This is in case it isn't."],
		L["Stay on the road, {name}. The road has guards. Some of the time."],
		L["Rain's coming, {name}, and so are the wolves. One of those I can help with."],
	},
	instance = {
		L["Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt."],
		L["Whatever waits at the end of this place, {name}, let's make it regret it."],
		L["They say nobody leaves here alive, {name}. Let's be rude and prove them wrong."],
		L["Our host had years to prepare, {name}. We have {buff}."],
		L["Nobody builds a dungeon with a back door, {name}. Take this instead."],
		L["Dark halls, old traps, worse tempers. At least you're ready, {name}."],
		L["Better I hand you this now, {name}, than a eulogy later."],
		L["There's treasure in here, {name}, and something very large sat on it."],
		L["If a door slams shut behind us, {name}, that's tradition. Take this first."],
		L["Mind the patrols, {name}. They walk the same loop forever and resent it."],
		L["Whoever built this place, {name}, spent it all on skulls and nothing on lamps."],
		L["The last lot through here were never seen again, {name}. They lacked this."],
		L["Check the ceiling, {name}. In places like this, something always drops in."],
		L["If we meet a talking skull, {name}, let me do the talking."],
		L["If the walls start whispering, {name}, don't answer. It only encourages them."],
		L["Touch nothing that glows, pull nothing that clicks, {name}. Wear this."],
		L["Stick together in here, {name}. Echoes carry, and so do grudges."],
	},
	battle = {
		L["Flags, towers, graveyards, {name}. Whatever we're fighting over, take this."],
		L["Win or lose, {name}, nobody will say you went in unprepared."],
		L["The graveyard's just over there, {name}. Let's both not visit it."],
		L["Honour's on the line, {name}. So is the flag. Mostly the flag."],
		L["Stay with the group, {name}. Lone heroes make short songs."],
		L["Our banner looks better with you under it, {name}. Stand tall."],
		L["Keep your head down and your colours up, {name}."],
		L["Hold the line, {name}. The songs are always about the ones who stood."],
		L["Come back in one piece, {name}. That's all I ask."],
		L["Drums are for courage, {name}. This is for everything else."],
		L["Some fight for glory, {name}. I fight for whoever's beside me."],
		L["Fight for the banner, {name}, but come back for the singing. Mine's dreadful."],
	},
}

-- The hour on the realm's clock (RP.Hour): "morning" from five until eleven,
-- "night" from ten at night until five. Anybody's; a people whose hour it is
-- has its own lines as well (RP.RACE's "night" and "morning").
RP.TIME = {
	morning = {
		L["Early bird, {name}? Here's something better than a worm."],
		L["Good morning, {name}. Consider this your first cup of something strong."],
		L["Early start, {name}. The day hasn't had a chance to go wrong yet."],
		L["Not even lunch yet, {name}, and you're already better prepared than I am."],
		L["Morning, {name}. Somewhere, the monsters are still yawning."],
		L["A fresh day and a fresh {buff}, {name}. Let's not waste either."],
		L["Up with the sun, {name}? Show-off. Here; the sun doesn't get one."],
		L["Rise and shine, {name}. The shining can wait till after breakfast."],
		L["Everything's golden and nobody's shouted yet, {name}. Let's enjoy it."],
		L["Too early for heroics, {name}? Nonsense. Heroics go best before lunch."],
		L["The birds are singing, {name}. They haven't seen what's out there yet."],
		L["First good deed of the day, {name}. It's all downhill from here."],
		L["Still yawning, {name}? This works faster than tea."],
		L["Early, {name}. The dawn patrol looks at us like we've lost our minds."],
	},
	night = {
		L["Out this late, {name}? The night is hungrier than the day. Take this."],
		L["Past bedtime, {name}. The sensible folk are asleep, which leaves us."],
		L["Can't sleep either, {name}? Then we may as well be useful."],
		L["Mind the dark, {name}. Not everything out there is as friendly as I am."],
		L["It's late, {name}. This should keep you going till the sun remembers us."],
		L["Only the owls and us awake, {name}, and the owls get no {buff}."],
		L["The inns have locked up, {name}. This is the only thing still being served."],
		L["It's the hour for ghost stories, {name}. Take this, in case one is true."],
		L["Candles low, stars high, {name}. A good hour for small kindnesses."],
		L["Quiet hour, {name}. Every creak sounds like an ambush. Most of them aren't."],
		L["This late, {name}, even the guards are talking to themselves."],
		L["This is the hour things climb out of graves, {name}. Take this; walk briskly."],
		L["Tomorrow you'll wonder why you stayed up, {name}. This is one good reason."],
	},
}

-- The class of the person being helped (RP.Target): "sameclass" when it is
-- the speaker's own, or their class token otherwise. Gentle, and never at
-- their expense: the joke is on the help, the speaker or the world. Two of the
-- same class hear RP.SAME for that class, and these "sameclass" lines when it
-- has none.
RP.TARGET = {
	sameclass = {
		L["Takes one to know one, {name}. Takes one to do it properly, too."],
		L["From one of our trade to another, {name}. No need to check my work."],
		L["Professional courtesy, {name}. We don't charge each other."],
		L["Two of a kind, {name}. Between us we could write the manual."],
		L["Don't look so surprised, {name}. Same trainer, I expect."],
		L["I'd critique your technique, {name}, but mine looks exactly the same."],
		L["Don't tell the others, {name}, but ours really is the finest calling."],
		L["Look at us, {name}. Two experts, making it look easy. It isn't, is it?"],
		L["Between colleagues, {name}: I also have no idea how half of it works."],
		L["We walked the same road to get here, {name}. Good to meet another on it."],
		L["If anyone asks, {name}, we trained each other."],
		L["Calling to calling, {name}. We should compare notes some time."],
		L["Colleague, {name}. We look after our own."],
		L["Good to see the old craft in steady hands, {name}."],
	},
	WARRIOR = {
		L["I'd shout some encouragement, {name}, but you do that far better."],
		L["Charge in as usual, {name}. I'll simply feel better about it now."],
		L["For the one who goes in first, {name}. Somebody has to, and it's never me."],
		L["You take the hits so the rest of us don't, {name}. It's the least I can do."],
		L["Go on, {name}, charge. I'll be right behind you."],
		L["For the one who fixes every problem by hitting it, {name}. It usually works."],
		L["I'd shake your hand, {name}, but both of yours are holding something sharp."],
		L["A little help for a lot of armour, {name}. I hope it fits under there."],
		L["You'll charge something enormous soon, {name}. I'm just helping it lose."],
	},
	PALADIN = {
		L["Save your Light for later, {name}. This one's from me."],
		L["You bless everyone else all day, {name}. Here's one going the other way."],
		L["The Light already favours you, {name}. Here's a little more of it."],
		L["Even the Light's own champion needs a hand now and then, {name}."],
		L["I'd ask for a blessing back, {name}, but then we'd be here all day."],
		L["For the one who carries a hammer and a conscience, {name}. Heavy load."],
		L["Don't thank the Light for this one, {name}. This was me."],
		L["No need to kneel, {name}. I know it's a habit."],
	},
	HUNTER = {
		L["One for you, {name}, and a pat on the head for your companion."],
		L["You watch everyone's back from range, {name}. I've got yours."],
		L["Hunter's Mark for them, {buff} for you, {name}. Much nicer."],
		L["Aim true, {name}. And if it charges you anyway, run towards the rest of us."],
		L["Keen eye, steady hand, {name}. Here's something for the long hunt."],
		L["Nothing for the pet this time, {name}. It's already had three of my sandwiches."],
		L["I'd have brought arrows, {name}, but I never know which kind you like."],
		L["You can track anything, {name}, but you never saw this one coming."],
	},
	ROGUE = {
		L["Quick hands, quiet feet, {name}. Here's luck to go with them."],
		L["Quick, {name}, before you vanish again."],
		L["Poison on the blades, {buff} on you. Very thorough, {name}."],
		L["I'd slip it in your pocket, {name}, but you'd notice. You always notice."],
		L["For the one who opens every locked box, {name}. This one comes unlocked."],
		L["Nobody sees you coming, {name}. Now it's even worse news when they do."],
		L["Take this, {name}. Very discreet. It even walks quietly."],
		L["I'd have wrapped it, {name}, but you'd only pick the knot."],
		L["Keep this one, {name}. You don't even have to steal it."],
	},
	PRIEST = {
		L["For once, {name}, somebody's looking after the priest."],
		L["Save your prayers for the rest of us, {name}. This one's already answered."],
		L["Light or Shadow, {name}, I don't ask which. This suits both."],
		L["Sit down after this fight, {name}. That's an order, from a grateful patient."],
		L["You keep us all standing, {name}. Here's a little of it coming back."],
		L["You've knelt beside all of us, {name}. Stand tall a minute."],
		L["Something that needed no prayer, {name}. You've said plenty of those today."],
	},
	DEATHKNIGHT = {
		L["No voice in your head comes with this one, {name}. Refreshing, isn't it?"],
		L["The Ebon Blade asks no favours, {name}. I'm giving one anyway."],
		L["A little warmth, {name}. I know you don't feel the cold. It's the thought."],
		L["You came back from the dead, {name}. The least I can do is help you stay back."],
		L["Runes, plague and frost, {name}. Take this too; it completes the set."],
		L["A skeletal horse and a sword that talks back, {name}. Here's something normal."],
		L["No need to drag me over on a chain, {name}. I was coming anyway."],
		L["Welcome back to the land of the living, {name}. Well, its general direction."],
	},
	SHAMAN = {
		L["The elements look after you, {name}, but they don't make house calls."],
		L["Tell the spirits I said hello, {name}. They never write back."],
		L["Plant a totem in my honour, {name}. A small one. I'm modest."],
		L["Earth, fire, water, air and me, {name}. Admittedly the least of the five."],
		L["Totems up already, {name}? Then this goes with them."],
		L["The wind would have brought you this, {name}, but it's flighty. I'm reliable."],
		L["You speak for the land, {name}. I hope it speaks kindly of me."],
		L["The spirits said you'd earned this, {name}. I didn't ask; they volunteered."],
	},
	MAGE = {
		L["A gift for a mage, {name}. Hard to find one you can't conjure."],
		L["You solve most problems with sheep, {name}. This covers the rest."],
		L["You could teleport out of any trouble, {name}. This is for the trouble first."],
		L["For the clever one, {name}. Please don't thank me by making me a sheep."],
		L["Blink wherever you like, {name}. This comes too."],
		L["Stand a little back from the fire you're about to start, {name}. Here."],
		L["You keep us all fed and watered, {name}. Your turn to be looked after."],
		L["Portal fees are steep, {name}. Call this a down payment on my next one."],
	},
	WARLOCK = {
		L["Entirely demon-free, {name}. I checked."],
		L["Your imp may be jealous, {name}. Tell it there's plenty to go round."],
		L["No contract, no fine print, {name}. Just a gift."],
		L["For the one who hands out healthstones, {name}. Nobody ever thanks you."],
		L["Here, {name}. Summon the rest of us later and we'll call it even."],
		L["Your voidwalker can stop hovering, {name}. I mean well."],
		L["Your felhunter eats magic, {name}. Keep it off this one; it's for you."],
		L["For the one who reads what nobody else dares, {name}."],
		L["Carrying a bag of souls all day, {name}? Your shoulders must need this."],
	},
	MONK = {
		L["Roll wherever you like, {name}. This rolls with you."],
		L["Brew first or fight first, {name}? Either way, take this."],
		L["Inner peace for you, {name}, and outer peace too, as long as this lasts."],
		L["Chi flows better with a little help, {name}. Or so a monk once told me."],
		L["Kick, flip, roll, {name}. I'll just stand here and do this bit."],
		L["Teach me to flip without spilling my drink, {name}, and we're even."],
		L["Tea, meditation and this, {name}. The three pillars of a good day."],
	},
	DRUID = {
		L["Tell the bear this is for them too, {name}."],
		L["Hold still, {name}. I've never once managed to catch you as a cheetah."],
		L["Nature looks after you already, {name}. Today she sent me to help."],
		L["Whatever shape you're in next, {name}, this goes with you."],
		L["For the forest's friend, {name}. Give my regards to the trees."],
		L["Cenarion work is never done, {name}. Here's a little help."],
		L["I'd give it to the cat, {name}, but the cat would pretend not to care."],
		L["Say hello to your moonkin form for me, {name}. It always looks so startled."],
	},
	DEMONHUNTER = {
		L["You were not prepared, {name}. Now you are."],
		L["Years in a Warden's cell, {name}. You've earned a small kindness."],
		L["You gave up so much to fight the Legion, {name}. Here's a little back."],
		L["For the one who leaps first, {name}. Do land somewhere friendly."],
		L["Fel and fury, {name}, and now a little kindness. It'll balance out."],
		L["I'd ask if you saw this coming, {name}, but you see everything."],
		L["You can see souls, {name}. Mine's the one being generous."],
		L["Illidan never let anyone help him, {name}. You're wiser than your teacher."],
		L["A demon inside and a Legion outside, {name}. Here's one thing on your side."],
	},
	EVOKER = {
		L["For you, {name}. Please don't breathe on it."],
		L["A little help for a dragon, {name}. I'll be telling my grandchildren."],
		L["The Aspects sent you out into the world, {name}. I'm making it friendlier."],
		L["Take to the skies after this, {name}. I'll wave from down here."],
		L["A dragon on our side, {name}. I've never felt safer being generous."],
		L["A gift for a dragon, {name}. Normally folk bring gold and hope to leave again."],
		L["For the one who could fly me to the next town, {name}. Not asking. Hinting."],
		L["I've met a few dragons, {name}. You're the first I didn't run from."],
		L["For the world's youngest ancient, {name}."],
	},
}

-- The same class meeting itself, by that class (UnitClass's second return),
-- in place of RP.TARGET's "sameclass" lines: two mages have a joke two of
-- anything else do not.
RP.SAME = {
	MAGE = {
		L["{buff} for a mage, {name}. Like lending a library a book."],
		L["Mage to mage, {name}: I won't ask you for water if you won't ask me."],
		L["Two mages, {name}. Between us we can portal anywhere and still be late."],
		L["A mage for a mage, {name}. Our old masters would approve."],
		L["A mage enchanting a mage, {name}. We'll both pretend we needed it."],
		L["Neither of us will admit which spells we still read off the page, {name}."],
		L["One mage is a scholar, {name}. Two is an argument. Here's my opening point."],
		L["We both know this spell by heart, {name}. Humour me."],
		L["More mana for you, {name}. Try not to spend it all on one fireball."],
	},
	PRIEST = {
		L["Priest to priest, {name}: who blesses the blessers? Today, me."],
		L["Between us, {name}, we'll pretend the warriors listen."],
		L["A priest looking after a priest, {name}. It feels almost forbidden."],
		L["Two priests, {name}. Twice the praying and half the panic."],
		L["If it all goes wrong, {name}, we two are the last ones standing."],
		L["Rest your prayers a while, {name}. Mine can keep watch."],
		L["I'd preach to you, {name}, but you've heard it. You've probably given it."],
		L["Same vows and same sore knees, {name}. Here's something for yours."],
		L["If I fall, {name}, you know the words. If you fall, so do I. Let's neither."],
	},
	DRUID = {
		L["Two druids, {name}. The Cenarion Circle would call this a quorum."],
		L["Druid to druid, {name}: bear or cat, I'd know you by the leaves in your hair."],
		L["From one shapeshifter to another, {name}: this one fits every shape."],
		L["No handshake, {name}. Two druids, and neither of us has the right shape for it."],
		L["Between us, {name}, we've a shape for every problem. Mostly bears."],
		L["Fellow druid, {name}? Then you know the trees told me you were coming."],
		L["If you see me as a cat later, {name}, pretend you don't know me. Dignity."],
	},
	PALADIN = {
		L["Paladin to paladin, {name}: heavy hammer, light heart."],
		L["A blessing for a paladin, {name}. Now we're both insufferably radiant."],
		L["Two paladins, {name}. Somewhere, a priest is quietly relieved."],
		L["One of us should be humble about this, {name}. Neither of us will be."],
		L["Same oath, different polish, {name}. Yours is shinier; I noticed."],
		L["Between us, {name}, we could light a cathedral. Or a small, very holy room."],
		L["Two suits of plate, {name}. Nobody will hear us sneak up. Nobody ever does."],
		L["Your libram and mine agree on this one, {name}. Rare, that."],
	},
	WARLOCK = {
		L["Warlock to warlock, {name}: keep your imp away from mine. They gossip."],
		L["Fellow warlock, {name}? Then you'll know this one's harmless."],
		L["Two warlocks, {name}. Let's not compare soul shards in public."],
		L["Between us, {name}, the demons do all the work. This bit I do myself."],
		L["Another warlock, {name}. Let's be polite; I've seen what you summon."],
		L["A spell from one warlock to another, {name}. Check it for curses. I would."],
		L["Fellow warlock, {name}. The only one who won't ask where this came from."],
		L["Two warlocks, one kind deed, {name}. The Burning Legion must be livid."],
		L["I'd summon you a drink, {name}, but we both know how summoning goes."],
	},
	WARRIOR = {
		L["Two warriors, {name}. Somewhere, a healer just sighed."],
		L["Warrior to warrior, {name}: first into the fight buys the drinks. I'm buying."],
		L["Shout for shout, {name}. We'll deafen the whole place together."],
		L["No plan, {name}? Perfect. We'll get along."],
		L["Warriors, {name}: the only folk who think shouting is a spell. We're right."],
		L["One warrior to another, {name}: keep your shield up and your temper hot."],
		L["You know this one, {name}. You've probably shouted it at me already."],
		L["Our trainer would be proud, {name}. He'd shout it, but he'd be proud."],
		L["Fellow warrior? Then you know the blacksmith's first name too, {name}."],
	},
	DEATHKNIGHT = {
		L["We both served the Scourge, {name}. I won't ask what you did. Don't ask me."],
		L["Two death knights, {name}. We've died twice between us. Let's stop there."],
		L["Between us, {name}, we can drop the echoing voice. Nobody's here to frighten."],
		L["Mograine would approve, {name}. Grimly; he approves of everything grimly."],
		L["Two horns and one winter, {name}. Mine sounds today; yours can have tomorrow."],
		L["The living keep their distance from us, {name}. We needn't keep ours."],
		L["We both broke free at Light's Hope, {name}. Every choice since is our own."],
		L["Do you still dream, {name}? I only ask our own kind. The living would worry."],
		L["Walk with me after dark, {name}. With eyes like ours, we won't need a lantern."],
	},
	MONK = {
		L["Fellow monk, {name}? Then we'll spar later and both pretend we held back."],
		L["Two monks and one teapot, {name}. Whoever pours is the humbler, so I'll pour."],
		L["We should compare masters, {name}. Mine was the hardest. Everyone's was."],
		L["Meditate beside me later, {name}. If one of us snores, it was the other."],
		L["Monk to monk, {name}: I won't tell you to breathe. You'd only tell me back."],
		L["Two monks, {name}. Xuen would see a contest, Yu'lon a lesson. I see a friend."],
		L["Why is every monastery on a mountaintop, {name}? Someone should try a valley."],
		L["Do the forms with me at dawn, {name}. Two monks in step is nearly music."],
		L["Strangers ask you for wisdom too, {name}? I tell them to eat something."],
	},
	EVOKER = {
		L["Some of our own followed Sarkareth into the dark, {name}. We chose the sky."],
		L["Shall we speak Draconic, {name}? The mortals always think we're quarrelling."],
		L["Between us, {name}, not even the Aspects knew quite what to make of us."],
		L["Do you also hold a spell a moment too long, {name}, just to feel it gather?"],
		L["Our people are still choosing their customs, {name}. I'd like this one kept."],
		L["Valdrakken was built for grown dragons, {name}. I feel like a hatchling there."],
		L["Our magic hums when two of us stand close, {name}. I've never learned why."],
		L["Scalecommanders drilled us both, {name}. Any shout still straightens my back."],
		L["Whichever side you took, {name}, we were kin before there were sides to take."],
	},
	SHAMAN = {
		L["You heard the earth grumble just now, {name}? Good. I thought it was only me."],
		L["Race you to the next town as wolves, {name}? No lightning. Fair's fair."],
		L["My ancestors and yours have surely met by now, {name}. I hope they got along."],
		L["Two shamans, one sky, {name}. I asked first, so this storm is mine to give."],
		L["Folk stare when we talk to rocks, {name}. Let them. The rocks answer us."],
		L["Between two shamans, {name}, a storm is just a conversation. Here's my half."],
		L["The elements could go quiet any day, {name}. Every day they answer is a gift."],
		L["Ever tried to stop listening, {name}? I did, for a day. Everything got louder."],
		L["People want storms stopped or started, {name}. Nobody asks how the sky feels."],
	},
}

-- A spell given to a class it does little for, by the spell's buff key and
-- then the class helped (UnitClass's second return): Arcane Intellect fills
-- mana, and a warrior or a rogue has none. Heard as part of RP.TARGET's pool
-- for that class, so whoever is helped gets no more of the draw than before,
-- and only while the buff is manaOnly on this client: on Mists the intellect
-- key is Arcane Brilliance, whose crit a warrior has every use for.
-- The joke is on the spell or on the one casting it, never on the one who has
-- no use for it.
RP.ONTO = {
	intellect = {
		WARRIOR = {
			L["No mana to fill, {name}. It'll just stand about being clever, like me."],
			L["My spell on a warrior, {name}. Call it a small experiment."],
			L["I only know the one spell for friends, {name}. Rage or mana, you're getting it."],
			L["Your rage doesn't need this, {name}, but I'd feel rude walking past you."],
		},
		ROGUE = {
			L["No mana, I know, {name}. A sharp mind never hurt a sharp blade."],
			L["It's meant for mana, {name}. You'll find a use. Rogues always find a use."],
			L["Not your kind of magic, {name}. Call it a very clever lockpick."],
		},
	},
}

-- A people's own city, for its "city" lines, by the ids the client's maps
-- name it with: Undercity is 1458 on WoW Forever's world (as on Classic's) and
-- 90 on Retail's. A people with no city lines needs none.
RP.HOME = {
	forsaken = { [1458] = true, [90] = true },
}

-- The five lines beta.9 put in the box, frozen: a box saved with them is
-- still the untouched set however the pools above are rewritten, and the load
-- repair (RP.Repair) turns it into the examples as they read now. Nothing
-- here is ever said; these only recognise. Per people: its first thanks,
-- asked and offer; per side: the same three; then the general lines. A
-- people with none (the Haranir) saved its side's three and the general
-- thanks and offer; any other saved its three, its side's offer and the
-- general group line.
--
-- And `reworded`: example lines rewritten since boxes were saved with them,
-- each as it reads now and then as it read before, for RP.BEFORE below.
RP.LEGACY = {
	race = {
		dwarf = {
			L["Thank ye kindly, {name}! First round's on me when we're back at the forge."],
			L["Aye, {name}, ye only had to ask. Hold still now!"],
			L["Here, {name}, a wee somethin' to keep ye on yer feet."],
		},
		human = {
			L["My thanks, {name}. Allow me to return the kindness."],
			L["Of course, {name}. Stand fast a moment."],
			L["The road ahead is long, {name}. Take this with you."],
		},
		nightelf = {
			L["Ishnu-alah, {name}. Your kindness is returned."],
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Elune-adore, {name}. Walk softly beneath the stars."],
		},
		voidelf = {
			L["The shadows remember kindness, {name}. So do I."],
			L["As you wish, {name}. The shadows answer kindly today."],
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
		},
		gnome = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Request received, {name}! Processing... done!"],
			L["Hold still, {name}, this is perfectly safe. Probably!"],
		},
		draenei = {
			L["The Light rewards kindness, {name}, and so shall I."],
			L["Of course, {name}. May the Naaru guide your steps."],
			L["The Light is with you, {name}. Go in peace."],
		},
		worgen = {
			L["Much obliged, {name}. Gilneas never forgets a kindness."],
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Stay off the moors after dark, {name}. Take this."],
		},
		orc = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["Dabu, {name}. It is done."],
			L["Lok'tar ogar, {name}! Take this into battle."],
		},
		forsaken = {
			L["Thank you, {name}. It would warm my heart, if it still beat."],
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["Stay among the living a little longer, {name}."],
		},
		tauren = {
			L["The Earth Mother sees your kindness, {name}. I return it."],
			L["Of course, {name}. Stand tall and be at peace."],
			L["Walk with the Earth Mother, {name}."],
		},
		troll = {
			L["Ya be too kind, {name}! Dis one be from me."],
			L["Sure ting, {name}. Hold still now."],
			L["Da loa be watchin' over ya, {name}."],
		},
		bloodelf = {
			L["Such courtesy does you credit, {name}. Anar'alah belore."],
			L["Naturally, {name}. Only the finest for you."],
			L["Anar'alah belore, {name}. May the sun guide you."],
		},
		nightborne = {
			L["Your generosity is noted, {name}. Suramar remembers its friends."],
			L["Of course, {name}. A little arcane polish, just for you."],
			L["Take this, {name}. Arcane gifts are wasted on the idle."],
		},
		goblin = {
			L["A favour for a favour, {name}! Pleasure doing business."],
			L["You got it, {name}! Time is money, friend!"],
			L["This one's on the house, {name}. Don't tell the Trade Prince."],
		},
		vulpera = {
			L["Thank you, {name}! The caravan always repays a kindness."],
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Every traveller needs something for the road, {name}."],
		},
		pandaren = {
			L["A kindness returned is a kindness doubled, {name}."],
			L["Of course, {name}. Patience, and it is done."],
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
		},
		dracthyr = {
			L["Your kindness is noted, {name}. Dragons do not forget."],
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Take this, {name}. Even a dragon needs allies."],
		},
	},
	side = {
		Alliance = {
			L["Thank you, {name}. The Alliance looks after its own."],
			L["Of course, {name}. Allies help each other."],
			L["For the Alliance, {name}! Stay strong out there."],
		},
		Horde = {
			L["Strength and honour, {name}. Your kindness is repaid."],
			L["Consider it done, {name}. For the Horde."],
			L["For the Horde, {name}! Go with strength."],
		},
		Neutral = {
			L["Thank you, {name}. Good hearts are found everywhere."],
			L["Gladly, {name}, whatever banner you fly."],
			L["Friends can come from any side, {name}."],
		},
	},
	general = {
		thanks = L["One good turn deserves another, {name}."],
		offer = L["Safe travels, {name}. Take some {buff} with you."],
		group = L["Everyone ready? You are now, {name}."],
	},
	-- The review of the lines after 1.6.4: the trolls' examples, written
	-- more plainly, and a goblin's group line. Then the race voices: Magni
	-- is the living king of Ironforge in this world, not a diamond.
	reworded = {
		{ L["Ya too kind, {name}! This one's from me."],
			L["Ya be too kind, {name}! Dis one be from me."] },
		{ L["Death's gonna be real disappointed, {name}. Thanks, mon."],
			L["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] },
		{ L["Sure thing, {name}. Hold still; mojo hates a movin' target."],
			L["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] },
		{ L["No trouble, {name}. Da loa like ya."],
			L["No worries, {name}. Da loa got ya covered."] },
		{ L["Stay away from da voodoo, {name}. Except this one. This one's fine."],
			L["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] },
		{ L["Da loa watch over ya, {name}. They're real nosy that way."],
			L["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] },
		{ L["Stay sharp, {name}. Take this with ya."],
			L["Stay sharp out dere, {name}. Take dis wit' ya."] },
		{ L["Here, {name}. Walk like ya own the jungle. I do."],
			L["Take dis, {name}. Walk like ya own da jungle. I do."] },
		{ L["We look after our own, {name}. Always, mon."],
			L["Hey, {name}! Always good to see family, mon."] },
		{ L["Crew's got style, {name}. Now it's got mojo too."],
			L["Dis crew got style, {name}. Now it got mojo too."] },
		{ L["We go in together, {name}, we come out together. That's the plan, mon."],
			L["We go in together, {name}, we come out together. Dat be da whole plan, mon."] },
		{ L["Night's the best time for mojo, {name}. Nobody sees where it's from."],
			L["Night be da best time for mojo, {name}. Nobody see where it come from."] },
		{ L["We split the take even, {name}. I'll do the maths. Trust me."],
			L["We split the loot even, {name}. I'll do the maths. Trust me."] },
		{ L["Magni'd melt down his crown fer a friend, {name}. This is the cheaper option."],
			L["Magni turned to diamond fer the cause, {name}. This is the cheaper option."] },
	},
}

-- And what the examples' translations read before they were reworded: the
-- 1.6.6 pass "Translations read for fluency" changed lines that are examples
-- (Ishnu-alah spelled in Hangul for the night elves, the dwarves' and trolls'
-- lines in most languages), and a box saved by an earlier release holds them
-- as they read then, in the language it was filled in. Per language (esES
-- answers esMX), each English key with the lines it was translated as, never
-- said: RP.Active reads a line of a box that is one of these as the line it
-- is today. A translation of an example edited from now on needs its old
-- text here too: python tools/legacy_lines.py --check says which are
-- missing, --lua prints the table.
RP.LEGACY_TRANSLATED = {
	deDE = {
		["A gift freely given, {name}. The naaru hum a little louder. Returned."] = { "Freimütig gegeben, {name}. Die Naaru summen etwas lauter. Erwidert." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi sein jetzt echt enttäuscht, {name}. Danke, Mann." },
		["Da loa be watchin' over ya, {name}."] = { "Die Loa, die wachen über Euch, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Die Loa wachen über Euch, {name}. Die sein echt neugierig." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "Nacht sein die beste Zeit für Mojo, {name}. Keiner sieht, woher's kommt." },
		["No worries, {name}. Da loa got ya covered."] = { "Keine Sorge, {name}. Die Loa sein bei Euch." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Haltet Euch vom Voodoo fern, {name}. ...Außer von dem hier. Das sein gut." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Zusammen rein, {name}, zusammen raus. Das sein der ganze Plan, Mann." },
	},
	esES = {
		["A gift with no favour owed? The court would faint. Thank you, {name}."] = { "¿Un regalo sin deber favores? La corte se desmayaría. Gracias, {name}." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi se va a llevar un buen chasco, {name}. Gracia', mon." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Lo' loa velan por ti, {name}. Son mu' fisgones, mon." },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "Lo' loa te cuidan, {name}. Son bien curioso'." },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "La muerte se va a llevar un buen chasco, {name}. Gracia', mon." },
		["Here, {name}, a wee somethin' to keep ye on yer feet."] = { "Aquí tienes, {name}, algo pa' que no flaquees." },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "Toma, {name}, un detallito pa' que no flaquees. Chiquito, como yo." },
		["Here, {name}. Ale's for after; this is for before."] = { "Toma, {name}. La cerveza, pa' después; esto, pa' antes." },
		["Mornin', {name}! Too early for ale. Almost. Have this first."] = { "¡Buenos días, {name}! Temprano pa' la cerveza. Casi. Toma esto antes." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "La noche e' la mejor hora pa'l mojo, {name}. Nadie ve de dónde sale." },
		["No trouble, {name}. Da loa like ya."] = { "Sin problema, {name}. Lo' loa te quieren." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Aléjate del vudú, {name}. ...Menos de este vudú. Este tá bien." },
		["Stay away from da voodoo, {name}. Except this one. This one's fine."] = { "Aléjate del vudú, {name}. Meno' de este. Este está bien." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "No te alejes, {name}. Un trol se regenera; lo' demás, cuidadito." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Seguro, {name}. No te mueva': el mojo odia lo que se mueve." },
		["Sure ting, {name}. Hold still now."] = { "Claro que sí, {name}. No te mueva' ahora." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Claro, {name}. No te mueva': el mojo odia los blancos móviles." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Entramo' juntos, {name}, salimo' juntos. Ese e' to' el plan, mon." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "Entramo' junto', {name}, y salimo' junto'. Ese e' el plan, mon." },
		["We look after our own, {name}. Always, mon."] = { "Cuidamo' de los nuestro', {name}. Siempre, mon." },
		["Ya be too kind, {name}! Dis one be from me."] = { "¡Ere' mu' amable, {name}! Esta va de mi parte." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Parece' alguien que aprecia la calidad, {name}. Toma: calidad." },
		["Ya too kind, {name}! This one's from me."] = { "¡Qué amable ere', {name}! Esto va de mi parte." },
	},
	frFR = {
		["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."] = { "Demandez d'l'aide à un nain, {name} : vous l'aurez. Et vous l'entendrez." },
		["Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass."] = { "Oh, {name}. J'vous facturerais bien, mais je suis d'humeur sentimentale. Ça passera." },
		["Aye, {name}, ye only had to ask. Hold still now!"] = { "Pour sûr, {name}, suffisait d'demander. Bougez plus !" },
		["Aye, {name}, ye only had to ask. Hold still now, like a good anvil."] = { "Pour sûr, {name}, suffisait d'demander. Bougez plus, comme une bonne enclume." },
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Merci, {name} ! Une accolade ? Non, z'auriez besoin d'un soigneur après." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi, il va être bien déçu, {name}. Merci, l'ami." },
		["Crew's got style, {name}. Now it's got mojo too."] = { "L'équipe a du style, {name}. Et maint'nant, du mojo." },
		["Da loa be watchin' over ya, {name}."] = { "Les loa, ils veillent sur vous, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Les loa, ils veillent sur vous, {name}. Des vrais fouineurs, ceux-là." },
		["Deal, {name}! I'll put it on your tab. Kidding!"] = { "Marché conclu, {name} ! Je le mets sur votre ardoise. J'rigole !" },
		["Dis crew got style, {name}. Now it got mojo too."] = { "C'groupe a du style, {name}. Et maint'nant, du mojo." },
		["Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds."] = { "L'or appartient à ceux qui se lèvent tôt, {name} ! Un cadeau. Le dites pas aux autres lève-tôt." },
		["Here, {name}, a wee somethin' to keep ye on yer feet."] = { "Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb." },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb. P'tit, comme moi." },
		["Here, {name}. If anything explodes near you today, that was unrelated."] = { "Tenez, {name}. Si quelque chose explose près de vous aujourd'hui, j'y suis pour rien." },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "Tenez, {name}. Marchez comme si la jungle était à vous. Moi, c'est l'cas." },
		["Hey, {name}! Always good to see family, mon."] = { "Hé, {name} ! C'est toujours bon d'voir la famille, ça." },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "Si j'me mets à chanter, {name}, c'est qu'le combat s'passe bien. Ou très mal." },
		["Mornin', {name}! Too early for ale. Almost. Have this first."] = { "B'jour, {name} ! Trop tôt pour une bière. Presque. Prenez d'abord ça." },
		["Much obliged, {name}. Ye've a friend in the mountain now."] = { "Mille mercis, {name}. Z'avez un ami dans la montagne, maint'nant." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "La nuit, c'est l'meilleur moment pour l'mojo, {name}. Personne voit d'où il vient." },
		["Night's the best time for mojo, {name}. Nobody sees where it's from."] = { "La nuit, c'est l'meilleur moment pour l'mojo, {name}. Personne voit d'où il vient." },
		["No trouble, {name}. Da loa like ya."] = { "Pas d'souci, {name}. Les loa vous aiment bien." },
		["No worries, {name}. Da loa got ya covered."] = { "Pas d'souci, {name}. Les loa, ils vous couvrent." },
		["Nobody dies on my contract, {name}. The paperwork's a nightmare."] = { "Personne meurt sous mon contrat, {name}. La paperasse, c'est l'enfer." },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "Bon, {name} : j'prends l'avant, vous prenez l'butin, et on s'dispute après." },
		["Say no more, {name}. Stone and steel, here it comes."] = { "Pas un mot d'plus, {name}. Par la pierre et l'acier, ça vient !" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "Derrière moi, {name}. Oui, j'sais. Baissez-vous un peu." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Restez loin du vaudou, {name}. ...Sauf c'vaudou-là. Lui, il est bien." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "Restez près d'moi, {name}. Les trolls, ça régénère ; vous autres, faites attention." },
		["Stay sharp out dere, {name}. Take dis wit' ya."] = { "Faites gaffe dehors, {name}. Prenez ça avec vous." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Bien sûr, {name}. Bougez plus ; le mojo déteste les cibles qui bougent." },
		["Sure ting, {name}. Hold still now."] = { "Bien sûr, {name}. Bougez plus, là." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Bien sûr, {name}. Bougez plus, là ; le mojo, il aime pas les cibles qui bougent." },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "Prenez ça, {name}. Marchez comme si la jungle était à vous. Moi, c'est l'cas." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Merci, l'ami ! Les esprits, ils vous sourient, {name}." },
		["Thanks, {name}! I checked it for fine print. There wasn't any. Weird!"] = { "Merci, {name} ! J'ai cherché les petites lignes. Y en avait pas. Bizarre !" },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "On entre ensemble, {name}, on sort ensemble. C'est tout l'plan, l'ami." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "On entre ensemble, {name}, on sort ensemble. C'est ça, l'plan, l'ami." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Trop gentil, {name} ! Et çui-là, il vient d'moi." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "Vous m'avez donné du bon mojo, {name}. Maint'nant, vous en r'cevez, extra épicé." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Vous avez l'air d'aimer la qualité, {name}. Tenez : d'la qualité." },
		["Ya too kind, {name}! This one's from me."] = { "Trop gentil, {name} ! Çui-là, il vient d'moi." },
	},
	itIT = {
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Evviva, {name}! Ti abbraccerei, ma poi ti servirebbe un guaritore." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi ce resta malissimo, {name}. Grazie, cumpà." },
		["Crew's got style, {name}. Now it's got mojo too."] = { "Stu gruppo tene stile, {name}. E mo' pure 'o mojo." },
		["Da loa be watchin' over ya, {name}."] = { "'E loa te guardano 'e spalle, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "'E loa te guardano 'e spalle, {name}. So' curiosi assaje." },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "'E loa te tengono d'uocchio, {name}. So' curiuse assaje." },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "'A morte ce resta proprio male, {name}. Grazie, cumpà." },
		["Dis crew got style, {name}. Now it got mojo too."] = { "Sta compagnia tene stile, {name}. Mo' tene pure 'o mojo." },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "Piglia, {name}. Cammina comm'a padrone d''a giungla. Io 'o faccio." },
		["Hey, {name}! Always good to see family, mon."] = { "Uè, {name}! Fa sempre piacere vedé 'a famiglia, cumpà." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "'A notte è l'ora d''o mojo, {name}. Nisciuno vede da dove vene." },
		["Night's the best time for mojo, {name}. Nobody sees where it's from."] = { "'A notte è 'o mumento meglio p''o mojo, {name}. Nisciuno vede 'a do' vene." },
		["No trouble, {name}. Da loa like ya."] = { "Nisciun problema, {name}. 'E loa te vonno bene." },
		["No worries, {name}. Da loa got ya covered."] = { "Nun te preoccupà, {name}. Ce pensano 'e loa." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Statte luntano d''o voodoo, {name}. ...Tranne chisto. Chisto va bbuono." },
		["Stay away from da voodoo, {name}. Except this one. This one's fine."] = { "Statte luntano d''o voodoo, {name}. Chisto no: chisto è bbuono." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "Stamme vicino, {name}. 'E troll se rigenerano; vuje no, quindi occhio." },
		["Stay sharp out dere, {name}. Take dis wit' ya."] = { "Occhi aperti llà fore, {name}. Pigliate chisto." },
		["Stay sharp, {name}. Take this with ya."] = { "Uocchie aperte, {name}. Portate chisto." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Va bbuono, {name}. Nun te movere: 'o mojo odia chi se move." },
		["Sure ting, {name}. Hold still now."] = { "Sicuro, {name}. Mo' nun te movere." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Sicuro, {name}. Nun te movere: 'o mojo nun ama 'e bersagli mobili." },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "Piglia, {name}. Cammina da padrone d''a giungla. Comme a me." },
		["Take it, {name}, I've a spare. I've three spares of everything."] = { "Prendi, {name}, ho il ricambio. Ho tre ricambi di tutto." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Grazie assaje, cumpà! 'E spiriti te sorrideno, {name}." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Trasimmo insieme, {name}, e ascimmo insieme. Chisto è tutto 'o piano, cumpà." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "Trasimmo 'nzieme, {name}, e ascimmo 'nzieme. Chisto è 'o piano, cumpà." },
		["We look after our own, {name}. Always, mon."] = { "Nuje penzammo a 'e nuoste, {name}. Sempe, cumpà." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Si' troppo gentile, {name}! Chisto t'o dong' io." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "M'hai dato buon mojo, {name}. Mo' te lo torno, cu 'o peperoncino." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Tieni 'a faccia 'e chi apprezza 'a qualità, {name}. Ecco: qualità." },
		["Ya too kind, {name}! This one's from me."] = { "Si' troppo gentile, {name}! Chisto è da parte mia." },
	},
	koKR = {
		["Anar'alah belore, {name}. May the sun guide you, and light your good side."] = { "Anar'alah belore, {name}. 태양이 그대를 인도하고, 잘 나온 쪽을 비추기를." },
		["Anar'alah belore, {name}. May the sun guide you."] = { "Anar'alah belore, {name}. 태양이 그대를 인도하기를." },
		["Archenon poros, {name}! The children of Argus look after one another."] = { "Archenon poros, {name}! 아르거스의 자손은 서로를 돌보지요." },
		["Archenon poros, {name}. Your gift is returned."] = { "Archenon poros, {name}. 받은 선물을 돌려드립니다." },
		["Dabu, {name}. It is done."] = { "Dabu, {name}. 다 됐다." },
		["Elune-adore, {name}. Walk softly beneath the stars."] = { "Elune-adore, {name}. 별빛 아래 사뿐히 걷기를." },
		["Elune-adore, {name}. Walk softly; the trees are light sleepers."] = { "Elune-adore, {name}. 사뿐히 걸으시오. 나무들은 잠귀가 밝으니." },
		["Ishnu-alah, {name}. Elune keeps her children close."] = { "Ishnu-alah, {name}. 엘룬께선 자녀들을 늘 곁에 두시지요." },
		["Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing."] = { "Ishnu-alah, {name}. 당일에 갚다니, 칼도레이로선 서두른 셈이오." },
		["Ishnu-alah, {name}. Your kindness is returned."] = { "Ishnu-alah, {name}. 그대의 호의를 돌려드리리다." },
		["Lok'tar ogar, {name}! Take this into battle."] = { "Lok'tar ogar, {name}! 이걸 품고 전장으로 가라!" },
		["Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts."] = { "Lok'tar ogar, {name}! 이걸 품고 전장으로 가라. 술집 싸움도 전장이다." },
		["Shorel'aran, {name}. Fight with elegance."] = { "Shorel'aran, {name}. 우아하게 싸우시길." },
		["Such courtesy does you credit, {name}. Anar'alah belore."] = { "그 예의, 칭찬할 만하군요, {name}. Anar'alah belore." },
		["Throm-ka, {name}! Honour is repaid."] = { "Throm-ka, {name}! 명예로 갚는다!" },
		["Throm-ka, {name}! The blood of the clans runs strong in you."] = { "Throm-ka, {name}! 네 안에 부족의 피가 힘차게 흐르는군." },
	},
	ptBR = {
		["A gift freely given, {name}. The naaru hum a little louder. Returned."] = { "Um presente dado de coração, {name}. Os Naarus zumbem mais alto. Retribuído." },
		["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."] = { "Pede ajuda a um anão, {name}, e cê ganha. Aos berros." },
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Brigadão, {name}! Te daria um abraço, mas depois cê ia precisar de curador." },
		["Much obliged, {name}. Ye've a friend in the mountain now."] = { "Valeu demais, {name}. Agora cê tem amigos na montanha." },
		["Of course, {name}. The naaru guide your steps; this puts a spring in them."] = { "Claro, {name}. Os Naarus guiam seus passos; isto dá um gás neles." },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "Combinado, {name}: eu vou na frente, cê pega o saque e depois a gente briga." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Valeu, mano! Os espíritos sorriem procê, {name}." },
		["The naaru would call this a fellowship, {name}. I call it good luck."] = { "Os Naarus chamariam isto de irmandade, {name}. Eu chamo de sorte." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Cê é gente boa demais, {name}! Essa vai de mim." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "Cê me deu mojo bom, {name}. Agora toma de volta, extra apimentado." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Cê tem cara de quem curte qualidade, {name}. Toma: qualidade." },
		["Ya too kind, {name}! This one's from me."] = { "Cê é gentil demais, {name}! Essa é por minha conta." },
	},
	zhCN = {
		["Crew's got style, {name}. Now it's got mojo too."] = { "这队人有派头，{name}。现在还有巫毒咧。" },
		["Da loa be watchin' over ya, {name}."] = { "洛阿在守着你咧，{name}。" },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "洛阿在守着你咧，{name}。他们就是这么爱管闲事。" },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "洛阿看着你咧，{name}。它们就是这么爱管闲事。" },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "死神这下要失望透咧，{name}。谢啦，老兄。" },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "喏，{name}，一点小意思，保你站得稳。小，跟俺一个样。" },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "要是俺唱起歌来，{name}，就是仗打得顺。或者糟透了。" },
		["No trouble, {name}. Da loa like ya."] = { "小事，{name}。洛阿喜欢你咧。" },
		["No worries, {name}. Da loa got ya covered."] = { "莫担心，{name}。洛阿罩着你咧。" },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "说好了，{name}：俺打头阵，你捡战利品，完事再吵。" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "站俺后头，{name}。嗯，俺知道。你蹲低点儿。" },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "跟紧点，{name}。巨魔能再生，你们其他人可得小心咧。" },
		["Stone and hammer keep ye, cousin {name}!"] = { "愿石与锤护着你，老表{name}！" },
		["Such courtesy does you credit, {name}. Nearly as much as it does me."] = { "如此礼数，为你增光，{name}。差不多跟为我增的光一样多。" },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "没问题，{name}。别动，巫毒最讨厌移动靶咧。" },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "小事一桩，{name}。莫乱动，巫毒不喜欢移动靶咧。" },
		["Thank ye kindly, {name}! First round's on me when we're back at the forge."] = { "多谢啦，{name}！回到熔炉边，头一轮酒俺请！" },
		["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."] = { "谢啦，{name}！没它俺也扛得住，真的。不过还是谢啦！" },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "谢啦，伙计！众灵在冲你笑咧，{name}。" },
		["The Sunwell shines for us both, {name}."] = { "太阳之井为我们闪耀，{name}。" },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "你给了我好巫毒，{name}。现在还你一份，加辣的咧。" },
		["Ya too kind, {name}! This one's from me."] = { "你太客气咧，{name}！这个是我送的。" },
	},
	zhTW = {
		["Da loa be watchin' over ya, {name}."] = { "羅亞在看著你哩，{name}。" },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "羅亞在看著你哩，{name}。祂們可愛管閒事了。" },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "來，{name}，小小心意讓你站穩腳。小，跟俺一樣！" },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "給你，{name}。走路要像叢林是你家的。咱就這樣走。" },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "俺要是開唱，{name}，不是打得很順，就是很慘。" },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "好，{name}：俺打頭陣，你撿寶，打完再吵！" },
		["Say no more, {name}. Stone and steel, here it comes."] = { "甭多說，{name}！岩石與鋼鐵，接著！" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "躲俺後面，{name}。對，俺知道。蹲低點。" },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "{name}，走路要像叢林你家開的。咱就是。" },
		["Thank ye kindly, {name}! First round's on me when we're back at the forge."] = { "多謝啦，{name}！回熔爐頭一杯俺請！" },
		["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."] = { "謝啦，{name}！沒這個俺也行，真的！但還是謝啦。" },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "謝啦老兄！眾靈對你笑哩，{name}。" },
		["Ya be too kind, {name}! Dis one be from me."] = { "你太客氣啦，{name}！這份算咱的。" },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "你給咱好巫毒，{name}。現在還你，加辣的。" },
		["Ya too kind, {name}! This one's from me."] = { "你太客氣啦，{name}！這個咱送的。" },
	},
}

-- Every line of a ready-made set and of an "In character" example, in every
-- language the addon is translated into, by the hash of its text (LineHash
-- below) to the English key of the line, which is its place in RP.OTHER_KEYS.
-- A box keeps the language it was filled in, and a client's own Locales file
-- holds only its own language, so a box saved by a client in German and opened
-- by one in English could not be told from the player's own words: In
-- character stopped, and a fixed set stayed German. This is the table that
-- carries the other languages' text; RP.InThisLanguage turns each line of a
-- box into the client's own reading, and the box counts as untouched when the
-- result is a set or the examples. Written by python tools/legacy_lines.py
-- --write-other, which --check says is out of date after any change to a set,
-- an example or a translation of one: do not edit it by hand.
-- BEGIN other-languages (python tools/legacy_lines.py --write-other writes everything up to END)
RP.OTHER_KEYS = {
	"A favour for a favour, {name}! Pleasure doing business.",
	"A fellow wanderer! The caravan is never far, {name}.",
	"A fight, then a meal, {name}. That is the correct order. Never the reverse.",
	"A gift freely given, {name}. The naaru hum a little louder. Returned.",
	"A gift from the Dragon Isles, {name}. Fly well.",
	"A gift from the shadows, {name}. No, don't look. You won't find me.",
	"A gift with no favour owed? The court would faint. Thank you, {name}.",
	"A kindness returned is a kindness doubled, {name}.",
	"A little something from the Telogrus Rift, {name}. It's cleaner than it sounds.",
	"A little something, {name}. Don't tell the guards; they'll all want one.",
	"A pack again, {name}. I hadn't known how much I'd missed one.",
	"A party at last, {name}. I did dress for one.",
	"A reasonable request, {name}. Granted.",
	"A small upgrade for you, {name}. No cogs required.",
	"A spark of Suramar's arcana for you, {name}. Use it wisely.",
	"A touch of shadow for you, {name}. Quite safe. Mostly.",
	"A true warband, {name}. Loud, angry, and all on the same side for once.",
	"Alexstrasza says every life is precious, {name}. I am starting with yours.",
	"Among orcs, {name}, making you stronger is how we say we like you.",
	"An expedition, {name}! In Suramar this needed six permits and a masquerade.",
	"An orc giving gifts unasked? Tell no one, {name}. It ruins the image.",
	"An'she rises, {name}, and so do we. Slower, in my case.",
	"Anar'alah belore, {name}. May the sun guide you, and light your good side.",
	"Anything for a fellow entrepreneur, {name}!",
	"Anything shiny in there, {name}, I saw it first. Caravan law.",
	"Arathor's children stand together, {name}.",
	"Arcane for everyone, {name}. The court would call it waste. I call it company.",
	"Archenon poros, {name}! The children of Argus look after one another.",
	"Archenon poros, {name}. Your gift is returned.",
	"As you wish, {name}. The shadows answer kindly today.",
	"Ask a dwarf fer help, {name}, and ye'll get it. Loudly.",
	"Ask an orc for help and you get it, {name}. Ask for subtlety and you wait.",
	"Ask and it is given, {name}. The herd shares what it has.",
	"Ask the dead for a favour, {name}. We rarely have other plans.",
	"At last, {name}! I've waited ten thousand years for someone to ask.",
	"At once, {name}. Quick for a pandaren, which is not saying much.",
	"Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass.",
	"Aye, {name}, ye only had to ask. Hold still now, like a good anvil.",
	"Azeroth needs you on your feet, {name}.",
	"Balance in all things, {name}. Now go with a light heart.",
	"Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after.",
	"Bless you, {name}. No, you didn't sneeze; I'm simply thorough.",
	"Blood and thunder, {name}! Go and earn your glory.",
	"Buffed. You're welcome, {name}.",
	"By my calculations, {name}, you're owed exactly one {buff}.",
	"Caravan rules, {name}: stay together, share the water, nobody sells the alpaca.",
	"Careful by the shore, {name}. Where there's one murloc, there are nine.",
	"Certainly, {name}. Hold still, I don't bite. Much.",
	"Certainly, {name}. Stand clear of the tail.",
	"Certainly, {name}. The short version; the long one takes a lunar cycle.",
	"Certainly, {name}. The whispers said no, so it's an easy yes.",
	"Certainly, {name}. Try not to die. It's overrated.",
	"Cheers, {name}!",
	"Coming right up, {name}! Caravan service, no waiting.",
	"Consider it done, {name}. The Void obeys us, not the other way round.",
	"Consider us even, {name}.",
	"Consider yourself shouted at, {name}. Affectionately.",
	"Crew's got style, {name}. Now it's got mojo too.",
	"Da loa watch over ya, {name}. They're real nosy that way.",
	"Dabu, {name}. It is done.",
	"Daylight, {name}. Ten thousand years under a dome, and it still startles me.",
	"Deal, {name}! I'll put it on your tab. Kidding!",
	"Death's gonna be real disappointed, {name}. Thanks, mon.",
	"Do keep pace, {name}. We have a reputation for arriving beautifully.",
	"Don't spend it all at once, {name}.",
	"Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds.",
	"Elune lights your path, {name}. I'm merely holding the lantern.",
	"Elune saw that, {name}. She sees everything, so I had best return it.",
	"Elune watches the whole party, {name}. I'm just the one who waves at her.",
	"Elune-adore, {name}. Walk softly; the trees are light sleepers.",
	"Every traveller needs something for the road, {name}. I checked: not a rock.",
	"Everyone deserves to shine, {name}. Only a little less than me, of course.",
	"Fair winds and following seas, {name}.",
	"Fall in a lake someday, {name}, and you'll think of me fondly.",
	"Follow the visions, Hagar said, {name}. Today they pointed at you. Take this.",
	"For Gnomeregan, {name}! Always nice to talk to somebody at eye level.",
	"For the Alliance, {name}! Stay strong out there. Stronger, now.",
	"For the Horde, {name}! Go with strength. I've just handed you some.",
	"For you, {name}.",
	"For you, {name}. No, I don't want a treat. Well. Perhaps a small one.",
	"For you, {name}. Unasked, unearned and entirely deserved. Draconic logic.",
	"For you, {name}? Of course. The sun gives freely.",
	"Forward, {name}. The Horde advances together. Retreats... never, officially.",
	"Found this lying around, {name}. Kidding! It's fresh. Take it!",
	"Free sample, {name}! If you like it, you know where to find me.",
	"Fresh from the Emerald Dream, {name}. Sorry if I yawn.",
	"Friends can come from any side, {name}. Or, like me, from none in particular.",
	"From Kalimdor to the Eastern Kingdoms, {name}, may every road bring you home.",
	"From one wanderer of Azeroth to another.",
	"Get behind me, {name}. There's room back there for the whole party.",
	"Gladly, {name}. Be still, and let the moonlight find you.",
	"Gladly, {name}. The Light answers those who ask.",
	"Go with honour, {name}. Victory awaits.",
	"Go with the Light, {name}. I'll be right behind you, clanking.",
	"Granted, {name}. A dragon keeps its word.",
	"Group rate, {name}! Everybody here gets it half off. Of free.",
	"Hagar sent me to see the goddess's work, {name}. You're some of her best.",
	"Have some {buff}, {name}.",
	"Hear that, {name}? Winter, on your side for once.",
	"Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me.",
	"Here, {name}. Ale's for after; this is for before.",
	"Here, {name}. Best thing in my pack, and I've got a lot of pack.",
	"Here, {name}. Don't ask where it came from. Really, don't.",
	"Here, {name}. I had a spare thought and nowhere to put it.",
	"Here, {name}. If anything explodes near you today, that was unrelated.",
	"Here, {name}. Think of it as a prayer that arrived early.",
	"Here, {name}. Walk like ya own the jungle. I do.",
	"Hold still, {name}, this is perfectly safe. Probably!",
	"Hold still, {name}. Strength for the fight ahead.",
	"How gracious, {name}. Allow me to return the favour.",
	"How kind, {name}! You're on the caravan's good list now.",
	"I passed you twice on my morning run, {name}. The third time, I stopped. Here.",
	"I slept through ten thousand years of good deeds, {name}. Catching up now.",
	"I was a physician in Lordaeron, {name}. Old habits die harder than I did.",
	"I woke in a cave full of strangers, {name}. This is far better company.",
	"I would bow, {name}, but last time my wings cleared a table. Thank you.",
	"I'd have brought this sooner, {name}, but I stopped to chase something.",
	"I'll be the one you can't see, {name}. That's not a mistake; that's the plan.",
	"I'll catch the scent of trouble first, {name}. It's the one perk of the curse.",
	"I'll draw up a plan, {name}, and then we can all ignore it together.",
	"I'll take the front, {name}. What's the worst that could happen? Again?",
	"I've gone without magic once, {name}. I don't recommend it. Take this.",
	"I've run the numbers, {name}: with you here, we win. I rounded up.",
	"If I fall down, {name}, give it a minute. Old habit.",
	"If I shout 'duck', {name}, don't look for a duck. That went badly last time.",
	"If I start singin', {name}, the fight's gone well. Or very badly.",
	"If something whispers to you in the dark, {name}, don't answer.",
	"If the shadows start giving orders, {name}, ignore them. I usually do.",
	"Ishnu-alah, {name}. Elune keeps her children close.",
	"Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing.",
	"It's a long way up to a tauren's heart, {name}. You found it.",
	"Keep an eye on my shadow, {name}. It wanders off when there's a fight.",
	"Keep close, {name}. Humans have always won by outnumbering things.",
	"Keep this, {name}. The desert is long and the water is short.",
	"Keep your wits about you, {name}. Something is always hunting.",
	"Kind of you, {name}. We sin'dorei never turn down free magic. Ask anyone.",
	"Kindly done, {name}. Let no one say we forget a friend.",
	"Kindness echoes, {name}, and I grew up in a cavern. Here it comes back to you.",
	"Least I could do, {name}.",
	"Ley lines run under all of Azeroth, {name}. Today a little runs your way.",
	"Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts.",
	"Low ceilings ahead, {name}? I'll be the first to find out. Take this.",
	"Magni'd melt down his crown fer a friend, {name}. This is the cheaper option.",
	"May An'she light your path, {name}.",
	"May the Barrens be kinder to you than they were to me, {name}.",
	"May the forest shelter you, {name}, wherever you roam.",
	"More work? Gladly, {name}. It beats the lumber mill.",
	"Mornin', {name}! Too early for ale. Almost. Have this first.",
	"Morning already, {name}? I've been up all night. And all of last decade.",
	"Morning, {name}! Up since three. The toaster needed a new engine.",
	"Morning, {name}. I'd have been up sooner, but the rug by the fire was so warm.",
	"Morning, {name}. My people slept through these for millennia. I'm adapting.",
	"Most gracious, {name}. Allow me to repay you in kind.",
	"Mu'sha keeps the night watch, {name}. I'll tell her to keep an eye on you.",
	"Much obliged, {name}. Gilneas never forgets a kindness, and nor does my nose.",
	"Much obliged, {name}. Ye've a friend in the mountain now.",
	"My Legacy Stone showed who I'd stand beside, {name}. It forgot you. Thank you.",
	"My thanks, {name}. Let me return the kindness before a bard gets it wrong.",
	"My thanks, {name}. The ren'dorei do not forget a kindness.",
	"My undying gratitude, {name}. For once, the phrase is accurate.",
	"Naturally, {name}. Only the finest for you.",
	"Neltharion made us to fight alone, {name}. We have improved on him.",
	"Night again, {name}. I'm at my best and my worst. This is the best part.",
	"Night at last, {name}. Add a few thousand lanterns and it's nearly Suramar.",
	"Night suits the ren'dorei, {name}. We match the decor.",
	"Night's the best time for mojo, {name}. Nobody sees where it's from.",
	"No charge, {name}. The apothecaries would have made you sign something.",
	"No charge, {name}. They'd call me mad in Booty Bay.",
	"No flag over this party, {name}, just us. That's plenty.",
	"No incense, no prayers, {name}. Just me, shouting encouragingly.",
	"No trouble, {name}. Da loa like ya.",
	"Nobody dies on my contract, {name}. The paperwork's a nightmare.",
	"Of course, {name}! I built a machine for this. It's in pieces, so: by hand.",
	"Of course, {name}! Shake the sand out and hold still.",
	"Of course, {name}. A little arcane polish, just for you.",
	"Of course, {name}. Dalnir would call this a distraction. Dalnir isn't here.",
	"Of course, {name}. Elune's blessings are meant to be shared.",
	"Of course, {name}. Hold still and look heroic; it helps the bards.",
	"Of course, {name}. I answered the goddess's call. Yours is far easier to hear.",
	"Of course, {name}. Patience, and it is done. Patience is the slow part.",
	"Of course, {name}. Protect, tend and serve, my people say. This is the serving.",
	"Of course, {name}. Stand back a pace; I do this with my whole body.",
	"Of course, {name}. Stand tall and be at peace. I'll handle the tall part.",
	"Of course, {name}. The naaru guide your steps; this puts a spring in them.",
	"Off ye go, {name}, steady as the mountain.",
	"Oh, I'll keep this, {name}! I keep everything. Here's one for you.",
	"One for the party, {name}! A caravan's only as fast as its slowest alpaca.",
	"One good buff deserves another, {name}.",
	"One good turn, {name}. Azeroth could use a few more of those.",
	"One upgrade, coming right up, {name}! Stand still for calibration.",
	"Onward, {name}. The Alliance is with you.",
	"Orcs keep their thanks short, {name}. Thanks.",
	"Orcs return every blow twice, {name}. The kind ones too.",
	"Our strength is each other, {name}. For the Horde!",
	"Pack rules, {name}: nobody wanders off, and nobody mentions the fleas.",
	"Party-wide calibration complete, {name}! Nobody touch anything shiny.",
	"Past my first nap, {name}, and before my second. Quickly, while I'm awake.",
	"Patience, {name}. Radiance can't be rushed, only admired.",
	"Quick one, {name}? By kaldorei reckoning we'll be done before we start.",
	"Ragnaros still burns under Blackrock Mountain, {name}. Let's keep him down there.",
	"Reciprocity engaged! Much obliged, {name}.",
	"Repaid on the spot, {name}. In Stormwind that'd take three forms and a stamp.",
	"Request received, {name}! Processing... done!",
	"Returning the favour, {name}.",
	"Right away, {name}! Satisfaction guaranteed or your {buff} back.",
	"Right away, {name}. Keep your shield high.",
	"Right away, {name}. Stay, now. I've always wanted to say that.",
	"Right you are, {name}. Stand steady now.",
	"Right, {name}: I take the front, ye take the loot, and we argue after.",
	"Right, {name}: shields up, heads down, and nobody charges before the plan does.",
	"Say no more, {name}. Stone and steel, here it comes.",
	"Science says you need this, {name}. Who am I to argue?",
	"Shorel'aran, {name}. Fight with elegance.",
	"Side by side, {name}, whatever comes.",
	"Some of Deathwing's brood wear human faces, {name}. Mind who you trust.",
	"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	"Somewhere, a Sha just went hungry. Thank you, {name}.",
	"Soon they'll hand us tabards, {name}. Until then, we look after each other.",
	"Stand behind me, {name}. Aye, I know. Crouch a bit.",
	"Stand where the light is good, {name}. If we must fight, we'll look splendid.",
	"Stay alive, {name}. Undercity's housing list is already very long.",
	"Stay among the living a little longer, {name}.",
	"Stay away from da voodoo, {name}. Except this one. This one's fine.",
	"Stay close, {name}. A haranir needs something to guard, and today it's you.",
	"Stay close, {name}. The whispers are much quieter in company.",
	"Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful.",
	"Stay in formation, {name}. We haven't got one, but stay in it anyway.",
	"Stay near, {name}. I lost a world once; I'm keeping hold of this party.",
	"Stay off the moors after dark, {name}. Take this.",
	"Stay out of the Plaguelands if you can, {name}. Go well armed if you can't.",
	"Stay sharp, {name}. Take this with ya.",
	"Stay together, {name}, like dumplings in a steamer. Warm, and ready.",
	"Stay with the warband, {name}. Strength in numbers. And in axes.",
	"Stone and hammer keep ye, cousin {name}!",
	"Such courtesy does you credit, {name}. Nearly as much as it does me.",
	"Such warmth, for one so cold? Returned in full, {name}.",
	"Suramar's children shine together again, {name}.",
	"Sure thing, {name}. Hold still; mojo hates a movin' target.",
	"Sure, {name}! Let me dig it out... rope, rocks, a nice rock... here it is!",
	"Take it, {name}, I've a spare. I've three spares of everything.",
	"Take this, {name}, and may Aln'hara be with you.",
	"Take this, {name}, from a long way below. The roots send their regards.",
	"Take this, {name}. A grummle would sell it to you for a luckydo.",
	"Take this, {name}. And perhaps a cup of tea afterward?",
	"Take this, {name}. Any tentacles you see are purely decorative.",
	"Take this, {name}. Arcane gifts are wasted on the idle.",
	"Take this, {name}. Elves have centuries to be generous; I've got fifty years.",
	"Take this, {name}. Even a dragon needs allies. Especially one this size.",
	"Take this, {name}. I meant to explain the spell first. Too late now.",
	"Take this, {name}. I'd add bread, but conjured bread tastes of nothing.",
	"Take this, {name}. My people always travel Light.",
	"Take this, {name}. Nature provides, and I'm its errand runner today.",
	"Take this, {name}. The Earth Mother would scold me if I walked past.",
	"Take this, {name}. The Legion is always coming. I'd know.",
	"Take this, {name}. The grave can wait.",
	"Take this, {name}. The storm doesn't know you yet, but I've introduced you.",
	"Take this, {name}. Whatever happens out there is merely a setback.",
	"Tell me when to breathe fire, {name}. And, please, when not to.",
	"Thank ye kindly, {name}! First round's on me when we're back at the forge.",
	"Thank ye, {name}! I'd have been fine without it, mind. But thank ye.",
	"Thank you, {name}! The caravan always repays a kindness. Usually in string.",
	"Thank you, {name}. Aysa would bow, Ji would cheer. I will do both, badly.",
	"Thank you, {name}. Elune smiles on the generous.",
	"Thank you, {name}. Even the wisps glow brighter, and they're hard to impress.",
	"Thank you, {name}. Few give gifts to someone who glows this ominously.",
	"Thank you, {name}. I haven't felt this radiant since... well, this morning.",
	"Thank you, {name}. I'd blush, but the blood stopped reaching my face.",
	"Thank you, {name}. I'd knight you, but apparently I 'need permission'.",
	"Thank you, {name}. I'm deeply moved, and it takes a lot to move a tauren.",
	"Thank you, {name}. If worgen had tails, mine would be wagging.",
	"Thank you, {name}. It would warm my heart, if it still beat.",
	"Thank you, {name}. May the winds guide you.",
	"Thank you, {name}. Returned on swift wings.",
	"Thank you, {name}. Ten thousand years under a dome; I'm still practising that.",
	"Thank you, {name}. The voices approve of you, which is frankly alarming.",
	"Thank you, {name}. Where I come from, a kindness is tended like a root.",
	"Thank you, {name}. You have my gratitude, and my best howl.",
	"Thank you, {name}. You have restored my balance.",
	"Thanks for the buff, {name}!",
	"Thanks, mon! Da spirits smile on ya, {name}.",
	"Thanks, {name}! Consider your account settled in full.",
	"Thanks, {name}! Here's yours back. Well, a new one. Hardly used.",
	"Thanks, {name}! I checked it for fine print. There wasn't any. Weird!",
	"Thanks, {name}! I'd build you a thank-you machine, but it'd explode.",
	"Thanks, {name}! Kindness received, catalogued and returned!",
	"Thanks, {name}. I'd offer a lift in the Exodar, but you've seen how it lands.",
	"The Earth Mother saw your kindness, {name}. She nudged me. Quite hard.",
	"The Earth Mother watches over us both, {name}.",
	"The Forbidden Reach feels far behind us now, {name}.",
	"The Legion's been at this world for ten thousand years, {name}. It hasn't won yet.",
	"The Light asks nothing in return, {name}. I, however, accept thanks.",
	"The Light is with you, {name}. Go in peace, or at least go prepared.",
	"The Light rewards kindness, {name}. I'm simply its fastest courier.",
	"The Scourge is always recruiting, {name}. Don't give them the satisfaction.",
	"The Sunwell shines for us both, {name}.",
	"The Titans shaped this world, {name}. Keeping it whole falls to the likes of us.",
	"The curse binds us, {name}, but Gilneas binds us tighter.",
	"The dead keep terrible hours, {name}. Nice to have company for once.",
	"The dome kept us safe, {name}. Now we must make do with one another. Gladly.",
	"The herd moves together, {name}. Mind my hooves; the herd has learned to.",
	"The horn sounds for you, {name}. It used to sound only for the Scourge.",
	"The jinyu say the waters foretold this, {name}. They say that a lot.",
	"The moon's up, {name}. For a kaldorei, this is the middle of the morning.",
	"The naaru would call this a fellowship, {name}. I call it good luck.",
	"The plan, {name}: we hit it. Questions? No? Good plan.",
	"The road ahead is long, {name}. This won't shorten it, but it'll help.",
	"The shadows remember kindness, {name}. So do I.",
	"The sky has a little fury to spare, {name}. Take some.",
	"The sky has no ceiling, {name}. Anything could fall on you. Take this.",
	"The sun has risen, {name}, and so have I. We coordinate.",
	"The world outside the dome is so large, {name}. And so under-enchanted. Here.",
	"This one's on me, {name}.",
	"This one's on the house, {name}. Don't tell the Trade Prince.",
	"Throm-ka, {name}! Honour is repaid.",
	"Throm-ka, {name}! The blood of the clans runs strong in you.",
	"Together we stand, {name}. For the Alliance!",
	"Top-shelf stuff, zero fees, {name}. Today only!",
	"Twenty-five thousand years on the run, {name}. Walking with friends is nicer.",
	"Two haranir out in the world, {name}. No wonder the elders are up in arms.",
	"Up before the tea, {name}? Brave. Here, instead of the tea.",
	"Velen foresaw you asking, {name}. I foresaw saying yes.",
	"Very well, {name}. Stand still, I would hate to singe you.",
	"Walk carefully in the dark places, {name}.",
	"Walk in the Light, {name}. May it shelter you always.",
	"Walk with the Earth Mother, {name}. She's everywhere, so you can't get lost.",
	"Watch the long grass in Stranglethorn, {name}. The panthers are watching you.",
	"We Forsaken must look after each other, {name}.",
	"We go in together, {name}, we come out together. That's the plan, mon.",
	"We have to stop meeting like this, {name}. Actually, no, we don't.",
	"We look after our own, {name}. Always, mon.",
	"We move as one, {name}. Slowly, perhaps, but as one.",
	"We must share a brew when the road allows, {name}!",
	"We once mastered every beast on our mountain, {name}. These won't take long.",
	"We ren'dorei look after our own, {name}.",
	"We split the take even, {name}. I'll do the maths. Trust me.",
	"We vulpera travel by night, {name}. Cool sand, sleepy scorpids.",
	"Wings, fire and scales, {name}, and still you thought I needed help. Touching.",
	"With pleasure, {name}. A kind deed is never wasted.",
	"Word from Harandar, {name}: the haranir are ready to join the fight.",
	"Ya gave me good mojo, {name}. Now ya get some back, extra spicy.",
	"Ya look like somebody who appreciate quality, {name}. Here: quality.",
	"Ya too kind, {name}! This one's from me.",
	"You dropped this, {name}.",
	"You give freely, {name}. I return the favour.",
	"You got it, {name}! Time is money, friend!",
	"You looked like you could use a friend, {name}. I'm a very big one.",
	"You need only ask, {name}. The dead are patient.",
	"You've made a friend for life, {name}. Loyalty is rather our thing.",
	"Your generosity is noted, {name}. In triplicate. Suramar remembers its friends.",
	"Your kindness is noted, {name}. Dragons do not forget.",
	"Your stance says you've had a long day, {name}. Monks notice these things.",
	"{name} \\o",
	"{name}, you look like you need this.",
	"{name}.",
}
RP.OTHER_HASH = {
	[1257712] = 143, [2650649] = 100, [2788810] = 157, [3693110] = 158, [6739775] = 131, [7398612] = 92,
	[7425467] = 4, [7762479] = 328, [8066599] = 30, [10180862] = 42, [10422469] = 331, [15154699] = 1,
	[16134556] = 84, [17900983] = 127, [20075545] = 250, [21275604] = 309, [21798674] = 140, [22358906] = 165,
	[22481666] = 65, [22774299] = 96, [26098017] = 109, [26587171] = 123, [27676140] = 320, [30584287] = 311,
	[32067802] = 199, [35949627] = 315, [38276695] = 150, [38852408] = 243, [39076519] = 87, [40791608] = 28,
	[43740096] = 146, [44333340] = 178, [47050641] = 179, [48121372] = 198, [49109627] = 286, [49901130] = 310,
	[50708038] = 80, [50991313] = 126, [54742705] = 132, [57172643] = 201, [57829973] = 256, [58687549] = 269,
	[60935406] = 334, [61351621] = 296, [62521652] = 189, [62872114] = 323, [63905910] = 211, [64622433] = 111,
	[64859634] = 181, [65364828] = 329, [69014768] = 59, [69022454] = 348, [69122703] = 185, [69470207] = 23,
	[70155693] = 190, [72360037] = 75, [72997857] = 177, [74350629] = 300, [74427613] = 83, [75172503] = 96,
	[76610820] = 261, [77536104] = 195, [78896595] = 96, [81117471] = 34, [88132716] = 347, [90138163] = 318,
	[102459263] = 322, [104062761] = 7, [108849327] = 307, [109960437] = 152, [111238854] = 147, [112789632] = 180,
	[113260480] = 277, [115020422] = 239, [115592487] = 67, [116105059] = 298, [116798001] = 34, [117200310] = 341,
	[118299613] = 116, [118808656] = 126, [119163082] = 230, [119400822] = 155, [121456284] = 181, [122014669] = 233,
	[122230856] = 308, [123649611] = 168, [123663919] = 345, [124492394] = 95, [124503489] = 34, [125084078] = 166,
	[125822618] = 332, [127576685] = 211, [127857374] = 82, [128406580] = 159, [128844417] = 251, [128918281] = 354,
	[131925619] = 219, [134362469] = 128, [134681744] = 15, [137394030] = 232, [137522975] = 317, [139765472] = 297,
	[140368819] = 151, [141532718] = 342, [143629472] = 255, [144289512] = 71, [146511330] = 128, [147047296] = 173,
	[149660900] = 119, [154362536] = 25, [157321985] = 239, [162610247] = 110, [166847199] = 323, [167044651] = 38,
	[167073833] = 338, [167135618] = 228, [168696717] = 13, [174379499] = 327, [175304935] = 326, [177553247] = 307,
	[178308841] = 270, [178956068] = 276, [181419114] = 113, [181991410] = 48, [186596265] = 229, [188898673] = 246,
	[190052505] = 69, [190870802] = 114, [190888053] = 155, [191813834] = 318, [193890905] = 70, [194611347] = 280,
	[195617139] = 184, [195847966] = 72, [196106703] = 102, [196453832] = 161, [201830970] = 152, [202025568] = 347,
	[206253708] = 122, [206357278] = 245, [208127967] = 312, [210033811] = 87, [212283356] = 234, [214639513] = 289,
	[214661278] = 216, [215101491] = 186, [216130395] = 259, [217126264] = 280, [220057581] = 167, [220152650] = 207,
	[221836807] = 124, [222800576] = 304, [223939681] = 255, [224962130] = 245, [226218589] = 3, [227292560] = 329,
	[230390548] = 345, [234908601] = 36, [239352818] = 104, [239673459] = 119, [240962530] = 125, [241340568] = 90,
	[242654459] = 92, [242668324] = 32, [243624568] = 151, [243758013] = 215, [245908871] = 290, [247539585] = 196,
	[247896490] = 76, [250790127] = 254, [251564519] = 57, [253340344] = 242, [255829233] = 180, [256582965] = 279,
	[257002103] = 238, [257575457] = 308, [258462977] = 69, [258858677] = 91, [262337611] = 133, [264467452] = 225,
	[265905182] = 81, [266875469] = 287, [268132565] = 191, [268722269] = 121, [272192671] = 9, [272925804] = 280,
	[276760983] = 303, [276839012] = 20, [278719608] = 313, [278841027] = 185, [279424047] = 338, [280272116] = 155,
	[281711819] = 55, [282210846] = 2, [282281357] = 21, [283032205] = 59, [283073120] = 97, [283443127] = 273,
	[287386589] = 262, [287633404] = 161, [287801488] = 333, [288127992] = 128, [288775558] = 275, [290450555] = 104,
	[292543833] = 102, [293634509] = 245, [294714388] = 40, [295041263] = 23, [296759399] = 265, [296909880] = 107,
	[297619137] = 27, [298110307] = 73, [304039254] = 127, [304703405] = 74, [304877739] = 77, [304975177] = 225,
	[305247071] = 208, [306034546] = 87, [307188983] = 303, [310345653] = 148, [312894890] = 234, [314744736] = 315,
	[317818657] = 50, [317993528] = 120, [319795677] = 111, [321411895] = 132, [323317363] = 337, [323380071] = 154,
	[323420248] = 152, [325154573] = 291, [325229454] = 13, [327963268] = 33, [328465396] = 304, [330039501] = 336,
	[330589186] = 47, [330906229] = 203, [333327395] = 294, [333568287] = 248, [336246901] = 151, [336516816] = 77,
	[336990130] = 165, [337790808] = 111, [338125738] = 106, [340295021] = 160, [342641033] = 302, [343773719] = 154,
	[344546400] = 278, [346242372] = 80, [348896335] = 308, [349824412] = 75, [351525682] = 153, [352690908] = 318,
	[354605729] = 3, [355927955] = 35, [356760405] = 126, [357197598] = 183, [357469596] = 293, [357692271] = 318,
	[362764023] = 15, [363115765] = 133, [369078908] = 228, [369437404] = 162, [371154355] = 223, [371977922] = 10,
	[373174878] = 213, [373475724] = 126, [373911219] = 20, [373988268] = 7, [376398533] = 160, [376530652] = 2,
	[378919873] = 2, [382170958] = 321, [383132495] = 155, [385156752] = 46, [385250348] = 130, [387656102] = 92,
	[388351651] = 100, [388866105] = 147, [389579358] = 172, [389679773] = 148, [389948250] = 275, [390732851] = 219,
	[391995398] = 214, [397590146] = 213, [397890433] = 15, [398306549] = 252, [399348087] = 3, [400226251] = 220,
	[400256646] = 221, [400771945] = 192, [401879267] = 115, [402451574] = 332, [403234630] = 192, [404304872] = 37,
	[404710261] = 6, [405703723] = 21, [406063892] = 280, [407228526] = 85, [409071975] = 117, [409309098] = 190,
	[410415062] = 64, [412827179] = 72, [413440966] = 309, [417499929] = 178, [419331454] = 87, [419900461] = 7,
	[420743732] = 55, [422933749] = 145, [423351311] = 166, [423556843] = 51, [423943603] = 144, [426681076] = 28,
	[426812082] = 260, [428097045] = 226, [429203519] = 84, [435196951] = 65, [436839351] = 106, [437449716] = 190,
	[437978442] = 85, [438707536] = 110, [442152246] = 251, [443897978] = 344, [445297092] = 142, [445345713] = 103,
	[449356617] = 175, [449938165] = 243, [450105699] = 203, [451322581] = 106, [451377611] = 211, [452605458] = 235,
	[454387409] = 25, [454798498] = 220, [460166694] = 159, [469312104] = 157, [471588014] = 329, [472420576] = 79,
	[472522905] = 43, [473034490] = 18, [474622399] = 338, [474651415] = 111, [476674272] = 78, [478038685] = 266,
	[479794606] = 153, [480911143] = 209, [481918936] = 212, [482550060] = 267, [484138181] = 261, [485181371] = 215,
	[486224275] = 41, [486747962] = 138, [486790523] = 267, [487627634] = 288, [488550641] = 133, [490822636] = 122,
	[491701801] = 192, [493394062] = 36, [495263478] = 3, [495507245] = 9, [498112626] = 208, [501666924] = 235,
	[501911702] = 110, [501974987] = 129, [503284546] = 149, [504750198] = 340, [507283244] = 310, [508018945] = 286,
	[509394808] = 169, [513263939] = 37, [514377179] = 202, [514777850] = 247, [515144973] = 249, [517793126] = 128,
	[517992386] = 163, [519234715] = 134, [521321770] = 99, [521489848] = 181, [521882070] = 233, [521936806] = 341,
	[525944418] = 295, [529552061] = 142, [532001071] = 167, [532632614] = 313, [533290248] = 350, [538627511] = 100,
	[539960839] = 248, [540046559] = 206, [541807427] = 7, [542279334] = 284, [542982037] = 256, [543707680] = 89,
	[544532832] = 329, [548276449] = 48, [548856273] = 58, [552046116] = 177, [552590161] = 206, [553010830] = 105,
	[555187393] = 253, [558382598] = 213, [566291305] = 326, [568787234] = 182, [571883797] = 191, [572390761] = 65,
	[573010573] = 154, [574019749] = 177, [574364236] = 232, [574776594] = 8, [575696193] = 162, [576841026] = 240,
	[577448027] = 41, [581189715] = 157, [581247672] = 218, [584215670] = 181, [585185171] = 15, [587875823] = 21,
	[588278759] = 78, [589253950] = 13, [589361773] = 157, [593038117] = 294, [595327646] = 256, [595365984] = 162,
	[595774967] = 200, [597642187] = 201, [598819208] = 102, [599837036] = 39, [601808460] = 22, [601846226] = 41,
	[605668431] = 324, [607933347] = 224, [608006692] = 196, [608080483] = 226, [610483190] = 218, [611125374] = 225,
	[612306290] = 222, [612363235] = 283, [613324059] = 146, [616720938] = 133, [617228970] = 250, [618236948] = 1,
	[618949710] = 150, [620880082] = 264, [621002243] = 171, [624570933] = 349, [628023288] = 118, [629667242] = 88,
	[630982356] = 202, [631087668] = 74, [632656956] = 98, [634588680] = 42, [635378892] = 173, [636816584] = 195,
	[642444998] = 183, [643373325] = 53, [645220857] = 292, [645604770] = 183, [647048209] = 89, [649860255] = 80,
	[652574623] = 338, [653475617] = 77, [655629449] = 10, [655725939] = 32, [656089676] = 44, [659488315] = 108,
	[662847054] = 191, [665811891] = 180, [666746932] = 323, [667499805] = 134, [671227336] = 295, [673178195] = 56,
	[676556960] = 158, [676795663] = 41, [678115827] = 29, [678473128] = 124, [679361579] = 107, [681803008] = 242,
	[683618912] = 108, [685132757] = 85, [688445131] = 353, [689494953] = 342, [689532728] = 110, [690140479] = 140,
	[690347760] = 103, [693658334] = 101, [693802122] = 86, [694148987] = 52, [696680341] = 311, [697936393] = 194,
	[700008451] = 167, [701895163] = 62, [702315737] = 151, [702886024] = 10, [703093010] = 46, [703158269] = 132,
	[707546992] = 349, [707929522] = 295, [708296553] = 55, [709581009] = 122, [709614677] = 253, [710801364] = 195,
	[714684142] = 27, [715331885] = 163, [715582169] = 350, [715717176] = 257, [715793295] = 259, [716471117] = 331,
	[717504711] = 59, [718615263] = 9, [720941728] = 43, [730142420] = 48, [731411427] = 246, [731419287] = 313,
	[733973285] = 90, [736188716] = 62, [738348258] = 101, [740475648] = 214, [741905229] = 209, [742112504] = 229,
	[742565136] = 97, [743114200] = 95, [744111463] = 180, [745151642] = 12, [746167991] = 250, [748298649] = 175,
	[751568664] = 330, [753603672] = 320, [755124060] = 221, [756011019] = 25, [756506577] = 316, [756591085] = 90,
	[757175274] = 230, [757400923] = 167, [760450734] = 180, [761906654] = 263, [762753088] = 146, [765219583] = 309,
	[765977320] = 114, [769767945] = 266, [770658082] = 182, [774472758] = 144, [776740686] = 40, [778418386] = 141,
	[780286755] = 10, [780712632] = 225, [782427314] = 104, [782535508] = 214, [783152117] = 275, [783727135] = 30,
	[784506244] = 348, [785601958] = 290, [785638072] = 98, [786483965] = 31, [791577929] = 179, [792075589] = 219,
	[792804450] = 112, [794799208] = 38, [795404213] = 144, [795889451] = 214, [797152109] = 49, [797813577] = 204,
	[798230937] = 259, [798485937] = 232, [798892090] = 61, [800096829] = 125, [802061043] = 8, [802402993] = 64,
	[803291860] = 210, [805409818] = 17, [805540986] = 193, [806619591] = 240, [807011822] = 214, [807260228] = 182,
	[808941722] = 193, [809163910] = 278, [809813322] = 57, [812115803] = 288, [816386347] = 82, [816881746] = 282,
	[817847217] = 304, [819319319] = 203, [820319202] = 17, [820818380] = 160, [820927197] = 22, [821578387] = 229,
	[822208312] = 80, [822816368] = 5, [823056477] = 183, [823734937] = 172, [824204569] = 39, [825850715] = 268,
	[826958122] = 223, [827801974] = 101, [831863295] = 75, [832701882] = 84, [837458219] = 195, [839405896] = 180,
	[840091018] = 31, [842551420] = 164, [843446807] = 186, [845181024] = 165, [846271991] = 43, [846551148] = 90,
	[849531115] = 200, [852349773] = 337, [853484023] = 145, [855830482] = 44, [856473688] = 4, [860822859] = 327,
	[862332446] = 108, [863595210] = 45, [865289701] = 343, [865648560] = 138, [869157913] = 120, [870749546] = 129,
	[872419319] = 137, [873282239] = 180, [874272961] = 326, [876897941] = 117, [877076214] = 74, [877094626] = 310,
	[877381589] = 11, [878410050] = 218, [879792623] = 173, [881022774] = 19, [881486740] = 170, [886104425] = 149,
	[887380136] = 160, [889320771] = 139, [890814591] = 19, [890831062] = 326, [891608427] = 168, [895549245] = 290,
	[898174318] = 31, [899894141] = 332, [900005165] = 279, [900268616] = 47, [903771611] = 211, [907576092] = 306,
	[908659558] = 253, [909258248] = 351, [912057189] = 43, [912729155] = 252, [912851765] = 345, [913018253] = 212,
	[917337761] = 294, [917718488] = 308, [917983731] = 78, [922066241] = 258, [927434008] = 169, [932903605] = 73,
	[933712128] = 127, [939700726] = 104, [939724023] = 244, [941295841] = 309, [941944428] = 289, [942608056] = 93,
	[942854282] = 333, [946495131] = 250, [947246113] = 313, [947650507] = 247, [949641174] = 64, [950187111] = 219,
	[951949624] = 10, [951953216] = 230, [953046205] = 201, [956038193] = 188, [958069942] = 291, [958100131] = 157,
	[958237062] = 288, [958556024] = 7, [960134213] = 115, [962791970] = 270, [963726376] = 18, [965820456] = 95,
	[966161183] = 298, [966194367] = 340, [970034843] = 294, [970099034] = 160, [970584921] = 249, [970658774] = 135,
	[973289176] = 258, [973522840] = 122, [977607476] = 246, [977709893] = 266, [978631356] = 223, [980227842] = 82,
	[980551128] = 54, [981329096] = 95, [981689259] = 233, [981798629] = 165, [983616898] = 137, [983864845] = 211,
	[985975296] = 150, [991508705] = 37, [992053175] = 226, [993167969] = 120, [993260607] = 19, [996972565] = 24,
	[998005328] = 186, [998175061] = 281, [999830272] = 161, [999869623] = 101, [1000372873] = 345, [1000920908] = 267,
	[1001828127] = 304, [1003204015] = 288, [1004001797] = 173, [1004167916] = 13, [1005787627] = 185, [1007662944] = 256,
	[1011081525] = 95, [1014236280] = 246, [1018354402] = 285, [1020249333] = 110, [1020955067] = 57, [1022796217] = 63,
	[1025598520] = 107, [1025603970] = 238, [1026617971] = 202, [1029119777] = 91, [1030210568] = 273, [1030506304] = 291,
	[1031957448] = 287, [1032650456] = 115, [1033020460] = 200, [1034860093] = 320, [1035297836] = 1, [1035759260] = 8,
	[1035791950] = 12, [1035809741] = 242, [1036153181] = 293, [1036832404] = 211, [1037713303] = 289, [1038581900] = 292,
	[1039479510] = 233, [1040111796] = 46, [1049128745] = 27, [1049300824] = 324, [1049985283] = 339, [1050303494] = 210,
	[1050632002] = 353, [1053483600] = 28, [1055151401] = 204, [1058746237] = 311, [1058828503] = 38, [1060190435] = 212,
	[1061026485] = 287, [1061505989] = 320, [1062205487] = 231, [1063074299] = 39, [1063204560] = 258, [1064493985] = 51,
	[1065170813] = 169, [1067604364] = 174, [1070459407] = 223, [1073003672] = 228, [1074955812] = 348, [1076434685] = 207,
	[1076767063] = 63, [1077104629] = 94, [1079713633] = 133, [1081199632] = 121, [1083004043] = 260, [1083042499] = 91,
	[1084554553] = 331, [1084818053] = 48, [1085592790] = 110, [1087578319] = 292, [1088111417] = 317, [1091221527] = 295,
	[1092840750] = 279, [1094565832] = 166, [1094769687] = 125, [1096148565] = 52, [1096257053] = 116, [1096749199] = 103,
	[1100380250] = 274, [1100853514] = 263, [1101027264] = 211, [1105304225] = 202, [1108081600] = 319, [1108533260] = 192,
	[1108984786] = 12, [1109378881] = 41, [1109430624] = 259, [1110961243] = 336, [1112028338] = 174, [1113316770] = 23,
	[1114615750] = 96, [1116387633] = 231, [1117233805] = 270, [1117486618] = 40, [1120193795] = 343, [1123199608] = 185,
	[1124027765] = 134, [1125672125] = 57, [1126181827] = 32, [1127553094] = 316, [1129841289] = 330, [1130680048] = 30,
	[1131595194] = 325, [1131738856] = 189, [1133100193] = 179, [1133798907] = 223, [1134335386] = 300, [1135875824] = 309,
	[1136642485] = 187, [1140136716] = 178, [1140526383] = 229, [1141157665] = 296, [1142199261] = 8, [1143131405] = 226,
	[1143204748] = 176, [1144045078] = 72, [1145551521] = 161, [1150628375] = 225, [1150982498] = 61, [1151306824] = 205,
	[1152294519] = 148, [1152976620] = 59, [1157329308] = 282, [1157395469] = 156, [1157439873] = 307, [1160258047] = 115,
	[1160293674] = 157, [1161401581] = 191, [1162240557] = 108, [1162797367] = 269, [1165084813] = 203, [1165358210] = 172,
	[1166410662] = 11, [1168720052] = 37, [1169972221] = 248, [1170135303] = 337, [1171050429] = 136, [1173320561] = 11,
	[1173656854] = 348, [1173881783] = 227, [1174787955] = 4, [1175070171] = 63, [1177457478] = 260, [1178412136] = 52,
	[1180142596] = 276, [1180626803] = 206, [1181842728] = 293, [1182014866] = 93, [1183221550] = 79, [1183390609] = 317,
	[1183538225] = 283, [1185616600] = 47, [1186094057] = 93, [1188161215] = 153, [1191343432] = 271, [1192559660] = 189,
	[1195359637] = 273, [1196531552] = 346, [1199054881] = 321, [1199174033] = 67, [1201232440] = 4, [1205458059] = 191,
	[1206001377] = 139, [1206331960] = 102, [1209274842] = 68, [1212888795] = 4, [1213286761] = 139, [1215632487] = 218,
	[1216957039] = 28, [1217089408] = 269, [1218359066] = 134, [1220167116] = 173, [1223754991] = 130, [1226657045] = 58,
	[1227226481] = 91, [1227413570] = 30, [1228063876] = 317, [1228437715] = 314, [1233806683] = 103, [1235195677] = 128,
	[1236244879] = 135, [1236524659] = 59, [1238081417] = 95, [1238795487] = 26, [1239338584] = 35, [1240090465] = 125,
	[1242242952] = 33, [1242503214] = 172, [1244531032] = 169, [1247337801] = 143, [1247483415] = 134, [1248263366] = 334,
	[1249899916] = 203, [1250282326] = 158, [1251036055] = 180, [1255038070] = 96, [1256448939] = 141, [1256646685] = 5,
	[1257317902] = 185, [1259277062] = 20, [1260038844] = 341, [1260314521] = 77, [1261197186] = 336, [1261848628] = 49,
	[1262863065] = 279, [1263997995] = 219, [1266976619] = 341, [1269117209] = 335, [1269390849] = 238, [1269403446] = 337,
	[1270186005] = 222, [1270978326] = 58, [1271562020] = 247, [1272174000] = 193, [1276731560] = 176, [1278684594] = 258,
	[1279031096] = 164, [1279888659] = 174, [1280551509] = 175, [1280926789] = 136, [1283708770] = 18, [1284472646] = 217,
	[1286516125] = 16, [1292741295] = 12, [1293108129] = 40, [1293926467] = 290, [1296908621] = 85, [1299595076] = 313,
	[1299685720] = 228, [1301966371] = 268, [1302207491] = 333, [1302345180] = 205, [1303340326] = 26, [1304309327] = 291,
	[1307291178] = 204, [1308544175] = 149, [1308755325] = 10, [1309713963] = 115, [1310427610] = 221, [1310984121] = 309,
	[1313350276] = 273, [1313789731] = 109, [1314966104] = 332, [1315613888] = 166, [1316510993] = 339, [1320367047] = 138,
	[1322001238] = 201, [1324162298] = 117, [1324530634] = 2, [1324626923] = 228, [1325671703] = 346, [1326299310] = 119,
	[1336692402] = 9, [1336944237] = 293, [1337077835] = 119, [1341309331] = 51, [1341914091] = 71, [1342515292] = 58,
	[1343934060] = 327, [1344067787] = 123, [1344143063] = 285, [1345368575] = 78, [1345398210] = 22, [1348049792] = 281,
	[1348598027] = 266, [1349099340] = 168, [1349772151] = 121, [1350756187] = 38, [1351685682] = 131, [1351764287] = 345,
	[1352191663] = 151, [1352290345] = 342, [1353873662] = 297, [1354216808] = 108, [1357134629] = 29, [1357525483] = 139,
	[1358442627] = 82, [1359828270] = 307, [1364667123] = 205, [1364804552] = 325, [1365084749] = 321, [1367412856] = 254,
	[1369047227] = 80, [1371029706] = 247, [1371193955] = 268, [1373839533] = 35, [1376086040] = 106, [1378258182] = 33,
	[1385219963] = 265, [1387788435] = 81, [1387958872] = 343, [1388218912] = 6, [1389331994] = 216, [1390685165] = 1,
	[1391872374] = 249, [1394081743] = 37, [1395103851] = 161, [1395562718] = 46, [1396993614] = 19, [1397507958] = 285,
	[1397723446] = 54, [1398994091] = 117, [1401939534] = 260, [1402518644] = 299, [1403858784] = 325, [1405774571] = 327,
	[1406580817] = 261, [1407030746] = 71, [1407269666] = 326, [1408507220] = 116, [1408667051] = 162, [1408718349] = 283,
	[1409320547] = 172, [1410916263] = 170, [1413480250] = 312, [1414993351] = 252, [1417229148] = 153, [1418258422] = 52,
	[1420569579] = 33, [1420818027] = 307, [1421303597] = 288, [1422247722] = 325, [1423943254] = 298, [1424357266] = 230,
	[1424906250] = 163, [1425059406] = 177, [1425302117] = 174, [1426308655] = 15, [1426386864] = 54, [1427007212] = 66,
	[1427101234] = 120, [1427898306] = 205, [1430058086] = 278, [1432381198] = 301, [1432580775] = 44, [1433925367] = 235,
	[1434973327] = 165, [1435952751] = 182, [1436595445] = 303, [1438173983] = 190, [1440789041] = 102, [1442410512] = 16,
	[1444458423] = 74, [1445360344] = 66, [1448552602] = 12, [1450548963] = 158, [1450954350] = 77, [1453251459] = 273,
	[1454656858] = 284, [1456575721] = 49, [1457501669] = 310, [1459975851] = 340, [1460832159] = 71, [1461604352] = 276,
	[1463778596] = 109, [1464063737] = 34, [1464291488] = 201, [1467901944] = 12, [1470862899] = 32, [1470895744] = 74,
	[1474939529] = 254, [1475100228] = 258, [1477677444] = 45, [1477907866] = 21, [1482689220] = 113, [1483344497] = 262,
	[1483616804] = 166, [1484987227] = 106, [1485046431] = 119, [1487047951] = 85, [1487472891] = 302, [1490077765] = 59,
	[1491150385] = 319, [1494824005] = 79, [1497167308] = 121, [1497783732] = 5, [1498346671] = 249, [1498751864] = 312,
	[1500099977] = 10, [1500710160] = 232, [1502522751] = 277, [1505639355] = 156, [1508904690] = 219, [1509655081] = 64,
	[1509803273] = 15, [1509957302] = 278, [1512254826] = 265, [1517663240] = 208, [1518313409] = 123, [1519538198] = 222,
	[1520740173] = 154, [1520799895] = 212, [1520856168] = 347, [1523356967] = 231, [1524423776] = 167, [1524822449] = 114,
	[1524904081] = 107, [1525088709] = 264, [1529651731] = 199, [1529701957] = 149, [1531763282] = 260, [1536666263] = 221,
	[1536836195] = 291, [1537691049] = 296, [1539635659] = 54, [1539714240] = 129, [1541673070] = 301, [1541934283] = 225,
	[1542125114] = 281, [1544690717] = 236, [1546376553] = 336, [1547987166] = 98, [1549202254] = 331, [1549796136] = 197,
	[1550064203] = 56, [1554355524] = 311, [1554972527] = 197, [1555856268] = 234, [1556571555] = 191, [1556984378] = 160,
	[1557433990] = 292, [1557953898] = 341, [1558644162] = 190, [1558971591] = 138, [1560092631] = 146, [1562154025] = 139,
	[1562522567] = 265, [1563851975] = 50, [1563905369] = 37, [1564601164] = 200, [1566399683] = 100, [1567381925] = 144,
	[1568112158] = 100, [1571076186] = 233, [1574088999] = 100, [1574481937] = 14, [1581328771] = 274, [1583607522] = 102,
	[1586890674] = 44, [1586906411] = 19, [1588362636] = 190, [1588868866] = 86, [1589066990] = 196, [1590208426] = 62,
	[1594230830] = 37, [1596901191] = 338, [1598407436] = 3, [1601324644] = 38, [1601429190] = 303, [1601714514] = 282,
	[1604587986] = 296, [1605933376] = 268, [1609243501] = 83, [1609333911] = 234, [1611915487] = 176, [1613316505] = 144,
	[1615002676] = 194, [1620627970] = 164, [1621991209] = 136, [1624023707] = 175, [1625248997] = 186, [1627217601] = 277,
	[1627256574] = 171, [1627276552] = 17, [1628076484] = 72, [1628278115] = 305, [1628457631] = 94, [1631108631] = 339,
	[1631177455] = 114, [1631787475] = 285, [1634110046] = 344, [1634230918] = 204, [1635248045] = 206, [1638150486] = 237,
	[1638457990] = 111, [1640256553] = 176, [1640323351] = 65, [1645052643] = 166, [1646284383] = 320, [1647077179] = 28,
	[1651115990] = 301, [1651808034] = 251, [1654516997] = 344, [1655675539] = 91, [1656627711] = 136, [1656670980] = 72,
	[1657097599] = 39, [1658410932] = 18, [1658732981] = 195, [1659603758] = 323, [1660263865] = 199, [1662171739] = 28,
	[1662402380] = 126, [1662755568] = 152, [1663577673] = 245, [1665088638] = 124, [1666164164] = 169, [1667434208] = 293,
	[1667451219] = 111, [1668761358] = 244, [1669514181] = 351, [1670230662] = 350, [1672870364] = 233, [1673117906] = 324,
	[1676693712] = 347, [1678045459] = 286, [1678149345] = 9, [1681019875] = 89, [1681162983] = 264, [1681369875] = 3,
	[1681403658] = 344, [1681662076] = 99, [1682063034] = 243, [1682135398] = 261, [1683595991] = 9, [1689250111] = 140,
	[1690891714] = 152, [1691481713] = 105, [1693210265] = 104, [1694373097] = 353, [1695803517] = 83, [1695878265] = 97,
	[1698656054] = 127, [1699220598] = 292, [1699719933] = 252, [1704991091] = 185, [1705498337] = 259, [1707288151] = 82,
	[1707309149] = 289, [1708785181] = 293, [1711258643] = 328, [1711872759] = 323, [1713516770] = 143, [1713799330] = 266,
	[1716000731] = 237, [1718965382] = 207, [1719843846] = 196, [1720164011] = 327, [1720934866] = 204, [1722358195] = 298,
	[1722980813] = 284, [1724290901] = 320, [1724629326] = 345, [1724854655] = 118, [1725708342] = 208, [1725882056] = 302,
	[1725925081] = 202, [1727053408] = 263, [1727314724] = 131, [1728370844] = 340, [1728475715] = 71, [1730135852] = 199,
	[1731975409] = 6, [1738005351] = 141, [1738097050] = 296, [1739024562] = 42, [1740524079] = 91, [1745297992] = 8,
	[1746476594] = 76, [1746554391] = 18, [1747859430] = 90, [1748242483] = 331, [1748791630] = 27, [1751525876] = 60,
	[1752410151] = 124, [1754266366] = 254, [1755288385] = 125, [1755695857] = 11, [1755849049] = 238, [1757645112] = 319,
	[1759646316] = 300, [1760448045] = 18, [1760859123] = 343, [1761243477] = 317, [1761872437] = 241, [1763698239] = 65,
	[1767102357] = 121, [1767666062] = 187, [1769899532] = 98, [1770031990] = 90, [1771088814] = 278, [1771233771] = 19,
	[1773373539] = 164, [1774871510] = 249, [1776889411] = 79, [1776970006] = 253, [1780247462] = 133, [1780460430] = 190,
	[1780549130] = 202, [1783348646] = 1, [1783893982] = 251, [1785894709] = 259, [1786261182] = 31, [1790193167] = 229,
	[1791305018] = 146, [1792157765] = 117, [1792238830] = 82, [1794358177] = 178, [1794732371] = 266, [1795772111] = 224,
	[1796941503] = 148, [1798346898] = 126, [1798871310] = 58, [1800577388] = 244, [1802645229] = 142, [1803901363] = 20,
	[1803933988] = 248, [1804092675] = 313, [1807508123] = 124, [1807797046] = 88, [1807988716] = 261, [1808874251] = 25,
	[1810067676] = 114, [1810098223] = 326, [1812137501] = 69, [1814384758] = 304, [1814946516] = 232, [1816549953] = 262,
	[1823620151] = 203, [1824017342] = 180, [1824281485] = 319, [1825014375] = 47, [1826105025] = 294, [1828247815] = 61,
	[1828712371] = 19, [1830085219] = 214, [1832180024] = 97, [1832466421] = 342, [1835907454] = 198, [1837264463] = 251,
	[1837549509] = 86, [1838371281] = 346, [1839263389] = 149, [1840643097] = 254, [1841164496] = 52, [1841973963] = 34,
	[1842054507] = 202, [1843459116] = 94, [1843548180] = 75, [1843736322] = 70, [1844405829] = 286, [1844475888] = 32,
	[1845706479] = 254, [1847627498] = 64, [1847703311] = 286, [1848818152] = 26, [1852036131] = 120, [1852687102] = 326,
	[1852733968] = 245, [1853209436] = 217, [1855428598] = 298, [1856107838] = 174, [1856652108] = 17, [1857515393] = 267,
	[1857648220] = 62, [1860326109] = 35, [1862002506] = 278, [1862339040] = 220, [1865043400] = 126, [1867369259] = 161,
	[1868668168] = 26, [1869384225] = 198, [1869588379] = 227, [1872140669] = 281, [1872334721] = 247, [1873729049] = 146,
	[1874946881] = 75, [1875642658] = 153, [1878034543] = 255, [1878129116] = 290, [1878840411] = 109, [1879668713] = 39,
	[1881135178] = 191, [1881207324] = 36, [1889545476] = 73, [1891128369] = 216, [1891892607] = 151, [1893113426] = 315,
	[1893663688] = 217, [1894840770] = 308, [1896435773] = 255, [1896946342] = 6, [1897487233] = 304, [1898640540] = 114,
	[1901215867] = 172, [1902100148] = 329, [1902206483] = 302, [1903355188] = 93, [1904537109] = 225, [1904849257] = 297,
	[1905328714] = 291, [1906690001] = 75, [1909176902] = 121, [1909662579] = 12, [1913119054] = 176, [1915164823] = 297,
	[1915793558] = 130, [1916417975] = 348, [1918099373] = 297, [1919073149] = 80, [1919924025] = 213, [1920940716] = 271,
	[1921376878] = 262, [1922622277] = 139, [1923092117] = 297, [1925566287] = 187, [1925588361] = 16, [1926307538] = 335,
	[1926803304] = 309, [1927421811] = 193, [1929838992] = 237, [1932176124] = 210, [1933104254] = 226, [1933791492] = 164,
	[1935389813] = 323, [1936413336] = 32, [1938173359] = 311, [1938392557] = 272, [1938630159] = 87, [1940219671] = 237,
	[1940415326] = 71, [1942267602] = 95, [1946783517] = 196, [1949010734] = 133, [1950101074] = 2, [1950367527] = 32,
	[1950937337] = 255, [1952851700] = 322, [1954558163] = 283, [1957203136] = 272, [1957739891] = 243, [1958949741] = 238,
	[1959901934] = 257, [1960308723] = 106, [1962778087] = 137, [1963316401] = 319, [1963421152] = 161, [1966813884] = 121,
	[1968622992] = 4, [1973324311] = 272, [1973548205] = 2, [1976404970] = 313, [1977169993] = 271, [1977224755] = 41,
	[1980418557] = 322, [1981112453] = 34, [1981949710] = 89, [1982833265] = 99, [1982837780] = 78, [1984593668] = 165,
	[1985767584] = 324, [1985913268] = 55, [1986886648] = 143, [1987669226] = 167, [1988090099] = 276, [1988187100] = 160,
	[1989379037] = 241, [1992408673] = 215, [1998614326] = 232, [2000185330] = 139, [2000296257] = 175, [2001016501] = 169,
	[2001019467] = 277, [2004553609] = 13, [2005648325] = 209, [2007893794] = 49, [2008887393] = 76, [2009982212] = 305,
	[2010191238] = 351, [2012725271] = 8, [2017003367] = 340, [2019924315] = 272, [2021583117] = 53, [2022942614] = 343,
	[2023260166] = 240, [2023732173] = 270, [2024363910] = 299, [2024663184] = 235, [2025020971] = 161, [2025481566] = 106,
	[2027119643] = 131, [2028780615] = 317, [2028873451] = 75, [2028881529] = 266, [2029010968] = 330, [2030512647] = 28,
	[2031493937] = 290, [2032474245] = 261, [2032875693] = 135, [2035072574] = 125, [2035179925] = 147, [2036157350] = 74,
	[2036944589] = 333, [2041386341] = 350, [2041773916] = 7, [2043471955] = 30, [2043513814] = 231, [2043534669] = 260,
	[2046572188] = 62, [2047898330] = 21, [2048597955] = 228, [2049670495] = 40, [2050293814] = 220, [2052242849] = 259,
	[2053980976] = 142, [2054075497] = 241, [2056359856] = 276, [2057151322] = 132, [2057505158] = 172, [2058017156] = 301,
	[2058213173] = 331, [2059193078] = 258, [2059472395] = 31, [2060712464] = 57, [2063464541] = 79, [2064929863] = 293,
	[2067216822] = 200, [2069743511] = 299, [2072582566] = 242, [2074440778] = 179, [2074501289] = 116, [2075345924] = 210,
	[2077674991] = 226, [2078293713] = 186, [2078687857] = 348, [2080098367] = 126, [2080752977] = 83, [2080811505] = 244,
	[2084440926] = 150, [2086890406] = 149, [2087001442] = 124, [2087794960] = 10, [2092263280] = 263, [2093005829] = 206,
	[2093652334] = 179, [2094350771] = 220, [2094581668] = 269, [2095212640] = 158, [2095393746] = 153, [2096702513] = 256,
	[2097741920] = 227, [2100390046] = 121, [2105292242] = 92, [2105376187] = 268, [2107754392] = 29, [2112436365] = 196,
	[2113569080] = 5, [2114444678] = 127, [2114627706] = 288, [2121181297] = 32, [2121971035] = 104, [2122207463] = 145,
	[2124388225] = 335, [2127071893] = 12, [2130358241] = 14, [2131738373] = 8, [2131865141] = 305, [2132108619] = 151,
	[2132452974] = 250, [2132565349] = 250, [2133058248] = 243, [2133112298] = 270, [2135407499] = 214, [2138300899] = 54,
	[2139722823] = 107, [2141259094] = 195, [2142678360] = 264, [2144024924] = 262, [2147082974] = 303, [2148964941] = 18,
	[2152085784] = 157, [2152930568] = 120, [2153077231] = 171, [2153386929] = 125, [2154925510] = 307, [2156283240] = 60,
	[2156391930] = 80, [2157593073] = 229, [2161149277] = 284, [2162174516] = 259, [2164253893] = 188, [2165212171] = 108,
	[2165487278] = 351, [2165836932] = 328, [2165870710] = 221, [2166111208] = 280, [2168597523] = 14, [2169090431] = 45,
	[2170476476] = 9, [2171676074] = 25, [2172458745] = 24, [2174669273] = 22, [2174753445] = 142, [2175455275] = 118,
	[2178496597] = 320, [2178999023] = 65, [2179401551] = 207, [2179470395] = 306, [2183148657] = 207, [2184540389] = 81,
	[2185891544] = 332, [2187264678] = 256, [2187893643] = 280, [2188550884] = 296, [2189098859] = 314, [2190062816] = 238,
	[2191129326] = 340, [2192745620] = 49, [2192914146] = 123, [2196676833] = 49, [2197149509] = 51, [2198407616] = 84,
	[2201449054] = 93, [2202673751] = 47, [2203795728] = 170, [2204688935] = 132, [2205090556] = 243, [2205939573] = 318,
	[2206239712] = 182, [2206724011] = 338, [2207212170] = 156, [2209204620] = 341, [2209424172] = 239, [2210177530] = 239,
	[2212351959] = 101, [2213657221] = 334, [2214372058] = 201, [2214650862] = 191, [2216962132] = 263, [2217224304] = 244,
	[2219566856] = 321, [2221975620] = 22, [2223219033] = 347, [2223536432] = 305, [2226428263] = 280, [2226564557] = 106,
	[2227055631] = 278, [2227250399] = 241, [2229077983] = 264, [2229709441] = 71, [2230002616] = 268, [2230602981] = 206,
	[2232964763] = 70, [2233522537] = 255, [2234064154] = 24, [2234127192] = 3, [2236299533] = 69, [2237607945] = 40,
	[2238905790] = 194, [2241645008] = 26, [2242007641] = 292, [2242399278] = 241, [2249937662] = 130, [2254360419] = 333,
	[2254659836] = 104, [2255636868] = 79, [2257898239] = 254, [2262694945] = 255, [2264186233] = 29, [2265126825] = 182,
	[2270657110] = 252, [2270761885] = 342, [2270819754] = 251, [2272356006] = 268, [2273337552] = 134, [2276422689] = 194,
	[2277277873] = 254, [2279575991] = 58, [2281242496] = 324, [2281303471] = 271, [2282229937] = 218, [2286251965] = 286,
	[2287123443] = 166, [2287826707] = 235, [2288553041] = 213, [2290357168] = 299, [2293967761] = 27, [2299445730] = 163,
	[2299475711] = 14, [2303120102] = 33, [2303754113] = 200, [2303880944] = 227, [2304322738] = 262, [2307170215] = 10,
	[2308489969] = 137, [2310252132] = 68, [2314941081] = 162, [2315521958] = 4, [2315580894] = 73, [2316528993] = 47,
	[2317379158] = 140, [2322712564] = 74, [2324499917] = 227, [2328373379] = 298, [2328885145] = 130, [2331014163] = 252,
	[2331050132] = 335, [2334978848] = 184, [2335328037] = 267, [2335346764] = 70, [2336995885] = 311, [2340068777] = 45,
	[2340667267] = 79, [2341181661] = 147, [2342725490] = 238, [2343261127] = 285, [2344952710] = 188, [2349528723] = 324,
	[2349975121] = 274, [2350757433] = 318, [2351522217] = 163, [2352135411] = 92, [2355799342] = 277, [2356334156] = 50,
	[2357077406] = 237, [2357227953] = 229, [2358790485] = 31, [2360333388] = 230, [2360885919] = 284, [2362223252] = 40,
	[2363259553] = 66, [2365084755] = 119, [2367768149] = 280, [2368385312] = 231, [2370612134] = 11, [2372363678] = 183,
	[2376870710] = 309, [2376962043] = 282, [2377280709] = 87, [2378119393] = 287, [2379347518] = 214, [2381512703] = 334,
	[2387255831] = 260, [2390870980] = 142, [2390887242] = 260, [2392049959] = 1, [2392227448] = 148, [2392987018] = 244,
	[2393422698] = 179, [2399867418] = 150, [2402246581] = 295, [2405468121] = 125, [2406568590] = 342, [2409904011] = 20,
	[2410431859] = 322, [2411176188] = 252, [2411913039] = 344, [2413247805] = 270, [2414437524] = 90, [2416567198] = 349,
	[2417812885] = 36, [2420102316] = 285, [2420851383] = 236, [2423000440] = 187, [2426569116] = 263, [2431203259] = 25,
	[2431204018] = 46, [2435348132] = 217, [2436179063] = 124, [2436556439] = 177, [2436896916] = 339, [2437344203] = 160,
	[2437581599] = 221, [2439428406] = 113, [2439701251] = 20, [2439943203] = 159, [2439988036] = 265, [2441138781] = 143,
	[2442779499] = 61, [2444320747] = 330, [2445794507] = 111, [2447632476] = 89, [2448561749] = 95, [2448999201] = 145,
	[2449832634] = 227, [2450454189] = 174, [2452808146] = 112, [2456160611] = 247, [2456514449] = 328, [2461874552] = 134,
	[2463690051] = 222, [2464577710] = 184, [2470927862] = 168, [2472900739] = 218, [2473983127] = 34, [2475886474] = 219,
	[2475990396] = 170, [2477909753] = 6, [2478189016] = 217, [2479740045] = 5, [2482605692] = 196, [2483388154] = 307,
	[2483592182] = 173, [2484551591] = 181, [2485181401] = 146, [2486783322] = 80, [2487002606] = 282, [2488266830] = 324,
	[2491664645] = 247, [2492432694] = 273, [2494302915] = 331, [2494328891] = 53, [2494399360] = 314, [2494583535] = 274,
	[2496448651] = 44, [2500667815] = 184, [2500710307] = 241, [2503074658] = 308, [2503910745] = 58, [2505839267] = 223,
	[2507150314] = 143, [2508263585] = 172, [2508388701] = 195, [2508931935] = 257, [2509613866] = 99, [2509678304] = 219,
	[2511248827] = 200, [2512363330] = 292, [2513213607] = 253, [2513460586] = 97, [2515672518] = 23, [2517069610] = 293,
	[2518092722] = 98, [2518308813] = 269, [2518689604] = 316, [2519447575] = 137, [2519562582] = 89, [2519872193] = 341,
	[2521107925] = 239, [2522512431] = 165, [2523704987] = 216, [2529397267] = 301, [2529779467] = 170, [2531328530] = 69,
	[2532273269] = 5, [2532339793] = 302, [2536318336] = 42, [2537641877] = 167, [2539055750] = 199, [2540290441] = 217,
	[2540826998] = 136, [2548023563] = 84, [2548518839] = 230, [2548573801] = 78, [2549641415] = 297, [2551038877] = 146,
	[2551450116] = 50, [2552816698] = 201, [2553722720] = 271, [2555781896] = 325, [2556800002] = 276, [2557578725] = 175,
	[2558102088] = 94, [2559487149] = 316, [2560788515] = 246, [2561570643] = 96, [2562351392] = 296, [2562750491] = 47,
	[2563131419] = 104, [2568481511] = 170, [2569104589] = 344, [2571358656] = 163, [2572215659] = 282, [2572658436] = 93,
	[2579356335] = 203, [2580144297] = 100, [2580341438] = 124, [2580513324] = 208, [2581007957] = 94, [2581498112] = 236,
	[2581746267] = 209, [2582365878] = 344, [2582505772] = 24, [2583174142] = 203, [2584045350] = 101, [2586422887] = 77,
	[2587095918] = 116, [2588382606] = 70, [2589112803] = 146, [2589500397] = 67, [2593660304] = 346, [2593784421] = 131,
	[2597388352] = 347, [2599599336] = 351, [2600391781] = 198, [2600634636] = 328, [2601529898] = 30, [2605376686] = 241,
	[2605542875] = 97, [2606850249] = 70, [2608346758] = 303, [2608347177] = 164, [2608389599] = 122, [2609273322] = 136,
	[2609624068] = 184, [2610609045] = 312, [2612959115] = 316, [2613362603] = 275, [2613950819] = 306, [2614161871] = 24,
	[2614608229] = 81, [2616300632] = 107, [2620195338] = 187, [2620227689] = 345, [2621568239] = 351, [2624318286] = 226,
	[2626170427] = 323, [2626510701] = 190, [2627070464] = 240, [2627462485] = 300, [2628247064] = 109, [2629660165] = 91,
	[2630084627] = 42, [2630177856] = 98, [2630534281] = 210, [2635024445] = 94, [2635150071] = 35, [2637081533] = 287,
	[2638183743] = 211, [2638919519] = 189, [2639530786] = 244, [2639907071] = 327, [2640137163] = 221, [2640667162] = 40,
	[2640687964] = 14, [2640926075] = 186, [2641251785] = 147, [2642128642] = 60, [2642372576] = 96, [2643931372] = 74,
	[2645036015] = 271, [2645785023] = 333, [2646430928] = 116, [2649125027] = 212, [2649234125] = 84, [2649802940] = 235,
	[2652941875] = 316, [2653358892] = 285, [2655661638] = 141, [2659285620] = 177, [2659293491] = 295, [2659404582] = 140,
	[2660041658] = 168, [2660475167] = 312, [2660618225] = 99, [2660835411] = 96, [2662544725] = 79, [2665464989] = 76,
	[2666234897] = 185, [2666441693] = 199, [2668753918] = 226, [2668834075] = 63, [2671472858] = 46, [2673287157] = 64,
	[2675357770] = 68, [2679212776] = 17, [2679510939] = 143, [2681066222] = 118, [2681420083] = 334, [2682041502] = 24,
	[2683409454] = 216, [2684818051] = 154, [2687755319] = 73, [2688192022] = 123, [2689331335] = 334, [2689490559] = 234,
	[2689535385] = 292, [2689644617] = 228, [2689906956] = 269, [2690777493] = 30, [2691671336] = 144, [2691858891] = 60,
	[2693987476] = 335, [2695401494] = 314, [2695970305] = 51, [2696149334] = 305, [2696796982] = 23, [2696803749] = 251,
	[2697394416] = 58, [2700366400] = 271, [2700519840] = 5, [2702800086] = 49, [2703477740] = 227, [2704634836] = 63,
	[2705794809] = 109, [2709087745] = 135, [2709693379] = 210, [2712106459] = 38, [2712797905] = 129, [2713761677] = 56,
	[2714714113] = 53, [2716103407] = 197, [2717178957] = 335, [2717758023] = 194, [2720756708] = 132, [2720937150] = 275,
	[2721215239] = 177, [2723729935] = 220, [2726421947] = 46, [2726460319] = 30, [2729308854] = 253, [2730152604] = 104,
	[2732096900] = 12, [2733189353] = 245, [2733733752] = 295, [2734792800] = 278, [2734897538] = 30, [2735438692] = 126,
	[2735627428] = 116, [2735770329] = 231, [2736687795] = 129, [2749857943] = 183, [2750437741] = 36, [2750776075] = 267,
	[2750807893] = 108, [2751363216] = 205, [2751402454] = 22, [2752707334] = 43, [2753064243] = 299, [2753407274] = 318,
	[2753597652] = 282, [2755043151] = 283, [2755364856] = 4, [2755835149] = 248, [2755987429] = 138, [2755997346] = 264,
	[2757572580] = 144, [2757576980] = 274, [2757704961] = 69, [2760443053] = 264, [2760785309] = 215, [2762437064] = 291,
	[2767610052] = 214, [2768716812] = 107, [2768911944] = 262, [2770160761] = 60, [2771665160] = 179, [2772980253] = 66,
	[2774631230] = 239, [2775412987] = 210, [2776369376] = 165, [2777106824] = 194, [2780770753] = 258, [2781408981] = 269,
	[2782073140] = 149, [2782353906] = 295, [2784084284] = 76, [2788576033] = 307, [2790095280] = 236, [2790602900] = 2,
	[2794649205] = 172, [2797651212] = 15, [2801906629] = 209, [2802345855] = 62, [2804878652] = 302, [2806000148] = 23,
	[2806229472] = 76, [2807807952] = 291, [2810930107] = 182, [2812505438] = 86, [2818376012] = 287, [2819561377] = 137,
	[2820711620] = 148, [2820978486] = 246, [2821162385] = 78, [2822572035] = 50, [2822853548] = 6, [2823760319] = 31,
	[2824615267] = 14, [2824870299] = 117, [2825527963] = 103, [2825737416] = 221, [2826528100] = 22, [2828721760] = 98,
	[2829737582] = 343, [2829988336] = 210, [2831859467] = 205, [2833151958] = 353, [2834884084] = 324, [2835803682] = 222,
	[2835961130] = 222, [2836376353] = 335, [2836962017] = 6, [2840186005] = 48, [2840190789] = 3, [2840473890] = 8,
	[2840812814] = 222, [2841452956] = 283, [2841900602] = 333, [2844121094] = 8, [2844846266] = 296, [2846434049] = 99,
	[2846445704] = 269, [2848433285] = 119, [2848893590] = 36, [2850221795] = 234, [2851808134] = 300, [2851818194] = 352,
	[2852628423] = 59, [2853664595] = 78, [2854455551] = 224, [2855395026] = 75, [2855858933] = 54, [2857488240] = 308,
	[2858797136] = 152, [2859247012] = 224, [2859792982] = 243, [2860413236] = 207, [2860538941] = 52, [2863546799] = 109,
	[2864058369] = 223, [2865740774] = 16, [2867064291] = 339, [2868393238] = 284, [2870118425] = 11, [2876273712] = 67,
	[2876311586] = 38, [2876808705] = 29, [2878175544] = 67, [2880300055] = 103, [2881565832] = 334, [2882196665] = 93,
	[2886812066] = 182, [2888379713] = 21, [2888606409] = 196, [2888644843] = 42, [2888832503] = 197, [2891320488] = 117,
	[2892713989] = 215, [2894637645] = 321, [2894672374] = 304, [2896572306] = 313, [2897957592] = 117, [2898003297] = 346,
	[2898717691] = 110, [2899677154] = 150, [2899995494] = 178, [2900303488] = 240, [2903603203] = 217, [2905011030] = 116,
	[2907428328] = 27, [2908741025] = 290, [2908988938] = 79, [2909756120] = 50, [2909973507] = 326, [2911542289] = 329,
	[2915516156] = 337, [2917923385] = 122, [2918285820] = 85, [2923463127] = 89, [2925664566] = 155, [2929147642] = 346,
	[2929270190] = 277, [2930583552] = 215, [2930815980] = 41, [2931475022] = 272, [2937340209] = 39, [2937564066] = 130,
	[2938021106] = 209, [2938188319] = 56, [2940800513] = 224, [2944337503] = 82, [2946319624] = 287, [2946893471] = 101,
	[2948469068] = 235, [2949571091] = 132, [2950594399] = 14, [2951407067] = 36, [2953042598] = 352, [2953256160] = 354,
	[2953547349] = 348, [2958007211] = 62, [2959318606] = 319, [2961096159] = 76, [2961693141] = 301, [2961880527] = 168,
	[2962426990] = 113, [2963951021] = 5, [2965282572] = 257, [2965763078] = 279, [2968473125] = 354, [2968786059] = 21,
	[2970872949] = 14, [2971891877] = 213, [2972413883] = 283, [2973339686] = 313, [2975192269] = 268, [2975536379] = 204,
	[2976019091] = 156, [2976794674] = 150, [2977251863] = 122, [2977778431] = 174, [2978414905] = 80, [2980439878] = 7,
	[2980996006] = 187, [2981203727] = 90, [2981370296] = 153, [2982113531] = 27, [2983432667] = 258, [2984282541] = 224,
	[2985878444] = 261, [2986042292] = 345, [2986335894] = 128, [2986364476] = 306, [2988807605] = 326, [2989677534] = 305,
	[2990496874] = 242, [2993720719] = 346, [2995203658] = 318, [2998031625] = 208, [2998296137] = 63, [2999230935] = 71,
	[2999668200] = 305, [3000840161] = 105, [3004552515] = 42, [3007116394] = 192, [3007282507] = 142, [3007316467] = 283,
	[3009565316] = 171, [3009722153] = 94, [3013027625] = 137, [3013342660] = 217, [3015151178] = 153, [3015514442] = 314,
	[3015760521] = 270, [3016047878] = 348, [3017651416] = 300, [3018453750] = 174, [3018971272] = 159, [3026272626] = 33,
	[3026388913] = 281, [3028894131] = 213, [3029139580] = 286, [3030939569] = 298, [3035086169] = 155, [3037321566] = 59,
	[3040647756] = 283, [3041064829] = 88, [3041406548] = 310, [3042831069] = 339, [3044053122] = 152, [3045954569] = 294,
	[3046369027] = 183, [3052006778] = 299, [3055318950] = 325, [3061332088] = 175, [3063197157] = 232, [3067208629] = 220,
	[3068267092] = 110, [3071806281] = 193, [3073738536] = 69, [3073941855] = 231, [3074102831] = 91, [3075860355] = 236,
	[3077739157] = 334, [3077803418] = 23, [3078551853] = 56, [3082247116] = 198, [3084861654] = 240, [3084880197] = 171,
	[3084974600] = 173, [3087679984] = 289, [3089375113] = 315, [3089938982] = 266, [3090659006] = 100, [3091340384] = 250,
	[3091990512] = 268, [3094193457] = 16, [3094969202] = 290, [3095606990] = 70, [3095624509] = 319, [3097464357] = 7,
	[3099786905] = 128, [3100374952] = 82, [3102112129] = 193, [3102347821] = 135, [3104255994] = 115, [3111857882] = 151,
	[3115220207] = 46, [3120545032] = 53, [3120718235] = 315, [3122564007] = 81, [3124526836] = 48, [3125241311] = 224,
	[3127329510] = 72, [3127706475] = 213, [3127828435] = 189, [3128655142] = 127, [3130445652] = 213, [3132896083] = 93,
	[3132971157] = 53, [3133076559] = 88, [3133653937] = 299, [3134081066] = 293, [3134328291] = 136, [3134710793] = 52,
	[3136934146] = 11, [3140409844] = 306, [3140616228] = 321, [3141697625] = 197, [3143542113] = 18, [3144090742] = 198,
	[3144120212] = 238, [3145290719] = 217, [3148021855] = 165, [3149370802] = 276, [3150254044] = 21, [3151971362] = 184,
	[3152578053] = 68, [3153843025] = 23, [3153975677] = 340, [3154035276] = 188, [3155456837] = 333, [3156310816] = 343,
	[3156665261] = 349, [3158364768] = 241, [3159195230] = 325, [3162000382] = 325, [3162091160] = 105, [3163547154] = 65,
	[3165893478] = 124, [3166165247] = 327, [3167354783] = 132, [3168180411] = 234, [3168913316] = 267, [3170199705] = 319,
	[3171116789] = 73, [3171474932] = 309, [3172172742] = 94, [3173303577] = 328, [3173439053] = 102, [3174045310] = 297,
	[3175609629] = 137, [3176216647] = 275, [3178589696] = 322, [3178969255] = 186, [3180435041] = 76, [3182045787] = 187,
	[3184744600] = 183, [3184948682] = 156, [3186147984] = 97, [3186269982] = 192, [3186719012] = 332, [3187654548] = 55,
	[3188198143] = 215, [3189108062] = 54, [3189648440] = 239, [3190045045] = 176, [3191895661] = 159, [3192935795] = 201,
	[3193174021] = 229, [3198741662] = 134, [3202238590] = 230, [3204033760] = 259, [3204868325] = 114, [3206789064] = 351,
	[3208018723] = 112, [3211661701] = 138, [3213700586] = 279, [3214100619] = 90, [3214810280] = 106, [3214887103] = 344,
	[3216745336] = 336, [3216828780] = 73, [3218067001] = 108, [3218426911] = 256, [3218896556] = 314, [3220756369] = 302,
	[3221781811] = 159, [3228623910] = 205, [3232041020] = 105, [3233834078] = 163, [3235521738] = 37, [3235538422] = 209,
	[3235948876] = 142, [3237781622] = 52, [3240373689] = 88, [3240622044] = 84, [3243538882] = 47, [3246060697] = 317,
	[3246435570] = 61, [3249595094] = 312, [3251497926] = 122, [3253433000] = 350, [3255235072] = 240, [3255573392] = 328,
	[3256085139] = 145, [3256457615] = 57, [3258213031] = 176, [3258233683] = 131, [3259781843] = 219, [3261043431] = 44,
	[3263639532] = 61, [3263755139] = 48, [3263974764] = 269, [3265788690] = 13, [3267314709] = 92, [3269361086] = 207,
	[3269833490] = 248, [3269891171] = 43, [3271390684] = 186, [3271479519] = 194, [3271830110] = 343, [3273355665] = 155,
	[3275723797] = 89, [3277221270] = 66, [3281539396] = 347, [3282226944] = 303, [3288264928] = 148, [3288375833] = 323,
	[3290012212] = 319, [3291881021] = 159, [3293814577] = 289, [3294366581] = 294, [3294926677] = 143, [3297975728] = 24,
	[3299027316] = 9, [3300285335] = 222, [3306786184] = 248, [3309553293] = 279, [3310596643] = 242, [3310916752] = 50,
	[3311084802] = 135, [3311329319] = 25, [3311882203] = 207, [3312764637] = 350, [3313313062] = 1, [3315978186] = 20,
	[3316419223] = 95, [3316738814] = 29, [3318203173] = 242, [3318337384] = 115, [3324400529] = 115, [3325812840] = 149,
	[3326744738] = 325, [3327248699] = 38, [3327375032] = 228, [3327867221] = 26, [3332669128] = 277, [3333442503] = 35,
	[3337123794] = 63, [3337679219] = 279, [3338866774] = 113, [3338902363] = 239, [3338930809] = 88, [3339586018] = 123,
	[3340080201] = 96, [3340316426] = 353, [3341143644] = 113, [3342387280] = 334, [3343330336] = 246, [3345717667] = 63,
	[3345920198] = 116, [3346544028] = 263, [3346551234] = 133, [3346999344] = 303, [3348965967] = 199, [3351444627] = 129,
	[3351509608] = 64, [3352091905] = 107, [3353143239] = 237, [3354624223] = 193, [3357735270] = 257, [3358137605] = 222,
	[3358294054] = 56, [3359105121] = 18, [3359636668] = 245, [3363155148] = 179, [3364116133] = 315, [3366815174] = 137,
	[3367049490] = 135, [3367162210] = 207, [3370724234] = 6, [3372135902] = 26, [3372330646] = 224, [3377153125] = 336,
	[3378435595] = 65, [3378625547] = 138, [3379611071] = 53, [3380620397] = 15, [3380944003] = 93, [3381470071] = 244,
	[3381747510] = 324, [3384582674] = 26, [3384744470] = 311, [3385717104] = 85, [3386528732] = 256, [3390774270] = 24,
	[3391909990] = 81, [3392782482] = 337, [3393737667] = 245, [3393789157] = 43, [3394705723] = 340, [3395258311] = 330,
	[3396590197] = 46, [3397701573] = 24, [3401169778] = 208, [3403155927] = 284, [3403441012] = 254, [3405285978] = 303,
	[3405475996] = 140, [3405524881] = 78, [3405819871] = 112, [3406571938] = 312, [3406884493] = 176, [3408309727] = 246,
	[3411365293] = 289, [3415233454] = 265, [3415297543] = 58, [3418005806] = 67, [3418111819] = 265, [3419636251] = 277,
	[3421791653] = 236, [3422463701] = 305, [3423509401] = 118, [3423629982] = 189, [3424885071] = 175, [3427193117] = 123,
	[3428686322] = 288, [3429492693] = 310, [3430462846] = 102, [3431134778] = 148, [3431663409] = 225, [3433304153] = 230,
	[3433929892] = 66, [3435043648] = 249, [3435397793] = 236, [3436105744] = 184, [3440273717] = 33, [3440280058] = 62,
	[3440796033] = 311, [3442860540] = 314, [3443776202] = 157, [3444008872] = 103, [3444141373] = 197, [3444690053] = 110,
	[3445279831] = 301, [3446346402] = 341, [3451826715] = 86, [3454356524] = 347, [3454369177] = 155, [3455542855] = 330,
	[3460305662] = 25, [3463559136] = 192, [3464193585] = 57, [3464379073] = 73, [3471211102] = 257, [3471981763] = 353,
	[3474814024] = 86, [3476605910] = 338, [3478369083] = 169, [3479868080] = 33, [3480560345] = 76, [3480843815] = 342,
	[3481779644] = 322, [3483805162] = 277, [3484062043] = 306, [3486882290] = 193, [3490736690] = 85, [3492598667] = 149,
	[3492800426] = 339, [3494253057] = 45, [3496060694] = 136, [3498695252] = 133, [3499340814] = 322, [3499652969] = 74,
	[3500112259] = 351, [3500407199] = 173, [3501113940] = 51, [3501504985] = 272, [3502663291] = 61, [3502819604] = 218,
	[3504597040] = 265, [3505957004] = 306, [3507519029] = 54, [3508419498] = 314, [3508792525] = 92, [3509300075] = 81,
	[3511661734] = 285, [3511696144] = 345, [3511698576] = 342, [3513947924] = 301, [3515661870] = 289, [3518293960] = 120,
	[3521693463] = 16, [3523172593] = 105, [3525481260] = 197, [3526598649] = 291, [3529546550] = 2, [3533296458] = 243,
	[3535664786] = 108, [3537323423] = 141, [3538329596] = 192, [3539140613] = 350, [3539207563] = 45, [3539825427] = 310,
	[3540084115] = 114, [3541513470] = 353, [3541976194] = 162, [3542788569] = 1, [3543577048] = 302, [3544513174] = 53,
	[3544536026] = 55, [3545382216] = 135, [3546650537] = 158, [3549981341] = 39, [3550970058] = 261, [3551239474] = 22,
	[3554124538] = 4, [3554612638] = 83, [3554963074] = 178, [3555315503] = 215, [3557462538] = 151, [3558250162] = 128,
	[3558357747] = 257, [3558459476] = 228, [3561380432] = 233, [3563438855] = 167, [3563497230] = 276, [3564607941] = 247,
	[3565475365] = 264, [3566528792] = 298, [3567064025] = 279, [3568318319] = 320, [3569640935] = 206, [3570380863] = 11,
	[3572605540] = 9, [3572876476] = 267, [3573440136] = 72, [3575186963] = 241, [3576129453] = 230, [3576782314] = 302,
	[3577552432] = 1, [3577752730] = 35, [3578792801] = 333, [3583424411] = 299, [3584486144] = 197, [3584665077] = 159,
	[3585135092] = 130, [3586428904] = 140, [3587150236] = 299, [3588877570] = 43, [3589812833] = 274, [3592599694] = 130,
	[3592730126] = 97, [3592945205] = 260, [3593530577] = 256, [3594965647] = 75, [3596567990] = 232, [3596993433] = 198,
	[3597027287] = 223, [3603018104] = 168, [3604244936] = 56, [3606252569] = 155, [3606500246] = 335, [3607343691] = 148,
	[3608678097] = 154, [3609295552] = 21, [3616207956] = 5, [3616211342] = 145, [3617760249] = 112, [3617870773] = 294,
	[3622695380] = 289, [3625133633] = 267, [3626154537] = 50, [3628765607] = 186, [3629496685] = 68, [3630386428] = 253,
	[3631259064] = 20, [3638457310] = 55, [3638920079] = 19, [3641141594] = 304, [3641290000] = 101, [3642360001] = 150,
	[3649271415] = 321, [3650569630] = 60, [3651032198] = 154, [3651078667] = 287, [3651606052] = 109, [3651728151] = 194,
	[3653154542] = 118, [3653773919] = 62, [3654699611] = 44, [3656320872] = 131, [3657230120] = 198, [3657424501] = 200,
	[3659481798] = 253, [3660941273] = 141, [3661463215] = 189, [3663100371] = 103, [3663450118] = 318, [3665651567] = 56,
	[3666591624] = 99, [3667939504] = 87, [3669960319] = 257, [3671797251] = 145, [3673437633] = 338, [3673682209] = 233,
	[3673996241] = 263, [3674980250] = 156, [3676251781] = 61, [3676866092] = 27, [3677753201] = 188, [3679148435] = 68,
	[3679716424] = 77, [3683443238] = 181, [3683637967] = 285, [3684727453] = 141, [3686191963] = 234, [3689873005] = 16,
	[3695760751] = 39, [3696411029] = 127, [3696616077] = 125, [3697026387] = 329, [3697294856] = 351, [3700080991] = 66,
	[3701397318] = 49, [3704012236] = 249, [3704213739] = 113, [3706004420] = 154, [3706884875] = 86, [3707432027] = 314,
	[3709190106] = 118, [3710179070] = 60, [3710603915] = 171, [3711388484] = 69, [3712491497] = 240, [3715893134] = 316,
	[3716288197] = 220, [3716457718] = 67, [3717081578] = 112, [3717365440] = 340, [3718096042] = 350, [3720384323] = 147,
	[3721456319] = 92, [3725037511] = 262, [3725552984] = 310, [3726541418] = 287, [3727469581] = 107, [3727957977] = 13,
	[3728669995] = 346, [3729555452] = 232, [3730747840] = 147, [3731289657] = 218, [3731321024] = 72, [3731405878] = 349,
	[3732589494] = 113, [3734745544] = 118, [3735212862] = 99, [3735875590] = 237, [3736343693] = 174, [3741234584] = 204,
	[3742155641] = 301, [3742168992] = 189, [3742443452] = 19, [3743122172] = 29, [3746360768] = 37, [3746873343] = 169,
	[3751787743] = 170, [3751995643] = 31, [3753474999] = 120, [3753608757] = 240, [3754524459] = 248, [3755494846] = 350,
	[3756213726] = 181, [3759325323] = 244, [3762226216] = 191, [3763688408] = 157, [3766197338] = 150, [3768113260] = 200,
	[3769083378] = 329, [3769368267] = 264, [3769403617] = 330, [3771988995] = 229, [3772936830] = 321, [3776089683] = 102,
	[3778996051] = 347, [3779081005] = 179, [3781370149] = 89, [3782765326] = 349, [3782980193] = 136, [3786963579] = 40,
	[3787606592] = 276, [3788646987] = 205, [3789416821] = 255, [3790899142] = 281, [3793275219] = 262, [3793287701] = 134,
	[3794410858] = 275, [3794715192] = 153, [3797674335] = 252, [3799914506] = 234, [3801710797] = 166, [3807213778] = 35,
	[3807651210] = 72, [3808620942] = 190, [3811980627] = 312, [3812001098] = 166, [3816227221] = 13, [3816563399] = 208,
	[3817825467] = 261, [3818091545] = 105, [3818530276] = 152, [3819548861] = 6, [3819744161] = 14, [3823617082] = 295,
	[3824124864] = 250, [3825506711] = 129, [3827430759] = 111, [3827550707] = 61, [3827870480] = 231, [3828683340] = 51,
	[3828965355] = 43, [3829254492] = 342, [3829382760] = 266, [3831699967] = 51, [3832541371] = 199, [3833119522] = 169,
	[3836457343] = 171, [3837495696] = 158, [3837734078] = 327, [3838669781] = 98, [3839058960] = 218, [3841028362] = 211,
	[3842510579] = 68, [3843920564] = 131, [3844056336] = 29, [3845469760] = 201, [3845492080] = 208, [3846201600] = 349,
	[3847679044] = 159, [3848649442] = 88, [3848746473] = 156, [3849103829] = 307, [3849232473] = 239, [3849340012] = 63,
	[3851274036] = 60, [3853525564] = 164, [3854972913] = 216, [3855958132] = 274, [3856347497] = 162, [3857375270] = 284,
	[3857481620] = 343, [3858448745] = 100, [3859830621] = 224, [3861657812] = 42, [3865314192] = 50, [3868203871] = 339,
	[3870372375] = 271, [3870456092] = 300, [3870773055] = 189, [3871847354] = 320, [3873114268] = 42, [3874279644] = 312,
	[3875422752] = 288, [3876214595] = 69, [3878450355] = 178, [3880661870] = 111, [3882003193] = 212, [3886668387] = 304,
	[3887564694] = 235, [3887752473] = 56, [3887900865] = 94, [3894278447] = 113, [3895502410] = 242, [3896028137] = 194,
	[3897646916] = 337, [3900646304] = 27, [3900993960] = 158, [3902796523] = 119, [3903884537] = 246, [3904209796] = 336,
	[3908160227] = 16, [3911886578] = 231, [3911996518] = 310, [3913747496] = 238, [3913839138] = 187, [3914578848] = 51,
	[3916916978] = 35, [3917695385] = 11, [3917701627] = 160, [3918987124] = 67, [3919835985] = 316, [3920860908] = 216,
	[3921376752] = 306, [3922051813] = 181, [3922382397] = 181, [3927545161] = 49, [3928807725] = 164, [3929627674] = 88,
	[3932598042] = 184, [3933245482] = 84, [3933271296] = 311, [3934103532] = 65, [3934579294] = 77, [3934836536] = 118,
	[3936737392] = 221, [3937500690] = 88, [3937757002] = 317, [3938503886] = 73, [3939117903] = 129, [3940153006] = 235,
	[3941574382] = 296, [3943808221] = 185, [3945397756] = 85, [3946517027] = 44, [3946627718] = 212, [3947350142] = 139,
	[3948506689] = 249, [3948649340] = 120, [3948835784] = 251, [3949576241] = 170, [3949670509] = 237, [3950224321] = 187,
	[3950394247] = 202, [3952804936] = 71, [3953041976] = 117, [3954194819] = 292, [3956457110] = 236, [3956712534] = 344,
	[3959543363] = 199, [3960848675] = 178, [3960900123] = 173, [3964868195] = 337, [3966496109] = 286, [3967663760] = 77,
	[3968789717] = 66, [3970356274] = 57, [3971449614] = 327, [3973624367] = 308, [3973785306] = 227, [3975580113] = 328,
	[3978272689] = 55, [3979053642] = 144, [3980221751] = 205, [3983420005] = 98, [3984496333] = 236, [3985730814] = 101,
	[3991202429] = 86, [3992049521] = 48, [3992137583] = 17, [3992256677] = 225, [3993559979] = 70, [3993614635] = 329,
	[3998801319] = 41, [3999397399] = 83, [3999860274] = 36, [4004643552] = 274, [4004981495] = 281, [4005581169] = 270,
	[4007780206] = 70, [4013031963] = 2, [4014508638] = 220, [4014809833] = 209, [4016249592] = 227, [4016506033] = 206,
	[4016936349] = 112, [4017124134] = 203, [4021774734] = 127, [4026397888] = 53, [4028264087] = 83, [4034764778] = 7,
	[4035807984] = 195, [4036074585] = 143, [4036299969] = 54, [4036878753] = 87, [4037079411] = 317, [4039031557] = 142,
	[4039121956] = 175, [4040050783] = 353, [4041199876] = 109, [4041414323] = 281, [4044156018] = 250, [4045463165] = 17,
	[4047205463] = 105, [4048734129] = 288, [4048961467] = 41, [4050319437] = 332, [4050672292] = 188, [4051426647] = 103,
	[4051616254] = 158, [4052450656] = 284, [4054063153] = 135, [4055890525] = 38, [4056307012] = 131, [4060316962] = 210,
	[4062775824] = 349, [4063066572] = 28, [4063563824] = 28, [4064981644] = 13, [4067253510] = 308, [4070590894] = 243,
	[4072405310] = 280, [4074867037] = 145, [4076168289] = 68, [4076577117] = 321, [4076615723] = 52, [4077979835] = 338,
	[4078991404] = 349, [4079606061] = 132, [4080054401] = 273, [4080567911] = 15, [4080898729] = 47, [4081107295] = 29,
	[4081515487] = 164, [4082950760] = 341, [4083579454] = 114, [4083856199] = 330, [4088251069] = 67, [4088638939] = 188,
	[4088714345] = 300, [4088827723] = 258, [4089183475] = 216, [4089468407] = 140, [4091948122] = 34, [4096863380] = 272,
	[4097030363] = 167, [4097627877] = 178, [4099705146] = 252, [4099967099] = 204, [4103906982] = 66, [4105434253] = 147,
	[4105584030] = 32, [4106521560] = 147, [4106522790] = 33, [4106657197] = 170, [4107788451] = 353, [4109292533] = 247,
	[4110306785] = 198, [4110644480] = 119, [4111538109] = 255, [4112298852] = 20, [4113072377] = 141, [4114579224] = 305,
	[4115128252] = 26, [4115642896] = 152, [4115657661] = 171, [4117507375] = 176, [4118422932] = 202, [4118436526] = 330,
	[4118831076] = 273, [4119047898] = 141, [4119321926] = 162, [4119559782] = 81, [4122424858] = 177, [4123587826] = 294,
	[4127127113] = 115, [4128658227] = 138, [4129384219] = 138, [4131198609] = 223, [4132871024] = 204, [4137214689] = 249,
	[4138298989] = 188, [4140632060] = 156, [4140948576] = 316, [4141071041] = 315, [4141216281] = 36, [4141506668] = 97,
	[4141608309] = 212, [4144069623] = 45, [4145268540] = 45, [4145389478] = 242, [4146253646] = 183, [4146696184] = 123,
	[4148211228] = 171, [4148926945] = 290, [4149108369] = 297, [4151553215] = 129, [4151705880] = 331, [4152195396] = 339,
	[4154671665] = 275, [4155256177] = 195, [4155548688] = 263, [4155878431] = 34, [4155955030] = 212, [4158134574] = 83,
	[4158324871] = 196, [4160437485] = 81, [4161391131] = 274, [4165693260] = 281, [4169338486] = 45, [4171402261] = 300,
	[4171514814] = 39, [4171717412] = 298, [4173763752] = 156, [4176850816] = 162, [4178859314] = 154, [4179917763] = 248,
	[4181451382] = 216, [4183272416] = 3, [4184102950] = 86, [4184114435] = 322, [4184532768] = 57, [4184934797] = 92,
	[4185083420] = 206, [4191832078] = 55, [4193165128] = 328, [4194166038] = 209, [4194437757] = 273, [4195917991] = 182,
	[4198699924] = 25, [4199195057] = 128, [4200206719] = 163, [4200949743] = 87, [4200975453] = 336, [4201517171] = 168,
	[4202077519] = 253, [4207082694] = 91, [4207360097] = 286, [4207448350] = 272, [4210939591] = 188, [4211828760] = 83,
	[4212573512] = 130, [4217799282] = 145, [4218158331] = 185, [4221076296] = 177, [4221715615] = 84, [4222004222] = 197,
	[4222121400] = 336, [4222778035] = 331, [4228677710] = 282, [4229333072] = 59, [4231508125] = 278, [4232606725] = 17,
	[4233071491] = 123, [4233796129] = 237, [4234125105] = 332, [4234749083] = 275, [4235469902] = 144, [4236335593] = 245,
	[4237999374] = 323, [4238875304] = 22, [4239436774] = 121, [4242317409] = 64, [4242477243] = 161, [4243885554] = 215,
	[4244034058] = 184, [4246047024] = 140, [4246332608] = 193, [4247894803] = 105, [4248238619] = 322, [4249882346] = 271,
	[4250843594] = 60, [4251068962] = 139, [4253103341] = 265, [4255604911] = 315, [4258217246] = 192, [4258680259] = 306,
	[4258946792] = 44, [4259694191] = 315, [4259839765] = 68, [4260531280] = 272, [4260841400] = 257, [4264623560] = 282,
	[4268894024] = 99, [4270053009] = 226, [4270068436] = 17, [4271226518] = 31, [4274115715] = 16, [4274344233] = 233,
	[4274862175] = 112, [4275492415] = 251, [4276410443] = 270, [4277272201] = 346, [4280734240] = 127, [4281403682] = 64,
	[4282152913] = 82, [4283335873] = 337, [4283993812] = 348, [4284479679] = 163, [4285472214] = 122, [4286959717] = 48,
	[4288745161] = 332, [4291705428] = 168, [4292396491] = 112, [4293386001] = 335, [4294965476] = 23,
}
-- END other-languages

do
	-- The same sum tools/legacy_lines.py makes: 33 times the sum so far plus the
	-- byte, modulo the largest prime under 2^32, exact in Lua's doubles.
	local function LineHash(line)
		local h = 5381
		for i = 1, #line do h = (h * 33 + line:byte(i)) % 4294967291 end
		return h
	end

	-- The box with each line the addon has in any language as this client reads
	-- it; a line it does not know stays as it is. Never written back: only
	-- compared with this client's sets and examples.
	function RP.InThisLanguage(text)
		local keys, hashes, translated = RP.OTHER_KEYS, RP.OTHER_HASH, ns.L
		return (text:gsub("[^\n]+", function(line)
			local n = hashes[LineHash(line)]
			if n then return translated[keys[n]] end
		end))
	end
end
ns.InThisLanguage = RP.InThisLanguage

-- The pools the examples are drawn from as they read before the lines in
-- RP.LEGACY.reworded were rewritten: a box saved then, by 1.6.4 or by an
-- earlier version, is built from these (RP.Active). Made here, before the
-- thinning below, which thins these as it thins the pools, so that on a
-- client in another language each old line drops out or stays as its
-- translation says, as it did when the box was saved. Never said.
do
	local was = {}
	for _, pair in ipairs(RP.LEGACY.reworded) do was[pair[1]] = pair[2] end
	-- A copy of a pool with a reworded line in it, or of a table of pools;
	-- any other pool is shared. The thinning replaces the pools inside the
	-- tables that hold them, so those are always copied.
	local function Before(tbl)
		local out, copy = {}, false
		for key, value in pairs(tbl) do
			if type(value) == "table" then
				value, copy = Before(value), true
			elseif was[value] then
				value, copy = was[value], true
			end
			out[key] = value
		end
		return copy and out or tbl
	end
	RP.BEFORE = {}
	for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "HISTORY", "PLACE" }) do
		RP.BEFORE[name] = Before(RP[name])
	end
end

-- On a client in another language, a line nobody has translated yet is left
-- out rather than said in English: Locales/Init.lua's English fallback is right
-- for a button and wrong for a line said aloud in /say. A translation is a
-- value its Locales/<code>.lua set on ns.L itself, so rawget finds it where the
-- fallback, in the metatable, is not. Every pool the picking reads is thinned
-- here, at load, so the box's examples, Roll a few and the prompt all keep to
-- the same lines; a pool left with none is taken away and joins no draw (a
-- people with no group lines left speaks its offers, see RP.PoolFor).
-- RP.BEFORE is thinned the same way; RP.LEGACY only recognises, and is left
-- whole.
--
-- A language with no translations at all keeps its English lines: thinned,
-- the set would have nothing left to say.
do
	local locale, translated = ns.LOCALE, ns.L
	if locale ~= nil and locale ~= "enUS" and locale ~= "enGB"
		and type(translated) == "table" and next(translated) ~= nil then
		-- A list of lines (the first entry is one), or a table of such lists.
		local function Keep(tbl)
			if type(tbl) ~= "table" then return tbl end
			if type(tbl[1]) ~= "string" then
				for key, value in pairs(tbl) do tbl[key] = Keep(value) end
				return tbl
			end
			local kept = {}
			for _, text in ipairs(tbl) do
				local key = ENGLISH[text]
				if key ~= nil and rawget(translated, key) ~= nil then kept[#kept + 1] = text end
			end
			if kept[1] == nil then return nil end
			return kept
		end
		for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
			"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO" }) do
			RP[name] = Keep(RP[name])
		end
		RP.BEFORE = Keep(RP.BEFORE)
	end
end

-- How many lines the set can say here, counted once: every pool the pick
-- reads, after the thinning above, so a translated client counts what it
-- will say. What I say names it above the box, which holds only a handful of
-- examples -- a player read those eight lines as all there was (1.5.0).
local lineCount
function RP.Count()
	if lineCount then return lineCount end
	local seen, n = {}, 0
	local function walk(tbl)
		if type(tbl) ~= "table" then return end
		for _, v in pairs(tbl) do
			if type(v) == "string" then
				if not seen[v] then seen[v], n = true, n + 1 end
			else
				walk(v)
			end
		end
	end
	for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
		"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO", "HOME" }) do
		walk(RP[name])
	end
	lineCount = n
	return n
end

-- How much of the draw each pool gets. A pool's share is its weight times
-- the number of its lines that fit, counted up to RP.SPREAD, split evenly
-- between them: a pool of one line is heard a third as often as a full one
-- (a single line said too often grates), and a pool of thirty no more often
-- than one of three, so writing more lines buys variety and never airtime.
--
-- A people's own lines come first, by a long way: a Forsaken should sound
-- Forsaken, a dwarf like a dwarf, in every moment, and above all in a
-- thank-you, the line most players hear. The rare moments made for this very
-- click (somebody met again, a gift to answer, kin, the people's own hour and
-- city) come next, so they are heard when they apply, and of a gift, what it
-- does is said more than its name. The moments that are nearly always true (a
-- place, the hour, the spell, whom you are helping, the speaker's class) weigh
-- little each, since several apply at once, and half that when returning a
-- favour (see RP.Pick). Worked through for full pools: a stranger outdoors at
-- midday hears their people about two times in three, a thank-you for a known
-- spell included (a little less in a busy run, since the memory below skips
-- lines said lately); somebody met a third time hears about it one pick in
-- four. Kin weighs less than the people's lines because a kin pool is small,
-- and a small pool at full weight is heard over and over.
RP.WEIGHT = {
	race = 36, kin = 12, class = 3, faction = 2, general = 1, group = 2,
	spell = 3, trade = 2, gift = 3, history = 17, place = 3, time = 3,
	hour = 8, home = 10, target = 4,
}
RP.SPREAD = 3

-- Lines a language gives a man's voice. The English lines are written for
-- anybody to say ("I'm old, dry and very flammable"); where a language agrees
-- an adjective, a participle or a noun with its speaker, the translation had to
-- pick, and picked the masculine. RP.Pick leaves these out for a woman
-- (UnitSex 3) unless that would leave the pool under RP.SPREAD lines, and says
-- them to everybody else. Keyed by the English line, so a retranslation does not
-- lose its place; esMX reads esES's. Found with tools/audit_i18n_gender.py and
-- read line by line: a line about somebody else, or in a form that does not
-- change with the speaker ("sono felice"), is not one.
RP.MASCULINE = {
	frFR = {
		["Keep the torches clear of me, {name}. I'm old, dry and very flammable."] = true,
		["Hold still, {name}. I've practised on kodo, and they're far less polite."] = true,
		["Thank you, {name}. Somebody had to go first, and I'm glad it was you."] = true,
		["Certainly, {name}. It's this or a lecture on ley lines, and you've been kind."] = true,
		["If I ice-block, {name}, I'm not frozen with fear. I'm frozen on purpose."] = true,
		["Thank you, {name}. My aura just brightened. It does that when I'm touched."] = true,
		["Thank you, {name}. I switched to my grateful stance for that. It's rarely used."] = true,
		["Your {gift} softens every blow, {name}. I'm upholstered."] = true,
		["I'll remember your face now, {name}, and I'm terrible with faces."] = true,
		["If this goes badly, {name}, don't worry. I've died before; it passes."] = true,
	},
	itIT = {
		["Thank ye, {name}. I'd offer me beard as surety, but I'm terrible fond of it."] = true,
		["I was a physician in Lordaeron, {name}. Old habits die harder than I did."] = true,
		["I've outlived everyone I knew, {name}. I'd rather not outlive you. Take this."] = true,
		["Pardon me, {name}. I'm told I lurk. I'm trying to lurk helpfully."] = true,
		["Keep the torches clear of me, {name}. I'm old, dry and very flammable."] = true,
		["Mind the green puddles, {name}. I've seen what they do. I'm what they do."] = true,
		["Night, {name}. The one time nobody can tell I'm pale."] = true,
		["Hold still, {name}. I've practised on kodo, and they're far less polite."] = true,
		["Morning, {name}. Dew on the grass, dew on my fur. I'll be damp till noon."] = true,
		["This late, {name}, only trolls and trouble are up. I'm the nice one."] = true,
		["I heard your horn and swung harder, {name}. Nobody had to tell me twice."] = true,
		["I'm half thunderstorm now, {name}. Thank you, and sorry about the rain."] = true,
	},
	esES = {
		["Nobody else understands the hair, {name}. It was blond once. I think."] = true,
	},
	ptBR = {
		["Dawn, {name}. Rich goblins sleep in. I'm not rich yet."] = true,
		["A spare life in my pocket, {name}. I'll try not to spend it. Thank you."] = true,
		["Thank you, {name}. Death can knock now; I've a key to the back door."] = true,
		["Dying's only a delay with your {gift}, {name}. Thank you."] = true,
		["Thank you, {name}. If the worst happens, I'll get up and say it twice."] = true,
		["Let the next thing roar at me, {name}. I'm not running this time. Thank you."] = true,
		["{gift}! One fright, already dealt with, {name}. Thank you."] = true,
		["Thank you, {name}. The next scream I hear won't be mine."] = true,
		["No running in circles for me, {name}. Not the first time, anyway. Thank you."] = true,
		["Thank you, {name}. Lakes, rivers, puddles: all floors now."] = true,
		["Walking on water, {name}. Folk will start a religion. Thank you."] = true,
		["The murlocs will be furious, {name}. Thank you for the shortcut."] = true,
		["Thank you, {name}. I'll be across before it fades. Probably."] = true,
		["Thank you, {name}. Every lurker around just lost their only trick."] = true,
		["Thank you, {name}. Now I can see what your imp gets up to."] = true,
		["My eyes see more than my wits can handle, {name}. Thank you."] = true,
	},
}

-- How many picks back a line is remembered: one said lately gets no share
-- while any other line still fits, so five people helped in a row hear five
-- different lines. By the line as written, so the same joke to another name
-- still counts. Nothing is saved; a reload forgets.
RP.RECENT = 12

do
	-- The reason on a queue entry to the kind of line it wants. A group member
	-- you target keeps the group lines (the reason says "target", inGroup still
	-- says where they stand: see RP.Pick); the target, nearby and anything new
	-- outside your group get an offer.
	local KIND = { owed = "thanks", asked = "asked", group = "group" }

	local GetTime = _G.GetTime

	-- Our own race, faction and class are ours to read, but through ns.plain
	-- anyway: a secret must never reach a comparison.
	local function Ask(fn, ...)
		if type(fn) ~= "function" then return nil end
		local ok, a, b = pcall(fn, ...)
		if not ok then return nil end
		return ns.plain(a), ns.plain(b)
	end

	-- What the client answers where "no" is an answer too (IsResting says
	-- false, IsInInstance false): known is false when it would not say at
	-- all -- no such function, a throw, or a secret in either answer.
	local function Read(fn, ...)
		if type(fn) ~= "function" then return false end
		local ok, a, b = pcall(fn, ...)
		if not ok then return false end
		local secret = _G.issecretvalue
		if secret and (secret(a) or secret(b)) then return false end
		return true, a, b
	end

	-- A class token that may be compared and used as a key: MAGE, PRIEST.
	local function ClassToken(value)
		value = ns.plain(value)
		if type(value) ~= "string" or #value > 20 or not value:find("^%u+$") then return nil end
		return value
	end

	-- The lines this speaker leaves out: RP.MASCULINE's for a woman, in a
	-- language that has them; nil for everybody else. The sex is the player's
	-- own, which the client always says.
	local function Leaving()
		local code = ns.LOCALE == "esMX" and "esES" or ns.LOCALE
		local list = RP.MASCULINE[code]
		if not list or type(_G.UnitSex) ~= "function" then return nil end
		if ns.plain(_G.UnitSex("player")) ~= 3 then return nil end
		return list
	end

	-- The English a line was read under, for the tests.
	function RP.EnglishOf(text) return ENGLISH[text] end

	-- Which lines of this pool are left out (text -> true), or nil: none are
	-- flagged, or leaving them out would take the pool below RP.SPREAD lines.
	local function LeaveOut(pool, leaving)
		local out, total, n = nil, 0, 0
		for _, text in ipairs(pool) do
			total = total + 1
			if leaving[ENGLISH[text]] then
				out = out or {}
				out[text] = true
				n = n + 1
			end
		end
		if out and total - n < RP.SPREAD then return nil end
		return out
	end

	-- The player's people ("dwarf", or nil for a race with no family), side
	-- ("Alliance", "Horde" or "Neutral") and class token (nil when unknown).
	function RP.Player()
		local _, race = Ask(_G.UnitRace, "player")
		local faction = Ask(_G.UnitFactionGroup, "player")
		if faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end
		local _, class = Ask(_G.UnitClass, "player")
		return RP.FAMILY[race], faction, ClassToken(class)
	end

	-- The lines a table has for this kind of moment; a group member hears the
	-- offers when there are no group lines (a people's at half weight: see
	-- RP.Pick).
	local function PoolFor(tbl, kind)
		if type(tbl) ~= "table" then return nil end
		return tbl[kind] or (kind == "group" and tbl.offer) or nil
	end
	RP.PoolFor = PoolFor

	-- The unit token on the entry, while it still holds the person on it. It
	-- was taken when the queue was built and may since be somebody else, so
	-- their name has to still be on it.
	local function Holding(entry)
		if type(entry) ~= "table" or type(entry.unit) ~= "string" then return nil end
		local ok, name = pcall(ns.UnitFullName, entry.unit)
		if not ok or name == nil or name ~= entry.name then return nil end
		return entry.unit
	end

	-- Whether the person on the prompt is of our people. Their race is often
	-- a secret for a stranger, and then they are not kin as far as anybody
	-- can tell.
	function RP.IsKin(entry, family)
		if not family then return false end
		local unit = Holding(entry)
		if not unit then return false end
		local _, race = Ask(_G.UnitRace, unit)
		return race ~= nil and RP.FAMILY[race] == family
	end

	-- Which RP.TARGET pool the person being helped calls for: "sameclass" for
	-- our own class (RP.Pick then asks RP.SAME first), their class token
	-- otherwise, nil when it is unknown. The queue read their class with their
	-- name; a token still holding them is asked when it did not.
	function RP.Target(entry, mine)
		if type(entry) ~= "table" then return nil end
		local theirs = ClassToken(entry.class)
		if not theirs then
			local unit = Holding(entry)
			if unit then
				local _, class = Ask(_G.UnitClass, unit)
				theirs = ClassToken(class)
			end
		end
		if not theirs then return nil end
		if theirs == mine then return "sameclass" end
		return theirs
	end

	local function SpellName(id)
		local spells = _G.C_Spell
		local name = spells and Ask(spells.GetSpellName, id)
		if name == nil then name = Ask(_G.GetSpellInfo, id) end
		return name
	end

	local function GiftId(entry)
		local owed = ns.owed
		local debt = type(owed) == "table" and type(entry.name) == "string" and owed[entry.name]
		local id = type(debt) == "table" and ns.plain(debt.spell) or nil
		if type(id) ~= "number" then return nil end
		return id
	end

	-- The name of the spell they gave you, for {gift}, or nil when it is not
	-- known. The debt records it (Core's NoteFavour files the spell with the
	-- favour); a debt kept across a reload does not, and gets no trade line.
	-- Roll a few hands in a stand-in as entry.gift.
	function RP.Gift(entry)
		if type(entry) ~= "table" then return nil end
		local name = entry.gift
		if name == nil then
			local id = GiftId(entry)
			if not id then return nil end
			name = SpellName(id)
		end
		name = ns.plain(name)
		if type(name) ~= "string" or name == "" or name:find("[|\r\n]") then return nil end
		return name
	end

	-- The favours no buff of Buffs.lua holds (its favourOnly ids), by every
	-- rank's id: a Soulstone, Fear Ward, Water Walking, Detect Invisibility,
	-- and on retail Unending Breath, which elsewhere is a warlock's buff and
	-- found under BUFF_BY_ID first. 27239 is Burning Crusade's sixth Soulstone.
	local FAVOUR_KEY = {
		[20707] = "soulstone", [20762] = "soulstone", [20763] = "soulstone",
		[20764] = "soulstone", [20765] = "soulstone", [27239] = "soulstone",
		[6346] = "fearward", [546] = "waterwalking",
		[132] = "detectinvis", [2970] = "detectinvis", [11743] = "detectinvis",
		[5697] = "breath",
	}

	-- The buff key of the spell they gave you ("intellect", "thorns"), for
	-- RP.GIFT, or nil: the debt's spell looked up in Buffs.lua's ids, where
	-- any rank or group version of it is filed, or among the favours above.
	-- Roll a few's stand-in hands its key in as entry.giftKey.
	function RP.GiftKey(entry)
		if type(entry) ~= "table" then return nil end
		local key = entry.giftKey
		if key == nil then
			local id = GiftId(entry)
			local byId = ns.BUFF_BY_ID
			local buff = id and type(byId) == "table" and byId[id]
			key = type(buff) == "table" and buff.key or (id and FAVOUR_KEY[id]) or nil
		end
		if type(key) ~= "string" then return nil end
		return key
	end

	-- Where this is, for RP.PLACE: "instance" in a dungeon or raid, "battle"
	-- in a battleground or an arena, "city" while resting (a city or an inn),
	-- "wild" anywhere else outdoors; nil in a scenario, and whenever the client
	-- will not say, since the wilds guessed in an inn read wrong.
	function RP.Place()
		local known, inside, what = Read(_G.IsInInstance)
		if not known then return nil end
		if inside then
			if what == "party" or what == "raid" then return "instance" end
			if what == "pvp" or what == "arena" then return "battle" end
			return nil
		end
		local sure, resting = Read(_G.IsResting)
		if not sure then return nil end
		if resting then return "city" end
		return "wild"
	end

	-- Whether the player stands in their own people's city (RP.HOME), by the
	-- map the client says they are on: false for a people with none, and
	-- whenever the client will not say.
	function RP.Home(family)
		local maps = family and RP.HOME[family]
		local C_Map = _G.C_Map
		if type(maps) ~= "table" or type(C_Map) ~= "table" then return false end
		local known, id = Read(C_Map.GetBestMapForUnit, "player")
		return known and type(id) == "number" and maps[id] == true
	end

	-- Two lists of lines as one pool, so the moment can add to a pool without
	-- adding to its share of the draw; either alone when the other is missing.
	local function Both(a, b)
		if type(a) == "string" then a = { a } end
		if type(b) ~= "table" or b[1] == nil then return a end
		if type(a) ~= "table" then return b end
		local out = {}
		for i = 1, #a do out[i] = a[i] end
		for i = 1, #b do out[#a + i] = b[i] end
		return out
	end

	-- The hour on the realm's clock, for RP.TIME and a people's own hour:
	-- "morning" from five until eleven (5:00 to 10:59), "night" from ten at
	-- night until five (22:00 to 4:59), nil in between and when the client
	-- will not say.
	function RP.Hour()
		local known, hour = Read(_G.GetGameTime)
		if not known or type(hour) ~= "number" then return nil end
		if hour >= 5 and hour <= 10 then return "morning" end
		if hour >= 22 or hour <= 4 then return "night" end
		return nil
	end

	-- How often buffs have passed between the player and each person this
	-- session, for RP.HISTORY: counted from what Core tells the ledger, in memory
	-- only, since "again" is about today's session. A favour counts once when it
	-- arrives and its return completes it; a buff given unasked or asked for
	-- counts once.
	local met = {}        -- [name] = exchanges this session
	local waiting = {}    -- [name] = true while a counted favour is unreturned
	local lastSettle = {} -- [name] = the last settle, for a refusal to take back
	local people = 0      -- names in met, so a long session cannot grow it forever
	local MAX_PEOPLE = 500

	local function Count(name, by)
		if met[name] == nil then
			if people >= MAX_PEOPLE then
				wipe(met)
				wipe(waiting)
				wipe(lastSettle)
				people = 0
			end
			people = people + 1
		end
		met[name] = math.max(0, (met[name] or 0) + by)
	end

	function RP.Heard(event, a, b)
		if event == "Received" then
			-- a = the favour (name, spell, class), b = nothing we cast helps them
			local name = type(a) == "table" and a.name
			if type(name) ~= "string" then return end
			if not waiting[name] then Count(name, 1) end
			if not b then waiting[name] = true end
		elseif event == "Settled" then
			-- a = the name, b = the debt that stood, nil for a buff unasked
			if type(a) ~= "string" then return end
			local gift = not b
			-- A debt kept from before a reload was never counted here.
			if gift or not waiting[a] then Count(a, 1) end
			waiting[a] = nil
			lastSettle[a] = { clock = GetTime(), gift = gift }
		elseif event == "Refused" then
			-- a = the name, b = the stamp on the settle the server refused
			local undo = type(a) == "string" and lastSettle[a]
			if not undo or undo.clock ~= b then return end
			lastSettle[a] = nil
			if undo.gift then Count(a, -1) else waiting[a] = true end
		elseif event == "LetGo" then
			if type(a) == "string" then waiting[a] = nil end
		end
	end

	-- Which RP.HISTORY pool this exchange calls for: "again" for the second
	-- or third this session, "regular" from the fourth, nil for the first. A
	-- thank-you is for a favour already counted; anything else is one more.
	-- Roll a few hands in its own count as entry.met.
	function RP.Familiar(entry, kind)
		if type(entry) ~= "table" then return nil end
		local n = entry.met
		if type(n) ~= "number" then
			local name = entry.name
			if type(name) ~= "string" then return nil end
			n = met[name] or 0
			if not (kind == "thanks" and waiting[name]) then n = n + 1 end
		end
		if n >= 4 then return "regular" end
		if n >= 2 then return "again" end
		return nil
	end

	-- The lines said lately, oldest first, and how many times each is among
	-- them, by the line as written (RP.RECENT). A line counts once a press
	-- carries it (Prompt/Press.lua, OnPostClick), not when it is picked: the
	-- prompt picks a line for its tooltip, and the press can leave it out.
	local lately, latelyCount = {}, {}

	function RP.Remember(text)
		if type(text) ~= "string" then return end
		lately[#lately + 1] = text
		latelyCount[text] = (latelyCount[text] or 0) + 1
		local keep = tonumber(RP.RECENT) or 0
		while #lately > keep do
			local old = table.remove(lately, 1)
			local left = latelyCount[old] - 1
			latelyCount[old] = left > 0 and left or nil
		end
	end

	-- One line for this person, now, with the channel command in front, and
	-- the line as written for RP.Remember; or nil when nothing fits. Every
	-- pool the moment calls for is gathered, each at its share of the draw
	-- (RP.WEIGHT, RP.SPREAD), and every candidate is measured before the roll
	-- rather than after it, so a long name or spell leaves the shorter lines
	-- to choose from instead of silence. A line said in the last RP.RECENT
	-- gets no share while another still fits, and only then: the memory never
	-- silences the set.
	--
	-- entry.lean (Roll a few's context rows) keeps the draw to the pool of
	-- that name, where it has a line that fits. The queue never sets it.
	function RP.Pick(entry, command, budget)
		if type(entry) ~= "table" or type(command) ~= "string" or type(budget) ~= "number" then
			return nil
		end
		local family, faction, class = RP.Player()
		-- Never a stranger's "for the road" to somebody in your own group.
		local kind = KIND[entry.reason] or (entry.inGroup and "group") or "offer"
		local name = entry.short or entry.name
		local single = entry.buff and ns.BuffName(entry.buff)
		local key = type(entry.buff) == "table" and entry.buff.key
		-- {buff} is the spell that goes out: a group cast's own name
		-- (GroupBuffs.lua), which the macro casts.
		local buff = entry.groupCast and ns.EntrySpellName and ns.EntrySpellName(entry) or single
		-- A line that names the single spell outright ("Mark of the Wild,
		-- {name}.") would be wrong under Gift of the Wild, so it sits out.
		local notSaying = entry.groupCast and single ~= buff and single or nil
		local gift = kind == "thanks" and RP.Gift(entry) or nil
		-- "Your Fortitude for my Fortitude" is no trade: like with like, by the
		-- single names on both sides or by the buff, since the favour may have
		-- been the group version (a Prayer of Fortitude, filed under the same
		-- key in Buffs.lua), which is named otherwise.
		if gift ~= nil and (gift == single or (key and RP.GiftKey(entry) == key)) then gift = nil end
		local weight, spread, about = RP.WEIGHT, RP.SPREAD, RP.ABOUT
		local leaving = Leaving()

		local lines, weights, tags, texts, total = {}, {}, {}, {}, 0
		local function add(pool, share, tag)
			if type(pool) == "string" then pool = { pool } end
			if type(pool) ~= "table" or type(share) ~= "number" then return end
			local left = leaving and LeaveOut(pool, leaving)
			local first = #lines + 1
			for _, text in ipairs(pool) do
				-- A line that would say an empty name or spell is left out,
				-- not said with a hole in it.
				local usable = type(text) == "string"
					and (name or not text:find("{name}", 1, true))
					and (buff or not text:find("{buff}", 1, true))
					and (gift or not text:find("{gift}", 1, true))
					and not (notSaying and text:find(notSaying, 1, true))
					-- Nor one about a spell of ours (RP.ABOUT) while another goes out.
					and (about[text] == nil or about[text] == key)
					-- Nor a line this language gives a man's voice, for a woman.
					and not (left and left[text])
				if usable then
					local said = ns.Swap(ns.Swap(ns.Swap(text, "{name}", name), "{buff}", buff), "{gift}", gift)
					said = said:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
					local line = "/" .. command .. " " .. said
					if said ~= "" and #line <= budget then
						lines[#lines + 1] = line
						tags[#lines] = tag
						texts[#lines] = text
					end
				end
			end
			local fits = #lines - first + 1
			if fits == 0 then return end
			local each = share * math.min(fits, spread) / fits
			for i = first, #lines do
				weights[i] = each
				total = total + each
			end
		end

		-- Who is speaking. A people with no group lines speaks its offers to
		-- the group at half weight: some of them are for a stranger on a road.
		-- Its lines about how other peoples take to it are the moment's own
		-- too, for somebody who is not kin, away from home.
		local race = RP.RACE[family]
		local kin = RP.IsKin(entry, family)
		local place = RP.Place()
		local home = place == "city" and RP.Home(family)
		local own = race and race[kind]
		if own then
			local outsider = not kin and not home and race.outsider
			add(Both(own, outsider and outsider[kind]), weight.race, "race")
		else
			add(PoolFor(race, kind), weight.race / 2, "race")
		end
		if kin then add((race and race.kin) or RP.KIN, weight.kin, "kin") end
		local side = RP.FACTION[faction]
		if kind == "group" then
			-- The side's offers are for a stranger on a road: said to the
			-- group only while the side has no group lines to say.
			if side.group then
				add(side.group, weight.group, "group")
			else
				add(side.offer, weight.faction, "faction")
			end
			add(RP.GENERAL.group, weight.group, "group")
		else
			add(PoolFor(side, kind), weight.faction, "faction")
			add(RP.GENERAL[kind], weight.general, "general")
		end
		add(PoolFor(RP.CLASS[class], kind), weight.class, "class")

		-- And the moment. Returning a favour, the pools that do not say thank
		-- you -- the spell, the place, the hour, whoever is helped -- weigh
		-- half, so a thank-you mostly sounds like one.
		local aside = kind == "thanks" and 0.5 or 1
		add(key and RP.SPELL[key], weight.spell * aside, "spell")
		if gift then add(RP.TRADE, weight.trade, "trade") end
		-- Filed with the trade lines, so Roll a few's favour row shows either.
		if gift then add(RP.GIFT[RP.GiftKey(entry)], weight.gift, "trade") end
		add(RP.HISTORY[RP.Familiar(entry, kind)], weight.history, "history")
		-- At home, the people's own city in place of anybody's.
		local city = home and race and race.city
		if city then
			add(city, weight.home, "home")
		else
			add(RP.PLACE[place], weight.place * aside, "place")
		end
		local hour = RP.Hour()
		add(RP.TIME[hour], weight.time * aside, "time")
		add(race and hour and race[hour], weight.hour, "hour")
		-- Whoever is helped, and the spell on a class it does little for: a
		-- spell Buffs.lua marks manaOnly on this client, since Mists' Arcane
		-- Brilliance gives a warrior the same crit it gives a mage.
		local helped = RP.Target(entry, class)
		local them = helped == "sameclass" and RP.SAME[class] or RP.TARGET[helped]
		local onto = key and entry.buff.manaOnly and RP.ONTO[key]
		add(Both(them, onto and onto[helped]), weight.target * aside, "target")
		if total <= 0 then return nil end

		local lean = entry.lean
		if lean ~= nil then
			local leaning = 0
			for i = 1, #lines do
				if tags[i] == lean then leaning = leaning + weights[i] end
			end
			if leaning > 0 then
				for i = 1, #lines do
					if tags[i] ~= lean then weights[i] = 0 end
				end
				total = leaning
			end
		end

		-- Nothing said lately, while anything else is left to say.
		local fresh = 0
		for i = 1, #lines do
			if not latelyCount[texts[i]] then fresh = fresh + weights[i] end
		end
		if fresh > 0 and fresh < total then
			for i = 1, #lines do
				if latelyCount[texts[i]] then weights[i] = 0 end
			end
			total = fresh
		end

		local roll = math.random() * total
		local chosen
		for i = 1, #lines do
			roll = roll - weights[i]
			if roll < 0 then
				chosen = i
				break
			end
		end
		-- Only rounding misses: the last line with any share.
		if not chosen then
			for i = #lines, 1, -1 do
				if weights[i] > 0 then
					chosen = i
					break
				end
			end
		end
		if not chosen then return nil end
		return lines[chosen], texts[chosen]
	end

	-- Line n of a pool, or with names (ENGLISH or ENGLISH_NOW), as it read
	-- before translation; a pool of one line as a plain string has only a
	-- line 1. On a client in another language the pools were thinned at load,
	-- so line n there is the nth translated line, and the box shows no line
	-- the set would not say.
	local function Nth(pool, n, names)
		local text = pool
		if type(pool) == "table" then
			text = pool[n]
		elseif n ~= 1 then
			return nil
		end
		if type(text) ~= "string" then return nil end
		return names and names[text] or text
	end

	-- A list of example lines, and put(pool, now, before) to add a pool's
	-- first lines to it: `now` of them for the box as it is, or with older,
	-- `before` of them (none when not given) for the box as beta.10 to 1.5.0
	-- filled it, one line of each of fewer pools. Players still have that one
	-- saved, and it must still read as the untouched set (RP.Active).
	-- Today's box shows each line once, in case two lines were translated
	-- alike; the older box never checked, and is rebuilt as it was. With
	-- english, today's pools (RP) are put back by the key they were read
	-- under first, the older ones (RP.BEFORE) by the last.
	local function Lines(english, older, pools)
		local names = english and (pools == RP and ENGLISH_NOW or ENGLISH)
		local out, seen = {}, {}
		local function put(pool, now, before)
			for i = 1, older and (before or 0) or now do
				local text = Nth(pool, i, names)
				if text == nil then return end
				if older or not seen[text] then
					seen[text] = true
					out[#out + 1] = text
				end
			end
		end
		return out, put
	end

	-- The box begins with a people's lines and its side's: what a thank-you,
	-- an answer and an offer sound like, then a group and kin. The people's
	-- most, since the set speaks mostly as them; beta.10 to 1.5.0 showed a
	-- line of each, the side's offer and the general group line. A people
	-- with no lines of its own (as the Haranir until 1.7.2) has its side's lines in their
	-- place and the general ones in the side's. From pools, RP or RP.BEFORE.
	local function Head(put, family, faction, pools)
		local race, side, general = pools.RACE[family], pools.FACTION[faction] or {}, pools.GENERAL
		if race then
			put(race.thanks, 4, 1) put(race.asked, 3, 1) put(race.offer, 4, 1) put(side.offer, 2, 1)
			put(race.group, 3) put(side.group, 2) put(general.group, 0, 1) put(race.kin or pools.KIN, 1)
		else
			put(side.thanks, 4, 1) put(side.asked, 3, 1) put(side.offer, 4, 1)
			put(general.thanks, 2, 1) put(general.offer, 2, 1) put(side.group, 3) put(general.group, 2)
		end
	end

	-- Then the set noticing the moment: the class's offers, somebody met
	-- again, a dungeon, and the people's own hours where it has them.
	local function Tail(put, class, family, pools)
		put(PoolFor(pools.CLASS[class], "offer"), 2, 1)
		put(pools.HISTORY.again, 1, 1)
		put(pools.PLACE.instance, 1, 1)
		local race = pools.RACE[family]
		if race then put(race.night, 1) put(race.morning, 1) end
	end

	-- What the phrase box shows for a people, side and class: the first few
	-- lines of their pools, always the same ones, so the box can be
	-- recognised as untouched. With english, the same lines as they read
	-- before translation; with older, the box as beta.10 to 1.5.0 filled it;
	-- with pools, from those (RP.BEFORE) rather than from today's.
	local function Examples(family, faction, class, english, older, pools)
		pools = pools or RP
		local out, put = Lines(english, older, pools)
		Head(put, family, faction, pools)
		Tail(put, class, family, pools)
		return table.concat(out, "\n")
	end
	RP.Examples = Examples

	function RP.Text()
		return Examples(RP.Player())
	end

	-- The five lines beta.9 put in the box for a people and side, from
	-- RP.LEGACY, where they are kept as it saved them.
	local function Frozen(family, faction, english)
		local legacy = RP.LEGACY
		local race, side, general = legacy.race[family], legacy.side[faction] or {}, legacy.general
		local five = race and { race[1], race[2], race[3], side[3], general.group }
			or { side[1], side[2], side[3], general.thanks, general.offer }
		local out = {}
		for i = 1, 5 do
			local text = Nth(five[i], 1, english and ENGLISH)
			if text then out[#out + 1] = text end
		end
		return table.concat(out, "\n")
	end

	local FACTIONS = { "Alliance", "Horde", "Neutral" }
	local lastText, lastAnswer

	-- The boxes the examples have been, each as Lines' older and the pools it
	-- is made of: today's; 1.6.4's, today's box of the lines as they read
	-- before RP.LEGACY.reworded; and beta.10 to 1.5.0's eight, of those lines
	-- too.
	local TODAY = { false, RP }
	local SAVED = { TODAY, { false, RP.BEFORE }, { true, RP.BEFORE } }

	-- Whether text is the examples of any people, side and class, in the
	-- client's language or, with english, as they read before translation;
	-- with older, the boxes earlier versions filled count too: 1.6.4's, the
	-- eight lines of beta.10 to 1.5.0 and beta.9's five. Every class's
	-- examples begin with their people's and side's, so only the classes of a
	-- beginning the text has are tried.
	local function IsExamples(text, english, older)
		local classes = { false }
		for class in pairs(RP.CLASS) do classes[#classes + 1] = class end
		local families = { false }
		for family in pairs(RP.RACE) do families[#families + 1] = family end
		local forms = older and SAVED or { TODAY }
		for _, faction in ipairs(FACTIONS) do
			for _, family in ipairs(families) do
				family = family or nil
				for _, form in ipairs(forms) do
					local out, put = Lines(english, form[1], form[2])
					Head(put, family, faction, form[2])
					local head = table.concat(out, "\n")
					if text:sub(1, #head) == head then
						for _, class in ipairs(classes) do
							if text == Examples(family, faction, class or nil, english, form[1], form[2]) then
								return true
							end
						end
					end
				end
				if older and text == Frozen(family, faction, english) then return true end
			end
		end
		return false
	end

	-- The box with each line that is one of an example's earlier translations
	-- (RP.LEGACY_TRANSLATED) as that line reads now, line by line. A line that
	-- is not one is left as it is, so a box with a line of the player's own in
	-- it still matches no examples.
	local earlier
	local function Modernise(text)
		if earlier == nil then
			earlier = {}
			local byLocale = RP.LEGACY_TRANSLATED
			local set = byLocale and byLocale[ns.LOCALE == "esMX" and "esES" or ns.LOCALE]
			for key, olds in pairs(set or {}) do
				local now = rawget(ns.L, key)
				if now ~= nil then
					for _, old in ipairs(olds) do earlier[old] = now end
				end
			end
		end
		-- A box filled by a client in another language first (RP.OTHER_HASH).
		text = RP.InThisLanguage(text)
		return (text:gsub("[^\n]+", earlier))
	end

	-- Whether "In character" is what speaks. The box is compared with the
	-- examples of every people, side and class, not only this character's: on a
	-- shared profile, the dwarf mage who picked the set has not edited anything
	-- the orc warrior should lose. English examples count too, and the boxes
	-- earlier versions saved (1.6.4's, beta.10 to 1.5.0's eight lines, beta.9's
	-- five), and those with the examples as they were translated then.
	function RP.Active(speech)
		if type(speech) ~= "table" or speech.presetChoice ~= "incharacter" then return false end
		local text = speech.phrases
		if type(text) ~= "string" then return false end
		if text == lastText then return lastAnswer end
		local answer = IsExamples(text, false, true) or IsExamples(text, true, true)
		if not answer then
			local now = Modernise(text)
			answer = now ~= text and IsExamples(now, false, true)
		end
		lastText, lastAnswer = text, answer
		return answer
	end

	-- The load-time repair (Core's ClampSettings) for this set: examples saved in
	-- English, or in an earlier version's shorter box, become this character's
	-- examples as they read now, as the fixed sets' English text does. On an
	-- English client an untouched box of today's is left as it is.
	function RP.Repair(speech)
		if not RP.Active(speech) or IsExamples(speech.phrases) then return end
		speech.phrases = RP.Text()
	end

	-- What each reason is called when Roll a few prints it.
	local ROLL = {
		{ reason = "owed", label = L["Returning a favour:"] },
		{ reason = "asked", label = L["Answering a request:"] },
		{ reason = "group", label = L["In your group:"] },
		{ reason = "nearby", label = L["Offering unasked:"] },
	}
	-- And two moments the set notices, each leaning on the lines written for
	-- it so the row shows one: a favour whose spell is known, and somebody met
	-- for the third time.
	local GIFTED = { reason = "owed", lean = "trade", label = L["Returning a favour of %s:"] }
	local AGAIN = { reason = "nearby", lean = "history", met = 3, label = L["Meeting somebody a third time:"] }
	local AGAIN_OWED = { reason = "owed", lean = "history", met = 3, label = AGAIN.label }

	-- A spell somebody else might have given: the first of these that is not
	-- the one this character gives, named as the client names it, and its key.
	local STAND_INS = { { "PRIEST", "fortitude" }, { "DRUID", "motw" }, { "MAGE", "intellect" } }
	local function StandInGift(buff)
		local mine = buff and ns.BuffName(buff)
		for _, pick in ipairs(STAND_INS) do
			local other = ns.FindBuff(pick[1], pick[2])
			local id = other and other.ranks and other.ranks[1]
			local name = id and SpellName(id)
			if type(name) == "string" and name ~= "" and name ~= mine then return name, pick[2] end
		end
		return nil
	end

	-- Roll a few for this set: a line for each reason speech is on for, since
	-- the set speaks differently for each, then a favour whose spell is known
	-- and somebody met again, all through ns.PickPhrase and the same budget
	-- the cast path measures. Speaking only when returning a favour keeps to
	-- the favours.
	function RP.Roll(somebody)
		local speech = ns.db and ns.db.profile and ns.db.profile.speech
		local only = speech and speech.onlyWhenReturning
		local buff = ns.ResolveBuff(true)
		local gift, giftKey = StandInGift(buff)
		local rows = only and { ROLL[1] } or { ROLL[1], ROLL[2], ROLL[3], ROLL[4] }
		if gift then rows[#rows + 1] = GIFTED end
		rows[#rows + 1] = only and AGAIN_OWED or AGAIN
		for _, row in ipairs(rows) do
			local fake = { short = somebody, name = somebody, reason = row.reason, buff = buff,
				lean = row.lean, met = row.met, gift = row.lean == "trade" and gift or nil,
				giftKey = row.lean == "trade" and giftKey or nil }
			local line = ns.PickPhrase(fake, ns.PhraseBudget(fake))
			local label = row.label
			if row == GIFTED then label = label:format(gift) end
			ns.addon:Print("|cff888888" .. label .. "|r "
				.. (line or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r"))
		end
	end
end

-- On the list after Roleplay, which it is the per-character version of.
ns.PHRASE_SETS.incharacter = {
	label = L["In character"],
	summary = L["an in-character line"],
	text = RP.Text,
}
table.insert(ns.PHRASE_SET_ORDER, 2, "incharacter")
