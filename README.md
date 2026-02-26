# surface-dots

Personal dotfiles + UI setup for my **Surface Laptop 4 (AMD)** running **Hyprland**.
Also, please check out my calendar app: [Evercal](https://github.com/snes19xx/EverCal)

---

## Table of contents

- [Dependencies](#dependencies)
- [Hyprland](#hyprland)
- [Shaders](#shaders)
- [Quickshell Bar](#quickshell-bar)
- [Quickshell Hub (`snes-hub`)](#quickshell-hub-snes-hub)
- [Power menu](#power-menu)
- [Wifi menu](#wifi-menu)
- [Pixel sddm theme](#pixel-sddm-theme)
- [Firefox custom new-tab](#firefox-custom-new-tab)
- [Surface-only features](#surface-only-features)
- [Credits & acknowledgements](#credits--acknowledgements)
- [Media sources](#media-sources)

---

<div align="center">
  <img src="media/screenshots/ss1.png" width="45%" />
  <img src="media/screenshots/ss2.png" width="45%" />
  <p><i>SDDM: Lock Screen & Login Screen (hyprlock also looks just like this + with media information if playing when locked)</i></p>
  
  <br/>

  <img src="media/screenshots/ss4.png" width="45%" />
  <img src="media/screenshots/ss6.png" width="45%" />
  <p><i>Dark Mode & Light Mode (Hub + Rofi)</i></p>

  <br/>

  <img src="media/screenshots/reading_mode.png" width="45%" />
  <img src="media/screenshots/ss12.png" width="45%" />
  <p><i>Reading mode & Various other apps</i></p>
</div>

## Dependencies

<table>
<tr>
<td valign="top">

### Core & System

- Hyprland
- hypridle
- hyprlock
- hyprshade
- hyprland-plugins
- xdg-utils
- xdg-desktop-portal-hyprland
- xdg-desktop-portal-kde
- xdg-desktop-portal-gtk
- polkit-gnome
- sddm
- networkmanager
- bluez, blueman

</td>
<td valign="top">

### UI & Theming

- dunst
- swww
- waypaper
- rofi
- kitty
- firefox
- colorreload-gtk-module
- Everforest-Dark-theme
- EVerforest-Light-theme
- qt6ct
- kvantum
- papirus-icon-theme
- ttf-manrope
- ttf-nerd-fonts-symbols
- inter-font

</td>
<td valign="top">

### Utilities

- grim, slurp, swappy, grimblast
- pamixer, pipewire-pulse or pulseaudio
- playerctl
- brightnessctl
- quickshell
- vdirsyncer
- khal
- [EverCal](https://github.com/snes19xx/EverCal)
- xdg-utils
- curl, jq
- flutter, dart
- linux-surface tools (Linux-surface only)
- auto-cpufreq

</td>
</tr>
</table>

---

> [!CAUTION]
> Layout geometry is hardcoded for 3:2 high-resolution display. Deviation in aspect ratio or pixel density will result in misalignment or things looking too big or small. Please reconfigure values accordingly.

## Hyprland

Main config is for Hyprland v0.53: `~/.config/hypr/hyprland.conf`
Old Config at `~/.config/hypr/hyprland_OLD.conf`

<details>
  <summary><strong>Keybindings</strong></summary>

### Apps

- `SUPER + Q` → terminal (`kitty`)
- `SUPER + E` → file manager (`thunar`)
- `SUPER + R` → rofi
- `SUPER + B` → firefox
- `SUPER + D` → reading mode
- `SUPER + S` → my custom ocr app

### Window actions

- `SUPER + SPACE` → toggle hub on or off
- `SUPER + X` → kill active window
- `SUPER + F` → toggle floating (simple)
- `SUPER + ALT + F` → toggle floating **and** set size `900x600` + center
- `SUPER + M` → fullscreen
- `SUPER + P` → pseudotile
- `SUPER + UP` → togglesplit
- `SUPER + DOWN` → togglesplit

### Exit

- `ALT + F4` → Power menu
- `SUPER + ALT + F4` → exit Hyprland

### Focus (arrow keys)

- `SUPER + Left/Right` → move focus horizontally
- `SUPER + UP/Down` → move focus vertically

### Workspaces

- `SUPER + 1..0` → workspace `1..10`
- `SUPER + SHIFT + 1..0` → move active window to workspace `1..10`
- `SUPER + mouse wheel` → next/prev workspace
- `SUPER + G` → toggle group
- `SUPER+CTRL+LEFT/RIGHT` → move across grouped windows

### Scratchpad (“special workspace”)

- `SUPER + H` → toggle special workspace `magic`
- `SUPER + SHIFT + S` → move active window to `special:magic`

### Mouse (window move/resize)

- `SUPER + LMB` → move window
- `SUPER + RMB` → resize window

### Screenshots

- `Print` → screenshot script mode `s`
- `SUPER + Print` → mode `p`
- `SUPER + SHIFT + Print` → mode `sf`
- `SUPER + O` → mode `m`

</details>

---

## Shaders

activate with:
`hyprshade on <name of the shader.glsl>`

deactivate with:
`hyprshade off`

### Reading Mode

A shader-based reading mode to mimic an e-ink reader.

- Toggle with `SUPER + D` or `~/.config/hypr/shaders/reading_mode.sh`
- Automatically disables animations, shadows, and blur
- Custom GLSL shader with e-ink-like color reproduction
- Warm cream paper tone
- Soft charcoal blacks for reduced contrast
- Fine paper grain -like texture
- Shader located at `~/.config/hypr/shaders/reading_mode.glsl`
- Uses [hyprshade](https://github.com/loqusion/hyprshade)

### Other shaders

**Ranked from Useful to completely Useless:**

1. **`main.glsl`** – _my main shader to improve my display (I run it at startup)_
2. **`night.glsl`** – _my main night-light mode shader (script coming soon)_
3. **`outdoor.gls`** – _for maximum outdoor useability_
4. **`cinema.glsl`** – _for media consumption_
5. **`soft.glsl`** – _soft, muted textures_
6. **`matte.glsl`** – _anti-glare, matte_
7. **`IMB5151.glsl`** – _simulates vintage IBM 3278 / 5151 monitors_
8. **`fuji_acros.glsl`** – _simulates fujifilm acros_
9. **`crt_mode.glsl`** – _simulates a crt monitor/retro nostalgia_
10. **`vhs.glsl`** – _simulates vhs_
11. **`gameboy.glsl`** – _simulates a gameboy screen_
12. **`clarity_inefficient.glsl`** – _an early version of my main shader_
13. **`focus.glsl`** – _party trick_
14. **`night_vision.glsl`** – _simulates night_vision_

## Quickshell Bar

The bar uses an Arch glyph icon (top left) as the launcher button:

- Left click: launches rofi, choosing a different launcher script depending on the current theme mode.
- Right click: toggles the bar’s isDarkMode and calls a theme script:

```bash
bash ~/config/quickshell/snes-hub/bar/theme-mode.sh dark|light
```

<details>
  <summary><strong>Expand for Bar components</strong></summary>

### Workspaces

Clicking a workspace pill runs: `- hyprctl dispatch workspace <id>`

### Updates

Updates are shown using a poller, but it won’t run checkupdates while pacman is busy (to avoid lock-related crashes). When the pacman lock file exists, the bar displays the last cached update count instead. Polled with:

```bash
if [ -e /var/lib/pacman/db.lck ]; then
  cat /tmp/qs_updates_count 2>/dev/null || echo 0
else
  checkupdates 2>/dev/null | wc -l | tee /tmp/qs_updates_count
fi

```

Clicking the updates pill runs:

```bash
kitty -e bash -lc "sudo pacman -Syu"
```

### Date and Clock

- Pressing the clock triggers a requestHubToggle() signal (used to open/close the hub).
- Esc closes the hub (or clicking anywhere outside it).

</details>

## Quickshell Hub (`snes-hub`)

- Toggled by clicking the date/clock module in the bar or SUPER+SPACE keybinding through hyprland
- The hub window is an overlay (wlr-layershell) and is designed to get out of your way quickly:
- Organized into reusable components, making it straightforward to add/remove cards or re-skin pieces without rewriting the whole hub.
- If you want a lightweight fallback, use the early **AGS** version in `.config/ags/` (works, but fewer features).

<details>
  <summary><strong>Components (click to expand)</strong></summary>

<img src="media/screenshots/comparison.png" align="right" width="580" alt="Hub comparison" />
    
#### Header
- Profile icon,username + RAM/CPU usage chips.
- Screenshot button (runs the capture script and then closes the hub).
- Power button

#### Power options

- Compact power grid that expands (click the power button or press `p` key) _inside the header_ (no extra window):
- Keyboard navigation: **Arrow keys / Tab** to move, **Enter** to trigger, **Esc** to close.

#### Buttons and Sliders

- Wi‑Fi toggle + SSID readout (right‑click opens wifi module).
- Bluetooth toggle + connected device status.
- Performance profile button (cycle modes via `auto-cpufreq`, right click toggles battery health card).
- DND toggle (dunst).
- Volume + brightness sliders (pactl + brightnessctl).

#### Battery health

- Polls: `upower -i /org/freedesktop/UPower/devices/battery_BAT1`
- Shows: **Health** (capacity %) + **current charge %**, **Charge cycles**, **Energy (full / design)**, **Time remaining** (to full/empty when available), **State** (charging/discharging/fully-charged)

> [!NOTE]
> If your battery isn’t `battery_BAT1`, swap the device path in `BatteryHealthCard.qml` to match your system.

#### Media card (MPRIS)

- The hub includes an MPRIS-powered media card:
- Clicking the media card launches the external now-playing widget and then toggles the hub off.
- It tracks metadata changes and resets its internal timing state when tracks change. It's still finicky with some browser contents like youtube videos
- Only appears when something is playing

#### Now Playing (Flutter)

- This is a separate Flutter desktop widget (class rules are handled in Hyprland).
- Resizable is disabled (setResizable(false) is used)
- Esc closes the widget
- Generates theme colors from album art using palette_generator

#### Calendar, Weather and Events

A simple calendar with weather (json based script and events from my google calendar using khal+ vdirsyncer.

<details>
<summary><strong>Google Calendar sync (vdirsyncer + khal)</strong></summary>

Recommended approach (avoids system Python packaging issues):

```bash
sudo pacman -S --needed python-pipx
```

```python
pipx install "vdirsyncer[google]"
```

- If you have both a system and pipx vdirsyncer, remove the system one and make sure PATH prefers ~/.local/bin.

###### Config

Create folders:

```bash
mkdir -p ~/.config/vdirsyncer/status ~/.config/vdirsyncer/tokens
mkdir -p ~/.local/share/vdirsyncer/calendars
```

Example vdirsyncer config uses:
`token_file = "~/.config/vdirsyncer/tokens/google_calendar"`
`type = "google_calendar"`
`client_id / client_secret` from Google Cloud OAuth
`~/.local/share/vdirsyncer/calendars/*` - Khal reads .ics files from here

###### Note:

- You must enable CalDAV API in Google Cloud (not only the “Google Calendar API”).
- If OAuth consent is in Testing mode, add yourself as a “Test user”.
- If you get “token obtained but Not Found”, enable calendars at: https://calendar.google.com/calendar/syncselect

###### Run + test

```bash
vdirsyncer discover
vdirsyncer sync
khal list now 7d
```

</details>

#### Notifications

- Clicking dismisses.
- Uses **dunst** (`dunstctl`) as the notification backend.
- Contracted by default when the media player card is active, but can be expanded via the expand button.

#### OSDs

- custom OSDs for brightness and volume controls
- custom OSD for various modes (Dark/Light/Reading Mode etc.)

</details>

## Power menu

<div align="center">
  <table>
    <tr>
      <td>
        <img src="media/screenshots/powermenu.png" height="200" alt="Quickshell Power Menu screenshot (Dark)" />
      </td>
      <td>
        <img src="media/screenshots/powermenu_light.png" height="200" alt="Quickshell Power Menu screenshot (Light)" />
      </td>
    </tr>
  </table>
</div>

wlr-layershell power menu overlay (separate from the hub header menu). Toggled with ALT+F4
**Run**

```bash
quickshell -p ~/.config/quickshell/snes-hub/bar/PowerMenu.qml
```

## Wifi menu

Standalone network manager applet located at lib/WifiMenu.qml. With both (light/dark) theme.

- Trigger: Right-click the Wi-Fi button in the Hub.
- or run: `quickshell -p ~/.config/quickshell/snes-hub/lib/Wifimenu.qml`

> [!WARNING]
> You cannot connect to enterprise access points (for now), I haven't had the time to fix it yet

## Pixel sddm theme

[Note: I am using qt5, please install qt5 dependencies]

```bash
sudo pacman -S qt6-5compat qt6-svg qqc2-desktop-style inter-font ttf-nerd-fonts-symbols
```

_<b>if you don't want windows hello like animation please use main.qml from the </b>`old` <b>directory</b>_

- To install:
  - move the contents of sddm/theme folder to `/usr/share/sddm/themes/` (create the dir if it doesn't exist yet)
  - Set "pixel" as the current theme by creating a config file in `/etc/sddm.conf.d/`:
  - make sure the directory exists:

  ```bash
  sudo mkdir -p /etc/sddm.conf.d
  ```

  - then create the config file:

  ```bash
  echo -e "[Theme]\nCurrent=pixel" | sudo tee /etc/sddm.conf.d/theme.conf
  ```

## Firefox custom new-tab

- Custom Firefox start page: https://github.com/snes19xx/custom-firefox-start
- usercss (Also in this repo): https://github.com/snes19xx/firefox-customizations

Firefox doesn't really want you to use local html as a new tab page so

- Move autoconfig.js to Firefox defaults/pref/ (e.g. /usr/lib/firefox/defaults/pref/)
- Edit mozilla.cfg (repo path: .config/firefox/mozilla.cfg) and set your file path
- Move mozilla.cfg to the Firefox install directory root (e.g. /usr/lib/firefox/)

## Credits & acknowledgements

- [Everforest-GTK-Theme](https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme) by Fausto-Korpsvart
- Rofi themes loosely based on @adi1090x's [type 7](https://github.com/adi1090x/rofi/blob/master/previews/launchers/type-7/5.png)
- `Pixeldots.qml` in sddm theme based on @mahaveergurjar's [Pixeldots](https://github.com/mahaveergurjar/sddm/tree/pixel)
- Colors: Modified from https://github.com/sainnhe/everforest
- SVG icons: https://www.svgrepo.com/
- linux-surface project: https://github.com/linux-surface/linux-surface
- Thorium: https://thorium.rocks/ for the background visualizations in firefox custom new tab

## Media sources

1. Photo by fffunction studio on [Unsplash](https://unsplash.com/photos/green-trees-near-mountains-during-daytime-IrWgzQ_Y_zg)
2. Photo by Brian McGowan on [Unsplash](https://unsplash.com/photos/astronaut-in-white-suit-in-grayscale-photography-I0fDR8xtApA)
3. Photo by Mimicry Hu on [Unsplash](https://unsplash.com/photos/aerial-photography-of-persons-on-plant-field-24tsXm7qGQE)
4. Photo by Bailey Zindel on [Unsplash](https://unsplash.com/photos/body-of-water-surrounded-by-trees-NRQV-hBF10M)
5. Photo by on Jay Yu on [Unsplash](https://unsplash.com/photos/silhouette-of-trees-under-starry-night-atiSW3NHtUM)
6. Photo by Ben Dutton on [Unsplash](https://unsplash.com/photos/green-trees-FKrcPEZfoNU)
7. Photo by Richard Rhee on [Flickr](https://www.flickr.com/photos/rcrhee/15167206848/)
8. Photo by Cedric Chambaz on [Flickr](https://www.flickr.com/photos/cchambaz/2391578535/in/gallery-195423583@N07-72157720611385337/)

[OC]

- Lucina wallpaper from [Fire Emblem Awekening Artbook](https://www.amazon.ca/Art-Fire-Emblem-Awakening-ebook/dp/B01J1XIC2O)
- Final Fantasy X logo: by [Yoshitaka Amano](https://en.yoshitaka-amano.com/#/)
- Most Monogatari wallpapers are edited from the scans of [Monogatari Series 10th Anniversary Illustration Works Art Book](https://www.ebay.ca/itm/403993406564)
- crab2,hanekawa3 and crab2.png are form [AhogeDesu](https://imgur.com/gallery/utamonogatari-styled-heroines-DH4ca2m)

- All Rofi pictures were pulled from Pinterest; I don’t know the original owners.

#### <span style="color:#a41d1d">[Reuse Note:]</span>

Feel free to copy/steal whatever you want as long as you cite me and
more importantly the listed media sources in the credits/references where applicable.
