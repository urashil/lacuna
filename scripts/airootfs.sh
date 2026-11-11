# Stage "airootfs" (sourced by build.sh). Builds $AIROOT the way mkarchiso's pacstrap + customize steps would,
# then leaves markers so mkarchiso (stage "iso") skips those steps.
pkgs() { grep -vE '^\s*(#|$)' "$LACUNA/profile/packages.x86_64"; }
in_br_root=/build/iso/x86_64/airootfs

msg "airootfs: seed pacman into the empty root"
mkdir -p "$AIROOT/var/lib/pacman" "$AIROOT/etc/pacman.d"
cp "$BR/etc/pacman.d/mirrorlist" "$AIROOT/etc/pacman.d/mirrorlist"
if [[ ! -x $AIROOT/usr/bin/pacman ]]; then
    # Extraction only: hooks can't run here (they'd need chroot), so this pass just gives the root a working pacman.
    br pacman --config /build/lacuna/profile/pacman.conf -r "$in_br_root" -Sy --noconfirm --noscriptlet pacman \
        2>&1 | grep -vE 'command failed to execute|execv|^\(' || true
    rm -rf "$AIROOT/var/lib/pacman/local"   # forget it again: pass 2 installs everything properly
fi
cp "$BR/etc/pacman.d/mirrorlist" "$AIROOT/etc/pacman.d/mirrorlist"
# the seed pass couldn't run update-ca-trust; lend it the build root's bundle (pass 2 regenerates its own)
mkdir -p "$AIROOT/etc/ca-certificates/extracted"
cp -a "$BR/etc/ca-certificates/extracted/." "$AIROOT/etc/ca-certificates/extracted/"

msg "airootfs: install $(pkgs | wc -l) packages (pacman runs inside the root, hooks and scriptlets for real)"
if [[ ! -e $AIROOT/var/lib/pacman/local/ALPM_DB_VERSION ]] || [[ -n ${REINSTALL:-} ]]; then
    air pacman --config /build/lacuna/profile/pacman.conf --gpgdir /build/gnupg -Sy --noconfirm \
        --overwrite '*' $(pkgs)
else
    air pacman --config /build/lacuna/profile/pacman.conf --gpgdir /build/gnupg -Sy --noconfirm --needed $(pkgs)
fi

# mkarchiso's cleanup empties /boot; a later rebuild needs the kernel back
[[ -e $AIROOT/boot/vmlinuz-linux-hardened ]] ||
    air pacman --config /build/lacuna/profile/pacman.conf --gpgdir /build/gnupg -S --noconfirm linux-hardened

msg "airootfs: overlay + live user home"
cp -af --no-preserve=ownership "$LACUNA/profile/airootfs/." "$AIROOT/"
cp "$BR/etc/pacman.d/mirrorlist" "$AIROOT/etc/pacman.d/mirrorlist"
# always build from the newest dotfiles (fast-forward only; keep going on the local copy if offline or diverged)
if [[ -d $DOTFILES/.git ]]; then
    sudo -u "$BUILD_USER" git -C "$DOTFILES" pull -q --ff-only --recurse-submodules ||
        warn "could not update the dotfiles; building from the local copy"
    git -c safe.directory='*' -C "$DOTFILES" rev-parse HEAD > "$WORK/dotfiles.commit"
    msg "  dotfiles at $(git -c safe.directory='*' -C "$DOTFILES" log -1 --format='%h %s')"
fi
DOTFILES=$DOTFILES PERSONAL=$PERSONAL bash "$LACUNA/scripts/make-skel.sh" "$WORK/skel"
rm -rf "$AIROOT/home/amnesia"; mkdir -p "$AIROOT/home"
cp -a "$WORK/skel" "$AIROOT/home/amnesia"
[[ -f $WORK/dotfiles.commit ]] && cp "$WORK/dotfiles.commit" "$AIROOT/etc/lacuna-dotfiles-commit"
# profile picture: the dashboard and lock screen read ~/.face
PFP=${PFP:-$(cd "$LACUNA/.." && pwd)/pfp_dark.png}
if [[ -f $PFP ]]; then install -m 644 "$PFP" "$AIROOT/home/amnesia/.face"; else warn "no profile picture at $PFP"; fi

msg "airootfs: greeter"
source "$LACUNA/scripts/greeter.sh"

msg "airootfs: anonium + sandbox"
# anonium (Chromium disguised as Chrome on Windows, its own Tor) runs in `sandbox`, whose root helper anonium
# expects at the rice-security path. Both come from the public part of rice-security (PLAN section 1: harden core).
RICESEC=${RICESEC:-$(cd "$LACUNA/.." && pwd)/rice-security}
ANONIUM=${ANONIUM:-$(cd "$LACUNA/.." && pwd)/anonium}
[[ -f $ANONIUM && -f $RICESEC/bin/sandbox && -f $RICESEC/lib/sandbox-run ]] ||
    die "anonium ($ANONIUM) or the sandbox tooling ($RICESEC) is missing"
install -Dm755 "$ANONIUM" "$AIROOT/usr/local/bin/anonium"
install -Dm755 "$RICESEC/bin/sandbox" "$AIROOT/usr/local/bin/sandbox"
install -Dm755 "$RICESEC/lib/sandbox-run" "$AIROOT/usr/local/lib/rice-security/lib/sandbox-run"
install -Dm644 "$RICESEC/lib/wl-secctx.py" "$AIROOT/usr/local/lib/rice-security/lib/wl-secctx.py"
install -Dm644 "$RICESEC/polkit/org.rice.sandbox.policy" "$AIROOT/usr/share/polkit-1/actions/org.rice.sandbox.policy"

msg "airootfs: Tor Browser"
WORK=$WORK bash "$LACUNA/scripts/tor-browser.sh" "$AIROOT"

msg "airootfs: gate"
source "$LACUNA/scripts/gate.sh"

msg "airootfs: installer"
source "$LACUNA/scripts/installer.sh"

msg "airootfs: vault"
source "$LACUNA/scripts/vault.sh"

msg "airootfs: apparmor"
source "$LACUNA/scripts/apparmor.sh"

msg "airootfs: shufflecake"
source "$LACUNA/scripts/shufflecake.sh"

msg "airootfs: customize"
air bash /build/lacuna/scripts/customize.sh

msg "airootfs: secureboot"
source "$LACUNA/scripts/secureboot.sh"

msg "airootfs: personal-data check"
bash "$LACUNA/scripts/check-personal.sh" "$AIROOT"

# the live system (and the installer) use normal mirrors, even when the build was pinned to a snapshot
echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > "$AIROOT/etc/pacman.d/mirrorlist"
echo "${ARCH_SNAPSHOT:-rolling}" > "$AIROOT/etc/lacuna-package-snapshot"

# mkarchiso: these steps are done
for s in _make_custom_airootfs _make_packages _make_customize_airootfs; do touch "$ISOWORK/base.$s"; done
