class_name StoryData
extends RefCounted
## All original story text for 《天平之誓》.

const PARTY := {
	"linyan": {"name": "林砚", "cls": "swordsman", "lord": true, "bonus": {"hp": 10, "def": 2}, "color": Color(0.36, 0.52, 0.86),
		"title": "林氏少主 · 持秤者"},
	"gelan": {"name": "葛岚", "cls": "lancer", "color": Color(0.62, 0.64, 0.72), "title": "林家老骑士"},
	"suzhi": {"name": "苏芷", "cls": "archer", "color": Color(0.36, 0.66, 0.40), "title": "山林猎户"},
	"wenzhou": {"name": "闻舟", "cls": "mage", "color": Color(0.56, 0.38, 0.78), "title": "游学术士"},
	"baitang": {"name": "白棠", "cls": "healer", "color": Color(0.92, 0.86, 0.70), "title": "渡口医女"},
	"moqi": {"name": "墨七", "cls": "thief", "color": Color(0.30, 0.40, 0.32), "title": "情报贩子"},
}

const PARTY_ORDER := ["linyan", "gelan", "suzhi", "wenzhou", "baitang", "moqi"]

const SPEAKERS := {
	"soldier": {"name": "被俘的鸦卒", "color": Color(0.55, 0.22, 0.24)},
	"tieh": {"name": "铁喙", "color": Color(0.40, 0.30, 0.30)},
}

const DIALOGUES := {
	"prologue": {
		"title": "序章 · 青石渡",
		"bg": "res://assets/bg/ford.png",
		"lines": [
			{"who": "", "text": "澜川边境，青石渡。一条湍急的浅河，将南方的村镇与北方的铁原公国隔开。"},
			{"who": "", "text": "林氏一族世代镇守此地。凡遇大事，族人便取出祠堂里那架古旧的「誓约天平」——同伴各投一枚石子，天平倾向哪一边，众人便走哪一条路。"},
			{"who": "linyan", "text": "葛岚，北面的烟又浓了。"},
			{"who": "gelan", "text": "是铁原的灰鸦军。他们昨夜烧了北岭村，逃难的人正沿着河岸往渡口来。"},
			{"who": "baitang", "text": "难民里有许多伤者和孩子……我的药箱快要见底了。"},
			{"who": "gelan", "text": "少主，渡口开或不开，得由您拿个主意。"},
			{"choice": [
				{"text": "打开渡口，先让所有人活下来。", "virtue": "ren", "reply": "不管来的是谁，先让他们活下去。其余的事，以后再说。"},
				{"text": "逐一盘问，以防灰鸦军混入人群。", "virtue": "zhi", "reply": "灰鸦军最擅混在人群里。谨慎一些，才能护住更多的人。"},
				{"text": "我亲自守在桥头，谁敢作乱就先过我这关。", "virtue": "yong", "reply": "只要我还站在桥上，青石渡就乱不了。"},
			]},
			{"who": "gelan", "text": "……明白了。您的这份心意，天平会记住的。"},
			{"who": "baitang", "text": "我去煮些热汤。至少今晚，大家能睡个安稳觉。"},
		],
	},
	"scout": {
		"title": "第一幕 · 河对岸的影子",
		"bg": "res://assets/bg/ford.png",
		"lines": [
			{"who": "moqi", "text": "哟，林家少主。我带来一个坏消息，和一个更坏的消息。"},
			{"who": "linyan", "text": "墨七？你又从哪里钻出来的。说吧。"},
			{"who": "moqi", "text": "坏消息：灰鸦军的先锋已经摸到了石桥对岸，五六个人，打算趁夜过河。"},
			{"who": "moqi", "text": "更坏的消息：他们点名要渡口交出北岭村的难民。"},
			{"who": "suzhi", "text": "我在对岸林子里看见了他们的弩手。动作很快，是老兵。"},
			{"who": "wenzhou", "text": "石桥狭窄，河水虽浅却会拖慢脚步。抢先占住两岸的高处，便能以少胜多。"},
			{"who": "wenzhou", "text": "另外——从背后或侧面出手，远比正面硬碰有效。若能和同伴把敌人夹在中间，同伴也会顺势追击。"},
			{"who": "linyan", "text": "全员备战。守住青石渡！"},
		],
	},
	"aftermath": {
		"title": "第二幕 · 天平之前",
		"bg": "res://assets/bg/night.png",
		"lines": [
			{"who": "", "text": "夜里，先锋被击退了。众人押着一名俘虏，围坐在祠堂的火盆旁。"},
			{"who": "soldier", "text": "哼……你们赢了一场又如何？统领「铁喙」的主力两日内就到。"},
			{"who": "soldier", "text": "公爵大人只要那群难民。交出来，渡口就能保全。"},
			{"who": "baitang", "text": "把逃命的人交给烧了他们家园的军队？绝不可能。"},
			{"who": "gelan", "text": "那就守。渡口的城寨虽旧，墙还结实，铁喙未必攻得下来。"},
			{"who": "moqi", "text": "或者走。雪岭隘口能通南方的白泽城，只是那条路上……恐怕已经埋伏着灰鸦的斥候。"},
			{"who": "wenzhou", "text": "守，则渡口百姓与难民同处险地；走，则要带着老弱翻越风雪。两条路都不好走。"},
			{"who": "suzhi", "text": "少主，这次怎么定？"},
			{"who": "linyan", "text": "取出誓约天平吧。让每个人投下自己的石子。"},
		],
	},
	"pre_2A": {
		"title": "第三幕 · 雪岭隘口",
		"bg": "res://assets/bg/snow.png",
		"lines": [
			{"who": "", "text": "天平倾向了南方。众人护送难民，在风雪中踏上雪岭。"},
			{"who": "suzhi", "text": "雪地上有新鲜的脚印……我们被盯上了。"},
			{"who": "moqi", "text": "是灰鸦的斥候长「隼目」。那家伙箭法极毒，总爱守在高处。"},
			{"who": "linyan", "text": "击倒隼目，其余斥候便会溃散。为难民杀出一条路！"},
		],
	},
	"pre_2B": {
		"title": "第三幕 · 渡口城寨",
		"bg": "res://assets/bg/ford.png",
		"lines": [
			{"who": "", "text": "天平倾向了渡口。众人连夜加固城寨，将难民安置在后方的祠堂。"},
			{"who": "gelan", "text": "城门已经顶上了。看那面黑旗——铁喙亲自来了。"},
			{"who": "wenzhou", "text": "城墙高处是弓手的天下，千万别让敌人占住。"},
			{"who": "tieh", "text": "林家的小子！交出难民，我便饶你这座破渡口！"},
			{"who": "linyan", "text": "青石渡不交任何人。只要击败铁喙，灰鸦军自会退去——守住这里！"},
		],
	},
}

