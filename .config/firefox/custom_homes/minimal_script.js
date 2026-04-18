// file 3 of 3 (minimal)
// TEST CONFIGURATION
const TEST_CONFIG = {
  forceTheme: false, // "dark", "light", or false
  forceWeather: false, // 0 (clear), 61 (rain), 71 (snow), 95 (storm), or false
  forceFestival: false, // "xmas", "halloween", "canada", "newyear", "fireworks", or false
};

window.activeGreeting = null;

function applyTheme(isDay) {
  if (TEST_CONFIG.forceTheme) {
    if (TEST_CONFIG.forceTheme === "dark")
      document.documentElement.classList.add("dark-theme");
    else document.documentElement.classList.remove("dark-theme");
    return;
  }

  const hr = new Date().getHours();
  if (isDay && hr >= 6 && hr < 18) {
    document.documentElement.classList.remove("dark-theme");
  } else {
    document.documentElement.classList.add("dark-theme");
  }
}

applyTheme(true);

// ----------------------------------------
// CLOCK & GREETING
function updateClock() {
  const now = new Date();
  const hours = now.getHours();
  const minutes = now.getMinutes().toString().padStart(2, "0");

  document.getElementById("clock").textContent = `${hours}:${minutes}`;

  const greetingEl = document.getElementById("greeting");

  if (window.activeGreeting) {
    greetingEl.textContent = window.activeGreeting;
    return;
  }

  const day = now.getDay();

  if (day === 5 && hours >= 16) {
    greetingEl.textContent = "Happy Friday, snes.";
  } else if (hours < 12) {
    greetingEl.textContent = "Good morning, snes.";
  } else if (hours < 18) {
    greetingEl.textContent = "Good afternoon, snes.";
  } else {
    greetingEl.textContent = "Good evening, snes.";
  }
}
setInterval(updateClock, 1000);
updateClock();

// ----------------------------------------
// SEARCH & SHORTCUTS
const searchInput = document.getElementById("search");
searchInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && searchInput.value.trim()) {
    window.location.href = `https://www.google.com/search?q=${encodeURIComponent(searchInput.value.trim())}`;
  }
});

const SHORTCUTS = [
  {
    label: "Quercus",
    href: "https://q.utoronto.ca/",
    icon: `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l9 4.5-9 4.5-9-4.5z"/><path d="M5 9v6c0 3 7 3 7 3s7 0 7-3V9"/><path d="M19 10v4"/><circle cx="19" cy="15" r="1"/></svg>`,
  },
  {
    label: "Acorn",
    href: "https://acorn.utoronto.ca/",
    icon: `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2c-2.5 0-4.5 1.5-5.5 3.5S4 10 4 12c0 3 2.5 5 5 5h6c2.5 0 5-2 5-5 0-2-1.5-4.5-2.5-6.5S14.5 2 12 2z"/><path d="M12 17v5"/><path d="M9 22h6"/></svg>`,
  },
  {
    label: "YouTube",
    href: "https://youtube.com",
    icon: `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22.54 6.42a2.78 2.78 0 0 0-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 0 0-1.94 2A29 29 0 0 0 1 11.75a29 29 0 0 0 .46 5.33 2.78 2.78 0 0 0 1.94 2C5.12 19.5 12 19.5 12 19.5s6.88 0 8.6-.46a2.78 2.78 0 0 0 1.94-2 29 29 0 0 0 .46-5.33 29 29 0 0 0-.46-5.33z"/><polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02"/></svg>`,
  },
  {
    label: "Archwiki",
    href: "https://wiki.archlinux.org/",
    icon: `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 9l3 3-3 3M13 17h4"/><rect x="3" y="4" width="18" height="16" rx="2" ry="2"/></svg>`,
  },
  {
    label: "Outlook",
    href: "https://outlook.office.com",
    icon: `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2" ry="2"/><path d="M3 7l9 6 9-6"/></svg>`,
  },
];

