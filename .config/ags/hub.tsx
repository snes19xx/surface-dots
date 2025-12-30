#!/usr/bin/env -S ags run

import { For } from "ags"
import { readFile } from "ags/file"
import { Astal } from "ags/gtk4"
import app from "ags/gtk4/app"
import { exec, execAsync } from "ags/process"
import { createPoll } from "ags/time"

import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"

const PROFILE_IMG = "/home/snes/Pictures/j.png"
const PROFILE_NAME = "snes"

const TOP_GAP = 50
const RIGHT_GAP = 10
const PANEL_W = 340
const PANEL_H = 600

/* ---------------- GTK CSS  ---------------- */
const css = `
* { all: unset; font-family: "Manrope V5", "Manrope", "Noto Sans", "JetBrainsMono Nerd Font", sans-serif; }
window.Hub { background: transparent; }

.scrim { background: rgba(0,0,0,0.22); }

.panel {
  background: rgba(20,23,25,0.88);
  border-radius: 24px;
  padding: 12px;
  border: 1px solid rgba(255,255,255,0.06);
  box-shadow: 0 18px 48px rgba(0,0,0,0.45);
}

.card {
  background: #1e2326;
  border-radius: 24px;
  padding: 12px;
  border: 1px solid rgba(255,255,255,0.05);
  box-shadow: 0 10px 26px rgba(0,0,0,0.22);
}
.card + .card { margin-top: 10px; }

/* header (no card) */
.header {
  padding: 2px 4px;
  margin-bottom: 6px;
}
.avatar {
  min-width: 48px; min-height: 48px;
  border-radius: 18px;
  background-size: cover;
  background-position: center;
  border: none;
}
.name { font-size: 18px; font-weight: 800; color: #d3c6aa; }

.chip {
  background: #2d353b;
  border-radius: 999px;
  padding: 5px 10px;
  border: 1px solid rgba(255,255,255,0.06);
}
.chip-icon { font-size: 12px; color: #a7c080; }
.chip-text { font-size: 11px; font-weight: 800; color: #d3c6aa; }

/* -------- Buttons -------- */
.btn-row { margin-top: 6px; }

.qs-btn {
  background: #2d353b;
  color: #d3c6aa;
  min-height: 44px;
  border-radius: 18px;
  border: 1px solid rgba(255,255,255,0.06);
  padding: 6px 0;
  transition: background-color 140ms ease, box-shadow 140ms ease, opacity 120ms ease;
}
.qs-btn:hover { background: #374145; box-shadow: 0 0 0 2px rgba(167,192,128,0.10) inset; }
.qs-btn:active { opacity: 0.92; }

.qs-btn.active {
  background: #a7c080;
  color: #232a2e;
  border-color: rgba(167,192,128,0.9);
  box-shadow: 0 0 18px rgba(167,192,128,0.16);
}

.qs-icon { font-size: 24px; color: inherit; }
.qs-label {
  font-size: 8px;
  font-weight: 800;
  opacity: 0.82;
  letter-spacing: 0.02em;
  color: inherit;
}

/* -------- Sliders (no extra “row outlines”) -------- */
.sliders-box { margin-top: 10px; }
.slider-row { padding: 0; background: transparent; border: none; }

.slider-icon { color: #9da9a0; font-size: 14px; min-width: 16px; }

scale { min-height: 24px; }
scale trough {
  background: #2d353b;
  border-radius: 999px;
  min-height: 24px;
  border: 1px solid rgba(255,255,255,0.06);
}
scale highlight { background: #a7c080; border-radius: 999px; }
scale slider { background: transparent; min-width: 1px; min-height: 1px; }

/* -------- Calendar + weather (MATCH HTML) -------- */
.cal-top-row { }
.cal-left { }
.cal-right { }

.cal-day-name {
  font-size: 24px;          /* ~1.6rem vibe */
  font-weight: 600;
  line-height: 1;
  text-transform: uppercase;
  color: #d3c6aa;
}

.cal-day-num {
  font-size: 52px;          /* ~3.2rem vibe */
  font-weight: 800;
  line-height: 1;
  margin-top: -15px;
  letter-spacing: -1.5px;
  color: #d3c6aa;
}

.weather-row {
  margin-top: 4px;
  color: rgba(157,169,160,0.9);
}
.weather-icon { font-size: 12px; color: #7fbbb3; }
.weather-text { font-size: 12px; font-weight: 600; color: rgba(157,169,160,0.9); }

.cal-month {
  font-size: 15px;
  font-weight: 800;
  letter-spacing: 0.10em;
  margin-bottom: 0px;
  text-transform: uppercase;
  color: #a7c080;
}

.cal-head { font-size: 10px; font-weight: 900; color: rgba(157,169,160,0.8); }

.cal-cell {
  min-width: 14px;
  min-height: 14px;
  border-radius: 4px;
  background: transparent;
  padding: 0;
  margin: 0;
  font-size: 9px;
  font-weight: 700;
  color: rgba(157,169,160,0.9);
}
.cal-cell.today { background: #a7c080; color: #232a2e; font-weight: 900; }

/* -------- Glance -------- */
.glance {
  background: rgba(45,53,59,0.20);
  border-radius: 16px;
  padding: 8px 10px;
  border: 1px solid rgba(255,255,255,0.04);
  margin-top: 10px;
}
.glance-ico { color: #a7c080; font-size: 12px; }
.glance-txt { color: #d3c6aa; font-size: 11px; font-weight: 800; }

/* -------- Notifications -------- */
.notif-title { font-size: 13px; font-weight: 900; color: #d3c6aa; }

.badge {
  background: #2d353b;
  border-radius: 999px;
  padding: 4px 9px;
  border: 1px solid rgba(255,255,255,0.06);
}
.badge-text { font-size: 11px; font-weight: 900; color: #d3c6aa; }

.btn-clear {
  background: rgba(230,126,128,0.10);
  border-radius: 12px;
  padding: 6px 12px;
  border: 1px solid rgba(230,126,128,0.35);
  transition: background-color 120ms ease, opacity 120ms ease;
}
.btn-clear:hover { background: rgba(230,126,128,0.18); }
.btn-clear:active { opacity: 0.92; }
.btn-clear label { color: #e67e80; font-size: 10px; font-weight: 900; }

.notif-item {
  background: #2d353b;
  border-radius: 12px;
  padding: 10px;
  border: 1px solid rgba(255,255,255,0.06);
  transition: background-color 120ms ease, opacity 160ms ease, margin-left 160ms ease;
}
.notif-item:hover { background: #374145; }
.notif-item:active { opacity: 0.92; }
.notif-item.gone { opacity: 0.0; margin-left: -10px; }

.notif-ico {
  min-width: 28px; min-height: 28px;
  border-radius: 999px;
  background: rgba(255,255,255,0.05);
  color: #a7c080;
}
.notif-ico label { font-size: 14px; line-height: 1; margin-top: 0px; }

.notif-app {
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.12em;
  color: rgba(157,169,160,0.85);
}
.notif-msg { font-size: 11px; font-weight: 800; color: #d3c6aa; }

.empty-text {
  font-size: 11px;
  font-style: italic;
  color: rgba(157,169,160,0.75);
  padding: 14px 0;
}

.btn-row > button:nth-child(1) .qs-icon {
  padding-left: 0;
  padding-right: 10px;
}

.btn-row > button:nth-child(2) .qs-icon {
  padding-left: 0;
  padding-right: 0;
}

.btn-row > button:nth-child(3) .qs-icon {
  padding-left: 0;
  padding-right: 4px;
}

.btn-row > button:nth-child(4) .qs-icon {
  padding-left: 0;
  padding-right: 0;
}

.qs-label {
  font-size: 8px;
  font-weight: 400;
  opacity: 1;
  color: inherit;
}
`

