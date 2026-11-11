# Shared settings and helpers for the Lacuna build. Sourced by build.sh (runs on the host side, as root).
#
# The build container has no CAP_SYS_ADMIN, no user namespaces and no loop devices, so nothing here mounts anything.
# Every step that needs an Arch userland runs under proot (path translation via ptrace). proot cannot nest and cannot
# emulate chroot(2), so each stage is started from the host with proot rooted at the tree it works on.

set -euo pipefail

LACUNA=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${WORK:-$(cd "$LACUNA/.." && pwd)/work}
BR=$WORK/root.x86_64            # Arch build root (from the official bootstrap tarball)
REPO=$WORK/repo                 # local pacman repo with the AUR builds
AURSRC=$WORK/aur                # AUR checkouts
CACHE=$WORK/cache               # shared package cache
ISOWORK=$WORK/iso               # mkarchiso work dir
AIROOT=$ISOWORK/x86_64/airootfs # the live system's root
OUT=$WORK/out
DOTFILES=${DOTFILES:-$(cd "$LACUNA/.." && pwd)/dotfiles}

msg()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m  x\033[0m %s\n' "$*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "run as root (sudo)"
[[ -x /usr/local/bin/proot ]] || die "run scripts/build-proot.sh first (Alpine proot is too old)"
PATH=/usr/local/bin:$PATH

PERSONAL=${PERSONAL:-$WORK/personal}   # the build owner's personal drop list + check patterns (not in the repo)
export PERSONAL
KEYS=$WORK/keys                 # Secure Boot MOK + release signing keys: made once, never in the image
SB=$WORK/sb                     # shim, MokManager, signed systemd-boot, the MOK certificate (for the ESP)
mkdir -p "$REPO" "$AURSRC" "$CACHE" "$ISOWORK" "$OUT" "$WORK/home-builder" "$SB"
install -d -m 700 "$KEYS"

# Run a command inside the build root.
br() {
    proot -r "$BR" -b /dev -b /proc -b /sys -b /etc/resolv.conf \
        -b "$LACUNA:/build/lacuna" -b "$REPO:/build/repo" -b "$AURSRC:/build/aur" \
        -b "$CACHE:/var/cache/pacman/pkg" -b "$ISOWORK:/build/iso" -b "$OUT:/build/out" \
        -b "$KEYS:/build/keys" -b "$SB:/build/sb" \
        -w / /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/bin "$@"
}

# Same build root, but as the unprivileged host user (for makepkg). Only the AUR checkouts are writable.
BUILD_USER=${SUDO_USER:-$(logname 2>/dev/null)}
[[ -n $BUILD_USER && $BUILD_USER != root ]] || { echo "run the build with sudo from your normal user" >&2; exit 1; }
br_user() {
    sudo -u "$BUILD_USER" /usr/local/bin/proot -r "$BR" -b /dev -b /proc -b /sys -b /etc/resolv.conf \
        -b "$LACUNA:/build/lacuna" -b "$AURSRC:/build/aur" -b "$WORK/home-builder:/home/builder" \
        -w / /usr/bin/env -i HOME=/home/builder USER=builder TERM="${TERM:-xterm}" LANG=C.UTF-8 \
        MAKEFLAGS="-j$(nproc)" PATH=/usr/local/sbin:/usr/local/bin:/usr/bin "$@"
}

# Run a command inside the live system's root. pacman runs here with root "/", so it never needs chroot(2).
# The keyring is borrowed from the build root at /build/gnupg (pass --gpgdir): gpg-agent hangs under proot, and with
# /etc/pacman.d/gnupg left empty the archlinux-keyring scriptlet skips its --populate instead of hanging.
air() {
    proot -r "$AIROOT" -b /dev -b /proc -b /sys -b /etc/resolv.conf \
        -b "$REPO:/build/repo" -b "$CACHE:/var/cache/pacman/pkg" \
        -b "$BR/etc/pacman.d/gnupg:/build/gnupg" -b "$LACUNA:/build/lacuna" \
        -w / /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/bin "$@"
}

# The Secure Boot MOK (shim's Machine Owner Key), made once: a self-signed code-signing certificate, the form
# MokManager enrolls. Its private key stays in $KEYS; only the certificate goes into the image.
ensure_mok() {
    [[ -s $KEYS/MOK.key && -s $KEYS/MOK.crt ]] && return 0
    br openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 -subj "/CN=Lacuna Secure Boot (build key)/" \
        -addext "extendedKeyUsage=codeSigning" -keyout /build/keys/MOK.key -out /build/keys/MOK.crt >/dev/null 2>&1 ||
        die "could not make the Secure Boot MOK"
    chmod 600 "$KEYS/MOK.key"
}
