-- =========================================================================
-- @snes19xx Hyprland CONFIG
-- =========================================================================

local mod     = "SUPER"
local alt     = "ALT"
local home    = os.getenv("HOME") or "/home/snes"
local scripts = home .. "/.config/hypr/scripts"

-- Import Shader Manager and Inject Core
local shader = require("shader")

-- =========================================================================
-- Monitors
-- =========================================================================
-- The installer rewrites the blocks below from what you enter on its monitor
-- screen. Editing them by hand afterwards is fine, keep them at the top level.
hl.monitor({
    output   = "eDP-1",
    mode     = "2256x1504@60",
    position = "0x0",
    scale    = 1,
})
hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@60",
    position = "1920x0",
    scale    = 1.33,
})

local function set_wallpapers()
    hl.exec_cmd(scripts .. "/wallpaper.sh")
end

-- Plugging a monitor in gives it no wallpaper until awww is told about it, so
-- redraw shortly after the layout settles.
local function set_wallpapers_delayed()
    hl.timer(set_wallpapers, { timeout = 500, type = "oneshot" })
end

hl.on("monitor.added",   set_wallpapers_delayed)
hl.on("monitor.removed", set_wallpapers_delayed)

-- =========================================================================
-- Environment Variables
-- =========================================================================
-- Cursor: 
local function theme_mode()
    local f = io.open(home .. "/.cache/quickshell/theme_mode", "r")
    if not f then return "dark" end
    local m = f:read("l") or ""
    f:close()
    return m:gsub("%s+", "") == "light" and "light" or "dark"
end

local function cursor_installed(name)
    for _, dir in ipairs({ home .. "/.local/share/icons/", "/usr/share/icons/" }) do
        local f = io.open(dir .. name .. "/index.theme", "r")
        if f then f:close() return true end
    end
    return false
end

local wanted_cursor = theme_mode() == "light" and "Saturnian-Day" or "Saturnian-Night"
local cursor_theme  = cursor_installed(wanted_cursor) and wanted_cursor or "Adwaita"

hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE",  "32")
hl.env("XCURSOR_THEME",    cursor_theme)
hl.env("XCURSOR_SIZE",     "32")
hl.env("GDK_SCALE",       "2")
hl.env("GDK_BACKEND",     "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("TERMINAL",        "kitty")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE",    "kvantum")
hl.env("QT_QPA_PLATFORM",      "wayland;xcb")

-- =========================================================================
-- Autostart
-- =========================================================================
hl.on("hyprland.start", function()
    shader.toggle("Main")
    hl.exec_cmd("qs")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dunst")
    hl.exec_cmd("blueman-applet")
    -- hyprpolkitagent if you have it, polkit-gnome otherwise
    hl.exec_cmd("systemctl --user start hyprpolkitagent 2>/dev/null || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- needs the oauth done first, skip it if there's no config
    hl.exec_cmd("[ -f $HOME/.config/vdirsyncer/config ] && vdirsyncer sync || true")
    hl.exec_cmd("sleep 1 && mpv --no-video --volume=100 " .. home .. "/.config/hypr/sounds/startup.wav")
    hl.timer(set_wallpapers, { timeout = 1500, type = "oneshot" }) -- after awww-daemon is up
end)

-- =========================================================================
-- Workspace Rules
-- =========================================================================
for i = 1, 5  do hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" }) end
for i = 6, 10 do hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" }) end

-- =========================================================================
-- Core Config
-- =========================================================================
hl.config({
    general = {
        gaps_in               = 1,
        gaps_out              = 3,
        border_size           = 1,
        ["col.active_border"]   = "rgba(87b158aa)",
        ["col.inactive_border"] = "rgba(595959aa)",
        resize_on_border      = false,
        allow_tearing         = false,
        layout                = "dwindle"
    },
    decoration = {
        rounding         = 7,
        active_opacity   = 1.0,
        inactive_opacity = 0.9,
        dim_inactive     = false,
        dim_strength     = 0.19,
        dim_around       = 0.6,
        shadow = {
            enabled      = true,
            range        = 3,
            render_power = 17,
            color        = "rgba(44220044)"
        },
        blur = {
            enabled           = true,
            size              = 5,
            passes            = 2,
            new_optimizations = true,
        }
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_resizing = true
    },
    master = {
        new_status = "master"
    },
    group = {
        ["col.border_active"]   = "rgba(00000000)",
        ["col.border_inactive"] = "rgba(00000000)",
        groupbar = {
            enabled              = true,
            height               = 16,
            gradients            = true,
            ["col.active"]       = "rgb(87b158)",
            ["col.inactive"]     = "rgba(2D353Bff)",
            keep_upper_gap       = false,
            indicator_height     = 0,
            indicator_gap        = 0,
            gaps_in              = 0,
            gaps_out             = 9,
            gradient_rounding    = 8,
            font_family          = "Inter",
            font_size            = 11,
            font_weight_active   = "medium",
            font_weight_inactive = "medium",
            text_color           = "rgb(293136)",
            text_color_inactive  = "rgba(e5e6c5ff)",
            text_offset          = 1
        }
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0.35,
        repeat_rate  = 50,
        repeat_delay = 300,
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true
        }
    },
    xwayland = {
        force_zero_scaling = true
    },
    misc = {
        vrr                      = 1,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        animate_manual_resizes   = true,
        enable_swallow           = true,
        swallow_regex            = "^(kitty)$"
    },
layerrule = {
    "animation slide, rofi",
    "animation popin, power-menu",
    "dim_around, power-menu",
}
})

