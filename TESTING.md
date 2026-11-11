# What to check on the next ISO

Build: `work/out/lacuna-<date>-<dotfiles commit>-x86_64.iso`. It contains milestones 1-9. Nothing in it was tested
in QEMU, so these checks happen on the laptop.

## Things that were broken: check they're fixed

1. **Stick pull: the screen dimmed and froze.** The wipe now froze the compositor (so nothing restarts), but its
   console switch (`chvt`) then waited forever for the frozen compositor to give up the screen. Now everything is
   killed first, nothing in the screen step waits, and a watchdog powers off after at most 20 s + 2 s per GiB of
   RAM whatever happens. Check: pull the stick on the normal entry. The screen goes black or dark at once (on
   panels that only dim at brightness 0, it's black once the console is cleared), and the machine powers off.
2. **Strip at the bottom of the greeter.** It was the few pixels below the last row of text: foot drew them
   see-through and Textual's cells opaque. foot is opaque now, in the same colour. Check: no strip.
3. **powerlevel10k "fetching gitstatusd" in every new terminal.** Its helper is now in the image. Check: a new
   terminal starts without that message.
4. **PIA login failed.** The cause isn't known yet. The setup now enables PIA's background mode before logging in,
   logs out first, retries the login 3 times, and the **real piactl message** is shown on the start screen and in
   `journalctl -b -u lacuna-greeterd`. Check: PIA works, or tell me the message it shows.
5. **Built-in Snowflake stuck at 10%.** In the build container the image's own Tor + Snowflake reached 100% in
   30 s, so the config is right. 10% is where Snowflake starts its WebRTC (UDP) connection, and networks that
   block UDP stop it right there. After a minute stuck, the start screen now says so and shows Tor's last
   transport message. Check: on the same network, try meek, or the new restricted-network option (item 8). Tell me
   the "Last message" if Snowflake is still stuck on an open network.

## Found in the Proxmox VM tests (fixed in this build)

O. **Tor mode: nothing but Tor Browser could reach the internet.** The firewall redirected apps' traffic into Tor
   and then dropped it (its accept rule checked the route from before the redirect). Fixed and checked in the VM:
   `curl https://check.torproject.org/api/ip` says IsTor:true and DNS works. Check: any app works in Tor mode.
P. **Hidden passphrase failed when the stick isn't USB** (SD card reader, virtual disk): the internal-disk rule made
   it read-only. vault now makes the boot disk writable itself. Normal USB sticks weren't affected.
Q. **systemd stalled for a minute at a time** (sudo and systemctl hung): the reaper opened a login session every 20 s.
   Check: `sudo` and `systemctl status` answer at once.
R. Greeter: old screens showed through behind the current one, long labels were cut off, a "Back" hint on the
   first screen, and a Ctrl+P command palette. All fixed.

## New in this build

S. **Decoy-only persistence** (`sudo vault` → create → kind 2): just the plain folder ~/Persistent, no hidden part,
   no saved settings. It opens exactly like the decoy of a hidden vault, which is the point: since decoy-only
   vaults exist, a decoy alone doesn't suggest a hidden part. To make that true, **every decoy now opens
   read-write** (before, a decoy opened read-only, which itself hinted at a hidden part). Writing a lot into the
   decoy of a hidden vault can overwrite the hidden part once the decoy fills up to it (VeraCrypt's usual trade-off).
T. **AppArmor** is on (kernel `lsm=...apparmor...`, apparmor.service). Tor Browser (firefox and its own tor) runs
   confined in enforce mode, with the profiles Tails uses (from torbrowser-launcher), adapted to where Lacuna runs
   it. Check: `sudo aa-status` lists `torbrowser_firefox` in enforce mode and a firefox process under it; Tor
   Browser browses, plays video with sound, and downloads into ~/Downloads/Tor Browser. If something is blocked:
   `journalctl -k | grep -i apparmor`.

U. **Opsec session** (greeter → Options → Session: Opsec). A minimal floating desktop (labwc + waybar + fuzzel):
   - network is Tor only in Tails' model: no transparent redirect, apps reach Tor only through SOCKS, anything else
     has no network at all; no VPN modes, no Unsafe Browser (the switches are gone);
   - the launcher (Super+Space, or "Apps" on the bar) offers only Tor Browser, a terminal (foot), Thunar,
     KeePassXC, Lacuna Settings and Persistence. Nothing starts by itself;
   - extra apps are chosen on the "Apps for this session" screen (Thunderbird, Signal, Element, Electrum, Monero,
     SimpleX, Spotify, mpv). Each runs through `torapp` on its own Tor SOCKS port, so its own circuits;
   - keys: Super+Return terminal, Super+B Tor Browser, Super+E files, Super+Alt+L lock, Super+Q close,
     Super+arrows maximize/snap; right-click the desktop for a menu.
   Check: `sudo leaktest` passes in this session (plain connections must fail); Tor Browser works; an added app
   (e.g. Electrum) connects. In the terminal, use `torsocks curl ...` for anything that should go out.

## Milestone 9 (previous build)

I. **Your rice's VPN update** (vpnctl, the bar's VPN menu, the IVPN menu) is in. In a VPN mode the gate points
   the bar at that VPN (`~/.config/rice/vpn.json` provider), with auto-connect off since the gate connects. Check:
   in Mullvad or IVPN mode the bar's VPN menu shows that VPN as connected; region and method changes from the
   menu work. Switching provider from the bar doesn't (it needs your root helper, which Lacuna doesn't have): use
   Lacuna Settings.