/* ---------------- helpers ---------------- */
function sh(cmd: string) { return ["bash", "-lc", cmd] }
function safeAsync(cmd: string) { return execAsync(sh(cmd)).catch(() => {}) }
function safeSync(cmd: string) { try { return String(exec(sh(cmd)) ?? "") } catch { return "" } }

/* ---------------- CPU/RAM ---------------- */
let prevTotal = 0
let prevIdle = 0

const cpuPct = createPoll("0%", 2000, () => {
  try {
    const line = (readFile("/proc/stat").split("\n")[0] || "").trim()
    const parts = line.split(/\s+/).slice(1).map(Number)
    if (parts.length < 4) return "0%"

    const idle = parts[3] + (parts[4] || 0)
    const total = parts.reduce((a, b) => a + b, 0)

    const totald = total - prevTotal
    const idled = idle - prevIdle
    prevTotal = total
    prevIdle = idle

    if (totald <= 0) return "0%"
    const usage = Math.max(0, Math.min(1, 1 - idled / totald))
    return `${Math.round(usage * 100)}%`
  } catch { return "0%" }
})

const ramPct = createPoll("0%", 3000, () => {
  try {
    const mem = readFile("/proc/meminfo")
    const total = Number(/MemTotal:\s+(\d+)/.exec(mem)?.[1] || 0)
    const avail = Number(/MemAvailable:\s+(\d+)/.exec(mem)?.[1] || 0)
    if (!total) return "0%"
    const usage = Math.max(0, Math.min(1, 1 - avail / total))
    return `${Math.round(usage * 100)}%`
  } catch { return "0%" }
})

