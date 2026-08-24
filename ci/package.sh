# shellcheck shell=bash
# shellcheck disable=SC2164,SC2153,SC2034

################################################################################
# Packaging
################################################################################

prepare_package_name() {
    VARIANT="$(is_true "$KSU" && echo "KSU" || echo "VNL")"
    is_true "$SUSFS" && VARIANT+="-SUSFS"
    is_true "$LXC" && VARIANT+="-LXC"
    PACKAGE_NAME="$KERNEL_NAME-$KERNEL_VERSION-$VARIANT"
    if ! is_true "$IS_RELEASE"; then
        PACKAGE_NAME+="-$KERNEL_COMMIT"
    fi
}

package_anykernel() {
    step "Package AnyKernel3"

    local package_name="$1"
    local package_path="$OUT_DIR/$package_name-AnyKernel3.zip"

    pushd "$AK3" > /dev/null
    cp -p "$KERNEL_OUT/arch/arm64/boot/Image" .

    info "Compressing kernel image using zstd..."
    zstd -19 -T0 --no-progress -o Image.zst Image > /dev/null 2>&1
    rm -f ./Image
    sha256sum Image.zst > Image.zst.sha256

    info "Cleaning up AK3..."
    find . -type f -name 'placeholder' -delete
    find . -mindepth 1 -depth -type d -empty -delete

    rm -f "$package_path"
    zip -r9q -T -X -y -n .zst "$package_path" . -x '.git/*' '*.log' '.github/*' 'README.md'

    popd > /dev/null
    success "AnyKernel3 packaged"
}

package_bootimg() {
    if is_device_target; then
        return
    fi

    make_boot() {
        "$MKBOOTIMG/mkbootimg.py" \
            --header_version "4" \
            --kernel "$1" \
            --output "$2" \
            --ramdisk out/ramdisk \
            --os_version "12.0.0" \
            --os_patch_level "2099-12"
        "$BUILD_TOOLS/linux-x86/bin/avbtool" add_hash_footer \
            --partition_name boot \
            --partition_size "$partition_size" \
            --image "$2" \
            --algorithm SHA256_RSA4096 \
            --key "$BOOT_SIGN_KEY"
    }

    step "Package boot image"

    # Only needed for generic boot image packaging.
    validate_deps bootimg

    local package_name="$1"
    local partition_size=$((64 * 1024 * 1024))

    pushd "$BOOT_IMAGE" > /dev/null

    curl -fsSLo gki-kernel.zip "$GKI_URL"
    unzip gki-kernel.zip > /dev/null 2>&1 && rm gki-kernel.zip

    "$MKBOOTIMG/unpack_bootimg.py" --boot_img="boot-5.10.img"
    cp -p "$KERNEL_OUT/arch/arm64/boot/Image" ./Image

    gzip -n -k -f -9 Image
    lz4 -f -l --favor-decSpeed Image Image.lz4

    make_boot "Image" "boot-raw.img"
    make_boot "Image.gz" "boot-gz.img"
    make_boot "Image.lz4" "boot-lz4.img"

    cp "$BOOT_IMAGE/boot-raw.img" "$OUT_DIR/$package_name-boot-raw.img"
    cp "$BOOT_IMAGE/boot-gz.img" "$OUT_DIR/$package_name-boot-gz.img"
    cp "$BOOT_IMAGE/boot-lz4.img" "$OUT_DIR/$package_name-boot-lz4.img"

    popd > /dev/null
}