const linksContainer = document.getElementById("links");
SHORTCUTS.forEach(({ label, href, icon }) => {
  const a = document.createElement("a");
  a.className = "shortcut";
  a.href = href;
  a.innerHTML = `${icon}<span>${label}</span>`;
  linksContainer.appendChild(a);
});

// ----------------------------------------
// EFFECTS
const fxContainer = document.getElementById("dynamic-effects");

function createParticles(className, count, styleFunc) {
  for (let i = 0; i < count; i++) {
    const el = document.createElement("div");
    el.className = className;
    Object.assign(el.style, styleFunc(i));
    fxContainer.appendChild(el);
  }
}

function injectSpaceObjects() {
  const saturn = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  saturn.setAttribute("class", "floating-obj");
  saturn.setAttribute("viewBox", "0 0 100 100");
  saturn.style.top = "15%";
  saturn.style.right = "10%";
  saturn.style.width = "100px";
  saturn.innerHTML = `<circle cx="50" cy="50" r="20"/><ellipse cx="50" cy="50" rx="40" ry="10" transform="rotate(-20 50 50)"/>`;
  fxContainer.appendChild(saturn);

  const starBase = document.createElementNS(
    "http://www.w3.org/2000/svg",
    "svg",
  );
  starBase.setAttribute("class", "floating-obj");
  starBase.setAttribute("viewBox", "0 0 50 50");
  starBase.style.bottom = "20%";
  starBase.style.left = "15%";
  starBase.style.width = "60px";
  starBase.style.animationDelay = "-5s";
  starBase.innerHTML = `<polygon points="25,5 30,20 45,20 32,30 37,45 25,35 13,45 18,30 5,20 20,20"/>`;
  fxContainer.appendChild(starBase);
}

function injectXmasTree() {
  const tree = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  tree.setAttribute("class", "xmas-tree");
  tree.setAttribute("viewBox", "0 0 100 120");
  tree.innerHTML = `
    <polygon points="50,15 20,55 40,55 10,95 90,95 60,55 80,55" fill="var(--accent)" />
    <rect x="40" y="95" width="20" height="25" fill="var(--text-muted)" />
    <polygon style="transform-origin: 50px 15px; transform: scale(0.6);" points="50,0 54,10 65,10 56,16 60,26 50,20 40,26 44,16 35,10 46,10" fill="var(--text-main)" />
  `;
  fxContainer.appendChild(tree);
}

function injectHalloween() {
  const glow = document.createElement("div");
  glow.className = "halloween-glow";
  fxContainer.appendChild(glow);

  for (let i = 0; i < 3; i++) {
    const bat = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    bat.setAttribute("class", "bat");
    bat.setAttribute("viewBox", "0 0 100 50");
    bat.style.animationDelay = `${i * 3}s`;
    bat.style.top = `${Math.random() * 40}vh`;
    bat.innerHTML = `<path d="M50,20 Q40,0 10,10 Q20,30 50,40 Q80,30 90,10 Q60,0 50,20 Z" />`;
    fxContainer.appendChild(bat);
  }
}