/* ---------------- WiFi/BT/DND ---------------- */
const wifiOn = createPoll(false, 1500, sh(`nmcli -t -f WIFI g 2>/dev/null | head -n1 || true`), (o) => o.trim() === "enabled")
const wifiSSID = createPoll("WiFi", 2500, sh(`nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print $2; exit}' || true`), (o) => {
  const s = o.trim() || "WiFi"
  return s.length > 9 ? s.slice(0, 9) : s
})

const btOn = createPoll(false, 1500, sh(`bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}' || true`), (o) => o.trim() === "yes")
const btDev = createPoll(
  "Off",
  1500,
  sh(`
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      dev="$(bluetoothctl devices Connected | head -n1 | cut -d' ' -f3-)"
      if [ -n "$dev" ]; then
        echo "$dev"
      else
        echo "On"
      fi
    else
      echo "Off"
    fi
  `),
  (o) => {
    const d = o.trim() || "Off"
    return d.length > 9 ? d.slice(0, 9) : d
  },
)

const dndOn = createPoll(false, 1500, sh(`makoctl mode 2>/dev/null || true`), (o) => o.includes("do-not-disturb"))
async function toggleDnd() { await safeAsync(`makoctl mode -t do-not-disturb`) }

/* ---------------- weather ---------------- */
// Path must match weather.sh script
const WEATHER_CACHE_PATH = `${GLib.get_home_dir()}/.config/ags/.cache/ags-weather.json`

// Helper to safely parse the JSON from our script
function parseWeather(jsonString: string) {
  try {
    const data = JSON.parse(jsonString)
    let d = data.desc || ""
    
   // Conciseness filters:
    d = d.replace(/Overcast clouds/i, "Overcast")
         .replace(/Scattered clouds/i, "Scattered")
         .replace(/Broken clouds/i, "Cloudy")
         .replace(/Few clouds/i, "Few Clouds")

         .replace(/Thunderstorm with/i, "T-Storm &") 
         .replace(/Thunderstorm/i, "T-Storm")

         .replace(/shower rain/i, "Showers")
         .replace(/shower snow/i, "Snow Showers")
         .replace(/drizzle rain/i, "Drizzle")
         .replace(/rain and snow/i, "Rain & Snow")
         
         // Remove filler words
         .replace(/intensity/i, "")  // "Heavy intensity rain" -> "Heavy rain"
         .replace(/moderate/i, "")   // "Moderate rain" -> "Rain" (context usually implies it)
         .replace(/heavy/i, "Hvy.")  
         .replace(/light/i, "Lt.")   
         .trim()

    d = d.replace(/\s+/g, " ")
         
    return { ...data, desc: d }
  } catch {
    return { temp: "--", icon: "", desc: "Error" }
  }
}

// LOAD INSTANTLY
let initialWeather = { temp: "--", icon: "☁", desc: "Loading..." }
try {
  const cachedData = readFile(WEATHER_CACHE_PATH)
  initialWeather = parseWeather(cachedData)
} catch (e) {
  console.log("No weather cache found, waiting for script...")
}

//  POLL
const weather = createPoll(
  initialWeather, 
  90_000,        
  sh(`${GLib.get_home_dir()}/.config/ags/script/weather.sh`), 
  (out) => parseWeather(out)
)

