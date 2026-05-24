/*
codex-stellarium
[part 3 of 3 -- JS]
codex-stellarium is my custom firefox newtab/homepage. 
Use alongside my userChrome.css for best experience

by snes19xx, https://github.com/snes19xx
*/

const _DEFAULTS = {
  theme: "auto",
  username: "user",
  size: 1,
  location: {
    name: "Toronto, ON", // default is toronto
    lat: 43.661708,
    lon: -79.395039,
  },
  toggles: {
    clickComets: true,
    timerComets: true,
    asteroidBelt: true,
    planets: true,
    planetaryRotation: true,
    parallax: true,
    milkyWay: true,
    stars: true,
  },
  shortcuts: [
    // defaults but configurable
    { name: "YouTube", url: "https://youtube.com" },
    { name: "NASA", url: "https://nasa.gov" },
    { name: "Wikipedia", url: "https://wikipedia.org" },
    { name: "Maps", url: "https://maps.google.com" },
    { name: "Earth", url: "https://science.nasa.gov/earth/" },
    { name: "Reddit", url: "https://reddit.com" },
    { name: "Library", url: "https://annas-archive.pk/" },
    { name: "NotebookLM", url: "https://notebooklm.google.com" },
    { name: "Images", url: "https://images.google.com" },
  ],
};

function _loadSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem("_surf_settings") || "{}");
    return {
      theme: saved.theme || _DEFAULTS.theme,
      username:
        saved.username !== undefined ? saved.username : _DEFAULTS.username,
      size: saved.size || _DEFAULTS.size,
      location: saved.location
        ? { ..._DEFAULTS.location, ...saved.location }
        : { ..._DEFAULTS.location },
      toggles: saved.toggles
        ? { ..._DEFAULTS.toggles, ...saved.toggles }
        : { ..._DEFAULTS.toggles },
      shortcuts:
        saved.shortcuts && saved.shortcuts.length === 9
          ? saved.shortcuts
          : _DEFAULTS.shortcuts.map((s) => ({ ...s })),
    };
  } catch (_e) {
    return {
      ..._DEFAULTS,
      location: { ..._DEFAULTS.location },
      toggles: { ..._DEFAULTS.toggles },
      shortcuts: _DEFAULTS.shortcuts.map((s) => ({ ...s })),
    };
  }
}

const SETTINGS = _loadSettings();

document.documentElement.style.setProperty("--ui-scale", SETTINGS.size);

const pad = (n) => String(n).padStart(2, "0");
const DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];
const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

const cssVars = { ink: "", border: "", accent: "" };
function refreshCSSVars() {
  const s = getComputedStyle(document.documentElement);
  cssVars.ink = s.getPropertyValue("--ink").trim();
  cssVars.border = s.getPropertyValue("--border").trim();
  cssVars.accent = s.getPropertyValue("--accent").trim();
}
refreshCSSVars();
window.addEventListener("themeChange", refreshCSSVars);

const elCh = document.getElementById("ch");
const elCm = document.getElementById("cm");
const elCs = document.getElementById("cs");
const elGreeting = document.getElementById("greeting");
const elClockDate = document.getElementById("clock-date");
const elFooterUtc = document.getElementById("footer-utc");
const elFooterLst = document.getElementById("footer-lst");
const elMoonSvg = document.getElementById("moon-svg");
const elMoonName = document.getElementById("moon-name");
const elSidereal = document.getElementById("sidereal");
const elSunElev = document.getElementById("sun-elev");
const elEphem = document.getElementById("ephem");
const elWxIcon = document.getElementById("wx-icon");
const elWxTemp = document.getElementById("wx-temp");
const elWxMeta = document.getElementById("wx-meta");

