-- shader.lua: Screen shader manager for my hyprland setup. 
-- hyprshade is no longer required

local home       = os.getenv("HOME") or "/home/snes"
local shader_dir = home .. "/.config/hypr/shaders/"

-- Cache files
local cache_dir       = home .. "/.cache/quickshell"
local theme_mode_file = cache_dir .. "/theme_mode"
local rm_restore_file = cache_dir .. "/reading_mode_restore"
local rm_state_file   = cache_dir .. "/reading_mode"
local nl_state_file   = cache_dir .. "/night_light"
local crt_state_file  = cache_dir .. "/crt_mode"

local theme_script     = home .. "/.config/quickshell/utils/theme-mode.sh"
local wallpaper_script = home .. "/.config/hypr/scripts/wallpaper.sh"
local wallpaper_conf   = home .. "/.config/surface-dots/wallpapers.conf"

local M = {}

M.current_shader = nil
M.active_mode    = nil

-- Default decoration / layout values
M.defaults = {
    rounding        = 7,
    gaps_in         = 1,
    gaps_out        = 2,
    border_size     = 1,
    active_border   = "rgba(87b158aa)",
    inactive_border = "rgba(595959aa)",
    animations      = true,
    shadow          = true,
    blur            = true,
    dim_inactive    = false,
    dim_around      = 0.6,
    damage_tracking = 2,
}

M.ui_state = {
    theme = "dark",
}

-- Helpers
local function write_file(path, content)
    local f = io.open(path, "w")
    if f then f:write(content) f:close() end
end

local function read_file(path, fallback)
    local f = io.open(path, "r")
    if not f then return fallback end
    local content = f:read("*l") or ""
    f:close()
    content = content:match("^%s*(.-)%s*$")
    return (content ~= "") and content or fallback
end

local function wallpaper_override(key)
    local f = io.open(wallpaper_conf, "r")
    if not f then return nil end
    local value
    for line in f:lines() do
        local v = line:match("^%s*" .. key .. "%s*=%s*(.+)$")
        if v then value = v end
    end
    f:close()
    if not value then return nil end
    value = value:gsub("[\"']", ""):gsub("%s+$", "")
    value = value:gsub("%$HOME", home):gsub("^~", home)
    return (value ~= "") and value or nil
end


local function wallpaper_cmd(key, transition)
    local override = key and wallpaper_override(key)
    if override then
        return 'awww img "' .. override .. '" ' .. (transition or "--transition-type none")
    end
    return wallpaper_script
end

local function apply_theme(theme, with_wallpaper)
    M.ui_state.theme = theme
    local cmd = theme_script .. " " .. theme .. " --quiet --no-wallpaper"
    if with_wallpaper then cmd = cmd .. " && " .. wallpaper_script end
    hl.exec_cmd(cmd)
end

local function switch_theme(restore_file, new_theme)
    local current = read_file(theme_mode_file, "dark")
    write_file(restore_file, current)
    apply_theme(new_theme)
end

local function restore_defaults()
    hl.config({
        general = {
            gaps_in         = M.defaults.gaps_in,
            gaps_out        = M.defaults.gaps_out,
            border_size     = M.defaults.border_size,
            ["col.active_border"]   = M.defaults.active_border,
            ["col.inactive_border"] = M.defaults.inactive_border,
        },
        decoration = {
            rounding     = M.defaults.rounding,
            dim_inactive = M.defaults.dim_inactive,
            dim_around   = M.defaults.dim_around,
            shadow       = { enabled = M.defaults.shadow },
            blur         = { enabled = M.defaults.blur },
        },
        animations = { enabled = M.defaults.animations },
        debug      = { damage_tracking = M.defaults.damage_tracking },
    })
    
    -- Isolate shader clear
    hl.config({ decoration = { screen_shader = "" } })
end

-- Simple shaders
M.simple_shaders = {
    ["Main"]         = "main.glsl",
    ["Outdoor"]      = "outdoor.glsl",
    ["Cinema"]       = "cinema.glsl",
    ["Soft"]         = "soft.glsl",
    ["Matte"]        = "matte.glsl",
    ["IBM 5151"]     = "IBM5151.glsl",
    ["Fuji Acros"]   = "fuji_acros.glsl",
    ["VHS"]          = "vhs.glsl",
    ["Gameboy"]      = "gameboy.glsl",
    ["Clarity"]      = "clarity_inefficient.glsl",
    ["Focus"]        = "focus.glsl",
    ["Night Vision"] = "night_vision.glsl",
}

