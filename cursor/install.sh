#!/usr/bin/env bash
# Saturnian cursor theme - installer.
#
#   ./install.sh              install for the current user
#   ./install.sh --system     install for all users (needs root)
#   ./install.sh --uninstall  remove again
#

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-}"
TARGET="$HOME/.local/share/icons"
[[ $MODE == --system ]] && TARGET="/usr/share/icons"

bold=$'\033[1m'; dim=$'\033[2m'; red=$'\033[31m'; grn=$'\033[32m'; off=$'\033[0m'
die() { printf '%serror%s %s\n' "$red" "$off" "$*" >&2; exit 1; }

mapfile -t THEMES < <(
  find "$HERE" -mindepth 2 -maxdepth 2 -name index.theme -printf '%h\n' | xargs -rn1 basename | sort
)
[[ ${#THEMES[@]} -gt 0 ]] || die "no themes found next to $0"

if [[ $MODE == --system && $EUID -ne 0 ]]; then
  die "--system needs root: sudo $0 --system"
fi

if [[ $MODE == --uninstall ]]; then
  for t in "${THEMES[@]}"; do
    for dir in "$HOME/.local/share/icons/$t" "/usr/share/icons/$t"; do
      [[ -e $dir ]] && { rm -rf "$dir" && printf '  removed %s\n' "$dir"; }
    done
  done
  echo "done - log out and back in, or run: hyprctl setcursor Adwaita 32"
  exit 0
fi

mkdir -p "$TARGET"
for t in "${THEMES[@]}"; do
  rm -rf "${TARGET:?}/$t"
  cp -r "$HERE/$t" "$TARGET/$t"
  printf '  %s%s%s -> %s\n' "$grn" "$t" "$off" "$TARGET/$t"
done

cat <<EOF

${bold}Installed.${off} both variants: ${bold}Saturnian-Night${off} for dark desktops,
${bold}Saturnian-Day${off} for light ones.

${dim}Try it right now:${off}
    hyprctl setcursor Saturnian-Night 32

${dim}Make it permanent - Hyprland:${off}
    env = HYPRCURSOR_THEME,Saturnian-Night
    env = HYPRCURSOR_SIZE,32
    env = XCURSOR_THEME,Saturnian-Night
    env = XCURSOR_SIZE,32

${dim}Make it permanent - GTK / other desktops:${off}
    gsettings set org.gnome.desktop.interface cursor-theme Saturnian-Night
    gsettings set org.gnome.desktop.interface cursor-size 32

EOF