let _prevMin = -1;
function tick() {
  const now = new Date();
  const h = now.getHours(),
    m = now.getMinutes(),
    s = now.getSeconds();
  elCh.textContent = pad(h);
  if (m !== _prevMin) {
    elCm.style.transition = "opacity 0.25s";
    elCm.style.opacity = "0.25";
    setTimeout(() => {
      elCm.textContent = pad(m);
      elCm.style.opacity = "1";
    }, 180);
    _prevMin = m;
    if (SETTINGS.theme === "auto" && typeof applyTheme === "function") {
      applyTheme(h >= 6 && h < 19);
    }
  }
  elCs.textContent = pad(s) + "s";
  const dow = now.getDay();
  const name = SETTINGS.username || "user";
  if (dow === 5 && h >= 16) elGreeting.textContent = `Happy Friday, ${name}.`;
  else if (h < 5) elGreeting.textContent = `Still up, ${name}?`;
  else if (h < 12) elGreeting.textContent = `Good morning, ${name}.`;
  else if (h < 18) elGreeting.textContent = `Good afternoon, ${name}.`;
  else elGreeting.textContent = `Good evening, ${name}.`;
  elClockDate.textContent = `${DAYS[dow]}, ${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
  const utcH = now.getUTCHours(),
    utcM = now.getUTCMinutes(),
    utcS = now.getUTCSeconds();
  elFooterUtc.textContent = `UTC ${pad(utcH)}:${pad(utcM)}:${pad(utcS)}`;
  elFooterLst.textContent = `LST ${siderealTime(SETTINGS.location.lon, now)}`;
}
elCm.textContent = pad(new Date().getMinutes());
setInterval(tick, 1000);
tick();

function moonPhase(date) {
  return (
    ((((date - new Date(2000, 0, 6)) / 86400000) % 29.530588853) +
      29.530588853) %
    29.530588853
  );
}
function moonName(p) {
  if (p < 1.85) return "New Moon";
  if (p < 7.38) return "Waxing Crescent";
  if (p < 9.22) return "First Quarter";
  if (p < 14.77) return "Waxing Gibbous";
  if (p < 16.61) return "Full Moon";
  if (p < 22.15) return "Waning Gibbous";
  if (p < 23.99) return "Last Quarter";
  return "Waning Crescent";
}

const createSVG = (tag, attrs) => {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  return el;
};

function drawMoon(phase) {
  const r = 11,
    cx = 14,
    cy = 14;
  const p = phase / 29.53,
    isWaxing = p < 0.5;
  const termX = r * Math.cos(p * Math.PI * 2);
  const atx = Math.max(0.35, Math.abs(termX));

  const bgCircle = createSVG("circle", {
    cx,
    cy,
    r,
    fill: "var(--bg)",
    stroke: "var(--border-s)",
    "stroke-width": "0.7",
  });
  elMoonSvg.replaceChildren(bgCircle);

  if (p < 0.02 || p > 0.98) {
    return;
  }

  let innerEl;
  if (p > 0.48 && p < 0.52) {
    innerEl = createSVG("circle", {
      cx,
      cy,
      r,
      fill: "var(--ink)",
      opacity: "0.85",
    });
  } else if (isWaxing) {
    const sw = termX > 0 ? 0 : 1;
    const d = `M${cx} ${cy - r} A${atx} ${r} 0 0 ${sw} ${cx} ${cy + r} A${r} ${r} 0 0 1 ${cx} ${cy - r}Z`;
    innerEl = createSVG("path", { d, fill: "var(--ink)", opacity: "0.85" });
  } else {
    const sw = termX < 0 ? 1 : 0;
    const d = `M${cx} ${cy - r} A${r} ${r} 0 0 0 ${cx} ${cy + r} A${atx} ${r} 0 0 ${sw} ${cx} ${cy - r}Z`;
    innerEl = createSVG("path", { d, fill: "var(--ink)", opacity: "0.85" });
  }
  elMoonSvg.appendChild(innerEl);
}

function siderealTime(lon, date) {
  const JD = date.getTime() / 86400000 + 2440587.5;
  const T = (JD - 2451545) / 36525;
  let GMST =
    280.46061837 + 360.98564736629 * (JD - 2451545) + T * T * 0.000387933;
  GMST = ((GMST % 360) + 360) % 360;
  const LST = (((GMST + lon) % 360) + 360) % 360;
  return `${pad(Math.floor(LST / 15))}h${pad(Math.floor(((LST / 15) % 1) * 60))}m`;
}

function sunElev(lat, lon, date) {
  const JD = date.getTime() / 86400000 + 2440587.5,
    n = JD - 2451545;
  const L = ((280.46 + 0.9856474 * n) * Math.PI) / 180;
  const g = ((357.528 + 0.9856003 * n) * Math.PI) / 180;
  const lam =
    L + ((1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * Math.PI) / 180;
  const eps = (23.439 * Math.PI) / 180;
  const dec = Math.asin(Math.sin(eps) * Math.sin(lam));
  const GMST =
    (((280.46061837 + 360.98564736629 * (JD - 2451545)) % 360) + 360) % 360;
  const LST = (((GMST + lon) % 360) + 360) % 360;
  const HA =
    ((LST - (((((lam * 180) / Math.PI) % 360) + 360) % 360)) * Math.PI) / 180;
  const latR = (lat * Math.PI) / 180;
  const alt = Math.asin(
    Math.sin(latR) * Math.sin(dec) +
      Math.cos(latR) * Math.cos(dec) * Math.cos(HA),
  );
  return ((alt * 180) / Math.PI).toFixed(1);
}

function updateCelestial() {
  const now = new Date();
  const phase = moonPhase(now);
  drawMoon(phase);
  elMoonName.textContent = moonName(phase);
  elSidereal.textContent = siderealTime(SETTINGS.location.lon, now);
  const elev = sunElev(SETTINGS.location.lat, SETTINGS.location.lon, now);
  elSunElev.textContent = elev;
  const doy = Math.ceil((now - new Date(now.getFullYear(), 0, 0)) / 86400000);
  const illum = Math.round(
    ((1 - Math.cos((phase / 29.53) * 2 * Math.PI)) / 2) * 100,
  );

  elEphem.replaceChildren();
  const t1 = document.createTextNode(`Day `);
  const s1 = document.createElement("span");
  s1.textContent = doy;
  const t2 = document.createTextNode(` of `);
  const s2 = document.createElement("span");
  s2.textContent = now.getFullYear();
  const t3 = document.createTextNode(`  ·  Moon `);
  const s3 = document.createElement("span");
  s3.textContent = `${illum}%`;
  const t4 = document.createTextNode(` illuminated`);
  const br = document.createElement("br");
  const t5 = document.createTextNode(`Solar elevation `);
  const s4 = document.createElement("span");
  s4.textContent = `${elev}°`;
  elEphem.append(t1, s1, t2, s2, t3, s3, t4, br, t5, s4);
}
updateCelestial();
setInterval(updateCelestial, 30000);

function renderShortcuts() {
  const scGrid = document.getElementById("sc-grid");
  scGrid.replaceChildren();
  SETTINGS.shortcuts.forEach(({ name, url }, i) => {
    if (!name && !url) return;
    const sym = String.fromCodePoint(0x2460 + i);
    const a = document.createElement("a");
    a.className = "sc-link";
    a.href = url || "#";
    a.style.cssText = `opacity:0; animation: up 0.5s ease ${0.2 + i * 0.03}s forwards`;

    const spanIcon = document.createElement("span");
    spanIcon.className = "sc-icon";
    spanIcon.textContent = sym;

    const spanName = document.createElement("span");
    spanName.className = "sc-name";
    spanName.textContent = name;

    a.append(spanIcon, spanName);
    scGrid.appendChild(a);
  });
}
renderShortcuts();

document.getElementById("search").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && e.target.value.trim())
    location.href = `https://www.google.com/search?q=${encodeURIComponent(e.target.value.trim())}`;
});

const WX_SVG = {
  sunny: `<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>`,
  moon: `<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>`,
  cloud: `<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>`,
  rain: `<path d="M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"/><line x1="8" y1="19" x2="8" y2="21"/><line x1="12" y1="17" x2="12" y2="19"/><line x1="16" y1="19" x2="16" y2="21"/>`,
  snow: `<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/><line x1="11" y1="20" x2="11" y2="22"/>`,
  storm: `<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>`,
};
const WX_DESC = {
  0: "Clear",
  1: "Mostly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Icy fog",
  51: "Light drizzle",
  53: "Drizzle",
  55: "Dense drizzle",
  61: "Light rain",
  63: "Rain",
  65: "Heavy rain",
  71: "Light snow",
  73: "Snow",
  75: "Heavy snow",
  77: "Snow grains",
  80: "Showers",
  81: "Showers",
  82: "Violent showers",
  85: "Snow showers",
  86: "Heavy snow showers",
  95: "Thunderstorm",
  96: "Thunderstorm",
  99: "Severe storm",
};

const domParser = new DOMParser();

function applyWeatherData(d) {
  const temp = Math.round(d.current.temperature_2m);
  const code = d.current.weather_code;
  const isDay = d.current.is_day === 1;
  if (typeof applyTheme === "function") applyTheme(isDay);
  elWxTemp.textContent = `${temp}°C`;

  elWxMeta.replaceChildren(
    document.createTextNode(SETTINGS.location.name),
    document.createElement("br"),
    document.createTextNode(WX_DESC[code] || "Variable"),
  );

  let k = "sunny";
  if (!isDay && code === 0) k = "moon";
  else if (code <= 3) k = "cloud";
  else if (code >= 51 && code <= 82) k = "rain";
  else if (code >= 71 && code <= 86) k = "snow";
  else if (code >= 95) k = "storm";

  const parsedSvg = domParser.parseFromString(
    `<svg xmlns="http://www.w3.org/2000/svg">${WX_SVG[k]}</svg>`,
    "image/svg+xml",
  );
  elWxIcon.replaceChildren(...parsedSvg.documentElement.childNodes);

  drawMoon(moonPhase(new Date()));
}

