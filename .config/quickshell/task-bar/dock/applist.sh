#!/bin/bash

# DEBUG: Uncomment to see what's happening
# echo "DEBUG: Script started" >&2
# echo "DEBUG: Cache dir: $CACHE_DIR" >&2

# --- CONFIG ---
SCRIPT_DIR="$HOME/.config/quickshell/task-bar/dock"
CACHE_DIR="$HOME/.config/quickshell/.cache"
CACHE_FILE="$CACHE_DIR/applist.cache"
BLACKLIST_FILE="$CACHE_DIR/blacklist.txt"
TIMESTAMP_FILE="$CACHE_DIR/applist.timestamp"

SEARCH_PATHS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/var/lib/flatpak/exports/share/applications"
)

ICON_SEARCH_PATHS=(
    "$HOME/.local/share/icons"
    "/usr/share/icons"
    "$HOME/.icons"
    "/usr/share/pixmaps"
)

# Get system icon theme (should respect qt5ct/qt6ct settings)
ICON_THEME="${ICON_THEME:-Papirus}"
if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ]; then
    CONFIGURED_THEME=$(grep "^icon_theme=" "$HOME/.config/qt5ct/qt5ct.conf" | cut -d'=' -f2)
    [ -n "$CONFIGURED_THEME" ] && ICON_THEME="$CONFIGURED_THEME"
fi
if [ -f "$HOME/.config/qt6ct/qt6ct.conf" ]; then
    CONFIGURED_THEME=$(grep "^icon_theme=" "$HOME/.config/qt6ct/qt6ct.conf" | cut -d'=' -f2)
    [ -n "$CONFIGURED_THEME" ] && ICON_THEME="$CONFIGURED_THEME"
fi

# --- BLACKLIST ---
BLACKLIST=(
    "avahi-discover.desktop"
    "bssh.desktop"
    "bvnc.desktop"
    "qv4l2.desktop"
    "qvidcap.desktop"
    "cmake-gui.desktop"
    "assistant.desktop"
    "designer.desktop"
    "linguist.desktop"
    "qdbusviewer.desktop"
    "xfce4-notifyd-config.desktop"
    "thunar-settings.desktop"
)