// --- FIREWORKS ---
let autoFireworkTimeout;
function startFireworks(customColors) {
  window.human = false;
  const canvasEl = document.getElementById("fireworks-canvas");
  const ctx = canvasEl.getContext("2d");
  const numberOfParticules = 30;
  let pointerX = 0;
  let pointerY = 0;

  function setCanvasSize() {
    canvasEl.width = window.innerWidth * 2;
    canvasEl.height = window.innerHeight * 2;
    canvasEl.style.width = window.innerWidth + "px";
    canvasEl.style.height = window.innerHeight + "px";
    ctx.scale(2, 2);
  }

  function getColors() {
    if (customColors) return customColors;
    const style = getComputedStyle(document.body);
    return [
      style.getPropertyValue("--accent").trim(),
      style.getPropertyValue("--text-main").trim(),
      style.getPropertyValue("--text-muted").trim(),
    ];
  }

  function setParticuleDirection(p) {
    const angle = (anime.random(0, 360) * Math.PI) / 180;
    const value = anime.random(50, 150);
    const radius = [-1, 1][anime.random(0, 1)] * value;
    return {
      x: p.x + radius * Math.cos(angle),
      y: p.y + radius * Math.sin(angle),
    };
  }

  function createParticule(x, y) {
    const p = {};
    p.x = x;
    p.y = y;
    const colors = getColors();
    p.color = colors[anime.random(0, colors.length - 1)];
    p.radius = anime.random(8, 24);
    p.endPos = setParticuleDirection(p);
    p.draw = function () {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, 2 * Math.PI, true);
      ctx.fillStyle = p.color;
      ctx.fill();
    };
    return p;
  }

  function renderParticule(anim) {
    for (let i = 0; i < anim.animatables.length; i++) {
      anim.animatables[i].target.draw();
    }
  }

  function animateParticules(x, y) {
    const particules = [];
    for (let i = 0; i < numberOfParticules; i++) {
      particules.push(createParticule(x, y));
    }
    anime.timeline().add({
      targets: particules,
      x: function (p) {
        return p.endPos.x;
      },
      y: function (p) {
        return p.endPos.y;
      },
      radius: 0.1,
      duration: anime.random(1200, 1800),
      easing: "easeOutExpo",
      update: renderParticule,
    });
  }

  const render = anime({
    duration: Infinity,
    update: function () {
      ctx.clearRect(0, 0, canvasEl.width / 2, canvasEl.height / 2);
    },
  });

  document.addEventListener(
    "mousedown",
    function (e) {
      if (e.target.tagName === "INPUT" || e.target.closest("a")) return;
      window.human = true;
      pointerX = e.clientX;
      pointerY = e.clientY;
      animateParticules(pointerX, pointerY);
    },
    false,
  );

  function autoClick() {
    if (window.human) return;
    const centerX = window.innerWidth / 2;
    const centerY = window.innerHeight / 2;
    animateParticules(
      anime.random(centerX - 150, centerX + 150),
      anime.random(centerY - 150, centerY + 150),
    );
    autoFireworkTimeout = setTimeout(autoClick, anime.random(1000, 2500));
  }

  setCanvasSize();
  window.addEventListener("resize", setCanvasSize, false);
  autoClick();
}

function stopFireworks() {
  clearTimeout(autoFireworkTimeout);
  const canvasEl = document.getElementById("fireworks-canvas");
  const ctx = canvasEl.getContext("2d");
  ctx.clearRect(0, 0, canvasEl.width, canvasEl.height);
}

