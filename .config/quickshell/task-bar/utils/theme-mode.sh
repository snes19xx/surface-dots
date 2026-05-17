#!/bin/bash
set -e
# =============================================================================
# GLOBAL THEME SWITCHER 
# =============================================================================
# This script switches between light and dark themes across:
# - GTK 3/4 apps
# - KDE Plasma (when used as backup WM)
# - Kvantum themes
# - Wallpapers
# - Dunst
# - Kitty terminal
# =============================================================================
# THEMES
THEME_DARK="green-dark"
THEME_LIGHT="green-light"
ICONS_DARK="Papirus-Dark"
ICONS_LIGHT="Papirus-Light"
# WALLPAPERS
WALLPAPER_DARK="$HOME/Pictures/ffx.png"
WALLPAPER_LIGHT="$HOME/Pictures/dissidia_ff.jpg"
# PATHS
GTK3_CONF="$HOME/.config/gtk-3.0"
GTK3_SETTINGS="$GTK3_CONF/settings.ini"
GTK4_CONF="$HOME/.config/gtk-4.0"
KDE_GLOBALS="$HOME/.config/kdeglobals"
STATE_FILE="$HOME/.cache/quickshell/theme_mode"
KITTY_STATE="$HOME/.local/state/theme/kitty_theme.conf"
DUNST_CONF="$HOME/.config/dunst/dunstrc"
[[ "$*" == *"--quiet"* ]] && QUIET=1 || QUIET=0
# Added --no-wallpaper flag so reading_mode can handle its own wallpapers
[[ "$*" == *"--no-wallpaper"* ]] && NO_WALLPAPER=1 || NO_WALLPAPER=0
# Create necessary directories if they don't exist
# mkdir -p "$GTK3_CONF" "$GTK4_CONF" "$(dirname "$STATE_FILE")" "$(dirname "$KITTY_STATE")"
# HELPER FUNCTIONS
# Make sure GTK3 settings file exists with proper structure
ensure_gtk3_ini() {
  if [ ! -f "$GTK3_SETTINGS" ]; then
    printf "[Settings]\ngtk-theme-name=\ngtk-icon-theme-name=\ngtk-application-prefer-dark-theme=0\n" > "$GTK3_SETTINGS"
  elif ! grep -q '^\[Settings\]' "$GTK3_SETTINGS"; then
    sed -i '1i [Settings]' "$GTK3_SETTINGS"
  fi
}
# Update INI file
update_ini_key() {
  local file="$1" 
  local key="$2" 
  local value="$3"
  
  if grep -q "^${key}=" "$file"; then
    # Key exists, update it
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    # Key doesn't exist, add it under [Settings]
    sed -i "/^\[Settings\]/a ${key}=${value}" "$file"
  fi
}
# GTK4 uses symlinks to theme files instead of a config file
update_gtk4_links() {
  local theme="$1"
  local theme_path="$HOME/.themes/$theme/gtk-4.0"
  
  # Remove old symlinks
  rm -f "$GTK4_CONF/assets" "$GTK4_CONF/gtk.css" "$GTK4_CONF/gtk-dark.css"
  
  # Create new symlinks to the theme
  ln -sf "$theme_path/assets"  "$GTK4_CONF/assets"
  ln -sf "$theme_path/gtk.css" "$GTK4_CONF/gtk.css"
  [ -f "$theme_path/gtk-dark.css" ] && ln -sf "$theme_path/gtk-dark.css" "$GTK4_CONF/gtk-dark.css"
}
# Update KDE icon theme
update_kde_icons() {
  [ -f "$KDE_GLOBALS" ] || return 0
  
  # Use kwriteconfig6 if available, otherwise fall back to kwriteconfig5
  local tool=""
  command -v kwriteconfig6 &>/dev/null && tool="kwriteconfig6" || tool="kwriteconfig5"
  
  if [ -n "$tool" ]; then
    $tool --file "$KDE_GLOBALS" --group Icons --key Theme "$1"
  fi
  
  # KWin config reload
  if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  elif command -v qdbus &>/dev/null; then
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
}
# Update Kitty terminal theme
update_kitty() {
  local source_conf="$1"
  ln -sf "$source_conf" "$KITTY_STATE"
  # Reload Kitty config without restarting
  kill -SIGUSR1 $(pidof kitty) 2>/dev/null || true
}
# Update Dunst notification theme
update_dunst() {
  local source_conf="$1"
  # cp instead of syslinks
  cp -f "$HOME/.config/dunst/$source_conf" "$DUNST_CONF"
  
  # Safely restart the daemon to prevent D-Bus locks
  if systemctl --user is-active --quiet dunst.service; then
    systemctl --user restart dunst.service
  else
    killall dunst 2>/dev/null || true
    sleep 0.2
    dunst >/dev/null 2>&1 &
    disown
  fi
}
# OPTIONAL: VS CODE THEME SWITCHING
# NOTE: I prefer to handle VS Code themes natively using settings.json with:
#   "workbench.preferredDarkColorTheme": "Everforest Dark",
#   "workbench.preferredLightColorTheme": "Everforest Light"
#
# Uncomment the function below if that somehow didn't work or if you want the script to handle it instead:
#set_vscode_theme() {
#  local theme_name="$1"
#  local VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
#  # Use this path for VS Code OSS:
#  # local VSCODE_SETTINGS="$HOME/.config/Code - OSS/User/settings.json"
#  
#  if [ -f "$VSCODE_SETTINGS" ]; then
#    if grep -q '"workbench.colorTheme"' "$VSCODE_SETTINGS"; then
#      sed -i "s/\"workbench\.colorTheme\": \"[^\"]*\"/\"workbench.colorTheme\": \"${theme_name}\"/" "$VSCODE_SETTINGS"
#    else
#      sed -i "0,/{/s/{/{\n  \"workbench.colorTheme\": \"${theme_name}\",/" "$VSCODE_SETTINGS"
#    fi
#  fi
#}
# OPTIONAL: XFCE/Thunar SYNC
# If you don't use XFCE/Thunar, comment or remove this to sync Thunar themes:
xfce_thunar_sync() {
  local theme="$1" 
  local icons="$2"
  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "$theme" >/dev/null 2>&1 || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$icons" >/dev/null 2>&1 || true
  fi
}
# MAIN THEME FUNCTION
apply_theme() {
  local mode="$1"              # "light" or "dark"
  local theme_gtk="$2"         # GTK theme name
  local theme_icon="$3"        # Icon theme name
  local theme_kvantum="$4"     # Kvantum theme name
  local wallpaper="$5"         # Wallpaper path
  local kitty_conf="$6"        # Kitty config file name
  local dunst_conf="$7"        # Dunst config file name
  local prefer_dark_bool="$8"  # "true" or "false" for gsettings
  local gnome_scheme="$9"      # "prefer-dark" or "prefer-light"
  
  # Convert boolean to integer for GTK settings.ini
  local prefer_dark_int=0
  [ "$prefer_dark_bool" == "true" ] && prefer_dark_int=1
  
  echo "Switching to $mode mode..."
  # echo "$mode" > "$STATE_FILE"
  # Write atomically to trigger file watchers
echo "$mode" > "${STATE_FILE}.tmp" && mv -f "${STATE_FILE}.tmp" "$STATE_FILE"
if [[ "$QUIET" != "1" ]]; then
  echo "$mode" > "${HOME}/.cache/quickshell/theme_osd"
fi
  
  # ---------------------------------------------------------------------------
  # DUNST
  # ---------------------------------------------------------------------------
  update_dunst "$dunst_conf"
  # ---------------------------------------------------------------------------
  # GTK 3
  # ---------------------------------------------------------------------------
  ensure_gtk3_ini
  update_ini_key "$GTK3_SETTINGS" "gtk-theme-name" "$theme_gtk"
  update_ini_key "$GTK3_SETTINGS" "gtk-icon-theme-name" "$theme_icon"
  update_ini_key "$GTK3_SETTINGS" "gtk-application-prefer-dark-theme" "$prefer_dark_int"
  touch "$GTK3_SETTINGS"  # Force timestamp update so apps notice the change
  
  # ---------------------------------------------------------------------------
  # GTK 4
  # ---------------------------------------------------------------------------
  update_gtk4_links "$theme_gtk"
  
  # ---------------------------------------------------------------------------
  # GNOME/GSETTINGS (for GTK apps that check gsettings)
  # ---------------------------------------------------------------------------
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme "$gnome_scheme" || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme "$prefer_dark_bool" || true
    gsettings set org.gnome.desktop.interface icon-theme "$theme_icon" || true
    gsettings set org.gnome.desktop.interface gtk-theme "$theme_gtk" || true
  fi
  
  # Restart Nautilus if it's running so it picks up the new theme
  # pkill nautilus || true
  
  # ---------------------------------------------------------------------------
  # KDE PLASMA & KVANTUM
  # ---------------------------------------------------------------------------
  # This section handles both Plasma (my backup WM) and Kvantum app styling
  
  # Set Plasma color scheme (controls shell, panels, system UI)
  if [ "$mode" == "dark" ]; then
    plasma-apply-colorscheme "Everforest Dark" 2>/dev/null || true
  else
    plasma-apply-colorscheme "Everforest Light" 2>/dev/null || true
  fi
  
  # Set application style to Kvantum
  local kwrite_tool=""
  command -v kwriteconfig6 &>/dev/null && kwrite_tool="kwriteconfig6" || kwrite_tool="kwriteconfig5"
  if [ -n "$kwrite_tool" ]; then
    $kwrite_tool --file "$KDE_GLOBALS" --group KDE --key widgetStyle kvantum
  fi
  
  # Set Kvantum theme (application colors)
  if command -v kvantummanager &>/dev/null; then
     kvantummanager --set "$theme_kvantum" >/dev/null 2>&1 || true
  fi
  
  # Update icon theme in KDE
  update_kde_icons "$theme_icon"
  
  # Restart Plasma shell if in Plasma 
  if pgrep plasmashell &>/dev/null; then
    killall plasmashell 2>/dev/null || true
    kstart5 plasmashell 2>/dev/null || kstart plasmashell 2>/dev/null || true
  fi
  
  # Restart Dolphin so it picks up the new colors
  pkill dolphin || true
  
  # ---------------------------------------------------------------------------
  # WALLPAPER
  # ---------------------------------------------------------------------------
  # Respect the --no-wallpaper flag to avoid conflicts
  if [[ "$NO_WALLPAPER" != "1" ]]; then
    command -v awww &>/dev/null && awww img "$wallpaper" \
        --transition-type wipe \
        --transition-pos center \
        --transition-step 90 \
        --transition-duration 1.2
  fi
  
  # ---------------------------------------------------------------------------
  # KITTY TERMINAL
  # ---------------------------------------------------------------------------
  update_kitty "$HOME/.config/kitty/themes/$kitty_conf"
  
  # ---------------------------------------------------------------------------
  # OPTIONAL INTEGRATIONS
  # ---------------------------------------------------------------------------
  # Uncomment if needed:
  xfce_thunar_sync "$theme_gtk" "$theme_icon"
  # set_vscode_theme "Everforest $mode"
}
# SCRIPT EXECUTION
if [ "$1" == "light" ]; then
  apply_theme "light" \
    "$THEME_LIGHT" \
    "$ICONS_LIGHT" \
    "EverforestGreenLight" \
    "$WALLPAPER_LIGHT" \
    "everforest_light.conf" \
    "dunstrc_light" \
    "false" \
    "prefer-light"
else
  # Default to dark
  apply_theme "dark" \
    "$THEME_DARK" \
    "$ICONS_DARK" \
    "EverforestGreenDark" \
    "$WALLPAPER_DARK" \
    "everforest.conf" \
    "dunstrc_dark" \
    "true" \
    "prefer-dark"
fi