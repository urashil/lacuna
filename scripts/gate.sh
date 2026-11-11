# Stage part "gate" (sourced by airootfs.sh): installs the network gate (PLAN section 4) into $AIROOT.
G=$LACUNA/gate
install -Dm755 "$G/gate" "$AIROOT/usr/local/lib/lacuna/gate"
install -Dm644 "$G/lacuna-gate.service" "$AIROOT/etc/systemd/system/lacuna-gate.service"
install -Dm644 "$G/NetworkManager.service.d/lacuna-gate.conf" "$AIROOT/etc/systemd/system/NetworkManager.service.d/lacuna-gate.conf"
install -Dm644 "$G/nm-lacuna-gate.conf" "$AIROOT/etc/NetworkManager/conf.d/50-lacuna-gate.conf"
install -Dm644 "$G/sysctl-lacuna-gate.conf" "$AIROOT/etc/sysctl.d/61-lacuna-gate.conf"
# Tor's built-in bridges come from Tor Browser (verified at download): extract its pt_config.json
mkdir -p "$AIROOT/usr/share/lacuna/tor"
bsdtar -xOf "$AIROOT/opt/tor-browser/Browser/omni.ja" chrome/toolkit/content/global/pt_config.json \
    > "$AIROOT/usr/share/lacuna/tor/pt_config.json"
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["bridges"]["obfs4"]' \
    "$AIROOT/usr/share/lacuna/tor/pt_config.json" || die "no built-in bridges in Tor Browser's pt_config.json"
ln -sf ../lacuna-gate.service "$AIROOT/etc/systemd/system/sysinit.target.wants/lacuna-gate.service"
install -Dm755 "$G/leaktest" "$AIROOT/usr/local/bin/leaktest"
