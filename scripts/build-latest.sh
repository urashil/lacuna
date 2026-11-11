#!/usr/bin/env bash
# Rebuilds (airootfs + iso) until the ISO matches the newest dotfiles commit on GitHub: if a commit lands while a
# build runs, that build still finishes and the next round picks the commit up. Run as root, detached:
#   sudo setsid nohup scripts/build-latest.sh >/dev/null 2>&1 &      (log: ../work/build.log)
source "$(dirname "$0")/common.sh"
log=$WORK/build.log
while :; do
    "$LACUNA/build.sh" airootfs iso > "$log" 2>&1 || { echo "EXIT $?" >> "$log"; exit 1; }
    echo "EXIT 0" >> "$log"
    used=$(cat "$WORK/dotfiles.commit" 2>/dev/null || echo none)
    remote=$(git -c safe.directory='*' -C "$DOTFILES" ls-remote origin HEAD 2>/dev/null | cut -f1)
    if [[ -z $remote || $remote == "$used" ]]; then
        echo "LATEST $used" >> "$log"; exit 0
    fi
    echo "NEWER dotfiles $remote (built ${used:0:7}): rebuilding" >> "$log"
    cp "$log" "$WORK/build-${used:0:7}.log"
done
