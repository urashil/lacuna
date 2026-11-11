# Stage part "apparmor" (sourced by airootfs.sh, before customize): AppArmor in the live system. The kernel gets
# the LSM (profiledef.sh), apparmor.service loads the profiles at boot (customize.sh). Confined in enforce mode:
# Tor Browser (firefox and its own tor), with the profiles torbrowser-launcher ships (the ones Tails uses), pointed
# at where appbox runs it. Arch's packaged profiles (mostly "unconfined" user-namespace grants) load as well.
TBDIR=/run/lacuna-apps/torbrowser/tor-browser
br pacman -Sw --noconfirm --needed torbrowser-launcher >/dev/null
pkg=$(ls -t "$CACHE"/torbrowser-launcher-*.pkg.tar.zst | head -1)
[[ -s $pkg ]] || die "apparmor: torbrowser-launcher package not downloaded"
bsdtar -xf "$pkg" -C "$AIROOT" etc/apparmor.d
a=$AIROOT/etc/apparmor.d
sed -i "s|^@{torbrowser_installation_dir}=.*|@{torbrowser_installation_dir}=$TBDIR|" "$a/tunables/torbrowser"
sed -i "s|/home/\*/.local/share/torbrowser/tbb/{i686,x86_64}/tor-browser|$TBDIR|" \
    "$a/torbrowser.Browser.firefox" "$a/torbrowser.Tor.tor"
grep -q "$TBDIR/Browser/firefox.real" "$a/torbrowser.Browser.firefox" || die "apparmor: firefox path not replaced"
cat > "$a/local/torbrowser.Browser.firefox" <<'R'
# Lacuna: Tor Browser runs as its own user (torbrowser). It draws and plays sound through the live user's
# Wayland and PipeWire/Pulse sockets (appbox gives that user ACLs on them), which aren't its own, so the
# stock profile's "owner" rules don't cover them.
/run/user/[0-9]*/ r,
/run/user/[0-9]*/wayland-[0-9]* rw,
/run/user/[0-9]*/pipewire-0 rw,
/run/user/[0-9]*/pulse/ r,
/run/user/[0-9]*/pulse/native rw,
# its RAM home and runtime dir (appbox: HOME and XDG_RUNTIME_DIR under /run/lacuna-apps/torbrowser)
owner /run/lacuna-apps/torbrowser/ r,
owner /run/lacuna-apps/torbrowser/{.cache,.config,.local,.mozilla,run}/{,**} rwk,
# downloads land in the live user's ~/Downloads/Tor Browser
"/home/*/Downloads/Tor Browser/" rw,
"/home/*/Downloads/Tor Browser/**" rwk,
R
# a profile with a syntax error would leave Tor Browser unconfined (or not starting): fail the build instead
air apparmor_parser -Q -K --skip-cache /etc/apparmor.d/torbrowser.Browser.firefox /etc/apparmor.d/torbrowser.Tor.tor ||
    die "apparmor: the Tor Browser profiles don't parse"
echo "   apparmor: Tor Browser profiles (enforce) for $TBDIR"
