#!/bin/bash
# %C = Condition (e.g. Heavy Snow), %t = Temp, %f = Feels Like
WEATHER=$(curl -s 'wttr.in?format=%C,+Feels+like+%f')
echo "$WEATHER"