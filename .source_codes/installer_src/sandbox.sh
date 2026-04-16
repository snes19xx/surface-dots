#!/usr/bin/env bash
REAL_HOME="$HOME"
SANDBOX="/tmp/sandbox-home"

mkdir -p "$SANDBOX/.config"
mkdir -p "$SANDBOX/.local/share"
mkdir -p "$SANDBOX/.cache"
mkdir -p "/tmp/fake-bin"

export HOME="$SANDBOX"
export XDG_CONFIG_HOME="$SANDBOX/.config"
export XDG_CACHE_HOME="$SANDBOX/.cache"
export XDG_DATA_HOME="$SANDBOX/.local/share"

export RUSTUP_HOME="$REAL_HOME/.rustup"
export CARGO_HOME="$REAL_HOME/.cargo"

export PATH="/tmp/fake-bin:$CARGO_HOME/bin:$PATH"

rm -rf "${XDG_CONFIG_HOME:?}/*" 2>/dev/null

exec cargo tauri dev