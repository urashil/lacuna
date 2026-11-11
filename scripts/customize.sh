#!/usr/bin/env bash
# Runs INSIDE the live root (proot, root "/"). The equivalent of archiso's customize_airootfs.sh.
set -euo pipefail
locale-gen

# live user: no persistence and no usable password (greeter-customize.sh locks it; the greeter may set one)
id amnesia >/dev/null 2>&1 || useradd -M -u 1000 -U -G wheel,video,audio,input -s /usr/bin/zsh -d /home/amnesia amnesia
# apps that run as their own user (appbox): Tor Browser, and the Unsafe Browser (the only user the firewall lets
# out directly, and only when allowed in the greeter)
for u in torbrowser clearnet; do
    id "$u" >/dev/null 2>&1 || useradd -r -M -U -d / -s /usr/bin/nologin "$u"
done
# niri includes colors.kdl and keyboard.kdl but parses its config before anything at login could create them:
# generate both now (the login scripts still refresh them; keyboard-mode stays on "auto")
H=/home/amnesia
as_amnesia_env=(env HOME=$H XDG_CONFIG_HOME=$H/.config XDG_CACHE_HOME=$H/.cache XDG_STATE_HOME=$H/.local/state)
# caelestia's own scheme state: without one it falls back to catppuccin mocha, which has no light mode, so the
# light/dark toggle fails. Use the wallpaper-based "dynamic" scheme (both modes).
wp=$(cat $H/.cache/rice/current)
"${as_amnesia_env[@]}" caelestia wallpaper -f "$wp" >/dev/null 2>&1 || true
"${as_amnesia_env[@]}" caelestia scheme set -n dynamic -m dark >/dev/null 2>&1 || true
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("name")=="dynamic" else 1)' \
    $H/.local/state/caelestia/scheme.json ||
    { echo "caelestia scheme is not 'dynamic' (light mode would fail)" >&2; exit 1; }
if [[ -x $H/.local/bin/rice-theme-sync ]]; then
    # newer dotfiles: caelestia owns the palette and its postHook (rice-theme-sync) renders the app templates.
    # Run it once here; outside a session its gsettings/kitty reload steps just fail quietly.
    "${as_amnesia_env[@]}" $H/.local/bin/rice-theme-sync >/dev/null 2>&1 || true
else
    # older dotfiles: matugen renders the templates (runs after caelestia so its outputs win)
    "${as_amnesia_env[@]}" matugen image "$wp" --mode dark --type scheme-tonal-spot --prefer saturation --quiet
fi
"${as_amnesia_env[@]}" $H/.local/bin/keyboard-mode standard >/dev/null
rm -f /home/amnesia/.config/rice/keyboard-mode
for f in colors.kdl keyboard.kdl larp.kdl; do
    [[ -s /home/amnesia/.config/niri/$f || $f == larp.kdl ]] || { echo "missing niri include: $f" >&2; exit 1; }
done
niri validate -c /home/amnesia/.config/niri/config.kdl

chown -R amnesia:amnesia /home/amnesia
chmod 700 /home/amnesia

# boot splash (theme from the wallpaper + palette above)
bash /build/lacuna/scripts/plymouth-theme.sh
# greeter: foot colours + wallpaper from the same palette, password locked, greeterd enabled
bash /build/lacuna/scripts/greeter-customize.sh

systemctl enable greetd NetworkManager iwd bluetooth power-profiles-daemon upower systemd-timesyncd usbguard
# Arch's presets enable systemd-resolved: the live system doesn't use it (NetworkManager writes resolv.conf, the gate
# redirects DNS into Tor), and its mDNS listener sat on the port Tor's DNS uses
systemctl mask systemd-resolved.service >/dev/null 2>&1 || true
systemctl enable apparmor.service
systemctl enable piavpn 2>/dev/null || true
systemctl set-default graphical.target
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service
# no swap of any kind, ever
systemctl mask systemd-zram-setup@zram0.service swap.target >/dev/null 2>&1 || true

# the live system's own pacman: no local [lacuna] repo, keyring set up at boot only if someone needs pacman
sed -i '/^\[lacuna\]/,/^$/d' /etc/pacman.conf
# USBGuard refuses world-readable rule/config files
chmod 600 /etc/usbguard/rules.conf /etc/usbguard/usbguard-daemon.conf /etc/usbguard/IPCAccessControl.d/:wheel

# archiso initramfs (overlay's mkinitcpio.conf.d/archiso.conf)
mkinitcpio -P
