# Stage part "installer" (sourced by airootfs.sh): the TUI installer and harden (PLAN section 9, milestone 8).
I=$LACUNA/installer
install -Dm755 "$I/installer" "$AIROOT/usr/local/bin/installer"
install -Dm755 "$I/harden"    "$AIROOT/usr/local/bin/harden"
install -Dm644 "$I/installer.desktop" "$AIROOT/usr/share/applications/installer.desktop"
# installing on Shufflecake: the new system's boot unlock, units and the modules copy (installer/sflc)
rm -rf "$AIROOT/usr/share/lacuna/installer/sflc"; install -d "$AIROOT/usr/share/lacuna/installer/sflc"
cp -a "$I/sflc/." "$AIROOT/usr/share/lacuna/installer/sflc/"
for f in "$I"/sflc/{initcpio-install,unlock,modules,modules-sfs,decoy-mount,sflc-tpm}; do bash -n "$f" || die "installer: $f doesn't parse"; done
# TPM2 enrollment at an installed system's first start (installer/tpm)
rm -rf "$AIROOT/usr/share/lacuna/installer/tpm"; install -d "$AIROOT/usr/share/lacuna/installer/tpm"
cp -a "$I/tpm/." "$AIROOT/usr/share/lacuna/installer/tpm/"
bash -n "$I/tpm/tpm-enroll" || die "installer: tpm-enroll doesn't parse"
# the rice's boot and login screens for installed systems (installer/rice)
source "$LACUNA/scripts/rice-boot.sh"
# the package groups the installer offers, from the sections of the ISO's own package list
mkdir -p "$AIROOT/usr/share/lacuna/installer"
python3 -I - "$LACUNA/profile/packages.x86_64" "$AIROOT/usr/share/lacuna/installer/groups.json" <<'PY'
import json, sys
sec, cur = {}, None
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith("# ----"):
        cur = line.strip("# -").split(" (")[0].strip(); sec[cur] = []
    elif line and not line.startswith("#") and cur:
        sec[cur].append(line.split()[0])
live_only = {"mkinitcpio-archiso", "plymouth", "syslinux", "pv", "busybox", "arch-install-scripts", "greetd",
             "usbguard", "python-textual"}
vpn = {"piavpn-bin": "vpn-pia", "mullvad-vpn-daemon-bin": "vpn-mullvad", "ivpn": "vpn-ivpn"}
pick = lambda names: [p for n in names for p in sec.get(n, []) if p not in live_only and p not in vpn]
g = {
    "graphics": {"title": "Graphics, sound, Bluetooth, power (needed for a desktop)", "packages": pick(["graphics / audio / hardware"])},
    "desktop": {"title": "The desktop: niri + caelestia shell, terminals, fonts, CLI tools", "packages": pick(["session", "shell / cli"])},
    "apps": {"title": "Apps: browsers, mail, passwords, wallets, messengers, media, privacy tools", "packages": pick(["apps"])},
    "tor": {"title": "Tor, Nyx, torsocks", "packages": ["tor", "nyx", "torsocks"]},
    "vpn-pia": {"title": "PIA VPN client", "packages": ["piavpn-bin"]},
    "vpn-mullvad": {"title": "Mullvad VPN (daemon + mullvad CLI)", "packages": ["mullvad-vpn-daemon-bin"]},
    "vpn-ivpn": {"title": "IVPN (daemon + ivpn CLI)", "packages": ["ivpn"]},
}
assert all(v["packages"] for v in g.values()), {k: len(v["packages"]) for k, v in g.items()}
json.dump(g, open(sys.argv[2], "w"), indent=1)
print("   installer: groups " + ", ".join(f"{k} ({len(v['packages'])})" for k, v in g.items()))
PY
# the desktop configuration, as built (the live home changes at runtime; this copy doesn't)
rm -rf "$AIROOT/usr/share/lacuna/skel"; cp -a "$WORK/skel" "$AIROOT/usr/share/lacuna/skel"
# Lacuna's own repo (the AUR builds: the shell, the VPN clients, ...) for installing them offline
rm -rf "$AIROOT/opt/lacuna/repo"; install -d "$AIROOT/opt/lacuna/repo"
cp -a "$REPO"/lacuna.db* "$REPO"/lacuna.files* "$AIROOT/opt/lacuna/repo/"
rm -f "$AIROOT"/opt/lacuna/repo/*.old
# only the packages the database lists (no old versions); bsdtar reads its zstd, the host's Python can't
n=0
while read -r f; do
    cp -a "$REPO/$f" "$AIROOT/opt/lacuna/repo/"; n=$((n + 1))
done < <(bsdtar -xOf "$REPO/lacuna.db" '*/desc' | awk 'p {print; p=0} /^%FILENAME%$/ {p=1}')
((n > 0)) || die "installer: no packages listed in Lacuna's repo"
echo "   installer: $n packages of Lacuna's repo on the stick"
echo "   installer: installed"
