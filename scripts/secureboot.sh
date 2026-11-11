# Stage part "secureboot" (sourced by airootfs.sh, after customize): Secure Boot for the stick itself (milestone 9).
#
#   firmware (Microsoft UEFI CA 2011) -> shim (Fedora's, signed by Microsoft) -> systemd-boot (signed with the
#   Lacuna MOK) -> the kernel (signed with the Lacuna MOK, checked by shim through its protocol)
#
# The first time, shim can't verify systemd-boot and opens MokManager: "Enroll key from disk" -> the stick's
# EFI partition -> LACUNA-MOK.cer, then reboot. The MOK's private key is made once, here, in $KEYS: it never goes
# into the image. (The initramfs isn't covered: shim and systemd-boot only check EFI binaries.)
SHIM_URL=https://kojipkgs.fedoraproject.org/packages/shim/16.1/7/x86_64/shim-x64-16.1-7.x86_64.rpm
SHIM_SHA256=0a119f3488e5da27ca55c1864ee8e131afa5ecf27689385ba09b805eb00dd608
KVER=$(ls "$AIROOT/usr/lib/modules" | head -1)

ensure_mok
br openssl x509 -in /build/keys/MOK.crt -outform DER -out /build/sb/LACUNA-MOK.cer

# shim + MokManager, pinned
rpm=$CACHE/${SHIM_URL##*/}
[[ -s $rpm ]] || curl -fsSL -o "$rpm" "$SHIM_URL" || die "secureboot: shim download failed"
echo "$SHIM_SHA256  $rpm" | sha256sum -c --quiet - || { rm -f "$rpm"; die "secureboot: shim checksum mismatch"; }
tmp=$(mktemp -d); bsdtar -xf "$rpm" -C "$tmp"
install -m 644 "$(find "$tmp" -name shimx64.efi | head -1)" "$SB/shimx64.efi"
install -m 644 "$(find "$tmp" -name mmx64.efi | head -1)" "$SB/mmx64.efi"
rm -rf "$tmp"
grep -aq 'Microsoft Corporation UEFI CA 2011' "$SB/shimx64.efi" || die "secureboot: that shim isn't Microsoft-signed"

# sign: systemd-boot (as grubx64.efi, the name shim starts) and the kernel; already-signed files are left alone
sign() {   # sign IN OUT  (paths inside the build root)
    br sh -c "if ! sbverify --cert /build/keys/MOK.crt '$2' >/dev/null 2>&1; then
                  sbsign --key /build/keys/MOK.key --cert /build/keys/MOK.crt --output '$2.new' '$1' >/dev/null &&
                  mv -f '$2.new' '$2'
              fi" || die "secureboot: signing $1 failed"
}
br pacman -S --needed --noconfirm sbsigntools >/dev/null
rm -f "$SB/grubx64.efi"
sign /build/iso/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi /build/sb/grubx64.efi
sign /build/iso/x86_64/airootfs/boot/vmlinuz-linux-hardened /build/iso/x86_64/airootfs/boot/vmlinuz-linux-hardened
br sbverify --cert /build/keys/MOK.crt /build/sb/grubx64.efi >/dev/null || die "secureboot: systemd-boot not signed"
br sbverify --cert /build/keys/MOK.crt /build/iso/x86_64/airootfs/boot/vmlinuz-linux-hardened >/dev/null ||
    die "secureboot: kernel not signed"
install -Dm644 "$SB/LACUNA-MOK.cer" "$AIROOT/usr/share/lacuna/LACUNA-MOK.cer"
echo "   secureboot: shim 16.1 + MOK-signed systemd-boot and kernel ($KVER)"
