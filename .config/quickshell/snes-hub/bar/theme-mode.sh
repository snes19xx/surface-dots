#!/bin/bash
set -e

# --- GTK THEMES ---
THEME_DARK="Everforest-Dark-Green-Dark"
THEME_LIGHT="Everforest-Light-Green-Light"

# --- ICON THEMES ---
ICONS_DARK="Papirus-Dark"
ICONS_LIGHT="Papirus-Light"

# --- WALLPAPERS ---
WALLPAPER_DARK="/home/snes/Pictures/desktop/3.png"
WALLPAPER_LIGHT="/home/snes/Pictures/desktop/l2.png"

# --- PATHS ---
GTK3_CONF="$HOME/.config/gtk-3.0"
GTK4_CONF="$HOME/.config/gtk-4.0"
GTK3_SETTINGS="$GTK3_CONF/settings.ini"

# VS Code settings (change if you use OSS)
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
# VSCODE_SETTINGS="$HOME/.config/Code - OSS/User/settings.json"

# Hub theme state file (Quickshell Hub ThemeEngine)
STATE_FILE="$HOME/.cache/quickshell/theme_mode"

# KDE globals
KDE_GLOBALS="$HOME/.config/kdeglobals"

mkdir -p "$GTK3_CONF" "$GTK4_CONF" "$(dirname "$STATE_FILE")"

# --- HELPERS ---

gtk3_settings_ini() {
  if [ ! -f "$GTK3_SETTINGS" ]; then
    cat > "$GTK3_SETTINGS" <<'EOF'
[Settings]
gtk-theme-name=
gtk-icon-theme-name=
gtk-application-prefer-dark-theme=0
EOF
  else
    if ! grep -q '^\[Settings\]' "$GTK3_SETTINGS"; then
      printf "[Settings]\n" | cat - "$GTK3_SETTINGS" > "${GTK3_SETTINGS}.tmp" && mv "${GTK3_SETTINGS}.tmp" "$GTK3_SETTINGS"
    fi
  fi
}

set_ini_key() {
  # Usage: set_ini_key file key value
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    sed -i "/^\[Settings\]/a ${key}=${value}" "$file"
  fi
}

set_vscode_theme() {
  local theme_name="$1"
  if [ -f "$VSCODE_SETTINGS" ]; then
    # If key exists, replace. If not, insert near top (after first {).
    if grep -q '"workbench.colorTheme"' "$VSCODE_SETTINGS"; then
      sed -i "s/\"workbench\.colorTheme\": \"[^\"]*\"/\"workbench.colorTheme\": \"${theme_name}\"/" "$VSCODE_SETTINGS"
    else
      sed -i "0,/{/s/{/{\n  \"workbench.colorTheme\": \"${theme_name}\",/" "$VSCODE_SETTINGS"
    fi
  fi
}

sync_kde_icons_optional() {
  # Only runs if KDE tools exist and kdeglobals exists.
  local icon_theme="$1"

  [ -f "$KDE_GLOBALS" ] || return 0

  if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file "$KDE_GLOBALS" --group Icons --key Theme "$icon_theme"
  elif command -v kwriteconfig5 &>/dev/null; then
    kwriteconfig5 --file "$KDE_GLOBALS" --group Icons --key Theme "$icon_theme"
  fi

  # Gets KDE to refresh if possible
  if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  elif command -v qdbus &>/dev/null; then
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
}

set_gtk4_assets() {
  local theme="$1"
  rm -rf "$GTK4_CONF/assets" "$GTK4_CONF/gtk.css" "$GTK4_CONF/gtk-dark.css"

  ln -sf "$HOME/.themes/$theme/gtk-4.0/assets"  "$GTK4_CONF/assets"
  ln -sf "$HOME/.themes/$theme/gtk-4.0/gtk.css" "$GTK4_CONF/gtk.css"

  if [ -f "$HOME/.themes/$theme/gtk-4.0/gtk-dark.css" ]; then
    ln -sf "$HOME/.themes/$theme/gtk-4.0/gtk-dark.css" "$GTK4_CONF/gtk-dark.css"
  fi
}

reload_kitty() {
  local pids
  pids="$(pidof kitty 2>/dev/null || true)"
  [ -n "$pids" ] && kill -SIGUSR1 $pids 2>/dev/null || true
}

xfce_thunar_sync_optional() {
  local theme="$1"
  local icons="$2"

  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "$theme" >/dev/null 2>&1 || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$icons" >/dev/null 2>&1 || true
  fi
}

# --- APPLY THEMES ---

apply_dark() {
  echo "Applying Dark Theme..."
  echo "dark" > "$STATE_FILE"

  # Wallpaper
  command -v waypaper &>/dev/null && waypaper --wallpaper "$WALLPAPER_DARK" || true

  gtk3_settings_ini

  # GTK via gsettings
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_DARK" || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICONS_DARK" || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true || true
  fi

  # GTK3 settings.ini
  set_ini_key "$GTK3_SETTINGS" "gtk-theme-name" "$THEME_DARK"
  set_ini_key "$GTK3_SETTINGS" "gtk-icon-theme-name" "$ICONS_DARK"
  set_ini_key "$GTK3_SETTINGS" "gtk-application-prefer-dark-theme" "1"

  #KDE sync
  sync_kde_icons_optional "$ICONS_DARK"

  # Thunar annoyance
  xfce_thunar_sync_optional "$THEME_DARK" "$ICONS_DARK"

  # GTK4 assets
  set_gtk4_assets "$THEME_DARK"

  # VS Code
  set_vscode_theme "Everforest Dark"

  # Kitty
  local KITTY_THEME_TARGET="$HOME/.local/state/theme/kitty_theme.conf"
  local KITTY_THEME_SOURCE="$HOME/.config/kitty/themes/everforest.conf"
  mkdir -p "$(dirname "$KITTY_THEME_TARGET")"
  ln -sf "$KITTY_THEME_SOURCE" "$KITTY_THEME_TARGET"
  reload_kitty
}

apply_light() {
  echo "Applying Light Theme..."
  echo "light" > "$STATE_FILE"

  # Wallpaper
  command -v waypaper &>/dev/null && waypaper --wallpaper "$WALLPAPER_LIGHT" || true

  gtk3_settings_ini

  # GTK via gsettings
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_LIGHT" || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICONS_LIGHT" || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme false || true
  fi

  # GTK3 settings.ini
  set_ini_key "$GTK3_SETTINGS" "gtk-theme-name" "$THEME_LIGHT"
  set_ini_key "$GTK3_SETTINGS" "gtk-icon-theme-name" "$ICONS_LIGHT"
  set_ini_key "$GTK3_SETTINGS" "gtk-application-prefer-dark-theme" "0"

  # KDE sync
  sync_kde_icons_optional "$ICONS_LIGHT"

  # thunar
  xfce_thunar_sync_optional "$THEME_LIGHT" "$ICONS_LIGHT"

  # GTK4 assets
  set_gtk4_assets "$THEME_LIGHT"

  # VS Code
  set_vscode_theme "Everforest Light"

  # Kitty
  local KITTY_THEME_TARGET="$HOME/.local/state/theme/kitty_theme.conf"
  local KITTY_THEME_SOURCE="$HOME/.config/kitty/themes/everforest_light.conf"
  mkdir -p "$(dirname "$KITTY_THEME_TARGET")"
  ln -sf "$KITTY_THEME_SOURCE" "$KITTY_THEME_TARGET"
  reload_kitty
}

# --- EXECUTION ---
if [ "$1" == "light" ]; then
  apply_light
else
  apply_dark
fi
