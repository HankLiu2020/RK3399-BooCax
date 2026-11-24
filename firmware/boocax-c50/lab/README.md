# BooCax C50 bootloader lab candidate

Built in GitHub Actions run 45394691686 at U-Boot v2026.10. The large binary is preserved in the ZIP with its FIT report, component checksums and source references.

u-boot-rockchip.bin contains the runtime-matched Rockchip DDR payload, the U-Boot SPL and a FIT with BL31 and the BooCax control tree. It is the payload used by ophub Rockchip packaging, placed at LBA 64 in a newly assembled disk image. It has passed build and artifact checks. Physical boot, storage initialization and boot into Linux remain to be verified. The current eMMC installation uses the separate vendor-format components under known-working/.
