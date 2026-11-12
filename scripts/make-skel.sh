#!/usr/bin/env bash
# Builds the live user's home template from the public dotfiles (DOTFILES, default ../dotfiles) into $1.
# Personal pieces are dropped here, and scripts/check-personal.sh fails the build if anything personal slips through.
set -euo pipefail
src=${DOTFILES:?}/home dst=$1 home=/home/amnesia
[[ -d $src ]] || { echo "no dotfiles at $src" >&2; exit 1; }
rm -rf "$dst"; mkdir -p "$dst"
cp -a "$src/." "$dst/"

# --- personal pieces of the dotfiles' author: a script outside this repo ($PERSONAL/skel.sh, sourced here with
# $dst set) drops them; scripts/check-personal.sh then fails the build if anything personal slipped through ---
if [[ -f ${PERSONAL:-/nonexistent}/skel.sh ]]; then
    source "$PERSONAL/skel.sh"
fi
find "$dst" -name __pycache__ -prune -exec rm -rf {} +

# niri: drop binds for the removed tools; the old vbar song keys go to playerctl
sed -i -e 's|spawn-sh "qs -c vbar ipc call song key play-pause"|spawn "playerctl" "play-pause"|' \
       -e 's|spawn-sh "qs -c vbar ipc call song key stop"|spawn "playerctl" "stop"|' \
       -e 's|spawn-sh "qs -c vbar ipc call song key previous"|spawn "playerctl" "previous"|' \
       -e 's|spawn-sh "qs -c vbar ipc call song key next"|spawn "playerctl" "next"|' \
       "$dst/.config/niri/config.kdl"
# locking without a password would be a dead end: idle/lid/keybind locks go through lock
sed -i -e "s|'caelestia shell lock lock'|'/usr/local/bin/lock idle'|g" \
       -e 's|spawn "caelestia" "shell" "lock" "lock"|spawn "/usr/local/bin/lock"|g' "$dst/.config/niri/config.kdl"
# idle with no password set: lock only blanks the screens and marks it, so the reaper (6 hours) counts it
# like a lock; the resume clears the mark
sed -i "s|timeout 300 '/usr/local/bin/lock idle'|timeout 300 '/usr/local/bin/lock idle' resume '/usr/local/bin/lock resume'|" "$dst/.config/niri/config.kdl"
grep -q "resume '/usr/local/bin/lock resume'" "$dst/.config/niri/config.kdl" || { echo "make-skel: the swayidle line changed; update the lock edit" >&2; exit 1; }
# everything else that locks (lid close, the bar) uses ~/.local/bin/lock: through lock as well
if [[ -f $dst/.local/bin/lid-close ]]; then
    sed -i 's|"$HOME/.local/bin/lock"|/usr/local/bin/lock idle|g' "$dst/.local/bin/lid-close"
fi
if [[ -f $dst/.local/bin/lock ]]; then
    printf '#!/bin/sh\n# the system lock command (it knows the session: caelestia or swaylock)\nexec /usr/local/bin/lock "$@"\n' \
        > "$dst/.local/bin/lock"
    chmod 755 "$dst/.local/bin/lock"
fi

# what install.sh does in $HOME
{ grep -rlI -e '@HOME@' "$dst" || true; } | xargs -r sed -i -e "s|@HOME@|$home|g"
chmod +x "$dst"/.local/bin/* 2>/dev/null || true
mkdir -p "$dst/Pictures/Screenshots" "$dst/Pictures/Wallpapers" "$dst/.cache/rice" "$dst/.config/rice"
: > "$dst/.config/niri/larp.kdl"
cp -n "$DOTFILES"/wallpapers/* "$dst/Pictures/Wallpapers/"
echo "$home/Pictures/Wallpapers/height-of-magic.png" > "$dst/.cache/rice/current"
echo dark > "$dst/.cache/rice/mode"
mkdir -p "$dst/.themes" && tar -xf "$DOTFILES/assets/Nordic-darker.tar.xz" -C "$dst/.themes"
# powerlevel10k, pinned
p10k=$dst/.local/share/zsh/powerlevel10k
git clone -q https://github.com/romkatv/powerlevel10k.git "$p10k"
git -C "$p10k" checkout -q "${P10K_REV:-v1.20.0}"
rm -rf "$p10k/.git"
# gitstatusd (p10k's git helper) in the image: otherwise every new shell of an amnesic session downloads it again
# ("fetching gitstatusd"), which is slow over Tor. Its installer checks the pinned sha256; usrbin/ is searched first.
GITSTATUS_CACHE_DIR="$p10k/gitstatus/usrbin" sh "$p10k/gitstatus/install" -f -s linux -m x86_64 -- true
ls "$p10k/gitstatus/usrbin/"gitstatusd-linux-x86_64 >/dev/null ||
    { echo "make-skel: gitstatusd was not downloaded" >&2; exit 1; }
echo "skel ready: $(du -sh "$dst" | cut -f1)"
