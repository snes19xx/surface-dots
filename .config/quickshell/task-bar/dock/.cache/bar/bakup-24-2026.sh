#!/bin/bash
set -e

# --- CONFIGURATION ---
THEME_DARK="Everforest-Dark-Green-Dark"
THEME_LIGHT="Everforest-Light-Green-Light"
ICONS_DARK="Papirus-Dark"
ICONS_LIGHT="Papirus-Light"

# Colors (Kvantum Patching)
KVANTUM_DARK_BG="#1e2326"
KVANTUM_DARK_TEXT="#d3c6aa"
KVANTUM_LIGHT_BG="#fdf6e3"
KVANTUM_LIGHT_TEXT="#5c6a72"

# Wallpapers
WALLPAPER_DARK="$HOME/Pictures/desktop/1.png"
WALLPAPER_LIGHT="$HOME/Pictures/desktop/l2.png"

# Paths
GTK3_CONF="$HOME/.config/gtk-3.0"
GTK3_SETTINGS="$GTK3_CONF/settings.ini"
GTK4_CONF="$HOME/.config/gtk-4.0"

# KDE / Kvantum Paths
KDE_GLOBALS="$HOME/.config/kdeglobals"
KDE_GLOBALS_DARK="$HOME/.config/Kvantum/EverforestGreenDark/kdeglobals.dark"
KDE_GLOBALS_LIGHT="$HOME/.config/Kvantum/EverforestGreenLight/kdeglobals.light"

STATE_FILE="$HOME/.cache/quickshell/theme_mode"
KITTY_STATE="$HOME/.local/state/theme/kitty_theme.conf"

# --- VS CODE CONFIGURATION ---
# NOTE: It is recommended to handle theming natively in VS Code settings.json
# using the following keys rather than this script:
#   "workbench.preferredDarkColorTheme": "Everforest Dark",
#   "workbench.preferredLightColorTheme": "Everforest Light"
#
# However, the legacy file-write method is preserved below:
#VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
#VSCODE_SETTINGS="$HOME/.config/Code - OSS/User/settings.json"

mkdir -p "$GTK3_CONF" "$GTK4_CONF" "$(dirname "$STATE_FILE")" "$(dirname "$KITTY_STATE")"

# --- HELPERS ---

ensure_gtk3_ini() {
  if [ ! -f "$GTK3_SETTINGS" ]; then
    printf "[Settings]\ngtk-theme-name=\ngtk-icon-theme-name=\ngtk-application-prefer-dark-theme=0\n" > "$GTK3_SETTINGS"
  elif ! grep -q '^\[Settings\]' "$GTK3_SETTINGS"; then
    sed -i '1i [Settings]' "$GTK3_SETTINGS"
  fi
}

update_ini_key() {
  # Usage: update_ini_key file key value
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    sed -i "/^\[Settings\]/a ${key}=${value}" "$file"
  fi
}

update_gtk4_links() {
  local theme="$1"
  local theme_path="$HOME/.themes/$theme/gtk-4.0"
  rm -f "$GTK4_CONF/assets" "$GTK4_CONF/gtk.css" "$GTK4_CONF/gtk-dark.css"

  ln -sf "$theme_path/assets"  "$GTK4_CONF/assets"
  ln -sf "$theme_path/gtk.css" "$GTK4_CONF/gtk.css"
  [ -f "$theme_path/gtk-dark.css" ] && ln -sf "$theme_path/gtk-dark.css" "$GTK4_CONF/gtk-dark.css"
}

update_kde_icons() {
  [ -f "$KDE_GLOBALS" ] || return 0
  local tool=""
  command -v kwriteconfig6 &>/dev/null && tool="kwriteconfig6" || tool="kwriteconfig5"
  [ -n "$tool" ] && $tool --file "$KDE_GLOBALS" --group Icons --key Theme "$1"

  # Refresh KWin
  if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  elif command -v qdbus &>/dev/null; then
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
}

enforce_kvantum_colors() {
  local theme_name="$1"
  local bg_color="$2"
  local text_color="$3"
  local file="$HOME/.config/Kvantum/$theme_name/$theme_name.kvconfig"

  [ -f "$file" ] || return 0

  # 1. Force Kvantum to ignore system settings
  sed -i 's/^respect_DE=true/respect_DE=false/' "$file"

  # 2. Clean old overrides
  sed -i '/^view.text.color=/d' "$file"
  sed -i '/^view.base.color=/d' "$file"

  # 3. Inject new colors into [GeneralColors]
  if grep -q "\[GeneralColors\]" "$file"; then
     sed -i "/\[GeneralColors\]/a view.text.color=$text_color\nview.base.color=$bg_color" "$file"
  fi
}