// --- MAIN EFFECT ---
function triggerEffects(apiWeatherCode) {
  fxContainer.innerHTML = "";
  window.activeGreeting = null;
  stopFireworks();

  const date = new Date();
  const month = date.getMonth();
  const day = date.getDate();

  const activeWeather =
    TEST_CONFIG.forceWeather !== false
      ? TEST_CONFIG.forceWeather
      : apiWeatherCode;
  const activeFestival =
    TEST_CONFIG.forceFestival !== false ? TEST_CONFIG.forceFestival : null;

  // Festivals
  let isHoliday = false;

  if (activeFestival === "xmas" || (!activeFestival && month === 11)) {
    window.activeGreeting = "Merry Christmas, snes.";
    createParticles("xmas-light", 25, (i) => ({
      left: `${i * 4}%`,
      animationDelay: `${Math.random() * 2}s`,
    }));
    injectXmasTree();
    isHoliday = true;
  }

  if (activeFestival === "halloween" || (!activeFestival && month === 9)) {
    window.activeGreeting = "Happy Halloween, snes.";
    injectHalloween();
    isHoliday = true;
  }

  if (
    activeFestival === "canada" ||
    (!activeFestival && month === 6 && day === 1)
  ) {
    window.activeGreeting = "Happy Canada Day, snes.";
    startFireworks(["#FF0000", "#FFFFFF"]);
    isHoliday = true;
  }

  if (
    activeFestival === "newyear" ||
    (!activeFestival && month === 0 && day === 1)
  ) {
    window.activeGreeting = "Happy New Year, snes.";
    startFireworks([
      "#ff0044",
      "#00ff44",
      "#4400ff",
      "#ffea00",
      "#00eaff",
      "#ff00aa",
    ]);
    isHoliday = true;
  }

  if (activeFestival === "fireworks" && !isHoliday) {
    startFireworks(null);
    isHoliday = true;
  }

  updateClock();

  // Weather
  let hasWeatherFx = false;
  if (activeWeather >= 51 && activeWeather <= 67) {
    createParticles("rain-drop", 50, () => ({
      left: `${Math.random() * 100}vw`,
      animationDuration: `${Math.random() * 0.5 + 0.5}s`,
      animationDelay: `${Math.random() * 2}s`,
    }));
    hasWeatherFx = true;
  } else if (activeWeather >= 71 && activeWeather <= 86) {
    createParticles("snow-flake", 80, () => ({
      left: `${Math.random() * 100}vw`,
      animationDuration: `${Math.random() * 3 + 4}s`,
      animationDelay: `${Math.random() * 5}s`,
    }));
    hasWeatherFx = true;
  } else if (activeWeather >= 1 && activeWeather <= 3) {
    createParticles("cloud", 4, () => ({
      top: `${Math.random() * 40}vh`,
      width: `${Math.random() * 200 + 150}px`,
      height: `${Math.random() * 40 + 40}px`,
      animationDuration: `${Math.random() * 30 + 40}s`,
      animationDelay: `-${Math.random() * 40}s`,
    }));
  } else if (activeWeather >= 95) {
    createParticles("rain-drop", 80, () => ({
      left: `${Math.random() * 100}vw`,
      animationDuration: `${Math.random() * 0.4 + 0.4}s`,
    }));
    const thunder = document.createElement("div");
    thunder.className = "thunder";
    fxContainer.appendChild(thunder);
    hasWeatherFx = true;
  }

  // Default Cosmology
  if (!hasWeatherFx) {
    createParticles("meteor", 4, () => ({
      left: `${Math.random() * 100}vw`,
      top: `${Math.random() * 50}vh`,
      animationDelay: `${Math.random() * 15}s`,
    }));
    createParticles("comet", 1, () => ({
      left: `${Math.random() * 100}vw`,
      top: `${Math.random() * 30}vh`,
      animationDelay: `${Math.random() * 25}s`,
    }));
    injectSpaceObjects();
  }
}

// ----------------------------------------
// WEATHER API
async function loadWeather() {
  try {
    const res = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=43.654&longitude=-79.383&current=temperature_2m,weather_code,is_day&timezone=auto`,
    );
    const data = await res.json();

    const temp = Math.round(data.current.temperature_2m);
    const code = data.current.weather_code;
    const isDay = data.current.is_day === 1;

    applyTheme(isDay);
    triggerEffects(code);

    document.getElementById("wx-temp").textContent = `${temp}°C`;

    let svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>`;

    if (!isDay && code === 0) {
      svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>`;
    } else if (code >= 1 && code <= 3) {
      svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/></svg>`;
    } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="16" y1="13" x2="16" y2="21"/><line x1="8" y1="13" x2="8" y2="21"/><line x1="12" y1="15" x2="12" y2="23"/><path d="M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"/></svg>`;
    } else if (code >= 71 && code <= 86) {
      svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="2" y1="12" x2="22" y2="12"/><line x1="12" y1="2" x2="12" y2="22"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>`;
    } else if (code >= 95) {
      svgIcon = `<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`;
    }

    document.getElementById("wx-emoji").innerHTML = svgIcon;
  } catch (e) {
    document.getElementById("wx-temp").textContent = "N/A";
    triggerEffects(
      TEST_CONFIG.forceWeather !== false ? TEST_CONFIG.forceWeather : 0,
    );
  }
}

loadWeather();
