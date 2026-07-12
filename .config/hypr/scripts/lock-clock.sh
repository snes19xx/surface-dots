#!/usr/bin/env bash
# Renders the lockscreen clock as Pango markup so each part can be styled
# independently, like my SDDM "stellarium" theme:
#   HH  -> EB Garamond, warm ink (#ece6d6)
#   :   -> EB Garamond, faint   (#8d8676)
#   MM  -> Newsreader italic, accent green (#87b08a)
H=$(date +%H)
M=$(date +%M)
printf '<span font_family="EB Garamond" foreground="#ece6d6">%s</span><span font_family="EB Garamond" foreground="#8d8676">:</span><span font_family="Newsreader" style="italic" foreground="#87b08a">%s</span>' "$H" "$M"
