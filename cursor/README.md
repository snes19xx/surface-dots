# Saturnian

Custom cursor theme for Surface-dots in two variants — **Saturnian-Night** for dark desktops,
**Saturnian-Day** for light.

## Install

```sh
./install.sh              # current user  -> ~/.local/share/icons
sudo ./install.sh --system  # all users   -> /usr/share/icons
./install.sh --uninstall
```

Then, without restarting anything:

```sh
hyprctl setcursor Saturnian-Night 32
```

## Contents

Each variant ships **both** cursor formats in one directory, so a single theme
name selects the right one automatically:

```
Saturnian-Night/
├── index.theme      XCursor metadata
├── cursors/         20 cursors + 108 alias symlinks
├── manifest.hl      hyprcursor metadata
└── hyprcursors/     20 .hlc archives (SVG, scales to any size)
```

- **XCursor** is read by every toolkit — GTK, Qt, XWayland, Electron, SDL.
  Rasterised at 24, 32, 48, 64, 96 and 128 px.
- **hyprcursor** is read by Hyprland in preference to XCursor. It keeps the
  SVGs, so it stays sharp at any size and at fractional scaling.

`wait` and `progress` are animated, 16 frames each.

The 108 aliases cover the modern CSS names, the legacy X11 names, and the
MD5-style hash names that Wine, Java and older Firefox still request.

## Configuration

**Hyprland** -- set both pairs.

```
env = HYPRCURSOR_THEME,Saturnian-Night
env = HYPRCURSOR_SIZE,32
env = XCURSOR_THEME,Saturnian-Night
env = XCURSOR_SIZE,32
```

**GTK / GNOME**

```sh
gsettings set org.gnome.desktop.interface cursor-theme Saturnian-Night
gsettings set org.gnome.desktop.interface cursor-size 32
```

## Notes

The per-user install path is `~/.local/share/icons`, not `$XDG_DATA_HOME/icons`.
libhyprcursor ignores `XDG_DATA_HOME` and only searches
`$HOME/.local/share/icons`, `$HOME/.icons` and `/usr/share/icons`. If your XDG
data home is relocated, install there anyway or Hyprland will quietly use the
XCursor half instead of the vector one.

The drawings were designed at 32 px, which is the size to use them at.

## Credits

`grab` and `grabbing` are redrawn from outline icons sourced via SVG Repo.
