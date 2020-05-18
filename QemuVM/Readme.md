# PPC64le Qemu Virtual Machine <!-- omit in toc -->

The objective of this guide is to provide an end-to-end solution on running a PPC64le Virtual machine and building the necessary packages to a fully-functional Qemu VM and it's boot requirements.

The boot process for Qemu uses IBM's [SLOF (Slimline Open Firmware)](https://github.com/qemu/SLOF) and Grub as the bootloader. The image file has two partitions, the first a PReP partition that is required by PPC64 and the second the rootfs. Kernel image and initramfs are in the `/boot` dir on root partition.

Below is a diagram of the process:

```sh
+----------------------------------+          Grub                  Linux
|                                  |
|            BOOTLOADER            |    +----------------+    +--------------------+
|                                  |    |                |    |                    |
|  +-----------+    +-----------+  |    |   Grub  Menu   |    | Starting kernel ...|
|  |           |    |           |  |    |                |    | [0.00] Linux versio|
|  |           |    |  PReP     |  |    | 1. Kernel 5.5  |    | [0.00] Kernel comma|
+  |    SLOF   +--->+  Partition|  +--->+ 2. Kernel 5.6  +--->+ ..                 |
|  |           |    |  with     |  |    |                |    | ...                |
|  |           |    |  Grub     |  |    |                |    |                    |
|  |           |    |           |  |    |                |    |                    |
|  +-----------+    +-----------+  |    +----------------+    +--------------------+
|                                  |
+----------------------------------+

```

## Table of Contents <!-- omit in toc -->

