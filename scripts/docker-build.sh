#!/bin/bash

set -e
DOCKERDIST=$HOME/docker-dist
ARCH=ppc64le

sudo apt install -y build-essential cmake pkg-config btrfs-tools libbtrfs-dev libdevmapper-dev libseccomp-dev

mkdir -p $DOCKERDIST
mkdir -p $DOCKERDIST/debs
cd $DOCKERDIST

# Containerd
mkdir -p $GOPATH/src/github.com/containerd/
pushd $GOPATH/src/github.com/containerd/
if [ ! -d containerd ]; then
    git clone https://github.com/containerd/containerd;
    pushd containerd
else
    pushd containerd
    git pull;
fi
git checkout $(git tag | sort -V | tail -1)

make BUILDTAGS="no_btrfs"

# For debs
DESTDIR=$DOCKERDIST/debs/usr/local make install
git checkout master
popd
popd

# Runc
mkdir -p $GOPATH/src/github.com/opencontainers/
pushd $GOPATH/src/github.com/opencontainers/
if [ ! -d runc ]; then
    git clone https://github.com/opencontainers/runc;
    pushd runc
else
    pushd runc
    git pull;
fi
git checkout $(git tag | sort -V | tail -1)

make
DESTDIR=$DOCKERDIST/debs/ make install
git checkout master
popd
popd


# Docker cli
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
if [ ! -d cli ]; then
    git clone https://github.com/docker/cli
    pushd cli
else
    pushd cli
    git pull;
fi
git checkout $(git tag | sort -V | grep ^v | tail -1)

./scripts/build/binary

# For debs
cp ./build/docker-linux-$ARCH $DOCKERDIST/debs/usr/local/bin
ln -sf $DOCKERDIST/debs/usr/local/bin/docker-linux-$ARCH $DOCKERDIST/debs/usr/local/bin/docker
git checkout master
popd
popd

# Docker init
if [ ! -d tini ]; then
    git clone https://github.com/krallin/tini
    pushd tini
else
    pushd tini
    git pull;
fi

export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
cmake . && make

# For debs
cp tini-static $DOCKERDIST/debs/usr/local/bin/docker-init
popd

# Docker proxy
mkdir -p $GOPATH/src/github.com/docker
pushd $GOPATH/src/github.com/docker

if [ ! -d libnetwork ]; then
    git clone https://github.com/docker/libnetwork/
    pushd libnetwork
else
    pushd libnetwork
    git pull;
fi

go get github.com/ishidawataru/sctp
go build ./cmd/proxy

# For debs
cp proxy $DOCKERDIST/debs/usr/local/bin/docker-proxy
popd
popd

# Rootlesskit
mkdir -p $GOPATH/src/github.com/rootless-containers/
pushd $GOPATH/src/github.com/rootless-containers/
if [ ! -d rootlesskit ]; then
    git clone https://github.com/rootless-containers/rootlesskit.git
    pushd rootlesskit
else
    pushd rootlesskit
    git pull;
fi

make

# For debs
cp bin/* $DOCKERDIST/debs/usr/local/bin/
popd
popd

# Dockerd
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
if [ ! -d docker ]; then
    git clone git://github.com/moby/moby docker
    pushd docker
else
    pushd docker
    git pull;
fi
git checkout $(git tag | sort -V | grep ^v | tail -1)

sudo cp ./contrib/dockerd-rootless.sh $DOCKERDIST/debs/usr/local/bin

./hack/make.sh binary
sudo cp bundles/binary-daemon/dockerd-dev $DOCKERDIST/debs/usr/local/bin/dockerd
DOCKERVERSION=$(git tag | sort -V | grep ^v | tail -1 | sed s/^v//)
git checkout master
popd
popd

mkdir -p $DOCKERDIST/debs/etc/systemd/system/
# Systemd
cat << EOF | sudo tee $DOCKERDIST/debs/etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
KillMode=process
Delegate=yes
LimitNOFILE=1048576
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

cat << EOF | sudo tee $DOCKERDIST/debs/etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/local/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

cat << EOF | sudo tee $DOCKERDIST/debs/etc/systemd/system/docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

mkdir -p $DOCKERDIST/debs/DEBIAN
cat << EOF | sudo tee $DOCKERDIST/debs/DEBIAN/control
Package: docker
Version: $DOCKERVERSION
Architecture: ppc64el
Maintainer: Carlos de Paula <carlosedp@gmail.com>
Depends: libseccomp2 (>= 2.3.0), conntrack, ebtables, ethtool, iproute2, iptables, mount, socat, util-linux
Description: Docker Engine and CLI
EOF

cat << EOF | sudo tee $DOCKERDIST/debs/DEBIAN/postinst
#!/bin/sh
# see: dh_installdeb(1)

set -o errexit
set -o nounset

case "$1" in
    configure)
        # postinst configure step auto-starts it.
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable containerd 2>/dev/null || true
        systemctl enable docker 2>/dev/null || true
        systemctl restart containerd 2>/dev/null || true
        systemctl restart docker 2>/dev/null || true
        groupadd docker 2>/dev/null || true
        echo "To add permission to additional users, run: sudo usermod -aG docker $USER"
    ;;

    abort-upgrade|abort-remove|abort-deconfigure)
        exit 1
    ;;

    *)
    ;;
esac

# dh_installdeb will replace this with shell code automatically
# generated by other debhelper scripts.

#DEBHELPER#

exit 0
EOF

sudo chmod +x $DOCKERDIST/debs/DEBIAN/postinst

pushd $DOCKERDIST
dpkg-deb -b debs "docker-"$DOCKERVERSION"_ppc64el.deb"
pushd debs
tar -cf "docker-"$DOCKERVERSION"_ppc64el.tar" --exclude DEBIAN .
gzip "docker-"$DOCKERVERSION"_ppc64el.tar"
popd
mv debs/"docker-"$DOCKERVERSION"_ppc64el.tar.gz" .
popd