update_kitty() {
  local source_conf="$1"
  ln -sf "$source_conf" "$KITTY_STATE"
  kill -SIGUSR1 $(pidof kitty) 2>/dev/null || true
}

#set_vscode_theme() {
  #local theme_name="$1"
  #if [ -f "$VSCODE_SETTINGS" ]; then
    #if grep -q '"workbench.colorTheme"' "$VSCODE_SETTINGS"; then
      #sed -i "s/\"workbench\.colorTheme\": \"[^\"]*\"/\"workbench.colorTheme\": \"${theme_name}\"/" "$VSCODE_SETTINGS"
    #else
      #sed -i "0,/{/s/{/{\n  \"workbench.colorTheme\": \"${theme_name}\",/" "$VSCODE_SETTINGS"
    #fi
  #fi
#}

xfce_thunar_sync_() {
  local theme="$1" icons="$2"
  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "$theme" >/dev/null 2>&1 || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$icons" >/dev/null 2>&1 || true
  fi
}

# --- LOGIC ---

apply_theme() {
  local mode="$1" # light or dark
  local theme_gtk="$2"
  local theme_icon="$3"
  local theme_kvantum="$4"
  local wallpaper="$5"
  local kitty_conf="$6"
  local prefer_dark_bool="$7" # true or false (gsettings)
  local gnome_scheme="$8" # prefer-dark or prefer-light
  # KDE specifics
  local kde_global_src="$9"
  local kvantum_bg="${10}"
  local kvantum_text="${11}"

  # Convert bool to int for settings.ini
  local prefer_dark_int=0
  [ "$prefer_dark_bool" == "true" ] && prefer_dark_int=1

  echo "Switching to $mode..."
  echo "$mode" > "$STATE_FILE"

  # 1. GTK 3
  ensure_gtk3_ini
  update_ini_key "$GTK3_SETTINGS" "gtk-theme-name" "$theme_gtk"
  update_ini_key "$GTK3_SETTINGS" "gtk-icon-theme-name" "$theme_icon"
  update_ini_key "$GTK3_SETTINGS" "gtk-application-prefer-dark-theme" "$prefer_dark_int"
  touch "$GTK3_SETTINGS" # Force timestamp update

  # 2. GTK 4
  update_gtk4_links "$theme_gtk"

  # 3. GNOME / GSettings
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme "$gnome_scheme" || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme "$prefer_dark_bool" || true
    gsettings set org.gnome.desktop.interface icon-theme "$theme_icon" || true
    gsettings set org.gnome.desktop.interface gtk-theme "$theme_gtk" || true
  fi
  pkill nautilus || true

  # 4. KDE / Kvantum
  cp "$kde_global_src" "$KDE_GLOBALS"
  enforce_kvantum_colors "$theme_kvantum" "$kvantum_bg" "$kvantum_text"
  
  if command -v kvantummanager &>/dev/null; then
     kvantummanager --set "$theme_kvantum" >/dev/null 2>&1 || true
  fi
  
  update_kde_icons "$theme_icon"
  pkill dolphin || true

  # 5. External Tools
  command -v waypaper &>/dev/null && waypaper --wallpaper "$wallpaper" || true
  update_kitty "$HOME/.config/kitty/themes/$kitty_conf"

  # 6. Legacy / Disabled
  # xfce_thunar_sync_ "$theme_gtk" "$theme_icon"
}

# --- EXECUTION ---

if [ "$1" == "light" ]; then
  apply_theme "light" \
    "$THEME_LIGHT" "$ICONS_LIGHT" "EverforestGreenLight" \
    "$WALLPAPER_LIGHT" "everforest_light.conf" \
    "false" "prefer-light" \
    "$KDE_GLOBALS_LIGHT" "$KVANTUM_LIGHT_BG" "$KVANTUM_LIGHT_TEXT"
    #set_vscode_theme "Everforest Light"
else
  # Default to dark
  apply_theme "dark" \
    "$THEME_DARK" "$ICONS_DARK" "EverforestGreenDark" \
    "$WALLPAPER_DARK" "everforest.conf" \
    "true" "prefer-dark" \
    "$KDE_GLOBALS_DARK" "$KVANTUM_DARK_BG" "$KVANTUM_DARK_TEXT"
    #set_vscode_theme "Everforest Dark"
fi