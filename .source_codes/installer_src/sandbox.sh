#!/usr/bin/env bash
# Run the installer against a throwaway $HOME so it never touches your real
# ~/.config. SDDM writes are redirected into /tmp/sandbox-root via the fake
# pkexec beside this script.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_HOME="$HOME"
SANDBOX="/tmp/sandbox-home"
FAKEBIN="/tmp/fake-bin"
REPO="${SD_REPO_ROOT:-$REAL_HOME/Documents/surface-dots}"

if [[ ! -d "$REPO/.config" || ! -d "$REPO/sddm" ]]; then
    echo "surface-dots repo not found at: $REPO" >&2
    echo "Set SD_REPO_ROOT to the repo path and re-run." >&2
    exit 1
fi

rm -rf "$SANDBOX"
mkdir -p "$SANDBOX/.config" "$SANDBOX/.cache" "$SANDBOX/.local/share" "$SANDBOX/.themes" "$FAKEBIN"
rm -rf /tmp/sandbox-root

install -m 755 "$HERE/pkexec" "$FAKEBIN/pkexec"

FINISHLOG="/tmp/sandbox-calls.log"
rm -f "$FINISHLOG"
for shim in qs awww awww-daemon notify-send; do
    cat > "$FAKEBIN/$shim" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "query" ]] && exit 0
echo "[$shim] \$*" >> "$FINISHLOG"
EOF
    chmod 755 "$FAKEBIN/$shim"
done

export HOME="$SANDBOX"
export XDG_CONFIG_HOME="$SANDBOX/.config"
export XDG_CACHE_HOME="$SANDBOX/.cache"
export XDG_DATA_HOME="$SANDBOX/.local/share"

export SD_REPO_ROOT="$REPO"
export SD_SKIP_POLKIT_CHECK=1

export RUSTUP_HOME="$REAL_HOME/.rustup"
export CARGO_HOME="$REAL_HOME/.cargo"
export PATH="$FAKEBIN:$CARGO_HOME/bin:$PATH"

export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_GPU_PROCESS=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1

BIN="${SD_INSTALLER_BIN:-$HERE/surface-dots-installer}"

echo "sandbox HOME : $SANDBOX"
echo "repo         : $REPO"
echo "sddm writes  : /tmp/sandbox-root"
echo "binary       : $BIN"
echo "shimmed calls: $FINISHLOG"

if [[ -x "$BIN" ]]; then
    exec "$BIN"
else
    echo "release binary not found at $BIN - falling back to cargo run" >&2
    cd "$HERE/installer/src-tauri"
    exec cargo run
fi
