#!/bin/bash

# --- GTK ---
THEME_DARK="Everforest-Dark-Green-Dark"
THEME_LIGHT="Everforest-Light-Green-Light"

# Wallpapers
WALLPAPER_DARK="/home/snes/Pictures/desktop/3.png"
WALLPAPER_LIGHT="/home/snes/Pictures/desktop/l2.png"

# Paths
GTK3_CONF="$HOME/.config/gtk-3.0"
GTK4_CONF="$HOME/.config/gtk-4.0"
GTK3_SETTINGS="$GTK3_CONF/settings.ini"
KITTY_SWITCHER="$HOME/.config/kitty/themes/theme_switcher.sh"

# VS CODE SETTINGS PATH 
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
# If you use the OSS version, uncomment this line:
# VSCODE_SETTINGS="$HOME/.config/Code - OSS/User/settings.json"

# Hub theme state file (for Quickshell Hub ThemeEngine)
STATE_FILE="$HOME/.cache/quickshell/theme_mode"

# Just in case
mkdir -p "$GTK4_CONF"
mkdir -p "$(dirname "$STATE_FILE")"

# --- FUNCTIONS ---

apply_dark() {
    echo "Applying Dark Theme..."

    # 0) Theme state for Hub
    echo "dark" > "$STATE_FILE"

    # 1. Wallpaper (Waypaper)
    waypaper --wallpaper "$WALLPAPER_DARK"

    # 2. GTK 
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$THEME_DARK/" "$GTK3_SETTINGS"
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_DARK"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    rm -rf "$GTK4_CONF/assets" "$GTK4_CONF/gtk.css" "$GTK4_CONF/gtk-dark.css"
    ln -sf "$HOME/.themes/$THEME_DARK/gtk-4.0/assets" "$GTK4_CONF/assets"
    ln -sf "$HOME/.themes/$THEME_DARK/gtk-4.0/gtk.css" "$GTK4_CONF/gtk.css"
    ln -sf "$HOME/.themes/$THEME_DARK/gtk-4.0/gtk-dark.css" "$GTK4_CONF/gtk-dark.css"

    # 3. VS Code 
    if [ -f "$VSCODE_SETTINGS" ]; then
        sed -i 's/"workbench.colorTheme": ".*"/"workbench.colorTheme": "Everforest Dark"/' "$VSCODE_SETTINGS"
    fi

    # 4. Kitty 
    local KITTY_THEME_TARGET="$HOME/.local/state/theme/kitty_theme.conf"
    local KITTY_THEME_SOURCE="$HOME/.config/kitty/themes/everforest.conf"
    
    ln -sf "$KITTY_THEME_SOURCE" "$KITTY_THEME_TARGET"
    
    # Reload all kitty instances
    kill -SIGUSR1 $(pidof kitty) 2>/dev/null

    #5. QT applications
}

apply_light() {
    echo "Applying Light Theme..."

    # 0) Theme state for Hub
    echo "light" > "$STATE_FILE"

    # 1. Wallpaper (Waypaper)
    waypaper --wallpaper "$WALLPAPER_LIGHT"

    # 2. GTK 
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$THEME_LIGHT/" "$GTK3_SETTINGS"
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_LIGHT"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'

    rm -rf "$GTK4_CONF/assets" "$GTK4_CONF/gtk.css" "$GTK4_CONF/gtk-dark.css"
    ln -sf "$HOME/.themes/$THEME_LIGHT/gtk-4.0/assets" "$GTK4_CONF/assets"
    ln -sf "$HOME/.themes/$THEME_LIGHT/gtk-4.0/gtk.css" "$GTK4_CONF/gtk.css"
    ln -sf "$HOME/.themes/$THEME_LIGHT/gtk-4.0/gtk-dark.css" "$GTK4_CONF/gtk-dark.css"

    # 3. VS Code 
    if [ -f "$VSCODE_SETTINGS" ]; then
        sed -i 's/"workbench.colorTheme": ".*"/"workbench.colorTheme": "Everforest Light"/' "$VSCODE_SETTINGS"
    fi

    # 4. Kitty 
    local KITTY_THEME_TARGET="$HOME/.local/state/theme/kitty_theme.conf"
    local KITTY_THEME_SOURCE="$HOME/.config/kitty/themes/everforest_light.conf"
    
    ln -sf "$KITTY_THEME_SOURCE" "$KITTY_THEME_TARGET"
    
    # Reload all kitty instances
    kill -SIGUSR1 $(pidof kitty) 2>/dev/null
}

# --- EXECUTION ---
if [ "$1" == "light" ]; then
    apply_light
else
    apply_dark
fi