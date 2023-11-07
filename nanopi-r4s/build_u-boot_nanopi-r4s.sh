
# Set atf_ver and uboot_ver environment variables
export atf_ver="lts-v2.8.10"
export uboot_ver="v2023.07.02"

export container=$(buildah from arm64v8/alpine:3.18)
buildah config --label maintainer=""github.com/deamen"" $container

# Set atf_ver environment variables in container
buildah config --env atf_ver=$atf_ver $container

#Set uboot_ver environment variables in container
buildah config --env uboot_ver=$uboot_ver $container

buildah run $container apk add git gcc make libc-dev bison flex openssl-dev python3 dtc gcc-arm-none-eabi py3-setuptools swig python3-dev py3-elftools curl
buildah run $container git clone https://github.com/ARM-software/arm-trusted-firmware.git --depth 1 --branch $atf_ver
buildah run $container git clone https://github.com/u-boot/u-boot.git --depth 1 --branch $uboot_ver

buildah config --workingdir "/arm-trusted-firmware" $container

buildah run $container make PLAT=rk3399 DEBUG=0 bl31
buildah config --env BL31="/arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf" $container
buildah config --workingdir "/u-boot" $container


buildah run $container make -j$(nproc --ignore 1) nanopi-r4s-rk3399_defconfig
buildah run $container sed -i -e 's!^CONFIG_BAUDRATE=.*!CONFIG_BAUDRATE=115200!' .config
buildah run $container make -j$(nproc --ignore 1)

copy_script="copy_artifact.sh"
cat << 'EOF' >> $copy_script
#!/bin/sh
mnt=$(buildah mount $container)
cp $mnt/u-boot/u-boot-rockchip.bin ./out/u-boot_nanopi-r4s.bin
buildah umount $container
EOF
chmod a+x $copy_script
buildah unshare ./$copy_script
rm ./$copy_script
buildah rm $container
