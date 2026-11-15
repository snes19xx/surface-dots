#!/usr/bin/env bash
# Usage: palette-gen.sh <wallpaper> <seedIndex>, prints one line of json or exits 1
set -u

W="${1:-}"
IDX="${2:-0}"
[[ -f "$W" ]] || exit 1
[[ "$IDX" =~ ^[0-9]+$ ]] || IDX=0
for c in matugen jq sha1sum stat; do command -v "$c" >/dev/null 2>&1 || exit 1; done

SCHEMES=(tonal-spot vibrant expressive fidelity content neutral monochrome rainbow fruit-salad)
ROLES='["surface","surface_container","surface_container_high","surface_container_highest","on_surface","on_surface_variant","primary","on_primary","secondary","tertiary","error","outline_variant"]'

CACHE="$HOME/.cache/quickshell/palettes"
mkdir -p "$CACHE" || exit 1
# mtime is in the key, otherwise a new wallpaper with the same name keeps the old colours
KEY="$(printf '%s %s' "$W" "$(stat -c %Y "$W")" | sha1sum | cut -d' ' -f1)"

if [[ -s "$CACHE/$KEY-$IDX.json" ]]; then
    cat "$CACHE/$KEY-$IDX.json"
    exit 0
fi

SEEDS="$(matugen image "$W" --show-source-colors --json hex --dry-run 2>/dev/null \
    | jq -Rn -c '[inputs | select(test("^#[0-9a-fA-F]{6}$"))]')" || exit 1
N="$(jq 'length' <<<"$SEEDS")" || exit 1
[[ "$N" -ge 1 ]] || exit 1
(( IDX >= N )) && IDX=$((N - 1))

if [[ -s "$CACHE/$KEY-$IDX.json" ]]; then
    cat "$CACHE/$KEY-$IDX.json"
    exit 0
fi

TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT

for id in "${SCHEMES[@]}"; do
    (
        matugen image "$W" -t "scheme-$id" --json hex --dry-run --source-color-index "$IDX" 2>/dev/null \
            | jq -c --arg id "$id" --argjson r "$ROLES" '
                {($id): {
                    dark:  ([$r[] as $k | {($k): .colors[$k].dark.color}]  | add),
                    light: ([$r[] as $k | {($k): .colors[$k].light.color}] | add)
                }}' > "$TMP/$id.json"
    ) &
done
wait

FILES=()
for id in "${SCHEMES[@]}"; do FILES+=("$TMP/$id.json"); done

jq -s -c -e --arg w "$W" --argjson seeds "$SEEDS" --argjson seed "$IDX" '
    {wallpaper: $w, seeds: $seeds, seed: $seed, schemes: add}
    | select([.schemes[][][]] | length == 216 and all(type == "string" and test("^#[0-9a-fA-F]{6}$")))
' "${FILES[@]}" > "$TMP/out.json" 2>/dev/null || exit 1
[[ -s "$TMP/out.json" ]] || exit 1

# copy then mv, otherwise the shell can read a half written file
cp "$TMP/out.json" "$CACHE/$KEY-$IDX.json.tmp$$" && mv "$CACHE/$KEY-$IDX.json.tmp$$" "$CACHE/$KEY-$IDX.json" || exit 1
cat "$CACHE/$KEY-$IDX.json"