-- =========================================================================
-- Animations
-- =========================================================================
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0.0}, {0, 1.0} } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1.0} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0.0}, {0.8, 0.15} } })

hl.curve("winIn", { type = "spring", mass = 1, stiffness = 350, dampening = 35 })
hl.curve("winOut", { type = "spring", mass = 1, stiffness = 320, dampening = 32 })
hl.curve("winMove", { type = "spring", mass = 1, stiffness = 300, dampening = 30 })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, spring = "winIn", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, spring = "winOut", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "winMove", style = "slide" })

hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "md3_standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2, bezier = "md3_standard" })

hl.animation({ leaf = "workspacesIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slidefade 15%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3, bezier = "md3_accel", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "md3_accel", style = "slide top" })

hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "md3_accel" })




-- =========================================================================
-- Gestures
-- =========================================================================
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical",   action = "fullscreen" })

-- =========================================================================
-- Keybindings
-- =========================================================================

-- Hub & Modes
hl.bind(mod .. " + SPACE", hl.dsp.global("quickshell:hubToggle")) -- QuickShell Hub
hl.bind(mod .. " + R", hl.dsp.global("quickshell:drawerToggle"))  -- Workspace Drawer

-- Apps
hl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))
-- hl.bind(mod .. " + R", hl.dsp.exec_cmd(home .. "/.config/rofi/rofi_wide.sh")) -- if you prefer rofi
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("lens --no-decorations --sniper"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))

-- Window Actions
hl.bind(mod .. " + X", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + " .. alt .. " + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600 }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(mod .. " + M", function() hl.dispatch(hl.dsp.window.fullscreen()) end)
-- hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + DOWN", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + UP",   hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + G",    hl.dsp.group.toggle())

hl.bind(mod .. " + L", function()
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ exact = true, x = 1440, y = 1080 }))
end)

hl.bind(mod .. " + CTRL + left",  hl.dsp.group.prev())
hl.bind(mod .. " + CTRL + right", hl.dsp.group.next())

hl.bind(mod .. " + " .. alt .. " + F4", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(alt .. " + F4", hl.dsp.exec_cmd("hyprctl layers | grep -q power-menu || quickshell -p ~/.config/quickshell/utils/PowerMenu.qml"))

hl.bind(mod .. " + left",         hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right",        hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",   hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mod .. " + H",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh d"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh i"))
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh i"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh d"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh m"))
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh"))