function wxCacheKey() {
  return (
    "wx_v1_" +
    SETTINGS.location.lat.toFixed(4) +
    "_" +
    SETTINGS.location.lon.toFixed(4)
  );
}

async function loadWeather() {
  const WX_KEY = wxCacheKey();
  const WX_TTL = 600000;

  try {
    const cached = localStorage.getItem(WX_KEY);
    if (cached) {
      const { d, ts } = JSON.parse(cached);
      if (Date.now() - ts < WX_TTL) {
        applyWeatherData(d);
        return;
      }
    }
  } catch (e) {
    console.error("Weather cache read failed:", e);
  }

  try {
    const r = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${SETTINGS.location.lat}&longitude=${SETTINGS.location.lon}&current=temperature_2m,weather_code,is_day&timezone=auto`,
    );

    if (!r.ok) {
      throw new Error(`Weather API returned status ${r.status}`);
    }

    const d = await r.json();

    try {
      localStorage.setItem(WX_KEY, JSON.stringify({ d, ts: Date.now() }));
    } catch (e) {
      console.error("Weather cache write failed:", e);
    }

    applyWeatherData(d);
  } catch (e) {
    console.error("Weather fetch execution failed:", e);
    elWxMeta.replaceChildren(
      document.createTextNode(SETTINGS.location.name),
      document.createElement("br"),
      document.createTextNode("Unavailable"),
    );
  }
}

loadWeather();

let RW = window.innerWidth,
  RH = window.innerHeight;

const bgRenderer = (() => {
  const C = document.getElementById("bg-canvas");
  const ctx = C.getContext("2d");
  let t = 0;

  const ORBS = Array.from({ length: 2 }, () => ({
    xp: 0.1 + Math.random() * 0.8,
    yp: 0.1 + Math.random() * 0.8,
    rx: 0.15 + Math.random() * 0.22,
    ry: 0.08 + Math.random() * 0.14,
    sp: 0.00007 + Math.random() * 0.00013,
    ph: Math.random() * Math.PI * 2,
    ph2: Math.random() * Math.PI * 2,
    rot: Math.random() * Math.PI,
  }));
  const HUES = [40, 200];

  return {
    resize(w, h) {
      C.width = w;
      C.height = h;
    },
    draw() {
      const W = RW,
        H = RH;
      ctx.clearRect(0, 0, W, H);
      const base = Math.min(W, H);
      for (let i = 0; i < ORBS.length; i++) {
        const o = ORBS[i];
        const x = (o.xp + Math.sin(t * o.sp + o.ph) * 0.11) * W;
        const y = (o.yp + Math.cos(t * o.sp * 0.7 + o.ph2) * 0.09) * H;
        const rx = o.rx * base,
          ry = o.ry * base;
        const rot = o.rot + t * o.sp * 0.2;
        const h = HUES[i];
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(rot);
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
        g.addColorStop(0, `hsla(${h},55%,80%,0.05)`);
        g.addColorStop(0.5, `hsla(${h},40%,88%,0.02)`);
        g.addColorStop(1, `hsla(${h},30%,95%,0)`);
        ctx.beginPath();
        ctx.ellipse(0, 0, rx, ry, 0, 0, Math.PI * 2);
        ctx.fillStyle = g;
        ctx.fill();
        ctx.restore();
      }
      t++;
    },
  };
})();

const systemRenderer = (() => {
  const C = document.getElementById("system-canvas");
  const ctx = C.getContext("2d");
  let time = 0;
  let orbitCache = null,
    orbitCacheW = 0,
    orbitCacheH = 0;

  const PLANETS = [
    { name: "Mercury", r: 40, spd: 0.019, sz: 1.8 },
    { name: "Venus", r: 70, spd: 0.0075, sz: 4.3 },
    {
      name: "Earth",
      r: 105,
      spd: 0.0065,
      sz: 4.6,
      moons: [{ r: 10, spd: 0.02, sz: 1.0 }],
    },
    { name: "Mars", r: 140, spd: 0.005, sz: 2.4 },
    {
      name: "Jupiter",
      r: 240,
      spd: 0.002,
      sz: 10,
      moons: [
        { r: 14, spd: 0.04, sz: 1.1 },
        { r: 19, spd: 0.03, sz: 1.3 },
        { r: 26, spd: 0.02, sz: 1.5 },
        { r: 33, spd: 0.015, sz: 1.0 },
      ],
    },
    {
      name: "Saturn",
      r: 330,
      spd: 0.0012,
      sz: 8,
      rings: { inner: 14, outer: 26 },
      moons: [{ r: 24, spd: 0.02, sz: 1.2 }],
    },
    { name: "Uranus", r: 410, spd: 0.0007, sz: 6.5 },
    { name: "Neptune", r: 480, spd: 0.0004, sz: 6.4 },
  ];

  const ASTEROIDS = [];
  for (let i = 0; i < 900; i++) {
    ASTEROIDS.push({
      angle: Math.random() * Math.PI * 2,
      r: 180 + Math.random() * 30,
      spd: 0.001 + Math.random() * 0.001,
      sz: 0.6 + Math.random() * 0.9,
    });
  }

  function buildOrbitCache(W, H) {
    const oc = document.createElement("canvas");
    oc.width = W;
    oc.height = H;
    const octx = oc.getContext("2d");
    const cx = W / 2,
      cy = H / 2;
    const base = Math.min(W, H) / 1100;
    octx.strokeStyle = cssVars.border;
    octx.lineWidth = 0.5;
    for (let i = 0; i < PLANETS.length; i++) {
      octx.beginPath();
      octx.arc(cx, cy, PLANETS[i].r * base, 0, Math.PI * 2);
      octx.stroke();
    }
    orbitCache = oc;
    orbitCacheW = W;
    orbitCacheH = H;
  }

  return {
    resize(w, h) {
      C.width = w;
      C.height = h;
      orbitCache = null;
    },
    invalidateCache() {
      orbitCache = null;
    },
    draw() {
      const W = RW,
        H = RH;
      const cx = W / 2,
        cy = H / 2;
      ctx.clearRect(0, 0, W, H);
      const base = Math.min(W, H) / 1100;

      if (!orbitCache || orbitCacheW !== W || orbitCacheH !== H) {
        buildOrbitCache(W, H);
      }

      if (SETTINGS.toggles.planets) {
        ctx.drawImage(orbitCache, 0, 0);
        
        ctx.beginPath();
        ctx.arc(cx, cy, 17 * base, 0, Math.PI * 2);
        ctx.fillStyle = cssVars.accent;
        ctx.fill();

        for (let i = 0; i < PLANETS.length; i++) {
          const p = PLANETS[i];
          const angle = time * p.spd + i * 1.23;
          const pr = p.r * base;
          const px = cx + Math.cos(angle) * pr;
          const py = cy + Math.sin(angle) * pr;
          const psz = Math.max(1, p.sz * base);

          if (p.rings) {
            const rOuter = p.rings.outer * base;
            ctx.beginPath();
            ctx.ellipse(px, py, rOuter, rOuter * 0.35, angle, 0, Math.PI * 2);
            ctx.strokeStyle = cssVars.border;
            ctx.lineWidth = 1.2;
            ctx.stroke();
          }

          ctx.beginPath();
          ctx.arc(px, py, psz, 0, Math.PI * 2);
          ctx.fillStyle = cssVars.ink;
          ctx.fill();

          if (p.moons) {
            for (let mi = 0; mi < p.moons.length; mi++) {
              const m = p.moons[mi];
              const mr = m.r * base;
              const mAngle = time * m.spd + mi * 2.1;
              const mx = px + Math.cos(mAngle) * mr;
              const my = py + Math.sin(mAngle) * mr;
              const msz = Math.max(0.5, m.sz * base);
              ctx.beginPath();
              ctx.arc(px, py, mr, 0, Math.PI * 2);
              ctx.strokeStyle = cssVars.border;
              ctx.globalAlpha = 0.3;
              ctx.lineWidth = 0.5;
              ctx.stroke();
              ctx.globalAlpha = 1;
              ctx.beginPath();
              ctx.arc(mx, my, msz, 0, Math.PI * 2);
              ctx.fillStyle = cssVars.accent;
              ctx.fill();
            }
          }
        }
      }

      if (SETTINGS.toggles.asteroidBelt) {
        ctx.fillStyle = cssVars.ink;
        ctx.globalAlpha = 0.5;
        for (let i = 0; i < ASTEROIDS.length; i++) {
          const a = ASTEROIDS[i];
          a.angle += a.spd;
          const ar = a.r * base;
          const ax = cx + Math.cos(a.angle) * ar;
          const ay = cy + Math.sin(a.angle) * ar;
          const asz = a.sz * base;
          if (asz < 1.2) {
            ctx.fillRect(ax - asz/2, ay - asz/2, asz, asz);
          } else {
            ctx.beginPath();
            ctx.arc(ax, ay, asz, 0, Math.PI * 2);
            ctx.fill();
          }
        }
        ctx.globalAlpha = 1;
      } else {
        for (let i = 0; i < ASTEROIDS.length; i++) {
          ASTEROIDS[i].angle += ASTEROIDS[i].spd;
        }
      }

      if (SETTINGS.toggles.planetaryRotation) {
        time++;
      }
    },
  };
})();

const cometRenderer = (() => {
  const C = document.getElementById("comet-canvas");
  const ctx = C.getContext("2d");
  let cometTime = 0;

  const PLANET_DATA = [
    { r: 40, spd: 0.012, sz: 1.5, mass: 0.3 },
    { r: 70, spd: 0.009, sz: 2.5, mass: 5 },
    { r: 105, spd: 0.007, sz: 2.5, mass: 6 },
    { r: 140, spd: 0.005, sz: 2, mass: 3 },
    { r: 240, spd: 0.002, sz: 6, mass: 100 },
    { r: 330, spd: 0.0012, sz: 5, mass: 80 },
    { r: 410, spd: 0.0007, sz: 4, mass: 40 },
    { r: 480, spd: 0.0004, sz: 4, mass: 40 },
  ];

  const PLANET_STATES = PLANET_DATA.map((p) => ({
    x: 0,
    y: 0,
    mass: p.mass,
    sz: 0,
  }));
  const comets = [];
  const debris = [];
  let nextSpawn = newInterval();

  function newInterval() {
    return Math.floor((30 + Math.random() * 60) * 60);
  }

  function updatePlanetStates(b) {
    const cx = RW / 2,
      cy = RH / 2;
    for (let i = 0; i < PLANET_DATA.length; i++) {
      const p = PLANET_DATA[i];
      const angle = cometTime * p.spd + i * 1.23;
      const pr = p.r * b;
      PLANET_STATES[i].x = cx + Math.cos(angle) * pr;
      PLANET_STATES[i].y = cy + Math.sin(angle) * pr;
      PLANET_STATES[i].sz = Math.max(1, p.sz * b);
    }
  }

  function spawnComet(targetX, targetY) {
    const b = Math.min(RW, RH) / 1100;
    const cx = RW / 2,
      cy = RH / 2;
    const edge = Math.floor(Math.random() * 4);
    let x, y;
    const mg = 60;
    if (edge === 0) {
      x = Math.random() * RW;
      y = -mg;
    } else if (edge === 1) {
      x = RW + mg;
      y = Math.random() * RH;
    } else if (edge === 2) {
      x = Math.random() * RW;
      y = RH + mg;
    } else {
      x = -mg;
      y = Math.random() * RH;
    }

    let tx, ty;
    if (targetX !== undefined && targetY !== undefined) {
      tx = targetX;
      ty = targetY;
    } else {
      const jitter = 280 * b;
      tx = cx + (Math.random() - 0.5) * jitter;
      ty = cy + (Math.random() - 0.5) * jitter;
    }

    const dx = tx - x,
      dy = ty - y,
      d = Math.sqrt(dx * dx + dy * dy);
    const spd = (1.2 + Math.random() * 1.6) * b;
    comets.push({
      x,
      y,
      vx: (dx / d) * spd,
      vy: (dy / d) * spd,
      tail: [],
      age: 0,
      alpha: 1,
      mass: 1,
      dead: false,
    });
  }

  document.addEventListener("mousedown", (e) => {
    if (!SETTINGS.toggles.clickComets) return;
    if (typeof IS_NIGHT !== "undefined" && IS_NIGHT) return;
    if (
      e.target.tagName === "INPUT" ||
      e.target.closest("a") ||
      e.target.closest(".sett-panel")
    )
      return;
    spawnComet(e.clientX, e.clientY);
  });

  function spawnDebris(x, y, isSun, cometMass = 1) {
    const massScale = Math.max(1, Math.sqrt(cometMass));
    const count = Math.floor((isSun ? 40 : 22) * massScale);
    for (let i = 0; i < count; i++) {
      const ang = Math.random() * Math.PI * 2;
      const spd =
        ((isSun ? 1.5 : 0.5) + Math.random() * (isSun ? 5 : 3.5)) * massScale;
      const warm = Math.random() > (isSun ? 0.3 : 0.5);
      debris.push({
        x,
        y,
        vx: Math.cos(ang) * spd,
        vy: Math.sin(ang) * spd,
        r: (0.6 + Math.random() * (isSun ? 3 : 2)) * massScale,
        alpha: 0.8 + Math.random() * 0.2,
        decay: 0.011 + Math.random() * 0.014,
        warm,
      });
    }
  }

  return {
    resize(w, h) {
      C.width = w;
      C.height = h;
    },
    draw() {
      const W = RW,
        H = RH;
      if (
        typeof IS_NIGHT !== "undefined" &&
        IS_NIGHT &&
        comets.length === 0 &&
        debris.length === 0
      ) {
        ctx.clearRect(0, 0, W, H);
        return;
      }

      ctx.clearRect(0, 0, W, H);

      const b = Math.min(W, H) / 1100;
      const cx = W / 2,
        cy = H / 2;
      const sunSz = 14 * b;
      const G_SUN = 880 * b * b;
      const G_PL = 0.88 * b * b;
      const MAX_V = 18 * b;

      if (typeof IS_NIGHT === "undefined" || !IS_NIGHT) {
        updatePlanetStates(b);
        if (
          SETTINGS.toggles.timerComets &&
          cometTime > 0 &&
          cometTime % nextSpawn === 0
        ) {
          spawnComet();
          nextSpawn = cometTime + newInterval();
        }
      }

      const planets = PLANET_STATES;

      for (let i = debris.length - 1; i >= 0; i--) {
        const d = debris[i];
        d.x += d.vx;
        d.y += d.vy;
        d.vx *= 0.982;
        d.vy *= 0.982;
        d.alpha -= d.decay;
        if (d.alpha <= 0) {
          debris.splice(i, 1);
          continue;
        }
        ctx.beginPath();
        ctx.arc(d.x, d.y, d.r, 0, Math.PI * 2);
        ctx.globalAlpha = Math.max(0, d.alpha);
        ctx.fillStyle = d.warm ? "rgb(255,200,90)" : "rgb(200,228,255)";
        ctx.fill();
      }
      ctx.globalAlpha = 1;

      for (let i = comets.length - 1; i >= 0; i--) {
        const c = comets[i];
        if (c.dead) {
          comets.splice(i, 1);
          continue;
        }
        c.age++;
        if (c.age > 900) {
          comets.splice(i, 1);
          continue;
        }
        c.alpha = c.age > 810 ? (900 - c.age) / 90 : 1;

        c.tail.push({ x: c.x, y: c.y });
        if (c.tail.length > 58) c.tail.shift();

        if (typeof IS_NIGHT === "undefined" || !IS_NIGHT) {
          const dsx = cx - c.x,
            dsy = cy - c.y;
          const distSun = Math.sqrt(dsx * dsx + dsy * dsy);
          if (distSun > 0.5) {
            const f = G_SUN / (distSun * distSun * distSun);
            c.vx += f * dsx;
            c.vy += f * dsy;
          }

          if (SETTINGS.toggles.planets) {
            for (let pi = 0; pi < planets.length; pi++) {
              const p = planets[pi];
              const dpx = p.x - c.x,
                dpy = p.y - c.y;
              const distP = Math.sqrt(dpx * dpx + dpy * dpy);
              if (distP > 0.5) {
                const f = (G_PL * p.mass) / (distP * distP * distP);
                c.vx += f * dpx;
                c.vy += f * dpy;
              }
            }
          }

          const spd = Math.sqrt(c.vx * c.vx + c.vy * c.vy);
          if (spd > MAX_V) {
            const s = MAX_V / spd;
            c.vx *= s;
            c.vy *= s;
          }
        }

        c.x += c.vx;
        c.y += c.vy;

        if (typeof IS_NIGHT === "undefined" || !IS_NIGHT) {
          let merged = false;
          for (let j = i - 1; j >= 0; j--) {
            const c2 = comets[j];
            if (c2.dead) continue;
            const dxx = c2.x - c.x,
              dyy = c2.y - c.y;
            const cDist = Math.sqrt(dxx * dxx + dyy * dyy);
            const r1 = Math.max(1.2, 2.2 * b) * Math.sqrt(c.mass);
            const r2 = Math.max(1.2, 2.2 * b) * Math.sqrt(c2.mass);
            if (cDist < r1 + r2) {
              const tm = c.mass + c2.mass;
              c2.vx = (c2.vx * c2.mass + c.vx * c.mass) / tm;
              c2.vy = (c2.vy * c2.mass + c.vy * c.mass) / tm;
              c2.x = (c2.x * c2.mass + c.x * c.mass) / tm;
              c2.y = (c2.y * c2.mass + c.y * c.mass) / tm;
              c2.mass = Math.min(tm, 30);
              c.dead = true;
              merged = true;
              break;
            }
          }
          if (merged) {
            comets.splice(i, 1);
            continue;
          }

          const dsx2 = cx - c.x,
            dsy2 = cy - c.y;
          if (Math.sqrt(dsx2 * dsx2 + dsy2 * dsy2) < sunSz + 4) {
            spawnDebris(c.x, c.y, true, c.mass);
            comets.splice(i, 1);
            continue;
          }

          let hit = false;
          if (SETTINGS.toggles.planets) {
            for (let pi = 0; pi < planets.length; pi++) {
              const p = planets[pi];
              const dpx = p.x - c.x,
                dpy = p.y - c.y;
              if (Math.sqrt(dpx * dpx + dpy * dpy) < p.sz * 3.5 + 2) {
                spawnDebris(c.x, c.y, false, c.mass);
                comets.splice(i, 1);
                hit = true;
                break;
              }
            }
          }
          if (hit) continue;
        }

        if (c.age > 60) {
          const mg = 180;
          if (c.x < -mg || c.x > W + mg || c.y < -mg || c.y > H + mg) {
            comets.splice(i, 1);
            continue;
          }
        }

        const massScale = Math.sqrt(c.mass);
        const tLen = c.tail.length;
        if (tLen > 1) {
          ctx.strokeStyle = "rgb(255,210,140)";
          for (let t = 1; t < tLen; t++) {
            const p1 = c.tail[t - 1],
              p2 = c.tail[t];
            const prog = t / tLen;
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.globalAlpha = prog * 0.72 * c.alpha;
            ctx.lineWidth = Math.max(0.4, prog * 2.4 * b) * massScale;
            ctx.stroke();
          }
          const dStart = Math.max(0, tLen - 28);
          ctx.strokeStyle = "rgb(255,228,170)";
          for (let t = dStart + 1; t < tLen; t++) {
            const p1 = c.tail[t - 1],
              p2 = c.tail[t];
            const prog = (t - dStart) / (tLen - dStart);
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.globalAlpha = prog * 0.3 * c.alpha;
            ctx.lineWidth = Math.max(0.3, prog * 1.6 * b) * massScale;
            ctx.stroke();
          }
          ctx.globalAlpha = 1;
        }

        const glowR = 13 * b * massScale;
        const glow = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, glowR);
        glow.addColorStop(
          0,
          `rgba(255,230,200,${(0.95 * c.alpha).toFixed(3)})`,
        );
        glow.addColorStop(
          0.25,
          `rgba(255,170,110,${(0.6 * c.alpha).toFixed(3)})`,
        );
        glow.addColorStop(
          0.6,
          `rgba(220,110,60,${(0.25 * c.alpha).toFixed(3)})`,
        );
        glow.addColorStop(1, "rgba(160,70,40,0)");
        ctx.beginPath();
        ctx.arc(c.x, c.y, glowR, 0, Math.PI * 2);
        ctx.fillStyle = glow;
        ctx.globalAlpha = 1;
        ctx.fill();

        ctx.beginPath();
        ctx.arc(c.x, c.y, Math.max(1.2, 2.2 * b) * massScale, 0, Math.PI * 2);
        ctx.globalAlpha = c.alpha;
        ctx.fillStyle = "rgb(245,252,255)";
        ctx.fill();
        ctx.globalAlpha = 1;
      }

      cometTime++;
    },
  };
})();

const starRenderer = (() => {
  const C = document.getElementById("starfield");
  const ctx = C.getContext("2d");
  let frameN = 0,
    mx = 0.5,
    my = 0.5;
  let stars = [],
    shoot = null;
  let milkyWayCache = null;
  let dumbStarCache = null;

  const LAYERS = [
    {
      n: 160,
      rMin: 0.34,
      rMax: 0.72,
      op: 0.28,
      spd: 0.06,
      tBase: 0,
      tRange: 0.08,
    },
    {
      n: 55,
      rMin: 0.74,
      rMax: 1.28,
      op: 0.48,
      spd: 0.16,
      tBase: 0,
      tRange: 0.08,
    },
    {
      n: 18,
      rMin: 1.3,
      rMax: 2.1,
      op: 0.72,
      spd: 0.32,
      tBase: 0,
      tRange: 0.08,
    },
    {
      n: 220,
      rMin: 0.2,
      rMax: 0.55,
      op: 0.15,
      spd: 0.04,
      tBase: 0.08,
      tRange: 0.52,
    },
    {
      n: 110,
      rMin: 0.45,
      rMax: 0.95,
      op: 0.32,
      spd: 0.11,
      tBase: 0.15,
      tRange: 0.6,
    },
    {
      n: 45,
      rMin: 0.9,
      rMax: 1.7,
      op: 0.52,
      spd: 0.22,
      tBase: 0.35,
      tRange: 0.65,
    },
  ];

  function initStars(diag) {
    stars = [];
    for (let li = 0; li < LAYERS.length; li++) {
      const l = LAYERS[li];
      for (let i = 0; i < l.n; i++) {
        stars.push({
          x: (Math.random() - 0.5) * diag,
          y: (Math.random() - 0.5) * diag,
          r: l.rMin + Math.random() * (l.rMax - l.rMin),
          op: l.op * (0.5 + Math.random() * 0.5),
          tw: 0.3 + Math.random() * 2.4,
          to: Math.random() * Math.PI * 2,
          spd: l.spd,
          threshold: l.tBase + Math.random() * l.tRange,
        });
      }
    }
  }

  function buildDumbStars(diag) {
    const c = document.createElement("canvas");
    c.width = diag;
    c.height = diag;
    const mc = c.getContext("2d");
    mc.fillStyle = "#ebe1d2";
    for (let i = 0; i < 2500; i++) {
      const x = Math.random() * diag;
      const y = Math.random() * diag;
      const r = 0.2 + Math.random() * 0.6;
      mc.globalAlpha = 0.1 + Math.random() * 0.5;
      mc.beginPath();
      mc.arc(x, y, r, 0, Math.PI * 2);
      mc.fill();
    }
    return c;
  }

  document.addEventListener("mousemove", (e) => {
    if (!SETTINGS.toggles.parallax) return;
    mx = e.clientX / RW;
    my = e.clientY / RH;
  });

  function nightMultiplier() {
    const now = new Date();
    const h = now.getHours() + now.getMinutes() / 60;
    const nightH = h < 13 ? h + 24 : h;
    const peak = 25;
    const riseStart = 18,
      riseEnd = 23;
    const setStart = 27,
      setEnd = 30;
    if (nightH < riseStart || nightH >= setEnd) return 0;
    if (nightH < riseEnd)
      return (
        0.5 *
        (1 - Math.cos((Math.PI * (nightH - riseStart)) / (riseEnd - riseStart)))
      );
    if (nightH >= setStart)
      return (
        0.5 *
        (1 + Math.cos((Math.PI * (nightH - setStart)) / (setEnd - setStart)))
      );
    const distFromPeak = Math.abs(nightH - peak);
    return Math.max(
      0.4,
      1 - 0.6 * Math.pow(distFromPeak / (peak - riseEnd), 2),
    );
  }

  function buildMilkyWay(diagLen) {
    const mw = document.createElement("canvas");
    mw.width = diagLen;
    mw.height = diagLen;
    const mc = mw.getContext("2d");
    const halfBand = diagLen * 0.22;

    mc.save();
    mc.translate(diagLen * 0.5, diagLen * 0.5);
    const stretch = 3.5;
    mc.scale(1, stretch);
    mc.globalCompositeOperation = "lighter";

    const rOuter = halfBand;
    const g1 = mc.createRadialGradient(0, 0, 0, 0, 0, rOuter);
    g1.addColorStop(0, "rgba(90,100,165,0.07)");
    g1.addColorStop(0.5, "rgba(70,80,140,0.03)");
    g1.addColorStop(1, "rgba(70,80,140,0)");
    mc.fillStyle = g1;
    mc.beginPath();
    mc.arc(0, 0, rOuter, 0, Math.PI * 2);
    mc.fill();

    const rMid = halfBand * 0.55;
    const g2 = mc.createRadialGradient(0, 0, 0, 0, 0, rMid);
    g2.addColorStop(0, "rgba(180,185,228,0.09)");
    g2.addColorStop(0.5, "rgba(165,172,218,0.04)");
    g2.addColorStop(1, "rgba(155,165,210,0)");
    mc.fillStyle = g2;
    mc.beginPath();
    mc.arc(0, 0, rMid, 0, Math.PI * 2);
    mc.fill();

    const rCore = halfBand * 0.25;
    const g3 = mc.createRadialGradient(0, 0, 0, 0, 0, rCore);
    g3.addColorStop(0, "rgba(250,240,215,0.14)");
    g3.addColorStop(0.5, "rgba(238,226,200,0.06)");
    g3.addColorStop(1, "rgba(230,218,195,0)");
    mc.fillStyle = g3;
    mc.beginPath();
    mc.arc(0, 0, rCore, 0, Math.PI * 2);
    mc.fill();

    mc.scale(1, 1 / stretch);
    mc.globalCompositeOperation = "source-over";

    for (let i = 0; i < 2600; i++) {
      const u = Math.random(),
        v = Math.random();
      const gauss =
        Math.sqrt(-2 * Math.log(Math.max(u, 0.001))) *
        Math.cos(2 * Math.PI * v);
      const bx = gauss * halfBand * (0.38 + Math.random() * 0.1);
      const by = (Math.random() - 0.5) * diagLen * 1.3;
      const xFrac = Math.abs(bx) / halfBand;
      const yFrac = Math.abs(by) / (diagLen * 0.65);
      if (xFrac > 1 || yFrac > 1) continue;
      const opScale = Math.pow(1 - xFrac, 1.7) * Math.pow(1 - yFrac, 2.0);
      const r = 0.15 + Math.random() * 0.65;
      const warm = Math.random() > 0.52;
      const alpha = (0.008 + Math.random() * 0.1) * opScale;
      mc.beginPath();
      mc.arc(bx, by, r, 0, Math.PI * 2);
      mc.fillStyle = warm
        ? `rgba(255,242,210,${alpha.toFixed(3)})`
        : `rgba(185,205,255,${alpha.toFixed(3)})`;
      mc.fill();
    }
    mc.restore();
    milkyWayCache = mw;
  }

  return {
    resize(w, h) {
      C.width = w;
      C.height = h;
      const diag = Math.ceil(Math.sqrt(w * w + h * h));
      dumbStarCache = buildDumbStars(diag);
      initStars(diag);
      buildMilkyWay(diag);
    },
    draw() {
      const W = RW,
        H = RH;
      ctx.clearRect(0, 0, W, H);

      const doStars = SETTINGS.toggles.stars;
      const doMilkyWay = SETTINGS.toggles.milkyWay;

      if (!doStars && !doMilkyWay) {
        frameN++;
        return;
      }

      const mult = nightMultiplier();
      if (mult <= 0) {
        frameN++;
        return;
      }

      const diag = Math.ceil(Math.sqrt(W * W + H * H));

      const t = frameN * 0.011;
      const mwAlpha = mult > 0.12 ? 0.12 + (mult - 0.12) * 0.72 : 0;
      const globalRot = frameN * 0.0001;

      const pmx = SETTINGS.toggles.parallax ? mx : 0.5;
      const pmy = SETTINGS.toggles.parallax ? my : 0.5;

      ctx.save();
      ctx.translate(W * 0.5 + (pmx - 0.5) * 10, H * 0.5 + (pmy - 0.5) * 10);
      ctx.rotate(globalRot);

      if (doStars && dumbStarCache) {
        ctx.globalAlpha = Math.min(1, mult * 1.5);
        ctx.drawImage(dumbStarCache, -diag * 0.5, -diag * 0.5);
      }

      if (doMilkyWay && mwAlpha > 0 && milkyWayCache) {
        const mwBaseAngle = -Math.PI / 5.4;
        ctx.save();
        ctx.rotate(mwBaseAngle);
        ctx.globalAlpha = mwAlpha * 0.65;
        ctx.drawImage(milkyWayCache, -diag * 0.5, -diag * 0.5);
        ctx.restore();
      }

      if (doStars) {
        ctx.fillStyle = "#ebe1d2";
        const starCount = stars.length;
        const starLimit = Math.round(
          0.15 * starCount + 0.85 * mult * starCount,
        );

        for (let i = 0; i < Math.min(starLimit, starCount); i++) {
          const s = stars[i];
          if (mult < s.threshold) continue;
          const fade = Math.min(1, (mult - s.threshold) / 0.1);
          const tw = 0.62 + 0.38 * Math.sin(t * s.tw + s.to);
          const al = s.op * (0.45 + 0.55 * tw) * fade;

          const px = s.x + (pmx - 0.5) * s.spd * 20;
          const py = s.y + (pmy - 0.5) * s.spd * 20;

          ctx.globalAlpha = al;
          ctx.beginPath();
          ctx.arc(px, py, s.r, 0, Math.PI * 2);
          ctx.fill();

          if (s.r > 1.38) {
            const cr = s.r * 3;
            ctx.strokeStyle = "#e2d2b6";
            ctx.globalAlpha = al * 0.18;
            ctx.lineWidth = 0.48;
            ctx.beginPath();
            ctx.moveTo(px - cr, py);
            ctx.lineTo(px + cr, py);
            ctx.moveTo(px, py - cr);
            ctx.lineTo(px, py + cr);
            ctx.stroke();
          }
        }
      }

      ctx.restore();

      if (doStars) {
        ctx.globalAlpha = 1;
        if (!shoot && frameN % 420 === 0)
          shoot = {
            x: Math.random() * W,
            y: Math.random() * H * 0.4,
            t: 0,
          };

        if (shoot) {
          shoot.t++;
          const prog = shoot.t / 55;
          if (prog >= 1) {
            shoot = null;
          } else {
            const ex = shoot.x + 210 * prog,
              ey = shoot.y + 110 * prog;
            const ang = Math.atan2(110, 210),
              len = 129.6 * (1 - prog);
            const sx = ex - len * Math.cos(ang),
              sy = ey - len * Math.sin(ang);
            const g = ctx.createLinearGradient(sx, sy, ex, ey);
            g.addColorStop(0, "rgba(226,210,182,0)");
            g.addColorStop(
              1,
              `rgba(226,210,182,${((1 - prog) * 0.62).toFixed(3)})`,
            );
            ctx.beginPath();
            ctx.strokeStyle = g;
            ctx.globalAlpha = 1;
            ctx.lineWidth = 1.32;
            ctx.moveTo(sx, sy);
            ctx.lineTo(ex, ey);
            ctx.stroke();
          }
        }
      }

      frameN++;
    },
  };
})();

let _rafId = null;

function masterLoop() {
  if (typeof IS_NIGHT === "undefined" || !IS_NIGHT) {
    bgRenderer.draw();
    systemRenderer.draw();
  }
  cometRenderer.draw();
  if (typeof IS_NIGHT !== "undefined" && IS_NIGHT) {
    starRenderer.draw();
  }
  _rafId = requestAnimationFrame(masterLoop);
}

document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    if (_rafId !== null) {
      cancelAnimationFrame(_rafId);
      _rafId = null;
    }
  } else {
    if (_rafId === null) _rafId = requestAnimationFrame(masterLoop);
  }
});

let _resizeRequested = false;
window.addEventListener("resize", () => {
  if (!_resizeRequested) {
    _resizeRequested = true;
    requestAnimationFrame(() => {
      RW = window.innerWidth;
      RH = window.innerHeight;
      bgRenderer.resize(RW, RH);
      systemRenderer.resize(RW, RH);
      cometRenderer.resize(RW, RH);
      starRenderer.resize(RW, RH);
      _resizeRequested = false;
    });
  }
});

window.addEventListener("themeChange", () => {
  systemRenderer.invalidateCache();
  const clearCanvas = (id) => {
    const c = document.getElementById(id);
    c.getContext("2d").clearRect(0, 0, c.width, c.height);
  };
  clearCanvas("bg-canvas");
  clearCanvas("system-canvas");
  clearCanvas("starfield");

  if (typeof updateThemeColorMeta === "function") {
    requestAnimationFrame(updateThemeColorMeta);
  }
});

bgRenderer.resize(RW, RH);
systemRenderer.resize(RW, RH);
cometRenderer.resize(RW, RH);
starRenderer.resize(RW, RH);
_rafId = requestAnimationFrame(masterLoop);

let _settPendingLoc = null;

function _settOpen() {
  _settPendingLoc = null;

  const themeRadio = document.querySelector(
    `[name="sett-theme"][value="${SETTINGS.theme}"]`,
  );
  if (themeRadio) themeRadio.checked = true;

  const sizeVal = String(SETTINGS.size);
  const sizeRadio = document.querySelector(
    `[name="sett-size"][value="${sizeVal}"]`,
  );
  if (sizeRadio) sizeRadio.checked = true;

  document.getElementById("sett-username").value = SETTINGS.username;
  document.getElementById("sett-loc-input").value = SETTINGS.location.name;
  document.getElementById("sett-loc-status").textContent = "";

  const toggleKeys = [
    "clickComets",
    "timerComets",
    "asteroidBelt",
    "planets",
    "planetaryRotation",
    "parallax",
    "milkyWay",
    "stars",
  ];
  toggleKeys.forEach((k) => {
    const el = document.getElementById("sett-tog-" + k);
    if (el) el.checked = SETTINGS.toggles[k];
  });

  function _syncPlanetRotRow() {
    const planetsOn = document.getElementById("sett-tog-planets").checked;
    const rotRow = document.getElementById("sett-tog-row-planetaryRotation");
    rotRow.classList.toggle("sett-toggle-disabled", !planetsOn);
    if (!planetsOn)
      document.getElementById("sett-tog-planetaryRotation").checked = false;
  }
  _syncPlanetRotRow();
  document
    .getElementById("sett-tog-planets")
    .addEventListener("change", _syncPlanetRotRow);

  const scContainer = document.getElementById("sett-shortcuts");
  scContainer.replaceChildren();
  SETTINGS.shortcuts.forEach((sc, i) => {
    const sym = String.fromCodePoint(0x2460 + i);
    const row = document.createElement("div");
    row.className = "sett-sc-row";

    const numSpan = document.createElement("span");
    numSpan.className = "sett-sc-num";
    numSpan.textContent = sym;

    const nameIn = document.createElement("input");
    nameIn.type = "text";
    nameIn.className = "sett-input sett-sc-name-in";
    nameIn.id = "sett-sc-name-" + i;
    nameIn.value = sc.name;
    nameIn.placeholder = "name";

    const urlIn = document.createElement("input");
    urlIn.type = "text";
    urlIn.className = "sett-input sett-sc-url-in";
    urlIn.id = "sett-sc-url-" + i;
    urlIn.value = sc.url;
    urlIn.placeholder = "https://";

    row.appendChild(numSpan);
    row.appendChild(nameIn);
    row.appendChild(urlIn);
    scContainer.appendChild(row);
  });

  document.getElementById("sett-overlay").classList.add("open");
}

function _settClose() {
  document.getElementById("sett-overlay").classList.remove("open");
}

async function _settResolveLocation() {
  const val = document.getElementById("sett-loc-input").value.trim();
  if (!val) return;
  const statusEl = document.getElementById("sett-loc-status");
  statusEl.textContent = "resolving…";
  try {
    const r = await fetch(
      "https://geocoding-api.open-meteo.com/v1/search?name=" +
        encodeURIComponent(val) +
        "&count=1&language=en&format=json",
    );
    const d = await r.json();
    if (d.results && d.results[0]) {
      const loc = d.results[0];
      const name = loc.name + (loc.admin1 ? ", " + loc.admin1 : "");
      _settPendingLoc = { name, lat: loc.latitude, lon: loc.longitude };
      statusEl.textContent =
        "✓ " +
        name +
        " (" +
        loc.latitude.toFixed(3) +
        ", " +
        loc.longitude.toFixed(3) +
        ")";
    } else {
      statusEl.textContent = "✗ not found";
      _settPendingLoc = null;
    }
  } catch (_e) {
    statusEl.textContent = "✗ error";
    _settPendingLoc = null;
  }
}

function _settSave() {
  const themeEl = document.querySelector('[name="sett-theme"]:checked');
  const sizeEl = document.querySelector('[name="sett-size"]:checked');

  if (themeEl) SETTINGS.theme = themeEl.value;
  if (sizeEl) SETTINGS.size = parseFloat(sizeEl.value);

  const uname = document.getElementById("sett-username").value.trim();
  SETTINGS.username = uname || "user";

  if (_settPendingLoc) {
    SETTINGS.location = _settPendingLoc;
  }

  const toggleKeys = [
    "clickComets",
    "timerComets",
    "asteroidBelt",
    "planets",
    "planetaryRotation",
    "parallax",
    "milkyWay",
    "stars",
  ];
  toggleKeys.forEach((k) => {
    const el = document.getElementById("sett-tog-" + k);
    if (el) SETTINGS.toggles[k] = el.checked;
  });

  const shortcuts = [];
  for (let i = 0; i < 9; i++) {
    const nameEl = document.getElementById("sett-sc-name-" + i);
    const urlEl = document.getElementById("sett-sc-url-" + i);
    const name = nameEl ? nameEl.value.trim() : "";
    const url = urlEl ? urlEl.value.trim() : "";
    shortcuts.push({ name: name || "Link " + (i + 1), url: url || "#" });
  }
  SETTINGS.shortcuts = shortcuts;

  try {
    localStorage.setItem("_surf_settings", JSON.stringify(SETTINGS));
  } catch (_e) {}

  _applySettings();
  _settClose();
}

function _applySettings() {
  const h = new Date().getHours();
  if (typeof applyTheme === "function") applyTheme(h >= 6 && h < 19);
  document.documentElement.style.setProperty("--ui-scale", SETTINGS.size);
  _prevMin = -1;
  tick();
  renderShortcuts();
  loadWeather();
  updateCelestial();
}

document.getElementById("settings-btn").addEventListener("click", _settOpen);
document.getElementById("sett-close").addEventListener("click", _settClose);
document.getElementById("sett-save").addEventListener("click", _settSave);
document.getElementById("sett-reset").addEventListener("click", function () {
  if (confirm("Reset all settings to defaults?")) {
    try {
      localStorage.removeItem("_surf_settings");
    } catch (_e) {}
    location.reload();
  }
});
document
  .getElementById("sett-loc-resolve")
  .addEventListener("click", _settResolveLocation);
document.getElementById("sett-loc-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") _settResolveLocation();
});
document.getElementById("sett-overlay").addEventListener("click", (e) => {
  if (e.target === document.getElementById("sett-overlay")) _settClose();
});
