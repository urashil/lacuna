# mullvad-vpn-bin: only the daemon + CLI (mullvad-vpn-daemon-bin), not the Electron GUI. Lacuna drives it from the
# gate and the greeter. The .deb is checked against Mullvad's signing key, fetched by fingerprint into the build
# user's keyring (makepkg verifies with it).
set -euo pipefail
KEY=A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF
grep -q "$KEY" PKGBUILD || { echo "mullvad-vpn-bin: the signing key changed in the PKGBUILD; check it" >&2; exit 1; }
export GNUPGHOME="$(cd ../.. && pwd)/home-builder/.gnupg"
mkdir -p -m 700 "$GNUPGHOME"
curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$KEY" | gpg -q --import 2>/dev/null || true
gpg --list-keys --with-colons "$KEY" 2>/dev/null | grep -q "^fpr:*$KEY:" || { echo "mullvad key not imported" >&2; exit 1; }
python3 - <<'PY'
import re
s = open("PKGBUILD").read()
s, n = re.subn(r"pkgname=\(\s*'mullvad-vpn-bin'\s*'mullvad-vpn-daemon-bin'\s*\)", "pkgname=('mullvad-vpn-daemon-bin')", s)
assert n == 1, "pkgname list changed"
open("PKGBUILD", "w").write(s)
PY
