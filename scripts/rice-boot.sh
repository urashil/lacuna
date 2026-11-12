# Stage part "rice-boot" (sourced by installer.sh): what the installer needs to give an installed system the rice's
# boot and login screens: the dotfiles' Plymouth artwork function, their sddm.conf, and SilentSDDM (pinned).
RB=$AIROOT/usr/share/lacuna/installer/rice
SILENT_COMMIT=d179078e88cde18195b82841d3e879949b06faa8
SILENT_SHA256=5444823f03eb68c81518c93200367687fd35197f27c1efefb887854ef59debad
rm -rf "$RB"; install -d "$RB"
install -m755 "$LACUNA/installer/rice/rice-boot" "$RB/rice-boot"
# make_plymouth_art, exactly as the dotfiles have it (so the installed boot screen follows their changes)
# (the function's end is the first "}" at the start of a line outside its here-documents: the Plymouth script
#  inside it has its own)
python3 -I - "$DOTFILES/boot/boot-theme.sh" > "$RB/plymouth-art.sh" <<'PY'
import re, sys
out, on, hd = [], False, None
for line in open(sys.argv[1]):
    if not on and line.startswith("make_plymouth_art() {"):
        on = True
    if not on:
        continue
    out.append(line)
    if hd:
        if line.rstrip("\n") == hd:
            hd = None
        continue
    m = re.search(r"<<-?['\"]?([A-Za-z_]+)['\"]?\s*$", line)
    if m:
        hd = m.group(1)
    elif line.startswith("}"):
        break
sys.stdout.write("".join(out))
PY
grep -q 'display_password_callback' "$RB/plymouth-art.sh" ||
    die "rice-boot: make_plymouth_art not found in the dotfiles' boot/boot-theme.sh (or it lost its passphrase entry)"
bash -n "$RB/plymouth-art.sh" || die "rice-boot: the extracted plymouth-art.sh doesn't parse"
install -m644 "$DOTFILES/root/etc/sddm.conf" "$RB/sddm.conf"
tar=$CACHE/SilentSDDM-$SILENT_COMMIT.tar.gz
[[ -s $tar ]] || curl -fsSL -o "$tar" "https://codeload.github.com/uiriansan/SilentSDDM/tar.gz/$SILENT_COMMIT" ||
    die "rice-boot: SilentSDDM download failed"
echo "$SILENT_SHA256  $tar" | sha256sum -c --quiet - || { rm -f "$tar"; die "rice-boot: SilentSDDM checksum mismatch"; }
install -d "$RB/silent"; tar -xzf "$tar" -C "$RB/silent" --strip-components=1
rm -rf "$RB/silent/.git" "$RB/silent/docs" 2>/dev/null || true
echo "   rice-boot: plymouth art from the dotfiles, SilentSDDM ${SILENT_COMMIT:0:7}"