const VOTE := {
	"question": "灰鸦军主力将至，我们该何去何从？",
	"options": {
		"A": {"name": "翻越雪岭", "desc": "护送难民经雪岭隘口南下白泽城。\n山路险峻，或有斥候埋伏。", "appeal": {"ren": 2, "zhi": 1, "yong": 0}},
		"B": {"name": "固守渡口", "desc": "据守青石渡的城寨，\n正面迎击灰鸦统领铁喙。", "appeal": {"ren": 0, "zhi": 1, "yong": 2}},
	},
	"members": [
		{"id": "gelan", "name": "葛岚", "values": {"ren": 1, "zhi": 1, "yong": 3}, "resolve": 3,
			"quote": "「骑士的长枪，从不向威胁低头。」", "hint": "看重：勇"},
		{"id": "suzhi", "name": "苏芷", "values": {"ren": 2, "zhi": 0, "yong": 3}, "resolve": 2,
			"quote": "「山里的规矩：护好身边的人。」", "hint": "看重：勇、仁"},
		{"id": "wenzhou", "name": "闻舟", "values": {"ren": 1, "zhi": 3, "yong": 1}, "resolve": 3,
			"quote": "「先算清得失，再谈其他。」", "hint": "看重：智"},
		{"id": "baitang", "name": "白棠", "values": {"ren": 3, "zhi": 1, "yong": 0}, "resolve": 3,
			"quote": "「每一条性命都一样重。」", "hint": "看重：仁"},
		{"id": "moqi", "name": "墨七", "values": {"ren": 0, "zhi": 2, "yong": 2}, "resolve": 2,
			"quote": "「活下来的才有资格讲道理。」", "hint": "看重：智、勇"},
	],
	"arguments": {
		"A": {
			"ren": "难民里有老人和孩子，留在渡口只会被战火吞没。",
			"zhi": "渡口无险可守，雪岭虽难行，却能甩开敌军主力。",
			"yong": "穿越风雪比守城更需要胆量——我们敢走这条路。",
		},
		"B": {
			"ren": "若我们离开，渡口的百姓将无人庇护。",
			"zhi": "城寨有墙有门，以逸待劳，胜过在雪中疲于奔命。",
			"yong": "退一步，灰鸦军就会进十步。今天必须在此挡住他们！",
		},
	},
}

const ENDINGS := {
	"A": {
		"title": "终章 · 白泽城的灯火",
		"bg": "res://assets/bg/snow.png",
		"lines": [
			"隼目倒下之后，灰鸦的斥候四散而逃。",
			"三日后，疲惫的队伍终于望见了白泽城的灯火。北岭村的孩子们在城门下堆起了雪人。",
			"青石渡被灰鸦军占去了半年，又在来年春天被夺了回来。",
			"有人说林砚放弃了祖地；也有人说，他守住的是比祖地更重要的东西。",
			"誓约天平依旧悬在林氏祠堂里。它从不替人作出选择——它只记住每一次选择的重量。",
		],
	},
	"B": {
		"title": "终章 · 不落的渡口",
		"bg": "res://assets/bg/ford.png",
		"lines": [
			"铁喙败退，灰鸦军的黑旗在黎明前撤过了河。",
			"青石渡的城门伤痕累累，却始终没有被攻破。难民们在祠堂的屋檐下等到了春天。",
			"铁原公国再未轻易南下。人们开始传说：澜川边境有一座守诺的渡口。",
			"代价同样沉重——城寨里添了许多新坟，林砚亲手为每一座立了碑。",
			"誓约天平依旧悬在林氏祠堂里。它从不替人作出选择——它只记住每一次选择的重量。",
		],
	},
}


static func speaker(who: String) -> Dictionary:
	if PARTY.has(who):
		return {"name": PARTY[who]["name"], "color": PARTY[who]["color"]}
	if SPEAKERS.has(who):
		return SPEAKERS[who]
	return {"name": "", "color": Color(0.6, 0.6, 0.6)}