-- Complex modes
M.complex_modes = {
    ["Reading Mode"] = {
        shader = "reading_mode.glsl",
        activate = function(shader_path)
            switch_theme(rm_restore_file, "light")
            write_file(rm_state_file, "on")

            hl.exec_cmd("sleep 1 && " .. wallpaper_cmd("WALLPAPER_READING"))
            hl.exec_cmd("brightnessctl set 37%")

            hl.config({
                general = {
                    gaps_in  = 0, gaps_out = 0, border_size = 1,
                    ["col.active_border"]   = "rgba(000000ff)",
                    ["col.inactive_border"] = "rgba(000000ff)",
                },
                decoration = {
                    rounding     = 0,
                    dim_inactive = false,
                    shadow       = { enabled = false },
                    blur         = { enabled = false },
                },
                animations = { enabled = false },
            })
            
            -- Apply shader distinctly
            hl.config({ decoration = { screen_shader = shader_path } })
        end,
        deactivate = function()
            local prev_theme = read_file(rm_restore_file, "dark")
            apply_theme(prev_theme, true)
            write_file(rm_state_file, "off")
            os.remove(rm_restore_file)

            restore_defaults()
        end,
    },

    ["Night Light"] = {
        shader = "night.glsl",
        activate = function(shader_path)
            switch_theme(rm_restore_file, "dark")
            write_file(nl_state_file, "on")

            hl.exec_cmd("brightnessctl set 37%")
            hl.config({ decoration = { screen_shader = shader_path } })
        end,
        deactivate = function()
            local prev_theme = read_file(rm_restore_file, "dark")
            apply_theme(prev_theme)
            write_file(nl_state_file, "off")
            os.remove(rm_restore_file)

            hl.exec_cmd("brightnessctl set 57%")
            restore_defaults()
        end,
    },

    ["CRT Mode"] = {
        shader = "crt_mode.glsl",
        activate = function(shader_path)
            write_file(crt_state_file, "on")

            hl.exec_cmd(wallpaper_cmd("WALLPAPER_CRT", "--transition-type grow --transition-pos 0.5,0.5 --transition-duration 1.5 --transition-fps 60"))

            hl.exec_cmd("pkill qs")
            hl.exec_cmd("qs -p " .. home .. "/.config/quickshell/lib/ThemeOSD.qml")
            hl.exec_cmd("waybar &")

            hl.config({
                general = {
                    gaps_in  = 0, gaps_out = 0, border_size = 3,
                    ["col.active_border"]   = "rgba(626c73ff)",
                    ["col.inactive_border"] = "rgba(626c73ff)",
                },
                decoration = {
                    rounding   = 0,
                    dim_around = 0,
                    shadow     = { enabled = false },
                    blur       = { enabled = false },
                },
                animations = { enabled = false },
                debug      = { damage_tracking = 0 },
            })
            
            -- Apply shader distinctly
            hl.config({ decoration = { screen_shader = shader_path } })
        end,
        deactivate = function()
            write_file(crt_state_file, "off")

            hl.exec_cmd("pkill waybar")
            hl.exec_cmd("qs &")

            hl.exec_cmd(wallpaper_script)

            restore_defaults()
        end,
    },
}

-- Public API
function M.turn_off_all()
    if M.active_mode then
        M.complex_modes[M.active_mode].deactivate()
        M.active_mode = nil
    end
    M.current_shader = nil
    hl.config({ decoration = { screen_shader = "" } })
end

function M.toggle(name)
    if name == "Turn Off All" then
        M.turn_off_all()
        return
    end

    if M.current_shader == name then
        M.turn_off_all()
        return
    end

    if M.active_mode and M.active_mode ~= name then
        M.complex_modes[M.active_mode].deactivate()
        M.active_mode    = nil
        M.current_shader = nil
    end

    if M.complex_modes[name] then
        M.active_mode    = name
        M.current_shader = name
        M.complex_modes[name].activate(shader_dir .. M.complex_modes[name].shader)
        return
    end

    if M.simple_shaders[name] then
        M.current_shader = name
        hl.config({ decoration = { screen_shader = shader_dir .. M.simple_shaders[name] } })
        return
    end
end

-- Keybindings
local mod = "SUPER"
local alt = "ALT"

hl.bind(mod .. " + D",       function() M.toggle("Reading Mode") end, { description = "Toggle Reading Mode"    })
hl.bind(mod .. " + N",       function() M.toggle("Night Light")  end, { description = "Toggle Night Light"     })
hl.bind(alt .. " + C",       function() M.toggle("CRT Mode")     end, { description = "Toggle CRT Mode"        })
hl.bind(mod .. " + ALT + S", function() M.turn_off_all()         end, { description = "Turn off all shaders"   })

-- empty return makes require() yield true (#16)
return M