/* ---------------- calendar + events ---------------- */
const weekDay = createPoll("", 60000, () => new Date().toLocaleDateString("en-US", { weekday: "short" }).toUpperCase())
const dayNum = createPoll("", 60000, () => String(new Date().getDate()))
const monthLbl = createPoll("", 60000, () => new Date().toLocaleDateString("en-US", { month: "short" }).toUpperCase())

type Ev = { title?: string; "start-time"?: string }
const events = createPoll<Ev[]>(
  [],
  60000,
  sh(`khal list now 1h --json title --json start-time 2>/dev/null || echo '[]'`),
  (out) => {
    try {
      const v = JSON.parse(out)
      return Array.isArray(v) ? v.slice(0, 2) : []
    } catch { return [] }
  },
)

let calGridRef: Gtk.Grid | null = null
function rebuildCalendarGrid() {
  if (!calGridRef) return
  const grid = calGridRef

  while (true) {
    const child = grid.get_first_child()
    if (!child) break
    grid.remove(child)
  }

  const d = new Date()
  const y = d.getFullYear()
  const m = d.getMonth()
  const today = d.getDate()
  const firstDay = new Date(y, m, 1).getDay()
  const daysInMonth = new Date(y, m + 1, 0).getDate()

  const heads = ["S", "M", "T", "W", "T", "F", "S"]
  heads.forEach((h, i) => {
    const l = new Gtk.Label({ label: h })
    l.add_css_class("cal-head")
    l.set_halign(Gtk.Align.CENTER)
    l.set_valign(Gtk.Align.CENTER)
    grid.attach(l, i, 0, 1, 1)
  })

  let col = firstDay
  let row = 1
  for (let i = 1; i <= daysInMonth; i++) {
    const cell = new Gtk.Label({ label: String(i), xalign: 0.5, yalign: 0.5 })
    cell.add_css_class("cal-cell")
    if (i === today) cell.add_css_class("today")
    cell.set_halign(Gtk.Align.CENTER)
    cell.set_valign(Gtk.Align.CENTER)
    grid.attach(cell, col, row, 1, 1)

    col++
    if (col > 6) { col = 0; row++ }
  }
}

/* ---------------- volume / brightness ---------------- */
function readVolNow(): number {
  const o = safeSync(`pactl get-sink-volume @DEFAULT_SINK@ | head -n1 || true`)
  const m = o.match(/(\d+)%/)
  const n = Number(m?.[1] || 0)
  return Number.isFinite(n) ? Math.max(0, Math.min(150, n)) : 0
}

function readBrightNow(): number {
  const o = safeSync(`brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '% ' || true`)
  const n = Number(o.trim())
  return Number.isFinite(n) ? Math.max(0, Math.min(100, n)) : 50
}

const volAdj = new Gtk.Adjustment({
  lower: 0, upper: 150,
  step_increment: 1, page_increment: 5,
  value: readVolNow(),
})

const briAdj = new Gtk.Adjustment({
  lower: 0, upper: 100,
  step_increment: 1, page_increment: 5,
  value: readBrightNow(),
})

let lastUserVolMs = 0
let lastUserBriMs = 0

async function setVolumePct(v: number) {
  lastUserVolMs = Date.now()
  await safeAsync(`pactl set-sink-volume @DEFAULT_SINK@ ${Math.round(v)}%`)
}

async function setBrightnessPct(v: number) {
  lastUserBriMs = Date.now()
  await safeAsync(`brightnessctl set ${Math.round(v)}%`)
}

// Live sync (updates when you use keyboard keys / other apps)
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 350, () => {
  if (Date.now() - lastUserVolMs >= 450) volAdj.set_value(readVolNow())
  return GLib.SOURCE_CONTINUE
})

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
  if (Date.now() - lastUserBriMs >= 650) briAdj.set_value(readBrightNow())
  return GLib.SOURCE_CONTINUE
})

/* ---------------- notifications (hub-only dismiss, NEVER touches mako) ---------------- */
type Notif = { id: number; app: string; summary: string }

function parseMakoHistory(raw: string): Notif[] {
  const lines = raw.split("\n")
  const out: Notif[] = []
  for (let i = 0; i < lines.length && out.length < 200; i++) {
    const line = lines[i].trim()
    const m = line.match(/^Notification\s+(\d+):\s*(.+)$/)
    if (!m) continue
    const id = Number(m[1])
    const summary = m[2]

    let appName = "SYSTEM"
    for (let j = i + 1; j < Math.min(i + 10, lines.length); j++) {
      const l2 = lines[j].trim()
      const am = l2.match(/^App name:\s*(.+)$/)
      if (am) { appName = am[1]; break }
      if (l2.startsWith("Notification ")) break
    }

    out.push({ id, app: appName, summary })
  }
  return out
}

