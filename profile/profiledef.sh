#!/usr/bin/env bash
# shellcheck disable=SC2034
iso_name="lacuna"
iso_label="LACUNA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Lacuna"
iso_application="Lacuna live system"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="lacuna"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/root"]="0:0:750"
)
kernel_params_x86_64="init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 slab_nomerge vsyscall=none debugfs=off randomize_kstack_offset=on intel_iommu=on iommu.passthrough=0 iommu.strict=1 efi=disable_early_pci_dma systemd.gpt_auto=0 noresume cow_spacesize=75% lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
