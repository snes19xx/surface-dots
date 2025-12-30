.pragma library

// hardcoding just for now.
var PROFILE_IMG = "/home/snes/.config/quickshell/snes-hub/profile.jpg"
var PROFILE_NAME = "snes"

var TOP_GAP = 50
var RIGHT_GAP = 10
var PANEL_W = 340
var PANEL_H = 600

// Weather
var WEATHER_CACHE_PATH = "/home/snes/.config/ags/.cache/ags-weather.json"
var WEATHER_SCRIPT_PATH = "/home/snes/.config/ags/script/weather.sh"

// Events
var EVENTS_CMD = "khal list now 1h --json title --json start-time 2>/dev/null || echo '[]'"

// Screenshot
var SNAP_CMD = "command -v grimblast >/dev/null && grimblast --notify copysave area || true"