J. **Every TUI screen scrolls.** On every screen of the greeter, Lacuna Settings and the installer, the middle
   scrolls and the title, buttons and messages stay put. Checked here at 70x18 for every control on every screen.
   Check: with a big font or a small screen, Tab reaches everything and Continue/Back stay visible.
K. **Secure Boot on the stick** (shim): Fedora's Microsoft-signed shim, then systemd-boot and the kernel signed
   with this build's own key. The first time with Secure Boot on:
   1. In the firmware: Secure Boot on, with the Microsoft third-party UEFI CA allowed (on some laptops a separate
      "allow Microsoft 3rd-party UEFI CA" switch).
   2. Boot the stick. shim shows a blue MokManager screen ("Verification failed" first is normal): **Enroll key
      from disk**, pick the stick's EFI partition, then `EFI/LACUNA-MOK.cer`, Continue, Yes, Reboot.
   3. It boots normally from then on. In Lacuna, `mokutil --sb-state` says "SecureBoot enabled".
   With Secure Boot off, nothing changes (shim just starts systemd-boot). The initramfs isn't covered, as with
   most distros.
L. **Shufflecake** as the second persistence backend (`sudo vault` -> create -> backend 2). It hides which parts
   of the stick changed between two images of it. Hidden and decoy work as before: the hidden passphrase opens
   both, the decoy passphrase only the decoy (read-write now, see S). Unlock tries VeraCrypt and Shufflecake at once, and the
   answer always takes ~15 s. **None of this could be tested here** (no block devices in the build container):
   try it on a stick without data you care about. Check: `lsmod | grep dm_sflc` shows the module.
M. **Signed ISO:** `gpg --import lacuna-release-key.asc && gpg --verify lacuna-...iso.sig lacuna-...iso`.
N. **Builds:** `ARCH_SNAPSHOT=2026/11/10 sudo ./build.sh` pins every package to that day (reproducible
   releases). `.github/workflows/build.yml` builds on GitHub once the repo is there (see the comments in it).

## Milestone 8 + VPNs (previous build)

F. **Mullvad and IVPN** next to PIA. The mode screen is now Tor / a VPN / Tor over a VPN / Offline, with a VPN
   picker (PIA, Mullvad, IVPN) and the right account field (PIA user + password, Mullvad account number, IVPN
   account ID). An account is saved in the persistence only after it has logged in once. Check: each VPN
   connects, `curl https://ipinfo.io` shows its address, and "Tor over Mullvad/IVPN" connects too.
   IVPN note: its CLI only takes the account ID as an argument.
G. **Installer** ("Install to this computer" in the launcher, or `sudo installer`). Every step asks: disk
   (guided or your own partitions), LUKS2 (cipher, key size, KDF, unlock time, TPM2, FIDO2), filesystem and swap,
   systemd-boot + signed UKIs, Secure Boot with your own keys, login screen, package groups (graphics, desktop,
   apps, Tor, each VPN), the rice's dotfiles, system settings, and harden modules. At the end: review, then **Save**
   writes the configuration as .json (to `~/Private/lacuna-installer/` when the persistence is open; no
   passwords in it). Next time, **Load** it, or `sudo installer --config FILE`. It needs a network mode (packages
   come from the Arch mirrors over Tor/VPN; the AUR ones from the stick). Try it on a spare disk or machine first.
