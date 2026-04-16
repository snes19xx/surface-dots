#!/usr/bin/env bash

# Check if there are arguments (something and hit Enter)
if [ -n "$*" ]; then
    # 1. nohup: Keeps the browser running even after this script dies
    # 2. >/dev/null 2>&1: Silences output so Rofi doesn't wait for text
    # 3. &: Runs it in the background immediately
    nohup xdg-open "https://www.google.com/search?q=$*" >/dev/null 2>&1 &
    exit 0
fi

# If no args (initial run), print nothing
exit 0