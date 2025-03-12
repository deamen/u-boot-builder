#!/bin/bash
set -e

# Set atf_ver and uboot_ver environment variables
export atf_ver="lts-v2.10.14"
export uboot_ver="v2025.01"

# Alpine Linux 3.21 use swig 4.3 which causes the build to fail, so we use 3.20
# Need this commit to fix it: https://github.com/u-boot/u-boot/commit/a63456b9191fae2fe49f4b121e025792022e3950
export container=$(buildah from --arch ARM64 docker.io/library/alpine:3.20)
buildah config --label maintainer=""github.com/deamen"" $container

# Set atf_ver environment variables in container
buildah config --env atf_ver=$atf_ver $container

#Set uboot_ver environment variables in container
buildah config --env uboot_ver=$uboot_ver $container

# gnutls-dev is needed in uboot v2025.01
buildah run $container apk add git gcc make libc-dev bison flex openssl-dev python3 dtc gcc-arm-none-eabi py3-setuptools swig python3-dev py3-elftools patch gnutls-dev
buildah run $container git -c advice.detachedHead=false clone https://github.com/ARM-software/arm-trusted-firmware.git --depth 1 --branch $atf_ver
buildah run $container git -c advice.detachedHead=false clone https://github.com/u-boot/u-boot.git --depth 1 --branch $uboot_ver
#buildah run $container git clone https://github.com/Doct2O/orangepi-zero3-bl.git
buildah config --workingdir "/arm-trusted-firmware" $container
buildah run $container make -j$(nproc --ignore 1) PLAT=sun50i_h616 DEBUG=0 bl31
buildah config --env BL31="/arm-trusted-firmware/build/sun50i_h616/release/bl31.bin" $container

buildah config --workingdir "/u-boot" $container


buildah run $container make -j$(nproc --ignore 1) orangepi_zero3_defconfig

buildah run $container make -j$(nproc --ignore 1) CONFIG_SPL_IMAGE_TYPE=sunxi_egon

copy_script="copy_u-boot.sh"
cat << 'EOF' >> $copy_script
#!/bin/sh
mnt=$(buildah mount $container)
cp $mnt/u-boot/u-boot-sunxi-with-spl.bin ./out/u-boot_orangepi_zero3.bin
buildah umount $container
EOF
chmod a+x $copy_script
buildah unshare ./$copy_script
rm ./$copy_script
buildah rm $container
