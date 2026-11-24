#!/usr/bin/env bash
set -euo pipefail

inputs="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$1"
output="$2"
mkdir -p "$output"
output="$(realpath "$output")"

ddr_rev=0ff82d9067f6fc90d29ed24883c46bc0d532bb4f
bl31_rev=1d47b8d9369522dfc2c5af420b6e41a9993ddd78
uboot_rev=5508406582f6f7120dce0c4b3059819a41788db2
rkbin=https://raw.githubusercontent.com/rockchip-linux/rkbin

cd "$source_dir"
test "$(git rev-parse HEAD)" = "$uboot_rev"
curl -fsSL --retry 3 "$rkbin/$ddr_rev/bin/rk33/rk3399_ddr_800MHz_v1.24.bin" -o ddr.bin
curl -fsSL --retry 3 "$rkbin/$bl31_rev/bin/rk33/rk3399_bl31_v1.36.elf" -o bl31.elf
curl -fsSL --retry 3 "$rkbin/$ddr_rev/README" -o "$output/README-rkbin"
printf '%s\n' \
    '01840f15167d75e2a7790210c749a83ce0f21f0d891cca15f9d8d8de4ca9c6bf  ddr.bin' \
    '3be6cdf32462d7f676d109bb2a97af9a1f469f058674ef0a5cb20941af2923d5  bl31.elf' |
    sha256sum --check

board_dir=dts/upstream/src/arm64/rockchip
cp "$inputs/rk3399-boocax-c50.dts" "$board_dir/"
cp "$inputs/rk3399-boocax-c50-u-boot.dtsi" arch/arm/dts/
printf '\ndtb-$(CONFIG_ROCKCHIP_RK3399) += rk3399-boocax-c50.dtb\n' >> "$board_dir/Makefile"
export CROSS_COMPILE=aarch64-linux-gnu-
export SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)"
export ROCKCHIP_TPL="$PWD/ddr.bin"
export BL31="$PWD/bl31.elf"
make evb-rk3399_defconfig
./scripts/kconfig/merge_config.sh -m .config "$inputs/boocax-c50.config"
make olddefconfig
for option in \
    'CONFIG_DEFAULT_DEVICE_TREE="rockchip/rk3399-boocax-c50"' \
    'CONFIG_ROCKCHIP_EXTERNAL_TPL=y' \
    'CONFIG_SPL_ATF=y' \
    'CONFIG_ENV_IS_NOWHERE=y' \
    'CONFIG_BOOTMETH_EXTLINUX=y' \
    'CONFIG_BOOTMETH_SCRIPT=y' \
    'CONFIG_CMD_BOOTI=y'; do
    grep -Fx -- "$option" .config
done
if grep -Eq '^CONFIG_(TPL|ENV_IS_IN_MMC|VIDEO|MMC_HS400_SUPPORT)=y$' .config; then
    echo "Unexpected option in board configuration" >&2
    exit 1
fi

make -j"$(nproc)"
test "$(fdtget -t s u-boot.dtb / model)" = 'BooCax C50 V1.0'
test "$(fdtget -t s u-boot.dtb /chosen stdout-path)" = 'serial2:1500000n8'
test "$(fdtget -t s u-boot.dtb /i2c@ff3c0000/pmic@1c compatible)" = 'rockchip,rk818'
tools/dumpimage -l u-boot.itb | tee "$output/fit-contents.txt"
grep -qi 'arm-trusted-firmware' "$output/fit-contents.txt"
cp u-boot-rockchip.bin idbloader.img u-boot.itb u-boot.dtb "$output/"
cp .config "$output/uboot.config"
cp Licenses/README "$output/README-uboot-licenses"
printf 'u-boot %s\nddr %s\nbl31 %s\n' "$uboot_rev" "$ddr_rev" "$bl31_rev" > "$output/sources.txt"
(
    cd "$output"
    sha256sum u-boot-rockchip.bin idbloader.img u-boot.itb u-boot.dtb > SHA256SUMS
)
