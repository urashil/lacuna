# Stage part "greeter" (sourced by airootfs.sh after the overlay): installs the milestone-3 greeter into $AIROOT.
# The palette-dependent bits (foot colours, wallpaper) are made in customize.sh, where the palette exists.
G=$LACUNA/greeter
install -Dm755 "$G/greeterd"        "$AIROOT/usr/local/lib/lacuna/greeterd"
install -Dm755 "$G/login-gate"      "$AIROOT/usr/local/lib/lacuna/login-gate"
install -Dm755 "$G/greeter-session" "$AIROOT/usr/local/lib/lacuna/greeter-session"
install -Dm755 "$G/greeter-loop"    "$AIROOT/usr/local/lib/lacuna/greeter-loop"
install -Dm755 "$G/greeter"  "$AIROOT/usr/local/bin/greeter"
install -Dm755 "$G/lock"     "$AIROOT/usr/local/bin/lock"
install -Dm644 "$G/niri.kdl"        "$AIROOT/usr/share/lacuna/greeter/niri.kdl"
install -Dm644 "$G/greetd-config.toml" "$AIROOT/etc/greetd/config.toml"
install -Dm644 "$G/pam-greetd"      "$AIROOT/etc/pam.d/greetd"
install -Dm644 "$G/lacuna-greeterd.service" "$AIROOT/etc/systemd/system/lacuna-greeterd.service"
install -Dm644 "$G/getty-nogui.conf" "$AIROOT/etc/systemd/system/getty@tty1.service.d/lacuna-nogui.conf"
install -Dm644 "$G/settings.desktop" "$AIROOT/usr/share/applications/settings.desktop"
install -Dm755 "$G/appbox"        "$AIROOT/usr/local/lib/lacuna/appbox"
install -Dm755 "$G/launch" "$AIROOT/usr/local/bin/launch"
# the opsec session (labwc + waybar + fuzzel; Tor only, SOCKS per app)
O=$G/opsec
install -Dm755 "$O/torapp"                "$AIROOT/usr/local/bin/torapp"
install -Dm755 "$O/opsec-session"  "$AIROOT/usr/local/bin/opsec-session"
install -Dm755 "$O/tor-status"              "$AIROOT/usr/share/lacuna/opsec/tor-status"
install -Dm644 "$O/labwc/rc.xml"          "$AIROOT/usr/share/lacuna/opsec/labwc/rc.xml"
install -Dm644 "$O/labwc/menu.xml"        "$AIROOT/usr/share/lacuna/opsec/labwc/menu.xml"
install -Dm644 "$O/labwc/autostart"       "$AIROOT/usr/share/lacuna/opsec/labwc/autostart"
install -Dm644 "$O/waybar/config.jsonc"   "$AIROOT/usr/share/lacuna/opsec/waybar/config.jsonc"
install -Dm644 "$O/waybar/style.css"      "$AIROOT/usr/share/lacuna/opsec/waybar/style.css"
# broken XML or JSON would leave the opsec session without keybinds or a bar: fail the build instead
python3 -I - "$O" <<'PY' || die "greeter: an opsec session config doesn't parse"
import json, re, sys, xml.etree.ElementTree as ET
d = sys.argv[1]
for f in ("labwc/rc.xml", "labwc/menu.xml"):
    ET.parse(f"{d}/{f}")
json.loads(re.sub(r"^\s*//.*$", "", open(f"{d}/waybar/config.jsonc").read(), flags=re.M))
PY
