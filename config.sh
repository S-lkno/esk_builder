# shellcheck shell=bash
# shellcheck disable=SC2034

#
# ESK Kernel builder configuration
#

################################################################################
# Branch-specific device configuration
################################################################################
DEVICE_NAME="xaga"
KERNEL_NAME="ESK"
KBUILD_BUILD_HOST="esk"
DEVICE_KERNEL_REPO="github.com:ESK-Project/android_kernel_xiaomi_mt6895@${BRANCH_OVERRIDE:-16.2-rebase}"
DEVICE_AK3_REPO="github.com:ESK-Project/AnyKernel3@xaga"
DEVICE_RELEASE_REPO="ESK-Project/esk-releases"
DEVICE_DEFCONFIG_OVERLAY="vendor/xaga.config"
DEVICE_LXC_SUPPORTED="true"

################################################################################
# Project Identity
################################################################################
KERNEL_DEFCONFIG="gki_defconfig"

# Kbuild identity
KBUILD_BUILD_USER="builder"

# Used for timestamps in logs
TIMEZONE="Asia/Ho_Chi_Minh"

# Where release artifacts are published
RELEASE_BRANCH="main"

################################################################################
# Build target
################################################################################
BUILD_TARGET="${BUILD_TARGET:-device}"

################################################################################
# Build options
################################################################################
# Clang LTO mode: thin | full
CLANG_LTO="thin"

KSU_DEFAULT="false"
SUSFS_DEFAULT="false"
LXC_DEFAULT="false"
DROIDSPACES_DEFAULT="false"
USB_SERIAL_DEFAULT="false"
USB_NET_DEFAULT="false"
USB_WLAN_DEFAULT="false"
TG_NOTIFY_DEFAULT="false"
RESET_SOURCES_DEFAULT="false"
IS_RELEASE_DEFAULT="false"

# Parallel build jobs (override: JOBS=16 ./build.sh)
JOBS="${JOBS:-$(nproc --all)}"

# ccache size
CCACHE_SIZE="${CCACHE_SIZE:-2G}"

################################################################################
# Source
################################################################################
# Format: <host>:<owner/repo>@<ref>
BUILD_TOOLS_REPO="android.googlesource.com:kernel/prebuilts/build-tools@main-kernel-build-2024"
MKBOOTIMG_REPO="android.googlesource.com:platform/system/tools/mkbootimg@main-kernel-build-2024"
SUSFS_REPO="gitlab.com:simonpunk/susfs4ksu@gki-android12-5.10"

# Other sources
GKI_URL="https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-2025-09_r1.zip"
LIBFAKESTAT_RELEASE_API="https://api.github.com/repos/cctv18/libfakestat/releases/latest"
LINUX_FIRMWARE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"

# Firmware files packaged into the USB_WLAN KernelSU module
USB_FIRMWARE_FILES=(
    rt2870.bin
    htc_9271.fw
    htc_7010.fw
    carl9170-1.fw
    ar5523.bin
)

# Kernel modules bundled into the USB_WLAN firmware module and insmodded by its
# post-fs-data hook, in dependency order. They are kept out of vendor_dlkm so
# that flashing a build never grows that image.
USB_WLAN_MODULES=(
    eeprom_93cx6 rt2x00lib rt2x00usb rt2800lib rt2800usb
    ath9k_hw ath9k_common ath9k_htc carl9170 ar5523
    rtl8187 rtl8xxxu zd1201 zd1211rw
)

case "$BUILD_TARGET" in
    device)
        TARGET_NAME="$DEVICE_NAME"
        KERNEL_REPO="$DEVICE_KERNEL_REPO"
        AK3_REPO="$DEVICE_AK3_REPO"
        RELEASE_REPO="$DEVICE_RELEASE_REPO"
        STOCK_CONFIG_DEFAULT="false"
        ;;
    generic)
        TARGET_NAME="generic"
        KERNEL_REPO="github.com:ESK-Project/android12-5.10-gki@${BRANCH_OVERRIDE:-main}"
        AK3_REPO="github.com:ESK-Project/AnyKernel3@generic"
        RELEASE_REPO="ESK-Project/gki-releases"
        STOCK_CONFIG_DEFAULT="true"
        ;;
    *)
        echo "Unknown build target: $BUILD_TARGET" >&2
        exit 1
        ;;
esac

################################################################################
# Paths
################################################################################
# Work dirs
KERNEL="$WORKSPACE/kernel"
AK3="$WORKSPACE/anykernel3"
BUILD_TOOLS="$WORKSPACE/build-tools"
MKBOOTIMG="$WORKSPACE/mkbootimg"
CLANG="$WORKSPACE/clang"
KERNEL_PATCHES="$WORKSPACE/kernel_patches"
SUSFS_DIR="$WORKSPACE/susfs"
LIBFAKESTAT_DIR="$WORKSPACE/libfakestat"

# Output stuff
KERNEL_OUT="$WORKSPACE/work"
OUT_DIR="$WORKSPACE/out"
BOOT_IMAGE="$WORKSPACE/boot_image"
LOGFILE="$WORKSPACE/build.log"
SIGN_KEY="$WORKSPACE/key"

# Helper paths
CLANG_BIN="$CLANG/bin"
BOOT_SIGN_KEY="$SIGN_KEY/boot_sign_key.pem"
LIBFAKESTAT="$LIBFAKESTAT_DIR/libfakestat.so"

# Module paths
MOD="$WORKSPACE/modules"

MOD_FLAT="$MOD/flatten"
MOD_STAGE="$MOD/staging"

MOD_LOAD="$MOD/load"

MODULE_PACKAGE="$OUT_DIR/module.tar.xz"

DLKM_FS_CONFIG="$AK3/config/vendor_dlkm_fs_config"
DLKM_FILE_CONTEXTS="$AK3/config/vendor_dlkm_file_contexts"