* [Running the Qemu VM](#running-the-qemu-vm)
  * [Install Qemu on Mac](#install-qemu-on-mac)
  * [Install Qemu on Linux](#install-qemu-on-linux)
  * [Running](#running)
  * [SSH login into the guest](#ssh-login-into-the-guest)
  * [Additional config](#additional-config)
* [Building the Qemu VM Image](#building-the-qemu-vm-image)
  * [Install Toolchain to build Kernel](#install-toolchain-to-build-kernel)
  * [Clone repositories](#clone-repositories)
  * [Linux Kernel](#linux-kernel)
    * [Downloading a prebuilt Kernel](#downloading-a-prebuilt-kernel)
    * [Building the Kernel](#building-the-kernel)
  * [Creating disk image](#creating-disk-image)
  * [Create tarball for distribution](#create-tarball-for-distribution)
  * [Remount Qcow image for changes](#remount-qcow-image-for-changes)
  * [Creating snapshots](#creating-snapshots)
* [References](#references)

## Running the Qemu VM

### Install Qemu on Mac

On mac, installing Qemu is a matter of using [homebrew](https://brew.sh/) and installing with `brew install qemu`. Avoid using Qemu 4.2 due to a know problem. I recommend installing Qemu from source HEAD with `brew install qemu --HEAD -s`.

### Install Qemu on Linux

On Debian or Ubuntu distros, install Qemu with:

```bash
sudo apt-get update
sudo apt-get install qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support
```

On Fedora, install with `dnf install qemu`.

I recommend building Qemu from source.

Currently there are three distributions of PPC64le VMs pre-packaged for Qemu:

* [Debian Sid](https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/DebianSid-ppc64le-QemuVM-202005.tar.gz)
* [Ubuntu Focal](https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/UbuntuFocal-ppc64le-QemuVM-202005.tar.gz)

### Running

To run the VM, download, unzip and use the script:

    ./run_ppc64elVM.sh

### SSH login into the guest

    ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost

Login with user `root` and password `ppc64le`.

### Additional config

If required, you can add additional ports to be mapped between the VM and your host. Add them to the startup script `run_ppc64elVM.sh` lines `TCPports` or `UDPports`.

--------------------------------------------------------------------------------

## Building the Qemu VM Image

### Install Toolchain to build Kernel

This process has been done in a amd64 VM running Debian Buster.

First install the ppc64le toolchain. I recommend downloading a pre-built one from [Bootlin](https://toolchains.bootlin.com/releases_powerpc64le-power8.html).

### Clone repositories

Clone the required repositories. You need OpenSBI (bootloader), U-Boot and the Linux kernel. I keep all in one directory.

```sh
mkdir qemu-boot
cd qemu-boot

# Linux Kernel
git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux
```

### Linux Kernel

#### Downloading a prebuilt Kernel

An easier option is downloading and extracting a prebuilt kernel from Debian repository like:

```sh
kernel_url="http://ftp.debian.org/debian/pool/main/l/linux/linux-image-5.6.0-1-powerpc64le_5.6.7-1_ppc64el.deb"

mkdir kernel && cd kernel && wget $kernel_url && ar x linux-image-*.deb && tar xf data.tar.* && cd ..
mv kernel/boot/vmlinux* .
pushd kernel/lib/modules && tar -cvzf kernel-modules.tar.gz  * && popd && mv kernel/lib/modules/kernel-modules.tar.gz .
rm -rf kernel
```

#### Building the Kernel

Let's checkout a stable Kernel version (check `git tag` for available versions).

```sh
pushd linux
git checkout v5.6
```

Download config from the repo. This config has most requirements for containers and networking features built-in and is confirmed to work. This config is modified from the one included in Debian Buster.

```sh
wget -O .config https://github.com/carlosedp/ppc64-bringup/raw/master/QemuVM/config-ppc64le
```

Build the kernel. The `menuconfig` line is in case you want to customize any parameter. Also set the `$version` variable to be used later.

```sh
make CROSS_COMPILE=powerpc64le-linux- ARCH=powerpc olddefconfig
make CROSS_COMPILE=powerpc64le-linux- ARCH=powerpc menuconfig
make CROSS_COMPILE=powerpc64le-linux- ARCH=powerpc -j6
```

Check if building produced the file `vmlinux`.

**Generating Kernel modules:**

```bash
rm -rf modules_install
mkdir -p modules_install
CROSS_COMPILE=powerpc64le-linux- ARCH=powerpc make modules_install INSTALL_MOD_PATH=./modules_install
version=`cat include/config/kernel.release`
echo $version
pushd ./modules_install/lib/modules

tar -cf kernel-modules-${version}.tar .
gzip kernel-modules-${version}.tar
popd
mv ./modules_install/lib/modules/kernel-modules-${version}.tar.gz .
```

### Creating disk image

```bash
# Create and mount the disk image. Adjust maximum size on qemu-img below
qemu-img create -f qcow2 ppc64le-QemuVM.qcow2 10G
sudo modprobe nbd max_part=16
sudo qemu-nbd -c /dev/nbd0 ppc64le-QemuVM.qcow2

sudo sfdisk /dev/nbd0 << 'EOF'
label: dos
label-id: 0x297f8257
device: /dev/nbd0
unit: sectors

/dev/nbd0p1 : start=        2048, size=       14336, type=41, bootable
/dev/nbd0p2 : start=       16384, type=83
EOF

sudo mkfs.ext4 /dev/nbd0p2
sudo e2label /dev/nbd0p2 rootfs

mkdir rootfs
sudo mount /dev/nbd0p2 rootfs
```

As the root filesystem, you can choose between downloading a pre-built tarball or build the rootfs yourself. The available rootfs are listed on <https://github.com/carlosedp/ppc64-bringup/release>.

* Debian Buster: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/debian-buster-rootfs.tar.gz`.
* Ubuntu Focal: `wget -O rootfs.tar.bz2 https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/ubuntu-focal-rootfs.tar.gz`.

To build the rootfs from scratch, check the [guide for Debian](https://github.com/carlosedp/ppc64-bringup/blob/master/Debian-Rootfs-Guide.md) or the [guide for Ubuntu](https://github.com/carlosedp/ppc64-bringup/blob/master/Ubuntu-Rootfs-Guide.md).

Installing Kernel, modules and bootloader:

```bash
# Unpack choosen rootfs
sudo tar vxf rootfs.tar.bz2 -C ./rootfs --strip-components=1

# Unpack Kernel modules (built or downloaded previously)
sudo mkdir -p ./rootfs/lib/modules
sudo cp vmlinux* ./rootfs/boot
sudo tar vxf kernel-modules.tar.gz -C ./rootfs/lib/modules

# Generate initramfs
sudo chroot ./rootfs update-initramfs -c -k all

# Do not boot in quiet mode
sudo sed -i  's/quiet//' rootfs/etc/default/grub

# Install Grub2 as bootloader
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i ./rootfs/$i; done
sudo chroot rootfs grub-install /dev/nbd0p1
sudo chroot rootfs update-grub /dev/nbd0p1
for i in /dev/pts /proc /sys /run /dev; do sudo umount ./rootfs/$i; done

sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

### Create tarball for distribution

```bash
mkdir qemu-vm
mv ppc64le-QemuVM.qcow2 qemu-vm

# Create start script
cat > qemu-vm/run_ppc64elVM.sh << 'EOF'
#!/bin/bash

# List here required TCP and UDP ports to be exposed on Qemu
TCPports=(2049 38188 8080 6443 8443 9090 9093)
UDPports=(2049 38188)

LocalSSHPort=22222

for port in ${TCPports[@]}
do
 ports=hostfwd=tcp::$port-:$port,$ports
done
for port in ${UDPports[@]}
do
 ports=hostfwd=udp::$port-:$port,$ports
done

ports=$ports"hostfwd=tcp::$LocalSSHPort-:22"
ports="hostfwd=tcp::$LocalSSHPort-:22"

# Accelerate if KVM is available
ARGS=""
if $(command -v lsmod > /dev/null); then
  if [ $(uname -m) == "ppc64le" ]; then
    sudo modprobe kvm
    sudo modprobe kvm-hv
    ARGS="-enable-kvm -machine cap-ccf-assist=off"
  fi
fi

qemu-system-ppc64 \
    -M pseries -cpu POWER9 -smp cores=4,threads=1 -m 4G \
    $ARGS \
    -display none -nographic -nodefaults -serial mon:stdio  \
    -drive file=ppc64le-QemuVM.qcow2,format=qcow2,if=virtio \
    -netdev user,id=network01,$ports -device virtio-net-pci,netdev=network01

EOF

# Create start script
cat > qemu-vm/ssh.sh << 'EOF'
#!/bin/bash
ssh -p 22222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost
EOF

chmod +x qemu-vm/run_ppc64elVM.sh qemu-vm/ssh.sh
tar -cf ppc64le-QemuVM.tar qemu-vm
gzip ppc64le-QemuVM.tar
```

Now start the VM with the `run_ppc64elVM.sh` script. After boot, login on console or connect via SSH using `ssh.sh` in another terminal.

Kernel files are in `/boot`. You can add new versions or modify parameters with Grub.

Root password is *ppc64le*.

### Remount Qcow image for changes

```bash
sudo qemu-nbd -c /dev/nbd0 ./qemu-vm/ppc64le-QemuVM.qcow2
sudo partx -a /dev/nbd0

sudo mount /dev/nbd0p1 rootfs

# Edit as will

sudo umount rootfs
sudo qemu-nbd -d /dev/nbd0
```

### Creating snapshots

You can create a snapshot Qcow2 file that works as copy-on-write based on an existing base image.
This way you can keep the original image with base packages and the new snapshot holds all changes.

```bash
sudo qemu-img create -f qcow2 -b ppc64le-QemuVM.qcow2 snapshot-layer.qcow2
```

Then point the `-drive` parameter to this new layer. Keep both on same directory.

## References

