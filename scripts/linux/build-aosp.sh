#!/usr/bin/env bash
set -e

echo "========================================="
echo " TabletDroid AOSP Image Build Script"
echo " (Run this on a 64-bit Linux Build Machine)"
echo "========================================="

# 1. 빌드 환경 확인
if [ -z "$ANDROID_BUILD_TOP" ]; then
    echo "[!] Setting up build environment..."
    source build/envsetup.sh
fi

TARGET_PRODUCT="tabletdroid_x86_64"
TARGET_VARIANT="userdebug"

echo "[*] Selecting target: ${TARGET_PRODUCT}-${TARGET_VARIANT}..."
lunch "${TARGET_PRODUCT}-${TARGET_VARIANT}"

echo "[*] Starting build..."
m -j"$(nproc)"

echo "[+] Build completed successfully!"
echo "[+] Images available at: ${ANDROID_PRODUCT_OUT}"
