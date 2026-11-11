# Stage "iso" (sourced by build.sh): stock mkarchiso inside the build root. The airootfs stage left markers, so it only
# does the boot setup, cleanup, squashfs, EFI image and xorriso steps (all of which work without mounts).
[[ -e $ISOWORK/base._make_customize_airootfs && -e $AIROOT/boot/vmlinuz-linux-hardened ]] ||
    die "run the airootfs stage first (it also restores /boot after a previous iso run)"
# forget every mkarchiso step except the three the airootfs stage did itself
find "$ISOWORK" -maxdepth 1 -type f -name '*._*' ! -name 'base._make_custom_airootfs' ! -name 'base._make_packages' \
    ! -name 'base._make_customize_airootfs' -delete
# mkarchiso keeps its first build date in $ISOWORK/build_date and reuses it forever: every ISO then had the same
# date and the same boot UUID, so with two Lacuna media attached the initramfs could mount the wrong one's system.
# A fresh date per build, unless SOURCE_DATE_EPOCH is set on purpose (reproducible releases).
rm -f "$ISOWORK/build_date"
[[ -n ${SOURCE_DATE_EPOCH:-} ]] && printf '%s\n' "$SOURCE_DATE_EPOCH" > "$ISOWORK/build_date"
msg "iso: mkarchiso"
# Secure Boot (scripts/secureboot.sh): mkarchiso puts systemd-boot at EFI/BOOT/BOOTX64.EFI; a patched copy puts
# shim there instead, with the MOK-signed systemd-boot as grubx64.efi (what shim starts), MokManager, and the
# certificate to enroll. The ISO 9660 copy and the El Torito FAT image both get them (mkarchiso copies EFI/).
python3 -I - "$BR/usr/bin/mkarchiso" "$BR/usr/local/bin/mkarchiso-lacuna" <<'PY'
import sys
s = open(sys.argv[1]).read()
old = """    install -m 0644 -- "${pacstrap_dir}/usr/lib/systemd/boot/efi/systemd-boot${target_arch,,}.efi" \\
        "${isofs_dir}/EFI/BOOT/BOOT${target_arch}.EFI"
"""
new = """    if [[ "${target_arch^^}" == X64 && -s /build/sb/shimx64.efi && -s /build/sb/grubx64.efi ]]; then
        # FAT ignores case: one name only (a leftover BOOTx64.EFI next to BOOTX64.EFI breaks the FAT copy)
        rm -f -- "${isofs_dir}/EFI/BOOT/"BOOT[xX]64.EFI
        install -m 0644 -- /build/sb/shimx64.efi "${isofs_dir}/EFI/BOOT/BOOT${target_arch}.EFI"
        install -m 0644 -- /build/sb/mmx64.efi "${isofs_dir}/EFI/BOOT/mmx64.efi"
        install -m 0644 -- /build/sb/grubx64.efi "${isofs_dir}/EFI/BOOT/grubx64.efi"
        install -m 0644 -- /build/sb/LACUNA-MOK.cer "${isofs_dir}/EFI/LACUNA-MOK.cer"
    else
        install -m 0644 -- "${pacstrap_dir}/usr/lib/systemd/boot/efi/systemd-boot${target_arch,,}.efi" \\
            "${isofs_dir}/EFI/BOOT/BOOT${target_arch}.EFI"
    fi
"""
assert s.count(old) == 1, "mkarchiso changed: update the shim patch in scripts/iso.sh"
open(sys.argv[2], "w").write(s.replace(old, new))
PY
chmod 755 "$BR/usr/local/bin/mkarchiso-lacuna"
br mkarchiso-lacuna -v -w /build/iso -o /build/out /build/lacuna/profile
iso=$(ls -t "$OUT"/lacuna-*.iso | head -1)
# name it after the dotfiles commit it was built from, so builds of the same day don't overwrite each other
if [[ -f $WORK/dotfiles.commit ]]; then
    c=$(cut -c1-7 "$WORK/dotfiles.commit")
    named=${iso%-x86_64.iso}-$c-x86_64.iso
    mv -f "$iso" "$named"; iso=$named
fi
(cd "$OUT" && sha256sum "${iso##*/}" > "${iso##*/}.sha256")
# release signature: a build key of its own (made once in $KEYS/gnupg), public key next to the ISO
export GNUPGHOME=$KEYS/gnupg
if ! gpg --list-secret-keys lacuna-release >/dev/null 2>&1; then
    install -d -m 700 "$GNUPGHOME"
    gpg --batch --passphrase '' --quick-gen-key "Lacuna release (build key) <lacuna-release>" ed25519 sign 0 2>/dev/null
fi
gpg --batch --yes --armor --export lacuna-release > "$OUT/lacuna-release-key.asc"
gpg --batch --yes --detach-sign --armor -u lacuna-release -o "$iso.sig" "$iso" || die "iso: signing failed"
echo "   signed: ${iso##*/}.sig (key $(gpg --with-colons --list-keys lacuna-release | awk -F: '/^fpr/ {print $10; exit}'))"
unset GNUPGHOME
msg "ISO: $iso ($(du -h "$iso" | cut -f1))"
cat "$iso.sha256"
