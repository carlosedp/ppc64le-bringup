# Building and Running K3s

This is intented to guide you on installing and building K3s from source and all changes required to the repositories. This guide will be updated as the PRs get upstreamed.

I already provide the K3s binary pre-built on this repository [releases](https://github.com/carlosedp/ppc64-bringup/releases) section, download from there and follow from the [Installing](#installing) section.

If you want to build from source, check the section [below](#building-from-source).

## Installing

```sh
wget https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/k3s-ppc64le
sudo install ./dist/artifacts/k3s-ppc64le /usr/local/bin/k3s
for APP in kubectl crictl ctr;do sudo ln -sf /usr/local/bin/k3s /usr/local/bin/$APP;done
```

Soon I will adjust the `install.sh` script to make installation simpler.

## Running

If not using the systemd script (soon), start manually with:

```sh
sudo k3s server &
sudo chmod 777 /etc/rancher/k3s/k3s.yaml    # Give permission to all users (optional)

# Check (use sudo if chmod command below is not executed)
sudo kubectl get nodes
```

This will allow all users to access the cluster thru the cluster config file. For more info, check the [official docs](https://github.com/rancher/k3s/#documentation).

## Deploy test app

This will deploy the NGINX web server into the cluster and expose it on an ingress route on your node.

```sh
DOMAIN=`ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'`.nip.io
kubectl create deployment nginx -n default --image=nginx
kubectl create service clusterip nginx -n default --tcp=80:80

cat <<EOF | kubectl apply -f -
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
    name: nginx
    namespace: default
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: nginx.$DOMAIN
      http:
        paths:
        - path: /
          backend:
            serviceName: nginx
            servicePort: 80
EOF

curl nginx.$DOMAIN
```

## Building from source

To build the required images, use or follow the `build-images.sh` script.

Checkout K3s from it's master branch and apply the patch below:

```bash
git clone https://github.com/rancher/k3s.git
cd k3s

wget https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/k3s-master.patch
patch --ignore-whitespace << k3s-master.patch
```

After this, run `./scripts/download && ./scripts/build && ./scripts/package-cli` on a `ppc64le` host and you will have the binaries at the `dist` dir.

## Misc

In case you get firewall errors or no communication between containers, check config with `sudo k3s check-config`. You might need to enable iptables legacy mode:

```sh
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
```

To clean a previous execution and remove all files:

```sh
Clean

ps aux |grep -v grep |grep shim | awk '{print $2}'|xargs sudo kill -9
ps aux |grep -v grep |grep pause | awk '{print $2}'|xargs sudo kill -9
ps aux |grep -v grep |grep coredns | awk '{print $2}'|xargs sudo kill -9

mount|grep kubelet|awk '{print $3}'| xargs sudo umount
mount|grep cni|awk '{print $3}'| xargs sudo umount
mount|grep containerd|awk '{print $3}'| xargs sudo umount
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/rancher
sudo rm -rf /etc/rancher/k3s

sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F
```

