#!/usr/bin/env bash
# Fetches the current Tor Browser for linux-x86_64, verifies it against the Tor Browser Developers signing key
# (pinned fingerprint below) and unpacks it to $1/opt/tor-browser. Cached in $WORK/dl.
set -euo pipefail
dest=$1 dl=${WORK:?}/dl/tor-browser
TB_KEY=EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
mkdir -p "$dl"
json=$(curl -fsSL https://aus1.torproject.org/torbrowser/update_3/release/downloads.json)
ver=$(jq -r .version <<<"$json")
url=$(jq -r '.downloads["linux-x86_64"].ALL.binary' <<<"$json")
sig=$(jq -r '.downloads["linux-x86_64"].ALL.sig' <<<"$json")
tar=$dl/${url##*/}
[[ -s $tar ]] || curl -fsSL -o "$tar.part" "$url" && { [[ -s $tar ]] || mv "$tar.part" "$tar"; }
curl -fsSL -o "$tar.asc" "$sig"
export GNUPGHOME=$(mktemp -d)
trap 'rm -rf "$GNUPGHOME"' EXIT
curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$TB_KEY" | gpg -q --import 2>/dev/null
# VALIDSIG's last field is the primary key fingerprint: it must be the pinned one
primary=$(gpg --status-fd 1 --verify "$tar.asc" "$tar" 2>/dev/null | awk '/VALIDSIG/{print $NF}')
[[ $primary == "$TB_KEY" ]] || { echo "Tor Browser signature check FAILED ($tar)" >&2; exit 1; }
echo "   Tor Browser $ver: signature OK (key $TB_KEY)"
rm -rf "$dest/opt/tor-browser"; mkdir -p "$dest/opt"
tar -xf "$tar" -C "$dest/opt"
[[ -d $dest/opt/tor-browser ]] || mv "$dest"/opt/tor-browser* "$dest/opt/tor-browser"
chown -R 0:0 "$dest/opt/tor-browser"
chmod -R a+rX "$dest/opt/tor-browser"            # the tarball's dirs are 0700: nobody but root could use it
echo "$ver" > "$dest/opt/tor-browser/LACUNA_VERSION"
