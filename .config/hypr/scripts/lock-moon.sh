#!/usr/bin/env bash
# Prints the current moon phase as Pango markup for the lockscreen footer:
#   —  <emoji>  <phase name> · <NN>% lit
# Computed locally  from the mean synodic month. Northern-hemisphere
# emoji orientation. 
exec python3 - <<'PY'
import math, time

# Reference new moon: 2000-01-06 18:14 UTC = JD 2451550.1
SYNODIC = 29.53058867
jd = time.time() / 86400.0 + 2440587.5
frac = ((jd - 2451550.1) / SYNODIC) % 1.0          # 0=new .. 0.5=full
illum = round((1 - math.cos(2 * math.pi * frac)) / 2 * 100)

phases = [
    ("🌑", "New Moon"),        ("🌒", "Waxing Crescent"),
    ("🌓", "First Quarter"),   ("🌔", "Waxing Gibbous"),
    ("🌕", "Full Moon"),       ("🌖", "Waning Gibbous"),
    ("🌗", "Last Quarter"),    ("🌘", "Waning Crescent"),
]
emoji, name = phases[int(frac * 8 + 0.5) % 8]

print(
    '<span foreground="#8d8676">—  </span>'
    f'{emoji}  '
    f'<span foreground="#c8c1b2" style="italic">{name}</span>'
    f'<span foreground="#8d8676"> · {illum}% lit</span>',
    end="",
)
PY