const DISMISSED_PATH = `${GLib.get_user_cache_dir()}/ags-hub-dismissed.json`

function loadDismissed(): Set<number> {
  try {
    const raw = safeSync(`cat "${DISMISSED_PATH}" 2>/dev/null || true`).trim()
    if (!raw) return new Set()
    const arr = JSON.parse(raw)
    if (!Array.isArray(arr)) return new Set()
    return new Set(arr.map((x) => Number(x)).filter((n) => Number.isFinite(n)))
  } catch {
    return new Set()
  }
}

const clearedNotifIds = loadDismissed()

function saveDismissed() {
  try {
    const dir = GLib.path_get_dirname(DISMISSED_PATH)
    GLib.mkdir_with_parents(dir, 0o755)
    const payload = JSON.stringify([...clearedNotifIds].slice(-400))
    GLib.file_set_contents(DISMISSED_PATH, payload)
  } catch {
    // ignore
  }
}

const notifs = createPoll<Notif[]>(
  [],
  1500, 
  sh(`makoctl history 2>/dev/null | head -n 320 || true`),
  (out) => {
    if (!out) { console.log("Debug: makoctl returned empty string"); return []; }
    const parsed = parseMakoHistory(out)
    const visible = parsed.filter(n => !clearedNotifIds.has(n.id))
    return visible.slice(0, 6)
  },
)

async function clearNotifs() {
  for (const n of notifs()) clearedNotifIds.add(n.id)
  saveDismissed()
}

async function dismissOne(id: number) {
  await safeAsync(`makoctl dismiss -n ${id}`)
  clearedNotifIds.add(id)
  saveDismissed()
}

/* ---------------- UI components ---------------- */
function Chip(props: { icon: string; text: any }) {
  return (
    <Gtk.Box class="chip" spacing={6} valign={Gtk.Align.CENTER}>
      <Gtk.Label class="chip-icon" label={props.icon} />
      <Gtk.Label class="chip-text" label={props.text} />
    </Gtk.Box>
  )
}

function Header() {
  return (
    <Gtk.CenterBox class="header" valign={Gtk.Align.CENTER}>
      <Gtk.Box $type="start" spacing={12} valign={Gtk.Align.CENTER}>
        <Gtk.Box class="avatar" css={`background-image: url("file://${PROFILE_IMG}");`} />
        <Gtk.Label class="name" xalign={0} label={PROFILE_NAME} />
      </Gtk.Box>

      <Gtk.Box $type="end" spacing={8} valign={Gtk.Align.CENTER}>
        <Chip icon="" text={cpuPct} />
        <Chip icon="" text={ramPct} />
      </Gtk.Box>
    </Gtk.CenterBox>
  )
}

