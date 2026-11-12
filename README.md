# Lacuna

An amnesic Arch Linux live system: it runs from a USB stick, keeps nothing after shutdown, and lets nothing out
except through Tor (or a VPN, if you choose), with deniable encrypted persistence on the same stick.

> **Experimental and unaudited.** Lacuna has had no outside security review. Bugs that break its guarantees have
> been found during development and more are likely. If being identified would seriously hurt you, use
> [Tails](https://tails.net) instead, which has years of audits and a large user base behind it.

## What it does

- **A password every session.** It unlocks the lock screen. Admin rights (sudo) are a separate choice, off by
  default: without them nothing in the session can become root.
- **Amnesic.** Runs from RAM. No swap, no hibernation, internal disks read-only. Pulling the stick blacks the
  screen, overwrites free RAM and powers off. A lock timer (6 hours locked or idle) does the same.
- **Network gate.** A default-drop nftables firewall. After the greeter, traffic leaves only through:
  - **Tor**, transparently, or in the opsec session SOCKS-only, the way Tails does it;
  - **PIA, Mullvad or IVPN**;
  - **Tor over one of those VPNs**;
  - or nothing at all (offline).

  Bridges: obfs4, Snowflake, meek or your own. A "restricted network" option makes Tor connect only over
  port 443. `leaktest` checks the gate from the machine itself, and its negative control proves it can see a leak.
- **Two sessions.**
  - The normal one: niri with the caelestia shell.
  - An **opsec session**: labwc, waybar and fuzzel. It is Tor-only and SOCKS-only, and each app runs on its own
    Tor circuits. It offers only Tor Browser, a terminal, a file manager and KeePassXC unless you add apps.
- **Deniable persistence** (`vault`). It lives after the ISO on the stick, in space that looks random.
  - **VeraCrypt or Shufflecake.**
  - **Hidden + decoy, or decoy only.** Because decoy-only vaults exist, a decoy alone doesn't suggest a hidden
    part.
  - **One prompt.** A wrong passphrase looks exactly like "no persistence here".
  - **What it keeps:** the hidden part holds your settings (Wi-Fi, VPN accounts, password hash, admin rights, network
    mode) and the folders you choose.
- **Tor Browser** runs as its own user, confined by AppArmor (the profiles Tails uses). An optional **Unsafe
  Browser** handles Wi-Fi sign-in pages; it's off by default and never available in the opsec session.
- **Secure Boot** on the stick itself: Microsoft-signed shim, then systemd-boot and the kernel signed with your
  build's own key (enrolled once through MokManager).
- **Installer.** A TUI where every choice is a prompt and nothing is opinionated:
  - LUKS2, unlocked by any combination of passphrase, TPM2 and FIDO2: any one of them, or all of them (one
    encryption layer each), with a recovery key for every layer that has no passphrase;
  - or Shufflecake, deniable like the stick: a hidden system plus a decoy system, or a decoy only, behind one
    passphrase prompt;
  - a choice of filesystem and swap;
  - systemd-boot with signed UKIs, Secure Boot with your own keys;
  - `harden` modules (firewall, sysctl, USBGuard, DNS over HTTPS, AppArmor, lockdown).

  Configurations save as JSON, in the persistence if you like, so reinstalls replay them.

## Build

The build runs without mounts, user namespaces or KVM, so it works in an unprivileged container. It reimplements
mkarchiso's stages on top of proot, rooted at an Arch build root.

    scripts/build-proot.sh                  # termux proot -> /usr/local/bin/proot
    # extract the Arch bootstrap tarball (verify its signature) to ../work/root.x86_64
    sudo ./build.sh                         # stages: buildroot aur airootfs iso
    sudo ARCH_SNAPSHOT=2026/11/10 ./build.sh   # pin every package to one Arch Linux Archive day

Host tools: bash, coreutils, gnupg, curl, jq, zstd, squashfs-tools, xorriso, mtools, dosfstools,
libarchive (bsdtar), python3, and a C toolchain with talloc headers for proot. The output goes to
`../work/out/`: the ISO, its `.sha256`, a detached GPG signature and the release key.

Your desktop comes from a dotfiles checkout at `../dotfiles` (or `DOTFILES=`). Personal pieces of those dotfiles
can be dropped by `../work/personal/skel.sh`, and `../work/personal/patterns.txt` makes the build fail if anything
matching it ends up in the image. Both live outside the repo. Keys (the Secure Boot MOK, the release key) are made
once in `../work/keys` and never enter the image.

To write a stick: `sudo vault/flash lacuna.iso /dev/sdX` (the ISO plus random data in the rest of the stick).
`--update` replaces the system and keeps the persistence. Plain `dd` works too; `vault create` fills the free space
itself then.

`TESTING.md` is the checklist for testing a build on hardware.

## Layout

| Path | What |
|---|---|
| `build.sh`, `scripts/` | the build: `common.sh` (paths, proot wrappers), one script per stage part |
| `profile/` | the archiso profile: boot entries, packages, the files laid over the live root |
| `greeter/` | greetd greeter (Textual TUI), `greeterd` (root daemon), Settings, `appbox`, the opsec session |
| `gate/` | the network gate (`gate`), `leaktest` |
| `vault/` | `vault` (deniable persistence), `flash` (stick writer) |
| `installer/` | `installer`, `harden` |
| `aur/` | AUR packages built into the image's local repo, with patches |
| `.github/workflows/` | CI: build on demand, on push, on new Tor Browser releases |