H. **harden** on the installed system: `harden` shows the status. `sudo harden dns portal` lets a Wi-Fi sign-in
   page through for 5 minutes. `sudo harden secureboot enroll --microsoft` (firmware in setup mode) enrolls the
   keys if the installer couldn't.

## New in the previous build

A. **Screens that didn't fit** (the mode screen hid Back/Continue): the middle of each screen now scrolls, and the
   title, buttons and messages always stay visible. Check: the mode screen with "Custom bridge lines" open still
   shows Back/Continue. Tab moves into the hidden fields and scrolls to them.
B. **Restricted network = Tor only:** "Tor connects only over port 443". PIA is left alone (back to WireGuard).
C. **Unsafe Browser** (like Tails): switch it on in the greeter's options (or Lacuna Settings), then open **Unsafe
   Browser** from the launcher. Chromium opens with a red warning page and http://neverssl.com (which brings up a
   Wi-Fi sign-in page). It goes straight out, not through Tor or PIA. Check:
   - with the switch off, it refuses to start ("didn't start" notification);
   - on, in Tor mode, a hotel/café sign-in works, and `curl https://check.torproject.org/api/ip` in a terminal
     still says IsTor:true (only the browser's own user goes out directly);
   - closing it and opening it again starts empty.
D. **Tor Browser as its own user** (`torbrowser`): it opens as before. Downloads land in ~/Downloads/Tor Browser.
   Sound works in videos. `ps -o user,cmd -C firefox` shows `torbrowser`.
E. **Kiwix library** in the persistence: `sudo vault features enable kiwix` (or Lacuna Settings).

## New in the previous build

6. **Wrong passphrase:** says "No persistence opened: wrong passphrase, or none on this stick" and lets you try
   again. Only an empty field starts without persistence. (The message is the same whether or not a vault
   exists, so that's still deniable.)
7. **Stickless entry:** a "Remove the USB stick" screen comes first, and nothing goes on until the stick is out.
   Then it continues by itself.
8. **Restricted network** (switch on the mode screen): only TCP port 443 is used. Tor without bridges only uses
   relays on 443. Built-in obfs4 keeps only its 3 bridges on 443, and meek is HTTPS anyway. Snowflake is refused
   with this switch (it needs UDP). PIA switches to OpenVPN over TCP 443. Check: Tor and PIA both connect with it
   on, and the setting is saved in the persistence.
9. **Lacuna Settings** (launcher), in the session:
   - **Network:** mode, bridges, restricted network, PIA account (a new one replaces the saved one, and is only
     saved once it has logged in). The status screen shows Tor % / PIA as in the greeter.
   - **What the persistence keeps** (hidden passphrase only): switches for SSH, GnuPG, Spotify, Thunderbird, ...
   - **Set an admin password** (only shown when none is set; changing an existing one stays a greeter thing,
     otherwise an unlocked session could take over root).
   - With the hidden persistence, a working network choice becomes the default for the next start.
10. **reaper (milestone 6):** 6 hours locked, or in the greeter, or (no password) idle with the screens off, then
    wipe and power off. With the persistence open, it is written out and unmounted cleanly first.
    - Quick test: edit the boot entry, add `lacuna.reaper=120` (seconds). Lock the screen (needs a password) and
      wait: off after 2 minutes. Unlocked, it never fires. `sudo /usr/local/lib/lacuna/reaper status` shows the
      clock.
    - Lid close now locks through lacuna-lock as well (before, with no password set, it would have locked you
      out for good).

## From before (if not done yet)

11. Persistence create/unlock (hidden: settings restored, ~/Private; decoy: ~/Persistent, read-write).
12. Tor over PIA, PIA alone, Offline. Leak check with `tcpdump` on another machine.
13. USBGuard Allow notification; internal disks RO=1; Tor Browser and Anonium.

## Logs, if something fails

- Greeter, unlock, PIA: `journalctl -b -u lacuna-greeterd -u greetd -u lacuna-gate -u piavpn`.
- Tor: `sudo cat /var/log/tor/notices.log`.
- Wipe/reaper: `systemctl status lacuna-stickwatch lacuna-reaper` (before pulling the stick).
