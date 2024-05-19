#!/bin/bash

#set -e

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=cust_defconfig
ANYKERNEL3_DIR=$PWD/AnyKernel3/
FINAL_KERNEL_ZIP=YAMK-miatoll-$(date '+%Y%m%d').zip
ZYC_REPO="$HOME/zyc"
ZYC_BIN="$ZYC_REPO/bin/clang"

if ! [ -d "$ZYC_REPO" ]; then
    echo "ZYC clang not found, cloning via HTTPS..."
    git clone https://github.com/ZyCromerZ/Clang.git "$ZYC_REPO"
fi

if ! [ -d "$ZYC_BIN" ]; then
    echo "ZYC clang binary not found. Please run the compiler script"
    exit 1
fi

export PATH="$ZYC_REPO/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_HOST=cosmos
export KBUILD_BUILD_USER=cosmic
export KBUILD_COMPILER_STRING="$($ZYC_REPO/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Speed up build process
MAKE="./makeparallel"

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

# Clean build always lol
echo "**** Cleaning ****"
mkdir -p out
make O=out clean
make mrproper

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "***********************************************$nocol"
make $KERNEL_DEFCONFIG O=out
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      LD=ld.lld \
                      LLVM=1 \
                      LLVM_IAS=1

echo "**** Verify Image.gz, dtbo.img & dtb ****"
ls $PWD/out/arch/arm64/boot/Image.gz
ls $PWD/out/arch/arm64/boot/dtbo.img
ls $PWD/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb

# Anykernel 3 time!!
echo "**** Verifying AnyKernel3 Directory ****"
ls $ANYKERNEL3_DIR
echo "**** Removing leftovers ****"
rm -rf $ANYKERNEL3_DIR/Image.gz
rm -rf $ANYKERNEL3_DIR/dtbo.img
rm -rf $ANYKERNEL3_DIR/dtb
rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP

echo "**** Copying Image.gz , dtbo.img & dtb ****"
cp $PWD/out/arch/arm64/boot/Image.gz $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dtbo.img $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb $ANYKERNEL3_DIR/dtb

echo "**** Time to zip up! ****"
cd $ANYKERNEL3_DIR/
zip -r9 "../$FINAL_KERNEL_ZIP" * -x README $FINAL_KERNEL_ZIP

echo "**** Done, here is your sha1 ****"
cd ..
rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP
rm -rf $ANYKERNEL3_DIR/Image.gz
rm -rf $ANYKERNEL3_DIR/dtbo.img
rm -rf $ANYKERNEL3_DIR/dtb
rm -rf out/

sha1sum $FINAL_KERNEL_ZIP

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
