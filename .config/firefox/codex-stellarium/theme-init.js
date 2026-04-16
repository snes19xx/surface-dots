let IS_NIGHT = false;
let _themeInit = false;

const _savedTheme = (() => {
  try {
    return (
      JSON.parse(localStorage.getItem("_surf_settings") || "{}").theme || "auto"
    );
  } catch (_e) {
    return "auto";
  }
})();

function updateThemeColorMeta() {
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!meta) {
    meta = document.createElement("meta");
    meta.name = "theme-color";
    document.head.appendChild(meta);
  }

  const el = document.body || document.documentElement;
  if (el) {
    const bgColor = getComputedStyle(el).backgroundColor;
    if (bgColor !== "rgba(0, 0, 0, 0)" && bgColor !== "transparent") {
      meta.content = bgColor;
    }
  }
}

function applyTheme(isDay) {
  const theme = typeof SETTINGS !== "undefined" ? SETTINGS.theme : _savedTheme;
  const h = new Date().getHours();
  let nextNight;

  if (theme === "dark") nextNight = true;
  else if (theme === "light") nextNight = false;
  else nextNight = !(isDay && h >= 6 && h < 19);

  const prevNight = IS_NIGHT;
  IS_NIGHT = nextNight;

  document.documentElement.classList.toggle("night", IS_NIGHT);

  requestAnimationFrame(updateThemeColorMeta);

  if (_themeInit && prevNight !== IS_NIGHT) {
    window.dispatchEvent(new Event("themeChange"));
  }
}

applyTheme(true);
_themeInit = true;

window.addEventListener("DOMContentLoaded", updateThemeColorMeta);
