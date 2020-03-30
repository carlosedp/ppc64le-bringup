# PPC64 project tracker and bring-up  <!-- omit in toc -->

The objective of this repository is to track the progress and pre-requisites to bring new applications and projects to PPC64le architecture.

## Contents  <!-- omit in toc -->

* [Docker Community Edition](#docker-community-edition)
* [K3s - Lightweight Kubernetes](#k3s---lightweight-kubernetes)
* [Prometheus](#prometheus)
* [Grafana](#grafana)
* [Traefik Image](#traefik-image)
* [Drone-CI CLI](#drone-ci-cli)
* [Kubernetes Dashboard](#kubernetes-dashboard)

---------------------------------------------------

## Docker Community Edition

Until there is an official package,I've built a `.deb` and tarball packages available in [releases](https://github.com/carlosedp/ppc64-bringup/releases/). All pre-requisites are already bundled in (containerd, runc, dockerd and docker-cli).

```sh
# Download the package for Debian/Ubuntu
wget https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/docker-19.03.8_ppc64el.deb

# or for other distros
wget https://github.com/carlosedp/ppc64-bringup/releases/download/v1.0/docker-19.03.8_ppc64el.tar.gz

# Install for Debian/Ubuntu
sudo apt install ./docker-master-dev_ppc64el.deb

# or other distros
sudo tar vxf docker-master-dev_ppc64el.tar.gz -C /
```

* [ ] Add Debian packages for ppc64el

---------------------------------------------------

## K3s - Lightweight Kubernetes

[K3s](https://k3s.io/) is a highly available, certified Kubernetes distribution designed for production workloads in unattended, resource-constrained, remote locations or inside IoT appliances.

K3s is packaged as a single <40MB binary that reduces the dependencies and steps needed to install, run and auto-update a production Kubernetes cluster.

Since K3s still does not provide `ppc64le` binaries or images, I've build the required pre-requisites and binaries to have a streamlined install on ppc64le architecture. Check the [guide here](k3s/Readme.md#installing) to install on your host.

The [guide](k3s/Readme.md#building-from-source) also provides the process to build images and k3s.

**Dependencies:**

* [ ] Add arch to [dqlite-builder](https://github.com/rancher/dqlite-build) - [PR#12](https://github.com/rancher/dqlite-build/pull/12)
* [ ] Add arch to [k3s-root](https://github.com/rancher/k3s-root) - [PR#7](https://github.com/rancher/k3s-root/pull/7)
* [ ] Fix dapper download on K3s Makefile
* [ ] Add klipper-helm image support or overrire it on Go module.

**Required `ppc64le` images:**

* [ ] `rancher/coredns-coredns:1.6.3` - []()
* [ ] `rancher/klipper-helm:v0.2.3` - [PR#13](https://github.com/rancher/klipper-helm/pull/13)
* [ ] `rancher/klipper-lb:v0.1.2` - []()
* [ ] `rancher/library-traefik:1.7.19` - []()
* [ ] `rancher/local-path-provisioner:v0.0.11` - []()
* [ ] `rancher/pause:3.1` - []()

**Temporary Images:**

All these images are multi-arch for `amd64`, `arm`, `arm64` and `ppc64le`.

* [`carlosedp/pause:3.1`](https://hub.docker.com/r/carlosedp/pause)
* [`carlosedp/local-path-provisioner:v0.0.12`](https://hub.docker.com/r/carlosedp/local-path-provisioner)
* [`carlosedp/klipper-helm:v0.2.3`](https://hub.docker.com/r/carlosedp/klipper-helm)
* [`carlosedp/klipper-lb:v0.1.2`](https://hub.docker.com/r/carlosedp/klipper-lb)
* [`carlosedp/traefik:v2.2.0`](https://hub.docker.com/r/carlosedp/traefik)
* [`carlosedp/traefik:v1.7`](https://hub.docker.com/r/carlosedp/traefik)
* [`carlosedp/metrics-server:v0.3.6`](https://hub.docker.com/r/carlosedp/metrics-server)
* [`coredns/coredns:1.6.3`](https://hub.docker.com/r/coredns/coredns:1.6.3)

---------------------------------------------------

## Prometheus

Add `ppc64le` images to CI:

* [ ] `prometheus` - [PR#7067](https://github.com/prometheus/prometheus/pull/7067)
* [x] `alertmanager` - [PR#2219](https://github.com/prometheus/alertmanager/pull/2219)
* [x] `node-exporter` - Already supports `ppc64le`
* [x] `snmp-exporter` - [PR#494](https://github.com/prometheus/snmp_exporter/pull/494)
* [x] `blackbox-exporter` - [PR#587](https://github.com/prometheus/blackbox_exporter/pull/587)
* [ ] `pushgateway` - [PR#339](https://github.com/prometheus/pushgateway/pull/339)

---------------------------------------------------

## Grafana

* [ ] ~~grafana/grafana - [PR#23177](https://github.com/grafana/grafana/pull/23177)~~ - Cancelled

---------------------------------------------------

## Traefik Image

* [ ] traefik - [PR#]()

---------------------------------------------------

## Drone-CI CLI

Command Line Tools for Drone CI. <https://github.com/drone/drone-cli>

* [x] Add binaries for ppc64le - [PR#170](https://github.com/drone/drone-cli/pull/170)

---------------------------------------------------

## Kubernetes Dashboard

The new Kubernetes dashboard is composed of the Dashboard front-end and the [metrics-scraper](https://github.com/kubernetes-sigs/dashboard-metrics-scraper). The Dashboard is already built for ppc64le but the scraper needs build support.

* [ ] Add build support for ppc64le - [PR#29](https://github.com/kubernetes-sigs/dashboard-metrics-scraper/pull/29)

---------------------------------------------------