function ButtonsAndSlidersCard() {
  return (
    <Gtk.Box class="card" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <Gtk.Box class="btn-row" spacing={12} homogeneous>
        
        {/* Wi-Fi */}
        <Gtk.Button
          class={wifiOn((on) => (on ? "qs-btn active" : "qs-btn"))}
          hexpand
          onClicked={async () => {
            await safeAsync(`nmcli radio wifi ${wifiOn() ? "off" : "on"}`)
          }}
          $={(btn) => {
            const right = new Gtk.GestureClick()
            right.set_button(3)
            right.connect("pressed", () => safeAsync(`nm-connection-editor`))
            btn.add_controller(right)
          }}
        >
          <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={3} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <Gtk.Label class="qs-icon" label="󰤨" halign={Gtk.Align.CENTER} />
            <Gtk.Label class="qs-label" label={wifiSSID} max_width_chars={8} ellipsize={Pango.EllipsizeMode.END} />
          </Gtk.Box>
        </Gtk.Button>

        {/* Bluetooth */}
        <Gtk.Button
          class={btOn((on) => (on ? "qs-btn active" : "qs-btn"))}
          hexpand
          onClicked={async () => {
            await safeAsync(`bluetoothctl power ${btOn() ? "off" : "on"}`)
          }}
          $={(btn) => {
            const right = new Gtk.GestureClick()
            right.set_button(3)
            right.connect("pressed", () => safeAsync(`blueman-manager`))
            btn.add_controller(right)
          }}
        >
          <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={3} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <Gtk.Label class="qs-icon" label="󰂯" />
            <Gtk.Label class="qs-label" label={btDev} max_width_chars={9} ellipsize={Pango.EllipsizeMode.END} />
          </Gtk.Box>
        </Gtk.Button>

        {/* Screenshot */}
        <Gtk.Button
          class="qs-btn"
          hexpand
          onClicked={() => safeAsync(`command -v grimblast >/dev/null && grimblast --notify copysave area || true`)}
        >
          <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={3} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <Gtk.Label class="qs-icon" label="󱣴" />
            <Gtk.Label class="qs-label" label="Snap" />
          </Gtk.Box>
        </Gtk.Button>

        {/* DND */}
        <Gtk.Button
          class={dndOn((on) => (on ? "qs-btn active" : "qs-btn"))}
          hexpand
          onClicked={toggleDnd}
        >
          <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={3} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
            <Gtk.Label class="qs-icon" label="󰂛" />
            <Gtk.Label class="qs-label" label={dndOn((x) => (x ? "DND" : "Off"))} />
          </Gtk.Box>
        </Gtk.Button>
      </Gtk.Box>

      {/* sliders */}
      <Gtk.Box class="sliders-box" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        <Gtk.Box class="slider-row" spacing={10} valign={Gtk.Align.CENTER}>
          <Gtk.Label class="slider-icon" label="󰃟" />
          <Gtk.Scale
            hexpand
            draw_value={false}
            orientation={Gtk.Orientation.HORIZONTAL}
            adjustment={briAdj}
            $={(self) => self.connect("value-changed", () => setBrightnessPct(self.get_value()))}
          />
        </Gtk.Box>

        <Gtk.Box class="slider-row" spacing={10} valign={Gtk.Align.CENTER}>
          <Gtk.Label class="slider-icon" label="󰕾" />
          <Gtk.Scale
            hexpand
            draw_value={false}
            orientation={Gtk.Orientation.HORIZONTAL}
            adjustment={volAdj}
            $={(self) => self.connect("value-changed", () => setVolumePct(self.get_value()))}
          />
        </Gtk.Box>
      </Gtk.Box>
    </Gtk.Box>
  )
}

function CalendarGrid() {
  return (
    <Gtk.Grid
      column_spacing={3}
      row_spacing={3}
      halign={Gtk.Align.END}
      $={(grid) => {
        calGridRef = grid
        rebuildCalendarGrid()
      }}
    />
  )
}

function CalendarWeatherCard() {
  return (
    <Gtk.Box class="card" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {/* TOP ROW (HTML layout) */}
      <Gtk.Box class="cal-top-row" spacing={0} valign={Gtk.Align.CENTER}>
        {/* LEFT */}
        <Gtk.Box
          class="cal-left"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={0}
          valign={Gtk.Align.CENTER}
          halign={Gtk.Align.START}
          hexpand
        >
          <Gtk.Label class="cal-day-name" xalign={0} halign={Gtk.Align.START} label={weekDay} />
          <Gtk.Label class="cal-day-num" xalign={0} halign={Gtk.Align.START} label={dayNum} />

          {/* single-line weather */}
          <Gtk.Box class="weather-row" spacing={6} valign={Gtk.Align.CENTER}>
            <Gtk.Label class="weather-icon" label={weather((w) => w.icon)} />
            <Gtk.Label 
              class="weather-text" 
              label={weather((w) => `${w.temp} • ${w.desc}`)}
              max_width_chars={16}
              ellipsize={Pango.EllipsizeMode.END} 
            />
          </Gtk.Box>
        </Gtk.Box>

        {/* RIGHT */}
        <Gtk.Box
          class="cal-right"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={6}
          widthRequest={120}
          halign={Gtk.Align.END}
          valign={Gtk.Align.CENTER}
        >
          <Gtk.Label class="cal-month" xalign={1} label={monthLbl} />
          <CalendarGrid />
        </Gtk.Box>
      </Gtk.Box>

      {/* at-a-glance*/}
      <Gtk.Box class="glance" visible={events((e) => e.length > 0)} spacing={8} valign={Gtk.Align.CENTER}>
        <Gtk.Label class="glance-ico" label="󰃭" />
        <Gtk.Label
          class="glance-txt"
          label={events((e) => {
            const ev = e[0]
            const t = ev?.["start-time"] ? `${ev["start-time"]} ` : ""
            return `${t}${ev?.title || "Upcoming event"}`
          })}
          ellipsize={Pango.EllipsizeMode.END}
          max_width_chars={34}
        />
      </Gtk.Box>
    </Gtk.Box>
  )
}

