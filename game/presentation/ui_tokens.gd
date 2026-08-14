class_name UiTokens
extends RefCounted

const VERSION := "phase3-quiet-forge-v3"

const COLOR := {
	"background": Color("0b0e16"),
	"background_depth": Color("211a1b"),
	"surface": Color("171b24e6"),
	"surface_raised": Color("202b3af2"),
	"primary": Color("f4f1e8"),
	"accent": Color("e4b45f"),
	"tone_luminous": Color("2fd4ff"),
	"ding_luminous": Color("ffc45f"),
	"slap_luminous": Color("ff806f"),
	"right_hand_luminous": Color("38d9ff"),
	"left_hand_luminous": Color("ff72b6"),
	"spawn_luminous": Color("9a7cff"),
	"success": Color("8ed3a7"),
	"warning": Color("e8bd72"),
	"error": Color("e78072"),
	"muted": Color("aaa79f"),
	"focus": Color("ffe29b"),
	"disabled": Color("696a6f"),
	"line": Color("777a82")
}

const SPACE := {"xs":5, "sm":10, "md":14, "lg":19, "xl":28, "xxl":38, "page":48}
const FONT_SIZE := {"caption":15, "body":19, "label":22, "title":36, "score":48, "combo":60}
const CORNER := {"control":8, "panel":14, "status":17}
const STROKE := {"hairline":1, "guide":2, "focus":3, "note":5}
const GLOW := {"idle":0.14, "active":0.42, "hit":0.72}
const MOTION_MS := {"hover":90, "status":140, "hit":180, "overlay":220}

static func color(name: String) -> Color:
	return COLOR.get(name, COLOR["primary"])

static func spacing(name: String) -> int:
	return int(SPACE.get(name, SPACE["md"]))
