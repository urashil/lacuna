# Stage part "vault" (sourced by airootfs.sh): the deniable persistence (PLAN section 5) and the stick writer.
V=$LACUNA/vault
install -Dm755 "$V/vault" "$AIROOT/usr/local/bin/vault"
install -Dm755 "$V/flash" "$AIROOT/usr/local/bin/flash"
install -Dm644 "$V/90-lacuna-vault.rules" "$AIROOT/etc/udev/rules.d/90-lacuna-vault.rules"
install -Dm644 "$V/persistence.desktop" "$AIROOT/usr/share/applications/persistence.desktop"
mkdir -p "$AIROOT/etc/systemd/system/multi-user.target.wants"
ln -sf ../lacuna-vault.service "$AIROOT/etc/systemd/system/multi-user.target.wants/lacuna-vault.service"
python3 -I -m py_compile "$AIROOT/usr/local/bin/vault" && rm -rf "$AIROOT/usr/local/bin/__pycache__"
echo "   vault: installed"