function NotificationsCard() {
  return (
    <Gtk.Box class="card" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <Gtk.Box spacing={10} valign={Gtk.Align.CENTER}>
        <Gtk.Label class="notif-title" hexpand xalign={0} label="Notifications" />

        <Gtk.Box class="badge">
          <Gtk.Label class="badge-text" label={notifs((n) => String(n.length))} />
        </Gtk.Box>

        <Gtk.Button class="btn-clear" visible={notifs((n) => n.length > 0)} onClicked={clearNotifs}>
          <Gtk.Label label="Clear" />
        </Gtk.Button>
      </Gtk.Box>

      <Gtk.Box visible={notifs((n) => n.length === 0)}>
        <Gtk.Label class="empty-text" label="No new notifications" halign={Gtk.Align.CENTER} />
      </Gtk.Box>

      <Gtk.ScrolledWindow
        visible={notifs((n) => n.length > 0)}
        heightRequest={170}
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
        vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
      >
        <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <For each={notifs}>
            {(n: { id: number; app: string; summary: string }) => (
              <Gtk.Button
                class="notif-item"
                $={(self) => {
                  self.connect("clicked", async () => {
                    self.add_css_class("gone")
                    setTimeout(async () => { await dismissOne(n.id) }, 170)
                  })
                }}
              >
                <Gtk.Box spacing={10} valign={Gtk.Align.CENTER}>
                  <Gtk.CenterBox class="notif-ico">
                    <Gtk.Label
                      $type="center"
                      label="󰋽"
                      halign={Gtk.Align.CENTER}
                      valign={Gtk.Align.CENTER}
                      xalign={0.5}
                      yalign={0.5}
                    />
                  </Gtk.CenterBox>

                  <Gtk.Box orientation={Gtk.Orientation.VERTICAL} spacing={2} hexpand>
                    <Gtk.Label class="notif-app" xalign={0} label={(n.app || "SYSTEM").toUpperCase()} />
                    <Gtk.Label class="notif-msg" xalign={0} wrap label={n.summary || "Notification"} />
                  </Gtk.Box>
                </Gtk.Box>
              </Gtk.Button>
            )}
          </For>
        </Gtk.Box>
      </Gtk.ScrolledWindow>
    </Gtk.Box>
  )
}

/* ---------------- Window ---------------- */
let hubWin: any = null

function Hub() {
  const A = Astal.WindowAnchor

  return (
    <window
      name="hub"
      class="Hub"
      application={app}
      monitor={0}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      anchor={A.TOP | A.BOTTOM | A.LEFT | A.RIGHT}
      $={(self) => {
        hubWin = self

        const k = new Gtk.EventControllerKey()
        k.connect("key-pressed", (_: any, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) self.visible = false
        })
        self.add_controller(k)

        self.connect("notify::visible", () => {
          if (!self.visible) return
          volAdj.set_value(readVolNow())
          briAdj.set_value(readBrightNow())
          rebuildCalendarGrid()
        })
      }}
    >
      <Gtk.Overlay>
        <Gtk.Button class="scrim" hexpand vexpand onClicked={() => { if (hubWin) hubWin.visible = false }} />
        <Gtk.Box
          $type="overlay"
          class="panel"
          orientation={Gtk.Orientation.VERTICAL}
          widthRequest={PANEL_W}
          heightRequest={PANEL_H}
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          css={`margin-top:${TOP_GAP}px; margin-right:${RIGHT_GAP}px;`}
        >
          <Header />
          <ButtonsAndSlidersCard />
          <CalendarWeatherCard />
          <NotificationsCard />
        </Gtk.Box>
      </Gtk.Overlay>
    </window>
  )
}

app.start({
  css,
  main() {
    app.hold()
    return Hub()
  },
})
