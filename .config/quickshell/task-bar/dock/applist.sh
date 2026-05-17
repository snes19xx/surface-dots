#!/usr/bin/env bash

# --- CONFIG ---
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

ICON_THEME="${ICON_THEME:-Papirus}"
for cfg in "$HOME/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"; do
    if [[ -f "$cfg" ]]; then
        while IFS='=' read -r key val; do
            if [[ "$key" == "icon_theme" && -n "$val" ]]; then
                ICON_THEME="$val"
                break
            fi
        done < "$cfg"
    fi
done

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

    [[ "$icon_name" == /* ]] && { [[ -f "$icon_name" ]] && echo "$icon_name" || echo ""; return; }

    icon_name="${icon_name%.png}"
    icon_name="${icon_name%.svg}"
    icon_name="${icon_name%.xpm}"
    icon_name="${icon_name%.ico}"

    local sizes=(128 scalable 96 64 48)
    local exts=(svg png xpm)
    local contexts=(apps applications places categories)

    for size in "${sizes[@]}"; do
        for path in "${ICON_SEARCH_PATHS[@]}"; do
            local theme_path="$path/$ICON_THEME"
            [[ ! -d "$theme_path" ]] && continue

            local subpath="${size}x${size}"
            [[ "$size" == "scalable" ]] && subpath="scalable"

            for context in "${contexts[@]}"; do
                for ext in "${exts[@]}"; do
                    local icon_file="$theme_path/$subpath/$context/$icon_name.$ext"
                    [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
                done
            done
        done
    done

    for size in "${sizes[@]}"; do
        for path in "${ICON_SEARCH_PATHS[@]}"; do
            local subpath="${size}x${size}"
            [[ "$size" == "scalable" ]] && subpath="scalable"
            for ext in "${exts[@]}"; do
                local icon_file="$path/hicolor/$subpath/apps/$icon_name.$ext"
                [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
            done
        done
    done

    for ext in "${exts[@]}"; do
        local icon_file="/usr/share/pixmaps/$icon_name.$ext"
        [[ -f "$icon_file" ]] && { echo "$icon_file"; return; }
    done

    echo ""
}

# --- CACHE CHECK ---
needs_refresh() {
    mkdir -p "$CACHE_DIR"

    [[ ! -f "$CACHE_FILE" ]] && return 0

    if [[ -f "$BLACKLIST_FILE" ]]; then
        [[ "$BLACKLIST_FILE" -nt "$CACHE_FILE" ]] && return 0
    fi

    [[ -f "$TIMESTAMP_FILE" ]] || { touch "$TIMESTAMP_FILE"; return 0; }

    for dir in "${SEARCH_PATHS[@]}"; do
        [[ ! -d "$dir" ]] && continue
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

    for b in "${BLACKLIST[@]}"; do blacklist_map["$b"]=1; done

    if [[ -f "$BLACKLIST_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && blacklist_map["$line"]=1
        done < "$BLACKLIST_FILE"
    fi

    for dir in "${SEARCH_PATHS[@]}"; do
        [[ ! -d "$dir" ]] && continue

        for file in "$dir"/*.desktop; do
            [[ ! -f "$file" ]] && continue

            local filename="${file##*/}"

            [[ "${seen_apps[$filename]}" ]] && continue
            seen_apps[$filename]=1
            [[ "${blacklist_map[$filename]}" ]] && continue

            # Explicit empty assignments so values never leak between loop iterations
            local name="" icon="" exec_cmd="" term="" nodisplay="" in_entry=0

            while IFS= read -r line || [[ -n "$line" ]]; do
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
                        Name=*)      name="${line#*=}" ;;
                        Icon=*)      icon="${line#*=}" ;;
                        Exec=*)      exec_cmd="${line#*=}" ;;
                        Terminal=*)  term="${line#*=}" ;;
                        NoDisplay=*) nodisplay="${line#*=}" ;;
                    esac
                fi
            done < "$file"

            [[ "$nodisplay" == "true" ]] && continue
            [[ -z "$name" || -z "$exec_cmd" ]] && continue

            # Strip desktop-file field codes (%f, %F, %u, %U, etc.)
            exec_cmd="${exec_cmd//%[fFuUicdDnkVm]/}"

            # Trim leading and trailing whitespace
            exec_cmd="${exec_cmd#"${exec_cmd%%[![:space:]]*}"}"
            exec_cmd="${exec_cmd%"${exec_cmd##*[![:space:]]}"}"

            local icon_path=""
            if [[ -z "$icon" ]]; then
                icon_path="/usr/share/pixmaps/application-x-executable.png"
            else
                icon_path=$(find_icon "$icon")
                [[ -z "$icon_path" ]] && icon_path="$icon"
            fi

            echo "$name|$icon_path|$exec_cmd|$term|$filename"
        done
    done | sort -t'|' -k1,1 -f
}

# --- MAIN ---
if needs_refresh; then
    build_list > "$CACHE_FILE"
    touch "$TIMESTAMP_FILE"
fi

cat "$CACHE_FILE"