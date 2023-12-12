#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -x
set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd ${OUTDIR}/linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here

    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- mrproper

    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- defconfig

    make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- all

fi

cp ${OUTDIR}/linux-stable/arch/arm64/boot/Image ${OUTDIR}

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir rootfs
cd rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu-
make CONFIG_PREFIX=${OUTDIR}/rootfs/ ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- install

cd ${OUTDIR}/rootfs
echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs

SYSROOT_DIR=`aarch64-none-linux-gnu-gcc --print-sysroot`
cp $SYSROOT_DIR/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib

cp $SYSROOT_DIR/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/

cp $SYSROOT_DIR/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/

cp $SYSROOT_DIR/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/

# TODO: Make device nodes
cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 45

# TODO: Clean and build the writer utility

make -C $FINDER_APP_DIR clean
make -C $FINDER_APP_DIR CROSS_COMPILE=aarch64-none-linux-gnu-

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cd ${OUTDIR}/rootfs
cp $FINDER_APP_DIR/finder.sh ./home/
cp $FINDER_APP_DIR/finder-test.sh ./home/
cp $FINDER_APP_DIR/writer ./home/
mkdir ./home/conf
cp $FINDER_APP_DIR/conf/username.txt ./home/conf
cp $FINDER_APP_DIR/conf/assignment.txt ./home/conf
cp $FINDER_APP_DIR/autorun-qemu.sh ./home/

# TODO: Chown the root directory
cd ${OUTDIR}/rootfs
sudo chown -R root:root .

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find .| cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio.gz
