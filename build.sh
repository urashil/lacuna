#!/usr/bin/env bash
# Lacuna build. Run as root on the build host:   sudo ./build.sh [stage...]
# Stages (default: all, in order): buildroot aur airootfs iso
# See PLAN.md "Build environment" for why this doesn't call mkarchiso's pacstrap/arch-chroot directly.
source "$(dirname "$0")/scripts/common.sh"

stage_buildroot() {
    msg "build root"
    [[ -x $BR/usr/bin/pacman ]] || die "no build root at $BR (extract the Arch bootstrap tarball there first)"
    sed -i 's/^CheckSpace/#CheckSpace/; s/^#DisableSandbox$/DisableSandbox/; s/^#ParallelDownloads.*/ParallelDownloads = 8/' \
        "$BR/etc/pacman.conf"
    grep -q '^\[lacuna\]' "$BR/etc/pacman.conf" || cat >> "$BR/etc/pacman.conf" <<'EOF'

# local AUR builds (built on this machine, unsigned)
[lacuna]
SigLevel = Never
Server = file:///build/repo
EOF
    # ARCH_SNAPSHOT=YYYY/MM/DD pins every Arch package to that day's Arch Linux Archive snapshot, so a tagged
    # release always builds from the same packages (the live system and the installer get normal mirrors again)
    if [[ -n ${ARCH_SNAPSHOT:-} ]]; then
        [[ $ARCH_SNAPSHOT =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || die "ARCH_SNAPSHOT: YYYY/MM/DD"
        echo "Server = https://archive.archlinux.org/repos/$ARCH_SNAPSHOT/\$repo/os/\$arch" > "$BR/etc/pacman.d/mirrorlist"
        echo "   packages pinned to the $ARCH_SNAPSHOT snapshot"
    elif ! grep -q '^Server' "$BR/etc/pacman.d/mirrorlist" 2>/dev/null || grep -q archive.archlinux.org "$BR/etc/pacman.d/mirrorlist"; then
        echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > "$BR/etc/pacman.d/mirrorlist"
    fi
    [[ -e $REPO/lacuna.db.tar.zst ]] || br repo-add -q /build/repo/lacuna.db.tar.zst
    # makepkg: all cores, no debug packages, zstd
    sed -i -E 's/^#?MAKEFLAGS=.*/MAKEFLAGS="-j'"$(nproc)"'"/; s/^OPTIONS=\((.*) debug (.*)\)/OPTIONS=(\1 !debug \2)/' \
        "$BR/etc/makepkg.conf"
    br pacman -Syu --noconfirm --needed base-devel git archiso cmake ninja meson
}

stage_aur() {
    msg "AUR packages"
    local pkg
    while read -r pkg; do
        [[ -z $pkg || $pkg == \#* ]] && continue
        if compgen -G "$REPO/${pkg%-bin}-*[0-9]*.pkg.tar.zst" >/dev/null && [[ -z ${REBUILD:-} ]]; then
            echo "   $pkg: already built"; continue
        fi
        msg "  $pkg"
        chown -R "$BUILD_USER": "$AURSRC" "$WORK/home-builder"
        local u=(sudo -u "$BUILD_USER")
        if [[ -d $AURSRC/$pkg/.git ]]; then
            "${u[@]}" git -C "$AURSRC/$pkg" fetch -q && "${u[@]}" git -C "$AURSRC/$pkg" reset -q --hard origin/master
        else
            "${u[@]}" git clone -q "https://aur.archlinux.org/$pkg.git" "$AURSRC/$pkg"
        fi
        [[ -f $LACUNA/aur/patches/$pkg.sh ]] && (cd "$AURSRC/$pkg" && "${u[@]}" bash "$LACUNA/aur/patches/$pkg.sh")
        br_user bash /build/lacuna/scripts/in-br-makepkg.sh srcinfo "$pkg"
        br      bash /build/lacuna/scripts/in-br-makepkg.sh deps "$pkg"
        br_user bash /build/lacuna/scripts/in-br-makepkg.sh build "$pkg"
        br      bash /build/lacuna/scripts/in-br-makepkg.sh add "$pkg"
    done < "$LACUNA/aur/packages.txt"
}

stage_airootfs() { source "$LACUNA/scripts/airootfs.sh"; }
stage_iso()      { source "$LACUNA/scripts/iso.sh"; }

stages=("$@"); ((${#stages[@]})) || stages=(buildroot aur airootfs iso)
for s in "${stages[@]}"; do "stage_$s"; done
msg "done: ${stages[*]}"