hl.bind("Print",                    hl.dsp.exec_cmd(scripts .. "/screenshot.sh s"))
hl.bind(mod .. " + Print",         hl.dsp.exec_cmd(scripts .. "/screenshot.sh p"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/screenshot.sh sf"))
hl.bind(mod .. " + O",             hl.dsp.exec_cmd(scripts .. "/screenshot.sh m"))

-- =========================================================================
-- Workspace Binds
-- =========================================================================
for i = 1, 9 do
    hl.bind(mod .. " + " .. tostring(i),         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. tostring(i), hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- =========================================================================
-- Mouse Binds
-- =========================================================================
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- =========================================================================
-- Lid Switch
-- =========================================================================
-- switch:off = lid OPEN, switch:on = lid CLOSED
-- No monitor block here. The installer regenerates every
-- monitor block in this file and would take these two with it.
-- "preferred,auto" re-reads the panel instead of repeating the mode above, so
-- this keeps working whatever the monitor section ends up saying.
hl.bind("switch:off:Lid Switch", function()
    hl.exec_cmd("hyprctl keyword monitor eDP-1,preferred,auto,1")
    set_wallpapers_delayed()
end, { locked = true })

hl.bind("switch:on:Lid Switch", function()
    hl.exec_cmd("hyprctl keyword monitor eDP-1,disable")
end, { locked = true })

-- =========================================================================
-- Window Rules
-- =========================================================================
hl.window_rule({ match = { class = "^kitty$" }, float = true, size = "950 550", center = true, rounding = 8, opacity = "0.9 0.9" })
hl.window_rule({ match = { class = "^org.pwmt.zathura$" }, float = true, size = "750 1000" })
hl.window_rule({ match = { class = "^blueman-manager$" }, float = true, size = "500 300", move = "1165 777", rounding = 10, opacity = "0.90 0.90", border_size = 1, border_color = "rgb(87b158) rgb(2D353B)", animation = "popin", dim_around = true })
hl.window_rule({ match = { class = "^nm-connection-editor$" }, float = true, size = "500 600", center = true, rounding = 10, opacity = "0.95 0.95", border_color = "rgb(87b158)" })
hl.window_rule({ match = { class = "^com.snes.evercal$" }, float = true, size = "1000 650", center = true, border_size = 1, rounding = 8 })
hl.window_rule({ match = { class = "^org.gnome.Lollypop$" }, float = true, size = "900 600" })
hl.window_rule({ match = { class = "^org.kde.plasma-systemmonitor$" }, float = true, size = "1000 700", rounding = 14 })
hl.window_rule({ match = { class = "^lens$" }, float = true, center = true, size = "1000 700", rounding = 10, border_color = "rgb(374527)" })
--hl.window_rule({ match = { class = "^thunar$" }, float = true, size = "900 600", center = true })
hl.window_rule({ match = { class = "^xdm-app$" }, float = true, size = "700 400", rounding = 10, opacity = "0.8 0.8", center = true })
hl.window_rule({ match = { class = "^org.gnome.FileRoller$" }, float = true, size = "500 350", center = true, rounding = 10, border_color = "rgb(87b158)" })
hl.window_rule({ match = { class = "^com.snes.nowplaying$" }, float = true, pin = true, border_size = 1, border_color = "rgb(1e2327)", animation = "slide", move = "1425 16", opacity = "0.9 0.9" })
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true, center = true, size = "700 400" })

local portals = { "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland|org.freedesktop.impl.portal.desktop.gtk|org.freedesktop.impl.portal.desktop.kde)$", "^(org.kde.polkit-kde-authentication-agent-1|polkit-gnome-authentication-agent-1|lxqt-policykit-agent|mate-polkit)$", "^(pinentry|pinentry-gtk-2|pinentry-gnome3|gcr-prompter)$", "^(ssh-askpass|sshaskpass)$" }
for _, p in ipairs(portals) do hl.window_rule({ match = { class = p }, tag = "portal-ui" }) end
hl.window_rule({ match = { tag = "portal-ui" }, float = true, center = true, rounding = 10, size = "1100 750", dim_around = true, opacity = "0.95 0.95" })

local dialog_titles = { "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Choose wallpaper)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$", "^(Library)(.*)$", "^(File Upload)(.*)$", "^(Extract archive)$", "^(Extract)(.*)$", "^(Extract to)$", "^(Confirm to replace files)$", "^(Rename)(.*)$", "^(Create New Folder)$", "^(Properties)$", "^(File Operation Progress)(.*)$" }
for _, t in ipairs(dialog_titles) do hl.window_rule({ match = { title = t }, float = true, center = true }) end

local dim_dialogs = { "^(Open File)(.*)$", "^(Save As)(.*)$", "^(Confirm to replace files)$" }
for _, t in ipairs(dim_dialogs) do hl.window_rule({ match = { title = t }, dim_around = true }) end

hl.window_rule({ match = { title = "^(Open File)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Save As)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(File Upload)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Confirm to replace files)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(File Operation Progress)(.*)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(Rename)(.*)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Create New Folder)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Properties)$" }, size = "500 600" })
hl.window_rule({ match = { modal = true }, float = true, center = true, rounding = 10 })