package_firmware() {
    local package_name="$1"
    local package_path="$OUT_DIR/$package_name-firmware-KSU.zip"

    step "Package USB WLAN firmware module"

    local fw_root="$OUT_DIR/firmware-module"
    reset_dir "$fw_root"
    mkdir -p "$fw_root/system/vendor/firmware"

    cat > "$fw_root/module.prop" << EOF
id=usb_wifi_firmware
name=USB WiFi Dongle Firmware
version=$KERNEL_VERSION
versionCode=1
author=$KERNEL_NAME Builder
description=Firmware and drivers for the USB Wi-Fi adapters enabled by USB_WLAN=true: Ralink rt2x00 USB, Atheros ath9k_htc/carl9170/ar5523. Overlays firmware into /vendor/firmware via magic mount and loads the dongle drivers at boot through post-fs-data. Requires a root manager such as KernelSU or Magisk.
EOF

    cat > "$fw_root/customize.sh" << 'EOF'
SKIPUNZIP=0

ui_print "- Installing USB Wi-Fi dongle firmware to /vendor/firmware"
ui_print "- Dongle drivers load at the next boot; replug the adapter after booting"
ui_print "- Android settings won't manage dongle interfaces; configure them manually with root"
EOF

    local fw_file fw_dir ok=0
    for fw_file in "${USB_FIRMWARE_FILES[@]}"; do
        fw_dir="$(dirname "$fw_file")"
        [[ $fw_dir == "." ]] || mkdir -p "$fw_root/system/vendor/firmware/$fw_dir"
        if curl -fsSLo "$fw_root/system/vendor/firmware/$fw_file" "$LINUX_FIRMWARE_URL/$fw_file"; then
            ok=$((ok + 1))
            info "Firmware downloaded: $fw_file"
        else
            rm -f "$fw_root/system/vendor/firmware/$fw_file"
            warn "Firmware download failed, skipping: $fw_file"
        fi
    done

    if ((ok == 0)); then
        error "No USB Wi-Fi firmware could be downloaded"
    fi

    local mod mod_dir="$fw_root/system/lib/modules" copied=0
    mkdir -p "$mod_dir"

    {
        echo '#!/system/bin/sh'
        echo
        # shellcheck disable=SC2016
        echo 'MODDIR=${0%/*}'
        echo
        for mod in "${USB_WLAN_MODULES[@]}"; do
            echo "insmod \"\$MODDIR/system/lib/modules/$mod.ko\" 2>/dev/null"
        done
    } > "$fw_root/post-fs-data.sh"
    chmod 0755 "$fw_root/post-fs-data.sh"

    for mod in "${USB_WLAN_MODULES[@]}"; do
        if [[ -f $MOD_STAGE/usb_wlan/$mod.ko ]]; then
            cp -p "$MOD_STAGE/usb_wlan/$mod.ko" "$mod_dir/"
            copied=$((copied + 1))
        else
            warn "USB WLAN module missing from staging: $mod.ko"
        fi
    done
    info "Bundled $copied USB WLAN kernel module(s)"

    pushd "$fw_root" > /dev/null
    rm -f "$package_path"
    zip -r9q -T -X "$package_path" .
    popd > /dev/null

    rm -rf "$fw_root"
    success "USB WLAN firmware module packaged"
}

write_metadata() {
    step "Write metadata"

    META_FILE="$WORKSPACE/github.json"

    local package_name="$1"

    py_cli meta write \
        "$META_FILE" \
        "$KERNEL_VERSION" "$KERNEL_NAME" "$COMPILER_STRING" \
        "$package_name" "$VARIANT" "$KERNEL_NAME" "$OUT_DIR" \
        "$RELEASE_REPO" "$RELEASE_BRANCH" \
        "$KERNEL_COMMIT"
}

notify_success() {
    local final_package="$1"
    local build_time="$2"
    # For indicating package type (boot image, anykernel3)
    local additional_tag="$3"

    local kernel_commit_url
    kernel_commit_url="$(repo_spec "$KERNEL_REPO" github-commit-url "$KERNEL_COMMIT")"

    local minutes=$((build_time / 60))
    local seconds=$((build_time % 60))

    local result_caption
    result_caption=$(
        cat << EOF
✅ *$(escape_md_v2 "$KERNEL_NAME Build Successfully!")*

🏷️ \#$(escape_md_v2 "$BUILD_TAG") \#$(escape_md_v2 "$additional_tag")
$(tg_run_line)
*Target:* $(escape_md_v2 "$TARGET_NAME")
*Time:* $(escape_md_v2 "${minutes}m ${seconds}s")
*Kernel:* $(escape_md_v2 "$KERNEL_VERSION")
*Commit:* [$(escape_md_v2 "$KERNEL_COMMIT")]($(escape_md_v2 "$kernel_commit_url"))
*Compiler:* $(escape_md_v2 "$COMPILER_STRING")
*Features:* KSU $(parse_bool "$KSU"), SuSFS $(is_true "$SUSFS" && escape_md_v2 "$SUSFS_VERSION" || echo "Disabled"), LXC $(parse_bool "$LXC"), Droidspaces $(parse_bool "$DROIDSPACES"), USB serial $(parse_bool "$USB_SERIAL"), USB net $(parse_bool "$USB_NET"), USB WLAN $(parse_bool "$USB_WLAN"), Stock config $(parse_bool "$STOCK_CONFIG")
EOF
    )

    telegram_upload_file "$final_package" "$result_caption"
}

telegram_notify() {
    local build_time="$1"
    local package_name="$2"

    # AnyKernel3
    local ak3_package="$OUT_DIR/$package_name-AnyKernel3.zip"
    notify_success "$ak3_package" "$build_time" "anykernel3"

    # Boot image
    if is_device_target; then
        return
    fi
    pushd "$OUT_DIR" > /dev/null
    zip -9q -T "$package_name-boot.zip" "$package_name"-boot*.img
    popd > /dev/null

    notify_success "$OUT_DIR/$package_name-boot.zip" "$build_time" "boot_image"
    rm -f "$OUT_DIR/$package_name-boot.zip"
}
