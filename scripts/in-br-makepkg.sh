#!/usr/bin/env bash
# Runs INSIDE the build root (via proot). One AUR checkout in /build/aur/<pkg>, in three steps:
#   srcinfo  (as the unprivileged build user)  regenerate .SRCINFO after patches
#   deps     (as root)                         install depends/makedepends from the repos + [lacuna]
#   build    (as the unprivileged build user)  makepkg
#   add      (as root)                         copy packages into /build/repo and repo-add
# Root and the build user are separate proot sessions: proot as root can't trace a process that drops to another
# uid (no CAP_SYS_PTRACE in the build container), so we never switch users inside proot.
set -euo pipefail
step=$1 pkg=$2
cd "/build/aur/$pkg"
case $step in
srcinfo) makepkg --printsrcinfo > .SRCINFO ;;
deps)
    mapfile -t deps < <(awk -F' = ' '/^\t(depends|makedepends|checkdepends)(_x86_64)? = /{print $2}' .SRCINFO \
                        | sed -E 's/[<>=].*//' | sort -u)
    pacman -Syu --noconfirm >/dev/null            # a full upgrade: -Sy alone is a partial upgrade (broken deps)
    ((${#deps[@]} == 0)) || pacman -S --needed --noconfirm --asdeps "${deps[@]}"
    ;;
build)
    rm -f ./*.pkg.tar.zst
    PKGDEST="/build/aur/$pkg" makepkg -f --nocheck --noconfirm --nodeps
    ;;
add)
    for f in ./*.pkg.tar.zst; do
        case $f in *-debug-*) continue ;; esac
        cp "$f" /build/repo/
        repo-add -q -R /build/repo/lacuna.db.tar.zst "/build/repo/${f#./}"
    done
    pacman -Sy --noconfirm >/dev/null
    ;;
esac