# --- ICON RESOLUTION ---
find_icon() {
    local icon_name="$1"
    
    # If already a full path, return it
    [[ "$icon_name" == /* ]] && { [[ -f "$icon_name" ]] && echo "$icon_name" || echo ""; return; }
    
    # Remove extension if present
    icon_name="${icon_name%.png}"
    icon_name="${icon_name%.svg}"
    icon_name="${icon_name%.xpm}"
    icon_name="${icon_name%.ico}"
    
    # Search in icon theme directories
    # Priority: configured theme (e.g., Papirus) first, then hicolor fallback
    local sizes=(128 scalable 96 64 48)
    local exts=(svg png xpm)
    local contexts=(apps applications places categories)
    
    # First: Search in configured theme (Papirus)
    for size in "${sizes[@]}"; do
        for path in "${ICON_SEARCH_PATHS[@]}"; do
            local theme_path="$path/$ICON_THEME"
            [[ ! -d "$theme_path" ]] && continue
            
            if [[ "$size" == "scalable" ]]; then
                for context in "${contexts[@]}"; do
                    for ext in "${exts[@]}"; do
                        local icon_file="$theme_path/scalable/$context/$icon_name.$ext"
                        [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
                    done
                done
            else
                for context in "${contexts[@]}"; do
                    for ext in "${exts[@]}"; do
                        local icon_file="$theme_path/${size}x${size}/$context/$icon_name.$ext"
                        [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
                    done
                done
            fi
        done
    done
    
    # Second: Hicolor
    for size in "${sizes[@]}"; do
        for path in "${ICON_SEARCH_PATHS[@]}"; do
            if [[ "$size" == "scalable" ]]; then
                for ext in "${exts[@]}"; do
                    local icon_file="$path/hicolor/scalable/apps/$icon_name.$ext"
                    [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
                done
            else
                for ext in "${exts[@]}"; do
                    local icon_file="$path/hicolor/${size}x${size}/apps/$icon_name.$ext"
                    [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
                done
            fi
        done
    done
    
    # Third: Pixmaps directory
    for ext in "${exts[@]}"; do
        local icon_file="/usr/share/pixmaps/$icon_name.$ext"
        [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
    done
    
    # Return empty if not found 
    echo ""
}
# --- CACHE CHECK ---
needs_refresh() {
    # Create cache dir if needed
    mkdir -p "$CACHE_DIR"
    
    # No cache exists
    [[ ! -f "$CACHE_FILE" ]] && return 0
    
    # Blacklist changed
    if [[ -f "$BLACKLIST_FILE" ]]; then
        [[ "$BLACKLIST_FILE" -nt "$CACHE_FILE" ]] && return 0
    fi
    
    # Check if any desktop file is newer than cache
    [[ -f "$TIMESTAMP_FILE" ]] || { touch "$TIMESTAMP_FILE"; return 0; }
    
    for dir in "${SEARCH_PATHS[@]}"; do
        [[ ! -d "$dir" ]] && continue
        # Find any .desktop file newer than timestamp
        if find "$dir" -maxdepth 1 -name "*.desktop" -newer "$TIMESTAMP_FILE" 2>/dev/null | grep -q .; then
            return 0
        fi
    done
    
    return 1
}

# --- BUILD APP LIST ---
build_list() {
    declare -A seen_apps
    declare -A blacklist_map
    
    # Build blacklist map
    for b in "${BLACKLIST[@]}"; do blacklist_map["$b"]=1; done
    
    if [[ -f "$BLACKLIST_FILE" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && blacklist_map["$line"]=1
        done < "$BLACKLIST_FILE"
    fi
    
    # Scan desktop files
    for dir in "${SEARCH_PATHS[@]}"; do
        [[ ! -d "$dir" ]] && continue
        
        for file in "$dir"/*.desktop; do
            [[ ! -f "$file" ]] && continue
            
            filename=$(basename "$file")
            
            # Skip if seen or blacklisted
            [[ "${seen_apps[$filename]}" ]] && continue
            seen_apps[$filename]=1
            [[ "${blacklist_map[$filename]}" ]] && continue
            
            # Parse desktop file
            name=""
            icon=""
            exec_cmd=""
            term=""
            nodisplay=""
            in_entry=0
            
            while IFS= read -r line; do
                if [[ "$line" == \[* ]]; then
                    if [[ "$line" == "[Desktop Entry]" ]]; then
                        in_entry=1
                        continue
                    else
                        [[ $in_entry -eq 1 ]] && break
                    fi
                fi
                
                if [[ $in_entry -eq 1 ]]; then
                    case "$line" in
                        Name=*) name="${line#*=}" ;;
                        Icon=*) icon="${line#*=}" ;;
                        Exec=*) exec_cmd="${line#*=}" ;;
                        Terminal=*) term="${line#*=}" ;;
                        NoDisplay=*) nodisplay="${line#*=}" ;;
                    esac
                fi
            done < "$file"
            
            # Validation
            [[ "$nodisplay" == "true" ]] && continue
            [[ -z "$name" || -z "$exec_cmd" ]] && continue
            
            # Clean exec command
            exec_cmd="${exec_cmd//%[fFuUicdDnkVm]/}"
            exec_cmd=$(echo "$exec_cmd" | xargs)
            
            # Resolve icon path
            if [[ -z "$icon" ]]; then
                icon_path="/usr/share/pixmaps/application-x-executable.png"
            else
                icon_path=$(find_icon "$icon")
                # If not found, use the name anyway (QML might find it)
                [[ -z "$icon_path" ]] && icon_path="$icon"
            fi
            
            echo "$name|$icon_path|$exec_cmd|$term|$filename"
        done
    done | sort -t'|' -k1,1 -f
}

# --- MAIN ---
if needs_refresh; then
    # Rebuild cache
    build_list > "$CACHE_FILE"
    touch "$TIMESTAMP_FILE"
fi

# Output cached list
cat "$CACHE_FILE"
