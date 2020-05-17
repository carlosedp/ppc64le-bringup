# Debian Rootfs from scratch

This guide walks thru the build of a Debian root filesystem from scratch.

This process can be done on a Debian or Ubuntu host.

```bash
# Install pre-reqs on host
sudo apt-get install debootstrap qemu-user-static binfmt-support debian-ports-archive-keyring qemu-system qemu-utils qemu-system-misc

mkdir rootfs-buster

# Generate minimal bootstrap rootfs
sudo debootstrap --arch=ppc64el --variant=minbase buster ./rootfs-buster http://deb.debian.org/debian

# chroot to it. Requires "qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support" packages on host
sudo chroot rootfs-buster /bin/bash

# Link init to systemd
ln -sf /lib/systemd/systemd /sbin/init

# Create base config files
mkdir -p /etc/network
cat >/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Add package sources
cat >/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free

deb http://security.debian.org/debian-security buster/updates main contrib
deb-src http://security.debian.org/debian-security buster/updates main contrib
EOF

# Install essential packages
apt-get update
apt-get upgrade -y
apt-get install --no-install-recommends -y util-linux haveged openntpd ntpdate openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim neofetch dhcpcd5 systemd-sysv grub2

cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

cat >/etc/fstab <<EOF
LABEL=rootfs	/	ext4	user_xattr,errors=remount-ro	0	1
EOF

echo "debian-ppc64le" > /etc/hostname

# Disable some services on Qemu
ln -s /dev/null /etc/systemd/network/99-default.link
sed -i 's/^DAEMON_OPTS="/DAEMON_OPTS="-s /' /etc/default/openntpd

# Set root passwd
echo "root:ppc64le" | chpasswd

# Exit chroot
exit

sudo tar -cSf debian-rootfs.tar -C rootfs-buster .
bzip2 debian-rootfs.tar
rm -rf rootfs-buster
```
