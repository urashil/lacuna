#!/usr/bin/env bash
# Runs INSIDE the live root (from customize.sh, after the palette and the Plymouth theme exist): the greeter's
# palette-dependent files, and no usable password by default (PLAN section 6: set in the greeter or restored).
set -euo pipefail
H=/home/amnesia
D=/usr/share/lacuna/greeter
mkdir -p "$D"

# no default password: nothing can authenticate as amnesia (or root) until the greeter sets one
passwd -l amnesia >/dev/null
passwd -l root >/dev/null

# same blurred wallpaper as the boot splash, so splash -> greeter -> desktop look continuous
cp /usr/share/plymouth/themes/lacuna/bg.png "$D/wallpaper.png"
COLORS=$H/.cache/rice/colors.json
[[ -r $COLORS ]] || COLORS=$H/.config/quickshell/bar/colors.json
install -m644 "$COLORS" "$D/colors.json"

# foot for the TUI: the palette, opaque. Textual paints every cell with an explicit colour (which foot never makes
# see-through), so with alpha only the few pixels below the last text row showed the wallpaper: a strip at the
# bottom. Opaque, with the same background as Textual's, the leftover pixels are invisible.
python3 -I - "$D/colors.json" "$D/foot.ini" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
g = lambda k, d: c.get(k, d).lstrip("#")
fg, bg = g("text", "e2e2e9"), g("surface", "111318")
regular = [bg, g("red", "ffb4ab"), g("green", "a6d189"), g("yellow", "e5c890"), g("blue", "8caaee"),
           g("magenta", "f4b8e4"), g("cyan", "81c8be"), g("textDim", "c4c6d0")]
bright = [g("outline", "8e9099")] + regular[1:7] + [fg]
lines = ["[main]", "font=JetBrainsMono Nerd Font:size=12", "pad=0x0 center", "[cursor]", "style=beam", "blink=yes",
         "[colors-dark]", f"foreground={fg}", f"background={bg}"]
lines += [f"regular{i}={v}" for i, v in enumerate(regular)] + [f"bright{i}={v}" for i, v in enumerate(bright)]
open(sys.argv[2], "w").write("\n".join(lines) + "\n")
PY

# niri falls back to its default config on any error (no autostart, empty screen): fail the build instead
niri validate -c "$D/niri.kdl"
# foot exits on any config error, which would leave the greeter session empty: fail the build instead
foot --check-config -c "$D/foot.ini"

systemctl enable lacuna-greeterd.service
echo "   greeter: installed (amnesia password locked)"
