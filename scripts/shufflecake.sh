# Stage part "shufflecake" (sourced by airootfs.sh, before customize): the Shufflecake persistence backend
# (milestone 9): its kernel module, built against the image's own kernel and signed with the MOK, and its CLI.
SFLC_VER=0.6.2
SFLC_SHA256=e3547816b832ba4c66ce4f561767a6a3236a5659aae19ed21fa9e18f99e6a764
KVER=$(ls "$AIROOT/usr/lib/modules" | head -1)
ensure_mok
tar=$CACHE/shufflecake-$SFLC_VER.tar.gz
[[ -s $tar ]] || curl -fsSL -o "$tar" "https://codeberg.org/shufflecake/shufflecake-c/archive/v$SFLC_VER.tar.gz" ||
    die "shufflecake: download failed"
echo "$SFLC_SHA256  $tar" | sha256sum -c --quiet - || { rm -f "$tar"; die "shufflecake: checksum mismatch"; }

# the build root's headers must be exactly the image's kernel
br pacman -S --needed --noconfirm linux-hardened-headers libgcrypt device-mapper base-devel pkgconf sbsigntools >/dev/null
[[ -d $BR/usr/lib/modules/$KVER/build ]] ||
    die "shufflecake: the build root has no headers for $KVER (its linux-hardened-headers is another version)"
src=$ISOWORK/sflc-build
rm -rf "$src"; mkdir -p "$src"; tar -xzf "$tar" -C "$src" --strip-components=1
br sh -c "cd /build/iso/sflc-build && make KERNEL_DIR=/usr/lib/modules/$KVER/build -j$(nproc) >/build/iso/sflc-build/build.log 2>&1" ||
    { tail -20 "$src/build.log"; die "shufflecake: build failed"; }
# sign the module with the MOK, so it also loads where module signatures are enforced (Secure Boot + MOK)
br "/usr/lib/modules/$KVER/build/scripts/sign-file" sha512 /build/keys/MOK.key /build/keys/MOK.crt /build/iso/sflc-build/dm-sflc/dm-sflc.ko ||
    die "shufflecake: signing the module failed"
install -Dm644 "$src/dm-sflc/dm-sflc.ko" "$AIROOT/usr/lib/modules/$KVER/updates/dm-sflc.ko"
install -Dm755 "$src/sflc/build/bin/sflc" "$AIROOT/usr/local/sbin/sflc"
air depmod "$KVER"
rm -rf "$src"
echo "   shufflecake: $SFLC_VER (module for $KVER, signed with the MOK)"
